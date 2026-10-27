--  The USB virtual serial port on the full-speed OTG controller: its pins
--  and clock, the controller started in device mode with its FIFOs, and its
--  interrupt, which hands the controller's events to the device and carries
--  out the endpoint operations each one asks for. The flight software sends
--  bytes to the host and takes the bytes from it.
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.USB is
   --  The pins, the clock and the controller in device mode, with the product
   --  name the host reads.
   procedure Init (Product : String);
   --  Whether the host configured the port.
   function Configured return Boolean;
   --  Bytes toward the host, taken while no transfer runs and up to the free
   --  room.
   procedure Send (Data : Byte_Array; Accepted : out Natural);
   --  The bytes from the host, up to Into's length.
   procedure Take (Into : out Byte_Array; Count : out Natural);
end Adaflight.STM32.USB;
