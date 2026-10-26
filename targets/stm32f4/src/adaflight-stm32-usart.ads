--  USART1 of the STM32F405 at eight data bits, no parity and one stop bit
--  over two pins: a blocking transmitter the command line puts its text
--  through, and a receiver whose interrupt keeps the bytes in a ring of 256
--  until the main loop takes them.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.USART is

   type Port is limited null record;

   --  The peripheral clock of USART1: the 168 MHz system clock on the APB2
   --  bus, which the runtime's clock setup divides by two.
   PCLK2_Hz : constant := 84_000_000;

   procedure Init (TX, RX : Pin; Baud : Positive);

   --  Every character of Text, each after the transmit register empties.
   procedure Put (Into : in out Port; Text : String);

   --  Every byte of Data, each after the transmit register empties.
   procedure Put (Into : in out Port; Data : Byte_Array);

   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (Into : out Byte_Array; Count : out Natural);

end Adaflight.STM32.USART;
