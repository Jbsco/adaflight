package body Adaflight.Optical_Flow_Detect.Probe with SPARK_Mode is

   procedure Detect
     (D                 : in out Device;
      Rangefinder_Built : Boolean;
      Hardware          : Byte;
      Rangefinder       : Byte;
      Detected          : in out Byte;
      Found             : out Boolean)
   is
      Reported : Delay_Ms;
   begin
      Found := False;
      if not Rangefinder_Built then
         return;
      end if;
      if Hardware = Hardware_MT then
         Detect_Chip (D, MT, Rangefinder, Found, Reported);
      elsif Hardware = Hardware_UPT1 then
         Detect_Chip (D, UPT1, Rangefinder, Found, Reported);
      else
         return;
      end if;
      if Found then
         Reschedule (D, Reported * 1000);
         Detected := Hardware;
      end if;
   end Detect;

end Adaflight.Optical_Flow_Detect.Probe;
