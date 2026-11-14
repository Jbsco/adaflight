package body Adaflight.Virtual_FAT with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_64;
   use Adaflight.Bytes;

   subtype Integer_64 is Interfaces.Integer_64;

   --  The table's marks for a free cluster, a cluster no entry has, the root
   --  directory's end and a chain's end.
   Free_Mark     : constant Unsigned_32 := 0;
   Reserved_Mark : constant Unsigned_32 := 1;
   Root_End      : constant Unsigned_32 := 16#0FFF_FFF8#;
   Chain_End     : constant Unsigned_32 := 16#0FFF_FFFF#;

   Dir_Entry_Size  : constant := 32;
   Entries_Per_Sector : constant := Sector_Size / Dir_Entry_Size;
   Values_Per_Sector  : constant := Sector_Size / 4;

   --  The clusters a size takes, one for none.
   function Clusters_Of (Size : Unsigned_32) return Unsigned_32 is
     (if Size = 0 then 1 else (Size + (Cluster_Size - 1)) / Cluster_Size);

   procedure Start (V : in out Volume; OK : out Boolean) is
      --  The entry at each level on the way from the root to the last entry.
      type Level_Path is array (0 .. Max_Entries) of Entry_Index;
      Path     : Level_Path := (others => 1);
      Level    : Natural := 0;
      E        : Entry_Index := 1;
      Cluster  : Unsigned_32 := 2;
      Reserved : Unsigned_32 := 0;
      Table    : Unsigned_64;
      Per_FAT  : Unsigned_32;
   begin
      OK := False;
      if V.Count = 0 or else V.Entries (1).Level /= 0 or else not V.Entries (1).Dir then
         return;
      end if;
      V.Entries (1).Top := 0;
      V.Entries (1).Next := 0;
      V.Entries (1).Sub := 0;
      V.Entries (1).Subentries := 0;
      for I in 2 .. V.Count loop
         pragma Loop_Invariant (Level <= I - 2);
         V.Entries (I).Top := 0;
         V.Entries (I).Next := 0;
         V.Entries (I).Sub := 0;
         V.Entries (I).Subentries := 0;
         if V.Entries (I).Level = Level - 1 then
            if Level = 0 then
               return;
            end if;
            Level := Level - 1;
            E := Path (Level);
         end if;
         if V.Entries (I).Level = Level + 1 then
            if not V.Entries (E).Dir then
               return;
            end if;
            V.Entries (E).Sub := I;
            V.Entries (I).Top := E;
            Level := Level + 1;
         elsif V.Entries (I).Level = Level then
            if Level = 0 then
               return;
            end if;
            V.Entries (Path (Level - 1)).Subentries := V.Entries (Path (Level - 1)).Subentries + 1;
            V.Entries (I).Top := Path (Level - 1);
            V.Entries (E).Next := I;
         else
            return;
         end if;
         Path (Level) := I;
         E := I;
      end loop;
      for I in 1 .. V.Count loop
         V.Entries (I).First_Cluster := Cluster;
         if V.Entries (I).Dir then
            V.Entries (I).Current_Size := 0;
            V.Entries (I).Maximum_Size := 0;
            V.Entries (I).Last_Cluster := Cluster + Clusters_Of (V.Entries (I).Subentries * Dir_Entry_Size) - 1;
            V.Entries (I).Last_Reserved := V.Entries (I).Last_Cluster;
         else
            V.Entries (I).Last_Cluster := Cluster + Clusters_Of (V.Entries (I).Current_Size) - 1;
            V.Entries (I).Last_Reserved := Cluster + Clusters_Of (V.Entries (I).Maximum_Size) - 1;
         end if;
         Reserved := Reserved + (V.Entries (I).Last_Reserved - V.Entries (I).Last_Cluster);
         Cluster := V.Entries (I).Last_Reserved + 1;
      end loop;
      Cluster := Cluster - 2;
      V.Boot_LBA := 62;
      V.FSInfo_LBA := V.Boot_LBA + 1;
      V.FAT1_LBA := V.FSInfo_LBA + 1;
      V.Clusters := Cluster;
      V.Free_Clusters := Reserved;
      Table := Unsigned_64 (Cluster) * 4;
      Per_FAT := (if Table = 0 then 1 else Unsigned_32 ((Table + (Sector_Size - 1)) / Sector_Size));
      V.FAT2_LBA := V.FAT1_LBA + Per_FAT;
      V.Root_LBA := V.FAT2_LBA + Per_FAT;
      V.Last := 1;
      V.Disk_Sectors := Cluster * Sectors_Per_Cluster + V.Root_LBA;
      V.Size := Unsigned_64 (V.Disk_Sectors) * Sector_Size;
      OK := True;
   end Start;

   procedure Put_16 (Data : in out Sector; At_Byte : Natural; Value : Unsigned_32)
     with Pre => At_Byte <= Sector_Size - 2
   is
   begin
      Data (At_Byte) := Byte (Value and 16#FF#);
      Data (At_Byte + 1) := Byte (Interfaces.Shift_Right (Value, 8) and 16#FF#);
   end Put_16;

   procedure Put_32 (Data : in out Sector; At_Byte : Natural; Value : Unsigned_32)
     with Pre => At_Byte <= Sector_Size - 4
   is
   begin
      Put_16 (Data, At_Byte, Value and 16#FFFF#);
      Put_16 (Data, At_Byte + 2, Interfaces.Shift_Right (Value, 16));
   end Put_32;

   procedure Put_Text (Data : in out Sector; At_Byte : Natural; Text : String)
     with Pre => Text'Length <= Sector_Size and then At_Byte <= Sector_Size - Text'Length
   is
   begin
      for I in Text'Range loop
         Data (At_Byte + (I - Text'First)) := Character'Pos (Text (I));
      end loop;
   end Put_Text;

   --  A sector's cylinder, head and sector numbers as a partition table
   --  packs them, from the sector's number read as a signed word.
   procedure CHS (LBA : Unsigned_32; Sector_Byte, Cylinder_Byte, Head_Byte : out Byte) is
      Signed   : constant Integer_64 := (if LBA >= 2 ** 31 then Integer_64 (LBA) - 2 ** 32 else Integer_64 (LBA));
      Sectors  : constant := 63;
      Heads    : constant := 255;
      S        : constant Integer_64 := Signed rem Sectors + 1;
      H        : constant Integer_64 := (Signed / Sectors) rem Heads;
      Cylinder : constant Integer_64 := Signed / (Sectors * Heads);
   begin
      if Cylinder >= 1024 then
         Sector_Byte := 16#FF#;
         Cylinder_Byte := 16#FF#;
         Head_Byte := 16#FF#;
      else
         Sector_Byte := Byte (S mod 256) or Byte (((Cylinder mod 1024) / 256) * 64);
         Cylinder_Byte := Byte (Cylinder mod 256);
         Head_Byte := Byte (H mod 256);
      end if;
   end CHS;

   procedure Partition_Sector (V : Volume; Data : out Sector) is
      Start_Sector, Start_Cylinder, Start_Head : Byte;
      End_Sector, End_Cylinder, End_Head       : Byte;
      Part                                     : constant := 446;
   begin
      Data := (others => 0);
      CHS (V.Boot_LBA, Start_Sector, Start_Cylinder, Start_Head);
      CHS (V.Disk_Sectors - 1, End_Sector, End_Cylinder, End_Head);
      Data (Part) := 16#80#;
      Data (Part + 1) := Start_Head;
      Data (Part + 2) := Start_Sector;
      Data (Part + 3) := Start_Cylinder;
      Data (Part + 4) := 16#0C#;
      Data (Part + 5) := End_Head;
      Data (Part + 6) := End_Sector;
      Data (Part + 7) := End_Cylinder;
      Put_32 (Data, Part + 8, V.Boot_LBA);
      Put_32 (Data, Part + 12, V.Disk_Sectors);
      Data (510) := 16#55#;
      Data (511) := 16#AA#;
   end Partition_Sector;

   procedure Boot_Sector (V : Volume; Data : out Sector) is
   begin
      Data := (others => 0);
      Data (0) := 16#EB#;
      Data (1) := 16#58#;
      Data (2) := 16#90#;
      Put_Text (Data, 3, "MSDOS5.0");
      Put_16 (Data, 11, Sector_Size);
      Data (13) := Sectors_Per_Cluster;
      Put_16 (Data, 14, 2);
      Data (16) := 2;
      Data (21) := 16#F8#;
      Put_16 (Data, 24, 63);
      Put_16 (Data, 26, 16#FF#);
      Put_32 (Data, 28, 62);
      Put_32 (Data, 32, V.Disk_Sectors - V.Boot_LBA);
      Put_32 (Data, 36, V.FAT2_LBA - V.FAT1_LBA);
      Put_32 (Data, 44, 2);
      Put_16 (Data, 48, 1);
      Data (64) := 128;
      Data (66) := 16#29#;
      Data (67) := 148;
      Data (68) := 14;
      Data (69) := 13;
      Data (70) := 8;
      Put_Text (Data, 71, "NO NAME    ");
      Put_Text (Data, 82, "FAT32   ");
      Data (510) := 16#55#;
      Data (511) := 16#AA#;
   end Boot_Sector;

   procedure Information_Sector (V : Volume; Data : out Sector) is
   begin
      Data := (others => 0);
      Put_32 (Data, 0, 16#4161_5252#);
      Put_32 (Data, 484, 16#6141_7272#);
      Put_32 (Data, 488, V.Free_Clusters);
      Put_32 (Data, 492, 16#FFFF_FFFF#);
      Put_32 (Data, 508, 16#AA55_0000#);
   end Information_Sector;

   function Is_Cluster_Of (E : File_Entry; Cluster : Unsigned_32) return Boolean is
     (Cluster >= E.First_Cluster and then Cluster <= E.Last_Reserved);

   --  The entry with a cluster, looked for backward from an entry that
   --  starts past it and forward otherwise, or none.
   function Find (V : Volume; Cluster : Unsigned_32; Nearest : Entry_Index) return Entry_Link
     with Pre => Nearest <= V.Count, Post => Find'Result <= V.Count
   is
   begin
      if V.Entries (Nearest).First_Cluster > Cluster then
         for K in reverse 1 .. Nearest loop
            if Is_Cluster_Of (V.Entries (K), Cluster) then
               return K;
            end if;
         end loop;
      else
         for K in Nearest .. V.Count loop
            if Is_Cluster_Of (V.Entries (K), Cluster) then
               return K;
            end if;
         end loop;
      end if;
      return 0;
   end Find;

   procedure Table_Sector (V : in out Volume; Index : Unsigned_32; Data : out Sector)
     with Pre => Ready (V), Post => Ready (V) and then V.Count = V.Count'Old
   is
      Current : Unsigned_32 := Index * Values_Per_Sector;
      First   : Natural := 0;
      Entry_At : Entry_Index := V.Last;
      Found   : Entry_Link;
      Value   : Unsigned_32;
   begin
      Data := (others => 0);
      if Current = 0 then
         Put_32 (Data, 0, Root_End);
         Put_32 (Data, 4, 16#FFFF_FFFF#);
         First := 2;
         Current := 2;
      end if;
      for Slot in First .. Values_Per_Sector - 1 loop
         pragma Loop_Invariant (Entry_At <= V.Count and then Ready (V) and then V.Count = V.Count'Loop_Entry);
         Value := Reserved_Mark;
         if Is_Cluster_Of (V.Entries (Entry_At), Current) then
            Found := Entry_At;
         else
            Found := Find (V, Current, Entry_At);
            Entry_At := (if Found = 0 then V.Last else Found);
         end if;
         if Found /= 0 then
            if Current = V.Entries (Entry_At).Last_Cluster then
               Value := Chain_End;
            elsif not V.Entries (Entry_At).Dir and then Current > V.Entries (Entry_At).Last_Cluster then
               Value := Free_Mark;
            else
               Value := Current + 1;
            end if;
         end if;
         Put_32 (Data, 4 * Slot, Value);
         Current := Current + 1;
      end loop;
      V.Last := Entry_At;
   end Table_Sector;

   --  A directory entry at a place in a sector: the name as eight characters
   --  and, for what is no directory, three after its last dot, in upper
   --  case, then attributes, times, first cluster and size. A label and the
   --  entries for a directory itself and the one above have no times.
   procedure Fill_Entry
     (Data : in out Sector; At_Byte : Natural; Name : String; Attr : Byte; Cluster : Unsigned_32; CMA : Times;
      Size : Unsigned_32)
     with Pre => At_Byte <= Sector_Size - Dir_Entry_Size and then Name'First = 1 and then Name'Length <= Max_Name
   is
      Length : constant Name_Length := Name'Length;
      Dot    : Name_Length := 0;
      Main   : Natural range 0 .. 8;
      Rest   : Natural range 0 .. 3 := 0;
   begin
      for I in At_Byte .. At_Byte + Dir_Entry_Size - 1 loop
         Data (I) := 0;
      end loop;
      Put_16 (Data, At_Byte + 14, CMA (0) and 16#FFFF#);
      Put_16 (Data, At_Byte + 16, Interfaces.Shift_Right (CMA (0), 16));
      Put_16 (Data, At_Byte + 18, Interfaces.Shift_Right (CMA (2), 16));
      Put_16 (Data, At_Byte + 22, CMA (1) and 16#FFFF#);
      Put_16 (Data, At_Byte + 24, Interfaces.Shift_Right (CMA (1), 16));
      if (Attr and Directory) = 0 then
         for I in reverse 1 .. Length loop
            if Name (I) = '.' then
               Dot := I;
               exit;
            end if;
         end loop;
      end if;
      if Dot = 0 then
         Main := Natural'Min (Length, 8);
      else
         Main := Natural'Min (Dot - 1, 8);
         Rest := Natural'Min (Length - Dot, 3);
      end if;
      for I in 0 .. 10 loop
         Data (At_Byte + I) := Character'Pos (' ');
      end loop;
      pragma Assert (Main <= Length and then Dot + Rest <= Length);
      for I in 1 .. Main loop
         pragma Loop_Invariant (Main <= Length);
         Data (At_Byte + I - 1) := Character'Pos (Name (I));
      end loop;
      for I in 1 .. Rest loop
         pragma Loop_Invariant (Dot + Rest <= Length);
         Data (At_Byte + 7 + I) := Character'Pos (Name (Dot + I));
      end loop;
      for I in 0 .. 10 loop
         if Data (At_Byte + I) in Character'Pos ('a') .. Character'Pos ('z') then
            Data (At_Byte + I) := Data (At_Byte + I) - 16#20#;
         end if;
      end loop;
      Data (At_Byte + 11) := Attr;
      Data (At_Byte + 12) := 24;
      Put_16 (Data, At_Byte + 20, Interfaces.Shift_Right (Cluster, 16));
      Put_16 (Data, At_Byte + 26, Cluster and 16#FFFF#);
      Put_32 (Data, At_Byte + 28, Size);
   end Fill_Entry;

   --  A sector of a directory by its place in a cluster: in the first one
   --  the volume's label, or the entries for the directory itself and the
   --  one above, then the directory's entries from where the sectors before
   --  ended.
   procedure Directory_Sector (V : Volume; Dir : Entry_Index; Place : Natural; Data : out Sector)
     with Pre => Place < Sectors_Per_Cluster
   is
      No_Times : constant Times := (others => 0);
      Rooted   : constant Boolean := V.Entries (Dir).Top = 0;
      At_Byte  : Natural := 0;
      Cursor   : Entry_Link := V.Entries (Dir).Sub;
   begin
      Data := (others => 0);
      if Place = 0 then
         if Rooted then
            Fill_Entry (Data, 0, V.Label (1 .. V.Label_Length), Volume_Label, 0, No_Times, 0);
            At_Byte := Dir_Entry_Size;
         else
            Fill_Entry
              (Data, 0, ".", Directory or Read_Only, V.Entries (Dir).First_Cluster, No_Times, 0);
            Fill_Entry
              (Data, Dir_Entry_Size, "..", Directory or Read_Only,
               (if V.Entries (V.Entries (Dir).Top).Top = 0 then 0
                else V.Entries (V.Entries (Dir).Top).First_Cluster),
               No_Times, 0);
            At_Byte := 2 * Dir_Entry_Size;
         end if;
      else
         for Skipped in 1 .. Place * Entries_Per_Sector - (if Rooted then 1 else 2) loop
            exit when Cursor = 0;
            Cursor := V.Entries (Cursor).Next;
         end loop;
      end if;
      for Slot in 1 .. Entries_Per_Sector loop
         pragma Loop_Invariant (At_Byte <= (Slot + 1) * Dir_Entry_Size);
         exit when Cursor = 0 or else At_Byte > Sector_Size - Dir_Entry_Size;
         if V.Entries (Cursor).Dir then
            Fill_Entry
              (Data, At_Byte, V.Entries (Cursor).Name (1 .. V.Entries (Cursor).Length), Directory or Read_Only,
               V.Entries (Cursor).First_Cluster, V.Entries (Cursor).CMA, 0);
         else
            Fill_Entry
              (Data, At_Byte, V.Entries (Cursor).Name (1 .. V.Entries (Cursor).Length),
               Archive or Read_Only or V.Entries (Cursor).Attr, V.Entries (Cursor).First_Cluster,
               V.Entries (Cursor).CMA, V.Entries (Cursor).Current_Size);
         end if;
         Cursor := V.Entries (Cursor).Next;
         At_Byte := At_Byte + Dir_Entry_Size;
      end loop;
   end Directory_Sector;

   procedure Data_Sector (V : in out Volume; Relative : Unsigned_32; Data : out Sector; From : out Source)
     with Pre => Ready (V), Post => Ready (V) and then V.Count = V.Count'Old
   is
      Cluster  : constant Unsigned_32 := Relative / Sectors_Per_Cluster + 2;
      Place    : constant Natural := Natural (Relative mod Sectors_Per_Cluster);
      Entry_At : Entry_Index := V.Last;
      Found    : Entry_Link;
   begin
      From := (others => <>);
      Data := (others => 0);
      if not Is_Cluster_Of (V.Entries (Entry_At), Cluster) then
         Found := Find (V, Cluster, Entry_At);
         if Found = 0 then
            for I in 0 .. Values_Per_Sector - 1 loop
               Data (4 * I) := 16#DE#;
               Data (4 * I + 1) := 16#AD#;
               Data (4 * I + 2) := 16#BE#;
               Data (4 * I + 3) := 16#EF#;
            end loop;
            return;
         end if;
         Entry_At := Found;
         V.Last := Entry_At;
      end if;
      if V.Entries (Entry_At).Dir then
         Directory_Sector (V, Entry_At, Place, Data);
         return;
      end if;
      if V.Entries (Entry_At).Readable then
         From :=
           (Kind   => From_File,
            File   => Entry_At,
            Offset => (Cluster - V.Entries (Entry_At).First_Cluster) * Cluster_Size
                      + Unsigned_32 (Place) * Sector_Size + V.Entries (Entry_At).Offset);
      end if;
   end Data_Sector;

   procedure Read (V : in out Volume; Number : Unsigned_32; Data : out Sector; From : out Source) is
   begin
      From := (others => <>);
      if Number >= V.Root_LBA then
         Data_Sector (V, Number - V.Root_LBA, Data, From);
      elsif Number = 0 then
         Partition_Sector (V, Data);
      elsif Number = V.FSInfo_LBA then
         Information_Sector (V, Data);
      elsif Number = V.Boot_LBA then
         Boot_Sector (V, Data);
      elsif Number >= V.FAT1_LBA and then Number < V.FAT2_LBA then
         Table_Sector (V, Number - V.FAT1_LBA, Data);
      elsif Number >= V.FAT2_LBA and then Number < V.Root_LBA then
         Table_Sector (V, Number - V.FAT2_LBA, Data);
      else
         Data := (others => 0);
      end if;
   end Read;

   function Packed_Time (Unix : Unsigned_32) return Unsigned_32 is
      Day_Seconds : constant := 86_400;
      Month_Days  : constant array (1 .. 12) of Unsigned_32 := (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
      Day     : Unsigned_32 := Unix / Day_Seconds;
      Rest    : constant Unsigned_32 := Unix mod Day_Seconds;
      Hours   : constant Unsigned_32 := Rest / 3_600;
      Minutes : constant Unsigned_32 := (Rest mod 3_600) / 60;
      Seconds : constant Unsigned_32 := (Rest mod 3_600) mod 60;
      Year    : Unsigned_32 := 1_970;
      Month   : Unsigned_32 := 1;
      Leap    : Boolean;

      function Year_Days (Y : Unsigned_32) return Unsigned_32 is (if Y mod 4 = 0 then 366 else 365);
      function Days_In (M : Positive) return Unsigned_32 is (if M = 2 and then Leap then 29 else Month_Days (M))
        with Pre => M <= 12;
   begin
      for Y in Unsigned_32 range 1_970 .. 2_106 loop
         exit when Day < Year_Days (Y);
         Day := Day - Year_Days (Y);
         Year := Y + 1;
      end loop;
      Leap := Year mod 4 = 0;
      for M in 1 .. 11 loop
         exit when Day < Days_In (M);
         Day := Day - Days_In (M);
         Month := Unsigned_32 (M) + 1;
      end loop;
      return Interfaces.Shift_Left
          (Interfaces.Shift_Left (Year - 1_980, 9) or Interfaces.Shift_Left (Month, 5) or (Day + 1), 16)
        or (Interfaces.Shift_Left (Hours, 11) or Interfaces.Shift_Left (Minutes, 5)
            or Interfaces.Shift_Right (Seconds, 1));
   end Packed_Time;

end Adaflight.Virtual_FAT;
