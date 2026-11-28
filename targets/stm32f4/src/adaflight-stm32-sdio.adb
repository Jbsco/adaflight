package body Adaflight.STM32.SDIO is
   procedure Init_Hardware (OK : out Boolean) is
   begin
      OK := False;
   end Init_Hardware;

   procedure Init_Card (OK : out Boolean) is
   begin
      OK := False;
   end Init_Card;

   procedure Check_Ready (Ready : out Boolean) is
   begin
      Ready := False;
   end Check_Ready;

   procedure Card_Info (Info : out Adaflight.SD_Card_Types.Card_Information; OK : out Boolean) is
   begin
      Info := (others => <>);
      OK := False;
   end Card_Info;

   function Read_Pending return Boolean is (False);
   function Write_Pending return Boolean is (False);

   procedure Start_Read (Index : Interfaces.Unsigned_32; OK : out Boolean) is
      pragma Unreferenced (Index);
   begin
      OK := False;
   end Start_Read;

   procedure Fetch_Block (Data : out Adaflight.SD_Card_Bus.Block) is
   begin
      Data := (others => 0);
   end Fetch_Block;

   procedure Start_Write (Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean) is
      pragma Unreferenced (Index, Data);
   begin
      OK := False;
   end Start_Write;
end Adaflight.STM32.SDIO;
