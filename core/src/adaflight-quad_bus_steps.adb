package body Adaflight.Quad_Bus_Steps with SPARK_Mode is

   procedure Step_Transmit (D : in out Quad_Line; Instruction : Byte; Data : Byte_Array) is
      pragma Unreferenced (D, Instruction, Data);
   begin
      null;
   end Step_Transmit;

   procedure Step_Receive (D : in out Quad_Line; Instruction : Byte; Data : out Byte_Array) is
      pragma Unreferenced (D, Instruction);
   begin
      Data := (others => 0);
   end Step_Receive;

   procedure Step_Instruction_With_Address
     (D : in out Quad_Line; Instruction : Byte; Address : Interfaces.Unsigned_32)
   is
      pragma Unreferenced (D, Instruction, Address);
   begin
      null;
   end Step_Instruction_With_Address;

   procedure Step_Receive_With_Address
     (D           : in out Quad_Line;
      Instruction : Byte;
      Dummy       : Natural;
      Address     : Interfaces.Unsigned_32;
      Data        : out Byte_Array;
      OK          : out Boolean)
   is
      pragma Unreferenced (D, Instruction, Dummy, Address);
   begin
      Data := (others => 0);
      OK := True;
   end Step_Receive_With_Address;

   procedure Step_Run
     (D      : in out Quad_Line;
      F      : in out Flash_Device.Device;
      Q      : Flash_Device.Sequence;
      First  : Flash_Device.Segment_Index;
      Data_1 : Byte_Array;
      Data_2 : Byte_Array)
   is
      pragma Unreferenced (D, F, Q, First, Data_1, Data_2);
   begin
      null;
   end Step_Run;

   procedure Step_Wait (D : in out Quad_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   procedure Step_Millis (D : in out Quad_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

   procedure Step_Report_Written (D : in out Quad_Line; Bytes : Interfaces.Unsigned_32) is
      pragma Unreferenced (D, Bytes);
   begin
      null;
   end Step_Report_Written;

end Adaflight.Quad_Bus_Steps;
