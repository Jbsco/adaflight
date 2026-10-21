--  The stick command path: deadbands, the throttle curve with the low voltage
--  cutoff and the 3D throttle from the receiver channels, the deflections and
--  rates into raw setpoints, feedforward from the setpoint motion, and the
--  smoothing filters whose cutoffs follow the receiver frame rate, in the
--  operation order of the reference.

with Interfaces;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.Rates;
with Adaflight.PID_Config; use Adaflight.PID_Config;

package Adaflight.RC_Command with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Throttle_Points : constant := 12;
   subtype Table_Index is Natural range 0 .. Throttle_Points - 1;
   subtype Pulse is Natural range 1000 .. 2000;
   type Throttle_Table is array (Table_Index) of Pulse;

   subtype Channel is Natural range 0 .. 3;
   Throttle_Channel : constant Channel := 3;
   subtype Channel_Value is Float range 750.0 .. 2250.0;
   type Channel_Values is array (Channel) of Channel_Value;

   type Receiver_Settings is record
      Mid_RC               : Natural range 1200 .. 1700 := 1500;
      Min_Check            : Natural range 750 .. 1999 := 1050;
      Smoothing            : Boolean := True;
      Auto_Factor_Setpoint : Natural range 0 .. 250 := 30;
      Auto_Factor_Throttle : Natural range 0 .. 250 := 30;
      Setpoint_Cutoff      : Natural range 0 .. 255 := 0;
      Throttle_Cutoff      : Natural range 0 .. 255 := 0;
   end record;

   type Control_Settings is record
      Deadband     : Natural range 0 .. 32 := 0;
      Yaw_Deadband : Natural range 0 .. 100 := 0;
      Yaw_Reversed : Boolean := False;
   end record;

   type Config is record
      Rates        : Adaflight.Rates.Profile;
      Receiver     : Receiver_Settings;
      Controls     : Control_Settings;
      Loop_Time    : PID_Config.Loop_Time_Us := 125;
      --  The 3D feature, and its switched mode, where the 3D switch reverses
      --  the motors instead of mapping the stick around the middle.
      Feature_3D       : Boolean := False;
      Switched_Mode_3D : Boolean := False;
   end record;

   --  What the throttle reads from the other units: the 3D switch, failsafe,
   --  and the battery's low voltage cutoff with its throttle percentage.
   type Command_Inputs is record
      Box_3D          : Boolean := False;
      Failsafe_Active : Boolean := False;
      LVC_Enabled     : Boolean := False;
      LVC_Percentage  : Natural range 0 .. 100 := 100;
   end record;

   subtype Divider is Float range 400.0 .. 500.0;
   subtype Interval_Us is Natural range 800 .. 65_500;
   subtype Rate_Hz is Float range 15.0 .. 1250.0;
   subtype Cutoff_Hz is Natural range 0 .. 65_535;
   subtype Averaging_Count is Natural range 0 .. 3;

   type Command_Values is array (Channel) of Float range -500.0 .. 2000.0;
   type Axis_Values is array (Axis) of Signal;
   type Axis_Deflections is array (Axis) of Float range -1.0 .. 1.0;
   type Axis_Magnitudes is array (Axis) of Float range 0.0 .. 1.0;
   type Axis_PT1 is array (Axis) of Filters.PT1;
   type Axis_PT3 is array (Axis) of Filters.PT3;
   type Channel_PT3 is array (Channel) of Filters.PT3;
   type Level_PT3 is array (Axis range Roll .. Pitch) of Filters.PT3;
   type Axis_Averages is array (Axis) of Moving_Average;
   type Axis_Flags is array (Axis) of Boolean;
   type Axis_Intervals is array (Axis) of Float range 0.0 .. 0.1;

   type State is record
      Table                 : Throttle_Table := (others => 1000);
      Command_Divider       : Divider := 500.0;
      Yaw_Divider           : Divider := 500.0;
      Max_Rate              : Axis_Values := (others => 0.0);
      Auto_Setpoint_Factor  : Float range 0.0 .. 1.5 := 1.5;
      Auto_Throttle_Factor  : Float range 0.0 .. 1.5 := 1.5;
      Setpoint_Cutoff_Hz    : Cutoff_Hz := 0;
      Throttle_Cutoff_Hz    : Cutoff_Hz := 0;
      Setpoint_Filters      : Channel_PT3;
      Deflection_Filters    : Level_PT3;
      Feedforward_Filters   : Axis_PT3;
      Speed_Filters         : Axis_PT1;
      Delta_Filters         : Axis_PT1;
      Yaw_Hold_Filter       : Filters.PT1;
      Averaging             : Averaging_Count := 0;
      Averages              : Axis_Averages;
      Prev_Command          : Axis_Values := (others => 0.0);
      Prev_Delta_Abs        : Axis_Values := (others => 0.0);
      Prev_Setpoint         : Axis_Values := (others => 0.0);
      Prev_Speed            : Axis_Values := (others => 0.0);
      Prev_Speed_Delta      : Axis_Values := (others => 0.0);
      Prev_Duplicate        : Axis_Flags := (others => False);
      Prev_Interval         : Axis_Intervals := (others => 0.0);
      Command               : Command_Values := (others => 0.0);
      Raw_Setpoint          : Axis_Values := (others => 0.0);
      Setpoint_Rate         : Axis_Values := (others => 0.0);
      Deflection            : Axis_Deflections := (others => 0.0);
      Deflection_Abs        : Axis_Magnitudes := (others => 0.0);
      Deflection_Smoothed   : Axis_Values := (others => 0.0);
      Max_Deflection_Abs    : Float range 0.0 .. 1.0 := 0.0;
      Feedforward_Raw       : Axis_Values := (others => 0.0);
      Feedforward_Smoothed  : Axis_Values := (others => 0.0);
      To_Smooth             : Axis_Values := (others => 0.0);
      Throttle_To_Smooth    : Float range -500.0 .. 2000.0 := 0.0;
      Last_Rx_Time_Us       : Unsigned_32 := 0;
      Current_Interval_Us   : Interval_Us := 800;
      Previous_Interval_Us  : Interval_Us := 800;
      Current_Rate_Hz       : Rate_Hz := 1250.0;
      Smoothed_Rate_Hz      : Rate_Hz := 100.0;
      Rate_Valid            : Boolean := False;
      Data_New              : Boolean := False;
      Valid_Count           : Natural range 0 .. 3 := 0;
      Outlier_Count         : Natural range 0 .. 3 := 0;
      Prev_Outlier_Negative : Boolean := False;
      --  The switched 3D mode's motor reversal.
      Motors_Reversed       : Boolean := False;
   end record;

   --  Prepares the throttle table, the dividers, the rate maxima, and the
   --  filters from the settings and runtime constants.
   procedure Init (S : out State; C : Config; R : Runtime);

   --  Tracks the receiver frame interval and rate from the frame times.
   procedure Update_Refresh_Rate
     (S : in out State; Time_Us : Unsigned_32; Receiving : Boolean; Frame_Time_Us : Unsigned_32);

   --  Commands from the channels: deadbands on the sticks, the curve on the throttle.
   procedure Update_Commands (S : in out State; C : Config; Data : Channel_Values; Inp : Command_Inputs);

   --  Deflections, raw setpoints, feedforward, and the smoothing filters; runs
   --  every loop and does the receiver-side work when the data is new.
   procedure Process (S : in out State; C : Config; R : Runtime);

   function Setpoint_Rate (S : State; C : Config; A : Axis) return Signal is
     (if C.Receiver.Smoothing then S.Setpoint_Rate (A) else S.Raw_Setpoint (A));

   function Feedforward (S : State; C : Config; A : Axis) return Signal is
     (if C.Receiver.Smoothing then S.Feedforward_Smoothed (A) else S.Feedforward_Raw (A));

end Adaflight.RC_Command;
