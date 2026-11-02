package body Adaflight.Internal_ADC with SPARK_Mode is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_64;

   function Wrapped_16 (V : Integer_32) return Integer_16 is
     (Integer_16 ((Interfaces.Integer_64 (V) + 32_768) mod 65_536 - 32_768));

   --  The window takes the new reading in place of the oldest, the sum
   --  follows the window, and the average is the sum over the window
   --  length.
   procedure Update (M : in out Moving_Average; New_Value : ADC_Value; Result : out ADC_Value)
     with Post => Result = ADC_Value (M.Sum / Window_Length)
   is
      V : Window := M.Values;
   begin
      V (M.Pos) := New_Value;
      M := (Sum => Window_Sum (V), Values => V, Pos => (M.Pos + 1) mod Window_Length);
      Result := ADC_Value (M.Sum / Window_Length);
   end Update;

   ---------------------
   -- Compensate_Vref --
   ---------------------

   function Compensate_Vref (Cal : Calibration; Sample : ADC_Value) return Unsigned_16 is
      Scaled : constant Unsigned_32 := Unsigned_32'Mod (Interfaces.Integer_64 (Cal.Vrefint_Cal) * Reference_Mv);
   begin
      if Sample = 0 then
         return 0;
      end if;
      return Unsigned_16'Mod (Scaled / Unsigned_32 (Sample));
   end Compensate_Vref;

   -------------------------
   -- Compute_Temperature --
   -------------------------

   function Compute_Temperature (Cal : Calibration; Sample : ADC_Value; Vref_Mv : Unsigned_16) return Integer_16 is
      Scaled  : constant Integer_32 range 0 .. 4095 * 65_535 / Reference_Mv :=
        Integer_32 (Interfaces.Integer_64 (Sample) * Interfaces.Integer_64 (Vref_Mv) / Reference_Mv);
      Degrees : constant Integer_32 := ((Scaled - Cal.Ts_Cal1) * Cal.Ts_Slope_K + 500) / 1000 + Cal1_Temperature;
   begin
      return Wrapped_16 (Degrees);
   end Compute_Temperature;

   ----------
   -- Init --
   ----------

   procedure Init (S : out Sampler) is
   begin
      S := (Vref_Average     => (Sum => 0, Values => (others => 0), Pos => 0),
            Temp_Average     => (Sum => 0, Values => (others => 0), Pos => 0),
            Vref_Value       => 0,
            Temp_Value       => 0,
            Vref_Mv          => 0,
            Core_Temperature => 0,
            Taps             => <>);
   end Init;

   -------------
   -- Process --
   -------------

   procedure Process (S : in out Sampler; Cal : Calibration; Vref_Sample, Temp_Sample : ADC_Value) is
   begin
      Update (S.Vref_Average, Vref_Sample, S.Vref_Value);
      Update (S.Temp_Average, Temp_Sample, S.Temp_Value);
      S.Vref_Mv := Compensate_Vref (Cal, S.Vref_Value);
      S.Core_Temperature := Compute_Temperature (Cal, S.Temp_Value, S.Vref_Mv);
      S.Taps.Processed := True;
      S.Taps.Vref_Sample := Vref_Sample;
      S.Taps.Temp_Sample := Temp_Sample;
   end Process;

end Adaflight.Internal_ADC;
