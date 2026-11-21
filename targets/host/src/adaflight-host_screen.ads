--  The host's OSD screen file: the MAX7456 model's display memory as text,
--  sixteen lines of thirty characters with a dot for a code outside
--  printable ASCII, in the file the environment variable
--  ADAFLIGHT_OSD_SCREEN names, adaflight-osd.txt when unset. The file is
--  written at most ten times a second, and only after a screen draw that
--  sent all it found changed, so it never holds part of a screen update.
with Interfaces;
package Adaflight.Host_Screen is
   subtype Address is Natural range 0 .. 511;
   --  The whole memory cleared, and one character written.
   procedure Clear;
   procedure Put (At_Address : Address; Code : Interfaces.Unsigned_8);
   --  Writes the file when it is due, once per scheduler pass, with whether
   --  the board's last screen draw was complete.
   procedure Poll (Synced : Boolean);
end Adaflight.Host_Screen;
