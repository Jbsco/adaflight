package body Adaflight.Flash_Device.M25P16 with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   Read_Instruction         : constant Byte := 16#03#;
   Read_Status_Instruction  : constant Byte := 16#05#;
   Write_Enable_Instruction : constant Byte := 16#06#;
   Program_Instruction      : constant Byte := 16#02#;
   Sector_Erase_Instruction : constant Byte := 16#D8#;
   Bulk_Erase_Instruction   : constant Byte := 16#C7#;
   Four_Byte_Instruction    : constant Byte := 16#B7#;
   Large_Bytes              : constant := 16 * 1024 * 1024;

   type Chip is record
      JEDEC            : Interfaces.Unsigned_32;
      Max_Clock_MHz    : Interfaces.Unsigned_16;
      Max_Read_MHz     : Interfaces.Unsigned_16;
      Sectors          : Interfaces.Unsigned_16;
      Pages_Per_Sector : Interfaces.Unsigned_16;
   end record;

   type Chip_Table is array (Positive range <>) of Chip;

   Chips : constant Chip_Table :=
     ((16#C2_20_16#, 86, 33, 64, 256), (16#C2_20_17#, 86, 33, 128, 256), (16#C2_20_19#, 80, 50, 512, 256),
      (16#C2_20_18#, 120, 50, 256, 256), (16#20_20_15#, 25, 20, 32, 256), (16#20_BA_17#, 108, 54, 128, 256),
      (16#20_BA_18#, 108, 54, 256, 256), (16#EF_40_14#, 104, 50, 16, 256), (16#EF_40_15#, 104, 50, 32, 256),
      (16#EF_30_16#, 133, 50, 64, 256), (16#EF_40_16#, 133, 50, 64, 256), (16#EF_40_17#, 133, 50, 128, 256),
      (16#EF_70_17#, 133, 50, 128, 256), (16#EF_60_17#, 104, 50, 128, 256), (16#EF_80_17#, 104, 50, 128, 256),
      (16#EF_40_18#, 104, 50, 256, 256), (16#EF_40_20#, 133, 50, 1024, 256), (16#85_20_18#, 133, 80, 256, 256),
      (16#5E_40_18#, 104, 50, 256, 256), (16#EF_70_18#, 66, 50, 256, 256), (16#EF_40_19#, 133, 50, 512, 256),
      (16#01_60_17#, 133, 50, 128, 256), (16#01_60_18#, 133, 50, 256, 256), (16#01_20_18#, 104, 50, 256, 256),
      (16#E0_40_16#, 133, 50, 1024, 16), (16#68_40_17#, 108, 54, 128, 256), (16#20_60_19#, 166, 80, 8192, 16),
      (16#C8_40_15#, 104, 50, 32, 256), (16#BA_60_16#, 104, 50, 64, 256), (16#C8_40_18#, 104, 80, 4096, 16),
      (16#68_40_18#, 104, 50, 256, 256), (16#A1_40_17#, 80, 66, 128, 256), (16#A1_40_18#, 80, 50, 256, 256),
      (16#A1_40_19#, 80, 50, 512, 256), (16#0B_40_18#, 96, 80, 256, 256), (16#C4_60_14#, 104, 104, 16, 256),
      (16#C4_60_15#, 104, 104, 32, 256), (16#C4_60_16#, 90, 90, 64, 256), (16#1C_71_17#, 104, 104, 128, 256),
      (16#1C_71_18#, 104, 104, 256, 256));

   Poll : constant Segment :=
     (Source => Command, Bytes => (Read_Status_Instruction, others => 0), Length => 2, Receive => True,
      Negate_CS => True, After => Ready_Poll);

   Enable : constant Segment :=
     (Source => Command, Bytes => (Write_Enable_Instruction, others => 0), Length => 1, Receive => False,
      Negate_CS => True, After => Write_Enabled);

   No_Bytes : constant Byte_Array (1 .. 0) := (others => 0);

   function Address_Length (F : Device) return Natural is (if F.Large then 5 else 4)
     with Global => null;

   procedure Set_Command_Address (Bytes : in out Command_Bytes; Address : Interfaces.Unsigned_32; Long : Boolean)
     with Global => null
   is
      First : constant Natural := (if Long then 2 else 1);
   begin
      if Long then
         Bytes (1) := Byte (Address / 2 ** 24);
      end if;
      Bytes (First) := Byte (Address / 2 ** 16 mod 256);
      Bytes (First + 1) := Byte (Address / 2 ** 8 mod 256);
      Bytes (First + 2) := Byte (Address mod 256);
   end Set_Command_Address;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean) is
   begin
      for C of Chips loop
         if C.JEDEC = JEDEC then
            F.Max_Clock_Hz := Interfaces.Unsigned_32 (C.Max_Clock_MHz) * 1_000_000;
            F.Max_Read_Clock_Hz := Interfaces.Unsigned_32 (C.Max_Read_MHz) * 1_000_000;
            F.Map.Sectors := C.Sectors;
            F.Map.Pages_Per_Sector := C.Pages_Per_Sector;
            F.Map.Kind := NOR;
            F.Map.Page_Size := Page_Bytes;
            F.Map.Sector_Size := Interfaces.Unsigned_32 (C.Pages_Per_Sector) * Page_Bytes;
            F.Map.Total_Size := F.Map.Sector_Size * Interfaces.Unsigned_32 (C.Sectors);
            F.Could_Be_Busy := True;
            OK := True;
            return;
         end if;
      end loop;
      F.Map.Sectors := 0;
      F.Map.Pages_Per_Sector := 0;
      F.Map.Sector_Size := 0;
      F.Map.Total_Size := 0;
      OK := False;
   end Identify;

   procedure Configure (D : in out SPI_Device; F : in out Device; Flags : Interfaces.Unsigned_32) is
      Divisor : Interfaces.Unsigned_16;
   begin
      if (Flags and Memory_Mapped) /= 0 then
         return;
      end if;
      Divider (D, F.Max_Read_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      if F.Map.Total_Size > Large_Bytes then
         F.Large := True;
         Write (D, (0 => Four_Byte_Instruction));
      end if;
   end Configure;

   procedure Read_Status (D : in out SPI_Device; Status : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Read_Write (D, (Read_Status_Instruction, 0), Rx);
      Status := Rx (1);
   end Read_Status;

   procedure Is_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean) is
      Busy   : Boolean := False;
      Status : Byte;
   begin
      if Uses_DMA (D) then
         Bus_Busy (D, Busy);
      end if;
      if Busy then
         Ready := False;
         return;
      end if;
      if not F.Could_Be_Busy then
         Ready := True;
         return;
      end if;
      Read_Status (D, Status);
      F.Could_Be_Busy := (Status and Write_In_Progress) /= 0;
      Ready := not F.Could_Be_Busy;
   end Is_Ready;

   procedure Wait_For_Ready (D : in out SPI_Device; F : in out Device) is
      Ready : Boolean;
   begin
      loop
         Is_Ready (D, F, Ready);
         exit when Ready;
      end loop;
   end Wait_For_Ready;

   procedure Erase_Sector (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32) is
      Erase : Command_Bytes := (Sector_Erase_Instruction, others => 0);
      Q     : Sequence := (others => (others => <>));
   begin
      Wait (D);
      Set_Command_Address (Erase, Address, F.Large);
      Q (0) := Poll;
      Q (1) := Enable;
      Q (2) :=
        (Source => Command, Bytes => Erase, Length => Address_Length (F), Receive => False, Negate_CS => True,
         After => None);
      Run (D, F, Q, 0, No_Bytes, No_Bytes);
      Wait (D);
   end Erase_Sector;

   procedure Erase_Completely (D : in out SPI_Device; F : in out Device) is
      Q : Sequence := (others => (others => <>));
   begin
      Q (0) := Poll;
      Q (1) := Enable;
      Q (2) :=
        (Source => Command, Bytes => (Bulk_Erase_Instruction, others => 0), Length => 1, Receive => False,
         Negate_CS => True, After => None);
      Run (D, F, Q, 0, No_Bytes, No_Bytes);
      Wait (D);
   end Erase_Completely;

   procedure Page_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean) is
   begin
      F.Has_Callback := Has_Callback;
      F.Current_Write_Address := Address;
   end Page_Program_Begin;

   procedure Page_Program_Continue
     (D : in out SPI_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32)
   is
      Program : Command_Bytes := (Program_Instruction, others => 0);
      Q       : Sequence := (others => (others => <>));
   begin
      Wait (D);
      Set_Command_Address (Program, F.Current_Write_Address, F.Large);
      F.Bytes_Written := Interfaces.Unsigned_32 (Data_1'Length);
      if Count = 1 then
         Q (3) :=
           (Source => Buffer_1, Bytes => (others => 0), Length => Data_1'Length, Receive => False, Negate_CS => True,
            After => Write_Done);
      elsif Count = 2 then
         Q (3) :=
           (Source => Buffer_1, Bytes => (others => 0), Length => Data_1'Length, Receive => False, Negate_CS => False,
            After => None);
         Q (4) :=
           (Source => Buffer_2, Bytes => (others => 0), Length => Data_2'Length, Receive => False, Negate_CS => True,
            After => Write_Done);
         F.Bytes_Written := F.Bytes_Written + Interfaces.Unsigned_32 (Data_2'Length);
      else
         Written := 0;
         return;
      end if;
      Q (0) := Poll;
      Q (1) := Enable;
      Q (2) :=
        (Source => Command, Bytes => Program, Length => Address_Length (F), Receive => False, Negate_CS => False,
         After => None);
      Run (D, F, Q, (if F.Could_Be_Busy then 0 else 1), Data_1, Data_2);
      if not F.Has_Callback then
         Wait (D);
      end if;
      Written := F.Bytes_Written;
   end Page_Program_Continue;

   procedure Page_Program
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean)
   is
      Written : Interfaces.Unsigned_32;
   begin
      Page_Program_Begin (F, Address, Has_Callback);
      Page_Program_Continue (D, F, Data, No_Bytes, 1, Written);
      pragma Unreferenced (Written);
   end Page_Program;

   procedure Read_Bytes
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : out Byte_Array)
   is
      Read    : Command_Bytes := (Read_Instruction, others => 0);
      Q       : Sequence := (others => (others => <>));
      Divisor : Interfaces.Unsigned_16;
   begin
      Wait (D);
      Set_Command_Address (Read, Address, F.Large);
      Q (0) := Poll;
      Q (1) :=
        (Source => Command, Bytes => Read, Length => Address_Length (F), Receive => False, Negate_CS => False,
         After => None);
      Q (2) :=
        (Source => Read_Data, Bytes => (others => 0), Length => Buffer'Length, Receive => True, Negate_CS => True,
         After => None);
      Divider (D, F.Max_Read_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Run_Read (D, F, Q, (if F.Could_Be_Busy then 0 else 1), Buffer);
      Wait (D);
      Divider (D, F.Max_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
   end Read_Bytes;

end Adaflight.Flash_Device.M25P16;
