package body Adaflight.STM32.SD_SDIO is
   procedure Init (Setup : Adaflight.SD_Card_Types.Config) is null;

   procedure Is_Inserted (Inserted : out Boolean) is
   begin
      Inserted := False;
   end Is_Inserted;

   procedure Poll (Card_Ready : out Boolean) is
   begin
      Card_Ready := False;
   end Poll;

   procedure Read_Block
     (Index : Interfaces.Unsigned_32; Has_Callback : Boolean; Callback_Data : Interfaces.Unsigned_32;
      Accepted : out Boolean) is
   begin
      Accepted := False;
   end Read_Block;

   procedure Write_Block
     (Index         : Interfaces.Unsigned_32;
      Data          : Adaflight.SD_Card_Bus.Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Adaflight.SD_Card_Types.Operation_Status) is
   begin
      Status := Adaflight.SD_Card_Types.Failure;
   end Write_Block;

   procedure Begin_Write_Blocks
     (Index : Interfaces.Unsigned_32; Count : Interfaces.Unsigned_32;
      Status : out Adaflight.SD_Card_Types.Operation_Status) is
   begin
      Status := Adaflight.SD_Card_Types.Failure;
   end Begin_Write_Blocks;

   function Is_Functional return Boolean is (False);
   function Is_Initialized return Boolean is (False);
   function Metadata return Adaflight.SD_Card_Types.Metadata is (others => <>);
   function Data return Adaflight.SD_Card_Bus.Block is (others => 0);

   procedure Take_Completion (C : out Completion) is
   begin
      C := (others => <>);
   end Take_Completion;
end Adaflight.STM32.SD_SDIO;
