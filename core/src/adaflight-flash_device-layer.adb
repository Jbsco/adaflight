package body Adaflight.Flash_Device.Layer with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   Init_Clock_Hz : constant := 5_000_000;
   Init_Delay_Ms : constant := 50;

   procedure Preinit (D : in out SPI_Device; C : Flash_Config) is
   begin
      Preinit_CS (D, C.CS_Tag);
   end Preinit;

   function Find_By_Type (L : Flash; Kind : Natural) return Integer is
   begin
      for I in Partition_Index loop
         if Natural (L.Partitions (I).Kind) = Kind then
            return I;
         end if;
      end loop;
      return -1;
   end Find_By_Type;

   procedure Find_By_Index (L : Flash; Index : Natural; Found : out Boolean; P : out Partition) is
   begin
      Found := Index < L.Count;
      P := (if Found then L.Partitions (Index) else (others => <>));
   end Find_By_Index;

   procedure Partition_Set
     (L : in out Flash; Kind : Byte; Start_Sector : Interfaces.Unsigned_32; End_Sector : Interfaces.Unsigned_32)
   is
      Index : Integer := Find_By_Type (L, Natural (Kind));
   begin
      if Index < 0 then
         if L.Count = Max_Partitions - 1 then
            return;
         end if;
         Index := L.Count;
         L.Count := L.Count + 1;
      end if;
      L.Partitions (Index) :=
        (Kind => Kind, Start_Sector => Interfaces.Unsigned_16 (Start_Sector mod 2 ** 16),
         End_Sector => Interfaces.Unsigned_16 (End_Sector mod 2 ** 16));
   end Partition_Set;

   procedure Configure_Partitions (L : in out Flash)
     with Global => null
   is
      G          : constant Geometry := Get_Geometry (L);
      End_Sector : Interfaces.Unsigned_16;
      Bad_Blocks : Integer;
   begin
      if G.Total_Size = 0 then
         return;
      end if;
      End_Sector := G.Sectors - 1;
      Bad_Blocks := Find_By_Type (L, Natural (Bad_Block_Partition));
      if Bad_Blocks >= 0 then
         End_Sector := L.Partitions (Bad_Blocks).Start_Sector - 1;
      end if;
      Partition_Set (L, Flash_FS_Partition, 0, Interfaces.Unsigned_32 (End_Sector));
   end Configure_Partitions;

   procedure SPI_Init (D : in out SPI_Device; L : in out Flash; C : Flash_Config; Detected : out Boolean) is
      Free     : Boolean;
      OK       : Boolean;
      Divisor  : Interfaces.Unsigned_16;
      Response : Byte_Array (0 .. 3);
      JEDEC    : Interfaces.Unsigned_32;
   begin
      Detected := False;
      if C.CS_Tag = 0 then
         return;
      end if;
      CS_Free (D, Free);
      if not Free then
         return;
      end if;
      Attach_Bus (D, C.SPI_Bus, OK);
      if not OK then
         return;
      end if;
      Prepare_CS (D);
      Divider (D, Init_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Delay_Ms (D, Init_Delay_Ms);
      Read_Id (D, Response);
      JEDEC :=
        Interfaces.Unsigned_32 (Response (0)) * 2 ** 16 + Interfaces.Unsigned_32 (Response (1)) * 2 ** 8
        + Interfaces.Unsigned_32 (Response (2));
      Chip_Identify (L.Chip, JEDEC, Detected);
      if not Detected then
         JEDEC :=
           Interfaces.Unsigned_32 (Response (1)) * 2 ** 16 + Interfaces.Unsigned_32 (Response (2)) * 2 ** 8
           + Interfaces.Unsigned_32 (Response (3));
         Chip_Identify_Newer (L.Chip, JEDEC, Detected);
         if Detected and then L.Chip.Map.Kind = NAND then
            Partition_Set
              (L, Bad_Block_Partition, Interfaces.Unsigned_32 (L.Chip.NAND.Bad_Block_First),
               Interfaces.Unsigned_32 (L.Chip.NAND.Bad_Block_Last));
         end if;
      end if;
      if Detected then
         L.Chip.Map.JEDEC_Id := JEDEC;
         return;
      end if;
      Preinit_CS (D, C.CS_Tag);
   end SPI_Init;

   procedure Init (D : in out SPI_Device; L : in out Flash; C : Flash_Config) is
      Detected : Boolean := False;
   begin
      L.Partitions := (others => (others => <>));
      L.Count := 0;
      if C.SPI_Bus /= 0 then
         SPI_Init (D, L, C, Detected);
      end if;
      L.Have := Detected;
      if L.Have then
         Chip_Configure (D, L.Chip, 0);
      end if;
      Configure_Partitions (L);
   end Init;

   procedure Is_Ready (D : in out SPI_Device; L : in out Flash; Ready : out Boolean) is
   begin
      Chip_Is_Ready (D, L.Chip, Ready);
   end Is_Ready;

   procedure Is_Ready_Or_Fail (D : in out SPI_Device; L : in out Flash; Ready : out Boolean) is
      Now : Interfaces.Unsigned_32;
   begin
      Chip_Is_Ready (D, L.Chip, Ready);
      if Ready then
         L.Chip.Timeout_At := 0;
         return;
      end if;
      if L.Chip.Timeout_At /= 0 then
         Millis (D, Now);
         if Now - L.Chip.Timeout_At < 2 ** 31 then
            Write_Failed (D);
         end if;
      end if;
   end Is_Ready_Or_Fail;

   procedure Wait_For_Ready (D : in out SPI_Device; L : in out Flash; Ready : out Boolean) is
   begin
      Chip_Wait_For_Ready (D, L.Chip, Ready);
   end Wait_For_Ready;

   procedure Wait_Or_Fail (D : in out SPI_Device; L : in out Flash) is
      Ready : Boolean;
   begin
      Chip_Wait_For_Ready (D, L.Chip, Ready);
      if not Ready then
         Write_Failed (D);
      end if;
   end Wait_Or_Fail;

   procedure Erase_Sector (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32) is
   begin
      L.Chip.Has_Callback := False;
      Chip_Erase_Sector (D, L.Chip, Address);
      Wait_Or_Fail (D, L);
   end Erase_Sector;

   procedure Erase_Completely (D : in out SPI_Device; L : in out Flash) is
   begin
      L.Chip.Has_Callback := False;
      Chip_Erase_Completely (D, L.Chip);
   end Erase_Completely;

   procedure Page_Program_Begin (L : in out Flash; Address : Interfaces.Unsigned_32; Has_Callback : Boolean) is
   begin
      Chip_Program_Begin (L.Chip, Address, Has_Callback);
   end Page_Program_Begin;

   procedure Page_Program_Continue
     (D : in out SPI_Device; L : in out Flash; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32; Size_1 : out Natural; Size_2 : out Natural)
   is
      Page : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (L.Chip.Map.Page_Size);
      Room : Interfaces.Unsigned_32 := Page - L.Chip.Current_Write_Address mod Page;
      N    : Natural := Count;
   begin
      Size_1 := Data_1'Length;
      Size_2 := Data_2'Length;
      if Count = 0 then
         Written := 0;
         return;
      end if;
      if Interfaces.Unsigned_32 (Size_1) >= Room then
         Size_1 := Natural (Room);
         N := 1;
      else
         Room := Room - Interfaces.Unsigned_32 (Size_1);
         if N = 2 and then Interfaces.Unsigned_32 (Size_2) > Room then
            Size_2 := Natural (Room);
         end if;
      end if;
      Chip_Program_Continue
        (D, L.Chip, Data_1 (Data_1'First .. Data_1'First + Size_1 - 1),
         Data_2 (Data_2'First .. Data_2'First + Size_2 - 1), N, Written);
   end Page_Program_Continue;

   procedure Page_Program
     (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean)
   is
   begin
      Chip_Program (D, L.Chip, Address, Data, Has_Callback);
   end Page_Program;

   procedure Read_Bytes
     (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural)
   is
   begin
      L.Chip.Has_Callback := False;
      Chip_Read (D, L.Chip, Address, Buffer, Count);
   end Read_Bytes;

   procedure Flush (D : in out SPI_Device; L : in out Flash) is
      Present : Boolean;
   begin
      Chip_Flush (D, L.Chip, Present);
      if Present then
         Wait_Or_Fail (D, L);
      end if;
   end Flush;

   function Type_Name (Kind : Natural) return String is
     (case Kind is
         when 0 => "UNKNOWN  ",
         when 1 => "PARTITION",
         when 2 => "FLASHFS  ",
         when 3 => "BBMGMT   ",
         when 4 => "FIRMWARE ",
         when 5 => "CONFIG   ",
         when others => "");

end Adaflight.Flash_Device.Layer;
