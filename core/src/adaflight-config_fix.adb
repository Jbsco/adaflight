with Adaflight.Maths;
with Adaflight.Mixer_Init;
with Adaflight.OSD_Task;
with Adaflight.Sensor_Alignment;

package body Adaflight.Config_Fix with SPARK_Mode is

   package Map renames Adaflight.Serial_Feature_Map;
   use type Map.Telemetry_Provider;

   Box_Arm          : constant Unsigned_8 := 0;
   Box_GPS_Rescue   : constant Unsigned_8 := 10;
   Box_MSP_Override : constant Unsigned_8 := 44;

   Mixer_Custom          : constant Unsigned_8 := 23;
   Mixer_Custom_Airplane : constant Unsigned_8 := 24;
   Mixer_Custom_Tri      : constant Unsigned_8 := 25;
   Mixer_Last            : constant Unsigned_8 := 27;

   Protocol_PWM          : constant Unsigned_8 := 0;
   Protocol_Oneshot_125  : constant Unsigned_8 := 1;
   Protocol_Oneshot_42   : constant Unsigned_8 := 2;
   Protocol_Brushed      : constant Unsigned_8 := 4;
   Protocol_DShot_150    : constant Unsigned_8 := 5;
   Protocol_DShot_300    : constant Unsigned_8 := 6;
   Protocol_DShot_600    : constant Unsigned_8 := 7;
   Protocol_ProShot_1000 : constant Unsigned_8 := 8;

   Brushless_PWM_Rate    : constant := 480;
   Max_PID_Process_Denom : constant Unsigned_8 := 16;

   Failsafe_Drop_It    : constant Unsigned_8 := 1;
   Failsafe_GPS_Rescue : constant Unsigned_8 := 2;
   Failsafe_Count      : constant Unsigned_8 := 3;

   function Is_DShot (Protocol : Unsigned_8) return Boolean is
     (Protocol in Protocol_DShot_150 .. Protocol_ProShot_1000);

   procedure Enable (Features : in out Unsigned_32; Runtime : in out Unsigned_32; Mask : Unsigned_32)
     with Post => Features = (Features'Old or Mask) and then Runtime = (Runtime'Old or Mask)
   is
   begin
      Features := Features or Mask;
      Runtime := Runtime or Mask;
   end Enable;

   procedure Disable (Features : in out Unsigned_32; Runtime : in out Unsigned_32; Mask : Unsigned_32)
     with Post => Features = (Features'Old and not Mask) and then Runtime = (Runtime'Old and not Mask)
   is
   begin
      Features := Features and not Mask;
      Runtime := Runtime and not Mask;
   end Disable;

   --  A cutoff past the filter limit takes the reset value.
   procedure Limit_Filter (Hz : in out Unsigned_16; Reset : Unsigned_16)
     with Post => Hz = (if Hz'Old > LPF_Max_Hz then Reset else Hz'Old)
   is
   begin
      if Hz > LPF_Max_Hz then
         Hz := Reset;
      end if;
   end Limit_Filter;

   --  A mode with motors but no motor table becomes the custom mode, and one
   --  with servos but no servo rules the custom airplane. A mode past the
   --  mixer table stays as it is.
   procedure Fix_Mixer_Mode (Mode : in out Unsigned_8) is
      use Adaflight.Mixer_Init;
      Mixers : constant Mixer_Init.Options := (others => <>);
      function Has_Servo_Rules (M : Mixer_Mode) return Boolean is
        (M in Tri | Bicopter | Gimbal | Flying_Wing | Airplane | Heli_120_CCPM | Dualcopter | Singlecopter);
   begin
      if Mode in 1 .. Mixer_Last and then Mode not in Mixer_Custom | Mixer_Custom_Airplane | Mixer_Custom_Tri then
         declare
            M : constant Mixer_Mode := Mixer_Mode'Val (Mode - 1);
         begin
            if Motor_Count_Of (M) > 0 and then not Has_Table (Mixers, M) then
               Mode := Mixer_Custom;
            end if;
            if Uses_Servos (M) and then not Has_Servo_Rules (M) then
               Mode := Mixer_Custom_Airplane;
            end if;
         end;
      end if;
   end Fix_Mixer_Mode;

   --  A later provider slot repeating the protocol of an earlier slot with a
   --  port is cleared.
   procedure Validate_Providers (P : in out Telemetry_Provider_Record_List_3) is
   begin
      for I in 1 .. P'Last loop
         if P (I).Protocol /= 0 then
            for J in 0 .. I - 1 loop
               if P (J).Protocol = P (I).Protocol and then P (J).Uart /= -1 then
                  P (I) := (Protocol => 0, Uart => -1, Baud => 0);
                  exit;
               end if;
            end loop;
         end if;
      end loop;
   end Validate_Providers;

   function To_Port (V : Integer_8) return Map.Port_Id is
     (if Integer (V) in Map.Port_Id'Range then Map.Port_Id (V) else Absent_Port);

   function To_Baud (V : Unsigned_8) return Map.Baud_Index is
     (if V <= Unsigned_8 (Map.Baud_Index'Last) then Map.Baud_Index (V) else Map.Baud_Auto);

   function To_Protocol (V : Unsigned_8) return Map.Telemetry_Protocol is
     (if V <= Map.Telemetry_Protocol'Pos (Map.Telemetry_Protocol'Last) then Map.Telemetry_Protocol'Val (V)
      else Map.No_Telemetry);

   function To_VTX (V : Unsigned_8) return Map.VTX_Device is
     (case V is
         when 0 => Map.Unsupported,
         when 1 => Map.RTC6705,
         when 3 => Map.SmartAudio,
         when 4 => Map.Tramp,
         when 5 => Map.MSP_VTX,
         when others => Map.Unknown);

   function Provider_Of (P : Telemetry_Provider_Record) return Map.Telemetry_Provider is
     (Protocol => To_Protocol (P.Protocol), Port => To_Port (P.Uart), Baud => To_Baud (P.Baud));

   --  The serial assignments the port settings make.
   function Assignments_Of
     (Msp : Msp_Config_Record; Gps : Gps_Config_Record; Rx : Rx_Config_Record; Blackbox : Blackbox_Config_Record;
      ESC : Esc_Sensor_Config_Record; Device : Rcdevice_Config_Record; Gimbal : Gimbal_Track_Config_Record;
      VTX : Vtx_Settings_Config_Record; Rangefinder : Rangefinder_Config_Record; Flow : Opticalflow_Config_Record;
      OSD : Osd_Config_Record; Telemetry : Telemetry_Config_Record) return Map.Assignments
   is
     (MSP_Port            => (To_Port (Msp.Msp_Uart (0)), To_Port (Msp.Msp_Uart (1)), To_Port (Msp.Msp_Uart (2))),
      MSP_Baud            => (To_Baud (Msp.Msp_Baud (0)), To_Baud (Msp.Msp_Baud (1)), To_Baud (Msp.Msp_Baud (2))),
      GPS_Port            => To_Port (Gps.Gps_Uart),
      GPS_Baud            => To_Baud (Gps.Gps_Baud),
      RX_Port             => To_Port (Rx.Rx_Uart),
      RX_Provider         =>
        (if Rx.Serialrx_Provider <= Map.Serial_RX'Pos (Map.Serial_RX'Last)
         then Map.Serial_RX'Val (Rx.Serialrx_Provider) else Map.No_Serial_RX),
      Blackbox_Port       => To_Port (Blackbox.Blackbox_Uart),
      Blackbox_Baud       => To_Baud (Blackbox.Blackbox_Baud),
      ESC_Sensor_Port     => To_Port (ESC.Esc_Sensor_Uart),
      RCDevice_Port       => To_Port (Device.Rcdevice_Uart),
      Gimbal_Port         => To_Port (Gimbal.Gimbal_Uart),
      VTX_Port            => To_Port (VTX.Vtx_Uart),
      VTX_Type            => To_VTX (VTX.Vtx_Type),
      Rangefinder_Port    => To_Port (Rangefinder.Rangefinder_Uart),
      Rangefinder_On_MSP  => Rangefinder.Rangefinder_Hardware in 4 .. 7,
      Optical_Flow_Port   => To_Port (Flow.Opticalflow_Uart),
      Optical_Flow_On_MSP => Flow.Opticalflow_Hardware = 1,
      OSD_Port            => To_Port (OSD.Osd_Uart),
      Display_Device      =>
        (if OSD.Display_Port_Device <= OSD_Task.Device_Kind'Pos (OSD_Task.Device_Kind'Last)
         then OSD_Task.Device_Kind'Val (OSD.Display_Port_Device) else OSD_Task.None),
      Custom_Text_Port    => To_Port (OSD.Osd_Custom_Text_Uart),
      Custom_Text_Baud    => To_Baud (OSD.Osd_Custom_Text_Baud),
      Telemetry           =>
        (Provider_Of (Telemetry.Providers (0)), Provider_Of (Telemetry.Providers (1)),
         Provider_Of (Telemetry.Providers (2))));

   --  A port setting the serial check changed takes its new port.
   procedure Write_Port (Setting : in out Integer_8; Before : Map.Port_Id; After : Map.Port_Id) is
   begin
      if After /= Before then
         Setting := Integer_8 (After);
      end if;
   end Write_Port;

   procedure Write_MSP_Ports (Uarts : in out Integer_8_List_3; Before : Map.MSP_Ports; After : Map.MSP_Ports) is
   begin
      for S in Map.MSP_Slot loop
         Write_Port (Uarts (Integer (S) - 1), Before (S), After (S));
      end loop;
   end Write_MSP_Ports;

   function Serial_Assignments (C : Configuration) return Map.Assignments is
     (Assignments_Of
        (C.Msp_Config, C.Gps_Config, C.Rx_Config, C.Blackbox_Config, C.Esc_Sensor_Config, C.Rcdevice_Config,
         C.Gimbal_Track_Config, C.Vtx_Settings_Config, C.Rangefinder_Config, C.Opticalflow_Config, C.Osd_Config,
         C.Telemetry_Config));

   procedure Write_Baud (Setting : in out Unsigned_8; Before : Map.Baud_Index; After : Map.Baud_Index) is
   begin
      if After /= Before then
         Setting := Unsigned_8 (After);
      end if;
   end Write_Baud;

   VTX_Device_Numbers : constant array (Map.VTX_Device) of Unsigned_8 :=
     (Map.Unsupported => 0, Map.RTC6705 => 1, Map.SmartAudio => 3, Map.Tramp => 4, Map.MSP_VTX => 5,
      Map.Unknown => 255);

   procedure Store_Serial_Assignments (C : in out Configuration; Before, After : Map.Assignments) is
      use type Map.VTX_Device;
      use type Map.Telemetry_Protocol;
      use type OSD_Task.Device_Kind;
   begin
      Write_MSP_Ports (C.Msp_Config.Msp_Uart, Before.MSP_Port, After.MSP_Port);
      for S in Map.MSP_Slot loop
         Write_Baud (C.Msp_Config.Msp_Baud (Integer (S) - 1), Before.MSP_Baud (S), After.MSP_Baud (S));
      end loop;
      Write_Port (C.Gps_Config.Gps_Uart, Before.GPS_Port, After.GPS_Port);
      Write_Baud (C.Gps_Config.Gps_Baud, Before.GPS_Baud, After.GPS_Baud);
      Write_Port (C.Rx_Config.Rx_Uart, Before.RX_Port, After.RX_Port);
      Write_Port (C.Blackbox_Config.Blackbox_Uart, Before.Blackbox_Port, After.Blackbox_Port);
      Write_Baud (C.Blackbox_Config.Blackbox_Baud, Before.Blackbox_Baud, After.Blackbox_Baud);
      Write_Port (C.Esc_Sensor_Config.Esc_Sensor_Uart, Before.ESC_Sensor_Port, After.ESC_Sensor_Port);
      Write_Port (C.Rcdevice_Config.Rcdevice_Uart, Before.RCDevice_Port, After.RCDevice_Port);
      Write_Port (C.Gimbal_Track_Config.Gimbal_Uart, Before.Gimbal_Port, After.Gimbal_Port);
      Write_Port (C.Vtx_Settings_Config.Vtx_Uart, Before.VTX_Port, After.VTX_Port);
      if After.VTX_Type /= Before.VTX_Type then
         C.Vtx_Settings_Config.Vtx_Type := VTX_Device_Numbers (After.VTX_Type);
      end if;
      Write_Port (C.Rangefinder_Config.Rangefinder_Uart, Before.Rangefinder_Port, After.Rangefinder_Port);
      Write_Port (C.Opticalflow_Config.Opticalflow_Uart, Before.Optical_Flow_Port, After.Optical_Flow_Port);
      Write_Port (C.Osd_Config.Osd_Uart, Before.OSD_Port, After.OSD_Port);
      if After.Display_Device /= Before.Display_Device then
         C.Osd_Config.Display_Port_Device := OSD_Task.Device_Kind'Pos (After.Display_Device);
      end if;
      Write_Port (C.Osd_Config.Osd_Custom_Text_Uart, Before.Custom_Text_Port, After.Custom_Text_Port);
      Write_Baud (C.Osd_Config.Osd_Custom_Text_Baud, Before.Custom_Text_Baud, After.Custom_Text_Baud);
      for S in Map.Telemetry_Slot loop
         if After.Telemetry (S).Protocol /= Before.Telemetry (S).Protocol then
            C.Telemetry_Config.Providers (Integer (S) - 1).Protocol :=
              Map.Telemetry_Protocol'Pos (After.Telemetry (S).Protocol);
         end if;
         Write_Port (C.Telemetry_Config.Providers (Integer (S) - 1).Uart, Before.Telemetry (S).Port,
                     After.Telemetry (S).Port);
         Write_Baud (C.Telemetry_Config.Providers (Integer (S) - 1).Baud, Before.Telemetry (S).Baud,
                     After.Telemetry (S).Baud);
      end loop;
   end Store_Serial_Assignments;

   --  A provider the serial check cleared loses its protocol and port.
   procedure Write_Providers
     (Providers : in out Telemetry_Provider_Record_List_3; Before : Map.Telemetry_Providers;
      After : Map.Telemetry_Providers)
   is
   begin
      for S in Map.Telemetry_Slot loop
         if After (S) /= Before (S) then
            Providers (Integer (S) - 1).Protocol := Map.Telemetry_Protocol'Pos (After (S).Protocol);
            Providers (Integer (S) - 1).Uart := Integer_8 (After (S).Port);
         end if;
      end loop;
   end Write_Providers;

   --  An invalid serial assignment loses the claims on its conflicting
   --  ports, then every claim when it is still invalid, leaving MSP on the
   --  first port at its default baud rate.
   procedure Fix_Serial
     (Msp : in out Msp_Config_Record; Gps : in out Gps_Config_Record; Rx : in out Rx_Config_Record;
      Blackbox : in out Blackbox_Config_Record; ESC : in out Esc_Sensor_Config_Record;
      Device : in out Rcdevice_Config_Record; Gimbal : in out Gimbal_Track_Config_Record;
      VTX : in out Vtx_Settings_Config_Record; Rangefinder : in out Rangefinder_Config_Record;
      Flow : in out Opticalflow_Config_Record; OSD : in out Osd_Config_Record;
      Telemetry : in out Telemetry_Config_Record; Ports : Map.Port_List)
     with Pre => Ports'Length in 1 .. Map.Max_Ports
   is
      Before : constant Map.Assignments :=
        Assignments_Of (Msp, Gps, Rx, Blackbox, ESC, Device, Gimbal, VTX, Rangefinder, Flow, OSD, Telemetry);
      A      : Map.Assignments := Before;
      Reset  : Boolean := False;
   begin
      if not Map.Config_Valid (Serial_Options, A, Ports) then
         Map.Drop_Conflicting_Assignments (Serial_Options, A, Ports);
         if not Map.Config_Valid (Serial_Options, A, Ports) then
            Map.Reset_Feature_Assignments (Serial_Options, A, Ports);
            Reset := True;
         end if;
      end if;
      Write_MSP_Ports (Msp.Msp_Uart, Before.MSP_Port, A.MSP_Port);
      if Reset then
         Msp.Msp_Baud (0) := Unsigned_8 (Map.Default_Port_Baud (Map.MSP_Baud));
      end if;
      Write_Port (Gps.Gps_Uart, Before.GPS_Port, A.GPS_Port);
      Write_Port (Rx.Rx_Uart, Before.RX_Port, A.RX_Port);
      Write_Port (Blackbox.Blackbox_Uart, Before.Blackbox_Port, A.Blackbox_Port);
      Write_Port (ESC.Esc_Sensor_Uart, Before.ESC_Sensor_Port, A.ESC_Sensor_Port);
      Write_Port (Device.Rcdevice_Uart, Before.RCDevice_Port, A.RCDevice_Port);
      Write_Port (Gimbal.Gimbal_Uart, Before.Gimbal_Port, A.Gimbal_Port);
      Write_Port (VTX.Vtx_Uart, Before.VTX_Port, A.VTX_Port);
      Write_Port (Rangefinder.Rangefinder_Uart, Before.Rangefinder_Port, A.Rangefinder_Port);
      Write_Port (Flow.Opticalflow_Uart, Before.Optical_Flow_Port, A.Optical_Flow_Port);
      Write_Port (OSD.Osd_Uart, Before.OSD_Port, A.OSD_Port);
      Write_Port (OSD.Osd_Custom_Text_Uart, Before.Custom_Text_Port, A.Custom_Text_Port);
      Write_Providers (Telemetry.Providers, Before.Telemetry, A.Telemetry);
   end Fix_Serial;

   --  A GPS that needs no serial port gives up the port it names, and one
   --  that needs a port and names none turns the GPS feature off.
   procedure Fix_GPS_Port
     (GPS : Gps_Config_Record; Features : in out Unsigned_32; Runtime : in out Unsigned_32; Removed : in out Integer_8)
   is
      No_Port_Needed : constant Boolean := GPS.Provider in 2 .. 4;
   begin
      if No_Port_Needed and then GPS.Gps_Uart /= -1 then
         Removed := GPS.Gps_Uart;
      end if;
      if not No_Port_Needed and then GPS.Gps_Uart = -1 then
         Disable (Features, Runtime, Feature_GPS);
      end if;
   end Fix_GPS_Port;

   --  Brushed motors turn 3D off and start at 1000 at least, and PWM motors
   --  update at 480 Hz at most.
   procedure Fix_Motor_Output
     (M : in out Motor_Config_Record; Features : in out Unsigned_32; Runtime : in out Unsigned_32)
   is
   begin
      if M.Dev.Motor_Protocol = Protocol_Brushed then
         Disable (Features, Runtime, Feature_3D);
         if M.Mincommand < 1_000 then
            M.Mincommand := 1_000;
         end if;
      end if;
      if M.Dev.Motor_Protocol = Protocol_PWM and then M.Dev.Motor_Pwm_Rate > Brushless_PWM_Rate then
         M.Dev.Motor_Pwm_Rate := Brushless_PWM_Rate;
      end if;
   end Fix_Motor_Output;

   --  The D term filter cutoffs within their limit and in order, the motor
   --  output limit and the automatic cell count within range, D max at or
   --  above D, and no sag compensation without an ADC voltage meter.
   procedure Fix_PID_Profile (P : in out Pid_Profile_Record; Voltage_From_ADC : Boolean)
     with Post => Fixed_PID_Profile (P)
   is
   begin
      Limit_Filter (P.Dterm_Lpf1_Static_Hz, LPF_Max_Hz);
      Limit_Filter (P.Dterm_Lpf2_Static_Hz, LPF_Max_Hz);
      Limit_Filter (P.Dterm_Notch_Hz, LPF_Max_Hz);
      Limit_Filter (P.Dterm_Notch_Cutoff, 0);
      if P.Dterm_Notch_Cutoff >= P.Dterm_Notch_Hz then
         P.Dterm_Notch_Hz := 0;
      end if;
      if P.Dterm_Lpf1_Dyn_Min_Hz > P.Dterm_Lpf1_Dyn_Max_Hz then
         P.Dterm_Lpf1_Dyn_Min_Hz := 0;
      end if;
      if P.Motor_Output_Limit > 100 or else P.Motor_Output_Limit = 0 then
         P.Motor_Output_Limit := 100;
      end if;
      if P.Auto_Profile_Cell_Count > 8 or else P.Auto_Profile_Cell_Count < -1 then
         P.Auto_Profile_Cell_Count := 0;
      end if;
      for Axis in P.D_Max'Range loop
         if P.D_Max (Axis) < P.Pid (Axis).D then
            P.D_Max (Axis) := 0;
         end if;
      end loop;
      if not Voltage_From_ADC then
         P.Vbat_Sag_Compensation := 0;
      end if;
   end Fix_PID_Profile;

   procedure Fix_PID_Profiles (Profiles : in out Pid_Profile_Record_List_4; Voltage_From_ADC : Boolean)
     with Post => (for all P of Profiles => Fixed_PID_Profile (P))
   is
   begin
      for I in Profiles'Range loop
         Fix_PID_Profile (Profiles (I), Voltage_From_ADC);
         pragma Loop_Invariant (for all K in Profiles'First .. I => Fixed_PID_Profile (Profiles (K)));
      end loop;
   end Fix_PID_Profiles;

   --  The gyro filter cutoffs within their limit and in order.
   procedure Fix_Gyro_Filters (G : in out Gyro_Config_Record)
     with Post => G.Gyro_Lpf1_Static_Hz <= LPF_Max_Hz and then G.Gyro_Lpf2_Static_Hz <= LPF_Max_Hz
                  and then (G.Gyro_Soft_Notch_Hz_1 = 0 or else G.Gyro_Soft_Notch_Cutoff_1 < G.Gyro_Soft_Notch_Hz_1)
                  and then (G.Gyro_Soft_Notch_Hz_2 = 0 or else G.Gyro_Soft_Notch_Cutoff_2 < G.Gyro_Soft_Notch_Hz_2)
                  and then G.Gyro_Lpf1_Dyn_Min_Hz <= G.Gyro_Lpf1_Dyn_Max_Hz
   is
   begin
      Limit_Filter (G.Gyro_Lpf1_Static_Hz, LPF_Max_Hz);
      Limit_Filter (G.Gyro_Lpf2_Static_Hz, LPF_Max_Hz);
      Limit_Filter (G.Gyro_Soft_Notch_Hz_1, LPF_Max_Hz);
      Limit_Filter (G.Gyro_Soft_Notch_Cutoff_1, 0);
      Limit_Filter (G.Gyro_Soft_Notch_Hz_2, LPF_Max_Hz);
      Limit_Filter (G.Gyro_Soft_Notch_Cutoff_2, 0);
      if G.Gyro_Soft_Notch_Cutoff_1 >= G.Gyro_Soft_Notch_Hz_1 then
         G.Gyro_Soft_Notch_Hz_1 := 0;
      end if;
      if G.Gyro_Soft_Notch_Cutoff_2 >= G.Gyro_Soft_Notch_Hz_2 then
         G.Gyro_Soft_Notch_Hz_2 := 0;
      end if;
      if G.Gyro_Lpf1_Dyn_Min_Hz > G.Gyro_Lpf1_Dyn_Max_Hz then
         G.Gyro_Lpf1_Dyn_Min_Hz := 0;
      end if;
   end Fix_Gyro_Filters;

   --  Bidirectional DShot below the overclock level runs at DShot300 and,
   --  above 4 kHz, every second gyro sample at most; then the motor update
   --  rate of the protocol holds back the continuous update rate, or slows
   --  the PID loop to a whole number of gyro samples.
   procedure Fix_Loop_Rate
     (Dev : in out Motor_Dev_Config_Record; Denom : in out Unsigned_8; Overclock : Unsigned_8; Rate : Gyro_Rate)
     with Pre => Rate > 0
   is
      Sampling_Time : constant Float := 1.0 / Float (Rate);
      Restriction   : Float;
   begin
      if Overclock < 2 and then Dev.Use_Dshot_Telemetry /= 0 then
         if Dev.Motor_Protocol = Protocol_DShot_600 then
            Dev.Motor_Protocol := Protocol_DShot_300;
         end if;
         if Rate > 4_000 then
            Denom := Unsigned_8'Max (2, Denom);
         end if;
      end if;
      case Dev.Motor_Protocol is
         when Protocol_PWM =>
            Restriction := 1.0 / Float (Brushless_PWM_Rate);
         when Protocol_Oneshot_125 =>
            Restriction := 0.000_5;
         when Protocol_Oneshot_42 =>
            Restriction := 0.000_1;
         when Protocol_DShot_150 =>
            Restriction := 0.000_250;
         when Protocol_DShot_300 =>
            Restriction := 0.000_1;
         when others =>
            Restriction := 0.000_031_25;
      end case;
      if Dev.Use_Continuous_Update /= 0 then
         if not Is_DShot (Dev.Motor_Protocol) and then Dev.Motor_Protocol /= Protocol_PWM then
            declare
               Max_ESC_Rate : constant Maths.Rounded_Integer := Maths.Round_Half_Even (1.0 / Restriction);
            begin
               if Max_ESC_Rate in 0 .. Integer (Dev.Motor_Pwm_Rate) - 1 then
                  Dev.Motor_Pwm_Rate := Unsigned_16 (Max_ESC_Rate);
               end if;
            end;
         end if;
      else
         declare
            PID_Looptime : constant Float := Sampling_Time * Float (Denom);
         begin
            if Dev.Use_Dshot_Telemetry /= 0 then
               Restriction := Restriction * 2.0;
            end if;
            if PID_Looptime < Restriction then
               declare
                  Ratio     : constant Float := Restriction / Sampling_Time;
                  Min_Denom : Unsigned_8 := Unsigned_8 (Float'Truncation (Ratio));
               begin
                  if Ratio > Float (Min_Denom) then
                     Min_Denom := Min_Denom + 1;
                  end if;
                  Min_Denom := Unsigned_8'Max (1, Unsigned_8'Min (Max_PID_Process_Denom, Min_Denom));
                  Denom := Unsigned_8'Max (Denom, Min_Denom);
               end;
            end if;
         end;
      end if;
   end Fix_Loop_Rate;

   --  Profile selections past their counts return to the first profile.
   procedure Fix_Profile_Selections (S : in out System_Config_Record) is
   begin
      if S.Active_Rate_Profile >= Control_Rate_Config_Record_List_4'Length then
         S.Active_Rate_Profile := 0;
      end if;
      if S.Pid_Profile_Index >= Pid_Profile_Record_List_4'Length then
         S.Pid_Profile_Index := 0;
      end if;
      if S.Active_Battery_Profile >= Battery_Profile_Record_List_3'Length then
         S.Active_Battery_Profile := 0;
      end if;
   end Fix_Profile_Selections;

   procedure Fix_Gyro (C : in out Configuration; Gyro_Sample_Rate_Hz : Gyro_Rate) is
   begin
      Fix_Gyro_Filters (C.Gyro_Config);
      if Gyro_Sample_Rate_Hz > 0 then
         Fix_Loop_Rate
           (C.Motor_Config.Dev, C.Pid_Config.Pid_Process_Denom, C.System_Config.Cpu_Overclock, Gyro_Sample_Rate_Hz);
      end if;
      Fix_Profile_Selections (C.System_Config);
      if C.Flight_Plan_Config.Waypoint_Count > C.Flight_Plan_Config.Waypoints'Length then
         C.Flight_Plan_Config.Waypoint_Count := 0;
      end if;
   end Fix_Gyro;

   --  A nonzero accelerometer zero marks the calibration as done.
   procedure Fix_Acc_Zero (Zero : in out Integer_16_List_4) is
   begin
      if Zero (0) /= 0 or else Zero (1) /= 0 or else Zero (2) /= 0 then
         Zero (3) := 1;
      end if;
   end Fix_Acc_Zero;

   --  A standard alignment's angles; the default and custom alignments keep
   --  theirs. Codes past the custom one wrap onto the eight standard ones.
   procedure Align_From_Standard (Angles : in out Integer_16_List_3; Alignment : Unsigned_8) is
      use Adaflight.Sensor_Alignment;
      A : Alignment_Angles;
   begin
      if Alignment /= 0 and then Alignment /= 9 then
         From_Standard (A, Standard_Alignment'Val ((Alignment - 1) mod 8 + 1));
         Angles := (A.Roll, A.Pitch, A.Yaw);
      end if;
   end Align_From_Standard;

   procedure Align_Gyros (Gyros : in out Gyro_Device_Config_Record_List_1) is
   begin
      for G of Gyros loop
         Align_From_Standard (G.Custom_Alignment, G.Alignment);
      end loop;
   end Align_Gyros;

   --  Every condition for the mode taken out, the later conditions moved up
   --  and the freed entries cleared.
   procedure Remove_Condition (Conditions : in out Mode_Activation_Condition_Record_List_20; Mode : Unsigned_8) is
      Last   : constant Natural := Conditions'Last;
      Offset : Natural range 0 .. Conditions'Length := 0;
   begin
      for I in Conditions'Range loop
         if Conditions (I).Mode_Id = Mode and then Offset = 0 then
            Offset := 1;
         end if;
         if Offset > 0 then
            while I + Offset <= Last and then Conditions (I + Offset).Mode_Id = Mode loop
               Offset := Offset + 1;
            end loop;
            if I + Offset <= Last then
               Conditions (I) := Conditions (I + Offset);
            else
               Conditions (I) :=
                 (Mode_Id => 0, Aux_Channel_Index => 0, Range_Value => (Start_Step => 0, End_Step => 0),
                  Mode_Logic => 0, Linked_To => 0);
            end if;
         end if;
      end loop;
   end Remove_Condition;

   function Is_Present (Conditions : Mode_Activation_Condition_Record_List_20; Mode : Unsigned_8) return Boolean is
     (for some M of Conditions =>
        M.Mode_Id = Mode and then (M.Range_Value.Start_Step < M.Range_Value.End_Step or else M.Linked_To /= 0));

   function Is_Linked (Conditions : Mode_Activation_Condition_Record_List_20; Mode : Unsigned_8) return Boolean is
     (for some M of Conditions => M.Mode_Id = Mode and then M.Linked_To /= 0);

   --  A linked condition for arming, or linked to a mode that is itself
   --  linked, is taken out with every condition for its mode.
   procedure Cut_Linked_Chains (Conditions : in out Mode_Activation_Condition_Record_List_20) is
   begin
      for I in Conditions'Range loop
         declare
            M : constant Mode_Activation_Condition_Record := Conditions (I);
         begin
            if M.Linked_To /= 0 and then (M.Mode_Id = Box_Arm or else Is_Linked (Conditions, M.Linked_To)) then
               Remove_Condition (Conditions, M.Mode_Id);
            end if;
         end;
      end loop;
   end Cut_Linked_Chains;

   --  One receiver feature at most: the serial receiver when none is set,
   --  and the first of PPM, MSP, serial, SPI and parallel PWM set clears
   --  the others.
   procedure Fix_Receiver_Features (Features : in out Unsigned_32; Runtime : in out Unsigned_32) is
      All_RX : constant Unsigned_32 :=
        Feature_RX_PPM or Feature_RX_UDP or Feature_RX_Serial or Feature_RX_Parallel_PWM or Feature_RX_MSP
        or Feature_RX_SPI;
   begin
      if (Features and (All_RX and not Feature_RX_UDP)) = 0 then
         Enable (Features, Runtime, Feature_RX_Serial);
      end if;
      if (Features and Feature_RX_PPM) /= 0 then
         Disable (Features, Runtime, All_RX and not Feature_RX_PPM);
      end if;
      if (Features and Feature_RX_MSP) /= 0 then
         Disable (Features, Runtime, All_RX and not Feature_RX_MSP);
      end if;
      if (Features and Feature_RX_Serial) /= 0 then
         Disable (Features, Runtime, All_RX and not Feature_RX_Serial);
      end if;
      if (Features and Feature_RX_SPI) /= 0 then
         Disable (Features, Runtime, All_RX and not Feature_RX_SPI);
      end if;
      if (Features and Feature_RX_Parallel_PWM) /= 0 then
         Disable (Features, Runtime, All_RX and not Feature_RX_Parallel_PWM);
      end if;
   end Fix_Receiver_Features;

   --  RSSI from the ADC takes no channel and no frame errors, and RSSI from
   --  a channel or a pulse receiver takes no frame errors.
   procedure Fix_RSSI (Rx : in out Rx_Config_Record; Features : Unsigned_32) is
   begin
      if (Features and Feature_RSSI_ADC) /= 0 then
         Rx.Rssi_Channel := 0;
         Rx.Rssi_Src_Frame_Errors := 0;
      elsif Rx.Rssi_Channel /= 0 or else (Features and (Feature_RX_PPM or Feature_RX_Parallel_PWM)) /= 0 then
         Rx.Rssi_Src_Frame_Errors := 0;
      end if;
   end Fix_RSSI;

   --  Without GPS, in 3D or on a fixed wing, the failsafe drops instead of
   --  rescuing and the GPS rescue mode's conditions are taken out.
   procedure Fix_GPS_Rescue
     (Features : Unsigned_32; Mixer_Mode : Unsigned_8; Failsafe : in out Failsafe_Config_Record;
      Conditions : in out Mode_Activation_Condition_Record_List_20)
   is
   begin
      if (Features and Feature_3D) /= 0 or else (Features and Feature_GPS) = 0
        or else Mixer_Mode in 8 | 14 | Mixer_Custom_Airplane
      then
         if Failsafe.Failsafe_Procedure = Failsafe_GPS_Rescue then
            Failsafe.Failsafe_Procedure := Failsafe_Drop_It;
         end if;
         if Failsafe.Failsafe_Procedure >= Failsafe_Count then
            Failsafe.Failsafe_Procedure := Failsafe_Drop_It;
         end if;
         if Is_Present (Conditions, Box_GPS_Rescue) then
            Remove_Condition (Conditions, Box_GPS_Rescue);
         end if;
      end if;
   end Fix_GPS_Rescue;

   --  ProShot with bidirectional telemetry leaves bit banging to the driver.
   procedure Fix_ProShot_Bitbang (Dev : in out Motor_Dev_Config_Record) is
   begin
      if Dev.Motor_Protocol = Protocol_ProShot_1000 and then Dev.Use_Dshot_Telemetry /= 0
        and then Dev.Use_Dshot_Bitbang = 1
      then
         Dev.Use_Dshot_Bitbang := 2;
      end if;
   end Fix_ProShot_Bitbang;

   --  The ADC reads battery voltage and current where they come from the ADC,
   --  and RSSI where the running features read it there or an FrSky D SPI
   --  receiver sends it.
   procedure Fix_ADC
     (ADC : in out Adc_Config_Record; Battery : Battery_Config_Record; Runtime : Unsigned_32;
      RX_SPI_Protocol : Unsigned_8)
   is
   begin
      ADC.Vbat.Enabled := Battery.Voltage_Meter_Source = 1;
      ADC.Current.Enabled := Battery.Current_Meter_Source = 1;
      ADC.Rssi.Enabled := (Runtime and Feature_RSSI_ADC) /= 0;
      ADC.Rssi.Enabled := ADC.Rssi.Enabled or else ((Runtime and Feature_RX_SPI) /= 0 and then RX_SPI_Protocol = 8);
   end Fix_ADC;

   --  Whether a soft serial port has a pin.
   function Soft_Serial_Pinned (Pins : Serial_Pin_Config_Record) return Boolean is
      Soft_Serial_First : constant := 6;
      Soft_Serial_Last  : constant Natural := Soft_Serial_First + Serial_Options.Soft_Serial_Ports - 1;
   begin
      for I in Soft_Serial_First .. Soft_Serial_Last loop
         if Pins.Io_Tag_Tx (I) /= 0 or else Pins.Io_Tag_Rx (I) /= 0 then
            return True;
         end if;
      end loop;
      return False;
   end Soft_Serial_Pinned;

   --  Features the build lacks are cleared, and an unconfigured board turns
   --  on telemetry, the OSD, the LED strip and, with a pin, soft serial.
   procedure Fix_Features
     (Features : in out Unsigned_32; Runtime : in out Unsigned_32; State : Unsigned_8; Pins : Serial_Pin_Config_Record)
   is
   begin
      Disable (Features, Runtime, not Supported_Features);
      if State = 0 then
         Enable
           (Features, Runtime,
            (Feature_Telemetry or Feature_OSD or Feature_LED_Strip
             or (if Soft_Serial_Pinned (Pins) then Feature_Soft_Serial else 0))
            and Supported_Features);
      end if;
   end Fix_Features;

   --  A beeper frequency without a timer, beeper and beacon flags past the
   --  allowed modes and a beacon tone past the five beacons are reset.
   procedure Fix_Beeper
     (Device : in out Beeper_Dev_Config_Record; Beeper : in out Beeper_Config_Record; Timers : Pin_Timers)
   is
   begin
      if Device.Frequency /= 0 and then Timers (Device.Io_Tag) = No_Timer then
         Device.Frequency := 0;
      end if;
      if (Beeper.Beeper_Off_Flags and not 16#7F_FFFF#) /= 0 then
         Beeper.Beeper_Off_Flags := 0;
      end if;
      if (Beeper.Dshot_Beacon_Off_Flags and not 16#202#) /= 0 then
         Beeper.Dshot_Beacon_Off_Flags := 16#202#;
      end if;
      if Beeper.Dshot_Beacon_Tone not in 1 .. 5 then
         Beeper.Dshot_Beacon_Tone := 1;
      end if;
   end Fix_Beeper;

   --  DShot runs without continuous update, and bidirectional DShot needs a
   --  DShot protocol and, without bit banging, neither burst DMA nor a motor
   --  on an N channel timer.
   procedure Fix_DShot (Dev : in out Motor_Dev_Config_Record; H : Hardware) is
      DShot          : constant Boolean := Is_DShot (Dev.Motor_Protocol);
      N_Channel_Used : Boolean := False;
   begin
      if DShot then
         Dev.Use_Continuous_Update := 0;
      end if;
      for I in 0 .. H.Motors - 1 loop
         if Dev.Io_Tags (I) /= 0 and then H.Timers (Dev.Io_Tags (I)) = N_Channel then
            N_Channel_Used := True;
            exit;
         end if;
      end loop;
      if (not DShot or else (Dev.Use_Dshot_Bitbang = 0 and then (Dev.Use_Burst_Dshot = 1 or else N_Channel_Used)))
        and then Dev.Use_Dshot_Telemetry /= 0
      then
         Dev.Use_Dshot_Telemetry := 0;
      end if;
   end Fix_DShot;

   --  The band, channel and power within the VTX table; a channel or band
   --  reset also resets a frequency the band and channel set.
   procedure Fix_VTX (V : in out Vtx_Settings_Config_Record; T : Vtx_Table_Config_Record) is
   begin
      if V.Channel > T.Channels then
         V.Channel := 0;
         if V.Band > 0 then
            V.Freq := 0;
         end if;
      end if;
      if V.Band > T.Bands then
         V.Band := 0;
         V.Freq := 0;
      end if;
      if V.Power > T.Power_Levels then
         V.Power := 0;
      end if;
   end Fix_VTX;

   --  The rates within their type's limits; a type past the limit table
   --  keeps its rates.
   procedure Fix_Rates (R : in out Control_Rate_Config_Record) is
      type Limits is record
         RC_Rate, Super_Rate, Expo : Unsigned_8;
      end record;
      Table : constant array (Unsigned_8 range 0 .. 4) of Limits :=
        ((255, 100, 100), (200, 255, 100), (255, 99, 100), (200, 200, 100), (255, 200, 100));
   begin
      if R.Rates_Type in Table'Range then
         for Axis in R.Rc_Rates'Range loop
            R.Rc_Rates (Axis) := Unsigned_8'Min (R.Rc_Rates (Axis), Table (R.Rates_Type).RC_Rate);
            R.Rates (Axis) := Unsigned_8'Min (R.Rates (Axis), Table (R.Rates_Type).Super_Rate);
            R.Rc_Expo (Axis) := Unsigned_8'Min (R.Rc_Expo (Axis), Table (R.Rates_Type).Expo);
         end loop;
      end if;
   end Fix_Rates;

   procedure Fix_Rate_Profiles (Profiles : in out Control_Rate_Config_Record_List_4) is
   begin
      for P of Profiles loop
         Fix_Rates (P);
      end loop;
   end Fix_Rate_Profiles;

   --  The override channels with no override condition, and an override
   --  condition's own channel, cleared from the override mask. An aux
   --  channel past bit 31 names no bit.
   procedure Fix_MSP_Override (Conditions : in out Mode_Activation_Condition_Record_List_20; Mask : in out Unsigned_32)
   is
      Non_Aux_Channels : constant := 4;
   begin
      if Mask = 0 then
         Remove_Condition (Conditions, Box_MSP_Override);
      end if;
      for M of Conditions loop
         if M.Mode_Id = Box_MSP_Override and then Natural (M.Aux_Channel_Index) + Non_Aux_Channels < 32 then
            declare
               Bit : constant Unsigned_32 := Shift_Left (1, Natural (M.Aux_Channel_Index) + Non_Aux_Channels);
            begin
               if (Bit and Mask) /= 0 then
                  Mask := Mask and not Bit;
               end if;
            end;
         end if;
      end loop;
   end Fix_MSP_Override;

   --  An order naming a motor past the last, or one motor twice, becomes
   --  the identity.
   procedure Fix_Output_Reordering (Order : in out Bytes_8) is
      Invalid : Boolean := False;
      Seen    : array (Order'Range) of Boolean := (others => False);
   begin
      for I in Order'Range loop
         if Order (I) > Unsigned_8 (Order'Last) then
            Invalid := True;
            exit;
         end if;
         pragma Loop_Invariant
           (not Invalid and then (for all J in Order'First .. I => Order (J) <= Unsigned_8 (Order'Last)));
      end loop;
      if not Invalid then
         for I in Order'Range loop
            if Seen (Natural (Order (I))) then
               Invalid := True;
               exit;
            end if;
            Seen (Natural (Order (I))) := True;
         end loop;
      end if;
      if Invalid then
         for I in Order'Range loop
            Order (I) := Unsigned_8 (I);
         end loop;
      end if;
   end Fix_Output_Reordering;

   --  Cell voltages out of order return to their defaults, a forced cell
   --  count past 24 to automatic and a consumption warning past 100 % to
   --  10 %.
   procedure Fix_Battery_Profile (B : in out Battery_Profile_Record)
     with Post => B.Vbatmincellvoltage < B.Vbatmaxcellvoltage
                  and then B.Vbatmincellvoltage <= B.Vbatwarningcellvoltage
                  and then B.Vbatwarningcellvoltage <= B.Vbatfullcellvoltage
                  and then B.Vbatfullcellvoltage <= B.Vbatmaxcellvoltage
                  and then B.Force_Battery_Cell_Count <= 24 and then B.Consumption_Warning_Percentage <= 100
   is
   begin
      if B.Vbatmincellvoltage >= B.Vbatmaxcellvoltage
        or else B.Vbatwarningcellvoltage < B.Vbatmincellvoltage
        or else B.Vbatwarningcellvoltage > B.Vbatmaxcellvoltage
        or else B.Vbatfullcellvoltage < B.Vbatwarningcellvoltage
        or else B.Vbatfullcellvoltage > B.Vbatmaxcellvoltage
      then
         B.Vbatmincellvoltage := 330;
         B.Vbatmaxcellvoltage := 430;
         B.Vbatwarningcellvoltage := 350;
         B.Vbatfullcellvoltage := 410;
      end if;
      if B.Force_Battery_Cell_Count > 24 then
         B.Force_Battery_Cell_Count := 0;
      end if;
      if B.Consumption_Warning_Percentage > 100 then
         B.Consumption_Warning_Percentage := 10;
      end if;
   end Fix_Battery_Profile;

   procedure Fix_Battery_Profiles (Profiles : in out Battery_Profile_Record_List_3) is
   begin
      for B of Profiles loop
         Fix_Battery_Profile (B);
      end loop;
   end Fix_Battery_Profiles;

   --  A timer counting from an unknown source or at an unknown precision
   --  returns to its default.
   procedure Fix_OSD_Timers (Timers : in out Unsigned_16_List_2) is
   begin
      for I in Timers'Range loop
         if (Timers (I) and 16#F#) >= 5 or else (Shift_Right (Timers (I), 4) and 16#F#) >= 3 then
            Timers (I) := 16#0A00# + Unsigned_16 (I);
         end if;
      end loop;
   end Fix_OSD_Timers;

   --  The OSD's MSP port when the OSD draws over MSP, else the first port
   --  but USB with an MSP VTX, else none.
   function MSP_Display_Port
     (Msp : Msp_Config_Record; Gps : Gps_Config_Record; Rx : Rx_Config_Record; Blackbox : Blackbox_Config_Record;
      ESC : Esc_Sensor_Config_Record; Device : Rcdevice_Config_Record; Gimbal : Gimbal_Track_Config_Record;
      VTX : Vtx_Settings_Config_Record; Rangefinder : Rangefinder_Config_Record; Flow : Opticalflow_Config_Record;
      OSD : Osd_Config_Record; Telemetry : Telemetry_Config_Record; Ports : Map.Port_List) return Integer_8
     with Pre => Ports'Length <= Map.Max_Ports
   is
      MSP_Device : constant Unsigned_8 := OSD_Task.Device_Kind'Pos (OSD_Task.MSP);
      A          : constant Map.Assignments :=
        Assignments_Of (Msp, Gps, Rx, Blackbox, ESC, Device, Gimbal, VTX, Rangefinder, Flow, OSD, Telemetry);
   begin
      if OSD.Display_Port_Device = MSP_Device and then OSD.Osd_Uart /= -1 then
         return OSD.Osd_Uart;
      end if;
      for P of Ports loop
         if P /= Map.USB_VCP and then (Map.Function_Mask (Serial_Options, A, P) and Map.Function_VTX_MSP) /= 0 then
            return Integer_8 (P);
         end if;
      end loop;
      return -1;
   end MSP_Display_Port;

   --  A flight log on an SD card that is off goes nowhere.
   procedure Fix_Blackbox (Blackbox : in out Blackbox_Config_Record; SD_Card_Mode : Unsigned_8) is
   begin
      if Blackbox.Device = 2 and then SD_Card_Mode = 0 then
         Blackbox.Device := 0;
      end if;
   end Fix_Blackbox;

   --  The ESC sensor feature needs a serial port.
   procedure Fix_ESC_Sensor (Uart : Integer_8; Features : in out Unsigned_32; Runtime : in out Unsigned_32) is
   begin
      if Uart = -1 then
         Disable (Features, Runtime, Feature_ESC_Sensor);
      end if;
   end Fix_ESC_Sensor;

   --  A gyro hardware filter past the four the gyros know returns to the
   --  normal one.
   procedure Fix_Hardware_LPF (Lpf : in out Unsigned_8) is
   begin
      if Lpf >= 4 then
         Lpf := 0;
      end if;
   end Fix_Hardware_LPF;

   ---------
   -- Fix --
   ---------

   procedure Fix
     (C : in out Configuration; H : Hardware; Ports : Serial_Feature_Map.Port_List;
      Runtime_Features : in out Unsigned_32; R : out Results)
     with SPARK_Mode => Off
   is
   begin
      R := (others => <>);
      Fix_Mixer_Mode (C.Mixer_Config.Mixer_Mode);
      Validate_Providers (C.Telemetry_Config.Providers);
      Fix_Serial
        (C.Msp_Config, C.Gps_Config, C.Rx_Config, C.Blackbox_Config, C.Esc_Sensor_Config, C.Rcdevice_Config,
         C.Gimbal_Track_Config, C.Vtx_Settings_Config, C.Rangefinder_Config, C.Opticalflow_Config, C.Osd_Config,
         C.Telemetry_Config, Ports);
      Fix_GPS_Port (C.Gps_Config, C.Feature_Config.Enabled_Features, Runtime_Features, R.Removed_GPS_Port);
      Fix_PID_Profiles (C.Pid_Profiles, C.Battery_Config.Voltage_Meter_Source = 1);
      Fix_Motor_Output (C.Motor_Config, C.Feature_Config.Enabled_Features, Runtime_Features);
      Fix_Gyro (C, H.Gyro_Sample_Rate_Hz);
      Align_From_Standard (C.Compass_Config.Mag_Custom_Alignment, C.Compass_Config.Mag_Alignment);
      Align_Gyros (C.Gyro_Device_Config);
      Fix_Acc_Zero (C.Accelerometer_Config.Acc_Zero);
      Fix_Receiver_Features (C.Feature_Config.Enabled_Features, Runtime_Features);
      Fix_RSSI (C.Rx_Config, C.Feature_Config.Enabled_Features);
      Fix_GPS_Rescue
        (C.Feature_Config.Enabled_Features, C.Mixer_Config.Mixer_Mode, C.Failsafe_Config, C.Mode_Activation_Conditions);
      Fix_ESC_Sensor (C.Esc_Sensor_Config.Esc_Sensor_Uart, C.Feature_Config.Enabled_Features, Runtime_Features);
      Cut_Linked_Chains (C.Mode_Activation_Conditions);
      Fix_ProShot_Bitbang (C.Motor_Config.Dev);
      Fix_ADC (C.Adc_Config, C.Battery_Config, Runtime_Features, C.Rx_Spi_Config.Rx_Spi_Protocol);
      Fix_Hardware_LPF (C.Gyro_Config.Gyro_Hardware_Lpf);
      Fix_Features
        (C.Feature_Config.Enabled_Features, Runtime_Features, C.System_Config.Configuration_State,
         C.Serial_Pin_Config);
      Fix_Beeper (C.Beeper_Dev_Config, C.Beeper_Config, H.Timers);
      Fix_DShot (C.Motor_Config.Dev, H);
      Fix_OSD_Timers (C.Osd_Config.Timers);
      Fix_VTX (C.Vtx_Settings_Config, C.Vtx_Table_Config);
      Fix_Rate_Profiles (C.Control_Rate_Profiles);
      Fix_MSP_Override (C.Mode_Activation_Conditions, C.Rx_Config.Msp_Override_Channels_Mask);
      Fix_Output_Reordering (C.Motor_Config.Dev.Motor_Output_Reordering);
      Fix_Battery_Profiles (C.Battery_Profiles);
      R.MSP_Display_Port :=
        MSP_Display_Port
          (C.Msp_Config, C.Gps_Config, C.Rx_Config, C.Blackbox_Config, C.Esc_Sensor_Config, C.Rcdevice_Config,
           C.Gimbal_Track_Config, C.Vtx_Settings_Config, C.Rangefinder_Config, C.Opticalflow_Config, C.Osd_Config,
           C.Telemetry_Config, Ports);
      Fix_Blackbox (C.Blackbox_Config, C.Sdcard_Config.Mode);
   end Fix;

end Adaflight.Config_Fix;
