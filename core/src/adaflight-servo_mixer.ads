--  The servo mixer: whether the mixer drives servos, the rules it mixes by
--  for its mode, each rule's input moved at the rule's speed and scaled by
--  its rate within its range, each servo's rate and its middle or forwarded
--  channel, the camera stabilization, the servo limits and the lowpass
--  filter, then the servo writes in their output order: the mode's servos,
--  the gimbal pair, the forwarded servos not yet written and the forwarded
--  aux channels. The outputs and their timers stay with the target.
with Interfaces; use Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Filters;
with Adaflight.Mixer_Init;

package Adaflight.Servo_Mixer with SPARK_Mode is

   Max_Servos     : constant := 8;
   Max_Rules      : constant := 16;
   Source_Count   : constant := 14;
   Max_Channels   : constant := 18;
   Max_Aux        : constant := 14;
   Max_Writes     : constant := Max_Servos + 2 + Max_Servos + Max_Aux;
   Disabled       : constant := 255;

   subtype Servo_Index is Natural range 0 .. Max_Servos - 1;
   type Servo_Values is array (Servo_Index) of Integer_16;
   type Servo_Flags is array (Servo_Index) of Boolean;
   subtype Rule_Index is Natural range 0 .. Max_Rules - 1;
   type Rule_Outputs is array (Rule_Index) of Integer_16;
   type Servo_Filters is array (Servo_Index) of Filters.SVF_Lowpass;

   subtype Channel_Index is Natural range 0 .. Max_Channels - 1;
   subtype RC_Value is Float range -10_000.0 .. 10_000.0;
   type RC_Values is array (Channel_Index) of RC_Value;

   type Box_Flags is array (1 .. 3) of Boolean;

   subtype Axis is Natural range 0 .. 2;
   subtype Command is Float range -4_000.0 .. 4_000.0;
   type Commands is array (Axis) of Command;

   --  The mixer mode and the build's mixers, the servo tilt, channel
   --  forwarding and 3D features, the servo parameters and custom rules, the
   --  lowpass cutoff in hertz, the tricopter's unarmed servo, the first
   --  channel forwarded, the gimbal's mixed tilt, the receiver's middle and
   --  aux channel count, and the channels the receiver delivers.
   type Settings is record
      Mode               : Mixer_Init.Mixer_Mode := Mixer_Init.Quad_X;
      Options            : Mixer_Init.Options;
      Servo_Tilt         : Boolean := False;
      Channel_Forwarding : Boolean := False;
      Three_D            : Boolean := False;
      Params             : Config_Groups.Servo_Param_Record_List_8;
      Custom_Rules       : Config_Groups.Servo_Mixer_Record_List_16;
      Lowpass_Hz         : Unsigned_16 := 0;
      Tri_Unarmed        : Boolean := True;
      Forward_Start      : Natural range 0 .. 255 := 4;
      Mixed_Tilt         : Boolean := False;
      Mid_RC             : Unsigned_16 range 1_200 .. 1_700 := 1_500;
      Max_Aux_Channel    : Natural range 0 .. 255 := Max_Aux;
      Channel_Count      : Natural range 0 .. Max_Channels := Max_Channels;
   end record;

   --  One pass's readings: arming, passthrough, the three servo boxes and
   --  the camera stabilization box, the commands and the PID sums by axis,
   --  the attitude's roll and pitch in tenths of a degree, the first motor
   --  converted for its device or its own value without one, and the RC
   --  data.
   type Inputs is record
      Armed          : Boolean := False;
      Passthru       : Boolean := False;
      Servo_Box      : Box_Flags := (others => False);
      Camera_Box     : Boolean := False;
      RC_Command     : Commands := (others => 0.0);
      PID_Sum        : Commands := (others => 0.0);
      Roll, Pitch    : Integer_16 := 0;
      Motor_Device   : Boolean := True;
      External_Motor : Unsigned_16 range 0 .. 10_000 := 1_000;
      Motor          : RC_Value := 1_000.0;
      RC_Data        : RC_Values := (others => 1_500.0);
   end record;

   type Servo_Write is record
      Index : Natural range 0 .. 255 := 0;
      Value : Float := 0.0;
   end record;
   subtype Write_Count is Natural range 0 .. Max_Writes;
   type Servo_Writes is array (1 .. Max_Writes) of Servo_Write;

   type State is record
      Uses_Servos : Boolean := False;
      Rule_Count  : Natural range 0 .. Max_Rules := 0;
      Rules       : Config_Groups.Servo_Mixer_Record_List_16;
      Outputs     : Rule_Outputs := (others => 0);
      Servo       : Servo_Values := (others => 1_500);
      Filter      : Servo_Filters;
      Written     : Servo_Flags := (others => False);
   end record;

   --  The servo setup and the filter setup at the PID loop's period.
   procedure Init (S : out State; C : Settings; Dt : Filters.Period);

   --  The custom rules up to the first without a rate as the mixer's rules,
   --  in any mode, which an MSP servo rule write asks for.
   procedure Load_Custom_Rules (S : in out State; Rules : Config_Groups.Servo_Mixer_Record_List_16);

   --  One servo update: the servo table, the filter, then the writes.
   procedure Write_Servos (S : in out State; C : Settings; I : Inputs; W : out Servo_Writes; Count : out Write_Count);

end Adaflight.Servo_Mixer;
