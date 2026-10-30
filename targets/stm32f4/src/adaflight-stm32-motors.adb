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

   subtype Motor_Slot is Natural range 0 .. 7;
   type Frame_Buffer is array (0 .. Buffer_Size - 1) of Unsigned_32;
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
   end record;
   Outputs : array (Motor_Slot) of Output;

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
            Allocate (Dev.Io_Tags (Order), Adaflight.CLI_Resources.Motor, E, Index, Found, Ordinal => M + 1);
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
      Byte   : constant Natural := (if E.Channel mod 2 = 1 then 0 else 8);
      Mode   : Unsigned_32;
      Base   : constant Natural := 4 * (E.Channel - 1);
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
      Mode := (if E.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2);
      Mode := Mode and not Shift_Left (16#08#, Byte);
      Mode := (Mode and not Shift_Left (16#73#, Byte)) or Shift_Left (16#60#, Byte);
      if E.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
      Regs.CCER := Regs.CCER and not Shift_Left (16#F#, Base);
      if E.N then
         Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(2#0100#), Base) or (if Inverted then Shift_Left (Unsigned_32'(2#1000#), Base) else Unsigned_32'(0));
      else
         Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(2#0001#), Base) or (if Inverted then Shift_Left (Unsigned_32'(2#0010#), Base) else Unsigned_32'(0));
      end if;
      if Advanced (E.Timer) then
         Regs.CR2 := (Regs.CR2 and not Shift_Left (2#11#, 8 + 2 * (E.Channel - 1)))
           or (if E.N then Unsigned_32'(0) else Shift_Left (Unsigned_32'(1), 8 + 2 * (E.Channel - 1)));
      end if;
      declare
         CCR : Unsigned_32 with Volatile, Import, Address => System'To_Address (CCR_Value (E.Timer, E.Channel));
      begin
         CCR := 0;
      end;
      Mode := (if E.Channel <= 2 then Regs.CCMR1 else Regs.CCMR2) or Shift_Left (16#08#, Byte);
      if E.Channel <= 2 then
         Regs.CCMR1 := Mode;
      else
         Regs.CCMR2 := Mode;
      end if;
      Outputs (Slot) :=
        (Configured => True, Where => E.Where, Timer => E.Timer, Channel => E.Channel,
         Source => Shift_Left (1, 8 + E.Channel), Stream => S);
      Sources (E.Timer) := Sources (E.Timer) and not Outputs (Slot).Source;
      Stream.CR := Stream.CR and not EN;
      for Count in 1 .. 100_000 loop
         exit when (Stream.CR and EN) = 0;
      end loop;
      Enable_DMA (S);
      Stream.CR := 0;
      Stream.NDTR := 0;
      Stream.PAR := 0;
      Stream.M0AR := 0;
      Stream.M1AR := 0;
      Stream.FCR := 16#21#;
      Clear_Flags (S);
      Stream.CR := Shift_Left (Unsigned_32 (S.Channel), 25) or PL_High or MSIZE_32 or PSIZE_32 or MINC or DIR_M2P;
      Stream.FCR := DMDIS;
      Stream.PAR := CCR_Value (E.Timer, E.Channel);
      Stream.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Buffers (Slot)'Address));
      Regs.CR1 := Regs.CR1 or CEN;
      if New_Timer then
         Regs.CR1 := Regs.CR1 or ARPE;
         if Advanced (E.Timer) then
            Regs.BDTR := Regs.BDTR or MOE;
         end if;
         Regs.CR1 := Regs.CR1 or CEN;
      end if;
   end Configure;

   --  The bit clock of a DShot protocol number, zero for the others.
   function Protocol_Hz (Protocol : Unsigned_8) return Unsigned_32 is
     (case Protocol is
         when 5 => 3_000_000,
         when 6 => 6_000_000,
         when 7 => 12_000_000,
         when others => 0);

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural; Three_D : Boolean) is
      Hz    : constant Unsigned_32 := Protocol_Hz (C.Motor_Config.Dev.Motor_Protocol);
      Total : constant Natural := Natural'Min (Count, 8);
      Last  : Timer_Name := TIM1;
      Added : Boolean := False;
   begin
      Driven := 0;
      Kind := Adaflight.MSP_Motor_In.No_Device;
      Configured_Protocol := C.Motor_Config.Dev.Motor_Protocol;
      if Configured_Protocol in Adaflight.PWM_Output.Protocol then
         Init_Analog (C, Count, Three_D);
         return;
      end if;
      if Hz = 0 then
         return;
      end if;
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
            Allocate (Tag, Adaflight.CLI_Resources.Motor, E, Index, Found, Ordinal => M + 1);
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
     (Index < Driven and then Outputs (Index).Configured);

   function Stream_Of (Index : Natural) return Natural is
     (if Index < Driven and then Outputs (Index).Configured and then CCR_Of (Index) = 0
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
                               Request_Telemetry => Request, Inverted_Checksum => False);
   begin
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

   --  The timer driver captures no replies yet, so its frames stay plain
   --  DShot whatever the telemetry setting.
   function Telemetry_On return Boolean is (False);

   procedure Captures (C : out Adaflight.DShot.Captures; Stamp_Us : out Unsigned_32) is
   begin
      C := (others => <>);
      Stamp_Us := 0;
   end Captures;

   procedure Leave_Input (Processed : Natural; Done : Boolean) is null;

   --  Each timer used restarts with its period reloaded and asks for the
   --  transfers its motors armed.
   procedure Start_Transfers is
   begin
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
