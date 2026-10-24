--  The block and the segment endings an SD card driver shares with its bus.
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.SD_Card_Bus with SPARK_Mode is

   Block_Bytes : constant := 512;

   subtype Block is Byte_Array (0 .. Block_Bytes - 1);

   --  How a bus segment ends: at once, when the card answers the idle byte,
   --  when it answers another byte, or when it answers a data token.
   type Segment_Kind is (Plain, Until_Idle, Until_Not_Idle, Until_Data_Token);

end Adaflight.SD_Card_Bus;
