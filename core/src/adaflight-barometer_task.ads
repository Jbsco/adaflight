--  The barometer's read cycle. The device converts the temperature and then
--  the pressure, each started, read and sampled in a call of its own, and
--  the pressure sample yields the altitude. A device that reads both at
--  once starts over from the pressure. A start sleeps for the device's
--  conversion delay, and a cycle restart waits out the rest of the 40 Hz
--  period. A call while the bus is busy, or a read the device has not
--  finished, leaves the phase as it was. The task keeps the longest
--  execution of each phase and names the next phase's to the scheduler.
with Interfaces;
with Adaflight.Barometer;

package Adaflight.Barometer_Task with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Barometer.State;

   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Phase is
     (Temperature_Read, Temperature_Sample, Pressure_Start, Pressure_Read, Pressure_Sample, Temperature_Start);

   type Device_Call is
     (Start_Temperature, Read_Temperature, Get_Temperature, Start_Pressure, Read_Pressure, Get_Pressure);

   Call_Of : constant array (Phase) of Device_Call :=
     (Temperature_Read   => Read_Temperature,
      Temperature_Sample => Get_Temperature,
      Pressure_Start     => Start_Pressure,
      Pressure_Read      => Read_Pressure,
      Pressure_Sample    => Get_Pressure,
      Temperature_Start  => Start_Temperature);

   type Device is record
      Combined_Read        : Boolean := False;
      Temperature_Delay_Us : Unsigned_16 := 0;
      Pressure_Delay_Us    : Unsigned_16 := 0;
   end record;

   Cycle_Period_Us : constant := 1_000_000 / 40;
   Default_Sleep_Us : constant := 1_000;

   type Durations is array (Phase) of Unsigned_32;

   --  What the debug values read of the steps: whether one ran, and the
   --  phase it entered with, as the reference logs before its bus check.
   type Debug_Taps is record
      Stepped     : Boolean := False;
      Entry_Phase : Phase := Pressure_Start;
   end record;

   type State is record
      Current        : Phase := Pressure_Start;
      Cycle_Start_Us : Unsigned_32 := 0;
      Duration       : Durations := (others => 0);
      Taps           : Debug_Taps;
   end record;

   --  The device call this phase makes when the bus is free.
   function Call (T : State) return Device_Call is (Call_Of (T.Current));

   --  Whether a finished device call in this phase hands over a pressure and
   --  a temperature, which the caller computes from the device before Step.
   function Takes_Sample (T : State; Done : Boolean) return Boolean is
     (T.Current = Pressure_Sample and then Done);

   type Report is record
      Ran               : Phase := Pressure_Start;
      Sleep_Us          : Unsigned_32 := Default_Sleep_Us;
      Ignore_State_Time : Boolean := False;
      Ignore_Exec_Time  : Boolean := False;
      Ignore_Exec_Rate  : Boolean := False;
   end record;

   --  One call of the task. Done is the answer of the device call this
   --  phase made; a start's answer counts for nothing. Pressure and
   --  Temperature count only when the call takes a sample. Sleep_Us is the
   --  time to the next call. A busy bus ignores the call's state time and
   --  skips Finish.
   procedure Step
     (T           : in out State;
      B           : in out Barometer.State;
      C           : Barometer.Settings;
      D           : Device;
      Now_Us      : Unsigned_32;
      Bus_Busy    : Boolean;
      Done        : Boolean;
      Pressure    : Integer_32;
      Temperature : Barometer.Temperature_Centi;
      R           : out Report)
     with Global => null,
          Post   => R.Ran = T.Current'Old
                    and then R.Ignore_State_Time = Bus_Busy
                    and then (if Bus_Busy then T.Current = T.Current'Old
                                            and then T.Cycle_Start_Us = T.Cycle_Start_Us'Old
                                            and then T.Duration = T.Duration'Old and then B = B'Old
                                            and then not R.Ignore_Exec_Rate)
                    and then (if not Bus_Busy then R.Ignore_Exec_Rate = (T.Current /= Pressure_Start));

   --  After a call the bus let through: the phase that ran keeps its longest
   --  execution, and Next_State_Us is the next phase's as a time delta.
   procedure Finish (T : in out State; Ran : Phase; Elapsed_Us : Unsigned_32; Next_State_Us : out Integer_32)
     with Global => null,
          Post   => T.Current = T.Current'Old and then T.Cycle_Start_Us = T.Cycle_Start_Us'Old
                    and then T.Duration (Ran) = Unsigned_32'Max (T.Duration'Old (Ran), Elapsed_Us);

end Adaflight.Barometer_Task;
