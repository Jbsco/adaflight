--  The host's record of the pins' rising edges, which the bus models read
--  to see a device deselected between two transfers.
with Adaflight.Pins; use Adaflight.Pins;
package Adaflight.Host_Pins is
   procedure Rose (P : Pin);
   function Rises (P : Pin) return Natural;
end Adaflight.Host_Pins;
