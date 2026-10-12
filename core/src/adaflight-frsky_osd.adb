with Adaflight.Encoding;
with Adaflight.Float_Bits;

package body Adaflight.FrSky_OSD with SPARK_Mode is

   Preamble_0 : constant Byte := Character'Pos ('$');
   Preamble_1 : constant Byte := Character'Pos ('A');
   Polynomial : constant Byte := 16#D5#;
   Api_Version : constant Byte := 1;
   Info_Interval_Ms : constant := 1000;
   Info_Response_Size : constant := 17;

   Cmd_Error                : constant Byte := 0;
   Cmd_Info                 : constant Byte := 1;
   Cmd_Read_Font            : constant Byte := 2;
   Cmd_Write_Font           : constant Byte := 3;
   Cmd_Transaction_Begin    : constant Byte := 16;
   Cmd_Transaction_Commit   : constant Byte := 17;
   Cmd_Transaction_Profiled : constant Byte := 18;
   Cmd_Transaction_Reset    : constant Byte := 19;
   Cmd_Stroke_Color         : constant Byte := 22;
   Cmd_Fill_Color           : constant Byte := 23;
   Cmd_Stroke_Fill_Color    : constant Byte := 24;
   Cmd_Color_Inversion      : constant Byte := 25;
   Cmd_Set_Pixel            : constant Byte := 26;
   Cmd_Pixel_Stroke         : constant Byte := 27;
   Cmd_Pixel_Fill           : constant Byte := 28;
   Cmd_Stroke_Width         : constant Byte := 29;
   Cmd_Outline_Type         : constant Byte := 30;
   Cmd_Outline_Color        : constant Byte := 31;
   Cmd_Clip_To_Rect         : constant Byte := 40;
   Cmd_Clear_Screen         : constant Byte := 41;
   Cmd_Clear_Rect           : constant Byte := 42;
   Cmd_Drawing_Reset        : constant Byte := 43;
   Cmd_Draw_Char            : constant Byte := 46;
   Cmd_Draw_Char_Mask       : constant Byte := 47;
   Cmd_Draw_String          : constant Byte := 48;
   Cmd_Draw_String_Mask     : constant Byte := 49;
   Cmd_Move_To              : constant Byte := 50;
   Cmd_Line_To              : constant Byte := 51;
   Cmd_Stroke_Triangle      : constant Byte := 52;
   Cmd_Fill_Triangle        : constant Byte := 53;
   Cmd_Fill_Stroke_Triangle : constant Byte := 54;
   Cmd_Stroke_Rect          : constant Byte := 55;
   Cmd_Fill_Rect            : constant Byte := 56;
   Cmd_Fill_Stroke_Rect     : constant Byte := 57;
   Cmd_Stroke_Ellipse       : constant Byte := 58;
   Cmd_Fill_Ellipse         : constant Byte := 59;
   Cmd_Fill_Stroke_Ellipse  : constant Byte := 60;
   Cmd_Ctm_Reset            : constant Byte := 80;
   Cmd_Ctm_Set              : constant Byte := 81;
   Cmd_Ctm_Translate        : constant Byte := 82;
   Cmd_Ctm_Scale            : constant Byte := 83;
   Cmd_Ctm_Rotate           : constant Byte := 84;
   Cmd_Context_Push         : constant Byte := 100;
   Cmd_Context_Pop          : constant Byte := 101;
   Cmd_Draw_Grid_Chr        : constant Byte := 110;
   Cmd_Draw_Grid_Str        : constant Byte := 111;

   Max_Payload : constant := 128;
   subtype Payload is Byte_Array (0 .. Max_Payload - 1);
   subtype Point_Bytes is Byte_Array (0 .. 2);
   subtype Rect_Bytes is Byte_Array (0 .. 5);
   subtype Triangle_Bytes is Byte_Array (0 .. 8);
   subtype Word_Bytes is Byte_Array (0 .. 1);
   subtype Float_Bytes_4 is Byte_Array (0 .. 3);

   procedure Write (O : in out Output; B : Byte) is
   begin
      if O.Count < Max_Output then
         O.Tx (O.Count) := B;
         O.Count := O.Count + 1;
      end if;
   end Write;

   --  The queued commands as one frame: the preamble, the length as a
   --  varint, the commands and the checksum over the length and commands.
   procedure Flush (L : in out Link; O : in out Output) is
      Length  : Byte_Array (0 .. 3) := (others => 0);
      Written : Natural;
      Crc     : Byte := 0;
   begin
      if L.Send_Pos = 0 then
         return;
      end if;
      Write (O, Preamble_0);
      Write (O, Preamble_1);
      Adaflight.Encoding.Uvarint_Encode (Unsigned_32 (L.Send_Pos), Length, Written);
      for I in 0 .. Written - 1 loop
         Write (O, Length (I));
         Crc := CRC8 (Crc, Length (I), Polynomial);
      end loop;
      for I in 0 .. L.Send_Pos - 1 loop
         Write (O, L.Send (I));
         Crc := CRC8 (Crc, L.Send (I), Polynomial);
      end loop;
      Write (O, Crc);
      L.Send_Pos := 0;
   end Flush;

   --  A command queued, the queue flushed first when it would not fit.
   procedure Queue (L : in out Link; Cmd : Byte; Data : Byte_Array; O : in out Output)
     with Pre => Data'Length <= Max_Payload
   is
   begin
      if Send_Size - L.Send_Pos < Data'Length + 1 then
         Flush (L, O);
      end if;
      L.Send (L.Send_Pos) := Cmd;
      L.Send_Pos := L.Send_Pos + 1;
      for I in 0 .. Data'Length - 1 loop
         L.Send (L.Send_Pos + I) := Data (Data'First + I);
      end loop;
      L.Send_Pos := L.Send_Pos + Data'Length;
   end Queue;

   No_Data : constant Byte_Array (1 .. 0) := (others => 0);

   --  Two twelve-bit coordinates packed into three bytes, low bits first.
   function Point (X, Y : Integer) return Point_Bytes is
      XB : constant Natural := X mod 4096;
      YB : constant Natural := Y mod 4096;
   begin
      return Point_Bytes'(0 => Byte (XB mod 256), 1 => Byte (XB / 256 + (YB mod 16) * 16), 2 => Byte (YB / 16));
   end Point;

   function Rect (X, Y, W, H : Integer) return Rect_Bytes is (Point (X, Y) & Point (W, H));

   function U16 (V : Unsigned_16) return Word_Bytes is
     (Word_Bytes'(0 => Byte (V and 16#FF#), 1 => Byte (Interfaces.Shift_Right (V, 8))));

   function Float_Bytes (F : Float) return Float_Bytes_4 is
      Bits : constant Unsigned_32 := Adaflight.Float_Bits.Float_Bits (F);
   begin
      return Float_Bytes_4'(0 => Byte (Bits and 16#FF#),
                            1 => Byte (Interfaces.Shift_Right (Bits, 8) and 16#FF#),
                            2 => Byte (Interfaces.Shift_Right (Bits, 16) and 16#FF#),
                            3 => Byte (Interfaces.Shift_Right (Bits, 24)));
   end Float_Bytes;

   --  A command with a header, the blob length as a one-byte varint and
   --  the string blob ending in a zero; a blob past the payload would run
   --  past the reference's buffer (finding F87), so the text is bounded.
   procedure Queue_Blob (L : in out Link; Cmd : Byte; Header : Byte_Array; S : Text; O : in out Output)
     with Pre => Header'Length <= 5 and then Header'Length + S'Length <= Max_Payload - 2
   is
      P   : Payload := (others => 0);
      Pos : Natural := Header'Length;
   begin
      P (0 .. Header'Length - 1) := Header;
      P (Pos) := Byte (S'Length + 1);
      Pos := Pos + 1;
      for I in 0 .. S'Length - 1 loop
         P (Pos + I) := S (S'First + I);
      end loop;
      Pos := Pos + S'Length;
      P (Pos) := 0;
      Queue (L, Cmd, P (0 .. Pos), O);
   end Queue_Blob;

   procedure Reset_Receive (L : in out Link) is
   begin
      L.Recv_State := None;
      L.Recv_Crc := 0;
      L.Expected := 0;
      L.Expected_Shift := 0;
      L.Recv_Pos := 0;
   end Reset_Receive;

   procedure Request_Info (L : in out Link; Now_Ms : Unsigned_32; O : in out Output) is
   begin
      if L.Next_Info_Ms < Now_Ms then
         Queue (L, Cmd_Info, Byte_Array'(0 => Api_Version), O);
         Flush (L, O);
         L.Next_Info_Ms := Now_Ms + Info_Interval_Ms;
      end if;
   end Request_Info;

   --  One received byte through the frame states; bytes after a complete
   --  response wait for its handling and are dropped meanwhile.
   procedure Receive_Byte (L : in out Link; C : Byte) is
   begin
      case L.Recv_State is
         when None =>
            if C = Preamble_0 then
               L.Recv_State := Sync;
            end if;
         when Sync =>
            if C /= Preamble_1 then
               Reset_Receive (L);
            else
               L.Recv_State := Length;
            end if;
         when Length =>
            L.Recv_Crc := CRC8 (L.Recv_Crc, C, Polynomial);
            if L.Expected_Shift <= 15 then
               L.Expected := L.Expected or Interfaces.Shift_Left (Unsigned_16 (C and 16#7F#), L.Expected_Shift);
            end if;
            L.Expected_Shift := Natural'Min (L.Expected_Shift + 7, 28);
            if C < 16#80# then
               if L.Expected > Receive_Size then
                  Reset_Receive (L);
               else
                  L.Recv_State := (if L.Expected > 0 then Data else Checksum);
               end if;
            end if;
         when Data =>
            if L.Recv_Pos < Receive_Size then
               L.Recv (L.Recv_Pos) := C;
               L.Recv_Pos := L.Recv_Pos + 1;
            end if;
            L.Recv_Crc := CRC8 (L.Recv_Crc, C, Polynomial);
            if Unsigned_16 (L.Recv_Pos) = L.Expected then
               L.Recv_State := Checksum;
            end if;
         when Checksum =>
            if C /= L.Recv_Crc then
               Reset_Receive (L);
            else
               L.Recv_State := Done;
            end if;
         when Done =>
            null;
      end case;
   end Receive_Byte;

   --  The information response sets the version and grid, the first one
   --  clearing the screen and resetting the drawing; a font response
   --  fills the character being read.
   procedure Handle (L : in out Link; O : in out Output; OK : out Boolean) is
      Size : constant Natural := L.Recv_Pos - 1;
      Cmd  : constant Byte := L.Recv (0);
   begin
      OK := False;
      if Cmd = Cmd_Error then
         OK := Size >= 2;
      elsif Cmd = Cmd_Info then
         if Size < Info_Response_Size then
            return;
         end if;
         if L.Recv (1) /= Character'Pos ('A') or else L.Recv (2) /= Character'Pos ('G')
           or else L.Recv (3) /= Character'Pos ('H')
         then
            return;
         end if;
         L.Major := L.Recv (4);
         L.Minor := L.Recv (5);
         L.Rows := L.Recv (7);
         L.Columns := L.Recv (8);
         L.Width := Unsigned_16 (L.Recv (9)) or Interfaces.Shift_Left (Unsigned_16 (L.Recv (10)), 8);
         L.Height := Unsigned_16 (L.Recv (11)) or Interfaces.Shift_Left (Unsigned_16 (L.Recv (12)), 8);
         if not L.Initialized then
            L.Initialized := True;
            Clear_Screen (L, O);
            Reset_Drawing_State (L, O);
         end if;
         OK := True;
      elsif Cmd = Cmd_Read_Font then
         if not L.Reading_Font or else Size < 2 + Char_Bytes then
            return;
         end if;
         L.Font_Address := Unsigned_16 (L.Recv (1)) or Interfaces.Shift_Left (Unsigned_16 (L.Recv (2)), 8);
         L.Font := L.Recv (3 .. 2 + Char_Bytes);
         OK := True;
      elsif Cmd = Cmd_Write_Font then
         OK := True;
      end if;
   end Handle;

   --  The complete response handled and the receive state cleared; the
   --  link remembers whether the response was understood.
   procedure Dispatch (L : in out Link; O : in out Output)
     with Post => L.Recv_State = None and then L.Recv_Pos = 0
   is
      OK : Boolean := False;
   begin
      if L.Recv_Pos > 0 then
         Handle (L, O, OK);
      end if;
      L.Last_Handled := OK;
      Reset_Receive (L);
   end Dispatch;

   --  The bytes waiting before a request: a complete response is handled,
   --  a partial one dropped.
   procedure Clear_Receive (L : in out Link; Rx : Byte_Array; O : in out Output) is
   begin
      for I in Rx'Range loop
         Receive_Byte (L, Rx (I));
      end loop;
      if L.Recv_State = Done then
         Dispatch (L, O);
      elsif L.Recv_Pos > 0 then
         Reset_Receive (L);
      end if;
   end Clear_Receive;

   --  The reply bytes of a request that waits, all taken; a complete
   --  response among them is handled once, the bytes after it dropped.
   procedure Await_Reply (L : in out Link; Reply : Byte_Array; O : in out Output) is
   begin
      L.Last_Handled := False;
      for I in Reply'Range loop
         Receive_Byte (L, Reply (I));
      end loop;
      if L.Recv_State = Done then
         Dispatch (L, O);
      end if;
   end Await_Reply;

   ----------
   -- Init --
   ----------

   procedure Init (L : out Link; Port_Opened : Boolean; Now_Ms : Unsigned_32; O : in out Output) is
   begin
      L := (others => <>);
      L.Port_Open := Port_Opened;
      if Port_Opened then
         Request_Info (L, Now_Ms, O);
      end if;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (L : in out Link; Rx : Byte_Array; Now_Ms : Unsigned_32; O : in out Output) is
   begin
      if not L.Port_Open then
         return;
      end if;
      for I in Rx'Range loop
         Receive_Byte (L, Rx (I));
      end loop;
      if L.Recv_State = Done then
         Dispatch (L, O);
      end if;
      if not Is_Ready (L) or else Now_Ms > 0 then
         Request_Info (L, Now_Ms, O);
      end if;
   end Update;

   ------------------
   -- Transactions --
   ------------------

   procedure Begin_Transaction (L : in out Link; Opts : Transaction_Options; O : in out Output) is
   begin
      if Opts.Profiled then
         Queue (L, Cmd_Transaction_Profiled, Point (0, 10), O);
         if Opts.Reset_Drawing then
            Reset_Drawing_State (L, O);
         end if;
      elsif Opts.Reset_Drawing then
         Queue (L, Cmd_Transaction_Reset, No_Data, O);
      else
         Queue (L, Cmd_Transaction_Begin, No_Data, O);
      end if;
   end Begin_Transaction;

   --  A commit of a transaction with nothing drawn is dropped with its
   --  beginning.
   procedure Commit_Transaction (L : in out Link; O : in out Output) is
   begin
      if L.Send_Pos = 1 and then L.Send (0) in Cmd_Transaction_Begin | Cmd_Transaction_Reset then
         L.Send_Pos := 0;
         return;
      end if;
      Queue (L, Cmd_Transaction_Commit, No_Data, O);
      Flush (L, O);
   end Commit_Transaction;

   -------------
   -- Drawing --
   -------------

   procedure Draw_String_In_Grid (L : in out Link; X, Y : Unsigned_8; S : Text; O : in out Output) is
   begin
      Queue_Blob (L, Cmd_Draw_Grid_Str, Byte_Array'(X, Y, 0), S, O);
   end Draw_String_In_Grid;

   procedure Draw_Char_In_Grid (L : in out Link; X, Y : Unsigned_8; Chr : Unsigned_16; O : in out Output) is
   begin
      Queue (L, Cmd_Draw_Grid_Chr, Byte_Array'(X, Y) & U16 (Chr) & Byte_Array'(0 => 0), O);
   end Draw_Char_In_Grid;

   procedure Clear_Screen (L : in out Link; O : in out Output) is
   begin
      if Is_Ready (L) then
         Queue (L, Cmd_Clear_Screen, No_Data, O);
      end if;
   end Clear_Screen;

   function Color_Byte (C : Color) return Byte_Array is (Byte_Array'(0 => Byte (Color'Pos (C))));

   procedure Set_Stroke_Color (L : in out Link; C : Color; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Color, Color_Byte (C), O);
   end Set_Stroke_Color;

   procedure Set_Fill_Color (L : in out Link; C : Color; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Color, Color_Byte (C), O);
   end Set_Fill_Color;

   procedure Set_Stroke_And_Fill_Color (L : in out Link; C : Color; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Fill_Color, Color_Byte (C), O);
   end Set_Stroke_And_Fill_Color;

   procedure Set_Color_Inversion (L : in out Link; Inverted : Boolean; O : in out Output) is
   begin
      Queue (L, Cmd_Color_Inversion, Byte_Array'(0 => (if Inverted then 1 else 0)), O);
   end Set_Color_Inversion;

   procedure Set_Pixel (L : in out Link; X, Y : Integer; C : Color; O : in out Output) is
   begin
      Queue (L, Cmd_Set_Pixel, Point (X, Y) & Color_Byte (C), O);
   end Set_Pixel;

   procedure Set_Pixel_To_Stroke_Color (L : in out Link; X, Y : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Pixel_Stroke, Point (X, Y), O);
   end Set_Pixel_To_Stroke_Color;

   procedure Set_Pixel_To_Fill_Color (L : in out Link; X, Y : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Pixel_Fill, Point (X, Y), O);
   end Set_Pixel_To_Fill_Color;

   procedure Set_Stroke_Width (L : in out Link; Width : Unsigned_8; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Width, Byte_Array'(0 => Width), O);
   end Set_Stroke_Width;

   procedure Set_Line_Outline_Type (L : in out Link; Outline : Unsigned_8; O : in out Output) is
   begin
      Queue (L, Cmd_Outline_Type, Byte_Array'(0 => Outline), O);
   end Set_Line_Outline_Type;

   procedure Set_Line_Outline_Color (L : in out Link; C : Color; O : in out Output) is
   begin
      Queue (L, Cmd_Outline_Color, Color_Byte (C), O);
   end Set_Line_Outline_Color;

   procedure Clip_To_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Clip_To_Rect, Rect (X, Y, W, H), O);
   end Clip_To_Rect;

   procedure Clear_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Clear_Rect, Rect (X, Y, W, H), O);
   end Clear_Rect;

   procedure Reset_Drawing_State (L : in out Link; O : in out Output) is
   begin
      Queue (L, Cmd_Drawing_Reset, No_Data, O);
   end Reset_Drawing_State;

   procedure Draw_Character (L : in out Link; X, Y : Integer; Chr : Unsigned_16; Opts : Unsigned_8;
                             O : in out Output) is
   begin
      Queue (L, Cmd_Draw_Char, Point (X, Y) & U16 (Chr) & Byte_Array'(0 => Opts), O);
   end Draw_Character;

   procedure Draw_Character_Mask (L : in out Link; X, Y : Integer; Chr : Unsigned_16; C : Color; Opts : Unsigned_8;
                                  O : in out Output) is
   begin
      Queue (L, Cmd_Draw_Char_Mask, Point (X, Y) & U16 (Chr) & Byte_Array'(0 => Opts) & Color_Byte (C), O);
   end Draw_Character_Mask;

   procedure Draw_String (L : in out Link; X, Y : Integer; S : Text; Opts : Unsigned_8; O : in out Output) is
   begin
      Queue_Blob (L, Cmd_Draw_String, Point (X, Y) & Byte_Array'(0 => Opts), S, O);
   end Draw_String;

   procedure Draw_String_Mask (L : in out Link; X, Y : Integer; S : Text; C : Color; Opts : Unsigned_8;
                               O : in out Output) is
   begin
      Queue_Blob (L, Cmd_Draw_String_Mask, Point (X, Y) & Byte_Array'(0 => Opts) & Color_Byte (C), S, O);
   end Draw_String_Mask;

   procedure Move_To_Point (L : in out Link; X, Y : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Move_To, Point (X, Y), O);
   end Move_To_Point;

   procedure Stroke_Line_To_Point (L : in out Link; X, Y : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Line_To, Point (X, Y), O);
   end Stroke_Line_To_Point;

   function Triangle (X1, Y1, X2, Y2, X3, Y3 : Integer) return Triangle_Bytes is
     (Point (X1, Y1) & Point (X2, Y2) & Point (X3, Y3));

   procedure Stroke_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Triangle, Triangle (X1, Y1, X2, Y2, X3, Y3), O);
   end Stroke_Triangle;

   procedure Fill_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Triangle, Triangle (X1, Y1, X2, Y2, X3, Y3), O);
   end Fill_Triangle;

   procedure Fill_Stroke_Triangle (L : in out Link; X1, Y1, X2, Y2, X3, Y3 : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Stroke_Triangle, Triangle (X1, Y1, X2, Y2, X3, Y3), O);
   end Fill_Stroke_Triangle;

   procedure Stroke_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Rect, Rect (X, Y, W, H), O);
   end Stroke_Rect;

   procedure Fill_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Rect, Rect (X, Y, W, H), O);
   end Fill_Rect;

   procedure Fill_Stroke_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Stroke_Rect, Rect (X, Y, W, H), O);
   end Fill_Stroke_Rect;

   procedure Stroke_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Stroke_Ellipse, Rect (X, Y, W, H), O);
   end Stroke_Ellipse_In_Rect;

   procedure Fill_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Ellipse, Rect (X, Y, W, H), O);
   end Fill_Ellipse_In_Rect;

   procedure Fill_Stroke_Ellipse_In_Rect (L : in out Link; X, Y, W, H : Integer; O : in out Output) is
   begin
      Queue (L, Cmd_Fill_Stroke_Ellipse, Rect (X, Y, W, H), O);
   end Fill_Stroke_Ellipse_In_Rect;

   procedure Ctm_Reset (L : in out Link; O : in out Output) is
   begin
      Queue (L, Cmd_Ctm_Reset, No_Data, O);
   end Ctm_Reset;

   procedure Ctm_Set (L : in out Link; M11, M12, M21, M22, M31, M32 : Float; O : in out Output) is
   begin
      Queue (L, Cmd_Ctm_Set, Float_Bytes (M11) & Float_Bytes (M12) & Float_Bytes (M21) & Float_Bytes (M22)
             & Float_Bytes (M31) & Float_Bytes (M32), O);
   end Ctm_Set;

   procedure Ctm_Translate (L : in out Link; Tx, Ty : Float; O : in out Output) is
   begin
      Queue (L, Cmd_Ctm_Translate, Float_Bytes (Tx) & Float_Bytes (Ty), O);
   end Ctm_Translate;

   procedure Ctm_Scale (L : in out Link; Sx, Sy : Float; O : in out Output) is
   begin
      Queue (L, Cmd_Ctm_Scale, Float_Bytes (Sx) & Float_Bytes (Sy), O);
   end Ctm_Scale;

   procedure Ctm_Rotate (L : in out Link; R : Float; O : in out Output) is
   begin
      Queue (L, Cmd_Ctm_Rotate, Float_Bytes (R), O);
   end Ctm_Rotate;

   procedure Context_Push (L : in out Link; O : in out Output) is
   begin
      Queue (L, Cmd_Context_Push, No_Data, O);
   end Context_Push;

   procedure Context_Pop (L : in out Link; O : in out Output) is
   begin
      Queue (L, Cmd_Context_Pop, No_Data, O);
   end Context_Pop;

   -----------
   -- Fonts --
   -----------

   procedure Read_Font_Character (L : in out Link; Address : Unsigned_16; Before, Reply : Byte_Array;
                                  O : in out Output; OK : out Boolean) is
   begin
      L.Font_Address := 16#FFFF#;
      L.Reading_Font := True;
      Clear_Receive (L, Before, O);
      Queue (L, Cmd_Read_Font, U16 (Address), O);
      Flush (L, O);
      Await_Reply (L, Reply, O);
      L.Reading_Font := False;
      OK := L.Last_Handled and then L.Font_Address = Address;
   end Read_Font_Character;

   procedure Write_Font_Character (L : in out Link; Address : Unsigned_16; Chr : Char_Data; Before, Reply : Byte_Array;
                                   O : in out Output) is
   begin
      Clear_Receive (L, Before, O);
      Queue (L, Cmd_Write_Font, U16 (Address) & Chr, O);
      Flush (L, O);
      Await_Reply (L, Reply, O);
   end Write_Font_Character;

end Adaflight.FrSky_OSD;
