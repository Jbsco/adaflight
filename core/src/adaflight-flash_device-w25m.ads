--  The W25M stacked-die flash chips: the W25M512, two W25Q256 NOR dies, and
--  the W25M02G, two W25N01GV NAND dies, behind one select pin. Identification
--  selects each die and identifies it with its own driver, and the chip's
--  geometry is the first die's with twice its blocks. Each operation selects
--  the die of its address, by the die select command when another die was
--  selected last, and hands the operation to that die's driver at the
--  address within the die. A program's begin hands the die its whole address,
--  and its continuation and finish go to the die the begin selected. A read
--  that spans both dies reads from each in turn.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

--  The chip's SPI device: a sent transfer and the wait for the bus, and each
--  die's identification by the NOR or NAND driver and its operations, given
--  the die's number.
generic
   type SPI_Device is limited private;
   with procedure Send (D : in out SPI_Device; Tx : Byte_Array);
   with procedure Wait (D : in out SPI_Device);
   with procedure Die_Identify_NOR
     (Die : Natural; F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean);
   with procedure Die_Identify_NAND
     (Die : Natural; F : in out Device; JEDEC : Interfaces.Unsigned_32; OK : out Boolean);
   with procedure Die_Configure
     (D : in out SPI_Device; Die : Natural; F : in out Device; Flags : Interfaces.Unsigned_32);
   with procedure Die_Is_Ready (D : in out SPI_Device; Die : Natural; F : in out Device; Ready : out Boolean);
   with procedure Die_Wait_For_Ready (D : in out SPI_Device; Die : Natural; F : in out Device; Ready : out Boolean);
   with procedure Die_Erase_Sector
     (D : in out SPI_Device; Die : Natural; F : in out Device; Address : Interfaces.Unsigned_32);
   with procedure Die_Erase_Completely (D : in out SPI_Device; Die : Natural; F : in out Device);
   with procedure Die_Program_Begin
     (Die : Natural; F : in out Device; Address : Interfaces.Unsigned_32; Has_Callback : Boolean);
   with procedure Die_Program_Continue
     (D : in out SPI_Device; Die : Natural; F : in out Device; Data_1 : Byte_Array; Data_2 : Byte_Array;
      Count : Natural; Written : out Interfaces.Unsigned_32);
   with procedure Die_Program_Finish (Die : Natural; F : in out Device);
   with procedure Die_Read
     (D : in out SPI_Device; Die : Natural; F : in out Device; Address : Interfaces.Unsigned_32;
      Buffer : in out Byte_Array; Count : out Natural);
package Adaflight.Flash_Device.W25M with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   W25M512_JEDEC : constant Interfaces.Unsigned_32 := 16#EF_71_19#;
   W25M02G_JEDEC : constant Interfaces.Unsigned_32 := 16#EF_AB_21#;
   Memory_Mapped : constant Interfaces.Unsigned_32 := 1;

   subtype Die_Index is Natural range 0 .. 1;
   type Die_Devices is array (Die_Index) of Device;

   --  The dies, how many there are and the bytes of each, the die selected
   --  last or -1 for none, and the die and address within it of the last
   --  program's begin.
   type Stack is record
      Dies          : Die_Devices;
      Die_Count     : Natural range 0 .. 2 := 0;
      Die_Size      : Interfaces.Unsigned_32 := 0;
      Active_Die    : Integer range -1 .. 1 := -1;
      Write_Die     : Die_Index := 0;
      Write_Address : Interfaces.Unsigned_32 := 0;
   end record;

   function Valid (T : Stack) return Boolean is (T.Die_Count = 2 and then T.Die_Size in 1 .. 2 ** 30);

   function Within (T : Stack; Address : Interfaces.Unsigned_32) return Boolean is
     (Valid (T) and then Address / T.Die_Size < 2);

   procedure Identify
     (D : in out SPI_Device; F : in out Device; T : in out Stack; JEDEC : Interfaces.Unsigned_32; OK : out Boolean);

   procedure Configure (D : in out SPI_Device; T : in out Stack; Flags : Interfaces.Unsigned_32);

   procedure Is_Ready (D : in out SPI_Device; T : in out Stack; Ready : out Boolean);

   procedure Wait_For_Ready (D : in out SPI_Device; T : in out Stack; Ready : out Boolean);

   procedure Erase_Sector (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32)
     with Pre => Within (T, Address);

   procedure Erase_Completely (D : in out SPI_Device; T : in out Stack);

   procedure Page_Program_Begin
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Has_Callback : Boolean)
     with Pre => Within (T, Address);

   procedure Page_Program_Continue
     (D : in out SPI_Device; T : in out Stack; Data_1 : Byte_Array; Data_2 : Byte_Array; Count : Natural;
      Written : out Interfaces.Unsigned_32);

   procedure Page_Program_Finish (T : in out Stack);

   procedure Page_Program
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Data : Byte_Array;
      Has_Callback : Boolean)
     with Pre => Within (T, Address);

   --  Count is the bytes the die reads brought, up to the first one that
   --  brought fewer than asked.
   procedure Read_Bytes
     (D : in out SPI_Device; T : in out Stack; Address : Interfaces.Unsigned_32; Buffer : in out Byte_Array;
      Count : out Natural)
     with Pre => Valid (T)
                 and then Interfaces.Unsigned_64 (Address) + Interfaces.Unsigned_64 (Buffer'Length)
                          <= 2 * Interfaces.Unsigned_64 (T.Die_Size);

   function Get_Geometry (F : Device) return Geometry is (F.Map);

end Adaflight.Flash_Device.W25M;
