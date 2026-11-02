--  The failsafe state machine: the receiver link state from the frame
--  events, the stages after a link loss or a failsafe switch, the landing,
--  drop and GPS rescue procedures, the autopilot's own stage on a mission,
--  the monitoring period before a recovery, and the flags the arming logic
--  and the flight modes read.
with Interfaces;

package Adaflight.Failsafe with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Ms is Unsigned_32;

   type Switch_Mode is (Stage_1, Kill, Stage_2);
   type Procedure_Kind is (Auto_Landing, Drop, GPS_Rescue);
   --  What the autopilot does on a link loss during a mission: nothing of
   --  its own, the mission continued, or a landing.
   type Loss_Policy is (Disable, Continue, Land);

   --  Delays in tenths of a second, the landing time in seconds.
   type Settings is record
      Throttle_Low_Delay : Natural range 0 .. 300 := 100;
      Signal_Delay       : Positive range 1 .. 200 := 15;
      Landing_Time       : Natural range 0 .. 250 := 60;
      Switch             : Switch_Mode := Stage_1;
      Action             : Procedure_Kind := Drop;
      Recovery_Delay     : Positive range 1 .. 200 := 5;
      Policy             : Loss_Policy := Disable;
   end record;

   type Phase is
     (Idle, Rx_Loss_Detected, Landing, Landed, Rx_Loss_Monitoring, Rx_Loss_Recovered, GPS_Rescue, Autopilot);
   type Link is (Down, Up);
   type Beep is (Silence, Rx_Lost, Rx_Lost_Landing);

   type Inputs is record
      Armed               : Boolean := False;
      Switch_On           : Boolean := False;
      Throttle_Low        : Boolean := False;
      Configurator_Active : Boolean := False;
      Crash_Recovery      : Boolean := False;
      --  The autopilot flight mode, whether the executor flies a plan,
      --  whether that plan ended, whether a rescue plan can be staged now,
      --  and whether the sticks moved past the failsafe's threshold.
      Autopilot_Mode       : Boolean := False;
      Nav_Active           : Boolean := False;
      Nav_Ended            : Boolean := False;
      Rescue_Plan_Possible : Boolean := False;
      Sticks_Active        : Boolean := False;
   end record;

   subtype Event_Count is Natural range 0 .. 32_767;

   --  What a monitored pass wrote where upstream records a debug value: that
   --  it ran, and whether the receiver delivered data at its entry.
   type Debug_Taps is record
      Updated            : Boolean := False;
      Receiving_At_Entry : Boolean := False;
   end record;

   type State is record
      Events                          : Event_Count := 0;
      Monitoring                      : Boolean := False;
      Active                          : Boolean := False;
      Rx_Data_Failure_Period          : Time_Ms := 0;
      Rx_Data_Recovery_Period         : Time_Ms := 0;
      Valid_Rx_Data_Received_At       : Time_Ms := 0;
      Valid_Rx_Data_Failed_At         : Time_Ms := 0;
      Throttle_Low_Period             : Time_Ms := 0;
      Landing_Should_Be_Finished_At   : Time_Ms := 0;
      Receiving_Rx_Data_Period        : Time_Ms := 0;
      Receiving_Rx_Data_Period_Preset : Time_Ms := 0;
      Current                         : Phase := Idle;
      Rx_Link                         : Link := Down;
      Switch_Was_On                   : Boolean := False;
      Failsafe_Mode                   : Boolean := False;
      Arming_Disabled_Rx              : Boolean := False;
      Arming_Disabled                 : Boolean := False;
      Autopilot_Engage_Deadline       : Time_Ms := 0;
      Taps                            : Debug_Taps;
   end record;

   procedure Init (S : out State; C : Settings);

   procedure Reset (S : in out State; C : Settings)
     with Post => S.Current = Idle and then S.Rx_Link = Down and then not S.Switch_Was_On
                  and then S.Events = S.Events'Old and then S.Monitoring = S.Monitoring'Old;

   procedure Start_Monitoring (S : in out State)
     with Post => S.Monitoring;

   function Receiving_Rx_Data (S : State) return Boolean is (S.Rx_Link = Up);

   procedure On_Valid_Data_Received (S : in out State; Now : Time_Ms);
   procedure On_Valid_Data_Failed (S : in out State; Now : Time_Ms);
   procedure Check_Data_Failure_Period (S : in out State; Now : Time_Ms);
   procedure On_Rx_Suspend (S : in out State; Suspend_Period_Us : Unsigned_32);
   procedure On_Rx_Resume (S : in out State; Now : Time_Ms);

   --  One pass of the state machine. Disarm is set when the landed stage asks
   --  the arming logic to disarm; Beeper is the tone the pass selects;
   --  Stage_Rescue asks the caller to stage the executor's rescue plan as
   --  the GPS rescue starts, which the autopilot stage then waits for within
   --  its grace period.
   procedure Update (
      S            : in out State;
      C            : Settings;
      Now          : Time_Ms;
      In_Flight    : Inputs;
      Beeper       : out Beep;
      Disarm       : out Boolean;
      Stage_Rescue : out Boolean
   ) with Post => (if not S'Old.Monitoring
                   then S = S'Old and then Beeper = Silence and then not Disarm and then not Stage_Rescue)
                  and then S.Monitoring = S'Old.Monitoring;

end Adaflight.Failsafe;
