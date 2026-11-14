--  The USB device as a mass storage disk: two bulk endpoints for the
--  bulk-only transport. The mass storage engine decides what the endpoints
--  do; this package reports what happened on them and does that work.
with Adaflight.Bytes; use Adaflight.Bytes;
package Adaflight.STM32.USB_Storage is
   --  Whether this image has the device.
   function Available return Boolean;
   --  The device on the bus with the product name a host reads.
   procedure Start (Product : String);

   --  A host configured the device, a transfer arrived on the out endpoint,
   --  a transfer on the in endpoint ended, a host cleared an endpoint's
   --  halt, a host asked for the transport's reset, or the device left its
   --  configuration.
   type Event is (Nothing, Started, Packet_Out, Packet_In, Cleared_In, Cleared_Out, Transport_Reset, Stopped);
   --  The next event. A transfer that arrived is in Data from its start,
   --  Count bytes of it.
   procedure Next (What : out Event; Data : in out Byte_Array; Count : out Natural);

   --  Both endpoints flushed.
   procedure Flush;
   procedure Halt_In;
   procedure Halt_Out;
   --  Bytes toward a host as one transfer.
   procedure Send (Data : Byte_Array);
   --  The out endpoint takes one transfer of up to Length bytes.
   procedure Receive (Length : Natural);
end Adaflight.STM32.USB_Storage;
