--  The XN297 payload helpers for NRF24L01 receivers that talk to XN297
--  transmitters: the scrambled, bit-reversed payload and its CRC-16 CCITT
--  over the reversed receive address and the bytes on the air, with a
--  final value per length.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.XN297 with SPARK_Mode is

   Address_Length : constant := 5;
   Max_Length     : constant := 25;
   type Address is array (0 .. Address_Length - 1) of Byte;

   --  Unscrambles the first Length bytes of Data in place and gives the CRC
   --  that the bytes as received carry.
   procedure Unscramble (Data : in out Byte_Array; Length : Natural; Rx_Address : Address;
                         CRC : out Interfaces.Unsigned_16)
     with Global => null,
          Pre    => Length <= Max_Length and then Data'First = 0 and then Data'Length >= Length;

end Adaflight.XN297;
