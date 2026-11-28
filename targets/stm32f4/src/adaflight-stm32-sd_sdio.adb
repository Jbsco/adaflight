with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.SD_Card_SDIO;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SDIO;
with Adaflight.STM32.Time;
package body Adaflight.STM32.SD_SDIO is
   use type Interfaces.Unsigned_32;
   use type Adaflight.Bytes.Byte;
   package GPIO renames Adaflight.STM32.GPIO;
   package Types renames Adaflight.SD_Card_Types;

   type Device is record
      Detect     : Pin := (Port_A, 0);
      Has_Detect : Boolean := False;
      Done       : Completion;
   end record;

   procedure Init_Detect_Pin (D : in out Device) is
   begin
      if D.Has_Detect then
         GPIO.Enable_Port (D.Detect.Port);
         GPIO.Set_Input (D.Detect, GPIO.Up);
      end if;
   end Init_Detect_Pin;

   procedure Read_Detect_Pin (D : in out Device; High : out Boolean) is
   begin
      High := D.Has_Detect and then GPIO.Is_High (D.Detect);
   end Read_Detect_Pin;

   --  The controller moves its blocks with its own DMA.
   procedure Find_DMA (D : in out Device; Identifier : out Natural) is
      pragma Unreferenced (D);
   begin
      Identifier := 1;
   end Find_DMA;

   function Cache_Writes (D : Device) return Boolean is (False);

   procedure Init_Hardware (D : in out Device; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      SDIO.Init_Hardware (OK);
   end Init_Hardware;

   procedure Init_Card (D : in out Device; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      SDIO.Init_Card (OK);
   end Init_Card;

   procedure Check_Ready (D : in out Device; Ready : out Boolean) is
      pragma Unreferenced (D);
   begin
      SDIO.Check_Ready (Ready);
   end Check_Ready;

   procedure Card_Info (D : in out Device; Info : out Types.Card_Information; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      SDIO.Card_Info (Info, OK);
   end Card_Info;

   procedure Read_Pending (D : in out Device; Pending : out Boolean) is
      pragma Unreferenced (D);
   begin
      Pending := SDIO.Read_Pending;
   end Read_Pending;

   procedure Write_Pending (D : in out Device; Pending : out Boolean) is
      pragma Unreferenced (D);
   begin
      Pending := SDIO.Write_Pending;
   end Write_Pending;

   procedure Start_Read (D : in out Device; Index : Interfaces.Unsigned_32; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      SDIO.Start_Read (Index, OK);
   end Start_Read;

   procedure Fetch_Block (D : in out Device; Index : Interfaces.Unsigned_32; Data : out Adaflight.SD_Card_Bus.Block) is
      pragma Unreferenced (D, Index);
   begin
      SDIO.Fetch_Block (Data);
   end Fetch_Block;

   procedure Start_Write (D : in out Device; Index : Interfaces.Unsigned_32; Data : Byte_Array; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      if Data'Length mod 512 = 0 and then Data'Length in 512 .. SDIO.Max_Write_Blocks * 512 then
         SDIO.Start_Write (Index, Data, OK);
      else
         OK := False;
      end if;
   end Start_Write;

   procedure Millis (D : in out Device; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Adaflight.STM32.Time.Millis;
   end Millis;

   procedure Complete
     (D             : in out Device;
      Write         : Boolean;
      Index         : Interfaces.Unsigned_32;
      Has_Buffer    : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Data          : Adaflight.SD_Card_Bus.Block)
   is
      pragma Unreferenced (Data);
   begin
      D.Done := (Done => True, Write => Write, OK => Has_Buffer, Index => Index, Buffer => Callback_Data);
   end Complete;

   package Card is new Adaflight.SD_Card_SDIO
     (SDIO_Device     => Device,
      Init_Detect_Pin => Init_Detect_Pin,
      Read_Detect_Pin => Read_Detect_Pin,
      Find_DMA        => Find_DMA,
      Cache_Writes    => Cache_Writes,
      Init_Hardware   => Init_Hardware,
      Init_Card       => Init_Card,
      Check_Ready     => Check_Ready,
      Card_Info       => Card_Info,
      Read_Pending    => Read_Pending,
      Write_Pending   => Write_Pending,
      Start_Read      => Start_Read,
      Fetch_Block     => Fetch_Block,
      Start_Write     => Start_Write,
      Millis          => Millis,
      Complete        => Complete);

   Dev : Device;
   S   : Card.Card;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   procedure Init (Setup : Types.Config) is
   begin
      if Tagged_Pin (Setup.Detect_Tag) then
         Dev.Detect := (Port => Port_Name'Val (Natural (Setup.Detect_Tag / 16) - 1),
                        Number => Pin_Number (Setup.Detect_Tag mod 16));
         Dev.Has_Detect := True;
      end if;
      Card.Init (Dev, S, Setup);
   end Init;

   procedure Is_Inserted (Inserted : out Boolean) is
   begin
      Card.Is_Inserted (Dev, S, Inserted);
   end Is_Inserted;

   procedure Poll (Card_Ready : out Boolean) is
   begin
      Card.Poll (Dev, S, Card_Ready);
   end Poll;

   procedure Read_Block
     (Index : Interfaces.Unsigned_32; Has_Callback : Boolean; Callback_Data : Interfaces.Unsigned_32;
      Accepted : out Boolean) is
   begin
      Card.Read_Block (Dev, S, Index, Has_Callback, Callback_Data, Accepted);
   end Read_Block;

   procedure Write_Block
     (Index         : Interfaces.Unsigned_32;
      Data          : Adaflight.SD_Card_Bus.Block;
      Has_Callback  : Boolean;
      Callback_Data : Interfaces.Unsigned_32;
      Status        : out Types.Operation_Status) is
   begin
      Card.Write_Block (Dev, S, Index, Data, Has_Callback, Callback_Data, Status);
   end Write_Block;

   procedure Begin_Write_Blocks
     (Index : Interfaces.Unsigned_32; Count : Interfaces.Unsigned_32; Status : out Types.Operation_Status) is
   begin
      Card.Begin_Write_Blocks (Dev, S, Index, Count, Status);
   end Begin_Write_Blocks;

   function Is_Functional return Boolean is (Card.Is_Functional (S));
   function Is_Initialized return Boolean is (Card.Is_Initialized (S));
   function Metadata return Types.Metadata is (Card.Get_Metadata (S));
   function Data return Adaflight.SD_Card_Bus.Block is (S.Data);

   procedure Take_Completion (C : out Completion) is
   begin
      C := Dev.Done;
      Dev.Done := (others => <>);
   end Take_Completion;
end Adaflight.STM32.SD_SDIO;
