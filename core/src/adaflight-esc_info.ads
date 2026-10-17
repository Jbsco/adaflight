--  The ESC information reply that the DShot ESC information command asks
--  for: the frame's kind from its version byte, the length the kind has, the
--  checksum over the frame, and the firmware version, subversion and ESC
--  type the kind keeps at its own places.
with Interfaces;

package Adaflight.ESC_Info with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   Frame_Size       : constant := 64;
   Version_Position : constant := 12;
   type Frame is array (0 .. Frame_Size - 1) of Byte;

   type Kind is (KISS_V1, KISS_V2, BLHeli_32);

   function Kind_Of (F : Frame) return Kind is
     (if F (Version_Position) = 254 then BLHeli_32
      elsif F (Version_Position) = 255 then KISS_V2
      else KISS_V1);

   function Length_Of (K : Kind) return Positive is
     (case K is
         when KISS_V1   => 15,
         when KISS_V2   => 21,
         when BLHeli_32 => 64)
     with Post => Length_Of'Result <= Frame_Size;

   --  Whether the last byte of the kind's length is the KISS checksum of the
   --  bytes before it.
   function Checksum_Holds (F : Frame; K : Kind) return Boolean;

   function Firmware (F : Frame; K : Kind) return Byte is
     (if K = KISS_V1 then F (12) else F (13));

   --  KISS v1 keeps a letter in the low five bits of byte 13, from 'a'.
   function Subversion (F : Frame; K : Kind) return Byte is
     (if K = KISS_V1 then (F (13) and 16#1F#) + 97 else F (14));

   function ESC_Type (F : Frame; K : Kind) return Byte is
     (if K = KISS_V1 then Interfaces.Shift_Right (F (13) and 16#E0#, 5) else F (15));

   --  The BLHeli_32 type text from byte 31: up to 32 characters, ended at the
   --  first zero byte.
   function Type_Text_Length (F : Frame) return Natural
     with Post => Type_Text_Length'Result <= 32;

end Adaflight.ESC_Info;
