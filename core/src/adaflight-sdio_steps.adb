package body Adaflight.SDIO_Steps with SPARK_Mode is

   procedure Step_Init_Detect_Pin (D : in out Controller) is
      pragma Unreferenced (D);
   begin
      null;
   end Step_Init_Detect_Pin;

   procedure Step_Read_Detect_Pin (D : in out Controller; High : out Boolean) is
      pragma Unreferenced (D);
   begin
      High := True;
   end Step_Read_Detect_Pin;

   procedure Step_Find_DMA (D : in out Controller; Identifier : out Natural) is
      pragma Unreferenced (D);
   begin
      Identifier := 1;
   end Step_Find_DMA;

   function Step_Cache_Writes (D : Controller) return Boolean is
      pragma Unreferenced (D);
   begin
      return True;
   end Step_Cache_Writes;

   procedure Step_Init_Hardware (D : in out Controller; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      OK := True;
   end Step_Init_Hardware;

   procedure Step_Init_Card (D : in out Controller; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      OK := True;
   end Step_Init_Card;

   procedure Step_Check_Ready (D : in out Controller; Ready : out Boolean) is
      pragma Unreferenced (D);
   begin
      Ready := True;
   end Step_Check_Ready;

   procedure Step_Card_Info (D : in out Controller; Info : out SD_Card_Types.Card_Information; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      Info := (others => <>);
      OK := True;
   end Step_Card_Info;

   procedure Step_Read_Pending (D : in out Controller; Pending : out Boolean) is
      pragma Unreferenced (D);
   begin
      Pending := False;
   end Step_Read_Pending;

   procedure Step_Write_Pending (D : in out Controller; Pending : out Boolean) is
      pragma Unreferenced (D);
   begin
      Pending := False;
   end Step_Write_Pending;

   procedure Step_Start_Read (D : in out Controller; Index : Interfaces.Unsigned_32; OK : out Boolean) is
      pragma Unreferenced (D, Index);
   begin
      OK := True;
   end Step_Start_Read;

   procedure Step_Fetch_Block (D : in out Controller; Index : Interfaces.Unsigned_32; Data : out SD_Card_Bus.Block) is
      pragma Unreferenced (D, Index);
   begin
      Data := (others => 0);
   end Step_Fetch_Block;

   procedure Step_Start_Write
     (D : in out Controller; Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean)
   is
      pragma Unreferenced (D, Index, Data);
   begin
      OK := True;
   end Step_Start_Write;

   procedure Step_Millis (D : in out Controller; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := 0;
   end Step_Millis;

   procedure Step_Complete
     (D             : in out Controller;
      Write         : Boolean;
      Index         : Interfaces.Unsigned_32;
      Has_Buffer    : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Data          : SD_Card_Bus.Block)
   is
      pragma Unreferenced (D, Write, Index, Has_Buffer, Callback_Data, Data);
   begin
      null;
   end Step_Complete;

end Adaflight.SDIO_Steps;
