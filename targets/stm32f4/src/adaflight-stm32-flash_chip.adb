with Adaflight.Board;
with Adaflight.Flash_Device.Layer;
with Adaflight.Flash_Device.M25P16;
with Adaflight.Flash_FS;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Flash_Chip is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   package GPIO renames Adaflight.STM32.GPIO;
   package SPI renames Adaflight.STM32.SPI;
   package FD renames Adaflight.Flash_Device;
   package FS renames Adaflight.Flash_FS;

   --  The chip's SPI device: its bus, its select pin and the divisor its
   --  transfers take, and whether the select pin is low.
   type Chip_Bus is record
      Bus      : SPI.Bus := SPI.SPI3;
      CS       : Pin := (Port_A, 0);
      Has_CS   : Boolean := False;
      Divisor  : Unsigned_16 := 256;
      Selected : Boolean := False;
   end record;

   function Tagged_Pin (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Pin_Of (Tag : Byte) return Pin is
     ((Port => Port_Name'Val (Natural (Tag / 16) - 1), Number => Pin_Number (Tag mod 16)))
     with Pre => Tagged_Pin (Tag);

   procedure Select_Chip (D : in out Chip_Bus) is
   begin
      if D.Has_CS then
         GPIO.Set_Low (D.CS);
      end if;
      D.Selected := True;
   end Select_Chip;

   procedure Deselect (D : in out Chip_Bus) is
   begin
      if D.Has_CS then
         GPIO.Set_High (D.CS);
      end if;
      D.Selected := False;
   end Deselect;

   procedure Read_Write (D : in out Chip_Bus; Tx : Byte_Array; Rx : out Byte_Array) is
   begin
      SPI.Set_Divisor (D.Bus, D.Divisor);
      Select_Chip (D);
      SPI.Transfer (D.Bus, Tx, Rx);
      Deselect (D);
   end Read_Write;

   procedure Write_Bytes (D : in out Chip_Bus; Tx : Byte_Array) is
      Rx : Byte_Array (Tx'Range);
   begin
      Read_Write (D, Tx, Rx);
   end Write_Bytes;

   --  The program the chip ends reports its bytes to the file system.
   procedure Program_Done (Bytes : Unsigned_32);

   --  A segment list as the reference's bus runs it: the select pin low at
   --  the first segment and after each negation, each segment's bytes from
   --  its command or a buffer, idle bytes for a read, the callback after
   --  it, a busy answer repeating the segment and an abort skipping the
   --  rest.
   procedure Run_List
     (D        : in out Chip_Bus;
      F        : in out FD.Device;
      Q        : FD.Sequence;
      First    : FD.Segment_Index;
      Data_1   : Byte_Array;
      Data_2   : Byte_Array;
      Received : in out Byte_Array)
   is
      use type FD.Segment_Index;
      use type FD.Bus_Result;
      use type FD.Payload;
      use type FD.Callback;
      I     : FD.Segment_Index := First;
      Guard : Natural := 0;
   begin
      SPI.Set_Divisor (D.Bus, D.Divisor);
      while Q (I).Length /= 0 and then Guard < 100_000 loop
         Guard := Guard + 1;
         declare
            S      : constant FD.Segment := Q (I);
            Tx     : Byte_Array (0 .. S.Length - 1) := (others => 16#FF#);
            Rx     : Byte_Array (0 .. S.Length - 1);
            R      : FD.Bus_Result := FD.Ready;
            Notify : Boolean;
         begin
            case S.Source is
               when FD.Command =>
                  Tx := S.Bytes (0 .. S.Length - 1);
               when FD.Buffer_1 =>
                  Tx := Data_1 (Data_1'First .. Data_1'First + S.Length - 1);
               when FD.Buffer_2 =>
                  Tx := Data_2 (Data_2'First .. Data_2'First + S.Length - 1);
               when FD.Read_Data | FD.Link =>
                  null;
            end case;
            if not D.Selected then
               Select_Chip (D);
            end if;
            SPI.Transfer (D.Bus, Tx, Rx);
            if S.Source = FD.Read_Data and then Received'Length >= S.Length then
               Received (Received'First .. Received'First + S.Length - 1) := Rx;
            end if;
            if S.Negate_CS then
               Deselect (D);
            end if;
            case S.After is
               when FD.None =>
                  null;
               when FD.Ready_Poll =>
                  FD.Ready_Poll_Done (F, Rx (1), R);
               when FD.Write_Enabled =>
                  FD.Write_Enable_Done (F);
               when FD.Write_Done =>
                  FD.Write_Done (F, Notify);
                  if Notify then
                     Program_Done (F.Bytes_Written);
                  end if;
            end case;
            if R /= FD.Busy then
               if R = FD.Skip_Rest then
                  while I < FD.Segment_Index'Last and then Q (I + 1).Length /= 0 loop
                     I := I + 1;
                  end loop;
               end if;
               exit when I = FD.Segment_Index'Last;
               I := I + 1;
            end if;
         end;
      end loop;
      if D.Selected then
         Deselect (D);
      end if;
   end Run_List;

   procedure Run
     (D : in out Chip_Bus; F : in out FD.Device; Q : FD.Sequence; First : FD.Segment_Index; Data_1 : Byte_Array;
      Data_2 : Byte_Array)
   is
      None : Byte_Array (1 .. 0);
   begin
      Run_List (D, F, Q, First, Data_1, Data_2, None);
   end Run;

   procedure Run_Read
     (D : in out Chip_Bus; F : in out FD.Device; Q : FD.Sequence; First : FD.Segment_Index;
      Received : out Byte_Array)
   is
      None : Byte_Array (1 .. 0);
   begin
      Received := (others => 0);
      Run_List (D, F, Q, First, None, None, Received);
   end Run_Read;

   procedure Wait (D : in out Chip_Bus) is null;

   function Uses_DMA (D : Chip_Bus) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Uses_DMA;

   procedure Bus_Busy (D : in out Chip_Bus; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := False;
   end Bus_Busy;

   procedure Divider (D : in out Chip_Bus; Hz : Unsigned_32; Divisor : out Unsigned_16) is
      pragma Unreferenced (D);
   begin
      Divisor := SPI.Divider (Hz);
   end Divider;

   procedure Set_Divisor (D : in out Chip_Bus; Divisor : Unsigned_16) is
   begin
      D.Divisor := Divisor;
      SPI.Set_Divisor (D.Bus, Divisor);
   end Set_Divisor;

   package Chip is new FD.M25P16
     (SPI_Device  => Chip_Bus,
      Read_Write  => Read_Write,
      Write       => Write_Bytes,
      Run         => Run,
      Run_Read    => Run_Read,
      Wait        => Wait,
      Uses_DMA    => Uses_DMA,
      Bus_Busy    => Bus_Busy,
      Divider     => Divider,
      Set_Divisor => Set_Divisor);

   procedure Preinit_CS (D : in out Chip_Bus; Tag : Byte) is
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

   procedure CS_Free (D : in out Chip_Bus; Free : out Boolean) is
   begin
      Free := D.Has_CS;
   end CS_Free;

   procedure Attach_Bus (D : in out Chip_Bus; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 3 and then SPI.Started (SPI.Bus'Val (Instance - 1));
      if OK then
         D.Bus := SPI.Bus'Val (Instance - 1);
      end if;
   end Attach_Bus;

   procedure Prepare_CS (D : in out Chip_Bus) is
   begin
      if D.Has_CS then
         GPIO.Enable_Port (D.CS.Port);
         GPIO.Set_Output (D.CS);
         GPIO.Set_High (D.CS);
      end if;
   end Prepare_CS;

   procedure Delay_Ms (D : in out Chip_Bus; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Ms (Ms);
   end Delay_Ms;

   --  The identification instruction, then the identification's bytes.
   procedure Read_Id (D : in out Chip_Bus; Response : out Byte_Array) is
      Tx : constant Byte_Array (0 .. Response'Length) := (0 => 16#9F#, others => 16#FF#);
      Rx : Byte_Array (0 .. Response'Length);
   begin
      Read_Write (D, Tx, Rx);
      Response := Rx (1 .. Response'Length);
   end Read_Id;

   package Layer is new FD.Layer
     (SPI_Device            => Chip_Bus,
      Preinit_CS            => Preinit_CS,
      CS_Free               => CS_Free,
      Attach_Bus            => Attach_Bus,
      Prepare_CS            => Prepare_CS,
      Divider               => Divider,
      Set_Divisor           => Set_Divisor,
      Delay_Ms              => Delay_Ms,
      Read_Id               => Read_Id,
      Chip_Identify         => Chip.Identify,
      Chip_Configure        => Chip.Configure,
      Chip_Is_Ready         => Chip.Is_Ready,
      Chip_Wait_For_Ready   => Chip.Wait_For_Ready,
      Chip_Erase_Sector     => Chip.Erase_Sector,
      Chip_Erase_Completely => Chip.Erase_Completely,
      Chip_Program_Begin    => Chip.Page_Program_Begin,
      Chip_Program_Continue => Chip.Page_Program_Continue,
      Chip_Program          => Chip.Page_Program,
      Chip_Read             => Chip.Read_Bytes);

   Dev   : Chip_Bus;
   L     : Layer.Flash;
   State : FS.File_System;
   Setup : Layer.Flash_Config;

   procedure Program_Done (Bytes : Unsigned_32) is
   begin
      FS.Program_Complete (State, FS.Buffer_Count (Unsigned_32'Min (Bytes, FS.Buffer_Size)));
   end Program_Done;

   procedure Device_Ready (Ready : out Boolean) is
   begin
      if L.Have then
         Layer.Is_Ready (Dev, L, Ready);
      else
         Ready := False;
      end if;
   end Device_Ready;

   --  The operations a file system call listed, carried out on the chip in
   --  their order; a read's bytes go to Into from its first index.
   procedure Execute (O : in out FS.Output; Into : in out Byte_Array; Taken : in out Natural) is
   begin
      for K in 1 .. O.Count loop
         declare
            P : FS.Op renames O.Ops (K);
         begin
            case P.Kind is
               when FS.Ready_Check =>
                  null;
               when FS.Ready_Wait =>
                  Layer.Wait_For_Ready (Dev, L);
               when FS.Program =>
                  declare
                     Data : Byte_Array (0 .. P.First + P.Second - 1);
                  begin
                     for J in Data'Range loop
                        Data (J) := O.Data (P.Data_At + J);
                     end loop;
                     Layer.Page_Program (Dev, L, P.Address, Data, Has_Callback => P.Report);
                  end;
               when FS.Erase_Sector =>
                  Layer.Erase_Sector (Dev, L, P.Address);
               when FS.Erase_Chip =>
                  Layer.Erase_Completely (Dev, L);
               when FS.Read =>
                  if P.Length > 0 and then Taken + P.Length <= Into'Length then
                     declare
                        Got : Byte_Array (0 .. P.Length - 1);
                     begin
                        Layer.Read_Bytes (Dev, L, P.Address, Got);
                        Into (Into'First + Taken .. Into'First + Taken + P.Length - 1) := Got;
                        Taken := Taken + P.Length;
                     end;
                  end if;
               when FS.Flush =>
                  null;
               when FS.LED_Toggle =>
                  GPIO.Toggle (Adaflight.Board.LED0_Pin);
               when FS.LED_Off =>
                  GPIO.Set_High (Adaflight.Board.LED0_Pin);
            end case;
         end;
      end loop;
      O.Count := 0;
      O.Data_Used := 0;
   end Execute;

   procedure Execute (O : in out FS.Output) is
      None  : Byte_Array (1 .. 0);
      Taken : Natural := 0;
   begin
      Execute (O, None, Taken);
   end Execute;

   function Config_Of (C : Adaflight.Config_Groups.Configuration) return Layer.Flash_Config is
     (CS_Tag => C.Flash_Config.Cs_Tag, SPI_Bus => (if C.Flash_Config.Spi_Device in 1 .. 3 then C.Flash_Config.Spi_Device else 0));

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is
   begin
      Setup := Config_Of (C);
      Layer.Preinit (Dev, Setup);
   end Preinit;

   --  The chip, then the file system over its partition with the free
   --  space searched for and the write position set at its start.
   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      Map    : FS.Layout;
      Index  : Integer;
      Found  : Boolean;
      P      : Layer.Partition;
      Search : FS.Search;
      Block  : FS.Test_Block := (others => 0);
      Probe  : Byte_Array (0 .. FS.Free_Test_Bytes - 1);
      O      : FS.Output;
   begin
      Setup := Config_Of (C);
      Layer.Init (Dev, L, Setup);
      declare
         G : constant FD.Geometry := Layer.Get_Geometry (L);
      begin
         Map.Kind := FS.NOR;
         Map.Sectors := G.Sectors;
         Map.Page_Size := (if G.Page_Size in 1 .. 2_048 then Positive (G.Page_Size) else 256);
         Map.Sector_Size := G.Sector_Size;
         Map.Partition_Count := Natural'Min (16, Layer.Partition_Count (L));
         Map.Inline_Completion := True;
      end;
      Index := Layer.Find_By_Type (L, Natural (Layer.Flash_FS_Partition));
      if L.Have and then Index >= 0 then
         Layer.Find_By_Index (L, Index, Found, P);
         if Found and then P.End_Sector >= P.Start_Sector then
            Map.Has_Partition := True;
            Map.Start_Sector := P.Start_Sector;
            Map.End_Sector := P.End_Sector;
         end if;
      end if;
      FS.Init (State, Map);
      if not FS.Is_Supported (State) then
         return;
      end if;
      FS.Search_Start (Search, State);
      while not FS.Search_Done (Search) loop
         Layer.Read_Bytes (Dev, L, FS.Search_Address (Search), Probe);
         for K in Block'Range loop
            Block (K) := Probe (K);
         end loop;
         FS.Search_Next (Search, FS.Free_Test_Bytes, Block);
      end loop;
      FS.Seek_Abs (State, FS.Search_Offset (Search), O);
      Execute (O);
   end Init;

   function Supported return Boolean is (FS.Is_Supported (State));

   procedure Is_Ready (Ready : out Boolean) is
      Chip_Ready : Boolean;
   begin
      Device_Ready (Chip_Ready);
      Ready := FS.Is_Ready (State, Chip_Ready);
   end Is_Ready;

   function Full return Boolean is (FS.Is_EOF (State));

   function Free_Space return Natural is (FS.Free_Space (State));

   function Buffer_Usable return Natural is (FS.Buffer_Usable);

   procedure Write (Data : Byte_Array) is
      Ready : Boolean;
      O     : FS.Output;
      Next  : Natural := Data'First;
      Last  : Natural;
   begin
      if not FS.Is_Supported (State) then
         return;
      end if;
      while Next <= Data'Last loop
         Last := Natural'Min (Data'Last, Next + 255);
         Device_Ready (Ready);
         FS.Write (State, Data (Next .. Last), Sync => False, Device_Ready => Ready, O => O);
         Execute (O);
         Next := Last + 1;
      end loop;
   end Write;

   procedure Flush (Force : Boolean; Done : out Boolean) is
      Ready : Boolean;
      O     : FS.Output;
   begin
      Done := True;
      if not FS.Is_Supported (State) then
         return;
      end if;
      Device_Ready (Ready);
      FS.Flush_Async (State, Force, Ready, O, Done);
      Execute (O);
   end Flush;

   procedure Erase_Completely is
      O : FS.Output;
   begin
      if FS.Is_Supported (State) then
         FS.Erase_Completely (State, O);
         Execute (O);
      end if;
   end Erase_Completely;

   procedure Close is
      O : FS.Output;
   begin
      if FS.Is_Supported (State) then
         FS.Close (State, O);
         Execute (O);
      end if;
   end Close;

   procedure Erase_Step is
      Ready : Boolean;
      O     : FS.Output;
   begin
      if FS.Is_Supported (State) then
         Device_Ready (Ready);
         FS.Erase_Async (State, Ready, O);
         Execute (O);
      end if;
   end Erase_Step;

   procedure Seek (Address : Unsigned_32) is
      O : FS.Output;
   begin
      if FS.Is_Supported (State) and then (State.Data_Written or else FS.Is_Empty (State)) then
         FS.Seek_Abs (State, Address, O);
         Execute (O);
      end if;
   end Seek;

   procedure Write_Text (Data : String) is
      Ready : Boolean;
      O     : FS.Output;
      Bytes : Byte_Array (0 .. Data'Length - 1);
      Next  : Natural := 0;
      Last  : Natural;
   begin
      if not FS.Is_Supported (State) then
         return;
      end if;
      for K in Bytes'Range loop
         Bytes (K) := Character'Pos (Data (Data'First + K));
      end loop;
      while Next <= Bytes'Last loop
         Last := Natural'Min (Bytes'Last, Next + 255);
         Device_Ready (Ready);
         FS.Write (State, Bytes (Next .. Last), Sync => True, Device_Ready => Ready, O => O);
         Execute (O);
         Next := Last + 1;
      end loop;
   end Write_Text;

   procedure Flush_Sync is
      O : FS.Output;
   begin
      if FS.Is_Supported (State) and then (State.Data_Written or else FS.Is_Empty (State)) then
         FS.Flush_Sync (State, O);
         Execute (O);
      end if;
   end Flush_Sync;

   procedure Read_Text (Address : Unsigned_32; Length : Natural; Data : out String; Count : out Natural) is
      O     : FS.Output;
      Got   : Byte_Array (0 .. Natural'Max (0, Length - 1));
      Taken : Natural := 0;
      Asked : Natural;
   begin
      Data := (others => ' ');
      Count := 0;
      if Length = 0 or else not FS.Is_Supported (State)
        or else not (State.Data_Written or else FS.Is_Empty (State))
      then
         return;
      end if;
      FS.Read_Abs (State, Address, Length, O, Asked);
      Execute (O, Got, Taken);
      Count := Natural'Min (Natural'Min (Taken, Asked), Data'Length);
      for K in 0 .. Count - 1 loop
         Data (Data'First + K) := Character'Val (Got (K));
      end loop;
   end Read_Text;

   --  The reference's whole-flash check: the volume erased, every 32 bytes
   --  written as the address and a pattern, then read back and compared,
   --  the LED toggled every 64 KB and off at the end.
   procedure Verify (OK : out Boolean) is
      Ready    : Boolean;
      Failures : Natural := 0;
      Address  : Unsigned_32 := 0;
      Hex      : constant String := "0123456789abcdef";
      function Pattern (At_Address : Unsigned_32) return String is
         Text : String (1 .. 32) := "00000000 >> **0123456789ABCDEF**";
      begin
         for K in 0 .. 7 loop
            Text (8 - K) := Hex (Natural (Interfaces.Shift_Right (At_Address, 4 * K) and 16#F#) + 1);
         end loop;
         return Text;
      end Pattern;
   begin
      OK := False;
      if not FS.Is_Supported (State) then
         return;
      end if;
      Erase_Completely;
      loop
         Is_Ready (Ready);
         exit when Ready;
         Erase_Step;
         Adaflight.STM32.Time.Delay_Ms (100);
      end loop;
      Seek (0);
      while Address < State.Size loop
         Write_Text (Pattern (Address));
         if Address mod 16#10000# = 0 then
            GPIO.Toggle (Adaflight.Board.LED0_Pin);
         end if;
         Flush_Sync;
         Address := Address + 32;
      end loop;
      Close;
      Seek (0);
      Address := 0;
      while Address < State.Size loop
         declare
            Text  : String (1 .. 32);
            Count : Natural;
         begin
            Read_Text (Address, 32, Text, Count);
            if Count /= 32 or else Text /= Pattern (Address) then
               Failures := Failures + 1;
            end if;
         end;
         if Address mod 16#10000# = 0 then
            GPIO.Toggle (Adaflight.Board.LED0_Pin);
         end if;
         Address := Address + 32;
      end loop;
      GPIO.Set_High (Adaflight.Board.LED0_Pin);
      OK := Failures = 0;
   end Verify;

   function Summary return Adaflight.MSP_Hardware_Out.Flash_Values is
      Ready : Boolean;
      V     : Adaflight.MSP_Hardware_Out.Flash_Values;
   begin
      Is_Ready (Ready);
      V.Built := True;
      V.Supported := FS.Is_Supported (State);
      V.Ready := Ready;
      V.Start_Sector := State.Map.Start_Sector;
      V.End_Sector := State.Map.End_Sector;
      V.Size := State.Size;
      V.Offset := FS.Offset (State);
      return V;
   end Summary;

   function Geometry return FD.Geometry is (Layer.Get_Geometry (L));

   function Partition_Count return Natural is (Layer.Partition_Count (L));

   procedure Partition
     (Index : Natural; Found : out Boolean; Kind : out Natural; First, Last : out Unsigned_16)
   is
      P : Layer.Partition;
   begin
      Layer.Find_By_Index (L, Index, Found, P);
      Kind := Natural (P.Kind);
      First := P.Start_Sector;
      Last := P.End_Sector;
   end Partition;

   function Offset return Unsigned_32 is (FS.Offset (State));
end Adaflight.STM32.Flash_Chip;
