--  The host's SPI buses. SPI3 carries a model of the MAX7456 OSD chip and a
--  model of a flash chip, each answering while its select pin is low, SPI2
--  a model of an SD card, and every other bus reads 16#FF#. The chip model
--  takes a transfer as one selection of register writes and reads in pairs:
--  the display memory with its automatic increment ended by 16#FF#, the
--  character memory written to the font store on its write command and read
--  back on its read command, the reset bit clear at once, the insertion
--  register at its default and a PAL signal on the status. The display
--  memory goes to the host's screen file (Adaflight.Host_Screen). The card
--  model is a high capacity version
--  2 card over the image file the environment variable ADAFLIGHT_SD_IMAGE
--  names, answering while its select pin is low: one idle byte before each
--  answer, the registers of a card named ADAFL, block reads and writes with
--  the write's data answer followed by two busy bytes, and runs of writes
--  ended by the stop token. No image means no card. The flash model is a
--  16 MB W25Q128FV over the image file the environment variable
--  ADAFLIGHT_FLASH_IMAGE names: the identification, the status with the
--  write enable latch, page programs of up to 256 bytes that wrap in the
--  page, 64 KB sector erases, the chip erase, and reads from an address
--  with the fast read's idle byte. An image of 128 MB is a W25N01G NAND
--  chip instead: its identification after a dummy byte, its protection,
--  configuration and status registers, a data buffer of 2048 bytes that a
--  load fills and a page read takes from a page, programs and 128 KB block
--  erases that a set protection bit refuses, and buffer reads from a
--  column while its buffer read mode is on. The environment variable
--  ADAFLIGHT_FLASH_STUCK keeps that chip busy from its first block erase
--  when it says erase, and from its first page read when it says read. No
--  image means no chip. The board's
--  gyro bus carries a gyro model while the environment variable
--  ADAFLIGHT_GYRO_CHIP is set: an ICM-42605, ICM-42688-P or IIM-42653 where
--  its value names one, with their five register banks, a BMI270 where it
--  names that, an ICM-20602 or ICM-20689 with the MPU6000's register
--  layout, an LSM6DSV16X, LSM6DSV32X or LSM6DSK320X with a register store
--  that reads back what was written, and an MPU6000 otherwise. A model has
--  its identity, a
--  register store that a device reset clears, and its data registers, which
--  read zeros until its start wakes its sensors. They then read a
--  simulator's accelerations and rates, or without one a fixed acceleration
--  and rates that step from zero 8 s after the start. The BMI270 answers on
--  SPI after a rise of its select pin, puts a dummy byte before a read's
--  values, and wakes only with its configuration file loaded whole while
--  its power save is off.
with Ada.Direct_IO;
with Ada.Environment_Variables;
with Adaflight.BMI270_Config;
with Adaflight.Board;
with Adaflight.Host_Pin_Log;
with Adaflight.Host_Pins;
with Adaflight.Host_Screen;
with Adaflight.Host_Simulator;
with Adaflight.Sim_FDM;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Time;
package body Adaflight.STM32.SPI is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Running : array (Bus) of Boolean := (others => False);

   OSDM_Default : constant Byte := 16#1B#;
   Status_PAL   : constant Byte := 16#01#;

   Registers : Byte_Array (0 .. 16#7F#) := (16#0C# => OSDM_Default, others => 0);
   Address   : Natural range 0 .. 511 := 0;
   Increment : Boolean := False;
   Glyph     : Byte_Array (0 .. 63) := (others => 0);
   Font      : array (Byte) of Byte_Array (0 .. 53) := (others => (others => 0));

   procedure Chip_Write (Register : Byte; Value : Byte) is
   begin
      case Register is
         when 16#00# =>
            Registers (0) := Value and not 16#02#;
         when 16#04# =>
            Registers (4) := Value and not 16#04#;
            Increment := (Value and 16#01#) /= 0;
            if (Value and 16#04#) /= 0 then
               Adaflight.Host_Screen.Clear;
            end if;
         when 16#05# =>
            Registers (5) := Value;
            Address := Natural (Value and 16#01#) * 256 + Address mod 256;
         when 16#06# =>
            Registers (6) := Value;
            Address := (Address / 256) * 256 + Natural (Value);
         when 16#07# =>
            if Increment and then Value = 16#FF# then
               Increment := False;
            else
               Adaflight.Host_Screen.Put (Address, Value);
               if Increment then
                  Address := (Address + 1) mod 512;
               end if;
            end if;
         when 16#08# =>
            if Value = 16#A0# then
               Font (Registers (9)) := Glyph (0 .. 53);
            elsif Value = 16#50# then
               Glyph (0 .. 53) := Font (Registers (9));
            end if;
         when 16#0A# =>
            Registers (16#0A#) := Value and 16#3F#;
         when 16#0B# =>
            Glyph (Natural (Registers (16#0A#) and 16#3F#)) := Value;
         when others =>
            Registers (Natural (Register and 16#7F#)) := Value;
      end case;
   end Chip_Write;

   function Chip_Read (Register : Byte) return Byte is
     (if Register = 16#A0# then Status_PAL
      elsif Register = 16#C0# then Glyph (Natural (Registers (16#0A#) and 16#3F#))
      elsif Register in 16#80# .. 16#8F# then Registers (Natural (Register and 16#0F#))
      else 0);

   procedure Chip_Frame (Tx : Byte_Array; Rx : out Byte_Array) is
      I : Natural := Tx'First;
   begin
      Rx := (others => 0);
      while I + 1 <= Tx'Last loop
         if (Tx (I) and 16#80#) /= 0 then
            Rx (Rx'First + (I + 1 - Tx'First)) := Chip_Read (Tx (I));
         else
            Chip_Write (Tx (I), Tx (I + 1));
         end if;
         I := I + 2;
      end loop;
   end Chip_Frame;

   --  The card model over its image file.
   subtype Sector is Byte_Array (0 .. 511);
   package Sector_IO is new Ada.Direct_IO (Sector);

   Card_Checked     : Boolean := False;
   Card_Present     : Boolean := False;
   Card_File        : Sector_IO.File_Type;
   Card_Blocks      : Interfaces.Unsigned_32 := 0;
   Card_Initialized : Boolean := False;
   Card_App_Command : Boolean := False;
   Card_Command     : Byte_Array (0 .. 5) := (others => 0);
   Card_Command_Pos : Natural := 0;
   Card_Reply       : Byte_Array (0 .. 599) := (others => 16#FF#);
   Card_Reply_Len   : Natural := 0;
   Card_Reply_Pos   : Natural := 0;
   Card_Busy_After  : Natural := 0;
   Card_Busy_Left   : Natural := 0;
   Card_Receive     : Natural range 0 .. 2 := 0;
   Card_Receive_Pos : Integer := -1;
   Card_Write_Block : Interfaces.Unsigned_32 := 0;
   Card_Data        : Sector := (others => 0);

   procedure Card_Open is
   begin
      Card_Checked := True;
      if not Ada.Environment_Variables.Exists ("ADAFLIGHT_SD_IMAGE") then
         return;
      end if;
      Sector_IO.Open (Card_File, Sector_IO.Inout_File, Ada.Environment_Variables.Value ("ADAFLIGHT_SD_IMAGE"));
      Card_Blocks := Interfaces.Unsigned_32 (Sector_IO.Size (Card_File));
      Card_Present := Card_Blocks >= 1024;
   exception
      when others =>
         Card_Present := False;
   end Card_Open;

   procedure Card_Reply_Bytes (Data : Byte_Array) is
   begin
      for B of Data loop
         exit when Card_Reply_Len > Card_Reply'Last;
         Card_Reply (Card_Reply_Len) := B;
         Card_Reply_Len := Card_Reply_Len + 1;
      end loop;
   end Card_Reply_Bytes;

   --  An answer: one idle byte, the response, and for a register or a block
   --  one more idle byte, the start token, the bytes and two check bytes.
   procedure Card_Answer (Response : Byte_Array; Data : Byte_Array := (1 .. 0 => 0)) is
   begin
      Card_Reply_Len := 0;
      Card_Reply_Pos := 0;
      Card_Reply_Bytes ((0 => 16#FF#));
      Card_Reply_Bytes (Response);
      if Data'Length > 0 then
         Card_Reply_Bytes ((16#FF#, 16#FE#));
         Card_Reply_Bytes (Data);
         Card_Reply_Bytes ((0, 0));
      end if;
   end Card_Answer;

   function Card_CSD return Byte_Array is
      Size : constant Interfaces.Unsigned_32 := Card_Blocks / 1024 - 1;
   begin
      return
        (16#40#, 16#0E#, 16#00#, 16#32#, 16#5B#, 16#59#, 16#00#,
         Byte (Interfaces.Shift_Right (Size, 16) and 16#3F#), Byte (Interfaces.Shift_Right (Size, 8) and 16#FF#),
         Byte (Size and 16#FF#), 16#7F#, 16#80#, 16#0A#, 16#40#, 16#00#, 16#01#);
   end Card_CSD;

   Card_CID : constant Byte_Array (0 .. 15) :=
     (16#03#, Character'Pos ('S'), Character'Pos ('D'), Character'Pos ('A'), Character'Pos ('D'),
      Character'Pos ('A'), Character'Pos ('F'), Character'Pos ('L'), 16#10#, 16#00#, 16#00#, 16#12#, 16#34#,
      16#01#, 16#AA#, 16#01#);

   procedure Card_Process_Command is
      Code : constant Natural := Natural (Card_Command (0) and 16#3F#);
      Arg  : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Card_Command (1)) * 2 ** 24 + Interfaces.Unsigned_32 (Card_Command (2)) * 2 ** 16
        + Interfaces.Unsigned_32 (Card_Command (3)) * 256 + Interfaces.Unsigned_32 (Card_Command (4));
      App  : constant Boolean := Card_App_Command;
      R1   : constant Byte := (if Card_Initialized then 0 else 16#01#);
      Data : Sector;
   begin
      Card_App_Command := False;
      if App and then Code = 41 then
         Card_Initialized := True;
         Card_Answer ((0 => 0));
         return;
      elsif App then
         Card_Answer ((0 => R1));
         return;
      end if;
      case Code is
         when 0 =>
            Card_Initialized := False;
            Card_Answer ((0 => 16#01#));
         when 8 =>
            Card_Answer ((R1, 0, 0, Byte (Interfaces.Shift_Right (Arg, 8) and 16#0F#), Byte (Arg and 16#FF#)));
         when 55 =>
            Card_App_Command := True;
            Card_Answer ((0 => R1));
         when 58 =>
            Card_Answer ((R1, 16#C0#, 16#FF#, 16#80#, 16#00#));
         when 9 =>
            Card_Answer ((0 => R1), Card_CSD);
         when 10 =>
            Card_Answer ((0 => R1), Card_CID);
         when 16 =>
            Card_Answer ((0 => R1));
         when 17 =>
            if Arg < Card_Blocks then
               Sector_IO.Read (Card_File, Data, Sector_IO.Positive_Count (Arg + 1));
               Card_Answer ((0 => R1), Data);
            else
               Card_Answer ((0 => R1 or 16#40#));
            end if;
         when 24 | 25 =>
            Card_Answer ((0 => R1));
            if R1 = 0 then
               Card_Receive := (if Code = 24 then 1 else 2);
               Card_Receive_Pos := -1;
               Card_Write_Block := Arg;
            end if;
         when others =>
            Card_Answer ((0 => R1 or 16#04#));
      end case;
   end Card_Process_Command;

   --  One byte clocked to the card while it is selected, and the byte it
   --  answers.
   function Card_Clock (Input : Byte) return Byte is
      Output : Byte;
   begin
      if Card_Busy_Left > 0 then
         Card_Busy_Left := Card_Busy_Left - 1;
         return 0;
      end if;
      if Card_Reply_Pos < Card_Reply_Len then
         Output := Card_Reply (Card_Reply_Pos);
         Card_Reply_Pos := Card_Reply_Pos + 1;
         if Card_Reply_Pos = Card_Reply_Len then
            Card_Reply_Len := 0;
            Card_Reply_Pos := 0;
            Card_Busy_Left := Card_Busy_After;
            Card_Busy_After := 0;
         end if;
         return Output;
      end if;
      if Card_Receive /= 0 then
         if Card_Receive_Pos < 0 then
            if Input = 16#FD# and then Card_Receive = 2 then
               Card_Receive := 0;
               Card_Busy_Left := 2;
            elsif Input = (if Card_Receive = 1 then 16#FE# else 16#FC#) then
               Card_Receive_Pos := 0;
            end if;
         else
            if Card_Receive_Pos < 512 then
               Card_Data (Card_Receive_Pos) := Input;
            end if;
            Card_Receive_Pos := Card_Receive_Pos + 1;
            if Card_Receive_Pos = 512 + 2 then
               if Card_Write_Block < Card_Blocks then
                  Sector_IO.Write (Card_File, Card_Data, Sector_IO.Positive_Count (Card_Write_Block + 1));
                  Sector_IO.Flush (Card_File);
               end if;
               Card_Write_Block := Card_Write_Block + 1;
               Card_Reply (0) := 16#E5#;
               Card_Reply_Len := 1;
               Card_Reply_Pos := 0;
               Card_Busy_After := 2;
               Card_Receive_Pos := -1;
               if Card_Receive = 1 then
                  Card_Receive := 0;
               end if;
            end if;
         end if;
         return 16#FF#;
      end if;
      if Card_Command_Pos = 0 and then (Input and 16#C0#) = 16#40# then
         Card_Command (0) := Input;
         Card_Command_Pos := 1;
      elsif Card_Command_Pos > 0 then
         Card_Command (Card_Command_Pos) := Input;
         Card_Command_Pos := Card_Command_Pos + 1;
         if Card_Command_Pos = 6 then
            Card_Command_Pos := 0;
            Card_Process_Command;
         end if;
      end if;
      return 16#FF#;
   end Card_Clock;

   --  The flash model over its image file of 256-byte pages.
   subtype Page is Byte_Array (0 .. 255);
   package Page_IO is new Ada.Direct_IO (Page);

   Flash_Checked  : Boolean := False;
   Flash_Present  : Boolean := False;
   Flash_File     : Page_IO.File_Type;
   Flash_Pages    : Interfaces.Unsigned_32 := 0;
   Flash_Idle     : Boolean := True;
   Flash_Command  : Byte := 0;
   Flash_Pos      : Natural := 0;
   Flash_Address  : Interfaces.Unsigned_32 := 0;
   Flash_WEL      : Boolean := False;
   Flash_Page     : Page := (others => 16#FF#);
   Flash_Page_At  : Interfaces.Unsigned_32 := 0;
   Flash_Loaded   : Boolean := False;
   Flash_Rises    : Natural := 0;

   --  The NAND model's registers and data buffer over the same image file,
   --  eight of its records to a page.
   NAND_Page_Bytes  : constant := 2048;
   Flash_NAND       : Boolean := False;
   NAND_Buffer      : Byte_Array (0 .. NAND_Page_Bytes - 1) := (others => 16#FF#);
   NAND_Protection  : Byte := 16#7C#;
   NAND_Config      : Byte := 16#18#;
   NAND_Register    : Byte := 0;
   NAND_Column      : Natural := 0;
   NAND_Busy        : Boolean := False;
   NAND_Failed      : Byte := 0;
   NAND_Stuck_Erase : Boolean := False;
   NAND_Stuck_Read  : Boolean := False;

   procedure Flash_Open is
   begin
      Flash_Checked := True;
      if not Ada.Environment_Variables.Exists ("ADAFLIGHT_FLASH_IMAGE") then
         return;
      end if;
      Page_IO.Open (Flash_File, Page_IO.Inout_File, Ada.Environment_Variables.Value ("ADAFLIGHT_FLASH_IMAGE"));
      Flash_Pages := Interfaces.Unsigned_32 (Page_IO.Size (Flash_File));
      Flash_NAND := Flash_Pages = 524_288;
      Flash_Present := Flash_Pages = 65_536 or else Flash_NAND;
      NAND_Stuck_Erase := Ada.Environment_Variables.Value ("ADAFLIGHT_FLASH_STUCK", "") = "erase";
      NAND_Stuck_Read := Ada.Environment_Variables.Value ("ADAFLIGHT_FLASH_STUCK", "") = "read";
   exception
      when others =>
         Flash_Present := False;
   end Flash_Open;

   procedure Flash_Load (Index : Interfaces.Unsigned_32) is
   begin
      if Flash_Loaded and then Flash_Page_At = Index then
         return;
      end if;
      Page_IO.Read (Flash_File, Flash_Page, Page_IO.Positive_Count (Index + 1));
      Flash_Page_At := Index;
      Flash_Loaded := True;
   end Flash_Load;

   procedure Flash_Store is
   begin
      Page_IO.Write (Flash_File, Flash_Page, Page_IO.Positive_Count (Flash_Page_At + 1));
      Page_IO.Flush (Flash_File);
   end Flash_Store;

   procedure Flash_Erase_Pages (First, Count : Interfaces.Unsigned_32) is
      Blank : constant Page := (others => 16#FF#);
   begin
      for K in First .. First + Count - 1 loop
         exit when K >= Flash_Pages;
         Page_IO.Write (Flash_File, Blank, Page_IO.Positive_Count (K + 1));
      end loop;
      Page_IO.Flush (Flash_File);
      Flash_Loaded := False;
   end Flash_Erase_Pages;

   --  A NAND page into the data buffer, and the buffer's cleared bits into
   --  a page.
   procedure NAND_Read_Page (Index : Interfaces.Unsigned_32) is
   begin
      for K in Interfaces.Unsigned_32 range 0 .. 7 loop
         Flash_Load (Index * 8 + K);
         NAND_Buffer (Natural (K) * 256 .. Natural (K) * 256 + 255) := Flash_Page;
      end loop;
   end NAND_Read_Page;

   procedure NAND_Program_Page (Index : Interfaces.Unsigned_32) is
   begin
      for K in Interfaces.Unsigned_32 range 0 .. 7 loop
         Flash_Load (Index * 8 + K);
         for J in Flash_Page'Range loop
            Flash_Page (J) := Flash_Page (J) and NAND_Buffer (Natural (K) * 256 + J);
         end loop;
         Flash_Store;
      end loop;
   end NAND_Program_Page;

   --  One byte clocked to the NAND chip while it is selected, and the byte
   --  it answers. A busy chip takes status reads alone.
   function NAND_Clock (Input : Byte) return Byte is
      Output : Byte := 16#FF#;
      Page   : Interfaces.Unsigned_32;
   begin
      if Flash_Idle then
         Flash_Idle := False;
         Flash_Command := Input;
         Flash_Pos := 0;
         Flash_Address := 0;
         NAND_Column := 0;
         if NAND_Busy and then Input not in 16#05# | 16#0F# then
            Flash_Command := 0;
            return 16#FF#;
         end if;
         case Input is
            when 16#06# =>
               Flash_WEL := True;
            when 16#04# =>
               Flash_WEL := False;
            when 16#FF# =>
               Flash_WEL := False;
               NAND_Protection := 16#7C#;
               NAND_Config := 16#18#;
               NAND_Failed := 0;
            when 16#02# =>
               if Flash_WEL then
                  NAND_Buffer := (others => 16#FF#);
               end if;
            when others =>
               null;
         end case;
         return 16#FF#;
      end if;
      Flash_Pos := Flash_Pos + 1;
      case Flash_Command is
         when 16#9F# =>
            Output := (case Flash_Pos is when 2 => 16#EF#, when 3 => 16#AA#, when 4 => 16#21#, when others => 0);
         when 16#05# | 16#0F# =>
            if Flash_Pos = 1 then
               NAND_Register := Input;
            else
               Output :=
                 (case NAND_Register is
                     when 16#A0# => NAND_Protection,
                     when 16#B0# => NAND_Config,
                     when 16#C0# => (if NAND_Busy then 1 else 0) or (if Flash_WEL then 2 else 0) or NAND_Failed,
                     when others => 0);
            end if;
         when 16#01# | 16#1F# =>
            if Flash_Pos = 1 then
               NAND_Register := Input;
            elsif Flash_Pos = 2 and then NAND_Register = 16#A0# then
               NAND_Protection := Input;
            elsif Flash_Pos = 2 and then NAND_Register = 16#B0# then
               NAND_Config := Input;
            end if;
         when 16#D8# | 16#10# | 16#13# =>
            if Flash_Pos in 2 .. 3 then
               Flash_Address := Flash_Address * 256 + Interfaces.Unsigned_32 (Input);
            end if;
            if Flash_Pos = 3 then
               Page := Flash_Address mod (Flash_Pages / 8);
               if Flash_Command = 16#13# then
                  NAND_Read_Page (Page);
                  NAND_Busy := NAND_Stuck_Read;
               elsif Flash_WEL and then (NAND_Protection and 16#7C#) /= 0 then
                  NAND_Failed := NAND_Failed or (if Flash_Command = 16#D8# then 4 else 8);
                  Flash_WEL := False;
               elsif Flash_WEL and then Flash_Command = 16#D8# then
                  if NAND_Stuck_Erase then
                     NAND_Busy := True;
                  else
                     Flash_Erase_Pages ((Page / 64) * 512, 512);
                  end if;
                  Flash_WEL := False;
               elsif Flash_WEL then
                  NAND_Program_Page (Page);
                  Flash_WEL := False;
               end if;
            end if;
         when 16#02# | 16#84# =>
            if Flash_Pos <= 2 then
               NAND_Column := (NAND_Column * 256 + Natural (Input)) mod 65_536;
            elsif Flash_WEL and then NAND_Column < NAND_Page_Bytes then
               NAND_Buffer (NAND_Column) := Input;
               NAND_Column := NAND_Column + 1;
            end if;
         when 16#03# =>
            if Flash_Pos <= 2 then
               NAND_Column := (NAND_Column * 256 + Natural (Input)) mod 65_536;
            elsif Flash_Pos >= 4 then
               if (NAND_Config and 16#08#) /= 0 and then NAND_Column < NAND_Page_Bytes then
                  Output := NAND_Buffer (NAND_Column);
               end if;
               NAND_Column := NAND_Column + 1;
            end if;
         when others =>
            null;
      end case;
      return Output;
   end NAND_Clock;

   --  One byte clocked to the flash chip while it is selected, and the
   --  byte it answers.
   function Flash_Clock (Input : Byte) return Byte is
      Output : Byte := 16#FF#;
   begin
      if Flash_NAND then
         return NAND_Clock (Input);
      end if;
      if Flash_Idle then
         Flash_Idle := False;
         Flash_Command := Input;
         Flash_Pos := 0;
         Flash_Address := 0;
         case Input is
            when 16#06# =>
               Flash_WEL := True;
            when 16#04# =>
               Flash_WEL := False;
            when 16#C7# =>
               if Flash_WEL then
                  Flash_Erase_Pages (0, Flash_Pages);
                  Flash_WEL := False;
               end if;
            when others =>
               null;
         end case;
         return 16#FF#;
      end if;
      Flash_Pos := Flash_Pos + 1;
      case Flash_Command is
         when 16#9F# =>
            Output := (case Flash_Pos is when 1 => 16#EF#, when 2 => 16#40#, when 3 => 16#18#, when others => 0);
         when 16#05# =>
            Output := (if Flash_WEL then 16#02# else 16#00#);
         when 16#03# | 16#0B# | 16#02# | 16#D8# =>
            if Flash_Pos <= 3 then
               Flash_Address := Flash_Address * 256 + Interfaces.Unsigned_32 (Input);
               if Flash_Pos = 3 and then Flash_Command = 16#D8# and then Flash_WEL then
                  Flash_Erase_Pages ((Flash_Address / 16#10000#) * 256, 256);
                  Flash_WEL := False;
               end if;
            elsif Flash_Command = 16#0B# and then Flash_Pos = 4 then
               null;
            elsif Flash_Command = 16#02# then
               if Flash_WEL then
                  Flash_Load (Flash_Address / 256);
                  Flash_Page (Natural (Flash_Address mod 256)) := Flash_Page (Natural (Flash_Address mod 256)) and Input;
                  Flash_Address := (Flash_Address / 256) * 256 + (Flash_Address + 1) mod 256;
               end if;
            elsif Flash_Command in 16#03# | 16#0B# then
               if Flash_Address < Flash_Pages * 256 then
                  Flash_Load (Flash_Address / 256);
                  Output := Flash_Page (Natural (Flash_Address mod 256));
               end if;
               Flash_Address := Flash_Address + 1;
            end if;
         when others =>
            null;
      end case;
      return Output;
   end Flash_Clock;

   procedure Flash_Deselect is
   begin
      if not Flash_Idle and then not Flash_NAND and then Flash_Command = 16#02# and then Flash_Loaded then
         Flash_Store;
         Flash_WEL := False;
      end if;
      Flash_Idle := True;
   end Flash_Deselect;

   --  A rise of the select pin since the last transfer ends the command.
   procedure Flash_Check_Select is
   begin
      if Adaflight.Host_Pins.Rises (Adaflight.Board.Flash_CS_Pin) /= Flash_Rises then
         Flash_Rises := Adaflight.Host_Pins.Rises (Adaflight.Board.Flash_CS_Pin);
         Flash_Deselect;
      end if;
   end Flash_Check_Select;

   procedure Flash_Transfer (Tx : Byte_Array; Rx : out Byte_Array) is
   begin
      if not Flash_Checked then
         Flash_Open;
      end if;
      Rx := (others => 16#FF#);
      if not Flash_Present then
         return;
      end if;
      Flash_Check_Select;
      if Adaflight.STM32.GPIO.Is_High (Adaflight.Board.Flash_CS_Pin) then
         Flash_Deselect;
         return;
      end if;
      for K in Tx'Range loop
         Rx (Rx'First + (K - Tx'First)) := Flash_Clock (Tx (K));
      end loop;
   end Flash_Transfer;

   procedure Card_Transfer (Tx : Byte_Array; Rx : out Byte_Array) is
   begin
      if not Card_Checked then
         Card_Open;
      end if;
      Rx := (others => 16#FF#);
      if not Card_Present or else Adaflight.STM32.GPIO.Is_High (Adaflight.Board.SDCARD_SPI_CS_Pin) then
         Card_Command_Pos := 0;
         Card_Reply_Len := 0;
         Card_Reply_Pos := 0;
         return;
      end if;
      for K in Tx'Range loop
         Rx (Rx'First + (K - Tx'First)) := Card_Clock (Tx (K));
      end loop;
   end Card_Transfer;

   --  The chip the gyro model is: none without the environment variable, an
   --  ICM426xx where its value names one, an MPU6000 for any other value.
   type Gyro_Kind is
     (No_Model, MPU6000, ICM20602, ICM20689, BMI270, ICM42605, ICM42688P, IIM42653, LSM6DSV16X, LSM6DSV32X,
      LSM6DSK320X);
   function Gyro_Kind_Of_Environment return Gyro_Kind is
      Name : constant String := "ADAFLIGHT_GYRO_CHIP";
   begin
      if not Ada.Environment_Variables.Exists (Name) then
         return No_Model;
      end if;
      declare
         Value : constant String := Ada.Environment_Variables.Value (Name);
      begin
         return
           (if Value = "BMI270" then BMI270
            elsif Value = "ICM20602" then ICM20602
            elsif Value = "ICM20689" then ICM20689
            elsif Value = "LSM6DSV16X" then LSM6DSV16X
            elsif Value = "LSM6DSV32X" then LSM6DSV32X
            elsif Value = "LSM6DSK320X" then LSM6DSK320X
            elsif Value = "ICM42605" then ICM42605
            elsif Value = "ICM42688P" then ICM42688P
            elsif Value = "IIM42653" then IIM42653
            else MPU6000);
      end;
   end Gyro_Kind_Of_Environment;

   Gyro_Model     : constant Gyro_Kind := Gyro_Kind_Of_Environment;
   --  The chips with the MPU6000's register layout.
   MPU_Layout     : constant Boolean := Gyro_Model in MPU6000 | ICM20602 | ICM20689;
   LSM_Layout     : constant Boolean := Gyro_Model in LSM6DSV16X | LSM6DSV32X | LSM6DSK320X;
   Gyro_Model_Bus : constant Bus :=
     (if Adaflight.Board.Gyro_1_SPI_Device in 1 .. 6 then Bus'Val (Adaflight.Board.Gyro_1_SPI_Device - 1) else SPI1);
   Gyro_Sleep     : constant Byte := 16#40#;
   Gyro_Step_Ms   : constant := 8_000;
   subtype Gyro_Bank_Index is Natural range 0 .. 4;
   type Gyro_Banks is array (Gyro_Bank_Index) of Byte_Array (0 .. 16#7F#);
   --  A reset leaves an MPU6000 asleep, a BMI270 in its power save, and an
   --  LSM6DSV chip with its block update and address increment set, the
   --  LSM6DSV32X with its variant bit.
   Gyro_Reset     : constant Gyro_Banks :=
     (0      => (16#6B# => (if MPU_Layout then Gyro_Sleep else 0),
                 16#7C# => (if Gyro_Model = BMI270 then 3 else 0),
                 16#12# => (if LSM_Layout then 16#44# else 0),
                 16#17# => (if Gyro_Model = LSM6DSV32X then 16#04# else 0),
                 others => 0),
      others => (others => 0));
   --  The BMI270 answers on SPI once its select pin has risen: one rise
   --  after power, and after a soft reset the rise that ends the reset's own
   --  transfer and one more. Its configuration file loads with the power
   --  save off and the loading open, and counts when every byte is right.
   BMI_Rises_Needed : Natural := 1;
   BMI_File_Good    : Boolean := False;
   BMI_Loaded       : Boolean := False;
   Gyro_Registers : Gyro_Banks := Gyro_Reset;
   Gyro_Bank      : Gyro_Bank_Index := 0;

   --  One of the chip's seven readings: three accelerations, the
   --  temperature of 25 degrees and three rates. A chip that sleeps, or
   --  whose sensors are off, reads zeros.
   function Gyro_Reading (Which : Natural) return Integer is
      type Axes is array (1 .. 3) of Integer;
      One_G : constant Integer := (if Gyro_Model in IIM42653 | LSM6DSV32X then 1_024 else 2_048);
      Acc   : Axes := (One_G / 16, -One_G / 8, One_G - One_G / 256);
      Rates : Axes :=
        (if Adaflight.STM32.Time.Millis >= Gyro_Step_Ms then (164, 328, -492) else (0, 0, 0));
      Awake : constant Boolean :=
        (case Gyro_Model is
            when MPU6000 | ICM20602 | ICM20689 => (Gyro_Registers (0) (16#6B#) and Gyro_Sleep) = 0,
            when BMI270 => BMI_Loaded and then (Gyro_Registers (0) (16#7D#) and 16#06#) = 16#06#,
            when LSM6DSV16X | LSM6DSV32X | LSM6DSK320X =>
               (Gyro_Registers (0) (16#10#) and 16#0F#) /= 0 and then (Gyro_Registers (0) (16#11#) and 16#0F#) /= 0,
            when others => (Gyro_Registers (0) (16#4E#) and 16#0F#) = 16#0F#);
   begin
      if not Awake then
         return 0;
      end if;
      if Adaflight.Host_Simulator.Enabled then
         declare
            A : constant Adaflight.Sim_FDM.Axes := Adaflight.Host_Simulator.Acc;
            G : constant Adaflight.Sim_FDM.Axes := Adaflight.Host_Simulator.Gyro;
         begin
            for I in 1 .. 3 loop
               Acc (I) := Integer'Max (-32_768, Integer'Min (32_767, Integer (A (I)) * One_G / 256));
               Rates (I) := Integer (G (I));
            end loop;
         end;
      end if;
      return
        (case Which is
            when 0 .. 2 => Acc (Which + 1),
            when 3      => (if Gyro_Model = MPU6000 then -3_920 else 0),
            when others => Rates (Integer'Min (3, Which - 3)));
   end Gyro_Reading;

   --  A byte of a reading, its high byte first.
   function Gyro_Reading_Byte (Which : Natural; Low : Boolean) return Byte is
      Value : constant Integer := Gyro_Reading (Which) mod 65_536;
   begin
      return Byte (if Low then Value mod 256 else Value / 256);
   end Gyro_Reading_Byte;

   --  The MPU6000's data registers run from 16#3B#: accelerations,
   --  temperature, rates. The ICM426xx's run from 16#1D# in bank 0:
   --  temperature, accelerations, rates.
   function Gyro_Read (Register : Byte) return Byte is
      R : constant Natural := Natural (Register and 16#7F#);
   begin
      if MPU_Layout then
         return
           (if R in 16#3B# .. 16#48# then Gyro_Reading_Byte ((R - 16#3B#) / 2, (R - 16#3B#) mod 2 = 1)
            elsif R = 16#75# then (case Gyro_Model is when ICM20602 => 16#12#, when ICM20689 => 16#98#, when others => 16#68#)
            elsif R = 16#0C# and then Gyro_Model = MPU6000 then 16#14#
            else Gyro_Registers (0) (R));
      elsif R = 16#76# then
         return Byte (Gyro_Bank);
      elsif Gyro_Bank = 0 and then R in 16#1D# .. 16#1E# then
         return Gyro_Reading_Byte (3, R = 16#1E#);
      elsif Gyro_Bank = 0 and then R in 16#1F# .. 16#24# then
         return Gyro_Reading_Byte ((R - 16#1F#) / 2, (R - 16#1F#) mod 2 = 1);
      elsif Gyro_Bank = 0 and then R in 16#25# .. 16#2A# then
         return Gyro_Reading_Byte (4 + (R - 16#25#) / 2, (R - 16#25#) mod 2 = 1);
      elsif Gyro_Bank = 0 and then R = 16#75# then
         return (case Gyro_Model is when ICM42605 => 16#42#, when IIM42653 => 16#56#, when others => 16#47#);
      else
         return Gyro_Registers (Gyro_Bank) (R);
      end if;
   end Gyro_Read;

   --  A device reset clears the registers: the MPU6000's on its power
   --  register's top bit, the ICM426xx's on its device configuration's
   --  lowest. The ICM426xx's bank register selects one of five banks.
   procedure Gyro_Write (Register : Byte; Value : Byte) is
      R : constant Natural := Natural (Register and 16#7F#);
   begin
      if MPU_Layout then
         if R = 16#6B# and then (Value and 16#80#) /= 0 then
            Gyro_Registers := Gyro_Reset;
         else
            Gyro_Registers (0) (R) := Value;
         end if;
      elsif R = 16#76# then
         Gyro_Bank := (if Natural (Value and 7) <= 4 then Natural (Value and 7) else 0);
      elsif Gyro_Bank = 0 and then R = 16#11# and then (Value and 1) /= 0 then
         Gyro_Registers := Gyro_Reset;
      else
         Gyro_Registers (Gyro_Bank) (R) := Value;
      end if;
   end Gyro_Write;

   --  The BMI270's registers: its identity at 0, accelerations from 16#0C#
   --  and rates from 16#12#, each with its low byte first, and whether its
   --  configuration file is loaded at 16#21#.
   function BMI_Read (R : Natural) return Byte is
     (if R = 0 then 16#24#
      elsif R in 16#0C# .. 16#11# then Gyro_Reading_Byte ((R - 16#0C#) / 2, (R - 16#0C#) mod 2 = 0)
      elsif R in 16#12# .. 16#17# then Gyro_Reading_Byte (4 + (R - 16#12#) / 2, (R - 16#12#) mod 2 = 0)
      elsif R = 16#21# then (if BMI_Loaded then 1 else 0)
      else Gyro_Registers (0) (R mod 128));

   --  One selection of the BMI270: lost while the chip is not on SPI yet; a
   --  read with a dummy byte before its values; the soft reset; the
   --  configuration file; or a register write.
   procedure BMI_Frame (Tx : Byte_Array; Rx : out Byte_Array) is
      Register : constant Natural := Natural (Tx (Tx'First) and 16#7F#);
      Rises    : constant Natural := Adaflight.Host_Pins.Rises (Adaflight.Board.Gyro_1_CS_Pin);
   begin
      Rx := (others => 16#FF#);
      if Rises < BMI_Rises_Needed then
         return;
      end if;
      if (Tx (Tx'First) and 16#80#) /= 0 then
         for K in 1 .. Tx'Length - 1 loop
            Rx (Rx'First + K) := (if K = 1 then 0 else BMI_Read ((Register + K - 2) mod 128));
         end loop;
      elsif Tx'Length >= 2 then
         if Register = 16#7E# and then Tx (Tx'First + 1) = 16#B6# then
            Gyro_Registers := Gyro_Reset;
            BMI_File_Good := False;
            BMI_Loaded := False;
            BMI_Rises_Needed := Rises + 2;
         elsif Register = 16#5E# then
            BMI_File_Good :=
              Gyro_Registers (0) (16#59#) = 0 and then (Gyro_Registers (0) (16#7C#) and 1) = 0
              and then Tx (Tx'First + 1 .. Tx'Last) = Adaflight.BMI270_Config.Maximum_FIFO;
         else
            if Register = 16#59# then
               BMI_Loaded := Tx (Tx'First + 1) = 1 and then BMI_File_Good;
            end if;
            Gyro_Registers (0) (Register) := Tx (Tx'First + 1);
         end if;
      end if;
   end BMI_Frame;

   --  The LSM6DSV chips' registers: the identity at 16#0F#, rates from
   --  16#22# and accelerations from 16#28#, each with its low byte first.
   function LSM_Read (R : Natural) return Byte is
     (if R = 16#0F# then (if Gyro_Model = LSM6DSK320X then 16#75# else 16#70#)
      elsif R in 16#22# .. 16#27# then Gyro_Reading_Byte (4 + (R - 16#22#) / 2, (R - 16#22#) mod 2 = 0)
      elsif R in 16#28# .. 16#2D# then Gyro_Reading_Byte ((R - 16#28#) / 2, (R - 16#28#) mod 2 = 0)
      else Gyro_Registers (0) (R mod 128));

   --  One selection of an LSM6DSV chip: a read that runs on over the next
   --  registers, the software reset, which ends at once, or a register
   --  write.
   procedure LSM_Frame (Tx : Byte_Array; Rx : out Byte_Array) is
      Register : constant Natural := Natural (Tx (Tx'First) and 16#7F#);
   begin
      Rx := (others => 16#FF#);
      if (Tx (Tx'First) and 16#80#) /= 0 then
         for K in 1 .. Tx'Length - 1 loop
            Rx (Rx'First + K) := LSM_Read ((Register + K - 1) mod 128);
         end loop;
      elsif Tx'Length >= 2 then
         if Register = 16#12# and then (Tx (Tx'First + 1) and 1) /= 0 then
            Gyro_Registers := Gyro_Reset;
         else
            Gyro_Registers (0) (Register) := Tx (Tx'First + 1);
         end if;
      end if;
   end LSM_Frame;

   --  One selection: a register read that runs on over the next registers,
   --  or a register write.
   procedure Gyro_Frame (Tx : Byte_Array; Rx : out Byte_Array) is
      Register : constant Byte := Tx (Tx'First) and 16#7F#;
   begin
      if Gyro_Model = BMI270 then
         BMI_Frame (Tx, Rx);
         return;
      elsif LSM_Layout then
         LSM_Frame (Tx, Rx);
         return;
      end if;
      Rx := (others => 16#FF#);
      if (Tx (Tx'First) and 16#80#) /= 0 then
         for K in 1 .. Tx'Length - 1 loop
            Rx (Rx'First + K) := Gyro_Read (Byte ((Natural (Register) + K - 1) mod 128));
         end loop;
      elsif Tx'Length >= 2 then
         Gyro_Write (Register, Tx (Tx'First + 1));
      end if;
   end Gyro_Frame;

   procedure Init (B : Bus; SCK, SDI, SDO : Pin) is
      pragma Unreferenced (SCK, SDI, SDO);
   begin
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   function Divider (Hz : Interfaces.Unsigned_32) return Interfaces.Unsigned_16 is
      Clock   : Interfaces.Unsigned_32 := Bus_Clock_Hz / 2;
      Divisor : Interfaces.Unsigned_16 := 2;
   begin
      while Clock > Hz and then Divisor < 256 loop
         Divisor := Divisor * 2;
         Clock := Clock / 2;
      end loop;
      return Divisor;
   end Divider;

   function Clock_Of (Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32 is
     (Bus_Clock_Hz / Interfaces.Unsigned_32 (Interfaces.Unsigned_16'Max (1, Divisor)));

   procedure Set_Divisor (B : Bus; Divisor : Interfaces.Unsigned_16) is null;

   procedure Set_Mode (B : Bus; Leading_Edge : Boolean) is null;

   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array) is
   begin
      Adaflight.Host_Pin_Log.Transfer (Bus'Pos (B) + 1, Tx);
      if B = SPI3 and then not Adaflight.STM32.GPIO.Is_High (Adaflight.Board.Flash_CS_Pin) then
         Flash_Transfer (Tx, Rx);
      elsif B = SPI3 then
         if Flash_Present then
            Flash_Check_Select;
         end if;
         Chip_Frame (Tx, Rx);
      elsif B = SPI2 then
         Card_Transfer (Tx, Rx);
      elsif B = Gyro_Model_Bus and then Gyro_Model /= No_Model
        and then not Adaflight.STM32.GPIO.Is_High (Adaflight.Board.Gyro_1_CS_Pin)
      then
         Gyro_Frame (Tx, Rx);
      else
         Rx := (others => 16#FF#);
      end if;
   end Transfer;
end Adaflight.STM32.SPI;
