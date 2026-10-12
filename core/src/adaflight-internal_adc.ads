--  The internal ADC channels: the band gap reference and the temperature
--  sensor readings each run through a moving average of eight, the
--  reference gives the analog supply in millivolts from the chip's
--  calibration word, and the core temperature follows from the
--  calibration point and slope. The conversions, their timing and the
--  calibration words stay with the target.
with Interfaces;

package Adaflight.Internal_ADC with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;

   --  A 12-bit conversion.
   subtype ADC_Value is Unsigned_16 range 0 .. 4095;

   Window_Length : constant := 8;
   subtype Window_Index is Natural range 0 .. Window_Length - 1;
   type Window is array (Window_Index) of ADC_Value;

   function Window_Sum (V : Window) return Natural is
     (Natural (V (0)) + Natural (V (1)) + Natural (V (2)) + Natural (V (3))
      + Natural (V (4)) + Natural (V (5)) + Natural (V (6)) + Natural (V (7)));

   --  The sum stays the sum of the window.
   type Moving_Average is record
      Sum    : Natural range 0 .. Window_Length * 4095 := 0;
      Values : Window := (others => 0);
      Pos    : Window_Index := 0;
   end record
     with Dynamic_Predicate => Moving_Average.Sum = Window_Sum (Moving_Average.Values);

   Reference_Mv     : constant := 3300;
   Cal1_Temperature : constant := 30;

   --  The chip's calibration: the reference reading at the calibration
   --  supply, the temperature sensor reading at thirty degrees, and the
   --  slope in thousandths of a degree per count.
   type Calibration is record
      Vrefint_Cal : Integer_32 range 0 .. 65_535 := 1489;
      Ts_Cal1     : Integer_32 range 0 .. 4095 := 940;
      Ts_Slope_K  : Integer_32 range -10_000 .. 10_000 := 307;
   end record;

   type Sampler is record
      Vref_Average     : Moving_Average;
      Temp_Average     : Moving_Average;
      Vref_Value       : ADC_Value := 0;
      Temp_Value       : ADC_Value := 0;
      Vref_Mv          : Unsigned_16 := 0;
      Core_Temperature : Integer_16 := 0;
   end record;

   --  The supply in millivolts from the averaged reference reading; a
   --  reading of zero gives zero, as the target's core divides.
   function Compensate_Vref (Cal : Calibration; Sample : ADC_Value) return Unsigned_16;

   --  The core temperature in degrees from the averaged sensor reading
   --  and the supply.
   function Compute_Temperature (Cal : Calibration; Sample : ADC_Value; Vref_Mv : Unsigned_16) return Integer_16;

   procedure Init (S : out Sampler);

   --  One conversion of both channels.
   procedure Process (S : in out Sampler; Cal : Calibration; Vref_Sample, Temp_Sample : ADC_Value);

end Adaflight.Internal_ADC;
