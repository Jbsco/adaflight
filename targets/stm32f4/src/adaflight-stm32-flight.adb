with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Source_Info;
with Interfaces; use Interfaces;
with System;
with Adaflight.Acc_Inflight;
with Adaflight.Accelerometer;
with Adaflight.Arming;
with Adaflight.Attitude;
with Adaflight.Axes;
with Adaflight.Board;
with Adaflight.Bytes;
with Adaflight.Clock;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups;
with Adaflight.Config_Reset;
with Adaflight.Config_Runtime;
with Adaflight.Core_Loop;
with Adaflight.Gyro_Filters;
with Adaflight.Gyro_Selection;
with Adaflight.Mixer;
with Adaflight.Mixer_Init;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Control_In;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_Motor_In;
with Adaflight.MSP_Out;
with Adaflight.MSP_Port;
with Adaflight.MSP_Processor;
with Adaflight.PID_Config;
with Adaflight.Receiver;
with Adaflight.RPM_Filter;
with Adaflight.Scheduler;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.Console;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Gyro;
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

   --  The failure codes the LED flashes: a missing gyro, and a gyro whose
   --  initialization read failed.
   Failure_Missing_Acc      : constant := 1;
   Failure_Gyro_Init_Failed : constant := 6;

   --  The scheduler starts after the data ready interrupts of the gyro's
   --  start have passed the layer's detection count, the time the
   --  reference's longer startup gives them.
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
      Options : constant Adaflight.Task_Init.Options := (Accel => True, others => False);
      Inputs  : Adaflight.Task_Init.Inputs;
   begin
      Sched_Settings := Adaflight.Config_Runtime.Scheduler_Settings_Of
        (Config.Scheduler_Config, Cycles_Per_Us => Adaflight.STM32.Time.Cycles_Per_Us,
         Delay_Limit_Us => Delay_Limit_Us, Gyro_Period_Us => Sample_Us, Debug_Mode => Config.System_Config.Debug_Mode);
      Inputs.Serial_Update_Rate_Hz :=
        Adaflight.Task_Init.Rate_Hz (Natural'Max (1, Natural (Config.Serial_Config.Serial_Update_Rate_Hz)));
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

   --  The serial task: the bytes received go to the command line while its
   --  session is open, otherwise to the MSP port, which evaluates the other
   --  data while disarmed. The status reply reads the loop timing first.
   procedure MSP_Serial (Evaluate_Other_Data : Boolean) is
   begin
      Now_Ms := Adaflight.STM32.Time.Millis;
      Ctx.Out_Views.State.Status.PID_Delta_Us := Scheduler.Task_Delta_Time (Sched, Scheduler.PID);
      Ctx.Out_Views.State.Status.Load_Percent := Unsigned_16 (Sched.Average_Load_Percent);
      Env.Gyros (0).Mode := Gyro_Mode;
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
      Battery_Presence       => No_Step,
      Battery_States         => No_Step_At,
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

   --  The check function of a task with one: no receiver frames and no
   --  display yet, so none is signaled.
   function Check (Id : Scheduler.Task_Id) return Boolean is
      pragma Unreferenced (Id);
   begin
      return False;
   end Check;

   --  A task's body between the scheduler's execution prologue and
   --  epilogue, at the clock around its run.
   procedure Run_Body (Id : Scheduler.Task_Id) is
      Before : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Inputs : constant Tasks.Inputs := (CLI_Open => Session.Open, others => <>);
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

   procedure Init is
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
      Init_Loop_Units;
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
         if Scheduler.Failsafe_Due (Sched, Adaflight.STM32.Time.Millis) then
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
