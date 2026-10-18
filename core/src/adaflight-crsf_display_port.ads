--  The CRSF display port: the menu system draws into a screen of up to nine
--  rows of 32 characters, which the CRSF telemetry sends to the transmitter
--  in chunks. A clear blanks the screen, marks it for a clear frame and
--  holds the transfer back 45 ms; opening the menu holds it back 400 ms. A
--  write past the screen's rows or columns is dropped, one past its last
--  column cut, and a write that changes the screen marks it updated. The
--  transmitter opens, closes and polls the menu with display port commands.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Clock;

package Adaflight.CRSF_Display_Port with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;

   Rows_Max       : constant := 9;
   Cols_Max       : constant := 32;
   Buffer_Size    : constant := Rows_Max * Cols_Max;
   Open_Delay_Ms  : constant := 400;
   Clear_Delay_Ms : constant := 45;

   Command_Open  : constant := 3;
   Command_Close : constant := 4;
   Command_Poll  : constant := 5;

   subtype Row_Count is Natural range 0 .. Rows_Max;
   subtype Col_Count is Natural range 0 .. Cols_Max;
   subtype Screen_Index is Natural range 0 .. Buffer_Size - 1;
   type Screen_Buffer is array (Screen_Index) of Byte;

   type Screen is record
      Buffer         : Screen_Buffer := (others => 0);
      Updated        : Boolean := False;
      Rows           : Row_Count := 0;
      Cols           : Col_Count := 0;
      Reset          : Boolean := False;
      Delay_Until_Ms : Interfaces.Unsigned_32 := 0;
      Grabbed        : Boolean := False;
   end record;

   --  What a display port command asks of the menu system: nothing, to
   --  open the menu on this display, or to leave it.
   type Menu_Request is (None, Open, Leave);

   procedure Clear (S : in out Screen; Now_Ms : Interfaces.Unsigned_32)
     with Post => S.Reset and then not S.Updated and then S.Rows = S'Old.Rows and then S.Cols = S'Old.Cols
                  and then S.Grabbed = S'Old.Grabbed;

   --  The display's registration: the largest screen, released and cleared.
   procedure Init (S : in out Screen; Now_Ms : Interfaces.Unsigned_32)
     with Post => S.Rows = Rows_Max and then S.Cols = Cols_Max;

   procedure Grab (S : in out Screen)
     with Post => S.Grabbed and then S.Buffer = S'Old.Buffer;

   procedure Release (S : in out Screen; Now_Ms : Interfaces.Unsigned_32)
     with Post => not S.Grabbed and then S.Reset;

   procedure Set_Dimensions (S : in out Screen; Rows, Cols : Byte)
     with Post => S.Rows = Natural'Min (Natural (Rows), Rows_Max)
                  and then S.Cols = Natural'Min (Natural (Cols), Cols_Max);

   procedure Write_String (S : in out Screen; Col, Row : Byte; Text : String);

   --  One character; a zero writes nothing.
   procedure Write_Char (S : in out Screen; Col, Row : Byte; C : Byte);

   --  The transfer may run once its delay has passed, through the wrapping
   --  difference of the millisecond clock, while the menu is open on this
   --  display.
   function Ready (S : Screen; Now_Ms : Interfaces.Unsigned_32; In_Menu, Current : Boolean) return Boolean is
     (Adaflight.Clock.Elapsed (Now_Ms, S.Delay_Until_Ms) > 0 and then In_Menu and then Current);

   --  The menu opens on this display while disarmed, when no menu is open
   --  and the menu system has the display registered.
   function Can_Open (Armed, In_Menu, Registered : Boolean) return Boolean is
     (not Armed and then not In_Menu and then Registered);

   --  The menu opened on this display: the transfer waits 400 ms. The caller
   --  opens the menu first, since the menu's clear sets a shorter delay.
   procedure Opened (S : in out Screen; Now_Ms : Interfaces.Unsigned_32)
     with Post => S.Delay_Until_Ms = Now_Ms + Open_Delay_Ms;

   --  A display port command from the frame's byte after the destination
   --  and origin: open takes the rows and columns and opens the menu, close
   --  leaves an open menu, and poll redraws an open menu or opens one.
   procedure Command (S : in out Screen; Payload : Byte_Array; Now_Ms : Interfaces.Unsigned_32;
                      Armed, In_Menu, Registered : Boolean; Request : out Menu_Request)
     with Pre => Payload'Length >= 3;

end Adaflight.CRSF_Display_Port;
