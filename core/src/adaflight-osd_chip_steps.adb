package body Adaflight.OSD_Chip_Steps with SPARK_Mode is

   procedure Step_Preinit_CS (D : in out Chip_Line; Tag : Byte; Push_Pull : Boolean) is
      pragma Unreferenced (D, Tag, Push_Pull);
   begin
      null;
   end Step_Preinit_CS;

   procedure Step_Attach_Bus (D : in out Chip_Line; Instance : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Instance);
   begin
      OK := True;
   end Step_Attach_Bus;

   procedure Step_Check_CS_Free (D : in out Chip_Line; Free : out Boolean) is
      pragma Unreferenced (D);
   begin
      Free := True;
   end Step_Check_CS_Free;

   procedure Step_Prepare_CS (D : in out Chip_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Prepare_CS;

   procedure Step_Release_CS (D : in out Chip_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Release_CS;

   procedure Step_Claim_CS (D : in out Chip_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Claim_CS;

   procedure Step_Divider (D : in out Chip_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Hz);
   begin
      Divisor := 0;
   end Step_Divider;

   function Step_Clock_Of (D : Chip_Line; Divisor : Interfaces.Unsigned_16) return Interfaces.Unsigned_32 is
      pragma Unreferenced (D, Divisor);
   begin
      return 0;
   end Step_Clock_Of;

   procedure Step_Set_Divisor (D : in out Chip_Line; Divisor : Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Divisor);
   begin
      null;
   end Step_Set_Divisor;

   procedure Step_Write_Byte (D : in out Chip_Line; Value : Byte) is
      pragma Unreferenced (D, Value);
   begin
      null;
   end Step_Write_Byte;

   procedure Step_Write_Register (D : in out Chip_Line; Register : Byte; Value : Byte) is
      pragma Unreferenced (D, Register, Value);
   begin
      null;
   end Step_Write_Register;

   procedure Step_Read_Register (D : in out Chip_Line; Register : Byte; Value : out Byte) is
      pragma Unreferenced (D, Register);
   begin
      Value := 0;
   end Step_Read_Register;

   procedure Step_Write_Buffer (D : in out Chip_Line; Data : Byte_Array) is
      pragma Unreferenced (D, Data);
   begin
      null;
   end Step_Write_Buffer;

   procedure Step_Start_Transfer (D : in out Chip_Line; Data : Byte_Array) is
      pragma Unreferenced (D, Data);
   begin
      null;
   end Step_Start_Transfer;

   procedure Step_Check_Busy (D : in out Chip_Line; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Step_Check_Busy;

   function Step_Uses_DMA (D : Chip_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Uses_DMA;

   function Step_Transfer_Pending (D : Chip_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Transfer_Pending;

   procedure Step_Wait (D : in out Chip_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   procedure Step_Millis (D : in out Chip_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

   procedure Step_Micros (D : in out Chip_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Micros;

   procedure Step_Delay_Ms (D : in out Chip_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Delay_Us (D : in out Chip_Line; Us : Natural) is
      pragma Unreferenced (D, Us);
   begin
      null;
   end Step_Delay_Us;

   procedure Step_Toggle_LED (D : in out Chip_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Toggle_LED;

end Adaflight.OSD_Chip_Steps;
