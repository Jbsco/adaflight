--  Runtime modes: the activation conditions that map auxiliary channel ranges
--  onto the mode boxes, with the any-of and all-of logic per box, conditions
--  linked to another box, the sticky boxes that latch, and the airmode
--  decision the mixer and the rate loop read.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.Modes with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The boxes in the order of their protocol identifiers.
   type Box is
     (Arm, Angle, Horizon, Mag, Alt_Hold, Headfree, Chirp, Passthru, Failsafe, Pos_Hold,
      GPS_Rescue, Autopilot, Anti_Gravity, Head_Adj, Cam_Stab, Beeper_On, LED_Low, Calib,
      OSD, Telemetry, Servo_1, Servo_2, Servo_3, Blackbox, Airmode, Three_D, FPV_Angle_Mix,
      Blackbox_Erase, Camera_1, Camera_2, Camera_3, Crash_Flip, Prearm, Beep_GPS_Count,
      VTX_Pit_Mode, Paralyze, User_1, User_2, User_3, User_4, PID_Audio, Acro_Trainer,
      VTX_Control_Disable, Launch_Control, MSP_Override, Stick_Command_Disable, Beeper_Mute,
      Ready, Lap_Timer_Reset, WP_Capture, Launch);

   type Logic is (Any_Range, All_Ranges);

   Aux_Channel_Count : constant := 14;
   subtype Aux_Channel is Natural range 0 .. Aux_Channel_Count - 1;

   --  Range steps of 25 microseconds from 900 to 2100.
   Max_Range_Step : constant := 48;
   subtype Range_Step is Natural range 0 .. Max_Range_Step;

   type Channel_Range is record
      Start_Step : Range_Step := 0;
      End_Step   : Range_Step := 0;
   end record;

   function Usable (R : Channel_Range) return Boolean is (R.Start_Step < R.End_Step);

   --  Linked_To names the box whose activation this condition follows; Arm
   --  means the condition reads its own range.
   type Condition is record
      Mode      : Box := Arm;
      Aux       : Aux_Channel := 0;
      Span      : Channel_Range;
      Combine   : Logic := Any_Range;
      Linked_To : Box := Arm;
   end record;

   Empty : constant Condition := (Mode => Arm, Aux => 0, Span => (0, 0), Combine => Any_Range, Linked_To => Arm);

   Max_Conditions : constant := 20;
   subtype Condition_Index is Natural range 0 .. Max_Conditions - 1;
   type Conditions is array (Condition_Index) of Condition;

   type Mask is array (Box) of Boolean;
   type Aux_Values is array (Aux_Channel) of Signal;

   subtype List_Count is Natural range 0 .. Max_Conditions;
   type Index_List is array (Condition_Index) of Condition_Index;

   type State is record
      Active_Mask          : Mask := (others => False);
      Sticky_Ever_Disabled : Mask := (others => False);
      Airmode_Enabled      : Boolean := False;
      Active_Count         : List_Count := 0;
      Active               : Index_List := (others => 0);
      Linked_Count         : List_Count := 0;
      Linked               : Index_List := (others => 0);
   end record
     with Dynamic_Predicate => State.Active_Count + State.Linked_Count <= Max_Conditions;

   function Is_Active (S : State; B : Box) return Boolean is (S.Active_Mask (B));

   --  The channel value lies in the range; a range whose start is not below
   --  its end never activates.
   function Range_Active (Aux : Aux_Values; Channel : Aux_Channel; Span : Channel_Range) return Boolean
     with Post => (if not Usable (Span) then not Range_Active'Result);

   --  Sorts the configured conditions into the own-range list and the linked
   --  list, in configuration order.
   procedure Analyze (S : in out State; C : Conditions);

   procedure Update (
      S               : in out State;
      C               : Conditions;
      Aux             : Aux_Values;
      Now_Us          : Unsigned_32;
      Airmode_Feature : Boolean
   ) with Post => S.Airmode_Enabled = (Airmode_Feature or else S.Active_Mask (Airmode))
                  and then S.Active_Count = S.Active_Count'Old and then S.Linked_Count = S.Linked_Count'Old
                  and then S.Active = S.Active'Old and then S.Linked = S.Linked'Old;

   function Condition_Present (C : Conditions; B : Box) return Boolean is
     (for some I in Condition_Index => C (I).Mode = B and then (Usable (C (I).Span) or else C (I).Linked_To /= Arm));

   function Condition_Linked (C : Conditions; B : Box) return Boolean is
     (for some I in Condition_Index => C (I).Mode = B and then C (I).Linked_To /= Arm);

end Adaflight.Modes;
