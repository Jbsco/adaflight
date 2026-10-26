--  The STM32F4 image. Milestone 2: the command line on UART1 at 115200 baud
--  while the board's LED blinks at 1 Hz.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Source_Info;
with Interfaces; use Interfaces;
with System;
with Adaflight.Arming;
with Adaflight.Board;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.Config_Reset;
with Adaflight.MSP_Motor_In;
with Adaflight.Receiver;
with Adaflight.Scheduler;
with Adaflight.STM32.Console;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.USART;

procedure Adaflight_Stm32f4 is
   package CLI renames Adaflight.STM32.Console.CLI;
   package Terminal renames Adaflight.STM32.Console.Terminal;

   Baud       : constant := 115_200;
   Stack_Size : constant := 32_768;

   --  The device's unique identifier, the three words the status prints.
   UID : array (1 .. 3) of Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#1FFF_7A10#);

   --  The core's application interrupt and reset control register: the key
   --  in its high half with the system reset request.
   AIRCR : Unsigned_32
     with Import, Volatile, Address => System'To_Address (16#E000_ED0C#);
   System_Reset_Request : constant Unsigned_32 := 16#05FA_0004#;

   Epoch   : constant Time := Clock;
   Next    : Time := Epoch;
   Blink   : Time := Epoch;
   Board   : CLI.Board_State;
   Config  : Adaflight.Config_Groups.Configuration := Adaflight.Config_Reset.Reset (Board);
   Sched   : Adaflight.Scheduler.State;
   Session : Terminal.Session;
   Into    : CLI.Output;
   Changes : CLI.Effects;
   Ports   : constant CLI.Port_List (1 .. 0) := (others => 0);
   Input   : Adaflight.Bytes.Byte_Array (0 .. 63);
   Count   : Natural;
   Now_Ms  : Unsigned_32;

   Env : CLI.Environment :=
     (Navigation      => <>,
      Firmware        => CLI.To_Identity ("Adaflight"),
      Target          => CLI.To_Identity (Adaflight.Board.Board_Name),
      Version         => CLI.To_Identity ("0.1.0"),
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

   function Milliseconds_Since_Boot return Unsigned_32 is
     (Unsigned_32 ((Clock - Epoch) / Milliseconds (1)));

begin
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.LED0_Pin.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.LED0_Pin);
   Adaflight.STM32.GPIO.Enable_Port (Adaflight.Board.Inverter_Pin_UART1.Port);
   Adaflight.STM32.GPIO.Set_Output (Adaflight.Board.Inverter_Pin_UART1);
   Adaflight.STM32.GPIO.Set_Low (Adaflight.Board.Inverter_Pin_UART1);
   Adaflight.STM32.USART.Init (Adaflight.Board.UART1_TX_Pin, Adaflight.Board.UART1_RX_Pin, Baud);
   Terminal.Enter (Session, Into, Interactive => True, Now_Ms => 0);
   loop
      Adaflight.STM32.USART.Take (Input, Count);
      if Count > 0 then
         Now_Ms := Milliseconds_Since_Boot;
         Env.Now_Us := Now_Ms * 1000;
         Env.Status.Uptime_Ms := Now_Ms;
         Env.Status.Arming_Disabled (Adaflight.Arming.CLI_Open) := Session.Arming_Held;
         Terminal.Process (Session, Into, Input (0 .. Count - 1), Now_Ms, Config, Ports, Env, Board, Sched, Changes);
         if Changes.Reboot then
            AIRCR := System_Reset_Request;
            loop
               null;
            end loop;
         end if;
         if not Session.Open then
            Terminal.Enter (Session, Into, Interactive => True, Now_Ms => Now_Ms);
         end if;
         Changes := (others => <>);
      end if;
      if Clock >= Blink then
         Adaflight.STM32.GPIO.Toggle (Adaflight.Board.LED0_Pin);
         Blink := Blink + Milliseconds (500);
      end if;
      Next := Next + Milliseconds (1);
      delay until Next;
   end loop;
end Adaflight_Stm32f4;
