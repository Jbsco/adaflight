--  The OSD custom text: messages a serial port sends for the OSD to show.
--  Each message ends with a line feed or a null as configured; carriage
--  returns are dropped, and so are nulls when the line feed ends messages.
--  The text keeps the first 63 characters of a message and shows the first
--  31. An empty message clears the text. The port opening stays with the
--  target.
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.OSD_Custom_Text with SPARK_Mode is

   type Terminator is (Null_Byte, Line_Feed);

   Input_Size   : constant := 64;
   Display_Size : constant := 32;

   subtype Input_Index is Natural range 0 .. Input_Size - 2;
   subtype Display_Index is Natural range 0 .. Display_Size - 2;

   type State is record
      Open           : Boolean := False;
      Input          : Byte_Array (Input_Index) := (others => 0);
      Position       : Natural range 0 .. Input_Size - 1 := 0;
      Display        : Byte_Array (Display_Index) := (others => 0);
      Display_Length : Natural range 0 .. Display_Size - 1 := 0;
   end record;

   procedure Init (T : out State; Port_Configured : Boolean)
     with Post => T.Open = Port_Configured and then T.Display_Length = 0;

   --  The bytes that arrived since the last update.
   procedure Update (T : in out State; Ends : Terminator; Input : Byte_Array);

end Adaflight.OSD_Custom_Text;
