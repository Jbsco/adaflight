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

   --  The internal channels as an injected sequence of two after 480 sample
   --  cycles each: the band gap reference on channel 17, then the
   --  temperature sensor on channel 16.
   procedure Init_Internal;
   procedure Start_Internal;
   --  Whether a started conversion of the internal channels still runs.
   procedure Check_Internal (Busy : out Boolean);
   function Reference_Sample return Sample;
   function Temperature_Sample return Sample;

   --  The chip's calibration words: the reference reading at 3.3 V, and the
   --  sensor readings at 30 and 110 degrees.
   function Reference_Calibration return Interfaces.Unsigned_16;
   function Sensor_Calibration_30 return Interfaces.Unsigned_16;
   function Sensor_Calibration_110 return Interfaces.Unsigned_16;
end Adaflight.STM32.ADC;
