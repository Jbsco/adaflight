--  The host's SPI buses. SPI3 carries a model of the MAX7456 OSD chip, SPI2
--  a model of an SD card, and every other bus reads 16#FF#. The chip model
--  takes a transfer as one selection of register writes and reads in pairs:
--  the display memory with its automatic increment ended by 16#FF#, the
--  character memory written to the font store on its write command and read
--  back on its read command, the reset bit clear at once, the insertion
--  register at its default and a PAL signal on the status. The display
--  memory goes to a text file at most ten times a second after it changes:
--  sixteen lines of thirty characters, a dot for a code outside printable
--  ASCII, in the file the environment variable ADAFLIGHT_OSD_SCREEN names,
--  adaflight-osd.txt when unset. The card model is a high capacity version
--  2 card over the image file the environment variable ADAFLIGHT_SD_IMAGE
--  names, answering while its select pin is low: one idle byte before each
--  answer, the registers of a card named ADAFL, block reads and writes with
--  the write's data answer followed by two busy bytes, and runs of writes
--  ended by the stop token. No image means no card.
with Ada.Direct_IO;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Text_IO;
with Adaflight.Board;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.SPI is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Running : array (Bus) of Boolean := (others => False);

   OSDM_Default : constant Byte := 16#1B#;
   Status_PAL   : constant Byte := 16#01#;

   Registers : Byte_Array (0 .. 16#7F#) := (16#0C# => OSDM_Default, others => 0);
   Display   : Byte_Array (0 .. 511) := (others => 0);
   Address   : Natural range 0 .. 511 := 0;
   Increment : Boolean := False;
   Glyph     : Byte_Array (0 .. 63) := (others => 0);
   Font      : array (Byte) of Byte_Array (0 .. 53) := (others => (others => 0));
   Changed   : Boolean := False;
   Written   : Ada.Real_Time.Time := Ada.Real_Time.Clock;

   procedure Dump_Screen is
      File : Ada.Text_IO.File_Type;
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_OSD_SCREEN", "adaflight-osd.txt");
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
      for Row in 0 .. 15 loop
         for Col in 0 .. 29 loop
            declare
               Code : constant Byte := Display (Row * 30 + Col);
            begin
               Ada.Text_IO.Put (File, (if Code in 16#20# .. 16#7E# then Character'Val (Code) else '.'));
            end;
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         null;
   end Dump_Screen;

   procedure Chip_Write (Register : Byte; Value : Byte) is
   begin
      case Register is
         when 16#00# =>
            Registers (0) := Value and not 16#02#;
         when 16#04# =>
            Registers (4) := Value and not 16#04#;
            Increment := (Value and 16#01#) /= 0;
            if (Value and 16#04#) /= 0 then
               Display := (others => 0);
               Changed := True;
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
               Changed := Changed or else Display (Address) /= Value;
               Display (Address) := Value;
               if Increment then
                  Address := (Address + 1) mod Display'Length;
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

   procedure Transfer (B : Bus; Tx : Byte_Array; Rx : out Byte_Array) is
   begin
      if B = SPI3 then
         Chip_Frame (Tx, Rx);
         if Changed and then Ada.Real_Time.Clock - Written >= Ada.Real_Time.Milliseconds (100) then
            Dump_Screen;
            Changed := False;
            Written := Ada.Real_Time.Clock;
         end if;
      elsif B = SPI2 then
         Card_Transfer (Tx, Rx);
      else
         Rx := (others => 16#FF#);
      end if;
   end Transfer;
end Adaflight.STM32.SPI;
