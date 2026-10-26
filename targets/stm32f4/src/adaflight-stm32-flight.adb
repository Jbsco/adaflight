with Ada.Characters.Handling;
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Source_Info;
with Interfaces; use Interfaces;
with System;
with Adaflight.Acc_Inflight;
with Adaflight.Accelerometer;
with Adaflight.Arming;
with Adaflight.Attitude;
with Adaflight.Axes;
with Adaflight.Battery;
with Adaflight.Board;
with Adaflight.Board_Info;
with Adaflight.Bytes;
with Adaflight.Clock;
with Adaflight.Config_Codec;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups;
with Adaflight.Config_Reset;
with Adaflight.Config_Runtime;
with Adaflight.Config_Store;
with Adaflight.Core_Loop;
with Adaflight.Gyro_Filters;
with Adaflight.Gyro_Selection;
with Adaflight.Mixer;
with Adaflight.Mixer_Init;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Box;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_Motor_In;
with Adaflight.Modes;
with Adaflight.MSP_Out;
with Adaflight.MSP_Port;
with Adaflight.MSP_Processor;
with Adaflight.PID_Config;
with Adaflight.Pins;
with Adaflight.PID_Controller;
with Adaflight.RC_Command;
with Adaflight.Receiver;
with Adaflight.RPM_Filter;
with Adaflight.RX_Task;
with Adaflight.Scheduler;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.ADC;
with Adaflight.STM32.Console;
with Adaflight.STM32.Control;
with Adaflight.STM32.Flash;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Gyro;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Radio;
with Adaflight.STM32.SPI;
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

   --  The identity the configurator reads: the firmware variant, the version
   --  as a year, month and patch with its text.
   Variant       : constant Common.Four_Letters := "ADFL";
   Version_Year  : constant := 2026;
   Version_Month : constant := 10;
   Version_Patch : constant := 0;
   Version_Text  : constant String := "0.1.0";

   --  The device's unique identifier, the three words the status prints.
   UID : array (1 .. 3) of Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#1FFF_7A10#);

   --  The core's application interrupt and reset control register: the key
   --  in its high half with the system reset request.
   AIRCR : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#E000_ED0C#);
   System_Reset_Request : constant Unsigned_32 := 16#05FA_0004#;

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
   Board    : CLI.Board_State;
   Config   : Adaflight.Config_Groups.Configuration := Adaflight.Config_Reset.Reset (Board);
   Sched    : Scheduler.State;
   Session  : Terminal.Session;
   Into     : CLI.Output;
   Changes  : CLI.Effects;
   --  The board's serial ports by identifier: UART1, UART3, UART4 and UART6.
   Ports    : constant CLI.Port_List (1 .. 4) := (UART1_Id, 53, 54, 56);
   Input    : Adaflight.Bytes.Byte_Array (0 .. 63);
   Count    : Natural;
   Now_Ms   : Unsigned_32;
   Port     : Adaflight.MSP_Port.Port;
   Links    : Adaflight.MSP_Control_In.Link_State;
   Pending  : Adaflight.Bytes.Byte_Array (0 .. 255) := (others => 0);
   Waiting  : Natural := 0;
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
   RX_State         : Adaflight.RX_Task.State;
   Bat              : Adaflight.Battery.State;
   Bat_Settings     : Adaflight.Battery.Settings;
   Pilot_Facts      : Adaflight.STM32.Pilot.Facts;
   --  The attitude task's periods with the level modes on and off.
   Attitude_Period_Slow_Us : constant Scheduler.Time_Delta := 10_000;
   Attitude_Period_Fast_Us : Scheduler.Time_Delta := 2_000;

   procedure Apply (Step : Adaflight.Arming.Outputs);
   procedure Report_Battery;
   function Flight_Channels return Adaflight.RC_Command.Channel_Values;
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

   function Text (S : String) return Common.Text is
      T : Common.Text;
   begin
      T.Length := Natural'Min (S'Length, Common.Max_Text);
      T.Data (1 .. T.Length) := S (S'First .. S'First + T.Length - 1);
      return T;
   end Text;

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
      Build_Options   => <>,
      Option_Count    => 0,
      Soft_Serial     => False,
      Serial_Ports    => <>,
      Gyro_Positions  => 1,
      Gyros_Enabled   => 0,
      Gyros           => <>,
      Acc             => <>,
      Baro            => <>,
      Mag             => <>,
      Raw_Gyro_ICM456 => False,
      Interactive     => True,
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
                          Internal_ADC  => False,
                          Vref_Mv       => 3300,
                          Core_Temp_C   => 0,
                          Stack_Total   => Stack_Size,
                          Stack_High    => 16#2002_0000#,
                          others        => <>));

   procedure Reset is
   begin
      AIRCR := System_Reset_Request;
      loop
         null;
      end loop;
   end Reset;

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

   --  Whether the stored configuration names this board.
   function Board_Matches return Boolean is
      Stored : String (1 .. Board_Identifier'Length);
   begin
      for I in Stored'Range loop
         Stored (I) := Character'Val (Config.System_Config.Board_Identifier (I - 1));
      end loop;
      return Ada.Characters.Handling.To_Upper (Stored) = Board_Identifier;
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

   --  The stored configuration loaded: every group from its defaults and
   --  its stored bytes, the running features, the checks, and the board's
   --  information taken in; Success says the image held every group.
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
   procedure Start_Gyro is
      Inputs : Adaflight.Gyro_Selection.Inputs;
      Rate   : Adaflight.Config_Fix.Gyro_Rate;
      Bus    : constant CLI.Device_Bus := (Kind => CLI.SPI_Bus, Number => 1, Address => 0);
   begin
      Adaflight.STM32.SPI.Init (Adaflight.Board.SPI1_SCK_Pin, Adaflight.Board.SPI1_SDI_Pin,
                                Adaflight.Board.SPI1_SDO_Pin);
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
      Options : constant Adaflight.Task_Init.Options := (Accel => True, Sag_Compensation => True, others => False);
      Inputs  : Adaflight.Task_Init.Inputs;
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
      Inputs.Acc_Detected := Gyro_Report.Acc_Found;
      Inputs.Acc_Sample_Rate_Hz := Gyro_Report.Acc_Sample_Rate_Hz;
      Adaflight.Task_Init.Init (Sched, Sched_Settings, Adaflight.STM32.Time.Cycle_Count, Options, Inputs);
   end Init_Scheduler;

   --  The command line takes the port: an interactive session from the hash
   --  mark, a configurator session from the start of text.
   procedure Enter_Command_Line (Interactive : Boolean) is
   begin
      Env.Interactive := Interactive;
      Terminal.Enter (Session, Into, Interactive, Now_Ms);
   end Enter_Command_Line;

   --  One command frame through the processor, a requested write of the
   --  configuration with its read back, then its reply framed and sent.
   procedure Answer is
      Unused_Success : Boolean;
      Asked          : Adaflight.Arming.Outputs;
   begin
      Env.Now_Us := Now_Ms * 1000;
      Env.Status.Uptime_Ms := Now_Ms;
      Adaflight.Stream_Buffers.Init (Stream, 0, Reply'Length);
      MSP.Process (Ctx, Config, Board, Links, Unsigned_16 (Port.Command_Id), Port.Data (0 .. Port.Data_Size - 1),
                   Ports, Reply, Stream, Result, Effects);
      if Effects.Receiver.Modes_Init then
         Adaflight.STM32.Pilot.Reload_Modes (Config);
      end if;
      if Effects.Control.Acc_Calibration then
         Adaflight.Accelerometer.Start_Calibration (Acc_State);
      end if;
      if Effects.Control.Disarm then
         Adaflight.STM32.Pilot.Disarm (Adaflight.STM32.Time.Micros, Asked);
         Apply (Asked);
      end if;
      if Effects.Save then
         Scheduler.Ignore_Task_State_Time (Sched);
         Write_Configuration;
         Load_Configuration (Unused_Success);
      end if;
      Adaflight.MSP_Port.Encode (Port.Version, Port.Command_Id, Port.Flags, Result = MSP.Error,
                                 Reply (0 .. Stream.Next - 1), Frame, Frame_Length);
      Adaflight.STM32.USART.Put (Into.Target, Frame (0 .. Frame_Length - 1));
      if Effects.Reboot then
         Reset;
      end if;
   end Answer;

   --  The serial task: the bytes received go to the command line while its
   --  session is open, otherwise to the MSP port, which evaluates the other
   --  data while disarmed. The status reply reads the loop timing first.
   procedure MSP_Serial (Evaluate_Other_Data : Boolean) is
   begin
      Now_Ms := Adaflight.STM32.Time.Millis;
      Ctx.Out_Views.State.Status.PID_Delta_Us := Scheduler.Task_Delta_Time (Sched, Scheduler.PID);
      Ctx.Out_Views.State.Status.Load_Percent := Unsigned_16 (Sched.Average_Load_Percent);
      Env.Gyros (0).Mode := Gyro_Mode;
      Report_Battery;
      Adaflight.STM32.USART.Take (Adaflight.STM32.USART.UART1, Input, Count);
      if Count > 0 then
         declare
            Room : constant Natural := Pending'Length - Waiting;
            Take : constant Natural := Natural'Min (Count, Room);
         begin
            Pending (Waiting .. Waiting + Take - 1) := Input (0 .. Take - 1);
            Waiting := Waiting + Take;
         end;
      end if;
      if Session.Open then
         if Waiting > 0 then
            Terminal.Process (Session, Into, Pending (0 .. Waiting - 1), Now_Ms, Config, Ports, Env, Board, Sched,
                              Changes);
            Waiting := 0;
            if Changes.Modes then
               Adaflight.STM32.Pilot.Reload_Modes (Config);
            end if;
            if Changes.PID_Profile or else Changes.Rate_Profile then
               Adaflight.STM32.Pilot.Configure (Config, Runtime_Features, Pilot_Facts);
               Adaflight.STM32.Control.Init (Config, Runtime_Features);
            end if;
            if Changes.Save then
               Write_Configuration;
            end if;
            if Changes.Reboot then
               Reset;
            end if;
            Changes := (others => <>);
         end if;
      else
         loop
            Adaflight.MSP_Port.Process
              (Port, Pending (0 .. Waiting - 1), Consumed, Now_Ms,
               (Evaluate_Non_MSP => Evaluate_Other_Data, Peripheral => False,
                Reboot_Character => Config.Serial_Config.Reboot_Character, CLI_Running => False),
               Event);
            Pending (0 .. Waiting - Consumed - 1) := Pending (Consumed .. Waiting - 1);
            Waiting := Waiting - Consumed;
            case Event is
               when Adaflight.MSP_Port.Command_Frame =>
                  Answer;
               when Adaflight.MSP_Port.CLI_Opened =>
                  Enter_Command_Line (Interactive => True);
               when Adaflight.MSP_Port.CLI_Command_Entered =>
                  Enter_Command_Line (Interactive => False);
               when Adaflight.MSP_Port.Reset_Requested =>
                  Reset;
               when Adaflight.MSP_Port.Reply_Frame | Adaflight.MSP_Port.Nothing =>
                  null;
            end case;
            exit when Session.Open or else Consumed = 0 or else Waiting = 0;
         end loop;
      end if;
   end MSP_Serial;

   --  The accelerometer task: one reading through the accelerometer unit,
   --  and its counts over the one g divisor into the raw readings reply.
   procedure Acc_Update (Now_Us : Scheduler.Time_Us) is
      pragma Unreferenced (Now_Us);
      Raw : Adaflight.STM32.Gyro.Axis_Values;
      OK  : Boolean;
   begin
      Adaflight.STM32.Gyro.Read_Acc (Raw, OK);
      if not OK then
         return;
      end if;
      Adaflight.Accelerometer.Update
        (Acc_State, Acc_Settings, (Integer (Raw (0)), Integer (Raw (1)), Integer (Raw (2))), Acc_Cal);
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

   --  An analog channel's sample, zero when the channel is off.
   function Analog (Channel : Adaflight.Config_Groups.Adc_Channel_Config_T_Record; P : Adaflight.Pins.Pin)
                    return Natural is
     (if Channel.Enabled and then Adaflight.STM32.ADC.Has_Channel (P)
      then Natural (Adaflight.STM32.ADC.Read (P)) else 0);

   --  What the battery's other meters read: the arming, the throttle status
   --  with the motor stop feature and the mixer's throttle for the virtual
   --  meter.
   function Meters return Adaflight.Battery.Meter_Inputs is
     (ESC_Sensor   => False,
      ESC          => <>,
      Armed        => Adaflight.STM32.Pilot.Armed,
      Throttle_Low => Adaflight.STM32.Pilot.Throttle_Low (Flight_Channels),
      Motor_Stop   => (Runtime_Features and Adaflight.Config_Fix.Feature_Motor_Stop) /= 0,
      Throttle     => Float'Max (0.0, Float'Min (1.0, Adaflight.STM32.Control.Throttle)),
      Now_Ms       => Adaflight.STM32.Time.Millis);

   procedure Run_Battery_Voltage is
   begin
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Update_Voltage
        (Bat, Bat_Settings, Analog (Config.Adc_Config.Vbat, Adaflight.Board.ADC_VBAT_Pin),
         Adaflight.STM32.Time.Millis, Meters);
   end Run_Battery_Voltage;

   procedure Run_Battery_Current (Before : Unsigned_32) is
   begin
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Update_Current
        (Bat, Bat_Settings, Analog (Config.Adc_Config.Current, Adaflight.Board.ADC_CURR_Pin), Before, Meters);
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

   procedure No_Step is null;
   procedure No_Step_At (Now_Us : Scheduler.Time_Us) is null;
   procedure No_Step_Tilt (Now_Us : Scheduler.Time_Us; Cos_Tilt : Float) is null;
   procedure No_Step_Period (Now_Us : Scheduler.Time_Us; Next_Period_Us : out Scheduler.Time_Delta) is
      pragma Unreferenced (Now_Us);
   begin
      Next_Period_Us := 0;
   end No_Step_Period;

   package Tasks is new Adaflight.Task_Functions
     (SD_Card_Poll           => No_Step,
      Flash_Erase            => No_Step,
      MSP_Serial             => MSP_Serial,
      Battery_Presence       => Battery_Presence,
      Battery_States         => Battery_States,
      Battery_Alarms         => No_Step,
      Acc_Update             => Acc_Update,
      GPS_Rescue_Update      => No_Step,
      Baro_Update            => No_Step_Period,
      Pitot_Update           => No_Step_Period,
      Compass_Update         => No_Step_Period,
      Position_Update        => No_Step,
      Rangefinder_Update     => No_Step,
      Rangefinder_Process    => No_Step_Tilt,
      Optical_Flow_Update    => No_Step,
      Optical_Flow_Process   => No_Step,
      Telemetry_Poll_Sensors => No_Step_At,
      Telemetry_Process      => No_Step_At,
      Camera_Control_Process => No_Step_At);

   --  The gyro task: one reading into the gyro filters' accumulation, and
   --  the core loop's cadence.
   procedure Run_Gyro is
      Raw      : Adaflight.STM32.Gyro.Axis_Values;
      OK       : Boolean;
      Unused_Finished : Boolean;
   begin
      Adaflight.STM32.Gyro.Read_Gyro (Raw, OK);
      Adaflight.Gyro_Filters.Accumulate
        (Gyro_State, Gyro_Settings,
         (0 => (Integer (Raw (0)), Integer (Raw (1)), Integer (Raw (2))), others => (0, 0, 0)),
         (0 => OK, others => False), Unused_Finished);
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
   --  and the accelerometer, without a compass, disarmed and without the
   --  angle or headfree modes, then the angles and the quaternion into the
   --  attitude replies.
   procedure Run_Attitude (Now_Us : Scheduler.Time_Us) is
      Rates : constant Adaflight.Vectors.Vector3 :=
        (X => Gyro_State.Downsampled (Adaflight.Axes.Roll),
         Y => Gyro_State.Downsampled (Adaflight.Axes.Pitch),
         Z => Gyro_State.Downsampled (Adaflight.Axes.Yaw));
      No_Mag : constant Adaflight.Vectors.Vector3 := (0.0, 0.0, 0.0);
      Magnitude : constant Float := Float'Max (0.0, Float'Min (1.0e3, Acc_State.Magnitude));
   begin
      Adaflight.Attitude.Update
        (Att_State, Att_Config, Now_Us, Rates, Acc_State.Acc, Magnitude, No_Mag,
         Use_Mag => False, Armed => False, Angle_Mode => False, Headfree_Mode => False);
      Ctx.Out_Views.State.Attitude :=
        (Roll  => Integer_16 (Att_State.Euler.Roll),
         Pitch => Integer_16 (Att_State.Euler.Pitch),
         Yaw   => Integer_16 (Att_State.Euler.Yaw),
         W     => Adaflight.MSP_Out.Component (Att_State.Reported.W),
         X     => Adaflight.MSP_Out.Component (Att_State.Reported.X),
         Y     => Adaflight.MSP_Out.Component (Att_State.Reported.Y),
         Z     => Adaflight.MSP_Out.Component (Att_State.Reported.Z));
   end Run_Attitude;

   --  The check function of a task with one: the receiver task's check
   --  over the link; no display yet, so no other is signaled.
   function Check (Id : Scheduler.Task_Id) return Boolean is
     (Id = Scheduler.Rx and then Adaflight.STM32.Radio.Update_Check (Adaflight.RX_Task.In_Progress (RX_State)));

   --  What the arming logic senses on the board: the link and the failsafe,
   --  the attitude within the small angle once established or no
   --  accelerometer, the calibrations, no motor protocol yet, the scheduler's
   --  late share, the filtered rates and the stick deflections, and the
   --  command line.
   function Sense return Adaflight.Arming.Inputs is
      Sensed : Adaflight.Arming.Inputs;
   begin
      Sensed.Rx_Signal := Adaflight.STM32.Radio.Receiving;
      Sensed.Failsafe_Receiving := Adaflight.STM32.Radio.Failsafe_Receiving;
      Sensed.Failsafe_Active := Adaflight.STM32.Radio.Failsafe_Active;
      Sensed.Failsafe_Monitoring := Adaflight.STM32.Radio.Failsafe_Monitoring;
      Sensed.Upright := not Gyro_Report.Acc_Found
        or else (Att_State.Established
                 and then Adaflight.Attitude.Cos_Tilt (Att_State) > Att_Config.Small_Angle_Cos);
      Sensed.Gyro_Calibrated := Adaflight.Gyro_Filters.Calibration_Complete (Gyro_State);
      Sensed.Acc_Calibrated := Adaflight.Accelerometer.Calibration_Complete (Acc_State);
      Sensed.Acc_Has_Calibration := Config.Accelerometer_Config.Acc_Zero (3) /= 0;
      Sensed.First_Arm_Gyro_Cal_Running := Adaflight.Gyro_Filters.First_Arm_Calibration_Running (Gyro_State);
      Sensed.Motor_Protocol_Enabled := False;
      Sensed.Late_Permille := Scheduler.CPU_Percentage_Late (Sched);
      Sensed.PID_Sums := Adaflight.STM32.Control.PID_Sums;
      for A in Adaflight.Axes.Axis loop
         Sensed.Gyro_Abs_Dps (A) := Natural (Float'Min (65_535.0, abs Gyro_State.Filtered (A)));
      end loop;
      Sensed.Deflection_Abs := Adaflight.STM32.Pilot.Deflections;
      Sensed.CLI_Mode := Session.Open;
      return Sensed;
   end Sense;

   --  What the arming logic asked of the board after a step: the stick
   --  commands the board can serve, the saves, the trims, the first arming
   --  calibration, the headfree offset, the failsafe's monitoring and the
   --  attitude task's rate. The adjustments, the beeper, the DShot commands,
   --  the statistics and the ports wait for their units on the board.
   procedure Apply (Step : Adaflight.Arming.Outputs) is
      Trims : Adaflight.Config_Groups.Integer_16_List_2 renames Config.Accelerometer_Config.Accelerometer_Trims;
      Set   : Boolean;
      Unused_Success : Boolean;
   begin
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
      end if;
      if Step.First_Arm_Gyro_Cal > 0 then
         Adaflight.Gyro_Filters.Start_Calibration (Gyro_State, Gyro_Settings, First_Arm => True);
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
   end Apply;

   --  The arming and mode state into the replies: the disable reasons, the
   --  flight mode flags, the active boxes and the armed flag.
   procedure Report_Pilot is
      Status : Adaflight.MSP_Out.Status_Values renames Ctx.Out_Views.State.Status;
   begin
      Status.Arming_Disabled := Adaflight.STM32.Pilot.Disabled;
      Env.Status.Arming_Disabled := Adaflight.STM32.Pilot.Disabled;
      Adaflight.MSP_Box.Pack_Flight_Mode_Flags
        (Active => Adaflight.STM32.Pilot.Active_Boxes, Armed => Adaflight.STM32.Pilot.Armed,
         Flight => Adaflight.STM32.Pilot.Flight_Modes, Switches => Adaflight.STM32.Pilot.Active_Boxes,
         Wing => False, Packed => Status.Mode_Flags, Count => Status.Mode_Flag_Count);
      Ctx.Out_Views.Active := Adaflight.STM32.Pilot.Active_Boxes;
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
   procedure Run_Control (Before : Unsigned_32) is
      Channels : constant Adaflight.RC_Command.Channel_Values := Flight_Channels;
      Mode     : constant Adaflight.Mixer_Init.Mixer_Mode := Adaflight.STM32.Pilot.Mixer_Mode;
      I        : Adaflight.STM32.Control.Inputs;
      Asked    : Adaflight.Arming.Outputs;
      Trims    : Adaflight.Config_Groups.Integer_16_List_2 renames Config.Accelerometer_Config.Accelerometer_Trims;
   begin
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
      I.Battery_Voltage := Unsigned_16 (Bat.Voltage.Display_Filtered);
      I.Sag_Cell_Voltage := Adaflight.Battery.Sag_Cell_Voltage (Bat);
      I.Battery_Latest := Bat.Voltage.Unfiltered;
      Adaflight.STM32.Control.Pass
        (I, Sense, Channels,
         Resets_Yaw  => Adaflight.Core_Loop.Resets_Yaw
                          (Adaflight.STM32.Pilot.Sticks_Arm, Channels (Adaflight.RC_Command.Throttle_Channel),
                           Natural (Config.Rx_Config.Mincheck), Mode, Config.Servo_Config.Tri_Unarmed_Servo /= 0),
         Uses_Servos => Adaflight.Mixer_Init.Uses_Servos (Mode),
         CLI_Open    => Session.Open,
         PID_Audio   => Adaflight.STM32.Pilot.PID_Audio_Present,
         Asked       => Asked);
      Apply (Asked);
      if Adaflight.STM32.Control.Throttle_Step_Changed then
         Adaflight.Gyro_Filters.Update_Dynamic_Lowpass
           (Gyro_State, Gyro_Settings, Adaflight.STM32.Control.Throttle_Step);
      end if;
      Ctx.Out_Views.State.Motors.Enabled := False;
      for M in Adaflight.MSP_Out.Motor_Index loop
         Ctx.Out_Views.State.Motors.External (M) :=
           Unsigned_16 (Float'Max (0.0, Float'Min (65_535.0, Adaflight.STM32.Control.Motors (M))));
      end loop;
   end Run_Control;

   --  The receiver task's state machine: the rate ignored on every step but
   --  the last, the check step through the link and the arming's receiver
   --  pass with the frame rate, the modes step through the arming's modes
   --  pass over the auxiliary channels, the update step through the RC
   --  commands and the arming status, then what the passes asked, the step's
   --  estimate for the scheduler and the channels into the RC reply.
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
      Channels := Flight_Channels;
      for A in Adaflight.Modes.Aux_Channel loop
         Aux (A) := Adaflight.STM32.Radio.Channel (A + Adaflight.Receiver.Flight_Channel_Count);
      end loop;
      case Step is
         when Adaflight.RX_Task.Check =>
            Adaflight.STM32.Radio.Process
              (Before, Adaflight.STM32.Time.Millis,
               (if Adaflight.STM32.Radio.RSSI_ADC
                then Analog (Config.Adc_Config.Rssi, Adaflight.Board.ADC_RSSI_Pin) else 0),
               Ready);
            if Ready then
               Adaflight.STM32.Pilot.Update_Refresh_Rate
                 (Before, Adaflight.STM32.Radio.Receiving, Adaflight.STM32.Radio.Last_Frame_Us);
               Adaflight.STM32.Pilot.Receiver_Pass (Sense, Channels, Before, Asked);
               Adaflight.STM32.Control.Set_Stabilisation (Asked.Stabilisation_On, Asked.Iterm_Reset);
            end if;
         when Adaflight.RX_Task.Modes =>
            Adaflight.STM32.Pilot.Modes_Pass (Sense, Channels, Aux, Before, Delta_Us, Asked);
            Adaflight.STM32.Control.Set_Anti_Gravity (Asked.Anti_Gravity);
         when Adaflight.RX_Task.Update =>
            Adaflight.STM32.Pilot.Update_Pass
              (Sense, Channels,
               (Box_3D => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.Three_D),
                LVC_Enabled => Bat.LVC_Enabled, LVC_Percentage => Bat.LVC_Percentage,
                Failsafe_Active => Adaflight.STM32.Radio.Failsafe_Active),
               Before, Asked);
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

   --  A task's body between the scheduler's execution prologue and
   --  epilogue, at the clock around its run.
   procedure Run_Body (Id : Scheduler.Task_Id) is
      Before : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Inputs : constant Tasks.Inputs := (Armed => Adaflight.STM32.Pilot.Armed, CLI_Open => Session.Open, others => <>);
   begin
      case Id is
         when Scheduler.System =>
            Scheduler.System_Load (Sched, Before);
         when Scheduler.Main =>
            Tasks.Main;
         when Scheduler.Serial =>
            Tasks.Serial (Inputs);
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

   --  The board's analog inputs: the battery voltage, the current and the
   --  RSSI.
   Analog_Pins : constant array (1 .. 3) of Adaflight.Pins.Pin :=
     (Adaflight.Board.ADC_VBAT_Pin, Adaflight.Board.ADC_CURR_Pin, Adaflight.Board.ADC_RSSI_Pin);

   procedure Init is
   begin
      Adaflight.STM32.Time.Init;
      Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
      Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
      Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.Inverter_Pin_UART1.Port);
      Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.Inverter_Pin_UART1);
      Adaflight.STM32.GPIO.Set_Low (Adaflight.Board.Inverter_Pin_UART1);
      Adaflight.STM32.USART.Init (Adaflight.STM32.USART.UART1, Baud);
      Adaflight.MSP_Port.Init (Port);
      Init_Configuration;
      Ctx.Out_Views.Common := Common_Snapshot;
      Ctx.Out_Views.Build := (others => True);
      for I in Ports'Range loop
         Ctx.Out_Views.Serial_Ports (I) := (Port => Ports (I), Available => True);
      end loop;
      Ctx.Out_Views.Serial_Count := Ports'Length;
      Adaflight.STM32.ADC.Init;
      for P of Analog_Pins loop
         if Adaflight.STM32.ADC.Has_Channel (P) then
            Adaflight.STM32.ADC.Enable (P);
         end if;
      end loop;
      Start_Gyro;
      Init_Loop_Units;
      Adaflight.STM32.Radio.Init (Config, Runtime_Features, Adaflight.STM32.Time.Millis);
      Pilot_Facts := (Sensors        => (Gyro => Selection.Found, Acc => Gyro_Report.Acc_Found, others => False),
                      Sample_Time_Us => Natural (Sample_Us),
                      Loop_Ratio     => Positive (Loop_Ratio),
                      CRSF           => Adaflight.STM32.Radio.Linked);
      Adaflight.STM32.Pilot.Init (Config, Runtime_Features, Pilot_Facts);
      Adaflight.STM32.Control.Init (Config, Runtime_Features);
      Bat_Settings := Battery_Settings;
      Adaflight.Battery.Init (Bat, Bat_Settings);
      if Selection.Found then
         Adaflight.STM32.Time.Delay_Ms (First_Read_Delay_Ms);
      end if;
      Init_Scheduler;
      Blink := Ada.Real_Time.Clock;
   end Init;

   --  One pass of the scheduler in its phases: the realtime tasks at the
   --  gyro's target, the gyro lock, the selection over the queue with the
   --  checks, the held task's run, and the LED's blink.
   procedure Pass is
      G        : Scheduler.Gyro_Status;
      Poll     : Boolean;
      Proceed  : Boolean;
      Selected : Boolean;
      Run_It   : Boolean;
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
            Adaflight.STM32.Radio.Failsafe_Check (Adaflight.STM32.Time.Millis);
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
               Scheduler.Consider (Sched, Sched_Settings, Q, Check (Scheduler.Queued (Sched, Q)),
                                   Adaflight.STM32.Time.Micros);
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
