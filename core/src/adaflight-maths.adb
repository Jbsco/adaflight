with Ada.Numerics.Elementary_Functions;

package body Adaflight.Maths with SPARK_Mode is

   subtype Reduced is Float range -0.5 .. 0.5;
   subtype Reduced_Square is Float range 0.0 .. 0.25;
   type Quadrant is mod 4;

   --  Polynomial coefficients for sin and cos on the reduced argument
   --  r in [-0.5, 0.5], where the angle is r * Pi / 2.

   Sin_C0 : constant Float := 16#1.921F1C#;
   Sin_C1 : constant Float := -16#1.4A974# / 2.0;
   Sin_C2 : constant Float := 16#1.3DB294# / 16.0;

   Cos_D1 : constant Float := -16#1.3BD39C#;
   Cos_D2 : constant Float := 16#1.03B# / 4.0;
   Cos_D3 : constant Float := -16#1.4E5EEC# / 64.0;

   function Sin_Poly (R : Reduced; S : Reduced_Square) return Cosine is
     (R * ((Sin_C2 * S + Sin_C1) * S + Sin_C0));

   function Cos_Poly (S : Reduced_Square) return Cosine is
     (((Cos_D3 * S + Cos_D2) * S + Cos_D1) * S + 1.0);

   function Square (R : Reduced) return Reduced_Square is (R * R)
     with Inline;

   procedure Range_Reduce (X : Angle; R : out Reduced; Q : out Quadrant)
     with Inline
   is
      T  : constant Float := X * Two_Over_Pi;
      QF : constant Float := Float'Rounding (T);
      QI : constant Integer := Integer (QF);
   begin
      pragma Assert (QF >= T - 0.5 and then QF <= T + 0.5);
      R := T - QF;
      Q := Quadrant (QI mod 4);
   end Range_Reduce;

   function Sin_Quadrant (R : Reduced; Q : Quadrant) return Cosine
     with Inline
   is
      S : constant Reduced_Square := Square (R);
      V : Cosine;
   begin
      if (Q and 1) /= 0 then
         V := Cos_Poly (S);
      else
         V := Sin_Poly (R, S);
      end if;
      if (Q and 2) /= 0 then
         return -V;
      else
         return V;
      end if;
   end Sin_Quadrant;

   function Cos_Quadrant (R : Reduced; Q : Quadrant) return Cosine
     with Inline
   is
      S : constant Reduced_Square := Square (R);
      V : Cosine;
   begin
      if (Q and 1) /= 0 then
         V := -Sin_Poly (R, S);
      else
         V := Cos_Poly (S);
      end if;
      if (Q and 2) /= 0 then
         return -V;
      else
         return V;
      end if;
   end Cos_Quadrant;

   ----------------
   -- Sin_Approx --
   ----------------

   function Sin_Approx (X : Angle) return Cosine is
      R : Reduced;
      Q : Quadrant;
   begin
      Range_Reduce (X, R, Q);
      return Sin_Quadrant (R, Q);
   end Sin_Approx;

   ----------------
   -- Cos_Approx --
   ----------------

   function Cos_Approx (X : Angle) return Cosine is
      R : Reduced;
      Q : Quadrant;
   begin
      Range_Reduce (X, R, Q);
      return Cos_Quadrant (R, Q);
   end Cos_Approx;

   --------------------
   -- Sin_Cos_Approx --
   --------------------

   procedure Sin_Cos_Approx (X : Angle; S : out Cosine; C : out Cosine) is
      R  : Reduced;
      Q  : Quadrant;
      SS : Reduced_Square;
      SB : Cosine;
      CB : Cosine;
   begin
      Range_Reduce (X, R, Q);
      SS := Square (R);
      SB := Sin_Poly (R, SS);
      CB := Cos_Poly (SS);
      if (Q and 1) /= 0 then
         S := CB;
         C := -SB;
      else
         S := SB;
         C := CB;
      end if;
      if (Q and 2) /= 0 then
         S := -S;
         C := -C;
      end if;
   end Sin_Cos_Approx;

   ----------------
   -- Tan_Approx --
   ----------------

   function Tan_Approx (X : Tan_Argument) return Tangent is
      T  : constant Float := X * Two_Over_Pi;
      QF : constant Float := Float'Rounding (T);
      R  : Reduced;
      S  : Reduced_Square;
      SN : Cosine;
      CS : Float;
   begin
      pragma Assert (T in 0.0 .. 0.9614);
      pragma Assert (QF >= T - 0.5 and then QF <= T + 0.5);
      pragma Assert (QF = 0.0 or else QF = 1.0);
      R := T - QF;
      S := Square (R);
      if QF = 1.0 then
         pragma Assert (R in -0.5 .. -0.0386);
         SN := Cos_Poly (S);
         CS := -Sin_Poly (R, S);
         pragma Assert (CS >= 0.054);
      else
         SN := Sin_Poly (R, S);
         CS := Cos_Poly (S);
         pragma Assert (CS >= 0.69);
      end if;
      pragma Assert (SN >= 0.0);
      return Float'Min (Max_Tan, SN / CS);
   end Tan_Approx;

   ------------------
   -- Atan2_Approx --
   ------------------

   function Atan2_Approx (Y : Float; X : Float) return Half_Turn is
      P1 : constant Float := 3.14551665884836e-07;
      P2 : constant Float := 0.99997356613987;
      P3 : constant Float := 0.14744007058297684;
      P4 : constant Float := 0.3099814292351353;
      P5 : constant Float := 0.05030176425872175;
      P6 : constant Float := 0.1471039133652469;
      P7 : constant Float := 0.6444640676891548;

      subtype Octant is Float range 0.0 .. 1.5;
      subtype Quadrant_Arc is Float range 0.0 .. Pi / 2.0;
      subtype Half_Arc is Float range 0.0 .. Pi;

      Abs_X : constant Float := abs X;
      Abs_Y : constant Float := abs Y;
      Ratio : Unit_Interval;
      Num   : Float;
      Den   : Float;
      Res   : Octant;
      Arc   : Quadrant_Arc;
      Half  : Half_Arc;
   begin
      if Float'Max (Abs_X, Abs_Y) > 0.0 then
         Ratio := Float'Min (Abs_X, Abs_Y) / Float'Max (Abs_X, Abs_Y);
      else
         Ratio := 0.0;
      end if;
      declare
         T1 : constant Float := P5 * Ratio - P4;
         T2 : constant Float := T1 * Ratio - P3;
         T3 : constant Float := T2 * Ratio - P2;
         T4 : constant Float := T3 * Ratio - P1;
      begin
         pragma Assert (T1 in -0.32 .. -0.25);
         pragma Assert (T2 in -0.47 .. -0.14);
         pragma Assert (T3 in -1.47 .. -0.99);
         pragma Assert (T4 in -1.48 .. 0.0);
         Num := -T4;
      end;
      pragma Assert (Num in 0.0 .. 1.48);
      Den := (P7 * Ratio + P6) * Ratio + 1.0;
      pragma Assert (Den in 1.0 .. 1.8);
      Res := Num / Den;
      if Abs_Y > Abs_X then
         Arc := Pi / 2.0 - Res;
      else
         Arc := Res;
      end if;
      if X < 0.0 then
         Half := Pi - Arc;
      else
         Half := Arc;
      end if;
      if Y < 0.0 then
         return -Half;
      else
         return Half;
      end if;
   end Atan2_Approx;

   -----------------
   -- Acos_Approx --
   -----------------

   function Sqrt_Unit (Y : Unit_Interval) return Unit_Interval is
     (Float'Min (1.0, Ada.Numerics.Elementary_Functions.Sqrt (Y)))
     with Inline;

   function Acos_Approx (X : Cosine) return Float is
      XA     : constant Unit_Interval := abs X;
      Root   : constant Unit_Interval := Sqrt_Unit (1.0 - XA);
      Poly   : constant Float :=
        1.5707288 + XA * (-0.2121144 + XA * (0.0742610 + (-0.0187293 * XA)));
      Result : constant Float := Root * Poly;
   begin
      pragma Assert (Poly in 1.41 .. 1.5708);
      pragma Assert (Result in 0.0 .. 1.5708);
      if X < 0.0 then
         return Pi - Result;
      else
         return Result;
      end if;
   end Acos_Approx;

   -----------------
   -- Asin_Approx --
   -----------------

   function Asin_Approx (X : Cosine) return Quarter_Turn is
     (Pi * 0.5 - Acos_Approx (X));

   ------------------
   -- Sqrt_Bounded --
   ------------------

   function Sqrt_Bounded (X : Non_Negative_Signal) return Root_Signal is
     (Float'Min (Root_Signal'Last, Ada.Numerics.Elementary_Functions.Sqrt (X)));

   -----------------------
   -- Sqrt_Non_Negative --
   -----------------------

   function Round_Half_Even (X : Float) return Rounded_Integer is
      R : Integer := Integer (X);
   begin
      if abs (X - Float (R)) = 0.5 and then R mod 2 /= 0 then
         R := R - (if X > 0.0 then 1 else -1);
      end if;
      return R;
   end Round_Half_Even;

   function Sqrt_Non_Negative (X : Float) return Float is
     (Ada.Numerics.Elementary_Functions.Sqrt (X));

   ----------
   -- Lerp --
   ----------

   function Lerp (From : Signal; To : Signal; K : Unit_Interval) return Signal is
      R : constant Float := From + K * (To - From);
   begin
      return Float'Max (-Signal_Bound, Float'Min (Signal_Bound, R));
   end Lerp;

   ---------------
   -- Constrain --
   ---------------

   function Constrain (Value : Integer_32; Low : Integer_32; High : Integer_32)
     return Integer_32 is
   begin
      if Value < Low then
         return Low;
      elsif Value > High then
         return High;
      else
         return Value;
      end if;
   end Constrain;

   -----------------
   -- Constrain_F --
   -----------------

   function Constrain_F (Value : Float; Low : Float; High : Float) return Float is
   begin
      if Value < Low then
         return Low;
      elsif Value > High then
         return High;
      else
         return Value;
      end if;
   end Constrain_F;

   --------------------
   -- Apply_Deadband --
   --------------------

   function Apply_Deadband (Value : Integer_32; Deadband : Deadband_Width)
     return Integer_32 is
   begin
      if abs Value < Deadband then
         return 0;
      elsif Value >= 0 then
         return Value - Deadband;
      else
         return Value + Deadband;
      end if;
   end Apply_Deadband;

   ----------------------
   -- Apply_Deadband_F --
   ----------------------

   function Apply_Deadband_F (Value : Signal; Deadband : Deadband_Width_F)
     return Signal is
   begin
      if abs Value < Deadband then
         return 0.0;
      elsif Value >= 0.0 then
         return Value - Deadband;
      else
         return Value + Deadband;
      end if;
   end Apply_Deadband_F;

   ------------------------
   -- Degrees_To_Radians --
   ------------------------

   function Degrees_To_Radians (Degrees : Integer_16) return Float is
     (Float (Degrees) * Rad_Per_Degree);

   -----------------
   -- Scale_Range --
   -----------------

   function Scale_Range
     (Value     : Integer_32;
      Src_From  : Integer_32;
      Src_To    : Integer_32;
      Dest_From : Integer_32;
      Dest_To   : Integer_32) return Integer_32
   is
      A : constant Interfaces.Integer_64 :=
        (Interfaces.Integer_64 (Dest_To) - Interfaces.Integer_64 (Dest_From))
        * (Interfaces.Integer_64 (Value) - Interfaces.Integer_64 (Src_From));
      B : constant Interfaces.Integer_64 :=
        Interfaces.Integer_64 (Src_To) - Interfaces.Integer_64 (Src_From);
   begin
      return Integer_32 (A / B + Interfaces.Integer_64 (Dest_From));
   end Scale_Range;

   -------------------
   -- Scale_Range_F --
   -------------------

   function Scale_Range_F
     (Value     : Signal;
      Src_From  : Signal;
      Src_To    : Signal;
      Dest_From : Signal;
      Dest_To   : Signal) return Float
   is
      A : constant Float := (Dest_To - Dest_From) * (Value - Src_From);
      B : constant Float := Src_To - Src_From;
   begin
      return (A / B) + Dest_From;
   end Scale_Range_F;

   --------------------
   -- Scale_Map_Init --
   --------------------

   function Scale_Map_Init
     (Src_From  : Signal;
      Src_To    : Signal;
      Dest_From : Signal;
      Dest_To   : Signal) return Scale_Map
   is
      Range_Src  : constant Float := Src_To - Src_From;
      Range_Dest : constant Float := Dest_To - Dest_From;
      Scale      : constant Float := Range_Dest / Range_Src;
   begin
      return (Offset => Dest_From - (Src_From * Scale), Scale => Scale);
   end Scale_Map_Init;

   ---------------------
   -- Scale_Map_Apply --
   ---------------------

   function Scale_Map_Apply (Map : Scale_Map; Value : Signal) return Float is
     ((Value * Map.Scale) + Map.Offset);

   ---------
   -- Gcd --
   ---------

   function Gcd (Num : Integer_32; Denom : Integer_32) return Integer_32 is
      A : Integer_32 := Num;
      B : Integer_32 := Denom;
      T : Integer_32;
   begin
      while B /= 0 loop
         pragma Loop_Invariant (A >= 0 and then B >= 0);
         pragma Loop_Variant (Decreases => B);
         T := A mod B;
         A := B;
         B := T;
      end loop;
      return A;
   end Gcd;

   --  Sorting networks for the small medians.

   procedure Order (V : in out Int32_Window_9; I : Positive; J : Positive)
     with Inline, Pre => I in V'Range and then J in V'Range
   is
      T : Integer_32;
   begin
      if V (I) > V (J) then
         T := V (I);
         V (I) := V (J);
         V (J) := T;
      end if;
   end Order;

   procedure Order_F (V : in out Float_Window_9; I : Positive; J : Positive)
     with Inline, Pre => I in V'Range and then J in V'Range
   is
      T : Float;
   begin
      if V (I) > V (J) then
         T := V (I);
         V (I) := V (J);
         V (J) := T;
      end if;
   end Order_F;

   --------------------
   -- Quick_Median_3 --
   --------------------

   function Quick_Median_3 (V : Int32_Window_3) return Integer_32 is
      P : Int32_Window_9 := (V (1), V (2), V (3), others => 0);
   begin
      Order (P, 1, 2); Order (P, 2, 3); Order (P, 1, 2);
      return P (2);
   end Quick_Median_3;

   --------------------
   -- Quick_Median_5 --
   --------------------

   function Quick_Median_5 (V : Int32_Window_5) return Integer_32 is
      P : Int32_Window_9 := (V (1), V (2), V (3), V (4), V (5), others => 0);
   begin
      Order (P, 1, 2); Order (P, 4, 5); Order (P, 1, 4);
      Order (P, 2, 5); Order (P, 2, 3); Order (P, 3, 4);
      Order (P, 2, 3);
      return P (3);
   end Quick_Median_5;

   --------------------
   -- Quick_Median_7 --
   --------------------

   function Quick_Median_7 (V : Int32_Window_7) return Integer_32 is
      P : Int32_Window_9 := (V (1), V (2), V (3), V (4), V (5), V (6), V (7), others => 0);
   begin
      Order (P, 1, 6); Order (P, 1, 4); Order (P, 2, 7);
      Order (P, 3, 5); Order (P, 1, 2); Order (P, 4, 6);
      Order (P, 3, 7); Order (P, 3, 4); Order (P, 4, 7);
      Order (P, 5, 6); Order (P, 2, 5); Order (P, 2, 4);
      Order (P, 4, 5);
      return P (4);
   end Quick_Median_7;

   --------------------
   -- Quick_Median_9 --
   --------------------

   function Quick_Median_9 (V : Int32_Window_9) return Integer_32 is
      P : Int32_Window_9 := V;
   begin
      Order (P, 2, 3); Order (P, 5, 6); Order (P, 8, 9);
      Order (P, 1, 2); Order (P, 4, 5); Order (P, 7, 8);
      Order (P, 2, 3); Order (P, 5, 6); Order (P, 8, 9);
      Order (P, 1, 4); Order (P, 6, 9); Order (P, 5, 8);
      Order (P, 4, 7); Order (P, 2, 5); Order (P, 3, 6);
      Order (P, 5, 8); Order (P, 5, 3); Order (P, 7, 5);
      Order (P, 5, 3);
      return P (5);
   end Quick_Median_9;

   ----------------------
   -- Quick_Median_3_F --
   ----------------------

   function Quick_Median_3_F (V : Float_Window_3) return Float is
      P : Float_Window_9 := (V (1), V (2), V (3), others => 0.0);
   begin
      Order_F (P, 1, 2); Order_F (P, 2, 3); Order_F (P, 1, 2);
      return P (2);
   end Quick_Median_3_F;

   ----------------------
   -- Quick_Median_5_F --
   ----------------------

   function Quick_Median_5_F (V : Float_Window_5) return Float is
      P : Float_Window_9 := (V (1), V (2), V (3), V (4), V (5), others => 0.0);
   begin
      Order_F (P, 1, 2); Order_F (P, 4, 5); Order_F (P, 1, 4);
      Order_F (P, 2, 5); Order_F (P, 2, 3); Order_F (P, 3, 4);
      Order_F (P, 2, 3);
      return P (3);
   end Quick_Median_5_F;

   ----------------------
   -- Quick_Median_7_F --
   ----------------------

   function Quick_Median_7_F (V : Float_Window_7) return Float is
      P : Float_Window_9 := (V (1), V (2), V (3), V (4), V (5), V (6), V (7), others => 0.0);
   begin
      Order_F (P, 1, 6); Order_F (P, 1, 4); Order_F (P, 2, 7);
      Order_F (P, 3, 5); Order_F (P, 1, 2); Order_F (P, 4, 6);
      Order_F (P, 3, 7); Order_F (P, 3, 4); Order_F (P, 4, 7);
      Order_F (P, 5, 6); Order_F (P, 2, 5); Order_F (P, 2, 4);
      Order_F (P, 4, 5);
      return P (4);
   end Quick_Median_7_F;

   ----------------------
   -- Quick_Median_9_F --
   ----------------------

   function Quick_Median_9_F (V : Float_Window_9) return Float is
      P : Float_Window_9 := V;
   begin
      Order_F (P, 2, 3); Order_F (P, 5, 6); Order_F (P, 8, 9);
      Order_F (P, 1, 2); Order_F (P, 4, 5); Order_F (P, 7, 8);
      Order_F (P, 2, 3); Order_F (P, 5, 6); Order_F (P, 8, 9);
      Order_F (P, 1, 4); Order_F (P, 6, 9); Order_F (P, 5, 8);
      Order_F (P, 4, 7); Order_F (P, 2, 5); Order_F (P, 3, 6);
      Order_F (P, 5, 8); Order_F (P, 5, 3); Order_F (P, 7, 5);
      Order_F (P, 5, 3);
      return P (5);
   end Quick_Median_9_F;

   -----------------
   -- Stats_Clear --
   -----------------

   procedure Stats_Clear (Stats : out Running_Stats) is
   begin
      Stats := (others => <>);
   end Stats_Clear;

   ----------------
   -- Stats_Push --
   ----------------

   procedure Stats_Push (Stats : in out Running_Stats; X : Signal) is
      N : constant Sample_Count := Stats.Count + 1;
   begin
      if N = 1 then
         Stats := (Old_Mean => X, New_Mean => X, Old_Var => 0.0, New_Var => 0.0, Count => 1);
      else
         declare
            New_Mean : constant Signal :=
              Constrain_F (Stats.Old_Mean + (X - Stats.Old_Mean) / Float (N),
                           -Signal_Bound, Signal_Bound);
            Product  : constant Float := (X - Stats.Old_Mean) * (X - New_Mean);
            New_Var  : constant Float := Stats.Old_Var + Product;
         begin
            Stats := (Old_Mean => New_Mean,
                      New_Mean => New_Mean,
                      Old_Var  => Constrain_F (New_Var, 0.0, Variance_Bound),
                      New_Var  => Constrain_F (New_Var, 0.0, Variance_Bound),
                      Count    => N);
         end;
      end if;
   end Stats_Push;

   --------------------
   -- Stats_Variance --
   --------------------

   function Stats_Variance (Stats : Running_Stats) return Float is
   begin
      if Stats.Count > 1 then
         return Stats.New_Var / Float (Stats.Count - 1);
      else
         return 0.0;
      end if;
   end Stats_Variance;

   ------------------------------
   -- Stats_Standard_Deviation --
   ------------------------------

   function Stats_Standard_Deviation (Stats : Running_Stats) return Float is
     (Ada.Numerics.Elementary_Functions.Sqrt (Stats_Variance (Stats)));

   --  Arithmetic shift right by 12 as floor division, matching a two's
   --  complement shift for negative values.
   function Shift_Right_12 (V : Integer_32) return Integer_32 is
     ((V - (V mod 4096)) / 4096)
     with Pre => V > Integer_32'First + 4096;

   ---------------
   -- Q_Percent --
   ---------------

   function Q_Percent (Q : Fix12) return Integer_16 is
     (Integer_16 (Shift_Right_12 (100 * Q)));

   ----------------
   -- Q_Multiply --
   ----------------

   function Q_Multiply (Q : Fix12; Input : Integer_16) return Integer_16 is
     (Integer_16 (Shift_Right_12 (Integer_32 (Input) * Q)));

   -----------------
   -- Q_Construct --
   -----------------

   function Q_Construct (Num : Integer_16; Den : Integer_16) return Fix12 is
     ((Integer_32 (Num) * 4096) / Integer_32 (Den));

   -------------------------------
   -- Smooth_Step_Up_Transition --
   -------------------------------

   function Smooth_Step_Up_Transition
     (X : Signal; Center : Signal; Width : Float) return Unit_Interval
   is
      Half_Width  : constant Float := Width * 0.5;
      Left_Limit  : constant Float := Center - Half_Width;
      Right_Limit : constant Float := Center + Half_Width;
   begin
      if X < Left_Limit then
         return 0.0;
      elsif X > Right_Limit then
         return 1.0;
      else
         declare
            T : constant Float := (X - Left_Limit) / Width;
         begin
            return Constrain_F (T * T * (3.0 - 2.0 * T), 0.0, 1.0);
         end;
      end if;
   end Smooth_Step_Up_Transition;

end Adaflight.Maths;
