package body Adaflight.DShot_Table_Steps with SPARK_Mode is

   procedure Step_Delay_Us (T : in out Table; Us : Interfaces.Unsigned_32) is
      pragma Unreferenced (T, Us);
   begin
      null;
   end Step_Delay_Us;

   procedure Step_Decode (T : in out Table) is
      pragma Unreferenced (T);
   begin
      null;
   end Step_Decode;

   procedure Step_Request (T : in out Table; Index : Adaflight.DShot_Command.Motor_Index) is
      pragma Unreferenced (T, Index);
   begin
      null;
   end Step_Request;

   procedure Step_Write
     (T : in out Table; Q : Adaflight.DShot_Command.Queue; Index : Adaflight.DShot_Command.Motor_Index;
      Value : Interfaces.Unsigned_16)
   is
      pragma Unreferenced (T, Q, Index, Value);
   begin
      null;
   end Step_Write;

   procedure Step_Complete (T : in out Table; Q : in out Adaflight.DShot_Command.Queue) is
      pragma Unreferenced (T, Q);
   begin
      null;
   end Step_Complete;

end Adaflight.DShot_Table_Steps;
