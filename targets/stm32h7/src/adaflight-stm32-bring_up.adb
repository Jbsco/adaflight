with Ada.Real_Time;
with Interfaces; use Interfaces;
with System;
with System.Storage_Elements;
with Adaflight.Board;
with Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.ADC;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.Flash;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.I2C;
with Adaflight.STM32.SDIO;
with Adaflight.SD_Card_Bus;
with Adaflight.SD_Card_Types;
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

   procedure Start_ADC is
      Inputs : Adaflight.STM32.ADC.Input_Pins := (others => (Port_C, 0));
   begin
      Adaflight.STM32.ADC.Init;
      Adaflight.STM32.ADC.Start_Scan
        (Device => 0, Inputs => Inputs, Count => 1, Stream => (Controller => 1, Stream => 1, Channel => 9),
         Has_Stream => True, Taken => (others => False));
      Adaflight.STM32.ADC.Init_Internal;
      Adaflight.STM32.ADC.Start_Internal;
   end Start_ADC;

   function ADC_Reading return Natural is (Natural (Adaflight.STM32.ADC.Scanned (0)));

   Reference_Reading, Temperature_Reading : Natural := 0;

   procedure Read_Internal (Reference, Temperature : out Natural) is
      Busy : Boolean;
   begin
      Adaflight.STM32.ADC.Check_Internal (Busy);
      if not Busy then
         Reference_Reading := Natural (Adaflight.STM32.ADC.Reference_Sample);
         Temperature_Reading := Natural (Adaflight.STM32.ADC.Temperature_Sample);
         Adaflight.STM32.ADC.Start_Internal;
      end if;
      Reference := Reference_Reading;
      Temperature := Temperature_Reading;
   end Read_Internal;

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

   Barometer : Natural := 0;

   procedure Read_Barometer_Identity is
      BMP180_Address  : constant := 16#77#;
      Chip_Identifier : constant := 16#D0#;
      Reply : Adaflight.Bytes.Byte_Array (1 .. 1);
      OK    : Boolean;
   begin
      I2C.Init (I2C.I2C4, (Port_B, 6), (Port_B, 7));
      I2C.Read (I2C.I2C4, BMP180_Address, Chip_Identifier, Reply, OK);
      Barometer := (if OK then Natural (Reply (1)) else 0);
   end Read_Barometer_Identity;

   function Barometer_Identity return Natural is (Barometer);

   procedure Read_SD_Block_0 (Stage : out Natural; Blocks : out Natural; Signature : out Natural) is
      OK    : Boolean;
      Info  : Adaflight.SD_Card_Types.Card_Information;
      Block : Adaflight.SD_Card_Bus.Block;
   begin
      Stage := 0;
      Blocks := 0;
      Signature := 0;
      SDIO.Init_Hardware (OK);
      if not OK then
         return;
      end if;
      Stage := 1;
      SDIO.Init_Card (OK);
      if not OK then
         return;
      end if;
      Stage := 2;
      SDIO.Card_Info (Info, OK);
      Blocks := Natural (Interfaces.Unsigned_64'Min (Info.Capacity, Interfaces.Unsigned_64 (Natural'Last)));
      SDIO.Start_Read (0, OK);
      if not OK then
         return;
      end if;
      Stage := 3;
      for Spin in 1 .. 1_000_000 loop
         exit when not SDIO.Read_Pending;
      end loop;
      if SDIO.Read_Pending then
         return;
      end if;
      SDIO.Fetch_Block (Block);
      Signature := Natural (Block (510)) * 256 + Natural (Block (511));
      Stage := 4;
   end Read_SD_Block_0;
end Adaflight.STM32.Bring_Up;
