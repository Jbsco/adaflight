--  No board drives its USB controller as a mass storage disk yet.
package body Adaflight.STM32.USB_Storage is
   function Available return Boolean is (False);

   procedure Start (Product : String) is null;

   procedure Next (What : out Event; Data : in out Byte_Array; Count : out Natural) is
      pragma Unreferenced (Data);
   begin
      What := Nothing;
      Count := 0;
   end Next;

   procedure Flush is null;

   procedure Halt_In is null;

   procedure Halt_Out is null;

   procedure Send (Data : Byte_Array) is null;

   procedure Receive (Length : Natural) is null;
end Adaflight.STM32.USB_Storage;
