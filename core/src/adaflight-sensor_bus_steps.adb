package body Adaflight.Sensor_Bus_Steps with SPARK_Mode is

   function Step_Is_I2C (D : Bus_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return True;
   end Step_Is_I2C;

   function Step_Is_SPI (D : Bus_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Is_SPI;

   function Step_I2C_Address (D : Bus_Line) return Byte is
      pragma Unreferenced (D);
   begin
      return 0;
   end Step_I2C_Address;

   procedure Step_Set_I2C_Address (D : in out Bus_Line; Address : Byte) is
      pragma Unreferenced (D, Address);
   begin
      null;
   end Step_Set_I2C_Address;

   procedure Step_Prepare_SPI (D : in out Bus_Line; Max_Clock_Hz : Interfaces.Unsigned_32) is
      pragma Unreferenced (D, Max_Clock_Hz);
   begin
      null;
   end Step_Prepare_SPI;

   procedure Step_Release_SPI (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Release_SPI;

   procedure Step_Enable_EOC_Interrupt (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Enable_EOC_Interrupt;

   procedure Step_Release_EOC_Interrupt (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Release_EOC_Interrupt;

   procedure Step_Read_Byte (D : in out Bus_Line; Register : Byte; Value : out Byte) is
      pragma Unreferenced (D, Register);
   begin
      Value := 0;
   end Step_Read_Byte;

   procedure Step_Read_Buffer (D : in out Bus_Line; Command : Byte; Data : out Byte_Array) is
      pragma Unreferenced (D, Command);
   begin
      Data := (others => 0);
   end Step_Read_Buffer;

   procedure Step_Write_Byte (D : in out Bus_Line; Register : Byte; Value : Byte) is
      pragma Unreferenced (D, Register, Value);
   begin
      null;
   end Step_Write_Byte;

   procedure Step_Read_Registers (D : in out Bus_Line; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
      pragma Unreferenced (D, Register, Data);
   begin
      OK := False;
   end Step_Read_Registers;

   procedure Step_Write_Register (D : in out Bus_Line; Register : Byte; Value : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Register, Value);
   begin
      OK := False;
   end Step_Write_Register;

   procedure Step_Start_Read (D : in out Bus_Line; Register : Byte; Length : Positive; Started : out Boolean) is
      pragma Unreferenced (D, Register, Length);
   begin
      Started := False;
   end Step_Start_Read;

   procedure Step_Start_Write (D : in out Bus_Line; Register : Byte; Value : Byte; Started : out Boolean) is
      pragma Unreferenced (D, Register, Value);
   begin
      Started := False;
   end Step_Start_Write;

   procedure Step_Check_Busy (D : in out Bus_Line; Busy : out Boolean; Error : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
      Error := False;
   end Step_Check_Busy;

   procedure Step_Fetch (D : in out Bus_Line; Data : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      Data := (others => 0);
   end Step_Fetch;

   procedure Step_Register_Device (D : in out Bus_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Register_Device;

   procedure Step_Delay_Ms (D : in out Bus_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Delay_Us (D : in out Bus_Line; Us : Natural) is
      pragma Unreferenced (D, Us);
   begin
      null;
   end Step_Delay_Us;

   procedure Step_Millis (D : in out Bus_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

end Adaflight.Sensor_Bus_Steps;
