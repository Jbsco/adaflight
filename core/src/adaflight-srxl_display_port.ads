--  The SRXL display port: the menu system draws into the Spektrum text
--  generator's nine rows of twelve characters. A string goes on a character
--  at a time with the column stepping as a byte. A clear writes spaces over
--  the whole buffer and the firmware's name the caller gives at the top,
--  and while the menu does not hold the display, the three lines that tell
--  how to open it. The release clears; the registration releases and
--  clears.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.SRXL_Telemetry;

package Adaflight.SRXL_Display_Port with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Stream is SRXL_Telemetry.Stream;

   Help_Line_1 : constant String := "MENU:THR MID";
   Help_Line_2 : constant String := "+ YAW LEFT";
   Help_Line_3 : constant String := "+ PITCH UP";

   type Display is record
      Grabbed : Boolean := False;
   end record;

   procedure Write_Char (S : in out Stream; Col, Row : Byte; C : Byte);

   procedure Write_String (S : in out Stream; Col, Row : Byte; Text : String);

   procedure Clear (D : Display; S : in out Stream; Title : String);

   procedure Grab (D : out Display)
     with Post => D.Grabbed;

   procedure Release (D : out Display; S : in out Stream; Title : String)
     with Post => not D.Grabbed;

   procedure Register (D : out Display; S : in out Stream; Title : String)
     with Post => not D.Grabbed;

end Adaflight.SRXL_Display_Port;
