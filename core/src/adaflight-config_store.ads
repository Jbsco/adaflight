--  Config store: the storage image of the parameter groups. A header with
--  the storage version and the magic byte, one record per group with its
--  size, group number, version and class, a zero terminator, then the CRC
--  over all of it, inverted and big-endian, which makes the CRC of the whole
--  image a constant. Loading resets each group to its defaults and takes its
--  stored bytes only at the matching version, as many as the group holds.
--  Saving writes only when the image is invalid or a group has changed since
--  its hash was taken. Bytes past the region read as erased.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.Config_Store with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   Storage_Version : constant := 178;
   Magic           : constant := 16#BE#;
   Header_Size     : constant := 2;
   Record_Header   : constant := 6;
   Trailer_Size    : constant := 4;
   CRC_Start       : constant Unsigned_16 := 16#FFFF#;
   CRC_Check       : constant Unsigned_16 := 16#1D0F#;
   System_Class    : constant := 0;
   Class_Mask      : constant := 3;
   Erased          : constant Byte := 16#FF#;

   Max_Group_Size : constant := 16#0FFF#;
   Max_Groups     : constant := 256;
   Max_Image      : constant := 2 ** 20;

   subtype Group_Number is Unsigned_16 range 0 .. 16#0FFF#;
   subtype Group_Version is Interfaces.Unsigned_8 range 0 .. 15;
   subtype Group_Size is Natural range 0 .. Max_Group_Size;

   --  A group's number and version, and where its bytes lie in the
   --  configuration data.
   type Group is record
      Number  : Group_Number := 0;
      Version : Group_Version := 0;
      Offset  : Natural := 0;
      Size    : Group_Size := 0;
   end record;
   type Registry is array (Positive range <>) of Group;
   type Hash_List is array (Positive range <>) of Unsigned_32;

   --  Every group's bytes lie inside the data.
   function Within (Reg : Registry; Data : Byte_Array) return Boolean is
     (Reg'Length <= Max_Groups and then Data'Length <= Max_Image
      and then (for all G of Reg => G.Offset <= Data'Length and then G.Size <= Data'Length - G.Offset));

   --  The image's byte at an offset, erased past its end.
   function Byte_At (Image : Byte_Array; At_Offset : Natural) return Byte is
     (if At_Offset < Image'Length then Image (Image'First + At_Offset) else Erased)
     with Pre => Image'Length <= Max_Image;

   --  The image's little-endian 16-bit value at an offset.
   function U16_At (Image : Byte_Array; At_Offset : Natural) return Natural is
     (Natural (Byte_At (Image, At_Offset)) + 256 * Natural (Byte_At (Image, At_Offset + 1)))
     with Pre  => Image'Length <= Max_Image and then At_Offset < Natural'Last,
          Post => U16_At'Result <= 65_535;

   function Version_Valid (Image : Byte_Array) return Boolean is
     (Image'Length >= 1 and then Image (Image'First) = Storage_Version);

   --  Whether the image has the magic byte, records that each end before the
   --  region does with at least their own header, a terminator, and a CRC
   --  that makes the whole image's CRC the check value; Size is the image's
   --  length through its CRC.
   procedure Check_Structure (Image : Byte_Array; Valid : out Boolean; Size : out Natural)
     with Pre => Image'Length in Header_Size .. Max_Image;

   --  The offset of the first record of a group and class in a scan that
   --  stops where the structure check would, or zero.
   function Find (Image : Byte_Array; Number : Group_Number; Class : Interfaces.Unsigned_8) return Natural
     with Pre  => Image'Length in Header_Size .. Max_Image,
          Post => Find'Result = 0
                  or else (Find'Result in Header_Size .. Image'Length - 1
                           and then U16_At (Image, Find'Result) >= Record_Header
                           and then Find'Result + U16_At (Image, Find'Result) < Image'Length);

   --  Every group reset to its defaults, then given its stored bytes when a
   --  record of the system class has the group's version, as many as the
   --  group holds; each hash then taken over the group's bytes. Success is
   --  false when a group has no record or a record of another version.
   procedure Load
     (Image : Byte_Array; Reg : Registry; Defaults : Byte_Array; Data : in out Byte_Array; Hashes : out Hash_List;
      Success : out Boolean)
     with Pre => Image'Length in Header_Size .. Max_Image and then Defaults'Length = Data'Length
                 and then Within (Reg, Data) and then Hashes'Length = Reg'Length;

   --  Whether a save writes: the image's version or structure is invalid,
   --  or a group's bytes no longer match its hash.
   function Dirty (Image : Byte_Array; Reg : Registry; Data : Byte_Array; Hashes : Hash_List) return Boolean
     with Pre => Image'Length in Header_Size .. Max_Image and then Within (Reg, Data)
                 and then Hashes'Length = Reg'Length;

   --  The image's length for the groups.
   function Image_Length (Reg : Registry) return Natural
     with Pre  => Reg'Length <= Max_Groups,
          Post => Image_Length'Result <= Header_Size + Max_Groups * (Record_Header + Max_Group_Size) + Trailer_Size;

   --  When dirty, the region zeroed and the image of every group written:
   --  header, records, terminator and CRC. Written tells whether it wrote,
   --  and Fits is false, with nothing written, when the image is longer than
   --  the region.
   procedure Save
     (Reg : Registry; Data : Byte_Array; Hashes : Hash_List; Image : in out Byte_Array; Written : out Boolean;
      Fits : out Boolean)
     with Pre  => Image'Length in Header_Size .. Max_Image and then Within (Reg, Data)
                  and then Hashes'Length = Reg'Length,
          Post => (if not Written then Image = Image'Old);

end Adaflight.Config_Store;
