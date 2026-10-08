package body Adaflight.PWL with SPARK_Mode is

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (T : out Table; Num_Points : Point_Count; X_Min : Signal; X_Max : Signal)
   is
   begin
      T := (Y          => (others => 0.0),
            Num_Points => Num_Points,
            X_Min      => X_Min,
            X_Max      => X_Max,
            DX         => Float'Max (Min_Step, (X_Max - X_Min) / Float (Num_Points - 1)));
   end Initialize;

   ----------
   -- Fill --
   ----------

   procedure Fill (T : in out Table) is
   begin
      for I in 0 .. T.Num_Points - 1 loop
         pragma Loop_Invariant (T.Num_Points = T.Num_Points'Loop_Entry
                                and then T.X_Min = T.X_Min'Loop_Entry
                                and then T.X_Max = T.X_Max'Loop_Entry
                                and then T.DX = T.DX'Loop_Entry);
         T.Y (I) := F (T.X_Min + Float (I) * T.DX);
      end loop;
   end Fill;

   --  Floor of a non-negative position, held below the point count so the
   --  result is an index.
   function Floor_Index (Position : Float) return Point_Index
     with Pre => Position >= 0.0
   is
      Clamped : constant Float := Float'Min (Position, Float (Max_Points - 1));
      Rounded : constant Natural := Natural (Clamped);
   begin
      if Float (Rounded) > Clamped then
         return Rounded - 1;
      else
         return Rounded;
      end if;
   end Floor_Index;

   -----------------
   -- Interpolate --
   -----------------

   function Interpolate (T : Table; X : Signal) return Float is
      Last : constant Point_Index := T.Num_Points - 1;
   begin
      if X <= T.X_Min then
         return T.Y (0);
      end if;
      if X >= T.X_Max then
         return T.Y (Last);
      end if;
      declare
         DX       : constant Step := T.DX;
         Offset   : constant Float := X - T.X_Min;
         Position : constant Float := Offset / DX;
         Index    : Point_Index;
      begin
         pragma Assert (Offset >= 0.0);
         Index := Floor_Index (Position);
         if Index >= Last then
            return T.Y (Last);
         end if;
         declare
            X0 : constant Float := T.X_Min + Float (Index) * DX;
            Y0 : constant Signal := T.Y (Index);
            Y1 : constant Signal := T.Y (Index + 1);
            DY : constant Float := Y1 - Y0;
            DP : constant Float := (X - X0) * DY;
         begin
            pragma Assert (abs X0 <= 2.0 ** 39);
            pragma Assert (abs DP <= 2.0 ** 74);
            declare
               Q : constant Float := DP / DX;
            begin
               pragma Assert (abs Q <= 2.0 ** 101);
               return Y0 + Q;
            end;
         end;
      end;
   end Interpolate;

end Adaflight.PWL;
