with System.Storage_Elements;
with Adaflight.CLI_Resources;
with Adaflight.STM32.ADC;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.LED_Strip;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
with Adaflight.STM32.Timers; use Adaflight.STM32.Timers;
package body Adaflight.STM32.Transponder_Output is
   use Interfaces;
   package GPIO renames Adaflight.STM32.GPIO;
   package Core renames Adaflight.Transponder;

   --  The toggles of the code, which the stream reads.
   Toggles : Core.Pattern with Linker_Section => Adaflight.STM32.Platform.DMA_Section;

   Taken   : Boolean := False;
   Coding  : Core.Provider := Core.None;
   Toggle  : Unsigned_16 := 0;
   Channel : Timer_Entry;
   Stream  : DMA_Stream;

   PL_High  : constant Unsigned_32 := 2 * 2 ** 16;
   PSIZE_16 : constant Unsigned_32 := 2 ** 11;
   MSIZE_16 : constant Unsigned_32 := 2 ** 13;

   Load_Wait_Us : constant := 30_000;

   function Number (S : DMA_Stream) return Natural is ((S.Controller - 1) * 8 + S.Stream + 1);

   procedure Take (Tag : Unsigned_8; Found : out Boolean) is
      E     : Timer_Entry;
      Index : Natural;
      S     : DMA_Stream;
   begin
      Taken := False;
      Found := False;
      if Tag = 0 then
         return;
      end if;
      Allocate (Tag, Adaflight.CLI_Resources.Transponder, E, Index, Found);
      if not Found then
         return;
      end if;
      Found := False;
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
         if Adaflight.STM32.Motors.Stream_Of (M) = Number (S) then
            return;
         end if;
      end loop;
      if Adaflight.STM32.Motors.Bitbang_Setup.Streams (Number (S)) > 0 then
         return;
      end if;
      if Adaflight.STM32.LED_Strip.Stream_Number = Number (S)
        or else Adaflight.STM32.ADC.Stream_Number = Number (S)
      then
         return;
      end if;
      Channel := E;
      Stream := S;
      Taken := True;
      Found := True;
   end Take;

   --  The pin on the timer's alternate function pulled down, the timer
   --  stopped and counting at the coding's prescaler over its carrier's
   --  period, the channel in PWM mode 1 at zero with its preload, the
   --  outputs and the channel on, and the stream from the toggles to the
   --  compare register at the channel's request, sixteen bits a toggle. A
   --  transmission starts the timer.
   procedure Configure (P : Core.Provider) is
      Regs     : Timer_Registers with Import, Address => Timer_Base (Channel.Timer);
      DMA      : Stream_Registers with Import, Address => Stream_Address (Stream);
      Clock    : constant Unsigned_32 := Timer_Clock_Hz (Channel.Timer);
      Prescale : constant Unsigned_16 := Core.Prescaler (Clock, P);
      Period   : constant Unsigned_16 := Core.Period (Clock, Prescale, P);
   begin
      if not Taken then
         return;
      end if;
      Coding := P;
      Toggle := Core.Toggle_Of (Period);
      GPIO.Enable_Port (Channel.Where.Port);
      GPIO.Set_Alternate (Channel.Where, Alternate (Channel.Timer), GPIO.Down, Rate => GPIO.High);
      Enable_Clock (Channel.Timer);
      Enable_DMA (Stream);
      DMA.CR := DMA.CR and not EN;
      for Count in 1 .. 100_000 loop
         exit when (DMA.CR and EN) = 0;
      end loop;
      Regs.CR1 := Regs.CR1 and not CEN;
      Set_Time_Base (Channel.Timer, Unsigned_32 (Period), Unsigned_32 (Prescale));
      Set_Output_Compare (Channel, 0, Inverted => False);
      if Advanced (Channel.Timer) then
         Regs.BDTR := Regs.BDTR or MOE;
      end if;
      Regs.CCER :=
        Regs.CCER or Shift_Left (Unsigned_32'(if Channel.N then 2#0100# else 2#0001#), 4 * (Channel.Channel - 1));
      DMA.CR := 0;
      DMA.NDTR := 0;
      DMA.PAR := 0;
      DMA.M0AR := 0;
      DMA.M1AR := 0;
      DMA.FCR := 16#21#;
      Clear_Flags (Stream);
      DMA.CR := Shift_Left (Unsigned_32 (Stream.Channel), 25) or PL_High or MSIZE_16 or PSIZE_16 or MINC or DIR_M2P;
      DMA.FCR := DMA.FCR and not (DMDIS or 2#11#);
      DMA.PAR := CCR_Value (Channel.Timer, Channel.Channel);
      DMA.M0AR := Unsigned_32 (System.Storage_Elements.To_Integer (Toggles.Buffer'Address));
      Regs.DIER := Regs.DIER or Shift_Left (1, 8 + Channel.Channel);
   end Configure;

   function Ready return Boolean is
      DMA : Stream_Registers with Import, Address => Stream_Address (Stream);
   begin
      return Taken and then (DMA.CR and EN) = 0;
   end Ready;

   procedure Load (Data : Core.Code) is
      Start : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
   begin
      if not Taken then
         return;
      end if;
      while not Ready and then Adaflight.STM32.Time.Micros - Start < Load_Wait_Us loop
         null;
      end loop;
      Core.Encode (Coding, Data, Toggle, Toggles);
   end Load;

   procedure Transmit is
      Regs : Timer_Registers with Import, Address => Timer_Base (Channel.Timer);
      DMA  : Stream_Registers with Import, Address => Stream_Address (Stream);
   begin
      if not Ready then
         return;
      end if;
      Clear_Flags (Stream);
      DMA.NDTR := Unsigned_32 (Toggles.Length);
      Regs.CNT := 0;
      Regs.CR1 := Regs.CR1 or CEN;
      DMA.CR := DMA.CR or EN;
   end Transmit;

   function Stream_Number return Natural is (if Taken then Number (Stream) else 0);

end Adaflight.STM32.Transponder_Output;
