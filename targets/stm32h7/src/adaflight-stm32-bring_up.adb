with Ada.Real_Time;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements;
with Adaflight.Board;
with Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.Flash;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Timer_Dispatch;
package body Adaflight.STM32.Bring_Up is
   use Adaflight.STM32.Timers;

   Count : Natural := 0 with Atomic;

   procedure Rise is
   begin
      Count := (if Count = Natural'Last then 0 else Count + 1);
   end Rise;

   procedure Watch_Gyro_Interrupt is
      P : constant Pin := Adaflight.Board.Gyro_1_EXTI_Pin;
   begin
      GPIO.Enable_Port (P.Port);
      GPIO.Set_Input (P);
      EXTI_Dispatch.Register (P.Number, Rise'Access);
      EXTI.Enable_Rising (P);
   end Watch_Gyro_Interrupt;

   function Edges return Natural is (Count);

   UIF : constant Unsigned_32 := 2 ** 0;
   UIE : constant Unsigned_32 := 2 ** 0;

   Ticks : array (Timer_Name) of Natural := (others => 0) with Atomic_Components;

   procedure Tick (T : Timer_Name) is
      Regs : Timer_Registers with Import, Address => Timer_Base (T);
   begin
      if (Regs.SR and UIF) /= 0 then
         Regs.SR := not UIF;
         if T in Counted_Timer then
            Ticks (T) := (if Ticks (T) = Natural'Last then 0 else Ticks (T) + 1);
         end if;
      end if;
   end Tick;

   procedure Start_Timers is
   begin
      for T in Counted_Timer loop
         declare
            Regs : Timer_Registers with Import, Address => Timer_Base (T);
         begin
            Enable_Clock (T);
            Reset (T);
            Set_Time_Base (T, Reload => 999, Prescale => Timer_Clock_Hz (T) / 1_000_000 - 1);
            Regs.SR := 0;
            Timer_Dispatch.Register (T, Tick'Access);
            Regs.DIER := UIE;
            Regs.CR1 := Regs.CR1 or CEN;
         end;
      end loop;
   end Start_Timers;

   function Updates (T : Counted_Timer) return Natural is (Ticks (T));

   function Bus_Address (A : System.Address) return Unsigned_32 is
     (Unsigned_32 (System.Storage_Elements.To_Integer (A)));

   DIR_M2M  : constant Unsigned_32 := 2 ** 7;
   PINC     : constant Unsigned_32 := 2 ** 9;
   PSIZE_16 : constant Unsigned_32 := 2 ** 11;
   MSIZE_16 : constant Unsigned_32 := 2 ** 13;
   TCIF0    : constant Unsigned_32 := 2 ** 5;

   type Word_Block is array (1 .. 8) of Unsigned_32;
   Source : Word_Block := (others => 0) with Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   Copies : array (1 .. 2) of Word_Block := (others => (others => 0))
     with Volatile, Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   Done   : array (1 .. 2) of Boolean := (others => False);

   procedure Copy_By_DMA is
   begin
      for I in Source'Range loop
         Source (I) := 16#A5A5_0000# + Unsigned_32 (I);
      end loop;
      for C in Done'Range loop
         declare
            S      : constant DMA_Stream := (Controller => C, Stream => 0, Channel => 0);
            DMA    : Stream_Registers with Import, Address => Stream_Address (S);
            Status : Unsigned_32 with Volatile, Import, Address => System'To_Address (DMA_Base (C));
         begin
            Enable_DMA (S);
            DMA.CR := 0;
            Clear_Flags (S);
            DMA.PAR := Bus_Address (Source'Address);
            DMA.M0AR := Bus_Address (Copies (C)'Address);
            DMA.NDTR := Source'Length;
            DMA.FCR := DMDIS or 2#11#;
            DMA.CR := Request_Bits (S) or DIR_M2M or PINC or MINC or PSIZE_32 or MSIZE_32 or EN;
            for Wait in 1 .. 100_000 loop
               exit when (Status and TCIF0) /= 0;
            end loop;
            Done (C) := (Status and TCIF0) /= 0 and then Copies (C) = Source;
         end;
      end loop;
   end Copy_By_DMA;

   function Copied (Controller : Positive) return Boolean is (Controller in Done'Range and then Done (Controller));

   ADC1_Request : constant := 9;
   ADC_Stream   : constant DMA_Stream := (Controller => 1, Stream => 1, Channel => ADC1_Request);

   RCC_AHB1ENR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D8#);
   ADC_ISR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_2000#);
   ADC_CR      : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_2008#);
   ADC_CFGR    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_200C#);
   ADC_PCSEL   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_201C#);
   ADC_SQR1    : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_2030#);
   ADC_CCR     : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_2308#);
   ADC_DR      : constant := 16#4002_2040#;

   ADC12EN  : constant Unsigned_32 := 2 ** 5;
   ADEN     : constant Unsigned_32 := 2 ** 0;
   ADSTART  : constant Unsigned_32 := 2 ** 2;
   ADVREGEN : constant Unsigned_32 := 2 ** 28;
   DEEPPWD  : constant Unsigned_32 := 2 ** 29;
   ADRDY    : constant Unsigned_32 := 2 ** 0;
   DMNGT_DMA_One_Shot : constant Unsigned_32 := 2 ** 0;
   CONT     : constant Unsigned_32 := 2 ** 13;
   CKMODE_4 : constant Unsigned_32 := 2#11# * 2 ** 16;
   Input    : constant := 3;

   Samples : array (1 .. 16) of Unsigned_16 := (others => 0)
     with Volatile, Linker_Section => Adaflight.STM32.Platform.DMA_Section;
   ADC_DMA : Stream_Registers with Import, Address => Stream_Address (ADC_Stream);

   procedure Start_ADC_DMA is
   begin
      RCC_AHB1ENR := RCC_AHB1ENR or ADC12EN;
      ADC_CCR := ADC_CCR or CKMODE_4;
      ADC_CR := ADC_CR and not DEEPPWD;
      ADC_CR := ADC_CR or ADVREGEN;
      delay until Ada.Real_Time."+" (Ada.Real_Time.Clock, Ada.Real_Time.Microseconds (20));
      ADC_ISR := ADRDY;
      ADC_CR := ADC_CR or ADEN;
      for Wait in 1 .. 100_000 loop
         exit when (ADC_ISR and ADRDY) /= 0;
      end loop;
      ADC_PCSEL := 2 ** Input;
      ADC_SQR1 := Shift_Left (Input, 6);
      ADC_CFGR := DMNGT_DMA_One_Shot or CONT;
      Enable_DMA (ADC_Stream);
      ADC_DMA.CR := 0;
      Clear_Flags (ADC_Stream);
      ADC_DMA.PAR := ADC_DR;
      ADC_DMA.M0AR := Bus_Address (Samples'Address);
      ADC_DMA.NDTR := Samples'Length;
      ADC_DMA.CR := Request_Bits (ADC_Stream) or PSIZE_16 or MSIZE_16 or MINC or EN;
      ADC_CR := ADC_CR or ADSTART;
   end Start_ADC_DMA;

   function ADC_Transfers_Left return Natural is (Natural (ADC_DMA.NDTR and 16#FFFF#));

   Identity : Natural := 0;

   procedure Read_Gyro_2_Identity is
      Select_Pin : constant Pin := Adaflight.Board.Gyro_2_CS_Pin;
      Read_Who_Am_I : constant Adaflight.Bytes.Byte_Array (1 .. 2) := (16#75# + 16#80#, 0);
      Reply : Adaflight.Bytes.Byte_Array (1 .. 2);
   begin
      SPI.Init (SPI.SPI4, Adaflight.Board.SPI4_SCK_Pin, Adaflight.Board.SPI4_SDI_Pin, Adaflight.Board.SPI4_SDO_Pin);
      SPI.Set_Divisor (SPI.SPI4, SPI.Divider (1_000_000));
      GPIO.Enable_Port (Select_Pin.Port);
      GPIO.Set_High (Select_Pin);
      GPIO.Set_Output (Select_Pin);
      GPIO.Set_Low (Select_Pin);
      SPI.Transfer (SPI.SPI4, Read_Who_Am_I, Reply);
      GPIO.Set_High (Select_Pin);
      Identity := Natural (Reply (2));
   end Read_Gyro_2_Identity;

   function Gyro_2_Identity return Natural is (Identity);

   Marker  : constant String := "adaflight STM32H7 configuration store";
   Written : Boolean := False;

   function Config_Marker_Held return Boolean is
     (for all I in Marker'Range
        => Flash.Config (I - Marker'First) = Adaflight.Bytes.Byte (Character'Pos (Marker (I))));

   procedure Keep_Config_Marker is
      Block : Adaflight.Bytes.Byte_Array (0 .. Marker'Length - 1);
      OK    : Boolean;
   begin
      if Config_Marker_Held then
         return;
      end if;
      for I in Block'Range loop
         Block (I) := Adaflight.Bytes.Byte (Character'Pos (Marker (Marker'First + I)));
      end loop;
      Flash.Write (Block, OK);
      Written := OK;
   end Keep_Config_Marker;

   function Config_Marker_Written return Boolean is (Written);
end Adaflight.STM32.Bring_Up;
