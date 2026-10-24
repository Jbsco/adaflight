package body Adaflight.Flash_Device.W25Q128FV with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   Enable_Reset_Instruction          : constant Byte := 16#66#;
   Reset_Device_Instruction          : constant Byte := 16#99#;
   Read_Status_1_Instruction         : constant Byte := 16#05#;
   Read_Status_2_Instruction         : constant Byte := 16#35#;
   Write_Status_2_Instruction        : constant Byte := 16#31#;
   Write_Enable_Instruction          : constant Byte := 16#06#;
   Volatile_Write_Enable_Instruction : constant Byte := 16#50#;
   Block_Erase_Instruction           : constant Byte := 16#D8#;
   Chip_Erase_Instruction            : constant Byte := 16#C7#;
   Quad_Read_Instruction             : constant Byte := 16#6B#;
   Quad_Program_Instruction          : constant Byte := 16#32#;
   Quad_Enable                       : constant Byte := 16#02#;
   Read_Dummy_Cycles                 : constant := 8;

   Page_Read_Timeout_Ms    : constant := 1;
   Reset_Timeout_Ms        : constant := 1;
   Block_Erase_Timeout_Ms  : constant := 2000;
   Chip_Erase_Timeout_Ms   : constant := 200_000;

   type Chip is record
      JEDEC   : Interfaces.Unsigned_32;
      Sectors : Interfaces.Unsigned_16;
   end record;

   type Chip_Table is array (Positive range <>) of Chip;

   Chips : constant Chip_Table :=
     ((16#A1_40_17#, 128), (16#EF_40_18#, 256), (16#EF_60_18#, 256), (16#EF_70_18#, 256), (16#68_40_18#, 256),
      (16#A1_40_18#, 256), (16#A1_40_19#, 512), (16#EF_70_15#, 32), (16#EF_40_15#, 32));

   Poll : constant Segment :=
     (Source => Command, Bytes => (Read_Status_1_Instruction, others => 0), Length => 2, Receive => True,
      Negate_CS => True, After => Ready_Poll);

   Enable : constant Segment :=
     (Source => Command, Bytes => (Write_Enable_Instruction, others => 0), Length => 1, Receive => False,
      Negate_CS => True, After => Write_Enabled);

   No_Bytes : constant Byte_Array (1 .. 0) := (others => 0);

   procedure Set_Timeout (D : in out Quad_Device; F : in out Device; Ms : Interfaces.Unsigned_32) is
      Now : Interfaces.Unsigned_32;
   begin
      Millis (D, Now);
      F.Timeout_At := Now + Ms;
   end Set_Timeout;

   procedure One_Byte_Command (D : in out Quad_Device; Instruction : Byte) is
   begin
      Transmit (D, Instruction, No_Bytes);
   end One_Byte_Command;

   procedure Command_With_Address (D : in out Quad_Device; Instruction : Byte; Address : Interfaces.Unsigned_32) is
   begin
      Instruction_With_Address (D, Instruction, Address and 16#FF_FFFF#);
   end Command_With_Address;

   procedure Write_Enable (D : in out Quad_Device) is
   begin
      One_Byte_Command (D, Write_Enable_Instruction);
   end Write_Enable;

   procedure Read_Register (D : in out Quad_Device; Instruction : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 0);
   begin
      Receive (D, Instruction, Rx);
      Value := Rx (0);
   end Read_Register;

   procedure Write_Register (D : in out Quad_Device; Instruction : Byte; Value : Byte) is
   begin
      Transmit (D, Instruction, (0 => Value));
   end Write_Register;

   procedure Has_Timed_Out (D : in out Quad_Device; F : Device; Timed_Out : out Boolean) is
      Now : Interfaces.Unsigned_32;
   begin
      Millis (D, Now);
      Timed_Out := Now - F.Timeout_At < 2 ** 31;
   end Has_Timed_Out;

   procedure Wait_For_Timeout (D : in out Quad_Device; F : in out Device) is
      Timed_Out : Boolean;
   begin
      loop
         Has_Timed_Out (D, F, Timed_Out);
         exit when Timed_Out;
      end loop;
      F.Timeout_At := 0;
   end Wait_For_Timeout;

   procedure Is_Ready (D : in out Quad_Device; Ready : out Boolean) is
      Status : Byte;
   begin
      Read_Register (D, Read_Status_1_Instruction, Status);
      Ready := (Status and Write_In_Progress) = 0;
   end Is_Ready;

   procedure Wait_For_Ready (D : in out Quad_Device; F : in out Device; Ready : out Boolean) is
      Ready_Now : Boolean;
      Timed_Out : Boolean;
   begin
      Ready := True;
      loop
         Is_Ready (D, Ready_Now);
         exit when Ready_Now;
         Has_Timed_Out (D, F, Timed_Out);
         if Timed_Out then
            Ready := False;
            exit;
         end if;
      end loop;
      F.Timeout_At := 0;
   end Wait_For_Ready;

   procedure Device_Reset (D : in out Quad_Device; F : in out Device) is
      Unused_Ready : Boolean;
      Value        : Byte;
   begin
      Wait_For_Ready (D, F, Unused_Ready);
      One_Byte_Command (D, Enable_Reset_Instruction);
      One_Byte_Command (D, Reset_Device_Instruction);
      Set_Timeout (D, F, Reset_Timeout_Ms);
      Wait_For_Timeout (D, F);
      Wait_For_Ready (D, F, Unused_Ready);
      Read_Register (D, Read_Status_2_Instruction, Value);
      if (Value and Quad_Enable) = 0 then
         Read_Register (D, Read_Status_2_Instruction, Value);
         One_Byte_Command (D, Volatile_Write_Enable_Instruction);
         Write_Register (D, Write_Status_2_Instruction, Value or Quad_Enable);
      end if;
   end Device_Reset;

   procedure Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean) is
   begin
      for C of Chips loop
         if C.JEDEC = JEDEC then
            F.Map.Sectors := C.Sectors;
            F.Map.Pages_Per_Sector := Page_Bytes;
            F.Map.Page_Size := Page_Bytes;
            F.Map.Kind := NOR;
            F.Map.Sector_Size := Page_Bytes * Page_Bytes;
            F.Map.Total_Size := F.Map.Sector_Size * Interfaces.Unsigned_32 (C.Sectors);
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

   procedure Configure (D : in out Quad_Device; F : in out Device; Flags : Interfaces.Unsigned_32) is
   begin
      if (Flags and Memory_Mapped) /= 0 then
         return;
      end if;
      Device_Reset (D, F);
   end Configure;

   procedure Erase_Sector (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32) is
      Unused_Ready : Boolean;
   begin
      Wait_For_Ready (D, F, Unused_Ready);
      Write_Enable (D);
      Command_With_Address (D, Block_Erase_Instruction, Address);
      Set_Timeout (D, F, Block_Erase_Timeout_Ms);
   end Erase_Sector;

   procedure Erase_Completely (D : in out Quad_Device; F : in out Device) is
      Unused_Ready : Boolean;
   begin
      Wait_For_Ready (D, F, Unused_Ready);
      Write_Enable (D);
      One_Byte_Command (D, Chip_Erase_Instruction);
      Set_Timeout (D, F, Chip_Erase_Timeout_Ms);
   end Erase_Completely;

   procedure Page_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean) is
   begin
      F.Has_Callback := Has_Callback;
      F.Current_Write_Address := Address;
   end Page_Program_Begin;

   procedure Page_Program_Continue
     (D : in out Quad_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32)
   is
      Program : Command_Bytes := (Quad_Program_Instruction, others => 0);
      Q       : Sequence := (others => (others => <>));
   begin
      if Count = 0 then
         if F.Has_Callback then
            Report_Written (D, 0);
         end if;
         Written := 0;
         return;
      end if;
      Wait (D);
      Program (1) := Byte (F.Current_Write_Address / 2 ** 16 mod 256);
      Program (2) := Byte (F.Current_Write_Address / 2 ** 8 mod 256);
      Program (3) := Byte (F.Current_Write_Address mod 256);
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
      Q (2) := (Source => Command, Bytes => Program, Length => 4, Receive => False, Negate_CS => False, After => None);
      Run (D, F, Q, 0, Data_1, Data_2);
      if not F.Has_Callback then
         Wait (D);
      end if;
      Written := F.Bytes_Written;
   end Page_Program_Continue;

   procedure Page_Program
     (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean)
   is
      Unused_Written : Interfaces.Unsigned_32;
   begin
      Page_Program_Begin (F, Address, Has_Callback);
      Page_Program_Continue (D, F, Data, No_Bytes, 1, Unused_Written);
   end Page_Program;

   procedure Read_Bytes
     (D : in out Quad_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural)
   is
      Ready : Boolean;
      OK    : Boolean;
   begin
      Wait_For_Ready (D, F, Ready);
      if not Ready then
         Count := 0;
         return;
      end if;
      Receive_With_Address (D, Quad_Read_Instruction, Read_Dummy_Cycles, Address, Buffer, OK);
      Set_Timeout (D, F, Page_Read_Timeout_Ms);
      Count := (if OK then Buffer'Length else 0);
   end Read_Bytes;

end Adaflight.Flash_Device.W25Q128FV;
