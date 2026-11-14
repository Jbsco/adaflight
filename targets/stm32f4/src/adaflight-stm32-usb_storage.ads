--  The USB controller in mass storage mode: bus events in, endpoint
--  operations out. The mass storage device unit decides what the endpoints
--  do; this package reports what the bus brought and does that work.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.USB_Device;
package Adaflight.STM32.USB_Storage is
   --  Whether this image has the controller for it.
   function Available return Boolean;
   --  The controller on the bus as a device.
   procedure Start;

   --  A bus reset, a setup packet, a packet from the host on an endpoint, a
   --  transmission that ended on one, a suspend and a resume.
   type Event is (Nothing, Bus_Reset, Setup, Packet_Out, Packet_In, Suspend, Resume);
   --  The next event with its endpoint. A setup packet's eight bytes or a
   --  packet's bytes are in Data from its start, Count of them.
   procedure Next
     (What : out Event; EP : out Adaflight.USB_Device.Endpoint_Number; Data : in out Byte_Array; Count : out Natural)
     with Pre => Data'Length >= Adaflight.USB_Device.Packet_Size;

   --  The endpoint operations an event asked for, in their order.
   procedure Execute (A : Adaflight.USB_Device.Actions);
end Adaflight.STM32.USB_Storage;
