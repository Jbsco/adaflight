--  The STM32F4 and F7 converters at a 10.5 MHz clock: the configured
--  converter scans its inputs in order, 12 bits after 480 sample cycles
--  each, continuously, and a circular DMA stream writes each result into its
--  slot; ADC1 also converts the internal reference and temperature channels
--  on request.
with Interfaces;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.Timers;
package Adaflight.STM32.ADC is
   subtype Sample is Interfaces.Unsigned_16 range 0 .. 4_095;
   --  ADC1 on at the converters' clock.
   procedure Init;
   --  Whether the pin has a channel on a converter, 0 to 2 for ADC1 to ADC3.
   function Has_Channel (P : Pin; Device : Natural) return Boolean;

   Max_Inputs : constant := 4;
   subtype Input_Count is Natural range 0 .. Max_Inputs;
   type Input_Pins is array (0 .. Max_Inputs - 1) of Pin;
   --  The DMA streams other drivers took, numbered from 1 for the first
   --  controller's stream 0.
   type Stream_Flags is array (1 .. 16) of Boolean;

   --  The scan as the reference starts it: the converter's clock on, its
   --  inputs analog in order at 480 cycles each, a continuous scan asking for
   --  a transfer after each conversion, and the converter on; then, with a
   --  stream no other driver took, the stream circular from the data register
   --  into the slots and the first conversion. Without one the converter
   --  stays stopped and every slot reads zero.
   procedure Start_Scan
     (Device : Natural; Inputs : Input_Pins; Count : Input_Count; Stream : Adaflight.STM32.Timers.DMA_Stream;
      Has_Stream : Boolean; Taken : Stream_Flags)
     with Pre => Device <= 2;
   --  A slot's last result, zero before the first.
   function Scanned (Slot : Natural) return Sample;
   --  The stream the scan owns, zero for none.
   function Stream_Number return Natural;

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
