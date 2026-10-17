package body Adaflight.Blackbox_SD with SPARK_Mode is
   use type Unsigned_8;

   -----------------
   -- Name_Number --
   -----------------

   function Name_Number (Name : FAT_Name) return Integer_32 is
      --  A bound on the value of the digits before each position.
      Bound    : constant array (3 .. 7) of Integer_32 := (1, 10, 100, 1_000, 10_000);
      Position : Natural := 3;
      Negative : Boolean := False;
      Value    : Integer_32 := 0;
   begin
      while Position <= 7 and then Name (Position) in 32 | 9 .. 13 loop
         pragma Loop_Invariant (Position in 3 .. 7);
         pragma Loop_Variant (Increases => Position);
         Position := Position + 1;
      end loop;
      if Position <= 7 and then Name (Position) in Character'Pos ('+') | Character'Pos ('-') then
         Negative := Name (Position) = Character'Pos ('-');
         Position := Position + 1;
      end if;
      while Position <= 7 and then Name (Position) in Character'Pos ('0') .. Character'Pos ('9') loop
         pragma Loop_Invariant (Position in 3 .. 7 and then Value in 0 .. Bound (Position) - 1);
         pragma Loop_Variant (Increases => Position);
         Value := Value * 10 + Integer_32 (Name (Position)) - Character'Pos ('0');
         Position := Position + 1;
      end loop;
      return (if Negative then -Value else Value);
   end Name_Number;

   ------------------
   -- Take_Notices --
   ------------------

   procedure Take_Notices (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State) is
      Count   : constant Natural := FS.Notice_Count;
      Notices : constant Notice_List := FS.Notices;
   begin
      FS.Notice_Count := 0;
      for K in 1 .. Count loop
         case Notices (K).Tag is
            when Directory_Opened =>
               if Notices (K).File /= No_File then
                  L.Log_Directory := Notices (K).File;
                  FS_Ops.Find_First (FS, Card, File_Id (Notices (K).File), L.Finder);
                  L.State := Enumerate_Files;
               else
                  --  Tried again from the start.
                  L.State := Initial;
               end if;
            when File_Opened =>
               if Notices (K).File /= No_File then
                  L.Log_File := Notices (K).File;
                  if L.Largest < Integer_32'Last then
                     L.Largest := L.Largest + 1;
                  end if;
                  L.State := Ready_To_Log;
               else
                  L.State := Ready_To_Create_Log;
               end if;
            when others =>
               null;
         end case;
      end loop;
   end Take_Notices;

   ----------
   -- Poll --
   ----------

   procedure Poll (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Card_Ready : Boolean)
   is
   begin
      FS_Ops.Poll (FS, Card, Card_Ready);
      Take_Notices (L, FS, Card);
   end Poll;

   ---------------
   -- Begin_Log --
   ---------------

   procedure Begin_Log (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean)
   is
      Status  : Operation_Status;
      Slot    : Cache_Slot;
      Changed        : Boolean;
      Unused_Started : Boolean;
      Unused_Queued  : Boolean;
   begin
      Done := False;
      loop
         case L.State is
            when Initial =>
               if FS.State = Ready then
                  L.State := Waiting;
                  FS_Ops.Make_Directory (FS, Card, "logs", Directory_Opened, Unused_Started);
                  Take_Notices (L, FS, Card);
               end if;
               return;
            when Waiting =>
               return;
            when Enumerate_Files =>
               if L.Log_Directory = No_File then
                  return;
               end if;
               loop
                  pragma Loop_Invariant (L.Log_Directory /= No_File);
                  FS_Ops.Find_Next (FS, Card, File_Id (L.Log_Directory), L.Finder, Status, Slot);
                  if Status /= Success then
                     return;
                  end if;
                  if Slot /= No_Slot
                    and then not Is_Entry_Terminator (FS.Cache (Slot) (Natural (L.Finder.Index) * Directory_Entry_Size))
                  then
                     declare
                        Base : constant Sector_Offset := Natural (L.Finder.Index) * Directory_Entry_Size;
                        Name : FAT_Name;
                     begin
                        for K in Name'Range loop
                           Name (K) := FS.Cache (Slot) (Base + K);
                        end loop;
                        --  A log file's name: LOG, five characters, BFL.
                        if Name (0) = Character'Pos ('L') and then Name (1) = Character'Pos ('O')
                          and then Name (2) = Character'Pos ('G') and then Name (8) = Character'Pos ('B')
                          and then Name (9) = Character'Pos ('F') and then Name (10) = Character'Pos ('L')
                        then
                           L.Largest := Integer_32'Max (Name_Number (Name), L.Largest);
                        end if;
                     end;
                  else
                     --  Every name read: enter the directory.
                     FS_Ops.Find_Last (FS, File_Id (L.Log_Directory));
                     L.State := Change_Into_Log_Directory;
                     exit;
                  end if;
               end loop;
            when Change_Into_Log_Directory =>
               FS_Ops.Change_Directory (FS, Card, L.Log_Directory, Changed);
               if not Changed then
                  return;
               end if;
               --  The directory's own handle is no longer needed.
               FS_Ops.Close (FS, Card, L.Log_Directory, No_Callback, Unused_Queued);
               L.Log_Directory := No_File;
               L.State := Ready_To_Create_Log;
            when Ready_To_Create_Log =>
               declare
                  Name      : String := "LOG00000.BFL";
                  Remainder : Integer_32 := (if L.Largest < Integer_32'Last then L.Largest + 1 else L.Largest);
               begin
                  for I in reverse 4 .. 8 loop
                     Name (I) := Character'Val (Character'Pos ('0') + Integer (abs (Remainder rem 10)));
                     Remainder := Remainder / 10;
                  end loop;
                  L.State := Waiting;
                  FS_Ops.Open (FS, Card, Name, "as", File_Opened, Unused_Started);
                  Take_Notices (L, FS, Card);
               end;
               return;
            when Ready_To_Log =>
               Done := True;
               return;
         end case;
      end loop;
   end Begin_Log;

   -------------
   -- End_Log --
   -------------

   procedure End_Log
     (L : in out SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Retain : Boolean; Done : out Boolean)
   is
   begin
      --  The close or delete queues and finishes later.
      if Retain then
         FS_Ops.Close (FS, Card, L.Log_File, No_Callback, Done);
      else
         FS_Ops.Unlink (FS, Card, L.Log_File, No_Callback, Done);
      end if;
      if Done then
         L.Log_File := No_File;
         L.State := Ready_To_Create_Log;
      end if;
   end End_Log;

   ----------------
   -- Write_Byte --
   ----------------

   procedure Write_Byte (L : SD_Log; FS : in out File_System; Card : in out FS_Ops.Card_State; Value : Unsigned_8) is
   begin
      if L.Log_File /= No_File then
         FS_Ops.Put_Byte (FS, Card, File_Id (L.Log_File), Value);
      end if;
   end Write_Byte;

   ----------------
   -- Write_Text --
   ----------------

   procedure Write_Text
     (L      : SD_Log;
      FS     : in out File_System;
      Card   : in out FS_Ops.Card_State;
      Text   : Data_Bytes;
      Length : out Natural)
   is
      Unused_Written : Natural;
   begin
      if L.Log_File /= No_File then
         FS_Ops.Write (FS, Card, File_Id (L.Log_File), Text, Unused_Written);
      end if;
      Length := Text'Length;
   end Write_Text;

   -----------------
   -- Flush_Force --
   -----------------

   procedure Flush_Force (FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean) is
   begin
      FS_Ops.Flush (FS, Card, Done);
   end Flush_Force;

   --------------------------
   -- Flush_Force_Complete --
   --------------------------

   procedure Flush_Force_Complete (FS : in out File_System; Card : in out FS_Ops.Card_State; Done : out Boolean) is
      Unused_Flushed : Boolean;
   begin
      if Cache_In_Sync (FS) then
         Done := True;
      else
         FS_Ops.Flush (FS, Card, Unused_Flushed);
         Done := False;
      end if;
   end Flush_Force_Complete;

end Adaflight.Blackbox_SD;
