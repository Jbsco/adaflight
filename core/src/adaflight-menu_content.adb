with Adaflight.Config_Fix;
with Adaflight.OSD_Elements;
with Adaflight.Settings_Table;

package body Adaflight.Menu_Content with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   use type Adaflight.Menu.Element;

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
      Flags           : Interfaces.Unsigned_16 := 0) return Line
   is
     ((Text => Label (Text), Flags => Code (Adaflight.Menu.Fixed) or Flags, Has_Data => True, Value => Value,
       Min => Min, Max => Max, Step => 1, Multiplier => Multiplier, others => <>))
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

   --  A menu background's name from the command line's table.
   function Background_Name (Index : Natural) return Adaflight.Menu.Label_Text is
   begin
      if Index >= Adaflight.Settings_Table.Value_Count (Adaflight.Settings_Table.Table_Cms_Background) then
         return Label ("");
      end if;
      declare
         Name : constant String :=
           Adaflight.Settings_Table.Value_Name (Adaflight.Settings_Table.Table_Cms_Background, Index);
      begin
         return Label (Name (Name'First .. Name'First - 1 + Natural'Min (Name'Length, Adaflight.Menu.Max_Text)));
      end;
   end Background_Name;

   function Upper (C : Character) return Character is
     (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);

   --  A profile's text: its number from one, then its name in upper case in
   --  parentheses when it has one.
   function Profile_Text (Index : Interfaces.Unsigned_8; Name : Adaflight.Config_Groups.Bytes_9)
     return Adaflight.Menu.Label_Text
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
   begin
      if Index >= Adaflight.Settings_Table.Value_Count (Adaflight.Settings_Table.Table_Debug) then
         return Label ("");
      end if;
      declare
         Name : constant String := Adaflight.Settings_Table.Value_Name (Adaflight.Settings_Table.Table_Debug, Index);
      begin
         return Label (Name (Name'First .. Name'First - 1 + Natural'Min (Name'Length, Adaflight.Menu.Max_Text)));
      end;
   end Debug_Name;

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
   function PID_Frequency_Text (F : PID_Hertz) return Adaflight.Menu.Label_Text is
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
   procedure Device_Status (T : in out Target; Flash_Offset : Interfaces.Unsigned_32) is
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
         when Profile_Menu | PID_Menu | Rate_Menu | OSD_Menu | Active_Elements_Menu | Timers_Menu | Alarms_Menu
            | Blackbox_Menu | LED_Strip_Menu | Power_Menu | Failsafe_Menu | RPM_Limit_Menu | Misc_Menu
            | Persistent_Stats_Menu =>
            (Enter => True, Leave => True, Update => False),
         when RC_Preview_Menu => (Enter => True, Leave => True, Update => True),
         when Firmware_Menu | VTX_Error_Menu => (Enter => True, Leave => False, Update => False),
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

   --  The quick, main and features menus, the setup popup, the save menus and
   --  the VTX error menu.
   procedure Load_Main (T : Target; Id : Menu_Id; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      case Id is
         when Quick_Menu =>
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
         when Main_Menu =>
            Add (M, N, Make ("-- MAIN --", Label));
            Add (M, N, Sub ("PROFILE", Profile_Menu));
            Add (M, N, Sub ("FEATURES", Features));
            Add (M, N, Sub ("OSD", OSD_Menu));
            Add (M, N, Sub ("FC&FIRMWARE", Firmware_Menu));
            Add (M, N, Sub ("MISC", Misc_Menu));
            Add (M, N, Make ("SAVE/EXIT", Funcall, Has_Func => True));
         when Features =>
            Add (M, N, Make ("--- FEATURES ---", Label));
            Add (M, N, Sub ("BLACKBOX", Blackbox_Menu));
            Add (M, N, Make ("VTX", Funcall, Has_Func => True));
            Add (M, N, Sub ("LED STRIP", LED_Strip_Menu));
            Add (M, N, Sub ("POWER", Power_Menu));
            Add (M, N, Sub ("FAILSAFE", Failsafe_Menu));
            Add (M, N, Sub ("PERSISTENT STATS", Persistent_Stats_Menu));
            Add (M, N, Make ("BACK", Back));
         when Setup_Popup =>
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
         when Save_Exit =>
            Add (M, N, Make ("-- SAVE/EXIT --", Label));
            Add (M, N, Make ("EXIT", OSD_Exit, Has_Func => True, Value => 0));
            Add (M, N, Make ("SAVE&EXIT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 3));
            Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (M, N, Make ("BACK", Back));
         when Save_Exit_Reboot =>
            Add (M, N, Make ("-- SAVE/EXIT (REBOOT REQD)", Label));
            Add (M, N, Make ("EXIT&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 5));
            Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (M, N, Make ("BACK", Back));
         when VTX_Error_Menu =>
            Add (M, N, Text_Line ("", Label, T.VTX_Status.Line_1, Flags => Dynamic));
            Add (M, N, Text_Line ("", Label, T.VTX_Status.Line_2, Flags => Dynamic));
            Add (M, N, Make ("", Label));
            Add (M, N, Make ("BACK", Back));
         when others =>
            Add (M, N, Make ("", Label));
      end case;
      M.Count := N;
   end Load_Main;

   --  The power, failsafe, RPM limit, misc, RC preview, persistent statistics and GPS lap timer menus.
   procedure Load_Settings (T : Target; Id : Menu_Id; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      case Id is
         when Power_Menu =>
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
         when Failsafe_Menu =>
            Add (M, N, Make ("-- FAILSAFE --", Label));
            Add (M, N, Choice ("PROCEDURE", Interfaces.Integer_32 (T.Failsafe.Procedure_Kind), 2,
                         Procedure_Name (Natural (T.Failsafe.Procedure_Kind)), Reboot));
            Add (M, N, Fixed_Number ("GUARD TIME", Interfaces.Integer_32 (T.Failsafe.Guard_Time), 1, 200, 100, Reboot));
            Add (M, N,
                 Number ("LANDING_TIME", Interfaces.Integer_32 (T.Failsafe.Landing_Time), 0, 250, Flags => Reboot));
            Add (M, N, Number ("STAGE 2 THROTTLE", Interfaces.Integer_32 (T.Failsafe.Throttle), 750, 2250, UInt16,
                         Flags => Reboot));
            Add (M, N, Make ("BACK", Back));
         when RPM_Limit_Menu =>
            Add (M, N, Make ("-- RPM LIMIT --", Label));
            Add (M, N,
                 Make ("ACTIVE", Bool, Has_Data => True, Value => Boolean'Pos (T.RPM_Limit.Active), Flags => Reboot));
            Add (M, N, Number ("MAX RPM", Interfaces.Integer_32 (T.RPM_Limit.Limit), 0, 65_535, UInt16, 100));
            Add (M, N, Number ("KV", Interfaces.Integer_32 (T.RPM_Limit.KV), 0, 65_535, UInt16));
            Add (M, N, Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (M, N, Make ("BACK", Back));
         when Misc_Menu =>
            Add (M, N, Make ("-- MISC --", Label));
            Add (M, N, Number ("IDLE OFFSET", Interfaces.Integer_32 (T.Misc.Idle_Offset), 0, 200, Flags => Reboot));
            Add (M, N, Number ("FPV CAM ANGLE", Interfaces.Integer_32 (T.Misc.FPV_Cam_Angle), 0, 90));
            Add (M, N,
                 Number ("CRASHFLIP RATE", Interfaces.Integer_32 (T.Misc.Crashflip_Rate), 0, 100, Flags => Reboot));
            Add (M, N, Sub ("RC PREV", RC_Preview_Menu));
            Add (M, N, Sub ("GPS LAP TIMER", GPS_Lap_Timer_Menu));
            Add (M, N, Make ("BACK", Back));
         when RC_Preview_Menu =>
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
         when Persistent_Stats_Menu =>
            Add (M, N, Make ("-- PERSISTENT STATS --", Label));
            Add (M, N, Number ("FLIGHTS", Signed_Word (T.Stats.Total_Flights), 0, -1, UInt32));
            Add (M, N, Number ("TIME(sec)", Signed_Word (T.Stats.Total_Time_S), 0, -1, UInt32));
            Add (M, N, Number ("DIST(m)", Signed_Word (T.Stats.Total_Dist_M), 0, -1, UInt32));
            Add (M, N, Make ("RESET STATS", Funcall, Has_Func => True));
            Add (M, N, Make ("--- SETTINGS ---", Label));
            Add (M, N, Number ("MIN ARMED TIME(sec)", Interfaces.Integer_32 (T.Stats.Min_Armed_Time), -1, 127, Int8));
            Add (M, N, Make ("BACK", Back));
         when GPS_Lap_Timer_Menu =>
            Add (M, N, Make ("--- GPS LAP TIMER ---", Label));
            Add (M, N, Sub ("SET POSITION", Set_Gate_Menu));
            Add (M, N, Number ("GATE RADIUS(M)", Interfaces.Integer_32 (T.Lap.Gate_Tolerance), 1, 100));
            Add (M, N, Number ("MIN LAP SECONDS", Interfaces.Integer_32 (T.Lap.Minimum_Lap_Time), 0, 3000, UInt16));
            Add (M, N, Make ("BACK", Back));
         when Set_Gate_Menu =>
            Add (M, N, Make ("SETTING POSITION", Label));
            Add (M, N,
                 Number ("READINGS", Interfaces.Integer_32 (T.Live.Gate_Set_Readings), 0, 2000, UInt16, 0, Dynamic));
            Add (M, N, Number ("DISTANCE(CM)", Signed_Word (T.Live.Gate_Distance_Cm), 0, 200, UInt32, 0, Dynamic));
            Add (M, N, Make ("BACK", Back));
         when others =>
            Add (M, N, Make ("", Label));
      end case;
      M.Count := N;
   end Load_Settings;

   --  The blackbox, LED strip, firmware and calibration menus.
   procedure Load_System (T : Target; Id : Menu_Id; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      case Id is
         when Blackbox_Menu =>
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
         when Erase_Flash_Menu =>
            Add (M, N, Make ("CONFIRM ERASE", Label));
            Add (M, N, Make ("NO", Back));
            Add (M, N, Make ("YES", Funcall, Has_Func => True));
         when Storage_Device_Menu =>
            Add (M, N, Make ("CONFIRM USB MASS STORAGE", Label));
            Add (M, N, Make ("NO", Back));
            Add (M, N, Make ("YES", Funcall, Has_Func => True));
         when LED_Strip_Menu =>
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
         when Firmware_Menu =>
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
         when Calibration_Menu =>
            Add (M, N, Make ("--- CALIBRATE ---", Label));
            Add (M, N, Text_Line ("GYRO", Funcall, T.Calibration.Gyro, Has_Func => True, Flags => Dynamic));
            Add (M, N, Text_Line ("ACC", Funcall, T.Calibration.Acc, Has_Func => True, Flags => Dynamic));
            Add (M, N, Text_Line ("BARO", Funcall, T.Calibration.Baro, Has_Func => True, Flags => Dynamic));
            Add (M, N, Make ("BACK", Back));
         when Calibrate_Acc_Menu =>
            Add (M, N, Make ("--- CALIBRATE ACC ---", Label));
            Add (M, N, Make ("PLACE ON A LEVEL SURFACE", Label));
            Add (M, N, Make ("MAKE SURE CRAFT IS STILL", Label));
            Add (M, N, Make (" ", Label));
            Add (M, N, Make ("START CALIBRATION", Funcall, Has_Func => True));
            Add (M, N, Make ("BACK", Back));
         when others =>
            Add (M, N, Make ("", Label));
      end case;
      M.Count := N;
   end Load_System;

   --  The OSD menu with its active elements, timers and alarms menus.
   procedure Load_OSD (T : Target; Id : Menu_Id; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      case Id is
         when OSD_Menu =>
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
         when Active_Elements_Menu =>
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
         when Timers_Menu =>
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
         when Alarms_Menu =>
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
         when others =>
            Add (M, N, Make ("", Label));
      end case;
      M.Count := N;
   end Load_OSD;

   --  The profile menu with its PID and rate menus.
   procedure Load_Profile (T : Target; Id : Menu_Id; M : out Table)
     with Post => M.Count >= 1 and then Adaflight.Menu.Fixed_In_Range (M)
   is
      use Adaflight.Menu;
      N : Line_Count := 0;
   begin
      M := Empty_Table;
      case Id is
         when Profile_Menu =>
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
         when PID_Menu =>
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
         when Rate_Menu =>
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
         when others =>
            Add (M, N, Make ("", Label));
      end case;
      M.Count := N;
   end Load_Profile;

   procedure Load (T : Target; Id : Menu_Id; M : out Table) is
   begin
      case Id is
         when Profile_Menu | PID_Menu | Rate_Menu =>
            Load_Profile (T, Id, M);
         when OSD_Menu | Active_Elements_Menu | Timers_Menu | Alarms_Menu =>
            Load_OSD (T, Id, M);
         when Power_Menu | Failsafe_Menu | RPM_Limit_Menu | Misc_Menu | RC_Preview_Menu | Persistent_Stats_Menu
            | GPS_Lap_Timer_Menu | Set_Gate_Menu =>
            Load_Settings (T, Id, M);
         when Blackbox_Menu | Erase_Flash_Menu | Storage_Device_Menu | LED_Strip_Menu | Firmware_Menu | Calibration_Menu
            | Calibrate_Acc_Menu =>
            Load_System (T, Id, M);
         when others =>
            Load_Main (T, Id, M);
      end case;
   end Load;

   --  The setup popup's build: a line for the accelerometer calibration
   --  when arming waits for it, one for the battery restore when charge
   --  was drawn, and the exit; true when a line came in besides the exit.
   procedure Build_Popup (T : in out Target; Added : out Boolean) is
   begin
      T.Popup.Acc_Line := T.Live.Acc_Present and then T.Live.Acc_Calibration_Needed;
      T.Popup.Battery_Line := T.Live.Used_MAh;
      Added := T.Popup.Acc_Line or else T.Popup.Battery_Line;
   end Build_Popup;

   --  The PID profile changed to an index, stored when the profile exists.
   procedure Change_PID_Profile (T : in out Target; Index : Interfaces.Unsigned_8) is
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
   procedure Change_Rate_Profile (T : in out Target; Index : Interfaces.Unsigned_8) is
   begin
      if T.Asked.Rate_Changes < Natural'Last then
         T.Asked.Rate_Changes := T.Asked.Rate_Changes + 1;
      end if;
      T.Asked.Rate_Asked := Index;
      if Index < Rate_Profile_Count then
         T.Config.System_Config.Active_Rate_Profile := Index;
      end if;
   end Change_Rate_Profile;

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

   procedure On_Leave (T : in out Target; Id : Menu_Id; Self : Integer; Chain_Back : out Boolean) is
   begin
      Chain_Back := False;
      if Id = Quick_Menu then
         T.Config.Control_Rate_Profiles (T.Quick.Rate_Profile) := T.Quick.Rate;
         T.Config.Battery_Profiles (T.Quick.Battery_Profile) := T.Quick.Battery;
         T.Config.Pid_Profiles (T.Quick.PID_Profile).Motor_Output_Limit := T.Quick.Motor_Output_Limit;
         if T.Asked.PID_Config_Inits < Natural'Last then
            T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
         end if;
      elsif Id = Profile_Menu then
         Change_PID_Profile (T, T.Profile.PID_Index);
         Change_Rate_Profile (T, T.Profile.Rate_Index);
      elsif Id = PID_Menu then
         declare
            Current : constant Natural :=
              Natural (Interfaces.Unsigned_8'Min (T.Config.System_Config.Pid_Profile_Index, PID_Profile_Count - 1));
         begin
            for A in Feedforward_Table'Range loop
               T.Config.Pid_Profiles (Current).Pid (A).P := T.PID.Gains (A, 0);
               T.Config.Pid_Profiles (Current).Pid (A).I := T.PID.Gains (A, 1);
               T.Config.Pid_Profiles (Current).Pid (A).D := T.PID.Gains (A, 2);
               T.Config.Pid_Profiles (Current).Pid (A).F := T.PID.Feedforward (A);
            end loop;
         end;
         if T.Asked.PID_Config_Inits < Natural'Last then
            T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
         end if;
      elsif Id = Rate_Menu then
         T.Config.Control_Rate_Profiles
           (Natural (Interfaces.Unsigned_8'Min (T.Profile.Rate_Index, Rate_Profile_Count - 1))) := T.Rate.Profile;
      elsif Id = OSD_Menu then
         if T.Asked.Profile_Changes < Natural'Last then
            T.Asked.Profile_Changes := T.Asked.Profile_Changes + 1;
         end if;
         T.Asked.Profile_Asked := T.OSD.Profile;
         if T.OSD.Profile <= 3 then
            T.Config.Osd_Config.Osd_Profile_Index := T.OSD.Profile;
         end if;
      elsif Id = Active_Elements_Menu then
         T.Config.Osd_Element_Config.Item_Pos := T.Elements;
         if T.Asked.Element_Analyses < Natural'Last then
            T.Asked.Element_Analyses := T.Asked.Element_Analyses + 1;
         end if;
      elsif Id = Timers_Menu then
         for I in Timer_Fields'Range loop
            T.Config.Osd_Config.Timers (I) :=
              (Interfaces.Unsigned_16 (T.Timers.Source (I)) and 16#0F#)
              or (Interfaces.Unsigned_16 (T.Timers.Precision (I)) and 16#0F#) * 16
              or Interfaces.Unsigned_16 (T.Timers.Alarm (I)) * 256;
         end loop;
      elsif Id = Alarms_Menu then
         T.Config.Osd_Config.Rssi_Alarm := T.Alarms.RSSI;
         T.Config.Osd_Config.Link_Quality_Alarm := T.Alarms.Link_Quality;
         T.Config.Osd_Config.Rssi_Dbm_Alarm := T.Alarms.RSSI_Dbm;
         T.Config.Osd_Config.Rsnr_Alarm := T.Alarms.RSNR;
         T.Config.Osd_Config.Cap_Alarm := T.Alarms.Capacity;
         T.Config.Osd_Config.Alt_Alarm := T.Alarms.Altitude;
         T.Config.Osd_Config.Distance_Alarm := T.Alarms.Distance;
         T.Config.Battery_Config.Vbat_Duration_For_Warning := T.Alarms.Warning_Duration;
         T.Config.Battery_Config.Vbat_Duration_For_Critical := T.Alarms.Critical_Duration;
      elsif Id = Blackbox_Menu then
         if T.Live.Blackbox_May_Edit then
            T.Config.Blackbox_Config.Device := (if T.Blackbox.Device in 1 .. 3 then T.Blackbox.Device else 0);
         end if;
         T.Config.Blackbox_Config.Sample_Rate := T.Blackbox.Rate;
         T.Config.System_Config.Debug_Mode := T.Blackbox.Debug_Mode;
      elsif Id = LED_Strip_Menu then
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
      elsif Id = Power_Menu then
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
      elsif Id = Failsafe_Menu then
         T.Config.Failsafe_Config.Failsafe_Procedure := T.Failsafe.Procedure_Kind;
         T.Config.Failsafe_Config.Failsafe_Delay := T.Failsafe.Guard_Time;
         T.Config.Failsafe_Config.Failsafe_Landing_Time := T.Failsafe.Landing_Time;
         T.Config.Failsafe_Config.Failsafe_Throttle := T.Failsafe.Throttle;
      elsif Id = RPM_Limit_Menu then
         T.Config.Mixer_Config.Rpm_Limit_Value := T.RPM_Limit.Limit;
         T.Config.Motor_Config.Kv := T.RPM_Limit.KV;
         T.Config.Mixer_Config.Rpm_Limit := T.RPM_Limit.Active;
      elsif Id = Misc_Menu then
         T.Config.Motor_Config.Motor_Idle := 10 * Interfaces.Unsigned_16 (T.Misc.Idle_Offset);
         T.Config.Rx_Config.Fpv_Cam_Angle_Degrees := T.Misc.FPV_Cam_Angle;
         T.Config.Mixer_Config.Crashflip_Rate := T.Misc.Crashflip_Rate;
      elsif Id = RC_Preview_Menu then
         Chain_Back := Self /= 9;
      elsif Id = GPS_Lap_Timer_Menu then
         T.Config.Gps_Lap_Timer_Config.Minimum_Lap_Time_Seconds := T.Lap.Minimum_Lap_Time;
         T.Config.Gps_Lap_Timer_Config.Gate_Tolerance_M := T.Lap.Gate_Tolerance;
      elsif Id = Set_Gate_Menu then
         if T.Asked.Gate_Ends < Natural'Last then
            T.Asked.Gate_Ends := T.Asked.Gate_Ends + 1;
         end if;
      elsif Id = Persistent_Stats_Menu then
         T.Config.Stats_Config.Stats_Total_Flights := T.Stats.Total_Flights;
         T.Config.Stats_Config.Stats_Total_Time_S := T.Stats.Total_Time_S;
         T.Config.Stats_Config.Stats_Total_Dist_M := T.Stats.Total_Dist_M;
         T.Config.Stats_Config.Stats_Min_Armed_Time_S := T.Stats.Min_Armed_Time;
      end if;
   end On_Leave;

   --  The battery restore line's text: the stored charge in five places,
   --  cut to the reference's eighteen byte buffer.
   function Restore_Text (MAh : Interfaces.Unsigned_32) return Adaflight.Menu.Label_Text is
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
      function Whole_Channel (X : RC_Reading) return Interfaces.Integer_16 is
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
            when 6 => T.Stats.Min_Armed_Time :=
                 Interfaces.Integer_8 ((Interfaces.Integer_64 (Value) + 128) mod 256 - 128);
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

   function Lookup (T : Target; Id : Menu_Id; Line : Natural; Index : Natural) return Adaflight.Menu.Label_Text is
   begin
      return (if Id = Quick_Menu and then Line = 2 then Throttle_Limit_Name (Index)
              elsif Id = Power_Menu and then Line = 1 then Voltage_Meter_Name (Index)
              elsif Id = Power_Menu and then Line = 2 then Current_Meter_Name (Index)
              elsif Id = Failsafe_Menu and then Line = 1 then Procedure_Name (Index)
              elsif Id = Profile_Menu and then Line = 1 then Profile_Name (T.Profile.PID_Names, Index)
              elsif Id = Profile_Menu and then Line = 6 then Profile_Name (T.Profile.Rate_Names, Index)
              elsif Id = Rate_Menu and then Line = 13 then Throttle_Limit_Name (Index)
              elsif Id = OSD_Menu and then Line = 8 then Background_Name (Index)
              elsif Id = Timers_Menu and then Line in 1 | 4 then Timer_Source_Name (Index)
              elsif Id = Timers_Menu and then Line in 2 | 5 then Timer_Precision_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 2 then Blackbox_Rate_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 3 then Blackbox_Device_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 7 then Debug_Name (Index)
              elsif Id = LED_Strip_Menu and then Line = 2 then LED_Profile_Name (Index)
              elsif Id = LED_Strip_Menu and then Line in 3 | 4 | 9 then LED_Color_Name (Index)
              else Label (""));
   end Lookup;

end Adaflight.Menu_Content;
