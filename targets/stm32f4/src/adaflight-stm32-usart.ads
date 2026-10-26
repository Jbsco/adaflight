--  The UARTs of the STM32F405 the board family brings out, USART1 and USART6
--  on the 84 MHz bus and USART3 and UART4 on the 42 MHz bus, each at eight
--  data bits, no parity and one stop bit over its two pins: a blocking
--  transmitter, and a receiver whose interrupt keeps the bytes with their
--  arrival times in a ring of 256 until a task takes them.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.USART is
   type Number is (UART1, UART3, UART4, UART6);
   type Port is limited record
      Which : Number := UART1;
   end record;
   type Time_Array is array (Natural range <>) of Interfaces.Unsigned_32;
   procedure Init (N : Number; Baud : Positive);
   --  Every character of Text, each after the transmit register empties.
   procedure Put (Into : in out Port; Text : String);
   --  Every byte of Data, each after the transmit register empties.
   procedure Put (Into : in out Port; Data : Byte_Array);
   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural);
   --  The same with each byte's arrival time in microseconds.
   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural)
     with Pre => Times'Length >= Into'Length;
end Adaflight.STM32.USART;
