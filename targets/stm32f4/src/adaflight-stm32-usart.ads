--  The UARTs of the STM32F405 the board family brings out, USART1 and USART6
--  on the 84 MHz bus and USART3 and UART4 on the 42 MHz bus, each at eight
--  data bits, no parity and one or two stop bits over its two pins: a
--  transmitter whose interrupt sends the bytes queued in a ring of 256, and
--  a receiver whose interrupt keeps the bytes with their arrival times in a
--  ring of 256 until a task takes them.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.USART is
   type Number is (UART1, UART3, UART4, UART6);
   type Port is limited record
      Which : Number := UART1;
   end record;
   type Time_Array is array (Natural range <>) of Interfaces.Unsigned_32;
   procedure Init (N : Number; Baud : Positive; Two_Stop_Bits : Boolean := False);
   --  Every character of Text, queued as the ring has room.
   procedure Put (Into : in out Port; Text : String);
   --  Every byte of Data, queued as the ring has room.
   procedure Put (Into : in out Port; Data : Byte_Array);
   --  The bytes of Data the ring has room for, and their count.
   procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural);
   --  The ring's room, and whether every queued byte has left.
   function Free (N : Number) return Natural;
   function Transmit_Empty (N : Number) return Boolean;
   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural);
   --  The same with each byte's arrival time in microseconds.
   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural)
     with Pre => Times'Length >= Into'Length;
end Adaflight.STM32.USART;
