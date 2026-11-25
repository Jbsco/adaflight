package body Adaflight.A7105 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   FIFO_Data           : constant Byte := 16#05#;
   ID_Data             : constant Byte := 16#06#;
   Read_Bit            : constant Byte := 16#40#;
   Reset_Write_Pointer : constant Byte := 16#E0#;
   Reset_Read_Pointer  : constant Byte := 16#F0#;

   procedure Read_Register (D : in out Radio_Device; Address : Register; Value : out Byte) is
   begin
      Bus_Read_Command (D, Address or Read_Bit, Value);
   end Read_Register;

   procedure Write_Register (D : in out Radio_Device; Address : Register; Value : Byte) is
   begin
      Bus_Write_Command (D, Address, Value);
   end Write_Register;

   procedure Strobe (D : in out Radio_Device; Command : Byte) is
   begin
      Bus_Write_Byte (D, Command);
   end Strobe;

   procedure Write_ID (D : in out Radio_Device; Id : Interfaces.Unsigned_32) is
      Data : constant Byte_Array (0 .. 3) :=
        (Byte (Interfaces.Shift_Right (Id, 24)), Byte (Interfaces.Shift_Right (Id, 16) and 16#FF#),
         Byte (Interfaces.Shift_Right (Id, 8) and 16#FF#), Byte (Id and 16#FF#));
   begin
      Bus_Write_Command_Multi (D, ID_Data, Data);
   end Write_ID;

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array) is
   begin
      Strobe (D, Reset_Read_Pointer);
      Bus_Read_Command_Multi (D, FIFO_Data or Read_Bit, Data);
   end Read_FIFO;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array) is
   begin
      Strobe (D, Reset_Write_Pointer);
      Bus_Write_Command_Multi (D, FIFO_Data, Data);
   end Write_FIFO;

end Adaflight.A7105;
