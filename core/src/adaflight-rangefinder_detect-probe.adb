package body Adaflight.Rangefinder_Detect.Probe with SPARK_Mode is

   procedure Detect (D : in out Device; Hardware : Byte; Detected : in out Byte; Found : out Boolean) is
      Chip     : Driver;
      Reported : Delay_Ms;
   begin
      Found := False;
      if not Has_Driver (Hardware) then
         return;
      end if;
      Chip := Driver_Of (Hardware);
      Detect_Chip (D, Chip, Hardware, Found, Reported);
      if Found then
         Reschedule (D, Period_Ms (Chip, Reported) * 1000);
         Detected := Hardware;
      end if;
   end Detect;

end Adaflight.Rangefinder_Detect.Probe;
