package body Adaflight.Menu_Content with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
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

   function Number (Text : String; Value, Min, Max : Interfaces.Integer_32) return Line is
     ((Text => Label (Text), Flags => Code (Adaflight.Menu.UInt8), Has_Data => True, Value => Value, Min => Min,
       Max => Max, Step => 1, others => <>))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text;

   --  A submenu line to a menu, with the change function or none.
   function Sub (Text : String; Target : Menu_Id; Has_Func : Boolean := True) return Line is
     (Make (Text, Adaflight.Menu.Submenu, Has_Func => Has_Func, Has_Data => True,
            Value => Interfaces.Integer_32 (Target)))
     with Pre => Text'Length <= Adaflight.Menu.Max_Text;

   Throttle_Limit_Names : constant array (0 .. 2) of Adaflight.Menu.Label_Text :=
     (Label ("OFF"), Label ("SCALE"), Label ("CLIP"));

   function Throttle_Limit_Name (Index : Natural) return Adaflight.Menu.Label_Text is
     (if Index <= 2 then Throttle_Limit_Names (Index) else Label (""));

   function Hooks_Of (Id : Menu_Id) return Adaflight.Menu.Hook_Set is
     (case Id is
         when Quick_Menu  => (Enter => True, Leave => True, Update => False),
         when Main_Menu   => (Enter => True, Leave => False, Update => False),
         when Setup_Popup => (Enter => False, Leave => False, Update => True),
         when others      => (others => False));

   procedure Load (T : Target; Id : Menu_Id; M : out Table) is
      use Adaflight.Menu;
      N : Line_Count := 0;

      procedure Add (L : Line)
        with Pre  => N < Max_Lines and then Element_Of (L.Flags) /= Fixed
                     and then (for all I in 0 .. N - 1 => Element_Of (M.Lines (I).Flags) /= Fixed),
             Post => N = N'Old + 1
                     and then (for all I in 0 .. N - 1 => Element_Of (M.Lines (I).Flags) /= Fixed)
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
               declare
                  L : Line := Make ("CALIBRATE ACC", Funcall, Has_Func => True, Has_Data => True, Flags => Dynamic);
               begin
                  L.Value_Text := T.Popup.Acc_Status;
                  Add (L);
               end;
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
         when others =>
            null;
      end case;
   end On_Enter;

   procedure On_Leave (T : in out Target; Id : Menu_Id; Self : Integer; Chain_Back : out Boolean) is
      pragma Unreferenced (Self);
   begin
      Chain_Back := False;
      if Id = Quick_Menu then
         T.Config.Control_Rate_Profiles (T.Quick.Rate_Profile) := T.Quick.Rate;
         T.Config.Battery_Profiles (T.Quick.Battery_Profile) := T.Quick.Battery;
         T.Config.Pid_Profiles (T.Quick.PID_Profile).Motor_Output_Limit := T.Quick.Motor_Output_Limit;
         if T.Asked.PID_Config_Inits < Natural'Last then
            T.Asked.PID_Config_Inits := T.Asked.PID_Config_Inits + 1;
         end if;
      end if;
   end On_Leave;

   --  The battery restore line's text: the stored charge in five places,
   --  cut to the reference's eighteen byte buffer.
   function Restore_Text (MAh : Interfaces.Unsigned_32) return Adaflight.Menu.Label_Text is
      use type Interfaces.Integer_64;
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
   begin
      Chain_Back := False;
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
      Byte : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Value mod 256);
   begin
      if Id = Quick_Menu then
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
      return (if Id = Quick_Menu and then Line = 2 then Throttle_Limit_Name (Index) else Label (""));
   end Lookup;

end Adaflight.Menu_Content;
