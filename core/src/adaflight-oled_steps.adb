package body Adaflight.OLED_Steps with SPARK_Mode is

   procedure Step_Write (D : in out Link; Control : Byte; Value : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Control, Value);
   begin
      OK := True;
   end Step_Write;

end Adaflight.OLED_Steps;
