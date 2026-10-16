package body Adaflight.Core_Loop with SPARK_Mode is

   procedure Gyro_Sampled (C : in out Cadence; Ratio : Loop_Ratio) is
   begin
      if C.Counter mod Ratio = 0 then
         C.Counter := 0;
      end if;
      C.Counter := (C.Counter + 1) mod 256;
   end Gyro_Sampled;

end Adaflight.Core_Loop;
