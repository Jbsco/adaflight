--  The cooperative scheduler: the task table with its periods and static
--  priorities, the queue of enabled tasks in priority order, the realtime
--  gyro, filter, and PID tasks locked to the gyro's cycle, the dynamic
--  priorities that age the other tasks and the check functions that signal
--  the event-driven ones, the fit of a task into the time left before the
--  next gyro cycle with the tuned guard margins, and the execution statistics.
--  One pass of the reference's scheduler is split into phases around the
--  points where it runs a task or reads the clock, so the caller runs the
--  tasks and reads the clocks between them.
with Interfaces;

package Adaflight.Scheduler with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Cycles is Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Ms is Unsigned_32;
   subtype Time_Delta is Integer_32;

   --  The tasks in the order of the reference's table.
   type Task_Id is
     (System, Main, Gyro, Filter, PID, Accel, Attitude, Rx, Serial, Dispatch, Battery_Voltage,
      Battery_Current, Battery_Alerts, Beeper, GPS, GPS_Rescue, Alt_Hold, Pos_Hold, Mag_Hold,
      Compass, Baro, Rangefinder, Optical_Flow, Pitot, Position, Dashboard, Telemetry,
      LED_Strip, Transponder, Stack_Check, OSD, BST_Master, ESC_Sensor, CMS, VTX_Control,
      Camera_Control, RC_Device, ADC_Internal, PINIO_Box, Speed_Negotiation, RC_Stats, Gimbal,
      OSD_Custom_Text, DroneCAN);

   Task_Count : constant := Task_Id'Pos (Task_Id'Last) + 1;

   --  The static priorities; the realtime tasks run outside the queue's logic.
   Realtime    : constant := -1;
   Lowest      : constant := 1;
   Low         : constant := 2;
   Medium      : constant := 3;
   Medium_High : constant := 4;
   High        : constant := 5;
   subtype Static_Priority is Integer range -1 .. 255;

   --  The platform's floor on a rescheduled period: 10 microseconds on the
   --  STM32 F4 and later, 100 on AT32 and the older STM32, 1 on the
   --  simulator.
   subtype Delay_Limit is Time_Delta range 1 .. 100;
   subtype Period_Us is Time_Delta range 1 .. Time_Delta'Last;

   type Attributes is record
      Period    : Period_Us;
      Priority  : Static_Priority;
      Has_Check : Boolean;
   end record;

   type Attribute_Table is array (Task_Id) of Attributes;

   Hz_1 : constant Period_Us := 1_000_000;
   Defaults : constant Attribute_Table :=
     (System            => (Hz_1 / 10, Medium_High, False),
      Main              => (Hz_1 / 1000, Medium_High, False),
      Gyro              => (125, Realtime, False),
      Filter            => (125, Realtime, False),
      PID               => (125, Realtime, False),
      Accel             => (Hz_1 / 1000, Medium, False),
      Attitude          => (Hz_1 / 100, Medium, False),
      Rx                => (Hz_1 / 33, High, True),
      Serial            => (Hz_1 / 100, Low, False),
      Dispatch          => (Hz_1 / 1000, High, False),
      Battery_Voltage   => (Hz_1 / 50, Medium, False),
      Battery_Current   => (Hz_1 / 50, Medium, False),
      Battery_Alerts    => (Hz_1 / 5, Medium, False),
      Beeper            => (Hz_1 / 100, Low, False),
      GPS               => (Hz_1 / 100, Medium, False),
      GPS_Rescue        => (Hz_1 / 100, Medium, False),
      Alt_Hold          => (Hz_1 / 100, Low, True),
      Pos_Hold          => (Hz_1 / 100, Low, True),
      Mag_Hold          => (Hz_1 / 100, Low, False),
      Compass           => (Hz_1 / 40, Low, False),
      Baro              => (Hz_1 / 40, Low, False),
      Rangefinder       => (Hz_1 / 10, Medium, False),
      Optical_Flow      => (Hz_1 / 10, Medium, False),
      Pitot             => (Hz_1 / 20, Low, False),
      Position          => (Hz_1 / 100, Low, False),
      Dashboard         => (Hz_1 / 10, Low, False),
      Telemetry         => (Hz_1 / 250, Low, False),
      LED_Strip         => (Hz_1 / 60, Low, False),
      Transponder       => (Hz_1 / 250, Low, False),
      Stack_Check       => (Hz_1 / 10, Lowest, False),
      OSD               => (Hz_1 / 12, Low, True),
      BST_Master        => (Hz_1 / 50, Lowest, False),
      ESC_Sensor        => (Hz_1 / 100, Low, False),
      CMS               => (Hz_1 / 20, Low, False),
      VTX_Control       => (Hz_1 / 5, Lowest, False),
      Camera_Control    => (Hz_1 / 5, Low, False),
      RC_Device         => (Hz_1 / 20, Medium, False),
      ADC_Internal      => (Hz_1, Lowest, False),
      PINIO_Box         => (Hz_1 / 20, Lowest, False),
      Speed_Negotiation => (Hz_1 / 100, Low, False),
      RC_Stats          => (Hz_1 / 100, Low, False),
      Gimbal            => (Hz_1 / 100, Medium, False),
      OSD_Custom_Text   => (Hz_1 / 100, Low, False),
      DroneCAN          => (Hz_1 / 50, Low, False));

   type Settings is record
      Cycles_Per_Us  : Positive range 1 .. 1_000 := 168;
      Rx_Relax       : Natural range 0 .. 65_535 := 25;
      OSD_Relax      : Natural range 0 .. 65_535 := 25;
      Delay_Limit_Us : Delay_Limit := 10;
      Gyro_Period_Us : Period_Us := 125;
   end record;

   subtype Dynamic_Priority is Natural range 0 .. 65_535;
   subtype Age is Natural range 0 .. 65_535;

   --  One task's scheduling state and statistics, in the reference's units:
   --  times in microseconds, moving sums in tenths over eight samples, the
   --  anticipated execution time in 128ths of a microsecond.
   type Task_State is record
      Period                : Period_Us := 1;
      Dynamic               : Dynamic_Priority := 0;
      Age_Periods           : Age := 0;
      Latest_Delta_Us       : Time_Delta := 0;
      Last_Executed_Us      : Time_Us := 0;
      Last_Signaled_Us      : Time_Us := 0;
      Last_Desired_Us       : Time_Us := 0;
      Anticipated           : Unsigned_32 := 0;
      Moving_Sum_Delta      : Unsigned_32 := 0;
      Moving_Sum_Exec       : Unsigned_32 := 0;
      Max_Exec_Us           : Unsigned_32 := 0;
      Total_Exec_Us         : Unsigned_32 := 0;
      Last_Stats_Us         : Time_Us := 0;
      Exec_Since_States     : Unsigned_32 := 0;
      Moving_Sum_States_Exec : Unsigned_32 := 0;
      Max_States_Exec_Us    : Unsigned_32 := 0;
   end record;

   type Task_States is array (Task_Id) of Task_State;

   subtype Queue_Index is Natural range 0 .. Task_Count - 1;
   subtype Queue_Count is Natural range 0 .. Task_Count;
   type Queue_Array is array (Queue_Index) of Task_Id;

   --  The check functions' statistics.
   type Check_Statistics is record
      Max_Exec_Us        : Unsigned_32 := 0;
      Total_Exec_Us      : Unsigned_32 := 0;
      Moving_Sum_Exec_Us : Unsigned_32 := 0;
      Moving_Sum_Delta_Us : Unsigned_32 := 0;
   end record;

   --  The locals of one pass that the phases share.
   type Pass_State is record
      Next_Target        : Cycles := 0;
      Now_Cycles         : Cycles := 0;
      Remaining          : Integer_32 := 0;
      Current_Time_Us    : Time_Us := 0;
      First_Opportunity  : Boolean := False;
      Selected           : Boolean := False;
      Selected_Task      : Task_Id := System;
      Selected_Dynamic   : Dynamic_Priority := 0;
      Anticipated_End    : Cycles := 0;
   end record;

   type State is record
      Tasks                 : Task_States;
      Queue                 : Queue_Array := (others => System);
      Queue_Size            : Queue_Count := 0;
      Has_Current           : Boolean := False;
      Current               : Task_Id := System;
      Ignore_Exec_Rate      : Boolean := False;
      Ignore_Exec_Time      : Boolean := False;
      Next_State_Time       : Time_Delta := -1;
      Loop_Start_Cycles     : Integer_32 := 0;
      Loop_Start_Min        : Integer_32 := 0;
      Loop_Start_Max        : Integer_32 := 0;
      Loop_Start_Down       : Unsigned_32 := 0;
      Loop_Start_Up         : Unsigned_32 := 0;
      Guard_Cycles          : Integer_32 := 0;
      Guard_Min             : Integer_32 := 0;
      Guard_Max             : Integer_32 := 0;
      Guard_Down            : Unsigned_32 := 0;
      Guard_Up              : Unsigned_32 := 0;
      Average_Load_Percent  : Natural range 0 .. 65_535 := 0;
      Gyro_Enabled          : Boolean := False;
      Desired_Period_Cycles : Integer_32 := 0;
      Last_Target_Cycles    : Cycles := 0;
      Skipped_Rx            : Natural range 0 .. 255 := 0;
      Skipped_OSD           : Natural range 0 .. 255 := 0;
      Last_Failsafe_Ms      : Time_Ms := 0;
      Total_Exec_Us         : Unsigned_32 := 0;
      Load_Last_Us          : Time_Us := 0;
      Checks                : Check_Statistics;
      Rate_Count_End        : Unsigned_32 := 0;
      Rate_Start_Cycles     : Integer_32 := 0;
      Lock_Count_End        : Unsigned_32 := 0;
      Skew_Sum              : Integer_32 := 0;
      Check_Cycles          : Unsigned_32 := 0;
      Schedule_Count        : Unsigned_32 := 0;
      Pass                  : Pass_State;
   end record;

   --  What the gyro driver reports: whether it interrupts, how many
   --  interrupts it has seen, and the cycle count of the last one.
   type Gyro_Status is record
      Interrupts    : Boolean := False;
      Detected      : Unsigned_32 := 0;
      Sync_Cycles   : Cycles := 0;
   end record;

   function Micros_To_Cycles (C : Settings; Us : Unsigned_32) return Cycles is
     (Us * Unsigned_32 (C.Cycles_Per_Us));

   --  The queue holds the system task; the cycle constants come from the
   --  clock rate and the gyro period; every task's statistics start at zero.
   procedure Init (S : out State; C : Settings; Now_Cycles : Cycles);

   procedure Enable_Gyro (S : in out State);

   procedure Set_Task_Enabled (S : in out State; Id : Task_Id; Enabled : Boolean);

   function Enabled (S : State; Id : Task_Id) return Boolean;

   procedure Reschedule (S : in out State; C : Settings; Id : Task_Id; New_Period_Us : Time_Delta);

   function Current_Task (S : State) return Task_Id
     with Pre => S.Has_Current;

   function Task_Delta_Time (S : State; Id : Task_Id) return Time_Delta is
     (S.Tasks (Id).Latest_Delta_Us);

   --  Called by the running task: a short state, a state that should not
   --  count toward the rate, or a run known to be shorter than the peak.
   procedure Ignore_Task_State_Time (S : in out State);
   procedure Ignore_Task_Exec_Rate (S : in out State);
   procedure Ignore_Task_Exec_Time (S : in out State);

   function Ignoring_Task_Exec_Time (S : State) return Boolean is (S.Ignore_Exec_Time);

   procedure Reset_Task_Statistics (S : in out State; Id : Task_Id);
   procedure Reset_Task_Max_Execution_Time (S : in out State; Id : Task_Id);
   procedure Reset_Check_Max_Execution_Time (S : in out State);

   --  One task's statistics as the reference reports them: whether it is
   --  queued, its period and static priority, its latest interval, its peak
   --  and total execution times in microseconds, its average execution time
   --  and interval in tenths of a microsecond over the eight samples, and its
   --  average and peak loads in tenths of a percent, the products wrapping at
   --  32 bits.
   type Task_Info is record
      Enabled            : Boolean;
      Period             : Period_Us;
      Priority           : Static_Priority;
      Latest_Delta_Us    : Time_Delta;
      Max_Exec_Us        : Unsigned_32;
      Total_Exec_Us      : Unsigned_32;
      Average_Exec_10th  : Unsigned_32;
      Average_Delta_10th : Unsigned_32;
      Average_Load_10th  : Unsigned_32;
      Max_Load_10th      : Unsigned_32;
   end record;

   function Info (S : State; Id : Task_Id) return Task_Info;

   --  The check functions' statistics as the reference reports them: their
   --  peak and total execution times, and their average execution time and
   --  interval over the eight samples, in microseconds.
   type Check_Info is record
      Max_Exec_Us      : Unsigned_32;
      Total_Exec_Us    : Unsigned_32;
      Average_Exec_Us  : Unsigned_32;
      Average_Delta_Us : Unsigned_32;
   end record;

   function Check_Functions (S : State) return Check_Info;

   --  The task's name in the reference's table; the system and main tasks
   --  share one.
   function Name (Id : Task_Id) return String
     with Post => Name'Result'Length in 2 .. 18;

   --  A task with a state machine names the time its next state will take.
   procedure Set_Next_State_Time (S : in out State; Next_Us : Time_Delta);

   function Next_State_Time (S : State) return Time_Delta
     with Pre => S.Has_Current;

   --  The system task's load measurement over the time since its last run.
   procedure System_Load (S : in out State; Now_Us : Time_Us);

   function Cycle_Time_Multiplier (S : State; C : Settings) return Float
     with Pre => S.Desired_Period_Cycles > 0;

   --  The pass, in the reference's order. Begin_Pass takes the first cycle
   --  reading, which the reference takes only with the gyro enabled; it then
   --  places the next gyro target, recovers from a gross overrun, tunes the
   --  start wait, and says whether the realtime tasks run now, which the
   --  caller precedes by polling the cycle counter up to the target.
   procedure Begin_Pass (S : in out State; Now_Cycles : Cycles; Poll : out Boolean);

   --  The caller runs a task between these two; Now_Us is the pass's time,
   --  Before_Us and After_Us the clock around the task's own run.
   procedure Execute_Begin (S : in out State; Id : Task_Id; Now_Us : Time_Us)
     with Post => S.Has_Current and then S.Current = Id;
   procedure Execute_End (S : in out State; Before_Us : Time_Us; After_Us : Time_Us)
     with Pre => S.Has_Current;

   --  The failsafe check runs every ten milliseconds of the realtime block.
   function Failsafe_Due (S : State; Now_Ms : Time_Ms) return Boolean;
   procedure Failsafe_Checked (S : in out State; Now_Ms : Time_Ms);

   --  After the realtime tasks: the target advances, and the scheduler locks
   --  onto the gyro's measured rate and removes the skew to its interrupts.
   procedure End_Realtime (S : in out State; Now_Cycles : Cycles; G : Gyro_Status);

   --  The second cycle reading opens the selection when the time to the
   --  target leaves room for the checks, or always without the gyro.
   procedure Begin_Selection (
      S          : in out State;
      C          : Settings;
      Now_Cycles : Cycles;
      Now_Us     : Time_Us;
      Proceed    : out Boolean
   );

   --  The queue in priority order; a task whose check function must run on
   --  this pass is one with a check, outside the realtime priority, whose
   --  dynamic priority is zero. Check_Delta is the argument of the check.
   function Queued (S : State; Q : Queue_Index) return Task_Id
     with Pre => Q < S.Queue_Size;
   function Needs_Check (S : State; Q : Queue_Index) return Boolean
     with Pre => Q < S.Queue_Size;
   function Check_Delta (S : State; Q : Queue_Index) return Time_Delta
     with Pre => Q < S.Queue_Size;

   --  One task's turn in the selection: aged, or signaled by its check
   --  function, which ran between Needs_Check and this call and ended at
   --  Check_End_Us; then held as the selection when it outranks the current
   --  one and fits, or is aged enough, or is the serial task.
   procedure Consider (
      S            : in out State;
      C            : Settings;
      Q            : Queue_Index;
      Check_Result : Boolean;
      Check_End_Us : Time_Us
   )
     with Pre => Q < S.Queue_Size;

   --  The third cycle reading times the checks; Selected says whether a task
   --  was held.
   procedure End_Selection (S : in out State; Now_Cycles : Cycles; Selected : out Boolean);

   --  The fourth cycle reading rechecks the fit; Run says whether the held
   --  task runs now, and a task that cannot run and is aged or skipped often
   --  enough gets its anticipated time cut by a tenth.
   procedure Confirm (S : in out State; C : Settings; Now_Cycles : Cycles; Run : out Boolean)
     with Pre => S.Pass.Selected;

   --  The held task's execution prologue, at the pass's time.
   procedure Run_Selected_Begin (S : in out State)
     with Pre  => S.Pass.Selected,
          Post => S.Has_Current;

   --  The fifth cycle reading after the task: the overdue margin tunes the
   --  guard, and a run receiver or display task resets its skip count.
   procedure After_Run (S : in out State; Now_Cycles : Cycles);

   procedure End_Pass (S : in out State);

end Adaflight.Scheduler;
