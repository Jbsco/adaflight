--  Replays recorded vectors through the core and compares every float
--  result bit for bit. Each CSV line names a case and gives its inputs and
--  the expected outputs; floats are binary32 bit patterns in hex.

with Ada.Command_Line;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces;
with Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Vectors;
with Adaflight.PWL;
with Adaflight.SDFT;

procedure Vector_Check is

   use Ada.Text_IO;
   use Adaflight.Maths;
   use Adaflight.Filters;
   use Adaflight.Vectors;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_64;
   use type Interfaces.Integer_32;

   function To_Float is new Ada.Unchecked_Conversion (Unsigned_32, Float);
   function To_Bits is new Ada.Unchecked_Conversion (Float, Unsigned_32);

   type Tally is record
      Cases     : Natural := 0;
      Exact     : Natural := 0;
      Max_Ulp   : Integer_64 := 0;
      Tolerance : Integer_64 := 0;
   end record;

   package Tally_Maps is new Ada.Containers.Indefinite_Ordered_Maps (String, Tally);
   Tallies : Tally_Maps.Map;

   Failures : Natural := 0;

   --  Ordered key of a float so that the difference of two keys counts the
   --  representable values between them.
   function Key (B : Unsigned_32) return Integer_64 is
     (if (B and 16#8000_0000#) /= 0
      then -Integer_64 (B and 16#7FFF_FFFF#)
      else Integer_64 (B));

   procedure Record_Result (Name : String; Expected, Actual : Unsigned_32; Tolerance : Integer_64 := 0) is
      T : Tally;
      D : constant Integer_64 := abs (Key (Expected) - Key (Actual));
   begin
      if Tallies.Contains (Name) then
         T := Tallies.Element (Name);
      end if;
      T.Cases := T.Cases + 1;
      T.Tolerance := Tolerance;
      if Expected = Actual then
         T.Exact := T.Exact + 1;
      end if;
      if D > T.Max_Ulp then
         T.Max_Ulp := D;
      end if;
      if D > Tolerance then
         Failures := Failures + 1;
         if Failures <= 20 then
            Put_Line ("MISMATCH " & Name & " expected " & Unsigned_32'Image (Expected)
                      & " got " & Unsigned_32'Image (Actual) & " ulp " & Integer_64'Image (D));
         end if;
      end if;
      Tallies.Include (Name, T);
   end Record_Result;

   procedure Record_Int (Name : String; Expected, Actual : Integer_64) is
      T : Tally;
   begin
      if Tallies.Contains (Name) then
         T := Tallies.Element (Name);
      end if;
      T.Cases := T.Cases + 1;
      if Expected = Actual then
         T.Exact := T.Exact + 1;
      else
         Failures := Failures + 1;
         if Failures <= 20 then
            Put_Line ("MISMATCH " & Name & " expected " & Integer_64'Image (Expected)
                      & " got " & Integer_64'Image (Actual));
         end if;
      end if;
      Tallies.Include (Name, T);
   end Record_Int;

   Max_Fields : constant := 48;
   type Fields is array (1 .. Max_Fields) of String (1 .. 24);
   type Field_Lengths is array (1 .. Max_Fields) of Natural;

   F  : Fields;
   FL : Field_Lengths;
   NF : Natural;

   procedure Split (Line : String) is
      Start : Positive := Line'First;
   begin
      NF := 0;
      FL := (others => 0);
      for I in Line'Range loop
         if Line (I) = ',' then
            NF := NF + 1;
            FL (NF) := I - Start;
            F (NF) (1 .. FL (NF)) := Line (Start .. I - 1);
            Start := I + 1;
         end if;
      end loop;
      NF := NF + 1;
      FL (NF) := Line'Last - Start + 1;
      F (NF) (1 .. FL (NF)) := Line (Start .. Line'Last);
   end Split;

   function Str (I : Positive) return String is (F (I) (1 .. FL (I)));
   function Bits (I : Positive) return Unsigned_32 is (Unsigned_32'Value ("16#" & Str (I) & "#"));
   function Flt (I : Positive) return Float is (To_Float (Bits (I)));
   function Int (I : Positive) return Integer_64 is (Integer_64'Value (Str (I)));
   function I32 (I : Positive) return Integer_32 is (Integer_32'Value (Str (I)));

   --  Stateful sequences are keyed by the sequence number in field 2 and
   --  reinitialized when the number changes.

   Seq_PT     : Integer_64 := -1;
   P1 : PT1; P2 : PT2; P3 : PT3;
   LP : SVF_Lowpass; NF_Filter : SVF_Notch; RN : Weighted_Notch;
   PC : Phase_Comp;
   Seq_Slew   : Integer_64 := -1;
   SF : Slew_Filter;
   Seq_MA     : Integer_64 := -1;
   MA : Moving_Average;
   Seq_SLP    : Integer_64 := -1;
   SLP : Simple_Lowpass;
   Seq_Mean   : Integer_64 := -1;
   MACC : Mean_Accumulator;
   Seq_Stats  : Integer_64 := -1;
   ST : Running_Stats;

   procedure Check_Maths_Line is
      Name : constant String := Str (1);
      Out_F : Float;
      Out_S, Out_C : Cosine;
   begin
      if Name = "sin" then
         Record_Result (Name, Bits (3), To_Bits (Sin_Approx (Flt (2))));
      elsif Name = "cos" then
         Record_Result (Name, Bits (3), To_Bits (Cos_Approx (Flt (2))));
      elsif Name = "sincos" then
         Sin_Cos_Approx (Flt (2), Out_S, Out_C);
         Record_Result ("sincos.s", Bits (3), To_Bits (Out_S));
         Record_Result ("sincos.c", Bits (4), To_Bits (Out_C));
      elsif Name = "tan" then
         Record_Result (Name, Bits (3), To_Bits (Tan_Approx (Flt (2))));
      elsif Name = "atan2" then
         Record_Result (Name, Bits (4), To_Bits (Atan2_Approx (Flt (2), Flt (3))));
      elsif Name = "acos" then
         Record_Result (Name, Bits (3), To_Bits (Acos_Approx (Flt (2))));
      elsif Name = "asin" then
         Record_Result (Name, Bits (3), To_Bits (Asin_Approx (Flt (2))));
      elsif Name = "constrain" then
         Record_Int (Name, Int (5), Integer_64 (Constrain (I32 (2), I32 (3), I32 (4))));
      elsif Name = "constrainf" then
         Record_Result (Name, Bits (5), To_Bits (Constrain_F (Flt (2), Flt (3), Flt (4))));
      elsif Name = "deadband" then
         Record_Int (Name, Int (4), Integer_64 (Apply_Deadband (I32 (2), I32 (3))));
      elsif Name = "deadbandf" then
         Record_Result (Name, Bits (4), To_Bits (Apply_Deadband_F (Flt (2), Flt (3))));
      elsif Name = "deg2rad" then
         Record_Result (Name, Bits (3), To_Bits (Degrees_To_Radians (Integer_16'Value (Str (2)))));
      elsif Name = "scalerange" then
         Record_Int (Name, Int (7),
                     Integer_64 (Scale_Range (I32 (2), I32 (3), I32 (4), I32 (5), I32 (6))));
      elsif Name = "scalerangef" then
         Record_Result (Name, Bits (7),
                        To_Bits (Scale_Range_F (Flt (2), Flt (3), Flt (4), Flt (5), Flt (6))));
      elsif Name = "scalemap" then
         declare
            M : constant Scale_Map := Scale_Map_Init (Flt (2), Flt (3), Flt (4), Flt (5));
         begin
            Record_Result ("scalemap.scale", Bits (6), To_Bits (M.Scale));
            Record_Result ("scalemap.offset", Bits (7), To_Bits (M.Offset));
            Record_Result ("scalemap.apply", Bits (9), To_Bits (Scale_Map_Apply (M, Flt (8))));
         end;
      elsif Name = "gcd" then
         Record_Int (Name, Int (4), Integer_64 (Gcd (I32 (2), I32 (3))));
      elsif Name = "median3" then
         Record_Int (Name, Int (5), Integer_64 (Quick_Median_3 ((I32 (2), I32 (3), I32 (4)))));
      elsif Name = "median5" then
         Record_Int (Name, Int (7),
                     Integer_64 (Quick_Median_5 ((I32 (2), I32 (3), I32 (4), I32 (5), I32 (6)))));
      elsif Name = "median7" then
         Record_Int (Name, Int (9),
                     Integer_64 (Quick_Median_7 ((I32 (2), I32 (3), I32 (4), I32 (5), I32 (6),
                                                  I32 (7), I32 (8)))));
      elsif Name = "median9" then
         Record_Int (Name, Int (11),
                     Integer_64 (Quick_Median_9 ((I32 (2), I32 (3), I32 (4), I32 (5), I32 (6),
                                                  I32 (7), I32 (8), I32 (9), I32 (10)))));
      elsif Name = "median3f" then
         Record_Result (Name, Bits (5), To_Bits (Quick_Median_3_F ((Flt (2), Flt (3), Flt (4)))));
      elsif Name = "median5f" then
         Record_Result (Name, Bits (7),
                        To_Bits (Quick_Median_5_F ((Flt (2), Flt (3), Flt (4), Flt (5), Flt (6)))));
      elsif Name = "median7f" then
         Record_Result (Name, Bits (9),
                        To_Bits (Quick_Median_7_F ((Flt (2), Flt (3), Flt (4), Flt (5), Flt (6),
                                                    Flt (7), Flt (8)))));
      elsif Name = "median9f" then
         Record_Result (Name, Bits (11),
                        To_Bits (Quick_Median_9_F ((Flt (2), Flt (3), Flt (4), Flt (5), Flt (6),
                                                    Flt (7), Flt (8), Flt (9), Flt (10)))));
      elsif Name = "stats" then
         if Int (2) /= Seq_Stats then
            Seq_Stats := Int (2);
            Stats_Clear (ST);
         end if;
         Stats_Push (ST, Flt (3));
         Record_Result ("stats.mean", Bits (4), To_Bits (ST.New_Mean));
         Record_Result ("stats.variance", Bits (5), To_Bits (Stats_Variance (ST)));
         Record_Result ("stats.stddev", Bits (6), To_Bits (Stats_Standard_Deviation (ST)));
      elsif Name = "qpercent" then
         Record_Int (Name, Int (3), Integer_64 (Q_Percent (I32 (2))));
      elsif Name = "qmultiply" then
         Record_Int (Name, Int (4), Integer_64 (Q_Multiply (I32 (2), Integer_16'Value (Str (3)))));
      elsif Name = "qconstruct" then
         Record_Int (Name, Int (4),
                     Integer_64 (Q_Construct (Integer_16'Value (Str (2)), Integer_16'Value (Str (3)))));
      elsif Name = "smoothstep" then
         Out_F := Smooth_Step_Up_Transition (Flt (2), Flt (3), Flt (4));
         Record_Result (Name, Bits (5), To_Bits (Out_F));
      else
         Put_Line ("unknown maths case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Maths_Line;

   procedure Check_Filters_Line is
      Name : constant String := Str (1);
      O : Signal;
      V : Axis_Signals;
      OI : Simple_Input;
      O8 : Integer_8;
   begin
      if Name = "pt1gain" then
         Record_Result (Name, Bits (4), To_Bits (PT1_Gain (Flt (2), Flt (3))));
      elsif Name = "pt2gain" then
         Record_Result (Name, Bits (4), To_Bits (PT2_Gain (Flt (2), Flt (3))));
      elsif Name = "pt3gain" then
         Record_Result (Name, Bits (4), To_Bits (PT3_Gain (Flt (2), Flt (3))));
      elsif Name = "pt1delay" then
         Record_Result (Name, Bits (4), To_Bits (PT1_Gain_From_Delay (Flt (2), Flt (3))));
      elsif Name = "pt2delay" then
         Record_Result (Name, Bits (4), To_Bits (PT2_Gain_From_Delay (Flt (2), Flt (3))));
      elsif Name = "pt3delay" then
         Record_Result (Name, Bits (4), To_Bits (PT3_Gain_From_Delay (Flt (2), Flt (3))));
      elsif Name = "pt1" or else Name = "pt2" or else Name = "pt3" then
         if Int (2) /= Seq_PT then
            Seq_PT := Int (2);
            PT1_Init (P1, Flt (3));
            PT2_Init (P2, Flt (3));
            PT3_Init (P3, Flt (3));
         end if;
         if Name = "pt1" then
            PT1_Apply (P1, Flt (4), O);
         elsif Name = "pt2" then
            PT2_Apply (P2, Flt (4), O);
         else
            PT3_Apply (P3, Flt (4), O);
         end if;
         Record_Result (Name, Bits (5), To_Bits (O));
      elsif Name = "notchq" then
         Record_Result (Name, Bits (4), To_Bits (Notch_Q (Flt (2), Flt (3))));
      elsif Name = "svflpinit" then
         SVF_Lowpass_Init (LP, Flt (3), Flt (4));
         Record_Result ("svflpinit.f", Bits (5), To_Bits (LP.F));
         Record_Result ("svflpinit.a1", Bits (6), To_Bits (LP.A1));
         Record_Result ("svflpinit.a2", Bits (7), To_Bits (LP.A2));
      elsif Name = "svfnotchinit" then
         SVF_Notch_Init (NF_Filter, Flt (3), Flt (4), Flt (5));
         Record_Result ("svfnotchinit.a1", Bits (6), To_Bits (NF_Filter.A1));
         Record_Result ("svfnotchinit.a2q", Bits (7), To_Bits (NF_Filter.A2Q));
         Record_Result ("svfnotchinit.fq", Bits (8), To_Bits (NF_Filter.FQ));
      elsif Name = "rpmnotchinit" then
         Weighted_Notch_Init (RN, Flt (3), Flt (4), Flt (5), Flt (6));
         Record_Result ("rpmnotchinit.f", Bits (7), To_Bits (RN.F));
         Record_Result ("rpmnotchinit.a1", Bits (8), To_Bits (RN.A1));
         Record_Result ("rpmnotchinit.a2", Bits (9), To_Bits (RN.A2));
         Record_Result ("rpmnotchinit.wq", Bits (10), To_Bits (RN.WQ));
      elsif Name = "svflp" then
         SVF_Lowpass_Apply (LP, Flt (3), O);
         Record_Result (Name, Bits (4), To_Bits (O));
      elsif Name = "svfnotch" then
         SVF_Notch_Apply (NF_Filter, Flt (3), O);
         Record_Result (Name, Bits (4), To_Bits (O));
      elsif Name = "rpmnotch" then
         V := (Flt (3), Flt (4), Flt (5));
         Weighted_Notch_Apply (RN, V);
         Record_Result ("rpmnotch.roll", Bits (6), To_Bits (V (Roll)));
         Record_Result ("rpmnotch.pitch", Bits (7), To_Bits (V (Pitch)));
         Record_Result ("rpmnotch.yaw", Bits (8), To_Bits (V (Yaw)));
      elsif Name = "phasecompinit" then
         Phase_Comp_Init (PC, Flt (3), Flt (4), Integer'Value (Str (5)));
         Record_Result ("phasecompinit.b0", Bits (6), To_Bits (PC.B0));
         Record_Result ("phasecompinit.b1", Bits (7), To_Bits (PC.B1));
         Record_Result ("phasecompinit.a1", Bits (8), To_Bits (PC.A1));
      elsif Name = "phasecomp" then
         Phase_Comp_Apply (PC, Flt (3), O);
         Record_Result (Name, Bits (4), To_Bits (O));
      elsif Name = "slew" then
         if Int (2) /= Seq_Slew then
            Seq_Slew := Int (2);
            Slew_Init (SF, Flt (3), Flt (4));
         end if;
         Slew_Apply (SF, Flt (5), O);
         Record_Result (Name, Bits (6), To_Bits (O));
      elsif Name = "movavg" then
         if Int (2) /= Seq_MA then
            Seq_MA := Int (2);
            Moving_Average_Init (MA, Integer'Value (Str (3)));
         end if;
         Moving_Average_Update (MA, Flt (4), O);
         Record_Result (Name, Bits (5), To_Bits (O), Tolerance => 512);
      elsif Name = "simplelp" then
         if Int (2) /= Seq_SLP then
            Seq_SLP := Int (2);
            Simple_Lowpass_Init (SLP, Integer'Value (Str (3)), Integer'Value (Str (4)));
         end if;
         Simple_Lowpass_Update (SLP, I32 (5), OI);
         Record_Int (Name, Int (6), Integer_64 (OI));
      elsif Name = "meanadd" then
         if Int (2) /= Seq_Mean then
            Seq_Mean := Int (2);
            Mean_Init (MACC);
         end if;
         Mean_Add (MACC, Integer_8'Value (Str (3)));
      elsif Name = "meancalc" then
         if Int (2) /= Seq_Mean then
            Seq_Mean := Int (2);
            Mean_Init (MACC);
         end if;
         Mean_Calc (MACC, Integer_8'Value (Str (3)), O8);
         Record_Int (Name, Int (4), Integer_64 (O8));
      else
         Put_Line ("unknown filter case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Filters_Line;

   PWL_Table : Adaflight.PWL.Table;
   DFT       : Adaflight.SDFT.Transform;

   function Thousand_Sine (X : Float) return Signal is
     (1000.0 * Sin_Approx (Constrain_F (X, -Angle_Bound, Angle_Bound)));

   procedure Fill_Sine is new Adaflight.PWL.Fill (F => Thousand_Sine);

   procedure Record_Vec2 (Name : String; V : Vector2; First : Positive; Tolerance : Integer_64 := 0) is
   begin
      Record_Result (Name & ".x", Bits (First), To_Bits (V.X), Tolerance);
      Record_Result (Name & ".y", Bits (First + 1), To_Bits (V.Y), Tolerance);
   end Record_Vec2;

   procedure Record_Vec3 (Name : String; V : Vector3; First : Positive; Tolerance : Integer_64 := 0) is
   begin
      Record_Result (Name & ".x", Bits (First), To_Bits (V.X), Tolerance);
      Record_Result (Name & ".y", Bits (First + 1), To_Bits (V.Y), Tolerance);
      Record_Result (Name & ".z", Bits (First + 2), To_Bits (V.Z), Tolerance);
   end Record_Vec3;

   procedure Record_Matrix (Name : String; M : Matrix33; First : Positive) is
      I : Positive := First;
   begin
      for R in Coordinate loop
         for C in Coordinate loop
            Record_Result (Name, Bits (I), To_Bits (M (R, C)));
            I := I + 1;
         end loop;
      end loop;
   end Record_Matrix;

   procedure Record_Bins (Name : String; Output : Adaflight.SDFT.Magnitudes; First : Positive) is
   begin
      for B in Adaflight.SDFT.Bin loop
         Record_Result (Name, Bits (First + B), To_Bits (Output (B)));
      end loop;
   end Record_Bins;

   function V2 (First : Positive) return Vector2 is (X => Flt (First), Y => Flt (First + 1));
   function V3 (First : Positive) return Vector3 is
     (X => Flt (First), Y => Flt (First + 1), Z => Flt (First + 2));
   function RPY (First : Positive) return Euler_Angles is
     (Roll => Flt (First), Pitch => Flt (First + 1), Yaw => Flt (First + 2));

   procedure Check_Common_Line is
      Name : constant String := Str (1);
      Output : Adaflight.SDFT.Magnitudes;
   begin
      if Name = "v2add" then
         Record_Vec2 (Name, Add (V2 (2), V2 (4)), 6);
      elsif Name = "v2sub" then
         Record_Vec2 (Name, Sub (V2 (2), V2 (4)), 6);
      elsif Name = "v2scale" then
         Record_Vec2 (Name, Scale (V2 (2), Flt (4)), 5);
      elsif Name = "v2dot" then
         Record_Result (Name, Bits (6), To_Bits (Dot (V2 (2), V2 (4))));
      elsif Name = "v2cross" then
         Record_Result (Name, Bits (6), To_Bits (Cross (V2 (2), V2 (4))));
      elsif Name = "v2normsq" then
         Record_Result (Name, Bits (4), To_Bits (Norm_Sq (V2 (2))));
      elsif Name = "v2norm" then
         Record_Result (Name, Bits (4), To_Bits (Norm (V2 (2))));
      elsif Name = "v2normalize" then
         Record_Vec2 (Name, Normalize (V2 (2)), 4, Tolerance => 1);
      elsif Name = "v2rotate" then
         Record_Vec2 (Name, Rotate (V2 (2), Flt (4)), 5);
      elsif Name = "v3add" then
         Record_Vec3 (Name, Add (V3 (2), V3 (5)), 8);
      elsif Name = "v3sub" then
         Record_Vec3 (Name, Sub (V3 (2), V3 (5)), 8);
      elsif Name = "v3scale" then
         Record_Vec3 (Name, Scale (V3 (2), Flt (5)), 6);
      elsif Name = "v3dot" then
         Record_Result (Name, Bits (8), To_Bits (Dot (V3 (2), V3 (5))));
      elsif Name = "v3cross" then
         Record_Vec3 (Name, Cross (V3 (2), V3 (5)), 8);
      elsif Name = "v3normsq" then
         Record_Result (Name, Bits (5), To_Bits (Norm_Sq (V3 (2))));
      elsif Name = "v3norm" then
         Record_Result (Name, Bits (5), To_Bits (Norm (V3 (2))));
      elsif Name = "v3normalize" then
         Record_Vec3 (Name, Normalize (V3 (2)), 5, Tolerance => 1);
      elsif Name = "rotmat" then
         Record_Matrix (Name, Rotation_Matrix (RPY (2)), 5);
      elsif Name = "matmul" then
         Record_Vec3 (Name, Multiply (Rotation_Matrix (RPY (2)), V3 (5)), 8);
      elsif Name = "mattrnmul" then
         Record_Vec3 (Name, Multiply_Transposed (Rotation_Matrix (RPY (2)), V3 (5)), 8);
      elsif Name = "yawmat" then
         Record_Matrix (Name, Yaw_Rotation_Z (Flt (2)), 3);
      elsif Name = "pwlinit" then
         declare
            N : constant Adaflight.PWL.Point_Count := Integer'Value (Str (3));
         begin
            Adaflight.PWL.Initialize (PWL_Table, N, Flt (4), Flt (5));
            Record_Result ("pwlinit.dx", Bits (6), To_Bits (PWL_Table.DX));
            Fill_Sine (PWL_Table);
            for I in 0 .. N - 1 loop
               Record_Result ("pwlinit.y", Bits (7 + I), To_Bits (PWL_Table.Y (I)));
            end loop;
         end;
      elsif Name = "pwl" then
         Record_Result (Name, Bits (4), To_Bits (Adaflight.PWL.Interpolate (PWL_Table, Flt (3))));
      elsif Name = "sdftinit" then
         Adaflight.SDFT.Init (DFT, Integer'Value (Str (3)), Integer'Value (Str (4)), Integer'Value (Str (5)));
         Record_Int ("sdftinit.start", Int (6), Integer_64 (DFT.Start_Bin));
         Record_Int ("sdftinit.end", Int (7), Integer_64 (DFT.End_Bin));
         Record_Int ("sdftinit.batch", Int (8), Integer_64 (DFT.Batch_Size));
      elsif Name = "sdftpush" then
         Adaflight.SDFT.Push (DFT, Flt (3));
      elsif Name = "sdftpushbatch" then
         Adaflight.SDFT.Push_Batch (DFT, Flt (3), Integer'Value (Str (4)));
      elsif Name = "sdftmagsq" then
         Output := (others => 0.0);
         Adaflight.SDFT.Mag_Sq (DFT, Output);
         Record_Bins (Name, Output, 3);
      elsif Name = "sdftwinsq" then
         Output := (others => 0.0);
         Adaflight.SDFT.Win_Sq (DFT, Output);
         Record_Bins (Name, Output, 3);
      elsif Name = "sdftwindow" then
         Output := (others => 0.0);
         Adaflight.SDFT.Window (DFT, Output);
         Record_Bins (Name, Output, 3);
      else
         Put_Line ("unknown common case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Common_Line;

   --  The twiddle table is static; this confirms it against the fast
   --  trigonometry it was computed from.
   procedure Check_Twiddles is
      C : constant Float := 2.0 * Pi / Float (Adaflight.SDFT.Sample_Size);
   begin
      for B in Adaflight.SDFT.Bin loop
         declare
            Phi : constant Float := C * Float (B);
         begin
            Record_Result ("twiddle.re", To_Bits (Adaflight.SDFT.Damping * Cos_Approx (Phi)),
                           To_Bits (Adaflight.SDFT.Twiddle (B).Re));
            Record_Result ("twiddle.im", To_Bits (Adaflight.SDFT.Damping * Sin_Approx (Phi)),
                           To_Bits (Adaflight.SDFT.Twiddle (B).Im));
         end;
      end loop;
   end Check_Twiddles;

   procedure Run (Path : String; Kind : String) is
      File : File_Type;
      Lines : Natural := 0;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         declare
            Line : constant String := Get_Line (File);
         begin
            if Line'Length > 0 then
               Split (Line);
               Lines := Lines + 1;
               if Kind = "maths" then
                  Check_Maths_Line;
               elsif Kind = "filters" then
                  Check_Filters_Line;
               else
                  Check_Common_Line;
               end if;
            end if;
         end;
      end loop;
      Close (File);
      Put_Line (Path & ":" & Natural'Image (Lines) & " lines");
   end Run;

   Dir : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "vectors");

begin
   Run (Dir & "/maths.csv", "maths");
   Run (Dir & "/filters.csv", "filters");
   Run (Dir & "/common.csv", "common");
   Check_Twiddles;
   New_Line;
   Put_Line ("case                      cases    exact  max_ulp  tol");
   for C in Tallies.Iterate loop
      declare
         T : constant Tally := Tally_Maps.Element (C);
         N : constant String := Tally_Maps.Key (C);
      begin
         Put_Line (Ada.Strings.Fixed.Head (N, 24) & Natural'Image (T.Cases)
                   & Ada.Strings.Fixed.Tail (Natural'Image (T.Exact), 9)
                   & Ada.Strings.Fixed.Tail (Integer_64'Image (T.Max_Ulp), 9)
                   & Ada.Strings.Fixed.Tail (Integer_64'Image (T.Tolerance), 5));
      end;
   end loop;
   New_Line;
   if Failures = 0 then
      Put_Line ("vector_check: all cases within tolerance");
   else
      Put_Line ("vector_check: FAILURES" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Vector_Check;
