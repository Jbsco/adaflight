package body Adaflight.ESC_Pin_Steps with SPARK_Mode is

   procedure Step_Read_Micros (L : in out Pin_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (L);
   begin
      Now := 0;
   end Step_Read_Micros;

   procedure Step_Read_Millis (L : in out Pin_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (L);
   begin
      Now := 0;
   end Step_Read_Millis;

   procedure Step_Read_Pin (L : in out Pin_Line; ESC : Byte; High : out Boolean) is
      pragma Unreferenced (L, ESC);
   begin
      High := True;
   end Step_Read_Pin;

   procedure Step_Pin_Low (L : in out Pin_Line; ESC : Byte) is
      pragma Unreferenced (L, ESC);
   begin
      null;
   end Step_Pin_Low;

   procedure Step_Pin_High (L : in out Pin_Line; ESC : Byte) is
      pragma Unreferenced (L, ESC);
   begin
      null;
   end Step_Pin_High;

   procedure Step_Pin_Input (L : in out Pin_Line; ESC : Byte) is
      pragma Unreferenced (L, ESC);
   begin
      null;
   end Step_Pin_Input;

   procedure Step_Pin_Output (L : in out Pin_Line; ESC : Byte) is
      pragma Unreferenced (L, ESC);
   begin
      null;
   end Step_Pin_Output;

end Adaflight.ESC_Pin_Steps;
