with Adaflight.Blackbox_SD;
with Adaflight.FAT_FS;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.SD_Card;
with Adaflight.SD_Card_Bus;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.RTC;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.SD is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.FAT.Filesystem_State;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   package GPIO renames Adaflight.STM32.GPIO;
   package SPI renames Adaflight.STM32.SPI;
   package Types renames Adaflight.SD_Card_Types;

   --  The card's SPI device: its bus, its select and detect pins, the
   --  divisor its transfers take, whether the select pin is low, and the
   --  completion the driver reported in its last poll, delivered to the file
   --  system once the poll returns with the block.
   type Card_Bus is record
      Bus         : SPI.Bus := SPI.SPI2;
      CS          : Pin := (Port_A, 0);
      Has_CS      : Boolean := False;
      Detect      : Pin := (Port_A, 0);
      Has_Detect  : Boolean := False;
      Divisor     : Unsigned_16 := 256;
      Selected    : Boolean := False;
      Done        : Boolean := False;
      Done_Write  : Boolean := False;
      Done_OK     : Boolean := False;
      Done_Index  : Unsigned_32 := 0;
      Done_Buffer : Unsigned_32 := 0;
   end record;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Byte) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   procedure Preinit_CS (D : in out Card_Bus; Tag : Byte) is
   begin
      if not Tagged_Pin (Tag) then
         return;
      end if;
      D.CS := Pin_Of (Tag);
      D.Has_CS := True;
      GPIO.Enable_Port (D.CS.Port);
      GPIO.Set_Output (D.CS);
      GPIO.Set_High (D.CS);
   end Preinit_CS;

   procedure Init_Detect_Pin (D : in out Card_Bus) is
   begin
      if D.Has_Detect then
         GPIO.Enable_Port (D.Detect.Port);
         GPIO.Set_Input (D.Detect, GPIO.Up);
      end if;
   end Init_Detect_Pin;

   procedure Read_Detect_Pin (D : in out Card_Bus; High : out Boolean) is
   begin
      High := D.Has_Detect and then GPIO.Is_High (D.Detect);
   end Read_Detect_Pin;

   procedure Attach_Bus (D : in out Card_Bus; Instance : Byte) is
   begin
      if Instance in 1 .. 3 then
         D.Bus := SPI.Bus'Val (Instance - 1);
      end if;
   end Attach_Bus;

   procedure Prepare_CS (D : in out Card_Bus) is
   begin
      if D.Has_CS then
         GPIO.Enable_Port (D.CS.Port);
         GPIO.Set_Output (D.CS);
         GPIO.Set_High (D.CS);
      end if;
   end Prepare_CS;

   procedure Configure_CS (D : in out Card_Bus) is
   begin
      Prepare_CS (D);
   end Configure_CS;

   procedure CS_High (D : in out Card_Bus) is
   begin
      if D.Has_CS then
         GPIO.Set_High (D.CS);
      end if;
      D.Selected := False;
   end CS_High;

   procedure Divider (D : in out Card_Bus; Hz : Unsigned_32; Divisor : out Unsigned_16) is
      pragma Unreferenced (D);
   begin
      Divisor := SPI.Divider (Hz);
   end Divider;

   procedure Set_Divisor (D : in out Card_Bus; Divisor : Unsigned_16) is
   begin
      D.Divisor := Divisor;
      SPI.Set_Divisor (D.Bus, Divisor);
   end Set_Divisor;

   procedure Delay_Ms (D : in out Card_Bus; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Ms (Ms);
   end Delay_Ms;

   procedure Delay_Us (D : in out Card_Bus; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Us (Us);
   end Delay_Us;

   procedure Millis (D : in out Card_Bus; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Adaflight.STM32.Time.Millis;
   end Millis;

   procedure Select_Card (D : in out Card_Bus) is
   begin
      if D.Has_CS then
         GPIO.Set_Low (D.CS);
      end if;
      D.Selected := True;
   end Select_Card;

   --  A sequence selects the card at its first segment and after each
   --  segment that negated the select pin.
   procedure Start_Sequence (D : in out Card_Bus) is
   begin
      SPI.Set_Divisor (D.Bus, D.Divisor);
      Select_Card (D);
   end Start_Sequence;

   procedure Segment
     (D       : in out Card_Bus;
      Kind    : Adaflight.SD_Card_Bus.Segment_Kind;
      Negate  : Boolean;
      Length  : Positive;
      Tx      : Byte_Array;
      Rx      : in out Byte_Array;
      Receive : Boolean)
   is
      pragma Unreferenced (Kind);
      Sent : Byte_Array (0 .. Length - 1) := (others => 16#FF#);
      Got  : Byte_Array (0 .. Length - 1);
   begin
      if Tx'Length > 0 then
         Sent := Tx (Tx'First .. Tx'First + Length - 1);
      end if;
      if not D.Selected then
         Select_Card (D);
      end if;
      SPI.Transfer (D.Bus, Sent, Got);
      if Receive then
         Rx (Rx'First .. Rx'First + Length - 1) := Got;
      end if;
      if Negate then
         CS_High (D);
      end if;
   end Segment;

   procedure Wait (D : in out Card_Bus) is null;

   procedure Release (D : in out Card_Bus) is
   begin
      CS_High (D);
   end Release;

   procedure Bus_Busy (D : in out Card_Bus; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Bus_Busy;

   function Uses_DMA (D : Card_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Uses_DMA;

   procedure Read_Write (D : in out Card_Bus; Tx : Byte_Array) is
      Got : Byte_Array (Tx'Range);
   begin
      if not D.Selected then
         Select_Card (D);
      end if;
      SPI.Transfer (D.Bus, Tx, Got);
   end Read_Write;

   procedure Complete
     (D : in out Card_Bus; Write : Boolean; Index : Unsigned_32; Has_Buffer : Boolean; Data : Unsigned_32) is
   begin
      D.Done := True;
      D.Done_Write := Write;
      D.Done_OK := Has_Buffer;
      D.Done_Index := Index;
      D.Done_Buffer := Data;
   end Complete;

   package Card is new Adaflight.SD_Card
     (SPI_Device      => Card_Bus,
      Preinit_CS      => Preinit_CS,
      Init_Detect_Pin => Init_Detect_Pin,
      Read_Detect_Pin => Read_Detect_Pin,
      Attach_Bus      => Attach_Bus,
      Prepare_CS      => Prepare_CS,
      Configure_CS    => Configure_CS,
      CS_High         => CS_High,
      Divider         => Divider,
      Set_Divisor     => Set_Divisor,
      Delay_Ms        => Delay_Ms,
      Delay_Us        => Delay_Us,
      Millis          => Millis,
      Start_Sequence  => Start_Sequence,
      Segment         => Segment,
      Wait            => Wait,
      Release         => Release,
      Bus_Busy        => Bus_Busy,
      Uses_DMA        => Uses_DMA,
      Read_Write      => Read_Write,
      Complete        => Complete);

   --  The file system's card: the device and the driver's card.
   type Media is record
      Dev : Card_Bus;
      S   : Card.Card;
   end record;

   procedure FS_Read_Block
     (M : in out Media; Sector : Unsigned_32; Buffer : Adaflight.FAT.Cache_Index; Accepted : out Boolean) is
   begin
      Card.Read_Block (M.Dev, M.S, Sector, True, Unsigned_32 (Buffer), Accepted);
   end FS_Read_Block;

   procedure FS_Write_Block
     (M      : in out Media;
      Sector : Unsigned_32;
      Buffer : Adaflight.FAT.Cache_Index;
      Data   : Adaflight.FAT.Sector_Bytes;
      Status : out Adaflight.FAT.Card_Status)
   is
      Block  : Adaflight.SD_Card_Bus.Block;
      Result : Types.Operation_Status;
   begin
      for K in Block'Range loop
         Block (K) := Data (K);
      end loop;
      Card.Write_Block (M.Dev, M.S, Sector, Block, True, Unsigned_32 (Buffer), Result);
      Status := Adaflight.FAT.Card_Status'Val (Types.Operation_Status'Pos (Result));
   end FS_Write_Block;

   procedure FS_Begin_Write_Blocks (M : in out Media; Sector : Unsigned_32; Count : Unsigned_16) is
      Result : Types.Operation_Status;
   begin
      Card.Begin_Write_Blocks (M.Dev, M.S, Sector, Unsigned_32 (Count), Result);
   end FS_Begin_Write_Blocks;

   --  New entries carry the local time once the clock is set.
   procedure FS_Read_Clock (M : in out Media; Valid : out Boolean; Local : out Adaflight.FAT.Clock_Reading) is
      pragma Unreferenced (M);
   begin
      Adaflight.STM32.RTC.Local_Now (Valid, Local);
   end FS_Read_Clock;

   package FS_Ops is new Adaflight.FAT_FS
     (Card_State         => Media,
      Read_Block         => FS_Read_Block,
      Write_Block        => FS_Write_Block,
      Begin_Write_Blocks => FS_Begin_Write_Blocks,
      Read_Clock         => FS_Read_Clock);

   package Log is new Adaflight.Blackbox_SD (FS_Ops);

   Setup    : Types.Config;
   M        : Media with Linker_Section => ".bss.ccm";
   FS       : Adaflight.FAT.File_System with Linker_Section => ".bss.ccm";
   L        : Log.SD_Log;
   Ready    : Boolean := False;
   Present  : Boolean := False;
   Started  : Boolean := False;

   function Config_Of (C : Adaflight.Config_Groups.Configuration) return Types.Config is
     (Device          => (if C.Sdcard_Config.Device in 1 .. 3 then Byte (C.Sdcard_Config.Device) else 0),
      Detect_Tag      => C.Sdcard_Config.Card_Detect_Tag,
      CS_Tag          => C.Sdcard_Config.Chip_Select_Tag,
      Detect_Inverted => C.Sdcard_Config.Card_Detect_Inverted /= 0,
      Mode            => C.Sdcard_Config.Mode);

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is
   begin
      Setup := Config_Of (C);
      if Tagged_Pin (Setup.Detect_Tag) then
         M.Dev.Detect := Pin_Of (Setup.Detect_Tag);
         M.Dev.Has_Detect := True;
      end if;
      if Setup.Mode = Types.Mode_SPI then
         Card.Preinit (M.Dev, Setup);
      end if;
   end Preinit;

   --  The card driver then the file system, as the reference starts them
   --  after the SPI buses; the driver takes only the SPI mode here.
   procedure Init (C : Adaflight.Config_Groups.Configuration) is
   begin
      Preinit (C);
      Started := Setup.Mode = Types.Mode_SPI;
      if not Started then
         Setup.Mode := Types.Mode_Off;
      end if;
      Card.Init (M.Dev, M.S, Setup);
      Adaflight.FAT.Init (FS);
      Card.Is_Inserted (M.Dev, M.S, Present);
   end Init;

   procedure Poll is
   begin
      Card.Poll (M.Dev, M.S, Ready);
      if M.Dev.Done then
         M.Dev.Done := False;
         if M.Dev.Done_Write then
            Adaflight.FAT.Write_Complete
              (FS, Adaflight.FAT.Cache_Index (M.Dev.Done_Buffer), M.Dev.Done_Index, M.Dev.Done_OK);
         else
            declare
               Data : Adaflight.FAT.Sector_Bytes;
            begin
               for K in Data'Range loop
                  Data (K) := M.S.Data (K);
               end loop;
               Adaflight.FAT.Read_Complete
                 (FS, Adaflight.FAT.Cache_Index (M.Dev.Done_Buffer), M.Dev.Done_Index, Data, M.Dev.Done_OK);
            end;
         end if;
      end if;
      Log.Poll (L, FS, M, Ready);
      Card.Is_Inserted (M.Dev, M.S, Present);
   end Poll;

   function Configured return Boolean is (Started);

   function Inserted return Boolean is (Present);

   function Summary return Adaflight.MSP_Hardware_Out.SD_Card_Values is
     (Built       => True,
      Configured  => Started,
      Inserted    => Present,
      Functional  => Card.Is_Functional (M.S),
      State       =>
        (case FS.State is
            when Adaflight.FAT.Unknown        => Adaflight.MSP_Hardware_Out.Unknown,
            when Adaflight.FAT.Fatal          => Adaflight.MSP_Hardware_Out.Fatal,
            when Adaflight.FAT.Initialization => Adaflight.MSP_Hardware_Out.Initialization,
            when Adaflight.FAT.Ready          => Adaflight.MSP_Hardware_Out.Ready),
      Initialized => Card.Is_Initialized (M.S),
      Last_Error  => Interfaces.Unsigned_8 (Adaflight.FAT.Error_Kind'Pos (FS.Last_Error)),
      Free_Bytes  => Adaflight.FAT.Contiguous_Free_Space (FS),
      Block_Count => Card.Get_Metadata (M.S).Num_Blocks);

   function Card_Info return Types.Metadata is (Card.Get_Metadata (M.S));

   function File_System_State return Adaflight.FAT.Filesystem_State is (FS.State);

   function Last_Error return Adaflight.FAT.Error_Kind is (FS.Last_Error);

   function Log_Open_OK return Boolean is (Log.Device_Open (FS));

   function Log_Full return Boolean is (Log.Device_Full (FS));

   function Log_Free_Space return Natural is
     (Natural (Unsigned_32'Min (Adaflight.FAT.Free_Buffer_Space (FS), Unsigned_32 (Natural'Last))));

   procedure Log_Begin (Done : out Boolean) is
   begin
      Log.Begin_Log (L, FS, M, Done);
   end Log_Begin;

   procedure Log_End (Retain : Boolean; Done : out Boolean) is
   begin
      Log.End_Log (L, FS, M, Retain, Done);
   end Log_End;

   procedure Log_Flush (Done : out Boolean) is
   begin
      Log.Flush_Force (FS, M, Done);
   end Log_Flush;

   procedure Log_Flush_Complete (Done : out Boolean) is
   begin
      Log.Flush_Force_Complete (FS, M, Done);
   end Log_Flush_Complete;

   procedure Log_Write (Data : Byte_Array) is
      Text   : Adaflight.FAT.Data_Bytes (0 .. Data'Length - 1);
      Length : Natural;
   begin
      for K in Text'Range loop
         Text (K) := Data (Data'First + K);
      end loop;
      Log.Write_Text (L, FS, M, Text, Length);
   end Log_Write;

   function Log_Number return Interfaces.Integer_32 is (Log.Log_Number (L));
end Adaflight.STM32.SD;
