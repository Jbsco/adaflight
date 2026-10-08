--  Piecewise-linear table of a function over a closed interval, sampled at
--  evenly spaced points and interpolated between them.

with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.PWL with SPARK_Mode, Pure is

   Max_Points : constant := 32;
   subtype Point_Count is Positive range 2 .. Max_Points;
   subtype Point_Index is Natural range 0 .. Max_Points - 1;
   type Sample_Values is array (Point_Index) of Signal;

   --  The step is bounded below so that a position inside the interval
   --  divides to a finite index.
   Min_Step : constant := 2.0 ** (-26);
   subtype Step is Float range Min_Step .. 2.0 * Signal_Bound;

   type Table is record
      Y          : Sample_Values := (others => 0.0);
      Num_Points : Point_Count := 2;
      X_Min      : Signal := 0.0;
      X_Max      : Signal := 1.0;
      DX         : Step := 1.0;
   end record
     with Dynamic_Predicate => Table.X_Min < Table.X_Max;

   procedure Initialize
     (T : out Table; Num_Points : Point_Count; X_Min : Signal; X_Max : Signal)
     with Pre  => X_Max - X_Min >= Smallest_Span,
          Post => T.Num_Points = Num_Points and then T.X_Min = X_Min and then T.X_Max = X_Max;

   generic
      with function F (X : Float) return Signal;
   procedure Fill (T : in out Table)
     with Post => T.Num_Points = T.Num_Points'Old and then T.X_Min = T.X_Min'Old
       and then T.X_Max = T.X_Max'Old and then T.DX = T.DX'Old;

   function Interpolate (T : Table; X : Signal) return Float;

end Adaflight.PWL;
