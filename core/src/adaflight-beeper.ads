--  The beeper: the requests by mode against the priority of the sound
--  playing, the sequences of on and off durations the periodic update plays,
--  the multi-beep buffer the confirmation, warning, and satellite count beeps
--  fill, the mute switch and the bench suppression, the time of the arming
--  beep, and the DShot beacon requested while the link is lost or the beep
--  switch is on with the motors stopped.
with Interfaces;

package Adaflight.Beeper with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;

   --  The modes in the order of their protocol identifiers.
   type Mode is
     (Silence, Gyro_Calibrated, Rx_Lost, Rx_Lost_Landing, Disarming, Arming, Arming_GPS_Fix,
      Battery_Critical_Low, Battery_Low, GPS_Status, Rx_Set, Acc_Calibration,
      Acc_Calibration_Fail, Ready, Multi_Beeps, Disarm_Repeat, Armed, System_Init, USB,
      Blackbox_Erase, Crash_Flip, Camera_Open, Camera_Close, Arming_GPS_No_Fix, All_Sounds);

   subtype Sound is Mode range Gyro_Calibrated .. All_Sounds;
   subtype Beep_Count is Natural range 0 .. 255;
   type Mode_Flags is array (Sound) of Boolean;

   type Settings is record
      Off_Flags        : Mode_Flags := (others => False);
      Beacon_Off_Flags : Mode_Flags := (Rx_Lost | Rx_Set => True, others => False);
      Beacon_Tone      : Natural range 1 .. 5 := 1;
   end record;

   --  What the beeper reads from the other units: the battery's presence,
   --  the bench links, the three beeper boxes, the GPS, the motors, the
   --  failsafe, and the arming state.
   type Conditions is record
      Battery_Present     : Boolean := True;
      USB_Active          : Boolean := False;
      Configurator_Active : Boolean := False;
      Mute_Switch         : Boolean := False;
      Beep_Switch         : Boolean := False;
      Satellite_Switch    : Boolean := False;
      GPS_Feature         : Boolean := False;
      GPS_Fix             : Boolean := False;
      Satellites          : Natural range 0 .. 255 := 0;
      Motors_Running      : Boolean := False;
      Failsafe_Monitoring : Boolean := False;
      Failsafe_Receiving  : Boolean := True;
      Last_Disarm_Us      : Time_Us := 0;
      Trying_To_Arm       : Boolean := False;
   end record;

   --  A sequence alternates on and off durations in tens of milliseconds,
   --  a leading zero starts with a pause, and ends with Stop or Repeat.
   Stop      : constant := 255;
   Repeat    : constant := 254;
   subtype Step is Natural range 0 .. 255;
   Max_Multi : constant := 32;
   Max_Steps : constant := 2 * Max_Multi + 1;
   subtype Step_Index is Natural range 0 .. Max_Steps - 1;
   type Sequence is array (Step_Index) of Step with Component_Size => 8;

   --  The sounds in priority order, the first the highest.
   Table_Size : constant := 24;
   subtype Table_Index is Natural range 0 .. Table_Size - 1;
   type Sound_Table is array (Table_Index) of Sound;
   Table : constant Sound_Table :=
     (Gyro_Calibrated, Rx_Lost, Rx_Lost_Landing, Disarming, Arming, Arming_GPS_Fix,
      Arming_GPS_No_Fix, Battery_Critical_Low, Battery_Low, GPS_Status, Rx_Set, Acc_Calibration,
      Acc_Calibration_Fail, Ready, Multi_Beeps, Disarm_Repeat, Armed, System_Init, USB,
      Blackbox_Erase, Crash_Flip, Camera_Open, Camera_Close, All_Sounds);

   type State is record
      Is_On          : Boolean := False;
      Pos            : Step_Index := 0;
      Next_Toggle_Us : Time_Us := 0;
      Arming_Beep_Us : Time_Us := 0;
      Current        : Mode := Silence;
      Multi          : Sequence := (others => 0);
      Warning_Led    : Boolean := False;
      Visual_Was_On  : Boolean := False;
      Last_Beacon_Us : Time_Us := 0;
   end record;

   --  The effects of one update: a DShot beacon command, the on-screen
   --  display's visual beep set, and the scheduler told the update was short.
   type Update_Outputs is record
      Beacon_Command   : Boolean := False;
      Visual_Beep      : Boolean := False;
      Ignore_Exec_Time : Boolean := False;
   end record;

   --  A request starts the mode's sound when it outranks the one playing;
   --  Silence, the mute switch, and the bench suppression silence the beeper.
   procedure Request (S : in out State; C : Settings; Cond : Conditions; M : Mode);

   procedure Silence_Beeper (S : in out State)
     with Post => S.Current = Silence and then not S.Is_On;

   --  Count short beeps 200 milliseconds apart.
   procedure Confirmation_Beeps (S : in out State; C : Settings; Cond : Conditions; Count : Beep_Count);

   --  Four flashes, a long beep per five of the count, and a short beep per
   --  remaining one.
   procedure Warning_Beeps (S : in out State; C : Settings; Cond : Conditions; Count : Beep_Count);

   --  The periodic update: the beep and satellite switches, the beacon, and
   --  the next step of the playing sequence when its time has come.
   procedure Update (S : in out State; C : Settings; Cond : Conditions; Now_Us : Time_Us; Result : out Update_Outputs);

   function Arming_Beep_Time (S : State) return Time_Us is (S.Arming_Beep_Us);

   function Is_On (S : State) return Boolean is (S.Is_On);

end Adaflight.Beeper;
