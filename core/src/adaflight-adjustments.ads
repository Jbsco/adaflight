--  In-flight adjustments: the auxiliary channel ranges that step a rate or a
--  gain while a switch is held, set it from a dial through a center and a
--  scale, or select a profile or a peripheral mode by a switch position,
--  with the half-second pacing of the steps, the value the on-screen display
--  names for two seconds, the confirmation beeps, and the reinitializations
--  a changed setting asks for.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Modes;
with Adaflight.Rates;
with Adaflight.PID_Profile;

package Adaflight.Adjustments with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Ms is Unsigned_32;

   --  The functions in the order of their protocol identifiers.
   type Function_Kind is
     (None, RC_Rate, RC_Expo, Throttle_Expo, Pitch_Roll_Rate, Yaw_Rate, Pitch_Roll_P,
      Pitch_Roll_I, Pitch_Roll_D, Yaw_P, Yaw_I, Yaw_D, Rate_Profile, Pitch_Rate, Roll_Rate,
      Pitch_P, Pitch_I, Pitch_D, Roll_P, Roll_I, Roll_D, RC_Rate_Yaw, Pitch_Roll_F,
      Feedforward_Transition, Horizon_Strength, PID_Audio, Pitch_F, Roll_F, Yaw_F,
      OSD_Profile, LED_Profile, LED_Dimmer, Master_Multiplier, Battery_Profile);

   --  The functions a switch position selects; every other function steps.
   subtype Select_Kind is Function_Kind
     with Static_Predicate => Select_Kind in Rate_Profile | Horizon_Strength | PID_Audio
       | OSD_Profile | LED_Profile | LED_Dimmer | Master_Multiplier | Battery_Profile;

   subtype Position_Count is Positive range 1 .. 255;

   function Positions (K : Select_Kind) return Position_Count is
     (case K is
         when Rate_Profile | OSD_Profile | LED_Profile | Battery_Profile => 3,
         when Horizon_Strength => 255,
         when PID_Audio => 7,
         when LED_Dimmer | Master_Multiplier => 100);

   Max_Ranges : constant := 30;
   subtype Range_Index is Natural range 0 .. Max_Ranges - 1;
   subtype Range_Count is Natural range 0 .. Max_Ranges;
   subtype Dial_Setting is Natural range 0 .. 65_535;

   --  While the auxiliary channel is in its span, the function applies to the
   --  switch channel: stepping when the center is zero, set from the dial
   --  through the scale and the center otherwise, or selecting by position.
   type Adjustment_Range is record
      Aux        : Modes.Aux_Channel := 0;
      Span       : Modes.Channel_Range;
      Kind       : Function_Kind := None;
      Switch_Aux : Modes.Aux_Channel := 0;
      Center     : Dial_Setting := 0;
      Scale      : Dial_Setting := 0;
   end record;

   Unset : constant Adjustment_Range :=
     (Aux => 0, Span => (Start_Step => 0, End_Step => 0), Kind => None, Switch_Aux => 0,
      Center => 0, Scale => 0);

   type Ranges is array (Range_Index) of Adjustment_Range;

   type Settings is record
      Mid_RC                  : Natural range 1200 .. 1700 := 1500;
      Rate_Profile_6_Position : Boolean := False;
   end record;

   Rate_Profile_Count : constant := 4;
   subtype Rate_Profile_Index is Natural range 0 .. Rate_Profile_Count - 1;
   type Rate_Profiles is array (Rate_Profile_Index) of Rates.Profile;

   Battery_Profile_Count : constant := 3;
   subtype Battery_Profile_Index is Natural range 0 .. Battery_Profile_Count - 1;

   --  In the order of their protocol identifiers.
   type Audio_Mode is (Off, PID_Sum_X, PID_Sum_Y, PID_Sum_XY);
   subtype LED_Profile_Index is Natural range 0 .. 2;
   subtype LED_Level is Natural range 0 .. 255;

   --  The selections the profiles and the peripherals read.
   type Selections is record
      Rate_Profile    : Rate_Profile_Index := 0;
      Battery_Profile : Battery_Profile_Index := 0;
      Audio           : Audio_Mode := Off;
      LED_Profile     : LED_Profile_Index := 0;
      LED_Brightness  : LED_Level := 100;
   end record;

   subtype Shown_Value is Integer range -1 .. 65_535;

   --  The adjustment the on-screen display names for two seconds after a
   --  change; None once the two seconds have passed.
   type Display is record
      Kind       : Function_Kind := None;
      Value      : Shown_Value := -1;
      Changed_Ms : Time_Ms := 0;
   end record;

   type Step_State is record
      Index      : Range_Index := 0;
      Timeout_Ms : Time_Ms := 0;
      Ready      : Boolean := False;
   end record;

   type Dial_State is record
      Index    : Range_Index := 0;
      Last_Aux : Signal := 0.0;
   end record;

   type Step_States is array (Range_Index) of Step_State;
   type Dial_States is array (Range_Index) of Dial_State;

   subtype Position is Natural range 0 .. 254;

   type State is record
      Listed          : Boolean := False;
      Step_Count      : Range_Count := 0;
      Steps           : Step_States := (others => <>);
      Dial_Count      : Range_Count := 0;
      Dials           : Dial_States := (others => <>);
      Base_Set        : Boolean := False;
      Center_Position : Position := 0;
      Base_Multiplier : PID_Profile.Tuning_Factor := 100;
      Selected        : Selections;
      Shown           : Display;
      Config_Dirty    : Boolean := False;
   end record
     with Dynamic_Predicate => State.Step_Count + State.Dial_Count <= Max_Ranges;

   type Inputs is record
      Now_Ms    : Time_Ms := 0;
      Rx_Signal : Boolean := False;
      Aux       : Modes.Aux_Values := (others => 0.0);
   end record;

   subtype Beep_Count is Natural range 0 .. 255;

   --  The effects of one pass: the confirmation beeps requested and the last
   --  count, and the reinitializations the changed settings ask for.
   type Outputs is record
      Beep_Requests  : Range_Count := 0;
      Beeps          : Beep_Count := 0;
      PID_Reinit     : Boolean := False;
      RC_Reinit      : Boolean := False;
      Battery_Reinit : Boolean := False;
   end record;

   --  The ranges changed; the step and dial lists rebuild on the next pass.
   procedure Reset_List (S : in out State)
     with Post => not S.Listed;

   --  One pass of the adjustments task: the stepping functions whose range
   --  is active, then, while the receiver has a signal, the dials and the
   --  selections, over the rate profile active at the start of the pass.
   procedure Process (
      S      : in out State;
      C      : Settings;
      R      : Ranges;
      Rate   : in out Rate_Profiles;
      P      : in out PID_Profile.Profile;
      Inp    : Inputs;
      Result : out Outputs
   );

end Adaflight.Adjustments;
