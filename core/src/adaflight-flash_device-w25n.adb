package body Adaflight.Flash_Device.W25N with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Device_Reset_Instruction     : constant Byte := 16#FF#;
   Write_Enable_Instruction     : constant Byte := 16#06#;
   Block_Erase_Instruction      : constant Byte := 16#D8#;
   Data_Load_Instruction        : constant Byte := 16#02#;
   Random_Data_Load_Instruction : constant Byte := 16#84#;
   Program_Execute_Instruction  : constant Byte := 16#10#;
   Page_Data_Read_Instruction   : constant Byte := 16#13#;
   Read_Data_Instruction        : constant Byte := 16#03#;
   Protection_Register          : constant Byte := 16#A0#;
   Configuration_Register       : constant Byte := 16#B0#;
   Status_Register              : constant Byte := 16#C0#;
   ECC_Enable                   : constant Byte := 16#10#;
   Busy_Flag                    : constant Byte := 16#01#;
   ECC_Mask                     : constant Byte := 16#30#;
   Page_Read_Timeout_Ms         : constant := 2;
   Page_Program_Timeout_Ms      : constant := 2;
   Block_Erase_Timeout_Ms       : constant := 15;
   Reset_Timeout_Ms             : constant := 2;
   No_Page                      : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;

   type Chip is record
      JEDEC              : Interfaces.Unsigned_32;
      Max_Read_MHz       : Interfaces.Unsigned_16;
      Blocks             : Interfaces.Unsigned_16;
      Replacement_Blocks : Natural range 0 .. 40;
      Read_Status        : Byte;
      Write_Status       : Byte;
      Buffer_Read_Mode   : Byte;
      Dummy_Byte         : Boolean;
   end record;

   type Chip_Table is array (Positive range <>) of Chip;

   Chips : constant Chip_Table :=
     ((16#EF_AA_21#, 100, 1024, 20, 16#05#, 16#01#, 16#02#, True),
      (16#EF_AA_22#, 100, 2048, 20, 16#05#, 16#01#, 16#02#, True),
      (16#C2_26_03#, 80, 2048, 40, 16#0F#, 16#1F#, 16#00#, False));

   Enable : constant Segment :=
     (Source => Command, Bytes => (Write_Enable_Instruction, others => 0), Length => 1, Receive => False,
      Negate_CS => True, After => Write_Enabled);

   Linked : constant Segment := (Source => Link, Bytes => (others => 0), Length => 0, Receive => False,
                                 Negate_CS => True, After => None);

   No_Bytes : constant Byte_Array (1 .. 0) := (others => 0);

   function Poll (F : Device) return Segment is
     (Source => Command, Bytes => (F.NAND.Read_Status, Status_Register, others => 0), Length => 3, Receive => True,
      Negate_CS => True, After => Ready_Poll)
     with Global => null;

   procedure Set_Timeout (D : in out SPI_Device; F : in out Device; Ms : Interfaces.Unsigned_32) is
      Now : Interfaces.Unsigned_32;
   begin
      Millis (D, Now);
      F.Timeout_At := Now + Ms;
   end Set_Timeout;

   procedure One_Byte_Command (D : in out SPI_Device; Instruction : Byte) is
   begin
      Send (D, (0 => Instruction));
      Wait (D);
   end One_Byte_Command;

   procedure Page_Address_Command (D : in out SPI_Device; Instruction : Byte; Page : Interfaces.Unsigned_32) is
      High : constant Byte := Byte (Page / 2 ** 16 mod 256);
   begin
      Send (D, (Instruction, High, Byte (Page / 2 ** 8 mod 256), Byte (Page mod 256)));
      Wait (D);
   end Page_Address_Command;

   procedure Read_Register (D : in out SPI_Device; F : Device; Register : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 2);
   begin
      Wait (D);
      Exchange (D, (F.NAND.Read_Status, Register, 0), Rx);
      Wait (D);
      Value := Rx (2);
   end Read_Register;

   procedure Write_Register (D : in out SPI_Device; F : Device; Register : Byte; Value : Byte) is
   begin
      Wait (D);
      Send (D, (F.NAND.Write_Status, Register, Value));
      Wait (D);
   end Write_Register;

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
      Read_Register (D, F, Status_Register, Status);
      F.Could_Be_Busy := (Status and Busy_Flag) /= 0;
      Ready := not F.Could_Be_Busy;
   end Is_Ready;

   procedure Wait_For_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean) is
      Now : Interfaces.Unsigned_32;
   begin
      loop
         Is_Ready (D, F, Ready);
         exit when Ready;
         Millis (D, Now);
         if Now - F.Timeout_At < 2 ** 31 then
            return;
         end if;
      end loop;
      F.Timeout_At := 0;
   end Wait_For_Ready;

   procedure Device_Reset (D : in out SPI_Device; F : in out Device) is
      Ignored : Boolean;
   begin
      One_Byte_Command (D, Device_Reset_Instruction);
      Set_Timeout (D, F, Reset_Timeout_Ms);
      Wait_For_Ready (D, F, Ignored);
      Write_Register (D, F, Protection_Register, 0);
      Write_Register (D, F, Configuration_Register, ECC_Enable or F.NAND.Buffer_Read_Mode * 4);
   end Device_Reset;

   procedure Write_Enable (D : in out SPI_Device; F : in out Device) is
   begin
      One_Byte_Command (D, Write_Enable_Instruction);
      F.Could_Be_Busy := True;
   end Write_Enable;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean) is
   begin
      for C of Chips loop
         if C.JEDEC = JEDEC then
            F.NAND.Dummy_Byte := C.Dummy_Byte;
            F.NAND.Read_Status := C.Read_Status;
            F.NAND.Write_Status := C.Write_Status;
            F.Max_Read_Clock_Hz := Interfaces.Unsigned_32 (C.Max_Read_MHz) * 1_000_000;
            F.Map.Sectors := C.Blocks;
            F.Map.Pages_Per_Sector := Pages_Per_Block;
            F.Map.Page_Size := Page_Bytes;
            F.NAND.Replacement_Blocks := C.Replacement_Blocks;
            F.NAND.Buffer_Read_Mode := C.Buffer_Read_Mode;
            F.Map.Kind := NAND;
            F.Map.Sector_Size := Pages_Per_Block * Page_Bytes;
            F.Map.Total_Size := F.Map.Sector_Size * Interfaces.Unsigned_32 (C.Blocks);
            F.NAND.Bad_Block_First := C.Blocks - Interfaces.Unsigned_16 (C.Replacement_Blocks + 1);
            F.NAND.Bad_Block_Last := F.NAND.Bad_Block_First + Interfaces.Unsigned_16 (C.Replacement_Blocks);
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
      Device_Reset (D, F);
      Divider (D, F.Max_Read_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
   end Configure;

   procedure Erase_Sector (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32) is
      Ignored : Boolean;
   begin
      Wait_For_Ready (D, F, Ignored);
      Write_Enable (D, F);
      Page_Address_Command (D, Block_Erase_Instruction, Address / Page_Bytes);
      Set_Timeout (D, F, Block_Erase_Timeout_Ms);
   end Erase_Sector;

   procedure Erase_Completely (D : in out SPI_Device; F : in out Device) is
   begin
      for Block in 0 .. Natural (F.Map.Sectors) - 1 loop
         Erase_Sector (D, F, Interfaces.Unsigned_32 (Block) * Pages_Per_Block * Page_Bytes);
      end loop;
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
      pragma Unreferenced (Data_2);
      Q      : Sequence := (others => (others => <>));
      Load   : Byte := Data_Load_Instruction;
      Column : Interfaces.Unsigned_32;
      Page   : Interfaces.Unsigned_32;
   begin
      if Count < 1 then
         if F.Has_Callback then
            Report_Written (D, 0);
         end if;
         Written := 0;
         return;
      end if;
      Wait (D);
      if F.NAND.Buffer_Dirty then
         Load := Random_Data_Load_Instruction;
      else
         F.NAND.Program_Start := F.Current_Write_Address;
         F.NAND.Program_Load := F.Current_Write_Address;
      end if;
      Column := F.NAND.Program_Load mod Page_Bytes;
      Q (0) := Poll (F);
      Q (1) := Enable;
      Q (2) :=
        (Source => Command, Bytes => (Load, Byte (Column / 256), Byte (Column mod 256), others => 0), Length => 3,
         Receive => False, Negate_CS => False, After => None);
      Q (3) := Linked;
      Q (4) :=
        (Source => Buffer_1, Bytes => (others => 0), Length => Data_1'Length, Receive => False, Negate_CS => True,
         After => None);
      F.NAND.Buffer_Dirty := True;
      F.NAND.Program_Load := F.NAND.Program_Load + Interfaces.Unsigned_32 (Data_1'Length);
      if F.NAND.Program_Load mod Page_Bytes = 0 then
         F.NAND.Current_Page := F.NAND.Program_Start / Page_Bytes;
         Page := F.NAND.Current_Page;
         Q (5) := Linked;
         Q (6) := Poll (F);
         Q (7) := Enable;
         Q (8) :=
           (Source => Command,
            Bytes => (Program_Execute_Instruction, Byte (Page / 2 ** 16 mod 256), Byte (Page / 2 ** 8 mod 256),
                      Byte (Page mod 256), 0),
            Length => 4, Receive => False, Negate_CS => True, After => Write_Done);
         F.NAND.Buffer_Dirty := False;
         F.NAND.Program_Start := F.NAND.Program_Load;
      else
         Q (4).After := Write_Done;
      end if;
      F.Bytes_Written := Interfaces.Unsigned_32 (Data_1'Length);
      Run (D, F, Q, (if F.Could_Be_Busy then 0 else 1), Data_1);
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

   procedure Program_Execute (D : in out SPI_Device; F : in out Device; Page : Interfaces.Unsigned_32) is
      Ignored : Boolean;
   begin
      Wait_For_Ready (D, F, Ignored);
      Page_Address_Command (D, Program_Execute_Instruction, Page);
      Set_Timeout (D, F, Page_Program_Timeout_Ms);
   end Program_Execute;

   procedure Flush (D : in out SPI_Device; F : in out Device) is
   begin
      if F.NAND.Buffer_Dirty then
         F.NAND.Current_Page := F.NAND.Program_Start / Page_Bytes;
         Program_Execute (D, F, F.NAND.Program_Start / Page_Bytes);
         F.NAND.Buffer_Dirty := False;
      end if;
   end Flush;

   procedure Read_Bytes
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural)
   is
      Target    : constant Interfaces.Unsigned_32 := Address / Page_Bytes;
      Was_Dirty : constant Boolean := F.NAND.Buffer_Dirty;
      Column    : constant Interfaces.Unsigned_32 := Address mod Page_Bytes;
      Transfer  : Natural;
      Ready     : Boolean;
      Status    : Byte;
      Q         : Sequence := (others => (others => <>));
   begin
      Count := 0;
      Flush (D, F);
      if Was_Dirty or else F.NAND.Current_Page /= Target then
         Wait_For_Ready (D, F, Ready);
         if not Ready then
            return;
         end if;
         F.NAND.Current_Page := No_Page;
         Page_Address_Command (D, Page_Data_Read_Instruction, Target);
         Set_Timeout (D, F, Page_Read_Timeout_Ms);
         Wait_For_Ready (D, F, Ready);
         if not Ready then
            return;
         end if;
         F.NAND.Current_Page := Target;
      end if;
      Transfer :=
        (if Buffer'Length > Natural (Page_Bytes - Column) then Natural (Page_Bytes - Column) else Buffer'Length);
      Q (0) := Poll (F);
      Q (1) :=
        (Source => Command, Bytes => (Read_Data_Instruction, Byte (Column / 256), Byte (Column mod 256), others => 0),
         Length => 4, Receive => False, Negate_CS => False, After => None);
      Q (2) :=
        (Source => Read_Data, Bytes => (others => 0), Length => Transfer, Receive => True, Negate_CS => True,
         After => None);
      Run_Read (D, F, Q, 0, Buffer (Buffer'First .. Buffer'First + Transfer - 1));
      Wait (D);
      Set_Timeout (D, F, Page_Read_Timeout_Ms);
      Wait_For_Ready (D, F, Ready);
      if not Ready then
         return;
      end if;
      Read_Register (D, F, Status_Register, Status);
      if (Status and ECC_Mask) / 16 >= 2 then
         Device_Reset (D, F);
      end if;
      Count := Transfer;
   end Read_Bytes;

end Adaflight.Flash_Device.W25N;
