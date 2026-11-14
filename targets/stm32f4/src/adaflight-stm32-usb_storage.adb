--  No board drives its USB controller as a mass storage disk yet.
package body Adaflight.STM32.USB_Storage is
   function Available return Boolean is (False);

   procedure Start is null;

   procedure Next
     (What : out Event; EP : out Adaflight.USB_Device.Endpoint_Number; Data : in out Byte_Array; Count : out Natural)
   is
      pragma Unreferenced (Data);
   begin
      What := Nothing;
      EP := 0;
      Count := 0;
   end Next;

   procedure Execute (A : Adaflight.USB_Device.Actions) is null;
end Adaflight.STM32.USB_Storage;
