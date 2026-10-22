package body Adaflight.CLI_Board_Steps with SPARK_Mode is

   procedure DShot_Write (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8) is
      pragma Unreferenced (Index, Motors, Command);
   begin
      null;
   end DShot_Write;

   procedure Motors_Disable is
   begin
      null;
   end Motors_Disable;

   procedure Motors_Enable is
   begin
      null;
   end Motors_Enable;

   procedure ESC_Read_Start is
   begin
      null;
   end ESC_Read_Start;

   procedure ESC_Read_Bytes (F : out ESC_Info.Frame; Count : out Natural) is
   begin
      F := (others => 0);
      Count := 0;
   end ESC_Read_Bytes;

   procedure Delay_Ms (Ms : Natural) is
      pragma Unreferenced (Ms);
   begin
      null;
   end Delay_Ms;

end Adaflight.CLI_Board_Steps;
