with System;
with System.Storage_Elements;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
--  The STM32H743's SDMMC1 on PC8 to PC12 and PD2: its 100 MHz kernel clock
--  divided to 400 kHz for the card's identification and to 25 MHz with four
--  data lines and hardware flow control after it, commands run by its
--  command path, and block transfers through its internal DMA into a buffer
--  in the uncached D2 RAM.
package body Adaflight.STM32.SDIO is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   package GPIO renames Adaflight.STM32.GPIO;

   type Registers is record
      POWER, CLKCR, ARG, CMD, RESP1, RESP2, RESP3, RESP4, DTIMER, DLEN, DCTRL, STA, ICR, IDMACTRL, IDMABASE0 :
        Unsigned_32;
   end record with Volatile;
   for Registers use record
      POWER     at 16#00# range 0 .. 31;
      CLKCR     at 16#04# range 0 .. 31;
      ARG       at 16#08# range 0 .. 31;
      CMD       at 16#0C# range 0 .. 31;
      RESP1     at 16#14# range 0 .. 31;
      RESP2     at 16#18# range 0 .. 31;
      RESP3     at 16#1C# range 0 .. 31;
      RESP4     at 16#20# range 0 .. 31;
      DTIMER    at 16#24# range 0 .. 31;
      DLEN      at 16#28# range 0 .. 31;
      DCTRL     at 16#2C# range 0 .. 31;
      STA       at 16#34# range 0 .. 31;
      ICR       at 16#38# range 0 .. 31;
      IDMACTRL  at 16#50# range 0 .. 31;
      IDMABASE0 at 16#58# range 0 .. 31;
   end record;
   Regs : Registers with Import, Address => System'To_Address (16#5200_7000#);
   RCC_AHB3ENR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_44D4#);
   RCC_AHB3RSTR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5802_447C#);
   SDMMC1_Bit   : constant Unsigned_32 := 2 ** 16;

   Power_On     : constant Unsigned_32 := 2#11#;
   Divide_400K  : constant Unsigned_32 := 125;
   Divide_25M   : constant Unsigned_32 := 2;
   Wide_4       : constant Unsigned_32 := 2#01# * 2 ** 14;
   Flow_Control : constant Unsigned_32 := 2 ** 17;

   Transfer     : constant Unsigned_32 := 2 ** 6;
   Stop         : constant Unsigned_32 := 2 ** 7;
   Short        : constant Unsigned_32 := 2#01# * 2 ** 8;
   Short_No_CRC : constant Unsigned_32 := 2#10# * 2 ** 8;
   Long         : constant Unsigned_32 := 2#11# * 2 ** 8;
   Path_On      : constant Unsigned_32 := 2 ** 12;

   From_Card    : constant Unsigned_32 := 2 ** 1;
   Blocks_512   : constant Unsigned_32 := 9 * 2 ** 4;
   DMA_On       : constant Unsigned_32 := 2 ** 0;

   CRC_Failed      : constant Unsigned_32 := 2 ** 0;
   Data_CRC_Failed : constant Unsigned_32 := 2 ** 1;
   Timed_Out       : constant Unsigned_32 := 2 ** 2;
   Data_Timed_Out  : constant Unsigned_32 := 2 ** 3;
   Underrun        : constant Unsigned_32 := 2 ** 4;
   Overrun         : constant Unsigned_32 := 2 ** 5;
   Responded       : constant Unsigned_32 := 2 ** 6;
   Sent            : constant Unsigned_32 := 2 ** 7;
   Data_Ended      : constant Unsigned_32 := 2 ** 8;
   Line_Busy       : constant Unsigned_32 := 2 ** 20;
   DMA_Error       : constant Unsigned_32 := 2 ** 27;
   Data_Errors     : constant Unsigned_32 :=
     Data_CRC_Failed or Data_Timed_Out or Underrun or Overrun or DMA_Error;
   Clear_All       : constant Unsigned_32 := 16#1FE0_0FFF#;

   type Response_Kind is (None, R1, R3, Long_Response);
   type Word_Array is array (1 .. 4) of Unsigned_32;

   Buffer : Byte_Array (0 .. Max_Write_Blocks * 512 - 1) := (others => 0)
     with Alignment => 32, Volatile, Linker_Section => Adaflight.STM32.Platform.DMA_Section;

   type State is record
      Started       : Boolean := False;
      High_Capacity : Boolean := False;
      Version_2     : Boolean := False;
      Address       : Unsigned_32 := 0;
      CID, CSD      : Word_Array := (others => 0);
      Reading       : Boolean := False;
      Writing       : Boolean := False;
      Multi         : Boolean := False;
      Failed        : Boolean := False;
   end record;
   Card : State;

   function Bus_Address (A : System.Address) return Unsigned_32 is
     (Unsigned_32 (System.Storage_Elements.To_Integer (A)));

   --  A command and its response, OK when the card answered as its kind
   --  asks within about 50 ms. An R3 answer carries no CRC, so its CRC
   --  failure is its answer.
   procedure Command
     (Index : Natural; Argument : Unsigned_32; Kind : Response_Kind; OK : out Boolean; Flags : Unsigned_32 := 0)
   is
      Wait : constant Unsigned_32 :=
        (case Kind is when None => 0, when R1 => Short, when R3 => Short_No_CRC, when Long_Response => Long);
      Status : Unsigned_32 := 0;
   begin
      Regs.ICR := Clear_All;
      Regs.ARG := Argument;
      Regs.CMD := Unsigned_32 (Index) or Wait or Path_On or Flags;
      OK := False;
      for Spin in 1 .. 50_000 loop
         Status := Regs.STA;
         exit when (Status and (Responded or Sent or Timed_Out or CRC_Failed)) /= 0;
         Adaflight.STM32.Time.Delay_Us (1);
      end loop;
      case Kind is
         when None => OK := (Status and Sent) /= 0;
         when R3 => OK := (Status and (Responded or CRC_Failed)) /= 0 and then (Status and Timed_Out) = 0;
         when R1 | Long_Response => OK := (Status and Responded) /= 0;
      end case;
      Regs.ICR := Responded or Sent or Timed_Out or CRC_Failed;
   end Command;

   --  An application command, CMD55 with the card's address first.
   procedure App_Command (Index : Natural; Argument : Unsigned_32; Kind : Response_Kind; OK : out Boolean) is
   begin
      Command (55, Card.Address, R1, OK);
      if OK then
         Command (Index, Argument, Kind, OK);
      end if;
   end App_Command;

   procedure Init_Hardware (OK : out Boolean) is
      Data_Pins : constant array (1 .. 5) of Pin :=
        ((Port_C, 8), (Port_C, 9), (Port_C, 10), (Port_C, 11), (Port_D, 2));
   begin
      RCC_AHB3ENR := RCC_AHB3ENR or SDMMC1_Bit;
      RCC_AHB3RSTR := RCC_AHB3RSTR or SDMMC1_Bit;
      RCC_AHB3RSTR := RCC_AHB3RSTR and not SDMMC1_Bit;
      GPIO.Enable_Port (Port_C);
      GPIO.Enable_Port (Port_D);
      GPIO.Set_Alternate ((Port_C, 12), 12, Rate => GPIO.Very_High);
      for P of Data_Pins loop
         GPIO.Set_Alternate (P, 12, GPIO.Up, Rate => GPIO.Very_High);
      end loop;
      Regs.POWER := 0;
      Regs.CLKCR := Divide_400K;
      Regs.POWER := Power_On;
      Adaflight.STM32.Time.Delay_Ms (2);
      Card := (others => <>);
      OK := True;
   end Init_Hardware;

   procedure Init_Card (OK : out Boolean) is
      Answered : Boolean;
      Ready    : Boolean := False;
   begin
      Card.Started := False;
      Command (0, 0, None, OK);
      if not OK then
         return;
      end if;
      Command (8, 16#1AA#, R1, Answered);
      Card.Version_2 := Answered and then (Regs.RESP1 and 16#FFF#) = 16#1AA#;
      for Try in 1 .. 1_000 loop
         App_Command (41, 16#8010_0000# or (if Card.Version_2 then 16#4000_0000# else 0), R3, OK);
         exit when not OK;
         Ready := (Regs.RESP1 and 16#8000_0000#) /= 0;
         exit when Ready;
         Adaflight.STM32.Time.Delay_Ms (1);
      end loop;
      if not (OK and Ready) then
         OK := False;
         return;
      end if;
      Card.High_Capacity := (Regs.RESP1 and 16#4000_0000#) /= 0;
      Command (2, 0, Long_Response, OK);
      if not OK then
         return;
      end if;
      Card.CID := (Regs.RESP1, Regs.RESP2, Regs.RESP3, Regs.RESP4);
      Command (3, 0, R1, OK);
      if not OK then
         return;
      end if;
      Card.Address := Regs.RESP1 and 16#FFFF_0000#;
      Command (9, Card.Address, Long_Response, OK);
      if not OK then
         return;
      end if;
      Card.CSD := (Regs.RESP1, Regs.RESP2, Regs.RESP3, Regs.RESP4);
      Command (7, Card.Address, R1, OK);
      if not OK then
         return;
      end if;
      Command (16, 512, R1, OK);
      if not OK then
         return;
      end if;
      App_Command (6, 2, R1, OK);
      if not OK then
         return;
      end if;
      Regs.CLKCR := Divide_25M or Wide_4 or Flow_Control;
      Card.Started := True;
   end Init_Card;

   procedure Check_Ready (Ready : out Boolean) is
      OK : Boolean;
   begin
      Ready := False;
      if not Card.Started then
         return;
      end if;
      Command (13, Card.Address, R1, OK);
      Ready := OK and then Interfaces.Shift_Right (Regs.RESP1, 9) mod 16 = 4;
   end Check_Ready;

   --  A field of a 128-bit register as the card sends it, its bits counted
   --  from 0 at the low end of the last word.
   function Field (R : Word_Array; Low, Width : Natural) return Unsigned_32 is
      Value : Interfaces.Unsigned_64 := 0;
      Word  : constant Positive := 4 - Low / 32;
      Shift : constant Natural := Low mod 32;
      use type Interfaces.Unsigned_64;
   begin
      Value := Interfaces.Unsigned_64 (R (Word));
      if Word > R'First then
         Value := Value or Interfaces.Shift_Left (Interfaces.Unsigned_64 (R (Word - 1)), 32);
      end if;
      return Unsigned_32 (Interfaces.Shift_Right (Value, Shift) and (Interfaces.Shift_Left (1, Width) - 1));
   end Field;

   procedure Card_Info (Info : out Adaflight.SD_Card_Types.Card_Information; OK : out Boolean) is
      use type Interfaces.Unsigned_64;
      Blocks : Interfaces.Unsigned_64;
   begin
      Info := (others => <>);
      OK := Card.Started;
      if not OK then
         return;
      end if;
      if Field (Card.CSD, 126, 2) = 1 then
         Blocks := (Interfaces.Unsigned_64 (Field (Card.CSD, 48, 22)) + 1) * 1024;
      else
         Blocks := (Interfaces.Unsigned_64 (Field (Card.CSD, 62, 12)) + 1)
           * 2 ** Natural (Field (Card.CSD, 47, 3) + 2) * 2 ** Natural (Field (Card.CSD, 80, 4)) / 512;
      end if;
      Info :=
        (Kind         => (if Card.High_Capacity then 2 elsif Card.Version_2 then 1 else 0),
         Capacity     => Blocks,
         Manufacturer => Byte (Field (Card.CID, 120, 8)),
         OEM_Id       => Interfaces.Unsigned_16 (Field (Card.CID, 104, 16)),
         Name_Head    => Field (Card.CID, 72, 32),
         Name_Tail    => Byte (Field (Card.CID, 64, 8)),
         Revision     => Byte (Field (Card.CID, 56, 8)),
         Serial       => Field (Card.CID, 24, 32),
         Date         => Interfaces.Unsigned_16 (Field (Card.CID, 8, 12)));
   end Card_Info;

   --  A transfer's end: its data path stopped, the stop command after a
   --  multiple block write, and its result.
   procedure Finish is
      OK : Boolean;
   begin
      Card.Failed := (Regs.STA and Data_Errors) /= 0;
      Regs.IDMACTRL := 0;
      Regs.DCTRL := 0;
      Regs.ICR := Clear_All;
      if Card.Multi then
         Command (12, 0, R1, OK, Flags => Stop);
         Card.Failed := Card.Failed or not OK;
      end if;
      Card.Reading := False;
      Card.Writing := False;
      Card.Multi := False;
   end Finish;

   function Transfer_Ended return Boolean is ((Regs.STA and (Data_Ended or Data_Errors)) /= 0);

   function Read_Pending return Boolean is
   begin
      if Card.Reading and then Transfer_Ended then
         Finish;
      end if;
      return Card.Reading;
   end Read_Pending;

   function Write_Pending return Boolean is
   begin
      if Card.Writing and then Transfer_Ended then
         Finish;
      end if;
      return Card.Writing or else (Regs.STA and Line_Busy) /= 0;
   end Write_Pending;

   procedure Start_Data (Index : Interfaces.Unsigned_32; Blocks : Positive; Reading : Boolean; OK : out Boolean) is
      Argument : constant Unsigned_32 := (if Card.High_Capacity then Index else Index * 512);
   begin
      OK := False;
      if not Card.Started or else Card.Reading or else Card.Writing then
         return;
      end if;
      Regs.ICR := Clear_All;
      Regs.DTIMER := 25_000_000 / 2;
      Regs.DLEN := Unsigned_32 (Blocks) * 512;
      Regs.IDMABASE0 := Bus_Address (Buffer'Address);
      Regs.IDMACTRL := DMA_On;
      Regs.DCTRL := Blocks_512 or (if Reading then From_Card else 0);
      Card.Multi := not Reading and then Blocks > 1;
      Command ((if Reading then 17 elsif Blocks > 1 then 25 else 24), Argument, R1, OK, Flags => Transfer);
      if not OK then
         Regs.IDMACTRL := 0;
         Regs.DCTRL := 0;
         Card.Multi := False;
         return;
      end if;
      Card.Reading := Reading;
      Card.Writing := not Reading;
   end Start_Data;

   procedure Start_Read (Index : Interfaces.Unsigned_32; OK : out Boolean) is
   begin
      Start_Data (Index, 1, True, OK);
   end Start_Read;

   procedure Fetch_Block (Data : out Adaflight.SD_Card_Bus.Block) is
   begin
      for K in Data'Range loop
         Data (K) := Buffer (K);
      end loop;
   end Fetch_Block;

   procedure Start_Write (Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean) is
   begin
      for K in 0 .. Data'Length - 1 loop
         Buffer (K) := Data (Data'First + K);
      end loop;
      Start_Data (Index, Data'Length / 512, False, OK);
   end Start_Write;
end Adaflight.STM32.SDIO;
