package body Adaflight.Flash_Bus_Steps with SPARK_Mode is

   procedure Step_Read_Write (D : in out Flash_Line; Tx : Byte_Array; Rx : out Byte_Array) is
      pragma Unreferenced (D, Tx);
   begin
      Rx := (others => 0);
   end Step_Read_Write;

   procedure Step_Write (D : in out Flash_Line; Tx : Byte_Array) is
      pragma Unreferenced (D, Tx);
   begin
      null;
   end Step_Write;

   procedure Step_Run
     (D : in out Flash_Line; F : in out Device; Q : Sequence; First : Segment_Index; Data_1 : Byte_Array;
      Data_2 : Byte_Array)
   is
      pragma Unreferenced (D, F, Q, First, Data_1, Data_2);
   begin
      null;
   end Step_Run;

   procedure Step_Run_Read
     (D : in out Flash_Line; F : in out Device; Q : Sequence; First : Segment_Index; Received : out Byte_Array)
   is
      pragma Unreferenced (D, F, Q, First);
   begin
      Received := (others => 0);
   end Step_Run_Read;

   procedure Step_Wait (D : in out Flash_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   function Step_Uses_DMA (D : Flash_Line) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Step_Uses_DMA;

   procedure Step_Bus_Busy (D : in out Flash_Line; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Step_Bus_Busy;

   procedure Step_Divider (D : in out Flash_Line; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Hz);
   begin
      Divisor := 1;
   end Step_Divider;

   procedure Step_Set_Divisor (D : in out Flash_Line; Divisor : Interfaces.Unsigned_16) is
      pragma Unreferenced (D, Divisor);
   begin
      null;
   end Step_Set_Divisor;

end Adaflight.Flash_Bus_Steps;
