--  Bounded floating-point arithmetic for the control path.
--
--  Every value that flows through a filter or a controller is a Signal: a
--  binary32 value within +/- 2**32. The bound is far above any physical
--  quantity the controller handles and admits every 32-bit integer, so a
--  sensor count converts without a check. The bound is what lets the
--  prover show that no sum, difference, or product of two Signals can
--  overflow to infinity, which keeps NaN out of the motor outputs.

with Interfaces;

package Adaflight.Maths with SPARK_Mode, Pure is

   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_8 is Interfaces.Integer_8;

   Signal_Bound : constant := 2.0 ** 32;
   subtype Signal is Float range -Signal_Bound .. Signal_Bound;

   subtype Unit_Interval is Float range 0.0 .. 1.0;
   subtype Cosine is Float range -1.0 .. 1.0;

   Pi             : constant Float := 3.14159265358979323846;
   Rad_Per_Degree : constant Float := Pi / 180.0;
   Two_Over_Pi    : constant Float := 2.0 / Pi;

   subtype Half_Turn is Float range -Pi .. Pi;
   subtype Quarter_Turn is Float range -Pi / 2.0 .. Pi / 2.0;

   --  Angles are bounded so that range reduction fits an Integer.
   Angle_Bound : constant := 1.0e6;
   subtype Angle is Float range -Angle_Bound .. Angle_Bound;

   function Sin_Approx (X : Angle) return Cosine;
   function Cos_Approx (X : Angle) return Cosine;
   procedure Sin_Cos_Approx (X : Angle; S : out Cosine; C : out Cosine);

   --  Tangent of a non-negative angle below 0.483 pi, where the cosine of
   --  the approximation stays above 0.05, so the quotient is bounded.
   Max_Tan_Argument : constant := 1.51;
   Max_Tan : constant := 20.0;
   subtype Tan_Argument is Float range 0.0 .. Max_Tan_Argument;
   subtype Tangent is Float range 0.0 .. Max_Tan;

   function Tan_Approx (X : Tan_Argument) return Tangent;

   function Atan2_Approx (Y : Signal; X : Signal) return Half_Turn;
   function Acos_Approx (X : Cosine) return Float
     with Post => Acos_Approx'Result in 0.0 .. Pi;
   function Asin_Approx (X : Cosine) return Quarter_Turn;

   --  Square root of a non-negative Signal, bounded by the root of the
   --  Signal bound.
   subtype Non_Negative_Signal is Float range 0.0 .. Signal_Bound;
   subtype Root_Signal is Float range 0.0 .. 2.0 ** 16;

   function Sqrt_Bounded (X : Non_Negative_Signal) return Root_Signal;

   --  Convex combination of two Signals. The result is saturated at the
   --  Signal bound: in exact arithmetic it lies between From and To, and the
   --  saturation only absorbs the rounding of the last operation at the
   --  bound itself, which no physical signal reaches.
   function Lerp (From : Signal; To : Signal; K : Unit_Interval) return Signal
     with Inline;

   function Constrain (Value : Integer_32; Low : Integer_32; High : Integer_32)
     return Integer_32
     with Pre  => Low <= High,
          Post => Constrain'Result in Low .. High;

   function Constrain_F (Value : Float; Low : Float; High : Float) return Float
     with Pre  => Low <= High,
          Post => Constrain_F'Result in Low .. High;

   subtype Deadband_Width is Integer_32 range 0 .. Integer_32'Last;

   function Apply_Deadband (Value : Integer_32; Deadband : Deadband_Width)
     return Integer_32
     with Pre => Value > Integer_32'First;

   subtype Deadband_Width_F is Float range 0.0 .. Signal_Bound;

   function Apply_Deadband_F (Value : Signal; Deadband : Deadband_Width_F)
     return Signal;

   function Degrees_To_Radians (Degrees : Integer_16) return Float;

   --  Maps Value from the source range onto the destination range with
   --  64-bit intermediates. The precondition states that the result fits,
   --  which the caller usually knows from its constant ranges.
   subtype Integer_64 is Interfaces.Integer_64;

   Span_Bound : constant := 2 ** 31;

   function Scale_Range
     (Value     : Integer_32;
      Src_From  : Integer_32;
      Src_To    : Integer_32;
      Dest_From : Integer_32;
      Dest_To   : Integer_32) return Integer_32
     with Pre => Src_From /= Src_To
       and then abs (Integer_64 (Dest_To) - Integer_64 (Dest_From)) <= Span_Bound
       and then abs (Integer_64 (Value) - Integer_64 (Src_From)) <= Span_Bound
       and then (Integer_64 (Dest_To) - Integer_64 (Dest_From))
                * (Integer_64 (Value) - Integer_64 (Src_From))
                / (Integer_64 (Src_To) - Integer_64 (Src_From))
                + Integer_64 (Dest_From)
                in Integer_64 (Integer_32'First) .. Integer_64 (Integer_32'Last);

   Smallest_Span : constant := 2.0 ** (-20);

   function Scale_Range_F
     (Value     : Signal;
      Src_From  : Signal;
      Src_To    : Signal;
      Dest_From : Signal;
      Dest_To   : Signal) return Float
     with Pre => abs (Src_To - Src_From) >= Smallest_Span;

   --  Scale and Offset are bounded by the widest map the preconditions on
   --  Scale_Map_Init admit, so Scale_Map_Apply cannot overflow.
   type Scale_Map is record
      Offset : Float := 0.0;
      Scale  : Float := 0.0;
   end record
     with Dynamic_Predicate =>
       abs Scale_Map.Scale <= 2.0 ** 53 and then abs Scale_Map.Offset <= 2.0 ** 86;

   function Scale_Map_Init
     (Src_From  : Signal;
      Src_To    : Signal;
      Dest_From : Signal;
      Dest_To   : Signal) return Scale_Map
     with Pre => abs (Src_To - Src_From) >= Smallest_Span;

   function Scale_Map_Apply (Map : Scale_Map; Value : Signal) return Float;

   function Gcd (Num : Integer_32; Denom : Integer_32) return Integer_32
     with Pre => Num >= 0 and then Denom >= 0;

   type Int32_Window_3 is array (1 .. 3) of Integer_32;
   type Int32_Window_5 is array (1 .. 5) of Integer_32;
   type Int32_Window_7 is array (1 .. 7) of Integer_32;
   type Int32_Window_9 is array (1 .. 9) of Integer_32;

   function Quick_Median_3 (V : Int32_Window_3) return Integer_32;
   function Quick_Median_5 (V : Int32_Window_5) return Integer_32;
   function Quick_Median_7 (V : Int32_Window_7) return Integer_32;
   function Quick_Median_9 (V : Int32_Window_9) return Integer_32;

   type Float_Window_3 is array (1 .. 3) of Float;
   type Float_Window_5 is array (1 .. 5) of Float;
   type Float_Window_7 is array (1 .. 7) of Float;
   type Float_Window_9 is array (1 .. 9) of Float;

   function Quick_Median_3_F (V : Float_Window_3) return Float;
   function Quick_Median_5_F (V : Float_Window_5) return Float;
   function Quick_Median_7_F (V : Float_Window_7) return Float;
   function Quick_Median_9_F (V : Float_Window_9) return Float;

   --  Welford running mean and variance. The sample count is capped and
   --  the variance accumulator saturates at a bound the capped sum of
   --  squared Signals cannot reach, which keeps both finite by type.
   Max_Samples    : constant := 2 ** 20;
   Variance_Bound : constant := 2.0 ** 88;
   subtype Sample_Count is Natural range 0 .. Max_Samples;
   subtype Variance is Float range 0.0 .. Variance_Bound;

   type Running_Stats is record
      Old_Mean : Signal := 0.0;
      New_Mean : Signal := 0.0;
      Old_Var  : Variance := 0.0;
      New_Var  : Variance := 0.0;
      Count    : Sample_Count := 0;
   end record;

   procedure Stats_Clear (Stats : out Running_Stats)
     with Post => Stats.Count = 0;

   procedure Stats_Push (Stats : in out Running_Stats; X : Signal)
     with Pre  => Stats.Count < Max_Samples,
          Post => Stats.Count = Stats.Count'Old + 1;

   function Stats_Variance (Stats : Running_Stats) return Float
     with Post => Stats_Variance'Result >= 0.0;

   function Stats_Standard_Deviation (Stats : Running_Stats) return Float
     with Post => Stats_Standard_Deviation'Result >= 0.0;

   --  Q12 fixed point: 12 fractional bits in a 32-bit integer.
   subtype Fix12 is Integer_32;

   function Q_Percent (Q : Fix12) return Integer_16
     with Pre => Q in -2 ** 16 .. 2 ** 16;

   function Q_Multiply (Q : Fix12; Input : Integer_16) return Integer_16
     with Pre => Q in -(2 ** 12 - 1) .. 2 ** 12;

   function Q_Construct (Num : Integer_16; Den : Integer_16) return Fix12
     with Pre => Den /= 0;

   function Smooth_Step_Up_Transition
     (X : Signal; Center : Signal; Width : Float) return Unit_Interval
     with Pre => Width in Smallest_Span .. Signal_Bound;

end Adaflight.Maths;
