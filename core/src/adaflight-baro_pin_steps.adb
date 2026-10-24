package body Adaflight.Baro_Pin_Steps with SPARK_Mode is

   procedure Step_Init_Pin (D : in out Bus_Line; Tag : Byte; Owner : Byte) is
      pragma Unreferenced (D, Tag, Owner);
   begin
      null;
   end Step_Init_Pin;

   procedure Step_Config_Pin (D : in out Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Config_Pin;

   procedure Step_Pin_High (D : in out Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Pin_High;

   procedure Step_Pin_Low (D : in out Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Pin_Low;

   procedure Step_Read_Pin (D : in out Bus_Line; Tag : Byte; High : out Boolean) is
      pragma Unreferenced (D, Tag);
   begin
      High := False;
   end Step_Read_Pin;

   procedure Step_Release_Pin (D : in out Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Release_Pin;

   procedure Step_Interrupt_Init (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Interrupt_Init;

   procedure Step_Interrupt_Pin (D : in out Bus_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Interrupt_Pin;

end Adaflight.Baro_Pin_Steps;
