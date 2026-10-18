--  The HoTT display port: the menu system draws into the text mode's screen
--  of eight rows of 21 characters. A string goes on a character at a time
--  with the column stepping as a byte, a clear writes spaces over the
--  display's rows and columns, the grab marks the screen as the menu's and
--  the release clears it and asks the transmitter to leave. The display has
--  no rows or columns until its first registration has cleared it.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.HoTT_Telemetry;

package Adaflight.HoTT_Display_Port with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Link is HoTT_Telemetry.Link;

   type Display is record
      Rows    : Natural range 0 .. HoTT_Telemetry.Text_Rows := 0;
      Cols    : Natural range 0 .. HoTT_Telemetry.Text_Cols := 0;
      Grabbed : Boolean := False;
   end record;

   procedure Write_Char (L : in out Link; Col, Row : Byte; C : Byte);

   procedure Write_String (L : in out Link; Col, Row : Byte; Text : String);

   procedure Clear (D : Display; L : in out Link);

   procedure Grab (D : in out Display; L : in out Link)
     with Post => D.Grabbed;

   procedure Release (D : in out Display; L : in out Link)
     with Post => not D.Grabbed;

   --  The registration: released, cleared over the size it had, then the
   --  text mode's size.
   procedure Register (D : in out Display; L : in out Link)
     with Post => D.Rows = HoTT_Telemetry.Text_Rows and then D.Cols = HoTT_Telemetry.Text_Cols;

   --  The menu leaves with a save once the text mode stops.
   function Heartbeat_Exit (L : Link) return Boolean is (not L.Text_Alive);

end Adaflight.HoTT_Display_Port;
