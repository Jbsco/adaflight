--  The MSP display port: the OSD canvas of a goggle system driven over the
--  MSP link, each operation a display port payload sent as an MSP reply,
--  the attribute byte from the profile's font selection and the blink,
--  strings cut at thirty characters, and the rows and columns of the
--  canvas from the video system and the profile's adjustments. The MSP
--  link and the serial port stay with the target.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.Display_Port_MSP with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_8;
   use Adaflight.Bytes;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_8 is Interfaces.Integer_8;

   Command        : constant := 182;
   Max_String     : constant := 30;
   Character_Size : constant := 64;
   Max_Payload    : constant := Character_Size + 4;
   SD_Columns     : constant := 30;
   PAL_Lines      : constant := 16;
   NTSC_Lines     : constant := 13;

   subtype Payload is Byte_Array (0 .. Max_Payload - 1);
   subtype Character_Data is Byte_Array (0 .. Character_Size - 1);

   --  The display port subcommands in the reference's numbering.
   Heartbeat_Code     : constant Byte := 0;
   Release_Code       : constant Byte := 1;
   Clear_Screen_Code  : constant Byte := 2;
   Write_String_Code  : constant Byte := 3;
   Draw_Screen_Code   : constant Byte := 4;
   Sys_Code           : constant Byte := 6;
   Font_Char_Code     : constant Byte := 7;

   Blink_Attribute    : constant Unsigned_8 := 16#80#;
   Device_Blink       : constant Unsigned_8 := 16#40#;
   Font_Mask          : constant Unsigned_8 := 16#03#;

   subtype Severity_Index is Natural range 0 .. 3;
   type Font_Selection is array (Severity_Index) of Unsigned_8;

   --  The profile: the font bank per severity, the device blink, and the
   --  row and column adjustments of the standard definition canvas.
   type Profile is record
      Font             : Font_Selection := (0, 1, 2, 3);
      Use_Device_Blink : Boolean := False;
      Row_Adjust       : Integer_8 := 0;
      Col_Adjust       : Integer_8 := 0;
   end record;

   type Video_System is (Auto, PAL, NTSC, HD);

   --  The port's state as the display layer keeps it: the canvas size, the
   --  grab count, the cleared flag and the cursor row.
   type Port is record
      Rows             : Unsigned_8 := 0;
      Cols             : Unsigned_8 := 0;
      Grab_Count       : Integer_8 := 0;
      Cleared          : Boolean := False;
      Cursor_Row       : Integer_8 := 0;
      Use_Device_Blink : Boolean := False;
   end record;

   --  The attribute byte: the profile's font bank of the severity, and the
   --  device blink bit for a blinking element.
   function Attribute (Font : Font_Selection; Attr : Unsigned_8) return Unsigned_8;

   --  The rows and columns of the canvas: the configured canvas for a high
   --  definition system, else the standard lines of PAL or NTSC and the
   --  standard columns, each with the profile's adjustment.
   procedure Dimensions (System : Video_System; P : Profile; Canvas_Rows, Canvas_Cols : Unsigned_8;
                         Rows, Cols : out Unsigned_8);

   --  The port initialized: its dimensions, the device blink, and the clear
   --  and draw the initialization sends, as Clear_Screen and Draw_Screen
   --  payloads in that order.
   procedure Init (D : out Port; System : Video_System; P : Profile; Canvas_Rows, Canvas_Cols : Unsigned_8);

   procedure Heartbeat (Data : out Payload; Length : out Natural);
   procedure Release_Payload (Data : out Payload; Length : out Natural);
   procedure Clear_Screen_Payload (Data : out Payload; Length : out Natural);
   procedure Draw_Screen_Payload (Data : out Payload; Length : out Natural);

   --  A string at the column and row with its attribute, cut at the
   --  maximum; an empty string sends nothing.
   procedure Write_String (Font : Font_Selection; Col, Row, Attr : Unsigned_8; Text : String; Data : out Payload;
                           Length : out Natural);

   --  One character, as the string of that character; the null character
   --  writes an empty string.
   procedure Write_Char (Font : Font_Selection; Col, Row, Attr : Unsigned_8; C : Character; Data : out Payload;
                         Length : out Natural);

   procedure Write_Sys (Col, Row, Element : Unsigned_8; Data : out Payload; Length : out Natural);

   --  A font character at its address, the address low byte first.
   procedure Write_Font_Character (Address : Unsigned_16; Chr : Character_Data; Data : out Payload;
                                   Length : out Natural);

   --  The display layer's bookkeeping over the port: a grab sends the
   --  heartbeat and a clear and counts, a release the release payload, a
   --  clear the clear payload and marks the screen cleared; the device is
   --  always synced and ready, never mid-transfer.
   function Is_Synced return Boolean is (True);
   function Is_Ready return Boolean is (True);
   function Transfer_In_Progress return Boolean is (False);
   procedure Grab (D : in out Port)
     with Pre => D.Grab_Count < Integer_8'Last;
   procedure Release (D : in out Port)
     with Pre => D.Grab_Count > Integer_8'First;
   procedure Release_All (D : in out Port);
   procedure Clear (D : in out Port);
   function Is_Grabbed (D : Port) return Boolean is (D.Grab_Count > 0);
   function Screen_Size (D : Port) return Natural is (Natural (D.Rows) * Natural (D.Cols));

end Adaflight.Display_Port_MSP;
