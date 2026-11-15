--  The host's log of chosen pins and of one SPI bus, for checks of drivers
--  that have no model here. The file ADAFLIGHT_PIN_LOG names takes a line
--  per level change of each pin that ADAFLIGHT_PIN_LOG_PINS lists, as
--  C07,C02, and a line per transfer on the SPI bus whose number
--  ADAFLIGHT_PIN_LOG_SPI gives. A line starts with the image's milliseconds.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.Host_Pin_Log is
   procedure Level (P : Pin; High : Boolean);
   procedure Transfer (Bus : Positive; Tx : Byte_Array);
end Adaflight.Host_Pin_Log;
