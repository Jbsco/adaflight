--  The arming logic: the arming flags and the reasons that block arming,
--  the throttle status and percent from the throttle channel, the arm and
--  disarm paths with their beeps, the stick combinations that arm, disarm,
--  and command the calibrations and profiles, the automatic disarm on a low
--  throttle, and the flight modes the mode boxes select.
with Interfaces;
with Adaflight.Clock;
with Adaflight.Axes;
with Adaflight.Modes;
with Adaflight.RC_Command;

package Adaflight.Arming with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Time_Us is Clock.Time_Us;

   --  In the reference's bit order, which is its order of severity: the first
   --  set reason is the one the warning beeps count out.
   type Disable_Reason is
     (No_Gyro, Failsafe_Active, Rx_Loss, Not_Disarmed, Box_Failsafe, Runaway_Disarm, Crash_Disarm,
      Throttle, Angle, Boot_Grace, No_Prearm, CPU_Load, Calibrating, CLI_Open, CMS_Open, BST_Open,
      MSP_Open, Paralyzed, No_GPS_Fix, Rescue_Switch, DShot_Telemetry, Reboot_Required,
      DShot_Bitbang, Acc_Uncalibrated, Motor_Protocol, Crash_Flip_Block, Alt_Hold_Switch,
      Pos_Hold_Switch, Autopilot_Switch, Arm_Switch);
   type Disable_Set is array (Disable_Reason) of Boolean;

   --  The reference's name of a reason, as its arming report prints it.
   function Disable_Name (R : Disable_Reason) return String is
     (case R is
        when No_Gyro => "NOGYRO", when Failsafe_Active => "FAILSAFE",
        when Rx_Loss => "RXLOSS", when Not_Disarmed => "NOT_DISARMED",
        when Box_Failsafe => "BOXFAILSAFE", when Runaway_Disarm => "RUNAWAY",
        when Crash_Disarm => "CRASH", when Throttle => "THROTTLE",
        when Angle => "ANGLE", when Boot_Grace => "BOOTGRACE",
        when No_Prearm => "NOPREARM", when CPU_Load => "LOAD",
        when Calibrating => "CALIB", when CLI_Open => "CLI",
        when CMS_Open => "CMS", when BST_Open => "BST",
        when MSP_Open => "MSP", when Paralyzed => "PARALYZE",
        when No_GPS_Fix => "GPS", when Rescue_Switch => "RESCUE_SW",
        when DShot_Telemetry => "DSHOT_TELEM",
        when Reboot_Required => "REBOOT_REQD",
        when DShot_Bitbang => "DSHOT_BBANG", when Acc_Uncalibrated => "NO_ACC_CAL",
        when Motor_Protocol => "MOTOR_PROTO", when Crash_Flip_Block => "FLIP_SWITCH",
        when Alt_Hold_Switch => "ALT_HOLD_SW", when Pos_Hold_Switch => "POS_HOLD_SW",
        when Autopilot_Switch => "AUTOPILOT_SW", when Arm_Switch => "ARM_SWITCH");

   --  In the reference's bit order.
   type Flight_Mode is
     (Angle_Mode, Horizon_Mode, Mag_Mode, Alt_Hold_Mode, Pos_Hold_Mode, Headfree_Mode, Chirp_Mode,
      Passthru_Mode, Failsafe_Mode, GPS_Rescue_Mode, Autopilot_Mode, Launch_Mode);
   type Mode_Set is array (Flight_Mode) of Boolean;

   type Disarm_Reason is
     (Arming_Disabled, Failsafe, Throttle_Timeout, Sticks, Switch, Crash_Protection, Runaway_Takeoff,
      GPS_Rescue, Serial_Command, Landing, Crash_Flip, Launch_Abort);

   type Throttle_Level is (Throttle_Low, Throttle_High);

   --  A stick is low at or below the minimum check, high at or above the
   --  maximum check, and unplaced when the checks leave no room between.
   type Stick_Position is (Unplaced, Low, High, Center);
   type Stick_Positions is array (RC_Command.Channel) of Stick_Position;

   type Beep is
     (Silence, Arm_Tone, Disarm_Tone, Armed_Tone, Disarm_Repeat_Tone, Rx_Set_Tone, Warning_Tones, Confirmation_Tones);

   subtype Small_Count is Natural range 0 .. 255;

   --  The beeper requests of one pass: their number, the last one, and the
   --  number of tones it asked for.
   type Beeps is record
      Calls : Small_Count := 0;
      Last  : Beep := Silence;
      Count : Small_Count := 0;
   end record;

   type Stick_Command is
     (Gyro_Calibration, Baro_Ground_Level, PID_Profile_1, PID_Profile_2, PID_Profile_3, Acc_Calibration,
      Mag_Calibration, Rate_Profile_1, Rate_Profile_2, Rate_Profile_3, Rate_Profile_4,
      Dashboard_Cycling_Off, Dashboard_Cycling_On);
   type Command_Set is array (Stick_Command) of Boolean;

   subtype Trim_Delta is Integer range -1 .. 1;

   --  What one pass asks of the other units.
   type Outputs is record
      Beeper                    : Beeps;
      Commands                  : Command_Set := (others => False);
      Saves                     : Small_Count := 0;
      Trim_Roll                 : Trim_Delta := 0;
      Trim_Pitch                : Trim_Delta := 0;
      Disarm_Calls              : Small_Count := 0;
      First_Arm_Gyro_Cal        : Small_Count := 0;
      Headfree_Offsets          : Small_Count := 0;
      Start_Failsafe_Monitoring : Boolean := False;
      Stabilisation_On          : Boolean := False;
      Iterm_Reset               : Boolean := True;
      Anti_Gravity              : Boolean := False;
      Iterm_Resets              : Small_Count := 0;
   end record;

   type Sensor_Set is record
      Gyro : Boolean := True;
      Acc  : Boolean := True;
      Baro : Boolean := False;
      Mag  : Boolean := False;
   end record;

   --  The arming, system, receiver, and 3D configuration the arming logic
   --  reads, the features, and the sensors detected at boot.
   type Settings is record
      Gyro_Cal_On_First_Arm      : Boolean := False;
      Auto_Disarm_Delay          : Natural range 0 .. 255 := 5;
      Prearm_Allow_Rearm         : Boolean := False;
      Boot_Grace_Time            : Natural range 0 .. 255 := 5;
      Stick_Arming               : Boolean := False;
      Mid_RC                     : Natural range 1_200 .. 1_700 := 1_500;
      Min_Check                  : Natural range 750 .. 2_250 := 1_050;
      Max_Check                  : Natural range 750 .. 2_250 := 1_900;
      Airmode_Threshold          : Natural range 0 .. 100 := 25;
      Three_D                    : Boolean := False;
      Switched_Mode_3D           : Boolean := False;
      Deadband_3D_Throttle       : Natural range 0 .. 1_000 := 50;
      Motor_Stop                 : Boolean := False;
      Airmode_Feature            : Boolean := False;
      Anti_Gravity_Feature       : Boolean := False;
      Fixed_Wing                 : Boolean := False;
      PID_At_Min_Throttle        : Boolean := True;
      Launch_Control_Angle_Limit : Natural range 0 .. 90 := 0;
      --  The launch trigger throttle in percent and whether a trigger resets
      --  with the switch; the runaway takeoff prevention with its
      --  deactivation delay in milliseconds and throttle in percent.
      Launch_Trigger_Throttle    : Natural range 0 .. 100 := 20;
      Launch_Trigger_Reset       : Boolean := True;
      Runaway_Prevention         : Boolean := True;
      Runaway_Deactivate_Delay   : Natural range 100 .. 1_000 := 500;
      Runaway_Deactivate_Throttle : Natural range 0 .. 100 := 20;
      Sensors                    : Sensor_Set;
   end record;

   --  The controller's sums, the gyro's absolute rates to the whole degree
   --  per second, and the sticks' absolute deflections, as the runaway check
   --  reads them.
   type Axis_Sums is array (Axes.Axis) of Float range -2.0 ** 32 .. 2.0 ** 32;
   type Axis_Rates_Dps is array (Axes.Axis) of Natural range 0 .. 65_535;
   type Axis_Deflections is array (Axes.Axis) of Float range 0.0 .. 1.0;

   --  What the other units report at each pass.
   type Inputs is record
      Rx_Signal                  : Boolean := False;
      Failsafe_Receiving         : Boolean := True;
      Failsafe_Active            : Boolean := False;
      Failsafe_Monitoring        : Boolean := False;
      Upright                    : Boolean := False;
      Gyro_Calibrated            : Boolean := False;
      Acc_Calibrated             : Boolean := True;
      Baro_Calibrated            : Boolean := True;
      Mag_Calibrated             : Boolean := True;
      Acc_Has_Calibration        : Boolean := True;
      First_Arm_Gyro_Cal_Running : Boolean := False;
      Motor_Protocol_Enabled     : Boolean := True;
      Headfree_Offset_Set        : Boolean := True;
      PID_Sums                   : Axis_Sums := (others => 0.0);
      Gyro_Abs_Dps               : Axis_Rates_Dps := (others => 0);
      Deflection_Abs             : Axis_Deflections := (others => 0.0);
   end record;

   type Launch_State is (Launch_Disabled, Launch_Active, Launch_Triggered);

   subtype Reason_Index is Natural range 0 .. 30;
   subtype Hold_Time is Integer range -32_768 .. 32_767;

   type State is record
      Armed                : Boolean := False;
      Was_Ever_Armed       : Boolean := False;
      Armed_With_Prearm    : Boolean := False;
      Disabled             : Disable_Set := (others => False);
      Flight_Modes         : Mode_Set := (others => False);
      Sticks_Arm           : Boolean := True;
      Disarm_Requested     : Boolean := False;
      Disarm_At            : Time_Us := 0;
      Last_Disabled_Reason : Reason_Index := 0;
      Last_Disarm_Us       : Time_Us := 0;
      Last_Disarm_Reason   : Disarm_Reason := Arming_Disabled;
      Throttle_Raised      : Boolean := False;
      Airmode_Active       : Boolean := False;
      Had_Rx               : Boolean := False;
      Armed_Beeper_On      : Boolean := False;
      Hold_Ms              : Hold_Time := 0;
      Sticks               : Stick_Positions := (others => Unplaced);
      Disarm_Ticks         : Small_Count := 0;
      Do_Not_Repeat        : Boolean := False;
      Pending_Trim_Save    : Boolean := False;
      Launch               : Launch_State := Launch_Disabled;
      Runaway_Check_Disabled : Boolean := False;
      Runaway_Deactivate_Us  : Time_Us := 0;
      Runaway_Accumulated_Us : Time_Us := 0;
      Runaway_Trigger_Us     : Time_Us := 0;
      Mode_Overrides         : Modes.Mask := (others => False);
   end record;

   function Launch_Control_Active (S : State) return Boolean is (S.Launch = Launch_Active);

   function Arming_Disabled (S : State) return Boolean is
     (for some R in Disable_Reason => S.Disabled (R));

   --  Boot: the grace time blocks arming, and the sticks arm when no arm
   --  box is configured and stick arming is enabled.
   procedure Init (S : out State; C : Settings; Conds : Modes.Conditions)
     with Post => not S.Armed and then S.Disabled (Boot_Grace);

   function Throttle_Status (C : Settings; Channels : RC_Command.Channel_Values; Three_D_Switch : Boolean)
                             return Throttle_Level;

   --  The throttle above the minimum check in percent, negative for the
   --  reversed thrust of a 3D switch.
   function Throttle_Percent (C : Settings; Channels : RC_Command.Channel_Values; Three_D_Switch : Boolean)
                              return Integer
     with Post => Throttle_Percent'Result in -100 .. 100;

   --  The arming disabled reasons while disarmed; nothing while armed.
   procedure Update_Status (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Conds    : Modes.Conditions;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us
   );

   --  A box a ground station forces on over the switches, or releases; every
   --  disarm releases them all.
   procedure Set_Mode_Override (S : in out State; B : Modes.Box; Enabled : Boolean)
     with Post => S.Armed = S.Armed'Old;

   procedure Clear_Mode_Overrides (S : in out State)
     with Post => S.Armed = S.Armed'Old;

   procedure Disarm (S : in out State; Reason : Disarm_Reason; Now_Us : Time_Us; Out_Step : in out Outputs)
     with Post => not S.Armed;

   procedure Try_Arm (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Conds    : Modes.Conditions;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   );

   --  The controller pass: the runaway takeoff detection on the controller's
   --  sums and the gyro's rates while armed, which disarms after its delay.
   procedure Process_PID_Loop (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   );

   --  The receiver pass: the 3D switch disarm, the failsafe monitoring start,
   --  the raised throttle and airmode latches, the stabilisation state, the
   --  runaway check's deactivation in stable flight, and the launch trigger.
   procedure Process_Rx (
      S        : in out State;
      C        : Settings;
      M        : Modes.State;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Out_Step : in out Outputs
   );

   --  The modes pass: the automatic disarm, the stick positions, the mode
   --  update, and the flight mode selection, in the reference's order.
   procedure Process_Rx_Modes (
      S        : in out State;
      C        : Settings;
      M        : in out Modes.State;
      Conds    : Modes.Conditions;
      Aux      : Modes.Aux_Values;
      Sensed   : Inputs;
      Channels : RC_Command.Channel_Values;
      Now_Us   : Time_Us;
      Delta_Us : Natural;
      Out_Step : in out Outputs
   );

end Adaflight.Arming;
