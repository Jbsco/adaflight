--  USB mass storage as a host drives it: the bulk-only transport and the
--  SCSI commands of a disk. These are the sizes and the endpoint work that
--  the engine and its caller share.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.Mass_Storage with SPARK_Mode, Pure is

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Block_Size     : constant := 512;
   Command_Length : constant := 31;
   Status_Length  : constant := 13;
   Inquiry_Length : constant := 36;

   subtype Command_Bytes is Adaflight.Bytes.Byte_Array (0 .. Command_Length - 1);
   subtype Status_Bytes is Adaflight.Bytes.Byte_Array (0 .. Status_Length - 1);
   subtype Inquiry_Bytes is Adaflight.Bytes.Byte_Array (0 .. Inquiry_Length - 1);

   --  Blocks a data buffer may take.
   subtype Buffer_Block_Count is Positive range 1 .. 64;

   --  What goes out on the in endpoint: bytes from the start of the data
   --  buffer, or the status wrapper.
   type Send_Kind is (Nothing, Data, Status);
   --  What the out endpoint takes next: a command wrapper, or bytes for the
   --  start of the data buffer.
   type Receive_Kind is (Nothing, Command, Data);

   --  The endpoint work an event leaves, in this order: flush both
   --  endpoints, halt the out endpoint, halt the in endpoint, send, receive.
   type Actions is record
      Flush          : Boolean := False;
      Halt_Out       : Boolean := False;
      Halt_In        : Boolean := False;
      Send           : Send_Kind := Nothing;
      Send_Length    : Natural := 0;
      Receive        : Receive_Kind := Nothing;
      Receive_Length : Natural := 0;
   end record;

end Adaflight.Mass_Storage;
