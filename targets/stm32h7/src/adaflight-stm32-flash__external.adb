--  The configuration store of an image that runs from external flash,
--  which has no writer yet: a write reports failure and leaves the region.
package body Adaflight.STM32.Flash is

   procedure Write (Data : Byte_Array; OK : out Boolean) is
      pragma Unreferenced (Data);
   begin
      OK := False;
   end Write;

end Adaflight.STM32.Flash;
