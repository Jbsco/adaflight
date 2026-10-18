package body Adaflight.MPU_Slave_Steps with SPARK_Mode is

   function Step_Is_MPU_Slave (D : Bus_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Is_MPU_Slave;

   procedure Step_Master_DMA_Off (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Master_DMA_Off;

   procedure Step_Master_Write (D : in out Bus_Line; Register : Byte; Value : Byte) is
      pragma Unreferenced (D, Register, Value);
   begin
      null;
   end Step_Master_Write;

   procedure Step_Master_Read (D : in out Bus_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
      pragma Unreferenced (D, Register, Data);
   begin
      OK := False;
   end Step_Master_Read;

   procedure Step_Mask_Interrupts (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Mask_Interrupts;

   procedure Step_Unmask_Interrupts (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Unmask_Interrupts;

   procedure Step_Micros (D : in out Bus_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Micros;

   procedure Step_Delay_Us (D : in out Bus_Line; Us : Interfaces.Unsigned_32) is
      pragma Unreferenced (D, Us);
   begin
      null;
   end Step_Delay_Us;

end Adaflight.MPU_Slave_Steps;
