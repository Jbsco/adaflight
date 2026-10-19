--  An OLED display's I2C link as a step that does nothing, the shape the
--  display driver's proof takes.
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.OLED_Steps with SPARK_Mode is

   type Link is null record;

   procedure Step_Write (D : in out Link; Control : Byte; Value : Byte; OK : out Boolean)
     with Global => null;

end Adaflight.OLED_Steps;
