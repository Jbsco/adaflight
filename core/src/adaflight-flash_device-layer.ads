--  The flash layer over an SPI flash chip driver: the select pin before
--  initialization, the chip's identification on a 5 MHz clock 50 ms after
--  the bus attaches, its configuration, the partition table with the flash
--  filesystem over the chip's sectors, and the calls the flash filesystem
--  makes, with a sector erase that waits for the chip and programs trimmed
--  at the end of the page.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type SPI_Device is limited private;
   with procedure Preinit_CS (D : in out SPI_Device; Tag : Byte);
   with procedure CS_Free (D : in out SPI_Device; Free : out Boolean);
   with procedure Attach_Bus (D : in out SPI_Device; Instance : Byte; OK : out Boolean);
   with procedure Prepare_CS (D : in out SPI_Device);
   with procedure Divider (D : in out SPI_Device; Hz : Interfaces.Unsigned_32; Divisor : out Interfaces.Unsigned_16);
   with procedure Set_Divisor (D : in out SPI_Device; Divisor : Interfaces.Unsigned_16);
   with procedure Delay_Ms (D : in out SPI_Device; Ms : Natural);
   with procedure Read_Id (D : in out SPI_Device; Response : out Byte_Array);
   with procedure Chip_Identify (F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean);
   with procedure Chip_Configure (D : in out SPI_Device; F : in out Device; Flags : Interfaces.Unsigned_32);
   with procedure Chip_Is_Ready (D : in out SPI_Device; F : in out Device; Ready : out Boolean);
   with procedure Chip_Wait_For_Ready (D : in out SPI_Device; F : in out Device);
   with procedure Chip_Erase_Sector (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32);
   with procedure Chip_Erase_Completely (D : in out SPI_Device; F : in out Device);
   with procedure Chip_Program_Begin (F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean);
   with procedure Chip_Program_Continue
     (D : in out SPI_Device; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32);
   with procedure Chip_Program
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean);
   with procedure Chip_Read
     (D : in out SPI_Device; F : in out Device; Address : Interfaces.Unsigned_32; Buffer : out Byte_Array);
package Adaflight.Flash_Device.Layer with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Unknown_Partition    : constant Byte := 0;
   Flash_FS_Partition   : constant Byte := 2;
   Bad_Block_Partition  : constant Byte := 3;

   Max_Partitions : constant := 6;
   subtype Partition_Index is Natural range 0 .. Max_Partitions - 1;

   --  The type is the raw byte a caller set, the unknown type 0 for an
   --  empty entry.
   type Partition is record
      Kind         : Byte := Unknown_Partition;
      Start_Sector : Interfaces.Unsigned_16 := 0;
      End_Sector   : Interfaces.Unsigned_16 := 0;
   end record;

   type Partition_List is array (Partition_Index) of Partition;

   --  The select pin's tag and the bus, 1 for the first, 0 for none.
   type Flash_Config is record
      CS_Tag  : Byte := 0;
      SPI_Bus : Byte := 0;
   end record;

   --  The chip, the partitions, and whether a chip answered.
   type Flash is record
      Chip       : Device;
      Partitions : Partition_List;
      Count      : Natural range 0 .. Max_Partitions - 1 := 0;
      Have       : Boolean := False;
   end record;

   procedure Preinit (D : in out SPI_Device; C : Flash_Config);

   procedure Init (D : in out SPI_Device; L : in out Flash; C : Flash_Config);

   function Get_Geometry (L : Flash) return Geometry is (if L.Have then L.Chip.Map else (others => <>));

   procedure Is_Ready (D : in out SPI_Device; L : in out Flash; Ready : out Boolean);

   procedure Wait_For_Ready (D : in out SPI_Device; L : in out Flash);

   procedure Erase_Sector (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32);

   procedure Erase_Completely (D : in out SPI_Device; L : in out Flash);

   procedure Page_Program_Begin (L : in out Flash; Address : Interfaces.Unsigned_32; Has_Callback : Boolean);

   --  The buffers trimmed to the room left in the page, the first one alone
   --  when it fills it; Size_1 and Size_2 return the trimmed lengths.
   procedure Page_Program_Continue
     (D : in out SPI_Device; L : in out Flash; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32; Size_1 : out Natural; Size_2 : out Natural)
     with Pre => L.Chip.Map.Page_Size > 0;

   procedure Page_Program
     (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean);

   procedure Read_Bytes
     (D : in out SPI_Device; L : in out Flash; Address : Interfaces.Unsigned_32; Buffer : out Byte_Array);

   --  The index of the first partition of a type, empty ones being of the
   --  unknown type, or -1.
   function Find_By_Type (L : Flash; Kind : Natural) return Integer
     with Global => null, Post => Find_By_Type'Result in -1 .. Max_Partitions - 1;

   procedure Find_By_Index (L : Flash; Index : Natural; Found : out Boolean; P : out Partition)
     with Global => null;

   --  The partition of a type, a new one in the next free entry while fewer
   --  than five are in use, with the sectors cut to 16 bits.
   procedure Partition_Set
     (L : in out Flash; Kind : Byte; Start_Sector : Interfaces.Unsigned_32; End_Sector : Interfaces.Unsigned_32)
     with Global => null;

   function Partition_Count (L : Flash) return Natural is (L.Count);

   --  A type's name padded to nine characters, empty past the last type.
   function Type_Name (Kind : Natural) return String
     with Global => null, Post => Type_Name'Result'Length in 0 | 9;

end Adaflight.Flash_Device.Layer;
