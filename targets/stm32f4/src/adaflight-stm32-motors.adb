with Ada.Interrupts.Names;
with Adaflight.CLI_Resources;
with Interfaces;
with System;
with System.Storage_Elements;
with Adaflight.Board;
with Adaflight.DShot;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.PWM_Output;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
with Adaflight.STM32.Platform;
package body Adaflight.STM32.Motors is
   use Interfaces;
   package GPIO renames Adaflight.STM32.GPIO;

   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);

   --  The DShot timings: the bit's twenty counts, and the counts a zero
   --  and a one stay high.
   Bit_Length : constant := 20;
   Bit_0      : constant := 7;
   Bit_1      : constant := 14;
   Buffer_Size : constant := 18;
   Input_Length : constant := Adaflight.DShot.Input_Length;

   --  A motor's buffer: a frame's slots, then with bidirectional DShot the
   --  edge times of the reply its channel captures.
   subtype Motor_Slot is Natural range 0 .. 7;
   type Frame_Buffer is array (0 .. Input_Length - 1) of Unsigned_32;
   pragma Volatile_Components (Frame_Buffer);
   Buffers : array (Motor_Slot) of aliased Frame_Buffer := (others => (others => 0))
     with Linker_Section => Adaflight.STM32.Platform.DMA_Section;

   type Output is record
      Configured : Boolean := False;
      Where      : Pin := (Port => Port_A, Number => 0);
      Timer      : Timer_Name := TIM1;
      Channel    : Channel_Number := 1;
      Source     : Unsigned_32 := 0;
      Stream     : DMA_Stream;
      N          : Boolean := False;
      Low        : Boolean := False;
   end record;
   Outputs : array (Motor_Slot) of Output;

   --  Bidirectional DShot: the frames' signal and checksum inverted, and each
   --  channel in input capture from the end of its frame until the read of
   --  its reply, which needs the deadtime from the first switch; the motor of
   --  each stream for its transfer complete interrupt.
   Bidir       : Boolean := False;
   Deadtime_Us : Integer_32 := 0;
   Stream_Slot : array (1 .. 2, 0 .. 7) of Integer range -1 .. 7 := (others => (others => -1));
   type Motor_Flags_Array is array (Motor_Slot) of Boolean;
   TCIE        : constant Unsigned_32 := 2 ** 4;
   DIR_Bits    : constant Unsigned_32 := 2#11# * 2 ** 6;

   --  A channel in input capture at both edges, its filter at two samples
   --  without a prescaler, the timer counting to its top.
   procedure Input_Capture (E : Output) is
      Regs : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      Byte : constant Natural := (if E.Channel mod 2 = 1 then 0 else 8);
      Base : constant Natural := 4 * (E.Channel - 1);
      Mode : Unsigned_32;
   begin
      Regs.CR1 := Regs.CR1 or ARPE;
      Regs.ARR := 16#FFFF_FFFF#;
      Regs.CCER := Regs.CCER and not Shift_Left (1, Base);
      Mode := (if E.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := (Mode and not Shift_Left (16#F3#, Byte)) or Shift_Left (16#21#, Byte);
      Mode := Mode and not Shift_Left (16#0C#, Byte);
      if E.Channel <= 2 then
         Regs.CCMR1 := Mode and 16#FFFF#;
      else
         Regs.CCMR2 := Mode and 16#FFFF#;
      end if;
      Regs.CCER := (Regs.CCER and not Shift_Left (2#1010#, Base)) or Shift_Left (2#1011#, Base);
   end Input_Capture;

   --  The bit-banged driver: on when the configuration chose it, its setup
   --  and status, and each running group's port, pacer timer with the
   --  channel's DMA request, stream, pins' mode bits and outputs, and the set
   --  or reset word that holds its pins at idle; the groups' frames, which
   --  their streams write into the ports, and the samples their streams take.
   package BB renames Adaflight.DShot_Bitbang;
   BB_On     : Boolean := False;
   BB_Status : BB.Status_Kind := BB.OK;
   BB_Setup  : BB.Setup;

   type Group_Hardware is record
      Running     : Boolean := False;
      Port        : Port_Name := Port_A;
      Timer       : Timer_Name := TIM8;
      Request     : Unsigned_32 := 0;
      Stream      : DMA_Stream;
      Mode_Mask   : Unsigned_32 := 0;
      Mode_Output : Unsigned_32 := 0;
      Idle        : Unsigned_32 := 0;
   end record;
   Groups : array (BB.Port_Index) of Group_Hardware;
   type Group_Flags is array (BB.Port_Index) of Boolean;

   BB_Frames : array (BB.Port_Index) of aliased BB.Port_Buffer := (others => (others => 0))
     with Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   type Sample_Buffer is array (0 .. Adaflight.DShot.Max_Samples - 1) of Unsigned_16 with Alignment => 4;
   pragma Volatile_Components (Sample_Buffer);
   BB_Samples : array (BB.Port_Index) of aliased Sample_Buffer := (others => (others => 0))
     with Linker_Section => Adaflight.STM32.Platform.DMA_Section;

   PSIZE_16     : constant Unsigned_32 := 2 ** 11;
   PL_Very_High : constant Unsigned_32 := 3 * 2 ** 16;

   function Address_Of (A : System.Address) return Unsigned_32 is
     (Unsigned_32 (System.Storage_Elements.To_Integer (A)));

   --  The transfer complete interrupt of each stream a motor can use: the
   --  stream and the timer's request stopped and the stream's flags cleared,
   --  then with bidirectional DShot the channel in input capture, the switch
   --  time kept when it is the first, and the stream from the compare
   --  register for the reply's edges. With the bit-banged driver the
   --  interrupt serves the group of the stream, and the switches of a
   --  group's direction run here.
   protected Capture with Interrupt_Priority => System.Interrupt_Priority'First is
      function Input (Slot : Motor_Slot) return Boolean;
      function Stamp return Unsigned_32;
      procedure Leave (Slot : Motor_Slot);
      procedure Clear_Stamp;
      --  Whether a group still samples its replies.
      function BB_Pending (G : BB.Port_Index) return Boolean;
      --  A group's stream from its frames into the port's set and reset
      --  register, the pins outputs at idle and the pacer at the output
      --  period; Done is False when the stream does not stop.
      procedure BB_To_Output (G : BB.Port_Index; Done : out Boolean);
      --  The update's transfers: each running group reloaded after a
      --  transfer error, back to output from input, and its stream on, then
      --  each pacer timer's requests on.
      procedure BB_Start;
   private
      procedure Complete (Controller : Positive; Stream : Natural);
      procedure BB_Complete (Controller : Positive; Stream : Natural);
      procedure BB_To_Input (G : BB.Port_Index);
      procedure DMA1_0 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream0_Interrupt;
      procedure DMA1_1 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream1_Interrupt;
      procedure DMA1_2 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream2_Interrupt;
      procedure DMA1_3 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream3_Interrupt;
      procedure DMA1_4 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream4_Interrupt;
      procedure DMA1_5 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream5_Interrupt;
      procedure DMA1_6 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream6_Interrupt;
      procedure DMA1_7 with Attach_Handler => Ada.Interrupts.Names.DMA1_Stream7_Interrupt;
      procedure DMA2_1 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream1_Interrupt;
      procedure DMA2_2 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream2_Interrupt;
      procedure DMA2_3 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream3_Interrupt;
      procedure DMA2_4 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream4_Interrupt;
      procedure DMA2_6 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream6_Interrupt;
      procedure DMA2_7 with Attach_Handler => Ada.Interrupts.Names.DMA2_Stream7_Interrupt;
      Inputs       : Motor_Flags_Array := (others => False);
      Switch_Stamp : Unsigned_32 := 0;
      BB_Waiting   : Group_Flags := (others => False);
      BB_Reload    : Group_Flags := (others => False);
      BB_Input     : Group_Flags := (others => False);
   end Capture;

   protected body Capture is
      function Input (Slot : Motor_Slot) return Boolean is (Inputs (Slot));
      function Stamp return Unsigned_32 is (Switch_Stamp);

      procedure Leave (Slot : Motor_Slot) is
      begin
         Inputs (Slot) := False;
      end Leave;

      procedure Clear_Stamp is
      begin
         Switch_Stamp := 0;
      end Clear_Stamp;

      function BB_Pending (G : BB.Port_Index) return Boolean is (BB_Waiting (G));

      procedure BB_To_Output (G : BB.Port_Index; Done : out Boolean) is
         H    : Group_Hardware renames Groups (G);
         S    : Stream_Registers with Import, Address => Stream_Address (H.Stream);
         Regs : Timer_Registers with Import, Address => Timer_Base (H.Timer);
         Port : GPIO.Port_Registers with Import, Address => GPIO.Port_Base (H.Port);
      begin
         S.CR := S.CR and not EN;
         Done := False;
         for Spin in 1 .. 100 loop
            if (S.CR and EN) = 0 then
               Done := True;
               exit;
            end if;
         end loop;
         if not Done then
            return;
         end if;
         Port.BSRR := H.Idle;
         Port.MODER := (Port.MODER and not H.Mode_Mask) or H.Mode_Output;
         S.CR := Shift_Left (Unsigned_32 (H.Stream.Channel), 25) or PL_High or MSIZE_32 or PSIZE_32 or MINC or DIR_M2P
           or TCIE;
         S.FCR := DMDIS;
         S.NDTR := BB.Buffer_Length;
         S.PAR := Address_Of (GPIO.Port_Base (H.Port)) + 16#18#;
         S.M0AR := Address_Of (BB_Frames (G)'Address);
         Regs.ARR := BB_Setup.Output_Period;
         BB_Input (G) := False;
      end BB_To_Output;

      --  A group's pins inputs and its stream from the port's input register
      --  into its samples, the pacer restarted at the input period.
      procedure BB_To_Input (G : BB.Port_Index) is
         H    : Group_Hardware renames Groups (G);
         S    : Stream_Registers with Import, Address => Stream_Address (H.Stream);
         Regs : Timer_Registers with Import, Address => Timer_Base (H.Timer);
         Port : GPIO.Port_Registers with Import, Address => GPIO.Port_Base (H.Port);
      begin
         Port.MODER := Port.MODER and not H.Mode_Mask;
         S.CR := Shift_Left (Unsigned_32 (H.Stream.Channel), 25) or PL_Very_High or MSIZE_32 or PSIZE_16 or MINC
           or TCIE;
         S.FCR := DMDIS;
         S.NDTR := Adaflight.DShot.Max_Samples;
         S.PAR := Address_Of (GPIO.Port_Base (H.Port)) + 16#10#;
         S.M0AR := Address_Of (BB_Samples (G)'Address);
         Regs.CNT := 0;
         Regs.ARR := BB_Setup.Input_Period;
         S.CR := S.CR or EN;
         BB_Input (G) := True;
      end BB_To_Input;

      --  A group's transfer done: its stream and request off and its flags
      --  cleared; a transfer error leaves the stream for the next update to
      --  reload. With bidirectional DShot an output's end turns the group to
      --  input with its request on, and an input's end ends the wait.
      procedure BB_Complete (Controller : Positive; Stream : Natural) is
         Shifts : constant array (0 .. 3) of Natural := (0, 6, 16, 22);
         Status : Unsigned_32 with Volatile, Import,
           Address => System'To_Address (DMA_Base (Controller) + (if Stream < 4 then 16#00# else 16#04#));
      begin
         for G in 0 .. BB_Setup.Used_Ports - 1 loop
            if Groups (G).Running and then Groups (G).Stream.Controller = Controller
              and then Groups (G).Stream.Stream = Stream
            then
               declare
                  H     : Group_Hardware renames Groups (G);
                  S     : Stream_Registers with Import, Address => Stream_Address (H.Stream);
                  Regs  : Timer_Registers with Import, Address => Timer_Base (H.Timer);
                  Error : Boolean;
               begin
                  S.CR := S.CR and not EN;
                  Regs.DIER := Regs.DIER and not H.Request;
                  Error := (Status and Shift_Left (2#1000#, Shifts (Stream mod 4))) /= 0;
                  Clear_Flags (H.Stream);
                  if Error then
                     BB_Reload (G) := True;
                  elsif Bidir then
                     if BB_Input (G) then
                        BB_Waiting (G) := False;
                        S.CR := S.CR and not EN;
                     else
                        BB_To_Input (G);
                        BB_Waiting (G) := True;
                        Regs.DIER := Regs.DIER or H.Request;
                     end if;
                  end if;
               end;
               return;
            end if;
         end loop;
      end BB_Complete;

      procedure BB_Start is
         Done : Boolean;
      begin
         for G in 0 .. BB_Setup.Used_Ports - 1 loop
            if Groups (G).Running then
               Done := True;
               if BB_Reload (G) then
                  BB_To_Output (G, Done);
                  if Done then
                     BB_Reload (G) := False;
                  end if;
               end if;
               if Done and then Bidir and then BB_Input (G) then
                  BB_To_Output (G, Done);
               end if;
               if Done then
                  declare
                     S : Stream_Registers with Import, Address => Stream_Address (Groups (G).Stream);
                  begin
                     S.CR := S.CR or EN;
                  end;
               end if;
            end if;
         end loop;
         for P in 0 .. BB_Setup.Used_Pacers - 1 loop
            declare
               Regs : Timer_Registers with Import,
                 Address => Timer_Base (if BB_Setup.Timers (P).Timer = 1 then TIM1 else TIM8);
            begin
               Regs.DIER := Regs.DIER or Unsigned_32 (BB_Setup.Timers (P).Requests);
            end;
         end loop;
      end BB_Start;

      procedure Complete (Controller : Positive; Stream : Natural) is
         Shifts : constant array (0 .. 3) of Natural := (0, 6, 16, 22);
         Status : Unsigned_32 with Volatile, Import,
           Address => System'To_Address (DMA_Base (Controller) + (if Stream < 4 then 16#00# else 16#04#));
         Slot   : constant Integer := Stream_Slot (Controller, Stream);
      begin
         if BB_On then
            BB_Complete (Controller, Stream);
            return;
         end if;
         if Slot < 0 or else (Status and Shift_Left (16#20#, Shifts (Stream mod 4))) = 0 then
            return;
         end if;
         declare
            O    : Output renames Outputs (Slot);
            Regs : Timer_Registers with Import, Address => Timer_Base (O.Timer);
            S    : Stream_Registers with Import, Address => Stream_Address (O.Stream);
         begin
            S.CR := S.CR and not EN;
            Regs.DIER := Regs.DIER and not O.Source;
            for Count in 1 .. 1_000 loop
               exit when (S.CR and EN) = 0;
            end loop;
            Clear_Flags (O.Stream);
            if Bidir then
               S.CR := S.CR and not (DIR_Bits or TCIE);
               Inputs (Slot) := True;
               if Switch_Stamp = 0 then
                  Switch_Stamp := Adaflight.STM32.Time.Micros;
               end if;
               Input_Capture (O);
               S.NDTR := Input_Length;
               S.CR := S.CR or EN;
               Regs.DIER := Regs.DIER or O.Source;
            end if;
         end;
      end Complete;

      procedure DMA1_0 is begin Complete (1, 0); end DMA1_0;
      procedure DMA1_1 is begin Complete (1, 1); end DMA1_1;
      procedure DMA1_2 is begin Complete (1, 2); end DMA1_2;
      procedure DMA1_3 is begin Complete (1, 3); end DMA1_3;
      procedure DMA1_4 is begin Complete (1, 4); end DMA1_4;
      procedure DMA1_5 is begin Complete (1, 5); end DMA1_5;
      procedure DMA1_6 is begin Complete (1, 6); end DMA1_6;
      procedure DMA1_7 is begin Complete (1, 7); end DMA1_7;
      procedure DMA2_1 is begin Complete (2, 1); end DMA2_1;
      procedure DMA2_2 is begin Complete (2, 2); end DMA2_2;
      procedure DMA2_3 is begin Complete (2, 3); end DMA2_3;
      procedure DMA2_4 is begin Complete (2, 4); end DMA2_4;
      procedure DMA2_6 is begin Complete (2, 6); end DMA2_6;
      procedure DMA2_7 is begin Complete (2, 7); end DMA2_7;
   end Capture;

   Used    : array (Timer_Name) of Boolean := (others => False);
   Sources : array (Timer_Name) of Unsigned_32 := (others => 0);
   Driven  : Natural range 0 .. 8 := 0;
   Is_On   : Boolean := False;
   Kind    : Adaflight.MSP_Motor_In.Device_Kind := Adaflight.MSP_Motor_In.No_Device;

   --  The analog protocols' outputs: the configured protocol, whether the
   --  outputs update without forced overflows, each motor's timing and
   --  compare register, and whether it forces its timer's overflow.
   Configured_Protocol : Unsigned_8 := 0;
   Continuous          : Boolean := True;
   Timings             : array (Motor_Slot) of Adaflight.PWM_Output.Motor_Timing;
   CCR_Of              : array (Motor_Slot) of Unsigned_32 := (others => 0);
   Forced              : array (Motor_Slot) of Boolean := (others => False);

   --  The analog protocols' outputs as the reference sets them up: each motor
   --  of the mix in output order on the channel its pin holds, the pin on the
   --  timer's alternate function, the timer and channel at the protocol's
   --  timing with the idle pulse and the configured inversion, and the first
   --  motor of each timer forcing its overflow; a motor without a channel
   --  leaves no motor driven.
   procedure Init_Analog (C : Adaflight.Config_Groups.Configuration; Count : Natural; Three_D : Boolean) is
      Dev  : Adaflight.Config_Groups.Motor_Dev_Config_Record renames C.Motor_Config.Dev;
      Idle : constant Unsigned_16 := (if Three_D then C.Flight3_D_Config.Neutral3d else C.Motor_Config.Mincommand);
   begin
      for M in 0 .. Natural'Min (Count, 8) - 1 loop
         declare
            Order : constant Natural := Natural (Dev.Motor_Output_Reordering (M)) mod 8;
            E     : Timer_Entry;
            Index : Natural;
            Found : Boolean;
         begin
            Allocate (Dev.Io_Tags (Order), Adaflight.CLI_Resources.Motor, E, Index, Found, Ordinal => Order + 1);
            if not Found then
               Driven := 0;
               Outputs := (others => (others => <>));
               CCR_Of := (others => 0);
               return;
            end if;
            GPIO.Enable_Port (E.Where.Port);
            GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.No_Pull, Rate => GPIO.Low);
            Timings (M) := Adaflight.PWM_Output.Motor_Timing_Of
              (Dev.Motor_Protocol, Dev.Motor_Pwm_Rate, Dev.Use_Continuous_Update /= 0, Timer_Clock_Hz (E.Timer), Idle);
            Continuous := Timings (M).Continuous;
            Configure_PWM (E, Timings (M).Hz, Adaflight.PWM_Output.Period_Of (Timings (M)), Timings (M).Idle,
                           Inverted => Dev.Motor_Inversion /= 0);
            CCR_Of (M) := CCR_Value (E.Timer, E.Channel);
            Forced (M) := (for all K in 0 .. M - 1 => Outputs (K).Timer /= E.Timer);
            Outputs (M) := (Configured => True, Where => E.Where, Timer => E.Timer, Channel => E.Channel, others => <>);
            Driven := M + 1;
         end;
      end loop;
      Kind := (if Driven > 0 then Adaflight.MSP_Motor_In.PWM else Adaflight.MSP_Motor_In.No_Device);
   end Init_Analog;

   --  Each analog output's compare register cleared, which stops its pulses.
   procedure Clear_Pulses is
   begin
      for M in 0 .. Driven - 1 loop
         if CCR_Of (M) /= 0 then
            declare
               CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Of (M));
            begin
               CCR := 0;
            end;
         end if;
      end loop;
   end Clear_Pulses;

   --  A channel in PWM mode 1 at zero with its output on, low when the
   --  output is inverted, its preload off during the setup and on after.
   procedure Output_Compare (O : Output) is
      Regs : Timer_Registers with Import, Address => Timer_Base (O.Timer);
      Byte : constant Natural := (if O.Channel mod 2 = 1 then 0 else 8);
      Base : constant Natural := 4 * (O.Channel - 1);
      Mode : Unsigned_32;
   begin
      Mode := (if O.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := Mode and not Shift_Left (16#08#, Byte);
      Mode := (Mode and not Shift_Left (16#73#, Byte)) or Shift_Left (16#60#, Byte);
      if O.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
      Regs.CCER := Regs.CCER and not Shift_Left (16#F#, Base);
      if O.N then
         Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(2#0100#), Base)
           or (if O.Low then Shift_Left (Unsigned_32'(2#1000#), Base) else Unsigned_32'(0));
      else
         Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(2#0001#), Base)
           or (if O.Low then Shift_Left (Unsigned_32'(2#0010#), Base) else Unsigned_32'(0));
      end if;
      if Advanced (O.Timer) then
         Regs.CR2 := (Regs.CR2 and not Shift_Left (2#11#, 8 + 2 * (O.Channel - 1)))
           or (if O.N then Unsigned_32'(0) else Shift_Left (Unsigned_32'(1), 8 + 2 * (O.Channel - 1)));
      end if;
      declare
         CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (O.Timer, O.Channel));
      begin
         CCR := 0;
      end;
      Mode := (if O.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2) or Shift_Left (16#08#, Byte);
      if O.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
   end Output_Compare;

   --  A motor's stream reset, then from its buffer to its channel's compare
   --  register, with its transfer complete interrupt for bidirectional DShot.
   procedure Stream_Output (Slot : Motor_Slot) is
      O      : Output renames Outputs (Slot);
      Stream : Stream_Registers with Import, Address => Stream_Address (O.Stream);
   begin
      Stream.CR := Stream.CR and not EN;
      for Count in 1 .. 1_000 loop
         exit when (Stream.CR and EN) = 0;
      end loop;
      Stream.CR := 0;
      Stream.NDTR := 0;
      Stream.PAR := 0;
      Stream.M0AR := 0;
      Stream.M1AR := 0;
      Stream.FCR := 16#21#;
      Clear_Flags (O.Stream);
      Stream.CR := Shift_Left (Unsigned_32 (O.Stream.Channel), 25) or PL_High or MSIZE_32 or PSIZE_32 or MINC
        or DIR_M2P or (if Bidir then TCIE else 0);
      Stream.FCR := DMDIS;
      Stream.PAR := CCR_Value (O.Timer, O.Channel);
      Stream.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Buffers (Slot)'Address));
   end Stream_Output;

   --  One motor's output as the reference configures it: the pin on the
   --  timer's alternate function, the timer at the protocol's bit clock when
   --  it is the timer just added, the channel in PWM mode 1 with its
   --  preload, the stream from memory to the compare register, and the
   --  outputs on.
   procedure Configure
     (Slot : Motor_Slot; E : Timer_Entry; S : DMA_Stream; Hz : Unsigned_32; Inverted : Boolean;
      New_Timer : Boolean)
   is
      Regs   : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      Stream : Stream_Registers with Import, Address => Stream_Address (S);
   begin
      GPIO.Enable_Port (E.Where.Port);
      GPIO.Set_Alternate (E.Where, Alternate (E.Timer), (if Inverted then GPIO.Down else GPIO.Up), Rate => GPIO.High);
      if New_Timer then
         if On_APB2 (E.Timer) then
            RCC_APB2ENR := RCC_APB2ENR or Shift_Left (1, Enable_Bit (E.Timer));
         else
            RCC_APB1ENR := RCC_APB1ENR or Shift_Left (1, Enable_Bit (E.Timer));
         end if;
         Regs.CR1 := Regs.CR1 and not CEN;
         Regs.CR1 := Regs.CR1 and not (2#111_0000# or 2 ** 8 or 2 ** 9);
         Regs.ARR := Bit_Length - 1;
         Regs.PSC := Unsigned_32 (Float'Unbiased_Rounding (Float (Timer_Clock_Hz (E.Timer)) / Float (Hz) + 0.01)) - 1;
         if Advanced (E.Timer) then
            Regs.RCR := 0;
         end if;
         Regs.EGR := UG;
      end if;
      Outputs (Slot) :=
        (Configured => True, Where => E.Where, Timer => E.Timer, Channel => E.Channel,
         Source => Shift_Left (1, 8 + E.Channel), Stream => S, N => E.N, Low => Inverted /= Bidir);
      Output_Compare (Outputs (Slot));
      Sources (E.Timer) := Sources (E.Timer) and not Outputs (Slot).Source;
      Stream.CR := Stream.CR and not EN;
      for Count in 1 .. 100_000 loop
         exit when (Stream.CR and EN) = 0;
      end loop;
      Enable_DMA (S);
      Stream_Output (Slot);
      Stream_Slot (S.Controller, S.Stream) := Slot;
      Regs.CR1 := Regs.CR1 or CEN;
      if New_Timer then
         Regs.CR1 := Regs.CR1 or ARPE;
         if Advanced (E.Timer) then
            Regs.BDTR := Regs.BDTR or MOE;
         end if;
         Regs.CR1 := Regs.CR1 or CEN;
      end if;
      if Bidir then
         declare
            CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
         begin
            CCR := 16#FFFF#;
         end;
      end if;
   end Configure;

   --  The bit clock of a DShot protocol number, zero for the others.
   function Protocol_Hz (Protocol : Unsigned_8) return Unsigned_32 is
     (case Protocol is
         when 5 => 3_000_000,
         when 6 => 6_000_000,
         when 7 => 12_000_000,
         when others => 0);

   function Bitbang_Active (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (BB.Active (C.Motor_Config.Dev.Use_Dshot_Bitbang, C.Motor_Config.Dev.Use_Dshot_Telemetry /= 0,
                 C.Motor_Config.Dev.Motor_Protocol, Adaflight.STM32.Platform.F4));

   function Bitbang_On return Boolean is (BB_On);

   function Bitbang_Setup return BB.Setup is (BB_Setup);

   function Bitbang_OK return Boolean is (BB."=" (BB_Status, BB.OK));

   --  The setup over the configuration's pins and settings, the timer map's
   --  owners and the strip's and the ADC's streams, with no pin held before
   --  the motors.
   procedure Configure_Bitbang
     (C : Adaflight.Config_Groups.Configuration; Total : Natural; Strip_Stream : Natural; ADC_Stream : Natural;
      S : out BB.Setup)
   is
      Busy  : BB.Stream_Flags := (others => False);
      Tags  : BB.Tag_List;
      Order : BB.Order_List;
   begin
      for M in Tags'Range loop
         Tags (M) := C.Motor_Config.Dev.Io_Tags (M);
         Order (M) := Natural (C.Motor_Config.Dev.Motor_Output_Reordering (M)) mod 8;
      end loop;
      if Strip_Stream in Busy'Range then
         Busy (Strip_Stream) := True;
      end if;
      if ADC_Stream in Busy'Range then
         Busy (ADC_Stream) := True;
      end if;
      BB.Configure
        (S, Adaflight.STM32.Timers.Allocation, Busy, (others => False), Total, Tags, Order,
         C.Motor_Config.Dev.Use_Dshot_Bitbanged_Timer, Bidir, C.Motor_Config.Dev.Motor_Inversion /= 0,
         C.Motor_Config.Dev.Motor_Protocol, Adaflight.STM32.Platform.APB2_Timer_Hz);
   end Configure_Bitbang;

   --  The bit-banged start: the motors' pins through the output order as
   --  the setup checks them; a pin conflict leaves no motor driven, else
   --  each pin is a push-pull output pulled toward its idle level and set
   --  to its output's idle level.
   procedure Init_Bitbang (C : Adaflight.Config_Groups.Configuration; Total : Natural) is
      S        : BB.Setup;
      Inverted : constant Boolean := C.Motor_Config.Dev.Motor_Inversion /= 0;
      Speed    : constant Unsigned_32 := (if Adaflight.STM32.Platform.F4 then 2 else 0);
   begin
      BB_On := True;
      Configure_Bitbang (C, Total, 0, 0, S);
      BB_Status := S.Status;
      if not S.Init_OK then
         return;
      end if;
      for M in 0 .. Total - 1 loop
         declare
            Tag   : constant Unsigned_8 := S.Motors (M).Tag;
            P     : constant Pin := (Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16));
            Port  : GPIO.Port_Registers with Import, Address => GPIO.Port_Base (P.Port);
            Shift : constant Natural := 2 * Natural (P.Number);
         begin
            Outputs (M).Configured := True;
            Outputs (M).Where := P;
            GPIO.Enable_Port (P.Port);
            GPIO.Set_Output (P);
            Port.OSPEEDR := (Port.OSPEEDR and not Shift_Left (3, Shift)) or Shift_Left (Speed, Shift);
            Port.PUPDR := (Port.PUPDR and not Shift_Left (3, Shift)) or Shift_Left ((if Inverted then 2 else 1), Shift);
            if (S.Motors (M).Output and 1) /= 0 then
               GPIO.Set_Low (P);
            else
               GPIO.Set_High (P);
            end if;
         end;
      end loop;
      Driven := Total;
      Kind := Adaflight.MSP_Motor_In.DShot;
   end Init_Bitbang;

   --  A group's pacer and stream as the reference starts them: the timer
   --  counting up at the timer clock over the output period with its period
   --  preloaded, the channel in PWM mode 1 at ten counts with a low polarity
   --  and its output idling set, the timer on, and the stream's controller on.
   procedure Start_Group (G : BB.Port_Index; Row : BB.Pacer_Row) is
      P     : constant BB.Pacer := BB.Pacers (Row);
      Timer : constant Timer_Name := (if P.Timer = 1 then TIM1 else TIM8);
      Regs  : Timer_Registers with Import, Address => Timer_Base (Timer);
      Byte  : constant Natural := (if P.Channel mod 2 = 1 then 0 else 8);
      Base  : constant Natural := 4 * (P.Channel - 1);
      Idle  : constant Natural := 8 + 2 * (P.Channel - 1);
      Mode  : Unsigned_32;
   begin
      Groups (G) := (Running => True, Port => Port_Name'Val (Natural (BB_Setup.Ports (G).Port) - 1), Timer => Timer,
                     Request => Shift_Left (16#0200#, P.Channel - 1),
                     Stream  => (Controller => 2, Stream => P.Stream - 9, Channel => P.Request), others => <>);
      Enable_Clock (Timer);
      Set_Time_Base (Timer, Reload => BB_Setup.Output_Period, Prescale => 0);
      Regs.CR1 := Regs.CR1 or ARPE;
      Regs.CR1 := Regs.CR1 and not CEN;
      Regs.CCER := Regs.CCER and not Shift_Left (1, Base);
      Mode := (if P.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := (Mode and not Shift_Left (16#73#, Byte)) or Shift_Left (16#60#, Byte);
      Regs.CR2 := (Regs.CR2 and not Shift_Left (2#11#, Idle)) or Shift_Left (1, Idle);
      if P.Channel <= 2 then
         Regs.CCMR1 := Mode and 16#FFFF#;
      else
         Regs.CCMR2 := Mode and 16#FFFF#;
      end if;
      declare
         CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (Timer, P.Channel));
      begin
         CCR := 10;
      end;
      Regs.CCER := (Regs.CCER and not Shift_Left (2#1111#, Base)) or Shift_Left (2#0011#, Base);
      Regs.CR1 := Regs.CR1 or CEN;
      Enable_DMA (Groups (G).Stream);
   end Start_Group;

   procedure Post_Init (C : Adaflight.Config_Groups.Configuration; Strip_Stream : Natural; ADC_Stream : Natural) is
      Done : Boolean;
   begin
      if not BB_On or else Driven = 0 then
         return;
      end if;
      Configure_Bitbang (C, Driven, Strip_Stream, ADC_Stream, BB_Setup);
      BB_Status := BB_Setup.Status;
      for G in 0 .. BB_Setup.Used_Ports - 1 loop
         declare
            Row : constant BB.Pacer_Row := BB_Setup.Ports (G).Pacer;
         begin
            if BB_Setup.Ports (G).Allocated and then Row > 0
              and then BB_Setup.Streams (BB.Pacers (Row).Stream) = BB_Setup.Ports (G).Port
            then
               Start_Group (G, Row);
            end if;
         end;
      end loop;
      for M in 0 .. Driven - 1 loop
         if BB_Setup.Motors (M).Configured then
            declare
               G   : constant BB.Port_Index := BB_Setup.Motors (M).Group;
               Bit : constant Natural := BB_Setup.Motors (M).Pin;
            begin
               Groups (G).Mode_Mask := Groups (G).Mode_Mask or Shift_Left (3, 2 * Bit);
               Groups (G).Mode_Output := Groups (G).Mode_Output or Shift_Left (1, 2 * Bit);
               Groups (G).Idle := Groups (G).Idle or (if Bidir then Shift_Left (1, Bit) else Shift_Left (1, Bit + 16));
               if Bidir then
                  GPIO.Set_High (Outputs (M).Where);
               else
                  GPIO.Set_Low (Outputs (M).Where);
               end if;
               BB.Init (BB_Frames (G), Shift_Left (1, Bit), Inverted => Bidir);
               Capture.BB_To_Output (G, Done);
            end;
         end if;
      end loop;
   end Post_Init;

   procedure Update_Init is
   begin
      if BB_On then
         for G in 0 .. BB_Setup.Used_Ports - 1 loop
            BB.Clear (BB_Frames (G));
         end loop;
      end if;
   end Update_Init;

   procedure Telemetry_Wait (Ports : in out BB.Port_Inputs) is
      Start   : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Pending : Boolean;
      Elapsed : Unsigned_32;
   begin
      if not BB_On then
         return;
      end if;
      loop
         Pending := False;
         for G in 0 .. BB_Setup.Used_Ports - 1 loop
            Pending := Pending or else Capture.BB_Pending (G);
         end loop;
         Elapsed := Adaflight.STM32.Time.Micros - Start;
         if Elapsed < 2 ** 31 and then Integer_32 (Elapsed) > BB_Setup.Timeout_Us then
            for G in 0 .. BB_Setup.Used_Ports - 1 loop
               if Capture.BB_Pending (G) then
                  Ports (G).Aborted := True;
               end if;
            end loop;
            exit;
         end if;
         exit when not Pending;
      end loop;
   end Telemetry_Wait;

   procedure Port_Samples
     (Ports : in out BB.Port_Inputs; Used : out BB.Port_Total; Pins : out BB.Motor_Pins;
      Configured : out Adaflight.DShot.Motor_Total)
   is
   begin
      Used := (if BB_On then BB_Setup.Used_Ports else 0);
      Pins := (others => <>);
      Configured := 0;
      for G in 0 .. Used - 1 loop
         for K in Sample_Buffer'Range loop
            Ports (G).Buffer (K) := BB_Samples (G) (K);
         end loop;
         Ports (G).Count := Adaflight.DShot.Max_Samples;
      end loop;
      if BB_On then
         for M in 0 .. Driven - 1 loop
            exit when not BB_Setup.Motors (M).Configured;
            Pins (M) := (Port => BB_Setup.Motors (M).Group, Pin => BB_Setup.Motors (M).Pin);
            Configured := M + 1;
         end loop;
      end if;
   end Port_Samples;

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural; Three_D : Boolean) is
      Hz    : constant Unsigned_32 := Protocol_Hz (C.Motor_Config.Dev.Motor_Protocol);
      Total : constant Natural := Natural'Min (Count, 8);
      Last  : Timer_Name := TIM1;
      Added : Boolean := False;
   begin
      Driven := 0;
      Kind := Adaflight.MSP_Motor_In.No_Device;
      Configured_Protocol := C.Motor_Config.Dev.Motor_Protocol;
      Bidir := Telemetry_Configured (C);
      Stream_Slot := (others => (others => -1));
      BB_On := False;
      BB_Status := BB.OK;
      if Configured_Protocol in Adaflight.PWM_Output.Protocol then
         Init_Analog (C, Count, Three_D);
         return;
      end if;
      if Hz = 0 then
         return;
      end if;
      if Bitbang_Active (C) then
         Init_Bitbang (C, Total);
         return;
      end if;
      Deadtime_Us := 35 + Integer_32 (320_000_000 / Hz);
      for M in 0 .. Total - 1 loop
         declare
            Order    : constant Natural := Natural (C.Motor_Config.Dev.Motor_Output_Reordering (M)) mod 8;
            Tag      : constant Unsigned_8 := C.Motor_Config.Dev.Io_Tags (Order);
            Found    : Boolean;
            E        : Timer_Entry;
            Index    : Natural;
            S        : DMA_Stream;
            Inverted : constant Boolean := C.Motor_Config.Dev.Motor_Inversion /= 0;
         begin
            Allocate (Tag, Adaflight.CLI_Resources.Motor, E, Index, Found, Ordinal => Order + 1);
            if Found then
               declare
                  O      : constant DMA_Options := Options_Of (E.Timer, E.Channel);
                  Option : constant Integer := Option_Of (Index);
               begin
                  Found := Option in 0 .. O'Length - 1;
                  if Found then
                     S := O (O'First + Option);
                  end if;
               end;
            end if;
            if not Found then
               Driven := 0;
               Outputs := (others => (others => <>));
               return;
            end if;
            Added := not Used (E.Timer);
            if Added then
               Used (E.Timer) := True;
               Last := E.Timer;
            end if;
            Configure (M, E, S, Hz, Inverted, New_Timer => E.Timer = Last);
            Driven := M + 1;
         end;
      end loop;
      Kind := (if Driven > 0 then Adaflight.MSP_Motor_In.DShot else Adaflight.MSP_Motor_In.No_Device);
   end Init;

   procedure Enable is
   begin
      Is_On := Driven > 0;
   end Enable;

   procedure Disable is
   begin
      Clear_Pulses;
      Is_On := False;
   end Disable;

   procedure Shutdown is
   begin
      Clear_Pulses;
      Is_On := False;
      Adaflight.STM32.Time.Delay_Us
        (1_500 + (if Configured_Protocol in Adaflight.PWM_Output.Protocol_PWM .. Adaflight.PWM_Output.Protocol_MultiShot
                  then 500_000 else 0));
   end Shutdown;

   procedure Write_Pulse (Index : Natural; Value : Float) is
   begin
      if Index < Driven and then CCR_Of (Index) /= 0 then
         declare
            CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Of (Index));
         begin
            CCR := Adaflight.PWM_Output.Motor_Pulse
              (Timings (Index), Float'Max (Adaflight.PWM_Output.Write_Value'First,
                                           Float'Min (Adaflight.PWM_Output.Write_Value'Last, Value)));
         end;
      end if;
   end Write_Pulse;

   procedure Complete_Pulses is
   begin
      if Continuous or else Adaflight.MSP_Motor_In."/=" (Kind, Adaflight.MSP_Motor_In.PWM) then
         return;
      end if;
      for M in 0 .. Driven - 1 loop
         declare
            Regs : Timer_Registers with Import, Address => Timer_Base (Outputs (M).Timer);
            CCR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Of (M));
         begin
            if Forced (M) then
               Regs.EGR := Regs.EGR or UG;
            end if;
            CCR := 0;
         end;
      end loop;
   end Complete_Pulses;

   function Enabled return Boolean is (Is_On);

   procedure Hold_Idle is
   begin
      for Index in 0 .. Driven - 1 loop
         if Outputs (Index).Configured then
            GPIO.Set_Output (Outputs (Index).Where);
            GPIO.Set_High (Outputs (Index).Where);
         end if;
      end loop;
   end Hold_Idle;

   function Motor_Enabled (Index : Natural) return Boolean is
     (Index < Driven and then Outputs (Index).Configured and then (not BB_On or else BB_Setup.Motors (Index).Enabled));

   function Stream_Of (Index : Natural) return Natural is
     (if Index < Driven and then Outputs (Index).Configured and then CCR_Of (Index) = 0 and then not BB_On
      then (Outputs (Index).Stream.Controller - 1) * 8 + Outputs (Index).Stream.Stream + 1
      else 0);

   function Count return Natural is (Driven);

   function Device return Adaflight.MSP_Motor_In.Device_Kind is (Kind);

   --  A motor's frame into its buffer, most significant bit first, then two
   --  zero slots, and its stream armed; the stream and the request the
   --  previous frame left on end first, as the reference's transfer complete
   --  interrupt ends them.
   procedure Send_Frame (Index : Natural; Value : Unsigned_16; Request : Boolean) is
      Slot   : constant Motor_Slot := Index;
      O      : Output renames Outputs (Slot);
      Regs   : Timer_Registers with Import, Address => Timer_Base (O.Timer);
      Stream : Stream_Registers with Import, Address => Stream_Address (O.Stream);
      Packet : Unsigned_16 :=
        Adaflight.DShot.Frame (Adaflight.DShot.Frame_Value (Unsigned_16'Min (Value, 2_047)),
                               Request_Telemetry => Request, Inverted_Checksum => Bidir);
   begin
      if BB_On then
         if Index < Driven and then BB_Setup.Motors (Index).Configured then
            BB.Set (BB_Frames (BB_Setup.Motors (Index).Group), BB_Setup.Motors (Index).Pin, Packet, Inverted => Bidir);
         end if;
         return;
      end if;
      if not O.Configured then
         return;
      end if;
      for I in 0 .. 15 loop
         Buffers (Slot) (I) := (if (Packet and 16#8000#) /= 0 then Bit_1 else Bit_0);
         Packet := Shift_Left (Packet, 1);
      end loop;
      Buffers (Slot) (16) := 0;
      Buffers (Slot) (17) := 0;
      Regs.DIER := Regs.DIER and not O.Source;
      Stream.CR := Stream.CR and not EN;
      for Count in 1 .. 1_000 loop
         exit when (Stream.CR and EN) = 0;
      end loop;
      Clear_Flags (O.Stream);
      Stream.NDTR := Buffer_Size;
      Stream.CR := Stream.CR or EN;
      Sources (O.Timer) := Sources (O.Timer) or O.Source;
   end Send_Frame;

   function Telemetry_Configured (C : Adaflight.Config_Groups.Configuration) return Boolean is
     (C.Motor_Config.Dev.Use_Dshot_Telemetry /= 0 and then C.Motor_Config.Dev.Motor_Protocol in 5 .. 7);

   function Telemetry_On return Boolean is (Bidir);

   --  Each motor's capture: whether its channel is in input, the deadtime,
   --  the edges its stream took from the count left, and their times.
   procedure Captures (C : out Adaflight.DShot.Captures; Stamp_Us : out Unsigned_32) is
   begin
      C := (others => <>);
      for M in 0 .. Driven - 1 loop
         declare
            S    : Stream_Registers with Import, Address => Stream_Address (Outputs (M).Stream);
            Left : constant Unsigned_32 := S.NDTR and 16#FFFF#;
         begin
            C (M).Input := Capture.Input (M);
            C (M).Deadtime := Deadtime_Us;
            C (M).Edges := (if Left >= Input_Length then 0 else Input_Length - Natural (Left));
            for K in C (M).Buffer'Range loop
               C (M).Buffer (K) := Buffers (M) (K);
            end loop;
         end;
      end loop;
      Stamp_Us := Capture.Stamp;
   end Captures;

   --  The motors read leave input: a motor in input stops its timer's
   --  request, then each takes its output compare and its stream from the
   --  buffer back; once every motor is read the switch time clears and the
   --  channels' outputs go on.
   procedure Leave_Input (Processed : Natural; Done : Boolean) is
   begin
      for M in 0 .. Natural'Min (Processed, Driven) - 1 loop
         declare
            O    : Output renames Outputs (M);
            Regs : Timer_Registers with Import, Address => Timer_Base (O.Timer);
         begin
            if Capture.Input (M) then
               Regs.DIER := Regs.DIER and not O.Source;
            end if;
            Stream_Output (M);
            Capture.Leave (M);
            Output_Compare (O);
         end;
      end loop;
      if Done and then Bidir then
         Capture.Clear_Stamp;
         for M in 0 .. Driven - 1 loop
            declare
               O    : Output renames Outputs (M);
               Regs : Timer_Registers with Import, Address => Timer_Base (O.Timer);
            begin
               Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(if O.N then 2#0100# else 2#0001#), 4 * (O.Channel - 1));
            end;
         end loop;
      end if;
   end Leave_Input;

   --  Each timer used restarts with its period reloaded and asks for the
   --  transfers its motors armed.
   procedure Start_Transfers is
   begin
      if BB_On then
         Capture.BB_Start;
         return;
      end if;
      for T in Timer_Name loop
         if Used (T) then
            declare
               Regs : Timer_Registers with Import, Address => Timer_Base (T);
            begin
               Regs.CR1 := Regs.CR1 and not ARPE;
               Regs.ARR := Bit_Length - 1;
               Regs.CR1 := Regs.CR1 or ARPE;
               Regs.CNT := 0;
               Regs.DIER := Regs.DIER or Sources (T);
               Sources (T) := 0;
            end;
         end if;
      end loop;
   end Start_Transfers;
end Adaflight.STM32.Motors;
