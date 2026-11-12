--  The host's OLED display: a model of the dashboard's display on the first
--  I2C bus at the address 16#3C#, present when the environment variable
--  ADAFLIGHT_OLED_SCREEN names its screen file. Command writes set the
--  page and the column, with the value after a two-byte command skipped;
--  data writes fill the 128 by 64 memory in horizontal addressing. The
--  file shows the memory as eight lines of 21 characters read back through
--  the display's font: a block element in UTF-8 for a level of the vertical
--  bar graph, a hash for another glyph past printable ASCII and a question
--  mark for a cell that is no glyph. It is written at most ten
--  times a second, once the memory has rested for five milliseconds or has
--  waited a fifth of a second.
with Interfaces;
package Adaflight.Host_OLED is
   Address : constant Interfaces.Unsigned_8 := 16#3C#;
   function On return Boolean;
   procedure Write (Control : Interfaces.Unsigned_8; Value : Interfaces.Unsigned_8);
   --  Writes the file when it is due, once per scheduler pass.
   procedure Poll;
end Adaflight.Host_OLED;
