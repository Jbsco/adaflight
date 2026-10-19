--  The UG-2864HSWEG01 OLED display over I2C, 128 by 64 pixels drawn as 8
--  rows of 21 characters from a 5 by 7 font with a one-pixel gap. Every
--  transfer writes one control byte and one value: 16#80# before a command,
--  16#40# before a data byte. A command list stops at the first write the
--  display does not answer. Initialization sends the display-off command,
--  which has to be answered, then the 22 setup commands and a clear, and
--  answers true after. A clear sends the normal display, display off and
--  horizontal addressing commands, a quick clear, then the contrast 200 and
--  display on; a quick clear resets the page, the start line and the column
--  and writes 1024 zero bytes. A position sets the page from the row and the
--  column address from six times the column. A character sends its five
--  font columns and a gap byte, each combined with the format, normal or
--  inverse; a character below the space or past the font sends the blank,
--  where the reference reads past its table (finding F280).
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type I2C_Device is limited private;
   --  One write of a control byte and a value, answered or not.
   with procedure Write (D : in out I2C_Device; Control : Byte; Value : Byte; OK : out Boolean);
package Adaflight.OLED_Display with SPARK_Mode is

   Columns : constant := 21;
   Rows    : constant := 8;

   Normal_Format  : constant Byte := 0;
   Inverse_Format : constant Byte := 16#7F#;

   --  The format every character takes, the reference's global.
   type Display is record
      Format : Byte := Normal_Format;
   end record;

   procedure Init (D : in out I2C_Device; S : Display; OK : out Boolean);

   procedure Clear (D : in out I2C_Device);

   procedure Clear_Quick (D : in out I2C_Device);

   procedure Set_XY (D : in out I2C_Device; Col : Byte; Row : Byte);

   procedure Set_Line (D : in out I2C_Device; Row : Byte);

   procedure Send_Char (D : in out I2C_Device; S : Display; Ascii : Byte);

   procedure Send_String (D : in out I2C_Device; S : Display; Text : String);

end Adaflight.OLED_Display;
