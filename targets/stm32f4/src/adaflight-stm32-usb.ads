--  The USB virtual serial port on the full-speed OTG controller: its pins
--  and clock, the controller started in device mode with its FIFOs, and its
--  interrupt, which hands the controller's events to the device and carries
--  out the endpoint operations each one asks for. The flight software sends
--  bytes to the host and takes the bytes from it.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.USB is
   --  The pins, the clock and the controller in device mode, with the product
   --  name the host reads, as the serial port alone or as the composite
   --  device with a joystick interface.
   procedure Init (Product : String; Composite : Boolean := False);
   --  D+ held low for 200 milliseconds and then released, so a host still
   --  holding the connection sees the device leave.
   procedure Disconnect;
   --  Whether the host configured the port.
   function Configured return Boolean;
   --  Bytes toward the host, taken while no transfer runs and up to the free
   --  room.
   procedure Send (Data : Byte_Array; Accepted : out Natural);
   --  The bytes from the host, up to Into's length.
   procedure Take (Into : out Byte_Array; Count : out Natural);
   --  The bit rate of the host's line coding, zero until the host sets one.
   function Line_Rate return Interfaces.Unsigned_32;
   --  The control line state the host last set, DTR in its lowest bit, with
   --  the count of the requests that set it.
   procedure Control_Line (State : out Interfaces.Unsigned_16; Count : out Interfaces.Unsigned_32);
   --  A joystick report of nine bytes toward the host, which a configured
   --  composite device sends.
   procedure Send_Report (Report : Byte_Array)
     with Pre => Report'Length = 9;
end Adaflight.STM32.USB;
