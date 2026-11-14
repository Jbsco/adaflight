--  A storage that is ready, takes writes and reads as zeros, the shape the
--  mass storage engine's proof takes.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.Mass_Storage_Steps with SPARK_Mode is

   procedure Start_Storage
     with Global => null;

   procedure Capacity (Blocks : out Interfaces.Unsigned_32; OK : out Boolean)
     with Global => null;

   procedure Ready (OK : out Boolean)
     with Global => null;

   procedure Write_Protected (Yes : out Boolean)
     with Global => null;

   procedure Read_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : in out Adaflight.Bytes.Byte_Array; OK : out Boolean)
     with Global => null;

   procedure Write_Blocks
     (First : Interfaces.Unsigned_32; Count : Natural; Data : Adaflight.Bytes.Byte_Array; OK : out Boolean)
     with Global => null;

end Adaflight.Mass_Storage_Steps;
