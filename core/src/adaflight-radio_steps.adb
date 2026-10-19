package body Adaflight.Radio_Steps with SPARK_Mode is

   procedure Step_Read_Busy (D : in out Radio_Line; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Step_Read_Busy;

   procedure Step_Micros (D : in out Radio_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 1;
   end Step_Micros;

   procedure Step_Exti_Configured (D : in out Radio_Line; Configured : out Boolean) is
      pragma Unreferenced (D);
   begin
      Configured := True;
   end Step_Exti_Configured;

   procedure Step_Set_Normal_Speed (D : in out Radio_Line; Hz : Interfaces.Unsigned_32) is
      pragma Unreferenced (D, Hz);
   begin
      null;
   end Step_Set_Normal_Speed;

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

   procedure Step_Bus_Transfer (D : in out Radio_Line; Data : in out Byte_Array) is
      pragma Unreferenced (D, Data);
   begin
      null;
   end Step_Bus_Transfer;

   procedure Step_Bus_Write (D : in out Radio_Line; Data : Byte_Array) is
      pragma Unreferenced (D, Data);
   begin
      null;
   end Step_Bus_Write;

   procedure Step_Run_Transfer (D : in out Radio_Line; Step : Byte; Data : in out Byte_Array) is
      pragma Unreferenced (D, Step, Data);
   begin
      null;
   end Step_Run_Transfer;

   procedure Step_Run_Write (D : in out Radio_Line; Step : Byte; Data : Byte_Array) is
      pragma Unreferenced (D, Step, Data);
   begin
      null;
   end Step_Run_Write;

   procedure Step_Run_Pair (D : in out Radio_Line; Step : Byte; Head : Byte_Array; Tail : in out Byte_Array) is
      pragma Unreferenced (D, Step, Head, Tail);
   begin
      null;
   end Step_Run_Pair;

   procedure Step_Run_Pair_Write (D : in out Radio_Line; Step : Byte; Head : Byte_Array; Tail : Byte_Array) is
      pragma Unreferenced (D, Step, Head, Tail);
   begin
      null;
   end Step_Run_Pair_Write;

   procedure Step_Answer (D : in out Radio_Line; Answer : out Boolean) is
      pragma Unreferenced (D);
   begin
      Answer := False;
   end Step_Answer;

   procedure Step_Current_Frequency (D : in out Radio_Line; Frequency : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Frequency := 0;
   end Step_Current_Frequency;

   procedure Step_Telemetry_Buffer (D : in out Radio_Line; Data : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      Data := (others => 0);
   end Step_Telemetry_Buffer;

   procedure Step_Process_Packet
     (D : in out Radio_Line; Payload : Byte_Array; Timestamp : Interfaces.Unsigned_32; Status : out Byte)
   is
      pragma Unreferenced (D, Payload, Timestamp);
   begin
      Status := 0;
   end Step_Process_Packet;

   procedure Step_Set_Packet_Status (D : in out Radio_Line; Status : Byte) is
      pragma Unreferenced (D, Status);
   begin
      null;
   end Step_Set_Packet_Status;

end Adaflight.Radio_Steps;
