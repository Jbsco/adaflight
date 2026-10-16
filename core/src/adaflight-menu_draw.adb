package body Adaflight.Menu_Draw with SPARK_Mode is

   subtype Column is Adaflight.Menu.Column;
   subtype Label_Text is Adaflight.Menu.Label_Text;
   subtype Text_Length is Adaflight.Menu.Text_Length;

   Print_Value_Bit : constant Unsigned_8 := 16#20#;
   Print_Label_Bit : constant Unsigned_8 := 16#40#;

   function Col (N : Integer) return Column is (N mod 256);

   function Print_Value (Flags : Unsigned_8) return Boolean is ((Flags and Print_Value_Bit) /= 0);
   function Print_Label (Flags : Unsigned_8) return Boolean is ((Flags and Print_Label_Bit) /= 0);

   function Cut (T : Label_Text; Length : Text_Length) return Label_Text is
      R : Label_Text := T;
   begin
      R.Length := Natural'Min (T.Length, Length);
      return R;
   end Cut;

   function Decimal (V : Interfaces.Integer_32) return Label_Text is
      use type Interfaces.Integer_64;
      N       : Interfaces.Integer_64 := abs Interfaces.Integer_64 (V);
      Figures : String (1 .. 10) := (others => '0');
      Count   : Natural range 0 .. 10 := 0;
      T       : Label_Text;
   begin
      for K in 1 .. 10 loop
         pragma Loop_Invariant (Count = K - 1);
         Figures (K) := Character'Val (Character'Pos ('0') + Integer (N mod 10));
         N := N / 10;
         Count := Count + 1;
         exit when N = 0;
      end loop;
      if V < 0 then
         T.Data (1) := '-';
         T.Length := Count + 1;
         for K in 1 .. Count loop
            T.Data (1 + K) := Figures (Count + 1 - K);
         end loop;
      else
         T.Length := Count;
         for K in 1 .. Count loop
            T.Data (K) := Figures (Count + 1 - K);
         end loop;
      end if;
      return T;
   end Decimal;

   --  The display's write of a text: nothing for an empty one, else the
   --  text in the display's character set, with the bytes it takes.
   procedure Display_Write
     (On : Adaflight.Menu.Display_Index; X, Y : Column; Text : Label_Text; Cost : out Unsigned_32) is
   begin
      if Text.Length = 0 then
         Cost := 0;
      else
         declare
            T : constant Label_Text := Adaflight.Menu.Sanitized (Text);
         begin
            Write (On, X, Y, Normal, T.Data (1 .. T.Length), Cost);
         end;
      end if;
   end Display_Write;

   --  A value in its field, aligned to the right column.
   procedure Draw_Value
     (On   : Adaflight.Menu.Display_Index;
      L    : Adaflight.Menu.Layout;
      Text : in out Label_Text;
      Y    : Column;
      Size : Text_Length;
      Cost : out Unsigned_32) is
   begin
      Adaflight.Menu.Pad_Left (Text, Size);
      Display_Write (On, Col (L.Right_Column - Size), Y, Text, Cost);
   end Draw_Value;

   --  A line's value in its element's form. The option string of a submenu
   --  and the scrolling of a lookup table's text hang on flags the byte
   --  does not hold, so neither is drawn.
   procedure Draw_Entry
     (On             : Adaflight.Menu.Display_Index;
      L              : Adaflight.Menu.Layout;
      E              : Adaflight.Menu.Line;
      Row_Y          : Column;
      Selected       : Boolean;
      Flags          : in out Unsigned_8;
      Tk             : in out Adaflight.Menu.Ticker;
      Editing        : Boolean;
      Profile_Cursor : Adaflight.Menu.Profile_Number;
      Now_Ms         : Unsigned_32;
      Cost           : out Unsigned_32)
     with Pre => (if Adaflight.Menu.Element_Of (E.Flags) = Adaflight.Menu.Fixed then E.Value in 0 .. 255)
       and then L.Right_Column <= L.Left_Column + Adaflight.Menu.Max_Text + 2
   is
      Y    : Column := (if L.Small_Screen then Col (Row_Y + 1) else Row_Y);
      Buff : Label_Text;
   begin
      Cost := 0;
      case Adaflight.Menu.Element_Of (E.Flags) is
         when Adaflight.Menu.Str =>
            if Print_Value (Flags) and then E.Has_Data then
               Buff := Cut (E.Value_Text, Draw_Buffer_Length);
               Draw_Value (On, L, Buff, Y, Draw_Buffer_Length, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Submenu | Adaflight.Menu.Funcall =>
            if Print_Value (Flags) then
               if Adaflight.Menu.Element_Of (E.Flags) = Adaflight.Menu.Funcall and then E.Has_Data then
                  Buff := Cut (E.Value_Text, Draw_Buffer_Length);
               end if;
               Buff.Length := Buff.Length + 1;
               Buff.Data (Buff.Length) := '>';
               if L.Small_Screen then
                  Y := Col (Y - 1);
               end if;
               Draw_Value (On, L, Buff, Y, Buff.Length, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Bool =>
            if Print_Value (Flags) and then E.Has_Data then
               Buff.Data (1 .. 3) := (if E.Value /= 0 then "YES" else "NO ");
               Buff.Length := 3;
               Draw_Value (On, L, Buff, Y, 3, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Tab =>
            if Print_Value (Flags) then
               declare
                  Label_Length : constant Natural := E.Text.Length + 1;
                  Available    : constant Text_Length :=
                    Integer'Max (Draw_Buffer_Length, L.Right_Column - Label_Length - L.Left_Column - 1);
               begin
                  Tk := (Loop_Counter => 0, State => 0);
                  Buff := Cut (E.Value_Text, Table_Value_Length);
                  Draw_Value (On, L, Buff, Y, Available, Cost);
               end;
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Visible =>
            if Print_Value (Flags) and then E.Has_Data then
               declare
                  Blink : constant Boolean := Now_Ms mod (2 * Cursor_Blink_Delay_Ms) < Cursor_Blink_Delay_Ms;
                  Bits  : constant Interfaces.Unsigned_16 := Interfaces.Unsigned_16 (E.Value mod 65_536);
               begin
                  for X in 1 .. Adaflight.Menu.Profile_Count loop
                     Buff.Data (X) :=
                       (if Editing and then Blink and then Selected and then X = Profile_Cursor then ' '
                        elsif (Bits and Interfaces.Shift_Left (1, X - 1 + Profile_Bits_Position)) /= 0 then 'X'
                        else '-');
                  end loop;
               end;
               Buff.Length := Adaflight.Menu.Profile_Count;
               Draw_Value (On, L, Buff, Y, Adaflight.Menu.Profile_Count, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.UInt8 | Adaflight.Menu.Int8 | Adaflight.Menu.UInt16 | Adaflight.Menu.Int16
            | Adaflight.Menu.UInt32 | Adaflight.Menu.Int32 =>
            if Print_Value (Flags) and then E.Has_Data then
               Buff := Decimal (E.Value);
               Draw_Value (On, L, Buff, Y, Number_Field_Length, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Fixed =>
            if Print_Value (Flags) and then E.Has_Data then
               Buff := Adaflight.Menu.Format_Fixed (E.Value * Interfaces.Integer_32 (E.Multiplier));
               Draw_Value (On, L, Buff, Y, Number_Field_Length, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.Label =>
            if Print_Value (Flags) and then E.Has_Data then
               Display_Write (On, Col (L.Left_Column + 1 + E.Text.Length), Y, E.Value_Text, Cost);
               Flags := Flags and not Print_Value_Bit;
            end if;
         when Adaflight.Menu.OSD_Exit | Adaflight.Menu.End_Marker | Adaflight.Menu.Back | Adaflight.Menu.Guard =>
            null;
      end case;
   end Draw_Entry;

   procedure Draw
     (T              : in out Target_State;
      On             : Adaflight.Menu.Display_Index;
      M              : in out Adaflight.Menu.Table;
      Id             : Adaflight.Menu.Menu_Id;
      Has_Update     : Boolean;
      L              : Adaflight.Menu.Layout;
      P              : in out Adaflight.Menu.Page_State;
      C              : in out Adaflight.Menu.Context;
      D              : in out Adaflight.Menu.Display;
      S              : Adaflight.Menu.Slider_Settings;
      Now_Us         : Unsigned_32;
      Now_Ms         : Unsigned_32;
      Room           : Unsigned_32;
      Back_Requested : out Boolean)
   is
      Was_Cleared    : constant Boolean := D.Cleared;
      Top            : constant Column := (if L.Small_Screen then 1 else (D.Rows - P.Max_Row) / 2);
      Count          : constant Adaflight.Menu.Page_Count := Adaflight.Menu.Pages (M, L);
      Editing        : constant Boolean := C.Element_Editing;
      Profile_Cursor : constant Adaflight.Menu.Profile_Number := C.Profile_Cursor;
      Draw_Polled    : Boolean := False;
      Room_Left      : Unsigned_32 := Room;
      Cost           : Unsigned_32;
   begin
      Back_Requested := False;
      D.Cleared := False;
      if Now_Us > C.Last_Polled_Us + Poll_Interval_Us then
         Draw_Polled := True;
         C.Last_Polled_Us := Now_Us;
      end if;
      if Was_Cleared then
         for I in 0 .. P.Max_Row loop
            P.Flags (I) := P.Flags (I) or (Print_Label_Bit or Print_Value_Bit);
         end loop;
      elsif Draw_Polled then
         for I in 0 .. P.Max_Row loop
            if (M.Lines (P.Top + I).Flags and Adaflight.Menu.Dynamic) /= 0 then
               P.Flags (I) := P.Flags (I) or Print_Value_Bit;
            end if;
         end loop;
      end if;
      while P.Top + C.Cursor_Row < M.Count and then Adaflight.Menu.Skippable (M.Lines (P.Top + C.Cursor_Row), S) loop
         pragma Loop_Invariant (P.Top + C.Cursor_Row < M.Count);
         C.Cursor_Row := C.Cursor_Row + 1;
      end loop;
      if D.Cursor_Row >= 0 and then C.Cursor_Row /= D.Cursor_Row then
         Display_Write
           (On, L.Left_Column, Col (Top + D.Cursor_Row * L.Lines_Per_Item),
            (Data => (1 => ' ', others => ' '), Length => 1), Cost);
         Room_Left := Room_Left - Cost;
      end if;
      if Room_Left < Room_Floor then
         return;
      end if;
      if D.Cursor_Row /= C.Cursor_Row then
         Display_Write
           (On, L.Left_Column, Col (Top + C.Cursor_Row * L.Lines_Per_Item),
            (Data => (1 => '>', others => ' '), Length => 1), Cost);
         Room_Left := Room_Left - Cost;
         D.Cursor_Row := C.Cursor_Row;
      end if;
      if Room_Left < Room_Floor then
         return;
      end if;
      if Has_Update then
         Display_Update (T, Id, P.Top + C.Cursor_Row, Back_Requested);
         if Back_Requested then
            return;
         end if;
      end if;
      Refresh (T, Id, M);
      for I in 0 .. P.Max_Row loop
         declare
            E : constant Adaflight.Menu.Line := M.Lines (P.Top + I);
            Y : constant Column := Col (Top + I * L.Lines_Per_Item);
         begin
            if Print_Label (P.Flags (I)) then
               Display_Write
                 (On,
                  Col (L.Left_Column + (if Adaflight.Menu.Element_Of (E.Flags) = Adaflight.Menu.Label then 0 else 1)),
                  Y, E.Text, Cost);
               Room_Left := Room_Left - Cost;
               P.Flags (I) := P.Flags (I) and not Print_Label_Bit;
               if Room_Left < Room_Floor then
                  return;
               end if;
            end if;
            if Adaflight.Menu.Slider_Override (E.Flags, S) then
               Write_Char (On, Col (L.Left_Column - 1), Y, Normal, 'S');
            end if;
            if Print_Value (P.Flags (I)) then
               Draw_Entry
                 (On, L, E, Y, I = C.Cursor_Row, P.Flags (I), C.Table_Tickers (I), Editing, Profile_Cursor, Now_Ms,
                  Cost);
               Room_Left := Room_Left - Cost;
               if Room_Left < Room_Floor then
                  return;
               end if;
            end if;
         end;
      end loop;
      if Was_Cleared and then L.Left_Column > 0 then
         if P.Page > 0 then
            Write_Char (On, L.Left_Column - 1, Top, Normal, (if D.Supports_Symbols then Symbol_Arrow_Up else '^'));
         end if;
         if P.Page < Count - 1 then
            Write_Char
              (On, L.Left_Column - 1, Col (Top + P.Max_Row), Normal,
               (if D.Supports_Symbols then Symbol_Arrow_Down else 'v'));
         end if;
      end if;
   end Draw;

end Adaflight.Menu_Draw;
