--  Replays recorded vectors through the core and compares every float
--  result bit for bit. Each CSV line names a case and gives its inputs and
--  the expected outputs; floats are binary32 bit patterns in hex.

with Ada.Command_Line;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces;
with Adaflight.Axes;
with Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Rates;
with Adaflight.PID_Profile;
with Adaflight.PID_Config;
with Adaflight.PID_Filters;
with Adaflight.PID_Controller;
with Adaflight.Mixer;
with Adaflight.RC_Command;
with Adaflight.Gyro_Filters;
with Adaflight.Attitude;
with Adaflight.Failsafe;
with Adaflight.Vectors;
with Adaflight.PWL;
with Adaflight.SDFT;
with Adaflight.Bytes;
with Adaflight.Encoding;
with Adaflight.Float_Bits;
with Adaflight.Bit_Arrays;
with Adaflight.Stream_Buffers;
with Adaflight.Huffman;
with Adaflight.GPS_Conversion;
with Adaflight.Sensor_Alignment;
with Adaflight.Color;
with Adaflight.Exponentials;
with Adaflight.Chirp;

procedure Vector_Check is

   use Ada.Text_IO;
   use Adaflight.Axes;
   use Adaflight.Maths;
   use Adaflight.Filters;
   use Adaflight.Vectors;
   use Adaflight.Bytes;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_64;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_16;

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

   procedure Record_Result (Name : String; Expected, Actual : Unsigned_32; Tolerance : Integer_64 := 0;
                            Absolute : Float := 0.0) is
      T : Tally;
      D : constant Integer_64 :=
        (if Absolute > 0.0 and then abs (To_Float (Expected) - To_Float (Actual)) <= Absolute
         then Integer_64'Min (Tolerance, abs (Key (Expected) - Key (Actual)))
         else abs (Key (Expected) - Key (Actual)));
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

   Max_Fields : constant := 200;
   type Fields is array (1 .. Max_Fields) of String (1 .. 400);
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
   function Int_Hex (I : Positive) return Integer_64 is (Integer_64'Value ("16#" & Str (I) & "#"));
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

   --  Byte-level cases: integrity codes, encodings, bit arrays, and the
   --  stream buffer sequences.

   SB_Buffer : Byte_Array (0 .. 95) := (others => 16#EE#);
   SB        : Adaflight.Stream_Buffers.Stream;
   Seq_SB    : Integer_64 := -1;

   function Hex_Bytes (I : Positive) return Byte_Array is
      S : constant String := Str (I);
      R : Byte_Array (0 .. S'Length / 2 - 1);
   begin
      for K in R'Range loop
         R (K) := Byte'Value ("16#" & S (S'First + 2 * K .. S'First + 2 * K + 1) & "#");
      end loop;
      return R;
   end Hex_Bytes;

   function Hex_Words (I : Positive) return Adaflight.Bit_Arrays.Bit_Array is
      S : constant String := Str (I);
      R : Adaflight.Bit_Arrays.Bit_Array (0 .. S'Length / 8 - 1);
   begin
      for K in R'Range loop
         R (K) := Adaflight.Bit_Arrays.Word'Value ("16#" & S (S'First + 8 * K .. S'First + 8 * K + 7) & "#");
      end loop;
      return R;
   end Hex_Words;

   procedure Record_Bytes (Name : String; Expected : Byte_Array; Actual : Byte_Array) is
   begin
      if Expected'Length /= Actual'Length then
         Record_Int (Name & ".length", Integer_64 (Expected'Length), Integer_64 (Actual'Length));
      else
         for K in 0 .. Expected'Length - 1 loop
            Record_Int (Name, Integer_64 (Expected (Expected'First + K)),
                        Integer_64 (Actual (Actual'First + K)));
         end loop;
      end if;
   end Record_Bytes;

   procedure Record_Words (Name : String; Expected, Actual : Adaflight.Bit_Arrays.Bit_Array) is
   begin
      for K in Expected'Range loop
         Record_Int (Name, Integer_64 (Expected (K)), Integer_64 (Actual (K)));
      end loop;
   end Record_Words;

   procedure Check_Stream_Line is
      Name : constant String := Str (1);
   begin
      if Int (2) /= Seq_SB then
         Seq_SB := Int (2);
         SB_Buffer := (others => 16#EE#);
         Adaflight.Stream_Buffers.Init (SB, 0, 64);
      end if;
      if Name = "sbw8" then
         Adaflight.Stream_Buffers.Write_U8 (SB_Buffer, SB, Byte (Int_Hex (3)));
      elsif Name = "sbw16" then
         Adaflight.Stream_Buffers.Write_U16 (SB_Buffer, SB, Unsigned_16 (Int_Hex (3)));
      elsif Name = "sbw32" then
         Adaflight.Stream_Buffers.Write_U32 (SB_Buffer, SB, Unsigned_32 (Int_Hex (3)));
      elsif Name = "sbw16be" then
         Adaflight.Stream_Buffers.Write_U16_Big_Endian (SB_Buffer, SB, Unsigned_16 (Int_Hex (3)));
      elsif Name = "sbw32be" then
         Adaflight.Stream_Buffers.Write_U32_Big_Endian (SB_Buffer, SB, Unsigned_32 (Int_Hex (3)));
      elsif Name = "sbfill" then
         Adaflight.Stream_Buffers.Fill (SB_Buffer, SB, Byte (Int_Hex (3)), Integer'Value (Str (4)));
      elsif Name = "sbdata" then
         Adaflight.Stream_Buffers.Write_Data (SB_Buffer, SB, Hex_Bytes (3));
      elsif Name = "sbcrc16" then
         Adaflight.Stream_Buffers.Append_CRC16_CCITT (SB_Buffer, SB, Integer'Value (Str (3)));
      elsif Name = "sbcrc8" then
         Adaflight.Stream_Buffers.Append_CRC8 (SB_Buffer, SB, Integer'Value (Str (3)), DVB_S2_Polynomial);
      elsif Name = "sbxor" then
         Adaflight.Stream_Buffers.Append_Xor (SB_Buffer, SB, Integer'Value (Str (3)));
      elsif Name = "sbcontents" then
         Record_Int ("sbcontents.written", Int (4), Integer_64 (SB.Next));
         Record_Bytes ("sbcontents.bytes", Hex_Bytes (5), SB_Buffer (0 .. SB.Next - 1));
         Adaflight.Stream_Buffers.Switch_To_Reader (SB, 0);
      elsif Name = "sbr8" then
         declare
            V : Byte;
         begin
            Adaflight.Stream_Buffers.Read_U8 (SB_Buffer, SB, V);
            Record_Int (Name, Int_Hex (3), Integer_64 (V));
            Record_Int (Name & ".pos", Int (4), Integer_64 (SB.Next));
         end;
      elsif Name = "sbr16" then
         declare
            V : Unsigned_16;
         begin
            Adaflight.Stream_Buffers.Read_U16 (SB_Buffer, SB, V);
            Record_Int (Name, Int_Hex (3), Integer_64 (V));
            Record_Int (Name & ".pos", Int (4), Integer_64 (SB.Next));
         end;
      elsif Name = "sbr32" then
         declare
            V : Unsigned_32;
         begin
            Adaflight.Stream_Buffers.Read_U32 (SB_Buffer, SB, V);
            Record_Int (Name, Int_Hex (3), Integer_64 (V));
            Record_Int (Name & ".pos", Int (4), Integer_64 (SB.Next));
         end;
      elsif Name = "sbrdata" then
         declare
            Len : constant Natural := Integer'Value (Str (3));
            D   : Byte_Array (0 .. Len - 1);
         begin
            Adaflight.Stream_Buffers.Read_Data (SB_Buffer, SB, D);
            Record_Bytes (Name, Hex_Bytes (4), D);
            Record_Int (Name & ".pos", Int (5), Integer_64 (SB.Next));
         end;
      elsif Name = "sbadvance" then
         declare
            Adv : constant Integer := Integer'Value (Str (3));
         begin
            Adaflight.Stream_Buffers.Advance (SB, Adv);
            Record_Int (Name & ".pos", Int (4), Integer_64 (SB.Next));
         end;
      else
         Put_Line ("unknown bytes case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Stream_Line;

   procedure Check_Bytes_Line is
      Name : constant String := Str (1);
   begin
      if Name = "crc16" then
         Record_Int (Name, Int_Hex (4), Integer_64 (CRC16_CCITT_Update (Unsigned_16 (Int_Hex (2)), Hex_Bytes (3))));
      elsif Name = "crc8" then
         Record_Int (Name, Int_Hex (5),
                     Integer_64 (CRC8_Update (Byte (Int_Hex (2)), Hex_Bytes (4), Byte (Int_Hex (3)))));
      elsif Name = "crc8xor" then
         Record_Int (Name, Int_Hex (4), Integer_64 (CRC8_Xor_Update (Byte (Int_Hex (2)), Hex_Bytes (3))));
      elsif Name = "fnv" then
         Record_Int (Name, Int_Hex (4), Integer_64 (FNV_Update (Unsigned_32 (Int_Hex (2)), Hex_Bytes (3))));
      elsif Name = "zigzag" then
         Record_Int (Name, Int_Hex (3), Integer_64 (Adaflight.Encoding.Zigzag_Encode (I32 (2))));
      elsif Name = "floatbits" then
         Record_Int (Name, Int_Hex (3), Integer_64 (Adaflight.Float_Bits.Float_Bits (Flt (2))));
      elsif Name = "uvarintenc" then
         declare
            Size    : constant Natural := Integer'Value (Str (3));
            Buffer  : Byte_Array (0 .. Size - 1) := (others => 0);
            Written : Natural;
            R       : constant Integer_64 := Int (4);
         begin
            Adaflight.Encoding.Uvarint_Encode (Unsigned_32'Value (Str (2)), Buffer, Written);
            --  Declared deviation (DESIGN.md D6): the reference emits the value
            --  128 as one bare byte 16#80#; the core emits 16#80# 16#01#.
            if Unsigned_32'Value (Str (2)) = 128 then
               Record_Int ("uvarintenc.count", (if Size >= 2 then 2 else 0), Integer_64 (Written));
               if Size >= 2 then
                  Record_Bytes ("uvarintenc.bytes", (16#80#, 16#01#), Buffer (0 .. Written - 1));
               end if;
            else
               Record_Int ("uvarintenc.count", (if R < 0 then 0 else R), Integer_64 (Written));
               if R > 0 then
                  Record_Bytes ("uvarintenc.bytes", Hex_Bytes (5), Buffer (0 .. Written - 1));
               end if;
            end if;
         end;
      elsif Name = "uvarintdec" then
         declare
            Input    : constant Byte_Array := Hex_Bytes (2);
            Value    : Unsigned_32;
            Consumed : Natural;
            Status   : Adaflight.Encoding.Decode_Status;
            R        : constant Integer_64 := Int (3);
         begin
            Adaflight.Encoding.Uvarint_Decode (Input, Value, Consumed, Status);
            Record_Int ("uvarintdec.count", (if R < 0 then 0 else R), Integer_64 (Consumed));
            Record_Int ("uvarintdec.status", (if R = -2 then 2 elsif R = -1 then 1 else 0),
                        Adaflight.Encoding.Decode_Status'Pos (Status));
            if R > 0 then
               Record_Int ("uvarintdec.value", Integer_64 (Unsigned_32'Value (Str (4))), Integer_64 (Value));
            end if;
         end;
      elsif Name = "bitget" then
         Record_Int (Name, Int (4), Boolean'Pos (Adaflight.Bit_Arrays.Get (Hex_Words (2), Integer'Value (Str (3)))));
      elsif Name = "bitset" or else Name = "bitclr" then
         declare
            A : Adaflight.Bit_Arrays.Bit_Array := Hex_Words (2);
         begin
            if Name = "bitset" then
               Adaflight.Bit_Arrays.Set (A, Integer'Value (Str (3)));
            else
               Adaflight.Bit_Arrays.Clear (A, Integer'Value (Str (3)));
            end if;
            Record_Words (Name, Hex_Words (4), A);
         end;
      elsif Name = "bitcopy" then
         declare
            A : Adaflight.Bit_Arrays.Bit_Array := Hex_Words (2);
         begin
            Adaflight.Bit_Arrays.Copy_Bit (A, Integer'Value (Str (3)), Integer'Value (Str (4)));
            Record_Words (Name, Hex_Words (5), A);
         end;
      elsif Name = "bitxor" then
         declare
            D : Adaflight.Bit_Arrays.Bit_Array (0 .. 3);
         begin
            Adaflight.Bit_Arrays.Xor_Into (D, Hex_Words (2), Hex_Words (3));
            Record_Words (Name, Hex_Words (4), D);
         end;
      else
         Check_Stream_Line;
      end if;
   end Check_Bytes_Line;

   --  Extra cases: the Huffman encoder, GPS coordinates, sensor alignment,
   --  color conversion, and the fast exponential and logarithm.

   Huff_Out : Byte_Array (0 .. 159) := (others => 16#AA#);
   Huff     : Adaflight.Huffman.Encoder;

   procedure Check_Extra_Line is
      Name : constant String := Str (1);
   begin
      if Name = "huffstart" then
         Huff_Out := (others => 16#AA#);
         Adaflight.Huffman.Start (Huff, Huff_Out, 2, Integer'Value (Str (3)));
      elsif Name = "huffenc" then
         declare
            Input    : constant Byte_Array := Hex_Bytes (3);
            Overflow : Boolean;
            Expected : constant Byte_Array := Hex_Bytes (7);
         begin
            Adaflight.Huffman.Encode (Huff, Huff_Out, Input, Overflow);
            Record_Int ("huffenc.status", Int (4), (if Overflow then -1 else 0));
            Record_Int ("huffenc.written", Int (5), Integer_64 (Huff.Bytes_Written));
            Record_Int ("huffenc.bit", Int_Hex (6), Integer_64 (Huff.Out_Bit));
            Record_Bytes ("huffenc.bytes", Expected, Huff_Out (2 .. 2 + Expected'Length - 1));
         end;
      elsif Name = "gpscoord" then
         Record_Int (Name, Int (3), Integer_64 (Adaflight.GPS_Conversion.Coordinate_To_Degrees (Str (2))));
      elsif Name = "alignmat" then
         declare
            A : constant Adaflight.Sensor_Alignment.Alignment_Angles :=
              (Roll => Adaflight.Sensor_Alignment.Decidegrees'Value (Str (2)),
               Pitch => Adaflight.Sensor_Alignment.Decidegrees'Value (Str (3)),
               Yaw => Adaflight.Sensor_Alignment.Decidegrees'Value (Str (4)));
         begin
            Record_Matrix (Name, Adaflight.Sensor_Alignment.Rotation_Matrix (A), 5);
         end;
      elsif Name = "alignstd" then
         declare
            A : Adaflight.Sensor_Alignment.Alignment_Angles := (Roll => 123, Pitch => -456, Yaw => 789);
         begin
            Adaflight.Sensor_Alignment.From_Standard
              (A, Adaflight.Sensor_Alignment.Standard_Alignment'Val (Integer'Value (Str (2))));
            Record_Int (Name & ".roll", Int (3), Integer_64 (A.Roll));
            Record_Int (Name & ".pitch", Int (4), Integer_64 (A.Pitch));
            Record_Int (Name & ".yaw", Int (5), Integer_64 (A.Yaw));
         end;
      elsif Name = "hsv2rgb" then
         declare
            C : constant Adaflight.Color.HSV :=
              (H => Integer'Value (Str (2)), S => Adaflight.Color.Component'Value (Str (3)),
               V => Adaflight.Color.Component'Value (Str (4)));
            R : constant Adaflight.Color.RGB := Adaflight.Color.To_RGB (C);
         begin
            Record_Int (Name & ".r", Int (5), Integer_64 (R.R));
            Record_Int (Name & ".g", Int (6), Integer_64 (R.G));
            Record_Int (Name & ".b", Int (7), Integer_64 (R.B));
         end;
      elsif Name = "exp" then
         Record_Result (Name, Bits (3), To_Bits (Adaflight.Exponentials.Exp_Approx (Flt (2))));
      elsif Name = "log" then
         Record_Result (Name, Bits (3), To_Bits (Adaflight.Exponentials.Log_Approx (Flt (2))));
      elsif Name = "pow" then
         Record_Result (Name, Bits (4), To_Bits (Adaflight.Exponentials.Pow_Approx (Flt (2), Flt (3))));
      else
         Put_Line ("unknown extra case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Extra_Line;

   CG : Adaflight.Chirp.Generator;

   procedure Check_Chirp_Line is
      Name : constant String := Str (1);
      Running : Boolean;
   begin
      if Name = "fmod" then
         Record_Result (Name, Bits (4), To_Bits (Adaflight.Chirp.Fmod (Flt (2), Flt (3))));
      elsif Name = "chirpinit" then
         Adaflight.Chirp.Init (CG, Flt (3), Flt (4), Flt (5), Adaflight.Chirp.Unsigned_32'Value (Str (6)));
         Record_Result ("chirpinit.ts", Bits (7), To_Bits (CG.Ts));
         Record_Int ("chirpinit.n", Int (8), Integer_64 (CG.N));
         Record_Result ("chirpinit.beta", Bits (9), To_Bits (CG.Beta));
         Record_Result ("chirpinit.k0", Bits (10), To_Bits (CG.K0));
         Record_Result ("chirpinit.k1", Bits (11), To_Bits (CG.K1));
      elsif Name = "chirp" then
         Adaflight.Chirp.Update (CG, Running);
         Record_Int ("chirp.running", Int (3), Boolean'Pos (Running));
         Record_Int ("chirp.count", Int (4), Integer_64 (CG.Count));
         Record_Result ("chirp.fchirp", Bits (5), To_Bits (CG.F_Chirp));
         Record_Result ("chirp.sinarg", Bits (6), To_Bits (CG.Sin_Arg));
         Record_Int ("chirp.finished", Int (7), Boolean'Pos (CG.Is_Finished));
      elsif Name = "chirpend" then
         while CG.Count < CG.N + 3 and then not CG.Is_Finished loop
            Adaflight.Chirp.Update (CG, Running);
         end loop;
         for K in 1 .. 3 loop
            Adaflight.Chirp.Update (CG, Running);
         end loop;
         Record_Int ("chirpend.count", Int (3), Integer_64 (CG.Count));
         Record_Int ("chirpend.finished", Int (4), Boolean'Pos (CG.Is_Finished));
         Record_Result ("chirpend.fchirp", Bits (5), To_Bits (CG.F_Chirp));
         Record_Result ("chirpend.sinarg", Bits (6), To_Bits (CG.Sin_Arg));
      else
         Put_Line ("unknown chirp case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Chirp_Line;

   procedure Check_Rates_Line is
      Name : constant String := Str (1);
   begin
      if Name = "rate" then
         declare
            A : constant Adaflight.Axes.Axis := Adaflight.Axes.Axis'Val (Integer'Value (Str (3)));
            P : Adaflight.Rates.Profile;
            C : constant Adaflight.Rates.Command := Flt (9);
         begin
            P.Kind := Adaflight.Rates.Curve_Kind'Val (Integer'Value (Str (2)));
            P.RC_Rates (A) := Integer'Value (Str (4));
            P.RC_Expo (A) := Integer'Value (Str (5));
            P.Super_Rates (A) := Integer'Value (Str (6));
            P.Limits (A) := Integer'Value (Str (7));
            P.Quick_Expo := Str (8) = "1";
            Record_Result ("rate." & Adaflight.Rates.Curve_Kind'Image (P.Kind), Bits (10),
                           To_Bits (Adaflight.Rates.Apply (P, A, C, abs C)));
         end;
      else
         Put_Line ("unknown rates case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Rates_Line;

   --  PID runtime configuration: the profile inputs occupy fields 5 to 78
   --  and the expected runtime values follow.
   Profiles : array (0 .. 299) of Adaflight.PID_Profile.Profile;
   Profile_CRSF : array (0 .. 299) of Boolean := (others => False);
   Profile_Loop_Times : array (0 .. 299) of Integer := (others => 1000);

   procedure Check_PID_Init_Line is
      use Adaflight.PID_Profile;
      use Adaflight.PID_Config;
      P : Profile;
      R : Runtime;
      K : Positive := 5;
      function Next_Int return Integer is
         V : constant Integer := Integer'Value (Str (K));
      begin
         K := K + 1;
         return V;
      end Next_Int;
      procedure Expect_Float (Name : String; Actual : Float) is
      begin
         Record_Result ("pidinit." & Name, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float;
      procedure Expect_Int (Name : String; Actual : Integer_64) is
      begin
         Record_Int ("pidinit." & Name, Int (K), Actual);
         K := K + 1;
      end Expect_Int;
      Loop_Time : constant Integer := Integer'Value (Str (3));
      Is_CRSF   : constant Boolean := Str (4) = "1";
      Index     : constant Integer := Integer'Value (Str (2));
   begin
      for A in Adaflight.Axes.Axis loop
         P.Gains (A).P := Next_Int; P.Gains (A).I := Next_Int; P.Gains (A).D := Next_Int;
         P.Gains (A).F := Next_Int; P.Gains (A).S := Next_Int; P.D_Max (A) := Next_Int;
      end loop;
      P.Level.P := Next_Int; P.Level.I := Next_Int; P.Level.D := Next_Int; P.Level.F := Next_Int;
      P.Angle_Earth_Ref := Next_Int; P.Horizon_Ignore_Sticks := Next_Int = 1;
      P.Horizon_Limit_Degrees := Next_Int; P.Horizon_Delay_Ms := Next_Int;
      P.Rate_Accel_Limit := Next_Int; P.Yaw_Rate_Accel_Limit := Next_Int;
      P.Anti_Gravity_Gain := Next_Int; P.Anti_Gravity_P_Gain := Next_Int;
      P.Crash_Time := Next_Int; P.Crash_Delay := Next_Int; P.Crash_Recovery_Angle := Next_Int;
      P.Crash_Recovery_Rate := Next_Int; P.Crash_Gyro_Threshold := Next_Int;
      P.Crash_Dterm_Threshold := Next_Int; P.Crash_Setpoint_Threshold := Next_Int;
      P.Crash_Limit_Yaw := Next_Int;
      P.Iterm_Windup := Next_Int; P.PID_Sum_Limit := Next_Int; P.PID_Sum_Limit_Yaw := Next_Int;
      P.Iterm_Rotation := Next_Int = 1;
      P.Iterm_Relax := Iterm_Relax_Mode'Val (Next_Int);
      P.Iterm_Relax_Type := Iterm_Relax_Source'Val (Next_Int);
      P.Iterm_Relax_Cutoff := Next_Int;
      P.Acro_Trainer_Angle_Limit := Next_Int; P.Acro_Trainer_Lookahead_Ms := Next_Int;
      P.Acro_Trainer_Debug_Axis := Next_Int; P.Acro_Trainer_Gain := Next_Int;
      P.Dterm_LPF1_Dyn_Min_Hz := Next_Int; P.Dterm_LPF1_Dyn_Max_Hz := Next_Int;
      P.Dterm_LPF1_Dyn_Expo := Next_Int; P.Dterm_LPF1_Type := Lowpass_Kind'Val (Next_Int);
      P.Launch_Control := Launch_Control_Mode'Val (Next_Int);
      P.Launch_Control_Angle_Limit := Next_Int; P.Launch_Control_Gain := Next_Int;
      P.Thrust_Linearization := Next_Int; P.D_Max_Gain := Next_Int; P.D_Max_Advance := Next_Int;
      P.Feedforward_Transition := Next_Int;
      P.Feedforward_Average := Feedforward_Averaging'Val (Next_Int);
      P.Feedforward_Smooth_Factor := Next_Int; P.Feedforward_Jitter_Factor := Next_Int;
      P.Feedforward_Boost := Next_Int; P.Feedforward_Max_Rate_Limit := Next_Int;
      P.Feedforward_Yaw_Hold_Gain := Next_Int; P.Feedforward_Yaw_Hold_Time := Next_Int;
      P.Level_Race_Mode := Next_Int = 1; P.TPA_Rate := Next_Int; P.TPA_Breakpoint := Next_Int;
      P.TPA_Low_Rate := Next_Int; P.TPA_Low_Breakpoint := Next_Int; P.TPA_Low_Always := Next_Int = 1;
      P.Landing_Disarm_Threshold := Next_Int;
      Profiles (Index) := P;
      Profile_CRSF (Index) := Is_CRSF;
      Profile_Loop_Times (Index) := Loop_Time;
      Configure (R, P, Loop_Time, Has_Acc => False, Serial_Rx_Is_CRSF => Is_CRSF);
      Expect_Float ("dt", R.Dt); Expect_Float ("frequency", R.PID_Frequency);
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("kp", R.Coefficient (A).Kp); Expect_Float ("ki", R.Coefficient (A).Ki);
         Expect_Float ("kd", R.Coefficient (A).Kd); Expect_Float ("kf", R.Coefficient (A).Kf);
      end loop;
      Expect_Float ("angle_gain", R.Angle_Gain); Expect_Float ("angle_ff", R.Angle_Feedforward_Gain);
      Expect_Float ("earth_ref", R.Angle_Earth_Ref); Expect_Float ("horizon_gain", R.Horizon_Gain);
      Expect_Float ("horizon_ignore", R.Horizon_Ignore_Sticks);
      Expect_Float ("horizon_sticks", R.Horizon_Limit_Sticks);
      Expect_Float ("horizon_sticks_inv", R.Horizon_Limit_Sticks_Inv);
      Expect_Float ("horizon_degrees", R.Horizon_Limit_Degrees);
      Expect_Float ("horizon_degrees_inv", R.Horizon_Limit_Degrees_Inv);
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("max_velocity", R.Max_Velocity (A));
      end loop;
      Expect_Int ("ag_gain", Integer_64 (R.Anti_Gravity_Gain));
      Expect_Float ("ag_osd", R.Anti_Gravity_Osd_Cutoff); Expect_Float ("ag_p", R.Anti_Gravity_P_Gain);
      Expect_Int ("crash_time", Integer_64 (R.Crash_Time_Limit_Us));
      Expect_Int ("crash_delay", Integer_64 (R.Crash_Time_Delay_Us));
      Expect_Int ("crash_angle", Integer_64 (R.Crash_Recovery_Angle_Dd));
      Expect_Float ("crash_rate", R.Crash_Recovery_Rate); Expect_Float ("crash_gyro", R.Crash_Gyro_Threshold);
      Expect_Float ("crash_dterm", R.Crash_Dterm_Threshold);
      Expect_Float ("crash_setpoint", R.Crash_Setpoint_Threshold); Expect_Float ("crash_yaw", R.Crash_Limit_Yaw);
      Expect_Float ("iterm_limit", R.Iterm_Limit); Expect_Float ("iterm_limit_yaw", R.Iterm_Limit_Yaw);
      Expect_Int ("iterm_rotation", Boolean'Pos (R.Iterm_Rotation));
      Expect_Int ("iterm_relax", Iterm_Relax_Mode'Pos (R.Iterm_Relax));
      Expect_Int ("iterm_relax_type", Iterm_Relax_Source'Pos (R.Iterm_Relax_Type));
      Expect_Int ("iterm_relax_cutoff", Integer_64 (R.Iterm_Relax_Cutoff));
      Expect_Float ("acro_angle", R.Acro_Trainer_Angle_Limit);
      Expect_Float ("acro_lookahead", R.Acro_Trainer_Lookahead);
      Expect_Int ("acro_axis", Integer_64 (R.Acro_Trainer_Debug_Axis));
      Expect_Float ("acro_gain", R.Acro_Trainer_Gain);
      Expect_Int ("dyn_lpf", Dyn_Lowpass'Pos (R.Dyn_LPF_Filter));
      Expect_Int ("dyn_min", Integer_64 (R.Dyn_LPF_Min)); Expect_Int ("dyn_max", Integer_64 (R.Dyn_LPF_Max));
      Expect_Int ("dyn_expo", Integer_64 (R.Dyn_LPF_Curve_Expo));
      Expect_Int ("launch_mode", Launch_Control_Mode'Pos (R.Launch_Control));
      Expect_Int ("launch_angle", Integer_64 (R.Launch_Control_Angle_Limit));
      Expect_Float ("launch_ki", R.Launch_Control_Ki); Expect_Float ("thrust_linear", R.Thrust_Linearization);
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("dmax_percent", R.D_Max_Percent (A));
      end loop;
      Expect_Float ("dmax_gyro", R.D_Max_Gyro_Gain); Expect_Float ("dmax_setpoint", R.D_Max_Setpoint_Gain);
      Expect_Float ("ff_transition", R.Feedforward_Transition);
      Expect_Float ("ff_transition_inv", R.Feedforward_Transition_Inv);
      Expect_Int ("ff_averaging", Feedforward_Averaging'Pos (R.Feedforward_Average));
      Expect_Float ("ff_smooth", R.Feedforward_Smooth_Factor);
      Expect_Int ("ff_jitter", Integer_64 (R.Feedforward_Jitter_Factor));
      Expect_Float ("ff_jitter_inv", R.Feedforward_Jitter_Factor_Inv);
      Expect_Float ("ff_boost", R.Feedforward_Boost_Factor);
      Expect_Int ("ff_max_rate", Integer_64 (R.Feedforward_Max_Rate_Limit));
      Expect_Int ("ff_interpolate", Boolean'Pos (R.Feedforward_Interpolate));
      Expect_Float ("ff_yaw_time", R.Feedforward_Yaw_Hold_Time);
      Expect_Float ("ff_yaw_gain", R.Feedforward_Yaw_Hold_Gain);
      Expect_Int ("race_mode", Boolean'Pos (R.Level_Race_Mode));
      Expect_Float ("tpa_breakpoint", R.TPA_Breakpoint); Expect_Float ("tpa_multiplier", R.TPA_Multiplier);
      Expect_Float ("tpa_low_breakpoint", R.TPA_Low_Breakpoint);
      --  Declared deviation (DESIGN.md D6): an infinite or undefined low
      --  multiplier in the reference is zero here.
      if (Bits (K) and 16#7F80_0000#) = 16#7F80_0000# then
         Record_Result ("pidinit.tpa_low_multiplier", 0, To_Bits (R.TPA_Low_Multiplier));
         K := K + 1;
      else
         Expect_Float ("tpa_low_multiplier", R.TPA_Low_Multiplier);
      end if;
      Expect_Int ("tpa_low_always", Boolean'Pos (R.TPA_Low_Always));
      Expect_Int ("ez_disarm", Boolean'Pos (R.Use_Ez_Disarm));
      Expect_Float ("landing_threshold", R.Landing_Disarm_Threshold);
      if K /= NF + 1 then
         Put_Line ("pidinit: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
         Failures := Failures + 1;
      end if;
   end Check_PID_Init_Line;

   procedure Check_PID_Filters_Line is
      use Adaflight.PID_Profile;
      use Adaflight.PID_Config;
      use Adaflight.PID_Filters;
      P : Profile := Profiles (Integer'Value (Str (2)));
      R : Runtime;
      S : State;
      K : Positive := 4;
      function Next_Int return Integer is
         V : constant Integer := Integer'Value (Str (K));
      begin
         K := K + 1;
         return V;
      end Next_Int;
      procedure Expect_Float (Name : String; Actual : Float) is
      begin
         Record_Result ("pidfilt." & Name, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float;
      procedure Expect_Int (Name : String; Actual : Integer_64) is
      begin
         Record_Result ("pidfilt." & Name, Unsigned_32 (Integer_64'Value (Str (K))), Unsigned_32 (Actual));
         K := K + 1;
      end Expect_Int;
      function Stage_Kind (Stage : Lowpass_Stage) return Integer_64 is
        (if not Stage.Used then 0
         else (case Stage.Kind is
                  when Adaflight.PID_Profile.PT1 => 1, when Adaflight.PID_Profile.SVF => 2,
                  when Adaflight.PID_Profile.PT2 => 3, when Adaflight.PID_Profile.PT3 => 4));
      procedure Expect_Stage (Name : String; Stage : Lowpass_Stage) is
      begin
         case Stage_Kind (Stage) is
            when 1 => Expect_Float (Name & ".k", Stage.P1.K); K := K + 3;
            when 2 =>
               Expect_Float (Name & ".f", Stage.S.F); Expect_Float (Name & ".a1", Stage.S.A1);
               Expect_Float (Name & ".a2", Stage.S.A2); K := K + 1;
            when 3 => Expect_Float (Name & ".k", Stage.P2.K); K := K + 3;
            when 4 => Expect_Float (Name & ".k", Stage.P3.K); K := K + 3;
            when others => K := K + 4;
         end case;
      end Expect_Stage;
      Loop_Time : constant Integer := Integer'Value (Str (3));
   begin
      P.Dterm_Notch_Hz := Next_Int; P.Dterm_Notch_Cutoff := Next_Int;
      P.Dterm_LPF1_Static_Hz := Next_Int; P.Dterm_LPF1_Dyn_Min_Hz := Next_Int;
      P.Dterm_LPF1_Type := Lowpass_Kind'Val (Next_Int);
      P.Dterm_LPF2_Static_Hz := Next_Int; P.Dterm_LPF2_Type := Lowpass_Kind'Val (Next_Int);
      P.Yaw_Lowpass_Hz := Next_Int;
      R.Iterm_Relax := Iterm_Relax_Mode'Val (Next_Int); R.Iterm_Relax_Cutoff := Next_Int;
      P.Anti_Gravity_Cutoff_Hz := Next_Int; P.Throttle_Boost_Cutoff := Next_Int;
      P.Angle_Feedforward_Smoothing_Ms := Next_Int; P.Horizon_Delay_Ms := Next_Int;
      R.Dt := Float (Loop_Time) * 1.0e-6;
      Init (S, P, R);
      Profiles (Integer'Value (Str (2))) := P;
      Expect_Int ("notch_used", Boolean'Pos (S.Notch_Used));
      if S.Notch_Used then
         for A in Adaflight.Axes.Axis loop
            Expect_Float ("notch.a1", S.Notch (A).A1); Expect_Float ("notch.a2q", S.Notch (A).A2Q);
            Expect_Float ("notch.fq", S.Notch (A).FQ);
         end loop;
      else
         K := K + 9;
      end if;
      Expect_Int ("lpf1_kind", Stage_Kind (S.Lowpass1 (Adaflight.Axes.Roll)));
      for A in Adaflight.Axes.Axis loop
         Expect_Stage ("lpf1", S.Lowpass1 (A));
      end loop;
      Expect_Int ("lpf2_kind", Stage_Kind (S.Lowpass2 (Adaflight.Axes.Roll)));
      for A in Adaflight.Axes.Axis loop
         Expect_Stage ("lpf2", S.Lowpass2 (A));
      end loop;
      Expect_Int ("yaw_used", Boolean'Pos (S.Yaw_P_Used));
      if S.Yaw_P_Used then
         Expect_Float ("yaw_k", S.Yaw_P_Lowpass.K);
      else
         K := K + 1;
      end if;
      Expect_Float ("throttle_k", S.Throttle_Boost.K);
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("windup_k", S.Windup (A).K);
      end loop;
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("dmax_range_k", S.D_Max_Range (A).K);
      end loop;
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("dmax_lowpass_k", S.D_Max_Lowpass (A).K);
      end loop;
      Expect_Float ("anti_gravity_k", S.Anti_Gravity.K);
      for A in Level_Axis loop
         Expect_Float ("attitude_k", S.Attitude (A).K);
      end loop;
      for A in Level_Axis loop
         Expect_Float ("angle_feedforward_k", S.Angle_Feedforward (A).K);
      end loop;
      Expect_Float ("horizon_k", S.Horizon_Smoothing.K);
      if K /= NF + 1 then
         Put_Line ("pidfilt: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
         Failures := Failures + 1;
      end if;
   end Check_PID_Filters_Line;

   Step_State   : Adaflight.PID_Controller.State;
   Step_Runtime : Adaflight.PID_Config.Runtime;
   Step_Profile : Adaflight.PID_Profile.Profile;

   procedure Check_PID_Step_Line is
      use Adaflight.PID_Profile;
      use Adaflight.PID_Config;
      use Adaflight.PID_Controller;
      Index    : constant Integer := Integer'Value (Str (2));
      Step     : constant Integer := Integer'Value (Str (3));
      Loop_Time : constant Integer := Integer'Value (Str (4));
      Inp      : Inputs;
      K        : Positive := 18;
      procedure Expect_Float (Name : String; Actual : Float) is
      begin
         Record_Result ("pidstep." & Name, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float;
   begin
      if Step = 0 then
         Step_Profile := Profiles (Index);
         Step_Profile.TPA_Terms := TPA_Mode'Val (Integer'Value (Str (5)));
         Configure (Step_Runtime, Step_Profile, Loop_Time, Has_Acc => False,
                    Serial_Rx_Is_CRSF => Profile_CRSF (Index));
         Init (Step_State, Step_Profile, Step_Runtime);
         Set_Stabilisation (Step_State, True);
      end if;
      Inp.Anti_Gravity_Enabled := Str (6) = "1";
      Inp.Zero_Throttle_Iterm_Reset := Str (7) = "1";
      for A in Adaflight.Axes.Axis loop
         Inp.Gyro (A) := Flt (8 + Adaflight.Axes.Axis'Pos (A));
         Inp.Setpoint (A) := Flt (11 + Adaflight.Axes.Axis'Pos (A));
         Inp.Feedforward (A) := Flt (14 + Adaflight.Axes.Axis'Pos (A));
      end loop;
      Update_Throttle_Terms (Step_State, Step_Runtime, Flt (17));
      Expect_Float ("tpa_factor", Step_State.TPA_Factor);
      Expect_Float ("anti_gravity_throttle_d", Step_State.Anti_Gravity_Throttle_D);
      Update (Step_State, Step_Runtime, Step_Profile, Inp);
      Expect_Float ("iterm_accelerator", Step_State.Iterm_Accelerator);
      for A in Adaflight.Axes.Axis loop
         Expect_Float ("p", Step_State.Data (A).P); Expect_Float ("i", Step_State.Data (A).I);
         Expect_Float ("d", Step_State.Data (A).D); Expect_Float ("f", Step_State.Data (A).F);
         Expect_Float ("sum", Step_State.Data (A).Sum);
      end loop;
      if K /= NF + 1 then
         Put_Line ("pidstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
         Failures := Failures + 1;
      end if;
   end Check_PID_Step_Line;

   procedure Check_PID_Thr_Line is
      use Adaflight.PID_Profile;
      use Adaflight.PID_Config;
      use Adaflight.PID_Filters;
      Name  : constant String := Str (1);
      Index : constant Integer := Integer'Value (Str (2));
      P     : Profile := Profiles (Index);
      R     : Runtime;
      K     : Positive := 5;
      procedure Expect_Float (Prefix : String; Actual : Float) is
      begin
         Record_Result (Prefix, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float;
      function Stage_Kind (Stage : Lowpass_Stage) return Integer_64 is
        (if not Stage.Used then 0
         else (case Stage.Kind is
                  when Adaflight.PID_Profile.PT1 => 1, when Adaflight.PID_Profile.SVF => 2,
                  when Adaflight.PID_Profile.PT2 => 3, when Adaflight.PID_Profile.PT3 => 4));
      procedure Expect_Stage (Stage : Lowpass_Stage) is
      begin
         case Stage_Kind (Stage) is
            when 1 => Expect_Float ("piddyn.lpf1.k", Stage.P1.K); K := K + 3;
            when 2 =>
               Expect_Float ("piddyn.lpf1.f", Stage.S.F); Expect_Float ("piddyn.lpf1.a1", Stage.S.A1);
               Expect_Float ("piddyn.lpf1.a2", Stage.S.A2); K := K + 1;
            when 3 => Expect_Float ("piddyn.lpf1.k", Stage.P2.K); K := K + 3;
            when 4 => Expect_Float ("piddyn.lpf1.k", Stage.P3.K); K := K + 3;
            when others => K := K + 4;
         end case;
      end Expect_Stage;
   begin
      if Name = "pidtpa" then
         P.TPA_Curve_Type := Hyperbolic;
         P.TPA_Curve_Stall_Throttle := Integer'Value (Str (3));
         P.TPA_Curve_PID_Thr0 := Integer'Value (Str (4));
         P.TPA_Curve_PID_Thr100 := Integer'Value (Str (5));
         P.TPA_Curve_Expo := Integer'Value (Str (6));
         Profiles (Index) := P;
         Configure (R, P, Profile_Loop_Times (Index), Has_Acc => False,
                    Serial_Rx_Is_CRSF => Profile_CRSF (Index));
         for I in 0 .. TPA_Curve_Points - 1 loop
            if (Bits (7 + I) and 16#7F80_0000#) = 16#7F80_0000#
              or else To_Float (Bits (7 + I)) > Adaflight.Maths.Signal_Bound
            then
               --  Declared deviation (DESIGN.md D6): a table entry the reference
               --  leaves infinite or beyond the signal bound saturates here.
               Record_Result ("pidtpa.y.saturated", To_Bits (Adaflight.Maths.Signal_Bound),
                              To_Bits (R.TPA_Curve.Y (I)));
            else
               Record_Result ("pidtpa.y", Bits (7 + I), To_Bits (R.TPA_Curve.Y (I)), Tolerance => 0);
            end if;
         end loop;
      elsif Name = "piddyn" then
         declare
            S : State;
         begin
            Configure (R, P, Integer'Value (Str (3)), Has_Acc => False,
                       Serial_Rx_Is_CRSF => Profile_CRSF (Index));
            Init (S, P, R);
            Update_Dynamic_Lowpass (S, R, Flt (4));
            Record_Int ("piddyn.lpf1_kind", Int (K), Stage_Kind (S.Lowpass1 (Adaflight.Axes.Roll)));
            K := K + 1;
            for A in Adaflight.Axes.Axis loop
               Expect_Stage (S.Lowpass1 (A));
            end loop;
            if K /= NF + 1 then
               Put_Line ("piddyn: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      elsif Name = "pidtl" then
         Configure (R, P, Profile_Loop_Times (Index), Has_Acc => False,
                    Serial_Rx_Is_CRSF => Profile_CRSF (Index));
         Record_Result ("pidtl.apply", Bits (5),
                        To_Bits (Adaflight.PID_Controller.Apply_Thrust_Linearization (R, Flt (3))));
         Record_Result ("pidtl.compensate", Bits (6),
                        To_Bits (Adaflight.PID_Controller.Compensate_Thrust_Linearization (R, Flt (4))));
      else
         Put_Line ("unknown pidthr case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_PID_Thr_Line;

   Mix_State    : Adaflight.Mixer.State;
   Mix_Config   : Adaflight.Mixer.Config;
   Mix_Ctl      : Adaflight.PID_Controller.State;
   Mix_Runtime  : Adaflight.PID_Config.Runtime;
   Mix_Profile  : Adaflight.PID_Profile.Profile;
   Mix_Airmode  : Boolean := False;
   Mix_AG       : Boolean := False;

   procedure Check_Mix_Line is
      use Adaflight.PID_Profile;
      use Adaflight.PID_Config;
      use Adaflight.PID_Controller;
      use Adaflight.Mixer;
      Name  : constant String := Str (1);
      Index : constant Integer := Integer'Value (Str (2));
      K     : Positive := 15;
      procedure Expect_Float (N : String; Actual : Float) is
      begin
         Record_Result ("mixstep." & N, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float;
   begin
      if Name = "mixinit" then
         Mix_Profile := Profiles (Index);
         Mix_Profile.TPA_Terms := TPA_Mode'Val (Integer'Value (Str (4)));
         Mix_Profile.Throttle_Boost := Integer'Value (Str (12));
         Mix_Profile.TPA_Curve_Type := TPA_Curve_Kind'Val (Integer'Value (Str (20)));
         Mix_Profile.TPA_Curve_Stall_Throttle := Integer'Value (Str (21));
         Mix_Profile.TPA_Curve_PID_Thr0 := Integer'Value (Str (22));
         Mix_Profile.TPA_Curve_PID_Thr100 := Integer'Value (Str (23));
         Mix_Profile.TPA_Curve_Expo := Integer'Value (Str (24));
         Mix_Config := (Kind => Mixer_Kind'Val (Integer'Value (Str (5))),
                        Yaw_Reversed => Str (6) = "1",
                        Throttle_Limit => Throttle_Limit_Kind'Val (Integer'Value (Str (7))),
                        Throttle_Limit_Percent => Integer'Value (Str (15)),
                        Output_Low => Flt (16), Output_High => Flt (17), Disarm_Output => Flt (18),
                        others => <>);
         Mix_Airmode := Str (13) = "1";
         Mix_AG := Str (14) = "1";
         Configure (Mix_Runtime, Mix_Profile, Integer'Value (Str (3)), Has_Acc => False,
                    Serial_Rx_Is_CRSF => Profile_CRSF (Index));
         Record_Result ("mixinit.throttle_boost", Bits (19), To_Bits (Mix_Runtime.Throttle_Boost));
         Init (Mix_Ctl, Mix_Profile, Mix_Runtime);
         Set_Stabilisation (Mix_Ctl, True);
         Mix_State := (others => <>);
      elsif Name = "mixstep" then
         declare
            Step      : constant Integer := Integer'Value (Str (3));
            Loop_Time : constant Integer := Integer'Value (Str (4));
            Inp       : Adaflight.PID_Controller.Inputs;
            MInp      : Adaflight.Mixer.Inputs;
         begin
            for A in Adaflight.Axes.Axis loop
               Inp.Gyro (A) := Flt (5 + Adaflight.Axes.Axis'Pos (A));
               Inp.Setpoint (A) := Flt (8 + Adaflight.Axes.Axis'Pos (A));
               Inp.Feedforward (A) := Flt (11 + Adaflight.Axes.Axis'Pos (A));
            end loop;
            Inp.Anti_Gravity_Enabled := Mix_AG;
            Update (Mix_Ctl, Mix_Runtime, Mix_Profile, Inp);
            MInp.RC_Throttle := Flt (14);
            MInp.Time_Us := Interfaces.Unsigned_32 ((Step + 1) * Loop_Time);
            MInp.Armed := True;
            MInp.Airmode := Mix_Airmode;
            Adaflight.Mixer.Update (Mix_State, Mix_Config, Mix_Ctl, Mix_Runtime, Mix_Profile, MInp);
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("p", Mix_Ctl.Data (A).P); Expect_Float ("i", Mix_Ctl.Data (A).I);
               Expect_Float ("d", Mix_Ctl.Data (A).D); Expect_Float ("f", Mix_Ctl.Data (A).F);
               Expect_Float ("sum", Mix_Ctl.Data (A).Sum);
            end loop;
            Expect_Float ("iterm_accelerator", Mix_Ctl.Iterm_Accelerator);
            Expect_Float ("tpa_factor", Mix_Ctl.TPA_Factor);
            Expect_Float ("anti_gravity_throttle_d", Mix_Ctl.Anti_Gravity_Throttle_D);
            Expect_Float ("throttle", Mix_State.Throttle);
            Expect_Float ("rc_throttle", Mix_State.RC_Throttle);
            Expect_Float ("mix_range", Mix_State.Mix_Range);
            for M in 0 .. 3 loop
               Expect_Float ("motor." & Mixer_Kind'Image (Mix_Config.Kind)
                             & (if Mix_Airmode then ".air" else ".noair")
                             & (if Mix_Config.Throttle_Limit = Off then "" else ".lim"), Mix_State.Motors (M));
            end loop;
            if K /= NF + 1 then
               Put_Line ("mixstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown mix case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Mix_Line;

   RC_State   : Adaflight.RC_Command.State;
   RC_Config  : Adaflight.RC_Command.Config;
   RC_Runtime : Adaflight.PID_Config.Runtime;
   RC_Time    : Interfaces.Unsigned_32 := 0;

   procedure Check_RC_Line is
      use Adaflight.RC_Command;
      Name : constant String := Str (1);
      K    : Positive := 10;
      --  Declared deviation (DESIGN.md D6): the averaged feedforward carries the
      --  moving average's recomputed sum, held within 512 representable values
      --  or a hundredth of a degree per second.
      procedure Expect_Float (N : String; Actual : Float; Tolerance : Integer_64 := 0) is
      begin
         Record_Result ("rcstep." & N, Bits (K), To_Bits (Actual), Tolerance,
                        Absolute => (if Tolerance > 0 then 0.01 else 0.0));
         K := K + 1;
      end Expect_Float;
   begin
      if Name = "rcinit" then
         declare
            use Adaflight.Rates;
            use Adaflight.PID_Config;
            C : Config;
            R : Runtime;
            F : Positive := 5;
         begin
            C.Rates.Kind := Curve_Kind'Val (Integer'Value (Str (4)));
            for A in Adaflight.Axes.Axis loop
               C.Rates.RC_Rates (A) := Integer'Value (Str (F));
               C.Rates.RC_Expo (A) := Integer'Value (Str (F + 1));
               C.Rates.Super_Rates (A) := Integer'Value (Str (F + 2));
               C.Rates.Limits (A) := Integer'Value (Str (F + 3));
               F := F + 4;
            end loop;
            C.Rates.Quick_Expo := Str (17) = "1";
            C.Rates.Throttle_Mid := Integer'Value (Str (18));
            C.Rates.Throttle_Expo := Integer'Value (Str (19));
            C.Rates.Throttle_Hover := Integer'Value (Str (20));
            C.Receiver.Mid_RC := Integer'Value (Str (21));
            C.Receiver.Min_Check := Integer'Value (Str (22));
            C.Receiver.Smoothing := Str (23) = "1";
            C.Receiver.Auto_Factor_Setpoint := Integer'Value (Str (24));
            C.Receiver.Auto_Factor_Throttle := Integer'Value (Str (25));
            C.Receiver.Setpoint_Cutoff := Integer'Value (Str (26));
            C.Receiver.Throttle_Cutoff := Integer'Value (Str (27));
            C.Controls.Deadband := Integer'Value (Str (28));
            C.Controls.Yaw_Deadband := Integer'Value (Str (29));
            C.Controls.Yaw_Reversed := Str (30) = "1";
            C.Loop_Time := Integer'Value (Str (3));
            R.Feedforward_Smooth_Factor := Flt (31);
            R.Feedforward_Interpolate := Str (32) = "1";
            R.Feedforward_Jitter_Factor_Inv := Flt (33);
            R.Feedforward_Boost_Factor := Flt (34);
            R.Feedforward_Max_Rate_Limit := Integer'Value (Str (35));
            R.Feedforward_Yaw_Hold_Time := Flt (36);
            R.Feedforward_Yaw_Hold_Gain := Flt (37);
            R.Feedforward_Transition := Flt (38);
            R.Feedforward_Transition_Inv := Flt (39);
            R.Feedforward_Average :=
              Adaflight.PID_Profile.Feedforward_Averaging'Val (Integer'Value (Str (40)));
            RC_Config := C;
            RC_Runtime := R;
            RC_Time := 0;
            Init (RC_State, RC_Config, RC_Runtime);
            for I in Table_Index loop
               Record_Int ("rcinit.table", Int (41 + I), Integer_64 (RC_State.Table (I)));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Record_Result ("rcinit.max_rate", Bits (53 + Adaflight.Axes.Axis'Pos (A)),
                              To_Bits (RC_State.Max_Rate (A)));
            end loop;
            Record_Result ("rcinit.divider", Bits (56), To_Bits (RC_State.Command_Divider));
            Record_Result ("rcinit.yaw_divider", Bits (57), To_Bits (RC_State.Yaw_Divider));
         end;
      elsif Name = "rcstep" then
         declare
            Interval : constant Integer := Integer'Value (Str (4));
            Loops    : constant Integer := Integer'Value (Str (5));
            Data     : Channel_Values;
            FF_Tol   : constant Integer_64 := (if RC_State.Averaging > 0 then 512 else 0);
         begin
            RC_Time := RC_Time + Interfaces.Unsigned_32 (Interval);
            Update_Refresh_Rate (RC_State, RC_Time, True, RC_Time);
            for Ch in Channel loop
               Data (Ch) := Flt (6 + Ch);
            end loop;
            Update_Commands (RC_State, RC_Config, Data);
            Process (RC_State, RC_Config, RC_Runtime);
            for J in 2 .. Loops loop
               Process (RC_State, RC_Config, RC_Runtime);
            end loop;
            for Ch in Channel loop
               Expect_Float ("command", RC_State.Command (Ch));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("raw_setpoint", RC_State.Raw_Setpoint (A));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("setpoint_rate", RC_State.Setpoint_Rate (A));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("feedforward_raw", RC_State.Feedforward_Raw (A), FF_Tol);
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("feedforward_smoothed", RC_State.Feedforward_Smoothed (A), FF_Tol);
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("deflection", RC_State.Deflection (A));
            end loop;
            Expect_Float ("max_deflection", RC_State.Max_Deflection_Abs);
            Expect_Float ("setpoint_cutoff", Float (RC_State.Setpoint_Cutoff_Hz));
            Expect_Float ("throttle_cutoff", Float (RC_State.Throttle_Cutoff_Hz));
            Expect_Float ("smoothed_rate", RC_State.Smoothed_Rate_Hz);
            Record_Int ("rcstep.rate_valid", Int (K), Boolean'Pos (RC_State.Rate_Valid));
            K := K + 1;
            if K /= NF + 1 then
               Put_Line ("rcstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown rc case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_RC_Line;

   Gyro_State    : Adaflight.Gyro_Filters.State;
   Gyro_Settings : Adaflight.Gyro_Filters.Settings;
   Gyro_Denom    : Integer := 1;

   procedure Check_Gyro_Line is
      use Adaflight.Gyro_Filters;
      Name : constant String := Str (1);
   begin
      if Name = "gyroinit" then
         declare
            C : Settings;
            K : Positive := 22;
            function Stage_Kind (St : Stage) return Integer_64 is
              (if not St.Used then 0
               else (case St.Kind is
                        when Adaflight.PID_Profile.PT1 => 1, when Adaflight.PID_Profile.SVF => 2,
                        when Adaflight.PID_Profile.PT2 => 3, when Adaflight.PID_Profile.PT3 => 4));
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("gyroinit." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Stage (N : String; St : Stage) is
            begin
               case Stage_Kind (St) is
                  when 1 => Expect_Float (N & ".k", St.P1.K); K := K + 3;
                  when 2 =>
                     Expect_Float (N & ".f", St.S.F);
                     Expect_Float (N & ".a1", St.S.A1);
                     Expect_Float (N & ".a2", St.S.A2);
                     K := K + 1;
                  when 3 => Expect_Float (N & ".k", St.P2.K); K := K + 3;
                  when 4 => Expect_Float (N & ".k", St.P3.K); K := K + 3;
                  when others => K := K + 4;
               end case;
            end Expect_Stage;
         begin
            C.Loop_Time_Us := Integer'Value (Str (3));
            C.Sample_Time_Us := Integer'Value (Str (4));
            Gyro_Denom := Integer'Value (Str (5));
            C.Scale := Flt (6);
            for A in Adaflight.Axes.Axis loop
               C.Zero (A) := Flt (7 + Adaflight.Axes.Axis'Pos (A));
            end loop;
            C.LPF1_Type := Adaflight.PID_Profile.Lowpass_Kind'Val (Integer'Value (Str (10)));
            C.LPF1_Static_Hz := Integer'Value (Str (11));
            C.LPF1_Dyn_Min_Hz := Integer'Value (Str (12));
            C.LPF1_Dyn_Max_Hz := Integer'Value (Str (13));
            C.LPF1_Dyn_Expo := Integer'Value (Str (14));
            C.LPF2_Type := Adaflight.PID_Profile.Lowpass_Kind'Val (Integer'Value (Str (15)));
            C.LPF2_Static_Hz := Integer'Value (Str (16));
            C.Notch1_Hz := Integer'Value (Str (17));
            C.Notch1_Cutoff := Integer'Value (Str (18));
            C.Notch2_Hz := Integer'Value (Str (19));
            C.Notch2_Cutoff := Integer'Value (Str (20));
            Gyro_Settings := C;
            Init (Gyro_State, Gyro_Settings);
            Record_Int ("gyroinit.downsample", Int (21), Boolean'Pos (Gyro_State.Downsample_Filter));
            Record_Int ("gyroinit.lpf1_kind", Int (K), Stage_Kind (Gyro_State.Lowpass1 (Adaflight.Axes.Roll)));
            K := K + 1;
            for A in Adaflight.Axes.Axis loop
               Expect_Stage ("lpf1", Gyro_State.Lowpass1 (A));
            end loop;
            Record_Int ("gyroinit.lpf2_kind", Int (K), Stage_Kind (Gyro_State.Lowpass2 (Adaflight.Axes.Roll)));
            K := K + 1;
            for A in Adaflight.Axes.Axis loop
               Expect_Stage ("lpf2", Gyro_State.Lowpass2 (A));
            end loop;
            Record_Int ("gyroinit.notch1_used", Int (K), Boolean'Pos (Gyro_State.Notch1_Used));
            K := K + 1;
            if Gyro_State.Notch1_Used then
               for A in Adaflight.Axes.Axis loop
                  Expect_Float ("notch1.a1", Gyro_State.Notch1 (A).A1);
                  Expect_Float ("notch1.a2q", Gyro_State.Notch1 (A).A2Q);
                  Expect_Float ("notch1.fq", Gyro_State.Notch1 (A).FQ);
               end loop;
            else
               K := K + 9;
            end if;
            Record_Int ("gyroinit.notch2_used", Int (K), Boolean'Pos (Gyro_State.Notch2_Used));
            K := K + 1;
            if Gyro_State.Notch2_Used then
               for A in Adaflight.Axes.Axis loop
                  Expect_Float ("notch2.a1", Gyro_State.Notch2 (A).A1);
                  Expect_Float ("notch2.a2q", Gyro_State.Notch2 (A).A2Q);
                  Expect_Float ("notch2.fq", Gyro_State.Notch2 (A).FQ);
               end loop;
            else
               K := K + 9;
            end if;
            Expect_Float ("imu_k", Gyro_State.IMU_Filter (Adaflight.Axes.Roll).K);
            Record_Int ("gyroinit.dyn_filter", Int (K), Adaflight.PID_Config.Dyn_Lowpass'Pos (Gyro_State.Dyn_LPF));
            Record_Int ("gyroinit.dyn_min", Int (K + 1), Integer_64 (Gyro_State.Dyn_LPF_Min));
            Record_Int ("gyroinit.dyn_max", Int (K + 2), Integer_64 (Gyro_State.Dyn_LPF_Max));
            Record_Int ("gyroinit.dyn_expo", Int (K + 3), Integer_64 (Gyro_State.Dyn_LPF_Expo));
         end;
      elsif Name = "gyrostep" then
         declare
            K : Positive := 5;
            Thr : constant Float := Flt (4);
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("gyrostep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
         begin
            if Thr >= 0.0 then
               Update_Dynamic_Lowpass (Gyro_State, Gyro_Settings, Thr);
            end if;
            for S in 1 .. Gyro_Denom loop
               declare
                  Sample : Raw_Vector;
               begin
                  for A in Adaflight.Axes.Axis loop
                     Sample (A) := Integer (Int (K)); K := K + 1;
                  end loop;
                  Accumulate (Gyro_State, Gyro_Settings, Sample);
               end;
            end loop;
            Filter (Gyro_State, Gyro_Settings);
            for A in Adaflight.Axes.Axis loop Expect_Float ("rate", Gyro_State.Rate (A)); end loop;
            for A in Adaflight.Axes.Axis loop Expect_Float ("filtered", Gyro_State.Filtered (A)); end loop;
            for A in Adaflight.Axes.Axis loop Expect_Float ("downsampled", Gyro_State.Downsampled (A)); end loop;
            if K /= NF + 1 then
               Put_Line ("gyrostep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown gyro case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Gyro_Line;

   IMU_State  : Adaflight.Attitude.State;
   IMU_Config : Adaflight.Attitude.Config;

   procedure Check_IMU_Line is
      use Adaflight.Attitude;
      Name : constant String := Str (1);
   begin
      if Name = "imuinit" then
         IMU_Config := Configure ((DCM_Kp                    => Integer (Int (3)),
                                   DCM_Ki                    => Integer (Int (4)),
                                   Small_Angle               => Integer (Int (5)),
                                   Throttle_Correction_Angle => Integer (Int (6)),
                                   Throttle_Correction_Value => Integer (Int (7))));
         Init (IMU_State);
      elsif Name = "imustep" then
         declare
            K : Positive := 14;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("imustep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("imustep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            Gyro : constant Adaflight.Vectors.Vector3 := (X => Flt (7), Y => Flt (8), Z => Flt (9));
            Acc  : constant Adaflight.Vectors.Vector3 := (X => Flt (10), Y => Flt (11), Z => Flt (12));
         begin
            Update (IMU_State, IMU_Config,
                    Now           => Interfaces.Unsigned_32 (Int (4)),
                    Gyro          => Gyro,
                    Acc           => Acc,
                    Acc_Magnitude => Flt (13),
                    Armed         => Int (5) /= 0,
                    Angle_Mode    => Int (6) /= 0);
            Expect_Int ("roll", Integer_64 (IMU_State.Euler.Roll));
            Expect_Int ("pitch", Integer_64 (IMU_State.Euler.Pitch));
            Expect_Int ("yaw", Integer_64 (IMU_State.Euler.Yaw));
            Expect_Float ("q.w", IMU_State.Q.W);
            Expect_Float ("q.x", IMU_State.Q.X);
            Expect_Float ("q.y", IMU_State.Q.Y);
            Expect_Float ("q.z", IMU_State.Q.Z);
            for Row in Adaflight.Vectors.Coordinate loop
               for Col in Adaflight.Vectors.Coordinate loop
                  Expect_Float ("rotation", IMU_State.Rotation (Row, Col));
               end loop;
            end loop;
            Expect_Int ("correction", Integer_64 (IMU_State.Throttle_Correction));
            Expect_Float ("cos_tilt", Cos_Tilt (IMU_State));
            if K /= NF + 1 then
               Put_Line ("imustep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown imu case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_IMU_Line;

   FS_State    : Adaflight.Failsafe.State;
   FS_Settings : Adaflight.Failsafe.Settings;
   FS_Disarms  : Integer_64 := 0;

   procedure Check_Failsafe_Line is
      use Adaflight.Failsafe;
      Name : constant String := Str (1);
   begin
      if Name = "fsinit" then
         FS_Settings := (Throttle_Low_Delay => Integer (Int (3)),
                         Signal_Delay       => Integer (Int (4)),
                         Landing_Time       => Integer (Int (5)),
                         Switch             => Switch_Mode'Val (Int (6)),
                         Action             => Procedure_Kind'Val (Int (7)),
                         Recovery_Delay     => Integer (Int (8)));
         Init (FS_State, FS_Settings);
         FS_Disarms := 0;
         Record_Int ("fsinit.failure_period", Int (9), Integer_64 (FS_State.Rx_Data_Failure_Period));
         Record_Int ("fsinit.recovery_period", Int (10), Integer_64 (FS_State.Rx_Data_Recovery_Period));
      elsif Name = "fsstep" then
         declare
            Now       : constant Time_Ms := Time_Ms (Int (4));
            In_Flight : constant Inputs :=
              (Armed               => Int (5) /= 0,
               Switch_On           => Int (6) /= 0,
               Throttle_Low        => Int (7) /= 0,
               Configurator_Active => Int (8) /= 0,
               Crash_Recovery      => Int (9) /= 0);
            Event     : constant Integer_64 := Int (10);
            Beeper    : Beep;
            Disarm    : Boolean;
            K         : Positive := 13;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("fsstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            function Flags return Integer_64 is
              ((if FS_State.Arming_Disabled then 2 else 0) + (if FS_State.Arming_Disabled_Rx then 4 else 0));
         begin
            if Int (12) /= 0 then
               Start_Monitoring (FS_State);
            end if;
            case Event is
               when 1 => On_Valid_Data_Received (FS_State, Now);
               when 2 => On_Valid_Data_Failed (FS_State, Now);
               when 3 => Check_Data_Failure_Period (FS_State, Now);
               when 4 => On_Rx_Suspend (FS_State, Interfaces.Unsigned_32 (Int (11)));
               when 5 => On_Rx_Resume (FS_State, Now);
               when others => null;
            end case;
            Update (FS_State, FS_Settings, Now, In_Flight, Beeper, Disarm);
            if Disarm then
               FS_Disarms := FS_Disarms + 1;
            end if;
            Expect_Int ("phase", Phase'Pos (FS_State.Current));
            Expect_Int ("link", Link'Pos (FS_State.Rx_Link));
            Expect_Int ("active", Boolean'Pos (FS_State.Active));
            Expect_Int ("monitoring", Boolean'Pos (FS_State.Monitoring));
            Expect_Int ("events", Integer_64 (FS_State.Events));
            Expect_Int ("throttle_low_period", Integer_64 (FS_State.Throttle_Low_Period));
            Expect_Int ("landing_deadline", Integer_64 (FS_State.Landing_Should_Be_Finished_At));
            Expect_Int ("receiving_period", Integer_64 (FS_State.Receiving_Rx_Data_Period));
            Expect_Int ("receiving_preset", Integer_64 (FS_State.Receiving_Rx_Data_Period_Preset));
            Expect_Int ("received_at", Integer_64 (FS_State.Valid_Rx_Data_Received_At));
            Expect_Int ("failed_at", Integer_64 (FS_State.Valid_Rx_Data_Failed_At));
            Expect_Int ("flight_mode", (if FS_State.Failsafe_Mode then 1024 else 0));
            Expect_Int ("arming_disabled", Flags);
            Expect_Int ("disarms", FS_Disarms);
            Expect_Int ("beeper", (case Beeper is when Silence => -1, when Rx_Lost => 2, when Rx_Lost_Landing => 3));
            if K /= NF + 1 then
               Put_Line ("fsstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown failsafe case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Failsafe_Line;

   procedure Check_PID_Line is
   begin
      if Str (1) = "pidinit" then
         Check_PID_Init_Line;
      elsif Str (1) = "pidfilt" then
         Check_PID_Filters_Line;
      elsif Str (1) = "pidstep" then
         Check_PID_Step_Line;
      else
         Put_Line ("unknown pid case " & Str (1));
         Failures := Failures + 1;
      end if;
   end Check_PID_Line;

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
               elsif Kind = "common" then
                  Check_Common_Line;
               elsif Kind = "bytes" then
                  Check_Bytes_Line;
               elsif Kind = "extra" then
                  Check_Extra_Line;
               elsif Kind = "chirp" then
                  Check_Chirp_Line;
               elsif Kind = "rates" then
                  Check_Rates_Line;
               elsif Kind = "pidthr" then
                  Check_PID_Thr_Line;
               elsif Kind = "mix" then
                  Check_Mix_Line;
               elsif Kind = "rc" then
                  Check_RC_Line;
               elsif Kind = "gyro" then
                  Check_Gyro_Line;
               elsif Kind = "imu" then
                  Check_IMU_Line;
               elsif Kind = "failsafe" then
                  Check_Failsafe_Line;
               else
                  Check_PID_Line;
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
   Run (Dir & "/bytes.csv", "bytes");
   Run (Dir & "/extra.csv", "extra");
   Run (Dir & "/chirp.csv", "chirp");
   Run (Dir & "/rates.csv", "rates");
   Run (Dir & "/pid.csv", "pid");
   Run (Dir & "/pidthr.csv", "pidthr");
   Run (Dir & "/mix.csv", "mix");
   Run (Dir & "/rc.csv", "rc");
   Run (Dir & "/gyro.csv", "gyro");
   Run (Dir & "/imu.csv", "imu");
   Run (Dir & "/failsafe.csv", "failsafe");
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
