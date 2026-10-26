--  ADC1 of the STM32F405 at a 10.5 MHz clock: a pin in analog mode and one
--  conversion of its channel on request, 12 bits after 480 sample cycles.
with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.STM32.ADC is
   subtype Sample is Interfaces.Unsigned_16 range 0 .. 4_095;
   procedure Init;
   --  Whether the pin has an ADC1 channel.
   function Has_Channel (P : Pin) return Boolean;
   procedure Enable (P : Pin)
     with Pre => Has_Channel (P);
   function Read (P : Pin) return Sample
     with Pre => Has_Channel (P);
end Adaflight.STM32.ADC;
