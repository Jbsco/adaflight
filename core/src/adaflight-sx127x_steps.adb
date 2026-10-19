package body Adaflight.SX127x_Steps with SPARK_Mode is

   procedure Step_Exti_Configured (D : in out Radio_Line; Configured : out Boolean) is
      pragma Unreferenced (D);
   begin
      Configured := True;
   end Step_Exti_Configured;

   procedure Step_Pin (D : in out Radio_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Pin;

   procedure Step_Delay_Ms (D : in out Radio_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Last_Exti_Time (D : in out Radio_Line; Time : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Time := 0;
   end Step_Last_Exti_Time;

   procedure Step_Bus_Write_Command (D : in out Radio_Line; Command : Byte; Value : Byte) is
      pragma Unreferenced (D, Command, Value);
   begin
      null;
   end Step_Bus_Write_Command;

   procedure Step_Bus_Write_Command_Multi (D : in out Radio_Line; Command : Byte; Data : Byte_Array) is
      pragma Unreferenced (D, Command, Data);
   begin
      null;
   end Step_Bus_Write_Command_Multi;

   procedure Step_Bus_Read_Command (D : in out Radio_Line; Command : Byte; Value : out Byte) is
      pragma Unreferenced (D, Command);
   begin
      Value := 0;
   end Step_Bus_Read_Command;

   procedure Step_Bus_Read_Command_Multi (D : in out Radio_Line; Command : Byte; Data : out Byte_Array) is
      pragma Unreferenced (D, Command);
   begin
      Data := (others => 0);
   end Step_Bus_Read_Command_Multi;

end Adaflight.SX127x_Steps;
