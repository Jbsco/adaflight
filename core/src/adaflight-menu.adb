package body Adaflight.Menu with SPARK_Mode is

   function Layout_Of (Columns : Screen_Columns; Rows : Screen_Rows; Full_Screen : Boolean) return Layout is
      L : Layout;
   begin
      if Columns < 18 then
         L := (Small_Screen => True, Lines_Per_Item => 2, Left_Column => 0, Right_Column => Columns,
               Max_Items => Rows / 2);
      elsif Columns <= 30 then
         L := (Small_Screen => False, Lines_Per_Item => 1, Left_Column => 2, Right_Column => Columns - 2,
               Max_Items => Rows - 2);
      else
         L := (Small_Screen => False, Lines_Per_Item => 1, Left_Column => Columns / 2 - 13,
               Right_Column => Columns / 2 + 13, Max_Items => Rows - 2);
      end if;
      if Full_Screen then
         L.Left_Column := 0;
         L.Right_Column := Columns;
         L.Max_Items := Rows;
      end if;
      return L;
   end Layout_Of;

   procedure Select_Page (M : Table; L : Layout; Number : Page_Request; P : in out Page_State) is
      Count : constant Page_Count := Pages (M, L);
      Page  : constant Page_Number := (Number + Count) mod Count;
      Top   : constant Natural := Page * L.Max_Items;
   begin
      pragma Assert (Page <= (M.Count - 1) / L.Max_Items);
      pragma Assert (Top <= M.Count - 1);
      P.Page := Page;
      P.Top := Top;
      P.Max_Row := Natural'Min (Natural'Min (M.Count - Top, L.Max_Items), Max_Rows) - 1;
      for I in 0 .. P.Max_Row loop
         P.Flags (I) := Unsigned_8 (M.Lines (Top + I).Flags and 16#FF#);
      end loop;
   end Select_Page;

   function Slider_Override (Flags : Unsigned_16; S : Slider_Settings) return Boolean is
      RPY : constant Boolean := S.Mode = Adaflight.PID_Profile.RPY;
      RP  : constant Boolean := RPY or else S.Mode = Adaflight.PID_Profile.RP;
   begin
      return ((Flags and Slider_RP) /= 0 and then RP)
        or else ((Flags and Slider_RPY) /= 0 and then RPY)
        or else ((Flags and Slider_Gyro) /= 0 and then S.Gyro_Filter)
        or else ((Flags and Slider_DTerm) /= 0 and then S.DTerm_Filter);
   end Slider_Override;

   function Skippable (E : Line; S : Slider_Settings) return Boolean is
   begin
      case Element_Of (E.Flags) is
         when Label | Str =>
            return True;
         when UInt8 | Int8 | UInt16 | Int16 =>
            return E.Flags = Dynamic or else Slider_Override (E.Flags, S);
         when Back | OSD_Exit | Submenu | Funcall | Bool | UInt32 | Int32 | Fixed | Visible | Tab | End_Marker
            | Guard =>
            return False;
      end case;
   end Skippable;

   function Format_Fixed (Value : Fixed_Value) return Label_Text is
      N     : Natural := Natural (Value) + 100_000;
      Len   : constant Natural range 6 .. 8 := (if N >= 10_000_000 then 8 elsif N >= 1_000_000 then 7 else 6);
      Chars : String (1 .. 8) := (others => ' ');
      Last  : Natural range 4 .. 8 := Len;
      T     : Label_Text;
   begin
      for I in reverse 1 .. Len loop
         Chars (I) := Character'Val (Character'Pos ('0') + N mod 10);
         N := N / 10;
      end loop;
      Chars (1) := Chars (2);
      Chars (2) := Chars (3);
      Chars (3) := '.';
      if Chars (6) = '0' or else Chars (6) = '.' then
         Last := 5;
         if Chars (5) = '0' or else Chars (5) = '.' then
            Last := 4;
         end if;
      end if;
      if Chars (1) = '0' then
         Chars (1) := ' ';
      end if;
      T.Data (1 .. Last) := Chars (1 .. Last);
      T.Length := Last;
      return T;
   end Format_Fixed;

   procedure Pad_Left (T : in out Label_Text; Size : Text_Length) is
      Len   : constant Text_Length := Natural'Min (T.Length, Size);
      Shift : constant Text_Length := Size - Len;
   begin
      for I in reverse Shift + 1 .. Size loop
         T.Data (I) := T.Data (I - Shift);
      end loop;
      for I in 1 .. Shift loop
         T.Data (I) := ' ';
      end loop;
      T.Length := Size;
   end Pad_Left;

   procedure Clear_Screen (D : in out Display) is
   begin
      D.Cleared := True;
      D.Cursor_Row := -1;
   end Clear_Screen;

   function Sanitized (T : Label_Text) return Label_Text is
      R : Label_Text := T;
   begin
      for I in 1 .. T.Length loop
         declare
            C : Character := T.Data (I);
         begin
            if C in 'a' .. 'z' then
               C := Character'Val (Character'Pos (C) - 32);
            end if;
            R.Data (I) := (if C < ' ' or else C > '_' then ' ' else C);
         end;
      end loop;
      return R;
   end Sanitized;

end Adaflight.Menu;
