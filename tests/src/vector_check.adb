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
with Adaflight.Dyn_Notch;
with Adaflight.RPM_Filter;
with Adaflight.Attitude;
with Adaflight.Failsafe;
with Adaflight.Modes;
with Adaflight.Accelerometer;
with Adaflight.Barometer;
with Adaflight.Battery;
with Adaflight.Arming;
with Adaflight.Compass;
with Adaflight.Position_Filter;
with Adaflight.Altitude_Estimator;
with Adaflight.Altitude_Hold;
with Adaflight.Adjustments;
with Adaflight.Scheduler;
with Adaflight.Beeper;
with Adaflight.Receiver;
with Adaflight.SBUS;
with Adaflight.CRSF;
with Adaflight.Clock;
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
with Adaflight.SUMD;
with Adaflight.SUMH;
with Adaflight.IBUS;
with Adaflight.Spektrum;
with Adaflight.XBUS;
with Adaflight.Jeti_Ex_Bus;
with Adaflight.GHST;
with Adaflight.MSP_Receiver;
with Adaflight.SRXL2;
with Adaflight.FPORT;

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

   Max_Fields : constant := 600;
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
      P.Angle_Limit := Next_Int;
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
         if NF >= 65 then
            Step_Profile.Crash_Recovery := Crash_Recovery_Mode'Val (Int (51));
            Step_Profile.Crash_Time := Integer (Int (52));
            Step_Profile.Crash_Delay := Integer (Int (53));
            Step_Profile.Crash_Gyro_Threshold := Integer (Int (54));
            Step_Profile.Crash_Dterm_Threshold := Integer (Int (55));
            Step_Profile.Crash_Setpoint_Threshold := Integer (Int (56));
         end if;
         Configure (Step_Runtime, Step_Profile, Loop_Time, Has_Acc => NF >= 68 and then Int (68) /= 0,
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
      if NF >= 50 then
         Inp.Angle_Mode := Int (36) mod 2 = 1;
         Inp.Horizon_Mode := (Int (36) / 2) mod 2 = 1;
         for A in Level_Axis loop
            Inp.Attitude (A) := Integer (Int (37 + Adaflight.Axes.Axis'Pos (A)));
            Inp.Trims (A) := Integer (Int (39 + Adaflight.Axes.Axis'Pos (A)));
            Inp.Deflection (A) := Flt (41 + Adaflight.Axes.Axis'Pos (A));
            Inp.Max_RC_Rate (A) := Flt (43 + Adaflight.Axes.Axis'Pos (A));
         end loop;
         Inp.Now_Us := Interfaces.Unsigned_32 ((Step + 1) * Loop_Time);
      end if;
      if NF >= 65 then
         Inp.Now_Us := Interfaces.Unsigned_32 (Int (57));
         Inp.Armed := Int (58) /= 0;
         Inp.Acc_Present := Int (59) /= 0;
         Inp.Gyro_Overflow := Int (60) /= 0;
         Inp.Motor_Mix_Range := Flt (61);
      end if;
      if NF >= 68 then
         Inp.Launch_Control_Active := Int (66) /= 0;
         Inp.Yaw_Deflection := Flt (67);
      end if;
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
      if NF >= 50 then
         K := 45;
         Expect_Float ("angle_target_roll", Step_State.Angle_Target (Roll));
         Expect_Float ("angle_target_pitch", Step_State.Angle_Target (Pitch));
         Expect_Float ("angle_yaw_setpoint", Step_State.Angle_Yaw_Setpoint);
         for A in Adaflight.Axes.Axis loop
            Record_Int ("pidstep.axis_in_angle_mode", Int (K), Boolean'Pos (Step_State.Axis_In_Angle_Mode (A)));
            K := K + 1;
         end loop;
      end if;
      if NF >= 65 then
         K := 62;
         Record_Int ("pidstep.in_crash_recovery", Int (K), Boolean'Pos (Step_State.In_Crash_Recovery));
         Record_Int ("pidstep.crash_detected_us", Int (K + 1), Integer_64 (Step_State.Crash_Detected_Us));
         Record_Int ("pidstep.crash_beep", Int (K + 2), Boolean'Pos (Step_State.Crash_Beep));
         Record_Int ("pidstep.crash_disarm", Int (K + 3), Boolean'Pos (Step_State.Crash_Disarm_Requested));
         K := K + 4;
      end if;
      if NF >= 68 then
         K := K + 3;
      end if;
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
   Gyro_Cal_Samples : Natural := 0;
   Gyro_Now_Us      : Interfaces.Unsigned_32 := 0;
   Gyro_Motor_Hz    : Adaflight.RPM_Filter.Motor_Frequencies := (others => 0.0);
   Gyro_Dt_Scale    : Adaflight.RPM_Filter.Cycle_Multiplier := 1.0;

   procedure Check_Gyro_Line is
      use Adaflight.Gyro_Filters;
      Name : constant String := Str (1);
   begin
      if Name = "gyroinit" then
         declare
            C : Settings;
            K : Positive := 26;
            T : constant Positive := NF - 24;
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
            C.Alignment := Adaflight.Sensor_Alignment.Standard_Alignment'Val (Int (7));
            C.Custom_Angles := (Roll  => Adaflight.Sensor_Alignment.Decidegrees (Int (8)),
                                Pitch => Adaflight.Sensor_Alignment.Decidegrees (Int (9)),
                                Yaw   => Adaflight.Sensor_Alignment.Decidegrees (Int (10)));
            C.Board := (Roll => Integer (Int (11)), Pitch => Integer (Int (12)), Yaw => Integer (Int (13)));
            C.LPF1_Type := Adaflight.PID_Profile.Lowpass_Kind'Val (Integer'Value (Str (14)));
            C.LPF1_Static_Hz := Integer'Value (Str (15));
            C.LPF1_Dyn_Min_Hz := Integer'Value (Str (16));
            C.LPF1_Dyn_Max_Hz := Integer'Value (Str (17));
            C.LPF1_Dyn_Expo := Integer'Value (Str (18));
            C.LPF2_Type := Adaflight.PID_Profile.Lowpass_Kind'Val (Integer'Value (Str (19)));
            C.LPF2_Static_Hz := Integer'Value (Str (20));
            C.Notch1_Hz := Integer'Value (Str (21));
            C.Notch1_Cutoff := Integer'Value (Str (22));
            C.Notch2_Hz := Integer'Value (Str (23));
            C.Notch2_Cutoff := Integer'Value (Str (24));
            C.Calibration_Duration := Integer (Int (T));
            C.Movement_Threshold := Integer (Int (T + 1));
            C.Offset_Yaw := Integer (Int (T + 2));
            C.Check_Overflow := Overflow_Check'Val (Int (T + 3));
            C.Yaw_Spin := Spin_Recovery'Val (Int (T + 4));
            C.Yaw_Spin_Threshold := Integer (Int (T + 5));
            C.Overflow_Protected := Int (T + 6) /= 0;
            C.Dynamic_Notch := (Count  => Integer (Int (T + 8)), Q => Integer (Int (T + 9)),
                                Min_Hz => Integer (Int (T + 10)), Max_Hz => Integer (Int (T + 11)));
            C.RPM := (Harmonics     => Integer (Int (T + 13)),
                      Weights       => (0 => Integer (Int (T + 14)), 1 => Integer (Int (T + 15)),
                                        2 => Integer (Int (T + 16))),
                      Min_Hz        => Integer (Int (T + 17)),
                      Fade_Range_Hz => Integer (Int (T + 18)),
                      Q             => Integer (Int (T + 19)));
            C.Motors := Integer (Int (T + 20));
            C.Motor_Telemetry := Int (T + 21) /= 0;
            Gyro_Settings := C;
            Init (Gyro_State, Gyro_Settings);
            Init_Yaw_Spin_Recovery (Gyro_State, Gyro_Settings, Natural (Int (T + 7)));
            Record_Int ("gyroinit.dyn_active", Int (T + 12), Boolean'Pos (Gyro_State.Dyn.Active));
            Record_Int ("gyroinit.rpm_harmonics", Int (T + 22), Integer_64 (Gyro_State.RPM.Harmonics));
            Record_Result ("gyroinit.rpm_max_hz", Bits (T + 23), To_Bits (Gyro_State.RPM.Max_Hz));
            Record_Int ("gyroinit.rpm_updates", Int (T + 24), Integer_64 (Gyro_State.RPM.Updates_Per_Loop));
            Gyro_Motor_Hz := (others => 0.0);
            Gyro_Dt_Scale := 1.0;
            Record_Int ("gyroinit.downsample", Int (25), Boolean'Pos (Gyro_State.Downsample_Filter));
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
            if K + 3 /= T - 1 then
               Put_Line ("gyroinit: settings end at" & Integer'Image (K + 3) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
            Start_Calibration (Gyro_State, Gyro_Settings, False);
            Gyro_Cal_Samples := 0;
         end;
      elsif Name = "gyrocal" then
         --  A block of calibration samples at the sensor rate, with the loop
         --  running between them as on the craft.
         declare
            Finished : Boolean;
            K        : Positive := 3;
         begin
            while K + 2 <= NF loop
               Accumulate (Gyro_State, Gyro_Settings,
                           (Roll => Integer (Int (K)), Pitch => Integer (Int (K + 1)), Yaw => Integer (Int (K + 2))),
                           Finished);
               Gyro_Cal_Samples := Gyro_Cal_Samples + 1;
               if Gyro_Cal_Samples mod Gyro_Denom = 0 then
                  Filter (Gyro_State, Gyro_Settings,
                          Interfaces.Unsigned_32 (Gyro_Cal_Samples * Gyro_Settings.Sample_Time_Us), 0,
                          Gyro_Motor_Hz, Gyro_Dt_Scale);
               end if;
               K := K + 3;
            end loop;
         end;
      elsif Name = "gyrocaldone" then
         Filter (Gyro_State, Gyro_Settings,
                 Interfaces.Unsigned_32 (Gyro_Cal_Samples * Gyro_Settings.Sample_Time_Us), 0,
                 Gyro_Motor_Hz, Gyro_Dt_Scale);
         Record_Int ("gyrocaldone.samples", Int (3), Integer_64 (Gyro_Cal_Samples));
         for A in Adaflight.Axes.Axis loop
            Record_Result ("gyrocaldone.zero", Bits (4 + Adaflight.Axes.Axis'Pos (A)), To_Bits (Gyro_State.Zero (A)));
         end loop;
         Record_Int ("gyrocaldone.cycles", Int (7), Integer_64 (Gyro_State.Cycles_Remaining));
         for A in Adaflight.Axes.Axis loop
            Record_Result ("gyrocaldone.imu", Bits (8 + Adaflight.Axes.Axis'Pos (A)),
                           To_Bits (Gyro_State.Downsampled (A)));
         end loop;
         Gyro_Now_Us := Interfaces.Unsigned_32 (Gyro_Cal_Samples * Gyro_Settings.Sample_Time_Us);
      elsif Name = "gyrostep" then
         declare
            K   : Positive := 16;
            Thr : constant Float := Flt (4);
            Finished : Boolean;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("gyrostep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
         begin
            Gyro_Dt_Scale := Flt (7);
            for M in Adaflight.RPM_Filter.Motor_Index loop
               Gyro_Motor_Hz (M) := Flt (8 + M);
            end loop;
            if Thr >= 0.0 then
               Update_Dynamic_Lowpass (Gyro_State, Gyro_Settings, Thr);
            end if;
            if Int (5) /= 0 then
               Start_Calibration (Gyro_State, Gyro_Settings, False);
            end if;
            for S in 1 .. Gyro_Denom loop
               Accumulate (Gyro_State, Gyro_Settings,
                           (Roll => Integer (Int (K)), Pitch => Integer (Int (K + 1)), Yaw => Integer (Int (K + 2))),
                           Finished);
               K := K + 3;
            end loop;
            Gyro_Now_Us := Gyro_Now_Us + Interfaces.Unsigned_32 (Gyro_Settings.Loop_Time_Us);
            Filter (Gyro_State, Gyro_Settings, Gyro_Now_Us, Natural (Int (6)), Gyro_Motor_Hz, Gyro_Dt_Scale);
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("rate", Gyro_State.Rate (A));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("filtered", Gyro_State.Filtered (A));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("imu", Gyro_State.Downsampled (A));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Float ("zero", Gyro_State.Zero (A));
            end loop;
            Record_Int ("gyrostep.cycles", Int (K), Integer_64 (Gyro_State.Cycles_Remaining));
            Record_Int ("gyrostep.overflow", Int (K + 1), Boolean'Pos (Gyro_State.Overflow_Detected));
            Record_Int ("gyrostep.yaw_spin", Int (K + 2), Boolean'Pos (Gyro_State.Yaw_Spin_Detected));
            Record_Int ("gyrostep.now", Int (K + 3), Integer_64 (Gyro_Now_Us));
            K := K + 4;
            for A in Adaflight.Axes.Axis loop
               for P in Adaflight.Dyn_Notch.Notch_Index loop
                  Expect_Float ("center", Gyro_State.Dyn.Center (A, P));
               end loop;
            end loop;
            Record_Int ("gyrostep.max_center", Int (K), Integer_64 (Gyro_State.Dyn.Max_Center));
            Record_Int ("gyrostep.rpm_motor", Int (K + 1), Integer_64 (Gyro_State.RPM.Motor));
            Record_Int ("gyrostep.rpm_harmonic", Int (K + 2), Integer_64 (Gyro_State.RPM.Harmonic_Index));
            K := K + 3;
            if Gyro_State.RPM.Harmonics > 0 then
               Expect_Float ("rpm_f", Gyro_State.RPM.Notches (0, 0).F);
               Expect_Float ("rpm_a1", Gyro_State.RPM.Notches (0, 0).A1);
               Expect_Float ("rpm_a2", Gyro_State.RPM.Notches (0, 0).A2);
               Expect_Float ("rpm_wq", Gyro_State.RPM.Notches (0, 0).WQ);
            else
               K := K + 4;
            end if;
            if K /= NF + 1 then
               Put_Line ("gyrostep: consumed" & Integer'Image (K) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown gyro case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Gyro_Line;

   Pos_Filter : Adaflight.Position_Filter.Filter;
   Pos_Op     : Integer_64 := 9;
   Pos_Meas   : Float := 0.0;
   Pos_R      : Float := 0.0;

   procedure Check_Position_Line is
      use Adaflight.Position_Filter;
      Name : constant String := Str (1);
      procedure Expect_State (Prefix : String; First : Positive) is
         K : Positive := First;
      begin
         for C in Component loop
            Record_Result (Prefix & ".x", Bits (K), To_Bits (Pos_Filter.X (C)));
            K := K + 1;
         end loop;
         for Row in Component loop
            for Col in Component loop
               Record_Result (Prefix & ".p", Bits (K), To_Bits (Pos_Filter.P (Row, Col)));
               K := K + 1;
            end loop;
         end loop;
         if K /= NF + 1 then
            Put_Line (Prefix & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Expect_State;
   begin
      if Name = "posinit" then
         Init (Pos_Filter, Pos => Flt (3), Vel => Flt (4), Acc => Flt (5),
               Pos_Var => Flt (6), Vel_Var => Flt (7), Acc_Var => Flt (8), Q_Jerk => Flt (9));
         Expect_State ("posinit", 10);
      elsif Name = "posstep" then
         Pos_Op := Int (5);
         Pos_Meas := Flt (6);
         Pos_R := Flt (7);
         Predict (Pos_Filter, Flt (4));
         Expect_State ("posstep", 8);
      elsif Name = "posupd" then
         case Pos_Op is
            when 0 | 1 | 2 => Update_Position (Pos_Filter, Pos_Meas, Pos_R);
            when 3 | 4     => Update_Acceleration (Pos_Filter, Pos_Meas, Pos_R);
            when 5 | 6     => Update_Velocity_To_Position (Pos_Filter, Pos_Meas, Pos_R);
            when 7         => Update_Position_To_Velocity (Pos_Filter, Pos_Meas, Pos_R);
            when 8         => Shift_Position (Pos_Filter, Pos_Meas);
            when others    => null;
         end case;
         Expect_State ("posupd", 5);
      else
         Put_Line ("unknown position case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Position_Line;

   AH_State    : Adaflight.Altitude_Hold.State;
   AH_Settings : Adaflight.Altitude_Hold.Settings;

   procedure Check_Alt_Hold_Line is
      use Adaflight.Altitude_Hold;
      Name : constant String := Str (1);
   begin
      if Name = "ahinit" then
         AH_Settings := (Hover_Throttle => Integer (Int (3)),
                         Throttle_Min   => Integer (Int (4)),
                         Throttle_Max   => Integer (Int (5)),
                         Altitude_P     => Integer (Int (6)),
                         Altitude_I     => Integer (Int (7)),
                         Altitude_D     => Integer (Int (8)),
                         Altitude_A     => Integer (Int (9)),
                         Altitude_F     => Integer (Int (10)),
                         Climb_Rate     => Integer (Int (11)),
                         Deadband       => Integer (Int (12)),
                         Min_Check      => Integer (Int (13)));
         Init (AH_State, AH_Settings, Altitude_Cm => Flt (22));
         Record_Result ("ahinit.kp", Bits (14), To_Bits (AH_State.Kp));
         Record_Result ("ahinit.ki", Bits (15), To_Bits (AH_State.Ki));
         Record_Result ("ahinit.kd", Bits (16), To_Bits (AH_State.Kd));
         Record_Result ("ahinit.ka", Bits (17), To_Bits (AH_State.Ka));
         Record_Result ("ahinit.kf", Bits (18), To_Bits (AH_State.Kf));
         Record_Result ("ahinit.deadband", Bits (19), To_Bits (AH_State.Deadband));
         Record_Result ("ahinit.max_climb", Bits (20), To_Bits (AH_State.Max_Climb_Rate));
         Record_Int ("ahinit.allow_stick", Int (21), Boolean'Pos (AH_State.Allow_Stick));
         Record_Result ("ahinit.target", Bits (23), To_Bits (AH_State.Target_Altitude_Cm));
      elsif Name = "ahstep" then
         declare
            Inp : constant Inputs :=
              (Hold_Mode             => Int (6) /= 0,
               Interval_Us           => Interfaces.Integer_32 (Int (5)),
               Throttle_Command      => Flt (7),
               Throttle_Low          => Int (8) /= 0,
               Failsafe_Active       => Int (9) /= 0,
               Emergency_Descent     => Int (10) /= 0,
               Emergency_Rate_Cms    => Flt (11),
               Altitude_Cm           => Flt (12),
               Vertical_Velocity     => Flt (13),
               Vertical_Acceleration => Flt (14),
               Cos_Tilt              => Flt (15));
         begin
            Update (AH_State, AH_Settings, Inp);
            Record_Int ("ahstep.active", Int (16), Boolean'Pos (AH_State.Active));
            Record_Result ("ahstep.target", Bits (17), To_Bits (AH_State.Target_Altitude_Cm));
            Record_Result ("ahstep.target_velocity", Bits (18), To_Bits (AH_State.Target_Velocity));
            Record_Result ("ahstep.integral", Bits (19), To_Bits (AH_State.Altitude_I));
            Record_Result ("ahstep.throttle", Bits (20), To_Bits (AH_State.Throttle_Out));
            Record_Int ("ahstep.captured_hover", Int (21), Integer_64 (AH_State.Captured_Hover));
            Record_Int ("ahstep.hover", Int (22), Integer_64 (Hover_Throttle (AH_State, AH_Settings)));
            if NF /= 22 then
               Put_Line ("ahstep: expected 22 fields, got" & Integer'Image (NF));
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown alt hold case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Alt_Hold_Line;

   Adj_State    : Adaflight.Adjustments.State;
   Adj_Settings : Adaflight.Adjustments.Settings;
   Adj_Ranges   : Adaflight.Adjustments.Ranges;
   Adj_Rates    : Adaflight.Adjustments.Rate_Profiles;
   Adj_PID      : Adaflight.PID_Profile.Profile;

   procedure Check_Adjust_Line is
      use Adaflight.Adjustments;
      Name : constant String := Str (1);
      K    : Positive := 1;
      function Next return Integer is
         V : constant Integer := Integer (Int (K));
      begin
         K := K + 1;
         return V;
      end Next;
      procedure Read_Ranges is
      begin
         for M in Range_Index loop
            Adj_Ranges (M).Aux := Next;
            Adj_Ranges (M).Span.Start_Step := Next;
            Adj_Ranges (M).Span.End_Step := Next;
            Adj_Ranges (M).Kind := Function_Kind'Val (Next);
            Adj_Ranges (M).Switch_Aux := Next;
            Adj_Ranges (M).Center := Next;
            Adj_Ranges (M).Scale := Next;
         end loop;
      end Read_Ranges;
      procedure Expect_Int (N : String; Actual : Integer_64) is
      begin
         Record_Int ("adjstep." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Int;
      procedure Check_Fields (Of_Case : String) is
      begin
         if K /= NF + 1 then
            Put_Line (Of_Case & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "adjinit" then
         K := 4;
         Adj_Settings.Mid_RC := Next;
         Adj_Settings.Rate_Profile_6_Position := Next /= 0;
         Adj_State := (others => <>);
         Adj_State.Selected.Rate_Profile := Next;
         Adj_State.Selected.Battery_Profile := Next;
         Read_Ranges;
         for P in Rate_Profile_Index loop
            for A in Adaflight.Axes.Axis loop
               Adj_Rates (P).RC_Rates (A) := Next;
            end loop;
            for A in Adaflight.Axes.Axis loop
               Adj_Rates (P).RC_Expo (A) := Next;
            end loop;
            for A in Adaflight.Axes.Axis loop
               Adj_Rates (P).Super_Rates (A) := Next;
            end loop;
            Adj_Rates (P).Throttle_Expo := Next;
         end loop;
         Adj_PID := (others => <>);
         for A in Adaflight.Axes.Axis loop
            Adj_PID.Gains (A).P := Next;
            Adj_PID.Gains (A).I := Next;
            Adj_PID.Gains (A).D := Next;
            Adj_PID.Gains (A).F := Next;
         end loop;
         for A in Adaflight.Axes.Axis loop
            Adj_PID.D_Max (A) := Next;
         end loop;
         Adj_PID.Level.D := Next;
         Adj_PID.Feedforward_Transition := Next;
         Adj_PID.Simplified_Master_Multiplier := Next;
         Adj_PID.Simplified_PIDs_Mode := Adaflight.PID_Profile.Simplified_Mode'Val (Next);
         Adj_PID.Simplified_Roll_Pitch_Ratio := Next;
         Adj_PID.Simplified_I_Gain := Next;
         Adj_PID.Simplified_D_Gain := Next;
         Adj_PID.Simplified_PI_Gain := Next;
         Adj_PID.Simplified_D_Max_Gain := Next;
         Adj_PID.Simplified_Feedforward_Gain := Next;
         Adj_PID.Simplified_Pitch_PI_Gain := Next;
         Check_Fields ("adjinit");
      elsif Name = "adjranges" then
         K := 4;
         Read_Ranges;
         Reset_List (Adj_State);
         Check_Fields ("adjranges");
      elsif Name = "adjstep" then
         declare
            Inp : Inputs;
            Res : Outputs;
         begin
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (4));
            Inp.Rx_Signal := Int (5) /= 0;
            for Ch in Adaflight.Modes.Aux_Channel loop
               Inp.Aux (Ch) := Flt (6 + Ch);
            end loop;
            Process (Adj_State, Adj_Settings, Adj_Ranges, Adj_Rates, Adj_PID, Inp, Res);
            K := 20;
            Expect_Int ("rate_profile", Integer_64 (Adj_State.Selected.Rate_Profile));
            for P in Rate_Profile_Index loop
               for A in Adaflight.Axes.Axis loop
                  Expect_Int ("rc_rate", Integer_64 (Adj_Rates (P).RC_Rates (A)));
               end loop;
               for A in Adaflight.Axes.Axis loop
                  Expect_Int ("rc_expo", Integer_64 (Adj_Rates (P).RC_Expo (A)));
               end loop;
               for A in Adaflight.Axes.Axis loop
                  Expect_Int ("rate", Integer_64 (Adj_Rates (P).Super_Rates (A)));
               end loop;
               Expect_Int ("throttle_expo", Integer_64 (Adj_Rates (P).Throttle_Expo));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Int ("p", Integer_64 (Adj_PID.Gains (A).P));
               Expect_Int ("i", Integer_64 (Adj_PID.Gains (A).I));
               Expect_Int ("d", Integer_64 (Adj_PID.Gains (A).D));
               Expect_Int ("f", Integer_64 (Adj_PID.Gains (A).F));
            end loop;
            for A in Adaflight.Axes.Axis loop
               Expect_Int ("d_max", Integer_64 (Adj_PID.D_Max (A)));
            end loop;
            Expect_Int ("level_d", Integer_64 (Adj_PID.Level.D));
            Expect_Int ("ff_transition", Integer_64 (Adj_PID.Feedforward_Transition));
            Expect_Int ("master", Integer_64 (Adj_PID.Simplified_Master_Multiplier));
            Expect_Int ("battery_profile", Integer_64 (Adj_State.Selected.Battery_Profile));
            Expect_Int ("audio", Audio_Mode'Pos (Adj_State.Selected.Audio));
            Expect_Int ("led_profile", Integer_64 (Adj_State.Selected.LED_Profile));
            Expect_Int ("led_brightness", Integer_64 (Adj_State.Selected.LED_Brightness));
            Expect_Int ("display_kind", Function_Kind'Pos (Adj_State.Shown.Kind));
            Expect_Int ("display_value", Integer_64 (Adj_State.Shown.Value));
            Expect_Int ("beep_requests", Integer_64 (Res.Beep_Requests));
            Expect_Int ("beeps", Integer_64 (Res.Beeps));
            Expect_Int ("pid_reinit", Boolean'Pos (Res.PID_Reinit));
            Expect_Int ("rc_reinit", Boolean'Pos (Res.RC_Reinit));
            Expect_Int ("config_dirty", Boolean'Pos (Adj_State.Config_Dirty));
            Expect_Int ("battery_reinit", Boolean'Pos (Res.Battery_Reinit));
            Check_Fields ("adjstep");
         end;
      else
         Put_Line ("unknown adjust case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Adjust_Line;

   --  The scheduler replays the reference's passes with the simulated clocks
   --  of the oracle: one cycle per read of the cycle counter and the recorded
   --  durations while a task or a check runs.
   Sched_State    : Adaflight.Scheduler.State;
   Sched_Settings : Adaflight.Scheduler.Settings;
   Sched_Clock    : Unsigned_32 := 0;
   Sched_Tasks    : array (0 .. 63) of Adaflight.Scheduler.Task_Id := (others => Adaflight.Scheduler.System);
   Sched_Task_Count : Natural := 0;

   procedure Check_Sched_Line is
      use Adaflight.Scheduler;
      Name : constant String := Str (1);
      K    : Positive := 1;

      function Next return Integer_64 is
         V : constant Integer_64 := Int (K);
      begin
         K := K + 1;
         return V;
      end Next;

      function Next_Task return Task_Id is
         T : constant Task_Id := Task_Id'Value (Str (K));
      begin
         K := K + 1;
         return T;
      end Next_Task;

      procedure Expect (N : String; Expected : Integer_64; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Expected, Actual);
      end Expect;

      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;

      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;

      function Read_Cycles return Unsigned_32 is
      begin
         Sched_Clock := Sched_Clock + 1;
         return Sched_Clock;
      end Read_Cycles;

      function Micros return Unsigned_32 is (Sched_Clock / Unsigned_32 (Sched_Settings.Cycles_Per_Us));
      function Millis return Unsigned_32 is (Micros / 1_000);

      procedure Expect_Task (T : Task_Id) is
         R : Task_State renames Sched_State.Tasks (T);
      begin
         Expect_Next ("dynamic", Integer_64 (R.Dynamic));
         Expect_Next ("age", Integer_64 (R.Age_Periods));
         Expect_Next ("latest_delta", Integer_64 (R.Latest_Delta_Us));
         Expect_Next ("last_executed", Integer_64 (R.Last_Executed_Us));
         Expect_Next ("last_signaled", Integer_64 (R.Last_Signaled_Us));
         Expect_Next ("last_desired", Integer_64 (R.Last_Desired_Us));
         Expect_Next ("anticipated", Integer_64 (R.Anticipated));
         Expect_Next ("moving_delta", Integer_64 (R.Moving_Sum_Delta));
         Expect_Next ("moving_exec", Integer_64 (R.Moving_Sum_Exec));
         Expect_Next ("max_exec", Integer_64 (R.Max_Exec_Us));
         Expect_Next ("total_exec", Integer_64 (R.Total_Exec_Us));
         Expect_Next ("last_stats", Integer_64 (R.Last_Stats_Us));
         Expect_Next ("exec_since_states", Integer_64 (R.Exec_Since_States));
         Expect_Next ("moving_states_exec", Integer_64 (R.Moving_Sum_States_Exec));
         Expect_Next ("max_states_exec", Integer_64 (R.Max_States_Exec_Us));
      end Expect_Task;

      --  The events of one pass, read ahead so the pass can consume them in
      --  the order the scheduler asks for them.
      type Event is record
         Run        : Boolean := True;
         Task_Of    : Task_Id := System;
         Duration   : Unsigned_32 := 0;
         Rate       : Boolean := False;
         Time       : Boolean := False;
         Next_State : Integer_64 := -1;
         Result     : Boolean := False;
      end record;
      Events      : array (1 .. 80) of Event;
      Event_Count : Natural := 0;
      Event_Next  : Positive := 1;
      Run_Events  : array (1 .. 80) of Task_Id := (others => System);
      Run_Count   : Natural := 0;

      function Take (Run : Boolean; T : Task_Id) return Event is
         E : Event;
      begin
         if Event_Next > Event_Count then
            Put_Line (Name & ": the scheduler asked for " & (if Run then "a run of " else "a check of ")
                      & Task_Id'Image (T) & " past the recorded events");
            Failures := Failures + 1;
            return E;
         end if;
         E := Events (Event_Next);
         Event_Next := Event_Next + 1;
         if E.Run /= Run or else E.Task_Of /= T then
            Put_Line (Name & ": the scheduler asked for " & (if Run then "a run of " else "a check of ")
                      & Task_Id'Image (T) & " where the reference recorded "
                      & (if E.Run then "a run of " else "a check of ") & Task_Id'Image (E.Task_Of));
            Failures := Failures + 1;
         end if;
         return E;
      end Take;

      procedure Run_Body (T : Task_Id) is
         Before : constant Unsigned_32 := Micros;
         E      : constant Event := Take (True, T);
      begin
         Sched_Clock := Sched_Clock + E.Duration;
         if T = System then
            System_Load (Sched_State, Before);
         end if;
         if E.Rate then
            Ignore_Task_Exec_Rate (Sched_State);
         end if;
         if E.Time then
            Ignore_Task_Exec_Time (Sched_State);
         end if;
         if E.Next_State >= 0 then
            Set_Next_State_Time (Sched_State, Time_Delta (E.Next_State));
         end if;
         Execute_End (Sched_State, Before, Micros);
      end Run_Body;

      procedure Run_Task (T : Task_Id; Now_Us : Unsigned_32) is
      begin
         Execute_Begin (Sched_State, T, Now_Us);
         Run_Body (T);
      end Run_Task;

      procedure Pass is
         G        : Gyro_Status;
         Poll     : Boolean;
         Proceed  : Boolean;
         Selected : Boolean;
         Run_It   : Boolean;
         Now      : Unsigned_32;
         Filter_Ready, PID_Ready : Boolean;
         Failsafe_Checks : Natural := 0;
      begin
         Sched_Clock := Unsigned_32 (Int (4));
         G := (Interrupts => Int (5) /= 0, Detected => Unsigned_32 (Int (6)), Sync_Cycles => Unsigned_32 (Int (7)));
         Filter_Ready := Int (8) /= 0;
         PID_Ready := Int (9) /= 0;
         Now := (if Sched_State.Gyro_Enabled then Read_Cycles else 0);
         Begin_Pass (Sched_State, Now, Poll);
         if Poll then
            while Adaflight.Clock.Elapsed (Sched_State.Pass.Next_Target, Now) > 0 loop
               Now := Read_Cycles;
            end loop;
            declare
               Now_Us : constant Unsigned_32 := Micros;
            begin
               Run_Task (Gyro, Now_Us);
               if Filter_Ready then
                  Run_Task (Filter, Now_Us);
               end if;
               if PID_Ready then
                  Run_Task (PID, Now_Us);
               end if;
            end;
            if Failsafe_Due (Sched_State, Millis) then
               Failsafe_Checks := 1;
               Failsafe_Checked (Sched_State, Millis);
            end if;
            End_Realtime (Sched_State, Now, G);
         end if;
         Now := Read_Cycles;
         Begin_Selection (Sched_State, Sched_Settings, Now, Micros, Proceed);
         if Proceed then
            for Q in 0 .. Sched_State.Queue_Size - 1 loop
               if Needs_Check (Sched_State, Q) then
                  declare
                     E : constant Event := Take (False, Queued (Sched_State, Q));
                  begin
                     Sched_Clock := Sched_Clock + E.Duration;
                     Consider (Sched_State, Sched_Settings, Q, E.Result, Micros);
                  end;
               else
                  Consider (Sched_State, Sched_Settings, Q, False, 0);
               end if;
            end loop;
            End_Selection (Sched_State, Read_Cycles, Selected);
            if Selected then
               Confirm (Sched_State, Sched_Settings, Read_Cycles, Run_It);
               if Run_It then
                  Run_Selected_Begin (Sched_State);
                  Run_Body (Sched_State.Current);
                  After_Run (Sched_State, Read_Cycles);
               end if;
            end if;
         end if;
         End_Pass (Sched_State);
         if Event_Next <= Event_Count then
            Put_Line (Name & ": the reference recorded" & Integer'Image (Event_Count - Event_Next + 1)
                      & " more events than the scheduler asked for");
            Failures := Failures + 1;
         end if;
         if Name = "schedpass" then
            Expect ("after", Int (10), Integer_64 (Sched_Clock));
            K := 11;
         else
            Expect_Next ("after", Integer_64 (Sched_Clock));
            Expect_Next ("last_target", Integer_64 (Sched_State.Last_Target_Cycles));
            Expect_Next ("desired_period", Integer_64 (Sched_State.Desired_Period_Cycles));
            Expect_Next ("loop_start", Integer_64 (Sched_State.Loop_Start_Cycles));
            Expect_Next ("guard", Integer_64 (Sched_State.Guard_Cycles));
            Expect_Next ("skipped_rx", Integer_64 (Sched_State.Skipped_Rx));
            Expect_Next ("skipped_osd", Integer_64 (Sched_State.Skipped_OSD));
            Expect_Next ("load", Integer_64 (Sched_State.Average_Load_Percent));
            Expect_Next ("failsafe_ms", Integer_64 (Sched_State.Last_Failsafe_Ms));
            Expect_Next ("failsafe_checks", Integer_64 (Failsafe_Checks));
            Expect_Next ("check_max", Integer_64 (Sched_State.Checks.Max_Exec_Us));
            Expect_Next ("check_total", Integer_64 (Sched_State.Checks.Total_Exec_Us));
            Expect_Next ("check_moving_exec", Integer_64 (Sched_State.Checks.Moving_Sum_Exec_Us));
            Expect_Next ("check_moving_delta", Integer_64 (Sched_State.Checks.Moving_Sum_Delta_Us));
            Expect_Next ("total_exec", Integer_64 (Sched_State.Total_Exec_Us));
            for R in 1 .. Run_Count loop
               Expect_Task (Run_Events (R));
            end loop;
         end if;
      end Pass;
   begin
      if Name = "schedinit" then
         K := 3;
         Sched_Settings.Cycles_Per_Us := Integer (Next);
         Sched_Settings.Rx_Relax := Integer (Next);
         Sched_Settings.OSD_Relax := Integer (Next);
         declare
            Gyro_Period  : constant Integer_64 := Next;
            Gyro_Enabled : constant Boolean := Next /= 0;
            Count        : constant Natural := Integer (Next);
            Queue_Start  : constant Positive := K + 5 * Count;
            Clock_After  : constant Integer_64 := Int (Queue_Start + 1 + Integer (Int (Queue_Start)));
         begin
            Sched_Task_Count := Count;
            Sched_Clock := Unsigned_32 (Clock_After) - 1;
            Init (Sched_State, Sched_Settings, Read_Cycles);
            Reschedule (Sched_State, Sched_Settings, Gyro, Time_Delta (Gyro_Period));
            for T in 0 .. Count - 1 loop
               declare
                  Id : constant Task_Id := Next_Task;
               begin
                  Sched_Tasks (T) := Id;
                  Expect ("period", Next, Integer_64 (Sched_State.Tasks (Id).Period));
                  Expect ("priority", Next, Integer_64 (Defaults (Id).Priority));
                  Expect ("has_check", Next, Boolean'Pos (Defaults (Id).Has_Check));
                  if Next /= 0 then
                     Set_Task_Enabled (Sched_State, Id, True);
                  end if;
               end;
            end loop;
            if Gyro_Enabled then
               Enable_Gyro (Sched_State);
            end if;
            Expect_Next ("queue_size", Integer_64 (Sched_State.Queue_Size));
            for Q in 0 .. Sched_State.Queue_Size - 1 loop
               declare
                  Id : constant Task_Id := Next_Task;
               begin
                  Expect ("queue", Task_Id'Pos (Id), Task_Id'Pos (Sched_State.Queue (Q)));
               end;
            end loop;
            Expect_Next ("clock", Integer_64 (Sched_Clock));
         end;
         Check_Fields;
      elsif Name = "schedenable" then
         K := 4;
         declare
            Id : constant Task_Id := Next_Task;
         begin
            Set_Task_Enabled (Sched_State, Id, Next /= 0);
         end;
         Check_Fields;
      elsif Name = "schedresched" then
         K := 4;
         declare
            Id : constant Task_Id := Next_Task;
         begin
            Reschedule (Sched_State, Sched_Settings, Id, Time_Delta (Next));
         end;
         Check_Fields;
      elsif Name = "schedtasks" then
         K := 4;
         for T in 0 .. Sched_Task_Count - 1 loop
            Expect_Task (Sched_Tasks (T));
         end loop;
         Check_Fields;
      elsif Name = "schedpass" then
         Pass;
         Check_Fields;
      elsif Name = "schedstep" then
         Event_Count := Integer (Int (10));
         K := 11;
         for E in 1 .. Event_Count loop
            declare
               Run : constant Boolean := Str (K) = "r";
               Ev  : Event;
            begin
               K := K + 1;
               Ev.Run := Run;
               Ev.Task_Of := Next_Task;
               Ev.Duration := Unsigned_32 (Next);
               if Run then
                  Ev.Rate := Next /= 0;
                  Ev.Time := Next /= 0;
                  Ev.Next_State := Next;
                  Run_Count := Run_Count + 1;
                  Run_Events (Run_Count) := Ev.Task_Of;
               else
                  Ev.Result := Next /= 0;
               end if;
               Events (E) := Ev;
            end;
         end loop;
         Pass;
         Check_Fields;
      else
         Put_Line ("unknown sched case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Sched_Line;

   Beep_State    : Adaflight.Beeper.State;
   Beep_Settings : Adaflight.Beeper.Settings;

   procedure Check_Beeper_Line is
      use Adaflight.Beeper;
      Name : constant String := Str (1);
      K    : Positive := 1;
      function Next return Integer_64 is
         V : constant Integer_64 := Int (K);
      begin
         K := K + 1;
         return V;
      end Next;
      function Flags_Of (Bits : Integer_64) return Mode_Flags is
         F : Mode_Flags := (others => False);
      begin
         for M in Sound loop
            F (M) := (Bits / 2 ** (Adaflight.Beeper.Mode'Pos (M) - 1)) mod 2 = 1;
         end loop;
         return F;
      end Flags_Of;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
   begin
      if Name = "beepinit" then
         K := 3;
         Beep_Settings.Off_Flags := Flags_Of (Next);
         Beep_Settings.Beacon_Off_Flags := Flags_Of (Next);
         Beep_Settings.Beacon_Tone := Integer (Next);
         Beep_State := (others => <>);
      elsif Name = "beepstep" then
         declare
            Cond   : Conditions;
            Result : Update_Outputs;
            Now_Us : constant Unsigned_32 := Unsigned_32 (Int (4));
            Events : constant Natural := Integer (Int (19));
         begin
            Cond.Battery_Present := Int (5) /= 0;
            Cond.USB_Active := Int (6) /= 0;
            Cond.Configurator_Active := Int (7) /= 0;
            Cond.Mute_Switch := Int (8) /= 0;
            Cond.Beep_Switch := Int (9) /= 0;
            Cond.Satellite_Switch := Int (10) /= 0;
            Cond.GPS_Feature := Int (11) /= 0;
            Cond.GPS_Fix := Int (12) /= 0;
            Cond.Satellites := Integer (Int (13));
            Cond.Motors_Running := Int (14) /= 0;
            Cond.Failsafe_Monitoring := Int (15) /= 0;
            Cond.Failsafe_Receiving := Int (16) /= 0;
            Cond.Last_Disarm_Us := Unsigned_32 (Int (17));
            Cond.Trying_To_Arm := Int (18) /= 0;
            K := 20;
            for E in 1 .. Events loop
               declare
                  Kind : constant String := Str (K);
                  Arg  : constant Integer := Integer (Int (K + 1));
               begin
                  K := K + 2;
                  if Kind = "m" then
                     Request (Beep_State, Beep_Settings, Cond, Adaflight.Beeper.Mode'Val (Arg));
                  elsif Kind = "c" then
                     Confirmation_Beeps (Beep_State, Beep_Settings, Cond, Arg);
                  elsif Kind = "w" then
                     Warning_Beeps (Beep_State, Beep_Settings, Cond, Arg);
                  else
                     Silence_Beeper (Beep_State);
                  end if;
               end;
            end loop;
            Update (Beep_State, Beep_Settings, Cond, Now_Us, Result);
            Expect_Next ("on", Boolean'Pos (Beep_State.Is_On));
            Expect_Next ("led", Boolean'Pos (Beep_State.Warning_Led));
            Expect_Next ("current", Adaflight.Beeper.Mode'Pos (Beep_State.Current));
            Expect_Next ("pos", Integer_64 (Beep_State.Pos));
            Expect_Next ("next_toggle", Integer_64 (Beep_State.Next_Toggle_Us));
            Expect_Next ("arming_time", Integer_64 (Beep_State.Arming_Beep_Us));
            Expect_Next ("last_beacon", Integer_64 (Beep_State.Last_Beacon_Us));
            Expect_Next ("visual", Boolean'Pos (Result.Visual_Beep));
            Expect_Next ("beacon", Boolean'Pos (Result.Beacon_Command));
            Expect_Next ("beacon_tone", (if Result.Beacon_Command then Integer_64 (Beep_Settings.Beacon_Tone) else 0));
            Expect_Next ("beacon_motors", (if Result.Beacon_Command then 4 else 0));
            Expect_Next ("ignore", Boolean'Pos (Result.Ignore_Exec_Time));
            for I in Step_Index loop
               Expect_Next ("multi", Integer_64 (Beep_State.Multi (I)));
            end loop;
            if K /= NF + 1 then
               Put_Line ("beepstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown beeper case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Beeper_Line;

   Rx_State    : Adaflight.Receiver.State;
   Rx_Settings : Adaflight.Receiver.Settings;
   Rx_Raw      : Adaflight.Receiver.Raw_Values := (others => 0);
   --  The frame the driver holds until a frame check that is not skipped
   --  for a running task consumes it.
   Rx_Frame    : Adaflight.Receiver.Frame_Report;

   procedure Check_Rx_Line is
      use Adaflight.Receiver;
      Name : constant String := Str (1);
      K    : Positive := 1;
      function Next return Integer_64 is
         V : constant Integer_64 := Int (K);
      begin
         K := K + 1;
         return V;
      end Next;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Expect_Float_Next (N : String; Actual : Float) is
      begin
         Record_Result (Name & "." & N, Bits (K), To_Bits (Actual));
         K := K + 1;
      end Expect_Float_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "rxinit" then
         declare
            Protocol_RSSI    : RSSI_Source;
            Protocol_Quality : Link_Quality_Source;
            Arm_Aux, Arm_Start, Arm_End : Integer;
            Now_Ms : Unsigned_32;
         begin
            K := 3;
            Rx_Settings.Source := Provider'Val (Next);
            Rx_Settings.Reported_Channels := Integer (Next);
            for M in Mappable_Channel loop
               Rx_Settings.Map (M) := Integer (Next);
            end loop;
            for F in Flight_Channel loop
               Rx_Settings.Ranges (F).Low := Integer (Next);
               Rx_Settings.Ranges (F).High := Integer (Next);
            end loop;
            for Ch in Channel loop
               Rx_Settings.Failsafe (Ch).Mode := Failsafe_Mode'Val (Next);
               Rx_Settings.Failsafe (Ch).Step := Integer (Next);
            end loop;
            Rx_Settings.Min_Usec := Integer (Next);
            Rx_Settings.Max_Usec := Integer (Next);
            Rx_Settings.Mid_RC := Integer (Next);
            Rx_Settings.Max_Aux := Integer (Next);
            Rx_Settings.RSSI_ADC := Next /= 0;
            Rx_Settings.RSSI_Channel := Integer (Next);
            Rx_Settings.RSSI_Scale := Integer (Next);
            Rx_Settings.RSSI_Offset := Integer (Next);
            Rx_Settings.RSSI_Invert := Next /= 0;
            Rx_Settings.RSSI_Smoothing := Integer (Next);
            Rx_Settings.Frame_LPF_Period := Integer (Next);
            Rx_Settings.Feature_3D := Next /= 0;
            Rx_Settings.Switched_Mode_3D := Next /= 0;
            Rx_Settings.Failsafe_Throttle := Integer (Next);
            Protocol_RSSI := RSSI_Source'Val (Next);
            Protocol_Quality := Link_Quality_Source'Val (Next);
            Arm_Aux := Integer (Next);
            Arm_Start := Integer (Next);
            Arm_End := Integer (Next);
            Now_Ms := Unsigned_32 (Next);
            Init (Rx_State, Rx_Settings, Now_Ms, Protocol_RSSI, Protocol_Quality);
            if Arm_Aux >= 0 then
               Init_Arm_Switch (Rx_State, Arm_Aux, (Start_Step => Arm_Start, End_Step => Arm_End));
            end if;
            Rx_Raw := (others => 1500);
            Rx_Frame := (others => False);
            Expect_Next ("channels", Integer_64 (Rx_State.Channels));
            Expect_Next ("rssi_source", RSSI_Source'Pos (Rx_State.RSSI_From));
            for Ch in Channel loop
               Expect_Float_Next ("data", Rx_State.Data (Ch));
            end loop;
            for F in Flight_Channel loop
               Expect_Float_Next ("scale", Rx_State.Scales (F).Scale);
               Expect_Float_Next ("offset", Rx_State.Scales (F).Offset);
            end loop;
            Check_Fields;
         end;
      elsif Name = "rxstep" then
         declare
            Now_Us : constant Unsigned_32 := Unsigned_32 (Int (4));
            Delta_Us : constant Interfaces.Integer_32 := Interfaces.Integer_32 (Int (5));
            Box_Failsafe : constant Boolean := Int (6) /= 0;
            Box_3D : constant Boolean := Int (7) /= 0;
            Failsafe_Active : constant Boolean := Int (8) /= 0;
            Task_In_Progress : constant Boolean := Int (9) /= 0;
            ADC_Sample : constant Natural := Integer (Int (10));
            Events : constant Natural := Integer (Int (11));
            Processed, Frame_Processed : Boolean;
            Valid : Validity;
         begin
            K := 12;
            for E in 1 .. Events loop
               declare
                  Kind : constant String := Str (K);
                  A1   : constant Integer := Integer (Int (K + 1));
                  A2   : constant Integer := Integer (Int (K + 2));
               begin
                  K := K + 3;
                  if Kind = "f" then
                     Rx_Frame := (Complete => A1 mod 2 = 1, Failsafe => (A1 / 2) mod 2 = 1,
                                  Processing_Required => (A1 / 4) mod 2 = 1, Dropped => (A1 / 8) mod 2 = 1,
                                  PPM_Received => False, PWM_Received => False);
                  elsif Kind = "p" then
                     Rx_Frame.PPM_Received := True;
                  elsif Kind = "r" then
                     Set_RSSI (Rx_State, A1, RSSI_Source'Val (A2));
                  elsif Kind = "d" then
                     Set_RSSI_Direct (Rx_State, A1, RSSI_Source'Val (A2));
                  elsif Kind = "m" then
                     Set_RSSI_MSP (Rx_State, A1, Now_Us);
                  elsif Kind = "b" then
                     Set_RSSI_Dbm (Rx_State, A1, RSSI_Source'Val (A2));
                  elsif Kind = "n" then
                     Set_RSNR (Rx_State, A1);
                  elsif Kind = "q" then
                     Set_Link_Quality_Direct (Rx_State, A1);
                  elsif Kind = "s" then
                     Suspend (Rx_State, Rx_Settings, Now_Us);
                  elsif Kind = "u" then
                     Resume (Rx_State, Rx_Settings, Now_Us);
                  else
                     Put_Line ("rxstep: unknown event " & Kind);
                     Failures := Failures + 1;
                  end if;
               end;
            end loop;
            for Ch in Channel loop
               Rx_Raw (Ch) := Integer (Next);
            end loop;
            Frame_Check (Rx_State, Rx_Settings, Now_Us, Delta_Us, Task_In_Progress, Rx_Frame);
            if not Task_In_Progress then
               Rx_Frame := (others => False);
            end if;
            Calculate_Channels (Rx_State, Rx_Settings, Now_Us, Now_Us / 1_000, Rx_Raw, Box_Failsafe, Box_3D,
                                Failsafe_Active, Processed, Frame_Processed, Valid);
            Update_RSSI (Rx_State, Rx_Settings, Now_Us, ADC_Sample);
            Expect_Next ("processed", Boolean'Pos (Processed));
            Expect_Next ("frame_processed", Boolean'Pos (Frame_Processed));
            Expect_Next ("valid_received", Boolean'Pos (Valid = Data_Received));
            Expect_Next ("valid_failed", Boolean'Pos (Valid = Data_Failed));
            Expect_Next ("signal", Boolean'Pos (Rx_State.Signal_Received));
            Expect_Next ("flight_valid", Boolean'Pos (Rx_State.Flight_Valid));
            Expect_Next ("processing_required", Boolean'Pos (Rx_State.Processing_Required));
            Expect_Next ("aux_required", Boolean'Pos (Rx_State.Aux_Required));
            Expect_Next ("skip", Integer_64 (Rx_State.Skip_Samples));
            Expect_Next ("need_before", Integer_64 (Rx_State.Need_Signal_Before));
            Expect_Next ("suspend_until", Integer_64 (Rx_State.Suspend_Until));
            Expect_Next ("sample_index", Integer_64 (Rx_State.Sample_Index));
            Expect_Next ("rssi", Integer_64 (Rx_State.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (Rx_State.RSSI_Raw));
            --  A negative reported RSSI wraps on the oracle's host where the target saturates to zero (DESIGN.md D6).
            declare
               Wrapped : constant Boolean := Int (K) > 32_767;
            begin
               Record_Int (Name & ".rssi_out", (if Wrapped then 0 else Int (K)),
                           Integer_64 (RSSI (Rx_State, Rx_Settings)));
               K := K + 1;
               Record_Int (Name & ".rssi_percent", (if Wrapped then 0 else Int (K)),
                           Integer_64 (RSSI_Percent (Rx_State, Rx_Settings)));
               K := K + 1;
            end;
            Expect_Next ("link_quality", Integer_64 (Rx_State.Link_Quality));
            Expect_Next ("rssi_dbm", Integer_64 (Rx_State.RSSI_Dbm));
            Expect_Next ("rsnr", Integer_64 (Rx_State.RSNR));
            Expect_Next ("lq_percent", Integer_64 (Link_Quality_Percent (Rx_State)));
            Expect_Next ("last_smoothing", Integer_64 (Rx_State.Last_Smoothing_Us));
            Expect_Next ("rssi_source", RSSI_Source'Pos (Rx_State.RSSI_From));
            for Ch in Channel loop
               Expect_Float_Next ("data", Rx_State.Data (Ch));
            end loop;
            Check_Fields;
         end;
      elsif Name = "rxdump" then
         K := 4;
         for Ch in Channel loop
            Expect_Float_Next ("raw", Rx_State.Raw (Ch));
         end loop;
         for Ch in Channel loop
            Expect_Next ("valid_until", Integer_64 (Rx_State.Valid_Until_Ms (Ch)));
         end loop;
         Check_Fields;
      else
         Put_Line ("unknown rx case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Rx_Line;

   SBUS_State : Adaflight.SBUS.State;
   SBUS_Clock : Unsigned_32 := 0;

   procedure Check_SBUS_Line is
      use Adaflight.SBUS;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "sbusinit" then
         Init (SBUS_State, Integer (Int (3)));
         SBUS_Clock := Unsigned_32 (Int (4));
         K := 5;
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (SBUS_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "sbusburst" then
         declare
            Count  : constant Natural := Integer (Int (4));
            Status : Adaflight.Receiver.Frame_Report;
            Polled : Boolean;
            Code   : Integer_64 := 0;
         begin
            K := 5;
            for B in 1 .. Count loop
               SBUS_Clock := SBUS_Clock + Unsigned_32 (Int (K));
               Receive_Byte (SBUS_State, Integer (Int (K + 1)), SBUS_Clock);
               K := K + 2;
            end loop;
            SBUS_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            Polled := Int (K + 4) /= 0;
            if Polled then
               Frame_Status (SBUS_State, Status);
               Code := (if Status.Complete then 1 else 0) + (if Status.Failsafe then 2 else 0)
                 + (if Status.Dropped then 8 else 0);
               Expect_Next ("status", Code);
            else
               K := K + 1;
            end if;
            Expect_Next ("position", Integer_64 (SBUS_State.Frame.Position));
            Expect_Next ("done", Boolean'Pos (SBUS_State.Frame.Done));
            Expect_Next ("start_at", Integer_64 (SBUS_State.Frame.Start_At_Us));
            K := K + 1;
            Expect_Next ("frame_time", Integer_64 (SBUS_State.Last_Frame_Time_Us));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (SBUS_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (SBUS_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown sbus case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SBUS_Line;

   Alt_State    : Adaflight.Altitude_Estimator.State;
   Alt_Settings : Adaflight.Altitude_Estimator.Settings;
   Alt_Present  : Boolean := False;
   Alt_One_G_Reciprocal : Adaflight.Altitude_Estimator.Acc_Scale := 1.0 / 4_096.0;

   procedure Check_Altitude_Line is
      use Adaflight.Altitude_Estimator;
      Name : constant String := Str (1);
   begin
      if Name = "altinit" then
         Alt_Settings := (Source         => Altitude_Source'Val (Int (3)),
                          Prefer_Baro    => Integer (Int (4)),
                          Altitude_LPF   => Integer (Int (5)),
                          Derivative_LPF => Integer (Int (6)));
         Alt_Present := Int (7) /= 0;
         Alt_One_G_Reciprocal := Flt (8);
         Init (Alt_State, Alt_Settings, Armed => False);
         Record_Result ("altinit.altitude_k", Bits (9), To_Bits (Alt_State.Altitude_Filter.K));
         Record_Result ("altinit.derivative_k", Bits (10), To_Bits (Alt_State.Derivative_Filter.K));
      elsif Name = "altstep" then
         declare
            Inp : Inputs;
            K   : Positive := 21;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("altstep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("altstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Armed := Int (5) /= 0;
            Inp.Baro_Altitude_Cm := Flt (6);
            Inp.Baro_Sample_Time_Us := Interfaces.Unsigned_32 (Int (7));
            Inp.Baro_Interval_Us := Interfaces.Integer_32 (Int (8));
            Inp.Acc := (X => Flt (9), Y => Flt (10), Z => Flt (11));
            for Row in Adaflight.Vectors.Coordinate loop
               for Col in Adaflight.Vectors.Coordinate loop
                  Inp.Rotation (Row, Col) :=
                    Flt (12 + 3 * Adaflight.Vectors.Coordinate'Pos (Row) + Adaflight.Vectors.Coordinate'Pos (Col));
               end loop;
            end loop;
            Inp.Baro_Present := Alt_Present;
            Inp.One_G_Reciprocal := Alt_One_G_Reciprocal;
            Update (Alt_State, Alt_Settings, Inp);
            for Comp in Adaflight.Position_Filter.Component loop
               Expect_Float ("x", Alt_State.Up.X (Comp));
            end loop;
            for Row in Adaflight.Position_Filter.Component loop
               for Col in Adaflight.Position_Filter.Component loop
                  Expect_Float ("p", Alt_State.Up.P (Row, Col));
               end loop;
            end loop;
            Expect_Float ("baro_offset", Alt_State.Baro_Offset_Cm);
            Expect_Int ("baro_offset_set", Boolean'Pos (Alt_State.Baro_Offset_Set));
            Expect_Int ("baro_available", Boolean'Pos (Alt_State.Baro_Data_Available));
            Expect_Int ("baro_timestamp", Integer_64 (Alt_State.Baro_Timestamp_Us));
            Expect_Int ("baro_hold", Integer_64 (Alt_State.Baro_Hold_Us));
            Expect_Float ("gate_last", Alt_State.Baro_Gate.Last_Accepted_Cm);
            Expect_Int ("gate_reference", Boolean'Pos (Alt_State.Baro_Gate.Has_Reference));
            Expect_Int ("gate_rejects", Integer_64 (Alt_State.Baro_Gate.Rejects));
            Expect_Int ("last_z", Integer_64 (Alt_State.Last_Z_Measurement_Us));
            Expect_Int ("valid_z", Boolean'Pos (Alt_State.Valid_Z));
            Expect_Float ("trust_z", Alt_State.Trust_Z);
            Expect_Float ("altitude", Alt_State.Filtered_Altitude_Cm);
            Expect_Float ("derivative", Alt_State.Filtered_Derivative);
            Expect_Float ("control_altitude", Alt_State.Control_Altitude_Cm);
            Expect_Float ("control_derivative", Alt_State.Control_Derivative);
            Expect_Float ("control_acceleration", Alt_State.Control_Acceleration);
            Expect_Int ("estimated", Integer_64 (Estimated_Altitude_Cm (Alt_State)));
            if K /= NF + 1 then
               Put_Line ("altstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown altitude case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Altitude_Line;

   Comp_State    : Adaflight.Compass.State;
   Comp_Settings : Adaflight.Compass.Settings;
   Comp_Saves    : Integer_64 := 0;

   procedure Check_Compass_Line is
      use Adaflight.Compass;
      Name : constant String := Str (1);
      function Beep_Code (B : Beep) return Integer_64 is
        (case B is
            when Silence => -1, when Calibration_Start => 11, when Movement_Start => 13,
            when Calibrated => 1, when Calibration_Failed => 12);
   begin
      if Name = "compinit" then
         Comp_Settings :=
           (Alignment     => Adaflight.Sensor_Alignment.Standard_Alignment'Val (Int (3)),
            Custom_Angles => (Roll  => Adaflight.Sensor_Alignment.Decidegrees (Int (4)),
                              Pitch => Adaflight.Sensor_Alignment.Decidegrees (Int (5)),
                              Yaw   => Adaflight.Sensor_Alignment.Decidegrees (Int (6))),
            Board         => (Roll => Integer (Int (7)), Pitch => Integer (Int (8)), Yaw => Integer (Int (9))),
            Zero          => (Adaflight.Vectors.X => Integer (Int (10)),
                              Adaflight.Vectors.Y => Integer (Int (11)),
                              Adaflight.Vectors.Z => Integer (Int (12))));
         Init (Comp_State, Comp_Settings);
         Comp_Saves := 0;
         Record_Int ("compinit.alignment", Int (13),
                     Adaflight.Sensor_Alignment.Standard_Alignment'Pos (Comp_State.Alignment));
         Record_Int ("compinit.calibrated", Int (14), Boolean'Pos (Comp_State.Calibrated));
         Record_Result ("compinit.lambda", Bits (15), To_Bits (Comp_State.Estimator.Lambda));
         Record_Result ("compinit.d0", Bits (16), To_Bits (Comp_State.Estimator.D (0)));
         Record_Result ("compinit.threshold", Bits (17), To_Bits (Movement_Threshold));
      elsif Name = "compstep" then
         declare
            Sample : constant Raw_Vector :=
              (Adaflight.Vectors.X => Integer (Int (4)),
               Adaflight.Vectors.Y => Integer (Int (5)),
               Adaflight.Vectors.Z => Integer (Int (6)));
            Gyro   : constant Adaflight.Vectors.Vector3 := (X => Flt (7), Y => Flt (8), Z => Flt (9));
            Now    : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (10));
            K      : Positive := 12;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("compstep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("compstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
         begin
            if Int (11) /= 0 then
               Start_Calibration (Comp_State, Now);
               Record_Int ("compstep.beep_start", Int (22), Beep_Code (Comp_State.Beeper));
            end if;
            Update (Comp_State, Comp_Settings, Sample, Gyro, Now);
            if Comp_State.Save_Requested then
               Comp_Saves := Comp_Saves + 1;
            end if;
            for A in Adaflight.Vectors.Coordinate loop
               Expect_Float ("field", Comp_State.Field (A));
            end loop;
            Expect_Int ("calibrating", Boolean'Pos (Comp_State.Calibrating));
            Expect_Int ("moved", Boolean'Pos (Comp_State.Movement_Started));
            Expect_Int ("end_us", Integer_64 (Comp_State.Calibration_End_Us));
            Expect_Int ("calibrated", Boolean'Pos (Comp_State.Calibrated));
            for A in Adaflight.Vectors.Coordinate loop
               Expect_Int ("zero", Integer_64 (Comp_State.Zero (A)));
            end loop;
            K := K + 1;
            Expect_Int ("beep", Beep_Code (Comp_State.Beeper));
            Expect_Int ("saves", Comp_Saves);
            Expect_Float ("lambda", Comp_State.Estimator.Lambda);
            for A in Adaflight.Vectors.Coordinate loop
               Expect_Float ("bias", Comp_State.Estimator.B (A));
            end loop;
            for P in Parameter_Index loop
               Expect_Float ("theta", Comp_State.Estimator.Theta (P));
            end loop;
            if K /= NF + 1 then
               Put_Line ("compstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown compass case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Compass_Line;

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
                                   Throttle_Correction_Value => Integer (Int (7)),
                                   Mag_Declination           => Integer (Int (8))));
         Init (IMU_State);
      elsif Name = "imustep" then
         declare
            K : Positive := 18;
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
            Mag  : constant Adaflight.Vectors.Vector3 := (X => Flt (14), Y => Flt (15), Z => Flt (16));
         begin
            Update (IMU_State, IMU_Config,
                    Now           => Interfaces.Unsigned_32 (Int (4)),
                    Gyro          => Gyro,
                    Acc           => Acc,
                    Acc_Magnitude => Flt (13),
                    Mag           => Mag,
                    Use_Mag       => Int (17) /= 0,
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

   Modes_State      : Adaflight.Modes.State;
   Modes_Conditions : Adaflight.Modes.Conditions;

   procedure Check_Modes_Line is
      use Adaflight.Modes;
      Name : constant String := Str (1);
      function Word (M : Mask; W : Natural) return Integer_64 is
         V : Integer_64 := 0;
      begin
         for B in Box loop
            if M (B) and then Box'Pos (B) / 32 = W then
               V := V + 2 ** (Box'Pos (B) mod 32);
            end if;
         end loop;
         return V;
      end Word;
   begin
      if Name = "modesinit" then
         for M in Condition_Index loop
            declare
               F : constant Positive := 4 + 6 * M;
            begin
               Modes_Conditions (M) :=
                 (Mode      => Box'Val (Int (F)),
                  Aux       => Integer (Int (F + 1)),
                  Span      => (Start_Step => Integer (Int (F + 2)), End_Step => Integer (Int (F + 3))),
                  Combine   => Logic'Val (Int (F + 4)),
                  Linked_To => Box'Val (Int (F + 5)));
            end;
         end loop;
         Modes_State := (others => <>);
         Analyze (Modes_State, Modes_Conditions);
         Record_Int ("modesinit.active_count", Int (124), Integer_64 (Modes_State.Active_Count));
         Record_Int ("modesinit.linked_count", Int (125), Integer_64 (Modes_State.Linked_Count));
      elsif Name = "modesstep" then
         declare
            Aux : Aux_Values;
         begin
            for Ch in Aux_Channel loop
               Aux (Ch) := Flt (6 + Ch);
            end loop;
            Update (Modes_State, Modes_Conditions, Aux, Interfaces.Unsigned_32 (Int (4)), Int (5) /= 0);
            Record_Int ("modesstep.mask0", Int_Hex (20), Word (Modes_State.Active_Mask, 0));
            Record_Int ("modesstep.mask1", Int_Hex (21), Word (Modes_State.Active_Mask, 1));
            Record_Int ("modesstep.airmode", Int (22), Boolean'Pos (Modes_State.Airmode_Enabled));
            Record_Int ("modesstep.sticky0", Int_Hex (23), Word (Modes_State.Sticky_Ever_Disabled, 0));
            Record_Int ("modesstep.sticky1", Int_Hex (24), Word (Modes_State.Sticky_Ever_Disabled, 1));
            if NF /= 24 then
               Put_Line ("modesstep: expected 24 fields, found" & Integer'Image (NF));
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown modes case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Modes_Line;

   Acc_State    : Adaflight.Accelerometer.State;
   Acc_Settings : Adaflight.Accelerometer.Settings;

   procedure Check_Acc_Line is
      use Adaflight.Accelerometer;
      Name : constant String := Str (1);
   begin
      if Name = "accinit" then
         Acc_Settings :=
           (Sample_Rate_Hz => Integer (Int (3)),
            Lowpass_Hz     => Integer (Int (4)),
            Alignment      => Adaflight.Sensor_Alignment.Standard_Alignment'Val (Int (5)),
            Custom_Angles  => (Roll  => Adaflight.Sensor_Alignment.Decidegrees (Int (6)),
                               Pitch => Adaflight.Sensor_Alignment.Decidegrees (Int (7)),
                               Yaw   => Adaflight.Sensor_Alignment.Decidegrees (Int (8))),
            Board          => (Roll => Integer (Int (9)), Pitch => Integer (Int (10)), Yaw => Integer (Int (11))),
            One_G          => Integer (Int (12)),
            Roll_Trim      => Interfaces.Integer_16 (Int (15)),
            Pitch_Trim     => Interfaces.Integer_16 (Int (16)));
         Init (Acc_State, Acc_Settings);
         Record_Result ("accinit.one_g_rec", Bits (13), To_Bits (Acc_State.One_G_Reciprocal));
         if Acc_Settings.Lowpass_Hz /= 0 then
            Record_Result ("accinit.k", Bits (14), To_Bits (Acc_State.Filter (Adaflight.Vectors.X).K));
         end if;
         Start_Calibration (Acc_State);
      elsif Name = "accstep" then
         declare
            Sample : constant Raw_Vector :=
              (Adaflight.Vectors.X => Integer (Int (4)),
               Adaflight.Vectors.Y => Integer (Int (5)),
               Adaflight.Vectors.Z => Integer (Int (6)));
            K : Positive := 8;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("accstep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("accstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
         begin
            Update (Acc_State, Acc_Settings, Sample);
            Expect_Float ("acc", Acc_State.Acc.X);
            Expect_Float ("acc", Acc_State.Acc.Y);
            Expect_Float ("acc", Acc_State.Acc.Z);
            Expect_Float ("jerk", Acc_State.Jerk.X);
            Expect_Float ("jerk", Acc_State.Jerk.Y);
            Expect_Float ("jerk", Acc_State.Jerk.Z);
            Expect_Float ("magnitude", Acc_State.Magnitude);
            Expect_Float ("jerk_magnitude", Acc_State.Jerk_Magnitude);
            for A in Adaflight.Vectors.Coordinate loop
               Expect_Int ("zero", Integer_64 (Acc_State.Zero (A)));
            end loop;
            Expect_Int ("complete", Boolean'Pos (Calibration_Complete (Acc_State)));
            Expect_Int ("roll_trim", Integer_64 (Acc_State.Roll_Trim));
            Expect_Int ("pitch_trim", Integer_64 (Acc_State.Pitch_Trim));
            if K /= NF + 1 then
               Put_Line ("accstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown acc case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Acc_Line;

   Baro_State    : Adaflight.Barometer.State;
   Baro_Settings : Adaflight.Barometer.Settings;

   procedure Check_Baro_Line is
      use Adaflight.Barometer;
      Name : constant String := Str (1);
   begin
      if Name = "baroinit" then
         Baro_Settings := (Temperature_Drift_Cm_Per_10C => Integer (Int (4)), Virtual_Device => Int (3) /= 0);
         Init (Baro_State);
         Start_Calibration (Baro_State, Baro_Settings);
      elsif Name = "barostep" then
         declare
            K : Positive := 8;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("barostep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("barostep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
         begin
            if Int (7) /= 0 then
               Set_Ground_Level (Baro_State);
            end if;
            Sample (Baro_State, Baro_Settings,
                    Pressure    => Interfaces.Integer_32 (Int (5)),
                    Temperature => Interfaces.Integer_32 (Int (6)),
                    Now_Us      => Interfaces.Unsigned_32 (Int (4)));
            --  The power's last-bit rounding, amplified by the subtraction
            --  from one near sea level: at most 2.2 cm (DESIGN.md D6).
            Record_Result ("barostep.altitude", Bits (K), To_Bits (Baro_State.Altitude), Absolute => 3.0);
            K := K + 1;
            Expect_Int ("pressure", Integer_64 (Baro_State.Pressure));
            Expect_Int ("temperature", Integer_64 (Baro_State.Temperature));
            Expect_Int ("last_time", Integer_64 (Baro_State.Last_Data_Time_Us));
            Expect_Int ("interval", Integer_64 (Baro_State.Data_Interval_Us));
            Expect_Int ("calibrated", Boolean'Pos (Baro_State.Calibrated));
            Expect_Float ("ground", Baro_State.Ground_Altitude);
            Expect_Int ("temp_at_cal", Integer_64 (Baro_State.Temperature_At_Calibration));
            Expect_Int ("count", Integer_64 (Baro_State.Count));
            Expect_Int ("cycles", Integer_64 (Baro_State.Cycles));
            if K /= NF + 1 then
               Put_Line ("barostep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown baro case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Baro_Line;

   Battery_State_V  : Adaflight.Battery.State;
   Battery_Settings : Adaflight.Battery.Settings;

   procedure Check_Battery_Line is
      use Adaflight.Battery;
      Name : constant String := Str (1);
   begin
      if Name = "batinit" then
         Battery_Settings :=
           (Voltage_Meter                  => Voltage_Source'Val (Int (3)),
            Current_Meter                  => Current_Source'Val (Int (4)),
            Not_Present_Cell_Voltage       => Integer (Int (5)),
            LVC_Percentage                 => Integer (Int (6)),
            Voltage_Alerts                 => Int (7) /= 0,
            Consumption_Alerts             => Int (8) /= 0,
            Hysteresis                     => Integer (Int (9)),
            Display_Filter_Period          => Integer (Int (10)),
            Current_Filter_Period          => Integer (Int (11)),
            Duration_For_Warning           => Integer (Int (12)),
            Duration_For_Critical          => Integer (Int (13)),
            Max_Cell_Voltage               => Integer (Int (14)),
            Min_Cell_Voltage               => Integer (Int (15)),
            Warning_Cell_Voltage           => Integer (Int (16)),
            Full_Cell_Voltage              => Integer (Int (17)),
            Capacity_mAh                   => Integer (Int (18)),
            Force_Cell_Count               => Integer (Int (19)),
            Consumption_Warning_Percentage => Integer (Int (20)),
            Voltage_Scale                  => Integer (Int (21)),
            Voltage_Divider                => Integer (Int (22)),
            Voltage_Multiplier             => Integer (Int (23)),
            Current_Scale                  => Integer (Int (24)),
            Current_Offset                 => Integer (Int (25)));
         Init (Battery_State_V, Battery_Settings);
      elsif Name = "batstep" then
         declare
            Now_Us : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (4));
            Now_Ms : constant Interfaces.Unsigned_32 := Now_Us / 1_000;
            K      : Positive := 10;
            A      : Alert := Silence;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("batstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
         begin
            Update_Voltage (Battery_State_V, Battery_Settings, Integer (Int (5)), Now_Ms);
            Update_Current (Battery_State_V, Battery_Settings, Integer (Int (6)), Now_Us);
            if Int (8) /= 0 then
               if Int (9) /= 0 then
                  Update_Presence (Battery_State_V, Battery_Settings);
               end if;
               Update_States (Battery_State_V, Battery_Settings, Now_Us, Now_Ms);
               A := Alarm (Battery_State_V, Battery_Settings);
            end if;
            Expect_Int ("display", Integer_64 (Battery_State_V.Voltage.Display_Filtered));
            Expect_Int ("unfiltered", Integer_64 (Battery_State_V.Voltage.Unfiltered));
            Expect_Int ("stable_bits", Integer_64 (Battery_State_V.Voltage.Stable_Bits));
            Expect_Int ("stable_prev", Integer_64 (Battery_State_V.Voltage.Stable_Prev_Filtered));
            Expect_Int ("amperage", Integer_64 (Battery_State_V.Current.Amperage));
            Expect_Int ("amperage_latest", Integer_64 (Battery_State_V.Current.Amperage_Latest));
            Expect_Int ("mah", Integer_64 (Battery_State_V.Current.mAh_Drawn));
            Expect_Int ("cells", Integer_64 (Battery_State_V.Cells));
            Expect_Int ("voltage_state", Battery_State'Pos (Battery_State_V.Voltage_State));
            Expect_Int ("consumption_state", Battery_State'Pos (Battery_State_V.Consumption_State));
            Expect_Int ("state", Battery_State'Pos (Battery_State_V.Overall));
            Expect_Int ("warning_v", Integer_64 (Battery_State_V.Warning_Voltage));
            Expect_Int ("critical_v", Integer_64 (Battery_State_V.Critical_Voltage));
            Expect_Int ("warning_hyst", Integer_64 (Battery_State_V.Warning_Hysteresis));
            Expect_Int ("critical_hyst", Integer_64 (Battery_State_V.Critical_Hysteresis));
            Expect_Int ("lvc_enabled", Boolean'Pos (Battery_State_V.LVC_Enabled));
            Expect_Int ("lvc_percent", Integer_64 (Battery_State_V.LVC_Percentage));
            Record_Result ("batstep.watt_hours", Bits (K), To_Bits (Battery_State_V.Watt_Hours));
            K := K + 1;
            Expect_Int ("percent", Integer_64 (Percentage_Remaining (Battery_State_V, Battery_Settings)));
            Expect_Int ("beeper", (case A is when Silence => -1, when Low => 8, when Critical_Low => 7));
            if K /= NF + 1 then
               Put_Line ("batstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown battery case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Battery_Line;

   Arming_State      : Adaflight.Arming.State;
   Arming_Settings   : Adaflight.Arming.Settings;
   Arming_Modes      : Adaflight.Modes.State;
   Arming_Conditions : Adaflight.Modes.Conditions;

   procedure Check_Arming_Line is
      use Adaflight.Arming;
      Name : constant String := Str (1);
      function Reasons (D : Disable_Set) return Integer_64 is
         V : Integer_64 := 0;
      begin
         for R in Disable_Reason loop
            if D (R) then
               V := V + 2 ** Disable_Reason'Pos (R);
            end if;
         end loop;
         return V;
      end Reasons;
      function Mode_Bits (M : Mode_Set) return Integer_64 is
         V : Integer_64 := 0;
      begin
         for F in Flight_Mode loop
            if M (F) then
               V := V + (case F is
                           when Angle_Mode => 2 ** 0, when Horizon_Mode => 2 ** 1, when Mag_Mode => 2 ** 2,
                           when Alt_Hold_Mode => 2 ** 3, when Pos_Hold_Mode => 2 ** 5, when Headfree_Mode => 2 ** 6,
                           when Chirp_Mode => 2 ** 7, when Passthru_Mode => 2 ** 8, when Failsafe_Mode => 2 ** 10,
                           when GPS_Rescue_Mode => 2 ** 11, when Autopilot_Mode => 2 ** 12,
                           when Launch_Mode => 2 ** 13);
            end if;
         end loop;
         return V;
      end Mode_Bits;
      function Box_Word (M : Adaflight.Modes.Mask; W : Natural) return Integer_64 is
         V : Integer_64 := 0;
      begin
         for B in Adaflight.Modes.Box loop
            if M (B) and then Adaflight.Modes.Box'Pos (B) / 32 = W then
               V := V + 2 ** (Adaflight.Modes.Box'Pos (B) mod 32);
            end if;
         end loop;
         return V;
      end Box_Word;
      function Beep_Code (B : Beep) return Integer_64 is
        (case B is
            when Silence => 100, when Arm_Tone => 5, when Disarm_Tone => 4, when Armed_Tone => 16,
            when Disarm_Repeat_Tone => 15, when Rx_Set_Tone => 10, when Warning_Tones => 101,
            when Confirmation_Tones => 102);
      function Selected (Cmds : Command_Set; First, Last : Stick_Command) return Integer_64 is
      begin
         for Cmd in First .. Last loop
            if Cmds (Cmd) then
               return Integer_64 (Stick_Command'Pos (Cmd) - Stick_Command'Pos (First));
            end if;
         end loop;
         return -1;
      end Selected;
   begin
      if Name = "arminit" then
         Arming_Settings :=
           (Gyro_Cal_On_First_Arm      => Int (3) /= 0,
            Auto_Disarm_Delay          => Integer (Int (4)),
            Prearm_Allow_Rearm         => Int (5) /= 0,
            Boot_Grace_Time            => Integer (Int (6)),
            Stick_Arming               => Int (7) /= 0,
            Mid_RC                     => Integer (Int (8)),
            Min_Check                  => Integer (Int (9)),
            Max_Check                  => Integer (Int (10)),
            Airmode_Threshold          => Integer (Int (11)),
            Three_D                    => Int (12) /= 0,
            Switched_Mode_3D           => Int (13) /= 0,
            Deadband_3D_Throttle       => Integer (Int (14)),
            Motor_Stop                 => Int (15) /= 0,
            Airmode_Feature            => Int (16) /= 0,
            Anti_Gravity_Feature       => Int (17) /= 0,
            Fixed_Wing                 => Int (18) /= 0,
            PID_At_Min_Throttle        => Int (19) /= 0,
            Launch_Control_Angle_Limit => Integer (Int (20)),
            Launch_Trigger_Throttle    => Integer (Int (146)),
            Launch_Trigger_Reset       => Int (147) /= 0,
            Runaway_Prevention         => Int (149) /= 0,
            Runaway_Deactivate_Delay   => Integer (Int (150)),
            Runaway_Deactivate_Throttle => Integer (Int (151)),
            Sensors                    =>
              (Gyro => Int (21) /= 0, Acc => Int (22) /= 0, Baro => Int (23) /= 0, Mag => Int (24) /= 0));
         for M in Adaflight.Modes.Condition_Index loop
            declare
               F : constant Positive := 25 + 6 * M;
            begin
               Arming_Conditions (M) :=
                 (Mode      => Adaflight.Modes.Box'Val (Int (F)),
                  Aux       => Integer (Int (F + 1)),
                  Span      => (Start_Step => Integer (Int (F + 2)), End_Step => Integer (Int (F + 3))),
                  Combine   => Adaflight.Modes.Logic'Val (Int (F + 4)),
                  Linked_To => Adaflight.Modes.Box'Val (Int (F + 5)));
            end;
         end loop;
         Arming_Modes := (others => <>);
         Adaflight.Modes.Analyze (Arming_Modes, Arming_Conditions);
         Init (Arming_State, Arming_Settings, Arming_Conditions);
         Record_Int ("arminit.sticks_arm", Int (145), Boolean'Pos (Arming_State.Sticks_Arm));
      elsif Name = "armstep" then
         declare
            Now_Us   : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (4));
            Channels : Adaflight.RC_Command.Channel_Values;
            Aux      : Adaflight.Modes.Aux_Values := (others => 1_500.0);
            Sensed   : constant Inputs :=
              (Rx_Signal                  => Int (16) /= 0,
               Failsafe_Receiving         => Int (17) /= 0,
               Failsafe_Active            => Int (18) /= 0,
               Failsafe_Monitoring        => Int (19) /= 0,
               Upright                    => Int (20) /= 0,
               Gyro_Calibrated            => Int (21) /= 0,
               Acc_Calibrated             => Int (22) /= 0,
               Baro_Calibrated            => Int (23) /= 0,
               Mag_Calibrated             => Int (24) /= 0,
               Acc_Has_Calibration        => Int (25) /= 0,
               First_Arm_Gyro_Cal_Running => Int (26) /= 0,
               Motor_Protocol_Enabled     => Int (27) /= 0,
               Headfree_Offset_Set        => Int (28) /= 0,
               PID_Sums                   => (Adaflight.Axes.Roll => Flt (60), Adaflight.Axes.Pitch => Flt (61),
                                              Adaflight.Axes.Yaw => Flt (62)),
               Gyro_Abs_Dps               => (Adaflight.Axes.Roll  => Integer (Int (63)),
                                              Adaflight.Axes.Pitch => Integer (Int (64)),
                                              Adaflight.Axes.Yaw   => Integer (Int (65))),
               Deflection_Abs             => (Adaflight.Axes.Roll => Flt (66), Adaflight.Axes.Pitch => Flt (67),
                                              Adaflight.Axes.Yaw => Flt (68)));
            Step     : Outputs;
            K        : Positive := 29;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("armstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            procedure Expect_Hex (N : String; Actual : Integer_64) is
            begin
               Record_Int ("armstep." & N, Int_Hex (K), Actual);
               K := K + 1;
            end Expect_Hex;
            Flags : Integer_64;
         begin
            for Ch in Adaflight.RC_Command.Channel loop
               Channels (Ch) := Flt (6 + Ch);
            end loop;
            for Ch in 0 .. 5 loop
               Aux (Ch) := Flt (10 + Ch);
            end loop;
            Process_Rx (Arming_State, Arming_Settings, Arming_Modes, Sensed, Channels, Now_Us, Step);
            Process_Rx_Modes (Arming_State, Arming_Settings, Arming_Modes, Arming_Conditions, Aux, Sensed, Channels,
                              Now_Us, Natural (Int (5)), Step);
            Process_PID_Loop (Arming_State, Arming_Settings, Arming_Modes, Sensed, Channels, Now_Us, Step);
            Update_Status (Arming_State, Arming_Settings, Arming_Modes, Arming_Conditions, Sensed, Channels, Now_Us);
            Flags := Boolean'Pos (Arming_State.Armed) + 2 * Boolean'Pos (Arming_State.Was_Ever_Armed)
                     + 4 * Boolean'Pos (Arming_State.Armed_With_Prearm);
            Expect_Int ("flags", Flags);
            Expect_Hex ("disabled", Reasons (Arming_State.Disabled));
            Expect_Int ("flight_modes", Mode_Bits (Arming_State.Flight_Modes));
            Expect_Int ("last_disarm_us", Integer_64 (Arming_State.Last_Disarm_Us));
            Expect_Int ("disarm_calls", Integer_64 (Step.Disarm_Calls));
            Expect_Int ("disarm_reason", Disarm_Reason'Pos (Arming_State.Last_Disarm_Reason));
            Expect_Int ("beep_calls", Integer_64 (Step.Beeper.Calls));
            if Step.Beeper.Calls > 0 then
               Expect_Int ("beep_last", Beep_Code (Step.Beeper.Last));
            else
               K := K + 1;
            end if;
            Expect_Int ("beep_count", Integer_64 (Step.Beeper.Count));
            Expect_Int ("first_arm_gyro_cal", Integer_64 (Step.First_Arm_Gyro_Cal));
            Expect_Int ("gyro_cal", Boolean'Pos (Step.Commands (Gyro_Calibration)));
            Expect_Int ("baro_ground", Boolean'Pos (Step.Commands (Baro_Ground_Level)));
            Expect_Int ("acc_cal", Boolean'Pos (Step.Commands (Acc_Calibration)));
            Expect_Int ("mag_cal", Boolean'Pos (Step.Commands (Mag_Calibration)));
            Expect_Int ("pid_profile", Selected (Step.Commands, PID_Profile_1, PID_Profile_3));
            Expect_Int ("rate_profile", Selected (Step.Commands, Rate_Profile_1, Rate_Profile_4));
            Expect_Int ("dashboard", Selected (Step.Commands, Dashboard_Cycling_Off, Dashboard_Cycling_On));
            Expect_Int ("saves", Integer_64 (Step.Saves));
            Expect_Int ("trim_roll", Integer_64 (Step.Trim_Roll));
            Expect_Int ("trim_pitch", Integer_64 (Step.Trim_Pitch));
            Expect_Int ("headfree_offsets", Integer_64 (Step.Headfree_Offsets));
            Expect_Int ("failsafe_monitoring", Boolean'Pos (Step.Start_Failsafe_Monitoring));
            Expect_Int ("stabilisation", Boolean'Pos (Step.Stabilisation_On));
            Expect_Int ("iterm_reset", Boolean'Pos (Step.Iterm_Reset));
            Expect_Int ("anti_gravity", Boolean'Pos (Step.Anti_Gravity));
            Expect_Int ("last_reason", Integer_64 (Arming_State.Last_Disabled_Reason));
            Expect_Int ("disarm_at", Integer_64 (Arming_State.Disarm_At));
            Expect_Int ("throttle_raised", Boolean'Pos (Arming_State.Throttle_Raised));
            Expect_Int ("disarm_requested", Boolean'Pos (Arming_State.Disarm_Requested));
            Expect_Hex ("mask0", Box_Word (Arming_Modes.Active_Mask, 0));
            Expect_Hex ("mask1", Box_Word (Arming_Modes.Active_Mask, 1));
            K := K + 9;
            Expect_Int ("launch_state", Launch_State'Pos (Arming_State.Launch));
            Expect_Int ("runaway_check_disabled", Boolean'Pos (Arming_State.Runaway_Check_Disabled));
            Expect_Int ("runaway_deactivate_us", Integer_64 (Arming_State.Runaway_Deactivate_Us));
            Expect_Int ("runaway_accumulated_us", Integer_64 (Arming_State.Runaway_Accumulated_Us));
            Expect_Int ("runaway_trigger_us", Integer_64 (Arming_State.Runaway_Trigger_Us));
            Expect_Int ("iterm_resets", Integer_64 (Step.Iterm_Resets));
            Expect_Int ("launch_active", Boolean'Pos (Launch_Control_Active (Arming_State)));
            if K /= NF + 1 then
               Put_Line ("armstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown arming case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Arming_Line;

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

   CRSF_State    : Adaflight.CRSF.State;
   CRSF_Rx       : Adaflight.Receiver.State;
   CRSF_Settings : Adaflight.Receiver.Settings;
   CRSF_Clock    : Unsigned_32 := 0;

   procedure Check_CRSF_Line is
      use Adaflight.CRSF;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "crsfinit" then
         CRSF_Settings := (others => <>);
         CRSF_Settings.Mid_RC := Integer (Int (3));
         CRSF_Clock := Unsigned_32 (Int (4));
         Adaflight.Receiver.Init (CRSF_Rx, CRSF_Settings, CRSF_Clock / 1_000,
                                  Adaflight.Receiver.RSSI_Source'Val (Int (5)),
                                  Adaflight.Receiver.Link_Quality_Source'Val (Int (6)));
         Init (CRSF_State, Integer (Int (3)));
         K := 7;
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (CRSF_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "crsfbaud" then
         Update_Baudrate (CRSF_State, Unsigned_32 (Int (4)));
         K := 5;
         Expect_Next ("frame_time", Integer_64 (CRSF_State.Frame_Time_Us));
         Expect_Next ("event_telemetry", Boolean'Pos (CRSF_State.Event_Telemetry));
         Check_Fields;
      elsif Name = "crsfstep" then
         declare
            Negotiating : constant Boolean := Int (4) /= 0;
            Eeprom      : constant Boolean := Int (5) /= 0;
            Count       : constant Natural := Integer (Int (6));
            Result      : Byte_Outputs;
            Defaults, Commands, Responses : Natural := 0;
            Status      : Adaflight.Receiver.Frame_Report;
            Polled      : Boolean;
         begin
            K := 7;
            for B in 1 .. Count loop
               CRSF_Clock := CRSF_Clock + Unsigned_32 (Int (K));
               Receive_Byte (CRSF_State, CRSF_Rx, Integer (Int (K + 1)), CRSF_Clock, Negotiating, Eeprom, Result);
               if Result.Default_Speed then
                  Defaults := Defaults + 1;
               end if;
               if Result.Command then
                  Commands := Commands + 1;
               end if;
               if Result.Telemetry_Response then
                  Responses := Responses + 1;
               end if;
               K := K + 2;
            end loop;
            Polled := Int (K) /= 0;
            K := K + 1;
            CRSF_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Polled then
               Frame_Status (CRSF_State, CRSF_Rx, CRSF_Clock, Status);
               Expect_Next ("status", (if Status.Complete then 1 else 0) + (if Status.Dropped then 8 else 0));
            else
               K := K + 1;
            end if;
            Expect_Next ("done", Boolean'Pos (CRSF_State.Done));
            Expect_Next ("start_at", Integer_64 (CRSF_State.Start_At_Us));
            Expect_Next ("last_stats", Integer_64 (CRSF_State.Last_Stats_Us));
            Record_Result (Name & ".scale", Bits (K), To_Bits (CRSF_State.Scale));
            K := K + 1;
            Expect_Next ("frame_time", Integer_64 (CRSF_State.Last_Frame_Us));
            Expect_Next ("default_speed", Integer_64 (Defaults));
            Expect_Next ("commands", Integer_64 (Commands));
            Expect_Next ("responses", Integer_64 (Responses));
            Expect_Next ("rssi", Integer_64 (CRSF_Rx.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (CRSF_Rx.RSSI_Raw));
            Expect_Next ("rssi_dbm", Integer_64 (CRSF_Rx.RSSI_Dbm));
            Expect_Next ("rssi_dbm_raw", Integer_64 (CRSF_Rx.RSSI_Dbm_Raw));
            Expect_Next ("rsnr", Integer_64 (CRSF_Rx.RSNR));
            Expect_Next ("rsnr_raw", Integer_64 (CRSF_Rx.RSNR_Raw));
            Expect_Next ("link_quality", Integer_64 (CRSF_Rx.Link_Quality));
            Expect_Next ("rf_mode", Integer_64 (CRSF_Rx.RF_Mode));
            Expect_Next ("uplink_power", Integer_64 (CRSF_Rx.Uplink_Power_mW));
            Expect_Next ("antenna", Integer_64 (CRSF_Rx.Active_Antenna));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (CRSF_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (CRSF_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown crsf case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_CRSF_Line;

   SUMD_State : Adaflight.SUMD.State;
   SUMH_State : Adaflight.SUMH.State;
   SUM_Clock  : Unsigned_32 := 0;

   procedure Check_SUM_Line is
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
      function Code (Status : Adaflight.Receiver.Frame_Report) return Integer_64 is
        ((if Status.Complete then 1 else 0) + (if Status.Failsafe then 2 else 0) + (if Status.Dropped then 8 else 0));
   begin
      if Name = "sumdinit" then
         Adaflight.SUMD.Init (SUMD_State);
         SUM_Clock := Unsigned_32 (Int (3));
      elsif Name = "sumhinit" then
         Adaflight.SUMH.Init (SUMH_State);
         SUM_Clock := Unsigned_32 (Int (3));
      elsif Name = "sumdburst" or else Name = "sumhburst" then
         declare
            Count  : constant Natural := Integer (Int (4));
            SUMH   : constant Boolean := Name = "sumhburst";
            Status : Adaflight.Receiver.Frame_Report;
            Polled : Boolean;
         begin
            K := 5;
            for B in 1 .. Count loop
               SUM_Clock := SUM_Clock + Unsigned_32 (Int (K));
               if SUMH then
                  Adaflight.SUMH.Receive_Byte (SUMH_State, Integer (Int (K + 1)), SUM_Clock);
               else
                  Adaflight.SUMD.Receive_Byte (SUMD_State, Integer (Int (K + 1)), SUM_Clock);
               end if;
               K := K + 2;
            end loop;
            Polled := Int (K) /= 0;
            K := K + 1;
            SUM_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Polled then
               if SUMH then
                  Adaflight.SUMH.Frame_Status (SUMH_State, Status);
               else
                  Adaflight.SUMD.Frame_Status (SUMD_State, Status);
               end if;
               Expect_Next ("status", Code (Status));
            else
               K := K + 1;
            end if;
            if SUMH then
               Expect_Next ("done", Boolean'Pos (SUMH_State.Done));
               for Ch in 0 .. Adaflight.SUMH.Channel_Count loop
                  Expect_Next ("data",
                               (if Ch < Adaflight.SUMH.Channel_Count then Integer_64 (SUMH_State.Data (Ch)) else 0));
                  Record_Result (Name & ".raw", Bits (K), To_Bits (Adaflight.SUMH.Read_Raw (SUMH_State, Ch)));
                  K := K + 1;
               end loop;
            else
               Expect_Next ("done", Boolean'Pos (SUMD_State.Done));
               Expect_Next ("count", Integer_64 (SUMD_State.Channel_Count));
               Expect_Next ("crc", Integer_64 (SUMD_State.CRC));
               Expect_Next ("frame_time", Integer_64 (SUMD_State.Last_Frame_Us));
               for Ch in Adaflight.SUMD.Channel loop
                  Expect_Next ("data", Integer_64 (SUMD_State.Data (Ch)));
                  Record_Result (Name & ".raw", Bits (K), To_Bits (Adaflight.SUMD.Read_Raw (SUMD_State, Ch)));
                  K := K + 1;
               end loop;
            end if;
            Check_Fields;
         end;
      else
         Put_Line ("unknown sum case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SUM_Line;

   IBUS_State : Adaflight.IBUS.State;
   IBUS_Clock : Unsigned_32 := 0;

   procedure Check_IBUS_Line is
      use Adaflight.IBUS;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "ibusinit" then
         Init (IBUS_State);
         IBUS_Clock := Unsigned_32 (Int (3));
         K := 4;
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (IBUS_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "ibusburst" then
         declare
            Count   : constant Natural := Integer (Int (4));
            Status  : Adaflight.Receiver.Frame_Report;
            Request : Boolean := False;
         begin
            K := 5;
            for B in 1 .. Count loop
               IBUS_Clock := IBUS_Clock + Unsigned_32 (Int (K));
               Receive_Byte (IBUS_State, Integer (Int (K + 1)), IBUS_Clock);
               K := K + 2;
            end loop;
            IBUS_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Int (K + 1) /= 0 then
               Frame_Status (IBUS_State, Status, Request);
               Expect_Next ("status", Boolean'Pos (Status.Complete));
               K := K + 1;
               Expect_Next ("request", Boolean'Pos (Request));
               if Request then
                  Ignore_Echo (IBUS_State, Integer (Int (K)));
               end if;
               K := K + 1;
            else
               K := K + 4;
            end if;
            Expect_Next ("model", Model'Pos (IBUS_State.Kind));
            Expect_Next ("sync", Integer_64 (IBUS_State.Sync_Byte));
            Expect_Next ("frame_size", Integer_64 (IBUS_State.Frame_Size));
            Expect_Next ("offset", Integer_64 (IBUS_State.Channel_Offset));
            Expect_Next ("ignore", Integer_64 (IBUS_State.Bytes_To_Ignore));
            Expect_Next ("checksum", Integer_64 (IBUS_State.Checksum));
            Expect_Next ("done", Boolean'Pos (IBUS_State.Done));
            Expect_Next ("completed_at", Integer_64 (IBUS_State.Completed_At_Us));
            Expect_Next ("frame_time", Integer_64 (IBUS_State.Last_Frame_Time_Us));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (IBUS_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (IBUS_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown ibus case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_IBUS_Line;

   Spek_State : Adaflight.Spektrum.State;
   Spek_Clock : Unsigned_32 := 0;

   procedure Check_Spek_Line is
      use Adaflight.Spektrum;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "spekinit" then
         Init (Spek_State,
               (Kind         => (case Int (3) is
                                   when 15 => Spektrum_1024, when 10 => SRXL, when others => Spektrum_2048),
                Telemetry    => Int (4) /= 0,
                RSSI_Channel => Integer (Int (5))));
         Spek_Clock := Unsigned_32 (Int (6));
         K := 7;
         Expect_Next ("srxl", Boolean'Pos (Spek_State.SRXL_Enabled));
         Expect_Next ("resolution", Integer_64 (Spek_State.Resolution));
         Expect_Next ("count", Integer_64 (Spek_State.Channel_Count));
         Expect_Next ("rssi_channel", Integer_64 (Spek_State.RSSI_Channel));
         Expect_Next ("shift", Integer_64 (Spek_State.Shift));
         Expect_Next ("mask", Integer_64 (Spek_State.Mask));
         Expect_Next ("hires", Boolean'Pos (Spek_State.Hi_Res));
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (Spek_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "spekburst" then
         declare
            Count   : constant Natural := Integer (Int (4));
            Status  : Adaflight.Receiver.Frame_Report;
            VTX     : VTX_Request;
            Written : Boolean := False;
         begin
            K := 5;
            for B in 1 .. Count loop
               Spek_Clock := Spek_Clock + Unsigned_32 (Int (K));
               Receive_Byte (Spek_State, Integer (Int (K + 1)), Spek_Clock);
               K := K + 2;
            end loop;
            if Int (K) >= 0 then
               Queue_Telemetry (Spek_State, Integer (Int (K)));
            end if;
            Spek_Clock := Unsigned_32 (Int (K + 1));
            K := K + 2;
            if Int (K + 1) /= 0 then
               Frame_Status (Spek_State, Spek_Clock, Status, VTX);
               Expect_Next ("status",
                            (if Status.Complete then 1 else 0) + (if Status.Processing_Required then 4 else 0));
               if Status.Processing_Required then
                  Process_Frame (Spek_State, Written);
               end if;
            else
               K := K + 1;
            end if;
            K := K + 1;
            Expect_Next ("vtx", Boolean'Pos (VTX.Present));
            Expect_Next ("vtx_word", Integer_64 (VTX.Word));
            Expect_Next ("written", Boolean'Pos (Written));
            Expect_Next ("complete", Boolean'Pos (Spek_State.Frame_Complete));
            Expect_Next ("frame_time", Integer_64 (Spek_State.Last_Frame_Time_Us));
            Expect_Next ("internal", Boolean'Pos (Spek_State.Sat_Internal));
            Expect_Next ("fade_sec", Integer_64 (Spek_State.Fade_Last_Sec));
            Expect_Next ("fade_count", Integer_64 (Spek_State.Fade_Last_Sec_Count));
            Expect_Next ("telemetry_len", Integer_64 (Spek_State.Telemetry_Length));
            Expect_Next ("buffer_empty", Boolean'Pos (Telemetry_Buffer_Empty (Spek_State)));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (Spek_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (Spek_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown spektrum case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Spek_Line;

   XBUS_State : Adaflight.XBUS.State;
   XBUS_Clock : Unsigned_32 := 0;

   procedure Check_XBUS_Line is
      use Adaflight.XBUS;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "xbusinit" then
         Init (XBUS_State, (if Int (3) = 6 then Mode_B_RJ01 else Mode_B));
         XBUS_Clock := Unsigned_32 (Int (4));
         K := 5;
         Expect_Next ("count", Channel_Count);
         Expect_Next ("length", Integer_64 (XBUS_State.Length));
         Expect_Next ("channels", Channel_Count);
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (XBUS_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "xbusburst" then
         declare
            Count  : constant Natural := Integer (Int (4));
            Status : Adaflight.Receiver.Frame_Report;
         begin
            K := 5;
            for B in 1 .. Count loop
               XBUS_Clock := XBUS_Clock + Unsigned_32 (Int (K));
               Receive_Byte (XBUS_State, Integer (Int (K + 1)), XBUS_Clock);
               K := K + 2;
            end loop;
            XBUS_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Int (K + 1) /= 0 then
               Frame_Status (XBUS_State, Status);
               Expect_Next ("status", Boolean'Pos (Status.Complete));
            else
               K := K + 1;
            end if;
            K := K + 1;
            Expect_Next ("received", Boolean'Pos (XBUS_State.Frame_Received));
            Expect_Next ("incoming", Boolean'Pos (XBUS_State.Data_Incoming));
            Expect_Next ("position", Integer_64 (XBUS_State.Position));
            Expect_Next ("length", Integer_64 (XBUS_State.Length));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (XBUS_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (XBUS_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown xbus case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_XBUS_Line;

   Jeti_State : Adaflight.Jeti_Ex_Bus.State;
   Jeti_Clock : Unsigned_32 := 0;

   procedure Check_Jeti_Line is
      use Adaflight.Jeti_Ex_Bus;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "jetiinit" then
         Init (Jeti_State);
         Jeti_Clock := Unsigned_32 (Int (3));
         K := 4;
         Expect_Next ("count", Channel_Count);
         Expect_Next ("position", Integer_64 (Jeti_State.Position));
         Expect_Next ("length", Integer_64 (Jeti_State.Length));
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (Jeti_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "jetiburst" then
         declare
            Count  : constant Natural := Integer (Int (4));
            Status : Adaflight.Receiver.Frame_Report;
         begin
            K := 5;
            for B in 1 .. Count loop
               Jeti_Clock := Jeti_Clock + Unsigned_32 (Int (K));
               Receive_Byte (Jeti_State, Integer (Int (K + 1)), Jeti_Clock);
               K := K + 2;
            end loop;
            Jeti_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Int (K + 1) /= 0 then
               Frame_Status (Jeti_State, Status);
               Expect_Next ("status", Boolean'Pos (Status.Complete));
            else
               K := K + 1;
            end if;
            K := K + 1;
            Expect_Next ("frame_state", Frame_State_Kind'Pos (Jeti_State.Frame_State));
            Expect_Next ("request_state", Frame_State_Kind'Pos (Jeti_State.Request_State));
            Expect_Next ("can_tx", Boolean'Pos (Jeti_State.Can_Tx));
            Expect_Next ("position", Integer_64 (Jeti_State.Position));
            Expect_Next ("length", Integer_64 (Jeti_State.Length));
            Expect_Next ("channel_stamp", Integer_64 (Jeti_State.Channel_Stamp_Us));
            Expect_Next ("request_stamp", Integer_64 (Jeti_State.Request_Stamp_Us));
            Expect_Next ("frame_time", Integer_64 (Jeti_State.Last_Frame_Time_Us));
            Expect_Next ("channel_crc", Integer_64 (Frame_CRC16 (Jeti_State.Channel_Frame, Max_Channel_Frame)));
            Expect_Next ("request_crc", Integer_64 (Frame_CRC16 (Jeti_State.Request_Frame, Max_Request_Frame)));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (Jeti_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (Jeti_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown jeti case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Jeti_Line;

   GHST_State    : Adaflight.GHST.State;
   GHST_Rx       : Adaflight.Receiver.State;
   GHST_Settings : Adaflight.Receiver.Settings;
   GHST_Clock    : Unsigned_32 := 0;

   procedure Check_GHST_Line is
      use Adaflight.GHST;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "ghstinit" then
         GHST_Settings := (others => <>);
         GHST_Settings.Mid_RC := Integer (Int (3));
         GHST_Settings.RSSI_Smoothing := Integer (Int (4));
         GHST_Clock := Unsigned_32 (Int (5));
         Adaflight.Receiver.Init (GHST_Rx, GHST_Settings, GHST_Clock / 1_000,
                                  Adaflight.Receiver.RSSI_Source'Val (Int (6)),
                                  Adaflight.Receiver.Link_Quality_Source'Val (Int (7)));
         Init (GHST_State);
         K := 8;
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (GHST_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "ghststep" then
         declare
            Count     : constant Natural := Integer (Int (4));
            Status    : Adaflight.Receiver.Frame_Report;
            Result    : Process_Outputs;
            Processed : Boolean := False;
         begin
            K := 5;
            for B in 1 .. Count loop
               GHST_Clock := GHST_Clock + Unsigned_32 (Int (K));
               Receive_Byte (GHST_State, Integer (Int (K + 1)), GHST_Clock);
               K := K + 2;
            end loop;
            if Int (K) >= 0 then
               Queue_Telemetry (GHST_State, Integer (Int (K)));
            end if;
            GHST_Clock := Unsigned_32 (Int (K + 1));
            K := K + 2;
            if Int (K + 1) /= 0 then
               Frame_Status (GHST_State, GHST_Clock, Status);
               Expect_Next ("status",
                            (if Status.Complete then 1 else 0) + (if Status.Processing_Required then 4 else 0)
                            + (if Status.Dropped then 8 else 0));
               if Status.Processing_Required then
                  Process_Frame (GHST_State, GHST_Rx, GHST_Clock, Result);
                  Processed := True;
               end if;
            else
               K := K + 1;
            end if;
            K := K + 1;
            Expect_Next ("processed", Boolean'Pos (Processed));
            if Int (K) /= 0 then
               Idle (GHST_State);
            end if;
            K := K + 1;
            Expect_Next ("msp", Boolean'Pos (Result.MSP /= None));
            Expect_Next ("msp_type",
                         (case Result.MSP is when None => 0, when Request => MSP_Request, when Write => MSP_Write));
            Expect_Next ("telemetry_sent", Boolean'Pos (Result.Telemetry_Sent));
            Expect_Next ("available", Boolean'Pos (GHST_State.Frame_Available));
            Expect_Next ("validated", Boolean'Pos (GHST_State.Validated_Available));
            Expect_Next ("transmitting", Boolean'Pos (GHST_State.Transmitting_Telemetry));
            Expect_Next ("telemetry_enabled", Boolean'Pos (GHST_State.Telemetry_Enabled));
            Expect_Next ("rf_protocol", Integer_64 (GHST_State.RF_Protocol));
            Expect_Next ("telemetry_len", Integer_64 (GHST_State.Telemetry_Length));
            Expect_Next ("start_at", Integer_64 (GHST_State.Frame_Start_At_Us));
            Expect_Next ("end_at", Integer_64 (GHST_State.Frame_End_At_Us));
            Expect_Next ("frame_time", Integer_64 (GHST_State.Last_Frame_Time_Us));
            Expect_Next ("rssi", Integer_64 (GHST_Rx.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (GHST_Rx.RSSI_Raw));
            Expect_Next ("rssi_dbm", Integer_64 (GHST_Rx.RSSI_Dbm));
            Expect_Next ("rssi_dbm_raw", Integer_64 (GHST_Rx.RSSI_Dbm_Raw));
            Expect_Next ("link_quality", Integer_64 (GHST_Rx.Link_Quality));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (GHST_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (GHST_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown ghst case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_GHST_Line;

   MSP_Rx_State : Adaflight.MSP_Receiver.State;
   MSP_Rx_Clock : Unsigned_32 := 0;

   procedure Check_MSP_Rx_Line is
      use Adaflight.MSP_Receiver;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "mspinit" then
         Init (MSP_Rx_State);
         MSP_Rx_Clock := Unsigned_32 (Int (3));
         K := 4;
         Expect_Next ("count", Channel_Count);
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (MSP_Rx_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "mspstep" then
         declare
            Has_Frame : constant Boolean := Int (4) /= 0;
            Count     : constant Count_Range := Integer (Int (5));
            Frame     : Channel_Data;
            Status    : Adaflight.Receiver.Frame_Report;
            Complete  : Boolean := False;
         begin
            K := 6;
            for Ch in Channel loop
               Frame (Ch) := Integer (Int (K));
               K := K + 1;
            end loop;
            if Has_Frame then
               Frame_Receive (MSP_Rx_State, Frame, Count, Unsigned_32 (Int (K)) / 1_000);
            end if;
            MSP_Rx_Clock := Unsigned_32 (Int (K + 1));
            K := K + 2;
            if Int (K) /= 0 then
               Frame_Status (MSP_Rx_State, MSP_Rx_Clock, Status);
               Expect_Next ("polled", 1);
               Expect_Next ("status", Boolean'Pos (Status.Complete));
            else
               K := K + 2;
            end if;
            if Int (K) /= 0 then
               Override_Frame_Status (MSP_Rx_State, Complete);
               Expect_Next ("override_polled", 1);
               Expect_Next ("override_status", Boolean'Pos (Complete));
            else
               K := K + 2;
            end if;
            Expect_Next ("frame_time", Integer_64 (MSP_Rx_State.Last_Frame_Time_Us));
            for Ch in Channel loop
               Expect_Next ("fresh", Boolean'Pos (Is_Channel_Fresh (MSP_Rx_State, Ch, MSP_Rx_Clock / 1_000)));
            end loop;
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (MSP_Rx_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (MSP_Rx_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown msp receiver case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_MSP_Rx_Line;

   SRXL2_State    : Adaflight.SRXL2.State;
   SRXL2_Rx       : Adaflight.Receiver.State;
   SRXL2_Settings : Adaflight.Receiver.Settings;
   SRXL2_Clock    : Unsigned_32 := 0;

   procedure Check_SRXL2_Line is
      use Adaflight.SRXL2;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
      function Write_CRC return Integer_64 is
         CRC : Interfaces.Unsigned_16 := 0;
      begin
         for I in 0 .. SRXL2_State.Write_Length - 1 loop
            CRC := Adaflight.Bytes.CRC16_CCITT (CRC, Adaflight.Bytes.Byte (SRXL2_State.Write_Buffer (I)));
         end loop;
         return Integer_64 (CRC);
      end Write_CRC;
   begin
      if Name = "srxl2init" then
         SRXL2_Settings := (others => <>);
         SRXL2_Clock := Unsigned_32 (Int (5));
         Adaflight.Receiver.Init (SRXL2_Rx, SRXL2_Settings, SRXL2_Clock / 1_000,
                                  Adaflight.Receiver.RSSI_Source'Val (Int (6)), Adaflight.Receiver.None);
         Init (SRXL2_State, (Unit_Id => Integer (Int (3)), Baud_Fast => Integer (Int (4))), SRXL2_Clock);
         K := 7;
         Expect_Next ("state", Link_State'Pos (SRXL2_State.Link));
         Expect_Next ("timeout", Integer_64 (SRXL2_State.Timeout_Us));
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (SRXL2_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "srxl2step" then
         declare
            Count   : constant Natural := Integer (Int (4));
            Status  : Adaflight.Receiver.Frame_Report;
            VTX     : VTX_Request;
            Written : Boolean := False;
            Fill    : Integer_64;
         begin
            SRXL2_Clock := SRXL2_Clock + Unsigned_32 (Int (5));
            K := 6;
            for B in 1 .. Count loop
               SRXL2_Clock := SRXL2_Clock + Unsigned_32 (Int (K));
               Receive_Byte (SRXL2_State, Integer (Int (K + 1)), SRXL2_Clock);
               K := K + 2;
            end loop;
            if Int (K) >= 0 then
               SRXL2_Clock := SRXL2_Clock + Unsigned_32 (Int (K));
               Idle (SRXL2_State, SRXL2_Clock);
            end if;
            K := K + 1;
            if Int (K) /= 0 then
               Bind (SRXL2_State);
            end if;
            K := K + 1;
            Fill := Int (K);
            K := K + 1;
            if Fill >= 0 then
               Begin_Telemetry_Frame (SRXL2_State);
               for B in 1 .. Integer (Fill) loop
                  Add_Telemetry_Byte (SRXL2_State, Integer (Int (K)));
                  K := K + 1;
               end loop;
               Finish_Telemetry_Frame (SRXL2_State);
            end if;
            SRXL2_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Int (K) /= 0 then
               Frame_Status (SRXL2_State, SRXL2_Rx, SRXL2_Clock, Status, VTX);
               K := K + 1;
               Expect_Next ("status",
                            (if Status.Complete then 1 else 0) + (if Status.Failsafe then 2 else 0)
                            + (if Status.Processing_Required then 4 else 0) + (if Status.Dropped then 8 else 0));
               if Int (K) >= 0 then
                  SRXL2_Clock := SRXL2_Clock + Unsigned_32 (Int (K));
                  Process_Frame (SRXL2_State, SRXL2_Clock, Written);
               end if;
               K := K + 1;
            else
               K := K + 3;
            end if;
            Expect_Next ("state", Link_State'Pos (SRXL2_State.Link));
            Expect_Next ("baud", (case SRXL2_State.Baud is
                                     when Default_Rate => Default_Baud_Rate,
                                     when High_Rate    => High_Baud_Rate));
            Expect_Next ("bus_master", Integer_64 (SRXL2_State.Bus_Master));
            Expect_Next ("telemetry_requested", Boolean'Pos (SRXL2_State.Telemetry_Requested));
            Expect_Next ("write_length", Integer_64 (SRXL2_State.Write_Length));
            Expect_Next ("write_crc", Write_CRC);
            Expect_Next ("transmitting", Boolean'Pos (SRXL2_State.Transmitting));
            Expect_Next ("timeout", Integer_64 (SRXL2_State.Timeout_Us));
            Expect_Next ("full_timeout", Integer_64 (SRXL2_State.Full_Timeout_Us));
            Expect_Next ("last_valid", Integer_64 (SRXL2_State.Last_Valid_Us));
            Expect_Next ("last_receive", Integer_64 (SRXL2_State.Last_Receive_Us));
            Expect_Next ("last_idle", Integer_64 (SRXL2_State.Last_Idle_Us));
            Expect_Next ("frame_time", Integer_64 (SRXL2_State.Last_Frame_Time_Us));
            Expect_Next ("vtx", Boolean'Pos (VTX.Present));
            Expect_Next ("vtx_word", Integer_64 (VTX.Word));
            Expect_Next ("written", Boolean'Pos (Written));
            Expect_Next ("rssi", Integer_64 (SRXL2_Rx.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (SRXL2_Rx.RSSI_Raw));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (SRXL2_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (SRXL2_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown srxl2 case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SRXL2_Line;

   FPORT_State    : Adaflight.FPORT.State;
   FPORT_Rx       : Adaflight.Receiver.State;
   FPORT_Settings : Adaflight.Receiver.Settings;
   FPORT_Clock    : Unsigned_32 := 0;

   procedure Check_FPORT_Line is
      use Adaflight.FPORT;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "fportinit" then
         FPORT_Settings := (others => <>);
         FPORT_Settings.Mid_RC := Integer (Int (3));
         FPORT_Settings.RSSI_Smoothing := Integer (Int (4));
         FPORT_Clock := Unsigned_32 (Int (6));
         Adaflight.Receiver.Init (FPORT_Rx, FPORT_Settings, FPORT_Clock / 1_000,
                                  Adaflight.Receiver.Rx_Protocol, Adaflight.Receiver.None);
         Init (FPORT_State, Integer (Int (3)), Telemetry => Int (5) /= 0);
         K := 7;
         Expect_Next ("rssi_source", Adaflight.Receiver.RSSI_Source'Pos (FPORT_Rx.RSSI_From));
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (FPORT_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "fportstep" then
         declare
            Count   : constant Natural := Integer (Int (4));
            Status  : Adaflight.Receiver.Frame_Report;
            Result  : Process_Outputs;
            Handled : Boolean;
         begin
            K := 5;
            for B in 1 .. Count loop
               FPORT_Clock := FPORT_Clock + Unsigned_32 (Int (K));
               Receive_Byte (FPORT_State, Integer (Int (K + 1)), FPORT_Clock);
               K := K + 2;
            end loop;
            Handled := Int (K) /= 0;
            FPORT_Clock := Unsigned_32 (Int (K + 1));
            K := K + 2;
            if Int (K) /= 0 then
               K := K + 1;
               Frame_Status (FPORT_State, FPORT_Rx, FPORT_Clock, Status);
               Expect_Next ("status",
                            (if Status.Complete then 1 else 0) + (if Status.Failsafe then 2 else 0)
                            + (if Status.Processing_Required then 4 else 0) + (if Status.Dropped then 8 else 0));
               if Status.Processing_Required then
                  FPORT_Clock := FPORT_Clock + Unsigned_32 (Int (K));
                  Process_Frame (FPORT_State, FPORT_Clock, Handled, Result);
               end if;
               K := K + 1;
            else
               K := K + 3;
            end if;
            Expect_Next ("write_index", Integer_64 (FPORT_State.Write_Index));
            Expect_Next ("read_index", Integer_64 (FPORT_State.Read_Index));
            Expect_Next ("position", Integer_64 (FPORT_State.Position));
            Expect_Next ("clear_to_send", Boolean'Pos (FPORT_State.Clear_To_Send));
            Expect_Next ("telemetry_at", Integer_64 (FPORT_State.Last_Telemetry_At_Us));
            Expect_Next ("has_msp", Boolean'Pos (FPORT_State.Has_MSP));
            Expect_Next ("msp_frame_id", (if FPORT_State.Has_MSP then Integer_64 (FPORT_State.MSP.Frame_Id) else 0));
            Expect_Next ("msp_value_id", (if FPORT_State.Has_MSP then Integer_64 (FPORT_State.MSP.Value_Id) else 0));
            Expect_Next ("msp_data", (if FPORT_State.Has_MSP then Integer_64 (FPORT_State.MSP.Data) else 0));
            Expect_Next ("control_at_ms", Integer_64 (FPORT_State.Last_Control_At_Ms));
            Expect_Next ("frame_time", Integer_64 (FPORT_State.Last_Frame_Time_Us));
            Expect_Next ("consulted", Boolean'Pos (Result.Consulted));
            Expect_Next ("consulted_with_payload", Boolean'Pos (Result.Consulted_With_Payload));
            Expect_Next ("sent_empty", Boolean'Pos (Result.Sent_Empty_Reply));
            Expect_Next ("rssi", Integer_64 (FPORT_Rx.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (FPORT_Rx.RSSI_Raw));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (FPORT_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (FPORT_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown fport case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_FPORT_Line;

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
               elsif Kind = "modes" then
                  Check_Modes_Line;
               elsif Kind = "acc" then
                  Check_Acc_Line;
               elsif Kind = "baro" then
                  Check_Baro_Line;
               elsif Kind = "battery" then
                  Check_Battery_Line;
               elsif Kind = "arming" then
                  Check_Arming_Line;
               elsif Kind = "compass" then
                  Check_Compass_Line;
               elsif Kind = "position" then
                  Check_Position_Line;
               elsif Kind = "altitude" then
                  Check_Altitude_Line;
               elsif Kind = "althold" then
                  Check_Alt_Hold_Line;
               elsif Kind = "adjust" then
                  Check_Adjust_Line;
               elsif Kind = "sched" then
                  Check_Sched_Line;
               elsif Kind = "beeper" then
                  Check_Beeper_Line;
               elsif Kind = "rx" then
                  Check_Rx_Line;
               elsif Kind = "sbus" then
                  Check_SBUS_Line;
               elsif Kind = "crsf" then
                  Check_CRSF_Line;
               elsif Kind = "sumd" then
                  Check_SUM_Line;
               elsif Kind = "ibus" then
                  Check_IBUS_Line;
               elsif Kind = "spek" then
                  Check_Spek_Line;
               elsif Kind = "xbus" then
                  Check_XBUS_Line;
               elsif Kind = "jeti" then
                  Check_Jeti_Line;
               elsif Kind = "ghst" then
                  Check_GHST_Line;
               elsif Kind = "msprx" then
                  Check_MSP_Rx_Line;
               elsif Kind = "srxl2" then
                  Check_SRXL2_Line;
               elsif Kind = "fport" then
                  Check_FPORT_Line;
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
   Run (Dir & "/modes.csv", "modes");
   Run (Dir & "/acc.csv", "acc");
   Run (Dir & "/baro.csv", "baro");
   Run (Dir & "/battery.csv", "battery");
   Run (Dir & "/arming.csv", "arming");
   Run (Dir & "/compass.csv", "compass");
   Run (Dir & "/position.csv", "position");
   Run (Dir & "/altitude.csv", "altitude");
   Run (Dir & "/althold.csv", "althold");
   Run (Dir & "/adjust.csv", "adjust");
   Run (Dir & "/sched.csv", "sched");
   Run (Dir & "/beeper.csv", "beeper");
   Run (Dir & "/rx.csv", "rx");
   Run (Dir & "/sbus.csv", "sbus");
   Run (Dir & "/crsf.csv", "crsf");
   Run (Dir & "/sumd.csv", "sumd");
   Run (Dir & "/ibus.csv", "ibus");
   Run (Dir & "/spek.csv", "spek");
   Run (Dir & "/xbus.csv", "xbus");
   Run (Dir & "/jeti.csv", "jeti");
   Run (Dir & "/ghst.csv", "ghst");
   Run (Dir & "/msp.csv", "msprx");
   Run (Dir & "/srxl2.csv", "srxl2");
   Run (Dir & "/fport.csv", "fport");
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
