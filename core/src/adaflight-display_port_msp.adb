package body Adaflight.Display_Port_MSP with SPARK_Mode is

   function Attribute (Font : Font_Selection; Attr : Unsigned_8) return Unsigned_8 is
      Bank  : constant Unsigned_8 := Font (Natural (Attr and Font_Mask)) and Font_Mask;
      Blink : constant Unsigned_8 := (if (Attr and Blink_Attribute) /= 0 then Device_Blink else 0);
   begin
      return Bank or Blink;
   end Attribute;

   procedure Single (Code : Byte; Data : out Payload; Length : out Natural) is
   begin
      Data := (others => 0);
      Data (0) := Code;
      Length := 1;
   end Single;

   procedure Dimensions (System : Video_System; P : Profile; Canvas_Rows, Canvas_Cols : Unsigned_8;
                         Rows, Cols : out Unsigned_8) is
   begin
      if System = HD then
         Rows := Canvas_Rows;
         Cols := Canvas_Cols;
      else
         Rows := Unsigned_8'Mod ((if System = PAL then PAL_Lines else NTSC_Lines) + Integer (P.Row_Adjust));
         Cols := Unsigned_8'Mod (SD_Columns + Integer (P.Col_Adjust));
      end if;
   end Dimensions;

   procedure Init (D : out Port; System : Video_System; P : Profile; Canvas_Rows, Canvas_Cols : Unsigned_8) is
   begin
      D := (others => <>);
      D.Grab_Count := 0;
      Clear (D);
      D.Use_Device_Blink := P.Use_Device_Blink;
      Dimensions (System, P, Canvas_Rows, Canvas_Cols, D.Rows, D.Cols);
   end Init;

   procedure Heartbeat (Data : out Payload; Length : out Natural) is
   begin
      Single (Heartbeat_Code, Data, Length);
   end Heartbeat;

   procedure Release_Payload (Data : out Payload; Length : out Natural) is
   begin
      Single (Release_Code, Data, Length);
   end Release_Payload;

   procedure Clear_Screen_Payload (Data : out Payload; Length : out Natural) is
   begin
      Single (Clear_Screen_Code, Data, Length);
   end Clear_Screen_Payload;

   procedure Draw_Screen_Payload (Data : out Payload; Length : out Natural) is
   begin
      Single (Draw_Screen_Code, Data, Length);
   end Draw_Screen_Payload;

   procedure Write_String (Font : Font_Selection; Col, Row, Attr : Unsigned_8; Text : String; Data : out Payload;
                           Length : out Natural) is
      Count : constant Natural := Natural'Min (Text'Length, Max_String);
   begin
      Data := (others => 0);
      Length := 0;
      if Text'Length = 0 then
         return;
      end if;
      Data (0) := Write_String_Code;
      Data (1) := Row;
      Data (2) := Col;
      Data (3) := Attribute (Font, Attr);
      for K in 0 .. Count - 1 loop
         Data (4 + K) := Character'Pos (Text (Text'First + K));
      end loop;
      Length := Count + 4;
   end Write_String;

   procedure Write_Char (Font : Font_Selection; Col, Row, Attr : Unsigned_8; C : Character; Data : out Payload;
                         Length : out Natural) is
   begin
      Data := (others => 0);
      Data (0) := Write_String_Code;
      Data (1) := Row;
      Data (2) := Col;
      Data (3) := Attribute (Font, Attr);
      if C = Character'Val (0) then
         Length := 4;
      else
         Data (4) := Character'Pos (C);
         Length := 5;
      end if;
   end Write_Char;

   procedure Write_Sys (Col, Row, Element : Unsigned_8; Data : out Payload; Length : out Natural) is
   begin
      Data := (others => 0);
      Data (0) := Sys_Code;
      Data (1) := Row;
      Data (2) := Col;
      Data (3) := Element;
      Length := 4;
   end Write_Sys;

   procedure Write_Font_Character (Address : Unsigned_16; Chr : Character_Data; Data : out Payload;
                                   Length : out Natural) is
   begin
      Data := (others => 0);
      Data (0) := Font_Char_Code;
      Data (1) := Byte (Address and 16#FF#);
      Data (2) := Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#);
      Data (3) := 0;
      Data (4 .. 4 + Character_Size - 1) := Chr;
      Length := Max_Payload;
   end Write_Font_Character;

   procedure Grab (D : in out Port) is
   begin
      D.Grab_Count := D.Grab_Count + 1;
   end Grab;

   procedure Release (D : in out Port) is
   begin
      D.Grab_Count := D.Grab_Count - 1;
   end Release;

   procedure Release_All (D : in out Port) is
   begin
      D.Grab_Count := 0;
   end Release_All;

   procedure Clear (D : in out Port) is
   begin
      D.Cleared := True;
      D.Cursor_Row := -1;
   end Clear;

end Adaflight.Display_Port_MSP;
