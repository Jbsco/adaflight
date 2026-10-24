package body Adaflight.Serial_Port_Steps with SPARK_Mode is

   procedure Step_Open_Port
     (D : in out Port_Line; Port : Interfaces.Integer_8; Baud : Interfaces.Unsigned_32; Opened : out Boolean)
   is
      pragma Unreferenced (D, Port, Baud);
   begin
      Opened := False;
   end Step_Open_Port;

   procedure Step_Bytes_Waiting (D : in out Port_Line; Count : out Natural) is
      pragma Unreferenced (D);
   begin
      Count := 0;
   end Step_Bytes_Waiting;

   procedure Step_Read_Byte (D : in out Port_Line; B : out Byte) is
      pragma Unreferenced (D);
   begin
      B := 0;
   end Step_Read_Byte;

   procedure Step_Write_Bytes (D : in out Port_Line; Data : Byte_Array) is
      pragma Unreferenced (D, Data);
   begin
      null;
   end Step_Write_Bytes;

   procedure Step_Millis (D : in out Port_Line; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

end Adaflight.Serial_Port_Steps;
