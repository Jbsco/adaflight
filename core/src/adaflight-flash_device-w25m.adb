package body Adaflight.Flash_Device.W25M with SPARK_Mode is

   use type Interfaces.Unsigned_16;

   Die_Select_Instruction : constant Byte := 16#C2#;
   W25Q256_JEDEC          : constant Interfaces.Unsigned_32 := 16#EF_40_19#;
   W25N01GV_JEDEC         : constant Interfaces.Unsigned_32 := 16#EF_AA_21#;

   procedure Select_Die (D : in out SPI_Device; T : in out Stack; Die : Die_Index) is
   begin
      if T.Active_Die = Die then
         return;
      end if;
      Wait (D);
      Send (D, (Die_Select_Instruction, Byte (Die)));
      Wait (D);
      T.Active_Die := Die;
   end Select_Die;

   procedure Identify
     (D : in out SPI_Device; F : in out Device; T : in out Stack; JEDEC : Interfaces.Unsigned_32; OK : out Boolean)
   is
      Ignored : Boolean;
   begin
      if JEDEC = W25M512_JEDEC then
         T.Die_Count := 2;
         for Die in Die_Index loop
            Select_Die (D, T, Die);
            Die_Identify_NOR (Die, T.Dies (Die), W25Q256_JEDEC, Ignored);
         end loop;
         F.Map.Kind := NOR;
      elsif JEDEC = W25M02G_JEDEC then
         T.Die_Count := 2;
         for Die in Die_Index loop
            Select_Die (D, T, Die);
            Die_Identify_NAND (Die, T.Dies (Die), W25N01GV_JEDEC, Ignored);
         end loop;
         F.Map.Kind := NAND;
      else
         F.Map.Sectors := 0;
         F.Map.Pages_Per_Sector := 0;
         F.Map.Sector_Size := 0;
         F.Map.Total_Size := 0;
         OK := False;
         return;
      end if;
      F.Map.Sectors := T.Dies (0).Map.Sectors * 2;
      F.Map.Sector_Size := T.Dies (0).Map.Sector_Size;
      F.Map.Pages_Per_Sector := T.Dies (0).Map.Pages_Per_Sector;
      F.Map.Page_Size := T.Dies (0).Map.Page_Size;
      T.Die_Size := T.Dies (0).Map.Total_Size;
      F.Map.Total_Size := T.Die_Size * 2;
      OK := True;
   end Identify;

   procedure Configure (D : in out SPI_Device; T : in out Stack; Flags : Interfaces.Unsigned_32) is
   begin
      for Die in 0 .. T.Die_Count - 1 loop
         Select_Die (D, T, Die);
         Die_Configure (D, Die, T.Dies (Die), Flags);
      end loop;
   end Configure;

   procedure Is_Ready (D : in out SPI_Device; T : in out Stack; Ready : out Boolean) is
   begin
      for Die in 0 .. T.Die_Count - 1 loop
         if T.Dies (Die).Could_Be_Busy then
            Select_Die (D, T, Die);
            Die_Is_Ready (D, Die, T.Dies (Die), Ready);
            if not Ready then
               return;
            end if;
         end if;
      end loop;
      Ready := True;
   end Is_Ready;

   procedure Wait_For_Ready (D : in out SPI_Device; T : in out Stack; Ready : out Boolean) is
   begin
      for Die in 0 .. T.Die_Count - 1 loop
         Select_Die (D, T, Die);
         Die_Wait_For_Ready (D, Die, T.Dies (Die), Ready);
         if not Ready then
            return;
         end if;
      end loop;
      Ready := True;
   end Wait_For_Ready;

   procedure Erase_Sector (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32) is
      Die : constant Die_Index := Die_Index (Address / T.Die_Size);
   begin
      Select_Die (D, T, Die);
      Die_Erase_Sector (D, Die, T.Dies (Die), Address mod T.Die_Size);
   end Erase_Sector;

   procedure Erase_Completely (D : in out SPI_Device; T : in out Stack) is
   begin
      for Die in 0 .. T.Die_Count - 1 loop
         Select_Die (D, T, Die);
         Die_Erase_Completely (D, Die, T.Dies (Die));
      end loop;
   end Erase_Completely;

   procedure Page_Program_Begin
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Has_Callback : Boolean)
   is
      Die : constant Die_Index := Die_Index (Address / T.Die_Size);
   begin
      T.Write_Die := Die;
      Select_Die (D, T, Die);
      T.Write_Address := Address mod T.Die_Size;
      Die_Program_Begin (Die, T.Dies (Die), Address, Has_Callback);
   end Page_Program_Begin;

   procedure Page_Program_Continue
     (D : in out SPI_Device; T : in out Stack; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32)
   is
      Die : constant Die_Index := T.Write_Die;
   begin
      Die_Program_Continue (D, Die, T.Dies (Die), Data_1, Data_2, Count, Written);
   end Page_Program_Continue;

   procedure Page_Program_Finish (T : in out Stack) is
      Die : constant Die_Index := T.Write_Die;
   begin
      Die_Program_Finish (Die, T.Dies (Die));
   end Page_Program_Finish;

   procedure Page_Program
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean)
   is
      No_Bytes : constant Byte_Array (1 .. 0) := (others => 0);
      Written  : Interfaces.Unsigned_32;
   begin
      Page_Program_Begin (D, T, Address, Has_Callback);
      Page_Program_Continue (D, T, Data, No_Bytes, 1, Written);
      pragma Unreferenced (Written);
      Page_Program_Finish (T);
   end Page_Program;

   procedure Read_Bytes
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural)
   is
      At_Address : Interfaces.Unsigned_32 := Address;
      Done       : Natural := 0;
      Got        : Natural;
   begin
      while Done < Buffer'Length loop
         pragma Loop_Invariant (Valid (T));
         pragma Loop_Invariant (Done <= Buffer'Length);
         pragma Loop_Invariant
           (Interfaces.Unsigned_64 (At_Address) = Interfaces.Unsigned_64 (Address) + Interfaces.Unsigned_64 (Done));
         pragma Loop_Invariant
           (Interfaces.Unsigned_64 (At_Address) + Interfaces.Unsigned_64 (Buffer'Length - Done)
            <= 2 * Interfaces.Unsigned_64 (T.Die_Size));
         declare
            Die         : constant Die_Index := Die_Index (At_Address / T.Die_Size);
            Die_Address : constant Interfaces.Unsigned_32 := At_Address mod T.Die_Size;
            Left        : constant Natural := Buffer'Length - Done;
            Room        : constant Interfaces.Unsigned_32 := T.Die_Size - Die_Address;
            Transfer    : constant Natural :=
              (if Interfaces.Unsigned_64 (Left) <= Interfaces.Unsigned_64 (Room) then Left else Natural (Room));
         begin
            Select_Die (D, T, Die);
            Die_Read (D, Die, T.Dies (Die), Die_Address,
                      Buffer (Buffer'First + Done .. Buffer'First + Done + Transfer - 1), Got);
            if Got < Transfer then
               Count := Done + Got;
               return;
            end if;
            At_Address := At_Address + Interfaces.Unsigned_32 (Transfer);
            Done := Done + Transfer;
         end;
      end loop;
      Count := Buffer'Length;
   end Read_Bytes;

end Adaflight.Flash_Device.W25M;
