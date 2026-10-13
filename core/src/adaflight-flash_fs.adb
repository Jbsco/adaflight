package body Adaflight.Flash_FS with SPARK_Mode is

   procedure Add (O : in out Output; Item : Op) is
   begin
      if O.Count < Max_Ops then
         O.Count := O.Count + 1;
         O.Ops (O.Count) := Item;
      end if;
   end Add;

   ----------
   -- Init --
   ----------

   procedure Init (FS : out File_System; Map : Layout) is
   begin
      FS := (Map => Map, others => <>);
      if Map.Has_Partition then
         FS.Size := (Unsigned_32 (Map.End_Sector) + 1 - Unsigned_32 (Map.Start_Sector)) * Map.Sector_Size;
      end if;
   end Init;

   ----------------------
   -- Program_Complete --
   ----------------------

   procedure Program_Complete (FS : in out File_System; Bytes : Buffer_Count) is
      Advanced : constant Natural := FS.Tail + Bytes;
   begin
      FS.Tail_Address := FS.Tail_Address + Unsigned_32 (Bytes);
      FS.Tail := (if Advanced >= Buffer_Size then Advanced - Buffer_Size else Advanced);
      FS.Data_Written := True;
   end Program_Complete;

   ----------------------
   -- Erase_Completely --
   ----------------------

   procedure Erase_Completely (FS : in out File_System; O : in out Output) is
   begin
      if FS.Map.Sectors > 0 and then FS.Map.Partition_Count > 0 then
         --  One partition over the whole NOR chip takes the chip erase.
         if FS.Map.Kind = NOR and then FS.Map.Partition_Count = 1
           and then Integer (FS.Map.End_Sector) + 1 - Integer (FS.Map.Start_Sector) = Integer (FS.Map.Sectors)
         then
            Add (O, (Kind => Erase_Chip, others => <>));
            FS.Chip_Erase := True;
            FS.Erasing := True;
         else
            FS.Erase_Sector := FS.Map.Start_Sector;
            FS.Chip_Erase := False;
            FS.Erasing := True;
         end if;
      end if;
      FS.Tail := 0;
      FS.Head := 0;
      FS.Tail_Address := 0;
   end Erase_Completely;

   -----------------
   -- Erase_Async --
   -----------------

   procedure Erase_Async (FS : in out File_System; Device_Ready : Boolean; O : in out Output) is
   begin
      if not FS.Erasing then
         return;
      end if;
      Add (O, (Kind => Ready_Check, others => <>));
      if FS.Chip_Erase then
         if Device_Ready then
            FS.Chip_Erase := False;
            FS.Erasing := False;
            Add (O, (Kind => LED_Off, others => <>));
         end if;
      elsif Device_Ready then
         if FS.Erase_Sector <= FS.Map.End_Sector then
            Add (O, (Kind => Erase_Sector, Address => Unsigned_32 (FS.Erase_Sector) * FS.Map.Sector_Size,
                     others => <>));
            FS.Erase_Sector := FS.Erase_Sector + 1;
            Add (O, (Kind => LED_Toggle, others => <>));
         else
            FS.Erasing := False;
            Add (O, (Kind => LED_Off, others => <>));
         end if;
      end if;
   end Erase_Async;

   --  The buffered bytes from the tail as the run to the end of the ring and
   --  the run from its start, with the count of runs that hold bytes.
   procedure Dirty (FS : File_System; First, Second : out Buffer_Count; Count : out Natural)
     with Post => Count in 0 .. 2 and then (Count = 0) = (First = 0)
                  and then First <= Buffer_Size - FS.Tail and then Second < Buffer_Size
                  and then First + Second <= Buffer_Usable and then (if Count < 2 then Second = 0)
   is
   begin
      if FS.Head > FS.Tail then
         First := FS.Head - FS.Tail;
         Second := 0;
         Count := 1;
      elsif FS.Head < FS.Tail then
         First := Buffer_Size - FS.Tail;
         Second := FS.Head;
         Count := (if Second = 0 then 1 else 2);
      else
         First := 0;
         Second := 0;
         Count := 0;
      end if;
   end Dirty;

   --  A program of the runs at the tail address, trimmed at the page
   --  boundary as the flash layer trims it, with the bytes copied into the
   --  output while room remains. A flash that completes inside the call ends
   --  the program at once; otherwise a synchronous write ends it after its
   --  wait and the caller reports the end of an asynchronous one.
   procedure Write_Buffers (FS : in out File_System; First, Second : Buffer_Count; Count : Natural; Sync : Boolean;
                            Ready : Boolean; O : in out Output; Accepted : out Buffer_Count)
     with Pre => Count in 1 .. 2 and then First in 1 .. Buffer_Size - FS.Tail and then Second < Buffer_Size
                 and then First + Second <= Buffer_Usable and then (if Count = 1 then Second = 0)
   is
      Page   : constant Unsigned_32 := Unsigned_32 (FS.Map.Page_Size);
      Room   : Unsigned_32;
      Length : Buffer_Count := First;
      Rest   : Buffer_Count := Second;
      Pieces : Natural := Count;
   begin
      Accepted := 0;
      if Sync then
         Add (O, (Kind => Ready_Wait, others => <>));
      else
         Add (O, (Kind => Ready_Check, others => <>));
         if not Ready then
            return;
         end if;
      end if;
      if Is_EOF (FS) then
         return;
      end if;
      Room := Page - FS.Tail_Address mod Page;
      if Unsigned_32 (Length) >= Room then
         Length := Buffer_Count (Room);
         Pieces := 1;
      else
         Room := Room - Unsigned_32 (Length);
         if Pieces = 2 and then Unsigned_32 (Rest) > Room then
            Rest := Buffer_Count (Room);
         end if;
      end if;
      if Pieces = 1 then
         Rest := 0;
      end if;
      Accepted := Length + Rest;
      declare
         At_Byte : constant Natural := O.Data_Used;
      begin
         if At_Byte + Length + Rest <= Data_Size then
            for I in 0 .. Length - 1 loop
               O.Data (At_Byte + I) := FS.Buffer (FS.Tail + I);
            end loop;
            for I in 0 .. Rest - 1 loop
               O.Data (At_Byte + Length + I) := FS.Buffer (I);
            end loop;
            O.Data_Used := At_Byte + Length + Rest;
         end if;
         Add (O, (Kind    => Program,
                  Address => FS.Tail_Address,
                  First   => Length,
                  Second  => Rest,
                  Data_At => At_Byte,
                  Report  => not FS.Map.Inline_Completion and then not Sync,
                  others  => <>));
      end;
      FS.Data_Written := False;
      if FS.Map.Inline_Completion then
         Program_Complete (FS, Accepted);
      end if;
   end Write_Buffers;

   -----------------
   -- Flush_Async --
   -----------------

   procedure Flush_Async (FS : in out File_System; Force : Boolean; Device_Ready : Boolean; O : in out Output;
                          Done : out Boolean)
   is
      First, Second   : Buffer_Count;
      Count           : Natural;
      Ignore_Accepted : Buffer_Count;
   begin
      if Is_Empty (FS) then
         Done := True;
         return;
      end if;
      if not FS.Data_Written then
         Done := False;
         return;
      end if;
      Dirty (FS, First, Second, Count);
      if Count > 0 and then (Force or else First + Second >= Auto_Flush_Length) then
         Write_Buffers (FS, First, Second, Count, False, Device_Ready, O, Ignore_Accepted);
      end if;
      Done := Is_Empty (FS);
   end Flush_Async;

   ----------------
   -- Flush_Sync --
   ----------------

   procedure Flush_Sync (FS : in out File_System; O : in out Output) is
      First, Second : Buffer_Count;
      Count         : Natural;
      Accepted      : Buffer_Count := 0;
   begin
      if Is_Empty (FS) then
         return;
      end if;
      Dirty (FS, First, Second, Count);
      if Count > 0 then
         Write_Buffers (FS, First, Second, Count, True, True, O, Accepted);
      end if;
      --  The wait for the flash, during which a program in the background
      --  ends.
      Add (O, (Kind => Ready_Wait, others => <>));
      if not FS.Data_Written then
         Program_Complete (FS, Accepted);
      end if;
   end Flush_Sync;

   ----------------
   -- Write_Byte --
   ----------------

   procedure Write_Byte (FS : in out File_System; B : Unsigned_8; Device_Ready : Boolean; O : in out Output) is
      Ignore : Boolean;
   begin
      FS.Buffer (FS.Head) := B;
      FS.Head := (if FS.Head = Buffer_Size - 1 then 0 else FS.Head + 1);
      if Used (FS) >= Auto_Flush_Length then
         Flush_Async (FS, False, Device_Ready, O, Ignore);
      end if;
   end Write_Byte;

   -----------
   -- Write --
   -----------

   procedure Write (FS : in out File_System; Data : Bytes.Byte_Array; Sync : Boolean; Device_Ready : Boolean;
                    O : in out Output)
   is
      First, Second   : Buffer_Count;
      Count           : Natural;
      Ignore_Accepted : Buffer_Count;
   begin
      for I in Data'Range loop
         Write_Byte (FS, Data (I), Device_Ready, O);
      end loop;
      --  A synchronous write waits for the last program's end, which a flash
      --  that completes inside the call has already reported.
      if not FS.Data_Written then
         return;
      end if;
      Dirty (FS, First, Second, Count);
      if Count > 0 and then First + Second >= Auto_Flush_Length then
         Write_Buffers (FS, First, Second, Count, Sync, Device_Ready, O, Ignore_Accepted);
      end if;
   end Write;

   --------------
   -- Seek_Abs --
   --------------

   procedure Seek_Abs (FS : in out File_System; Offset : Unsigned_32; O : in out Output) is
   begin
      Flush_Sync (FS, O);
      FS.Tail_Address := Offset;
   end Seek_Abs;

   --------------
   -- Read_Abs --
   --------------

   procedure Read_Abs (FS : in out File_System; Address : Unsigned_32; Length : Natural; O : in out Output;
                       Length_Read : out Natural)
   is
   begin
      if Address >= FS.Size then
         Length_Read := 0;
         return;
      end if;
      declare
         Remaining : constant Unsigned_32 := FS.Size - Address;
      begin
         Length_Read := (if Unsigned_32 (Length) > Remaining then Natural (Remaining) else Length);
      end;
      if Length_Read = 0 then
         return;
      end if;
      Flush_Sync (FS, O);
      Add (O, (Kind => Read, Address => Address, Length => Length_Read, others => <>));
   end Read_Abs;

   -----------
   -- Close --
   -----------

   procedure Close (FS : in out File_System; O : in out Output) is
   begin
      case FS.Map.Kind is
         when NOR =>
            null;
         when NAND =>
            Add (O, (Kind => Flush, others => <>));
            declare
               Page : constant Unsigned_32 := Unsigned_32 (FS.Map.Page_Size);
            begin
               FS.Tail_Address := (FS.Tail_Address + Page - 1) and not (Page - 1);
            end;
      end case;
      FS.Tail_Address := (FS.Tail_Address + 2_047) and not 2_047;
   end Close;

   ------------------
   -- Search_Start --
   ------------------

   procedure Search_Start (S : out Search; FS : File_System) is
      Blocks : constant Block_Number := Block_Number (FS.Size / Free_Block_Size);
   begin
      S := (Left => 0, Right => Blocks, Result => Blocks, Stopped => False);
   end Search_Start;

   -----------------
   -- Search_Next --
   -----------------

   procedure Search_Next (S : in out Search; Count : Integer; Block : Test_Block) is
      Mid    : constant Block_Number := (S.Left + S.Right) / 2;
      Erased : Boolean := True;
   begin
      if Count < Free_Test_Bytes then
         S.Stopped := True;
         return;
      end if;
      for Word in 0 .. Free_Test_Bytes / 4 - 1 loop
         if Block (Word * 4) /= 16#FF# or else Block (Word * 4 + 1) /= 16#FF#
           or else Block (Word * 4 + 2) /= 16#FF# or else Block (Word * 4 + 3) /= 16#FF#
         then
            Erased := False;
            exit;
         end if;
      end loop;
      if Erased then
         S.Result := Mid;
         S.Right := Mid;
      else
         S.Left := Mid + 1;
      end if;
   end Search_Next;

end Adaflight.Flash_FS;
