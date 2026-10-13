--  MAVLink 2 framing for the messages the flight controller sends: payload
--  fields put in the library's wire order, the payload's trailing zeros
--  trimmed, the link's sequence number, the system and component ids, and
--  the checksum with the message's CRC extra.
with Interfaces;

package Adaflight.MAVLink_Frames with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Max_Payload : constant := 255;
   subtype Payload_Index is Natural range 0 .. Max_Payload - 1;
   type Payload is array (Payload_Index) of Unsigned_8;

   subtype Message_Id is Natural range 0 .. 2 ** 24 - 1;

   type Byte_Buffer is array (Positive range <>) of Unsigned_8;

   System_Id    : constant := 1;
   Component_Id : constant := 1;

   procedure Put_U8 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_8)
     with Global => null;

   procedure Put_U16 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_16)
     with Global => null, Pre => At_Byte <= Max_Payload - 2;

   procedure Put_U32 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_32)
     with Global => null, Pre => At_Byte <= Max_Payload - 4;

   procedure Put_U64 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_64)
     with Global => null, Pre => At_Byte <= Max_Payload - 8;

   procedure Put_F32 (P : in out Payload; At_Byte : Payload_Index; V : Float)
     with Global => null, Pre => At_Byte <= Max_Payload - 4;

   --  The payload's first Max_Len bytes framed after the buffer's Length
   --  bytes, the sequence number advanced; a frame that does not fit is
   --  dropped.
   procedure Frame
     (Seq       : in out Unsigned_8;
      Data      : in out Byte_Buffer;
      Length    : in out Natural;
      Id        : Message_Id;
      CRC_Extra : Unsigned_8;
      P         : Payload;
      Max_Len   : Positive)
     with Global => null,
          Pre    => Data'First = 1 and then Length <= Data'Last and then Max_Len <= Max_Payload,
          Post   => Length <= Data'Last;

end Adaflight.MAVLink_Frames;
