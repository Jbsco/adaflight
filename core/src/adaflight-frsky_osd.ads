--  The FrSky OSD device link: drawing and font commands queued into a
--  send buffer and framed on a flush as a preamble, a varint length, the
--  commands and a checksum; the device's responses reassembled from the
--  bytes received, the information response answering the version and
--  grid request the link repeats every second, the font responses
--  answering the two commands that wait for them.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.FrSky_OSD with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Color is (Black, Transparent, White, Gray);

   type Transaction_Options is record
      Profiled      : Boolean := False;
      Reset_Drawing : Boolean := False;
   end record;

   Send_Size    : constant := 192;
   Receive_Size : constant := 128;
   Char_Bytes   : constant := 64;
   Max_Text     : constant := 123;

   subtype Send_Position is Natural range 0 .. Send_Size;
   subtype Receive_Position is Natural range 0 .. Receive_Size;
   subtype Char_Data is Byte_Array (0 .. Char_Bytes - 1);
   subtype Text is Byte_Array;

   type Receive_State is (None, Sync, Length, Data, Checksum, Done);

   type Link is record
      Port_Open      : Boolean := False;
      Send           : Byte_Array (0 .. Send_Size - 1) := (others => 0);
      Send_Pos       : Send_Position := 0;
      Recv_State     : Receive_State := None;
      Recv_Crc       : Byte := 0;
      Expected       : Unsigned_16 := 0;
      Expected_Shift : Natural range 0 .. 28 := 0;
      Recv           : Byte_Array (0 .. Receive_Size - 1) := (others => 0);
      Recv_Pos       : Receive_Position := 0;
      Major          : Unsigned_8 := 0;
      Minor          : Unsigned_8 := 0;
      Next_Info_Ms   : Unsigned_32 := 0;
      Rows           : Unsigned_8 := 0;
      Columns        : Unsigned_8 := 0;
      Width          : Unsigned_16 := 0;
      Height         : Unsigned_16 := 0;
      Reading_Font   : Boolean := False;
      Font_Address   : Unsigned_16 := 0;
      Font           : Char_Data := (others => 0);
      Initialized    : Boolean := False;
      Last_Handled   : Boolean := False;
   end record;

   Max_Output : constant := 512;
   subtype Output_Count is Natural range 0 .. Max_Output;

   --  The bytes written to the port by one call.
   type Output is record
      Tx    : Byte_Array (0 .. Max_Output - 1) := (others => 0);
      Count : Output_Count := 0;
   end record;

   function Is_Ready (L : Link) return Boolean is (L.Minor > 0 or else L.Major > 0);

   --  The link over an opened port, asking the device for its information.
   procedure Init (L : out Link; Port_Opened : Boolean; Now_Ms : Unsigned_32; O : in out Output);

   --  One task call with the bytes received, every one taken: a complete
   --  response is handled, and the information request goes out once a
   --  second whether or not the device answered (finding F86).
   procedure Update (L : in out Link; Rx : Byte_Array; Now_Ms : Unsigned_32; O : in out Output);

   procedure Begin_Transaction (L : in out Link; Opts : Transaction_Options; O : in out Output);
   procedure Commit_Transaction (L : in out Link; O : in out Output);
   procedure Flush (L : in out Link; O : in out Output)
     with Post => L.Send_Pos = 0;

   procedure Draw_String_In_Grid (L : in out Link; X, Y : Unsigned_8; S : Text; O : in out Output)
     with Pre => S'Length <= Max_Text;
   procedure Draw_Char_In_Grid (L : in out Link; X, Y : Unsigned_8; Chr : Unsigned_16; O : in out Output);
   procedure Clear_Screen (L : in out Link; O : in out Output);

   procedure Set_Stroke_Color (L : in out Link; C : Color; O : in out Output);
   procedure Set_Fill_Color (L : in out Link; C : Color; O : in out Output);
   procedure Set_Stroke_And_Fill_Color (L : in out Link; C : Color; O : in out Output);
   procedure Set_Color_Inversion (L : in out Link; Inverted : Boolean; O : in out Output);
   procedure Set_Pixel (L : in out Link; X, Y : Integer; C : Color; O : in out Output);
   procedure Set_Pixel_To_Stroke_Color (L : in out Link; X, Y : Integer; O : in out Output);
   procedure Set_Pixel_To_Fill_Color (L : in out Link; X, Y : Integer; O : in out Output);
   procedure Set_Stroke_Width (L : in out Link; Width : Unsigned_8; O : in out Output);
   procedure Set_Line_Outline_Type (L : in out Link; Outline : Unsigned_8; O : in out Output);
   procedure Set_Line_Outline_Color (L : in out Link; C : Color; O : in out Output);

   procedure Clip_To_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Clear_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Reset_Drawing_State (L : in out Link; O : in out Output);
   procedure Draw_Character (L : in out Link; X, Y : Integer; Chr : Unsigned_16; Opts : Unsigned_8; O : in out Output);
   procedure Draw_Character_Mask (L : in out Link; X, Y : Integer; Chr : Unsigned_16; C : Color; Opts : Unsigned_8;
                                  O : in out Output);
   procedure Draw_String (L : in out Link; X, Y : Integer; S : Text; Opts : Unsigned_8; O : in out Output)
     with Pre => S'Length <= Max_Text - 1;
   procedure Draw_String_Mask (L : in out Link; X, Y : Integer; S : Text; C : Color; Opts : Unsigned_8;
                               O : in out Output)
     with Pre => S'Length <= Max_Text - 2;
   procedure Move_To_Point (L : in out Link; X, Y : Integer; O : in out Output);
   procedure Stroke_Line_To_Point (L : in out Link; X, Y : Integer; O : in out Output);
   procedure Stroke_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output);
   procedure Fill_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output);
   procedure Fill_Stroke_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output);
   procedure Stroke_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Fill_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Fill_Stroke_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Stroke_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Fill_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);
   procedure Fill_Stroke_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output);

   procedure Ctm_Reset (L : in out Link; O : in out Output);
   procedure Ctm_Set (L : in out Link; M11, M12, M21, M22, M31, M32 : Float; O : in out Output);
   procedure Ctm_Translate (L : in out Link; Tx, Ty : Float; O : in out Output);
   procedure Ctm_Scale (L : in out Link; Sx, Sy : Float; O : in out Output);
   procedure Ctm_Rotate (L : in out Link; R : Float; O : in out Output);
   procedure Context_Push (L : in out Link; O : in out Output);
   procedure Context_Pop (L : in out Link; O : in out Output);

   --  A font character read: the bytes waiting before the request are
   --  taken first, the request goes out with whatever was queued, and the
   --  bytes arriving while the link waits are all taken, the first
   --  complete response among them deciding the outcome.
   procedure Read_Font_Character (L : in out Link; Address : Unsigned_16; Before, Reply : Byte_Array;
                                  O : in out Output; OK : out Boolean);

   --  A font character written, waiting the same way for the confirmation.
   procedure Write_Font_Character (L : in out Link; Address : Unsigned_16; Chr : Char_Data; Before, Reply : Byte_Array;
                                   O : in out Output);

end Adaflight.FrSky_OSD;
