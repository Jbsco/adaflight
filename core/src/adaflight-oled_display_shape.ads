pragma SPARK_Mode (On);
--  The OLED display driver over a link that does nothing, the shape the
--  proof covers.
with Adaflight.OLED_Display;
with Adaflight.OLED_Steps;

package Adaflight.OLED_Display_Shape is new Adaflight.OLED_Display
  (I2C_Device => Adaflight.OLED_Steps.Link, Write => Adaflight.OLED_Steps.Step_Write);
