--  The STM32F4 image. Milestone 4: the gyro and accelerometer detected and
--  started over SPI1 at boot and read every millisecond into the state the
--  MSP replies and the status report, with MSP and the command line on UART1
--  at 115200 baud while the board's LED blinks at 1 Hz. The port starts as
--  an MSP port; a hash mark hands it to the command line after the guard
--  time, a start of text at once, and the command line hands it back when
--  its session closes.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Source_Info;
with Interfaces; use Interfaces;
with System;
with Adaflight.Arming;
with Adaflight.Board;
with Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups;
with Adaflight.Config_Reset;
with Adaflight.Gyro_Selection;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_Motor_In;
with Adaflight.MSP_Out;
with Adaflight.MSP_Port;
with Adaflight.MSP_Processor;
with Adaflight.Receiver;
with Adaflight.Scheduler;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Console;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Gyro;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
with Adaflight.STM32.USART;
with Adaflight.Stream_Buffers;

procedure Adaflight_Stm32f4 is
   package CLI renames Adaflight.STM32.Console.CLI;
   package Terminal renames Adaflight.STM32.Console.Terminal;
   package MSP renames Adaflight.MSP_Processor;
   package Common renames Adaflight.MSP_Common_Out;
   use type MSP.Result;
   use type Adaflight.MSP_Port.Event;

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

   --  The failure codes the LED flashes: a missing gyro, and a gyro whose
   --  initialization read failed.
   Failure_Missing_Acc      : constant := 1;
   Failure_Gyro_Init_Failed : constant := 6;

   --  The first gyro read waits for the data ready interrupts of the start
   --  to pass the layer's detection count, as the reference's longer
   --  startup lets them.
   First_Read_Delay_Ms : constant := 250;

   Next     : Time := Clock;
   Blink    : Time := Clock;
   Board    : CLI.Board_State;
   Config   : Adaflight.Config_Groups.Configuration := Adaflight.Config_Reset.Reset (Board);
   Sched    : Adaflight.Scheduler.State;
   Session  : Terminal.Session;
   Into     : CLI.Output;
   Changes  : CLI.Effects;
   Ports    : constant CLI.Port_List (1 .. 1) := (1 => UART1_Id);
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
   Gyro_Raw     : Adaflight.STM32.Gyro.Axis_Values;
   Acc_Raw      : Adaflight.STM32.Gyro.Axis_Values;
   Read_OK      : Boolean;
   Reads_From   : Unsigned_32 := 0;
   --  The divisor of the accelerometer counts in the raw readings reply, by
   --  the count for one g.
   Acc_Scale    : constant Float :=
     (if Adaflight.STM32.Gyro.Acc_One_G > 512 * 4 then 8.0
      elsif Adaflight.STM32.Gyro.Acc_One_G > 512 * 2 then 4.0
      elsif Adaflight.STM32.Gyro.Acc_One_G >= 512 then 2.0
      else 1.0);

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
                          Core_Clock_Hz => 168_000_000,
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
      Reads_From := Adaflight.STM32.Time.Millis + First_Read_Delay_Ms;
   end Start_Gyro;

   --  One gyro and accelerometer read into the raw readings reply, the
   --  gyro as counts and the accelerometer scaled, and the gyro's interrupt
   --  mode into the status report.
   procedure Read_Sensors is
   begin
      Adaflight.STM32.Gyro.Read (Gyro_Raw, Acc_Raw, Read_OK);
      if Read_OK then
         for I in Adaflight.MSP_Out.Axis loop
            Ctx.Out_Views.State.IMU.Gyro_Dps (I) := Gyro_Raw (I);
            Ctx.Out_Views.State.IMU.Acc (I) := Float (Acc_Raw (I)) / Acc_Scale;
         end loop;
      end if;
      Env.Gyros (0).Mode :=
        (case Adaflight.STM32.Gyro.Mode is
            when Adaflight.STM32.Gyro.Interrupt_Init => CLI.Interrupt_Init,
            when Adaflight.STM32.Gyro.Interrupt_DMA  => CLI.Interrupt_DMA,
            when Adaflight.STM32.Gyro.Interrupt      => CLI.Interrupt,
            when Adaflight.STM32.Gyro.No_Interrupt   => CLI.No_Interrupt);
   end Read_Sensors;

   --  The command line takes the port: an interactive session from the hash
   --  mark, a configurator session from the start of text.
   procedure Enter_Command_Line (Interactive : Boolean) is
   begin
      Env.Interactive := Interactive;
      Terminal.Enter (Session, Into, Interactive, Now_Ms);
   end Enter_Command_Line;

   --  One command frame through the processor, its reply framed and sent.
   procedure Answer is
   begin
      Env.Now_Us := Now_Ms * 1000;
      Env.Status.Uptime_Ms := Now_Ms;
      Adaflight.Stream_Buffers.Init (Stream, 0, Reply'Length);
      MSP.Process (Ctx, Config, Board, Links, Unsigned_16 (Port.Command_Id), Port.Data (0 .. Port.Data_Size - 1),
                   Ports, Reply, Stream, Result, Effects);
      Adaflight.MSP_Port.Encode (Port.Version, Port.Command_Id, Port.Flags, Result = MSP.Error,
                                 Reply (0 .. Stream.Next - 1), Frame, Frame_Length);
      Adaflight.STM32.USART.Put (Into.Target, Frame (0 .. Frame_Length - 1));
      if Effects.Reboot then
         Reset;
      end if;
   end Answer;

begin
   Adaflight.STM32.Time.Init;
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.Inverter_Pin_UART1.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.Inverter_Pin_UART1);
   Adaflight.STM32.GPIO.Set_Low (Adaflight.Board.Inverter_Pin_UART1);
   Adaflight.STM32.USART.Init (Adaflight.Board.UART1_TX_Pin, Adaflight.Board.UART1_RX_Pin, Baud);
   Adaflight.MSP_Port.Init (Port);
   Ctx.Out_Views.Common := Common_Snapshot;
   Ctx.Out_Views.Build := (others => True);
   Ctx.Out_Views.Serial_Ports (1) := (Port => UART1_Id, Available => True);
   Ctx.Out_Views.Serial_Count := 1;
   Start_Gyro;
   Next := Clock;
   Blink := Next;
   loop
      Now_Ms := Adaflight.STM32.Time.Millis;
      if Selection.Found and then Now_Ms >= Reads_From then
         Read_Sensors;
      end if;
      Adaflight.STM32.USART.Take (Input, Count);
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
            Env.Status.Arming_Disabled (Adaflight.Arming.CLI_Open) := Session.Arming_Held;
            Terminal.Process (Session, Into, Pending (0 .. Waiting - 1), Now_Ms, Config, Ports, Env, Board, Sched,
                              Changes);
            Waiting := 0;
            if Changes.Reboot then
               Reset;
            end if;
            Changes := (others => <>);
         end if;
      else
         loop
            Adaflight.MSP_Port.Process
              (Port, Pending (0 .. Waiting - 1), Consumed, Now_Ms,
               (Evaluate_Non_MSP => True, Peripheral => False,
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
      if Clock >= Blink then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Blink := Blink + Milliseconds (500);
      end if;
      Next := Next + Milliseconds (1);
      delay until Next;
   end loop;
end Adaflight_Stm32f4;
