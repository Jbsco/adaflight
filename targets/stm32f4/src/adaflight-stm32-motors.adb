with Interfaces;
with System;
with System.Storage_Elements;
with Adaflight.Board;
with Adaflight.DShot;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Motors is
   use Interfaces;
   package GPIO renames Adaflight.STM32.GPIO;

   RCC_AHB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3830#);
   RCC_APB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3844#);

   --  A DMA stream: its controller, its number and its channel.
   type DMA_Stream is record
      Controller : Positive range 1 .. 2 := 1;
      Stream     : Natural range 0 .. 7 := 0;
      Channel    : Natural range 0 .. 7 := 0;
   end record;
   type DMA_Options is array (Natural range <>) of DMA_Stream;

   --  The streams a timer channel's request reaches, by option.
   function Options_Of (T : Timer_Name; C : Channel_Number) return DMA_Options is
     (case T is
         when TIM1 =>
           (case C is
               when 1 => ((2, 6, 0), (2, 1, 6), (2, 3, 6)),
               when 2 => ((2, 6, 0), (2, 2, 6)),
               when 3 => ((2, 6, 0), (2, 6, 6)),
               when 4 => (0 => (2, 4, 6))),
         when TIM2 =>
           (case C is
               when 1 => (0 => (1, 5, 3)),
               when 2 => (0 => (1, 6, 3)),
               when 3 => (0 => (1, 1, 3)),
               when 4 => ((1, 7, 3), (1, 6, 3))),
         when TIM3 =>
           (case C is
               when 1 => (0 => (1, 4, 5)),
               when 2 => (0 => (1, 5, 5)),
               when 3 => (0 => (1, 7, 5)),
               when 4 => (0 => (1, 2, 5))),
         when TIM4 =>
           (case C is
               when 1 => (0 => (1, 0, 2)),
               when 2 => (0 => (1, 3, 2)),
               when 3 => (0 => (1, 7, 2)),
               when 4 => (1 .. 0 => (1, 0, 0))),
         when TIM5 =>
           (case C is
               when 1 => (0 => (1, 2, 6)),
               when 2 => (0 => (1, 4, 6)),
               when 3 => (0 => (1, 0, 6)),
               when 4 => ((1, 1, 6), (1, 3, 6))),
         when TIM8 =>
           (case C is
               when 1 => ((2, 2, 0), (2, 2, 7)),
               when 2 => ((2, 2, 0), (2, 3, 7)),
               when 3 => ((2, 2, 0), (2, 4, 7)),
               when 4 => (0 => (2, 7, 7))),
         when others => (1 .. 0 => (1, 0, 0)));

   DMA_Base : constant array (1 .. 2) of Unsigned_32 := (16#4002_6000#, 16#4002_6400#);

   type Stream_Registers is record
      CR, NDTR, PAR, M0AR, M1AR, FCR : Unsigned_32;
   end record with Volatile;
   for Stream_Registers use record
      CR   at 16#00# range 0 .. 31;
      NDTR at 16#04# range 0 .. 31;
      PAR  at 16#08# range 0 .. 31;
      M0AR at 16#0C# range 0 .. 31;
      M1AR at 16#10# range 0 .. 31;
      FCR  at 16#14# range 0 .. 31;
   end record;

   function Stream_Address (S : DMA_Stream) return System.Address is
     (System'To_Address (DMA_Base (S.Controller) + 16#10# + 16#18# * Unsigned_32 (S.Stream)));

   --  The stream's flags cleared: its interrupt flag clear register and the
   --  stream's six-bit group in it.
   procedure Clear_Flags (S : DMA_Stream) is
      Shifts : constant array (0 .. 3) of Natural := (0, 6, 16, 22);
      Clear  : Unsigned_32 with Volatile, Import,
        Address => System'To_Address (DMA_Base (S.Controller) + (if S.Stream < 4 then 16#08# else 16#0C#));
   begin
      Clear := Shift_Left (16#3D#, Shifts (S.Stream mod 4));
   end Clear_Flags;

   EN       : constant Unsigned_32 := 2 ** 0;
   DIR_M2P  : constant Unsigned_32 := 2 ** 6;
   MINC     : constant Unsigned_32 := 2 ** 10;
   PSIZE_32 : constant Unsigned_32 := 2 ** 12;
   MSIZE_32 : constant Unsigned_32 := 2 ** 14;
   PL_High  : constant Unsigned_32 := 2 ** 17;
   DMDIS    : constant Unsigned_32 := 2 ** 2;

   --  The DShot timings: the bit's twenty counts, and the counts a zero
   --  and a one stay high.
   Bit_Length : constant := 20;
   Bit_0      : constant := 7;
   Bit_1      : constant := 14;
   Buffer_Size : constant := 18;

   subtype Motor_Slot is Natural range 0 .. 7;
   type Frame_Buffer is array (0 .. Buffer_Size - 1) of Unsigned_32;
   pragma Volatile_Components (Frame_Buffer);
   Buffers : array (Motor_Slot) of aliased Frame_Buffer := (others => (others => 0));

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

   function Tagged_Pin (Tag : Unsigned_8) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Unsigned_8) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

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
      RCC_AHB1ENR := RCC_AHB1ENR or Shift_Left (1, 20 + S.Controller);
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

   procedure Init (C : Adaflight.Config_Groups.Configuration; Count : Natural) is
      Hz    : constant Unsigned_32 := Protocol_Hz (C.Motor_Config.Dev.Motor_Protocol);
      Total : constant Natural := Natural'Min (Count, 8);
      Last  : Timer_Name := TIM1;
      Added : Boolean := False;
   begin
      Driven := 0;
      Kind := Adaflight.MSP_Motor_In.No_Device;
      if Hz = 0 then
         return;
      end if;
      for M in 0 .. Total - 1 loop
         declare
            Order    : constant Natural := Natural (C.Motor_Config.Dev.Motor_Output_Reordering (M)) mod 8;
            Tag      : constant Unsigned_8 := C.Motor_Config.Dev.Io_Tags (Order);
            Found    : Boolean := False;
            E        : Timer_Entry := Timer_Table (Timer_Table'First);
            S        : DMA_Stream;
            Inverted : constant Boolean := C.Motor_Config.Dev.Motor_Inversion /= 0;
         begin
            if Tagged_Pin (Tag) then
               for Map of Adaflight.Board.Timer_Map loop
                  if Map.P = Pin_Of (Tag) and then Map.Timer_Option >= 1 and then Map.DMA_Option >= 0 then
                     declare
                        Seen : Natural := 0;
                     begin
                        for T of Timer_Table loop
                           if T.Where = Map.P then
                              Seen := Seen + 1;
                              if Seen = Map.Timer_Option then
                                 E := T;
                                 declare
                                    O : constant DMA_Options := Options_Of (T.Timer, T.Channel);
                                 begin
                                    if Map.DMA_Option < O'Length then
                                       S := O (O'First + Map.DMA_Option);
                                       Found := True;
                                    end if;
                                 end;
                              end if;
                           end if;
                        end loop;
                     end;
                     exit;
                  end if;
               end loop;
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
      Is_On := False;
   end Disable;

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
     (if Index < Driven and then Outputs (Index).Configured
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
