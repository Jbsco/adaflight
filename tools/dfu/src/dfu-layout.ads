with Interfaces;

--  Bootloader descriptors: the memory layout string of each alternate setting and the configuration
--  descriptor's DFU interface.
package DFU.Layout with Pure, SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Max_Text : constant := 255;
   Max_Name : constant := 32;
   Max_Pages : constant := 2048;
   subtype Page_Count is Natural range 0 .. Max_Pages;
   subtype Page_Index is Page_Count range 1 .. Max_Pages;
   type Address_Array is array (Page_Index) of Address;

   --  A memory region: its name and the first and last address of each page.
   type Memory is record
      Name   : String (1 .. Max_Name) := (others => ' ');
      Length : Natural range 0 .. Max_Name := 0;
      Pages  : Page_Count := 0;
      First  : Address_Array := (others => 0);
      Last   : Address_Array := (others => 0);
   end record;

   function Contiguous (M : Memory) return Boolean is
     (M.Pages >= 1
      and then (for all P in 1 .. M.Pages => M.First (P) <= M.Last (P))
      and then (for all P in 2 .. M.Pages => M.Last (P - 1) < Address'Last and then M.First (P) = M.Last (P - 1) + 1)
      and then (for all P in 1 .. M.Pages => M.First (1) <= M.First (P) and then M.Last (P) <= M.Last (M.Pages)));

   --  Reads a layout such as "@Internal Flash  /0x08000000/04*016Kg,01*064Kg,07*128Kg": the region's name,
   --  its start, and groups of pages, each a count and a size in bytes, kilobytes (K) or megabytes (M).
   --  Characters outside the printable range are dropped first.
   procedure Parse (Text : String; M : out Memory; Ok : out Boolean)
   with Global => null, Pre => Text'Length <= Max_Text, Post => (if Ok then Contiguous (M));

   function Is_Internal_Flash (M : Memory) return Boolean
   with Global => null;

   --  The string descriptor indexes of interface 0's alternate settings and the transfer size of the
   --  DFU functional descriptor, zero when the configuration gives none.
   Max_Alternates : constant := 8;
   subtype Alternate_Count is Natural range 0 .. Max_Alternates;
   type String_Indexes is array (1 .. Max_Alternates) of Byte;

   type Interface_Info is record
      Alternates    : Alternate_Count := 0;
      Strings       : String_Indexes := (others => 0);
      Transfer_Size : Interfaces.Unsigned_16 := 0;
   end record;

   procedure Parse_Configuration (Data : Byte_Array; Info : out Interface_Info)
   with Global => null;

   --  The text of a string descriptor, its UTF-16 characters outside the printable range dropped.
   procedure Decode_String (Data : Byte_Array; Text : out String; Length : out Natural)
   with Global => null, Pre => Text'First = 1 and then Text'Length = Max_Text, Post => Length <= Max_Text;

end DFU.Layout;
