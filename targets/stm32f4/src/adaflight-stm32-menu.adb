with Adaflight.SRXL_Telemetry;
with Adaflight.Menu;
with Adaflight.Menu_Content;
with Adaflight.Menu_Nav;
with Adaflight.PID_Profile;
with Adaflight.STM32.Control;
with Adaflight.STM32.Motors;
with Adaflight.STM32.OSD;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Menu is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Held        : Boolean := False;
   Reboot_Flag : Boolean := False;
   Save_Asked  : Boolean := False;
   Reset_Asked : Boolean := False;
   Armed_Now   : Boolean := False;
   --  The CRSF and SRXL transmitters' displays among the registered ones,
   --  when they are.
   CRSF_Display : Integer range -1 .. Adaflight.Menu.Max_Displays - 1 := -1;
   SRXL_Display : Integer range -1 .. Adaflight.Menu.Max_Displays - 1 := -1;

   --  A write costs the bytes it queues on the MSP display port and nothing on
   --  the MAX7456 or the CRSF display, which has no layers, background or
   --  heartbeat.
   procedure Act (On : Adaflight.Menu.Display_Index; A : Adaflight.Menu.Action; Arg : Integer) is
      CRSF   : constant Boolean := On = CRSF_Display;
      SRXL   : constant Boolean := On = SRXL_Display;
      Remote : constant Boolean := CRSF or else SRXL;
   begin
      case A is
         when Adaflight.Menu.Grab =>
            if CRSF then
               Adaflight.STM32.Radio.Display_Grab;
            elsif SRXL then
               Adaflight.STM32.Radio.SRXL_Display_Grab;
            else
               Adaflight.STM32.OSD.Menu_Grab;
            end if;
         when Adaflight.Menu.Release =>
            if CRSF then
               Adaflight.STM32.Radio.Display_Release (Adaflight.STM32.Time.Millis);
            elsif SRXL then
               Adaflight.STM32.Radio.SRXL_Display_Release;
            else
               Adaflight.STM32.OSD.Menu_Release;
            end if;
         when Adaflight.Menu.Clear =>
            if CRSF then
               Adaflight.STM32.Radio.Display_Clear (Adaflight.STM32.Time.Millis);
            elsif SRXL then
               Adaflight.STM32.Radio.SRXL_Display_Clear;
            else
               Adaflight.STM32.OSD.Menu_Clear;
            end if;
         when Adaflight.Menu.Layer_Select =>
            if not Remote then
               Adaflight.STM32.OSD.Menu_Layer_Select (Natural'Max (0, Arg));
            end if;
         when Adaflight.Menu.Background =>
            if not Remote then
               Adaflight.STM32.OSD.Menu_Background (Natural'Max (0, Arg));
            end if;
         when Adaflight.Menu.Redraw =>
            if not Remote then
               Adaflight.STM32.OSD.Menu_Redraw (Armed_Now);
            end if;
         when Adaflight.Menu.Save_Config =>
            Save_Asked := True;
         when Adaflight.Menu.Arming_Disabled =>
            Held := Arg /= 0;
         when Adaflight.Menu.Stop_Motors =>
            Adaflight.STM32.Control.Stop_Motors;
         when Adaflight.Menu.Motor_Shutdown =>
            Adaflight.STM32.Motors.Shutdown;
         when Adaflight.Menu.Delay_Ms =>
            Adaflight.STM32.Time.Delay_Ms (Natural'Max (0, Natural'Min (10_000, Arg)));
         when Adaflight.Menu.System_Reset =>
            Reset_Asked := True;
         when Adaflight.Menu.Set_Reboot_Required =>
            Reboot_Flag := True;
         when Adaflight.Menu.Heartbeat =>
            if not Remote then
               Adaflight.STM32.OSD.Menu_Heartbeat;
            end if;
         when Adaflight.Menu.Begin_Transaction | Adaflight.Menu.Commit_Transaction =>
            null;
      end case;
   end Act;

   procedure Write
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; Text : String; Cost : out Interfaces.Unsigned_32)
   is
      pragma Unreferenced (Attr);
   begin
      if On = CRSF_Display then
         Adaflight.STM32.Radio.Display_Write (Unsigned_8 (X), Unsigned_8 (Y), Text);
         Cost := 0;
      elsif On = SRXL_Display then
         Adaflight.STM32.Radio.SRXL_Display_Write (Unsigned_8 (X), Unsigned_8 (Y), Text);
         Cost := 0;
      else
         Adaflight.STM32.OSD.Menu_Write (Unsigned_8 (X), Unsigned_8 (Y), Text, Cost);
      end if;
   end Write;

   procedure Write_Char
     (On : Adaflight.Menu.Display_Index; X : Adaflight.Menu.Column; Y : Adaflight.Menu.Column;
      Attr : Interfaces.Unsigned_8; C : Character)
   is
      pragma Unreferenced (Attr);
      Unused_Cost : Unsigned_32;
   begin
      if On = CRSF_Display then
         Adaflight.STM32.Radio.Display_Write_Char (Unsigned_8 (X), Unsigned_8 (Y), Character'Pos (C));
      elsif On = SRXL_Display then
         Adaflight.STM32.Radio.SRXL_Display_Write_Char (Unsigned_8 (X), Unsigned_8 (Y), Character'Pos (C));
      else
         Adaflight.STM32.OSD.Menu_Write (Unsigned_8 (X), Unsigned_8 (Y), (1 => C), Unused_Cost);
      end if;
   end Write_Char;

   package Nav is new Adaflight.Menu_Nav
     (Target_State      => Adaflight.Menu_Content.Target,
      Hooks_Of          => Adaflight.Menu_Content.Hooks_Of,
      Load              => Adaflight.Menu_Content.Load,
      On_Enter          => Adaflight.Menu_Content.On_Enter,
      On_Leave          => Adaflight.Menu_Content.On_Leave,
      On_Display_Update => Adaflight.Menu_Content.On_Display_Update,
      Line_Call         => Adaflight.Menu_Content.Line_Call,
      Set_Value         => Adaflight.Menu_Content.Set_Value,
      Refresh           => Adaflight.Menu_Content.Refresh,
      Lookup            => Adaflight.Menu_Content.Lookup,
      Act               => Act,
      Write             => Write,
      Write_Char        => Write_Char);

   --  The navigation's state and the menus' target live in the core coupled
   --  memory, which the main RAM has no room for.
   State : Nav.State with Linker_Section => ".bss.ccm";
   T     : Adaflight.Menu_Content.Target with Linker_Section => ".bss.ccm";
   Asked : Adaflight.Menu_Content.Requests;

   function Label (S : String) return Adaflight.Menu.Label_Text is
      L : Adaflight.Menu.Label_Text;
   begin
      L.Length := Natural'Min (S'Length, Adaflight.Menu.Max_Text);
      L.Data (1 .. L.Length) := S (S'First .. S'First + L.Length - 1);
      return L;
   end Label;

   procedure Init
     (Version, Target_Name, Board_Name, Manufacturer : String; Display_Present : Boolean;
      Columns, Rows : Interfaces.Unsigned_8) is
   begin
      T.Identity := (Identifier  => Label ("ADFL"),
                     Version     => Label (Version),
                     Revision    => Label ("0000000"),
                     Target_Name => Label (Target_Name));
      T.Live.Board_Name := Label (Board_Name);
      T.Live.Manufacturer_Id := Label (Manufacturer);
      if Display_Present then
         Nav.Register_Display
           (State,
            (Columns          => Adaflight.Menu.Screen_Columns (Natural'Max (1, Natural (Columns))),
             Rows             => Adaflight.Menu.Screen_Rows (Natural'Max (8, Natural (Rows))),
             Full_Screen      => False,
             Supports_Symbols => True,
             others           => <>));
      end if;
   end Init;

   function Open return Boolean is (State.In_Menu);

   function Arming_Held return Boolean is (Held);

   function Reboot_Required return Boolean is (Reboot_Flag);

   function Sliders (C : Adaflight.Config_Groups.Configuration) return Adaflight.Menu.Slider_Settings is
      P : Adaflight.Config_Groups.Pid_Profile_Record renames
        C.Pid_Profiles (Natural'Min (3, Natural (C.System_Config.Pid_Profile_Index)));
      Mode : constant Natural := Natural'Min (2, Natural (P.Simplified_Pids_Mode));
   begin
      return (Mode         => Adaflight.PID_Profile.Simplified_Mode'Val (Mode),
              Gyro_Filter  => C.Gyro_Config.Simplified_Gyro_Filter /= 0,
              DTerm_Filter => P.Simplified_Dterm_Filter /= 0);
   end Sliders;

   procedure Run
     (C : in out Adaflight.Config_Groups.Configuration; F : Facts; Now_Us, Now_Ms : Interfaces.Unsigned_32;
      R : out Requests)
   is
      Was_Open : constant Boolean := State.In_Menu;
      Keys     : Nav.Key_Settings;
      Sticks   : Nav.Stick_Inputs;
      Before   : constant Adaflight.Menu_Content.Requests := Asked;
   begin
      R := (others => <>);
      Armed_Now := F.Armed;
      if not Was_Open then
         T.Config := C;
      end if;
      T.Live.Acc_Present := F.Acc_Present;
      T.Live.Acc_Calibration_Needed := F.Acc_Present and then not F.Acc_Calibrated;
      T.Live.Acc_Calibration_Complete := F.Acc_Calibration_Complete;
      T.Live.Acc_Calibrated := F.Acc_Calibrated;
      T.Live.Gyro_Present := F.Gyro_Present;
      T.Live.Gyro_Calibration_Complete := F.Gyro_Calibration_Complete;
      T.Live.Reboot_Required := Reboot_Flag;
      T.Live.Runtime_Features := F.Runtime_Features;
      T.Live.PID_Frequency := F.PID_Frequency;
      T.Live.Gate_Set_Readings := F.Gate_Set_Readings;
      T.Live.Gate_Distance_Cm := F.Gate_Distance_Cm;
      for I in 0 .. 3 loop
         T.Live.RC_Data (I) := F.Channels (I);
         T.Live.RC_Data (I + 4) := F.Aux (I);
      end loop;
      Keys := (Start            => Adaflight.Menu_Content.Start_Menu (T),
               Background       => Natural (C.Osd_Config.Cms_Background_Type),
               Save_Exit        => Adaflight.Menu_Content.Save_Exit,
               Save_Exit_Reboot => Adaflight.Menu_Content.Save_Exit_Reboot);
      Sticks := (Throttle                => F.Channels (Adaflight.RC_Command.Throttle_Channel),
                 Yaw                     => F.Channels (2),
                 Pitch                   => F.Channels (1),
                 Roll                    => F.Channels (0),
                 Armed                   => F.Armed,
                 Paralyzed               => F.Paralyzed,
                 Stick_Commands_Disabled => F.Stick_Commands_Disabled,
                 Device_In_Menu          => False,
                 Joystick_Active         => False);
      Nav.Update
        (State, T, Keys, Sliders (C), Sticks, Reboot_Flag, Now_Us, Now_Ms,
         (if (CRSF_Display >= 0 and then State.Port = CRSF_Display)
            or else (SRXL_Display >= 0 and then State.Port = SRXL_Display)
          then Unsigned_32'Last
          else Adaflight.STM32.OSD.Menu_Room));
      if Was_Open or else State.In_Menu then
         C := T.Config;
      end if;
      Asked := T.Asked;
      R.Acc_Calibration := Asked.Acc_Calibrations /= Before.Acc_Calibrations;
      R.Gyro_Calibration := Asked.Gyro_Calibrations /= Before.Gyro_Calibrations;
      R.Gate_Start := Asked.Gate_Starts /= Before.Gate_Starts;
      R.Gate_End := Asked.Gate_Ends /= Before.Gate_Ends;
      R.Elements := Asked.Element_Analyses /= Before.Element_Analyses;
      R.OSD_Profile := Asked.Profile_Changes /= Before.Profile_Changes;
      R.OSD_Profile_Idx := Asked.Profile_Asked;
      R.PID_Profile := Asked.PID_Changes /= Before.PID_Changes;
      R.PID_Profile_Idx := Asked.PID_Asked;
      R.Rate_Profile := Asked.Rate_Changes /= Before.Rate_Changes;
      R.Rate_Profile_Idx := Asked.Rate_Asked;
      R.PID_Init := Asked.PID_Config_Inits /= Before.PID_Config_Inits;
      R.Save := Save_Asked;
      R.Reset := Reset_Asked;
      Save_Asked := False;
      Reset_Asked := False;
   end Run;

   function Display_Of (Columns, Rows : Unsigned_8) return Adaflight.Menu.Display is
     (Columns          => Adaflight.Menu.Screen_Columns (Natural'Max (1, Natural (Columns))),
      Rows             => Adaflight.Menu.Screen_Rows (Natural'Max (8, Natural (Rows))),
      Full_Screen      => False,
      Supports_Symbols => False,
      others           => <>);

   procedure Register_CRSF (Columns, Rows : Interfaces.Unsigned_8) is
   begin
      if State.Port_Count < Adaflight.Menu.Max_Displays then
         Nav.Register_Display (State, Display_Of (Columns, Rows));
         CRSF_Display := State.Port_Count - 1;
      end if;
   end Register_CRSF;

   procedure Register_SRXL is
   begin
      if State.Port_Count < Adaflight.Menu.Max_Displays then
         Nav.Register_Display
           (State, Display_Of (Adaflight.SRXL_Telemetry.Input_Columns, Adaflight.SRXL_Telemetry.Rows));
         SRXL_Display := State.Port_Count - 1;
      end if;
   end Register_SRXL;

   function SRXL_Registered return Boolean is (SRXL_Display >= 0);

   function On_SRXL return Boolean is (State.In_Menu and then SRXL_Display >= 0 and then State.Port = SRXL_Display);

   procedure Resize_CRSF (Columns, Rows : Interfaces.Unsigned_8) is
      D : constant Adaflight.Menu.Display := Display_Of (Columns, Rows);
   begin
      if CRSF_Display >= 0 and then not State.In_Menu then
         State.Ports (CRSF_Display).Columns := D.Columns;
         State.Ports (CRSF_Display).Rows := D.Rows;
      end if;
   end Resize_CRSF;

   function CRSF_Registered return Boolean is (CRSF_Display >= 0);

   function On_CRSF return Boolean is (State.In_Menu and then CRSF_Display >= 0 and then State.Port = CRSF_Display);

   procedure Open_On_CRSF (C : Adaflight.Config_Groups.Configuration; Opened : out Boolean) is
      Found : Boolean := False;
   begin
      Opened := False;
      if CRSF_Display >= 0 and then not State.In_Menu then
         Nav.Select_Display (State, CRSF_Display, Found);
         if Found then
            T.Config := C;
            Nav.Open (State, T, Adaflight.Menu_Content.Start_Menu (T), Natural (C.Osd_Config.Cms_Background_Type));
            Opened := True;
         end if;
      end if;
   end Open_On_CRSF;

   procedure Leave is
   begin
      if State.In_Menu and then State.Has_Menu then
         Nav.Exit_Menu (State, T, Adaflight.Menu.Plain);
      end if;
   end Leave;

   procedure Set_Gate (Lat, Lon : Interfaces.Integer_32) is
   begin
      T.Config.Gps_Lap_Timer_Config.Gate_Lat := Lat;
      T.Config.Gps_Lap_Timer_Config.Gate_Lon := Lon;
   end Set_Gate;
end Adaflight.STM32.Menu;
