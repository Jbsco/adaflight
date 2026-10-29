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

   procedure ESC_Passthrough (Index : Natural; Protocol : Interfaces.Unsigned_8; Started : out Boolean) is
      pragma Unreferenced (Index, Protocol);
   begin
      Started := False;
   end ESC_Passthrough;

   procedure GPS_Passthrough (Started : out Boolean) is
   begin
      Started := False;
   end GPS_Passthrough;

   procedure Gyro_Read_Register (Gyro : Natural; Register : Interfaces.Unsigned_8; Value : out Interfaces.Unsigned_8)
   is
      pragma Unreferenced (Gyro, Register);
   begin
      Value := 0;
   end Gyro_Read_Register;

   procedure Flash_Erase_Completely is
   begin
      null;
   end Flash_Erase_Completely;

   procedure Flash_Ready (Ready : out Boolean) is
   begin
      Ready := True;
   end Flash_Ready;

   procedure Flash_Erase_Async is
   begin
      null;
   end Flash_Erase_Async;

   procedure Flash_Verify (OK : out Boolean) is
   begin
      OK := False;
   end Flash_Verify;

   procedure Flash_Seek (Address : Interfaces.Unsigned_32) is
      pragma Unreferenced (Address);
   begin
      null;
   end Flash_Seek;

   procedure Flash_Write (Data : String) is
      pragma Unreferenced (Data);
   begin
      null;
   end Flash_Write;

   procedure Flash_Flush is
   begin
      null;
   end Flash_Flush;

   procedure Flash_Read (Address : Interfaces.Unsigned_32; Length : Natural; Data : out String; Count : out Natural) is
      pragma Unreferenced (Address, Length);
   begin
      Data := (others => ' ');
      Count := 0;
   end Flash_Read;

   procedure Port_State
     (Id : Interfaces.Integer_32; Open : out Boolean; Baud : out Interfaces.Unsigned_32;
      Mode : out Interfaces.Unsigned_8; Options : out Interfaces.Unsigned_32; Callback : out Boolean)
   is
      pragma Unreferenced (Id);
   begin
      Open := False;
      Baud := 0;
      Mode := 0;
      Options := 0;
      Callback := False;
   end Port_State;

   procedure Port_Open
     (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32; Mode : Interfaces.Unsigned_8;
      Options : Interfaces.Unsigned_32; Opened : out Boolean)
   is
      pragma Unreferenced (Id, Baud, Mode, Options);
   begin
      Opened := False;
   end Port_Open;

end Adaflight.CLI_Board_Steps;
