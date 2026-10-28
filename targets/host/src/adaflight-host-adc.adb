package body Adaflight.STM32.ADC is
   procedure Init is null;

   function Has_Channel (P : Pin) return Boolean is
     (case P.Port is
         when Port_A => P.Number <= 7,
         when Port_B => P.Number <= 1,
         when Port_C => P.Number <= 5,
         when others => False);

   procedure Enable (P : Pin) is null;

   --  No analog input is connected on the host.
   function Read (P : Pin) return Sample is (0);

   --  The internal channels read 0 until the first conversion, then a
   --  reference of 3300 mV and a core at 40 degrees for the calibration
   --  words below.
   Started : Boolean := False;

   procedure Init_Internal is null;

   procedure Start_Internal is
   begin
      Started := True;
   end Start_Internal;

   procedure Check_Internal (Busy : out Boolean) is
   begin
      Busy := False;
   end Check_Internal;

   function Reference_Sample return Sample is (if Started then 1_489 else 0);
   function Temperature_Sample return Sample is (if Started then 973 else 0);

   function Reference_Calibration return Interfaces.Unsigned_16 is (1_489);
   function Sensor_Calibration_30 return Interfaces.Unsigned_16 is (940);
   function Sensor_Calibration_110 return Interfaces.Unsigned_16 is (1_200);
end Adaflight.STM32.ADC;
