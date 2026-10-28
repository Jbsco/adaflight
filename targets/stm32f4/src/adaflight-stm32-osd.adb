with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.Board;
with Adaflight.MAX7456;
with Adaflight.MAX7456.Display_Port;
with Adaflight.Config_Runtime;
with Adaflight.OSD_Canvas;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Page;
with Adaflight.OSD_Stats;
with Adaflight.OSD_Warnings;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.RTC;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.OSD is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_8;
   use type Adaflight.OSD_Task.Device_Kind;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The chip's SPI device: its bus, its select pin and the divisor its
   --  transfers take.
   type Chip_Bus is limited record
      Bus     : SPI.Bus := SPI.SPI3;
      CS      : Pin := (Port_A, 0);
      Has_CS  : Boolean := False;
      Divisor : Unsigned_16 := 256;
   end record;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Byte) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   --  One selection of the chip: the select pin low, the bytes out at the
   --  chip's divisor, the select pin high.
   procedure Frame (D : in out Chip_Bus; Tx : Byte_Array; Rx : out Byte_Array)
     with Pre => Rx'Length >= Tx'Length
   is
   begin
      GPIO.Set_Low (D.CS);
      SPI.Set_Divisor (D.Bus, D.Divisor);
      SPI.Transfer (D.Bus, Tx, Rx);
      GPIO.Set_High (D.CS);
   end Frame;

   procedure Preinit_CS (D : in out Chip_Bus; Tag : Byte; Push_Pull : Boolean) is
   begin
      if not Tagged_Pin (Tag) then
         return;
      end if;
      D.CS := Pin_Of (Tag);
      D.Has_CS := True;
      GPIO.Enable_Port (D.CS.Port);
      if Push_Pull then
         GPIO.Set_Output (D.CS);
         GPIO.Set_High (D.CS);
      else
         GPIO.Set_Input (D.CS, GPIO.Up);
      end if;
   end Preinit_CS;

   procedure Attach_Bus (D : in out Chip_Bus; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 3 and then SPI.Started (SPI.Bus'Val (Instance - 1));
      if OK then
         D.Bus := SPI.Bus'Val (Instance - 1);
      end if;
   end Attach_Bus;

   procedure Check_CS_Free (D : in out Chip_Bus; Free : out Boolean) is
   begin
      Free := D.Has_CS;
   end Check_CS_Free;

   procedure Prepare_CS (D : in out Chip_Bus) is
   begin
      GPIO.Enable_Port (D.CS.Port);
      GPIO.Set_Output (D.CS);
      GPIO.Set_High (D.CS);
   end Prepare_CS;

   procedure Release_CS (D : in out Chip_Bus) is
   begin
      GPIO.Set_Input (D.CS, GPIO.Up);
   end Release_CS;

   procedure Claim_CS (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      null;
   end Claim_CS;

   procedure Divider (D : in out Chip_Bus; Hz : Unsigned_32; Divisor : out Unsigned_16) is
      pragma Unreferenced (D);
   begin
      Divisor := SPI.Divider (Hz);
   end Divider;

   function Clock_Of (D : Chip_Bus; Divisor : Unsigned_16) return Unsigned_32 is
      pragma Unreferenced (D);
   begin
      return SPI.Clock_Of (Divisor);
   end Clock_Of;

   procedure Set_Divisor (D : in out Chip_Bus; Divisor : Unsigned_16) is
   begin
      D.Divisor := Divisor;
   end Set_Divisor;

   procedure Write_Byte (D : in out Chip_Bus; Value : Byte) is
      Rx : Byte_Array (0 .. 0);
   begin
      Frame (D, (0 => Value), Rx);
   end Write_Byte;

   procedure Write_Register (D : in out Chip_Bus; Register : Byte; Value : Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame (D, (Register, Value), Rx);
   end Write_Register;

   procedure Read_Register (D : in out Chip_Bus; Register : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Frame (D, (Register or 16#80#, 16#FF#), Rx);
      Value := Rx (1);
   end Read_Register;

   procedure Write_Buffer (D : in out Chip_Bus; Data : Byte_Array) is
      Rx : Byte_Array (0 .. Data'Length - 1);
   begin
      if Data'Length > 0 then
         Frame (D, Data, Rx);
      end if;
   end Write_Buffer;

   procedure Check_Busy (D : in out Chip_Bus; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Check_Busy;

   function Uses_DMA (D : Chip_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Uses_DMA;

   function Transfer_Pending (D : Chip_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Transfer_Pending;

   procedure Wait (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      null;
   end Wait;

   procedure Millis (D : in out Chip_Bus; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Millis;
   end Millis;

   procedure Micros (D : in out Chip_Bus; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Micros;
   end Micros;

   procedure Delay_Ms (D : in out Chip_Bus; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Ms (Ms);
   end Delay_Ms;

   procedure Delay_Us (D : in out Chip_Bus; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Us (Us);
   end Delay_Us;

   procedure Toggle_LED (D : in out Chip_Bus) is
      pragma Unreferenced (D);
   begin
      GPIO.Toggle (Adaflight.Board.LED0_Pin);
   end Toggle_LED;

   package Chip is new Adaflight.MAX7456
     (SPI_Device       => Chip_Bus,
      Preinit_CS       => Preinit_CS,
      Attach_Bus       => Attach_Bus,
      Check_CS_Free    => Check_CS_Free,
      Prepare_CS       => Prepare_CS,
      Release_CS       => Release_CS,
      Claim_CS         => Claim_CS,
      Divider          => Divider,
      Clock_Of         => Clock_Of,
      Set_Divisor      => Set_Divisor,
      Write_Byte       => Write_Byte,
      Write_Register   => Write_Register,
      Read_Register    => Read_Register,
      Write_Buffer     => Write_Buffer,
      Start_Transfer   => Write_Buffer,
      Check_Busy       => Check_Busy,
      Uses_DMA         => Uses_DMA,
      Transfer_Pending => Transfer_Pending,
      Wait             => Wait,
      Millis           => Millis,
      Micros           => Micros,
      Delay_Ms         => Delay_Ms,
      Delay_Us         => Delay_Us,
      Toggle_LED       => Toggle_LED);

   package Chip_Port is new Chip.Display_Port;

   Dev        : Chip_Bus;
   Chip_State : Chip.State;
   Port       : Chip_Port.Port;
   Kind       : Adaflight.OSD_Task.Device_Kind := Adaflight.OSD_Task.None;
   Present    : Boolean := False;

   function Chip_Config (C : Adaflight.Config_Groups.Configuration) return Chip.Config is
     ((Clock_Config => C.Max7456_Config.Clock_Config, CS_Tag => C.Max7456_Config.Cs_Tag,
       SPI_Instance => C.Max7456_Config.Spi_Device, Pre_Init_OPU => C.Max7456_Config.Pre_Init_Opu));

   function Video (C : Adaflight.Config_Groups.Configuration) return Chip.Video_Profile is
     ((Video_System => C.Vcd_Profile.Video_System, H_Offset => C.Vcd_Profile.H_Offset,
       V_Offset => C.Vcd_Profile.V_Offset));

   function Display (C : Adaflight.Config_Groups.Configuration) return Chip_Port.Display_Profile is
     ((Col_Adjust       => C.Display_Port_Profile_Max7456.Col_Adjust,
       Row_Adjust       => C.Display_Port_Profile_Max7456.Row_Adjust,
       Invert           => C.Display_Port_Profile_Max7456.Invert,
       Black_Brightness => C.Display_Port_Profile_Max7456.Black_Brightness,
       White_Brightness => C.Display_Port_Profile_Max7456.White_Brightness));

   function Overclock (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (C.System_Config.Cpu_Overclock /= 0);

   --  The driver's settings as the last start or configuration gave them.
   Chip_Settings    : Chip.Config;
   Video_Settings   : Chip.Video_Profile;
   Display_Settings : Chip_Port.Display_Profile;
   Overclocked      : Boolean := False;

   procedure Keep_Settings (C : Adaflight.Config_Groups.Configuration) is
   begin
      Chip_Settings := Chip_Config (C);
      Video_Settings := Video (C);
      Display_Settings := Display (C);
      Overclocked := Overclock (C);
   end Keep_Settings;

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is
   begin
      Chip.Preinit (Dev, Chip_Config (C));
   end Preinit;

   procedure Init
     (C : in out Adaflight.Config_Groups.Configuration; Feature_OSD : Boolean; Disable_Feature : out Boolean)
   is
      Setting   : constant Byte := C.Osd_Config.Display_Port_Device;
      Available : Boolean;
      Ready     : Boolean;
   begin
      Disable_Feature := False;
      Keep_Settings (C);
      if not Feature_OSD then
         return;
      end if;
      if Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.Auto)
        or else Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.MAX7456)
      then
         Chip_Port.Init (Dev, Chip_State, Port, Chip_Config (C), Video (C), Display (C), Overclock (C), Available,
                         Ready);
         if Available or else Setting = Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.OSD_Task.MAX7456) then
            Kind := Adaflight.OSD_Task.MAX7456;
            Present := Available;
         end if;
      end if;
      if Present then
         Adaflight.OSD_Canvas.Fit (C.Osd_Config, C.Osd_Element_Config, Port.Rows, Port.Cols);
      end if;
      Disable_Feature := Kind = Adaflight.OSD_Task.None;
   end Init;

   function Device return Adaflight.OSD_Task.Device_Kind is (Kind);

   function Port_Present return Boolean is (Present);

   procedure Dimensions (Columns, Rows : out Interfaces.Unsigned_8) is
   begin
      Columns := (if Present then Port.Cols else 0);
      Rows := (if Present then Port.Rows else 0);
   end Dimensions;

   procedure Check_Ready (C : Adaflight.Config_Groups.Configuration; Armed : Boolean; Ready : out Boolean) is
   begin
      if not Present then
         Ready := False;
         return;
      end if;
      Chip_Port.Check_Ready (Dev, Chip_State, Port, Chip_Config (C), Video (C), Display (C), Overclock (C), Armed,
                             Rescan => True, Ready => Ready);
   end Check_Ready;

   procedure Menu_Grab is
   begin
      if Present and then Port.Grab_Count < Interfaces.Integer_8'Last then
         Chip_Port.Grab (Dev, Chip_State, Port, Display_Settings);
      end if;
   end Menu_Grab;

   procedure Menu_Release is
   begin
      if Port.Grab_Count > Interfaces.Integer_8'First then
         Chip_Port.Release (Port);
      end if;
   end Menu_Release;

   function Grabbed return Boolean is (Port.Grab_Count > 0);

   procedure Menu_Clear is
   begin
      if Present then
         Chip_Port.Clear_Screen (Dev, Chip_State, Port, Display_Settings);
      end if;
   end Menu_Clear;

   procedure Menu_Layer_Select (Layer : Natural) is
      Unused : Boolean;
   begin
      Chip.Layer_Select (Chip_State, Layer, Unused);
   end Menu_Layer_Select;

   procedure Menu_Background (Kind : Natural) is
   begin
      if Present then
         Chip.Set_Background (Dev, Chip_State, Kind);
      end if;
   end Menu_Background;

   procedure Menu_Redraw (Armed : Boolean) is
   begin
      if Present then
         Chip_Port.Redraw (Dev, Chip_State, Armed);
      end if;
   end Menu_Redraw;

   procedure Menu_Heartbeat is
      Unused : Boolean;
   begin
      if Present then
         Chip_Port.Heartbeat (Dev, Chip_State, Unused);
      end if;
   end Menu_Heartbeat;

   procedure Menu_Write (X, Y : Interfaces.Unsigned_8; Text : String) is
      Data : Byte_Array (0 .. Text'Length - 1);
   begin
      for I in Data'Range loop
         Data (I) := Byte (Character'Pos (Text (Text'First + I)));
      end loop;
      Chip_Port.Write_String (Chip_State, X, Y, Data);
   end Menu_Write;

   function Font_Write_Taken return Boolean is (Present and then Chip_State.Detected);

   procedure Write_Font (Address : Interfaces.Unsigned_16; Data : Adaflight.MSP_Font_In.Character_Data) is
      Bytes          : Chip_Port.Character_Data;
      Unused_Written : Boolean;
   begin
      for I in Data'Range loop
         Bytes (Bytes'First + I) := Data (I);
      end loop;
      Chip_Port.Write_Font_Character (Dev, Chip_State, Address, Bytes, Unused_Written);
   end Write_Font;

   use type Adaflight.OSD_Task.Task_State;
   use type Adaflight.OSD_Render.Link_Quality_Source;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Task_Data : Adaflight.OSD_Task.OSD;
   Context   : Adaflight.OSD_Task.Context;

   --  A state's last run and an element draw's last time in microseconds,
   --  which stand for the current ones, as the task takes its clock readings
   --  as inputs before it runs.
   State_Us   : array (Adaflight.OSD_Task.Task_State) of Unsigned_32 := (others => 0);
   Element_Us : Unsigned_32 := 0;

   function Name_Of (B : Adaflight.Config_Groups.Bytes_17) return Adaflight.OSD_Render.Name is
      N : Adaflight.OSD_Render.Name;
   begin
      for I in B'Range loop
         exit when B (I) = 0 or else N.Length = Adaflight.OSD_Render.Max_Name;
         N.Length := N.Length + 1;
         N.Data (N.Length) := Character'Val (B (I));
      end loop;
      return N;
   end Name_Of;

   procedure Configure (C : Adaflight.Config_Groups.Configuration; Version : String) is
      O        : Adaflight.Config_Groups.Osd_Config_Record renames C.Osd_Config;
      Rate     : constant Natural := Natural'Min (3, Natural (C.System_Config.Active_Rate_Profile));
      PID      : constant Natural := Natural'Min (3, Natural (C.System_Config.Pid_Profile_Index));
      Bat      : constant Natural := Natural'Min (2, Natural (C.System_Config.Active_Battery_Profile));
      Min_Cell : constant Unsigned_16 := C.Battery_Profiles (Bat).Vbatmincellvoltage;
      Max_Cell : constant Unsigned_16 := C.Battery_Profiles (Bat).Vbatmaxcellvoltage;
   begin
      Keep_Settings (C);
      Context.Device := Kind;
      Context.Background_Layer := False;
      Context.Device_Blink := False;
      Context.Rate_Hz := Adaflight.OSD_Task.Frame_Rate (Unsigned_16'Max (1, Unsigned_16'Min (60, O.Framerate_Hz)));
      Context.Show_Spec := O.Osd_Show_Spec_Prearm /= 0;
      Context.Version (1 .. Version'Length) := Version;
      Context.Version_Length := Version'Length;
      Context.Page_Settings := Adaflight.Config_Runtime.OSD_Page_Settings_Of (O, C.Osd_Element_Config, False);
      Context.Alarm_Settings := Adaflight.Config_Runtime.OSD_Alarm_Settings_Of (O, C.Gps_Rescue_Config);
      for I in Adaflight.OSD_Elements.Item loop
         Context.Positions (I) := C.Osd_Element_Config.Item_Pos (Adaflight.OSD_Elements.Item'Pos (I));
      end loop;
      Context.Draw.Settings :=
        Adaflight.Config_Runtime.OSD_Render_Settings_Of (O, C.Vtx_Settings_Config, C.Osd_Nav_Map_Config);
      Context.Draw.Warn_Settings := Adaflight.Config_Runtime.OSD_Warnings_Settings_Of (O);
      Context.Draw.Craft_Name_Messages := O.Osd_Craftname_Msgs /= 0;
      Context.Draw.Inputs.Min_Cell := Min_Cell;
      Context.Draw.Inputs.Max_Cell := (if Max_Cell = Min_Cell then Min_Cell + 1 else Max_Cell);
      Context.Draw.Inputs.Craft_Name := Name_Of (C.Pilot_Config.Craft_Name);
      Context.Draw.Inputs.Rescue_Min_Sats := C.Gps_Rescue_Config.Min_Sats;
      Context.Draw.Inputs.Pilot_Name := Name_Of (C.Pilot_Config.Pilot_Name);
      Context.Spec_Settings := Adaflight.Config_Runtime.OSD_Spec_Settings_Of
        (C.Mixer_Config, C.Motor_Config, C.Control_Rate_Profiles (Rate), C.Pid_Profiles (PID),
         C.Battery_Profiles (Bat));
      if Context.Spec_Settings.Min_Cell = Context.Spec_Settings.Max_Cell then
         Context.Spec_Settings.Max_Cell := Context.Spec_Settings.Min_Cell + 1;
      end if;
      Context.Page.Units :=
        (if O.Units <= Adaflight.OSD_Format.Unit_System'Pos (Adaflight.OSD_Format.Unit_System'Last)
         then Adaflight.OSD_Format.Unit_System'Val (O.Units) else Adaflight.OSD_Format.Metric);
      Context.Page.Timer_1 := O.Timers (0);
      Context.Page.Timer_2 := O.Timers (1);
      Context.Page.Show_Cell_Value := O.Stat_Show_Cell_Value /= 0;
      Context.RTC_Variant := Adaflight.OSD_Elements.Variant (Context.Positions (Adaflight.OSD_Elements.RTC_Date_Time));
      Task_Data.Craft := (others => Character'Val (0));
      for K in 1 .. Adaflight.OSD_Render.Max_Name loop
         exit when C.Pilot_Config.Craft_Name (C.Pilot_Config.Craft_Name'First + K - 1) = 0;
         Task_Data.Craft (K) := Character'Val (C.Pilot_Config.Craft_Name (C.Pilot_Config.Craft_Name'First + K - 1));
      end loop;
   end Configure;

   procedure Analyze_Again is
   begin
      Task_Data.Last_GPS := not Context.Element_Inputs.GPS_Present;
   end Analyze_Again;

   function Task_Due (Now_Us : Unsigned_32) return Boolean is
      Due : Boolean;
   begin
      Adaflight.OSD_Task.Update_Check (Task_Data, Context, Now_Us, False, Due);
      return Due;
   end Task_Due;

   function Modes_Of (M : Adaflight.Arming.Mode_Set) return Adaflight.OSD_Render.Mode_Flags is
     ((Failsafe   => M (Adaflight.Arming.Failsafe_Mode),
       GPS_Rescue => M (Adaflight.Arming.GPS_Rescue_Mode),
       Headfree   => M (Adaflight.Arming.Headfree_Mode),
       Passthru   => M (Adaflight.Arming.Passthru_Mode),
       Pos_Hold   => M (Adaflight.Arming.Pos_Hold_Mode),
       Alt_Hold   => M (Adaflight.Arming.Alt_Hold_Mode),
       Chirp      => M (Adaflight.Arming.Chirp_Mode),
       Angle      => M (Adaflight.Arming.Angle_Mode),
       Horizon    => M (Adaflight.Arming.Horizon_Mode)));

   --  The frame's readings into the task's context.
   procedure Refresh (F : Facts; Now_Us : Unsigned_32) is
      P : Adaflight.OSD_Page.Inputs renames Context.Page_Inputs;
      R : Adaflight.OSD_Stats.Readings renames Context.Readings;
      A : Adaflight.OSD_Elements.Alarm_Inputs renames Context.Alarm_Inputs;
      D : Adaflight.OSD_Render.Inputs renames Context.Draw.Inputs;
      W : Adaflight.OSD_Warnings.Inputs renames Context.Draw.Warn_Inputs;
   begin
      P.Now_Us := Now_Us;
      P.Armed := F.Armed;
      P.Was_Ever_Armed := F.Was_Ever_Armed;
      P.Has_Link_Quality_Source := F.Link_Source /= Adaflight.OSD_Render.None;
      P.Failsafe_Active := F.Failsafe_Active;
      P.Display_Grabbed := Grabbed;
      P.OSD_Switch := F.OSD_Switch;
      P.Launch_Control_Active := F.Launch_Control;
      P.Aux_Rc := F.Aux_Rc;
      P.Throttle_High := F.Throttle_High;
      P.Pitch_High := F.Pitch_High;
      P.Crash_Flip_Box := F.Crash_Flip_Box;
      P.Crash_Flip_Active := F.Crash_Flip_Active;
      P.Acc_Present := F.Acc_Present;
      P.Acc_Magnitude := F.G_Force;

      R.Pack_Voltage := F.Pack_Voltage;
      R.Cell_Voltage := F.Cell_Voltage;
      R.Show_Cell_Value := Context.Page.Show_Cell_Value;
      R.Amperage := F.Amperage;
      R.RSSI_Percent := F.RSSI_Percent;
      R.Link_Quality_Percent := F.Link_Percent;
      R.RSSI_Dbm := F.RSSI_Dbm;
      R.RSNR := F.RSNR;
      R.Acceleration := F.G_Force;
      R.Motors := F.Motors;
      R.GPS_Fix := F.GPS.Fix;
      R.GPS_Fix_Home := F.GPS.Fix_Home;
      R.Distance_To_Home := F.GPS.Distance_To_Home_M;
      R.Speed_3D := F.GPS.Speed_3D;
      R.Ground_Speed := F.GPS.Ground_Speed;
      R.Use_3D_Speed := F.GPS.Use_3D_Speed;
      R.Altitude_Cm := F.Altitude_Cm;
      R.ESC_Sensor_Feature := F.ESC_Feature;
      R.ESC_Temperature := F.ESC_Combined.Temperature;
      R.ESC_Erpm := Natural (Interfaces.Integer_16'Max (0, F.ESC_Combined.Rpm));
      R.Erpm_To_Hz := F.ESC_Erpm_To_Hz;

      A.RSSI_Percent := F.RSSI_Percent;
      A.RSSI_Dbm := F.RSSI_Dbm;
      A.Link_Quality := F.Link_Percent;
      A.Battery := F.Battery;
      A.Profile_Capacity := F.Battery_Capacity;
      A.MAh_Drawn := F.MAh_Drawn;
      A.Motors := F.Motors;
      A.GPS_Present := F.GPS_Feature;
      A.GPS_Fix := F.GPS.Fix;
      A.GPS_Fix_Home := F.GPS.Fix_Home;
      A.Satellites := F.GPS.Satellites;
      A.Home_Distance_M := F.GPS.Distance_To_Home_M;
      A.Altitude_Cm := F.Altitude_Cm;
      A.ESC_Sensor_Feature := F.ESC_Feature;
      A.ESC_Temperature := F.ESC_Combined.Temperature;

      Context.Element_Inputs.Acc_Present := F.Acc_Present;
      Context.Element_Inputs.GPS_Present := F.GPS_Feature;
      Context.Element_Inputs.ESC_Sensor_Feature := F.ESC_Feature;
      Adaflight.STM32.RTC.Date_Now (Context.Has_Time, Context.Date);
      Context.Zone := (Zone => Adaflight.STM32.RTC.Zone);
      Context.Draw.Inputs.Has_Time := Context.Has_Time;
      Context.Draw.Inputs.Date := Context.Date;
      Context.Draw.Inputs.Zone := Context.Zone;
      Context.Page.GPS_Feature := F.GPS_Feature;
      Context.Page.Total_Flights := F.Total_Flights;
      Context.Page.Total_Time_S := F.Total_Time_S;
      Context.Page.Total_Dist_M := F.Total_Dist_M;

      D.Roll := F.Roll;
      D.Pitch := F.Pitch;
      D.Yaw := F.Yaw;
      D.Anti_Gravity := F.Anti_Gravity;
      D.Cell_Voltage := F.Cell_Voltage;
      D.Battery := F.Battery;
      D.Amperage := F.Amperage;
      D.G_Force := F.G_Force;
      D.MAh_Drawn := F.MAh_Drawn;
      D.Profile_Capacity := F.Battery_Capacity;
      D.Battery_Percent := F.Battery_Percent;
      D.Pack_Voltage := F.Pack_Voltage;
      D.PID_Index := F.PID_Index;
      D.Rate_Index := F.Rate_Index;
      D.RSSI_Percent := F.RSSI_Percent;
      D.RSSI_Dbm := F.RSSI_Dbm;
      D.RSNR := F.RSNR;
      D.Link_Source := F.Link_Source;
      D.Link_Quality := F.Link_Quality;
      D.RF_Mode := F.RF_Mode;
      D.Link_Quality_Percent := F.Link_Percent;
      D.Uplink_Mw := F.Uplink_mW;
      D.Throttle_Percent := Interfaces.Integer_8 (F.Throttle_Percent);
      D.Modes := Modes_Of (F.Modes);
      D.Airmode := F.Airmode;
      D.Motors := F.Motors;
      D.Motor_Output := F.Motor_Output;
      D.Output_Low := F.Output_Low;
      D.Output_High := (if F.Output_High > F.Output_Low + 1.0 then F.Output_High else F.Output_Low + 2.0);
      D.Motors_Running := F.Motors_Running;
      D.ESC_Sensor_Feature := F.ESC_Feature;
      D.ESC_Temperature := F.ESC_Combined.Temperature;
      D.ERPM_To_Hz := F.ESC_Erpm_To_Hz;
      for K in Adaflight.OSD_Render.Motor_Index loop
         D.ESC_RPM (K) := Natural (Interfaces.Integer_16'Max (0, F.ESC_Motors (K).Rpm));
      end loop;
      D.GPS_Present := F.GPS_Feature;
      D.GPS_Fix := F.GPS.Fix;
      D.GPS_Fix_Home := F.GPS.Fix_Home;
      D.GPS_Fix_Ever := F.GPS.Fix_Ever;
      D.Latitude := Interfaces.Integer_32'Max (Interfaces.Integer_32'First + 1, F.GPS.Latitude);
      D.Longitude := Interfaces.Integer_32'Max (Interfaces.Integer_32'First + 1, F.GPS.Longitude);
      D.Satellites := F.GPS.Satellites;
      D.PDOP := F.GPS.PDOP;
      D.Speed_3D := F.GPS.Speed_3D;
      D.Ground_Speed := F.GPS.Ground_Speed;
      D.GPS_Time_Ms := F.GPS.Time_Ms;
      D.Home_Distance_M := F.GPS.Distance_To_Home_M;
      D.Home_Direction :=
        Adaflight.OSD_Render.Yaw_Decidegrees ((Integer (F.GPS.Direction_To_Home) mod 3_600 + 3_600) mod 3_600);
      D.Flown_Cm := F.GPS.Distance_Flown_Cm;
      D.Use_3D_Speed := F.GPS.Use_3D_Speed;
      D.Altitude_Cm := F.Altitude_Cm;
      D.Adjustment_Present := F.Adjustment_Present;
      D.Adjustment_Name := F.Adjustment_Name;
      D.Adjustment_Value := F.Adjustment_Value;
      D.Vario_Cm_S := F.Vario;
      D.Pos_Hold_Ready := F.Pos_Hold_Ready;
      D.GPS_Healthy := F.GPS.Healthy;
      D.Screen_Rows := Port.Rows;
      D.Screen_Cols := Port.Cols;

      W.Now_Us := Now_Us;
      W.Battery := F.Battery;
      W.Armed := F.Armed;
      W.Was_Ever_Armed := F.Was_Ever_Armed;
      W.Arm_Box := F.Arm_Box;
      W.Disable_Flags := F.Disabled;
      W.Trying_To_Arm := F.Trying_To_Arm;
      W.Failsafe_Active := F.Failsafe_Active;
      W.Motors := F.Motors;
      W.ESC_Sensor_Feature := F.ESC_Feature;
      W.Erpm_To_Hz := F.ESC_Erpm_To_Hz;
      for K in Adaflight.OSD_Render.Motor_Index loop
         W.ESC_Sensor (K) :=
           (Present     => F.ESC_Feature and then K < F.Motors,
            RPM         => F.ESC_Motors (K).Rpm,
            Current     => F.ESC_Motors (K).Current,
            Temperature => F.ESC_Motors (K).Temperature);
         W.Motor_Active (K) := F.Motor_Active (K);
      end loop;
      W.Crash_Flip_Box := F.Crash_Flip_Box;
      W.Crash_Flip_Active := F.Crash_Flip_Active;
      W.Launch_Control_Active := F.Launch_Control;
      W.Acc_Present := F.Acc_Present;
      W.Pitch_Decidegrees := F.Pitch;
      W.Throttle_Percent := F.Throttle_Percent;
      W.RSSI_Percent := Natural (F.RSSI_Percent);
      W.RSSI_Dbm := F.RSSI_Dbm;
      W.RSNR := F.RSNR;
      W.Link_Quality_Percent := Natural (F.Link_Percent);
      W.Armed_Time_Us := Task_Data.Stats.Armed_Time_Us;
      W.Headfree_Mode := F.Modes (Adaflight.Arming.Headfree_Mode);
      W.Battery_Capacity := Natural (F.Battery_Capacity);
      W.MAh_Drawn := Natural (F.MAh_Drawn);
      W.Has_Used_MAh := F.MAh_Drawn > 0;
      W.Average_Cell_Voltage := Natural (F.Cell_Voltage);
      W.Full_Cell_Voltage := Natural (F.Full_Cell_Voltage);
      W.Pos_Hold_Failure := F.Pos_Hold_Failure;

      Context.Spec_Inputs.Pack_Voltage := F.Pack_Voltage;
      Context.Spec_Inputs.Cell_Voltage := F.Cell_Voltage;
      Context.Spec_Inputs.Battery := F.Battery;

      Context.Page.Acc_Present := F.Acc_Present;
      Context.Page.Pack_Voltage := F.Pack_Voltage;
      Context.Page.Cell_Voltage := F.Cell_Voltage;
      Context.Page.MAh_Drawn := F.MAh_Drawn;
   end Refresh;

   function Bytes_Of (T : Adaflight.OSD_Format.Text) return Byte_Array is
      B : Byte_Array (0 .. T.Length - 1);
   begin
      for I in B'Range loop
         B (I) := Byte (Character'Pos (T.Data (I + 1)));
      end loop;
      return B;
   end Bytes_Of;

   --  The task's display operations on the MAX7456. The chip has no system
   --  elements, background redraw or transactions, and the heartbeat and
   --  the draw ran before the state for its answers.
   procedure Execute (Result : Adaflight.OSD_Task.Ops; Armed : Boolean) is
      use all type Adaflight.OSD_Task.Op_Kind;
      Unused : Boolean;
   begin
      for K in 1 .. Result.Count loop
         declare
            Op : Adaflight.OSD_Task.Op renames Result.List (K);
         begin
            case Op.Kind is
               when Clear =>
                  Chip_Port.Clear_Screen (Dev, Chip_State, Port, Display_Settings);
               when Write =>
                  Chip_Port.Write_String (Chip_State, Op.X, Op.Y, Bytes_Of (Op.Line));
               when Write_Char =>
                  if Op.Line.Length > 0 then
                     Chip.Write_Char (Chip_State, Op.X, Op.Y, Byte (Character'Pos (Op.Line.Data (1))));
                  end if;
               when Select_Layer =>
                  Chip.Layer_Select (Chip_State, Natural (Op.Attr), Unused);
               when Layer_Copy =>
                  Chip_Port.Port_Layer_Copy (Chip_State, 0, 1, Unused);
               when Redraw =>
                  Chip_Port.Redraw (Dev, Chip_State, Armed);
               when Write_Logo | Write_Sys | Redraw_Background | Begin_Transaction | Commit_Transaction | Heartbeat
                  | Draw_Screen =>
                  null;
            end case;
         end;
      end loop;
   end Execute;

   procedure Run (F : Facts; Now_Us : Unsigned_32; Sched : in out Adaflight.Scheduler.State) is
      State    : constant Adaflight.OSD_Task.Task_State := Task_Data.State;
      Answers  : Adaflight.OSD_Task.Display_Answers;
      Result   : Adaflight.OSD_Task.Ops;
      Start    : Unsigned_32;
      Clock_Us : Unsigned_32;
      Draw_End : Unsigned_32;
   begin
      Refresh (F, Now_Us);
      Answers.Grabbed := Grabbed;
      case State is
         when Adaflight.OSD_Task.Init =>
            Chip_Port.Check_Ready (Dev, Chip_State, Port, Chip_Settings, Video_Settings, Display_Settings,
                                   Overclocked, F.Armed, Rescan => False, Ready => Answers.Ready);
         when Adaflight.OSD_Task.Update_Heartbeat =>
            Chip_Port.Heartbeat (Dev, Chip_State, Answers.Heartbeat_Taken);
         when Adaflight.OSD_Task.Transfer =>
            Chip.Draw_Screen (Dev, Chip_State, Answers.More_To_Draw);
         when others =>
            null;
      end case;
      Start := Time.Micros;
      if State = Adaflight.OSD_Task.Draw_Element then
         Clock_Us := Start;
         Draw_End := Start + Element_Us;
      else
         Clock_Us := Start + State_Us (State);
         Draw_End := Clock_Us;
      end if;
      Adaflight.OSD_Task.Update (Task_Data, Context, Now_Us, Clock_Us, Draw_End, Answers, Sched, Result);
      Execute (Result, F.Armed);
      if State = Adaflight.OSD_Task.Draw_Element then
         Element_Us := Time.Micros - Start;
      else
         State_Us (State) := Time.Micros - Start;
      end if;
   end Run;
end Adaflight.STM32.OSD;
