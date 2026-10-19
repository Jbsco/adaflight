package body Adaflight.Sonar_Pin_Steps with SPARK_Mode is

   procedure Step_Pin_Owned (D : in out Bus_Line; Tag : Byte; Owned : out Boolean) is
      pragma Unreferenced (D, Tag);
   begin
      Owned := True;
   end Step_Pin_Owned;

   procedure Step_Config_Pin (D : in out Bus_Line; Tag : Byte; Input : Boolean) is
      pragma Unreferenced (D, Tag, Input);
   begin
      null;
   end Step_Config_Pin;

end Adaflight.Sonar_Pin_Steps;
