with Adaflight.Config_Fix;
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
      Flags           : Interfaces.Unsigned_16 := 0) return Line
   is
     ((Text => Label (Text), Flags => Code (E) or Flags, Has_Data => True, Value => Value, Min => Min, Max => Max,
       Step => Step, others => <>))
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
     (Text  : String;
      Value : Interfaces.Integer_32;
      Max   : Interfaces.Integer_32;
      Name  : Adaflight.Menu.Label_Text;
      Flags : Interfaces.Unsigned_16 := 0) return Line
   is
     ((Text => Label (Text), Flags => Code (Adaflight.Menu.Tab) or Flags, Has_Data => True, Value => Value, Max => Max,
       Value_Text => Name, others => <>))
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
         when Blackbox_Menu | LED_Strip_Menu | Power_Menu | Failsafe_Menu | RPM_Limit_Menu | Misc_Menu
            | Persistent_Stats_Menu =>
            (Enter => True, Leave => True, Update => False),
         when RC_Preview_Menu => (Enter => True, Leave => True, Update => True),
         when Firmware_Menu => (Enter => True, Leave => False, Update => False),
         when Calibration_Menu => (Enter => False, Leave => False, Update => True),
         when GPS_Lap_Timer_Menu | Set_Gate_Menu => (Enter => True, Leave => True, Update => False),
         when others      => (others => False));

   procedure Load (T : Target; Id : Menu_Id; M : out Table) is
      use Adaflight.Menu;
      N : Line_Count := 0;

      procedure Add (L : Line)
        with Pre  => N < Max_Lines and then (if Element_Of (L.Flags) = Fixed then L.Value in 0 .. 255)
                     and then (for all I in 0 .. N - 1 =>
                                 (if Element_Of (M.Lines (I).Flags) = Fixed then M.Lines (I).Value in 0 .. 255)),
             Post => N = N'Old + 1
                     and then (for all I in 0 .. N - 1 =>
                                 (if Element_Of (M.Lines (I).Flags) = Fixed then M.Lines (I).Value in 0 .. 255))
      is
      begin
         M.Lines (N) := L;
         N := N + 1;
      end Add;
   begin
      M := (Lines => (others => (Flags => Code (Label), others => <>)), Count => 1);
      case Id is
         when Quick_Menu =>
            Add (Make ("-- QUICK --", Label));
            Add (Sub ("RPM LIM", RPM_Limit_Menu));
            declare
               L : Line := Make ("THR LIM TYPE", Tab, Has_Data => True,
                                 Value => Interfaces.Integer_32 (T.Quick.Rate.Throttle_Limit_Type));
            begin
               L.Max := 2;
               L.Value_Text := Throttle_Limit_Name (Natural (T.Quick.Rate.Throttle_Limit_Type));
               Add (L);
            end;
            Add (Number ("THR LIM %", Interfaces.Integer_32 (T.Quick.Rate.Throttle_Limit_Percent), 25, 100));
            Add (Number ("MTR OUT LIM %", Interfaces.Integer_32 (T.Quick.Motor_Output_Limit), 1, 100));
            Add (Number ("FORCE CELLS", Interfaces.Integer_32 (T.Quick.Battery.Force_Battery_Cell_Count), 0, 24));
            Add (Make ("VTX", Funcall, Has_Func => True));
            Add (Sub ("MAIN", Main_Menu, Has_Func => False));
            Add (Make ("EXIT", OSD_Exit, Has_Func => True, Value => 0));
            Add (Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
         when Main_Menu =>
            Add (Make ("-- MAIN --", Label));
            Add (Sub ("PROFILE", Profile_Menu));
            Add (Sub ("FEATURES", Features));
            Add (Sub ("OSD", OSD_Menu));
            Add (Sub ("FC&FIRMWARE", Firmware_Menu));
            Add (Sub ("MISC", Misc_Menu));
            Add (Make ("SAVE/EXIT", Funcall, Has_Func => True));
         when Features =>
            Add (Make ("--- FEATURES ---", Label));
            Add (Sub ("BLACKBOX", Blackbox_Menu));
            Add (Make ("VTX", Funcall, Has_Func => True));
            Add (Sub ("LED STRIP", LED_Strip_Menu));
            Add (Sub ("POWER", Power_Menu));
            Add (Sub ("FAILSAFE", Failsafe_Menu));
            Add (Sub ("PERSISTENT STATS", Persistent_Stats_Menu));
            Add (Make ("BACK", Back));
         when Setup_Popup =>
            Add (Make ("-- SETUP MENU --", Label));
            if T.Popup.Acc_Line then
               Add (Text_Line ("CALIBRATE ACC", Funcall, T.Popup.Acc_Status, Has_Func => True, Flags => Dynamic));
            end if;
            if T.Popup.Battery_Line then
               declare
                  L : Line := Make ("", Funcall, Has_Func => True, Flags => Dynamic);
               begin
                  L.Text := T.Popup.Battery_Text;
                  Add (L);
               end;
            end if;
            Add (Make ("EXIT", Back, Flags => Dynamic));
         when Save_Exit =>
            Add (Make ("-- SAVE/EXIT --", Label));
            Add (Make ("EXIT", OSD_Exit, Has_Func => True, Value => 0));
            Add (Make ("SAVE&EXIT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 3));
            Add (Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (Make ("BACK", Back));
         when Save_Exit_Reboot =>
            Add (Make ("-- SAVE/EXIT (REBOOT REQD)", Label));
            Add (Make ("EXIT&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 5));
            Add (Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (Make ("BACK", Back));
         when Blackbox_Menu =>
            declare
               B : Blackbox_Copies renames T.Blackbox;
            begin
               Add (Make ("-- BLACKBOX --", Label));
               Add (Text_Line ("(PID FREQ)", Str, B.PID_Frequency));
               Add (Choice ("SAMPLERATE", Interfaces.Integer_32 (B.Rate), 4, Blackbox_Rate_Name (Natural (B.Rate)),
                            Reboot));
               Add (Choice ("DEVICE", Interfaces.Integer_32 (B.Device), 3, Blackbox_Device_Name (Natural (B.Device)),
                            Reboot));
               Add (Text_Line ("(STATUS)", Str, B.Status));
               Add (Text_Line ("(USED)", Str, B.Used));
               Add (Text_Line ("(FREE)", Str, B.Free));
               Add (Choice ("DEBUG MODE", Interfaces.Integer_32 (B.Debug_Mode), Interfaces.Integer_32 (Debug_Count) - 1,
                            Debug_Name (Natural (B.Debug_Mode)), Reboot));
               Add (Sub ("USB MASS STORAGE", Storage_Device_Menu));
               Add (Sub ("ERASE FLASH", Erase_Flash_Menu));
               Add (Make ("BACK", Back));
            end;
         when Erase_Flash_Menu =>
            Add (Make ("CONFIRM ERASE", Label));
            Add (Make ("NO", Back));
            Add (Make ("YES", Funcall, Has_Func => True));
         when Storage_Device_Menu =>
            Add (Make ("CONFIRM USB MASS STORAGE", Label));
            Add (Make ("NO", Back));
            Add (Make ("YES", Funcall, Has_Func => True));
         when LED_Strip_Menu =>
            declare
               L : LED_Copies renames T.LED;
            begin
               Add (Make ("-- LED STRIP --", Label));
               Add (Make ("ENABLED", Bool, Has_Data => True, Value => Interfaces.Integer_32 (L.Enabled)));
               Add (Choice ("PROFILE", Interfaces.Integer_32 (L.Profile), LED_Profile_Count - 1,
                            LED_Profile_Name (Natural (L.Profile))));
               Add (Choice ("RACE COLOR", Interfaces.Integer_32 (L.Race_Color), LED_Color_Count - 1,
                            LED_Color_Name (Natural (L.Race_Color))));
               Add (Choice ("BEACON COLOR", Interfaces.Integer_32 (L.Beacon_Color), LED_Color_Count - 1,
                            LED_Color_Name (Natural (L.Beacon_Color))));
               Add (Number ("BEACON PERIOD", Interfaces.Integer_32 (L.Beacon_Period), 50, 10_000, UInt16, 10));
               Add (Number ("BEACON ON %", Interfaces.Integer_32 (L.Beacon_On_Percent), 0, 100));
               Add (Make ("BEACON ARMED ONLY", Bool, Has_Data => True,
                          Value => Interfaces.Integer_32 (L.Beacon_Armed_Only)));
               Add (Make ("VISUAL BEEPER", Bool, Has_Data => True, Value => Interfaces.Integer_32 (L.Visual_Beeper)));
               Add (Choice ("VISUAL COLOR", Interfaces.Integer_32 (L.Visual_Beeper_Color), LED_Color_Count - 1,
                            LED_Color_Name (Natural (L.Visual_Beeper_Color))));
               Add (Make ("BACK", Back));
            end;
         when Power_Menu =>
            declare
               P : Power_Copies renames T.Power;
            begin
               Add (Make ("-- POWER --", Label));
               Add (Choice ("V METER", Interfaces.Integer_32 (P.Voltage_Meter_Source), 2,
                            Voltage_Meter_Name (Natural (P.Voltage_Meter_Source)), Reboot));
               Add (Choice ("I METER", Interfaces.Integer_32 (P.Current_Meter_Source), 4,
                            Current_Meter_Name (Natural (P.Current_Meter_Source)), Reboot));
               Add (Number ("VBAT CLMIN", Interfaces.Integer_32 (P.Min_Cell_Voltage), 100, 500, UInt16));
               Add (Number ("VBAT CLMAX", Interfaces.Integer_32 (P.Max_Cell_Voltage), 100, 500, UInt16));
               Add (Number ("VBAT CLWARN", Interfaces.Integer_32 (P.Warning_Cell_Voltage), 100, 500, UInt16));
               Add (Number ("VBAT SCALE", Interfaces.Integer_32 (P.Voltage_Scale), 0, 255));
               Add (Number ("IBAT SCALE", Interfaces.Integer_32 (P.Current_Scale), -16_000, 16_000, Int16, 5));
               Add (Number ("IBAT OFFSET", Interfaces.Integer_32 (P.Current_Offset), -32_000, 32_000, Int16, 5));
               Add (Number ("IBAT VIRT SCALE", Interfaces.Integer_32 (P.Virtual_Scale), -16_000, 16_000, Int16, 5));
               Add (Number ("IBAT VIRT OFFSET", Interfaces.Integer_32 (P.Virtual_Offset), 0, 16_000, UInt16, 5));
               Add (Make ("BACK", Back));
            end;
         when Failsafe_Menu =>
            Add (Make ("-- FAILSAFE --", Label));
            Add (Choice ("PROCEDURE", Interfaces.Integer_32 (T.Failsafe.Procedure_Kind), 2,
                         Procedure_Name (Natural (T.Failsafe.Procedure_Kind)), Reboot));
            Add (Fixed_Number ("GUARD TIME", Interfaces.Integer_32 (T.Failsafe.Guard_Time), 1, 200, 100, Reboot));
            Add (Number ("LANDING_TIME", Interfaces.Integer_32 (T.Failsafe.Landing_Time), 0, 250, Flags => Reboot));
            Add (Number ("STAGE 2 THROTTLE", Interfaces.Integer_32 (T.Failsafe.Throttle), 750, 2250, UInt16,
                         Flags => Reboot));
            Add (Make ("BACK", Back));
         when RPM_Limit_Menu =>
            Add (Make ("-- RPM LIMIT --", Label));
            Add (Make ("ACTIVE", Bool, Has_Data => True, Value => Boolean'Pos (T.RPM_Limit.Active), Flags => Reboot));
            Add (Number ("MAX RPM", Interfaces.Integer_32 (T.RPM_Limit.Limit), 0, 65_535, UInt16, 100));
            Add (Number ("KV", Interfaces.Integer_32 (T.RPM_Limit.KV), 0, 65_535, UInt16));
            Add (Make ("SAVE&REBOOT", OSD_Exit, Has_Func => True, Has_Data => True, Value => 4));
            Add (Make ("BACK", Back));
         when Misc_Menu =>
            Add (Make ("-- MISC --", Label));
            Add (Number ("IDLE OFFSET", Interfaces.Integer_32 (T.Misc.Idle_Offset), 0, 200, Flags => Reboot));
            Add (Number ("FPV CAM ANGLE", Interfaces.Integer_32 (T.Misc.FPV_Cam_Angle), 0, 90));
            Add (Number ("CRASHFLIP RATE", Interfaces.Integer_32 (T.Misc.Crashflip_Rate), 0, 100, Flags => Reboot));
            Add (Sub ("RC PREV", RC_Preview_Menu));
            Add (Sub ("GPS LAP TIMER", GPS_Lap_Timer_Menu));
            Add (Make ("BACK", Back));
         when RC_Preview_Menu =>
            Add (Make ("-- RC PREV --", Label));
            for C in RC_Values'Range loop
               pragma Loop_Invariant
                 (N = C + 1
                  and then (for all I in 0 .. N - 1 =>
                              (if Element_Of (M.Lines (I).Flags) = Fixed then M.Lines (I).Value in 0 .. 255)));
               Add (Number (RC_Names (C) (1 .. RC_Name_Lengths (C)),
                            Interfaces.Integer_32 (T.Preview (RC_Line_Channels (C))), 1, 2500, Int16, 0, Dynamic));
            end loop;
            Add (Make ("BACK", Back));
         when Persistent_Stats_Menu =>
            Add (Make ("-- PERSISTENT STATS --", Label));
            Add (Number ("FLIGHTS", Signed_Word (T.Stats.Total_Flights), 0, -1, UInt32));
            Add (Number ("TIME(sec)", Signed_Word (T.Stats.Total_Time_S), 0, -1, UInt32));
            Add (Number ("DIST(m)", Signed_Word (T.Stats.Total_Dist_M), 0, -1, UInt32));
            Add (Make ("RESET STATS", Funcall, Has_Func => True));
            Add (Make ("--- SETTINGS ---", Label));
            Add (Number ("MIN ARMED TIME(sec)", Interfaces.Integer_32 (T.Stats.Min_Armed_Time), -1, 127, Int8));
            Add (Make ("BACK", Back));
         when Firmware_Menu =>
            Add (Make ("--- INFO ---", Label));
            Add (Text_Line ("FWID", Str, T.Identity.Identifier));
            Add (Text_Line ("FWVER", Str, T.Identity.Version));
            Add (Text_Line ("GITREV", Str, T.Identity.Revision));
            Add (Text_Line ("TARGET", Str, T.Identity.Target_Name));
            Add (Text_Line ("MFR", Str, T.Board.Manufacturer_Id));
            Add (Text_Line ("BOARD", Str, T.Board.Board_Name));
            Add (Make ("--- SETUP ---", Label));
            Add (Sub ("CALIBRATE", Calibration_Menu));
            Add (Make ("BACK", Back));
         when Calibration_Menu =>
            Add (Make ("--- CALIBRATE ---", Label));
            Add (Text_Line ("GYRO", Funcall, T.Calibration.Gyro, Has_Func => True, Flags => Dynamic));
            Add (Text_Line ("ACC", Funcall, T.Calibration.Acc, Has_Func => True, Flags => Dynamic));
            Add (Text_Line ("BARO", Funcall, T.Calibration.Baro, Has_Func => True, Flags => Dynamic));
            Add (Make ("BACK", Back));
         when GPS_Lap_Timer_Menu =>
            Add (Make ("--- GPS LAP TIMER ---", Label));
            Add (Sub ("SET POSITION", Set_Gate_Menu));
            Add (Number ("GATE RADIUS(M)", Interfaces.Integer_32 (T.Lap.Gate_Tolerance), 1, 100));
            Add (Number ("MIN LAP SECONDS", Interfaces.Integer_32 (T.Lap.Minimum_Lap_Time), 0, 3000, UInt16));
            Add (Make ("BACK", Back));
         when Set_Gate_Menu =>
            Add (Make ("SETTING POSITION", Label));
            Add (Number ("READINGS", Interfaces.Integer_32 (T.Live.Gate_Set_Readings), 0, 2000, UInt16, 0, Dynamic));
            Add (Number ("DISTANCE(CM)", Signed_Word (T.Live.Gate_Distance_Cm), 0, 200, UInt32, 0, Dynamic));
            Add (Make ("BACK", Back));
         when Calibrate_Acc_Menu =>
            Add (Make ("--- CALIBRATE ACC ---", Label));
            Add (Make ("PLACE ON A LEVEL SURFACE", Label));
            Add (Make ("MAKE SURE CRAFT IS STILL", Label));
            Add (Make (" ", Label));
            Add (Make ("START CALIBRATION", Funcall, Has_Func => True));
            Add (Make ("BACK", Back));
         when others =>
            Add (Make ("", Label));
      end case;
      M.Count := N;
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
      if Id = Blackbox_Menu then
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
      pragma Unreferenced (T);
   begin
      return (if Id = Quick_Menu and then Line = 2 then Throttle_Limit_Name (Index)
              elsif Id = Power_Menu and then Line = 1 then Voltage_Meter_Name (Index)
              elsif Id = Power_Menu and then Line = 2 then Current_Meter_Name (Index)
              elsif Id = Failsafe_Menu and then Line = 1 then Procedure_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 2 then Blackbox_Rate_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 3 then Blackbox_Device_Name (Index)
              elsif Id = Blackbox_Menu and then Line = 7 then Debug_Name (Index)
              elsif Id = LED_Strip_Menu and then Line = 2 then LED_Profile_Name (Index)
              elsif Id = LED_Strip_Menu and then Line in 3 | 4 | 9 then LED_Color_Name (Index)
              else Label (""));
   end Lookup;

end Adaflight.Menu_Content;
