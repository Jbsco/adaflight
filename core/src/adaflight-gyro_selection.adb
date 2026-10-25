package body Adaflight.Gyro_Selection with SPARK_Mode is

   function Bit (G : Gyro_Index) return Mask is (Interfaces.Shift_Left (1, G));

   function Lowest (M : Mask) return Mask is (M and (-M));

   ------------
   -- Choose --
   ------------

   procedure Choose (I : Inputs; R : out Result) is
      Scan        : Mask := (if I.Stored_Detected = 0 then 16#FF# else I.Stored_Detected);
      First_Found : Boolean := False;
      Compatible  : Boolean := True;
      Rate        : Natural range 0 .. 65_535 := 0;
      Scale       : Float range 0.0 .. 1.0 := 0.0;
   begin
      R := (Stored_Detected => I.Stored_Detected, Enabled_Setting => I.Enabled_Setting, others => <>);
      Scan := Scan or I.Enabled_Setting;
      for G in 0 .. I.Count - 1 loop
         if I.Configured (G) then
            Scan := Scan or Bit (G);
         end if;
      end loop;
      for G in 0 .. I.Count - 1 loop
         if (Scan and Bit (G)) /= 0 and then I.Present (G) then
            R.Detected := R.Detected or Bit (G);
         end if;
      end loop;
      if R.Detected = 0 then
         R.Sample_Rate_Hz := 1_000;
         return;
      end if;
      R.Found := True;
      if R.Detected /= I.Stored_Detected then
         R.Stored_Detected := R.Detected;
         R.Write := True;
      end if;
      R.Enabled := R.Detected and I.Enabled_Setting;
      if R.Enabled = 0 then
         R.Enabled := Lowest (R.Detected);
      end if;
      for G in 0 .. I.Count - 1 loop
         if (R.Enabled and Bit (G)) /= 0 then
            if not First_Found then
               First_Found := True;
               Rate := I.Reports (G).Sample_Rate_Hz;
               Scale := I.Reports (G).Scale;
            elsif Rate /= I.Reports (G).Sample_Rate_Hz or else Scale /= I.Reports (G).Scale then
               Compatible := False;
            end if;
         end if;
      end loop;
      if not Compatible then
         R.Enabled := Lowest (R.Enabled);
      end if;
      if I.Enabled_Setting /= R.Enabled then
         R.Enabled_Setting := R.Enabled;
         R.Write := True;
      end if;
      for G in 0 .. I.Count - 1 loop
         if (R.Enabled and Bit (G)) /= 0 then
            R.Overflow_Protected := R.Overflow_Protected and then I.Reports (G).Overflow_Protected;
         end if;
      end loop;
      for G in 0 .. I.Count - 1 loop
         if (R.Enabled and Bit (G)) /= 0 then
            R.First := G;
            R.Scale := I.Reports (G).Scale;
            R.Sample_Rate_Hz := I.Reports (G).Sample_Rate_Hz;
            exit;
         end if;
      end loop;
   end Choose;

end Adaflight.Gyro_Selection;
