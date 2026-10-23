pragma SPARK_Mode (On);
--  The MAX7456 display port over an SPI device that does nothing, the shape
--  the proof covers.
with Adaflight.MAX7456.Display_Port;
with Adaflight.MAX7456_Shape;

package Adaflight.MAX7456_Display_Port_Shape is new Adaflight.MAX7456_Shape.Display_Port;
