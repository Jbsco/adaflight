package body Adaflight.STM32.ADC is
   procedure Init is null;

   function Has_Channel (P : Pin; Device : Natural) return Boolean is
     (case P.Port is
         when Port_A => P.Number <= (if Device = 2 then 3 else 7),
         when Port_B => Device <= 1 and then P.Number <= 1,
         when Port_C => P.Number <= (if Device = 2 then 3 else 5),
         when others => False);

   --  No analog input is connected on the host, and no stream runs.
   procedure Start_Scan
     (Device : Natural; Inputs : Input_Pins; Count : Input_Count; Stream : Adaflight.STM32.Timers.DMA_Stream;
      Has_Stream : Boolean; Taken : Stream_Flags) is null;
   function Scanned (Slot : Natural) return Sample is (0);
   function Stream_Number return Natural is (0);

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
