--  The host's SPI buses. SPI3 carries a model of the MAX7456 OSD chip, and
--  every other bus reads 16#FF#. The model takes a transfer as one selection
--  of register writes and reads in pairs: the display memory with its
--  automatic increment ended by 16#FF#, the character memory written to the
--  font store on its write command and read back on its read command, the
--  reset bit clear at once, the insertion register at its default and a PAL
--  signal on the status.
package body Adaflight.STM32.SPI is
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
      else
         Rx := (others => 16#FF#);
      end if;
   end Transfer;
end Adaflight.STM32.SPI;
