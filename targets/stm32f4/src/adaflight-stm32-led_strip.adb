with Interfaces;
with System;
with System.Storage_Elements;
with Adaflight.CLI_Resources;
with Adaflight.WS2811;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
with Adaflight.STM32.Platform;
package body Adaflight.STM32.LED_Strip is
   use Interfaces;
   package GPIO renames Adaflight.STM32.GPIO;
   package W renames Adaflight.WS2811;

   --  Thirty-two bits for every LED the strip can have, then the low tail.
   Bits_Max    : constant := 32;
   Tail        : constant := 42;
   Buffer_Size : constant := Adaflight.LED_Strip.Max_Leds * Bits_Max + Tail;
   type Strip_Buffer is array (0 .. Buffer_Size - 1) of Unsigned_32;
   pragma Volatile_Components (Strip_Buffer);
   Buffer : Strip_Buffer := (others => 0)
     with Linker_Section => Adaflight.STM32.Platform.DMA_Section;

   Configured   : Boolean := False;
   Strip_Format : W.Format := W.GRB;
   One, Zero    : Unsigned_32 := 0;
   Channel      : Timer_Entry;
   Stream       : DMA_Stream;

   PL_Very_High : constant Unsigned_32 := 3 * 2 ** 16;

   --  The strip's channel and stream as the reference sets them up: the pin
   --  on the timer's alternate function pulled up, the timer stopped and
   --  counting at the strip's prescaler over the carrier's period, the
   --  channel in PWM mode 1 at zero with its preload, the outputs, the
   --  period's preload and the channel on, the timer on, and the stream from
   --  the buffer to the compare register at the channel's request.
   procedure Configure (E : Timer_Entry; S : DMA_Stream) is
      Regs     : Timer_Registers with Import, Address => Timer_Base (E.Timer);
      DMA      : Stream_Registers with Import, Address => Stream_Address (S);
      Clock    : constant Unsigned_32 := Timer_Clock_Hz (E.Timer);
      Prescale : constant Unsigned_16 := W.Prescaler (Clock);
      Period   : constant Unsigned_16 := W.Period (Clock, Prescale);
   begin
      GPIO.Enable_Port (E.Where.Port);
      GPIO.Set_Alternate (E.Where, Alternate (E.Timer), GPIO.Up, Rate => GPIO.High);
      Enable_Clock (E.Timer);
      Regs.CR1 := Regs.CR1 and not CEN;
      One := Unsigned_32 (W.Bit_1 (Period));
      Zero := Unsigned_32 (W.Bit_0 (Period));
      Set_Time_Base (E.Timer, Unsigned_32 (Period), Unsigned_32 (Prescale));
      Set_Output_Compare (E, 0, Inverted => False);
      if Advanced (E.Timer) then
         Regs.BDTR := Regs.BDTR or MOE;
      end if;
      Regs.CR1 := Regs.CR1 or ARPE;
      Regs.CCER := Regs.CCER or Shift_Left (Unsigned_32'(if E.N then 2#0100# else 2#0001#), 4 * (E.Channel - 1));
      Regs.CR1 := Regs.CR1 or CEN;
      Enable_DMA (S);
      DMA.CR := DMA.CR and not EN;
      for Count in 1 .. 100_000 loop
         exit when (DMA.CR and EN) = 0;
      end loop;
      DMA.CR := 0;
      DMA.NDTR := 0;
      DMA.PAR := 0;
      DMA.M0AR := 0;
      DMA.M1AR := 0;
      DMA.FCR := 16#21#;
      Clear_Flags (S);
      DMA.CR := Shift_Left (Unsigned_32 (S.Channel), 25) or PL_Very_High or MSIZE_32 or PSIZE_32 or MINC or DIR_M2P;
      DMA.FCR := DMA.FCR and not (DMDIS or 2#11#);
      DMA.NDTR := Buffer_Size;
      DMA.PAR := CCR_Value (E.Timer, E.Channel);
      DMA.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Buffer'Address));
      Regs.DIER := Regs.DIER or Shift_Left (1, 8 + E.Channel);
   end Configure;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      Tag    : constant Unsigned_8 := C.Led_Strip_Config.Io_Tag;
      Format : constant Unsigned_8 := C.Led_Strip_Config.Ledstrip_Grb_Rgb;
      E      : Timer_Entry;
      Index  : Natural;
      Found  : Boolean;
      S      : DMA_Stream;
   begin
      Configured := False;
      Strip_Format := (if Format <= 2 then W.Format'Val (Format) else W.GRB);
      Buffer := (others => 0);
      if Tag = 0 then
         return;
      end if;
      Allocate (Tag, Adaflight.CLI_Resources.LED_Strip, E, Index, Found);
      if not Found then
         return;
      end if;
      declare
         O      : constant DMA_Options := Options_Of (E.Timer, E.Channel);
         Option : constant Integer := Option_Of (Index);
      begin
         if Option not in 0 .. O'Length - 1 then
            return;
         end if;
         S := O (O'First + Option);
      end;
      for M in 0 .. Adaflight.STM32.Motors.Count - 1 loop
         if Adaflight.STM32.Motors.Stream_Of (M) = (S.Controller - 1) * 8 + S.Stream + 1 then
            return;
         end if;
      end loop;
      Configure (E, S);
      Channel := E;
      Stream := S;
      Configured := True;
   end Init;

   function Ready return Boolean is
      DMA : Stream_Registers with Import, Address => Stream_Address (Stream);
   begin
      return Configured and then (DMA.CR and EN) = 0;
   end Ready;

   function Stream_Number return Natural is
     (if Configured then (Stream.Controller - 1) * 8 + Stream.Stream + 1 else 0);

   procedure Send (Colors : Adaflight.LED_Strip.Led_Output) is
      Bits : constant Natural := W.Bits (Strip_Format);
      Regs : Timer_Registers with Import, Address => Timer_Base (Channel.Timer);
      DMA  : Stream_Registers with Import, Address => Stream_Address (Stream);
   begin
      if not Ready then
         return;
      end if;
      for L in Colors'Range loop
         declare
            P : constant Unsigned_32 := W.Packed (Strip_Format, Colors (L).R, Colors (L).G, Colors (L).B);
         begin
            for K in 0 .. Bits - 1 loop
               Buffer (L * Bits + K) := (if (Shift_Right (P, Bits - 1 - K) and 1) /= 0 then One else Zero);
            end loop;
         end;
      end loop;
      Clear_Flags (Stream);
      DMA.NDTR := Buffer_Size;
      Regs.CNT := 0;
      Regs.CR1 := Regs.CR1 or CEN;
      DMA.CR := DMA.CR or EN;
   end Send;
end Adaflight.STM32.LED_Strip;
