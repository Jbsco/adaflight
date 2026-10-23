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

   procedure Step_Send (D : in out Flash_Line; Tx : Byte_Array) is
      pragma Unreferenced (D, Tx);
   begin
      null;
   end Step_Send;

   procedure Step_Exchange (D : in out Flash_Line; Tx : Byte_Array; Rx : out Byte_Array) is
      pragma Unreferenced (D, Tx);
   begin
      Rx := (others => 0);
   end Step_Exchange;

   procedure Step_Run_One
     (D : in out Flash_Line; F : in out Device; Q : Sequence; First : Segment_Index; Data : Byte_Array)
   is
      pragma Unreferenced (D, F, Q, First, Data);
   begin
      null;
   end Step_Run_One;

   procedure Step_Wait (D : in out Flash_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Wait;

   procedure Step_Millis (D : in out Flash_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

   procedure Step_Report_Written (D : in out Flash_Line; Bytes : Interfaces.Unsigned_32) is
      pragma Unreferenced (D, Bytes);
   begin
      null;
   end Step_Report_Written;

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

   procedure Step_Preinit_CS (D : in out Flash_Line; Tag : Byte) is
      pragma Unreferenced (D, Tag);
   begin
      null;
   end Step_Preinit_CS;

   procedure Step_CS_Free (D : in out Flash_Line; Free : out Boolean) is
      pragma Unreferenced (D);
   begin
      Free := True;
   end Step_CS_Free;

   procedure Step_Attach_Bus (D : in out Flash_Line; Instance : Byte; OK : out Boolean) is
      pragma Unreferenced (D, Instance);
   begin
      OK := True;
   end Step_Attach_Bus;

   procedure Step_Prepare_CS (D : in out Flash_Line) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Prepare_CS;

   procedure Step_Delay_Ms (D : in out Flash_Line; Ms : Natural) is
      pragma Unreferenced (D, Ms);
   begin
      null;
   end Step_Delay_Ms;

   procedure Step_Read_Id (D : in out Flash_Line; Response : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      Response := (others => 0);
   end Step_Read_Id;

end Adaflight.Flash_Bus_Steps;
