with Adaflight.Config_Fix;
with Adaflight.Number_Text;
with Adaflight.OSD_Elements;
with Adaflight.Settings_Table;
with Adaflight.Simplified_Tuning.Stored;
with Adaflight.SmartAudio;
with Adaflight.Tramp;

package body Adaflight.Menu_Content with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   use type Adaflight.Menu.Element;
   use type Adaflight.SmartAudio.Version;

   subtype Line is Adaflight.Menu.Line;
   subtype Table is Adaflight.Menu.Table;

   function Label (S : String) return Adaflight.Menu.Label_Text
     with Pre => S'Length <= Adaflight.Menu.Max_Text
   is
      T : Adaflight.Menu.Label_Text;
   begin
      T.Length := S'Length;
      for K in 1 .. S'Length loop
         T.Data (K) := S (S'First - 1 + K);
      end loop;
      return T;
   end Label;

   function Code (E : Adaflight.Menu.Element) return Interfaces.Unsigned_16 is
     (Interfaces.Unsigned_16 (Adaflight.Menu.Element'Pos (E)));

   --  A line of an element with its text, whether a function and data
   --  stand behind it, and its value.
   function Make
     (Text     : String;
      E        : Adaflight.Menu.Element;
      Has_Func : Boolean := False;
      Has_Data : Boolean := False;
      Value    : Interfaces.Integer_32 := 0;
      Flags    : Interfaces.Unsigned_16 := 0) return Line
   is
     ((Text => Label (Text), Flags => Code (E) or Flags, Has_Data => Has_Data, Has_Func => Has_Func, Value => Value,
       others => <>))
     with Pre  => Text'Length <= Adaflight.Menu.Max_Text and then E /= Adaflight.Menu.Fixed
                  and then (Flags and Adaflight.Menu.Element_Mask) = 0;

   Reboot : constant Interfaces.Unsigned_16 := Adaflight.Menu.Reboot_Required;

   --  A number line of an element with its value, range and step.
   function Number
     (Text            : String;
      Value, Min, Max : Interfaces.Integer_32;
      E               : Adaflight.Menu.Element := Adaflight.Menu.UInt8;
      Step            : Interfaces.Integer_32 := 1;
      Flags           : Interfaces.Unsigned_16 := 0;
      Has_Func        : Boolean := False) return Line
   is
     ((Text => Label (Text), Flags => Code (E) or Flags, Has_Data => True, Has_Func => Has_Func, Value => Value,
       Min => Min, Max => Max, Step => Step, others => <>))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text and then E /= Adaflight.Menu.Fixed
                 and then (Flags and Adaflight.Menu.Element_Mask) = 0;

   --  A fixed-point line: a byte with its range, step and multiplier.
   function Fixed_Number
     (Text            : String;
      Value, Min, Max : Interfaces.Integer_32;
      Multiplier      : Natural;
      Flags           : Interfaces.Unsigned_16 := 0;
      Step            : Interfaces.Integer_32 := 1) return Line
   is
     ((Text => Label (Text), Flags => Code (Adaflight.Menu.Fixed) or Flags, Has_Data => True, Value => Value,
       Min => Min, Max => Max, Step => Step, Multiplier => Multiplier, others => <>))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text and then Value in 0 .. 255 and then Multiplier <= 65_535
                 and then (Flags and Adaflight.Menu.Element_Mask) = 0;

   --  A lookup table line with its value, the last index and the value's
   --  text.
   function Choice
     (Text     : String;
      Value    : Interfaces.Integer_32;
      Max      : Interfaces.Integer_32;
      Name     : Adaflight.Menu.Label_Text;
      Flags    : Interfaces.Unsigned_16 := 0;
      Has_Func : Boolean := False) return Line
   is
     ((Text => Label (Text), Flags => Code (Adaflight.Menu.Tab) or Flags, Has_Data => True, Has_Func => Has_Func,
       Value => Value, Max => Max, Value_Text => Name, others => <>))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text and then (Flags and Adaflight.Menu.Element_Mask) = 0;

   --  A submenu line to a menu, with the change function or none.
   function Sub (Text : String; Target : Menu_Id; Has_Func : Boolean := True) return Line is
     (Make (Text, Adaflight.Menu.Submenu, Has_Func => Has_Func, Has_Data => True,
            Value => Interfaces.Integer_32 (Target)))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text;

   --  A line of an element with a text behind it: a string line's value
   --  or a function call's status.
   function Text_Line
     (Text     : String;
      E        : Adaflight.Menu.Element;
      Value    : Adaflight.Menu.Label_Text;
      Has_Func : Boolean := False;
      Flags    : Interfaces.Unsigned_16 := 0) return Line
   is
     ((Text => Label (Text), Flags => Code (E) or Flags, Has_Data => True, Has_Func => Has_Func, Value_Text => Value,
       others => <>))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text and then E /= Adaflight.Menu.Fixed
                 and then (Flags and Adaflight.Menu.Element_Mask) = 0;

   --  A text cut to a length.
   function Cut (T : Adaflight.Menu.Label_Text; Length : Adaflight.Menu.Text_Length) return Adaflight.Menu.Label_Text is
     (if T.Length <= Length then T else Label (T.Data (1 .. Length)));

   --  A text up to its first null character, where the reference's strings
   --  end.
   function C_Text (S : String) return Adaflight.Menu.Label_Text
     with Pre => S'Length <= Adaflight.Menu.Max_Text
   is
      Last : Integer := S'Last;
   begin
      for K in S'Range loop
         pragma Loop_Invariant (Last = S'Last);
         if S (K) = ASCII.NUL then
            Last := K - 1;
            exit;
         end if;
      end loop;
      return Label (S (S'First .. Last));
   end C_Text;

   function Decimal (V : Interfaces.Unsigned_16; Width : Positive) return String
     renames Adaflight.Number_Text.Decimal;

   Pit_Mode_Names : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("---"), Label ("OFF"), Label ("ON "));

   function Pit_Mode_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then Pit_Mode_Names (Index) else Label (""));

   --  The VTX device menus' names of the running table's bands, channels and
   --  power levels by index, the first for none.
   function Band_Name (Run : Adaflight.VTX_Table.Table; Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index = 0 then Label ("--------")
      elsif Index <= Adaflight.VTX_Table.Max_Bands then C_Text (Run.Names (Index))
      else Label (""));
   function Channel_Name (Run : Adaflight.VTX_Table.Table; Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index = 0 then Label ("-")
      elsif Index <= Adaflight.VTX_Table.Max_Channels then C_Text ((1 => Run.Channel_Name (Index)))
      else Label (""));
   function Power_Name (Run : Adaflight.VTX_Table.Table; Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index = 0 then Label ("---")
      elsif Index <= Adaflight.VTX_Table.Max_Power_Levels then C_Text (Run.Label (Index))
      else Label (""));

   SA_Opmodel_Names    : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("----"), Label ("FREE"), Label ("RACE"));
   SA_Fsel_Names       : constant array (0 .. 1) of Adaflight.Menu.Label_Text := (Label ("CHAN"), Label ("USER"));
   SA_Pit_F_Mode_Names : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("---"), Label ("PIR"), Label ("POR"));
   SA_Status_Names     : constant array (0 .. 3) of Adaflight.Menu.Label_Text :=
     (Label ("OFFL"), Label ("ONL V1"), Label ("ONL V2"), Label ("ONLV21"));

   function SA_Opmodel_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then SA_Opmodel_Names (Index) else Label (""));
   function SA_Fsel_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 1 then SA_Fsel_Names (Index) else Label (""));
   function SA_Pit_F_Mode_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then SA_Pit_F_Mode_Names (Index) else Label (""));
   function SA_Status_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 3 then SA_Status_Names (Index) else Label (""));

   Throttle_Limit_Names : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("OFF"), Label ("SCALE"), Label ("CLIP"));

   function Throttle_Limit_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then Throttle_Limit_Names (Index) else Label (""));

   Voltage_Meter_Names : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("NONE"), Label ("ADC"), Label ("ESC"));
   Current_Meter_Names : constant array (0 .. 4) of Adaflight.Menu.Label_Text :=
     (Label ("NONE"), Label ("ADC"), Label ("VIRTUAL"), Label ("ESC"), Label ("MSP"));
   Procedure_Names     : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("AUTO-LAND"), Label ("DROP"), Label ("GPS-RESCUE"));

   function Voltage_Meter_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then Voltage_Meter_Names (Index) else Label (""));
   function Current_Meter_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 4 then Current_Meter_Names (Index) else Label (""));
   function Procedure_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then Procedure_Names (Index) else Label (""));

   LED_Profile_Names : constant array (0 .. LED_Profile_Count - 1) of Adaflight.Menu.Label_Text :=
     (Label ("RACE"), Label ("BEACON"), Label ("STATUS"));
   LED_Color_Names   : constant array (0 .. LED_Color_Count - 1) of Adaflight.Menu.Label_Text :=
     (Label ("BLACK"), Label ("WHITE"), Label ("RED"), Label ("ORANGE"), Label ("YELLOW"), Label ("LIME_GREEN"),
      Label ("GREEN"), Label ("MINT_GREEN"), Label ("CYAN"), Label ("LIGHT_BLUE"), Label ("BLUE"),
      Label ("DARK_VIOLET"), Label ("MAGENTA"), Label ("DEEP_PINK"));

   function LED_Profile_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index < LED_Profile_Count then LED_Profile_Names (Index) else Label (""));
   function LED_Color_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index < LED_Color_Count then LED_Color_Names (Index) else Label (""));

   Blackbox_Device_Names : constant array (0 .. 3) of Adaflight.Menu.Label_Text :=
     (Label ("NONE"), Label ("FLASH"), Label ("SDCARD"), Label ("SERIAL"));
   Blackbox_Rate_Names   : constant array (0 .. 4) of Adaflight.Menu.Label_Text :=
     (Label ("1/1"), Label ("1/2"), Label ("1/4"), Label ("1/8"), Label ("1/16"));

   function Blackbox_Device_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 3 then Blackbox_Device_Names (Index) else Label (""));
   function Blackbox_Rate_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 4 then Blackbox_Rate_Names (Index) else Label (""));

   use all type Adaflight.OSD_Elements.Item;

   --  The active elements menu's lines: an element's name and the element.
   type Element_Line is record
      Name : Adaflight.Menu.Label_Text;
      Item : Adaflight.OSD_Elements.Item;
   end record;

   function E (Name : String; Item : Adaflight.OSD_Elements.Item) return Element_Line is ((Label (Name), Item))
     with Pre => Name'Length <= Adaflight.Menu.Max_Text;

   Active_Count : constant := 77;

   Active_Lines : constant array (1 .. Active_Count) of Element_Line :=
     (E ("RSSI", RSSI_Value), E ("RSSI DBM", RSSI_Dbm_Value), E ("RSNR", RSNR_Value),
      E ("BATTERY VOLTAGE", Main_Battery_Voltage), E ("BATTERY USAGE", Main_Battery_Usage),
      E ("AVG CELL VOLTAGE", Average_Cell_Voltage), E ("BATTERY EFFICIENCY", Efficiency),
      E ("CROSSHAIRS", Crosshairs), E ("HORIZON", Artificial_Horizon), E ("HORIZON SIDEBARS", Horizon_Sidebars),
      E ("UP/DOWN REFERENCE", Up_Down_Reference), E ("TIMER 1", Timer_1), E ("TIMER 2", Timer_2),
      E ("REMAINING TIME ESTIMATE", Remaining_Time_Estimate), E ("RTC DATETIME", RTC_Date_Time),
      E ("ADJUSTMENT RANGE", Adjustment_Range), E ("CORE TEMPERATURE", Core_Temperature),
      E ("ANTI GRAVITY", Anti_Gravity), E ("FLY MODE", Fly_Mode), E ("CRAFT NAME", Craft_Name),
      E ("THROTTLE", Throttle_Position), E ("VTX CHAN", VTX_Channel), E ("CURRENT (A)", Current_Draw),
      E ("USED MAH", MAh_Drawn), E ("GPS SPEED", GPS_Speed), E ("GPS SATS", GPS_Sats), E ("GPS LAT", GPS_Latitude),
      E ("GPS LON", GPS_Longitude), E ("HOME DIR", Home_Direction), E ("HOME DIST", Home_Distance),
      E ("FLIGHT DIST", Flight_Distance), E ("WP NUMBER", WP_Number), E ("WP LAT", WP_Current_Lat),
      E ("WP LON", WP_Current_Lon), E ("WP ALT", WP_Current_Alt), E ("WP DIST", WP_Distance),
      E ("WP DIR", WP_Direction), E ("WP NEXT", WP_Next_Number), E ("WP ETA", WP_ETA), E ("COMPASS BAR", Compass_Bar),
      E ("ESC TEMPERATURE", ESC_Temperature), E ("ESC RPM", ESC_RPM), E ("ALTITUDE", Altitude), E ("POWER", Power),
      E ("ROLL PID", Roll_PIDs), E ("PITCH PID", Pitch_PIDs), E ("YAW PID", Yaw_PIDs),
      E ("PROFILES", PID_Rate_Profile), E ("PID PROFILE NAME", PID_Profile_Name),
      E ("RATE PROFILE NAME", Rate_Profile_Name), E ("OSD PROFILE NAME", Profile_Name), E ("DEBUG", Debug),
      E ("DEBUG2", Debug2), E ("WARNINGS", Warnings), E ("DISARMED", Disarmed), E ("PIT ANG", Pitch_Angle),
      E ("ROL ANG", Roll_Angle), E ("HEADING", Numerical_Heading), E ("POS HOLD READY", Position_Hold_Ready),
      E ("VARIO", Numerical_Vario), E ("G-FORCE", G_Force), E ("MOTOR DIAGNOSTIC", Motor_Diagnostics),
      E ("LOG STATUS", Log_Status), E ("FLIP ARROW", Flip_Arrow), E ("LINK QUALITY", Link_Quality),
      E ("STICK OVERLAY LEFT", Stick_Overlay_Left), E ("STICK OVERLAY RIGHT", Stick_Overlay_Right),
      E ("LAP TIME CURRENT", GPS_Lap_Time_Current), E ("LAP TIME PREVIOUS", GPS_Lap_Time_Previous),
      E ("LAP TIME BEST 3", GPS_Lap_Time_Best3), E ("PILOT NAME", Pilot_Name),
      E ("RC CHANNELS", Adaflight.OSD_Elements.RC_Channels),
      E ("CAMERA FRAME", Camera_Frame), E ("TOTAL FLIGHTS", Total_Flights), E ("AUX VALUE", Aux_Value),
      E ("LIDAR DIST", Lidar_Distance), E ("SERIAL TEXT", Custom_Serial_Text));

   Timer_Source_Names    : constant array (0 .. 4) of Adaflight.Menu.Label_Text :=
     (Label ("ON TIME  "), Label ("TOTAL ARM"), Label ("LAST ARM "), Label ("ON/ARM   "), Label ("LAUNCH TIME"));
   Timer_Precision_Names : constant array (0 .. 1) of Adaflight.Menu.Label_Text := (Label ("SCND"), Label ("HDTH"));

   function Timer_Source_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 4 then Timer_Source_Names (Index) else Label (""));
   function Timer_Precision_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 1 then Timer_Precision_Names (Index) else Label (""));

   --  A value's name from one of the command line's tables, empty past the
   --  table.
   function Setting_Name (Table : Adaflight.Settings_Table.Lookup_Table; Index : Natural)
     return Adaflight.Menu.Label_Text
   is
   begin
      if Index >= Adaflight.Settings_Table.Value_Count (Table) then
         return Label ("");
      end if;
      declare
         Name : constant String := Adaflight.Settings_Table.Value_Name (Table, Index);
      begin
         return Label (Name (Name'First .. Name'First - 1 + Natural'Min (Name'Length, Adaflight.Menu.Max_Text)));
      end;
   end Setting_Name;

   function Background_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (Setting_Name (Adaflight.Settings_Table.Table_Cms_Background, Index));

   function Upper (C : Character) return Character is
     (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);

   --  A profile's text: its number from one, then its name in upper case in
   --  parentheses when it has one.
   function Profile_Text (Index : Interfaces.Unsigned_8; Name : Adaflight.Config_Groups.Bytes_9)
     return Adaflight.Menu.Label_Text
     with Global => null
   is
      Len  : Natural range 0 .. 9 := 0;
      Text : Adaflight.Menu.Label_Text;
   begin
      for K in 0 .. 8 loop
         pragma Loop_Invariant (Len = K);
         exit when Name (K) = 0;
         Len := K + 1;
      end loop;
      Text.Data (1) := Character'Val ((Character'Pos ('1') + Natural (Index)) mod 256);
      Text.Length := 1;
      if Len > 0 then
         Text.Data (2) := ' ';
         Text.Data (3) := '(';
         for K in 0 .. Len - 1 loop
            Text.Data (4 + K) := Upper (Character'Val (Name (K)));
         end loop;
         Text.Data (4 + Len) := ')';
         Text.Length := 4 + Len;
      end if;
      return Text;
   end Profile_Text;

   function Profile_Name (Names : Profile_Texts; Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 3 then Names (Index) else Label (""));

   Debug_Count : constant Natural := Adaflight.Settings_Table.Value_Count (Adaflight.Settings_Table.Table_Debug);

   --  A debug mode's name from the command line's table, which holds the
   --  reference's debug mode names.
   function Debug_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (Setting_Name (Adaflight.Settings_Table.Table_Debug, Index));

   --  A thirty-two bit count as a line holds it: the reference's integer
   --  conversion.
   function Signed_Word (V : Interfaces.Unsigned_32) return Interfaces.Integer_32 is
     (if V < 2 ** 31 then Interfaces.Integer_32 (V)
      else Interfaces.Integer_32 (Interfaces.Integer_64 (V) - 2 ** 32));

   --  A count as the reference prints it into an eight-byte buffer: as a
   --  signed long on a 32-bit target, with its unit, cut to seven
   --  characters.
   function Count_Text (V : Interfaces.Unsigned_32; Unit : String) return Adaflight.Menu.Label_Text
     with Pre => Unit'Length <= 2
   is
      Image  : constant String := Interfaces.Integer_32'Image (Signed_Word (V));
      Number : constant String := (if Signed_Word (V) >= 0 then Image (Image'First + 1 .. Image'Last) else Image);
      Full   : constant String := Number & Unit;
   begin
      return Label (Full (Full'First .. Full'First - 1 + Natural'Min (Full'Length, 7)));
   end Count_Text;

   --  The PID loop's frequency cut to a whole number, in kilohertz with two
   --  decimals above a thousand hertz and else in hertz in three places, cut
   --  to the reference's eight-byte buffer.
   function PID_Frequency_Text (F : PID_Hertz) return Adaflight.Menu.Label_Text
     with Global => null
   is
      Hz     : constant Natural := Natural (Float'Truncation (F));
      Tenths : constant Natural := Hz / 10;
      Whole  : constant String := Natural'Image (Tenths / 100);
      Part   : constant String := Natural'Image (Tenths mod 100);
      Plain  : constant String := Natural'Image (Hz);
      Full   : constant String :=
        (if Hz > 1000
         then Whole (Whole'First + 1 .. Whole'Last) & "." & (if Tenths mod 100 < 10 then "0" else "")
              & Part (Part'First + 1 .. Part'Last) & "KHZ"
         elsif Hz < 100 then (if Hz < 10 then "  " else " ") & Plain (Plain'First + 1 .. Plain'Last) & "HZ"
         else Plain (Plain'First + 1 .. Plain'Last) & "HZ");
   begin
      return Label (Full (Full'First .. Full'First - 1 + Natural'Min (Full'Length, 7)));
   end PID_Frequency_Text;

   --  The display's information severity.
   Info : constant Interfaces.Unsigned_8 := 1;

   --  A text the hook writes on the display at a column and row.
   function Screen_Text (X, Y : Natural; Text : String) return Adaflight.Menu.Screen_Op
     with Pre => X <= 255 and then Y <= 255 and then Text'Length <= Adaflight.Menu.Max_Screen_Text
   is
      Op : Adaflight.Menu.Screen_Op := (Kind => Adaflight.Menu.Write_Text, X => X, Y => Y, Attr => Info, others => <>);
   begin
      Op.Length := Text'Length;
      for K in 1 .. Text'Length loop
         Op.Text (K) := Text (Text'First - 1 + K);
      end loop;
      return Op;
   end Screen_Text;

   --  The storage device's status and its used and free space, from the
   --  configured device and the device's readings with the flash's write
   --  offset given.
   procedure Device_Status (T : in out Target; Flash_Offset : Interfaces.Unsigned_32)
     with Global => null
   is
      Used, Free : Interfaces.Unsigned_32 := 0;
      Working    : Boolean := False;
   begin
      case T.Config.Blackbox_Config.Device is
         when 2 =>
            if not T.Live.Card_Inserted then
               T.Blackbox.Status := Label ("NO CARD");
            elsif not T.Live.Card_Functional then
               T.Blackbox.Status := Label ("FAULT");
            else
               case T.Live.Card_File_System is
                  when Ready =>
                     T.Blackbox.Status := Label ("READY");
                     Working := True;
                  when Initialization =>
                     T.Blackbox.Status := Label ("INIT");
                  when Fatal | Unknown =>
                     T.Blackbox.Status := Label ("FAULT");
               end case;
            end if;
            if Working then
               Free := T.Live.Card_Free_Bytes / 1_024_000;
               Used := T.Live.Card_Blocks / 2000 - Free;
            end if;
            T.Blackbox.Used := Count_Text (Used, "MB");
            T.Blackbox.Free := Count_Text (Free, "MB");
         when 1 =>
            if T.Live.Flash_Supported then
               T.Blackbox.Status := Label ("READY");
               Used := Flash_Offset / 1024;
               Free := Interfaces.Unsigned_32 (T.Live.Flash_Sectors) * T.Live.Flash_Sector_Size / 1024 - Used;
            else
               T.Blackbox.Status := Label ("FAULT");
            end if;
            T.Blackbox.Used := Count_Text (Used, "KB");
            T.Blackbox.Free := Count_Text (Free, "KB");
         when others =>
            T.Blackbox.Status := Label ("---");
            T.Blackbox.Used := Count_Text (Used, "B");
            T.Blackbox.Free := Count_Text (Free, "B");
      end case;
   end Device_Status;

   RC_Names : constant array (0 .. 7) of String (1 .. 5) :=
     ("ROLL ", "PITCH", "THR  ", "YAW  ", "AUX1 ", "AUX2 ", "AUX3 ", "AUX4 ");
   RC_Name_Lengths : constant array (0 .. 7) of Positive := (4, 5, 3, 3, 4, 4, 4, 4);

   --  The channel each preview line shows: the menu lists the throttle
   --  before the yaw, the channels come yaw first.
   RC_Line_Channels : constant array (0 .. 7) of Natural range 0 .. 7 := (0, 1, 3, 2, 4, 5, 6, 7);

   function Hooks_Of (Id : Menu_Id) return Adaflight.Menu.Hook_Set is
     (case Id is
         when Quick_Menu  => (Enter => True, Leave => True, Update => False),
         when Main_Menu   => (Enter => True, Leave => False, Update => False),
         when Setup_Popup => (Enter => False, Leave => False, Update => True),
         when Profile_Menu | PID_Menu | Rate_Menu | Simplified_Menu | Profile_Other_Menu | Launch_Control_Menu
            | Filter_Profile_Menu | Filter_Global_Menu | Dynamic_Filter_Menu | OSD_Menu | Active_Elements_Menu
            | Timers_Menu | Alarms_Menu
            | Blackbox_Menu | LED_Strip_Menu | Power_Menu | Failsafe_Menu | GPS_Rescue_Menu | GPS_Rescue_PID_Menu
            | RPM_Limit_Menu | Misc_Menu
            | Persistent_Stats_Menu =>
            (Enter => True, Leave => True, Update => False),
         when RC_Preview_Menu => (Enter => True, Leave => True, Update => True),
         when Copy_Profile_Menu => (Enter => True, Leave => False, Update => False),
         when Firmware_Menu | VTX_Error_Menu | VTX_MSP_Menu | VTX_Tramp_Menu | VTX_SmartAudio_Menu | SA_POR_Freq_Menu
            | SA_User_Freq_Menu =>
            (Enter => True, Leave => False, Update => False),
         when Calibration_Menu => (Enter => False, Leave => False, Update => True),
         when GPS_Lap_Timer_Menu | Set_Gate_Menu => (Enter => True, Leave => True, Update => False),
         when others      => (others => False));

   --  Every fixed-point line below a count holds a byte.
   function Fixed_Below (M : Table; N : Adaflight.Menu.Line_Count) return Boolean is
     (for all I in 0 .. N - 1 =>
        (if Adaflight.Menu.Element_Of (M.Lines (I).Flags) = Adaflight.Menu.Fixed then M.Lines (I).Value in 0 .. 255));

   --  A line added to a menu being built.
   procedure Add (M : in out Table; N : in out Adaflight.Menu.Line_Count; L : Line)
     with Pre  => N < Adaflight.Menu.Max_Lines
                  and then (if Adaflight.Menu.Element_Of (L.Flags) = Adaflight.Menu.Fixed then L.Value in 0 .. 255)
                  and then Fixed_Below (M, N),
          Post => N = N'Old + 1 and then Fixed_Below (M, N)
   is
   begin
      M.Lines (N) := L;
      N := N + 1;
   end Add;

   Empty_Table : constant Table :=
     (Lines => (others => (Flags => Code (Adaflight.Menu.Label), others => <>)), Count => 1);

   procedure Load_Quick_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- QUICK --", Label));
      Add (M, N, Sub ("RPM LIM", RPM_Limit_Menu));
      declare
         L : Line := Make ("THR LIM TYPE", Tab, Has_Data => True,
                           Value => Interfaces.Integer_32 (T.Quick.Rate.Throttle_Limit_Type));
      begin
         L.Max := 2;
         L.Value_Text := Throttle_Limit_Name (Natural (T.Quick.Rate.Throttle_Limit_Type));
         Add (M, N, L);
      end;
      Add (M, N, Number ("THR LIM %", Interfaces.Integer_32 (T.Quick.Rate.Throttle_Limit_Percent), 25, 100));
      Add (M, N, Number ("MTR OUT LIM %", Interfaces.Integer_32 (T.Quick.Motor_Output_Limit), 1, 100));
      Add (M, N, Number ("FORCE CELLS", Interfaces.Integer_32 (T.Quick.Battery.Force_Battery_Cell_Count), 0, 24));
      Add (M, N, Make ("VTX", Funcall, Has_Func => True));
      Add (M, N, Sub ("MAIN", Main_Menu, Has_Func => False));
      Add (M, N, Make ("EXIT", OSD_Exit, Has_Func => True, Value => 0));
      Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
      M.Count := N;
   end Load_Quick_Menu;

   procedure Load_Main_Menu (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- MAIN --", Label));
      Add (M, N, Sub ("PROFILE", Profile_Menu));
      Add (M, N, Sub ("FEATURES", Features));
      Add (M, N, Sub ("OSD", OSD_Menu));
      Add (M, N, Sub ("FC&FIRMWARE", Firmware_Menu));
      Add (M, N, Sub ("MISC", Misc_Menu));
      Add (M, N, Make ("SAVE/EXIT", Funcall, Has_Func => True));
      M.Count := N;
   end Load_Main_Menu;

   procedure Load_Features (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- FEATURES ---", Label));
      Add (M, N, Sub ("BLACKBOX", Blackbox_Menu));
      Add (M, N, Make ("VTX", Funcall, Has_Func => True));
      Add (M, N, Sub ("LED STRIP", LED_Strip_Menu));
      Add (M, N, Sub ("POWER", Power_Menu));
      Add (M, N, Sub ("FAILSAFE", Failsafe_Menu));
      Add (M, N, Sub ("PERSISTENT STATS", Persistent_Stats_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Features;

   procedure Load_Setup_Popup (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- SETUP MENU --", Label));
      if T.Popup.Acc_Line then
         Add (M, N, Text_Line ("CALIBRATE ACC", Funcall, T.Popup.Acc_Status, Has_Func => True, Flags => Dynamic));
      end if;
      if T.Popup.Battery_Line then
         declare
            L : Line := Make ("", Funcall, Has_Func => True, Flags => Dynamic);
         begin
            L.Text := T.Popup.Battery_Text;
            Add (M, N, L);
         end;
      end if;
      Add (M, N, Make ("EXIT", Back, Flags => Dynamic));
      M.Count := N;
   end Load_Setup_Popup;

   procedure Load_Save_Exit (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- SAVE/EXIT --", Label));
      Add (M, N, Make ("EXIT", OSD_Exit, Has_Func => True, Value => 0));
      Add (M, N, Make ("SAVE&EXIT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 3));
      Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Save_Exit;

   procedure Load_Save_Exit_Reboot (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- SAVE/EXIT (REBOOT REQD)", Label));
      Add (M, N, Make ("EXIT&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 5));
      Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Save_Exit_Reboot;

   procedure Load_VTX_Error_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Text_Line ("", Label, T.VTX_Status.Line_1, Flags => Dynamic));
      Add (M, N, Text_Line ("", Label, T.VTX_Status.Line_2, Flags => Dynamic));
      Add (M, N, Make ("", Label));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_VTX_Error_Menu;

   --  The VTX device menus' first lines: the title, the status line, and
   --  the pit mode, band, channel, frequency and power lines over the copies
   --  and the running table.
   procedure Add_VTX_Lines
     (M      : in out Table;
      N      : in out Adaflight.Menu.Line_Count;
      Title  : String;
      Status : Adaflight.Menu.Label_Text;
      C      : VTX_Copies;
      Run    : Adaflight.VTX_Table.Table)
     with Global => null,
          Pre    => Title'Length <= Adaflight.Menu.Max_Text and then N <= Adaflight.Menu.Max_Lines - 7
                    and then Fixed_Below (M, N),
          Post   => N = N'Old + 7 and then Fixed_Below (M, N)
   is
      use Adaflight.Menu;
   begin
      Add (M, N, Make (Title, Label));
      Add (M, N, Text_Line ("", Label, Status, Flags => Dynamic));
      Add (M, N, Choice ("PIT", Interfaces.Integer_32 (C.Pit_Mode), 2, Pit_Mode_Name (Natural (C.Pit_Mode)),
                         Has_Func => True));
      Add (M, N, Choice ("BAND", Interfaces.Integer_32 (C.Band), Interfaces.Integer_32 (Run.Bands),
                         Band_Name (Run, Natural (C.Band)), Has_Func => True));
      Add (M, N, Choice ("CHAN", Interfaces.Integer_32 (C.Channel), Interfaces.Integer_32 (Run.Channels),
                         Channel_Name (Run, Natural (C.Channel)), Has_Func => True));
      Add (M, N, Number ("(FREQ)", Interfaces.Integer_32 (C.Freq_Ref), 5600, 5900, UInt16, Step => 0,
                         Flags => Dynamic));
      Add (M, N, Choice ("POWER", Interfaces.Integer_32 (C.Power), Interfaces.Integer_32 (Run.Power_Levels),
                         Power_Name (Run, Natural (C.Power)), Has_Func => True));
   end Add_VTX_Lines;

   procedure Load_VTX_MSP_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add_VTX_Lines (M, N, "- MSP -", T.MSP_Status, T.MSP, T.VTX_Table);
      Add (M, N, Sub ("SAVE", VTX_MSP_Confirm));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_VTX_MSP_Menu;

   procedure Load_VTX_Tramp_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add_VTX_Lines (M, N, "- TRAMP -", T.Tramp_Status, T.Tramp, T.VTX_Table);
      Add (M, N, Number ("T(C)", Interfaces.Integer_32 (T.Tramp_Temp), -100, 300, Int16, Step => 0, Flags => Dynamic));
      Add (M, N, Sub ("SAVE&EXIT", VTX_Tramp_Confirm));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_VTX_Tramp_Menu;

   --  The SmartAudio menu's lines: the title, the status line, and offline
   --  the statistics, else the band, channel and band and channel's
   --  frequency or the user frequency, the power and pit mode, the save and
   --  the configuration.
   procedure Load_SA_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      V : Adaflight.SmartAudio.Menu_View renames T.VTX.SA_Menu;
      function U8 (X : Interfaces.Unsigned_8) return Interfaces.Integer_32 is (Interfaces.Integer_32 (X));
   begin
      M := Empty_Table;
      Add (M, N, Make ((if T.SA_Top = Offline_Lines then "- VTX SMARTAUDIO -" else "- SMARTAUDIO -"), Label));
      Add (M, N, Text_Line ("", Label, C_Text (V.Status), Flags => Dynamic));
      case T.SA_Top is
         when Offline_Lines =>
            Add (M, N, Sub ("STATX", SA_Stats_Menu));
         when Channel_Lines | Frequency_Lines =>
            if T.SA_Top = Channel_Lines then
               Add (M, N, Choice ("BAND", U8 (V.Band), Interfaces.Integer_32 (T.VTX_Table.Bands),
                                  Band_Name (T.VTX_Table, Natural (V.Band)), Has_Func => True));
               Add (M, N, Choice ("CHAN", U8 (V.Channel), Interfaces.Integer_32 (T.VTX_Table.Channels),
                                  Channel_Name (T.VTX_Table, Natural (V.Channel)), Has_Func => True));
               Add (M, N, Number ("(FREQ)", Interfaces.Integer_32 (V.Freq_Ref), 5600, 5900, UInt16, Step => 0,
                                  Flags => Dynamic));
            else
               Add (M, N, Make ("FREQ", Submenu, Has_Func => True, Has_Data => True,
                                Value => Interfaces.Integer_32 (SA_User_Freq_Menu), Flags => Opt_String));
            end if;
            Add (M, N, Choice ("POWER", U8 (V.Power), Interfaces.Integer_32 (T.VTX_Table.Power_Levels),
                               Power_Name (T.VTX_Table, Natural (V.Power)), Flags => Dynamic, Has_Func => True));
            Add (M, N, Choice ("PIT", U8 (V.Pit), 2, Pit_Mode_Name (Natural (V.Pit)), Flags => Dynamic,
                               Has_Func => True));
            Add (M, N, Sub ("SAVE&EXIT", SA_Confirm_Menu));
            Add (M, N, Sub ("CONFIG", SA_Config_Menu));
      end case;
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_SA_Menu;

   procedure Load_SA_Config_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      V : Adaflight.SmartAudio.Menu_View renames T.VTX.SA_Menu;
      function U8 (X : Interfaces.Unsigned_8) return Interfaces.Integer_32 is (Interfaces.Integer_32 (X));
   begin
      M := Empty_Table;
      Add (M, N, Make ("- SA CONFIG -", Label));
      Add (M, N, Choice ("OP MODEL", U8 (V.Opmodel), 2, SA_Opmodel_Name (Natural (V.Opmodel)), Flags => Dynamic,
                         Has_Func => True));
      Add (M, N, Choice ("FSEL MODE", U8 (V.Fsel_Mode_New), 1, SA_Fsel_Name (Natural (V.Fsel_Mode_New)),
                         Flags => Dynamic, Has_Func => True));
      Add (M, N, Choice ("PIT FMODE", U8 (V.Pit_F_Mode), 1, SA_Pit_F_Mode_Name (Natural (V.Pit_F_Mode)),
                         Has_Func => True));
      Add (M, N, Make ("POR FREQ", Submenu, Has_Func => True, Has_Data => True,
                       Value => Interfaces.Integer_32 (SA_POR_Freq_Menu), Flags => Opt_String));
      Add (M, N, Sub ("STATX", SA_Stats_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_SA_Config_Menu;

   procedure Load_SA_Stats_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      S : Adaflight.SmartAudio.Stats renames T.VTX.SA.Stat;
      function Count (Text : String; X : Interfaces.Unsigned_16) return Line is
        (Number (Text, Interfaces.Integer_32 (X), 0, 0, UInt16, Step => 0, Flags => Dynamic))
        with Pre => Text'Length <= Adaflight.Menu.Max_Text;
   begin
      M := Empty_Table;
      Add (M, N, Make ("- SA STATS -", Label));
      Add (M, N, Choice ("STATUS", Interfaces.Integer_32 (T.VTX.SA_Menu.Device_Status), 3,
                         SA_Status_Name (Natural (T.VTX.SA_Menu.Device_Status)), Flags => Dynamic));
      Add (M, N, Count ("BAUDRATE", Adaflight.SmartAudio.Rate_Of (T.VTX.SA.Smart_Baud)));
      Add (M, N, Count ("SENT", S.Sent));
      Add (M, N, Count ("RCVD", S.Received));
      Add (M, N, Count ("BADPRE", S.Bad_Preamble));
      Add (M, N, Count ("BADLEN", S.Bad_Length));
      Add (M, N, Count ("CRCERR", S.Crc_Errors));
      Add (M, N, Count ("OOOERR", S.Out_Of_Order));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_SA_Stats_Menu;

   --  The SmartAudio pit or user frequency menu: the frequency, its new
   --  value and the save.
   procedure Load_SA_Freq_Menu (Title : String; Current, New_Value : Interfaces.Unsigned_16; M : out Table)
     with Pre  => Title'Length <= Adaflight.Menu.Max_Text,
          Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make (Title, Label));
      Add (M, N, Number ("CUR FREQ", Interfaces.Integer_32 (Current), 5000, 5999, UInt16, Step => 0, Flags => Dynamic));
      Add (M, N, Number ("NEW FREQ", Interfaces.Integer_32 (New_Value), 5000, 5999, UInt16));
      Add (M, N, Make ("SAVE", Funcall, Has_Func => True));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_SA_Freq_Menu;

   procedure Load_SA_Confirm_Menu (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("CONFIRM", Label));
      Add (M, N, Make ("YES", OSD_Exit, Has_Func => True, Has_Data => True, Value => 0));
      Add (M, N, Make ("NO", Back));
      M.Count := N;
   end Load_SA_Confirm_Menu;

   procedure Load_VTX_Tramp_Confirm (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("CONFIRM", Label));
      Add (M, N, Make ("YES", OSD_Exit, Has_Func => True, Has_Data => True, Value => 0));
      Add (M, N, Make ("NO", Back));
      M.Count := N;
   end Load_VTX_Tramp_Confirm;

   procedure Load_VTX_MSP_Confirm (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("CONFIRM", Label));
      Add (M, N, Make ("YES", Funcall, Has_Func => True));
      Add (M, N, Make ("NO", Back));
      M.Count := N;
   end Load_VTX_MSP_Confirm;

   procedure Load_Power_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         P : Power_Copies renames T.Power;
      begin
         Add (M, N, Make ("-- POWER --", Label));
         Add (M, N, Choice ("V METER", Interfaces.Integer_32 (P.Voltage_Meter_Source), 2,
                      Voltage_Meter_Name (Natural (P.Voltage_Meter_Source)), Reboot));
         Add (M, N, Choice ("I METER", Interfaces.Integer_32 (P.Current_Meter_Source), 4,
                      Current_Meter_Name (Natural (P.Current_Meter_Source)), Reboot));
         Add (M, N, Number ("VBAT CLMIN", Interfaces.Integer_32 (P.Min_Cell_Voltage), 100, 500, UInt16));
         Add (M, N, Number ("VBAT CLMAX", Interfaces.Integer_32 (P.Max_Cell_Voltage), 100, 500, UInt16));
         Add (M, N, Number ("VBAT CLWARN", Interfaces.Integer_32 (P.Warning_Cell_Voltage), 100, 500, UInt16));
         Add (M, N, Number ("VBAT SCALE", Interfaces.Integer_32 (P.Voltage_Scale), 0, 255));
         Add (M, N, Number ("IBAT SCALE", Interfaces.Integer_32 (P.Current_Scale), -16_000, 16_000, Int16, 5));
         Add (M, N, Number ("IBAT OFFSET", Interfaces.Integer_32 (P.Current_Offset), -32_000, 32_000, Int16, 5));
         Add (M, N,
              Number ("IBAT VIRT SCALE", Interfaces.Integer_32 (P.Virtual_Scale), -16_000, 16_000, Int16, 5));
         Add (M, N, Number ("IBAT VIRT OFFSET", Interfaces.Integer_32 (P.Virtual_Offset), 0, 16_000, UInt16, 5));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Power_Menu;

   procedure Load_Failsafe_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- FAILSAFE --", Label));
      Add (M, N, Choice ("PROCEDURE", Interfaces.Integer_32 (T.Failsafe.Procedure_Kind), 2,
                   Procedure_Name (Natural (T.Failsafe.Procedure_Kind)), Reboot));
      Add (M, N, Fixed_Number ("GUARD TIME", Interfaces.Integer_32 (T.Failsafe.Guard_Time), 1, 200, 100, Reboot));
      Add (M, N,
           Number ("LANDING_TIME", Interfaces.Integer_32 (T.Failsafe.Landing_Time), 0, 250, Flags => Reboot));
      Add (M, N, Number ("STAGE 2 THROTTLE", Interfaces.Integer_32 (T.Failsafe.Throttle), 750, 2250, UInt16,
                   Flags => Reboot));
      Add (M, N, Sub ("GPS RESCUE", GPS_Rescue_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Failsafe_Menu;

   procedure Load_GPS_Rescue_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      R : Rescue_Copies renames T.Rescue;
      function U16 (V : Interfaces.Unsigned_16) return Interfaces.Integer_32 is (Interfaces.Integer_32 (V));
      function U8 (V : Interfaces.Unsigned_8) return Interfaces.Integer_32 is (Interfaces.Integer_32 (V));
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- GPS RESCUE ---", Label));
      Add (M, N, Number ("MIN START DIST  M", U16 (R.Min_Start_Dist_M), 5, 30, UInt16, Flags => Reboot));
      Add (M, N, Choice ("ALTITUDE MODE", U8 (R.Altitude_Mode), 2,
                         Setting_Name (Adaflight.Settings_Table.Table_Gps_Rescue_Alt_Mode, Natural (R.Altitude_Mode)),
                         Reboot));
      Add (M, N, Number ("INITAL CLIMB    M", U16 (R.Initial_Climb_M), 0, 100, UInt16, Flags => Reboot));
      Add (M, N, Number ("ASCEND RATE  CM/S", U16 (R.Ascend_Rate), 50, 2500, UInt16, Flags => Reboot));
      Add (M, N, Number ("RETURN ALT      M", U16 (R.Return_Altitude_M), 5, 1000, UInt16, Flags => Reboot));
      Add (M, N, Number ("RETURN SPEED CM/S", U16 (R.Ground_Speed_Cm_S), 0, 3000, UInt16, Flags => Reboot));
      Add (M, N, Number ("PITCH ANGLE MAX", U8 (R.Max_Angle), 0, 60, Flags => Reboot));
      Add (M, N, Number ("DESCENT DIST    M", U16 (R.Descent_Distance_M), 5, 500, UInt16, Flags => Reboot));
      Add (M, N, Number ("DESCENT RATE CM/S", U16 (R.Descend_Rate), 25, 500, UInt16, Flags => Reboot));
      Add (M, N, Number ("LANDING ALT     M", U8 (R.Landing_Altitude_M), 1, 15, Flags => Reboot));
      Add (M, N, Number ("THROTTLE MIN", U16 (R.Throttle_Min), 1050, 1400, UInt16, Flags => Reboot));
      Add (M, N, Number ("THROTTLE MAX", U16 (R.Throttle_Max), 1400, 2000, UInt16, Flags => Reboot));
      Add (M, N, Number ("THROTTLE HOV", U16 (R.Hover_Throttle), 1100, 1700, UInt16, Flags => Reboot));
      Add (M, N, Number ("SATS REQUIRED", U8 (R.Min_Sats), 5, 50, Flags => Reboot));
      Add (M, N, Make ("ARM WITHOUT FIX", Bool, Has_Data => True, Value => U8 (R.Allow_Arming_Without_Fix),
                       Flags => Reboot));
      Add (M, N, Sub ("GPS RESCUE PID", GPS_Rescue_PID_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_GPS_Rescue_Menu;

   procedure Load_GPS_Rescue_PID_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      P : Rescue_PID_Copies renames T.Rescue_PID;
      function U8 (V : Interfaces.Unsigned_8) return Interfaces.Integer_32 is (Interfaces.Integer_32 (V));
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- GPS RESCUE PID---", Label));
      Add (M, N, Number ("ALTITUDE P", U8 (P.Altitude_P), 0, 200, Flags => Reboot));
      Add (M, N, Number ("ALTITUDE I", U8 (P.Altitude_I), 0, 200, Flags => Reboot));
      Add (M, N, Number ("ALTITUDE D", U8 (P.Altitude_D), 0, 200, Flags => Reboot));
      Add (M, N, Number ("ALTITUDE A", U8 (P.Altitude_A), 0, 200, Flags => Reboot));
      Add (M, N, Number ("ALTITUDE F", U8 (P.Altitude_F), 0, 200, Flags => Reboot));
      Add (M, N, Number ("YAW P", U8 (P.Yaw_P), 0, 200, Flags => Reboot));
      Add (M, N, Number ("POSITION P", U8 (P.Position_P), 0, 200, Flags => Reboot));
      Add (M, N, Number ("POSITION I", U8 (P.Position_I), 0, 200, Flags => Reboot));
      Add (M, N, Number ("POSITION D", U8 (P.Position_D), 0, 200, Flags => Reboot));
      Add (M, N, Number ("SMOOTHING", U8 (P.Position_Cutoff), 10, 255, Flags => Reboot));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_GPS_Rescue_PID_Menu;

   procedure Load_RPM_Limit_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- RPM LIMIT --", Label));
      Add (M, N,
           Make ("ACTIVE", Bool, Has_Data => True, Value => Boolean'Pos (T.RPM_Limit.Active), Flags => Reboot));
      Add (M, N, Number ("MAX RPM", Interfaces.Integer_32 (T.RPM_Limit.Limit), 0, 65_535, UInt16, 100));
      Add (M, N, Number ("KV", Interfaces.Integer_32 (T.RPM_Limit.KV), 0, 65_535, UInt16));
      Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_RPM_Limit_Menu;

   procedure Load_Misc_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- MISC --", Label));
      Add (M, N, Number ("IDLE OFFSET", Interfaces.Integer_32 (T.Misc.Idle_Offset), 0, 200, Flags => Reboot));
      Add (M, N, Number ("FPV CAM ANGLE", Interfaces.Integer_32 (T.Misc.FPV_Cam_Angle), 0, 90));
      Add (M, N,
           Number ("CRASHFLIP RATE", Interfaces.Integer_32 (T.Misc.Crashflip_Rate), 0, 100, Flags => Reboot));
      Add (M, N, Sub ("RC PREV", RC_Preview_Menu));
      Add (M, N, Sub ("GPS LAP TIMER", GPS_Lap_Timer_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Misc_Menu;

   procedure Load_RC_Preview_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- RC PREV --", Label));
      for C in RC_Values'Range loop
         pragma Loop_Invariant
           (N = C + 1
            and then (for all I in 0 .. N - 1 =>
                        (if Element_Of (M.Lines (I).Flags) = Fixed then M.Lines (I).Value in 0 .. 255)));
         Add (M, N, Number (RC_Names (C) (1 .. RC_Name_Lengths (C)),
                      Interfaces.Integer_32 (T.Preview (RC_Line_Channels (C))), 1, 2500, Int16, 0, Dynamic));
      end loop;
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_RC_Preview_Menu;

   procedure Load_Persistent_Stats_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- PERSISTENT STATS --", Label));
      Add (M, N, Number ("FLIGHTS", Signed_Word (T.Stats.Total_Flights), 0, -1, UInt32));
      Add (M, N, Number ("TIME(sec)", Signed_Word (T.Stats.Total_Time_S), 0, -1, UInt32));
      Add (M, N, Number ("DIST(m)", Signed_Word (T.Stats.Total_Dist_M), 0, -1, UInt32));
      Add (M, N, Make ("RESET STATS", Funcall, Has_Func => True));
      Add (M, N, Make ("--- SETTINGS ---", Label));
      Add (M, N, Number ("MIN ARMED TIME(sec)", Interfaces.Integer_32 (T.Stats.Min_Armed_Time), -1, 127, Int8));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Persistent_Stats_Menu;

   procedure Load_GPS_Lap_Timer_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- GPS LAP TIMER ---", Label));
      Add (M, N, Sub ("SET POSITION", Set_Gate_Menu));
      Add (M, N, Number ("GATE RADIUS(M)", Interfaces.Integer_32 (T.Lap.Gate_Tolerance), 1, 100));
      Add (M, N, Number ("MIN LAP SECONDS", Interfaces.Integer_32 (T.Lap.Minimum_Lap_Time), 0, 3000, UInt16));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_GPS_Lap_Timer_Menu;

   procedure Load_Set_Gate_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("SETTING POSITION", Label));
      Add (M, N,
           Number ("READINGS", Interfaces.Integer_32 (T.Live.Gate_Set_Readings), 0, 2000, UInt16, 0, Dynamic));
      Add (M, N, Number ("DISTANCE(CM)", Signed_Word (T.Live.Gate_Distance_Cm), 0, 200, UInt32, 0, Dynamic));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Set_Gate_Menu;

   procedure Load_Blackbox_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         B : Blackbox_Copies renames T.Blackbox;
      begin
         Add (M, N, Make ("-- BLACKBOX --", Label));
         Add (M, N, Text_Line ("(PID FREQ)", Str, B.PID_Frequency));
         Add (M, N,
              Choice ("SAMPLERATE", Interfaces.Integer_32 (B.Rate), 4, Blackbox_Rate_Name (Natural (B.Rate)),
                      Reboot));
         Add (M, N,
              Choice ("DEVICE", Interfaces.Integer_32 (B.Device), 3, Blackbox_Device_Name (Natural (B.Device)),
                      Reboot));
         Add (M, N, Text_Line ("(STATUS)", Str, B.Status));
         Add (M, N, Text_Line ("(USED)", Str, B.Used));
         Add (M, N, Text_Line ("(FREE)", Str, B.Free));
         Add (M, N,
              Choice ("DEBUG MODE", Interfaces.Integer_32 (B.Debug_Mode), Interfaces.Integer_32 (Debug_Count) - 1,
                      Debug_Name (Natural (B.Debug_Mode)), Reboot));
         Add (M, N, Sub ("USB MASS STORAGE", Storage_Device_Menu));
         Add (M, N, Sub ("ERASE FLASH", Erase_Flash_Menu));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Blackbox_Menu;

   procedure Load_Erase_Flash_Menu (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("CONFIRM ERASE", Label));
      Add (M, N, Make ("NO", Back));
      Add (M, N, Make ("YES", Funcall, Has_Func => True));
      M.Count := N;
   end Load_Erase_Flash_Menu;

   procedure Load_Storage_Device_Menu (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("CONFIRM USB MASS STORAGE", Label));
      Add (M, N, Make ("NO", Back));
      Add (M, N, Make ("YES", Funcall, Has_Func => True));
      M.Count := N;
   end Load_Storage_Device_Menu;

   procedure Load_LED_Strip_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         L : LED_Copies renames T.LED;
      begin
         Add (M, N, Make ("-- LED STRIP --", Label));
         Add (M, N, Make ("ENABLED", Bool, Has_Data => True, Value => Interfaces.Integer_32 (L.Enabled)));
         Add (M, N, Choice ("PROFILE", Interfaces.Integer_32 (L.Profile), LED_Profile_Count - 1,
                      LED_Profile_Name (Natural (L.Profile))));
         Add (M, N, Choice ("RACE COLOR", Interfaces.Integer_32 (L.Race_Color), LED_Color_Count - 1,
                      LED_Color_Name (Natural (L.Race_Color))));
         Add (M, N, Choice ("BEACON COLOR", Interfaces.Integer_32 (L.Beacon_Color), LED_Color_Count - 1,
                      LED_Color_Name (Natural (L.Beacon_Color))));
         Add (M, N, Number ("BEACON PERIOD", Interfaces.Integer_32 (L.Beacon_Period), 50, 10_000, UInt16, 10));
         Add (M, N, Number ("BEACON ON %", Interfaces.Integer_32 (L.Beacon_On_Percent), 0, 100));
         Add (M, N, Make ("BEACON ARMED ONLY", Bool, Has_Data => True,
                    Value => Interfaces.Integer_32 (L.Beacon_Armed_Only)));
         Add (M, N,
              Make ("VISUAL BEEPER", Bool, Has_Data => True, Value => Interfaces.Integer_32 (L.Visual_Beeper)));
         Add (M, N, Choice ("VISUAL COLOR", Interfaces.Integer_32 (L.Visual_Beeper_Color), LED_Color_Count - 1,
                      LED_Color_Name (Natural (L.Visual_Beeper_Color))));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_LED_Strip_Menu;

   procedure Load_Firmware_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- INFO ---", Label));
      Add (M, N, Text_Line ("FWID", Str, T.Identity.Identifier));
      Add (M, N, Text_Line ("FWVER", Str, T.Identity.Version));
      Add (M, N, Text_Line ("GITREV", Str, T.Identity.Revision));
      Add (M, N, Text_Line ("TARGET", Str, T.Identity.Target_Name));
      Add (M, N, Text_Line ("MFR", Str, T.Board.Manufacturer_Id));
      Add (M, N, Text_Line ("BOARD", Str, T.Board.Board_Name));
      Add (M, N, Make ("--- SETUP ---", Label));
      Add (M, N, Sub ("CALIBRATE", Calibration_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Firmware_Menu;

   procedure Load_Calibration_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- CALIBRATE ---", Label));
      Add (M, N, Text_Line ("GYRO", Funcall, T.Calibration.Gyro, Has_Func => True, Flags => Dynamic));
      Add (M, N, Text_Line ("ACC", Funcall, T.Calibration.Acc, Has_Func => True, Flags => Dynamic));
      Add (M, N, Text_Line ("BARO", Funcall, T.Calibration.Baro, Has_Func => True, Flags => Dynamic));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Calibration_Menu;

   procedure Load_Calibrate_Acc_Menu (M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- CALIBRATE ACC ---", Label));
      Add (M, N, Make ("PLACE ON A LEVEL SURFACE", Label));
      Add (M, N, Make ("MAKE SURE CRAFT IS STILL", Label));
      Add (M, N, Make (" ", Label));
      Add (M, N, Make ("START CALIBRATION", Funcall, Has_Func => True));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Calibrate_Acc_Menu;

   procedure Load_OSD_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("---OSD---", Label));
      Add (M, N, Number ("OSD PROFILE", Interfaces.Integer_32 (T.OSD.Profile), 1, 3));
      Add (M, N, Sub ("ACTIVE ELEM", Active_Elements_Menu));
      Add (M, N, Sub ("TIMERS", Timers_Menu));
      Add (M, N, Sub ("ALARMS", Alarms_Menu));
      Add (M, N, Make ("INVERT", Bool, Has_Func => True, Has_Data => True, Value => Boolean'Pos (T.OSD.Invert)));
      Add (M, N, Number ("BRT BLACK", Interfaces.Integer_32 (T.OSD.Black_Brightness), 0, 3, Has_Func => True));
      Add (M, N, Number ("BRT WHITE", Interfaces.Integer_32 (T.OSD.White_Brightness), 0, 3, Has_Func => True));
      Add (M, N, Choice ("BACKGROUND", Interfaces.Integer_32 (T.OSD.Background), 3,
                         Background_Name (Natural (T.OSD.Background)), Has_Func => True));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_OSD_Menu;

   procedure Load_Active_Elements_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- ACTIV ELEM ---", Label));
      for K in Active_Lines'Range loop
         pragma Loop_Invariant (N = K and then Fixed_Below (M, N));
         Add (M, N,
              (Text     => Active_Lines (K).Name,
               Flags    => Code (Visible) or Dynamic,
               Has_Data => True,
               Value    =>
                 Interfaces.Integer_32 (T.Elements (Adaflight.OSD_Elements.Item'Pos (Active_Lines (K).Item))),
               others   => <>));
      end loop;
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Active_Elements_Menu;

   procedure Load_Timers_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("--- TIMERS ---", Label));
      for I in Timer_Fields'Range loop
         pragma Loop_Invariant (N = 1 + 3 * I and then Fixed_Below (M, N));
         Add (M, N, Choice ((if I = 0 then "1 SRC" else "2 SRC"), Interfaces.Integer_32 (T.Timers.Source (I)), 4,
                            Timer_Source_Name (Natural (T.Timers.Source (I)))));
         Add (M, N, Choice ((if I = 0 then "1 PREC" else "2 PREC"),
                            Interfaces.Integer_32 (T.Timers.Precision (I)), 2,
                            Timer_Precision_Name (Natural (T.Timers.Precision (I)))));
         Add (M, N, Number ((if I = 0 then "1 ALARM" else "2 ALARM"), Interfaces.Integer_32 (T.Timers.Alarm (I)),
                            0, 255));
      end loop;
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Timers_Menu;

   procedure Load_Alarms_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         A : Alarm_Copies renames T.Alarms;
      begin
         Add (M, N, Make ("--- ALARMS ---", Label));
         Add (M, N, Number ("RSSI", Interfaces.Integer_32 (A.RSSI), 5, 90, Step => 5));
         Add (M, N, Number ("LINK QUALITY", Interfaces.Integer_32 (A.Link_Quality), 5, 300, UInt16, 5));
         Add (M, N, Number ("RSSI DBM", Interfaces.Integer_32 (A.RSSI_Dbm), -130, 20, Int16, 5));
         Add (M, N, Number ("RSNR", Interfaces.Integer_32 (A.RSNR), -30, 20, Int16, 5));
         Add (M, N, Number ("MAIN BAT", Interfaces.Integer_32 (A.Capacity), 50, 30_000, UInt16, 50));
         Add (M, N, Number ("MAX ALT", Interfaces.Integer_32 (A.Altitude), 1, 200, UInt16));
         Add (M, N, Number ("MAX DISTANCE", Interfaces.Integer_32 (A.Distance), 0, 65_535, UInt16, 10));
         Add (M, N, Number ("VBAT WARN DUR", Interfaces.Integer_32 (A.Warning_Duration), 0, 200));
         Add (M, N, Number ("VBAT CRIT DUR", Interfaces.Integer_32 (A.Critical_Duration), 0, 200));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Alarms_Menu;

   procedure Load_Profile_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- PROFILE --", Label));
      Add (M, N, Choice ("PID PROF", Interfaces.Integer_32 (T.Profile.PID_Line), PID_Profile_Count - 1,
                         Profile_Name (T.Profile.PID_Names, Natural (T.Profile.PID_Line)), Has_Func => True));
      Add (M, N, Sub ("PID", PID_Menu));
      Add (M, N, Sub ("SIMPLIFIED TUNING", Simplified_Menu));
      Add (M, N, Sub ("MISC PP", Profile_Other_Menu));
      Add (M, N, Sub ("FILT PP", Filter_Profile_Menu));
      Add (M, N, Choice ("RATE PROF", Interfaces.Integer_32 (T.Profile.Rate_Line), Rate_Profile_Count - 1,
                         Profile_Name (T.Profile.Rate_Names, Natural (T.Profile.Rate_Line)), Has_Func => True));
      Add (M, N, Sub ("RATE", Rate_Menu));
      Add (M, N, Sub ("FILT GLB", Filter_Global_Menu));
      Add (M, N, Sub ("DYN FILT", Dynamic_Filter_Menu));
      Add (M, N, Sub ("COPY PROF", Copy_Profile_Menu));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Profile_Menu;

   procedure Load_PID_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         G : Gain_Table renames T.PID.Gains;
         F : Feedforward_Table renames T.PID.Feedforward;
      begin
         Add (M, N, Text_Line ("-- PID --", Label, T.PID.Profile_Text));
         Add (M, N, Number ("ROLL  P", Interfaces.Integer_32 (G (0, 0)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("ROLL  I", Interfaces.Integer_32 (G (0, 1)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("ROLL  D", Interfaces.Integer_32 (G (0, 2)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("ROLL  F", Interfaces.Integer_32 (F (0)), 0, 2000, UInt16, Flags => Slider_RP));
         Add (M, N, Number ("PITCH P", Interfaces.Integer_32 (G (1, 0)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("PITCH I", Interfaces.Integer_32 (G (1, 1)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("PITCH D", Interfaces.Integer_32 (G (1, 2)), 0, 200, Flags => Slider_RP));
         Add (M, N, Number ("PITCH F", Interfaces.Integer_32 (F (1)), 0, 2000, UInt16, Flags => Slider_RP));
         Add (M, N, Number ("YAW   P", Interfaces.Integer_32 (G (2, 0)), 0, 200, Flags => Slider_RPY));
         Add (M, N, Number ("YAW   I", Interfaces.Integer_32 (G (2, 1)), 0, 200, Flags => Slider_RPY));
         Add (M, N, Number ("YAW   D", Interfaces.Integer_32 (G (2, 2)), 0, 200, Flags => Slider_RPY));
         Add (M, N, Number ("YAW   F", Interfaces.Integer_32 (F (2)), 0, 2000, UInt16, Flags => Slider_RPY));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_PID_Menu;

   procedure Load_Rate_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         R : Adaflight.Config_Groups.Control_Rate_Config_Record renames T.Rate.Profile;
      begin
         Add (M, N, Text_Line ("-- RATE --", Label, T.Rate.Profile_Text));
         Add (M, N, Fixed_Number ("RC R RATE", Interfaces.Integer_32 (R.Rc_Rates (0)), 1, 255, 10));
         Add (M, N, Fixed_Number ("RC P RATE", Interfaces.Integer_32 (R.Rc_Rates (1)), 1, 255, 10));
         Add (M, N, Fixed_Number ("RC Y RATE", Interfaces.Integer_32 (R.Rc_Rates (2)), 1, 255, 10));
         Add (M, N, Fixed_Number ("ROLL SUPER", Interfaces.Integer_32 (R.Rates (0)), 0, 255, 10));
         Add (M, N, Fixed_Number ("PITCH SUPER", Interfaces.Integer_32 (R.Rates (1)), 0, 255, 10));
         Add (M, N, Fixed_Number ("YAW SUPER", Interfaces.Integer_32 (R.Rates (2)), 0, 255, 10));
         Add (M, N, Fixed_Number ("RC R EXPO", Interfaces.Integer_32 (R.Rc_Expo (0)), 0, 100, 10));
         Add (M, N, Fixed_Number ("RC P EXPO", Interfaces.Integer_32 (R.Rc_Expo (1)), 0, 100, 10));
         Add (M, N, Fixed_Number ("RC Y EXPO", Interfaces.Integer_32 (R.Rc_Expo (2)), 0, 100, 10));
         Add (M, N, Number ("THR MID", Interfaces.Integer_32 (R.Thr_Mid8), 0, 100));
         Add (M, N, Number ("THR EXPO", Interfaces.Integer_32 (R.Thr_Expo8), 0, 100));
         Add (M, N, Number ("THR HOVER", Interfaces.Integer_32 (R.Thr_Hover8), 0, 100));
         Add (M, N, Choice ("THR LIM TYPE", Interfaces.Integer_32 (R.Throttle_Limit_Type), 2,
                            Throttle_Limit_Name (Natural (R.Throttle_Limit_Type))));
         Add (M, N, Number ("THR LIM %", Interfaces.Integer_32 (R.Throttle_Limit_Percent), 25, 100));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Rate_Menu;

   procedure Load_Simplified_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         S : Simplified_Copies renames T.Simplified;
      begin
         Add (M, N, Make ("-- SIMPLIFIED PID --", Label));
         Add (M, N, Choice ("PID TUNING", Interfaces.Integer_32 (S.Mode), 2,
                            Setting_Name (Adaflight.Settings_Table.Table_Simplified_Tuning_Pids_Mode,
                                          Natural (S.Mode))));
         Add (M, N, Make ("-- BASIC --", Label));
         Add (M, N, Fixed_Number ("D GAINS", Interfaces.Integer_32 (S.D_Gain), 0, 200, 10, Step => 5));
         Add (M, N, Fixed_Number ("P&I GAINS", Interfaces.Integer_32 (S.PI_Gain), 0, 200, 10, Step => 5));
         Add (M, N, Fixed_Number ("FF GAINS", Interfaces.Integer_32 (S.FF_Gain), 0, 200, 10, Step => 5));
         Add (M, N, Make ("-- EXPERT --", Label));
         Add (M, N, Fixed_Number ("D MAX", Interfaces.Integer_32 (S.D_Max_Gain), 0, 200, 10, Step => 5));
         Add (M, N, Fixed_Number ("I GAINS", Interfaces.Integer_32 (S.I_Gain), 0, 200, 10, Step => 5));
         Add (M, N, Fixed_Number ("PITCH:ROLL D", Interfaces.Integer_32 (S.Roll_Pitch_Ratio), 0, 200, 10,
                                  Step => 5));
         Add (M, N, Fixed_Number ("PITCH:ROLL P,I&FF", Interfaces.Integer_32 (S.Pitch_PI_Gain), 0, 200, 10,
                                  Step => 5));
         Add (M, N, Fixed_Number ("MASTER MULT", Interfaces.Integer_32 (S.Master), 0, 200, 10, Step => 5));
         Add (M, N, Make ("-- SIMPLIFIED FILTER --", Label));
         Add (M, N, Choice ("GYRO TUNING", Interfaces.Integer_32 (S.Gyro_Filter), 1,
                            Setting_Name (Adaflight.Settings_Table.Table_Off_On, Natural (S.Gyro_Filter))));
         Add (M, N, Fixed_Number ("GYRO MULT", Interfaces.Integer_32 (S.Gyro_Multiplier), 10, 200, 10,
                                  Step => 5));
         Add (M, N, Choice ("DTERM TUNING", Interfaces.Integer_32 (S.DTerm_Filter), 1,
                            Setting_Name (Adaflight.Settings_Table.Table_Off_On, Natural (S.DTerm_Filter))));
         Add (M, N, Fixed_Number ("DTERM MULT", Interfaces.Integer_32 (S.DTerm_Multiplier), 10, 200, 10,
                                  Step => 5));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Simplified_Menu;

   procedure Load_Profile_Other_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         O : Other_Copies renames T.Other;
      begin
         Add (M, N, Text_Line ("-- OTHER PP --", Label, T.PID.Profile_Text));
         Add (M, N, Fixed_Number ("FF TRANSITION", Interfaces.Integer_32 (O.FF_Transition), 0, 100, 10));
         Add (M, N, Choice ("FF AVERAGING", Interfaces.Integer_32 (O.FF_Averaging), 4,
                            Setting_Name (Adaflight.Settings_Table.Table_Feedforward_Averaging,
                                          Natural (O.FF_Averaging))));
         Add (M, N, Number ("FF SMOOTHNESS", Interfaces.Integer_32 (O.FF_Smooth), 0, 95));
         Add (M, N, Number ("FF JITTER", Interfaces.Integer_32 (O.FF_Jitter), 0, 20));
         Add (M, N, Number ("FF BOOST", Interfaces.Integer_32 (O.FF_Boost), 0, 50));
         Add (M, N, Number ("ANGLE P", Interfaces.Integer_32 (O.Angle_P), 0, 200));
         Add (M, N, Number ("ANGLE FF", Interfaces.Integer_32 (O.Angle_FF), 0, 200));
         Add (M, N, Number ("ANGLE LIMIT", Interfaces.Integer_32 (O.Angle_Limit), 10, 90));
         Add (M, N, Number ("ANGLE E_REF", Interfaces.Integer_32 (O.Angle_Earth_Ref), 0, 100));
         Add (M, N, Number ("HORZN STR", Interfaces.Integer_32 (O.Horizon_Strength), 0, 100));
         Add (M, N, Number ("HORZN LIM_STK", Interfaces.Integer_32 (O.Horizon_Sticks), 10, 200));
         Add (M, N, Number ("HORZN LIM_DEG", Interfaces.Integer_32 (O.Horizon_Degrees), 10, 250));
         Add (M, N, Fixed_Number ("AG GAIN", Interfaces.Integer_32 (O.Anti_Gravity_Gain), 0, 250, 100));
         Add (M, N, Number ("THR BOOST", Interfaces.Integer_32 (O.Throttle_Boost), 0, 100));
         Add (M, N, Number ("THR LINEAR", Interfaces.Integer_32 (O.Thrust_Linearization), 0, 150));
         Add (M, N, Choice ("I_RELAX", Interfaces.Integer_32 (O.Iterm_Relax), 4,
                            Setting_Name (Adaflight.Settings_Table.Table_Iterm_Relax, Natural (O.Iterm_Relax))));
         Add (M, N, Choice ("I_RELAX TYPE", Interfaces.Integer_32 (O.Iterm_Relax_Type), 1,
                            Setting_Name (Adaflight.Settings_Table.Table_Iterm_Relax_Type,
                                          Natural (O.Iterm_Relax_Type))));
         Add (M, N, Number ("I_RELAX CUTOFF", Interfaces.Integer_32 (O.Iterm_Relax_Cutoff), 1, 50));
         Add (M, N, Sub ("LAUNCH CONTROL", Launch_Control_Menu));
         Add (M, N, Number ("MTR OUT LIM %", Interfaces.Integer_32 (O.Motor_Output_Limit), 1, 100));
         Add (M, N, Number ("AUTO CELL CNT", Interfaces.Integer_32 (O.Auto_Cell_Count), -1, 8, Int8));
         Add (M, N, Number ("D_MAX ROLL", Interfaces.Integer_32 (O.D_Max (0)), 0, 100, Flags => Slider_RP));
         Add (M, N, Number ("D_MAX PITCH", Interfaces.Integer_32 (O.D_Max (1)), 0, 100, Flags => Slider_RP));
         Add (M, N, Number ("D_MAX YAW", Interfaces.Integer_32 (O.D_Max (2)), 0, 100, Flags => Slider_RPY));
         Add (M, N, Number ("D_MAX GAIN", Interfaces.Integer_32 (O.D_Max_Gain), 0, 100));
         Add (M, N, Number ("D_MAX ADV", Interfaces.Integer_32 (O.D_Max_Advance), 0, 200));
         Add (M, N, Number ("VBAT_SAG_COMP", Interfaces.Integer_32 (O.Vbat_Sag), 0, 150));
         Add (M, N, Fixed_Number ("TPA RATE", Interfaces.Integer_32 (O.TPA_Rate), 0, 100, 10));
         Add (M, N, Number ("TPA BRKPT", Interfaces.Integer_32 (O.TPA_Breakpoint), 1000, 2000, UInt16, 10));
         Add (M, N, Number ("TPA LOW RATE", Interfaces.Integer_32 (O.TPA_Low_Rate), 0, 100, Int8));
         Add (M, N, Number ("TPA LOW BRKPT", Interfaces.Integer_32 (O.TPA_Low_Breakpoint), 1000, 2000, UInt16,
                            10));
         Add (M, N, Make ("TPA LOW ALWYS", Bool, Has_Data => True,
                          Value => Interfaces.Integer_32 (O.TPA_Low_Always)));
         Add (M, N, Number ("EZDISARM THR", Interfaces.Integer_32 (O.Landing_Disarm), 0, 150));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Profile_Other_Menu;

   procedure Load_Launch_Control_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      declare
         L : Launch_Copies renames T.Launch;
      begin
         Add (M, N, Text_Line ("-- LAUNCH CONTROL --", Label, T.PID.Profile_Text));
         Add (M, N, Choice ("MODE", Interfaces.Integer_32 (L.Mode), 2,
                            Setting_Name (Adaflight.Settings_Table.Table_Launch_Control_Mode, Natural (L.Mode))));
         Add (M, N, Make ("ALLOW RESET", Bool, Has_Data => True, Value => Interfaces.Integer_32 (L.Allow_Reset)));
         Add (M, N, Number ("TRIGGER THROTTLE", Interfaces.Integer_32 (L.Throttle_Percent), 0, 90));
         Add (M, N, Number ("ANGLE LIMIT", Interfaces.Integer_32 (L.Angle_Limit), 0, 80));
         Add (M, N, Number ("ITERM GAIN", Interfaces.Integer_32 (L.Gain), 0, 200));
         Add (M, N, Make ("BACK", Back));
      end;
      M.Count := N;
   end Load_Launch_Control_Menu;

   Profile_Target_Names : constant array (0 .. 3) of Adaflight.Menu.Label_Text :=
     (Label ("-"), Label ("1"), Label ("2"), Label ("3"));

   function Profile_Target_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 3 then Profile_Target_Names (Index) else Label (""));

   procedure Load_Filter_Profile_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      F : Filter_Profile_Copies renames T.Profile_Flt;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- FILTER PP  --", Label));
      Add (M, N, Number ("DTERM LPF1", Interfaces.Integer_32 (F.DTerm_LPF1), 0, 1000, UInt16, Flags => Slider_DTerm));
      Add (M, N, Number ("DTERM LPF2", Interfaces.Integer_32 (F.DTerm_LPF2), 0, 1000, UInt16, Flags => Slider_DTerm));
      Add (M, N, Number ("DTERM NF", Interfaces.Integer_32 (F.DTerm_Notch_Hz), 0, 1000, UInt16));
      Add (M, N, Number ("DTERM NFCO", Interfaces.Integer_32 (F.DTerm_Notch_Cutoff), 0, 1000, UInt16));
      Add (M, N, Number ("YAW LPF", Interfaces.Integer_32 (F.Yaw_Lowpass), 0, 500, UInt16));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Filter_Profile_Menu;

   procedure Load_Filter_Global_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      G : Filter_Global_Copies renames T.Global_Filt;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- FILTER GLB  --", Label));
      Add (M, N, Number ("GYRO LPF1", Interfaces.Integer_32 (G.Gyro_LPF1), 0, 1000, UInt16, Flags => Slider_Gyro));
      Add (M, N, Number ("GYRO LPF2", Interfaces.Integer_32 (G.Gyro_LPF2), 0, 1000, UInt16, Flags => Slider_Gyro));
      Add (M, N, Number ("GYRO NF1", Interfaces.Integer_32 (G.Notch1_Hz), 0, 500, UInt16));
      Add (M, N, Number ("GYRO NF1C", Interfaces.Integer_32 (G.Notch1_Cutoff), 0, 500, UInt16));
      Add (M, N, Number ("GYRO NF2", Interfaces.Integer_32 (G.Notch2_Hz), 0, 500, UInt16));
      Add (M, N, Number ("GYRO NF2C", Interfaces.Integer_32 (G.Notch2_Cutoff), 0, 500, UInt16));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Filter_Global_Menu;

   procedure Load_Dynamic_Filter_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
      D : Dynamic_Filter_Copies renames T.Dynamic;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- DYN FILT --", Label));
      Add (M, N, Number ("NOTCH COUNT", Interfaces.Integer_32 (D.Notch_Count), 0, 7));
      Add (M, N, Number ("NOTCH Q", Interfaces.Integer_32 (D.Notch_Q), 1, 1000, UInt16));
      Add (M, N, Number ("NOTCH MIN HZ", Interfaces.Integer_32 (D.Notch_Min_Hz), 20, 250, UInt16));
      Add (M, N, Number ("NOTCH MAX HZ", Interfaces.Integer_32 (D.Notch_Max_Hz), 200, 1000, UInt16));
      Add (M, N, Number ("GYRO DLPF MIN", Interfaces.Integer_32 (D.Gyro_Min), 0, 1000, UInt16, Flags => Slider_Gyro));
      Add (M, N, Number ("GYRO DLPF MAX", Interfaces.Integer_32 (D.Gyro_Max), 0, 1000, UInt16, Flags => Slider_Gyro));
      Add (M, N, Number ("GYRO DLPF EXPO", Interfaces.Integer_32 (D.Gyro_Expo), 0, 10));
      Add (M, N, Number ("DTERM DLPF MIN", Interfaces.Integer_32 (D.DTerm_Min), 0, 1000, UInt16,
                         Flags => Slider_DTerm));
      Add (M, N, Number ("DTERM DLPF MAX", Interfaces.Integer_32 (D.DTerm_Max), 0, 1000, UInt16,
                         Flags => Slider_DTerm));
      Add (M, N, Number ("DTERM DLPF EXPO", Interfaces.Integer_32 (D.DTerm_Expo), 0, 10));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Dynamic_Filter_Menu;

   procedure Load_Copy_Profile_Menu (T : Target; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      Add (M, N, Make ("-- COPY PROFILE --", Label));
      Add (M, N, Choice ("CPY PID PROF TO", Interfaces.Integer_32 (T.Copy.PID_Target), 3,
                         Profile_Target_Name (Natural (T.Copy.PID_Target))));
      Add (M, N, Make ("COPY PP", Funcall, Has_Func => True));
      Add (M, N, Choice ("CPY RATE PROF TO", Interfaces.Integer_32 (T.Copy.Rate_Target), 3,
                         Profile_Target_Name (Natural (T.Copy.Rate_Target))));
      Add (M, N, Make ("COPY RP", Funcall, Has_Func => True));
      Add (M, N, Make ("BACK", Back));
      M.Count := N;
   end Load_Copy_Profile_Menu;

   procedure Load (T : Target; Id : Menu_Id; M : out Table) is
   begin
      case Id is
         when Filter_Profile_Menu =>
            Load_Filter_Profile_Menu (T, M);
         when Filter_Global_Menu =>
            Load_Filter_Global_Menu (T, M);
         when Dynamic_Filter_Menu =>
            Load_Dynamic_Filter_Menu (T, M);
         when Copy_Profile_Menu =>
            Load_Copy_Profile_Menu (T, M);
         when Quick_Menu =>
            Load_Quick_Menu (T, M);
         when Main_Menu =>
            Load_Main_Menu (M);
         when Features =>
            Load_Features (M);
         when Setup_Popup =>
            Load_Setup_Popup (T, M);
         when Save_Exit =>
            Load_Save_Exit (M);
         when Save_Exit_Reboot =>
            Load_Save_Exit_Reboot (M);
         when VTX_Error_Menu =>
            Load_VTX_Error_Menu (T, M);
         when Power_Menu =>
            Load_Power_Menu (T, M);
         when Failsafe_Menu =>
            Load_Failsafe_Menu (T, M);
         when GPS_Rescue_Menu =>
            Load_GPS_Rescue_Menu (T, M);
         when GPS_Rescue_PID_Menu =>
            Load_GPS_Rescue_PID_Menu (T, M);
         when RPM_Limit_Menu =>
            Load_RPM_Limit_Menu (T, M);
         when Misc_Menu =>
            Load_Misc_Menu (T, M);
         when RC_Preview_Menu =>
            Load_RC_Preview_Menu (T, M);
         when Persistent_Stats_Menu =>
            Load_Persistent_Stats_Menu (T, M);
         when GPS_Lap_Timer_Menu =>
            Load_GPS_Lap_Timer_Menu (T, M);
         when Set_Gate_Menu =>
            Load_Set_Gate_Menu (T, M);
         when Blackbox_Menu =>
            Load_Blackbox_Menu (T, M);
         when Erase_Flash_Menu =>
            Load_Erase_Flash_Menu (M);
         when Storage_Device_Menu =>
            Load_Storage_Device_Menu (M);
         when LED_Strip_Menu =>
            Load_LED_Strip_Menu (T, M);
         when Firmware_Menu =>
            Load_Firmware_Menu (T, M);
         when Calibration_Menu =>
            Load_Calibration_Menu (T, M);
         when Calibrate_Acc_Menu =>
            Load_Calibrate_Acc_Menu (M);
         when OSD_Menu =>
            Load_OSD_Menu (T, M);
         when Active_Elements_Menu =>
            Load_Active_Elements_Menu (T, M);
         when Timers_Menu =>
            Load_Timers_Menu (T, M);
         when Alarms_Menu =>
            Load_Alarms_Menu (T, M);
         when Profile_Menu =>
            Load_Profile_Menu (T, M);
         when PID_Menu =>
            Load_PID_Menu (T, M);
         when Rate_Menu =>
            Load_Rate_Menu (T, M);
         when Simplified_Menu =>
            Load_Simplified_Menu (T, M);
         when Profile_Other_Menu =>
            Load_Profile_Other_Menu (T, M);
         when Launch_Control_Menu =>
            Load_Launch_Control_Menu (T, M);
         when VTX_MSP_Menu =>
            Load_VTX_MSP_Menu (T, M);
         when VTX_MSP_Confirm =>
            Load_VTX_MSP_Confirm (M);
         when VTX_Tramp_Menu =>
            Load_VTX_Tramp_Menu (T, M);
         when VTX_Tramp_Confirm =>
            Load_VTX_Tramp_Confirm (M);
         when VTX_SmartAudio_Menu =>
            Load_SA_Menu (T, M);
         when SA_Config_Menu =>
            Load_SA_Config_Menu (T, M);
         when SA_Stats_Menu =>
            Load_SA_Stats_Menu (T, M);
         when SA_POR_Freq_Menu =>
            Load_SA_Freq_Menu ("- POR FREQ -", T.VTX.SA_Menu.OR_Freq, T.VTX.SA_Menu.OR_Freq_New, M);
         when SA_User_Freq_Menu =>
            Load_SA_Freq_Menu ("- USER FREQ -", T.VTX.SA_Menu.User_Freq, T.VTX.SA_Menu.User_Freq_New, M);
         when SA_Confirm_Menu =>
            Load_SA_Confirm_Menu (M);
         when others =>
            M := Empty_Table;
      end case;
   end Load;

   --  The VTX device menus' frequency of their band and channel, kept while
   --  either is none.
   procedure Update_Freq_Ref (C : in out VTX_Copies; Run : Adaflight.VTX_Table.Table; Present : Boolean)
     with Global => null
   is
   begin
      if C.Band > 0 and then C.Channel > 0 then
         C.Freq_Ref :=
           (if Present then Adaflight.VTX_Table.Frequency_Of (Run, Natural (C.Band), Natural (C.Channel)) else 0);
      end if;
   end Update_Freq_Ref;

   --  The VTX device menus' copies from the device: the band and channel,
   --  the pit mode, none while unknown, and the power index, the first while
   --  unknown.
   procedure Read_VTX_Copies
     (V       : Adaflight.VTX.State;
      Run     : Adaflight.VTX_Table.Table;
      Present : Boolean;
      C       : in out VTX_Copies)
     with Global => null
   is
      Ignore_Known : Boolean;
      Known        : Boolean;
      Pit          : Boolean;
   begin
      Adaflight.VTX.Common_Get_Band_Channel (V, Run, C.Band, C.Channel, Ignore_Known);
      Update_Freq_Ref (C, Run, Present);
      Adaflight.VTX.Common_Get_Status (V, Pit, Known);
      C.Pit_Mode := (if not Known then 0 elsif Pit then 2 else 1);
      Adaflight.VTX.Common_Get_Power_Index (V, Run, C.Power, Known);
      if not Known then
         C.Power := 1;
      end if;
   end Read_VTX_Copies;

   --  The VTX device menus' band, channel and power sent to the device and
   --  stored with the band and channel's frequency.
   procedure Commence_VTX
     (V       : in out Adaflight.VTX.State;
      Run     : Adaflight.VTX_Table.Table;
      Present : Boolean;
      C       : VTX_Copies;
      S       : in out Adaflight.Config_Groups.Vtx_Settings_Config_Record)
     with Global => null
   is
   begin
      Adaflight.VTX.Common_Set_Band_Channel (V, Run, C.Band, C.Channel);
      Adaflight.VTX.Common_Set_Power_Index (V, Run, C.Power);
      S.Band := C.Band;
      S.Channel := C.Channel;
      S.Power := C.Power;
      S.Freq := (if Present then Adaflight.VTX_Table.Frequency_Of (Run, Natural (C.Band), Natural (C.Channel)) else 0);
   end Commence_VTX;

   --  A VTX device menu's line after its value changed: the pit mode set on
   --  the device, from none to off, and the band, channel and power from
   --  none to the first, the band and channel's frequency taken again.
   procedure VTX_Line_Changed
     (V       : in out Adaflight.VTX.State;
      Run     : Adaflight.VTX_Table.Table;
      Present : Boolean;
      C       : in out VTX_Copies;
      Line    : Natural)
     with Global => null
   is
   begin
      case Line is
         when 2 =>
            if C.Pit_Mode = 0 then
               C.Pit_Mode := 1;
            else
               Adaflight.VTX.Common_Set_Pit_Mode (V, Run, C.Pit_Mode /= 1);
            end if;
         when 3 =>
            if C.Band = 0 then
               C.Band := 1;
            else
               Update_Freq_Ref (C, Run, Present);
            end if;
         when 4 =>
            if C.Channel = 0 then
               C.Channel := 1;
            else
               Update_Freq_Ref (C, Run, Present);
            end if;
         when 6 =>
            if C.Power = 0 then
               C.Power := 1;
            end if;
         when others =>
            null;
      end case;
   end VTX_Line_Changed;

   --  The VTX device menus' status line as far as the power: the band's
   --  letter and the channel's name, or U F without them, and the frequency
   --  in four places, or dashes while the device does not know it.
   function Status_Head (V : Adaflight.VTX.State; Run : Adaflight.VTX_Table.Table) return String
     with Global => null,
          Post   => Status_Head'Result'First = 1 and then Status_Head'Result'Length = 9
   is
      Band, Channel : Interfaces.Unsigned_8 := 0;
      Freq          : Interfaces.Unsigned_16 := 0;
      Known         : Boolean;
      Pair          : String (1 .. 2) := "UF";
   begin
      Adaflight.VTX.Common_Get_Band_Channel (V, Run, Band, Channel, Known);
      if Known and then (Band /= 0 or else Channel /= 0) then
         Pair := (Adaflight.VTX_Table.Band_Letter_Of (Run, Natural (Band)),
                  Adaflight.VTX_Table.Channel_Name_Of (Run, Natural (Channel)));
      end if;
      Adaflight.VTX.Common_Get_Frequency (V, Run, Freq, Known);
      declare
         Freq_Text : constant String := (if Known and then Freq /= 0 then Decimal (Freq, 4) else "----");
      begin
         return "* " & Pair & " " & Freq_Text (Freq_Text'First .. Freq_Text'First + 3);
      end;
   end Status_Head;

   procedure Update_MSP_Status (T : in out Target) is
      Index : Interfaces.Unsigned_8 := 0;
      Known : Boolean;
   begin
      if T.VTX_Table.Bands = 0 or else T.VTX_Table.Power_Levels = 0 then
         T.MSP_Status := Label ("PLEASE CONFIGURE VTXTABLE");
         return;
      end if;
      Adaflight.VTX.Common_Get_Power_Index (T.VTX, T.VTX_Table, Index, Known);
      T.MSP_Status :=
        C_Text (Status_Head (T.VTX, T.VTX_Table)
                & (if Known and then Adaflight.VTX_Table.Has_Power_Value (T.VTX_Table, Natural (Index))
                   then " *" & Decimal (Adaflight.VTX_Table.Power_Value_Of (T.VTX_Table, Natural (Index)), 3)
                   else " ----"));
   end Update_MSP_Status;

   procedure Update_Tramp_Status (T : in out Target) is
      Actual : constant Interfaces.Unsigned_16 := Adaflight.Tramp.Actual_Power (T.VTX.TR);
      Index  : Interfaces.Unsigned_8 := 0;
      Known  : Boolean;
   begin
      if T.VTX_Table.Bands = 0 or else T.VTX_Table.Power_Levels = 0 then
         T.Tramp_Status := Label ("PLEASE CONFIGURE VTXTABLE");
         return;
      end if;
      Adaflight.VTX.Common_Get_Power_Index (T.VTX, T.VTX_Table, Index, Known);
      if Actual > 0 and then Known and then Adaflight.VTX_Table.Has_Power_Value (T.VTX_Table, Natural (Index)) then
         T.Tramp_Status :=
           C_Text (Status_Head (T.VTX, T.VTX_Table) & " "
                   & (if Actual = Adaflight.VTX_Table.Power_Value_Of (T.VTX_Table, Natural (Index)) then ' ' else '*')
                   & Decimal (Actual, 3));
      else
         T.Tramp_Status := C_Text (Status_Head (T.VTX, T.VTX_Table) & " ----");
      end if;
      T.Tramp_Temp := Adaflight.Tramp.Temperature (T.VTX.TR);
   end Update_Tramp_Status;

   --  The setup popup's build: a line for the accelerometer calibration
   --  when arming waits for it, one for the battery restore when charge
   --  was drawn, and the exit; true when a line came in besides the exit.
   procedure Build_Popup (T : in out Target; Added : out Boolean)
     with Global => null
   is
   begin
      T.Popup.Acc_Line := T.Live.Acc_Present and then T.Live.Acc_Calibration_Needed;
      T.Popup.Battery_Line := T.Live.Used_MAh;
      Added := T.Popup.Acc_Line or else T.Popup.Battery_Line;
   end Build_Popup;

   --  The PID profile changed to an index, stored when the profile exists.
   procedure Change_PID_Profile (T : in out Target; Index : Interfaces.Unsigned_8)
     with Global => null
   is
   begin
      if T.Asked.PID_Changes < Natural'Last then
         T.Asked.PID_Changes := T.Asked.PID_Changes + 1;
      end if;
      T.Asked.PID_Asked := Index;
      if Index < PID_Profile_Count then
         T.Config.System_Config.Pid_Profile_Index := Index;
      end if;
   end Change_PID_Profile;

   --  The rate profile changed to an index, stored when the profile exists.
   procedure Change_Rate_Profile (T : in out Target; Index : Interfaces.Unsigned_8)
     with Global => null
   is
   begin
      if T.Asked.Rate_Changes < Natural'Last then
         T.Asked.Rate_Changes := T.Asked.Rate_Changes + 1;
      end if;
      T.Asked.Rate_Asked := Index;
      if Index < Rate_Profile_Count then
         T.Config.System_Config.Active_Rate_Profile := Index;
      end if;
   end Change_Rate_Profile;

   --  The PID profile the profile menu last selected and the current one,
   --  each within the profiles.
   function Shown_PID (T : Target) return Natural is
     (Natural (Interfaces.Unsigned_8'Min (T.Profile.PID_Index, PID_Profile_Count - 1)));
   function Current_PID (T : Target) return Natural is
     (Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Pid_Profile_Index, PID_Profile_Count - 1)));

   --  The SmartAudio menu's lines from the device's state: offline while
   --  the device's version is unknown, else by band and channel or by
   --  frequency.
   procedure Setup_SA_Top (T : in out Target)
     with Global => null
   is
   begin
      T.SA_Top :=
        (if T.VTX.SA_Menu.Device_Status = 0 then Offline_Lines
         elsif T.VTX.SA_Menu.Fsel_Mode_New = 0 then Channel_Lines
         else Frequency_Lines);
   end Setup_SA_Top;

   --  The SmartAudio menu's frequency of its band and channel.
   function SA_Freq_Ref (T : Target) return Interfaces.Unsigned_16 is
     (if T.Live.VTX_Present
      then Adaflight.VTX_Table.Frequency_Of (T.VTX_Table, Natural (T.VTX.SA_Menu.Band), Natural (T.VTX.SA_Menu.Channel))
      else 0);

   --  The SmartAudio menu's lines after their values changed: the band and
   --  channel none while the device is unknown, stepped from none to the
   --  first, else their frequency taken; the power none while the device is
   --  unknown, stepped from none to the first, else the pit mode off; the pit
   --  mode none while the device is unknown, stepped from none to off, else
   --  the power the device's.
   procedure SA_Top_Line_Changed (T : in out Target; Line : Natural)
     with Global => null
   is
      Known : constant Boolean := T.VTX.SA.Device.Version_Seen /= Adaflight.SmartAudio.Unknown;
      Item  : constant Natural :=
        (case T.SA_Top is
            when Channel_Lines   => (case Line is when 2 => 1, when 3 => 2, when 5 => 3, when 6 => 4, when others => 0),
            when Frequency_Lines => (case Line is when 3 => 3, when 4 => 4, when others => 0),
            when Offline_Lines   => 0);
   begin
      case Item is
         when 1 =>
            if not Known then
               T.VTX.SA_Menu.Band := 0;
            elsif T.VTX.SA_Menu.Band = 0 then
               T.VTX.SA_Menu.Band := 1;
            else
               T.VTX.SA_Menu.Freq_Ref := SA_Freq_Ref (T);
            end if;
         when 2 =>
            if not Known then
               T.VTX.SA_Menu.Channel := 0;
            elsif T.VTX.SA_Menu.Channel = 0 then
               T.VTX.SA_Menu.Channel := 1;
            else
               T.VTX.SA_Menu.Freq_Ref := SA_Freq_Ref (T);
            end if;
         when 3 =>
            if not Known then
               T.VTX.SA_Menu.Power := 0;
            elsif T.VTX.SA_Menu.Power = 0 then
               T.VTX.SA_Menu.Power := 1;
            elsif T.VTX.SA_Menu.Pit > 0 and then T.VTX.SA_Menu.Pit /= 1 then
               T.VTX.SA_Menu.Pit := 1;
            end if;
         when 4 =>
            if not Known then
               T.VTX.SA_Menu.Pit := 0;
            elsif T.VTX.SA_Menu.Pit = 0 then
               T.VTX.SA_Menu.Pit := 1;
            elsif Integer (T.VTX.SA.Device.Power) /= Integer (T.VTX.SA_Menu.Power) then
               T.VTX.SA_Menu.Power := Interfaces.Unsigned_8'Mod (Integer (T.VTX.SA.Device.Power));
            end if;
         when others =>
            null;
      end case;
   end SA_Top_Line_Changed;

   --  The SmartAudio pit mode kind after its value changed: none for a
   --  first version device, in range for a 2.1 device, stepped from none to
   --  in range, else sent to the device as in or out of range.
   procedure SA_Pit_F_Mode_Changed (T : in out Target)
     with Global => null
   is
      Version : constant Adaflight.SmartAudio.Version := T.VTX.SA.Device.Version_Seen;
   begin
      if Version = Adaflight.SmartAudio.V1 then
         T.VTX.SA_Menu.Pit_F_Mode := 0;
      elsif Version >= Adaflight.SmartAudio.V21 then
         T.VTX.SA_Menu.Pit_F_Mode := 1;
      elsif T.VTX.SA_Menu.Pit_F_Mode = 0 then
         T.VTX.SA_Menu.Pit_F_Mode := 1;
      elsif T.VTX.SA_Menu.Pit_F_Mode = 1 then
         Adaflight.SmartAudio.Set_Mode (T.VTX.SA, Adaflight.SmartAudio.Set_In_Range_Pit);
      else
         Adaflight.SmartAudio.Set_Mode (T.VTX.SA, Adaflight.SmartAudio.Set_Out_Range_Pit);
      end if;
   end SA_Pit_F_Mode_Changed;

   --  The SmartAudio frequency selection after its value changed: by
   --  frequency only in the free model, and the menu's lines taken again.
   procedure SA_Freq_Mode_Changed (T : in out Target)
     with Global => null
   is
   begin
      if T.VTX.SA_Menu.Fsel_Mode_New /= 0 and then T.VTX.SA_Menu.Opmodel /= 1 then
         T.VTX.SA_Menu.Fsel_Mode_New := 0;
      end if;
      Setup_SA_Top (T);
   end SA_Freq_Mode_Changed;

   --  The SmartAudio operating model after its value changed: free for a
   --  first version device; the free model clears the pit mode ranges, the
   --  race model sets the pit mode kind to in range, keeps a 2.1 device in
   --  pit mode and selects by band and channel; none steps to free.
   procedure SA_Opmodel_Changed (T : in out Target)
     with Global => null
   is
      Version : constant Adaflight.SmartAudio.Version := T.VTX.SA.Device.Version_Seen;
   begin
      if Version = Adaflight.SmartAudio.V1 then
         if T.VTX.SA_Menu.Opmodel /= 1 then
            T.VTX.SA_Menu.Opmodel := 1;
         end if;
         return;
      end if;
      case T.VTX.SA_Menu.Opmodel is
         when 1 =>
            Adaflight.SmartAudio.Set_Mode (T.VTX.SA, 0);
         when 2 =>
            T.VTX.SA_Menu.Pit_F_Mode := 0;
            SA_Pit_F_Mode_Changed (T);
            if Version >= Adaflight.SmartAudio.V21 then
               Adaflight.SmartAudio.Set_Mode
                 (T.VTX.SA,
                  Adaflight.SmartAudio.Set_In_Range_Pit
                  or (if (T.VTX.SA.Device.Mode and Adaflight.SmartAudio.Mode_Pit) /= 0 then 0
                      else Adaflight.SmartAudio.Set_Clear_Pit));
            end if;
            T.VTX.SA_Menu.Fsel_Mode_New := 0;
            SA_Freq_Mode_Changed (T);
         when others =>
            T.VTX.SA_Menu.Opmodel := 1;
      end case;
   end SA_Opmodel_Changed;

   --  The SmartAudio menu's settings stored: the race model and a selection
   --  by band and channel store the band, channel and their frequency, a
   --  selection by frequency clears the pit mode ranges and stores no band
   --  with the user frequency; the pit mode goes to the device when the
   --  power stays; the power is stored, and Saved reports a change.
   procedure SA_Commence (T : in out Target; Saved : out Boolean)
     with Global => null
   is
      Prev    : constant Adaflight.Config_Groups.Vtx_Settings_Config_Record := T.Config.Vtx_Settings_Config;
      Changed : Adaflight.Config_Groups.Vtx_Settings_Config_Record := Prev;
      Pit     : constant Interfaces.Unsigned_8 := T.VTX.SA_Menu.Pit;
   begin
      if T.VTX.SA_Menu.Opmodel = 2 or else T.VTX.SA_Menu.Fsel_Mode_New = 0 then
         Changed.Band := T.VTX.SA_Menu.Band;
         Changed.Channel := T.VTX.SA_Menu.Channel;
         Changed.Freq := SA_Freq_Ref (T);
      else
         Adaflight.SmartAudio.Set_Mode (T.VTX.SA, 0);
         Changed.Band := 0;
         Changed.Freq := T.VTX.SA_Menu.User_Freq;
      end if;
      if Changed.Power = T.VTX.SA_Menu.Power and then Pit > 0 then
         Adaflight.VTX.Common_Set_Pit_Mode (T.VTX, T.VTX_Table, Pit = 2);
      end if;
      Changed.Power := T.VTX.SA_Menu.Power;
      Saved := Changed.Band /= Prev.Band or else Changed.Channel /= Prev.Channel or else Changed.Power /= Prev.Power
        or else Changed.Freq /= Prev.Freq;
      if Saved then
         T.Config.Vtx_Settings_Config := Changed;
      end if;
   end SA_Commence;

   procedure Enter_GPS_Rescue_Menu (T : in out Target)
     with Global => null
   is
      GR : Adaflight.Config_Groups.Gps_Rescue_Record renames T.Config.Gps_Rescue_Config;
      AP : Adaflight.Config_Groups.Autopilot_Config_Record renames T.Config.Autopilot_Config;
   begin
      T.Rescue :=
        (Min_Start_Dist_M         => GR.Min_Start_Dist_M,
         Altitude_Mode            => GR.Altitude_Mode,
         Initial_Climb_M          => GR.Initial_Climb_M,
         Ascend_Rate              => GR.Ascend_Rate,
         Return_Altitude_M        => GR.Return_Altitude_M,
         Ground_Speed_Cm_S        => GR.Ground_Speed_Cm_S,
         Max_Angle                => AP.Max_Angle,
         Descent_Distance_M       => GR.Descent_Distance_M,
         Descend_Rate             => GR.Descend_Rate,
         Landing_Altitude_M       => AP.Landing_Altitude_M,
         Throttle_Min             => AP.Throttle_Min,
         Throttle_Max             => AP.Throttle_Max,
         Hover_Throttle           => AP.Hover_Throttle,
         Min_Sats                 => GR.Min_Sats,
         Allow_Arming_Without_Fix => GR.Allow_Arming_Without_Fix);
   end Enter_GPS_Rescue_Menu;

   procedure Enter_GPS_Rescue_PID_Menu (T : in out Target)
     with Global => null
   is
      AP : Adaflight.Config_Groups.Autopilot_Config_Record renames T.Config.Autopilot_Config;
   begin
      T.Rescue_PID :=
        (Altitude_P      => AP.Altitude_P,
         Altitude_I      => AP.Altitude_I,
         Altitude_D      => AP.Altitude_D,
         Altitude_A      => AP.Altitude_A,
         Altitude_F      => AP.Altitude_F,
         Yaw_P           => T.Config.Gps_Rescue_Config.Yaw_P,
         Position_P      => AP.Position_P,
         Position_I      => AP.Position_I,
         Position_D      => AP.Position_D,
         Position_Cutoff => AP.Position_Cutoff);
   end Enter_GPS_Rescue_PID_Menu;

   procedure On_Enter (T : in out Target; Id : Menu_Id; Reply : out Adaflight.Menu.Answer) is
   begin
      Reply := (others => <>);
      case Id is
         when Quick_Menu =>
            T.Quick.PID_Profile :=
              Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Pid_Profile_Index, PID_Profile_Count - 1));
            T.Quick.Rate_Profile :=
              Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Active_Rate_Profile, Rate_Profile_Count - 1));
            T.Quick.Battery_Profile :=
              Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Active_Battery_Profile,
                                                  Battery_Profile_Count - 1));
            T.Quick.Rate := T.Config.Control_Rate_Profiles (T.Quick.Rate_Profile);
            T.Quick.Battery := T.Config.Battery_Profiles (T.Quick.Battery_Profile);
            T.Quick.Motor_Output_Limit := T.Config.Pid_Profiles (T.Quick.PID_Profile).Motor_Output_Limit;
         when Main_Menu =>
            declare
               Added : Boolean;
            begin
               Build_Popup (T, Added);
               if Added then
                  Reply.Done := Adaflight.Menu.Changed;
                  Reply.Target := Setup_Popup;
               end if;
            end;
         when Profile_Menu =>
            for I in Profile_Texts'Range loop
               T.Profile.PID_Names (I) :=
                 Profile_Text (Interfaces.Unsigned_8 (I), T.Config.Pid_Profiles (I).Profile_Name);
            end loop;
            T.Profile.PID_Index := T.Config.System_Config.Pid_Profile_Index;
            T.Profile.PID_Line := T.Profile.PID_Index;
            for I in Profile_Texts'Range loop
               T.Profile.Rate_Names (I) :=
                 Profile_Text (Interfaces.Unsigned_8 (I), T.Config.Control_Rate_Profiles (I).Profile_Name);
            end loop;
            T.Profile.Rate_Index := T.Config.System_Config.Active_Rate_Profile;
            T.Profile.Rate_Line := T.Profile.Rate_Index;
         when PID_Menu =>
            declare
               Current : constant Natural :=
                 Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Pid_Profile_Index, PID_Profile_Count - 1));
               Shown   : constant Natural :=
                 Natural (Interfaces.Unsigned_8'Min (T.Profile.PID_Index, PID_Profile_Count - 1));
            begin
               T.PID.Profile_Text := Profile_Text (T.Profile.PID_Index, T.Config.Pid_Profiles (Current).Profile_Name);
               for A in Feedforward_Table'Range loop
                  T.PID.Gains (A, 0) := T.Config.Pid_Profiles (Shown).Pid (A).P;
                  T.PID.Gains (A, 1) := T.Config.Pid_Profiles (Shown).Pid (A).I;
                  T.PID.Gains (A, 2) := T.Config.Pid_Profiles (Shown).Pid (A).D;
                  T.PID.Feedforward (A) := T.Config.Pid_Profiles (Shown).Pid (A).F;
               end loop;
            end;
         when Rate_Menu =>
            declare
               Shown : constant Natural :=
                 Natural (Interfaces.Unsigned_8'Min (T.Profile.Rate_Index, Rate_Profile_Count - 1));
            begin
               T.Rate.Profile_Text :=
                 Profile_Text (T.Profile.Rate_Index, T.Config.Control_Rate_Profiles (Shown).Profile_Name);
               T.Rate.Profile := T.Config.Control_Rate_Profiles (Shown);
            end;
         when Simplified_Menu =>
            declare
               P : constant Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (Shown_PID (T));
            begin
               T.Simplified.Mode := P.Simplified_Pids_Mode;
               T.Simplified.Master := P.Simplified_Master_Multiplier;
               T.Simplified.Roll_Pitch_Ratio := P.Simplified_Roll_Pitch_Ratio;
               T.Simplified.I_Gain := P.Simplified_I_Gain;
               T.Simplified.D_Gain := P.Simplified_D_Gain;
               T.Simplified.PI_Gain := P.Simplified_Pi_Gain;
               T.Simplified.D_Max_Gain := P.Simplified_D_Max_Gain;
               T.Simplified.FF_Gain := P.Simplified_Feedforward_Gain;
               T.Simplified.Pitch_PI_Gain := P.Simplified_Pitch_Pi_Gain;
               T.Simplified.DTerm_Filter := P.Simplified_Dterm_Filter;
               T.Simplified.DTerm_Multiplier := P.Simplified_Dterm_Filter_Multiplier;
               T.Simplified.Gyro_Filter := T.Config.Gyro_Config.Simplified_Gyro_Filter;
               T.Simplified.Gyro_Multiplier := T.Config.Gyro_Config.Simplified_Gyro_Filter_Multiplier;
            end;
         when Profile_Other_Menu =>
            T.PID.Profile_Text :=
              Profile_Text (T.Profile.PID_Index, T.Config.Pid_Profiles (Current_PID (T)).Profile_Name);
            declare
               P : constant Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (Shown_PID (T));
            begin
               T.Other.Angle_P := P.Pid (3).P;
               T.Other.Angle_FF := Interfaces.Unsigned_8 (P.Pid (3).F mod 256);
               T.Other.Angle_Limit := P.Angle_Limit;
               T.Other.Angle_Earth_Ref := P.Angle_Earth_Ref;
               T.Other.Horizon_Strength := P.Pid (3).I;
               T.Other.Horizon_Sticks := P.Pid (3).D;
               T.Other.Horizon_Degrees := P.Horizon_Limit_Degrees;
               T.Other.Anti_Gravity_Gain := P.Anti_Gravity_Gain;
               T.Other.Throttle_Boost := P.Throttle_Boost;
               T.Other.Thrust_Linearization := P.Thrust_Linearization;
               T.Other.Motor_Output_Limit := P.Motor_Output_Limit;
               T.Other.Auto_Cell_Count := P.Auto_Profile_Cell_Count;
               for A in D_Max_Table'Range loop
                  T.Other.D_Max (A) := P.D_Max (A);
               end loop;
               T.Other.D_Max_Gain := P.D_Max_Gain;
               T.Other.D_Max_Advance := P.D_Max_Advance;
               T.Other.Iterm_Relax := P.Iterm_Relax;
               T.Other.Iterm_Relax_Type := P.Iterm_Relax_Type;
               T.Other.Iterm_Relax_Cutoff := P.Iterm_Relax_Cutoff;
               T.Other.FF_Transition := P.Feedforward_Transition;
               T.Other.FF_Averaging := P.Feedforward_Averaging;
               T.Other.FF_Boost := P.Feedforward_Boost;
               T.Other.FF_Smooth := P.Feedforward_Smooth_Factor;
               T.Other.FF_Jitter := P.Feedforward_Jitter_Factor;
               T.Other.Vbat_Sag := P.Vbat_Sag_Compensation;
               T.Other.TPA_Rate := P.Tpa_Rate;
               T.Other.TPA_Breakpoint := P.Tpa_Breakpoint;
               T.Other.TPA_Low_Rate := P.Tpa_Low_Rate;
               T.Other.TPA_Low_Breakpoint := P.Tpa_Low_Breakpoint;
               T.Other.TPA_Low_Always := P.Tpa_Low_Always;
               T.Other.Landing_Disarm := P.Landing_Disarm_Threshold;
            end;
         when Launch_Control_Menu =>
            declare
               P : constant Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (Shown_PID (T));
            begin
               T.Launch.Mode := P.Launch_Control_Mode;
               T.Launch.Allow_Reset := P.Launch_Control_Allow_Trigger_Reset;
               T.Launch.Throttle_Percent := P.Launch_Control_Throttle_Percent;
               T.Launch.Angle_Limit := P.Launch_Control_Angle_Limit;
               T.Launch.Gain := P.Launch_Control_Gain;
            end;
         when Filter_Profile_Menu =>
            declare
               P : constant Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (Shown_PID (T));
            begin
               T.Profile_Flt.DTerm_LPF1 := P.Dterm_Lpf1_Static_Hz;
               T.Profile_Flt.DTerm_LPF2 := P.Dterm_Lpf2_Static_Hz;
               T.Profile_Flt.DTerm_Notch_Hz := P.Dterm_Notch_Hz;
               T.Profile_Flt.DTerm_Notch_Cutoff := P.Dterm_Notch_Cutoff;
               T.Profile_Flt.Yaw_Lowpass := P.Yaw_Lowpass_Hz;
            end;
         when Filter_Global_Menu =>
            T.Global_Filt.Gyro_LPF1 := T.Config.Gyro_Config.Gyro_Lpf1_Static_Hz;
            T.Global_Filt.Gyro_LPF2 := T.Config.Gyro_Config.Gyro_Lpf2_Static_Hz;
            T.Global_Filt.Notch1_Hz := T.Config.Gyro_Config.Gyro_Soft_Notch_Hz_1;
            T.Global_Filt.Notch1_Cutoff := T.Config.Gyro_Config.Gyro_Soft_Notch_Cutoff_1;
            T.Global_Filt.Notch2_Hz := T.Config.Gyro_Config.Gyro_Soft_Notch_Hz_2;
            T.Global_Filt.Notch2_Cutoff := T.Config.Gyro_Config.Gyro_Soft_Notch_Cutoff_2;
         when Dynamic_Filter_Menu =>
            T.Dynamic.Notch_Max_Hz := T.Config.Dyn_Notch_Config.Dyn_Notch_Max_Hz;
            T.Dynamic.Notch_Count := T.Config.Dyn_Notch_Config.Dyn_Notch_Count;
            T.Dynamic.Notch_Q := T.Config.Dyn_Notch_Config.Dyn_Notch_Q;
            T.Dynamic.Notch_Min_Hz := T.Config.Dyn_Notch_Config.Dyn_Notch_Min_Hz;
            T.Dynamic.Gyro_Min := T.Config.Gyro_Config.Gyro_Lpf1_Dyn_Min_Hz;
            T.Dynamic.Gyro_Max := T.Config.Gyro_Config.Gyro_Lpf1_Dyn_Max_Hz;
            T.Dynamic.Gyro_Expo := T.Config.Gyro_Config.Gyro_Lpf1_Dyn_Expo;
            T.Dynamic.DTerm_Min := T.Config.Pid_Profiles (Shown_PID (T)).Dterm_Lpf1_Dyn_Min_Hz;
            T.Dynamic.DTerm_Max := T.Config.Pid_Profiles (Shown_PID (T)).Dterm_Lpf1_Dyn_Max_Hz;
            T.Dynamic.DTerm_Expo := T.Config.Pid_Profiles (Shown_PID (T)).Dterm_Lpf1_Dyn_Expo;
         when Copy_Profile_Menu =>
            T.Copy := (PID_Target => 0, Rate_Target => 0);
         when VTX_MSP_Menu =>
            if T.Live.VTX_Present then
               Read_VTX_Copies (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.MSP);
            else
               Reply.Chain_Back := True;
            end if;
         when VTX_Tramp_Menu =>
            if T.Live.VTX_Present then
               Read_VTX_Copies (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.Tramp);
            else
               Reply.Chain_Back := True;
            end if;
         when VTX_Error_Menu =>
            if not T.Live.VTX_Present then
               T.VTX_Status := (Label ("VTX NOT RESPONDING"), Label ("OR NOT CONFIGURED"));
            elsif T.Live.VTX_Type = 0 then
               T.VTX_Status := (Label ("UNSUPPORTED VTX TYPE"), Label (""));
            else
               T.VTX_Status := (Label ("UNKNOWN VTX TYPE"), Label (""));
            end if;
         when OSD_Menu =>
            T.OSD.Profile := T.Config.Osd_Config.Osd_Profile_Index;
            T.OSD.Invert := T.Config.Display_Port_Profile_Max7456.Invert;
            T.OSD.Black_Brightness := T.Config.Display_Port_Profile_Max7456.Black_Brightness;
            T.OSD.White_Brightness := T.Config.Display_Port_Profile_Max7456.White_Brightness;
            T.OSD.Background := T.Config.Osd_Config.Cms_Background_Type;
         when Active_Elements_Menu =>
            T.Elements := T.Config.Osd_Element_Config.Item_Pos;
         when Timers_Menu =>
            for I in Timer_Fields'Range loop
               T.Timers.Source (I) := Interfaces.Unsigned_8 (T.Config.Osd_Config.Timers (I) and 16#0F#);
               T.Timers.Precision (I) := Interfaces.Unsigned_8 (T.Config.Osd_Config.Timers (I) / 16 and 16#0F#);
               T.Timers.Alarm (I) := Interfaces.Unsigned_8 (T.Config.Osd_Config.Timers (I) / 256);
            end loop;
         when Alarms_Menu =>
            T.Alarms.RSSI := T.Config.Osd_Config.Rssi_Alarm;
            T.Alarms.Link_Quality := T.Config.Osd_Config.Link_Quality_Alarm;
            T.Alarms.RSSI_Dbm := T.Config.Osd_Config.Rssi_Dbm_Alarm;
            T.Alarms.RSNR := T.Config.Osd_Config.Rsnr_Alarm;
            T.Alarms.Capacity := T.Config.Osd_Config.Cap_Alarm;
            T.Alarms.Altitude := T.Config.Osd_Config.Alt_Alarm;
            T.Alarms.Distance := T.Config.Osd_Config.Distance_Alarm;
            T.Alarms.Warning_Duration := T.Config.Battery_Config.Vbat_Duration_For_Warning;
            T.Alarms.Critical_Duration := T.Config.Battery_Config.Vbat_Duration_For_Critical;
         when Blackbox_Menu =>
            Device_Status (T, T.Live.Flash_Offset);
            T.Blackbox.Device := T.Config.Blackbox_Config.Device;
            T.Blackbox.Rate := T.Config.Blackbox_Config.Sample_Rate;
            T.Blackbox.Debug_Mode := T.Config.System_Config.Debug_Mode;
            T.Blackbox.PID_Frequency := PID_Frequency_Text (T.Live.PID_Frequency);
         when LED_Strip_Menu =>
            T.LED.Enabled :=
              (if (T.Live.Runtime_Features and Adaflight.Config_Fix.Feature_LED_Strip) /= 0 then 1 else 0);
            T.LED.Profile := T.Config.Led_Strip_Config.Ledstrip_Profile;
            T.LED.Race_Color := T.Config.Led_Strip_Config.Ledstrip_Race_Color;
            T.LED.Beacon_Color := T.Config.Led_Strip_Config.Ledstrip_Beacon_Color;
            T.LED.Beacon_Period := T.Config.Led_Strip_Config.Ledstrip_Beacon_Period_Ms;
            T.LED.Beacon_On_Percent := T.Config.Led_Strip_Config.Ledstrip_Beacon_Percent;
            T.LED.Beacon_Armed_Only := T.Config.Led_Strip_Config.Ledstrip_Beacon_Armed_Only;
            T.LED.Visual_Beeper := T.Config.Led_Strip_Config.Ledstrip_Visual_Beeper;
            T.LED.Visual_Beeper_Color := T.Config.Led_Strip_Config.Ledstrip_Visual_Beeper_Color;
         when Power_Menu =>
            T.Power.Voltage_Meter_Source := T.Config.Battery_Config.Voltage_Meter_Source;
            T.Power.Current_Meter_Source := T.Config.Battery_Config.Current_Meter_Source;
            T.Power.Battery_Profile :=
              Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Active_Battery_Profile,
                                                  Battery_Profile_Count - 1));
            T.Power.Min_Cell_Voltage := T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatmincellvoltage;
            T.Power.Max_Cell_Voltage := T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatmaxcellvoltage;
            T.Power.Warning_Cell_Voltage := T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatwarningcellvoltage;
            T.Power.Voltage_Scale := T.Config.Voltage_Sensor_Adc_Config (0).Vbatscale;
            T.Power.Current_Scale := T.Config.Current_Sensor_Adc_Config.Scale;
            T.Power.Current_Offset := T.Config.Current_Sensor_Adc_Config.Offset;
            T.Power.Virtual_Scale := T.Config.Current_Sensor_Virtual_Config.Scale;
            T.Power.Virtual_Offset := T.Config.Current_Sensor_Virtual_Config.Offset;
         when VTX_SmartAudio_Menu =>
            Setup_SA_Top (T);
         when SA_POR_Freq_Menu =>
            if T.VTX.SA.Device.Version_Seen = Adaflight.SmartAudio.V1 then
               Reply.Chain_Back := True;
            else
               T.VTX.SA_Menu.OR_Freq_New := T.VTX.SA_Menu.OR_Freq;
            end if;
         when SA_User_Freq_Menu =>
            T.VTX.SA_Menu.User_Freq_New := T.VTX.SA_Menu.User_Freq;
         when GPS_Rescue_Menu =>
            Enter_GPS_Rescue_Menu (T);
         when GPS_Rescue_PID_Menu =>
            Enter_GPS_Rescue_PID_Menu (T);
         when Failsafe_Menu =>
            T.Failsafe.Procedure_Kind := T.Config.Failsafe_Config.Failsafe_Procedure;
            T.Failsafe.Guard_Time := T.Config.Failsafe_Config.Failsafe_Delay;
            T.Failsafe.Landing_Time := T.Config.Failsafe_Config.Failsafe_Landing_Time;
            T.Failsafe.Throttle := T.Config.Failsafe_Config.Failsafe_Throttle;
         when RPM_Limit_Menu =>
            T.RPM_Limit.Limit := T.Config.Mixer_Config.Rpm_Limit_Value;
            T.RPM_Limit.KV := T.Config.Motor_Config.Kv;
            T.RPM_Limit.Active := T.Config.Mixer_Config.Rpm_Limit;
         when Misc_Menu =>
            T.Misc.Idle_Offset := Interfaces.Unsigned_8 ((T.Config.Motor_Config.Motor_Idle / 10) mod 256);
            T.Misc.FPV_Cam_Angle := T.Config.Rx_Config.Fpv_Cam_Angle_Degrees;
            T.Misc.Crashflip_Rate := T.Config.Mixer_Config.Crashflip_Rate;
         when RC_Preview_Menu =>
            Reply.Inhibit_Save := True;
         when Persistent_Stats_Menu =>
            T.Stats.Total_Flights := T.Config.Stats_Config.Stats_Total_Flights;
            T.Stats.Total_Time_S := T.Config.Stats_Config.Stats_Total_Time_S;
            T.Stats.Total_Dist_M := T.Config.Stats_Config.Stats_Total_Dist_M;
            T.Stats.Min_Armed_Time := T.Config.Stats_Config.Stats_Min_Armed_Time_S;
         when GPS_Lap_Timer_Menu =>
            T.Lap.Minimum_Lap_Time := T.Config.Gps_Lap_Timer_Config.Minimum_Lap_Time_Seconds;
            T.Lap.Gate_Tolerance := T.Config.Gps_Lap_Timer_Config.Gate_Tolerance_M;
         when Set_Gate_Menu =>
            if T.Asked.Gate_Starts < Natural'Last then
               T.Asked.Gate_Starts := T.Asked.Gate_Starts + 1;
            end if;
         when Firmware_Menu =>
            T.Board.Manufacturer_Id := Cut (T.Live.Manufacturer_Id, Manufacturer_Id_Length);
            T.Board.Board_Name := Cut (T.Live.Board_Name, Board_Name_Length);
         when others =>
            null;
      end case;
   end On_Enter;

   procedure Leave_Quick_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Control_Rate_Profiles (T.Quick.Rate_Profile) := T.Quick.Rate;
      T.Config.Battery_Profiles (T.Quick.Battery_Profile) := T.Quick.Battery;
      T.Config.Pid_Profiles (T.Quick.PID_Profile).Motor_Output_Limit := T.Quick.Motor_Output_Limit;
      if T.Asked.PID_Config_Inits < Natural'Last then
         T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
      end if;
   end Leave_Quick_Menu;

   procedure Leave_Profile_Menu (T : in out Target)
     with Global => null
   is
   begin
      Change_PID_Profile (T, T.Profile.PID_Index);
      Change_Rate_Profile (T, T.Profile.Rate_Index);
   end Leave_Profile_Menu;

   procedure Leave_PID_Menu (T : in out Target)
     with Global => null
   is
      Current : constant Natural := Current_PID (T);
      P       : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (Current);
   begin
      for A in Feedforward_Table'Range loop
         P.Pid (A).P := T.PID.Gains (A, 0);
         P.Pid (A).I := T.PID.Gains (A, 1);
         P.Pid (A).D := T.PID.Gains (A, 2);
         P.Pid (A).F := T.PID.Feedforward (A);
      end loop;
      T.Config.Pid_Profiles (Current) := P;
      if T.Asked.PID_Config_Inits < Natural'Last then
         T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
      end if;
   end Leave_PID_Menu;

   procedure Leave_Rate_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Control_Rate_Profiles
        (Natural (Interfaces.Unsigned_8'Min (T.Profile.Rate_Index, Rate_Profile_Count - 1))) := T.Rate.Profile;
   end Leave_Rate_Menu;

   procedure Leave_Simplified_Menu (T : in out Target)
     with Global => null
   is
      C       : constant Natural := Current_PID (T);
      S       : constant Simplified_Copies := T.Simplified;
      P       : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (C);
      G       : Adaflight.Config_Groups.Gyro_Config_Record := T.Config.Gyro_Config;
      Changed : constant Boolean :=
        P.Simplified_Pids_Mode /= S.Mode or else P.Simplified_Master_Multiplier /= S.Master
        or else P.Simplified_Roll_Pitch_Ratio /= S.Roll_Pitch_Ratio or else P.Simplified_I_Gain /= S.I_Gain
        or else P.Simplified_D_Gain /= S.D_Gain or else P.Simplified_Pi_Gain /= S.PI_Gain
        or else P.Simplified_D_Max_Gain /= S.D_Max_Gain or else P.Simplified_Feedforward_Gain /= S.FF_Gain
        or else P.Simplified_Pitch_Pi_Gain /= S.Pitch_PI_Gain or else P.Simplified_Dterm_Filter /= S.DTerm_Filter
        or else P.Simplified_Dterm_Filter_Multiplier /= S.DTerm_Multiplier
        or else G.Simplified_Gyro_Filter /= S.Gyro_Filter
        or else G.Simplified_Gyro_Filter_Multiplier /= S.Gyro_Multiplier;
   begin
      if Changed then
         P.Simplified_Pids_Mode := S.Mode;
         P.Simplified_Master_Multiplier := S.Master;
         P.Simplified_Roll_Pitch_Ratio := S.Roll_Pitch_Ratio;
         P.Simplified_I_Gain := S.I_Gain;
         P.Simplified_D_Gain := S.D_Gain;
         P.Simplified_Pi_Gain := S.PI_Gain;
         P.Simplified_D_Max_Gain := S.D_Max_Gain;
         P.Simplified_Feedforward_Gain := S.FF_Gain;
         P.Simplified_Pitch_Pi_Gain := S.Pitch_PI_Gain;
         P.Simplified_Dterm_Filter := S.DTerm_Filter;
         P.Simplified_Dterm_Filter_Multiplier := S.DTerm_Multiplier;
         G.Simplified_Gyro_Filter := S.Gyro_Filter;
         G.Simplified_Gyro_Filter_Multiplier := S.Gyro_Multiplier;
         Adaflight.Simplified_Tuning.Stored.Apply (P, G);
         T.Config.Pid_Profiles (C) := P;
         T.Config.Gyro_Config := G;
      end if;
   end Leave_Simplified_Menu;

   procedure Leave_Profile_Other_Menu (T : in out Target)
     with Global => null
   is
      I : constant Natural := Shown_PID (T);
      O : constant Other_Copies := T.Other;
      P : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (I);
   begin
      if T.Asked.PID_Config_Inits < Natural'Last then
         T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
      end if;
      P.Pid (3).P := O.Angle_P;
      P.Pid (3).F := Interfaces.Unsigned_16 (O.Angle_FF);
      P.Angle_Limit := O.Angle_Limit;
      P.Angle_Earth_Ref := O.Angle_Earth_Ref;
      P.Pid (3).I := O.Horizon_Strength;
      P.Pid (3).D := O.Horizon_Sticks;
      P.Horizon_Limit_Degrees := O.Horizon_Degrees;
      P.Anti_Gravity_Gain := O.Anti_Gravity_Gain;
      P.Throttle_Boost := O.Throttle_Boost;
      P.Thrust_Linearization := O.Thrust_Linearization;
      P.Motor_Output_Limit := O.Motor_Output_Limit;
      P.Auto_Profile_Cell_Count := O.Auto_Cell_Count;
      for A in D_Max_Table'Range loop
         P.D_Max (A) := O.D_Max (A);
      end loop;
      P.D_Max_Gain := O.D_Max_Gain;
      P.D_Max_Advance := O.D_Max_Advance;
      P.Iterm_Relax := O.Iterm_Relax;
      P.Iterm_Relax_Type := O.Iterm_Relax_Type;
      P.Iterm_Relax_Cutoff := O.Iterm_Relax_Cutoff;
      P.Feedforward_Transition := O.FF_Transition;
      P.Feedforward_Averaging := O.FF_Averaging;
      P.Feedforward_Boost := O.FF_Boost;
      P.Feedforward_Smooth_Factor := O.FF_Smooth;
      P.Feedforward_Jitter_Factor := O.FF_Jitter;
      P.Vbat_Sag_Compensation := O.Vbat_Sag;
      P.Tpa_Rate := O.TPA_Rate;
      P.Tpa_Breakpoint := O.TPA_Breakpoint;
      P.Tpa_Low_Rate := O.TPA_Low_Rate;
      P.Tpa_Low_Breakpoint := O.TPA_Low_Breakpoint;
      P.Tpa_Low_Always := O.TPA_Low_Always;
      P.Landing_Disarm_Threshold := O.Landing_Disarm;
      T.Config.Pid_Profiles (I) := P;
      if T.Asked.Endpoint_Inits < Natural'Last then
         T.Asked.Endpoint_Inits := T.Asked.Endpoint_Inits + 1;
      end if;
   end Leave_Profile_Other_Menu;

   procedure Leave_Launch_Control_Menu (T : in out Target)
     with Global => null
   is
      I : constant Natural := Shown_PID (T);
      P : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (I);
   begin
      P.Launch_Control_Mode := T.Launch.Mode;
      P.Launch_Control_Allow_Trigger_Reset := T.Launch.Allow_Reset;
      P.Launch_Control_Throttle_Percent := T.Launch.Throttle_Percent;
      P.Launch_Control_Angle_Limit := T.Launch.Angle_Limit;
      P.Launch_Control_Gain := T.Launch.Gain;
      T.Config.Pid_Profiles (I) := P;
   end Leave_Launch_Control_Menu;

   procedure Leave_OSD_Menu (T : in out Target)
     with Global => null
   is
   begin
      if T.Asked.Profile_Changes < Natural'Last then
         T.Asked.Profile_Changes := T.Asked.Profile_Changes + 1;
      end if;
      T.Asked.Profile_Asked := T.OSD.Profile;
      if T.OSD.Profile <= 3 then
         T.Config.Osd_Config.Osd_Profile_Index := T.OSD.Profile;
      end if;
   end Leave_OSD_Menu;

   procedure Leave_Active_Elements_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Osd_Element_Config.Item_Pos := T.Elements;
      if T.Asked.Element_Analyses < Natural'Last then
         T.Asked.Element_Analyses := T.Asked.Element_Analyses + 1;
      end if;
   end Leave_Active_Elements_Menu;

   procedure Leave_Timers_Menu (T : in out Target)
     with Global => null
   is
   begin
      for I in Timer_Fields'Range loop
         T.Config.Osd_Config.Timers (I) :=
           (Interfaces.Unsigned_16 (T.Timers.Source (I)) and 16#0F#)
           or (Interfaces.Unsigned_16 (T.Timers.Precision (I)) and 16#0F#) * 16
           or Interfaces.Unsigned_16 (T.Timers.Alarm (I)) * 256;
      end loop;
   end Leave_Timers_Menu;

   procedure Leave_Alarms_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Osd_Config.Rssi_Alarm := T.Alarms.RSSI;
      T.Config.Osd_Config.Link_Quality_Alarm := T.Alarms.Link_Quality;
      T.Config.Osd_Config.Rssi_Dbm_Alarm := T.Alarms.RSSI_Dbm;
      T.Config.Osd_Config.Rsnr_Alarm := T.Alarms.RSNR;
      T.Config.Osd_Config.Cap_Alarm := T.Alarms.Capacity;
      T.Config.Osd_Config.Alt_Alarm := T.Alarms.Altitude;
      T.Config.Osd_Config.Distance_Alarm := T.Alarms.Distance;
      T.Config.Battery_Config.Vbat_Duration_For_Warning := T.Alarms.Warning_Duration;
      T.Config.Battery_Config.Vbat_Duration_For_Critical := T.Alarms.Critical_Duration;
   end Leave_Alarms_Menu;

   procedure Leave_Blackbox_Menu (T : in out Target)
     with Global => null
   is
   begin
      if T.Live.Blackbox_May_Edit then
         T.Config.Blackbox_Config.Device := (if T.Blackbox.Device in 1 .. 3 then T.Blackbox.Device else 0);
      end if;
      T.Config.Blackbox_Config.Sample_Rate := T.Blackbox.Rate;
      T.Config.System_Config.Debug_Mode := T.Blackbox.Debug_Mode;
   end Leave_Blackbox_Menu;

   procedure Leave_LED_Strip_Menu (T : in out Target)
     with Global => null
   is
   begin
      declare
         Feature : constant Interfaces.Unsigned_32 := Adaflight.Config_Fix.Feature_LED_Strip;
      begin
         if T.LED.Enabled /= 0 then
            T.Config.Feature_Config.Enabled_Features := T.Config.Feature_Config.Enabled_Features or Feature;
            T.Live.Runtime_Features := T.Live.Runtime_Features or Feature;
            if T.Asked.LED_Strip_Enables < Natural'Last then
               T.Asked.LED_Strip_Enables := T.Asked.LED_Strip_Enables + 1;
            end if;
         else
            if T.Asked.LED_Strip_Disables < Natural'Last then
               T.Asked.LED_Strip_Disables := T.Asked.LED_Strip_Disables + 1;
            end if;
            T.Config.Feature_Config.Enabled_Features := T.Config.Feature_Config.Enabled_Features and not Feature;
            T.Live.Runtime_Features := T.Live.Runtime_Features and not Feature;
         end if;
      end;
      if T.LED.Profile < LED_Profile_Count then
         T.Config.Led_Strip_Config.Ledstrip_Profile := T.LED.Profile;
      end if;
      T.Config.Led_Strip_Config.Ledstrip_Race_Color := T.LED.Race_Color;
      T.Config.Led_Strip_Config.Ledstrip_Beacon_Color := T.LED.Beacon_Color;
      T.Config.Led_Strip_Config.Ledstrip_Beacon_Period_Ms := T.LED.Beacon_Period;
      T.Config.Led_Strip_Config.Ledstrip_Beacon_Percent := T.LED.Beacon_On_Percent;
      T.Config.Led_Strip_Config.Ledstrip_Beacon_Armed_Only := T.LED.Beacon_Armed_Only;
      T.Config.Led_Strip_Config.Ledstrip_Visual_Beeper := T.LED.Visual_Beeper;
      T.Config.Led_Strip_Config.Ledstrip_Visual_Beeper_Color := T.LED.Visual_Beeper_Color;
   end Leave_LED_Strip_Menu;

   procedure Leave_Power_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Battery_Config.Voltage_Meter_Source := T.Power.Voltage_Meter_Source;
      T.Config.Battery_Config.Current_Meter_Source := T.Power.Current_Meter_Source;
      T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatmincellvoltage := T.Power.Min_Cell_Voltage;
      T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatmaxcellvoltage := T.Power.Max_Cell_Voltage;
      T.Config.Battery_Profiles (T.Power.Battery_Profile).Vbatwarningcellvoltage := T.Power.Warning_Cell_Voltage;
      T.Config.Voltage_Sensor_Adc_Config (0).Vbatscale := T.Power.Voltage_Scale;
      T.Config.Current_Sensor_Adc_Config.Scale := T.Power.Current_Scale;
      T.Config.Current_Sensor_Adc_Config.Offset := T.Power.Current_Offset;
      T.Config.Current_Sensor_Virtual_Config.Scale := T.Power.Virtual_Scale;
      T.Config.Current_Sensor_Virtual_Config.Offset := T.Power.Virtual_Offset;
   end Leave_Power_Menu;

   procedure Leave_GPS_Rescue_Menu (T : in out Target)
     with Global => null
   is
      R  : Rescue_Copies renames T.Rescue;
      GR : Adaflight.Config_Groups.Gps_Rescue_Record := T.Config.Gps_Rescue_Config;
      AP : Adaflight.Config_Groups.Autopilot_Config_Record := T.Config.Autopilot_Config;
   begin
      GR.Min_Start_Dist_M := R.Min_Start_Dist_M;
      GR.Altitude_Mode := R.Altitude_Mode;
      GR.Initial_Climb_M := R.Initial_Climb_M;
      GR.Ascend_Rate := R.Ascend_Rate;
      GR.Return_Altitude_M := R.Return_Altitude_M;
      GR.Ground_Speed_Cm_S := R.Ground_Speed_Cm_S;
      AP.Max_Angle := R.Max_Angle;
      GR.Descent_Distance_M := R.Descent_Distance_M;
      GR.Descend_Rate := R.Descend_Rate;
      AP.Landing_Altitude_M := R.Landing_Altitude_M;
      AP.Throttle_Min := R.Throttle_Min;
      AP.Throttle_Max := R.Throttle_Max;
      AP.Hover_Throttle := R.Hover_Throttle;
      GR.Min_Sats := R.Min_Sats;
      GR.Allow_Arming_Without_Fix := R.Allow_Arming_Without_Fix;
      T.Config.Gps_Rescue_Config := GR;
      T.Config.Autopilot_Config := AP;
   end Leave_GPS_Rescue_Menu;

   procedure Leave_GPS_Rescue_PID_Menu (T : in out Target)
     with Global => null
   is
      P  : Rescue_PID_Copies renames T.Rescue_PID;
      AP : Adaflight.Config_Groups.Autopilot_Config_Record := T.Config.Autopilot_Config;
   begin
      AP.Altitude_P := P.Altitude_P;
      AP.Altitude_I := P.Altitude_I;
      AP.Altitude_D := P.Altitude_D;
      AP.Altitude_A := P.Altitude_A;
      AP.Altitude_F := P.Altitude_F;
      T.Config.Gps_Rescue_Config.Yaw_P := P.Yaw_P;
      AP.Position_P := P.Position_P;
      AP.Position_I := P.Position_I;
      AP.Position_D := P.Position_D;
      AP.Position_Cutoff := P.Position_Cutoff;
      T.Config.Autopilot_Config := AP;
   end Leave_GPS_Rescue_PID_Menu;

   procedure Leave_Failsafe_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Failsafe_Config.Failsafe_Procedure := T.Failsafe.Procedure_Kind;
      T.Config.Failsafe_Config.Failsafe_Delay := T.Failsafe.Guard_Time;
      T.Config.Failsafe_Config.Failsafe_Landing_Time := T.Failsafe.Landing_Time;
      T.Config.Failsafe_Config.Failsafe_Throttle := T.Failsafe.Throttle;
   end Leave_Failsafe_Menu;

   procedure Leave_RPM_Limit_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Mixer_Config.Rpm_Limit_Value := T.RPM_Limit.Limit;
      T.Config.Motor_Config.Kv := T.RPM_Limit.KV;
      T.Config.Mixer_Config.Rpm_Limit := T.RPM_Limit.Active;
   end Leave_RPM_Limit_Menu;

   procedure Leave_Misc_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Motor_Config.Motor_Idle := 10 * Interfaces.Unsigned_16 (T.Misc.Idle_Offset);
      T.Config.Rx_Config.Fpv_Cam_Angle_Degrees := T.Misc.FPV_Cam_Angle;
      T.Config.Mixer_Config.Crashflip_Rate := T.Misc.Crashflip_Rate;
   end Leave_Misc_Menu;

   procedure Leave_GPS_Lap_Timer_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Gps_Lap_Timer_Config.Minimum_Lap_Time_Seconds := T.Lap.Minimum_Lap_Time;
      T.Config.Gps_Lap_Timer_Config.Gate_Tolerance_M := T.Lap.Gate_Tolerance;
   end Leave_GPS_Lap_Timer_Menu;

   procedure Leave_Set_Gate_Menu (T : in out Target)
     with Global => null
   is
   begin
      if T.Asked.Gate_Ends < Natural'Last then
         T.Asked.Gate_Ends := T.Asked.Gate_Ends + 1;
      end if;
   end Leave_Set_Gate_Menu;

   procedure Leave_Persistent_Stats_Menu (T : in out Target)
     with Global => null
   is
   begin
      T.Config.Stats_Config.Stats_Total_Flights := T.Stats.Total_Flights;
      T.Config.Stats_Config.Stats_Total_Time_S := T.Stats.Total_Time_S;
      T.Config.Stats_Config.Stats_Total_Dist_M := T.Stats.Total_Dist_M;
      T.Config.Stats_Config.Stats_Min_Armed_Time_S := T.Stats.Min_Armed_Time;
   end Leave_Persistent_Stats_Menu;

   procedure Leave_Filter_Profile_Menu (T : in out Target)
     with Global => null
   is
      I : constant Natural := Current_PID (T);
      P : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (I);
   begin
      P.Dterm_Lpf1_Static_Hz := T.Profile_Flt.DTerm_LPF1;
      P.Dterm_Lpf2_Static_Hz := T.Profile_Flt.DTerm_LPF2;
      P.Dterm_Notch_Hz := T.Profile_Flt.DTerm_Notch_Hz;
      P.Dterm_Notch_Cutoff := T.Profile_Flt.DTerm_Notch_Cutoff;
      P.Yaw_Lowpass_Hz := T.Profile_Flt.Yaw_Lowpass;
      T.Config.Pid_Profiles (I) := P;
   end Leave_Filter_Profile_Menu;

   procedure Leave_Filter_Global_Menu (T : in out Target)
     with Global => null
   is
      G : Adaflight.Config_Groups.Gyro_Config_Record := T.Config.Gyro_Config;
   begin
      G.Gyro_Lpf1_Static_Hz := T.Global_Filt.Gyro_LPF1;
      G.Gyro_Lpf2_Static_Hz := T.Global_Filt.Gyro_LPF2;
      G.Gyro_Soft_Notch_Hz_1 := T.Global_Filt.Notch1_Hz;
      G.Gyro_Soft_Notch_Cutoff_1 := T.Global_Filt.Notch1_Cutoff;
      G.Gyro_Soft_Notch_Hz_2 := T.Global_Filt.Notch2_Hz;
      G.Gyro_Soft_Notch_Cutoff_2 := T.Global_Filt.Notch2_Cutoff;
      T.Config.Gyro_Config := G;
   end Leave_Filter_Global_Menu;

   procedure Leave_Dynamic_Filter_Menu (T : in out Target)
     with Global => null
   is
      I : constant Natural := Current_PID (T);
      G : Adaflight.Config_Groups.Gyro_Config_Record := T.Config.Gyro_Config;
      P : Adaflight.Config_Groups.Pid_Profile_Record := T.Config.Pid_Profiles (I);
   begin
      T.Config.Dyn_Notch_Config.Dyn_Notch_Max_Hz := T.Dynamic.Notch_Max_Hz;
      T.Config.Dyn_Notch_Config.Dyn_Notch_Count := T.Dynamic.Notch_Count;
      T.Config.Dyn_Notch_Config.Dyn_Notch_Q := T.Dynamic.Notch_Q;
      T.Config.Dyn_Notch_Config.Dyn_Notch_Min_Hz := T.Dynamic.Notch_Min_Hz;
      G.Gyro_Lpf1_Dyn_Min_Hz := T.Dynamic.Gyro_Min;
      G.Gyro_Lpf1_Dyn_Max_Hz := T.Dynamic.Gyro_Max;
      G.Gyro_Lpf1_Dyn_Expo := T.Dynamic.Gyro_Expo;
      T.Config.Gyro_Config := G;
      P.Dterm_Lpf1_Dyn_Min_Hz := T.Dynamic.DTerm_Min;
      P.Dterm_Lpf1_Dyn_Max_Hz := T.Dynamic.DTerm_Max;
      P.Dterm_Lpf1_Dyn_Expo := T.Dynamic.DTerm_Expo;
      T.Config.Pid_Profiles (I) := P;
   end Leave_Dynamic_Filter_Menu;

   procedure On_Leave (T : in out Target; Id : Menu_Id; Self : Integer; Chain_Back : out Boolean) is
   begin
      Chain_Back := False;
      case Id is
         when Filter_Profile_Menu =>
            Leave_Filter_Profile_Menu (T);
         when Filter_Global_Menu =>
            Leave_Filter_Global_Menu (T);
         when Dynamic_Filter_Menu =>
            Leave_Dynamic_Filter_Menu (T);
         when Quick_Menu =>
            Leave_Quick_Menu (T);
         when Profile_Menu =>
            Leave_Profile_Menu (T);
         when PID_Menu =>
            Leave_PID_Menu (T);
         when Rate_Menu =>
            Leave_Rate_Menu (T);
         when Simplified_Menu =>
            Leave_Simplified_Menu (T);
         when Profile_Other_Menu =>
            Leave_Profile_Other_Menu (T);
         when Launch_Control_Menu =>
            Leave_Launch_Control_Menu (T);
         when OSD_Menu =>
            Leave_OSD_Menu (T);
         when Active_Elements_Menu =>
            Leave_Active_Elements_Menu (T);
         when Timers_Menu =>
            Leave_Timers_Menu (T);
         when Alarms_Menu =>
            Leave_Alarms_Menu (T);
         when Blackbox_Menu =>
            Leave_Blackbox_Menu (T);
         when LED_Strip_Menu =>
            Leave_LED_Strip_Menu (T);
         when Power_Menu =>
            Leave_Power_Menu (T);
         when Failsafe_Menu =>
            Leave_Failsafe_Menu (T);
         when GPS_Rescue_Menu =>
            Leave_GPS_Rescue_Menu (T);
         when GPS_Rescue_PID_Menu =>
            Leave_GPS_Rescue_PID_Menu (T);
         when RPM_Limit_Menu =>
            Leave_RPM_Limit_Menu (T);
         when Misc_Menu =>
            Leave_Misc_Menu (T);
         when RC_Preview_Menu =>
            Chain_Back := Self /= 9;
         when GPS_Lap_Timer_Menu =>
            Leave_GPS_Lap_Timer_Menu (T);
         when Set_Gate_Menu =>
            Leave_Set_Gate_Menu (T);
         when Persistent_Stats_Menu =>
            Leave_Persistent_Stats_Menu (T);
         when others =>
            null;
      end case;
   end On_Leave;

   --  The battery restore line's text: the stored charge in five places,
   --  cut to the reference's eighteen byte buffer.
   function Restore_Text (MAh : Interfaces.Unsigned_32) return Adaflight.Menu.Label_Text
     with Global => null
   is
      Signed : constant Interfaces.Integer_64 :=
        (if MAh < 2 ** 31 then Interfaces.Integer_64 (MAh) else Interfaces.Integer_64 (MAh) - 2 ** 32);
      Image  : constant String := Interfaces.Integer_64'Image (Signed);
      Number : constant String := (if Signed >= 0 then Image (Image'First + 1 .. Image'Last) else Image);
      Padded : constant String := (if Number'Length < 5 then (1 .. 5 - Number'Length => ' ') & Number else Number);
      Full   : constant String := "RESTORE " & Padded & " MAH";
   begin
      return Label (Full (Full'First .. Full'First + Natural'Min (Full'Length, 17) - 1));
   end Restore_Text;

   procedure On_Display_Update (T : in out Target; Id : Menu_Id; Selected : Natural; Chain_Back : out Boolean) is
      pragma Unreferenced (Selected);

      --  A channel reading rounded to a whole number with ties to even, as
      --  the C library rounds.
      function Whole_Channel (X : RC_Reading) return Interfaces.Integer_16
        with Global => null
      is
         R : constant Integer := Integer (X);
      begin
         if abs (Float (R) - X) = 0.5 and then R mod 2 /= 0 then
            return Interfaces.Integer_16 (if X > 0.0 then R - 1 else R + 1);
         end if;
         return Interfaces.Integer_16 (R);
      end Whole_Channel;
   begin
      Chain_Back := False;
      if Id = RC_Preview_Menu then
         for C in RC_Values'Range loop
            T.Preview (C) := Whole_Channel (T.Live.RC_Data (C));
         end loop;
      end if;
      if Id = Calibration_Menu then
         T.Calibration.Gyro :=
           Label (if not T.Live.Gyro_Present then " --- " elsif T.Live.Gyro_Calibration_Complete then "  OK "
                  else "WAIT ");
         T.Calibration.Acc :=
           Label (if not T.Live.Acc_Present then " --- " elsif not T.Live.Acc_Calibration_Complete then "WAIT "
                  elsif T.Live.Acc_Calibrated then "  OK " else " NOK ");
         T.Calibration.Baro :=
           Label (if not T.Live.Baro_Present then " --- " elsif T.Live.Baro_Calibrated then "  OK " else "WAIT ");
      end if;
      if Id = Setup_Popup then
         T.Popup.Acc_Status :=
           Label (if not T.Live.Acc_Calibration_Complete then "  ACTIVE"
                  elsif T.Live.Acc_Calibrated then "COMPLETE" else "REQUIRED");
         if T.Live.Used_MAh then
            T.Popup.Battery_Text := Restore_Text (T.Config.Stats_Config.Stats_Mah_Used);
         end if;
      end if;
   end On_Display_Update;

   procedure Line_Call (T : in out Target; Id : Menu_Id; Line : Natural; Reply : out Adaflight.Menu.Answer) is
      M : Table;
   begin
      Reply := (others => <>);
      Load (T, Id, M);
      if Line >= M.Count then
         return;
      end if;
      case Adaflight.Menu.Element_Of (M.Lines (Line).Flags) is
         when Adaflight.Menu.OSD_Exit =>
            if Id = VTX_Tramp_Confirm and then Line = 1 then
               Commence_VTX (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.Tramp, T.Config.Vtx_Settings_Config);
               Reply.Screens := 1;
               Reply.Screen (1).Kind := Adaflight.Menu.Save_Config;
            elsif Id = SA_Confirm_Menu and then Line = 1 then
               declare
                  Saved : Boolean;
               begin
                  SA_Commence (T, Saved);
                  if Saved then
                     Reply.Screens := 1;
                     Reply.Screen (1).Kind := Adaflight.Menu.Save_Config;
                  end if;
               end;
            end if;
            Reply.Done := Adaflight.Menu.Exited;
            Reply.Kind := (if M.Lines (Line).Value in 0 .. 5 then Adaflight.Menu.Exit_Kind'Val (M.Lines (Line).Value)
                           else Adaflight.Menu.Plain);
         when Adaflight.Menu.Funcall =>
            if Id = Main_Menu then
               Reply.Done := Adaflight.Menu.Changed;
               Reply.Target := (if T.Live.Reboot_Required then Save_Exit_Reboot else Save_Exit);
            elsif Id = Setup_Popup and then T.Popup.Acc_Line and then Line = 1 then
               if T.Live.Acc_Present then
                  Reply.Done := Adaflight.Menu.Changed;
                  Reply.Target := Calibrate_Acc_Menu;
               end if;
            elsif Id = Calibration_Menu and then Line = 1 then
               if T.Live.Gyro_Present and then T.Asked.Gyro_Calibrations < Natural'Last then
                  T.Asked.Gyro_Calibrations := T.Asked.Gyro_Calibrations + 1;
               end if;
            elsif Id = Calibration_Menu and then Line = 2 then
               if T.Live.Acc_Present then
                  Reply.Done := Adaflight.Menu.Changed;
                  Reply.Target := Calibrate_Acc_Menu;
               end if;
            elsif Id = Calibration_Menu and then Line = 3 then
               if T.Live.Baro_Present and then T.Asked.Baro_Calibrations < Natural'Last then
                  T.Asked.Baro_Calibrations := T.Asked.Baro_Calibrations + 1;
               end if;
            elsif Id = Calibrate_Acc_Menu then
               if T.Live.Acc_Present and then T.Asked.Acc_Calibrations < Natural'Last then
                  T.Asked.Acc_Calibrations := T.Asked.Acc_Calibrations + 1;
               end if;
               Reply.Chain_Back := True;
            elsif (Id = Quick_Menu and then Line = 6) or else (Id = Features and then Line = 2) then
               Reply.Done := Adaflight.Menu.Changed;
               Reply.Target :=
                 (if not T.Live.VTX_Present then VTX_Error_Menu
                  else (case T.Live.VTX_Type is
                           when 1 => VTX_RTC6705_Menu,
                           when 3 => VTX_SmartAudio_Menu,
                           when 4 => VTX_Tramp_Menu,
                           when 5 => VTX_MSP_Menu,
                           when others => VTX_Error_Menu));
            elsif Id = Copy_Profile_Menu and then Line = 2 then
               if T.Copy.PID_Target > 0 then
                  declare
                     Dst : constant Interfaces.Unsigned_8 := T.Copy.PID_Target - 1;
                     Src : constant Interfaces.Unsigned_8 := T.Config.System_Config.Pid_Profile_Index;
                  begin
                     if Dst < PID_Profile_Count and then Src < PID_Profile_Count and then Dst /= Src then
                        T.Config.Pid_Profiles (Natural (Dst)) := T.Config.Pid_Profiles (Natural (Src));
                     end if;
                  end;
               end if;
            elsif Id = Copy_Profile_Menu and then Line = 4 then
               if T.Copy.Rate_Target > 0 then
                  declare
                     Dst : constant Interfaces.Unsigned_8 := T.Copy.Rate_Target - 1;
                     Src : constant Interfaces.Unsigned_8 := T.Config.System_Config.Active_Rate_Profile;
                  begin
                     if Dst < Rate_Profile_Count and then Src < Rate_Profile_Count and then Dst /= Src then
                        T.Config.Control_Rate_Profiles (Natural (Dst)) :=
                          T.Config.Control_Rate_Profiles (Natural (Src));
                     end if;
                  end;
               end if;
            elsif Id = VTX_MSP_Confirm and then Line = 1 then
               Commence_VTX (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.MSP, T.Config.Vtx_Settings_Config);
               Reply.Screens := 1;
               Reply.Screen (1).Kind := Adaflight.Menu.Save_Config;
               Reply.Chain_Back := True;
            elsif Id = SA_POR_Freq_Menu and then Line = 3 then
               Adaflight.SmartAudio.Set_Pit_Frequency (T.VTX.SA, T.VTX.SA_Menu.OR_Freq_New);
            elsif Id = SA_User_Freq_Menu and then Line = 3 then
               T.VTX.SA_Menu.User_Freq := T.VTX.SA_Menu.User_Freq_New;
               Reply.Chain_Back := True;
            elsif Id = Erase_Flash_Menu then
               if T.Live.Flash_Supported then
                  Reply.Screens := 5;
                  Reply.Screen (1).Kind := Adaflight.Menu.Clear_Wait;
                  Reply.Screen (2) := Screen_Text (5, 3, "ERASING FLASH...");
                  Reply.Screen (3).Kind := Adaflight.Menu.Redraw;
                  if T.Asked.Flash_Erases < Natural'Last then
                     T.Asked.Flash_Erases := T.Asked.Flash_Erases + 1;
                  end if;
                  if T.Asked.Erase_Beeps < Natural'Last then
                     T.Asked.Erase_Beeps := T.Asked.Erase_Beeps + 1;
                  end if;
                  Reply.Screen (4).Kind := Adaflight.Menu.Clear_Wait;
                  Reply.Screen (5).Kind := Adaflight.Menu.Redraw;
                  Device_Status (T, 0);
                  Reply.Chain_Back := True;
               end if;
            elsif Id = Storage_Device_Menu then
               if T.Live.Storage_Ready then
                  Reply.Screens := 4;
                  Reply.Screen (1).Kind := Adaflight.Menu.Clear_Wait;
                  Reply.Screen (2) := Screen_Text (2, 4, "USB MASS STORAGE MODE IS ON");
                  Reply.Screen (3) := Screen_Text (4, 5, "CONNECT YOUR GADGET");
                  Reply.Screen (4).Kind := Adaflight.Menu.Redraw;
                  if T.Asked.MSC_Resets < Natural'Last then
                     T.Asked.MSC_Resets := T.Asked.MSC_Resets + 1;
                  end if;
                  T.Asked.MSC_Reset_Offset := T.Config.Time_Config.Tz_Offset_Minutes;
               else
                  Reply.Screens := 2;
                  Reply.Screen (1) := Screen_Text (5, 3, "STORAGE NOT PRESENT OR FAILED TO INITIALIZE!");
                  Reply.Screen (2).Kind := Adaflight.Menu.Redraw;
                  Reply.Chain_Back := True;
               end if;
            elsif Id = Persistent_Stats_Menu then
               T.Stats.Total_Flights := 0;
               T.Stats.Total_Time_S := 0;
               T.Stats.Total_Dist_M := 0;
               Reply.Screens := 2;
               Reply.Screen (1).Kind := Adaflight.Menu.Clear_Wait;
               Reply.Screen (2).Kind := Adaflight.Menu.Redraw;
            elsif Id = Setup_Popup then
               if T.Asked.MAh_Restores < Natural'Last then
                  T.Asked.MAh_Restores := T.Asked.MAh_Restores + 1;
               end if;
               T.Asked.MAh_Restored := T.Config.Stats_Config.Stats_Mah_Used;
               T.Config.Stats_Config.Stats_Mah_Used := 0;
               Reply.Done := Adaflight.Menu.Exited;
               Reply.Kind := Adaflight.Menu.Plain;
            end if;
         when Adaflight.Menu.Bool | Adaflight.Menu.UInt8 | Adaflight.Menu.Tab =>
            if Id = Profile_Menu and then Line = 1 then
               T.Profile.PID_Index := T.Profile.PID_Line;
               Change_PID_Profile (T, T.Profile.PID_Index);
            elsif Id = Profile_Menu and then Line = 6 then
               T.Profile.Rate_Index := T.Profile.Rate_Line;
               Change_Rate_Profile (T, T.Profile.Rate_Index);
            elsif Id = OSD_Menu and then Line in 5 .. 7 then
               T.Config.Display_Port_Profile_Max7456.Invert := T.OSD.Invert;
               T.Config.Display_Port_Profile_Max7456.Black_Brightness := T.OSD.Black_Brightness;
               T.Config.Display_Port_Profile_Max7456.White_Brightness := T.OSD.White_Brightness;
               Reply.Screens := 1;
               Reply.Screen (1).Kind := Adaflight.Menu.Clear_Wait;
            elsif Id = VTX_MSP_Menu then
               VTX_Line_Changed (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.MSP, Line);
            elsif Id = VTX_Tramp_Menu then
               VTX_Line_Changed (T.VTX, T.VTX_Table, T.Live.VTX_Present, T.Tramp, Line);
            elsif Id = VTX_SmartAudio_Menu then
               SA_Top_Line_Changed (T, Line);
            elsif Id = SA_Config_Menu then
               case Line is
                  when 1 => SA_Opmodel_Changed (T);
                  when 2 => SA_Freq_Mode_Changed (T);
                  when 3 => SA_Pit_F_Mode_Changed (T);
                  when others => null;
               end case;
            elsif Id = OSD_Menu and then Line = 8 then
               T.Config.Osd_Config.Cms_Background_Type := T.OSD.Background;
               Reply.Screens := 1;
               Reply.Screen (1) := (Kind => Adaflight.Menu.Set_Background, Attr => T.OSD.Background, others => <>);
            end if;
         when others =>
            null;
      end case;
   end Line_Call;

   procedure Set_Value (T : in out Target; Id : Menu_Id; Line : Natural; Value : Interfaces.Integer_32) is
      function Signed_Byte (V : Interfaces.Integer_32) return Interfaces.Integer_8 is
        (Interfaces.Integer_8 ((Interfaces.Integer_64 (V) + 128) mod 256 - 128));
      Byte  : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Value mod 256);
      Word  : constant Interfaces.Unsigned_16 := Interfaces.Unsigned_16 (Value mod 65_536);
      Short : constant Interfaces.Integer_16 :=
        Interfaces.Integer_16 ((Interfaces.Integer_64 (Value) + 32_768) mod 65_536 - 32_768);
   begin
      if Id = Profile_Menu then
         case Line is
            when 1 => T.Profile.PID_Line := Byte;
            when 6 => T.Profile.Rate_Line := Byte;
            when others => null;
         end case;
      elsif Id = PID_Menu then
         if Line in 1 .. 12 then
            if (Line - 1) mod 4 = 3 then
               T.PID.Feedforward ((Line - 1) / 4) := Word;
            else
               T.PID.Gains ((Line - 1) / 4, (Line - 1) mod 4) := Byte;
            end if;
         end if;
      elsif Id = Filter_Profile_Menu then
         case Line is
            when 1 => T.Profile_Flt.DTerm_LPF1 := Word;
            when 2 => T.Profile_Flt.DTerm_LPF2 := Word;
            when 3 => T.Profile_Flt.DTerm_Notch_Hz := Word;
            when 4 => T.Profile_Flt.DTerm_Notch_Cutoff := Word;
            when 5 => T.Profile_Flt.Yaw_Lowpass := Word;
            when others => null;
         end case;
      elsif Id = Filter_Global_Menu then
         case Line is
            when 1 => T.Global_Filt.Gyro_LPF1 := Word;
            when 2 => T.Global_Filt.Gyro_LPF2 := Word;
            when 3 => T.Global_Filt.Notch1_Hz := Word;
            when 4 => T.Global_Filt.Notch1_Cutoff := Word;
            when 5 => T.Global_Filt.Notch2_Hz := Word;
            when 6 => T.Global_Filt.Notch2_Cutoff := Word;
            when others => null;
         end case;
      elsif Id = Dynamic_Filter_Menu then
         case Line is
            when 1 => T.Dynamic.Notch_Count := Byte;
            when 2 => T.Dynamic.Notch_Q := Word;
            when 3 => T.Dynamic.Notch_Min_Hz := Word;
            when 4 => T.Dynamic.Notch_Max_Hz := Word;
            when 5 => T.Dynamic.Gyro_Min := Word;
            when 6 => T.Dynamic.Gyro_Max := Word;
            when 7 => T.Dynamic.Gyro_Expo := Byte;
            when 8 => T.Dynamic.DTerm_Min := Word;
            when 9 => T.Dynamic.DTerm_Max := Word;
            when 10 => T.Dynamic.DTerm_Expo := Byte;
            when others => null;
         end case;
      elsif Id = Copy_Profile_Menu then
         case Line is
            when 1 => T.Copy.PID_Target := Byte;
            when 3 => T.Copy.Rate_Target := Byte;
            when others => null;
         end case;
      elsif Id = Simplified_Menu then
         case Line is
            when 1 => T.Simplified.Mode := Byte;
            when 3 => T.Simplified.D_Gain := Byte;
            when 4 => T.Simplified.PI_Gain := Byte;
            when 5 => T.Simplified.FF_Gain := Byte;
            when 7 => T.Simplified.D_Max_Gain := Byte;
            when 8 => T.Simplified.I_Gain := Byte;
            when 9 => T.Simplified.Roll_Pitch_Ratio := Byte;
            when 10 => T.Simplified.Pitch_PI_Gain := Byte;
            when 11 => T.Simplified.Master := Byte;
            when 13 => T.Simplified.Gyro_Filter := Byte;
            when 14 => T.Simplified.Gyro_Multiplier := Byte;
            when 15 => T.Simplified.DTerm_Filter := Byte;
            when 16 => T.Simplified.DTerm_Multiplier := Byte;
            when others => null;
         end case;
      elsif Id = Profile_Other_Menu then
         case Line is
            when 1 => T.Other.FF_Transition := Byte;
            when 2 => T.Other.FF_Averaging := Byte;
            when 3 => T.Other.FF_Smooth := Byte;
            when 4 => T.Other.FF_Jitter := Byte;
            when 5 => T.Other.FF_Boost := Byte;
            when 6 => T.Other.Angle_P := Byte;
            when 7 => T.Other.Angle_FF := Byte;
            when 8 => T.Other.Angle_Limit := Byte;
            when 9 => T.Other.Angle_Earth_Ref := Byte;
            when 10 => T.Other.Horizon_Strength := Byte;
            when 11 => T.Other.Horizon_Sticks := Byte;
            when 12 => T.Other.Horizon_Degrees := Byte;
            when 13 => T.Other.Anti_Gravity_Gain := Byte;
            when 14 => T.Other.Throttle_Boost := Byte;
            when 15 => T.Other.Thrust_Linearization := Byte;
            when 16 => T.Other.Iterm_Relax := Byte;
            when 17 => T.Other.Iterm_Relax_Type := Byte;
            when 18 => T.Other.Iterm_Relax_Cutoff := Byte;
            when 20 => T.Other.Motor_Output_Limit := Byte;
            when 21 => T.Other.Auto_Cell_Count := Signed_Byte (Value);
            when 22 .. 24 => T.Other.D_Max (Line - 22) := Byte;
            when 25 => T.Other.D_Max_Gain := Byte;
            when 26 => T.Other.D_Max_Advance := Byte;
            when 27 => T.Other.Vbat_Sag := Byte;
            when 28 => T.Other.TPA_Rate := Byte;
            when 29 => T.Other.TPA_Breakpoint := Word;
            when 30 => T.Other.TPA_Low_Rate := Signed_Byte (Value);
            when 31 => T.Other.TPA_Low_Breakpoint := Word;
            when 32 => T.Other.TPA_Low_Always := Byte;
            when 33 => T.Other.Landing_Disarm := Byte;
            when others => null;
         end case;
      elsif Id = Launch_Control_Menu then
         case Line is
            when 1 => T.Launch.Mode := Byte;
            when 2 => T.Launch.Allow_Reset := Byte;
            when 3 => T.Launch.Throttle_Percent := Byte;
            when 4 => T.Launch.Angle_Limit := Byte;
            when 5 => T.Launch.Gain := Byte;
            when others => null;
         end case;
      elsif Id = Rate_Menu then
         case Line is
            when 1 .. 3 => T.Rate.Profile.Rc_Rates (Line - 1) := Byte;
            when 4 .. 6 => T.Rate.Profile.Rates (Line - 4) := Byte;
            when 7 .. 9 => T.Rate.Profile.Rc_Expo (Line - 7) := Byte;
            when 10 => T.Rate.Profile.Thr_Mid8 := Byte;
            when 11 => T.Rate.Profile.Thr_Expo8 := Byte;
            when 12 => T.Rate.Profile.Thr_Hover8 := Byte;
            when 13 => T.Rate.Profile.Throttle_Limit_Type := Byte;
            when 14 => T.Rate.Profile.Throttle_Limit_Percent := Byte;
            when others => null;
         end case;
      elsif Id = OSD_Menu then
         case Line is
            when 1 => T.OSD.Profile := Byte;
            when 5 => T.OSD.Invert := Value /= 0;
            when 6 => T.OSD.Black_Brightness := Byte;
            when 7 => T.OSD.White_Brightness := Byte;
            when 8 => T.OSD.Background := Byte;
            when others => null;
         end case;
      elsif Id = Active_Elements_Menu then
         if Line in Active_Lines'Range then
            T.Elements (Adaflight.OSD_Elements.Item'Pos (Active_Lines (Line).Item)) := Word;
         end if;
      elsif Id = Timers_Menu then
         case Line is
            when 1 => T.Timers.Source (0) := Byte;
            when 2 => T.Timers.Precision (0) := Byte;
            when 3 => T.Timers.Alarm (0) := Byte;
            when 4 => T.Timers.Source (1) := Byte;
            when 5 => T.Timers.Precision (1) := Byte;
            when 6 => T.Timers.Alarm (1) := Byte;
            when others => null;
         end case;
      elsif Id = Alarms_Menu then
         case Line is
            when 1 => T.Alarms.RSSI := Byte;
            when 2 => T.Alarms.Link_Quality := Word;
            when 3 => T.Alarms.RSSI_Dbm := Short;
            when 4 => T.Alarms.RSNR := Short;
            when 5 => T.Alarms.Capacity := Word;
            when 6 => T.Alarms.Altitude := Word;
            when 7 => T.Alarms.Distance := Word;
            when 8 => T.Alarms.Warning_Duration := Byte;
            when 9 => T.Alarms.Critical_Duration := Byte;
            when others => null;
         end case;
      elsif Id = Blackbox_Menu then
         case Line is
            when 2 => T.Blackbox.Rate := Byte;
            when 3 => T.Blackbox.Device := Byte;
            when 7 => T.Blackbox.Debug_Mode := Byte;
            when others => null;
         end case;
      elsif Id = GPS_Rescue_Menu then
         case Line is
            when 1 => T.Rescue.Min_Start_Dist_M := Word;
            when 2 => T.Rescue.Altitude_Mode := Byte;
            when 3 => T.Rescue.Initial_Climb_M := Word;
            when 4 => T.Rescue.Ascend_Rate := Word;
            when 5 => T.Rescue.Return_Altitude_M := Word;
            when 6 => T.Rescue.Ground_Speed_Cm_S := Word;
            when 7 => T.Rescue.Max_Angle := Byte;
            when 8 => T.Rescue.Descent_Distance_M := Word;
            when 9 => T.Rescue.Descend_Rate := Word;
            when 10 => T.Rescue.Landing_Altitude_M := Byte;
            when 11 => T.Rescue.Throttle_Min := Word;
            when 12 => T.Rescue.Throttle_Max := Word;
            when 13 => T.Rescue.Hover_Throttle := Word;
            when 14 => T.Rescue.Min_Sats := Byte;
            when 15 => T.Rescue.Allow_Arming_Without_Fix := Byte;
            when others => null;
         end case;
      elsif Id = GPS_Rescue_PID_Menu then
         case Line is
            when 1 => T.Rescue_PID.Altitude_P := Byte;
            when 2 => T.Rescue_PID.Altitude_I := Byte;
            when 3 => T.Rescue_PID.Altitude_D := Byte;
            when 4 => T.Rescue_PID.Altitude_A := Byte;
            when 5 => T.Rescue_PID.Altitude_F := Byte;
            when 6 => T.Rescue_PID.Yaw_P := Byte;
            when 7 => T.Rescue_PID.Position_P := Byte;
            when 8 => T.Rescue_PID.Position_I := Byte;
            when 9 => T.Rescue_PID.Position_D := Byte;
            when 10 => T.Rescue_PID.Position_Cutoff := Byte;
            when others => null;
         end case;
      elsif Id = VTX_MSP_Menu then
         case Line is
            when 2 => T.MSP.Pit_Mode := Byte;
            when 3 => T.MSP.Band := Byte;
            when 4 => T.MSP.Channel := Byte;
            when 5 => T.MSP.Freq_Ref := Word;
            when 6 => T.MSP.Power := Byte;
            when others => null;
         end case;
      elsif Id = VTX_SmartAudio_Menu then
         case T.SA_Top is
            when Channel_Lines =>
               case Line is
                  when 2 => T.VTX.SA_Menu.Band := Byte;
                  when 3 => T.VTX.SA_Menu.Channel := Byte;
                  when 4 => T.VTX.SA_Menu.Freq_Ref := Word;
                  when 5 => T.VTX.SA_Menu.Power := Byte;
                  when 6 => T.VTX.SA_Menu.Pit := Byte;
                  when others => null;
               end case;
            when Frequency_Lines =>
               case Line is
                  when 3 => T.VTX.SA_Menu.Power := Byte;
                  when 4 => T.VTX.SA_Menu.Pit := Byte;
                  when others => null;
               end case;
            when Offline_Lines =>
               null;
         end case;
      elsif Id = SA_Config_Menu then
         case Line is
            when 1 => T.VTX.SA_Menu.Opmodel := Byte;
            when 2 => T.VTX.SA_Menu.Fsel_Mode_New := Byte;
            when 3 => T.VTX.SA_Menu.Pit_F_Mode := Byte;
            when others => null;
         end case;
      elsif Id = SA_Stats_Menu then
         if Line = 1 then
            T.VTX.SA_Menu.Device_Status := Byte;
         end if;
      elsif Id = SA_POR_Freq_Menu then
         case Line is
            when 1 => T.VTX.SA_Menu.OR_Freq := Word;
            when 2 => T.VTX.SA_Menu.OR_Freq_New := Word;
            when others => null;
         end case;
      elsif Id = SA_User_Freq_Menu then
         case Line is
            when 1 => T.VTX.SA_Menu.User_Freq := Word;
            when 2 => T.VTX.SA_Menu.User_Freq_New := Word;
            when others => null;
         end case;
      elsif Id = VTX_Tramp_Menu then
         case Line is
            when 2 => T.Tramp.Pit_Mode := Byte;
            when 3 => T.Tramp.Band := Byte;
            when 4 => T.Tramp.Channel := Byte;
            when 5 => T.Tramp.Freq_Ref := Word;
            when 6 => T.Tramp.Power := Byte;
            when 7 => T.Tramp_Temp := Short;
            when others => null;
         end case;
      elsif Id = LED_Strip_Menu then
         case Line is
            when 1 => T.LED.Enabled := Byte;
            when 2 => T.LED.Profile := Byte;
            when 3 => T.LED.Race_Color := Byte;
            when 4 => T.LED.Beacon_Color := Byte;
            when 5 => T.LED.Beacon_Period := Word;
            when 6 => T.LED.Beacon_On_Percent := Byte;
            when 7 => T.LED.Beacon_Armed_Only := Byte;
            when 8 => T.LED.Visual_Beeper := Byte;
            when 9 => T.LED.Visual_Beeper_Color := Byte;
            when others => null;
         end case;
      elsif Id = Power_Menu then
         case Line is
            when 1 => T.Power.Voltage_Meter_Source := Byte;
            when 2 => T.Power.Current_Meter_Source := Byte;
            when 3 => T.Power.Min_Cell_Voltage := Word;
            when 4 => T.Power.Max_Cell_Voltage := Word;
            when 5 => T.Power.Warning_Cell_Voltage := Word;
            when 6 => T.Power.Voltage_Scale := Byte;
            when 7 => T.Power.Current_Scale := Short;
            when 8 => T.Power.Current_Offset := Short;
            when 9 => T.Power.Virtual_Scale := Short;
            when 10 => T.Power.Virtual_Offset := Word;
            when others => null;
         end case;
      elsif Id = Failsafe_Menu then
         case Line is
            when 1 => T.Failsafe.Procedure_Kind := Byte;
            when 2 => T.Failsafe.Guard_Time := Byte;
            when 3 => T.Failsafe.Landing_Time := Byte;
            when 4 => T.Failsafe.Throttle := Word;
            when others => null;
         end case;
      elsif Id = Misc_Menu then
         case Line is
            when 1 => T.Misc.Idle_Offset := Byte;
            when 2 => T.Misc.FPV_Cam_Angle := Byte;
            when 3 => T.Misc.Crashflip_Rate := Byte;
            when others => null;
         end case;
      elsif Id = Persistent_Stats_Menu then
         case Line is
            when 1 => T.Stats.Total_Flights := Interfaces.Unsigned_32'Mod (Value);
            when 2 => T.Stats.Total_Time_S := Interfaces.Unsigned_32'Mod (Value);
            when 3 => T.Stats.Total_Dist_M := Interfaces.Unsigned_32'Mod (Value);
            when 6 => T.Stats.Min_Armed_Time := Signed_Byte (Value);
            when others => null;
         end case;
      elsif Id = GPS_Lap_Timer_Menu then
         case Line is
            when 2 => T.Lap.Gate_Tolerance := Byte;
            when 3 => T.Lap.Minimum_Lap_Time := Word;
            when others => null;
         end case;
      elsif Id = RPM_Limit_Menu then
         case Line is
            when 1 => T.RPM_Limit.Active := Value /= 0;
            when 2 => T.RPM_Limit.Limit := Word;
            when 3 => T.RPM_Limit.KV := Word;
            when others => null;
         end case;
      elsif Id = Quick_Menu then
         case Line is
            when 2 => T.Quick.Rate.Throttle_Limit_Type := Byte;
            when 3 => T.Quick.Rate.Throttle_Limit_Percent := Byte;
            when 4 => T.Quick.Motor_Output_Limit := Byte;
            when 5 => T.Quick.Battery.Force_Battery_Cell_Count := Byte;
            when others => null;
         end case;
      end if;
   end Set_Value;

   procedure Refresh (T : Target; Id : Menu_Id; M : in out Table) is
      Fresh : Table;
   begin
      Load (T, Id, Fresh);
      if Fresh.Count = M.Count then
         M := Fresh;
      end if;
   end Refresh;

   --  The SmartAudio menu's names by line: band, channel, power and pit mode.
   function SA_Top_Name (T : Target; Line : Natural; Index : Natural) return Adaflight.Menu.Label_Text is
     (case T.SA_Top is
         when Channel_Lines =>
           (case Line is
               when 2 => Band_Name (T.VTX_Table, Index),
               when 3 => Channel_Name (T.VTX_Table, Index),
               when 5 => Power_Name (T.VTX_Table, Index),
               when 6 => Pit_Mode_Name (Index),
               when others => Label ("")),
         when Frequency_Lines =>
           (case Line is
               when 3 => Power_Name (T.VTX_Table, Index),
               when 4 => Pit_Mode_Name (Index),
               when others => Label ("")),
         when Offline_Lines => Label (""));

   function Lookup (T : Target; Id : Menu_Id; Line : Natural; Index : Natural) return Adaflight.Menu.Label_Text is
   begin
      return (if Id = Quick_Menu and then Line = 2 then Throttle_Limit_Name (Index)
              elsif Id = Power_Menu and then Line = 1 then Voltage_Meter_Name (Index)
              elsif Id = Power_Menu and then Line = 2 then Current_Meter_Name (Index)
              elsif Id = Failsafe_Menu and then Line = 1 then Procedure_Name (Index)
              elsif Id = GPS_Rescue_Menu and then Line = 2
              then Setting_Name (Adaflight.Settings_Table.Table_Gps_Rescue_Alt_Mode, Index)
              elsif Id = Profile_Menu and then Line = 1 then Profile_Name (T.Profile.PID_Names, Index)
              elsif Id = Profile_Menu and then Line = 6 then Profile_Name (T.Profile.Rate_Names, Index)
              elsif Id = Rate_Menu and then Line = 13 then Throttle_Limit_Name (Index)
              elsif Id = Copy_Profile_Menu and then Line in 1 | 3 then Profile_Target_Name (Index)
              elsif Id = Simplified_Menu and then Line = 1
              then Setting_Name (Adaflight.Settings_Table.Table_Simplified_Tuning_Pids_Mode, Index)
              elsif Id = Simplified_Menu and then Line in 13 | 15
              then Setting_Name (Adaflight.Settings_Table.Table_Off_On, Index)
              elsif Id = Profile_Other_Menu and then Line = 2
              then Setting_Name (Adaflight.Settings_Table.Table_Feedforward_Averaging, Index)
              elsif Id = Profile_Other_Menu and then Line = 16
              then Setting_Name (Adaflight.Settings_Table.Table_Iterm_Relax, Index)
              elsif Id = Profile_Other_Menu and then Line = 17
              then Setting_Name (Adaflight.Settings_Table.Table_Iterm_Relax_Type, Index)
              elsif Id = Launch_Control_Menu and then Line = 1
              then Setting_Name (Adaflight.Settings_Table.Table_Launch_Control_Mode, Index)
              elsif Id = OSD_Menu and then Line = 8 then Background_Name (Index)
              elsif Id = Timers_Menu and then Line in 1 | 4 then Timer_Source_Name (Index)
              elsif Id = Timers_Menu and then Line in 2 | 5 then Timer_Precision_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 2 then Blackbox_Rate_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 3 then Blackbox_Device_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 7 then Debug_Name (Index)
              elsif Id = LED_Strip_Menu and then Line = 2 then LED_Profile_Name (Index)
              elsif Id = LED_Strip_Menu and then Line in 3 | 4 | 9 then LED_Color_Name (Index)
              elsif Id = VTX_MSP_Menu and then Line = 2 then Pit_Mode_Name (Index)
              elsif Id = VTX_MSP_Menu and then Line = 3 then Band_Name (T.VTX_Table, Index)
              elsif Id = VTX_MSP_Menu and then Line = 4 then Channel_Name (T.VTX_Table, Index)
              elsif Id = VTX_MSP_Menu and then Line = 6 then Power_Name (T.VTX_Table, Index)
              elsif Id = VTX_SmartAudio_Menu then SA_Top_Name (T, Line, Index)
              elsif Id = SA_Config_Menu and then Line = 1 then SA_Opmodel_Name (Index)
              elsif Id = SA_Config_Menu and then Line = 2 then SA_Fsel_Name (Index)
              elsif Id = SA_Config_Menu and then Line = 3 then SA_Pit_F_Mode_Name (Index)
              elsif Id = SA_Stats_Menu and then Line = 1 then SA_Status_Name (Index)
              elsif Id = VTX_Tramp_Menu and then Line = 2 then Pit_Mode_Name (Index)
              elsif Id = VTX_Tramp_Menu and then Line = 3 then Band_Name (T.VTX_Table, Index)
              elsif Id = VTX_Tramp_Menu and then Line = 4 then Channel_Name (T.VTX_Table, Index)
              elsif Id = VTX_Tramp_Menu and then Line = 6 then Power_Name (T.VTX_Table, Index)
              else Label (""));
   end Lookup;

end Adaflight.Menu_Content;
