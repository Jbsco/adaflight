--  The LED strip: a status profile that paints every LED from its
--  configured function and then runs the overlay layers on their own
--  timers, or a race or beacon profile that paints the whole strip one
--  color, and the strip update that scales each LED by the brightness
--  and turns it into red, green and blue for the driver.
with Interfaces;
with Adaflight.Color;

package Adaflight.LED_Strip with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype HSV is Adaflight.Color.HSV;
   subtype RGB is Adaflight.Color.RGB;
   use type Adaflight.Color.HSV;

   Max_Leds : constant := 32;
   subtype Led_Index is Natural range 0 .. Max_Leds - 1;
   subtype Led_Count is Natural range 0 .. Max_Leds;

   Color_Count : constant := 16;
   subtype Color_Index is Natural range 0 .. Color_Count - 1;
   subtype Named_Color is Natural range 0 .. 13;

   --  A LED's configuration packed as the reference stores it: the
   --  position, the function, the overlay bits, the color and the
   --  direction bits.
   type Led_Configs is array (Led_Index) of Unsigned_32;
   type Palette is array (Color_Index) of HSV;

   type Mode_Id is (Orientation, Headfree_Mode, Horizon_Mode, Angle_Mode, Mag_Mode, Baro_Mode);
   type Direction_Id is (North, East, South, West, Up, Down);
   type Direction_Colors is array (Direction_Id) of Color_Index;
   type Mode_Colors is array (Mode_Id) of Direction_Colors;

   type Special_Id is (Disarmed, Armed_Color, Animation, Background, Blink_Background, GPS_No_Sats, GPS_No_Lock,
                       GPS_Locked);
   type Special_Colors is array (Special_Id) of Color_Index;

   type Profile is (Race, Beacon, Status);

   subtype Brightness_Percent is Unsigned_8 range 0 .. 100;
   subtype Period_Ms is Unsigned_16 range 1 .. Unsigned_16'Last;
   subtype Channel_Index is Natural range 0 .. 17;

   type Settings is record
      Visual_Beeper       : Boolean := True;
      Prof                : Profile := Status;
      Race_Color          : Named_Color := 3;
      Beacon_Color        : Named_Color := 1;
      Beacon_Period       : Period_Ms := 500;
      Beacon_Percent      : Unsigned_8 := 50;
      Visual_Beeper_Color : Named_Color := 1;
      Brightness          : Brightness_Percent := 100;
      Rainbow_Delta       : Unsigned_16 := 0;
      Rainbow_Freq        : Unsigned_16 := 120;
      Leds                : Led_Configs := (others => 0);
      Colors              : Palette := (others => (0, 0, 0));
      Modes               : Mode_Colors := (others => (others => 0));
      Specials            : Special_Colors := (others => 0);
      Aux_Channel         : Channel_Index := 3;
   end record;

   type Battery_State is (OK, Warning, Critical, Not_Present, Init_State);

   subtype Stick is Float range -2000.0 .. 2000.0;
   subtype Pulse is Float range 0.0 .. 4000.0;
   subtype Height_Cm is Integer_32 range -10_000_000 .. 10_000_000;

   type Inputs is record
      Now_Us          : Unsigned_32 := 0;
      Now_Ms          : Unsigned_32 := 0;
      Led_Low         : Boolean := False;
      Beeper_Box      : Boolean := False;
      Armed           : Boolean := False;
      Arming_Disabled : Boolean := False;
      Failsafe        : Boolean := False;
      Crash_Flip      : Boolean := False;
      Beeper_On       : Boolean := False;
      Headfree        : Boolean := False;
      Mag             : Boolean := False;
      Horizon         : Boolean := False;
      Angle           : Boolean := False;
      Battery         : Battery_State := OK;
      Voltage_Meter   : Boolean := False;
      Battery_Percent : Unsigned_8 := 0;
      Rssi_Percent    : Unsigned_8 := 0;
      Rx_Signal       : Boolean := False;
      GPS_Present     : Boolean := False;
      Fix             : Boolean := False;
      Num_Sat         : Unsigned_8 := 0;
      Min_Sats        : Unsigned_8 := 8;
      Altitude_Cm     : Height_Cm := 0;
      Roll_Command    : Stick := 0.0;
      Pitch_Command   : Stick := 0.0;
      Aux             : Pulse := 1500.0;
      Throttle        : Pulse := 1000.0;
   end record;

   type Timer_Id is (Tim_Rainbow, Tim_Blink, Tim_Larson, Tim_Ring, Tim_Indicator, Tim_Vtx, Tim_Gps, Tim_Battery,
                     Tim_Rssi, Tim_Warning);
   type Timers is array (Timer_Id) of Unsigned_32;
   type Timer_Set is array (Timer_Id) of Boolean;

   type Led_Colors is array (Led_Index) of HSV;
   type Led_Output is array (Led_Index) of RGB;

   subtype Grid_Bound is Integer range -1 .. 16;
   subtype Larson_Position is Integer range -2 .. Max_Leds + 1;
   subtype Larson_Step is Integer range -1 .. 1;
   subtype Sequence_Length is Positive range 1 .. Max_Leds;

   --  The layout derived from the configuration: the LEDs in use, the
   --  rings and scanners, the grid halves, the timers no overlay needs,
   --  and the bar lengths.
   type Layout is record
      Count           : Led_Count := 0;
      Ring            : Led_Count := 0;
      Larson          : Led_Count := 0;
      Ring_Seq_Len    : Sequence_Length := 6;
      Highest_Y_North : Grid_Bound := 0;
      Lowest_Y_South  : Grid_Bound := 0;
      Highest_X_West  : Grid_Bound := 0;
      Lowest_X_East   : Grid_Bound := 0;
      Disabled        : Timer_Set := (others => False);
      GPS_Bars        : Led_Count := 0;
      Battery_Bars    : Led_Count := 0;
   end record;

   type Strip is record
      Enabled           : Boolean := False;
      Buffer            : Led_Colors := (others => (0, 0, 0));
      Needs_Full        : Boolean := True;
      Output            : Led_Output := (others => (0, 0, 0));
      Timer             : Timers := (others => 0);
      Warning_Counter   : Unsigned_8 := 0;
      Warning_Flags     : Unsigned_8 := 0;
      Battery_Flash     : Boolean := False;
      Rssi_Flash        : Boolean := False;
      Indicator_Flash   : Boolean := False;
      GPS_Pause         : Unsigned_8 := 0;
      GPS_Flash         : Unsigned_8 := 0;
      Rotation_Phase    : Unsigned_8 := 0;
      Rainbow_Offset    : Unsigned_32 := 0;
      Larson_Brightness : Unsigned_8 := 0;
      Larson_Index      : Larson_Position := 0;
      Larson_Direction  : Larson_Step := 1;
      Blink_Mask        : Unsigned_16 := 0;
      Previous_Simple   : HSV := (0, 0, 0);
      Color_Update_Us   : Unsigned_32 := 0;
   end record;

   --  The layout from the configuration.
   function Evaluate (C : Settings) return Layout;

   --  The strip enabled at start: every LED black and the driver updated.
   procedure Init (S : out Strip; C : Settings; L : Layout);

   --  One task call: the strip disabled or enabled by the switch, the
   --  profile applied and the driver updated when a layer's time came or
   --  the color changed. Updated says the output changed in this call.
   procedure Update (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Updated : out Boolean);

   Max_Text : constant := 60;

   --  A LED's configuration from its text: the position, the direction
   --  letters, the function and overlay letters and the color.
   procedure Parse_Led (Text : String; Result : out Unsigned_32; OK : out Boolean)
     with Pre => Text'First = 1 and then Text'Last in 0 .. Max_Text;

   --  A color from its text: hue, saturation and value.
   procedure Parse_Color (Text : String; Result : out HSV; OK : out Boolean)
     with Pre => Text'First = 1 and then Text'Last in 0 .. Max_Text;

end Adaflight.LED_Strip;
