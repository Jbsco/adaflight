package body Adaflight.CC2500_Steps with SPARK_Mode is

   procedure Step_Write_Command (D : in out Radio_Line; Command : Byte; Value : Byte) is
      pragma Unreferenced (D, Command, Value);
   begin
      null;
   end Step_Write_Command;

   procedure Step_Write_Command_Multi (D : in out Radio_Line; Command : Byte; Data : Byte_Array) is
      pragma Unreferenced (D, Command, Data);
   begin
      null;
   end Step_Write_Command_Multi;

   procedure Step_Read_Command (D : in out Radio_Line; Command : Byte; Value : out Byte) is
      pragma Unreferenced (D, Command);
   begin
      Value := 0;
   end Step_Read_Command;

   procedure Step_Read_Command_Multi (D : in out Radio_Line; Command : Byte; Data : out Byte_Array) is
      pragma Unreferenced (D, Command);
   begin
      Data := (others => 0);
   end Step_Read_Command_Multi;

   procedure Step_Write_Byte (D : in out Radio_Line; Value : Byte) is
      pragma Unreferenced (D, Value);
   begin
      null;
   end Step_Write_Byte;

   procedure Step_DMA_Enable (D : in out Radio_Line; Enable : Boolean) is
      pragma Unreferenced (D, Enable);
   begin
      null;
   end Step_DMA_Enable;

   procedure Step_Delay_Us (D : in out Radio_Line; Us : Natural) is
      pragma Unreferenced (D, Us);
   begin
      null;
   end Step_Delay_Us;

end Adaflight.CC2500_Steps;
