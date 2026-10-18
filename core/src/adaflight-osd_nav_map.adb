package body Adaflight.OSD_Nav_Map with SPARK_Mode is

   Blank      : constant Byte := 16#20#;
   Home_Flag  : constant Byte := 16#11#;
   Over_Home  : constant Byte := 16#05#;
   AH_Right   : constant Byte := 16#02#;
   AH_Left    : constant Byte := 16#03#;
   Arrow_Up   : constant Byte := 16#75#;
   Bar_0      : constant Byte := 16#80#;
   Vertical   : constant Byte := 16#16#;
   Horizontal : constant Byte := 16#17#;

   Interior_Cols : constant := Cols - 2;
   Interior_Rows : constant := Rows - 2;
   Marker_Max    : constant := 9;

   Rad : constant Float := Float'Machine (Float'Machine (3.14159265358979323846) / 180.0);

   --  Centimetres per unit of latitude at the equator, folded as the
   --  reference's compiler folds it.
   Angle_To_Cm : constant Float :=
     Float'Machine (Float'Machine (Float'Machine (Float'Machine (111.3195) * 1000.0) * 100.0) / 10_000_000.0);

   subtype Cell_F is Float range -3.0e8 .. 3.0e8;
   subtype Cell_Span is Float range -1.0e9 .. 1.0e9;
   subtype Line_Cm is Float range -4.0e10 .. 4.0e10;

   type Vector is record
      X : Position_Cm := 0.0;
      Y : Position_Cm := 0.0;
   end record;

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then not Unsigned_32 (-(I + 1)) else Unsigned_32 (I));

   function Wrapped_Difference (A, B : Integer_32) return Integer_32 is
     (To_Signed (To_Unsigned (A) - To_Unsigned (B)));

   --  The nearest whole number with ties to even, as the C library rounds.
   subtype Rounded is Integer_32 range -2_000_000_001 .. 2_000_000_001;
   function Round (X : Float) return Rounded is
     (if abs X < 16_777_215.0 then Integer_32 (Maths.Round_Half_Even (X)) else Integer_32 (X))
     with Pre => abs X <= 2.0e9;

   function Wrap_Deg360 (Deg : Integer) return Natural is
     (if Deg rem 360 < 0 then Deg rem 360 + 360 else Deg rem 360)
     with Post => Wrap_Deg360'Result < 360;

   function Positional (Kind : Byte) return Boolean is (Kind <= 4);

   --  The offsets east and north from one position to another, the
   --  longitudes folded across the antimeridian.
   function Distance_2D (From, To : Location; Cos_Lat : Maths.Cosine) return Vector
     with Global => null
   is
      D_Lon : Integer_32 := Wrapped_Difference (To.Longitude, From.Longitude);
   begin
      if D_Lon > 1_800_000_000 then
         D_Lon := D_Lon - 1_800_000_000;
         D_Lon := D_Lon - 1_800_000_000;
      elsif D_Lon <= -1_800_000_000 then
         D_Lon := D_Lon + 1_800_000_000;
         D_Lon := D_Lon + 1_800_000_000;
      end if;
      return (X => Float (D_Lon) * Cos_Lat * Angle_To_Cm,
              Y => Float (Wrapped_Difference (To.Latitude, From.Latitude)) * Angle_To_Cm);
   end Distance_2D;

   function Select_Scale_M (Required_M : Unsigned_32) return Unsigned_32 is
      type Step_Table is array (0 .. 22) of Unsigned_32;
      Steps : constant Step_Table :=
        (20, 30, 50, 75, 100, 150, 200, 300, 400, 600, 800, 1200, 1600, 2400, 3200, 4800, 6400, 9600, 12800, 19200,
         25600, 38400, 51200);
   begin
      for I in Steps'Range loop
         if Required_M <= Steps (I) then
            return Steps (I);
         end if;
      end loop;
      return Steps (Steps'Last);
   end Select_Scale_M;

   procedure World_To_View (S : State; P : Vector; View_X, View_Y : out View_Cm)
     with Global => null
   is
      Rel_East  : constant Float := P.X - S.Center_East;
      Rel_North : constant Float := P.Y - S.Center_North;
   begin
      if S.Rotated then
         View_X := Rel_East * S.Cos_Rot - Rel_North * S.Sin_Rot;
         View_Y := Rel_East * S.Sin_Rot + Rel_North * S.Cos_Rot;
      else
         View_X := Rel_East;
         View_Y := Rel_North;
      end if;
   end World_To_View;

   procedure View_To_Cell (S : State; View_X, View_Y : Line_Cm; Col_F, Row_F : out Cell_F)
     with Global => null
   is
   begin
      Col_F := Float (Interior_Cols - 1) * 0.5 + View_X / S.Cm_Per_Col;
      Row_F := Float (Interior_Rows - 1) * 0.5 - View_Y / S.Cm_Per_Row;
   end View_To_Cell;

   function In_Interior (Col, Row : Integer_32) return Boolean is
     (Col >= 0 and then Col < Interior_Cols and then Row >= 0 and then Row < Interior_Rows);

   procedure Plot_Cell (S : in out State; Col, Row : Integer_32; Glyph : Byte)
     with Global => null
   is
   begin
      if In_Interior (Col, Row) then
         S.Frame (Natural (Row) + 1) (Natural (Col) + 1) := Glyph;
      end if;
   end Plot_Cell;

   procedure Plot_Cell_Clamped (S : in out State; Col, Row : Integer_32; Glyph : Byte)
     with Global => null
   is
      C : constant Natural := Natural (Integer_32'Max (0, Integer_32'Min (Col, Interior_Cols - 1)));
      R : constant Natural := Natural (Integer_32'Max (0, Integer_32'Min (Row, Interior_Rows - 1)));
   begin
      S.Frame (R + 1) (C + 1) := Glyph;
   end Plot_Cell_Clamped;

   --  The bar glyph for a fraction of a cell from its centre; past one
   --  cell the glyph is the end one either way.
   function Bar (D : Float) return Byte is
     (Bar_0
      + Byte (Integer_32'Max (0, Integer_32'Min (Round ((Float'Max (-1.0, Float'Min (1.0, D)) + 0.5) * 8.0), 8))));

   --  A line between two points, clipped to the view, as one bar per column
   --  for a shallow line or one vertical bar per row for a steep one; a
   --  column whose bar sits one row from the bar already there is skipped.
   procedure Plot_World_Line (S : in out State; From, To : Vector)
     with Global => null
   is
      X0, Y0, X1, Y1 : View_Cm;
   begin
      World_To_View (S, From, X0, Y0);
      World_To_View (S, To, X1, Y1);
      declare
         Half_W : constant Float := Float (Interior_Cols) * 0.5 * S.Cm_Per_Col;
         Half_H : constant Float := Float (Interior_Rows) * 0.5 * S.Cm_Per_Row;
         DX     : constant Float := X1 - X0;
         DY     : constant Float := Y1 - Y0;
         type Four is array (0 .. 3) of Float;
         P      : constant Four := (-DX, DX, -DY, DY);
         Q      : constant Four := (X0 + Half_W, Half_W - X0, Y0 + Half_H, Half_H - Y0);
         T0     : Float := 0.0;
         T1     : Float := 1.0;
      begin
         for I in Four'Range loop
            pragma Loop_Invariant (T0 >= 0.0 and then T1 <= 1.0);
            if abs P (I) < 1.0E-6 then
               if Q (I) < 0.0 then
                  return;
               end if;
            else
               declare
                  T : constant Float := Q (I) / P (I);
               begin
                  if P (I) < 0.0 then
                     T0 := Float'Max (T0, T);
                  else
                     T1 := Float'Min (T1, T);
                  end if;
               end;
            end if;
         end loop;
         if T0 > T1 then
            return;
         end if;
         declare
            Col_F0, Row_F0, Col_F1, Row_F1 : Cell_F;
         begin
            View_To_Cell (S, X0 + T0 * DX, Y0 + T0 * DY, Col_F0, Row_F0);
            View_To_Cell (S, X0 + T1 * DX, Y0 + T1 * DY, Col_F1, Row_F1);
            declare
               D_Col  : constant Float := Col_F1 - Col_F0;
               D_Row  : constant Float := Row_F1 - Row_F0;
               AD_Col : constant Float := abs D_Col;
               AD_Row : constant Float := abs D_Row;
            begin
               if AD_Col < 0.05 and then AD_Row < 0.05 then
                  declare
                     Row : constant Integer_32 := Round (Row_F0);
                  begin
                     Plot_Cell (S, Round (Col_F0), Row, Bar (Row_F0 - Float (Row)));
                  end;
                  return;
               end if;
               if AD_Row <= AD_Col then
                  pragma Assert (AD_Col >= 0.05);
                  for Col in Round (Float'Min (Col_F0, Col_F1)) .. Round (Float'Max (Col_F0, Col_F1)) loop
                     declare
                        T   : constant Float :=
                          Float'Max (0.0, Float'Min (1.0, (Float (Col) - Col_F0) / D_Col));
                        R_F : constant Cell_Span := Row_F0 + T * D_Row;
                        Row : constant Integer_32 := Round (R_F);
                        Skip : Boolean := False;
                     begin
                        if Col >= 0 and then Col < Cols then
                           declare
                              Marked : constant Byte := S.Bar_Row (Natural (Col));
                           begin
                              if Marked /= 0 and then abs (Integer_32 (Marked) - (Row + 1)) <= 1 then
                                 Skip := True;
                              else
                                 S.Bar_Row (Natural (Col)) := Byte'Mod (Row + 1);
                              end if;
                           end;
                        end if;
                        if not Skip then
                           Plot_Cell (S, Col, Row, Bar (R_F - Float (Row)));
                        end if;
                     end;
                  end loop;
               else
                  pragma Assert (AD_Row >= 0.05);
                  for Row in Round (Float'Min (Row_F0, Row_F1)) .. Round (Float'Max (Row_F0, Row_F1)) loop
                     declare
                        T : constant Float := Float'Max (0.0, Float'Min (1.0, (Float (Row) - Row_F0) / D_Row));
                     begin
                        Plot_Cell (S, Round (Col_F0 + T * D_Col), Row, Vertical);
                     end;
                  end loop;
               end if;
            end;
         end;
      end;
   end Plot_World_Line;

   --  The trail from launch, then on to the craft with a position.
   procedure Plot_Trail (S : in out State; Inp : Inputs; Craft : Vector; Position_Valid : Boolean)
     with Global => null
   is
      Prev       : Vector := (0.0, 0.0);
      Prev_Valid : Boolean := False;
   begin
      for I in 0 .. Inp.Trail_Count - 1 loop
         declare
            Cur : constant Vector :=
              (X => Float (Inp.Trail (I).East_M) * 100.0, Y => Float (Inp.Trail (I).North_M) * 100.0);
         begin
            if Prev_Valid then
               Plot_World_Line (S, Prev, Cur);
            end if;
            Prev := Cur;
            Prev_Valid := True;
         end;
      end loop;
      if Prev_Valid and then Position_Valid then
         Plot_World_Line (S, Prev, Craft);
      end if;
   end Plot_Trail;

   --  Ticks at the compass points of the largest round distance that fits.
   procedure Plot_Range_Ring (S : in out State; Scale_M : Unsigned_32)
     with Global => null
   is
      type Ring_Table is array (0 .. 9) of Unsigned_32;
      Steps : constant Ring_Table := (25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000);
      type Ticks is array (0 .. 3) of Float;
      Tick_East  : constant Ticks := (0.0, 1.0, 0.0, -1.0);
      Tick_North : constant Ticks := (1.0, 0.0, -1.0, 0.0);
      Half_Height_M : constant Float := Float (Interior_Rows) * 0.5 * S.Cm_Per_Row / 100.0;
      Max_Radius_M  : constant Float := 0.85 * Float'Min (0.5 * Float (Scale_M), Half_Height_M);
      Radius_M      : Unsigned_32 := 0;
   begin
      for I in Steps'Range loop
         if Float (Steps (I)) <= Max_Radius_M then
            Radius_M := Steps (I);
         end if;
      end loop;
      if Radius_M = 0 then
         return;
      end if;
      declare
         Radius_Cm : constant Float := Float (Radius_M) * 100.0;
      begin
         for I in Ticks'Range loop
            declare
               V_X, V_Y : View_Cm;
               C_F, R_F : Cell_F;
            begin
               World_To_View (S, (X => Tick_East (I) * Radius_Cm, Y => Tick_North (I) * Radius_Cm), V_X, V_Y);
               View_To_Cell (S, V_X, V_Y, C_F, R_F);
               Plot_Cell (S, Round (C_F), Round (R_F), Character'Pos ('+'));
            end;
         end loop;
      end;
   end Plot_Range_Ring;

   procedure Plot_Marker (S : in out State; P : Vector; Glyph : Byte; Clamp_To_Edge : Boolean)
     with Global => null
   is
      V_X, V_Y : View_Cm;
      C_F, R_F : Cell_F;
   begin
      World_To_View (S, P, V_X, V_Y);
      View_To_Cell (S, V_X, V_Y, C_F, R_F);
      if Clamp_To_Edge then
         Plot_Cell_Clamped (S, Round (C_F), Round (R_F), Glyph);
      else
         Plot_Cell (S, Round (C_F), Round (R_F), Glyph);
      end if;
   end Plot_Marker;

   --  Text of at most sixteen characters.
   subtype Text_Length is Natural range 0 .. 16;
   type Text_Bytes is array (1 .. 16) of Byte;
   type Text is record
      Data   : Text_Bytes := (others => 0);
      Length : Text_Length := 0;
   end record;

   procedure Append (T : in out Text; B : Byte)
     with Global => null
   is
   begin
      if T.Length < 16 then
         T.Length := T.Length + 1;
         T.Data (T.Length) := B;
      end if;
   end Append;

   procedure Append_Number (T : in out Text; N : Natural)
     with Global => null
   is
      Digits_Buf : array (1 .. 10) of Byte := (others => 0);
      Count      : Natural range 0 .. 10 := 0;
      V          : Natural := N;
   begin
      loop
         pragma Loop_Invariant (Count < 10);
         Count := Count + 1;
         Digits_Buf (Count) := Character'Pos ('0') + Byte (V mod 10);
         V := V / 10;
         exit when V = 0 or else Count = 10;
      end loop;
      for I in reverse 1 .. Count loop
         Append (T, Digits_Buf (I));
      end loop;
   end Append_Number;

   procedure Draw_Border_And_Scale (S : in out State; C : Settings; Scale_M : Scale_Value)
     with Global => null
   is
      Value : Text;
      Label : Text;
   begin
      for Col in Col_Index loop
         S.Frame (0) (Col) := Horizontal;
         S.Frame (Rows - 1) (Col) := Horizontal;
      end loop;
      for Row in 1 .. Rows - 2 loop
         S.Frame (Row) (0) := Vertical;
         S.Frame (Row) (Cols - 1) := Vertical;
      end loop;
      if S.Rotated then
         S.Frame (0) (1) := Arrow_Up;
      else
         S.Frame (0) (1) := Character'Pos ('N');
         S.Frame (0) (2) := Arrow_Up;
      end if;
      declare
         Converted : constant Integer_32 := Round (OSD_Format.Meters_To_Unit (Integer_32 (Scale_M), C.Units));
      begin
         if Converted >= 10_000 then
            Append_Number (Value, Natural (Converted / 1000));
            Append (Value, Character'Pos ('.'));
            Append_Number (Value, Natural ((Converted mod 1000) / 100));
            Append (Value, Character'Pos ('K'));
         else
            Append_Number (Value, Natural (Integer_32'Max (0, Converted)));
            Append (Value, Character'Pos (OSD_Format.Meters_Symbol (C.Units)));
         end if;
      end;
      if Scale_M /= S.Last_Scale_M then
         S.Flash_Frames := 24;
         S.Zoomed_Out := S.Last_Scale_M /= 0 and then Scale_M > S.Last_Scale_M;
         if S.Last_Scale_M = 0 then
            S.Flash_Frames := 18;
         end if;
         S.Last_Scale_M := Scale_M;
      end if;
      if S.Flash_Frames = 0 then
         return;
      end if;
      S.Flash_Frames := S.Flash_Frames - 1;
      if S.Flash_Frames > 12 and then (S.Anim_Phase / 2) mod 2 = 1 then
         if S.Zoomed_Out then
            Append (Label, AH_Left);
            Append (Label, AH_Left);
            for I in 1 .. Value.Length loop
               Append (Label, Value.Data (I));
            end loop;
            Append (Label, AH_Right);
            Append (Label, AH_Right);
         else
            Append (Label, AH_Right);
            for I in 1 .. Value.Length loop
               Append (Label, Value.Data (I));
            end loop;
            Append (Label, AH_Left);
         end if;
      else
         Append (Label, AH_Left);
         for I in 1 .. Value.Length loop
            Append (Label, Value.Data (I));
         end loop;
         Append (Label, AH_Right);
      end if;
      declare
         Start : constant Integer := Cols - 1 - Label.Length;
      begin
         if Start > 0 then
            for I in 1 .. Label.Length loop
               if Start + I - 1 <= Col_Index'Last then
                  S.Frame (Rows - 1) (Start + I - 1) := Label.Data (I);
               end if;
            end loop;
         end if;
      end;
   end Draw_Border_And_Scale;

   procedure Draw_Centered (S : in out State; Message : String)
     with Global => null, Pre => Message'Length <= Cols and then Message'First = 1
   is
      Start : constant Integer := Integer'Max (1, (Cols - Message'Length) / 2);
   begin
      for I in 0 .. Message'Length - 1 loop
         exit when Start + I >= Cols - 1;
         S.Frame (Rows / 2) (Start + I) := Character'Pos (Message (Message'First + I));
      end loop;
   end Draw_Centered;

   procedure Plot_Waypoint_Markers (S : in out State; Inp : Inputs)
     with Global => null
   is
      Count : constant Natural := Natural'Min (Natural (Inp.Waypoint_Count), Max_Waypoints);
   begin
      for I in 0 .. Natural'Min (Count, Marker_Max) - 1 loop
         if Positional (Inp.Waypoints (I).Kind)
           and then not (Inp.Nav_Active and then I = Natural (Inp.Nav_Index) and then (S.Anim_Phase / 4) mod 2 = 1)
         then
            Plot_Marker
              (S, Distance_2D (Inp.Home, (Inp.Waypoints (I).Latitude, Inp.Waypoints (I).Longitude), Inp.Cos_Lat),
               Character'Pos ('1') + Byte (I), False);
         end if;
      end loop;
   end Plot_Waypoint_Markers;

   procedure Prepare_Frame (S : in out State; C : Settings; Inp : Inputs)
     with Global => null
   is
      Home_Valid     : constant Boolean := Inp.Fix_Home;
      Fix_Valid      : constant Boolean := Inp.Fix;
      Position_Valid : constant Boolean := Home_Valid and then Fix_Valid;
      Craft          : Vector := (0.0, 0.0);
      Heading        : constant Natural := Wrap_Deg360 (Integer (Inp.Yaw_Deci) / 10);
      Max_X          : Float := 100.0;
      Max_Y          : Float := 100.0;
      V_X, V_Y       : View_Cm;
   begin
      S.Frame := (others => (others => Blank));
      S.Bar_Row := (others => 0);
      S.Anim_Phase := S.Anim_Phase + 1;
      if Position_Valid then
         Craft := Distance_2D (Inp.Home, Inp.Craft, Inp.Cos_Lat);
      end if;
      S.Rotated := C.Heading_Up and then Position_Valid;
      if S.Rotated then
         declare
            Rot_Rad : constant Float := Float (Heading) * Rad;
         begin
            S.Sin_Rot := Maths.Sin_Approx (Rot_Rad);
            S.Cos_Rot := Maths.Cos_Approx (Rot_Rad);
         end;
      else
         S.Sin_Rot := 0.0;
         S.Cos_Rot := 1.0;
      end if;
      if C.Centre_Craft then
         S.Center_East := Craft.X;
         S.Center_North := Craft.Y;
      else
         S.Center_East := 0.0;
         S.Center_North := 0.0;
      end if;
      World_To_View (S, Craft, V_X, V_Y);
      Max_X := Float'Max (Max_X, abs V_X);
      Max_Y := Float'Max (Max_Y, abs V_Y);
      if Home_Valid then
         declare
            Count : constant Natural := Natural'Min (Natural (Inp.Waypoint_Count), Max_Waypoints);
         begin
            for I in 0 .. Natural'Min (Count, Marker_Max) - 1 loop
               pragma Loop_Invariant (Max_X in 100.0 .. 1.0e10 and then Max_Y in 100.0 .. 1.0e10);
               if Positional (Inp.Waypoints (I).Kind) then
                  World_To_View
                    (S, Distance_2D (Inp.Home, (Inp.Waypoints (I).Latitude, Inp.Waypoints (I).Longitude), Inp.Cos_Lat),
                     V_X, V_Y);
                  Max_X := Float'Max (Max_X, abs V_X);
                  Max_Y := Float'Max (Max_Y, abs V_Y);
               end if;
            end loop;
         end;
      end if;
      declare
         Height_As_Width : constant Float := Max_Y * Float (Interior_Cols) / (1.5 * Float (Interior_Rows));
         Required_M      : constant Unsigned_32 :=
           Unsigned_32 (Integer_32'Max (0, Round (2.0 * Float'Max (Max_X, Height_As_Width) * 1.25 / 100.0)));
         New_Scale       : Unsigned_32 := Select_Scale_M (Required_M);
         Min_Scale       : constant Unsigned_32 := Unsigned_32'Max (Unsigned_32 (C.Min_Scale_M), 20);
      begin
         if New_Scale < Min_Scale then
            New_Scale := Min_Scale;
         end if;
         if S.Auto_Scale_M = 0 or else New_Scale > S.Auto_Scale_M
           or else (New_Scale < S.Auto_Scale_M and then Float (Required_M) < 0.8 * Float (New_Scale))
         then
            S.Auto_Scale_M := New_Scale;
         end if;
      end;
      declare
         Scale_M : constant Scale_Value := S.Auto_Scale_M;
      begin
         S.Cm_Per_Col := Float (Scale_M) * 100.0 / Float (Interior_Cols);
         S.Cm_Per_Row := S.Cm_Per_Col * 1.5;
         Draw_Border_And_Scale (S, C, Scale_M);
         if not Home_Valid then
            Draw_Centered (S, (if Fix_Valid then "SET HOME" else "WAIT GPS"));
            return;
         end if;
         Plot_Range_Ring (S, Scale_M);
         Plot_Trail (S, Inp, Craft, Position_Valid);
         Plot_Waypoint_Markers (S, Inp);
      end;
      declare
         C_F, R_F : Cell_F;
      begin
         World_To_View (S, (0.0, 0.0), V_X, V_Y);
         View_To_Cell (S, V_X, V_Y, C_F, R_F);
         declare
            Home_Col : constant Integer_32 := Round (C_F);
            Home_Row : constant Integer_32 := Round (R_F);
         begin
            if In_Interior (Home_Col, Home_Row) then
               Plot_Cell (S, Home_Col, Home_Row, Home_Flag);
            else
               Plot_Cell_Clamped
                 (S, Home_Col, Home_Row,
                  Character'Pos (OSD_Format.Direction_Symbol
                    (Wrap_Deg360 (Integer (Round (Maths.Atan2_Approx (Y => V_X, X => V_Y) / Rad))))));
            end if;
         end;
      end;
      if Position_Valid then
         if Maths.Sqrt_Non_Negative (Craft.X * Craft.X + Craft.Y * Craft.Y) < Float'Min (S.Cm_Per_Col, 1000.0) then
            Plot_Marker (S, Craft, Over_Home, True);
         else
            Plot_Marker
              (S, Craft, Character'Pos (OSD_Format.Direction_Symbol (if S.Rotated then 0 else Heading)), True);
         end if;
      else
         Draw_Centered (S, "NO GPS");
      end if;
   end Prepare_Frame;

   procedure Render (S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Byte; Screen_Rows, Screen_Cols : Byte;
                     O : out Output) is
   begin
      O := (others => <>);
      if not S.Prepared then
         Prepare_Frame (S, C, Inp);
         S.Prepared := True;
         S.Render_Row := 0;
      end if;
      if Natural (Pos_Y) + S.Render_Row >= Natural (Screen_Rows) or else S.Render_Row = Rows then
         O.Draw := False;
         S.Prepared := False;
         return;
      end if;
      O.Line := S.Frame (S.Render_Row);
      O.Length := Cols;
      for I in Col_Index loop
         if O.Line (I) = 0 then
            O.Length := I;
            exit;
         end if;
      end loop;
      declare
         Max_Len : constant Integer := Integer (Screen_Cols) - Integer (Pos_X);
      begin
         if Max_Len <= 0 then
            O.Draw := False;
            S.Prepared := False;
            return;
         end if;
         if O.Length > Max_Len then
            O.Length := Max_Len;
         end if;
      end;
      O.Offset_Y := Byte (S.Render_Row);
      S.Render_Row := S.Render_Row + 1;
      if S.Render_Row < Rows then
         O.Rendered := False;
      else
         S.Prepared := False;
      end if;
   end Render;

end Adaflight.OSD_Nav_Map;
