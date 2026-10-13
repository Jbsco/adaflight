--  The MSP out messages that report the peripherals: the servo outputs, the
--  servos' configuration and mix rules, the motor output order, the LED
--  colors, the LED strip and its mode colors, the video transmitter's
--  configuration, and the wing's tuning. The caller gathers the outputs, the
--  configuration, the transmitter's state and the target's sizes and
--  options into a snapshot. Signed values wrap to their fields, and a reply
--  whose option is left out of the build is unsupported.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;

package Adaflight.MSP_Peripheral_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Servo_Command                   : constant := 103;
   Servo_Configurations_Command    : constant := 120;
   Servo_Mix_Rules_Command         : constant := 241;
   Motor_Output_Reordering_Command : constant := 16#3001#;
   LED_Colors_Command              : constant := 46;
   LED_Strip_Config_Command        : constant := 48;
   LED_Strip_Mode_Color_Command    : constant := 127;
   VTX_Config_Command              : constant := 88;
   Wing_Command                    : constant := 169;

   Max_Servos         : constant := 8;
   Max_Servo_Rules    : constant := 2 * Max_Servos;
   Max_Motors         : constant := 8;
   Color_Count        : constant := 16;
   Max_LEDs           : constant := 64;
   Mode_Count         : constant := 6;
   Direction_Count    : constant := 6;
   Special_Color_Count : constant := 11;
   Axis_Count         : constant := 3;
   Max_Reply_Length   : constant := 4 * Max_LEDs + 2;

   type Servo_Outputs is array (1 .. Max_Servos) of Integer_16;

   type Servo_Param is record
      Min, Max, Middle     : Integer_16 := 0;
      Rate                 : Integer_8 := 0;
      Forward_From_Channel : Integer_8 := 0;
      Reversed_Sources     : Unsigned_32 := 0;
   end record;
   type Servo_Params is array (1 .. Max_Servos) of Servo_Param;

   type Servo_Rule is record
      Target_Channel : Unsigned_8 := 0;
      Input_Source   : Unsigned_8 := 0;
      Rate           : Integer_8 := 0;
      Speed          : Unsigned_8 := 0;
      Min, Max       : Integer_8 := 0;
      Box            : Unsigned_8 := 0;
   end record;
   type Servo_Rules is array (1 .. Max_Servo_Rules) of Servo_Rule;

   type Motor_Order is array (1 .. Max_Motors) of Unsigned_8;

   type HSV_Color is record
      H    : Unsigned_16 := 0;
      S, V : Unsigned_8 := 0;
   end record;
   type HSV_Colors is array (1 .. Color_Count) of HSV_Color;
   type LED_Configs is array (1 .. Max_LEDs) of Unsigned_32;
   type Direction_Colors is array (1 .. Direction_Count) of Unsigned_8;
   type Mode_Colors is array (1 .. Mode_Count) of Direction_Colors;
   type Special_Colors is array (1 .. Special_Color_Count) of Unsigned_8;

   --  The LED strip: its status mode with the configurable colors, each LED's
   --  configuration word, the mode and special colors and the auxiliary
   --  channel, the strip's length on the target, and the profile.
   type LED_Values is record
      Strip       : Boolean := False;
      Status_Mode : Boolean := False;
      Length      : Positive range 1 .. Max_LEDs := Max_LEDs;
      Colors      : HSV_Colors;
      Configs     : LED_Configs := (others => 0);
      Modes       : Mode_Colors := (others => (others => 0));
      Specials    : Special_Colors := (others => 0);
      Aux_Channel : Unsigned_8 := 0;
      Profile     : Unsigned_8 := 0;
   end record;

   --  The video transmitter: the device's presence, type, pit mode and
   --  readiness, the configured band, channel, power, frequency, low power
   --  when disarmed and pit mode frequency, and the frequency table's size
   --  when the table is built.
   type VTX_Values is record
      Built          : Boolean := False;
      Device         : Boolean := False;
      Device_Type    : Unsigned_8 := 16#FF#;
      Pit_Mode       : Boolean := False;
      Ready          : Boolean := False;
      Band           : Unsigned_8 := 0;
      Channel        : Unsigned_8 := 0;
      Power          : Unsigned_8 := 0;
      Frequency      : Unsigned_16 := 0;
      Low_Power_Disarm : Unsigned_8 := 0;
      Pit_Frequency  : Unsigned_16 := 0;
      Table          : Boolean := False;
      Table_Bands    : Unsigned_8 := 0;
      Table_Channels : Unsigned_8 := 0;
      Table_Powers   : Unsigned_8 := 0;
   end record;

   type Axis_Bytes is array (1 .. Axis_Count) of Unsigned_8;
   type Axis_Words is array (1 .. Axis_Count) of Unsigned_16;

   --  The wing's tuning from the PID profile in use.
   type Wing_Values is record
      S_Gains             : Axis_Bytes := (others => 0);
      SPA_Center          : Axis_Words := (others => 0);
      SPA_Width           : Axis_Words := (others => 0);
      SPA_Mode            : Axis_Bytes := (others => 0);
      TPA_Curve_Type      : Unsigned_8 := 0;
      TPA_Curve_Stall     : Unsigned_8 := 0;
      TPA_Curve_PID_Thr0  : Unsigned_16 := 0;
      TPA_Curve_PID_Thr100 : Unsigned_16 := 0;
      TPA_Curve_Expo      : Integer_8 := 0;
      TPA_Speed_Type      : Unsigned_8 := 0;
      TPA_Speed_Delay     : Unsigned_16 := 0;
      TPA_Speed_Gravity   : Unsigned_16 := 0;
      TPA_Speed_Prop_Pitch : Unsigned_16 := 0;
      TPA_Speed_Mass      : Unsigned_16 := 0;
      TPA_Speed_Drag_K    : Unsigned_16 := 0;
      TPA_Speed_Thrust    : Unsigned_16 := 0;
      TPA_Speed_Max_Voltage : Unsigned_16 := 0;
      TPA_Speed_Pitch_Offset : Integer_16 := 0;
      Yaw_Type            : Unsigned_8 := 0;
      Angle_Pitch_Offset  : Integer_16 := 0;
   end record;

   type Snapshot is record
      Servos       : Boolean := False;
      Servo_Count  : Positive range 1 .. Max_Servos := Max_Servos;
      Outputs      : Servo_Outputs := (others => 0);
      Params       : Servo_Params;
      Rules        : Servo_Rules;
      Motors       : Motor_Order := (others => 0);
      LED          : LED_Values;
      VTX          : VTX_Values;
      Wing         : Wing_Values;
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Servo_Command | Servo_Configurations_Command | Servo_Mix_Rules_Command
               | Motor_Output_Reordering_Command | LED_Colors_Command | LED_Strip_Config_Command
               | LED_Strip_Mode_Color_Command | VTX_Config_Command | Wing_Command);

   --  Whether the reply exists for this build: the servo replies need the
   --  servos, the colors and mode colors the status mode, the strip
   --  configuration the strip, and the transmitter configuration the
   --  transmitter.
   function Supported (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Handles (Command)
      and then (Command not in Servo_Command | Servo_Configurations_Command | Servo_Mix_Rules_Command
                or else V.Servos)
      and then (Command not in LED_Colors_Command | LED_Strip_Mode_Color_Command or else V.LED.Status_Mode)
      and then (Command /= LED_Strip_Config_Command or else V.LED.Strip)
      and then (Command /= VTX_Config_Command or else V.VTX.Built));

   --  The reply to one of these out messages; any other command, or one not
   --  supported, writes nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Supported (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_Peripheral_Out;
