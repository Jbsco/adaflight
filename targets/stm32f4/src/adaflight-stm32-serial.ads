--  The board's ports for the MSP and the command line: the UARTs and the USB
--  virtual serial port behind one port type, so a reply leaves through the
--  port its request came in on.
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.Serial is
   type Line is (VCP, UART1, UART3, UART4, UART6);
   type Port is limited record
      Which : Line := UART1;
   end record;
   --  Every byte toward the port: a UART's after its transmit register
   --  empties, the virtual serial port's while the host has it configured,
   --  for up to 50 ms.
   procedure Put (Into : in out Port; Text : String);
   procedure Put (Into : in out Port; Data : Byte_Array);
   --  The bytes received since the last take, up to Into's length.
   procedure Take (Which : Line; Into : out Byte_Array; Count : out Natural);
end Adaflight.STM32.Serial;
