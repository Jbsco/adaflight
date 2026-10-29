with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Source_Info;
with Interfaces; use Interfaces;
with Adaflight.Acc_Inflight;
with Adaflight.Accelerometer;
with Adaflight.Adjustments;
with Adaflight.Altitude_Hold;
with Adaflight.Arming;
with Adaflight.Attitude;
with Adaflight.Axes;
with Adaflight.Battery;
with Adaflight.Beeper;
with Adaflight.Blackbox;
with Adaflight.Blackbox_Header;
with Adaflight.Blackbox_Info;
with Adaflight.Board;
with Adaflight.Build_Features;
with Adaflight.Build_Options;
with Adaflight.Board_Info;
with Adaflight.Bytes;
with Adaflight.Clock;
with Adaflight.Config_Codec;
with Adaflight.Config_Fix;
with Adaflight.MSP_Allocation;
with Adaflight.DShot;
with Adaflight.DShot_Command;
with Adaflight.LED_Strip;
with Adaflight.LTM_Telemetry;
with Adaflight.MAVLink_Commands;
with Adaflight.MAVLink_Telemetry;
with Adaflight.Maths;
with Adaflight.Position_Control;
with Adaflight.Position_Estimator;
with Adaflight.Position_Hold;
with Adaflight.Position_Nav;
with Adaflight.ESC_Sensor;
with Adaflight.Config_Groups;
with Adaflight.Config_Reset;
with Adaflight.Config_Runtime;
with Adaflight.Config_Store;
with Adaflight.Core_Loop;
with Adaflight.CRSF_Display_Port;
with Adaflight.CRSF_Telemetry;
with Adaflight.Failsafe;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.GHST_Telemetry;
with Adaflight.IBus_Telemetry;
with Adaflight.Jeti_Telemetry;
with Adaflight.FAT;
with Adaflight.Flash_Device;
with Adaflight.Flight_Stats;
with Adaflight.Gimbal_Control;
with Adaflight.Gyro_Filters;
with Adaflight.Gyro_Selection;
with Adaflight.Internal_ADC;
with Adaflight.Mixer;
with Adaflight.Mixer_Init;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Views;
with Adaflight.MSP_Box;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_Motor_In;
with Adaflight.Modes;
with Adaflight.MSP_Out;
with Adaflight.MSP_Port;
with Adaflight.MSP_Processor;
with Adaflight.PID_Config;
with Adaflight.PID_Profile;
with Adaflight.Rates;
with Adaflight.Pins;
with Adaflight.RTC;
with Adaflight.PID_Controller;
with Adaflight.RC_Command;
with Adaflight.Receiver;
with Adaflight.RPM_Filter;
with Adaflight.RunCam_Device;
with Adaflight.RX_Task;
with Adaflight.Scheduler;
with Adaflight.Serial_Feature_Map;
with Adaflight.Servo_Mixer;
with Adaflight.STM32.ADC;
with Adaflight.STM32.Baro;
with Adaflight.STM32.I2C;
with Adaflight.STM32.Blackbox;
with Adaflight.STM32.Console;
with Adaflight.STM32.Control;
with Adaflight.STM32.DShot_Output;
with Adaflight.STM32.ESC_Sensor;
with Adaflight.STM32.Flash;
with Adaflight.STM32.Flash_Chip;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.FrSky_Hub;
with Adaflight.STM32.IBus;
with Adaflight.STM32.LED_Strip;
with Adaflight.STM32.LTM;
with Adaflight.STM32.SmartPort;
with Adaflight.STM32.MAVLink;
with Adaflight.STM32.Gimbal;
with Adaflight.STM32.GPS;
with Adaflight.GPS_Frames;
with Adaflight.GPS_Lap_Timer;
with Adaflight.GPS_Link;
with Adaflight.GPS_Rescue;
with Adaflight.STM32.MCU;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Gyro;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Passthrough;
with Adaflight.STM32.PINIO;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Rangefinder;
with Adaflight.STM32.RunCam;
with Adaflight.STM32.RTC;
with Adaflight.STM32.SD;
with Adaflight.SD_Card_Types;
with Adaflight.SmartAudio;
with Adaflight.SmartPort_Telemetry;
with Adaflight.STM32.Sound;
with Adaflight.STM32.Serial;
with Adaflight.STM32.SPI;
with Adaflight.STM32.USB;
with Adaflight.STM32.VTX;
with Adaflight.MSP_OSD_Out;
with Adaflight.OSD_Task;
with Adaflight.OSD_Render;
with Adaflight.STM32.Menu;
with Adaflight.STM32.OSD;
with Adaflight.STM32.OSD_Custom_Text;
with Adaflight.STM32.Time;
with Adaflight.STM32.USART;
with Adaflight.Stream_Buffers;
with Adaflight.Task_Functions;
with Adaflight.Task_Init;
with Adaflight.Vectors;
package body Adaflight.STM32.Flight is
   package CLI renames Adaflight.STM32.Console.CLI;
   package Terminal renames Adaflight.STM32.Console.Terminal;
   package MSP renames Adaflight.MSP_Processor;
   package Common renames Adaflight.MSP_Common_Out;
   package Scheduler renames Adaflight.Scheduler;
   use type MSP.Result;
   use type Adaflight.MSP_Port.Event;
   use type Scheduler.Task_Id;
   use type Adaflight.STM32.Gyro.Read_Mode;

   Baud       : constant := 115_200;
   Stack_Size : constant := 32_768;
   UART1_Id   : constant Adaflight.Serial_Feature_Map.Port_Id := 51;
   VCP_Id     : constant Adaflight.Serial_Feature_Map.Port_Id := 20;

   --  The identity the configurator reads: the firmware variant, the version
   --  as a year, month and patch with its text.
   Variant       : constant Common.Four_Letters := "ADFL";
   Version_Year  : constant := 2026;
   Version_Month : constant := 10;
   Version_Patch : constant := 0;
   Version_Text  : constant String := "0.1.0";

   UID : constant Adaflight.STM32.MCU.Identifier := Adaflight.STM32.MCU.UID;

   --  The failure codes the LED flashes: a missing gyro, a configuration
   --  store that could not be written, and a gyro whose initialization read
   --  failed.
   Failure_Missing_Acc          : constant := 1;
   Failure_Config_Store_Failure : constant := 5;
   Failure_Gyro_Init_Failed     : constant := 6;

   --  The board identifier a stored configuration must name.
   Board_Identifier : constant String := "F405";

   --  The scheduler starts after the data ready interrupts of the gyro's
   --  start have passed the layer's detection count.
   First_Read_Delay_Ms : constant := 250;

   --  The platform's floor on a rescheduled period.
   Delay_Limit_Us : constant Scheduler.Delay_Limit := 10;

   Blink    : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   --  The defaults of the board's hardware, which every reset of the
   --  configuration takes.
   Board_Hardware : constant Adaflight.Board_Info.Hardware_Defaults :=
     (Vbat             => (Adaflight.Board.ADC_VBAT_Tag /= 0, Adaflight.Board.ADC_VBAT_Tag),
      Current          => (Adaflight.Board.ADC_CURR_Tag /= 0, Adaflight.Board.ADC_CURR_Tag),
      RSSI             => (Adaflight.Board.ADC_RSSI_Tag /= 0, Adaflight.Board.ADC_RSSI_Tag),
      External1        => (Adaflight.Board.ADC_External1_Tag /= 0, Adaflight.Board.ADC_External1_Tag),
      Beeper_Tag       => Adaflight.Board.Beeper_Tag,
      Beeper_Inverted  => Adaflight.Board.Beeper_Inverted,
      Beeper_Frequency => Adaflight.Board.Beeper_PWM_Hz,
      Voltage_Source   => Adaflight.Board.Default_Voltage_Meter_Source,
      Current_Source   => Adaflight.Board.Default_Current_Meter_Source,
      Voltage_Scale    => Adaflight.Board.Default_Voltage_Meter_Scale,
      Current_Scale    => Adaflight.Board.Default_Current_Meter_Scale,
      OSD_CS_Tag       => Adaflight.Board.MAX7456_CS_Tag,
      OSD_SPI_Device   => Adaflight.Board.MAX7456_SPI_Device,
      SD_SPI_Device    => Adaflight.Board.SDCARD_SPI_Device,
      SD_CS_Tag        => Adaflight.Board.SDCARD_CS_Tag,
      SD_Detect_Tag    => Adaflight.Board.SDCARD_Detect_Tag,
      SD_Detect_Low    => Adaflight.Board.SDCARD_Detect_Low,
      Flash_SPI_Device => Adaflight.Board.FLASH_SPI_Device,
      Flash_CS_Tag     => Adaflight.Board.FLASH_CS_Tag,
      Baro_Bus_Type    => (if Adaflight.Board.Baro_SPI_Device /= 0 then 2
                           elsif Adaflight.Board.Baro_I2C_Device /= 0 then 1 else 0),
      Baro_I2C_Device  => (if Adaflight.Board.Baro_SPI_Device /= 0 then 0 else Adaflight.Board.Baro_I2C_Device),
      Baro_I2C_Address => 0,
      Baro_SPI_Device  => Adaflight.Board.Baro_SPI_Device,
      Baro_CS_Tag      => (if Adaflight.Board.Baro_SPI_Device /= 0 then Adaflight.Board.Baro_CS_Tag else 0),
      Baro_EOC_Tag     => Adaflight.Board.Baro_EOC_Tag,
      Baro_XCLR_Tag    => Adaflight.Board.Baro_XCLR_Tag,
      Baro_Hardware    => (if Adaflight.Board.Baro_SPI_Device /= 0 or else Adaflight.Board.Baro_I2C_Device /= 0
                           then 0 else 1),
      Blackbox_Device  => Adaflight.Board.Default_Blackbox_Device,
      PINIO_Tags       => (Adaflight.Board.PINIO1_Tag, Adaflight.Board.PINIO2_Tag, Adaflight.Board.PINIO3_Tag,
                           Adaflight.Board.PINIO4_Tag),
      PINIO_Configs    => (Adaflight.Board.PINIO1_Config, Adaflight.Board.PINIO2_Config,
                           Adaflight.Board.PINIO3_Config, Adaflight.Board.PINIO4_Config),
      PINIO_Boxes      => (Adaflight.Board.PINIO1_Box, Adaflight.Board.PINIO2_Box, Adaflight.Board.PINIO3_Box,
                           Adaflight.Board.PINIO4_Box),
      Motor_Tags       => (Adaflight.Board.MOTOR1_Tag, Adaflight.Board.MOTOR2_Tag, Adaflight.Board.MOTOR3_Tag,
                           Adaflight.Board.MOTOR4_Tag, Adaflight.Board.MOTOR5_Tag, Adaflight.Board.MOTOR6_Tag,
                           Adaflight.Board.MOTOR7_Tag, Adaflight.Board.MOTOR8_Tag),
      LED_Strip_Tag    => Adaflight.Board.LED_Strip_Tag,
      MSP_First_Port        => Adaflight.MSP_Allocation.USB_VCP_Port,
      MSP_UART              => Adaflight.Board.MSP_UART,
      MSP_Other_UART        => Adaflight.Board.Use_MSP_UART,
      MSP_Display_Port_UART => Adaflight.Board.MSP_Display_Port_UART);

   Board    : CLI.Board_State := (Hardware => Board_Hardware, others => <>);
   Config   : Adaflight.Config_Groups.Configuration := Adaflight.Config_Reset.Reset (Board);
   Sched    : Scheduler.State;
   Session  : Terminal.Session;
   Into     : CLI.Output;
   Changes  : CLI.Effects;
   --  The board's serial ports by identifier: the USB virtual serial port,
   --  then the UARTs the board has in order.
   function Board_Ports return CLI.Port_List is
      Set   : constant Adaflight.STM32.USART.Number_List := Adaflight.STM32.USART.Present_Set;
      Ports : CLI.Port_List (1 .. Set'Length + 1) := (others => VCP_Id);
   begin
      for I in Set'Range loop
         Ports (I + 1) := Adaflight.STM32.USART.Identifier (Set (I));
      end loop;
      return Ports;
   end Board_Ports;
   Ports    : constant CLI.Port_List := Board_Ports;
   Input    : Adaflight.Bytes.Byte_Array (0 .. 63);
   Count    : Natural;
   Now_Ms   : Unsigned_32;
   Links    : Adaflight.MSP_Control_In.Link_State;
   --  The ports that serve the MSP and the command line, as the MSP
   --  allocation opens them after the other serial functions, each with its
   --  serial line, its rate and duplex, its MSP framing, its bytes waiting and
   --  its reply port. The command line runs on the one it was entered from.
   subtype MSP_Line is Positive range 1 .. Adaflight.MSP_Allocation.Max_Ports;
   Line_Count  : Natural range 0 .. Adaflight.MSP_Allocation.Max_Ports := 0;
   Line_Serial : array (MSP_Line) of Adaflight.STM32.Serial.Line := (others => Adaflight.STM32.Serial.VCP);
   Line_Rate   : array (MSP_Line) of Positive := (others => Baud);
   Line_Half   : array (MSP_Line) of Boolean := (others => False);
   type Line_State is record
      Port    : Adaflight.MSP_Port.Port;
      Pending : Adaflight.Bytes.Byte_Array (0 .. 255) := (others => 0);
      Waiting : Natural := 0;
   end record;
   Lines    : array (MSP_Line) of Line_State;
   Replies  : array (MSP_Line) of Adaflight.STM32.Serial.Port;
   CLI_Line : MSP_Line := 1;
   use type Adaflight.STM32.Serial.Line;

   --  A serial line's port identifier.
   function Line_Id (S : Adaflight.STM32.Serial.Line) return Adaflight.Serial_Feature_Map.Port_Id is
     (if S = Adaflight.STM32.Serial.VCP then VCP_Id else 50 + Adaflight.STM32.Serial.Line'Pos (S));

   --  The serial line of one of the board's port identifiers.
   function Line_Of (Id : Adaflight.Serial_Feature_Map.Port_Id) return Adaflight.STM32.Serial.Line is
     (if Id in 51 .. 56 then Adaflight.STM32.Serial.Line'Val (Id - 50) else Adaflight.STM32.Serial.VCP);

   --  A serial line's UART, UART1 for the USB port, which has none.
   function UART_Of (S : Adaflight.STM32.Serial.Line) return Adaflight.STM32.USART.Number is
     (if S = Adaflight.STM32.Serial.VCP then Adaflight.STM32.USART.UART1
      else Adaflight.STM32.USART.Number'Val (Adaflight.STM32.Serial.Line'Pos (S) - 1));
   Consumed : Natural;
   Event    : Adaflight.MSP_Port.Event;
   Reply    : Adaflight.Bytes.Byte_Array (0 .. MSP.Max_Reply_Length - 1) := (others => 0);
   Stream   : Adaflight.Stream_Buffers.Stream;
   Result   : MSP.Result;
   Effects  : MSP.Effects;
   Frame    : Adaflight.MSP_Port.Frame_Buffer := (others => 0);
   Frame_Length : Positive := 1;
   Gyro_Report  : Adaflight.STM32.Gyro.Report;
   Selection    : Adaflight.Gyro_Selection.Result;
   --  The running feature mask, from the stored features at the load, and
   --  the hash of each group's stored bytes.
   Runtime_Features : Unsigned_32 := 0;
   --  The mode boxes the image offers, set at each load of the
   --  configuration and once the sensors and the mixer are known.
   Offered          : Adaflight.Modes.Mask := (others => False);
   RX_State         : Adaflight.RX_Task.State;
   Bat              : Adaflight.Battery.State;
   Beep             : Adaflight.Beeper.State;
   Bat_Settings     : Adaflight.Battery.Settings;
   Internal         : Adaflight.Internal_ADC.Sampler;
   Internal_Cal     : Adaflight.Internal_ADC.Calibration;
   Pilot_Facts      : Adaflight.STM32.Pilot.Facts;
   Adj_State        : Adaflight.Adjustments.State;
   Stats_Tracker    : Adaflight.Flight_Stats.Tracker;
   Stats_Save_Due   : Boolean := False;
   Stats_Save_At_Us : Unsigned_32 := 0;
   Adj_Ranges       : Adaflight.Adjustments.Ranges := (others => Adaflight.Adjustments.Unset);
   --  The attitude task's periods with the level modes on and off.
   Attitude_Period_Slow_Us : constant Scheduler.Time_Delta := 10_000;
   Attitude_Period_Fast_Us : Scheduler.Time_Delta := 2_000;

   procedure Apply (Step : Adaflight.Arming.Outputs);
   procedure Sync_Reasons;
   procedure Report_Battery;
   function Flight_Channels return Adaflight.RC_Command.Channel_Values;
   function Pos_Hold_Failure return Boolean;
   function Pos_Hold_Ready return Boolean;
   procedure Run_Rescue;
   --  The GPS rescue runs when its failsafe procedure or its mode box is
   --  configured.
   function Rescue_Configured return Boolean is
     (Adaflight.STM32.Pilot.Box_Configured (Adaflight.Modes.GPS_Rescue)
      or else Natural (Config.Failsafe_Config.Failsafe_Procedure)
              = Adaflight.Failsafe.Procedure_Kind'Pos (Adaflight.Failsafe.GPS_Rescue));
   Hashes           : Adaflight.Config_Store.Hash_List (1 .. Adaflight.Config_Codec.Group_Count) := (others => 0);
   --  The divisor of the accelerometer counts in the raw readings reply, by
   --  the count for one g.
   Acc_Scale    : constant Float :=
     (if Adaflight.STM32.Gyro.Acc_One_G > 512 * 4 then 8.0
      elsif Adaflight.STM32.Gyro.Acc_One_G > 512 * 2 then 4.0
      elsif Adaflight.STM32.Gyro.Acc_One_G >= 512 then 2.0
      else 1.0);

   --  The loop units: the scheduler's settings, the core loop's cadence and
   --  ratio, the gyro filters, the accelerometer with its in-flight
   --  calibration, and the attitude estimate.
   Sched_Settings : Scheduler.Settings;
   Cadence        : Adaflight.Core_Loop.Cadence;
   Loop_Ratio     : Adaflight.Core_Loop.Loop_Ratio := 1;
   Sample_Us      : Scheduler.Period_Us := 125;
   Gyro_Settings  : Adaflight.Gyro_Filters.Settings;
   Gyro_State     : Adaflight.Gyro_Filters.State;
   Acc_Settings   : Adaflight.Accelerometer.Settings;
   Acc_State      : Adaflight.Accelerometer.State;
   Acc_Cal        : Adaflight.Acc_Inflight.State;
   Att_Config     : Adaflight.Attitude.Config;
   Att_State      : Adaflight.Attitude.State;
   --  Whether the craft is upright: no accelerometer, or an established
   --  attitude tilted less than the small angle.
   function Upright return Boolean is
     (not Gyro_Report.Acc_Found
      or else (Att_State.Established and then Adaflight.Attitude.Cos_Tilt (Att_State) > Att_Config.Small_Angle_Cos));
   Pos_Settings   : Adaflight.Position_Estimator.Settings;
   Pos_State      : Adaflight.Position_Estimator.State;

   Alt_Hold_Settings : Adaflight.Altitude_Hold.Settings;
   Alt_Hold_State    : Adaflight.Altitude_Hold.State;
   Control_Settings  : Adaflight.Position_Control.Settings;
   Pos_Hold_Settings : Adaflight.Position_Hold.Settings;
   Pos_Hold_State    : Adaflight.Position_Hold.State;
   Navigator         : Adaflight.Position_Nav.Navigator;
   Rescue_Settings   : Adaflight.GPS_Rescue.Settings;
   Rescue_State      : Adaflight.GPS_Rescue.State;
   --  The GPS lap timer, the stamp of the last solution it took, and the
   --  solution time it measures laps on: the module's own, or the clock at
   --  the solution for an NMEA module, whose solutions carry no time.
   Lap               : Adaflight.GPS_Lap_Timer.Timer;
   Lap_Stamp         : Unsigned_16 := 0;
   --  The LED strip and its layout, evaluated again when a command or a
   --  message changes the LEDs; its settings come from the configuration on
   --  each task call.
   Strip             : Adaflight.LED_Strip.Strip;
   Strip_Layout      : Adaflight.LED_Strip.Layout;
   function Strip_Settings return Adaflight.LED_Strip.Settings is
     (Adaflight.Config_Runtime.LED_Strip_Settings_Of (Config.Led_Strip_Config, Config.Led_Strip_Status_Mode_Config));
   function Lap_Clock_Ms (G : Adaflight.STM32.GPS.Readings) return Unsigned_32 is
     (if Config.Gps_Config.Provider = Adaflight.GPS_Link.Provider'Pos (Adaflight.GPS_Link.NMEA) then G.Solution_Ms
      else G.Time_Ms);

   --  The displayed altitude to the nearest centimetre, and the climb rate
   --  in centimetres per second with its 10 cm/s deadband.
   function Estimated_Altitude_Cm return Integer_32 is
     (Integer_32 (Integer'Max (-600_000_000, Integer'Min
        (600_000_000, Adaflight.Position_Estimator.Estimated_Altitude_Cm (Pos_State)))));

   function Estimated_Vario return Integer_16 is
      Rate : constant Float := Float'Max (-1.0e6, Float'Min (1.0e6, Pos_State.Filtered_Derivative));
      V    : constant Integer_32 :=
        Adaflight.Maths.Apply_Deadband (Integer_32 (Adaflight.Maths.Round_Half_Even (Rate)), 10);
   begin
      return Integer_16 (Integer_32'Max (-32_768, Integer_32'Min (32_767, V)));
   end Estimated_Vario;

   --  Whether a telemetry stream holds a UART.
   function Telemetry_Holds (N : Adaflight.STM32.USART.Number) return Boolean is
     (Adaflight.STM32.FrSky_Hub.Holds (N) or else Adaflight.STM32.SmartPort.Holds (N)
      or else (Adaflight.Build_Features.LTM_Telemetry and then Adaflight.STM32.LTM.Holds (N))
      or else (Adaflight.Build_Features.MAVLink_Telemetry and then Adaflight.STM32.MAVLink.Holds (N))
      or else (Adaflight.Build_Features.IBus_Telemetry and then Adaflight.STM32.IBus.Holds (N)));

   --  Whether one of the functions that open their ports before the MSP holds
   --  a UART.
   function Held_Before_MSP (N : Adaflight.STM32.USART.Number) return Boolean is
     (Adaflight.STM32.Rangefinder.Holds (N) or else Adaflight.STM32.Radio.Holds (N)
      or else Adaflight.STM32.GPS.Holds (N) or else Adaflight.STM32.OSD_Custom_Text.Holds (N)
      or else Adaflight.STM32.ESC_Sensor.Holds (N) or else Adaflight.STM32.Blackbox.Holds (N)
      or else Adaflight.STM32.VTX.Holds (N)
      or else (Adaflight.Build_Features.Gimbal and then Adaflight.STM32.Gimbal.Holds (N))
      or else Adaflight.STM32.RunCam.Holds (N));

   function Text (S : String) return Common.Text is
      T : Common.Text;
   begin
      T.Length := Natural'Min (S'Length, Common.Max_Text);
      T.Data (1 .. T.Length) := S (S'First .. S'First + T.Length - 1);
      return T;
   end Text;

   package Build renames Adaflight.Build_Options;

   --  The build options the image reports: the receivers, the telemetry,
   --  the features and the motor protocols the board drives, those of the
   --  features the build leaves out off.
   Image_Options : constant Build.List := Build.In_Order
     ((Build.Serial_RX_CRSF | Build.Serial_RX_FPORT | Build.Serial_RX_GHST | Build.Serial_RX_IBus
       | Build.Serial_RX_SBUS | Build.Serial_RX_Spektrum | Build.Serial_RX_XBus => True,
       Build.Serial_RX_Jeti_EX_Bus => Adaflight.Build_Features.Jeti_EX_Bus,
       Build.Serial_RX_SUMD => Adaflight.Build_Features.SUMD,
       Build.Telemetry_FrSky_Hub | Build.Telemetry_SmartPort => True,
       Build.Telemetry_IBus_Extended => Adaflight.Build_Features.IBus_Telemetry,
       Build.Telemetry_LTM => Adaflight.Build_Features.LTM_Telemetry,
       Build.Telemetry_MAVLink => Adaflight.Build_Features.MAVLink_Telemetry,
       Build.Altitude_Hold | Build.Chirp | Build.GPS | Build.LED_Strip | Build.OSD_SD | Build.OSD_HD | Build.PINIO
       | Build.Position_Hold | Build.Servos | Build.VTX => True,
       Build.Rangefinder => Adaflight.Build_Features.Rangefinder,
       Build.Brushed | Build.DShot | Build.MultiShot | Build.OneShot | Build.PWM_Output => True,
       others => False));

   --  What the common replies read beside the configuration: the firmware
   --  identity, the board, no meter readings yet, the beeper and the OSD chip
   --  built in.
   function Common_Snapshot return Common.Snapshot is
      V : Common.Snapshot;
   begin
      V.Firmware.Variant := Variant;
      V.Firmware.Year := Version_Year;
      V.Firmware.Month := Version_Month;
      V.Firmware.Patch := Version_Patch;
      V.Firmware.Version := Text (Version_Text);
      V.Firmware.MCU_Name := Text (Adaflight.Board.MCU_Name);
      V.Firmware.Build_Date := GNAT.Source_Info.Compilation_Date;
      V.Firmware.Build_Time := GNAT.Source_Info.Compilation_Time;
      V.Firmware.Revision := "0000000";
      V.Firmware.UID := (UID (1), UID (2), UID (3));
      V.Firmware.Options := Common.Build_Options (Image_Options.Numbers);
      V.Firmware.Option_Count := Image_Options.Length;
      for K in V.Board.Identifier'Range loop
         V.Board.Identifier (K) := Character'Val (Config.System_Config.Board_Identifier (K - 1));
      end loop;
      V.Board.MAX7456 := True;
      V.Board.Target_Name := Text (Adaflight.Board.MCU_Name);
      V.Board.Board_Info := True;
      V.Board.Board_Name := Text (Adaflight.Board.Board_Name);
      V.Board.Manufacturer := Text (Adaflight.Board.Manufacturer_ID);
      V.Board.Configuration_State := Config.System_Config.Configuration_State;
      V.Board.Motor_Protocol_Disabled := Config.Motor_Config.Dev.Motor_Protocol = 0;
      V.Beeper := True;
      V.Meters.Virtual := True;
      V.OSD := True;
      return V;
   end Common_Snapshot;

   Ctx : MSP.Context;

   --  The PID loop's time, which the log's intervals and the replies read.
   Loop_Time_Us : Adaflight.Blackbox.Loop_Time_Us := 125;

   function Log_Text (S : String) return Adaflight.Blackbox_Header.Text is
      T : Adaflight.Blackbox_Header.Text;
   begin
      T.Length := Natural'Min (S'Length, Adaflight.Blackbox_Header.Text_Max);
      T.Data (1 .. T.Length) := S (S'First .. S'First + T.Length - 1);
      return T;
   end Log_Text;

   --  A 32-bit word as the log prints it.
   function Log_Word (X : Unsigned_32) return Integer_32 is
     (if X >= 2 ** 31 then Integer_32 (Integer_64 (X) - 2 ** 32) else Integer_32 (X));

   --  The header's facts outside the stored configuration: the recorder's
   --  intervals and battery reference come from the recorder itself.
   function Log_Facts return Adaflight.Blackbox_Info.Facts is
      F : Adaflight.Blackbox_Info.Facts;
   begin
      F.Motor_Output_Low := Integer_32 (Float'Rounding (Adaflight.STM32.Control.Output_Low));
      F.Motor_Output_High := Integer_32 (Float'Rounding (Adaflight.STM32.Control.Output_High));
      F.Acc_1G := Integer_32 (Adaflight.STM32.Gyro.Acc_One_G);
      F.Loop_Time := Integer_32 (Loop_Time_Us);
      F.PID_Process_Denom := Integer_32 (Loop_Ratio);
      F.DShot_Telemetry := False;
      F.RC_Setpoint_Cutoff := Integer_32 (Config.Rx_Config.Rc_Smoothing_Setpoint_Cutoff);
      F.RC_Throttle_Cutoff := Integer_32 (Config.Rx_Config.Rc_Smoothing_Throttle_Cutoff);
      F.RC_Debug_Axis := Integer_32 (Config.Rx_Config.Rc_Smoothing_Debug_Axis);
      F.RC_Setpoint_Cutoff_Hz := Integer_32 (Adaflight.STM32.Pilot.Setpoint_Cutoff_Hz);
      F.RC_Throttle_Cutoff_Hz := Integer_32 (Adaflight.STM32.Pilot.Throttle_Cutoff_Hz);
      F.RX_Rate_Hz := Integer_32 (Float'Rounding (Adaflight.STM32.Pilot.RX_Rate_Hz));
      F.Debug_Mode := Integer_32 (Config.System_Config.Debug_Mode);
      F.Device_UID_0 := Log_Word (UID (1));
      F.Device_UID_1 := Log_Word (UID (2));
      F.Device_UID_2 := Log_Word (UID (3));
      F.Firmware_Type := Log_Text ("Adaflight");
      F.Firmware_Name := Log_Text ("Adaflight");
      F.Firmware_Version := Log_Text (Version_Text);
      F.Git_Revision := Log_Text ("0000000");
      F.Target_Name := Log_Text (Adaflight.Board.MCU_Name);
      F.Build_Date := Log_Text (GNAT.Source_Info.Compilation_Date);
      F.Build_Time := Log_Text (GNAT.Source_Info.Compilation_Time);
      F.Manufacturer_Id := Log_Text (Adaflight.Board.Manufacturer_ID);
      F.Board_Name := Log_Text (Adaflight.Board.Board_Name);
      F.Start_Date_Time := Log_Text (Adaflight.STM32.RTC.Start_Text);
      return F;
   end Log_Facts;

   Env : CLI.Environment :=
     (Navigation      => <>,
      Firmware        => CLI.To_Identity ("Adaflight"),
      Target          => CLI.To_Identity (Adaflight.Board.Board_Name),
      Version         => CLI.To_Identity (Version_Text),
      Build_Date      => CLI.To_Identity (GNAT.Source_Info.Compilation_Date),
      Build_Time      => CLI.To_Identity (GNAT.Source_Info.Compilation_Time),
      Revision        => CLI.To_Identity ("0000000"),
      MCU_Id          => (UID (1), UID (2), UID (3)),
      Now_Us          => 0,
      Debug_Mode      => 0,
      VTX_Present     => False,
      VTX_Power       => <>,
      Smoothing       => <>,
      Motors          => 0,
      Motor_Device    => Adaflight.MSP_Motor_In.No_Device,
      Three_D         => False,
      Receiver_Source => Adaflight.Receiver.None,
      Serial_Protocol => 0,
      DShot_Telemetry => <>,
      SD_Card         => <>,
      Flash           => <>,
      MSC_Ready       => False,
      DShot_Protocol  => False,
      ESC_Sensor      => False,
      Build_Options   => CLI.Build_Option_List (Image_Options.Numbers),
      Option_Count    => Image_Options.Length,
      Soft_Serial     => False,
      Serial_Ports    => <>,
      CLI_Port        => 20,
      Gyro_Positions  => 1,
      Gyros_Enabled   => 0,
      Gyros           => <>,
      Acc             => <>,
      Baro            => <>,
      Mag             => <>,
      Raw_Gyro_ICM456 => False,
      Interactive     => True,
      DMA_Motors      => <>,
      Rangefinder     => <>,
      Optical_Flow    => <>,
      Pitot           => <>,
      Acc_Revision    => 0,
      GPS_Enabled     => False,
      GPS             => <>,
      Status          => (MCU_Name      => CLI.To_Identity (Adaflight.Board.MCU_Name),
                          Core_Clock_Hz => Adaflight.STM32.Time.Core_Clock_Hz,
                          Clock_Sources => True,
                          System_Source => 2,
                          PLL_Source    => 1,
                          Internal_ADC  => True,
                          Vref_Mv       => 3300,
                          Core_Temp_C   => 0,
                          Stack_Total   => Stack_Size,
                          Stack_High    => 16#2002_0000#,
                          others        => <>));

   procedure Reset renames Adaflight.STM32.MCU.Reset;

   --  Count flashes of the LED from off, each on and off for the duration.
   procedure Flash (Count : Natural; Duration_Ms : Natural) is
   begin
      Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
      for I in 1 .. Count loop
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Adaflight.STM32.Time.Delay_Ms (Duration_Ms);
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Adaflight.STM32.Time.Delay_Ms (Duration_Ms);
      end loop;
   end Flash;

   --  The failure indication: five short flashes, a pause, the code as long
   --  flashes and a second's pause, repeated.
   procedure Indicate_Failure (Code : Natural; Repeats : Natural) is
   begin
      for I in 1 .. Repeats loop
         Flash (5, 50);
         Adaflight.STM32.Time.Delay_Ms (500);
         Flash (Code + 1, 250);
         Adaflight.STM32.Time.Delay_Ms (1000);
      end loop;
   end Indicate_Failure;

   --  The configuration's checks over the hardware the board knows: the
   --  gyro's sample rate once it runs, no motors and no timers yet.
   procedure Fix_Configuration is
      Hardware : constant Adaflight.Config_Fix.Hardware :=
        (Gyro_Sample_Rate_Hz => Ctx.Gyro_Sample_Rate_Hz, others => <>);
      Results  : Adaflight.Config_Fix.Results;
   begin
      Adaflight.Config_Fix.Fix (Config, Hardware, Ports, Runtime_Features, Results);
   end Fix_Configuration;

   --  Whether the stored configuration names this board: the identifier's
   --  characters, ASCII letters compared in upper case, and the zero after
   --  them.
   function Board_Matches return Boolean is
      Stored : String (1 .. Board_Identifier'Length);
   begin
      for I in Stored'Range loop
         Stored (I) := Character'Val (Config.System_Config.Board_Identifier (I - 1));
         if Stored (I) in 'a' .. 'z' then
            Stored (I) := Character'Val (Character'Pos (Stored (I)) - 32);
         end if;
      end loop;
      return Stored = Board_Identifier and then Config.System_Config.Board_Identifier (Board_Identifier'Length) = 0;
   end Board_Matches;

   --  The configuration written to the store after its checks: the region
   --  as it reads, the image of every group when any changed, programmed
   --  and checked back, in up to three attempts; a store that still fails
   --  flashes its code and resets.
   procedure Write_Configuration is
      Data    : Adaflight.Config_Codec.Data;
      Image   : Adaflight.Bytes.Byte_Array (Adaflight.STM32.Flash.Config'Range);
      Written : Boolean;
      Fits    : Boolean;
      OK      : Boolean;
      Valid   : Boolean;
      Size    : Natural;
   begin
      Adj_State.Config_Dirty := False;
      Fix_Configuration;
      Adaflight.Config_Codec.Encode (Config, Data);
      for Attempt in 1 .. 3 loop
         Image := Adaflight.STM32.Flash.Config;
         Adaflight.Config_Store.Save (Adaflight.Config_Codec.Registry, Data, Hashes, Image, Written, Fits);
         if not Written then
            return;
         end if;
         Adaflight.Config_Store.Check_Structure (Image, Valid, Size);
         Adaflight.STM32.Flash.Write (Image (0 .. Size - 1), OK);
         Adaflight.Config_Store.Check_Structure (Adaflight.STM32.Flash.Config, Valid, Size);
         if OK and then Valid and then Adaflight.Config_Store.Version_Valid (Adaflight.STM32.Flash.Config) then
            return;
         end if;
      end loop;
      Indicate_Failure (Failure_Config_Store_Failure, 10);
      Reset;
   end Write_Configuration;

   --  The mode boxes the image offers: those always offered, those of the
   --  features running, of the accelerometer, of the GPS feature, of the
   --  mixer and of a DShot motor protocol, the user boxes a PINIO output
   --  watches, and the MSP override when it names channels. The build holds
   --  the acro trainer, the flight plan, the camera control, the video
   --  transmitter control, PID audio, launch control, the lap timer and the
   --  chirp, and no magnetometer.
   function Available_Boxes return Adaflight.Modes.Mask is
      use type Adaflight.Mixer_Init.Mixer_Mode;
      Servo_Tilt : constant Unsigned_32 := 16#0000_0020#;
      No_Box     : constant Unsigned_8 := 255;
      M          : Adaflight.Modes.Mask := (others => False);
      Mixer      : Adaflight.Mixer_Init.Mixer_Mode := Adaflight.Mixer_Init.Quad_X;
      Found      : Boolean;
      Watched    : Adaflight.Modes.Box;
      function On (Feature : Unsigned_32) return Boolean is ((Runtime_Features and Feature) /= 0);
   begin
      if Config.Mixer_Config.Mixer_Mode in
           1 .. Adaflight.Mixer_Init.Mixer_Mode'Pos (Adaflight.Mixer_Init.Mixer_Mode'Last) + 1
      then
         Mixer := Adaflight.Mixer_Init.Mixer_Mode'Val (Config.Mixer_Config.Mixer_Mode - 1);
      end if;
      M (Adaflight.Modes.Arm) := True;
      M (Adaflight.Modes.Prearm) := True;
      M (Adaflight.Modes.Airmode) := not On (Adaflight.Config_Fix.Feature_Airmode);
      M (Adaflight.Modes.Anti_Gravity) :=
        (for some P of Config.Pid_Profiles => P.Anti_Gravity_Gain /= 0)
        and then not On (Adaflight.Config_Fix.Feature_Anti_Gravity);
      if Gyro_Report.Acc_Found then
         M (Adaflight.Modes.Angle) := True;
         M (Adaflight.Modes.Horizon) := True;
         M (Adaflight.Modes.Alt_Hold) := True;
         M (Adaflight.Modes.Pos_Hold) := True;
         M (Adaflight.Modes.Headfree) := True;
         M (Adaflight.Modes.Head_Adj) := True;
         M (Adaflight.Modes.FPV_Angle_Mix) := True;
         M (Adaflight.Modes.Calib) := On (Adaflight.Config_Fix.Feature_Inflight_Acc_Cal);
         M (Adaflight.Modes.Acro_Trainer) := True;
      end if;
      if On (Adaflight.Config_Fix.Feature_GPS) then
         M (Adaflight.Modes.GPS_Rescue) :=
           not On (Adaflight.Config_Fix.Feature_3D)
           and then not Adaflight.Mixer_Init.Is_Fixed_Wing (Adaflight.STM32.Pilot.Mixer_Mode);
         M (Adaflight.Modes.Beep_GPS_Count) := True;
      end if;
      M (Adaflight.Modes.Autopilot) := True;
      M (Adaflight.Modes.WP_Capture) := True;
      M (Adaflight.Modes.Failsafe) := True;
      M (Adaflight.Modes.Passthru) := Adaflight.Mixer_Init.Is_Fixed_Wing (Mixer);
      M (Adaflight.Modes.Beeper_On) := True;
      M (Adaflight.Modes.Beeper_Mute) := True;
      M (Adaflight.Modes.LED_Low) := On (Adaflight.Config_Fix.Feature_LED_Strip);
      M (Adaflight.Modes.Blackbox) := True;
      M (Adaflight.Modes.Blackbox_Erase) := True;
      M (Adaflight.Modes.Three_D) := On (Adaflight.Config_Fix.Feature_3D);
      M (Adaflight.Modes.Crash_Flip) := Config.Motor_Config.Dev.Motor_Protocol in 5 .. 8;
      M (Adaflight.Modes.Cam_Stab) := On (Servo_Tilt);
      M (Adaflight.Modes.OSD) := True;
      M (Adaflight.Modes.Telemetry) := On (Adaflight.Config_Fix.Feature_Telemetry);
      if Mixer = Adaflight.Mixer_Init.Custom_Airplane then
         M (Adaflight.Modes.Servo_1) := True;
         M (Adaflight.Modes.Servo_2) := True;
         M (Adaflight.Modes.Servo_3) := True;
      end if;
      M (Adaflight.Modes.Camera_1) := True;
      M (Adaflight.Modes.Camera_2) := True;
      M (Adaflight.Modes.Camera_3) := True;
      M (Adaflight.Modes.VTX_Pit_Mode) := True;
      M (Adaflight.Modes.VTX_Control_Disable) := True;
      M (Adaflight.Modes.Paralyze) := True;
      for Id of Config.Pinio_Box_Config.Permanent_Id loop
         if Id /= No_Box then
            Adaflight.MSP_Box.Find_By_Permanent_Id (Id, Found, Watched);
            if Found and then Watched in Adaflight.Modes.User_1 .. Adaflight.Modes.User_4 then
               M (Watched) := True;
            end if;
         end if;
      end loop;
      M (Adaflight.Modes.PID_Audio) := True;
      M (Adaflight.Modes.Launch_Control) := True;
      M (Adaflight.Modes.MSP_Override) := Config.Rx_Config.Msp_Override_Channels_Mask /= 0;
      M (Adaflight.Modes.Stick_Command_Disable) := True;
      M (Adaflight.Modes.Ready) := True;
      M (Adaflight.Modes.Lap_Timer_Reset) := True;
      M (Adaflight.Modes.Chirp) := True;
      return M;
   end Available_Boxes;

   --  The stored configuration loaded: every group from its defaults and
   --  its stored bytes, the running features, the checks, the board's
   --  information taken in, and the mode boxes offered; Success says the
   --  image held every group.
   procedure Load_Configuration (Success : out Boolean) is
      Defaults : Adaflight.Config_Codec.Data;
      Data     : Adaflight.Config_Codec.Data;
   begin
      Adaflight.Config_Codec.Encode (Adaflight.Config_Reset.Reset (Board), Defaults);
      Adaflight.Config_Store.Load
        (Adaflight.STM32.Flash.Config, Adaflight.Config_Codec.Registry, Defaults, Data, Hashes, Success);
      Adaflight.Config_Codec.Decode (Data, Config);
      Runtime_Features := Config.Feature_Config.Enabled_Features;
      Fix_Configuration;
      Adaflight.Board_Info.Init (Board, Config);
      Offered := Available_Boxes;
   end Load_Configuration;

   --  The configuration reset to its defaults, written and read back.
   procedure Reset_Configuration is
      Unused_Success : Boolean;
   begin
      Config := Adaflight.Config_Reset.Reset (Board);
      Write_Configuration;
      Load_Configuration (Unused_Success);
   end Reset_Configuration;

   --  The configuration at boot: a region without a valid structure, a
   --  load that missed a group, a stored version other than the core's, or
   --  another board's identifier reset the store.
   procedure Init_Configuration is
      Valid   : Boolean;
      Size    : Natural;
      Success : Boolean;
   begin
      Adaflight.Config_Store.Check_Structure (Adaflight.STM32.Flash.Config, Valid, Size);
      if not Valid then
         Reset_Configuration;
      end if;
      Load_Configuration (Success);
      if not Success or else not Adaflight.Config_Store.Version_Valid (Adaflight.STM32.Flash.Config)
        or else not Board_Matches
      then
         Reset_Configuration;
      end if;
   end Init_Configuration;

   --  The gyro's interrupt mode as the status report names it.
   function Gyro_Mode return CLI.Gyro_Mode is
     (case Adaflight.STM32.Gyro.Mode is
         when Adaflight.STM32.Gyro.Interrupt_Init => CLI.Interrupt_Init,
         when Adaflight.STM32.Gyro.Interrupt_DMA  => CLI.Interrupt_DMA,
         when Adaflight.STM32.Gyro.Interrupt      => CLI.Interrupt,
         when Adaflight.STM32.Gyro.No_Interrupt   => CLI.No_Interrupt);

   --  The gyro's start: the bus, the detection and initialization, the
   --  selection over the one position, the configuration's gyro checks, and
   --  what the MSP replies and the status report say about the sensors. A
   --  missing gyro flashes its code on a configured board and holds arming;
   --  a failed initialization flashes its code and resets.
   --  The SPI buses with their devices' select pins held first: the OSD
   --  chip's as the configuration names it.
   procedure Start_Buses is
   begin
      Adaflight.STM32.OSD.Preinit (Config);
      Adaflight.STM32.SD.Preinit (Config);
      Adaflight.STM32.Flash_Chip.Preinit (Config);
      if Adaflight.Board.Has_I2C1 then
         Adaflight.STM32.I2C.Init (Adaflight.STM32.I2C.I2C1, Adaflight.Board.I2C1_SCL_Pin, Adaflight.Board.I2C1_SDA_Pin);
      end if;
      if Adaflight.Board.Has_I2C2 then
         Adaflight.STM32.I2C.Init (Adaflight.STM32.I2C.I2C2, Adaflight.Board.I2C2_SCL_Pin, Adaflight.Board.I2C2_SDA_Pin);
      end if;
      if Adaflight.Board.Has_I2C3 then
         Adaflight.STM32.I2C.Init (Adaflight.STM32.I2C.I2C3, Adaflight.Board.I2C3_SCL_Pin, Adaflight.Board.I2C3_SDA_Pin);
      end if;
      if Adaflight.Board.Has_I2C4 then
         Adaflight.STM32.I2C.Init (Adaflight.STM32.I2C.I2C4, Adaflight.Board.I2C4_SCL_Pin, Adaflight.Board.I2C4_SDA_Pin);
      end if;
      if Adaflight.Board.Has_SPI1 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI1, Adaflight.Board.SPI1_SCK_Pin, Adaflight.Board.SPI1_SDI_Pin,
                                   Adaflight.Board.SPI1_SDO_Pin);
      end if;
      if Adaflight.Board.Has_SPI2 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI2, Adaflight.Board.SPI2_SCK_Pin, Adaflight.Board.SPI2_SDI_Pin,
                                   Adaflight.Board.SPI2_SDO_Pin);
      end if;
      if Adaflight.Board.Has_SPI3 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI3, Adaflight.Board.SPI3_SCK_Pin, Adaflight.Board.SPI3_SDI_Pin,
                                   Adaflight.Board.SPI3_SDO_Pin);
      end if;
      if Adaflight.Board.Has_SPI4 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI4, Adaflight.Board.SPI4_SCK_Pin, Adaflight.Board.SPI4_SDI_Pin,
                                   Adaflight.Board.SPI4_SDO_Pin);
      end if;
      if Adaflight.Board.Has_SPI5 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI5, Adaflight.Board.SPI5_SCK_Pin, Adaflight.Board.SPI5_SDI_Pin,
                                   Adaflight.Board.SPI5_SDO_Pin);
      end if;
      if Adaflight.Board.Has_SPI6 then
         Adaflight.STM32.SPI.Init (Adaflight.STM32.SPI.SPI6, Adaflight.Board.SPI6_SCK_Pin, Adaflight.Board.SPI6_SDI_Pin,
                                   Adaflight.Board.SPI6_SDO_Pin);
      end if;
      Adaflight.STM32.Flash_Chip.Init (Config);
      Adaflight.STM32.SD.Init (Config);
   end Start_Buses;

   --  The OSD display with the OSD feature on; no display started turns the
   --  feature off until the next start.
   procedure Start_OSD is
      Disable : Boolean;
   begin
      Adaflight.STM32.OSD.Init (Config, (Runtime_Features and Adaflight.Config_Fix.Feature_OSD) /= 0, Disable);
      if Disable then
         Runtime_Features := Runtime_Features and not Adaflight.Config_Fix.Feature_OSD;
      end if;
      Adaflight.STM32.OSD.Configure (Config, Version_Text);
      if Adaflight.Build_Features.Menus then
         declare
            Columns, Rows : Unsigned_8;
         begin
            Adaflight.STM32.OSD.Dimensions (Columns, Rows);
            Adaflight.STM32.Menu.Init
              (Version_Text, Adaflight.Board.MCU_Name, Adaflight.Board.Board_Name, Adaflight.Board.Manufacturer_ID,
               Adaflight.STM32.OSD.Port_Present, Columns, Rows);
         end;
      end if;
   end Start_OSD;

   procedure Start_Gyro is
      Inputs : Adaflight.Gyro_Selection.Inputs;
      Rate   : Adaflight.Config_Fix.Gyro_Rate;
      Bus    : constant CLI.Device_Bus := (Kind => CLI.SPI_Bus, Number => 1, Address => 0);
   begin
      Adaflight.STM32.Gyro.Start (Config.Gyro_Config.Gyro_Hardware_Lpf, Config.Gyro_Config.Gyro_High_Fsr /= 0,
                                  Config.Accelerometer_Config.Acc_Hardware, Gyro_Report);
      if Gyro_Report.Init_Failed then
         Indicate_Failure (Failure_Gyro_Init_Failed, 10);
         Reset;
      end if;
      Inputs.Count := 1;
      Inputs.Stored_Detected := Config.Gyro_Config.Gyros_Detected;
      Inputs.Enabled_Setting := Config.Gyro_Config.Gyro_Enabled_Bitmask;
      Inputs.Configured (0) := True;
      Inputs.Present (0) := Gyro_Report.Found;
      Inputs.Reports (0) := (Sample_Rate_Hz     => Gyro_Report.Sample_Rate_Hz,
                             Scale              => Gyro_Report.Scale,
                             Overflow_Protected => Gyro_Report.Overflow_Protected);
      Adaflight.Gyro_Selection.Choose (Inputs, Selection);
      if not Selection.Found then
         if Config.System_Config.Configuration_State /= 0 then
            Indicate_Failure (Failure_Missing_Acc, 2);
         end if;
         Env.Status.Arming_Disabled (Adaflight.Arming.No_Gyro) := True;
         Ctx.Out_Views.State.Status.Arming_Disabled (Adaflight.Arming.No_Gyro) := True;
         return;
      end if;
      Config.Gyro_Config.Gyros_Detected := Selection.Stored_Detected;
      Config.Gyro_Config.Gyro_Enabled_Bitmask := Selection.Enabled_Setting;
      Rate := Adaflight.Config_Fix.Gyro_Rate (Natural'Min (Selection.Sample_Rate_Hz, 32_000));
      Adaflight.Config_Fix.Fix_Gyro (Config, Rate);
      Ctx.Gyro_Sample_Rate_Hz := Rate;
      Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.Gyro) := True;
      Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.Acc) := Gyro_Report.Acc_Found;
      Ctx.Out_Views.Detected_Flags := Selection.Detected;
      Ctx.Out_Views.Hardware.Detected (Adaflight.MSP_Hardware_Out.Gyro) := Gyro_Report.Hardware;
      Ctx.Out_Views.Hardware.Detected (Adaflight.MSP_Hardware_Out.Acc) := Gyro_Report.Acc_Hardware;
      Ctx.Out_Views.Hardware.Gyro_Count := 1;
      Ctx.Out_Views.Hardware.Detected_Gyros (1) := Gyro_Report.Hardware;
      Env.Gyros (0) := (Hardware => Natural (Gyro_Report.Hardware), Bus => Bus, Mode => CLI.Interrupt_Init,
                        Bus_Devices => 1);
      Env.Gyros_Enabled := Selection.Enabled;
      Env.Acc := (Detected => Gyro_Report.Acc_Found, Hardware => Gyro_Report.Acc_Hardware, Bus => Bus);
   end Start_Gyro;

   --  The loop units' settings from the configuration once the gyro is
   --  known: the sample period from its rate, the loop ratio from the PID
   --  loop setting, the gyro filters with its scale, the accelerometer at
   --  its sample rate and count for one g, and the attitude estimate.
   procedure Init_Loop_Units is
      Mode   : Adaflight.Mixer_Init.Mixer_Mode := Adaflight.Mixer_Init.Quad_X;
      Motors : Adaflight.Mixer.Motor_Count := 4;
      Acc_Hz : Adaflight.Accelerometer.Sample_Rate := 1_000;
   begin
      if Selection.Sample_Rate_Hz > 0 then
         Sample_Us := Scheduler.Period_Us'Max (1, Scheduler.Period_Us (1_000_000 / Selection.Sample_Rate_Hz));
      end if;
      Loop_Ratio := Adaflight.Core_Loop.Loop_Ratio'Max (1,
                      Adaflight.Core_Loop.Loop_Ratio (Natural'Max (1, Natural (Config.Pid_Config.Pid_Process_Denom))));
      if Config.Mixer_Config.Mixer_Mode in
           1 .. Adaflight.Mixer_Init.Mixer_Mode'Pos (Adaflight.Mixer_Init.Mixer_Mode'Last) + 1
      then
         Mode := Adaflight.Mixer_Init.Mixer_Mode'Val (Config.Mixer_Config.Mixer_Mode - 1);
      end if;
      Motors := Adaflight.Mixer.Motor_Count'Max (1, Adaflight.Mixer_Init.Motor_Count_Of (Mode));
      Gyro_Settings := Adaflight.Config_Runtime.Gyro_Settings_Of
        (G => Config.Gyro_Config, N => Config.Dyn_Notch_Config, R => Config.Rpm_Filter_Config,
         Device => Config.Gyro_Device_Config (0), Board => Config.Board_Alignment, Motor => Config.Motor_Config,
         Loop_Rate => Config.Pid_Config, Sample_Time_Us => Adaflight.PID_Config.Loop_Time_Us (Sample_Us),
         Scale => Selection.Scale, Motors => Motors, Overflow_Protected => Selection.Overflow_Protected);
      Adaflight.Gyro_Filters.Init (Gyro_State, Gyro_Settings);
      if Gyro_Report.Acc_Sample_Rate_Hz in 1 .. 10_000 then
         Acc_Hz := Gyro_Report.Acc_Sample_Rate_Hz;
      end if;
      Acc_Settings := Adaflight.Config_Runtime.Accelerometer_Settings_Of
        (A => Config.Accelerometer_Config, Device => Config.Gyro_Device_Config (0), Board => Config.Board_Alignment,
         Sample_Rate_Hz => Acc_Hz, One_G => Adaflight.STM32.Gyro.Acc_One_G,
         Features => Config.Feature_Config.Enabled_Features);
      Adaflight.Accelerometer.Init (Acc_State, Acc_Settings);
      Attitude_Period_Fast_Us :=
        Scheduler.Time_Delta'Max
          (100, Scheduler.Time_Delta
                  (1_000_000 * Natural'Max (1, Natural (Config.Imu_Config.Imu_Process_Denom)) / Acc_Hz));
      Att_Config := Adaflight.Attitude.Configure
        (Adaflight.Config_Runtime.Attitude_Settings_Of (Config.Imu_Config, Config.Throttle_Correction_Config));
      Adaflight.Attitude.Init (Att_State);
      Adaflight.Gyro_Filters.Start_Calibration (Gyro_State, Gyro_Settings, First_Arm => False);
   end Init_Loop_Units;

   --  The scheduler with the tasks the image serves: the system load, the
   --  main and serial tasks, the realtime gyro, filter and PID tasks, the
   --  accelerometer and attitude tasks, and the receiver task whose check
   --  finds no frames yet.
   procedure Init_Scheduler is
      Options : constant Adaflight.Task_Init.Options :=
        (Accel => True, Beeper => True, Sag_Compensation => True, OSD => True, CMS => Adaflight.Build_Features.Menus,
         GPS => True, GPS_Rescue => True, Alt_Hold => True, Pos_Hold => True, Telemetry => True,
         VTX_Control => True, VTX_Driver => True, PINIO_Box => True, ESC_Sensor => True, RC_Device => True,
         Rangefinder => Adaflight.Build_Features.Rangefinder, OSD_Custom_Text => True,
         Gimbal => Adaflight.Build_Features.Gimbal, ADC_Internal => True, LED_Strip => True,
         Baro => Adaflight.STM32.Baro.Detected, others => False);
      Inputs  : Adaflight.Task_Init.Inputs;
      Feature_Rangefinder : constant Unsigned_32 := 16#0000_0200#;
   begin
      Sched_Settings := Adaflight.Config_Runtime.Scheduler_Settings_Of
        (Config.Scheduler_Config, Cycles_Per_Us => Adaflight.STM32.Time.Cycles_Per_Us,
         Delay_Limit_Us => Delay_Limit_Us, Gyro_Period_Us => Sample_Us, Debug_Mode => Config.System_Config.Debug_Mode);
      Inputs.Serial_Update_Rate_Hz :=
        Adaflight.Task_Init.Rate_Hz (Natural'Max (1, Natural (Config.Serial_Config.Serial_Update_Rate_Hz)));
      Inputs.Voltage_Meter := Adaflight.Battery."/=" (Bat_Settings.Voltage_Meter, Adaflight.Battery.None);
      Inputs.Current_Meter := Adaflight.Battery."/=" (Bat_Settings.Current_Meter, Adaflight.Battery.None);
      Inputs.Voltage_Alerts := Bat_Settings.Voltage_Alerts;
      Inputs.Consumption_Alerts := Bat_Settings.Consumption_Alerts;
      Inputs.Sag_Compensation := Bat_Settings.Sag_Compensation;
      Inputs.Gyro_Detected := Selection.Found;
      Inputs.Gyro_Sample_Looptime_Us := Sample_Us;
      Inputs.Gyro_Target_Looptime_Us := Sample_Us * Scheduler.Time_Delta (Loop_Ratio);
      Loop_Time_Us :=
        Adaflight.Blackbox.Loop_Time_Us'Max (1, Adaflight.Blackbox.Loop_Time_Us'Min
          (Adaflight.Blackbox.Loop_Time_Us'Last, Natural (Sample_Us) * Positive (Loop_Ratio)));
      Inputs.Acc_Detected := Gyro_Report.Acc_Found;
      Inputs.Acc_Sample_Rate_Hz := Gyro_Report.Acc_Sample_Rate_Hz;
      Inputs.Feature_OSD := (Runtime_Features and Adaflight.Config_Fix.Feature_OSD) /= 0;
      Inputs.Feature_GPS := (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0;
      Inputs.Feature_ESC_Sensor := (Runtime_Features and Adaflight.Config_Fix.Feature_ESC_Sensor) /= 0;
      Inputs.Feature_Telemetry := (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0;
      Inputs.PINIO_Box_Enabled := Adaflight.STM32.PINIO.Task_Enabled;
      Inputs.RC_Device_Enabled := Adaflight.STM32.RunCam.Enabled;
      Inputs.Rangefinder_Detected := Adaflight.STM32.Rangefinder.Detected;
      Inputs.Feature_Rangefinder := (Runtime_Features and Feature_Rangefinder) /= 0;
      Inputs.Feature_LED_Strip := (Runtime_Features and Adaflight.Config_Fix.Feature_LED_Strip) /= 0;
      Inputs.OSD_Framerate_Hz :=
        Adaflight.Task_Init.Rate_Hz (Natural'Max (1, Natural (Config.Osd_Config.Framerate_Hz)));
      Inputs.OSD_Display_Port := Adaflight.STM32.OSD.Port_Present;
      Adaflight.Task_Init.Init (Sched, Sched_Settings, Adaflight.STM32.Time.Cycle_Count, Options, Inputs);
      if Adaflight.STM32.Rangefinder.Detected then
         Scheduler.Reschedule
           (Sched, Sched_Settings, Scheduler.Rangefinder,
            Scheduler.Time_Delta (1_000 * Natural'Min (1_000, Adaflight.STM32.Rangefinder.Period_Ms)));
      end if;
   end Init_Scheduler;

   --  The command line takes the port: an interactive session from the hash
   --  mark, a configurator session from the start of text.
   procedure Enter_Command_Line (Interactive : Boolean) is
   begin
      Env.Interactive := Interactive;
      Terminal.Enter (Session, Into, Interactive, Now_Ms);
   end Enter_Command_Line;

   --  An MSP message's DShot commands to a motor or to all of them, each
   --  queued or sent at once by its type, with the motors disabled around
   --  blocking ones; another type sends nothing.
   procedure Send_DShot_Commands (E : Adaflight.MSP_Control_In.Effects) is
   begin
      if E.Motors_Off then
         Adaflight.STM32.DShot_Output.Disable;
      end if;
      for I in 0 .. E.DShot_Commands - 1 loop
         if E.DShot_Type <= 1 then
            Adaflight.STM32.DShot_Output.Write_Command
              (E.DShot_Motor, Adaflight.STM32.Control.Motor_Count, E.DShot_Values (I),
               (if E.DShot_Type = 1 then Adaflight.DShot_Command.Blocking else Adaflight.DShot_Command.Inline));
         end if;
      end loop;
      if E.Motors_Off then
         Adaflight.STM32.DShot_Output.Enable;
      end if;
   end Send_DShot_Commands;

   --  The MSP reboot modes the board serves: the firmware and the ROM
   --  bootloader; the others leave the board running.
   Firmware_Reboot       : constant := 0;
   ROM_Bootloader_Reboot : constant := 1;

   --  One command through the processor with its request, the effects it
   --  asks for, and a requested write of the configuration with its read
   --  back; the reply stays in the stream.
   procedure Process_Command (Command : Unsigned_16; Request : Adaflight.Bytes.Byte_Array) is
      Unused_Success : Boolean;
      Asked          : Adaflight.Arming.Outputs;
   begin
      Env.Now_Us := Now_Ms * 1000;
      Env.Status.Uptime_Ms := Now_Ms;
      Adaflight.Stream_Buffers.Init (Stream, 0, Reply'Length);
      Ctx.OSD_Port := Adaflight.STM32.OSD.Port_Present;
      Ctx.Font_Write_Taken := Adaflight.STM32.OSD.Font_Write_Taken;
      Ctx.Log := Adaflight.STM32.Blackbox.Recorder;
      Ctx.Loop_Time := Loop_Time_Us;
      Ctx.Out_Views.OSD.Device := Adaflight.STM32.OSD.Device;
      Ctx.Motors := Adaflight.STM32.Control.Motor_Count;
      Ctx.Motor_Device := Adaflight.STM32.Motors.Device;
      Ctx.VTX_Device := Adaflight.STM32.VTX.Device;
      Ctx.VTX_Table := Adaflight.STM32.VTX.Table;
      Ctx.Out_Views.VTX_Status := Adaflight.STM32.VTX.Status;
      Adaflight.STM32.VTX.Peripheral
        (Ctx.Out_Views.Peripheral.VTX_Device, Ctx.Out_Views.Peripheral.VTX_Pit_Mode,
         Ctx.Out_Views.Peripheral.VTX_Ready, Ctx.Out_Views.Peripheral.VTX_Type);
      if Command = Adaflight.MSP_OSD_Out.OSD_Config_Command then
         Adaflight.STM32.OSD.Check_Ready (Config, Adaflight.STM32.Pilot.Armed, Ctx.Out_Views.OSD.Device_Ready);
      end if;
      MSP.Process (Ctx, Config, Board, Links, Command, Request, Ports, Reply, Stream, Result, Effects);
      if Effects.Runtime.Clock then
         Adaflight.STM32.RTC.Set_Ms (Effects.Runtime.Clock_Ms);
      end if;
      if Effects.VTX.Pit_Mode_Set then
         Adaflight.STM32.VTX.Set_Pit_Mode (Effects.VTX.Pit_Mode_Value);
      end if;
      if Effects.Font.Write then
         Adaflight.STM32.OSD.Write_Font (Effects.Font.Address, Effects.Font.Data);
      end if;
      if Effects.OSD.OSD_Elements or else Effects.OSD.Profile_Change then
         Adaflight.STM32.OSD.Configure (Config, Version_Text);
         Adaflight.STM32.OSD.Analyze_Again;
      end if;
      if Effects.Receiver.Modes_Init then
         Adaflight.STM32.Pilot.Reload_Modes (Config);
         Scheduler.Set_Task_Enabled (Sched, Scheduler.PINIO_Box, Adaflight.STM32.PINIO.Task_Enabled);
      end if;
      if Effects.Control.Acc_Calibration then
         Adaflight.Accelerometer.Start_Calibration (Acc_State);
      end if;
      if Effects.Motor.Set then
         Adaflight.STM32.Control.Set_Disarmed (Effects.Motor.Values);
      end if;
      if Effects.Servo.Mixer_Load then
         Adaflight.STM32.Control.Load_Servo_Rules (Config.Custom_Servo_Mixers);
      end if;
      if Effects.LED.Layout then
         Strip_Layout := Adaflight.LED_Strip.Evaluate (Strip_Settings);
      end if;
      if Effects.Control.DShot then
         Send_DShot_Commands (Effects.Control);
      end if;
      if Effects.Control.Disarm then
         Adaflight.STM32.Pilot.Disarm (Adaflight.Arming.Serial_Command, Adaflight.STM32.Time.Micros, Asked);
         Apply (Asked);
      end if;
      case Effects.Control.MSP_Arming is
         when Adaflight.MSP_Control_In.Disable => Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.MSP_Open, True);
         when Adaflight.MSP_Control_In.Enable => Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.MSP_Open, False);
         when Adaflight.MSP_Control_In.Unchanged => null;
      end case;
      if Effects.Save then
         Scheduler.Ignore_Task_State_Time (Sched);
         Write_Configuration;
         Load_Configuration (Unused_Success);
      end if;
   end Process_Command;

   --  The reboot the processed command asked for, in its mode.
   procedure Reboot_If_Asked is
   begin
      if Effects.Reboot then
         case Effects.Control.Reboot_Mode is
            when Firmware_Reboot =>
               Adaflight.STM32.Motors.Shutdown;
               Reset;
            when ROM_Bootloader_Reboot =>
               Adaflight.STM32.Motors.Shutdown;
               Adaflight.STM32.MCU.Reset_To_Bootloader;
            when others =>
               null;
         end case;
      end if;
   end Reboot_If_Asked;

   --  One command frame through the processor, then its reply framed and
   --  sent back through the port it came in on, and a reboot in its mode.
   procedure Answer (L : MSP_Line) is
      Port : Adaflight.MSP_Port.Port renames Lines (L).Port;
   begin
      Process_Command (Unsigned_16 (Port.Command_Id), Port.Data (0 .. Port.Data_Size - 1));
      Adaflight.MSP_Port.Encode (Port.Version, Port.Command_Id, Port.Flags, Result = MSP.Error,
                                 Reply (0 .. Stream.Next - 1), Frame, Frame_Length);
      Adaflight.STM32.Serial.Put (Replies (L), Frame (0 .. Frame_Length - 1));
      Reboot_If_Asked;
   end Answer;

   --  A line's UART at its rate and duplex, with its MSP framing from the
   --  start.
   procedure Open_Line (L : MSP_Line) is
      Half : constant Adaflight.STM32.USART.Half_Duplex := (On => True, others => <>);
   begin
      if Line_Serial (L) /= Adaflight.STM32.Serial.VCP then
         Adaflight.STM32.USART.Init
           (UART_Of (Line_Serial (L)), Line_Rate (L),
            Line => (if Line_Half (L) then Half else Adaflight.STM32.USART.Full_Duplex));
      end if;
      Adaflight.MSP_Port.Init (Lines (L).Port);
      Replies (L).Which := Line_Serial (L);
   end Open_Line;

   --  A port's bytes received since the last take, after the bytes waiting.
   procedure Take_Line (L : MSP_Line) is
      S : Line_State renames Lines (L);
   begin
      Adaflight.STM32.Serial.Take (Line_Serial (L), Input, Count);
      if Count > 0 then
         declare
            Room : constant Natural := S.Pending'Length - S.Waiting;
            Take : constant Natural := Natural'Min (Count, Room);
         begin
            S.Pending (S.Waiting .. S.Waiting + Take - 1) := Input (0 .. Take - 1);
            S.Waiting := S.Waiting + Take;
         end;
      end if;
   end Take_Line;

   --  Whether a device streams MSP on the line: a UART the OSD names as a
   --  device's UART.
   function Peripheral_Line (L : MSP_Line) return Boolean is
     (Line_Serial (L) /= Adaflight.STM32.Serial.VCP
      and then Adaflight.STM32.OSD.Peripheral (UART_Of (Line_Serial (L))));

   --  A port's bytes through its MSP framing, which evaluates the other data
   --  while disarmed; the command line entered there takes the port.
   procedure Serve_MSP (L : MSP_Line; Evaluate_Other_Data : Boolean) is
      S : Line_State renames Lines (L);
   begin
      loop
         Adaflight.MSP_Port.Process
           (S.Port, S.Pending (0 .. S.Waiting - 1), Consumed, Now_Ms,
            (Evaluate_Non_MSP => Evaluate_Other_Data, Peripheral => Peripheral_Line (L),
             Reboot_Character => Config.Serial_Config.Reboot_Character, CLI_Running => False),
            Event);
         S.Pending (0 .. S.Waiting - Consumed - 1) := S.Pending (Consumed .. S.Waiting - 1);
         S.Waiting := S.Waiting - Consumed;
         case Event is
            when Adaflight.MSP_Port.Command_Frame =>
               Answer (L);
            when Adaflight.MSP_Port.CLI_Opened | Adaflight.MSP_Port.CLI_Command_Entered =>
               CLI_Line := L;
               Into.Target.Which := Line_Serial (L);
               Env.CLI_Port := Interfaces.Integer_32 (Line_Id (Line_Serial (L)));
               Adaflight.STM32.Passthrough.Set_Command_Line_Port (Line_Serial (L));
               Enter_Command_Line (Interactive => Event = Adaflight.MSP_Port.CLI_Opened);
            when Adaflight.MSP_Port.Reset_Requested =>
               Reset;
            when Adaflight.MSP_Port.Reply_Frame | Adaflight.MSP_Port.Nothing =>
               null;
         end case;
         exit when Session.Open or else Consumed = 0 or else S.Waiting = 0;
      end loop;
   end Serve_MSP;

   --  The flash chip as the command line reports it.
   function Flash_Status return CLI.Flash_Status is
      G : constant Adaflight.Flash_Device.Geometry := Adaflight.STM32.Flash_Chip.Geometry;
      S : CLI.Flash_Status;
      Found : Boolean;
      Kind  : Natural;
      First, Last : Unsigned_16;
   begin
      S.Sectors := G.Sectors;
      S.Sector_Size := G.Sector_Size;
      S.Pages_Per_Sector := G.Pages_Per_Sector;
      S.Page_Size := G.Page_Size;
      S.Total_Size := G.Total_Size;
      S.JEDEC_Id := G.JEDEC_Id;
      S.Count := Natural'Min (CLI.Max_Flash_Partitions, Adaflight.STM32.Flash_Chip.Partition_Count);
      for I in 0 .. S.Count - 1 loop
         Adaflight.STM32.Flash_Chip.Partition (I, Found, Kind, First, Last);
         if Found then
            S.Partitions (I) := (Kind => Natural'Min (5, Kind), First_Sector => First, Last_Sector => Last);
         end if;
      end loop;
      S.Used := Adaflight.STM32.Flash_Chip.Offset;
      return S;
   end Flash_Status;

   --  The SD card as the command line reports it.
   function SD_Status return CLI.SD_Card_Status is
      Meta : constant Adaflight.SD_Card_Types.Metadata := Adaflight.STM32.SD.Card_Info;
      Name : String (1 .. 5);
   begin
      for K in Name'Range loop
         Name (K) := Character'Val (Meta.Product_Name (K - 1));
      end loop;
      return
        (Inserted     => Adaflight.STM32.SD.Inserted,
         Functional   => Adaflight.STM32.SD.Summary.Functional,
         Initialized  => Adaflight.STM32.SD.Summary.Initialized,
         Manufacturer => Meta.Manufacturer,
         Blocks       => Meta.Num_Blocks,
         Month        => Meta.Production_Month,
         Year         => Meta.Production_Year,
         Major        => Meta.Revision_Major,
         Minor        => Meta.Revision_Minor,
         Name         => Name,
         State        =>
           (case Adaflight.STM32.SD.File_System_State is
               when Adaflight.FAT.Unknown        => CLI.Unknown,
               when Adaflight.FAT.Fatal          => CLI.Fatal,
               when Adaflight.FAT.Initialization => CLI.Initializing,
               when Adaflight.FAT.Ready          => CLI.Ready),
         Last_Error   =>
           (case Adaflight.STM32.SD.Last_Error is
               when Adaflight.FAT.None                  => CLI.No_Error,
               when Adaflight.FAT.Generic_Error         => CLI.Generic_Error,
               when Adaflight.FAT.Bad_MBR               => CLI.Bad_MBR,
               when Adaflight.FAT.Bad_Filesystem_Header => CLI.Bad_Header));
   end SD_Status;

   --  What the MSP replies and the command line read, taken fresh: the
   --  clock, the loop timing and load, the devices, the ESC readings, the
   --  altitude estimate, the video transmitter's power levels, the storage,
   --  the real-time clock, the OSD and the battery.
   procedure Refresh_Views is
   begin
      Now_Ms := Adaflight.STM32.Time.Millis;
      Ctx.Out_Views.State.Status.PID_Delta_Us := Scheduler.Task_Delta_Time (Sched, Scheduler.PID);
      Ctx.Out_Views.State.Status.Load_Percent := Unsigned_16 (Sched.Average_Load_Percent);
      Env.Gyros (0).Mode := Gyro_Mode;
      Env.SD_Card := SD_Status;
      Env.VTX_Present := Adaflight.STM32.VTX.Device.Present;
      Env.Motors := Adaflight.STM32.Control.Motor_Count;
      Env.Motor_Device := Adaflight.STM32.Motors.Device;
      Env.DShot_Protocol := Adaflight.STM32.DShot_Output.Protocol_Is_DShot;
      Env.ESC_Sensor := Adaflight.STM32.ESC_Sensor.Feature_On;
      Ctx.Out_Views.State.ESC := Adaflight.STM32.ESC_Sensor.Values (Adaflight.STM32.Control.Motor_Count);
      Ctx.Out_Views.State.Altitude :=
        (Estimate_Cm    => Estimated_Altitude_Cm, Vario => Estimated_Vario,
         Rangefinder_Cm => Adaflight.STM32.Rangefinder.Altitude_Cm);
      declare
         Count          : Natural;
         Levels, Powers : Adaflight.SmartAudio.Level_Values;
      begin
         Adaflight.STM32.VTX.Power_Levels (Count, Levels, Powers);
         Env.VTX_Power.Count := Natural'Min (CLI.Max_Power_Levels, Count);
         for I in 1 .. Env.VTX_Power.Count loop
            Env.VTX_Power.Levels (I) := Levels (I - 1);
            Env.VTX_Power.Powers (I) := Powers (I - 1);
         end loop;
      end;
      Ctx.Out_Views.Hardware.SD_Card := Adaflight.STM32.SD.Summary;
      Ctx.Out_Views.Hardware.Flash := Adaflight.STM32.Flash_Chip.Summary;
      Ctx.Out_Views.Hardware.Motor_Count := Unsigned_8 (Adaflight.STM32.Control.Motor_Count);
      Env.Flash := Flash_Status;
      Adaflight.STM32.RTC.Set_Zone (Config.Time_Config.Tz_Offset_Minutes);
      Ctx.Out_Views.State.Clock := Adaflight.STM32.RTC.Clock_Values;
      Env.Status.OSD_Device := Adaflight.OSD_Task.Device_Kind'Pos (Adaflight.STM32.OSD.Device);
      Env.Status.OSD_Port := Adaflight.STM32.OSD.Port_Present;
      Adaflight.STM32.OSD.Dimensions (Env.Status.OSD_Columns, Env.Status.OSD_Rows);
      Report_Battery;
   end Refresh_Views;

   --  A request from the receiver link's MSP tunnel, processed as a serial
   --  one, with the reboot it asks for before its reply goes out.
   procedure Telemetry_Request (Command : Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                                Answer_Bytes : out Adaflight.Bytes.Byte_Array; Length : out Natural;
                                Failed : out Boolean) is
   begin
      Refresh_Views;
      Process_Command (Command, Request);
      Reboot_If_Asked;
      Length := Natural'Min (Stream.Next, Answer_Bytes'Length);
      Answer_Bytes (Answer_Bytes'First .. Answer_Bytes'First + Length - 1) := Reply (0 .. Length - 1);
      Failed := Result = MSP.Error;
   end Telemetry_Request;

   procedure Telemetry_Step is new Adaflight.STM32.Radio.Telemetry_Step (Telemetry_Request);
   function SmartPort_Inputs return Adaflight.SmartPort_Telemetry.Inputs;
   procedure Receiver_Step is new Adaflight.STM32.Radio.Process (Telemetry_Request, SmartPort_Inputs);

   --  The serial task: while the command line is open its port's bytes go to
   --  it, otherwise each port's bytes go to its MSP framing, UART1's while no
   --  other device holds it. The status reply reads the loop timing first.
   procedure MSP_Serial (Evaluate_Other_Data : Boolean) is
   begin
      Refresh_Views;
      if Session.Open then
         Take_Line (CLI_Line);
         declare
            S : Line_State renames Lines (CLI_Line);
         begin
            if S.Waiting > 0 then
               Terminal.Process (Session, Into, S.Pending (0 .. S.Waiting - 1), Now_Ms, Config, Ports, Env, Board,
                                 Sched, Changes);
               S.Waiting := 0;
               if Changes.LEDs then
                  Strip_Layout := Adaflight.LED_Strip.Evaluate (Strip_Settings);
               end if;
               if Changes.Modes then
                  Adaflight.STM32.Pilot.Reload_Modes (Config);
                  Scheduler.Set_Task_Enabled (Sched, Scheduler.PINIO_Box, Adaflight.STM32.PINIO.Task_Enabled);
               end if;
               if Changes.PID_Profile or else Changes.Rate_Profile then
                  Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
                  Adaflight.STM32.Control.Init (Config, Runtime_Features);
               end if;
               if Changes.Motor then
                  if Changes.Every_Motor then
                     Adaflight.STM32.Control.Set_Disarmed_All (Changes.Motor_Value);
                  else
                     Adaflight.STM32.Control.Set_Disarmed_Motor (Changes.Motor_Index, Changes.Motor_Value);
                  end if;
               end if;
               if not Session.Open then
                  Adaflight.STM32.Control.Reset_Disarmed;
               end if;
               if Changes.Save then
                  Write_Configuration;
               end if;
               if Changes.Reboot then
                  Adaflight.STM32.Motors.Shutdown;
                  Reset;
               end if;
               if CLI."=" (Changes.Restart, CLI.ROM_Bootloader) then
                  Adaflight.STM32.Motors.Shutdown;
                  Adaflight.STM32.MCU.Reset_To_Bootloader;
               end if;
               Changes := (others => <>);
            end if;
         end;
      else
         for L in 1 .. Line_Count loop
            if Line_Serial (L) = Adaflight.STM32.Serial.VCP
              or else not (Held_Before_MSP (UART_Of (Line_Serial (L)))
                           or else Telemetry_Holds (UART_Of (Line_Serial (L))))
            then
               Take_Line (L);
               Serve_MSP (L, Evaluate_Other_Data);
            end if;
            exit when Session.Open;
         end loop;
      end if;
   end MSP_Serial;

   --  The accelerometer task: one reading through the accelerometer unit,
   --  and its counts over the one g divisor into the raw readings reply.
   --  The beeper settings from the stored beeper group, read at every use.
   function Beep_Settings return Adaflight.Beeper.Settings is
     (Adaflight.Config_Runtime.Beeper_Settings_Of (Config.Beeper_Config));

   --  The USB cable's detect pin, an input pulled down where the board has
   --  one.
   USB_Detect : constant Boolean := Adaflight.Board.USB_Detect_Tag /= 0;
   USB_Detect_Pin : constant Adaflight.Pins.Pin :=
     (Port   => Adaflight.Pins.Port_Name'Val (Natural'Max (1, Adaflight.Board.USB_Detect_Tag / 16) - 1),
      Number => Adaflight.Pins.Pin_Number (Adaflight.Board.USB_Detect_Tag mod 16));

   --  Whether the USB cable is active: its detect pin high, or a host that
   --  configured the port.
   function USB_Active return Boolean is
     ((USB_Detect and then Adaflight.STM32.GPIO.Is_High (USB_Detect_Pin)) or else Adaflight.STM32.USB.Configured);

   --  Whether a configurator talks MSP: a byte on the USB port's or UART1's
   --  MSP within the activity timeout.
   function Configurator_Active return Boolean is
     (for some L in 1 .. Line_Count =>
        Adaflight.MSP_Port.Configurator_Active
          (Lines (L).Port, Adaflight.STM32.Time.Millis, Peripheral => Peripheral_Line (L)));

   --  What the beeper reads: the battery's presence, the USB cable, a
   --  configurator on MSP, the beeper boxes, the GPS, the motors running while
   --  armed, the failsafe's link, the last disarm and a waiting arming.
   function Beep_Conditions return Adaflight.Beeper.Conditions is
     (Battery_Present     => Adaflight.Battery."/=" (Bat.Overall, Adaflight.Battery.Not_Present),
      USB_Active          => USB_Active,
      Configurator_Active => Configurator_Active,
      Mute_Switch         => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Beeper_Mute),
      Beep_Switch         => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Beeper_On),
      Satellite_Switch    => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Beep_GPS_Count),
      GPS_Feature         => Adaflight.STM32.GPS.Enabled,
      GPS_Fix             => Adaflight.STM32.GPS.Current.Fix,
      Satellites          => 0,
      Motors_Running      => Adaflight.STM32.Control.Motors_Running,
      Failsafe_Monitoring => Adaflight.STM32.Radio.Failsafe_Monitoring,
      Failsafe_Receiving  => Adaflight.STM32.Radio.Failsafe_Receiving,
      Last_Disarm_Us      => Adaflight.STM32.Pilot.Last_Disarm_Us,
      Trying_To_Arm       => Adaflight.STM32.Pilot.Trying_To_Arm);

   procedure Request_Beep (M : Adaflight.Beeper.Mode) is
   begin
      Adaflight.Beeper.Request (Beep, Beep_Settings, Beep_Conditions, M);
   end Request_Beep;

   procedure Confirmation_Beeps (Count : Adaflight.Beeper.Beep_Count) is
   begin
      Adaflight.Beeper.Confirmation_Beeps (Beep, Beep_Settings, Beep_Conditions, Count);
   end Confirmation_Beeps;

   procedure Silence_Beeper is
   begin
      Adaflight.Beeper.Silence_Beeper (Beep);
      Adaflight.STM32.Sound.Set (False);
   end Silence_Beeper;

   --  The beeper task: the update with its DShot beacon queued, the output
   --  following it, and the scheduler told when the update was short.
   procedure Run_Beeper (Before : Unsigned_32) is
      Result : Adaflight.Beeper.Update_Outputs;
   begin
      Adaflight.Beeper.Update (Beep, Beep_Settings, Beep_Conditions, Before, Result);
      if Result.Beacon_Command then
         Adaflight.STM32.DShot_Output.Write_Command
           (Adaflight.DShot_Command.All_Motors, Adaflight.STM32.Control.Motor_Count,
            Unsigned_8 (Beep_Settings.Beacon_Tone),
            Adaflight.DShot_Command.Inline);
      end if;
      Adaflight.STM32.Sound.Set (Adaflight.Beeper.Is_On (Beep));
      if Result.Ignore_Exec_Time then
         Scheduler.Ignore_Task_Exec_Time (Sched);
      end if;
   end Run_Beeper;

   --  The battery's alarm while its voltage alerts are on.
   procedure Battery_Alarms is
   begin
      case Adaflight.Battery.Alarm (Bat, Bat_Settings) is
         when Adaflight.Battery.Low =>
            Request_Beep (Adaflight.Beeper.Battery_Low);
         when Adaflight.Battery.Critical_Low =>
            Request_Beep (Adaflight.Beeper.Battery_Critical_Low);
         when Adaflight.Battery.Silence =>
            null;
      end case;
   end Battery_Alarms;

   --  A finished accelerometer calibration stored: its offsets, the
   --  calibration marked complete and the level trims reset, then written,
   --  read back and confirmed with a beep.
   procedure Store_Acc_Calibration is
      Unused_Success : Boolean;
   begin
      Config.Accelerometer_Config.Acc_Zero (0) := Integer_16 (Acc_State.Zero (Adaflight.Vectors.X));
      Config.Accelerometer_Config.Acc_Zero (1) := Integer_16 (Acc_State.Zero (Adaflight.Vectors.Y));
      Config.Accelerometer_Config.Acc_Zero (2) := Integer_16 (Acc_State.Zero (Adaflight.Vectors.Z));
      Config.Accelerometer_Config.Acc_Zero (3) := 1;
      Config.Accelerometer_Config.Accelerometer_Trims := (others => 0);
      Write_Configuration;
      Load_Configuration (Unused_Success);
      Confirmation_Beeps (1);
   end Store_Acc_Calibration;

   procedure Acc_Update (Now_Us : Scheduler.Time_Us) is
      pragma Unreferenced (Now_Us);
      Raw         : Adaflight.STM32.Gyro.Axis_Values;
      OK          : Boolean;
      Calibrating : Adaflight.Accelerometer.Cycle_Count;
   begin
      Adaflight.STM32.Gyro.Read_Acc (Raw, OK);
      if not OK then
         return;
      end if;
      Calibrating := Acc_State.Calibrating;
      Adaflight.Accelerometer.Update
        (Acc_State, Acc_Settings, (Integer (Raw (0)), Integer (Raw (1)), Integer (Raw (2))), Acc_Cal);
      if Acc_State.Inflight_Ended then
         Request_Beep (Adaflight.Beeper.Acc_Calibration);
      end if;
      if (Calibrating = 1 and then Acc_State.Calibrating = 0) or else Acc_State.Inflight_Saved then
         Store_Acc_Calibration;
      end if;
      Ctx.Out_Views.State.IMU.Acc :=
        (0 => Acc_State.Acc.X / Acc_Scale, 1 => Acc_State.Acc.Y / Acc_Scale, 2 => Acc_State.Acc.Z / Acc_Scale);
   end Acc_Update;

   --  The battery settings from the stored battery, sensor and selected
   --  profile groups, read again at every battery task as the stored values
   --  may change.
   function Battery_Settings return Adaflight.Battery.Settings is
     (Adaflight.Config_Runtime.Battery_Settings_Of
        (Config.Battery_Config,
         Config.Battery_Profiles (Natural'Min (2, Natural (Config.System_Config.Active_Battery_Profile))),
         Config.Voltage_Sensor_Adc_Config (0), Config.Current_Sensor_Adc_Config,
         Config.Current_Sensor_Virtual_Config, Config.Esc_Sensor_Config,
         Adaflight.Config_Runtime.Sag_Compensation_Of (Config.Pid_Profiles, Config.Mixer_Config)));

   --  The pin of a tag as the configuration stores it: the port from one in
   --  the high nibble and the pin number in the low one.
   function Tagged_Pin (Tag : Unsigned_8) return Boolean is
     (Tag / 16 in 1 .. Adaflight.Pins.Port_Name'Pos (Adaflight.Pins.Port_Name'Last) + 1);

   function Pin_Of (Tag : Unsigned_8) return Adaflight.Pins.Pin is
     ((Port => Adaflight.Pins.Port_Name'Val (Natural (Tag / 16) - 1),
       Number => Adaflight.Pins.Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   --  Whether an analog input is on with a pin that has a converter channel.
   function Analog_Input (Channel : Adaflight.Config_Groups.Adc_Channel_Config_T_Record) return Boolean is
     (Channel.Enabled and then Tagged_Pin (Channel.Io_Tag)
      and then Adaflight.STM32.ADC.Has_Channel (Pin_Of (Channel.Io_Tag)));

   --  An analog input's sample, zero when the input is off.
   function Analog (Channel : Adaflight.Config_Groups.Adc_Channel_Config_T_Record) return Natural is
     (if Analog_Input (Channel) then Natural (Adaflight.STM32.ADC.Read (Pin_Of (Channel.Io_Tag))) else 0);

   --  The internal ADC task: once the started conversion ends, both readings
   --  into the averages, the supply and core temperature to the status
   --  replies, then the next conversion.
   procedure Run_ADC_Internal is
      Busy : Boolean;
   begin
      Adaflight.STM32.ADC.Check_Internal (Busy);
      if Busy then
         return;
      end if;
      Adaflight.Internal_ADC.Process
        (Internal, Internal_Cal, Adaflight.STM32.ADC.Reference_Sample, Adaflight.STM32.ADC.Temperature_Sample);
      Env.Status.Vref_Mv := Internal.Vref_Mv;
      Env.Status.Core_Temp_C := Internal.Core_Temperature;
      Ctx.Out_Views.State.Status.Core_Temperature := Internal.Core_Temperature;
      Adaflight.STM32.ADC.Start_Internal;
   end Run_ADC_Internal;

   --  The internal channels with the stored calibration overrides or the
   --  chip's words, then nine passes of the task to fill the averages. The
   --  slope takes the processor's zero quotient for equal sensor readings
   --  and holds to the internal ADC unit's bound.
   procedure Init_Internal_ADC is
      A    : Adaflight.Config_Groups.Adc_Config_Record renames Config.Adc_Config;
      function Word (Stored, Chip : Unsigned_16) return Integer_32 is
        (Integer_32 (if Stored /= 0 then Stored else Chip));
      Cal1  : constant Integer_32 := Word (A.Temp_Sensor_Calibration1, Adaflight.STM32.ADC.Sensor_Calibration_30);
      Cal2  : constant Integer_32 := Word (A.Temp_Sensor_Calibration2, Adaflight.STM32.ADC.Sensor_Calibration_110);
      Slope : constant Integer_32 := (if Cal2 = Cal1 then 0 else (110 - 30) * 1_000 / (Cal2 - Cal1));
      Busy  : Boolean;
   begin
      Adaflight.STM32.ADC.Init_Internal;
      Internal_Cal :=
        (Vrefint_Cal => Word (A.Vref_Int_Calibration, Adaflight.STM32.ADC.Reference_Calibration),
         Ts_Cal1     => Integer_32'Min (4_095, Cal1),
         Ts_Slope_K  => Integer_32'Max (-10_000, Integer_32'Min (10_000, Slope)));
      Adaflight.Internal_ADC.Init (Internal);
      for Pass in 1 .. 9 loop
         loop
            Adaflight.STM32.ADC.Check_Internal (Busy);
            exit when not Busy;
         end loop;
         Run_ADC_Internal;
      end loop;
   end Init_Internal_ADC;

   --  What the battery's other meters read: the ESC sensor's reading over
   --  every motor, the arming, the throttle status with the motor stop
   --  feature and the mixer's throttle for the virtual meter, and the
   --  measured supply for the analog meters.
   function Meters return Adaflight.Battery.Meter_Inputs is
      M : Adaflight.Battery.Meter_Inputs :=
        (ESC_Sensor   => Adaflight.STM32.ESC_Sensor.Feature_On,
         ESC          => <>,
         Armed        => Adaflight.STM32.Pilot.Armed,
         Throttle_Low => Adaflight.STM32.Pilot.Throttle_Low (Flight_Channels),
         Motor_Stop   => (Runtime_Features and Adaflight.Config_Fix.Feature_Motor_Stop) /= 0,
         Throttle     => Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Control.Throttle)),
         Now_Ms       => Adaflight.STM32.Time.Millis,
         Supply_Mv    => Unsigned_16'Min (16_000, Internal.Vref_Mv));
   begin
      if M.ESC_Sensor then
         declare
            C     : Adaflight.ESC_Sensor.Reading;
            Bound : constant := 2 ** 23;
         begin
            Adaflight.STM32.ESC_Sensor.Combined (Adaflight.STM32.Control.Motor_Count, C);
            M.ESC :=
              (Data_Age    => Natural (C.Data_Age),
               Voltage     => Natural (C.Voltage),
               Current     => Integer_32'Max (-Bound, Integer_32'Min (Bound, C.Current)),
               Consumption => Integer_32'Max (-Bound, Integer_32'Min (Bound, C.Consumption)));
         end;
      end if;
      return M;
   end Meters;

   procedure Run_Battery_Voltage is
   begin
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Update_Voltage
        (Bat, Bat_Settings, Analog (Config.Adc_Config.Vbat),
         Adaflight.STM32.Time.Millis, Meters);
   end Run_Battery_Voltage;

   procedure Run_Battery_Current (Before : Unsigned_32) is
   begin
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Update_Current
        (Bat, Bat_Settings, Analog (Config.Adc_Config.Current), Before, Meters);
   end Run_Battery_Current;

   --  A battery's connection: the PID profile for the detected cells while
   --  disarmed, then the RPM limiter's reset.
   procedure Battery_Presence is
      Events  : Adaflight.Battery.Presence_Events;
      Current : constant Adaflight.Config_Runtime.Profile_Index :=
        Natural'Min (3, Natural (Config.System_Config.Pid_Profile_Index));
      Chosen  : Adaflight.Config_Runtime.Profile_Index;
   begin
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Update_Presence (Bat, Bat_Settings, Events);
      if not Events.Connected then
         return;
      end if;
      if Events.Detected_Cells > 0 and then not Adaflight.STM32.Pilot.Armed then
         Chosen := Adaflight.Config_Runtime.Profile_For_Cells (Config.Pid_Profiles, Current, Events.Detected_Cells);
         if Chosen /= Current then
            Config.System_Config.Pid_Profile_Index := Unsigned_8 (Chosen);
            Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
            Adaflight.STM32.Control.Init (Config, Runtime_Features, Unsigned_16 (Bat.Voltage.Display_Filtered));
         end if;
      end if;
      Adaflight.STM32.Control.Reset_RPM_Limiter (Unsigned_16 (Bat.Voltage.Display_Filtered));
   end Battery_Presence;

   procedure Battery_States (Now_Us : Scheduler.Time_Us) is
   begin
      Adaflight.Battery.Update_States (Bat, Bat_Settings, Now_Us, Adaflight.STM32.Time.Millis);
   end Battery_States;

   --  The battery's readings into the replies and the status report: the
   --  analog and battery replies, the battery meter at its id with the
   --  current meter of the configured source, and the status's battery line.
   procedure Report_Battery is
      use type Adaflight.Battery.Voltage_Source;
      use type Adaflight.Battery.Current_Source;
      B : Adaflight.MSP_Out.Battery_Values renames Ctx.Out_Views.State.Battery;
      M : Adaflight.MSP_Common_Out.Meter_Values renames Ctx.Out_Views.Common.Meters;
      Volts    : constant Natural := Bat.Voltage.Display_Filtered;
      Source   : constant Adaflight.Battery.Current_Source := Bat_Settings.Current_Meter;
      Profile  : Adaflight.Config_Groups.Battery_Profile_Record renames
        Config.Battery_Profiles (Natural'Min (2, Natural (Config.System_Config.Active_Battery_Profile)));
      function Reading (Id : Unsigned_8; Of_Source : Adaflight.Battery.Current_Source)
                        return Adaflight.MSP_Common_Out.Current_Reading is
        (if Source = Of_Source
         then (Id => Id, mAh_Drawn => Bat.Current.mAh_Drawn, Amperage => Bat.Current.Amperage)
         else (Id => Id, mAh_Drawn => 0, Amperage => 0));
   begin
      B.Legacy_Voltage := Unsigned_16 ((Volts + 5) / 10);
      B.MAh_Drawn := Bat.Current.mAh_Drawn;
      B.RSSI := Adaflight.STM32.Radio.RSSI;
      B.Amperage := Bat.Current.Amperage;
      B.Voltage := Unsigned_16 (Volts);
      B.Cell_Count := Unsigned_8 (Bat.Cells);
      B.Capacity_MAh := Profile.Battery_Capacity;
      B.State := Bat.Overall;
      M.Voltage_Count := 1;
      M.Voltages (1) :=
        (Id               => 10,
         Display_Filtered =>
           (if Bat_Settings.Voltage_Meter = Adaflight.Battery.Analog then Unsigned_16 (Volts) else 0));
      M.Current_Count := 3;
      M.Currents (1) := Reading (10, Adaflight.Battery.Analog);
      M.Currents (2) := Reading (80, Adaflight.Battery.Virtual);
      M.Currents (3) := Reading (90, Adaflight.Battery.MSP);
      Env.Status.Battery_Voltage := Unsigned_16 (Volts);
      Env.Status.Battery_Cells := Unsigned_8 (Bat.Cells);
      Env.Status.Battery_State := Bat.Overall;
   end Report_Battery;

   procedure Run_Telemetry (Now_Us : Scheduler.Time_Us);

   procedure No_Step is null;
   procedure No_Step_At (Now_Us : Scheduler.Time_Us) is null;
   procedure No_Step_Period (Now_Us : Scheduler.Time_Us; Next_Period_Us : out Scheduler.Time_Delta) is
      pragma Unreferenced (Now_Us);
   begin
      Next_Period_Us := 0;
   end No_Step_Period;

   package Tasks is new Adaflight.Task_Functions
     (SD_Card_Poll           => Adaflight.STM32.SD.Poll,
      Flash_Erase            => Adaflight.STM32.Flash_Chip.Erase_Step,
      MSP_Serial             => MSP_Serial,
      Battery_Presence       => Battery_Presence,
      Battery_States         => Battery_States,
      Battery_Alarms         => Battery_Alarms,
      Acc_Update             => Acc_Update,
      GPS_Rescue_Update      => Run_Rescue,
      Baro_Update            => Adaflight.STM32.Baro.Update,
      Pitot_Update           => No_Step_Period,
      Compass_Update         => No_Step_Period,
      Position_Update        => No_Step,
      Rangefinder_Update     => Adaflight.STM32.Rangefinder.Update,
      Rangefinder_Process    => Adaflight.STM32.Rangefinder.Process,
      Optical_Flow_Update    => No_Step,
      Optical_Flow_Process   => No_Step,
      Telemetry_Poll_Sensors => No_Step_At,
      Telemetry_Process      => Run_Telemetry,
      Camera_Control_Process => No_Step_At);

   --  The gyro task: one reading into the gyro filters' accumulation, and
   --  the core loop's cadence.
   procedure Run_Gyro is
      Raw      : Adaflight.STM32.Gyro.Axis_Values;
      OK       : Boolean;
      Finished : Boolean;
   begin
      Adaflight.STM32.Gyro.Read_Gyro (Raw, OK);
      Adaflight.Gyro_Filters.Accumulate
        (Gyro_State, Gyro_Settings,
         (0 => (Integer (Raw (0)), Integer (Raw (1)), Integer (Raw (2))), others => (0, 0, 0)),
         (0 => OK, others => False), Finished);
      if Finished then
         Request_Beep (Adaflight.Beeper.Gyro_Calibrated);
      end if;
      Adaflight.Core_Loop.Gyro_Sampled (Cadence, Loop_Ratio);
   end Run_Gyro;

   --  A filtered rate as the raw readings reply's counts.
   function Counts (Rate : Float) return Integer_16 is
      Scaled : constant Float := Float'Unbiased_Rounding (Rate / Gyro_Settings.Scale);
   begin
      return Integer_16 (Float'Max (-32_768.0, Float'Min (32_767.0, Scaled)));
   end Counts;

   --  The filter task: the loop's filtering without throttle or motor
   --  frequencies yet, then the filtered rates into the raw readings reply.
   procedure Run_Filter (Now_Us : Scheduler.Time_Us) is
      Multiplier : constant Float := Scheduler.Cycle_Time_Multiplier (Sched, Sched_Settings);
      Scale      : constant Adaflight.RPM_Filter.Cycle_Multiplier := Float'Max (0.25, Float'Min (4.0, Multiplier));
      No_Motors  : constant Adaflight.RPM_Filter.Motor_Frequencies := (others => 0.0);
   begin
      Adaflight.Gyro_Filters.Filter (Gyro_State, Gyro_Settings, Now_Us, Throttle_Percent => 0,
                                     Motor_Hz => No_Motors, Dt_Scale => Scale);
      for I in Adaflight.MSP_Out.Axis loop
         Ctx.Out_Views.State.IMU.Gyro_Dps (I) := Counts (Gyro_State.Filtered (Adaflight.Axes.Axis'Val (I)));
      end loop;
   end Run_Filter;

   --  The attitude task: the estimate from the attitude lowpass of the gyro
   --  and the accelerometer, without a compass, over the arming, the angle
   --  or horizon mode that turns the throttle correction on, the headfree
   --  mode, and the GPS course with the filtered yaw rate, then the angles
   --  and the quaternion into the attitude replies.
   procedure Run_Attitude (Now_Us : Scheduler.Time_Us) is
      Rates : constant Adaflight.Vectors.Vector3 :=
        (X => Gyro_State.Downsampled (Adaflight.Axes.Roll),
         Y => Gyro_State.Downsampled (Adaflight.Axes.Pitch),
         Z => Gyro_State.Downsampled (Adaflight.Axes.Yaw));
      No_Mag : constant Adaflight.Vectors.Vector3 := (0.0, 0.0, 0.0);
      Magnitude : constant Float := Float'Max (0.0, Float'Min (1.0e3, Acc_State.Magnitude));
      M : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Rate_Bound : constant := Adaflight.Attitude.Rate_Bound;
   begin
      Adaflight.Attitude.Update
        (Att_State, Att_Config, Now_Us, Rates, Acc_State.Acc, Magnitude, No_Mag,
         Use_Mag       => False,
         Armed         => Adaflight.STM32.Pilot.Armed,
         Angle_Mode    => M (Adaflight.Arming.Angle_Mode) or else M (Adaflight.Arming.Horizon_Mode),
         Headfree_Mode => M (Adaflight.Arming.Headfree_Mode),
         Course        =>
           (Usable       =>
              G.Present and then G.Fix and then Natural (G.Satellites) > Adaflight.Attitude.Min_Satellites,
            Ground_Speed => Natural (G.Ground_Speed),
            Course       => Natural'Min (3_599, Natural (G.Ground_Course)),
            Yaw_Rate     =>
              Float'Max (-Rate_Bound, Float'Min (Rate_Bound, Gyro_State.Filtered (Adaflight.Axes.Yaw))),
            Fixed_Wing   => Adaflight.Mixer_Init.Is_Fixed_Wing (Adaflight.STM32.Pilot.Mixer_Mode)));
      Ctx.Out_Views.State.Attitude :=
        (Roll  => Integer_16 (Att_State.Euler.Roll),
         Pitch => Integer_16 (Att_State.Euler.Pitch),
         Yaw   => Integer_16 (Att_State.Euler.Yaw),
         W     => Adaflight.MSP_Out.Component (Att_State.Reported.W),
         X     => Adaflight.MSP_Out.Component (Att_State.Reported.X),
         Y     => Adaflight.MSP_Out.Component (Att_State.Reported.Y),
         Z     => Adaflight.MSP_Out.Component (Att_State.Reported.Z));
   end Run_Attitude;

   --  The check function of a task with one: the receiver task's over the
   --  link, the display's frame time, and the altitude and position holds'
   --  update events from the position estimate, or twice their period since
   --  their last run.
   procedure Check (Id : Scheduler.Task_Id; Delta_Us : Scheduler.Time_Delta; Due : out Boolean) is
   begin
      case Id is
         when Scheduler.Rx =>
            Due := Adaflight.STM32.Radio.Update_Check (Adaflight.RX_Task.In_Progress (RX_State));
         when Scheduler.OSD =>
            Due := Adaflight.STM32.OSD.Task_Due (Adaflight.STM32.Time.Micros);
         when Scheduler.Alt_Hold =>
            Adaflight.Position_Estimator.Take_Update (Pos_State, Adaflight.Position_Estimator.Altitude_Hold, Due);
            Due := Due or else Delta_Us >= 2 * Adaflight.Altitude_Hold.Nominal_Interval_Us;
         when Scheduler.Pos_Hold =>
            Adaflight.Position_Estimator.Take_Update (Pos_State, Adaflight.Position_Estimator.Position_Hold, Due);
            Due := Due or else Delta_Us >= 2 * Adaflight.Position_Control.Nominal_Interval_Us;
         when others =>
            Due := False;
      end case;
   end Check;

   --  What the arming logic senses on the board: the link and the failsafe,
   --  the attitude within the small angle once established or no
   --  accelerometer, the calibrations, the GPS and the altitude estimate, no
   --  motor protocol yet, the scheduler's late share, the filtered rates and
   --  the stick deflections, the command line, and the DShot streaming
   --  commands, asked only where the boot grace check asks for them.
   function Sense return Adaflight.Arming.Inputs is
      Sensed : Adaflight.Arming.Inputs;
   begin
      Sensed.Rx_Signal := Adaflight.STM32.Radio.Receiving;
      Sensed.Failsafe_Receiving := Adaflight.STM32.Radio.Failsafe_Receiving;
      Sensed.Failsafe_Active := Adaflight.STM32.Radio.Failsafe_Active;
      Sensed.Failsafe_Monitoring := Adaflight.STM32.Radio.Failsafe_Monitoring;
      Sensed.Upright := Upright;
      Sensed.Gyro_Calibrated := Adaflight.Gyro_Filters.Calibration_Complete (Gyro_State);
      Sensed.GPS_Fix := Adaflight.STM32.GPS.Current.Fix;
      Sensed.GPS_Sats := Natural (Adaflight.STM32.GPS.Current.Satellites);
      Sensed.Altitude_Available := Pos_State.Valid_Z;
      Sensed.Acc_Calibrated := Adaflight.Accelerometer.Calibration_Complete (Acc_State);
      Sensed.Acc_Has_Calibration := Config.Accelerometer_Config.Acc_Zero (3) /= 0;
      Sensed.First_Arm_Gyro_Cal_Running := Adaflight.Gyro_Filters.First_Arm_Calibration_Running (Gyro_State);
      Sensed.Motor_Protocol_Enabled := Adaflight.STM32.Motors.Count > 0;
      Sensed.Late_Permille := Scheduler.CPU_Percentage_Late (Sched);
      Sensed.PID_Sums := Adaflight.STM32.Control.PID_Sums;
      for A in Adaflight.Axes.Axis loop
         Sensed.Gyro_Abs_Dps (A) := Natural (Float'Min (65_535.0, abs Gyro_State.Filtered (A)));
      end loop;
      Sensed.Deflection_Abs := Adaflight.STM32.Pilot.Deflections;
      Sensed.CLI_Mode := Session.Open;
      if Adaflight.STM32.Pilot.Disabled (Adaflight.Arming.Boot_Grace)
        and then Adaflight.STM32.Time.Millis >= Unsigned_32 (Config.System_Config.Power_On_Arming_Grace_Time) * 1_000
        and then Adaflight.STM32.DShot_Output.Protocol_Is_DShot
      then
         Adaflight.STM32.DShot_Output.Streaming_Enabled (Sensed.DShot_Streaming);
      end if;
      return Sensed;
   end Sense;

   --  The statistics at a disarm: the totals in the configuration move on
   --  past the minimum armed time, and a save waits half a second, unless
   --  one waits already.
   procedure Stats_On_Disarm is
      Stored   : Adaflight.Config_Groups.Stats_Config_Record renames Config.Stats_Config;
      T        : Adaflight.Flight_Stats.Totals :=
        (Flights => Stored.Stats_Total_Flights, Time_S => Stored.Stats_Total_Time_S,
         Dist_M  => Stored.Stats_Total_Dist_M, Mah_Used => Stored.Stats_Mah_Used);
      Schedule : Boolean;
   begin
      Adaflight.Flight_Stats.On_Disarm
        (Stats_Tracker, Adaflight.Config_Runtime.Flight_Stats_Settings_Of (Stored), T, Adaflight.STM32.Time.Millis,
         Adaflight.STM32.GPS.Current.Distance_Flown_Cm,
         Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.mAh_Drawn))), Schedule);
      Stored.Stats_Total_Flights := T.Flights;
      Stored.Stats_Total_Time_S := T.Time_S;
      Stored.Stats_Total_Dist_M := T.Dist_M;
      Stored.Stats_Mah_Used := T.Mah_Used;
      if Schedule and then not Stats_Save_Due then
         Stats_Save_Due := True;
         Stats_Save_At_Us := Adaflight.STM32.Time.Micros + Adaflight.Flight_Stats.Save_Delay_Us;
      end if;
   end Stats_On_Disarm;

   --  The statistics' waiting save once its time has come: written with the
   --  disarm beep while disarmed, still and with no other change unsaved,
   --  asked again after half a second while the craft moves.
   procedure Run_Stats_Save is
      Action : Adaflight.Flight_Stats.Save_Action;
      function Rate (A : Adaflight.Axes.Axis) return Adaflight.Flight_Stats.Rate is
        (Float'Max (-1.0e6, Float'Min (1.0e6, Gyro_State.Filtered (A))));
   begin
      if not Stats_Save_Due or else Adaflight.STM32.Time.Micros - Stats_Save_At_Us >= 16#8000_0000# then
         return;
      end if;
      Stats_Save_Due := False;
      Adaflight.Flight_Stats.Write
        (Stats_Tracker, Adaflight.Config_Runtime.Flight_Stats_Settings_Of (Config.Stats_Config),
         Adaflight.STM32.Pilot.Armed, Adj_State.Config_Dirty, Rate (Adaflight.Axes.Roll), Rate (Adaflight.Axes.Pitch),
         Rate (Adaflight.Axes.Yaw), Action);
      case Action is
         when Adaflight.Flight_Stats.Save =>
            Write_Configuration;
            Request_Beep (Adaflight.Beeper.Disarming);
         when Adaflight.Flight_Stats.Retry =>
            Stats_Save_Due := True;
            Stats_Save_At_Us := Adaflight.STM32.Time.Micros + Adaflight.Flight_Stats.Save_Delay_Us;
         when Adaflight.Flight_Stats.Nothing =>
            null;
      end case;
   end Run_Stats_Save;

   --  The telemetry ports opened or released as their sharing asks, and UART1
   --  back at the MSP rate with a fresh MSP framing when a stream gives it up.
   procedure Check_Telemetry is
      Was         : array (MSP_Line) of Boolean := (others => False);
      Armed       : constant Boolean := Adaflight.STM32.Pilot.Armed;
      Box_Present : constant Boolean := Adaflight.STM32.Pilot.Box_Configured (Adaflight.Modes.Telemetry);
      Box_Active  : constant Boolean := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Telemetry);
   begin
      for L in 1 .. Line_Count loop
         Was (L) := Line_Serial (L) /= Adaflight.STM32.Serial.VCP
                    and then Telemetry_Holds (UART_Of (Line_Serial (L)));
      end loop;
      Adaflight.STM32.FrSky_Hub.Check_State (Armed, Box_Present, Box_Active);
      Adaflight.STM32.SmartPort.Check_State (Armed, Box_Present, Box_Active);
      if Adaflight.Build_Features.LTM_Telemetry then
         Adaflight.STM32.LTM.Check_State (Armed, Box_Present, Box_Active);
      end if;
      if Adaflight.Build_Features.MAVLink_Telemetry then
         Adaflight.STM32.MAVLink.Check_State (Armed, Box_Present, Box_Active, Adaflight.STM32.Time.Millis);
      end if;
      if Adaflight.Build_Features.IBus_Telemetry then
         Adaflight.STM32.IBus.Check_State (Armed, Box_Present, Box_Active);
      end if;
      for L in 1 .. Line_Count loop
         if Was (L) and then not Telemetry_Holds (UART_Of (Line_Serial (L))) then
            Open_Line (L);
         end if;
      end loop;
   end Check_Telemetry;

   --  What the arming logic asked of the board after a step: the GPS home
   --  resets, the flight statistics at arming and disarming, the stick
   --  commands the board can serve, the saves, the trims, the beeper, the
   --  first arming calibration, the headfree offset, the failsafe's
   --  monitoring, the attitude task's rate, the telemetry ports' state and
   --  the DShot commands queued for the motors.
   procedure Apply (Step : Adaflight.Arming.Outputs) is
      Trims : Adaflight.Config_Groups.Integer_16_List_2 renames Config.Accelerometer_Config.Accelerometer_Trims;
      Set   : Boolean;
      Unused_Success : Boolean;
   begin
      for I in 1 .. Step.GPS_Home_Resets loop
         Adaflight.STM32.GPS.Reset_Home;
      end loop;
      for I in 1 .. Step.Stats_Arms loop
         Adaflight.Flight_Stats.On_Arm
           (Stats_Tracker, Adaflight.STM32.Time.Millis, Adaflight.STM32.GPS.Current.Distance_Flown_Cm);
      end loop;
      for I in 1 .. Step.Stats_Disarms loop
         Stats_On_Disarm;
      end loop;
      if Step.Commands (Adaflight.Arming.Gyro_Calibration) then
         Adaflight.Gyro_Filters.Start_Calibration (Gyro_State, Gyro_Settings, First_Arm => False);
      end if;
      if Step.Commands (Adaflight.Arming.Acc_Calibration) then
         Adaflight.Accelerometer.Start_Calibration (Acc_State);
      end if;
      for Profile in Adaflight.Arming.PID_Profile_1 .. Adaflight.Arming.PID_Profile_3 loop
         if Step.Commands (Profile) then
            Config.System_Config.Pid_Profile_Index :=
              Unsigned_8 (Adaflight.Arming.Stick_Command'Pos (Profile)
                          - Adaflight.Arming.Stick_Command'Pos (Adaflight.Arming.PID_Profile_1));
            Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
            Adaflight.STM32.Control.Init (Config, Runtime_Features);
         end if;
      end loop;
      for Profile in Adaflight.Arming.Rate_Profile_1 .. Adaflight.Arming.Rate_Profile_4 loop
         if Step.Commands (Profile) then
            Config.System_Config.Active_Rate_Profile :=
              Unsigned_8 (Adaflight.Arming.Stick_Command'Pos (Profile)
                          - Adaflight.Arming.Stick_Command'Pos (Adaflight.Arming.Rate_Profile_1));
            Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
            Adaflight.STM32.Control.Init (Config, Runtime_Features);
         end if;
      end loop;
      if Step.Trim_Roll /= 0 or else Step.Trim_Pitch /= 0 then
         Trims (0) := Integer_16 (Integer'Max (-300, Integer'Min (300, Integer (Trims (0)) + Step.Trim_Roll)));
         Trims (1) := Integer_16 (Integer'Max (-300, Integer'Min (300, Integer (Trims (1)) + Step.Trim_Pitch)));
      end if;
      if Step.Saves > 0 then
         Write_Configuration;
         Load_Configuration (Unused_Success);
         Confirmation_Beeps (1);
      end if;
      if Step.Beeper.Calls > 0 then
         case Step.Beeper.Last is
            when Adaflight.Arming.Silence => Silence_Beeper;
            when Adaflight.Arming.Arm_Tone => Request_Beep (Adaflight.Beeper.Arming);
            when Adaflight.Arming.Disarm_Tone => Request_Beep (Adaflight.Beeper.Disarming);
            when Adaflight.Arming.Armed_Tone => Request_Beep (Adaflight.Beeper.Armed);
            when Adaflight.Arming.Disarm_Repeat_Tone => Request_Beep (Adaflight.Beeper.Disarm_Repeat);
            when Adaflight.Arming.Rx_Set_Tone => Request_Beep (Adaflight.Beeper.Rx_Set);
            when Adaflight.Arming.Warning_Tones =>
               Adaflight.Beeper.Warning_Beeps (Beep, Beep_Settings, Beep_Conditions, Step.Beeper.Count);
            when Adaflight.Arming.Confirmation_Tones => Confirmation_Beeps (Step.Beeper.Count);
            when Adaflight.Arming.Crash_Flip_Tone => Request_Beep (Adaflight.Beeper.Crash_Flip);
            when Adaflight.Arming.GPS_Fix_Arm_Tone => Request_Beep (Adaflight.Beeper.Arming_GPS_Fix);
            when Adaflight.Arming.GPS_No_Fix_Arm_Tone => Request_Beep (Adaflight.Beeper.Arming_GPS_No_Fix);
            when Adaflight.Arming.Acc_Calibration_Tone => Request_Beep (Adaflight.Beeper.Acc_Calibration);
            when Adaflight.Arming.Acc_Calibration_Fail_Tone => Request_Beep (Adaflight.Beeper.Acc_Calibration_Fail);
         end case;
      end if;
      if Step.First_Arm_Gyro_Cal > 0 then
         Adaflight.Gyro_Filters.Start_Calibration (Gyro_State, Gyro_Settings, First_Arm => True);
      end if;
      if Step.Disarm_Calls > 0 then
         Adaflight.STM32.Blackbox.Disarmed
           (Adaflight.STM32.Pilot.Last_Disarm_Reason, Adaflight.STM32.Time.Micros, Adaflight.STM32.Time.Millis);
      end if;
      if Step.Headfree_Offsets > 0 then
         Adaflight.Attitude.Set_Headfree_Offset (Att_State, Set);
      end if;
      if Step.Start_Failsafe_Monitoring then
         Adaflight.STM32.Radio.Start_Failsafe_Monitoring;
      end if;
      if Step.Attitude_Fast then
         Scheduler.Reschedule (Sched, Sched_Settings, Scheduler.Attitude, Attitude_Period_Fast_Us);
      else
         Scheduler.Reschedule (Sched, Sched_Settings, Scheduler.Attitude, Attitude_Period_Slow_Us);
      end if;
      if Adaflight.Arming."/=" (Step.Telemetry_Ports, Adaflight.Arming.No_Port_Change) then
         Check_Telemetry;
      end if;
      for I in 1 .. Natural'Min (Step.DShot_Commands.Count, Adaflight.Arming.Command_Slot'Last) loop
         Adaflight.STM32.DShot_Output.Write_Command
           (Adaflight.DShot_Command.All_Motors, Adaflight.STM32.Control.Motor_Count,
            Unsigned_8 (Adaflight.Arming.Command_Code (Step.DShot_Commands.Items (I))), Adaflight.DShot_Command.Inline);
      end loop;
   end Apply;

   --  The arming and mode state into the replies: the disable reasons, the
   --  flight mode flags, the active boxes and the armed flag.
   procedure Report_Pilot is
      Status : Adaflight.MSP_Out.Status_Values renames Ctx.Out_Views.State.Status;
   begin
      Status.Arming_Disabled := Adaflight.STM32.Pilot.Disabled;
      Env.Status.Arming_Disabled := Adaflight.STM32.Pilot.Disabled;
      Adaflight.MSP_Box.Pack_Flight_Mode_Flags
        (Active => Offered, Armed => Adaflight.STM32.Pilot.Armed, Flight => Adaflight.STM32.Pilot.Flight_Modes,
         Switches => Adaflight.STM32.Pilot.Active_Boxes, Wing => False, Packed => Status.Mode_Flags,
         Count => Status.Mode_Flag_Count);
      Ctx.Out_Views.Active := Offered;
      Ctx.Control.Armed := Adaflight.STM32.Pilot.Armed;
   end Report_Pilot;

   --  The flight channels of the receiver, as the arming logic and the core
   --  loop read them.
   function Flight_Channels return Adaflight.RC_Command.Channel_Values is
      Channels : Adaflight.RC_Command.Channel_Values := (others => 1_500.0);
   begin
      for Ch in Adaflight.RC_Command.Channel loop
         Channels (Ch) := Float'Max (750.0, Float'Min (2_250.0, Adaflight.STM32.Radio.Channel (Ch)));
      end loop;
      return Channels;
   end Flight_Channels;

   --  The PID loop task: the pass over the control loop with what the board
   --  senses, what the runaway check asked, the gyro's dynamic lowpass at a
   --  new throttle step, and the motor outputs into the motor reply, which
   --  reads them disabled until the motors have a driver.
   --  The first thirty-two boxes active as the log's flight mode word.
   function Box_Word return Unsigned_32 is
      Active : constant Adaflight.Modes.Mask := Adaflight.STM32.Pilot.Active_Boxes;
      Word   : Unsigned_32 := 0;
   begin
      for B in Adaflight.Modes.Box loop
         if Adaflight.Modes.Box'Pos (B) < 32 and then Active (B) then
            Word := Word or Shift_Left (1, Adaflight.Modes.Box'Pos (B));
         end if;
      end loop;
      return Word;
   end Box_Word;

   --  The GPS date and time as seconds since 1970, zero without a valid one
   --  from 1980 on.
   function GPS_Epoch return Unsigned_32 is
      T : constant Adaflight.GPS_Frames.Date_Time := Adaflight.STM32.GPS.Time;
      D : Adaflight.RTC.Date_Time;
      Seconds : Integer_64;
   begin
      if not T.Valid or else T.Year < 1980 or else T.Month not in 1 .. 12 or else T.Day not in 1 .. 31
        or else T.Hour > 23 or else T.Minute > 59 or else T.Second > 60
      then
         return 0;
      end if;
      D := (Year => Unsigned_16 (T.Year), Month => Unsigned_8 (T.Month), Day => Unsigned_8 (T.Day),
            Hours => Unsigned_8 (T.Hour), Minutes => Unsigned_8 (T.Minute), Seconds => Unsigned_8 (T.Second),
            Millis => 0);
      Seconds := Adaflight.RTC.Seconds_Of (Adaflight.RTC.Date_To_Time (D));
      return (if Seconds in 0 .. Integer_64 (Unsigned_32'Last) then Unsigned_32 (Seconds) else 0);
   end GPS_Epoch;

   --  What the log reads from the flight before the pass.
   function Log_Inputs (Now_Us : Unsigned_32) return Adaflight.STM32.Blackbox.Facts is
      pragma Unreferenced (Now_Us);
      F : Adaflight.STM32.Blackbox.Facts;
      G : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Profile : constant Adaflight.PID_Profile.Profile := Adaflight.STM32.Pilot.Profile;
      Small_Angle : constant Boolean := Upright;
   begin
      F.Now_Ms := Adaflight.STM32.Time.Millis;
      F.Arming_Beep_Us := Adaflight.Beeper.Arming_Beep_Time (Beep);
      F.Battery_Voltage := Unsigned_16 (Natural'Min (65_535, Bat.Voltage.Display_Filtered));
      F.VBat_Latest := Unsigned_16 (Natural'Min (65_535, Bat.Voltage.Unfiltered));
      F.Amperage := Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.Amperage)));
      F.RSSI := Adaflight.STM32.Radio.RSSI;
      for A in Adaflight.Axes.Axis loop
         F.Gyro_Filtered (Adaflight.Axes.Axis'Pos (A)) :=
           Float'Max (-1.0e6, Float'Min (1.0e6, Gyro_State.Filtered (A)));
         F.Gyro_Raw (Adaflight.Axes.Axis'Pos (A)) :=
           Float'Max (-1.0e6, Float'Min (1.0e6, Gyro_State.Downsampled (A)));
      end loop;
      F.Acc := (0 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.X)),
                1 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.Y)),
                2 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.Z)));
      F.Quaternion_W := Att_State.Reported.W;
      F.Quaternion_XYZ := (0 => Att_State.Reported.X, 1 => Att_State.Reported.Y, 2 => Att_State.Reported.Z);
      F.Slow :=
        (Flight_Mode_Flags        => Box_Word,
         State_Flags              => (if G.Fix_Home then 1 else 0) or (if G.Fix then 2 else 0)
                                     or (if G.Fix_Ever then 4 else 0) or (if Small_Angle then 16 else 0),
         Failsafe_Phase           => Adaflight.STM32.Radio.Failsafe_Phase,
         RX_Signal_Received       => Adaflight.STM32.Radio.Receiving,
         RX_Flight_Channels_Valid => Adaflight.STM32.Radio.Flight_Channels_Valid);
      F.GPS :=
        (Home          => G.Home,
         Position      => (Lat => G.Latitude, Lon => G.Longitude, Alt_Cm => G.Altitude_Cm),
         Num_Sat       => G.Satellites,
         Speed_3D      => G.Speed_3D,
         Ground_Speed  => G.Ground_Speed,
         Ground_Course => G.Ground_Course,
         Vel_N         => G.Velocity.North,
         Vel_E         => G.Velocity.East,
         Vel_D         => G.Velocity.Down,
         Time_Ms       => G.Time_Ms,
         Epoch         => GPS_Epoch,
         Use_3D_Speed  => G.Use_3D_Speed);
      F.GPS_Feature := Adaflight.STM32.GPS.Enabled;
      F.Conditions.Has_Servos := Adaflight.STM32.Control.Uses_Servos;
      F.Conditions.DShot_Telemetry := False;
      F.Conditions.Acc_Present := Gyro_Report.Acc_Found;
      F.Conditions.Rangefinder_Present := Adaflight.STM32.Rangefinder.Detected;
      F.Surface_Raw := Adaflight.STM32.Rangefinder.Raw_Altitude_Cm;
      F.Baro_Alt := Integer_32 (Float'Max (-2.0e9, Float'Min (2.0e9, Adaflight.STM32.Baro.Altitude_Cm)));
      F.Conditions.RSSI_Configured := Adaflight.STM32.Radio.RSSI_Configured;
      F.Conditions.Debug_Active := Config.System_Config.Debug_Mode /= 0;
      F.Conditions.Voltage_Meter := Bat_Settings.Voltage_Meter;
      F.Conditions.Current_Meter := Bat_Settings.Current_Meter;
      for A in Adaflight.Axes.Axis loop
         F.Conditions.PID_D (Adaflight.Axes.Axis'Pos (A)) := Integer_32 (Profile.Gains (A).D);
      end loop;
      return F;
   end Log_Inputs;

   --  The servo mixer's values in the MSP servo reply.
   procedure Show_Servos is
   begin
      for N in Adaflight.Servo_Mixer.Servo_Index loop
         Ctx.Out_Views.Peripheral.Outputs (N + 1) := Adaflight.STM32.Control.Servo (N);
      end loop;
   end Show_Servos;

   procedure Run_Control (Before : Unsigned_32) is
      Channels : constant Adaflight.RC_Command.Channel_Values := Flight_Channels;
      Mode     : constant Adaflight.Mixer_Init.Mixer_Mode := Adaflight.STM32.Pilot.Mixer_Mode;
      I        : Adaflight.STM32.Control.Inputs;
      Asked    : Adaflight.Arming.Outputs;
      Trims    : Adaflight.Config_Groups.Integer_16_List_2 renames Config.Accelerometer_Config.Accelerometer_Trims;
   begin
      Adaflight.STM32.Blackbox.Set_Facts (Log_Inputs (Before));
      if Adaflight.STM32.Blackbox.Needs_Info then
         Adaflight.STM32.Blackbox.Set_Info (Adaflight.Blackbox_Info.Sysinfo_Of (Config, Log_Facts, Wing => False));
      end if;
      I.Now_Us := Before;
      I.Armed := Adaflight.STM32.Pilot.Armed;
      I.Acc_Present := Gyro_Report.Acc_Found;
      I.Failsafe := Adaflight.STM32.Radio.Failsafe_Active;
      I.Box_3D := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Three_D);
      for A in Adaflight.Axes.Axis loop
         I.Gyro (A) := Float'Max (-Adaflight.PID_Controller.Rate_Bound,
                                  Float'Min (Adaflight.PID_Controller.Rate_Bound, Gyro_State.Filtered (A)));
      end loop;
      I.Gyro_Overflow := Gyro_State.Overflow_Detected;
      I.Yaw_Spin := Gyro_State.Yaw_Spin_Detected;
      I.Attitude := (Adaflight.Axes.Roll => Att_State.Euler.Roll, Adaflight.Axes.Pitch => Att_State.Euler.Pitch);
      I.Trims := (Adaflight.Axes.Roll  => Integer'Max (-300, Integer'Min (300, Integer (Trims (0)))),
                  Adaflight.Axes.Pitch => Integer'Max (-300, Integer'Min (300, Integer (Trims (1)))));
      I.Cos_Tilt := Adaflight.Attitude.Cos_Tilt (Att_State);
      I.Throttle_Correction := Att_State.Throttle_Correction;
      I.Jerk_Magnitude := Acc_State.Jerk_Magnitude;
      I.RC_Data_Throttle := Channels (Adaflight.RC_Command.Throttle_Channel);
      I.Autopilot_Throttle := Alt_Hold_State.Control.Throttle_Out;
      I.Autopilot_Angles :=
        (Adaflight.Axes.Roll  => Pos_Hold_State.Control.Angle_Roll,
         Adaflight.Axes.Pitch => Pos_Hold_State.Control.Angle_Pitch);
      I.Autopilot_Max_Angle := Control_Settings.Max_Angle;
      I.Autopilot_Control := Adaflight.Position_Hold.In_Control (Pos_Hold_State);
      I.Below_Landing :=
        Pos_State.Control_Altitude_Cm < 100.0 * Float (Config.Autopilot_Config.Landing_Altitude_M);
      I.Battery_Voltage := Unsigned_16 (Bat.Voltage.Display_Filtered);
      I.Sag_Cell_Voltage := Adaflight.Battery.Sag_Cell_Voltage (Bat);
      I.Battery_Latest := Bat.Voltage.Unfiltered;
      if Adaflight.STM32.Control.Uses_Servos then
         Adaflight.STM32.Control.Set_Servo_Config (Config);
      end if;
      Adaflight.STM32.Control.Pass
        (I, Sense, Channels,
         Resets_Yaw  => Adaflight.Core_Loop.Resets_Yaw
                          (Adaflight.STM32.Pilot.Sticks_Arm, Channels (Adaflight.RC_Command.Throttle_Channel),
                           Natural (Config.Rx_Config.Mincheck), Mode, Config.Servo_Config.Tri_Unarmed_Servo /= 0),
         Log_Device  => Adaflight.STM32.Blackbox.Device_Set,
         CLI_Open    => Session.Open,
         PID_Audio   => Adaflight.STM32.Pilot.PID_Audio_Present,
         Asked       => Asked);
      Apply (Asked);
      if Adaflight.STM32.Control.Uses_Servos then
         Show_Servos;
      end if;
      if Adaflight.STM32.Control.Throttle_Step_Changed then
         Adaflight.Gyro_Filters.Update_Dynamic_Lowpass
           (Gyro_State, Gyro_Settings, Adaflight.STM32.Control.Throttle_Step);
      end if;
      Ctx.Out_Views.State.Motors.Enabled := Adaflight.STM32.Motors.Enabled;
      for M in Adaflight.MSP_Out.Motor_Index loop
         Ctx.Out_Views.State.Motors.Motor_Enabled (M) := Adaflight.STM32.Motors.Motor_Enabled (M);
         Ctx.Out_Views.State.Motors.External (M) :=
           (if Adaflight.MSP_Motor_In."=" (Adaflight.STM32.Motors.Device, Adaflight.MSP_Motor_In.DShot)
            then Unsigned_16 (Adaflight.DShot.To_External
                                (Adaflight.STM32.Control.Motors (M),
                                 (Runtime_Features and Adaflight.Config_Fix.Feature_3D) /= 0))
            else Unsigned_16
                   (Float'Truncation (Float'Max (0.0, Float'Min (65_535.0, Adaflight.STM32.Control.Motors (M))))));
      end loop;
   end Run_Control;

   --  The receiver task's state machine: the rate ignored on every step but
   --  the last, the check step through the link and the arming's receiver
   --  pass with the frame rate, the modes step through the arming's modes
   --  pass over the auxiliary channels, the update step through the RC
   --  commands and the arming status, then what the passes asked, the step's
   --  estimate for the scheduler and the channels into the RC reply.
   --  The arming disable reasons other units decide: the failsafe's lost link
   --  and active failsafe, and the command line's hold while its session is
   --  open.
   procedure Sync_Reasons is
   begin
      Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.Rx_Loss, Adaflight.STM32.Radio.Failsafe_Rx_Loss);
      Adaflight.STM32.Pilot.Set_Reason
        (Adaflight.Arming.Failsafe_Active, Adaflight.STM32.Radio.Failsafe_Blocks_Arming);
      Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.CLI_Open, Session.Arming_Held);
      Adaflight.STM32.Pilot.Set_Reason
        (Adaflight.Arming.CMS_Open, Adaflight.Build_Features.Menus and then Adaflight.STM32.Menu.Arming_Held);
      Adaflight.STM32.Pilot.Set_Reason
        (Adaflight.Arming.Reboot_Required,
         Adaflight.Build_Features.Menus and then Adaflight.STM32.Menu.Reboot_Required);
   end Sync_Reasons;

   --  The names the OSD shows for each adjustment.
   --  The adjustment labels in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Adjustment_Label_Pool_Length : constant := 282;
   Adjustment_Label_Text : constant String (1 .. Adjustment_Label_Pool_Length + 24) :=
     "RC RATERC EXPOTHROTTLE EXPOROLL RATEYAW RATEPITCH/ROLL PPITCH/ROLL IPITCH/ROLL DYAW PYAW IYAW DRATE PROF"
     & "ILEPITCH RATEPITCH PPITCH IPITCH DRC RATE YAWPITCH/ROLL FFF TRANSITIONHORIZON STRENGTHPID AUDIOPITCH FYA"
     & "W FOSD PROFILELED PROFILELED DIMMERSLIDER MASTER MULTIPLIERBATTERY PROFILE                        ";
   type Adjustment_Label_Start is range 0 .. Adjustment_Label_Pool_Length;
   type Adjustment_Label_Length is range 0 .. 24;
   Adjustment_Label_Starts : constant array (Adaflight.Adjustments.Function_Kind) of Adjustment_Label_Start :=
     (Adaflight.Adjustments.None => 0, Adaflight.Adjustments.RC_Rate => 0, Adaflight.Adjustments.RC_Expo => 7,
      Adaflight.Adjustments.Throttle_Expo => 14, Adaflight.Adjustments.Pitch_Roll_Rate => 27,
      Adaflight.Adjustments.Yaw_Rate => 36, Adaflight.Adjustments.Pitch_Roll_P => 44,
      Adaflight.Adjustments.Pitch_Roll_I => 56, Adaflight.Adjustments.Pitch_Roll_D => 68,
      Adaflight.Adjustments.Yaw_P => 80, Adaflight.Adjustments.Yaw_I => 85, Adaflight.Adjustments.Yaw_D => 90,
      Adaflight.Adjustments.Rate_Profile => 95, Adaflight.Adjustments.Pitch_Rate => 107,
      Adaflight.Adjustments.Roll_Rate => 27, Adaflight.Adjustments.Pitch_P => 117,
      Adaflight.Adjustments.Pitch_I => 124, Adaflight.Adjustments.Pitch_D => 131,
      Adaflight.Adjustments.Roll_P => 50, Adaflight.Adjustments.Roll_I => 62, Adaflight.Adjustments.Roll_D => 74,
      Adaflight.Adjustments.RC_Rate_Yaw => 138, Adaflight.Adjustments.Pitch_Roll_F => 149,
      Adaflight.Adjustments.Feedforward_Transition => 161, Adaflight.Adjustments.Horizon_Strength => 174,
      Adaflight.Adjustments.PID_Audio => 190, Adaflight.Adjustments.Pitch_F => 199,
      Adaflight.Adjustments.Roll_F => 155, Adaflight.Adjustments.Yaw_F => 206,
      Adaflight.Adjustments.OSD_Profile => 211, Adaflight.Adjustments.LED_Profile => 222,
      Adaflight.Adjustments.LED_Dimmer => 233, Adaflight.Adjustments.Master_Multiplier => 243,
      Adaflight.Adjustments.Battery_Profile => 267);
   Adjustment_Label_Lengths : constant array (Adaflight.Adjustments.Function_Kind) of Adjustment_Label_Length :=
     (Adaflight.Adjustments.None => 0, Adaflight.Adjustments.RC_Rate => 7, Adaflight.Adjustments.RC_Expo => 7,
      Adaflight.Adjustments.Throttle_Expo => 13, Adaflight.Adjustments.Pitch_Roll_Rate => 9,
      Adaflight.Adjustments.Yaw_Rate => 8, Adaflight.Adjustments.Pitch_Roll_P => 12,
      Adaflight.Adjustments.Pitch_Roll_I => 12, Adaflight.Adjustments.Pitch_Roll_D => 12,
      Adaflight.Adjustments.Yaw_P => 5, Adaflight.Adjustments.Yaw_I => 5, Adaflight.Adjustments.Yaw_D => 5,
      Adaflight.Adjustments.Rate_Profile => 12, Adaflight.Adjustments.Pitch_Rate => 10,
      Adaflight.Adjustments.Roll_Rate => 9, Adaflight.Adjustments.Pitch_P => 7, Adaflight.Adjustments.Pitch_I => 7,
      Adaflight.Adjustments.Pitch_D => 7, Adaflight.Adjustments.Roll_P => 6, Adaflight.Adjustments.Roll_I => 6,
      Adaflight.Adjustments.Roll_D => 6, Adaflight.Adjustments.RC_Rate_Yaw => 11,
      Adaflight.Adjustments.Pitch_Roll_F => 12, Adaflight.Adjustments.Feedforward_Transition => 13,
      Adaflight.Adjustments.Horizon_Strength => 16, Adaflight.Adjustments.PID_Audio => 9,
      Adaflight.Adjustments.Pitch_F => 7, Adaflight.Adjustments.Roll_F => 6, Adaflight.Adjustments.Yaw_F => 5,
      Adaflight.Adjustments.OSD_Profile => 11, Adaflight.Adjustments.LED_Profile => 11,
      Adaflight.Adjustments.LED_Dimmer => 10, Adaflight.Adjustments.Master_Multiplier => 24,
      Adaflight.Adjustments.Battery_Profile => 15);

   function Adjustment_Label (K : Adaflight.Adjustments.Function_Kind) return String is
     (Adjustment_Label_Text (Natural (Adjustment_Label_Starts (K)) + 1
                             .. Natural (Adjustment_Label_Starts (K)) + Natural (Adjustment_Label_Lengths (K))));

   --  The adjustment fields of a rate profile and a PID profile written back
   --  to the stored ones where the pass changed them, so the stored values the
   --  pass did not touch keep their own.
   procedure Store_Rates
     (Stored : in out Adaflight.Config_Groups.Control_Rate_Config_Record; Was, Now : Adaflight.Rates.Profile)
   is
      use type Adaflight.Rates.Profile;
      Axes : constant array (0 .. 2) of Adaflight.Axes.Axis :=
        (Adaflight.Axes.Roll, Adaflight.Axes.Pitch, Adaflight.Axes.Yaw);
   begin
      if Was = Now then
         return;
      end if;
      for I in Axes'Range loop
         if Now.RC_Rates (Axes (I)) /= Was.RC_Rates (Axes (I)) then
            Stored.Rc_Rates (I) := Unsigned_8 (Now.RC_Rates (Axes (I)));
         end if;
         if Now.RC_Expo (Axes (I)) /= Was.RC_Expo (Axes (I)) then
            Stored.Rc_Expo (I) := Unsigned_8 (Now.RC_Expo (Axes (I)));
         end if;
         if Now.Super_Rates (Axes (I)) /= Was.Super_Rates (Axes (I)) then
            Stored.Rates (I) := Unsigned_8 (Now.Super_Rates (Axes (I)));
         end if;
      end loop;
      if Now.Throttle_Expo /= Was.Throttle_Expo then
         Stored.Thr_Expo8 := Unsigned_8 (Now.Throttle_Expo);
      end if;
   end Store_Rates;

   procedure Store_PID
     (Stored : in out Adaflight.Config_Groups.Pid_Profile_Record; Was, Now : Adaflight.PID_Profile.Profile)
   is
      Axes : constant array (0 .. 2) of Adaflight.Axes.Axis :=
        (Adaflight.Axes.Roll, Adaflight.Axes.Pitch, Adaflight.Axes.Yaw);
   begin
      for I in Axes'Range loop
         declare
            G : Adaflight.PID_Profile.Axis_Gains renames Now.Gains (Axes (I));
            W : Adaflight.PID_Profile.Axis_Gains renames Was.Gains (Axes (I));
         begin
            if G.P /= W.P then
               Stored.Pid (I).P := Unsigned_8 (G.P);
            end if;
            if G.I /= W.I then
               Stored.Pid (I).I := Unsigned_8 (G.I);
            end if;
            if G.D /= W.D then
               Stored.Pid (I).D := Unsigned_8 (G.D);
            end if;
            if G.F /= W.F then
               Stored.Pid (I).F := Unsigned_16 (G.F);
            end if;
         end;
         if Now.D_Max (Axes (I)) /= Was.D_Max (Axes (I)) then
            Stored.D_Max (I) := Unsigned_8 (Now.D_Max (Axes (I)));
         end if;
      end loop;
      if Now.Level.D /= Was.Level.D then
         Stored.Pid (3).D := Unsigned_8 (Now.Level.D);
      end if;
      if Now.Feedforward_Transition /= Was.Feedforward_Transition then
         Stored.Feedforward_Transition := Unsigned_8 (Now.Feedforward_Transition);
      end if;
      if Now.Simplified_Master_Multiplier /= Was.Simplified_Master_Multiplier then
         Stored.Simplified_Master_Multiplier := Unsigned_8 (Now.Simplified_Master_Multiplier);
      end if;
   end Store_PID;

   --  One adjustment pass over the stored rate and PID profiles: the ranges'
   --  lists rebuilt when the stored ranges changed, the selections taken from
   --  the configuration, the changed values and selections written back, the
   --  profiles' users configured again as the pass asks, and the
   --  confirmation beeps.
   procedure Run_Adjustments (Aux : Adaflight.Modes.Aux_Values) is
      use type Adaflight.Adjustments.Ranges;
      Ranges : constant Adaflight.Adjustments.Ranges := Adaflight.MSP_Views.Adjustment_Ranges (Config);
      P_Idx  : constant Natural := Natural'Min (3, Natural (Config.System_Config.Pid_Profile_Index));
      Rates  : Adaflight.Adjustments.Rate_Profiles;
      Was_R  : Adaflight.Adjustments.Rate_Profiles;
      P      : Adaflight.PID_Profile.Profile := Adaflight.Config_Runtime.PID_Profile_Of (Config.Pid_Profiles (P_Idx));
      Was_P  : constant Adaflight.PID_Profile.Profile := P;
      Sel    : Adaflight.Adjustments.Selections renames Adj_State.Selected;
      Rate_Was : Natural;
      Result : Adaflight.Adjustments.Outputs;
   begin
      if Ranges /= Adj_Ranges then
         Adj_Ranges := Ranges;
         Adaflight.Adjustments.Reset_List (Adj_State);
      end if;
      for I in Rates'Range loop
         Rates (I) := Adaflight.Config_Runtime.Rate_Profile_Of (Config.Control_Rate_Profiles (I));
      end loop;
      Was_R := Rates;
      Sel.Rate_Profile := Natural'Min (3, Natural (Config.System_Config.Active_Rate_Profile));
      Sel.Battery_Profile := Natural'Min (2, Natural (Config.System_Config.Active_Battery_Profile));
      Sel.LED_Profile := Natural'Min (2, Natural (Config.Led_Strip_Config.Ledstrip_Profile));
      Sel.LED_Brightness := Natural (Config.Led_Strip_Config.Ledstrip_Brightness);
      Rate_Was := Sel.Rate_Profile;
      Adaflight.Adjustments.Process
        (Adj_State, Adaflight.Config_Runtime.Adjustment_Settings_Of (Config.Rx_Config, Config.System_Config),
         Adj_Ranges, Rates, P,
         (Now_Ms => Adaflight.STM32.Time.Millis, Rx_Signal => Adaflight.STM32.Radio.Receiving, Aux => Aux),
         Result);
      for I in Rates'Range loop
         Store_Rates (Config.Control_Rate_Profiles (I), Was_R (I), Rates (I));
      end loop;
      Store_PID (Config.Pid_Profiles (P_Idx), Was_P, P);
      Config.System_Config.Active_Rate_Profile := Unsigned_8 (Sel.Rate_Profile);
      Config.System_Config.Active_Battery_Profile := Unsigned_8 (Sel.Battery_Profile);
      Config.Led_Strip_Config.Ledstrip_Profile := Unsigned_8 (Sel.LED_Profile);
      Config.Led_Strip_Config.Ledstrip_Brightness := Unsigned_8 (Sel.LED_Brightness);
      if Result.PID_Reinit or else Result.RC_Reinit or else Sel.Rate_Profile /= Rate_Was then
         Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
         Adaflight.STM32.Control.Init (Config, Runtime_Features);
      end if;
      if Result.Battery_Reinit then
         Bat_Settings := Battery_Settings;
      end if;
      if Result.Beep_Requests > 0 then
         Confirmation_Beeps (Result.Beeps);
      end if;
   end Run_Adjustments;

   --  The display port command the receiver took: the menu opened on the
   --  CRSF display at the size the command set, or left; then the menu's
   --  state the display's transfer waits on.
   procedure Run_Display_Command is
      Request : Adaflight.CRSF_Display_Port.Menu_Request;
      Opened  : Boolean;
   begin
      Adaflight.STM32.Radio.Display_Command
        (Adaflight.STM32.Time.Millis, Adaflight.STM32.Pilot.Armed, Adaflight.STM32.Menu.Open,
         Adaflight.STM32.Menu.CRSF_Registered, Request);
      case Request is
         when Adaflight.CRSF_Display_Port.Open =>
            Adaflight.STM32.Menu.Resize_CRSF
              (Adaflight.STM32.Radio.Display_Columns, Adaflight.STM32.Radio.Display_Rows);
            Adaflight.STM32.Menu.Open_On_CRSF (Config, Opened);
            if Opened then
               Adaflight.STM32.Radio.Display_Opened (Adaflight.STM32.Time.Millis);
            end if;
         when Adaflight.CRSF_Display_Port.Leave =>
            Adaflight.STM32.Menu.Leave;
         when Adaflight.CRSF_Display_Port.None =>
            null;
      end case;
      Adaflight.STM32.Radio.Set_Menu_State (Adaflight.STM32.Menu.Open, Adaflight.STM32.Menu.On_CRSF);
   end Run_Display_Command;

   procedure Run_Receiver (Before : Unsigned_32) is
      Step        : constant Adaflight.RX_Task.Step := Adaflight.RX_Task.Current_Step (RX_State);
      Ready       : Boolean := True;
      Anticipated : constant Scheduler.Time_Delta := Scheduler.Next_State_Time (Sched);
      Next        : Integer_32;
      Channels    : Adaflight.RC_Command.Channel_Values := (others => 1_500.0);
      Aux         : Adaflight.Modes.Aux_Values := (others => 1_500.0);
      Asked       : Adaflight.Arming.Outputs;
      Delta_Us    : constant Natural := Natural (Integer_32'Max (0, Scheduler.Task_Delta_Time (Sched, Scheduler.Rx)));
   begin
      if Adaflight.RX_Task.Ignore_Rate (RX_State) then
         Scheduler.Ignore_Task_Exec_Rate (Sched);
      end if;
      Sync_Reasons;
      Channels := Flight_Channels;
      for A in Adaflight.Modes.Aux_Channel loop
         Aux (A) := Adaflight.STM32.Radio.Channel (A + Adaflight.Receiver.Flight_Channel_Count);
      end loop;
      case Step is
         when Adaflight.RX_Task.Check =>
            Receiver_Step
              (Before, Adaflight.STM32.Time.Millis,
               (if Adaflight.STM32.Radio.RSSI_ADC
                then Analog (Config.Adc_Config.Rssi) else 0),
               Ready);
            if Adaflight.Build_Features.Menus then
               Run_Display_Command;
            end if;
            if Ready then
               Adaflight.STM32.Pilot.Update_Refresh_Rate
                 (Before, Adaflight.STM32.Radio.Receiving, Adaflight.STM32.Radio.Last_Frame_Us);
               Adaflight.STM32.Pilot.Receiver_Pass (Sense, Channels, Before, Asked);
               Adaflight.STM32.Control.Set_Stabilisation (Asked.Stabilisation_On, Asked.Iterm_Reset);
            end if;
         when Adaflight.RX_Task.Modes =>
            Adaflight.STM32.Pilot.Modes_Pass (Sense, Channels, Aux, Before, Delta_Us, Asked);
            if Asked.Run_Adjustments then
               Run_Adjustments (Aux);
            end if;
            Adaflight.STM32.VTX.Switches (Config, Aux, Adaflight.STM32.Pilot.Armed);
            Adaflight.STM32.Control.Set_Anti_Gravity (Asked.Anti_Gravity);
         when Adaflight.RX_Task.Update =>
            Adaflight.STM32.Pilot.Update_Pass
              (Sense, Channels,
               (Box_3D => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Three_D),
                LVC_Enabled => Bat.LVC_Enabled, LVC_Percentage => Bat.LVC_Percentage,
                Failsafe_Active => Adaflight.STM32.Radio.Failsafe_Active),
               Att_State, Before, Asked);
      end case;
      Apply (Asked);
      Report_Pilot;
      Adaflight.RX_Task.Finish
        (RX_State, Rx_Ready => Ready, Ignore_Exec_Time => Scheduler.Ignoring_Task_Exec_Time (Sched),
         Anticipated_Us => Adaflight.RX_Task.Execution_Us
           (Integer_32'Max (0, Integer_32'Min (Adaflight.RX_Task.Max_Execution_Us, Anticipated))),
         Elapsed_Us => Adaflight.STM32.Time.Micros - Before + 1, Next_State_Us => Next);
      Scheduler.Set_Next_State_Time (Sched, Next);
      Ctx.Out_Views.State.RC.Count :=
        Natural'Min (Adaflight.STM32.Radio.Channel_Count, Adaflight.MSP_Out.Channel_Count);
      for I in 0 .. Ctx.Out_Views.State.RC.Count - 1 loop
         Ctx.Out_Views.State.RC.Channels (I) :=
           Float'Max (0.0, Float'Min (65_535.0, Adaflight.STM32.Radio.Channel (I)));
      end loop;
   end Run_Receiver;

   --  The OSD task: the flight's readings for the frame, then one state of
   --  the task on the display.
   procedure Run_OSD (Before : Unsigned_32) is
      F        : Adaflight.STM32.OSD.Facts;
      Channels : constant Adaflight.RC_Command.Channel_Values := Flight_Channels;
      Outputs  : constant Adaflight.Mixer.Motor_Outputs := Adaflight.STM32.Control.Motors;
      Motors   : constant Natural := Natural'Max (1, Natural'Min (8, Adaflight.STM32.Control.Motor_Count));
      Volts    : constant Natural := Natural'Min (20_000, Bat.Voltage.Display_Filtered);
      Throttle : constant Float := Adaflight.STM32.Pilot.Throttle_Command;
      Profile  : Adaflight.Config_Groups.Battery_Profile_Record renames
        Config.Battery_Profiles (Natural'Min (2, Natural (Config.System_Config.Active_Battery_Profile)));
   begin
      F.Armed := Adaflight.STM32.Pilot.Armed;
      F.Was_Ever_Armed := Adaflight.STM32.Pilot.Was_Ever_Armed;
      F.Failsafe_Active := Adaflight.STM32.Radio.Failsafe_Active;
      F.Trying_To_Arm := Adaflight.STM32.Pilot.Trying_To_Arm;
      F.Arm_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Arm);
      F.OSD_Switch := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.OSD);
      F.Disabled := Adaflight.STM32.Pilot.Disabled;
      F.Modes := Adaflight.STM32.Pilot.Flight_Modes;
      F.Airmode := Adaflight.STM32.Pilot.Airmode_Enabled;
      F.Crash_Flip_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Crash_Flip);
      F.Crash_Flip_Active := Adaflight.STM32.Pilot.Crash_Flip_Active;
      F.Upright := Upright;
      F.Small_Angle := Config.Imu_Config.Small_Angle;
      F.Ready_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Ready);
      F.Acro_Trainer_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Acro_Trainer);
      F.Antenna := Adaflight.STM32.Radio.Active_Antenna;
      Adaflight.STM32.VTX.OSD_Readings
        (F.VTX_Present, F.VTX_Status_OK, F.VTX_Status, F.VTX_Power_OK, F.VTX_Power_Index);
      F.VTX_Disable_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.VTX_Control_Disable);
      F.VTX_Table := Adaflight.STM32.VTX.Table;
      for C in Adaflight.Vectors.Coordinate loop
         F.Earth_Up (Adaflight.Vectors.Coordinate'Pos (C)) :=
           Float'Max (-1.0, Float'Min (1.0, Att_State.Rotation (Adaflight.Vectors.Z, C)));
      end loop;
      F.Launch_Control := Adaflight.STM32.Pilot.Launch_Control_Active;
      F.Acc_Present := Gyro_Report.Acc_Found;
      F.G_Force := Float'Max (0.0, Float'Min (100.0, Acc_State.Magnitude));
      F.Roll := Integer_16 (Att_State.Euler.Roll);
      F.Pitch := Integer_16 (Att_State.Euler.Pitch);
      F.Yaw :=
        Adaflight.OSD_Render.Yaw_Decidegrees (Integer'Max (0, Integer'Min (3_599, Integer (Att_State.Euler.Yaw))));
      F.Throttle_Percent := Integer'Max (0, Integer'Min (100, (Integer (Float'Rounding (Throttle)) - 1_000) / 10));
      declare
         Aux : constant Natural :=
           Natural (Config.Osd_Config.Aux_Channel) + Adaflight.Receiver.Flight_Channel_Count - 1;
      begin
         F.Aux_Rc :=
           (if Aux <= Adaflight.Receiver.Channel'Last
            then Float'Max (0.0, Float'Min (5_000.0, Adaflight.STM32.Radio.Channel (Aux)))
            else 1_000.0);
      end;
      F.Throttle_High := Channels (Adaflight.RC_Command.Throttle_Channel) > 1_750.0;
      F.Pitch_High := Channels (1) > 1_750.0;
      F.RSSI_Percent := Unsigned_8'Min (100, Adaflight.STM32.Radio.RSSI_Percent);
      F.RSSI_Dbm := Adaflight.STM32.Radio.RSSI_Dbm;
      F.RSNR := Adaflight.STM32.Radio.RSNR;
      F.Link_Quality := Unsigned_16'Min (1_023, Adaflight.STM32.Radio.Link_Quality);
      F.Link_Percent := Unsigned_16'Min (300, Adaflight.STM32.Radio.Link_Quality_Percent);
      F.Link_Source :=
        Adaflight.OSD_Render.Link_Quality_Source'Val
          (Adaflight.Receiver.Link_Quality_Source'Pos (Adaflight.STM32.Radio.Link_Source));
      F.RF_Mode := Unsigned_8 (Natural'Min (255, Adaflight.STM32.Radio.RF_Mode));
      F.Uplink_mW := Adaflight.STM32.Radio.Uplink_Power_mW;
      F.GPS_Feature := Adaflight.STM32.GPS.Enabled;
      F.GPS := Adaflight.STM32.GPS.Current;
      F.Battery := Bat.Overall;
      F.Pack_Voltage := Unsigned_16 (Volts);
      F.Cell_Voltage := (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0);
      F.Full_Cell_Voltage := Unsigned_16 (Bat_Settings.Full_Cell_Voltage);
      F.Amperage := Integer_32'Max (-100_000, Integer_32'Min (100_000, Integer_32 (Bat.Current.Amperage)));
      F.MAh_Drawn := Integer_32'Max (0, Integer_32'Min (2 ** 24, Integer_32 (Bat.Current.mAh_Drawn)));
      F.Wh_Drawn := Bat.Watt_Hours;
      F.Blackbox_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Blackbox);
      if F.Blackbox_Box then
         Adaflight.STM32.Blackbox.Device_State (F.Blackbox_Working, F.Blackbox_Full, F.Log_Number);
      end if;
      F.Battery_Percent := Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings));
      F.Battery_Capacity := Profile.Battery_Capacity;
      F.Motors := Motors;
      F.Altitude_Cm := Integer_32'Max (-40_000_000, Integer_32'Min (40_000_000, Estimated_Altitude_Cm));
      F.Rangefinder_Cm := Adaflight.STM32.Rangefinder.Altitude_Cm;
      F.Custom_Text := Adaflight.STM32.OSD_Custom_Text.Text;
      F.Lap := Lap;
      F.Lap_Clock_Ms := Lap_Clock_Ms (F.GPS);
      F.Vario := Estimated_Vario;
      F.Pos_Hold_Ready := Pos_Hold_Ready;
      F.Pos_Hold_Failure := Pos_Hold_Failure;
      F.Rescue_Configured := Rescue_Configured;
      F.Rescue_Available := Rescue_State.Is_Available;
      F.Rescue_OK := Rescue_State.Is_OK;
      F.Rescue_Heading_OK := Rescue_State.Sense.Heading_OK;
      for I in 0 .. Motors - 1 loop
         F.Motor_Output (I) := Float'Min (3_000.0, Outputs (I));
         F.Motor_Active (I) := Outputs (I) > Adaflight.STM32.Control.Disarm_Output;
      end loop;
      F.Motors_Running := Adaflight.STM32.Control.Motors_Running;
      F.ESC_Feature := Adaflight.STM32.ESC_Sensor.Feature_On;
      if F.ESC_Feature then
         F.ESC_Erpm_To_Hz := Float'Min (1.0, Adaflight.STM32.ESC_Sensor.Erpm_Factor);
         Adaflight.STM32.ESC_Sensor.Combined (Adaflight.STM32.Control.Motor_Count, F.ESC_Combined);
         for M in F.ESC_Motors'Range loop
            F.ESC_Motors (M) := Adaflight.STM32.ESC_Sensor.Motor_Reading (M);
         end loop;
      end if;
      if Adaflight.Adjustments."/=" (Adj_State.Shown.Kind, Adaflight.Adjustments.None) then
         declare
            Label : constant String := Adjustment_Label (Adj_State.Shown.Kind);
            Shown : constant Natural := Natural'Min (Label'Length, Adaflight.OSD_Render.Max_Name);
         begin
            F.Adjustment_Present := True;
            F.Adjustment_Name.Length := Shown;
            F.Adjustment_Name.Data (1 .. Shown) := Label (Label'First .. Label'First + Shown - 1);
            F.Adjustment_Value := Integer_32 (Adj_State.Shown.Value);
         end;
      end if;
      F.Total_Flights := Config.Stats_Config.Stats_Total_Flights;
      F.Core_Temperature := Internal.Core_Temperature;
      F.Total_Time_S := Config.Stats_Config.Stats_Total_Time_S;
      F.Total_Dist_M := Config.Stats_Config.Stats_Total_Dist_M;
      F.PID_Index := Config.System_Config.Pid_Profile_Index;
      F.Rate_Index := Config.System_Config.Active_Rate_Profile;
      declare
         P : Adaflight.Config_Groups.Pid_Profile_Record renames
           Config.Pid_Profiles (Natural'Min (3, Natural (Config.System_Config.Pid_Profile_Index)));
      begin
         for A in Adaflight.OSD_Render.Axis_Index loop
            F.PIDs (A) := (P => P.Pid (A).P, I => P.Pid (A).I, D => P.Pid (A).D, D_Max => P.D_Max (A),
                           F => P.Pid (A).F);
         end loop;
         F.PID_Profile_Name := P.Profile_Name;
      end;
      F.Rate_Profile_Name :=
        Config.Control_Rate_Profiles (Natural'Min (3, Natural (Config.System_Config.Active_Rate_Profile))).Profile_Name;
      F.Craft_Name := Config.Pilot_Config.Craft_Name;
      F.Pilot_Name := Config.Pilot_Config.Pilot_Name;
      F.Messages := Config.Pilot_Config.Message;
      Adaflight.STM32.OSD.Run (F, Before, Sched);
      if Config.Osd_Config.Osd_Craftname_Msgs /= 0 then
         Config.Pilot_Config.Craft_Name := Adaflight.STM32.OSD.Craft_Name;
      end if;
   end Run_OSD;

   --  The menu task: the flight's readings for the pass, one pass of the
   --  menu system, then its requests: the calibrations, the OSD's elements,
   --  the profiles, the configuration written and the reset.
   procedure Run_Menu (Before : Unsigned_32) is
      F : Adaflight.STM32.Menu.Facts;
      R : Adaflight.STM32.Menu.Requests;
   begin
      F.Channels := Flight_Channels;
      for A in 0 .. 3 loop
         F.Aux (A) := Float'Max (750.0, Float'Min (2_250.0, Adaflight.STM32.Radio.Channel
                                                                (A + Adaflight.Receiver.Flight_Channel_Count)));
      end loop;
      F.Armed := Adaflight.STM32.Pilot.Armed;
      F.Paralyzed := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Paralyze);
      F.Stick_Commands_Disabled := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Stick_Command_Disable);
      F.Acc_Present := Gyro_Report.Acc_Found;
      F.Acc_Calibration_Complete := Adaflight.Accelerometer.Calibration_Complete (Acc_State);
      F.Acc_Calibrated := Config.Accelerometer_Config.Acc_Zero (3) /= 0;
      F.Gyro_Present := Selection.Found;
      F.Gyro_Calibration_Complete := Adaflight.Gyro_Filters.Calibration_Complete (Gyro_State);
      F.PID_Frequency := Float'Min (65_535.0, 1.0e6 / Float (Natural'Max (1, Natural (Sample_Us))));
      F.Runtime_Features := Runtime_Features;
      F.Gate_Set_Readings := Lap.Set_Readings;
      F.Gate_Distance_Cm := Lap.Distance_To_Gate_Cm;
      Adaflight.STM32.Menu.Run (Config, F, Before, Adaflight.STM32.Time.Millis, R);
      Adaflight.STM32.Radio.Set_Menu_State (Adaflight.STM32.Menu.Open, Adaflight.STM32.Menu.On_CRSF);
      if R.Acc_Calibration then
         Adaflight.Accelerometer.Start_Calibration (Acc_State);
      end if;
      if R.Gyro_Calibration then
         Adaflight.Gyro_Filters.Start_Calibration (Gyro_State, Gyro_Settings, First_Arm => False);
      end if;
      if R.Gate_Start then
         Adaflight.GPS_Lap_Timer.Start_Set_Gate (Lap);
      end if;
      if R.Gate_End then
         declare
            Lap_Settings : Adaflight.GPS_Lap_Timer.Settings :=
              Adaflight.Config_Runtime.Lap_Timer_Settings_Of (Config.Gps_Lap_Timer_Config);
         begin
            Adaflight.GPS_Lap_Timer.End_Set_Gate (Lap, Lap_Settings);
            Config.Gps_Lap_Timer_Config.Gate_Lat := Lap_Settings.Gate_Lat;
            Config.Gps_Lap_Timer_Config.Gate_Lon := Lap_Settings.Gate_Lon;
            Adaflight.STM32.Menu.Set_Gate (Lap_Settings.Gate_Lat, Lap_Settings.Gate_Lon);
         end;
      end if;
      if R.PID_Profile then
         Config.System_Config.Pid_Profile_Index := Unsigned_8'Min (3, R.PID_Profile_Idx);
      end if;
      if R.Rate_Profile then
         Config.System_Config.Active_Rate_Profile := Unsigned_8'Min (3, R.Rate_Profile_Idx);
      end if;
      if R.OSD_Profile then
         Config.Osd_Config.Osd_Profile_Index := Unsigned_8'Max (1, Unsigned_8'Min (3, R.OSD_Profile_Idx));
      end if;
      if R.PID_Profile or else R.Rate_Profile or else R.PID_Init then
         Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
         Adaflight.STM32.Control.Init (Config, Runtime_Features);
      end if;
      if R.Elements or else R.OSD_Profile or else R.PID_Profile or else R.Rate_Profile then
         Adaflight.STM32.OSD.Configure (Config, Version_Text);
         Adaflight.STM32.OSD.Analyze_Again;
      end if;
      if R.Save then
         Scheduler.Ignore_Task_State_Time (Sched);
         Write_Configuration;
      end if;
      if R.Reset then
         Reset;
      end if;
   end Run_Menu;

   --  The GPS readings into the replies and the status.
   procedure Report_GPS is
      G : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      T : constant Adaflight.GPS_Frames.Date_Time := Adaflight.STM32.GPS.Time;
      V : Adaflight.MSP_Out.GPS_Values renames Ctx.Out_Views.State.GPS;
   begin
      V.Fix := G.Fix;
      V.Satellite_Count := G.Satellites;
      V.Latitude := G.Latitude;
      V.Longitude := G.Longitude;
      V.Altitude_Cm := G.Altitude_Cm;
      V.Ground_Speed := G.Ground_Speed;
      V.Ground_Course := G.Ground_Course;
      V.PDOP := G.PDOP;
      V.HDOP := G.HDOP;
      V.VDOP := G.VDOP;
      V.In_View := G.In_View;
      V.Distance_To_Home := G.Distance_To_Home_M;
      V.Direction_To_Home := G.Direction_To_Home;
      V.Update := Boolean'Pos (G.Tick);
      V.Channels := Natural'Min (Adaflight.MSP_Out.Max_Satellites, Natural (G.In_View));
      for I in 0 .. V.Channels - 1 loop
         declare
            S : constant Adaflight.GPS_Frames.Satellite := Adaflight.STM32.GPS.Satellite (I);
         begin
            V.Satellites (I) := (S.Channel, S.Id, S.Quality, S.Cno);
         end;
      end loop;
      Env.GPS_Enabled := Adaflight.STM32.GPS.Enabled;
      Env.GPS.State := Adaflight.STM32.GPS.Link_State;
      Env.GPS.Platform := Adaflight.STM32.GPS.Platform;
      Env.GPS.Port_Baud := Adaflight.STM32.GPS.Port_Baud;
      Env.GPS.Satellites := G.Satellites;
      Env.GPS.HDOP := G.HDOP;
      Env.GPS.VDOP := G.VDOP;
      Env.GPS.Fix := G.Fix;
      Env.GPS.Latitude := G.Latitude;
      Env.GPS.Longitude := G.Longitude;
      Env.GPS.Altitude_Cm := G.Altitude_Cm;
      Env.GPS.Time_Valid := T.Valid;
      Env.GPS.Year := T.Year;
      Env.GPS.Month := T.Month;
      Env.GPS.Day := T.Day;
      Env.GPS.Hour := T.Hour;
      Env.GPS.Minute := T.Minute;
      Env.GPS.Second := T.Second;
      Env.GPS.Channels := Natural'Min (CLI.Max_GPS_Channels, Natural (G.In_View));
      for I in 1 .. Env.GPS.Channels loop
         Env.GPS.Signals (I) := Adaflight.STM32.GPS.Satellite (I - 1).Cno;
      end loop;
   end Report_GPS;

   --  The GPS task: one run of the link, its ready beep, its task rate, and
   --  its readings into the replies and the status.
   procedure Run_GPS (Before : Unsigned_32) is
      R : Adaflight.STM32.GPS.Report;
   begin
      Adaflight.STM32.GPS.Run (Adaflight.STM32.Time.Millis, Before, Adaflight.STM32.Pilot.Armed, R);
      declare
         G : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      begin
         if G.Stamp /= Lap_Stamp then
            Lap_Stamp := G.Stamp;
            Adaflight.GPS_Lap_Timer.New_GPS_Data
              (Lap, Adaflight.Config_Runtime.Lap_Timer_Settings_Of (Config.Gps_Lap_Timer_Config),
               (Lat => G.Latitude, Lon => G.Longitude, Alt_Cm => G.Altitude_Cm), Lap_Clock_Ms (G), G.Cos_Lat,
               Reset_Mode => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Lap_Timer_Reset));
         end if;
      end;
      if R.Ready_Beep then
         Request_Beep (Adaflight.Beeper.Ready);
      end if;
      case R.Rate is
         when Adaflight.GPS_Link.Fast =>
            Scheduler.Reschedule (Sched, Sched_Settings, Scheduler.GPS, 1_000);
         when Adaflight.GPS_Link.Normal =>
            Scheduler.Reschedule (Sched, Sched_Settings, Scheduler.GPS, 10_000);
         when Adaflight.GPS_Link.Unchanged =>
            null;
      end case;
      Report_GPS;
   end Run_GPS;

   --  The telemetry's configuration: the sensors the board has, the
   --  telemetry group's disabled kinds and inertial frames, the battery
   --  meters, the GPS and telemetry features and the negotiated rate option.
   function Telemetry_Config return Adaflight.CRSF_Telemetry.Config is
      use type Adaflight.Battery.Voltage_Source;
      use type Adaflight.Battery.Current_Source;
      Meters : constant Adaflight.Battery.Settings := Battery_Settings;
   begin
      return
        (Acc_Present         => Gyro_Report.Acc_Found,
         Baro_Present        => Adaflight.STM32.Baro.Detected,
         Mag_Present         => False,
         Gyro_Present        => Selection.Found,
         Disabled_Kinds      => Config.Telemetry_Config.Disabled_Sensors,
         Voltage_Configured  => Meters.Voltage_Meter /= Adaflight.Battery.None,
         Amperage_Configured => Meters.Current_Meter /= Adaflight.Battery.None,
         GPS_Feature         => (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0,
         Telemetry_Feature   => (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0,
         Inertial_Frames     => Config.Telemetry_Config.Crsf_Tlm_Accgyro /= 0,
         Event_Driven        => False,
         Use_Negotiated_Baud => Config.Rx_Config.Crsf_Use_Negotiated_Baud /= 0);
   end Telemetry_Config;

   --  The flight mode word of the telemetry's flight mode frame.
   function Telemetry_Mode_Flags return Unsigned_16 is
      use Adaflight.CRSF_Telemetry;
      M : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
   begin
      return
        (if M (Adaflight.Arming.Angle_Mode) then Mode_Angle else 0)
        or (if M (Adaflight.Arming.Horizon_Mode) then Mode_Horizon else 0)
        or (if M (Adaflight.Arming.Alt_Hold_Mode) then Mode_Alt_Hold else 0)
        or (if M (Adaflight.Arming.Pos_Hold_Mode) then Mode_Pos_Hold else 0)
        or (if M (Adaflight.Arming.Chirp_Mode) then Mode_Chirp else 0)
        or (if M (Adaflight.Arming.Passthru_Mode) then Mode_Passthru else 0)
        or (if M (Adaflight.Arming.Failsafe_Mode) then Mode_Failsafe else 0)
        or (if M (Adaflight.Arming.GPS_Rescue_Mode) then Mode_GPS_Rescue else 0);
   end Telemetry_Mode_Flags;

   --  What the position estimate reads: the accelerometer through the
   --  attitude, no barometer, the GPS as its link reports it, and the modes
   --  that ask for the horizontal estimate.
   function Position_Inputs (Now_Us : Unsigned_32) return Adaflight.Position_Estimator.Inputs is
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      M     : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      Bound : constant := Adaflight.Position_Estimator.Acc_Bound;
      function Held (V : Float) return Float is (Float'Max (-Bound, Float'Min (Bound, V)));
   begin
      return
        (Now_Us             => Now_Us,
         Armed              => Adaflight.STM32.Pilot.Armed,
         Acc                => (Held (Acc_State.Acc.X), Held (Acc_State.Acc.Y), Held (Acc_State.Acc.Z)),
         One_G_Reciprocal   => Float'Max (2.0 ** (-16), Float'Min (1.0, Acc_State.One_G_Reciprocal)),
         Rotation           => Att_State.Rotation,
         GPS_Present        => G.Present,
         GPS_Fix            => G.Fix,
         GPS_Stamp          => G.Stamp,
         GPS_Rate_Hz        => G.Rate_Hz,
         GPS_Location       => (Lat => G.Latitude, Lon => G.Longitude, Alt_Cm => G.Altitude_Cm),
         GPS_Velocity_North => G.Velocity.North,
         GPS_Velocity_East  => G.Velocity.East,
         GPS_Velocity_Down  => G.Velocity.Down,
         GPS_H_Acc          => G.Accuracy.Horizontal,
         GPS_S_Acc          => G.Accuracy.Speed,
         GPS_V_Acc          => G.Accuracy.Vertical,
         Cos_Lat            => G.Cos_Lat,
         Position_Hold_Mode => M (Adaflight.Arming.Pos_Hold_Mode),
         Rescue_Mode        => M (Adaflight.Arming.GPS_Rescue_Mode),
         Baro_Present       => Adaflight.STM32.Baro.Detected,
         Baro_Altitude_Cm   => Adaflight.STM32.Baro.Altitude_Cm,
         others             => <>);
   end Position_Inputs;

   --  The altitude hold task over the estimate's control values, at the
   --  interval the scheduler measured since its last run.
   procedure Run_Altitude_Hold is
      M : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
   begin
      Adaflight.Altitude_Hold.Update
        (Alt_Hold_State, Alt_Hold_Settings,
         (Hold_Mode             => M (Adaflight.Arming.Alt_Hold_Mode),
          Interval_Us           => Scheduler.Task_Delta_Time (Sched, Scheduler.Alt_Hold),
          Throttle_Command      => Float'Max (750.0, Float'Min (2_250.0, Adaflight.STM32.Pilot.Throttle_Command)),
          Throttle_Low          => Adaflight.STM32.Pilot.Throttle_Low (Flight_Channels),
          Failsafe_Active       => Adaflight.STM32.Radio.Failsafe_Active,
          Emergency_Descent     => False,
          Emergency_Rate_Cms    => 0.0,
          Altitude_Cm           => Pos_State.Control_Altitude_Cm,
          Vertical_Velocity     => Pos_State.Control_Derivative,
          Vertical_Acceleration => Pos_State.Control_Acceleration,
          Cos_Tilt              => Float'Max (-1.0, Float'Min (1.0, Adaflight.Attitude.Cos_Tilt (Att_State)))));
   end Run_Altitude_Hold;

   --  Whether the attitude's heading is good to fly by: the board has no
   --  compass, so only a GPS course the attitude has matched long enough.
   function Heading_Valid return Boolean is (Adaflight.Attitude.Heading_Valid (Att_State, Compass_Calibrated => False));

   --  What the position hold reads: the arming, the failsafe and the modes,
   --  the interval the scheduler measured since its last run, the estimate's
   --  horizontal state, height and validity, whether its source needs a
   --  heading, the attitude's heading, and the sticks.
   function Hold_Inputs return Adaflight.Position_Control.Inputs is
      M     : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      Bound : constant := Adaflight.Position_Control.Estimate_Bound;
      function Held (V : Float) return Float is (Float'Max (-Bound, Float'Min (Bound, V)));
      function Rate (A : Adaflight.Axes.Axis) return Float is
        (Float'Max (-3_000.0, Float'Min (3_000.0, Adaflight.STM32.Pilot.Setpoint_Rate (A))));
      function Max_Rate (A : Adaflight.Axes.Axis) return Float is
        (Float'Max (1.0, Float'Min (5_000.0, Adaflight.STM32.Pilot.Max_Rate (A))));
      function Stick (A : Adaflight.Axes.Axis) return Float is
        (Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Pilot.Deflection_Abs (A))));
      Yaw   : constant Adaflight.RC_Command.Channel := Adaflight.Axes.Axis'Pos (Adaflight.Axes.Yaw);
   begin
      return
        (Armed            => Adaflight.STM32.Pilot.Armed,
         Failsafe_Active  => Adaflight.STM32.Radio.Failsafe_Active,
         Pos_Hold_Mode    => M (Adaflight.Arming.Pos_Hold_Mode),
         Rescue_Mode      => M (Adaflight.Arming.GPS_Rescue_Mode),
         Autopilot_Mode   => M (Adaflight.Arming.Autopilot_Mode),
         Mag_Mode         => M (Adaflight.Arming.Mag_Mode),
         Interval_Us      => Scheduler.Task_Delta_Time (Sched, Scheduler.Pos_Hold),
         Position         => (Held (Pos_State.Position_East), Held (Pos_State.Position_North)),
         Velocity         => (Held (Pos_State.Velocity_East), Held (Pos_State.Velocity_North)),
         Acceleration     => (Held (Pos_State.Acceleration_East), Held (Pos_State.Acceleration_North)),
         Position_Up      => Pos_State.Position_Up,
         Velocity_Up      => Pos_State.Velocity_Up,
         Valid_XY         => Pos_State.Valid_XY,
         Heading_Required =>
           Adaflight.Position_Estimator.Heading_Required (Pos_Settings, Position_Inputs (Adaflight.STM32.Time.Micros)),
         Yaw              => Att_State.Euler.Yaw,
         Heading_Valid    => Heading_Valid,
         Setpoint_Pitch   => Rate (Adaflight.Axes.Pitch),
         Setpoint_Roll    => Rate (Adaflight.Axes.Roll),
         Max_Rate_Pitch   => Max_Rate (Adaflight.Axes.Pitch),
         Max_Rate_Roll    => Max_Rate (Adaflight.Axes.Roll),
         Yaw_Command      => Float'Max (-500.0, Float'Min (500.0, Adaflight.STM32.Pilot.Command (Yaw))),
         Deflection_Pitch => Stick (Adaflight.Axes.Pitch),
         Deflection_Roll  => Stick (Adaflight.Axes.Roll));
   end Hold_Inputs;

   --  The position hold task: the hold over an idle navigator, the
   --  estimator's horizontal axes started when the controller starts, and
   --  the autopilot's yaw handed to the pilot's RC processing.
   procedure Run_Position_Hold is
      Inp       : constant Adaflight.Position_Control.Inputs := Hold_Inputs;
      Enable_XY : Boolean;
   begin
      Adaflight.Position_Hold.Update (Pos_Hold_State, Control_Settings, Inp, Navigator, Enable_XY);
      if Enable_XY then
         Adaflight.Position_Estimator.Enable_XY (Pos_State, Position_Inputs (Adaflight.STM32.Time.Micros), True);
      end if;
      Adaflight.STM32.Pilot.Set_Autopilot_Yaw
        (Pos_Hold_State.Control.Yaw_Active, Pos_Hold_State.Control.Yaw_Rate_Dps);
   end Run_Position_Hold;

   --  Whether the position hold is engaged and failing, and whether it could
   --  engage now.
   function Pos_Hold_Failure return Boolean is
     (Adaflight.STM32.Pilot.Flight_Modes (Adaflight.Arming.Pos_Hold_Mode)
      and then (not Pos_Hold_State.Control_Ok or else not Pos_Hold_State.Sensors_Ok));

   --  The GPS rescue task over the autopilot's altitude and position
   --  controllers the holds share: a disarm it asks for is a failsafe
   --  disarm, with the arm switch's disable reason set when it asks for that.
   procedure Run_Rescue is
      M     : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      P_Inp : constant Adaflight.Position_Control.Inputs := Hold_Inputs;
      Bound : constant := Adaflight.GPS_Rescue.Estimate_Bound;
      function Held (V : Float) return Float is (Float'Max (-Bound, Float'Min (Bound, V)));
      Inp   : constant Adaflight.GPS_Rescue.Inputs :=
        (Now_Us                => Adaflight.STM32.Time.Micros,
         Rescue_Mode           => M (Adaflight.Arming.GPS_Rescue_Mode),
         Armed                 => Adaflight.STM32.Pilot.Armed,
         GPS_Stamp             => G.Stamp,
         Heading_Valid         => Heading_Valid,
         GPS_Healthy           => G.Healthy,
         Altitude_Control_Cm   => Pos_State.Control_Altitude_Cm,
         Altitude_Filtered_Cm  => Held (Pos_State.Filtered_Altitude_Cm),
         Altitude_Available    => Pos_State.Valid_Z,
         Valid_XY              => P_Inp.Valid_XY,
         Position              => P_Inp.Position,
         Velocity              => P_Inp.Velocity,
         Yaw                   => Att_State.Euler.Yaw,
         GPS_Fix               => G.Fix,
         GPS_Fix_Home          => G.Fix_Home,
         Num_Sat               => G.Satellites,
         Crash_Recovery_Active => Adaflight.STM32.Control.Crash_Recovery_Active,
         Rx_Receiving          => Adaflight.STM32.Radio.Receiving,
         Vertical_Velocity     => Pos_State.Control_Derivative,
         Vertical_Acceleration => Pos_State.Control_Acceleration,
         Cos_Tilt              => Float'Max (-1.0, Float'Min (1.0, Adaflight.Attitude.Cos_Tilt (Att_State))));
      Disarm          : Boolean;
      Arming_Disabled : Boolean;
      Asked           : Adaflight.Arming.Outputs;
   begin
      Adaflight.GPS_Rescue.Update
        (Rescue_State, Rescue_Settings, Inp,
         Adaflight.Altitude_Hold.Control_Settings (Alt_Hold_Settings), Alt_Hold_State.Control,
         Control_Settings, P_Inp, Pos_Hold_State.Control, Disarm, Arming_Disabled);
      if Arming_Disabled then
         Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.Arm_Switch, True);
      end if;
      if Disarm then
         Adaflight.STM32.Pilot.Disarm (Adaflight.Arming.Failsafe, Adaflight.STM32.Time.Micros, Asked);
         Apply (Asked);
      end if;
   end Run_Rescue;

   function Pos_Hold_Ready return Boolean is
     (Pos_State.Valid_XY
      and then (not Adaflight.Position_Estimator.Heading_Required
                      (Pos_Settings, Position_Inputs (Adaflight.STM32.Time.Micros))
                or else Heading_Valid));

   --  The flight modes as the reference's flight mode word: angle, horizon,
   --  magnetometer and altitude hold in bits 0 to 3, then position hold,
   --  headfree, chirp and passthru from bit 5, then failsafe, rescue,
   --  autopilot and launch from bit 10.
   function Mode_Word (M : Adaflight.Arming.Mode_Set) return Unsigned_16 is
      use Adaflight.Arming;
      Bits : constant array (Flight_Mode) of Unsigned_16 :=
        (Angle_Mode => 2 ** 0, Horizon_Mode => 2 ** 1, Mag_Mode => 2 ** 2, Alt_Hold_Mode => 2 ** 3,
         Pos_Hold_Mode => 2 ** 5, Headfree_Mode => 2 ** 6, Chirp_Mode => 2 ** 7, Passthru_Mode => 2 ** 8,
         Failsafe_Mode => 2 ** 10, GPS_Rescue_Mode => 2 ** 11, Autopilot_Mode => 2 ** 12, Launch_Mode => 2 ** 13);
      W : Unsigned_16 := 0;
   begin
      for F in Flight_Mode loop
         if M (F) then
            W := W or Bits (F);
         end if;
      end loop;
      return W;
   end Mode_Word;

   --  What the MAVLink stream reads: the battery and its meters, the signal
   --  and the first eight channels, the attitude, the sensors, the GPS
   --  solution and home, the estimated altitude, the mixer, the arming, the
   --  failsafe and the flight modes, the clock and the disable reasons.
   function MAVLink_Inputs return Adaflight.MAVLink_Telemetry.Inputs is
      Inp   : Adaflight.MAVLink_Telemetry.Inputs;
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Volts : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      Alt   : constant Integer_32 := Adaflight.MAVLink_Telemetry.Altitude_Bound;
      function Held (V : Integer_32) return Integer_32 is (Integer_32'Max (-Alt, Integer_32'Min (Alt, V)));
   begin
      Inp.Battery := Bat.Overall;
      Inp.Voltage_Configured := Adaflight.Battery."/=" (Bat_Settings.Voltage_Meter, Adaflight.Battery.None);
      Inp.Amperage_Configured := Adaflight.Battery."/=" (Bat_Settings.Current_Meter, Adaflight.Battery.None);
      Inp.Pack_Voltage := Unsigned_16 (Volts);
      Inp.Cell_Voltage := (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0);
      Inp.Amperage := Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.Amperage)));
      Inp.MAh_Drawn := Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.mAh_Drawn)));
      Inp.Battery_Percent := Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings));
      Inp.Cell_Count := Unsigned_8 (Natural'Min (255, Bat.Cells));
      Inp.RSSI := Adaflight.STM32.Radio.RSSI;
      Inp.Channel_Count := Natural'Min (18, Adaflight.STM32.Radio.Channel_Count);
      for I in Inp.RC'Range loop
         Inp.RC (I) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.STM32.Radio.Channel (I)));
      end loop;
      Inp.Roll := Integer_16 (Att_State.Euler.Roll);
      Inp.Pitch := Integer_16 (Att_State.Euler.Pitch);
      Inp.Yaw := Integer_16 (Att_State.Euler.Yaw);
      Inp.GPS_Present := G.Present;
      Inp.GPS_Fix := G.Fix;
      Inp.GPS_Fix_Home := G.Fix_Home;
      Inp.Latitude := G.Latitude;
      Inp.Longitude := G.Longitude;
      Inp.Altitude_Cm := Held (G.Altitude_Cm);
      Inp.HDOP := G.HDOP;
      Inp.VDOP := G.VDOP;
      Inp.Ground_Speed := G.Ground_Speed;
      Inp.Ground_Course := G.Ground_Course;
      Inp.Satellites := G.Satellites;
      Inp.H_Acc := G.Accuracy.Horizontal;
      Inp.V_Acc := G.Accuracy.Vertical;
      Inp.S_Acc := G.Accuracy.Speed;
      Inp.Vel_N := G.Velocity.North;
      Inp.Vel_E := G.Velocity.East;
      Inp.Vel_D := G.Velocity.Down;
      Inp.Home_Latitude := G.Home.Lat;
      Inp.Home_Longitude := G.Home.Lon;
      Inp.Home_Altitude_Cm := Held (G.Home.Alt_Cm);
      Inp.Estimated_Alt_Cm := Held (Estimated_Altitude_Cm);
      Inp.Mixer_Mode := Config.Mixer_Config.Mixer_Mode;
      Inp.Armed := Adaflight.STM32.Pilot.Armed;
      Inp.Failsafe_Active := Adaflight.STM32.Radio.Failsafe_Active;
      Inp.Modes := Mode_Word (Adaflight.STM32.Pilot.Flight_Modes);
      Inp.Has_Time := Adaflight.STM32.RTC.Has_Time;
      if Inp.Has_Time then
         Inp.RTC_Ms := Integer_64'Max (0, Integer_64'Min (2 ** 53, Adaflight.STM32.RTC.Now_Ms));
      end if;
      Inp.Disable_Flags := Adaflight.STM32.Pilot.Disabled;
      return Inp;
   end MAVLink_Inputs;

   --  The requests a ground station's messages made, in their order: a
   --  disarm, the mode overrides, the home position, and a reboot once the
   --  replies have left.
   procedure Serve_MAVLink_Requests (R : Adaflight.MAVLink_Commands.Requests) is
      Asked : Adaflight.Arming.Outputs;
   begin
      for I in 1 .. R.Count loop
         declare
            Q : Adaflight.MAVLink_Commands.Request renames R.List (I);
         begin
            case Q.Kind is
               when Adaflight.MAVLink_Commands.Disarm =>
                  Adaflight.STM32.Pilot.Disarm (Adaflight.Arming.Serial_Command, Adaflight.STM32.Time.Micros, Asked);
                  Apply (Asked);
               when Adaflight.MAVLink_Commands.Clear_Overrides =>
                  Adaflight.STM32.Pilot.Clear_Mode_Overrides;
               when Adaflight.MAVLink_Commands.Set_Override =>
                  Adaflight.STM32.Pilot.Set_Mode_Override (Q.Box, True);
               when Adaflight.MAVLink_Commands.Reset_Home =>
                  Adaflight.STM32.GPS.Reset_Home;
               when Adaflight.MAVLink_Commands.Set_Home =>
                  Adaflight.STM32.GPS.Set_Home (Q.Latitude, Q.Longitude, Q.Altitude_Cm);
            end case;
         end;
      end loop;
      if Adaflight.MAVLink_Commands."/=" (R.Reboot, Adaflight.MAVLink_Commands.None) then
         Adaflight.STM32.MAVLink.Finish_Transmit;
         Adaflight.STM32.Motors.Shutdown;
         if Adaflight.MAVLink_Commands."=" (R.Reboot, Adaflight.MAVLink_Commands.Bootloader) then
            Adaflight.STM32.MCU.Reset_To_Bootloader;
         end if;
         Reset;
      end if;
   end Serve_MAVLink_Requests;

   --  What the LTM stream reads: the attitude, the flight modes, the arming
   --  and the failsafe, the battery, the signal, the GPS solution with its
   --  home, and the estimated altitude.
   --  What the FrSky hub telemetry reads: the clocks, the accelerometer, the
   --  combined ESC reading, the GPS, the battery, and the altitude estimate
   --  with its climb rate and the heading.
   function FrSky_Hub_Inputs return Adaflight.FrSky_Hub_Telemetry.Inputs is
      package FH renames Adaflight.FrSky_Hub_Telemetry;
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Volts : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      ESC   : Adaflight.ESC_Sensor.Reading;
      function Held (V : Float) return FH.Acceleration is (Float'Max (-1.0e6, Float'Min (1.0e6, V)));
      function Wide (V : Long_Integer) return Integer_32 is
        (Integer_32 (Long_Integer'Max (-2 ** 31, Long_Integer'Min (2 ** 31 - 1, V))));
   begin
      Adaflight.STM32.ESC_Sensor.Combined (Adaflight.STM32.Control.Motor_Count, ESC);
      return
        (Now_Us              => Adaflight.STM32.Time.Micros,
         Now_Ms              => Adaflight.STM32.Time.Millis,
         Acc_X               => Held (Acc_State.Acc.X),
         Acc_Y               => Held (Acc_State.Acc.Y),
         Acc_Z               => Held (Acc_State.Acc.Z),
         ESC_Valid           => Adaflight.STM32.ESC_Sensor.Feature_On,
         ESC_Rpm             => ESC.Rpm,
         ESC_Temperature     => ESC.Temperature,
         Fix                 => G.Fix,
         Lat                 => Integer_32'Max (-(2 ** 31 - 1), G.Latitude),
         Lon                 => Integer_32'Max (-(2 ** 31 - 1), G.Longitude),
         Alt_Cm              => G.Altitude_Cm,
         Ground_Speed        => G.Ground_Speed,
         Num_Sat             => G.Satellites,
         Pdop                => G.PDOP,
         Voltage_Configured  => Adaflight.Battery."/=" (Bat_Settings.Voltage_Meter, Adaflight.Battery.None),
         Amperage_Configured => Adaflight.Battery."/=" (Bat_Settings.Current_Meter, Adaflight.Battery.None),
         Cell_Count          => Unsigned_8 (Natural'Min (255, Bat.Cells)),
         Voltage_Cv          => Unsigned_16 (Volts),
         Amperage_Ca         => Wide (Long_Integer (Bat.Current.Amperage)),
         Capacity            => Unsigned_16 (Natural'Min (65_535, Bat_Settings.Capacity_mAh)),
         Percent             => Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings)),
         Mah_Drawn           => Wide (Long_Integer (Bat.Current.mAh_Drawn)),
         Vario_Cms           => Estimated_Vario,
         Altitude_Cm         => Estimated_Altitude_Cm,
         Yaw                 => Integer_16 (Att_State.Euler.Yaw));
   end FrSky_Hub_Inputs;

   --  What the EX Bus telemetry reads: the battery, the altitude estimate
   --  and its climb rate, the attitude, the GPS with its home, the
   --  accelerometer, and the ESC sensor's readings of the mixer's motors.
   --  The board keeps no debug values, so the debug sensors read zero.
   function Jeti_Inputs return Adaflight.Jeti_Telemetry.Inputs is
      package JT renames Adaflight.Jeti_Telemetry;
      G      : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Volts  : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      Motors : constant Natural := Natural'Min (JT.Max_Motors, Adaflight.STM32.Control.Motor_Count);
      Inp    : JT.Inputs;
      function Held (V : Float) return JT.Acc_Reading is (Float'Max (-1.0e6, Float'Min (1.0e6, V)));
      function Wide (V : Long_Integer) return Integer_32 is
        (Integer_32 (Long_Integer'Max (-2 ** 31, Long_Integer'Min (2 ** 31 - 1, V))));
   begin
      Inp.Legacy_Voltage := Unsigned_16 ((Volts + 5) / 10);
      Inp.Pack_Voltage := Unsigned_16 (Volts);
      Inp.Amperage := Wide (Long_Integer (Bat.Current.Amperage));
      Inp.Altitude_Cm := Estimated_Altitude_Cm;
      Inp.MAh_Drawn := Wide (Long_Integer (Bat.Current.mAh_Drawn));
      Inp.Vario := Estimated_Vario;
      Inp.Roll := Integer_16 (Att_State.Euler.Roll);
      Inp.Pitch := Integer_16 (Att_State.Euler.Pitch);
      Inp.Yaw := Integer_16 (Att_State.Euler.Yaw);
      Inp.Satellites := G.Satellites;
      Inp.Longitude := G.Longitude;
      Inp.Latitude := G.Latitude;
      Inp.Ground_Speed := G.Ground_Speed;
      Inp.Home_Distance := G.Distance_To_Home_M;
      Inp.Home_Direction := G.Direction_To_Home;
      Inp.Ground_Course := G.Ground_Course;
      Inp.GPS_Altitude_Cm := G.Altitude_Cm;
      Inp.GPS_Sensor := G.Present;
      Inp.Acc_ADC := (Held (Acc_State.Acc.X), Held (Acc_State.Acc.Y), Held (Acc_State.Acc.Z));
      Inp.One_G := Positive'Max (1, Natural'Min (65_535, Adaflight.STM32.Gyro.Acc_One_G));
      Inp.Motor_Count := Motors;
      for M in 0 .. Motors - 1 loop
         declare
            R : constant Adaflight.ESC_Sensor.Reading := Adaflight.STM32.ESC_Sensor.Motor_Reading (M);
         begin
            Inp.Rpm (M) := Natural'Max (0, Integer (R.Rpm));
            Inp.Data_Age (M) := R.Data_Age;
         end;
      end loop;
      Inp.Erpm_To_Hz := Float'Max (0.0, Float'Min (100.0, Adaflight.STM32.ESC_Sensor.Erpm_Factor));
      return Inp;
   end Jeti_Inputs;

   --  What the Ghost telemetry reads: the battery, the arming, the GPS with
   --  its home, the altitude estimate and the attitude's heading.
   function GHST_Inputs return Adaflight.GHST_Telemetry.Inputs is
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Volts : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      function Wide (V : Long_Integer) return Integer_32 is
        (Integer_32 (Long_Integer'Max (-2 ** 31, Long_Integer'Min (2 ** 31 - 1, V))));
   begin
      return
        (Now_Us         => Adaflight.STM32.Time.Micros,
         Voltage_Cv     => Unsigned_16 (Volts),
         Cell_Cv        => (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0),
         Amperage_Ca    => Wide (Long_Integer (Bat.Current.Amperage)),
         Mah_Drawn      => Wide (Long_Integer (Bat.Current.mAh_Drawn)),
         Armed          => Adaflight.STM32.Pilot.Armed,
         Lat            => G.Latitude,
         Lon            => G.Longitude,
         Alt_Cm         => G.Altitude_Cm,
         Fix            => G.Fix,
         Fix_Home       => G.Fix_Home,
         Ground_Speed   => G.Ground_Speed,
         Ground_Course  => G.Ground_Course,
         Num_Sat        => G.Satellites,
         Distance_Home  => G.Distance_To_Home_M,
         Direction_Home => G.Direction_To_Home,
         Altitude_Cm    => Estimated_Altitude_Cm,
         Yaw            => Integer_16 (Att_State.Euler.Yaw));
   end GHST_Inputs;

   --  What the iBus telemetry reads: the battery, the arming, the throttle
   --  and the modes, the accelerometer, the attitude, the climb rate and the
   --  GPS, with no barometer and no gyro temperature on the board.
   function IBus_Inputs return Adaflight.IBus_Telemetry.Inputs is
      package IB renames Adaflight.IBus_Telemetry;
      M     : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Volts : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      function Held (V : Float) return IB.Acceleration is (Float'Max (-1.0e6, Float'Min (1.0e6, V)));
      function Wide (V : Long_Integer) return Integer_32 is
        (Integer_32 (Long_Integer'Max (-2 ** 31, Long_Integer'Min (2 ** 31 - 1, V))));
   begin
      return
        (Voltage_Cv       => Unsigned_16 (Volts),
         Cell_Cv          => (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0),
         Amperage_Ca      => Wide (Long_Integer (Bat.Current.Amperage)),
         Capacity         => Unsigned_16 (Natural'Min (65_535, Bat_Settings.Capacity_mAh)),
         Percent          => Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings)),
         Mah_Drawn        => Wide (Long_Integer (Bat.Current.mAh_Drawn)),
         Armed            => Adaflight.STM32.Pilot.Armed,
         Throttle_Low     => Adaflight.STM32.Pilot.Throttle_Low (Flight_Channels),
         Motor_Stop       => (Runtime_Features and Adaflight.Config_Fix.Feature_Motor_Stop) /= 0,
         Throttle         => Float'Max (0.0, Float'Min (32_767.0, Adaflight.STM32.Pilot.Throttle_Command)),
         Angle_Like       =>
           M (Adaflight.Arming.Angle_Mode) or else M (Adaflight.Arming.Alt_Hold_Mode)
           or else M (Adaflight.Arming.Pos_Hold_Mode),
         Passthru         => M (Adaflight.Arming.Passthru_Mode),
         Headfree_Or_Mag  => M (Adaflight.Arming.Mag_Mode) or else M (Adaflight.Arming.Headfree_Mode),
         Horizon          => M (Adaflight.Arming.Horizon_Mode),
         Failsafe         => M (Adaflight.Arming.Failsafe_Mode),
         Acc_X            => Held (Acc_State.Acc.X),
         Acc_Y            => Held (Acc_State.Acc.Y),
         Acc_Z            => Held (Acc_State.Acc.Z),
         Roll             => Integer_16 (Att_State.Euler.Roll),
         Pitch            => Integer_16 (Att_State.Euler.Pitch),
         Yaw              => Integer_16 (Att_State.Euler.Yaw),
         Vario_Cms        => Estimated_Vario,
         GPS_Present      => G.Present,
         Fix              => G.Fix,
         Num_Sat          => G.Satellites,
         Ground_Speed     => G.Ground_Speed,
         Ground_Course    => G.Ground_Course,
         Lat              => G.Latitude,
         Lon              => G.Longitude,
         Alt_Cm           => G.Altitude_Cm,
         Distance_Home    => G.Distance_To_Home_M,
         others           => <>);
   end IBus_Inputs;

   --  The SmartPort value tables: the sensors the configuration leaves
   --  enabled, the battery meters configured, the accelerometer and the GPS
   --  feature, with no barometer on the board.
   function SmartPort_Build return Adaflight.SmartPort_Telemetry.Build_Inputs is
      package SP renames Adaflight.SmartPort_Telemetry;
      B        : SP.Build_Inputs;
      Disabled : constant Unsigned_32 := Config.Telemetry_Config.Disabled_Sensors;
   begin
      for Se in SP.Sensor loop
         B.Enabled (Se) := (Disabled / 2 ** SP.Sensor'Pos (Se)) mod 2 = 0;
      end loop;
      B.Voltage_Configured := Adaflight.Battery."/=" (Bat_Settings.Voltage_Meter, Adaflight.Battery.None);
      B.Amperage_Configured := Adaflight.Battery."/=" (Bat_Settings.Current_Meter, Adaflight.Battery.None);
      B.Acc_Present := Gyro_Report.Acc_Found;
      B.GPS_Feature := (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0;
      return B;
   end SmartPort_Build;

   --  What the SmartPort telemetry reads: the battery, the altitude and its
   --  climb rate, the attitude, the accelerometer with its scale, the arming
   --  and the modes, the GPS, the ESC readings with the motors' pole count,
   --  and the current profiles' gains and rates.
   function SmartPort_Inputs return Adaflight.SmartPort_Telemetry.Inputs is
      package SP renames Adaflight.SmartPort_Telemetry;
      M        : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G        : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Disabled : constant Adaflight.Arming.Disable_Set := Adaflight.STM32.Pilot.Disabled;
      Volts    : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      Motors   : constant SP.Motor_Count := Natural'Min (SP.Max_Motors, Adaflight.STM32.Control.Motor_Count);
      ESC_On   : constant Boolean := Adaflight.STM32.ESC_Sensor.Feature_On;
      PID      : Adaflight.Config_Groups.Pidf_Record_List_5 renames
        Config.Pid_Profiles (Natural'Min (3, Natural (Config.System_Config.Pid_Profile_Index))).Pid;
      Rates    : Adaflight.Config_Groups.Bytes_3 renames
        Config.Control_Rate_Profiles
          (Natural'Min (Config.Control_Rate_Profiles'Last, Natural (Config.System_Config.Active_Rate_Profile))).Rates;
      Inp      : SP.Inputs;
      function Held (V : Float) return SP.Acceleration is (Float'Max (-1.0e6, Float'Min (1.0e6, V)));
      function Wide (V : Long_Integer) return Integer_32 is
        (Integer_32 (Long_Integer'Max (-2 ** 31, Long_Integer'Min (2 ** 31 - 1, V))));
   begin
      Inp.Report_Cell_Voltage := Config.Telemetry_Config.Report_Cell_Voltage /= 0;
      Inp.Pid_Values := Config.Telemetry_Config.Pid_Values_As_Telemetry /= 0;
      Inp.Voltage_Cv := Unsigned_16 (Volts);
      Inp.Cell_Voltage_Cv := (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0);
      Inp.Amperage_Ca := Wide (Long_Integer (Bat.Current.Amperage));
      Inp.Capacity_Set := Bat_Settings.Capacity_mAh > 0;
      Inp.Percent_Remaining := Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings));
      Inp.Mah_Drawn := Wide (Long_Integer (Bat.Current.mAh_Drawn));
      Inp.Altitude_Cm := Estimated_Altitude_Cm;
      Inp.Vario_Cms := Estimated_Vario;
      Inp.Yaw := Integer_16 (Att_State.Euler.Yaw);
      Inp.Pitch := Integer_16 (Att_State.Euler.Pitch);
      Inp.Roll := Integer_16 (Att_State.Euler.Roll);
      Inp.Acc_X := Held (Acc_State.Acc.X);
      Inp.Acc_Y := Held (Acc_State.Acc.Y);
      Inp.Acc_Z := Held (Acc_State.Acc.Z);
      Inp.Acc_1G_Rec := Float'Max (0.0, Float'Min (1.0, Acc_State.One_G_Reciprocal));
      Inp.Arming_Disabled := (for some R in Adaflight.Arming.Disable_Reason => Disabled (R));
      Inp.Armed := Adaflight.STM32.Pilot.Armed;
      Inp.Angle_Like :=
        M (Adaflight.Arming.Angle_Mode) or else M (Adaflight.Arming.Alt_Hold_Mode)
        or else M (Adaflight.Arming.Pos_Hold_Mode);
      Inp.Horizon := M (Adaflight.Arming.Horizon_Mode);
      Inp.Passthru := M (Adaflight.Arming.Passthru_Mode);
      Inp.Mag := M (Adaflight.Arming.Mag_Mode);
      Inp.Headfree := M (Adaflight.Arming.Headfree_Mode);
      Inp.GPS_Present := G.Present;
      Inp.GPS_Feature := Adaflight.STM32.GPS.Enabled;
      Inp.Fix := G.Fix;
      Inp.Fix_Home := G.Fix_Home;
      Inp.Pdop := G.PDOP;
      Inp.Num_Sat := G.Satellites;
      Inp.Ground_Speed := G.Ground_Speed;
      Inp.Lat := G.Latitude;
      Inp.Lon := G.Longitude;
      Inp.Home_Distance_M := G.Distance_To_Home_M;
      Inp.GPS_Altitude_Cm := G.Altitude_Cm;
      Inp.Core_Temperature := Internal.Core_Temperature;
      for K in 0 .. Motors - 1 loop
         declare
            R : constant Adaflight.ESC_Sensor.Reading := Adaflight.STM32.ESC_Sensor.Motor_Reading (K);
         begin
            Inp.ESC (K) :=
              (Present => ESC_On, Voltage => R.Voltage, Current => R.Current, Temperature => R.Temperature,
               Rpm => R.Rpm);
         end;
      end loop;
      declare
         R : Adaflight.ESC_Sensor.Reading;
      begin
         Adaflight.STM32.ESC_Sensor.Combined (Motors, R);
         Inp.ESC_Combined :=
           (Present => ESC_On, Voltage => R.Voltage, Current => R.Current, Temperature => R.Temperature,
            Rpm => R.Rpm);
      end;
      Inp.Motors := Motors;
      Inp.Pole_Count := Config.Motor_Config.Motor_Pole_Count;
      Inp.P := (Roll => PID (0).P, Pitch => PID (1).P, Yaw => PID (2).P);
      Inp.I := (Roll => PID (0).I, Pitch => PID (1).I, Yaw => PID (2).I);
      Inp.D := (Roll => PID (0).D, Pitch => PID (1).D, Yaw => PID (2).D);
      Inp.Rates := (Roll => Rates (0), Pitch => Rates (1), Yaw => Rates (2));
      return Inp;
   end SmartPort_Inputs;

   function LTM_Inputs return Adaflight.LTM_Telemetry.Inputs is
      M : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
   begin
      return
        (Pitch         => Integer_16 (Att_State.Euler.Pitch),
         Roll          => Integer_16 (Att_State.Euler.Roll),
         Yaw           => Integer_16 (Att_State.Euler.Yaw),
         Passthru      => M (Adaflight.Arming.Passthru_Mode),
         Headfree      => M (Adaflight.Arming.Headfree_Mode),
         Angle         => M (Adaflight.Arming.Angle_Mode),
         Horizon       => M (Adaflight.Arming.Horizon_Mode),
         Rescue        => M (Adaflight.Arming.GPS_Rescue_Mode),
         Position_Hold => M (Adaflight.Arming.Pos_Hold_Mode),
         Altitude_Hold => M (Adaflight.Arming.Alt_Hold_Mode),
         Armed         => Adaflight.STM32.Pilot.Armed,
         Failsafe      => Adaflight.STM32.Radio.Failsafe_Active,
         Voltage_Cv    => Unsigned_16 (Natural'Min (65_535, Bat.Voltage.Display_Filtered)),
         Mah_Drawn     => Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.mAh_Drawn))),
         Rssi          => Adaflight.STM32.Radio.RSSI,
         GPS_Present   => G.Present,
         Fix           => G.Fix,
         Num_Sat       => G.Satellites,
         Lat           => G.Latitude,
         Lon           => G.Longitude,
         Ground_Speed  => G.Ground_Speed,
         Altitude_Cm   => Estimated_Altitude_Cm,
         Home_Lat      => G.Home.Lat,
         Home_Lon      => G.Home.Lon,
         Fix_Home      => G.Fix_Home);
   end LTM_Inputs;

   --  What the telemetry reads: the GPS solution with its date, the battery,
   --  the attitude, the flight state, the inertial sample and the craft name.
   function Telemetry_Sources return Adaflight.CRSF_Telemetry.Sources is
      Src      : Adaflight.CRSF_Telemetry.Sources;
      G        : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      T        : constant Adaflight.GPS_Frames.Date_Time := Adaflight.STM32.GPS.Time;
      Volts    : constant Natural := Natural'Min (65_535, Bat.Voltage.Display_Filtered);
      Disabled : constant Adaflight.Arming.Disable_Set := Adaflight.STM32.Pilot.Disabled;
   begin
      Src.GPS :=
        (Latitude       => G.Latitude,
         Longitude      => G.Longitude,
         Altitude_Cm    => G.Altitude_Cm,
         Ground_Speed   => G.Ground_Speed,
         Ground_Course  => G.Ground_Course,
         Satellites     => G.Satellites,
         Fix            => G.Fix,
         Time           => G.Solution_Ms,
         Velocity_North => G.Velocity.North,
         Velocity_East  => G.Velocity.East,
         Velocity_Down  => G.Velocity.Down,
         HDOP           => G.HDOP,
         VDOP           => G.VDOP,
         Date_Valid     => T.Valid,
         Year           => T.Year,
         Month          => T.Month,
         Day            => T.Day,
         Hour           => T.Hour,
         Minute         => T.Minute,
         Second         => T.Second,
         Millisecond    => T.Millis,
         others         => <>);
      Src.Battery :=
        (Legacy_Voltage      => Unsigned_16 ((Volts + 5) / 10),
         Cell_Voltage        => (if Bat.Cells > 0 then Unsigned_16 (Volts / Bat.Cells) else 0),
         Amperage            => Integer_32'Max (-2 ** 31, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.Amperage))),
         Drawn_Mah           => Integer_32'Max (0, Integer_32'Min (2 ** 31 - 1, Integer_32 (Bat.Current.mAh_Drawn))),
         Remaining_Percent   => Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings)),
         Report_Cell_Voltage => Config.Telemetry_Config.Report_Cell_Voltage /= 0);
      Src.Vario := Estimated_Vario;
      Src.Attitude :=
        (Pitch => Integer_16 (Att_State.Euler.Pitch),
         Roll  => Integer_16 (Att_State.Euler.Roll),
         Yaw   => Integer_16 (Att_State.Euler.Yaw));
      Src.Flight :=
        (Mode_Flags            => Telemetry_Mode_Flags,
         Armed                 => Adaflight.STM32.Pilot.Armed,
         Failsafe_Switch       => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Failsafe),
         Rescue_Switch         => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.GPS_Rescue),
         Rescue_Plan           => False,
         Position_Hold_Failure => Pos_Hold_Failure,
         Airmode               => Adaflight.STM32.Pilot.Airmode_Enabled,
         Arming_Disabled       => (for some R in Adaflight.Arming.Disable_Reason => Disabled (R)),
         GPS_Feature           => Adaflight.STM32.GPS.Enabled,
         Rescue_Configured     => Adaflight.STM32.Pilot.Box_Configured (Adaflight.Modes.GPS_Rescue),
         Rescue_Min_Satellites => Config.Gps_Rescue_Config.Min_Sats);
      Src.IMU.Fresh := True;
      for A in Adaflight.Axes.Axis loop
         Src.IMU.Gyro (Adaflight.Axes.Axis'Pos (A)) := Float'Max (-1.0e6, Float'Min (1.0e6, Gyro_State.Filtered (A)));
      end loop;
      Src.IMU.Acc := (0 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.X)),
                      1 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.Y)),
                      2 => Float'Max (-1.0e6, Float'Min (1.0e6, Acc_State.Acc.Z)));
      Src.IMU.Acc_1G_Reciprocal := 1.0 / Float (Natural'Max (1, Adaflight.STM32.Gyro.Acc_One_G));
      for I in Config.Pilot_Config.Craft_Name'Range loop
         exit when Config.Pilot_Config.Craft_Name (I) = 0 or else Src.Name_Last = Adaflight.CRSF_Telemetry.Name_Length_Max;
         Src.Name_Last := Src.Name_Last + 1;
         Src.Name (Src.Name_Last) := Character'Val (Config.Pilot_Config.Craft_Name (I));
      end loop;
      return Src;
   end Telemetry_Sources;

   --  The roll, pitch, yaw and throttle channels the gimbal mixes in.
   function Gimbal_Sticks return Adaflight.Gimbal_Control.Sticks is
      Channels : constant Adaflight.RC_Command.Channel_Values := Flight_Channels;
   begin
      return (Roll => Channels (0), Pitch => Channels (1), Yaw => Channels (2),
              Throttle => Channels (Adaflight.RC_Command.Throttle_Channel));
   end Gimbal_Sticks;

   --  The gimbal task, stopped for good when the gimbal has no port.
   procedure Run_Gimbal (Now_Us : Unsigned_32) is
      Stop : Boolean;
   begin
      Adaflight.STM32.Gimbal.Update (Config, Gimbal_Sticks, Now_Us, Stop);
      if Stop then
         Scheduler.Set_Task_Enabled (Sched, Scheduler.Gimbal, False);
      end if;
   end Run_Gimbal;

   --  The camera task over the sticks, the camera boxes, the arming, the
   --  menu and the attitude, with the beep a five key connection asks for.
   procedure Run_RunCam is
      Sticks   : constant Adaflight.RC_Command.Channel_Values := Flight_Channels;
      Disabled : constant Adaflight.Arming.Disable_Set := Adaflight.STM32.Pilot.Disabled;
      Sound    : Adaflight.RunCam_Device.Beep;
   begin
      Adaflight.STM32.RunCam.Run
        ((Now_Ms          => Adaflight.STM32.Time.Millis,
          Armed           => Adaflight.STM32.Pilot.Armed,
          Blocked         =>
            Disabled (Adaflight.Arming.Runaway_Disarm) or else Disabled (Adaflight.Arming.Crash_Disarm),
          Menu_Open       => Adaflight.Build_Features.Menus and then Adaflight.STM32.Menu.Open,
          Sticks_Disabled => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Stick_Command_Disable),
          Camera          =>
            (Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Camera_1),
             Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Camera_2),
             Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Camera_3)),
          Throttle        => Sticks (Adaflight.RC_Command.Throttle_Channel),
          Roll            => Sticks (0),
          Pitch           => Sticks (1),
          Yaw             => Sticks (2),
          Att_Roll        => Integer_16 (Att_State.Euler.Roll),
          Att_Pitch       => Integer_16 (Att_State.Euler.Pitch),
          Att_Yaw         => Integer_16 (Att_State.Euler.Yaw)),
         Sound);
      case Sound is
         when Adaflight.RunCam_Device.Connection_Open =>
            Request_Beep (Adaflight.Beeper.Camera_Open);
         when Adaflight.RunCam_Device.Connection_Close =>
            Request_Beep (Adaflight.Beeper.Camera_Close);
         when Adaflight.RunCam_Device.No_Beep =>
            null;
      end case;
   end Run_RunCam;

   procedure Run_Telemetry (Now_Us : Scheduler.Time_Us) is
   begin
      Telemetry_Step (Now_Us, Telemetry_Sources);
   end Run_Telemetry;

   --  A task's body between the scheduler's execution prologue and
   --  epilogue, at the clock around its run.
   --  What the LED strip reads: the clock, the LED low and beeper switches,
   --  the arming, the failsafe, the crash flip, the beeper, the flight modes,
   --  the battery with its meter, the signal, the GPS with the rescue's
   --  satellite minimum, the altitude, the roll and pitch commands, and the
   --  receiver's aux and throttle channels.
   function LED_Inputs return Adaflight.LED_Strip.Inputs is
      use type Adaflight.Battery.Voltage_Source;
      Modes : constant Adaflight.Arming.Mode_Set := Adaflight.STM32.Pilot.Flight_Modes;
      G     : constant Adaflight.STM32.GPS.Readings := Adaflight.STM32.GPS.Current;
      Aux   : constant Natural := Strip_Settings.Aux_Channel;
      I     : Adaflight.LED_Strip.Inputs;
   begin
      I.Now_Us := Adaflight.STM32.Time.Micros;
      I.Now_Ms := Adaflight.STM32.Time.Millis;
      I.Led_Low := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.LED_Low);
      I.Beeper_Box := Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Beeper_On);
      I.Armed := Adaflight.STM32.Pilot.Armed;
      I.Arming_Disabled := (for some Reason of Adaflight.STM32.Pilot.Disabled => Reason);
      I.Failsafe := Adaflight.STM32.Radio.Failsafe_Active;
      I.Crash_Flip := Adaflight.STM32.Pilot.Crash_Flip_Active;
      I.Beeper_On := Adaflight.Beeper.Is_On (Beep);
      I.Headfree := Modes (Adaflight.Arming.Headfree_Mode);
      I.Mag := Modes (Adaflight.Arming.Mag_Mode);
      I.Horizon := Modes (Adaflight.Arming.Horizon_Mode);
      I.Angle := Modes (Adaflight.Arming.Angle_Mode);
      I.Battery :=
        (case Bat.Overall is
            when Adaflight.Battery.OK          => Adaflight.LED_Strip.OK,
            when Adaflight.Battery.Warning     => Adaflight.LED_Strip.Warning,
            when Adaflight.Battery.Critical    => Adaflight.LED_Strip.Critical,
            when Adaflight.Battery.Not_Present => Adaflight.LED_Strip.Not_Present,
            when Adaflight.Battery.Init        => Adaflight.LED_Strip.Init_State);
      I.Voltage_Meter := Bat_Settings.Voltage_Meter /= Adaflight.Battery.None;
      I.Battery_Percent := Unsigned_8 (Adaflight.Battery.Percentage_Remaining (Bat, Bat_Settings));
      I.Rssi_Percent := Adaflight.STM32.Radio.RSSI_Percent;
      I.Rx_Signal := Adaflight.STM32.Radio.Receiving;
      I.GPS_Present := Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.GPS);
      I.Fix := G.Fix;
      I.Num_Sat := G.Satellites;
      I.Min_Sats := Config.Gps_Rescue_Config.Min_Sats;
      I.Altitude_Cm := Integer_32'Max (-10_000_000, Integer_32'Min (10_000_000, Estimated_Altitude_Cm));
      I.Roll_Command := Float'Max (-2_000.0, Float'Min (2_000.0, Adaflight.STM32.Pilot.Command (0)));
      I.Pitch_Command := Float'Max (-2_000.0, Float'Min (2_000.0, Adaflight.STM32.Pilot.Command (1)));
      I.Aux := Float'Max (0.0, Float'Min (4_000.0, Adaflight.STM32.Radio.Channel (Aux)));
      I.Throttle := Float'Max (0.0, Float'Min (4_000.0, Adaflight.STM32.Radio.Channel (3)));
      return I;
   end LED_Inputs;

   --  The LED strip task: nothing while the strip sends, else the strip's
   --  update with its colors sent when they changed.
   procedure Run_LED_Strip is
      Updated : Boolean;
   begin
      if Adaflight.STM32.LED_Strip.Ready then
         Adaflight.LED_Strip.Update (Strip, Strip_Settings, Strip_Layout, LED_Inputs, Updated);
         if Updated then
            Adaflight.STM32.LED_Strip.Send (Strip.Output);
         end if;
      end if;
   end Run_LED_Strip;

   procedure Run_Body (Id : Scheduler.Task_Id) is
      Before : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Inputs : constant Tasks.Inputs :=
        (Armed             => Adaflight.STM32.Pilot.Armed,
         CLI_Open          => Session.Open,
         Feature_Telemetry => (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0,
         Rescue_Configured    => Rescue_Configured,
         Rangefinder_Detected => Adaflight.STM32.Rangefinder.Detected,
         Cos_Tilt             => Adaflight.Attitude.Cos_Tilt (Att_State),
         others               => <>);
   begin
      case Id is
         when Scheduler.System =>
            Scheduler.System_Load (Sched, Before);
         when Scheduler.Main =>
            Tasks.Main;
         when Scheduler.Serial =>
            Tasks.Serial (Inputs);
            Run_Stats_Save;
         when Scheduler.Gyro =>
            Run_Gyro;
         when Scheduler.Filter =>
            Run_Filter (Before);
         when Scheduler.Accel =>
            Tasks.Accelerometer (Before);
         when Scheduler.Attitude =>
            Run_Attitude (Before);
         when Scheduler.Rx =>
            Run_Receiver (Before);
         when Scheduler.PID =>
            Run_Control (Before);
         when Scheduler.Battery_Voltage =>
            Run_Battery_Voltage;
         when Scheduler.Battery_Current =>
            Run_Battery_Current (Before);
         when Scheduler.Battery_Alerts =>
            Tasks.Battery_Alerts (Inputs, Before);
         when Scheduler.Beeper =>
            Run_Beeper (Before);
         when Scheduler.OSD =>
            Run_OSD (Before);
         when Scheduler.CMS =>
            if Adaflight.Build_Features.Menus then
               Run_Menu (Before);
            end if;
         when Scheduler.GPS =>
            Run_GPS (Before);
         when Scheduler.Position =>
            Adaflight.Position_Estimator.Update (Pos_State, Pos_Settings, Position_Inputs (Before));
         when Scheduler.Alt_Hold =>
            Run_Altitude_Hold;
         when Scheduler.Pos_Hold =>
            Run_Position_Hold;
         when Scheduler.GPS_Rescue =>
            Tasks.GPS_Rescue (Inputs);
         when Scheduler.RC_Device =>
            Run_RunCam;
         when Scheduler.Gimbal =>
            if Adaflight.Build_Features.Gimbal then
               Run_Gimbal (Before);
            end if;
         when Scheduler.OSD_Custom_Text =>
            Adaflight.STM32.OSD_Custom_Text.Update (Config.Osd_Custom_Text_Config.Terminator);
         when Scheduler.Rangefinder =>
            Tasks.Rangefinder (Inputs, Before);
         when Scheduler.ESC_Sensor =>
            Adaflight.STM32.ESC_Sensor.Run (Before, Adaflight.STM32.Control.Motor_Count);
         when Scheduler.ADC_Internal =>
            Run_ADC_Internal;
         when Scheduler.Telemetry =>
            if not Session.Open and then (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0 then
               Adaflight.STM32.FrSky_Hub.Run (FrSky_Hub_Inputs);
               Adaflight.STM32.SmartPort.Run (SmartPort_Inputs);
               if Adaflight.Build_Features.LTM_Telemetry then
                  Adaflight.STM32.LTM.Run (Adaflight.STM32.Time.Millis, LTM_Inputs);
               end if;
               if Adaflight.Build_Features.Jeti_EX_Bus then
                  Adaflight.STM32.Radio.Jeti_Telemetry_Step (Jeti_Inputs, Adaflight.STM32.Time.Micros);
               end if;
               if Adaflight.Build_Features.MAVLink_Telemetry then
                  declare
                     Requests : Adaflight.MAVLink_Commands.Requests;
                  begin
                     Adaflight.STM32.MAVLink.Run
                       (Adaflight.STM32.Time.Micros, Adaflight.STM32.Time.Millis, MAVLink_Inputs,
                        (Armed  => Adaflight.STM32.Pilot.Armed, GPS_Fix => Adaflight.STM32.GPS.Current.Fix,
                         Now_Us => Adaflight.STM32.Time.Micros, Now_Ms => Adaflight.STM32.Time.Millis),
                        Requests);
                     Serve_MAVLink_Requests (Requests);
                  end;
               end if;
            end if;
            Tasks.Telemetry (Inputs, Before);
            if not Session.Open and then (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0 then
               Adaflight.STM32.Radio.GHST_Telemetry_Step (GHST_Inputs);
               if Adaflight.Build_Features.IBus_Telemetry then
                  Adaflight.STM32.IBus.Run (IBus_Inputs);
               end if;
            end if;
         when Scheduler.LED_Strip =>
            Run_LED_Strip;
         when Scheduler.PINIO_Box =>
            Adaflight.STM32.PINIO.Update;
         when Scheduler.VTX_Control =>
            declare
               Save : Boolean;
            begin
               Adaflight.STM32.VTX.Run (Config, Adaflight.STM32.Time.Millis, Before, Session.Open, Save);
               if Save then
                  Write_Configuration;
               end if;
            end;
         when others =>
            null;
      end case;
      Scheduler.Execute_End (Sched, Sched_Settings, Before, Adaflight.STM32.Time.Micros);
   end Run_Body;

   procedure Run_Task (Id : Scheduler.Task_Id; Now_Us : Unsigned_32) is
   begin
      Scheduler.Execute_Begin (Sched, Id, Now_Us);
      Run_Body (Id);
   end Run_Task;

   --  The boot signal after the sensors: ten flashes of the LED, each with a
   --  25 millisecond beep unless the system init sound is off.
   procedure Boot_Beeps is
      Beeps : constant Boolean := not Beep_Settings.Off_Flags (Adaflight.Beeper.System_Init);
   begin
      Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
      for I in 1 .. 10 loop
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Adaflight.STM32.Time.Delay_Ms (25);
         if Beeps then
            Adaflight.STM32.Sound.Set (True);
         end if;
         Adaflight.STM32.Time.Delay_Ms (25);
         Adaflight.STM32.Sound.Set (False);
      end loop;
      Adaflight.STM32.GPIO.Set_High (Adaflight.Board.LED0_Pin);
   end Boot_Beeps;

   --  The MSP ports as the reference opens them after the other serial
   --  functions: the MSP slots, then the ports the features that talk MSP
   --  imply, each at its rate and duplex on a port no function holds.
   procedure Open_MSP_Lines is
      Present : Adaflight.MSP_Allocation.Port_Flags := (others => False);
      Busy    : Adaflight.MSP_Allocation.Port_Flags := (others => False);
      Plan    : Adaflight.MSP_Allocation.Opened_Ports;
      Count   : Adaflight.MSP_Allocation.Port_Count;
   begin
      for S in Adaflight.STM32.Serial.Line loop
         Present (Line_Id (S)) := True;
         Busy (Line_Id (S)) := S /= Adaflight.STM32.Serial.VCP and then Held_Before_MSP (UART_Of (S));
      end loop;
      Adaflight.MSP_Allocation.Allocate
        (Adaflight.Config_Fix.Serial_Options, Adaflight.Config_Fix.Serial_Assignments (Config),
         Config.Msp_Config.Half_Duplex /= 0, Present, Busy, Plan, Count);
      Line_Count := Count;
      for L in 1 .. Count loop
         Line_Serial (L) := Line_Of (Plan (L).Port);
         Line_Rate (L) := Positive (Plan (L).Rate);
         Line_Half (L) := Plan (L).Bidirectional;
         Open_Line (L);
      end loop;
   end Open_MSP_Lines;

   procedure Init is
   begin
      Adaflight.STM32.MCU.Init_Persistent;
      Adaflight.STM32.MCU.Check_Bootloader_Request;
      Adaflight.STM32.Time.Init;
      Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
      Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
      Adaflight.STM32.USART.Init_Inverters;
      Init_Configuration;
      Adaflight.STM32.PINIO.Init (Config);
      declare
         Bind_Saved : Boolean;
      begin
         Adaflight.STM32.Radio.Bind_At_Power_Up (Config, Bind_Saved);
         if Bind_Saved then
            Write_Configuration;
            Confirmation_Beeps (1);
         end if;
      end;
      Adaflight.STM32.RTC.Set_Zone (Config.Time_Config.Tz_Offset_Minutes);
      Adaflight.STM32.USB.Init ("Adaflight (" & Adaflight.Board.Board_Name & ")");
      Ctx.Out_Views.Common := Common_Snapshot;
      Ctx.Out_Views.Build := (others => True);
      for I in Ports'Range loop
         Ctx.Out_Views.Serial_Ports (I) := (Port => Ports (I), Available => True);
      end loop;
      Ctx.Out_Views.Serial_Count := Ports'Length;
      if Tagged_Pin (Config.Beeper_Dev_Config.Io_Tag) then
         Adaflight.STM32.Sound.Init
           (Pin_Of (Config.Beeper_Dev_Config.Io_Tag), Config.Beeper_Dev_Config.Frequency,
            Inverted => Config.Beeper_Dev_Config.Is_Inverted /= 0,
            Open_Drain => Config.Beeper_Dev_Config.Is_Open_Drain /= 0);
      end if;
      Adaflight.STM32.ADC.Init;
      declare
         Inputs : constant array (1 .. 3) of Adaflight.Config_Groups.Adc_Channel_Config_T_Record :=
           (Config.Adc_Config.Vbat, Config.Adc_Config.Current, Config.Adc_Config.Rssi);
      begin
         for Channel of Inputs loop
            if Analog_Input (Channel) then
               Adaflight.STM32.ADC.Enable (Pin_Of (Channel.Io_Tag));
            end if;
         end loop;
      end;
      Start_Buses;
      Start_Gyro;
      Init_Loop_Units;
      Adaflight.STM32.Baro.Init (Config);
      Env.Baro :=
        (Detected => Adaflight.STM32.Baro.Detected, Hardware => Adaflight.STM32.Baro.Hardware,
         Bus      => (Kind    => (case Adaflight.STM32.Baro.Bus_Type is
                                    when 1 => CLI.I2C_Bus, when 2 => CLI.SPI_Bus, when others => CLI.No_Bus),
                      Number  => Natural'Min (15, Adaflight.STM32.Baro.Bus_Number),
                      Address => Adaflight.STM32.Baro.Bus_Address));
      Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.Baro) := Adaflight.STM32.Baro.Detected;
      Adaflight.STM32.Rangefinder.Init (Config);
      Init_Internal_ADC;
      Boot_Beeps;
      Adaflight.STM32.Radio.Init (Config, Runtime_Features, Adaflight.STM32.Time.Millis, Telemetry_Config);
      Adaflight.STM32.Radio.Init_FPort_Telemetry (SmartPort_Build);
      Adaflight.STM32.GPS.Init (Config, Runtime_Features, Adaflight.STM32.Time.Millis);
      if (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0 then
         Adaflight.GPS_Lap_Timer.Init
           (Lap, Adaflight.Config_Runtime.Lap_Timer_Settings_Of (Config.Gps_Lap_Timer_Config));
      end if;
      Adaflight.STM32.OSD_Custom_Text.Init (Config);
      Adaflight.STM32.ESC_Sensor.Init (Config, Runtime_Features);
      if USB_Detect then
         Adaflight.STM32.GPIO.Enable_Port (USB_Detect_Pin.Port);
         Adaflight.STM32.GPIO.Set_Input (USB_Detect_Pin, Adaflight.STM32.GPIO.Down);
      end if;
      declare
         Save : Boolean;
      begin
         Adaflight.STM32.VTX.Init (Config, Save);
         if Save then
            Write_Configuration;
         end if;
      end;
      if Adaflight.Build_Features.Gimbal then
         Adaflight.STM32.Gimbal.Init (Config, Gimbal_Sticks);
      end if;
      Adaflight.STM32.RunCam.Init (Config, Adaflight.STM32.Time.Millis);
      Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.GPS) := Adaflight.STM32.GPS.Enabled;
      Ctx.Out_Views.State.Status.Sensors (Adaflight.MSP_Out.Rangefinder) := Adaflight.STM32.Rangefinder.Detected;
      Pilot_Facts := (Sensors        => (Gyro => Selection.Found, Acc => Gyro_Report.Acc_Found, others => False),
                      Sample_Time_Us => Natural (Sample_Us),
                      Loop_Ratio     => Positive (Loop_Ratio),
                      CRSF           => Adaflight.STM32.Radio.Is_CRSF);
      Adaflight.STM32.Pilot.Init (Config, Runtime_Features, Pilot_Facts);
      Adaflight.STM32.PINIO.Init_Boxes (Config);
      Adaflight.STM32.Pilot.Set_Reason (Adaflight.Arming.No_Gyro, not Selection.Found);
      Adaflight.STM32.Control.Init (Config, Runtime_Features);
      Adaflight.STM32.Control.Reset_Disarmed;
      Adaflight.STM32.Motors.Init
        (Config, Adaflight.STM32.Control.Motor_Count, (Runtime_Features and Adaflight.Config_Fix.Feature_3D) /= 0);
      for M in 0 .. Natural'Min (8, Adaflight.STM32.Motors.Count) - 1 loop
         if Adaflight.STM32.Motors.Stream_Of (M) > 0 then
            Env.DMA_Motors (Adaflight.STM32.Motors.Stream_Of (M)) := M + 1;
         end if;
      end loop;
      Adaflight.STM32.DShot_Output.Init (Config);
      Adaflight.STM32.Control.Init_Servos
        (Config, Runtime_Features, Adaflight.STM32.Radio.Channel_Count, Natural (Sample_Us) * Positive (Loop_Ratio));
      Show_Servos;
      Strip_Layout := Adaflight.LED_Strip.Evaluate (Strip_Settings);
      if (Runtime_Features and Adaflight.Config_Fix.Feature_LED_Strip) /= 0 then
         Adaflight.STM32.LED_Strip.Init (Config);
         Adaflight.LED_Strip.Init (Strip, Strip_Settings, Strip_Layout);
         Adaflight.STM32.LED_Strip.Send (Strip.Output);
      end if;
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Init (Bat, Bat_Settings);
      Start_OSD;
      if Selection.Found then
         Adaflight.STM32.Time.Delay_Ms (First_Read_Delay_Ms);
      end if;
      Init_Scheduler;
      Adaflight.STM32.Blackbox.Init (Config, Loop_Time_Us);
      Adaflight.STM32.Baro.Start_Calibration;
      Open_MSP_Lines;
      Pos_Settings :=
        Adaflight.Config_Runtime.Position_Estimator_Settings_Of (Config.Position_Config, Config.Pos_Hold_Config);
      Adaflight.Position_Estimator.Init (Pos_State, Pos_Settings, Armed => Adaflight.STM32.Pilot.Armed);
      Alt_Hold_Settings := Adaflight.Config_Runtime.Altitude_Hold_Settings_Of
        (Config.Autopilot_Config, Config.Alt_Hold_Config, Config.Rx_Config);
      Adaflight.Altitude_Hold.Init (Alt_Hold_State, Alt_Hold_Settings, Pos_State.Control_Altitude_Cm);
      Control_Settings := Adaflight.Config_Runtime.Position_Control_Settings_Of
        (Config.Autopilot_Config, Config.Rc_Controls_Config, Rescue_Plan => False);
      Pos_Hold_Settings := Adaflight.Config_Runtime.Position_Hold_Settings_Of (Config.Pos_Hold_Config);
      Adaflight.Position_Hold.Init (Pos_Hold_State, Pos_Hold_Settings, Control_Settings);
      Adaflight.Position_Nav.Init (Navigator);
      Rescue_Settings := Adaflight.Config_Runtime.GPS_Rescue_Settings_Of
        (Config.Gps_Rescue_Config, Config.Autopilot_Config, Config.Gps_Config);
      Adaflight.GPS_Rescue.Init (Rescue_State, Rescue_Settings);
      Adaflight.STM32.FrSky_Hub.Init
        (Config, Runtime_Features,
         Adaflight.Config_Runtime.FrSky_Hub_Settings_Of
           (Config.Telemetry_Config, Config.Motor_Config,
            (Gyro => Selection.Found, Acc => Gyro_Report.Acc_Found, Baro => Adaflight.STM32.Baro.Detected, Mag => False),
            Altitude_Present => Adaflight.STM32.Rangefinder.Detected,
            GPS_Present      => (Runtime_Features and Adaflight.Config_Fix.Feature_GPS) /= 0,
            Acc_1G_Rec       => Float'Max (0.0, Float'Min (1.0, Acc_State.One_G_Reciprocal))));
      if not Adaflight.STM32.Radio.Is_FPort then
         Adaflight.STM32.SmartPort.Init (Config, Runtime_Features, SmartPort_Build);
      end if;
      if Adaflight.Build_Features.LTM_Telemetry then
         Adaflight.STM32.LTM.Init (Config, Runtime_Features);
      end if;
      if Adaflight.Build_Features.Jeti_EX_Bus then
         Adaflight.STM32.Radio.Init_Jeti_Telemetry
           (Adaflight.Config_Runtime.Jeti_Settings_Of
              (Config.Battery_Config, Config.System_Config, Runtime_Features,
               (Gyro => Selection.Found, Acc => Gyro_Report.Acc_Found, Baro => Adaflight.STM32.Baro.Detected, Mag => False)),
            Feature_On => (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0);
      end if;
      if Adaflight.Build_Features.MAVLink_Telemetry then
         Adaflight.STM32.MAVLink.Init (Config, Runtime_Features, (UID (1), UID (2), UID (3)));
      end if;
      Adaflight.STM32.Radio.Init_GHST_Telemetry
        (Adaflight.Config_Runtime.GHST_Settings_Of
           (Config.Telemetry_Config, Config.Battery_Config, Runtime_Features,
            (Gyro => Selection.Found, Acc => Gyro_Report.Acc_Found, Baro => Adaflight.STM32.Baro.Detected, Mag => False)),
         Feature_On => (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0);
      if Adaflight.Build_Features.IBus_Telemetry then
         Adaflight.STM32.IBus.Init
           (Config, Runtime_Features,
            Adaflight.Config_Runtime.IBus_Settings_Of
              (Config.Telemetry_Config, Float'Max (0.0, Float'Min (1.0, Acc_State.One_G_Reciprocal))));
      end if;
      if Adaflight.Build_Features.Menus and then (Runtime_Features and Adaflight.Config_Fix.Feature_Telemetry) /= 0
        and then Adaflight.STM32.Radio.Is_CRSF
      then
         Adaflight.STM32.Menu.Register_CRSF (Adaflight.STM32.Radio.Display_Columns, Adaflight.STM32.Radio.Display_Rows);
      end if;
      Check_Telemetry;
      Offered := Available_Boxes;
      Adaflight.STM32.DShot_Output.Enable;
      Blink := Ada.Real_Time.Clock;
   end Init;

   --  The failsafe's check every ten milliseconds of the realtime block over
   --  the arming, the failsafe box, the throttle status, a configurator on
   --  MSP that silences the lost link tones, and the controller's crash
   --  recovery, with no autopilot on this image: its lost link tones, its
   --  landed stage's disarm, and its flight mode with the confirmation beep
   --  of a change.
   procedure Check_Failsafe is
      Beep     : Adaflight.Failsafe.Beep;
      Disarm   : Boolean;
      Changed  : Boolean;
      Asked    : Adaflight.Arming.Outputs;
      In_Flight : constant Adaflight.Failsafe.Inputs :=
        (Armed               => Adaflight.STM32.Pilot.Armed,
         Switch_On           => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Failsafe),
         Throttle_Low        => Adaflight.STM32.Pilot.Throttle_Low (Flight_Channels),
         Configurator_Active => Configurator_Active,
         Crash_Recovery      => Adaflight.STM32.Control.Crash_Recovery_Active,
         others              => False);
   begin
      Adaflight.STM32.Radio.Failsafe_Check (Adaflight.STM32.Time.Millis, In_Flight, Beep, Disarm);
      Sync_Reasons;
      case Beep is
         when Adaflight.Failsafe.Rx_Lost => Request_Beep (Adaflight.Beeper.Rx_Lost);
         when Adaflight.Failsafe.Rx_Lost_Landing => Request_Beep (Adaflight.Beeper.Rx_Lost_Landing);
         when Adaflight.Failsafe.Silence => null;
      end case;
      if Disarm then
         Adaflight.STM32.Pilot.Disarm (Adaflight.Arming.Failsafe, Adaflight.STM32.Time.Micros, Asked);
         Apply (Asked);
      end if;
      Adaflight.STM32.Pilot.Set_Failsafe_Mode (Adaflight.STM32.Radio.Failsafe_Mode, Changed);
      if Changed then
         Confirmation_Beeps (1);
      end if;
   end Check_Failsafe;

   --  One pass of the scheduler in its phases: the realtime tasks at the
   --  gyro's target, the gyro lock, the selection over the queue with the
   --  checks, the held task's run, and the LED's blink.
   procedure Pass is
      G        : Scheduler.Gyro_Status;
      Poll     : Boolean;
      Proceed  : Boolean;
      Selected : Boolean;
      Run_It   : Boolean;
      Due      : Boolean;
      Now      : Unsigned_32;
      Start_Us : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
   begin
      Now := (if Sched.Gyro_Enabled then Adaflight.STM32.Time.Cycle_Count else 0);
      Scheduler.Begin_Pass (Sched, Now, Poll);
      if Poll then
         while Adaflight.Clock.Elapsed (Sched.Pass.Next_Target, Now) > 0 loop
            Now := Adaflight.STM32.Time.Cycle_Count;
         end loop;
         declare
            Now_Us : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
         begin
            Run_Task (Scheduler.Gyro, Now_Us);
            if Adaflight.Core_Loop.Filter_Ready (Cadence, Loop_Ratio) then
               Run_Task (Scheduler.Filter, Now_Us);
            end if;
            if Adaflight.Core_Loop.PID_Ready (Cadence, Loop_Ratio) then
               Run_Task (Scheduler.PID, Now_Us);
            end if;
         end;
         declare
            Now_Us : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
         begin
            Adaflight.STM32.Radio.Frame_Check
              (Now_Us, Adaflight.Clock.Elapsed (Now_Us, Sched.Tasks (Scheduler.Rx).Last_Executed_Us),
               Adaflight.RX_Task.In_Progress (RX_State));
         end;
         if Scheduler.Failsafe_Due (Sched, Adaflight.STM32.Time.Millis) then
            Check_Failsafe;
            Scheduler.Failsafe_Checked (Sched, Adaflight.STM32.Time.Millis);
         end if;
         G := (Interrupts   => Adaflight.STM32.Gyro.Mode /= Adaflight.STM32.Gyro.No_Interrupt,
               Detected     => Adaflight.STM32.Gyro.Interrupt_Count,
               Sync_Cycles  => Adaflight.STM32.Gyro.Sync_Cycles,
               Short_Period => Adaflight.STM32.Gyro.Short_Period);
         Scheduler.End_Realtime (Sched, Sched_Settings, Now, G);
      end if;
      Now := Adaflight.STM32.Time.Cycle_Count;
      Scheduler.Begin_Selection (Sched, Sched_Settings, Now, Adaflight.STM32.Time.Micros, Proceed);
      if Proceed then
         for Q in 0 .. Sched.Queue_Size - 1 loop
            if Scheduler.Needs_Check (Sched, Q) then
               Check (Scheduler.Queued (Sched, Q), Scheduler.Check_Delta (Sched, Q), Due);
               Scheduler.Consider (Sched, Sched_Settings, Q, Due, Adaflight.STM32.Time.Micros);
            else
               Scheduler.Consider (Sched, Sched_Settings, Q, False, 0);
            end if;
         end loop;
         Scheduler.End_Selection (Sched, Adaflight.STM32.Time.Cycle_Count, Selected);
         if Selected then
            Scheduler.Confirm (Sched, Sched_Settings, Adaflight.STM32.Time.Cycle_Count, Run_It);
            if Run_It then
               Scheduler.Run_Selected_Begin (Sched);
               Run_Body (Sched.Current);
               Scheduler.After_Run (Sched, Sched_Settings, Adaflight.STM32.Time.Cycle_Count);
            end if;
         end if;
      end if;
      Scheduler.End_Pass (Sched, Sched_Settings, Start_Us, Adaflight.STM32.Time.Micros);
      if Ada.Real_Time.Clock >= Blink then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Blink := Blink + Milliseconds (500);
      end if;
   end Pass;
end Adaflight.STM32.Flight;
