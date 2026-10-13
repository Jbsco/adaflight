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
with Adaflight.Position_Estimator;
with Adaflight.Altitude_Hold;
with Adaflight.Adjustments;
with Adaflight.Scheduler;
with Adaflight.Beeper;
with Adaflight.Receiver;
with Adaflight.SBUS;
with Adaflight.CRSF;
with Adaflight.Clock;
with Adaflight.VTX;
with Adaflight.Tramp;
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
with Adaflight.Exponentials;
with Adaflight.Chirp;
with Adaflight.SUMD;
with Adaflight.SUMH;
with Adaflight.IBUS;
with Adaflight.Spektrum;
with Adaflight.XBUS;
with Adaflight.Jeti_Ex_Bus;
with Adaflight.Jeti_Telemetry;
with Adaflight.SPI_Radio;
with Adaflight.FrSky_SPI;
with Adaflight.SFHSS;
with Adaflight.Redpine;
with Adaflight.FlySky;
with Adaflight.Spektrum_SPI;
with Adaflight.RC_Stats;
with Adaflight.GHST;
with Adaflight.MSP_Receiver;
with Adaflight.SRXL2;
with Adaflight.FPORT;
with Adaflight.MAVLink;
with Adaflight.MSP_Port;
with Adaflight.ExpressLRS;
with Adaflight.ExpressLRS_Telemetry;
with Adaflight.Blackbox_Encoding;
with Adaflight.Text;
with Adaflight.DShot;
with Adaflight.CRSF_Telemetry;
with Adaflight.ESC_Sensor;
with Adaflight.SmartPort_Telemetry;
with Adaflight.RunCam_Device;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.IBus_Telemetry;
with Adaflight.HoTT_Telemetry;
with Adaflight.GHST_Telemetry;
with Adaflight.Transponder;
with Adaflight.SRXL_Telemetry;
with Adaflight.FrSky_OSD;
with Adaflight.LED_Strip;
with Adaflight.Color;
with Adaflight.Rangefinder;
with Adaflight.Optical_Flow;
with Adaflight.Pitot;
with Adaflight.RTC;
with Adaflight.Internal_ADC;
with Adaflight.Flight_Stats;
with Adaflight.Wing_Launch;
with Adaflight.Nav_Trail;
with Adaflight.GPS_Frames;
with Adaflight.GPS_Link;
with Adaflight.UBX_Config;
with Adaflight.Position_Control;
with Adaflight.Position_Hold;
with Adaflight.GPS_Rescue;
with Adaflight.Altitude_Control;
with Adaflight.VTX_Table;
with Adaflight.SmartAudio;
with Adaflight.LTM_Telemetry;
with Adaflight.GPS_Lap_Timer;
with Adaflight.MSP_Box;
with Adaflight.Dispatch;
with Adaflight.ExpressLRS_Receiver;
with Adaflight.Blackbox_Header;
with Adaflight.Blackbox;
with Adaflight.Position_Nav;
with Adaflight.OSD_Warnings;
with Adaflight.MSP_Telemetry;
with Adaflight.OSD_Format;
with Adaflight.VTX_MSP;
with Adaflight.Display_Port_MSP;
with Adaflight.OSD_Stats;
with Adaflight.OSD_Page;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Render;
with Adaflight.OSD_Draw;
with Adaflight.OSD_Spec;
with Adaflight.OSD_Task;
with Adaflight.MAVLink_Commands;
with Adaflight.MAVLink_Frames;
with Adaflight.MAVLink_Telemetry;

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

   Max_Fields : constant := 1000;
   type Fields is array (1 .. Max_Fields) of String (1 .. 4200);
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
         Record_Result ("ahinit.kp", Bits (14), To_Bits (AH_State.Control.Kp));
         Record_Result ("ahinit.ki", Bits (15), To_Bits (AH_State.Control.Ki));
         Record_Result ("ahinit.kd", Bits (16), To_Bits (AH_State.Control.Kd));
         Record_Result ("ahinit.ka", Bits (17), To_Bits (AH_State.Control.Ka));
         Record_Result ("ahinit.kf", Bits (18), To_Bits (AH_State.Control.Kf));
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
            Record_Result ("ahstep.integral", Bits (19), To_Bits (AH_State.Control.Altitude_I));
            Record_Result ("ahstep.throttle", Bits (20), To_Bits (AH_State.Control.Throttle_Out));
            Record_Int ("ahstep.captured_hover", Int (21), Integer_64 (AH_State.Control.Captured_Hover));
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

   Alt_State    : Adaflight.Position_Estimator.State;
   Alt_Settings : Adaflight.Position_Estimator.Settings;
   Alt_Present  : Boolean := False;
   Alt_One_G_Reciprocal : Adaflight.Position_Estimator.Acc_Scale := 1.0 / 4_096.0;

   procedure Check_Altitude_Line is
      use Adaflight.Position_Estimator;
      Name : constant String := Str (1);
   begin
      if Name = "altinit" then
         Alt_Settings := (Source         => Altitude_Source'Val (Int (3)),
                          Prefer_Baro    => Integer (Int (4)),
                          Altitude_LPF   => Integer (Int (5)),
                          Derivative_LPF => Integer (Int (6)),
                          Horizontal     => Auto);
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
            case Int (NF - 3) is
               when 1 =>
                  Clear_Mode_Overrides (Arming_State);
               when 2 =>
                  Clear_Mode_Overrides (Arming_State);
                  Set_Mode_Override (Arming_State, Adaflight.Modes.Box'Val (Int (NF - 2)), True);
               when 3 =>
                  Set_Mode_Override (Arming_State, Adaflight.Modes.Box'Val (Int (NF - 2)), True);
               when 4 =>
                  Set_Mode_Override (Arming_State, Adaflight.Modes.Box'Val (Int (NF - 2)), False);
               when others =>
                  null;
            end case;
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
            K := K + 2;
            Expect_Hex ("overrides0", Box_Word (Arming_State.Mode_Overrides, 0));
            Expect_Hex ("overrides1", Box_Word (Arming_State.Mode_Overrides, 1));
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

   Mav_State    : Adaflight.MAVLink.State;
   Mav_Rx       : Adaflight.Receiver.State;
   Mav_Settings : Adaflight.Receiver.Settings;
   Mav_Clock    : Unsigned_32 := 0;
   Mav_Min_Free : Adaflight.MAVLink.Byte := 0;

   procedure Check_MAVLink_Line is
      use Adaflight.MAVLink;
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
      if Name = "mavinit" then
         Mav_Settings := (others => <>);
         Mav_Settings.Mid_RC := Integer (Int (3));
         Mav_Settings.RSSI_Smoothing := Integer (Int (4));
         Mav_Clock := Unsigned_32 (Int (5));
         Adaflight.Receiver.Init (Mav_Rx, Mav_Settings, Mav_Clock / 1_000,
                                  Adaflight.Receiver.Protocol_Mavlink, Adaflight.Receiver.Mavlink);
         Init (Mav_State, Integer (Int (3)));
         K := 6;
         Expect_Next ("rssi_source", Adaflight.Receiver.RSSI_Source'Pos (Mav_Rx.RSSI_From));
         Expect_Next ("quality_source", Adaflight.Receiver.Link_Quality_Source'Pos (Mav_Rx.Quality_From));
         Mav_Min_Free := Integer (Int (K));
         K := K + 1;
         for Ch in Channel loop
            Expect_Next ("data", Integer_64 (Mav_State.Data (Ch)));
         end loop;
         Check_Fields;
      elsif Name = "mavstep" then
         declare
            Count  : constant Natural := Integer (Int (4));
            Status : Adaflight.Receiver.Frame_Report;
            Msg    : Message;
            Got    : Boolean := False;
         begin
            K := 5;
            for B in 1 .. Count loop
               Mav_Clock := Mav_Clock + Unsigned_32 (Int (K));
               Receive_Byte (Mav_State, Mav_Rx, Integer (Int (K + 1)), Mav_Clock);
               K := K + 2;
            end loop;
            Mav_Clock := Unsigned_32 (Int (K));
            K := K + 1;
            if Int (K) /= 0 then
               K := K + 1;
               Frame_Status (Mav_State, Status);
               Expect_Next ("status", Boolean'Pos (Status.Complete));
            else
               K := K + 2;
            end if;
            if Int (K) /= 0 then
               Pop_Queue (Mav_State, Msg, Got);
            end if;
            K := K + 1;
            Expect_Next ("got", Boolean'Pos (Got));
            Expect_Next ("popped_id", (if Got then Integer_64 (Msg.Id) else 0));
            Expect_Next ("popped_len", (if Got then Integer_64 (Msg.Len) else 0));
            Expect_Next ("popped_seq", (if Got then Integer_64 (Msg.Seq) else 0));
            Expect_Next ("parse_state", Parse_State'Pos (Mav_State.Frames.Status.State));
            Expect_Next ("packet_idx", Integer_64 (Mav_State.Frames.Status.Packet_Idx));
            Expect_Next ("success_count", Integer_64 (Mav_State.Frames.Status.Success_Count));
            Expect_Next ("flags", Integer_64 (Mav_State.Frames.Status.Flags));
            Expect_Next ("signature_left", Integer_64 (Mav_State.Frames.Status.Signature_Left));
            Expect_Next ("rx_len", Integer_64 (Mav_State.Frames.Rx.Len));
            Expect_Next ("rx_checksum", Integer_64 (Mav_State.Frames.Rx.Checksum));
            Expect_Next ("recv_id", Integer_64 (Mav_State.Frames.Received.Id));
            Expect_Next ("recv_len", Integer_64 (Mav_State.Frames.Received.Len));
            Expect_Next ("recv_seq", Integer_64 (Mav_State.Frames.Received.Seq));
            Expect_Next ("recv_sysid", Integer_64 (Mav_State.Frames.Received.Sysid));
            Expect_Next ("recv_compid", Integer_64 (Mav_State.Frames.Received.Compid));
            Expect_Next ("recv_checksum", Integer_64 (Mav_State.Frames.Received.Checksum));
            Expect_Next ("frame_received", Boolean'Pos (Mav_State.Frame_Received));
            Expect_Next ("head", Integer_64 (Mav_State.Head));
            Expect_Next ("tail", Integer_64 (Mav_State.Tail));
            Expect_Next ("tx_valid", Boolean'Pos (Mav_State.Tx_Buffer_Valid));
            Expect_Next ("tx_free", Integer_64 (Mav_State.Tx_Buffer_Free));
            Expect_Next ("should_send", Boolean'Pos (Should_Send_Telemetry (Mav_State, Mav_Min_Free)));
            Expect_Next ("frame_time", Integer_64 (Mav_State.Last_Frame_Time_Us));
            Expect_Next ("rssi", Integer_64 (Mav_Rx.RSSI));
            Expect_Next ("rssi_raw", Integer_64 (Mav_Rx.RSSI_Raw));
            Expect_Next ("rssi_dbm", Integer_64 (Mav_Rx.RSSI_Dbm));
            Expect_Next ("rssi_dbm_raw", Integer_64 (Mav_Rx.RSSI_Dbm_Raw));
            Expect_Next ("rsnr", Integer_64 (Mav_Rx.RSNR));
            Expect_Next ("rsnr_raw", Integer_64 (Mav_Rx.RSNR_Raw));
            Expect_Next ("link_quality", Integer_64 (Mav_Rx.Link_Quality));
            for Ch in Channel loop
               Expect_Next ("data", Integer_64 (Mav_State.Data (Ch)));
               Record_Result (Name & ".raw", Bits (K), To_Bits (Read_Raw (Mav_State, Ch)));
               K := K + 1;
            end loop;
            Check_Fields;
         end;
      else
         Put_Line ("unknown mavlink case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_MAVLink_Line;

   MSP_Serial_Port   : Adaflight.MSP_Port.Port;
   MSP_Serial_Queue  : Byte_Array (0 .. 16_383) := (others => 0);
   MSP_Serial_Len    : Natural := 0;
   MSP_Serial_Clock  : Unsigned_32 := 0;
   MSP_Serial_Reboot : Byte := 0;

   procedure Check_MSP_Serial_Line is
      use Adaflight.MSP_Port;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Expect_Bits (N : String; Actual : Unsigned_32) is
      begin
         Record_Result (Name & "." & N, Bits (K), Actual);
         K := K + 1;
      end Expect_Bits;
      procedure Check_Fields is
      begin
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Check_Fields;
   begin
      if Name = "mspserialinit" then
         Init (MSP_Serial_Port);
         MSP_Serial_Len := 0;
         MSP_Serial_Reboot := Byte (Int (3));
         MSP_Serial_Clock := Unsigned_32 (Int (4));
         K := 5;
         Expect_Next ("phase", Port_Phase'Pos (MSP_Serial_Port.Phase));
         Expect_Next ("decoder", Decoder_Phase'Pos (MSP_Serial_Port.Decoder));
         Check_Fields;
      elsif Name = "mspserialstep" then
         declare
            Count    : constant Natural := Integer (Int (4));
            Opt      : Options;
            Tx_Empty : Boolean;
            Tx_Free  : Natural;
            Consumed : Natural;
            Ev       : Event;
         begin
            MSP_Serial_Clock := MSP_Serial_Clock + Unsigned_32 (Int (5));
            Opt.Evaluate_Non_MSP := Int (6) /= 0;
            Opt.Peripheral := Int (7) /= 0;
            Tx_Empty := Int (8) /= 0;
            Tx_Free := Integer (Int (9));
            Opt.CLI_Running := Int (10) /= 0;
            Opt.Reboot_Character := MSP_Serial_Reboot;
            K := 11;
            for B in 1 .. Count loop
               MSP_Serial_Queue (MSP_Serial_Len) := Byte (Int (K));
               MSP_Serial_Len := MSP_Serial_Len + 1;
               K := K + 1;
            end loop;
            Process (MSP_Serial_Port, MSP_Serial_Queue (0 .. MSP_Serial_Len - 1), Consumed, MSP_Serial_Clock, Opt, Ev);
            MSP_Serial_Queue (0 .. MSP_Serial_Len - Consumed - 1) := MSP_Serial_Queue (Consumed .. MSP_Serial_Len - 1);
            MSP_Serial_Len := MSP_Serial_Len - Consumed;
            Expect_Next ("consumed", Integer_64 (Consumed));
            Expect_Next ("phase", Port_Phase'Pos (MSP_Serial_Port.Phase));
            Expect_Next ("decoder", Decoder_Phase'Pos (MSP_Serial_Port.Decoder));
            Expect_Next ("kind", Packet_Kind'Pos (MSP_Serial_Port.Kind));
            Expect_Next ("version", Framing'Pos (MSP_Serial_Port.Version));
            Expect_Next ("command", Integer_64 (MSP_Serial_Port.Command_Id));
            Expect_Next ("flags", Integer_64 (MSP_Serial_Port.Flags));
            Expect_Next ("data_size", Integer_64 (MSP_Serial_Port.Data_Size));
            Expect_Next ("offset", Integer_64 (MSP_Serial_Port.Offset));
            Expect_Next ("checksum_1", Integer_64 (MSP_Serial_Port.Checksum_1));
            Expect_Next ("checksum_2", Integer_64 (MSP_Serial_Port.Checksum_2));
            Expect_Next ("pending", Pending_Request'Pos (MSP_Serial_Port.Pending));
            Expect_Next ("activity", Integer_64 (MSP_Serial_Port.Last_Activity_Ms));
            Expect_Next ("event", Event'Pos (Ev));
            Expect_Bits ("frame_hash",
                         (if Ev in Command_Frame | Reply_Frame
                          then FNV_Update (FNV_Offset_Basis, MSP_Serial_Port.Data (0 .. MSP_Serial_Port.Data_Size - 1))
                          else 0));
            declare
               --  The recorded command processor: the result (none, acknowledged, error), the
               --  reply flags, and the reply payload follow from the command, its flags, and its size.
               Lengths : constant array (0 .. 13) of Natural :=
                 (0, 1, 2, 5, 32, 100, 200, 248, 249, 254, 255, 256, 300, 500);
               Cmd     : constant Natural := MSP_Serial_Port.Command_Id;
               Sz      : constant Natural := MSP_Serial_Port.Data_Size;
               Flg     : constant Natural := Natural (MSP_Serial_Port.Flags);
               Sel     : constant Natural := (Cmd + Sz) mod 8;
               Len     : constant Natural := Lengths ((Cmd * 7 + Sz * 3 + Flg) mod 14);
               Result  : Natural := 0;
               Tx_Len  : Natural := 0;
               Hdr_Len : Natural := 0;
               Length  : Positive := 1;
               Frame   : Frame_Buffer := (others => 0);
               Payload : Byte_Array (0 .. Max_Payload - 1) := (others => 0);
            begin
               if Ev = Command_Frame then
                  Result := (if Sel = 0 then 0 elsif Sel = 1 then 2 else 1);
                  for J in 0 .. Len - 1 loop
                     Payload (J) := Byte ((Cmd + 3 * J + Flg + Sz) mod 256);
                  end loop;
                  if Result /= 0 then
                     Encode (MSP_Serial_Port.Version, Cmd,
                             (if Sel = 3 then Byte ((Unsigned_32 (Cmd) xor 16#5A#) mod 256) else 0),
                             Error => Result = 2, Payload => Payload (0 .. Len - 1), Frame => Frame, Length => Length);
                     if May_Send (Length, Tx_Empty, Tx_Free) then
                        Tx_Len := Length;
                        Hdr_Len := Header_Length (MSP_Serial_Port.Version, Len);
                     end if;
                  end if;
               end if;
               Expect_Next ("result", Integer_64 (Result));
               Expect_Next ("tx_len", Integer_64 (Tx_Len));
               Expect_Bits ("tx_hash", FNV_Update (FNV_Offset_Basis, Frame (0 .. Tx_Len - 1)));
               Expect_Next ("hdr_len", Integer_64 (Hdr_Len));
               for B in 0 .. Hdr_Len - 1 loop
                  Expect_Next ("hdr", Integer_64 (Frame (B)));
               end loop;
            end;
            Expect_Next ("active",
                         Boolean'Pos (Configurator_Active (MSP_Serial_Port, MSP_Serial_Clock, Opt.Peripheral)));
            Check_Fields;
         end;
      else
         Put_Line ("unknown mspserial case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_MSP_Serial_Line;

   ELRS_Hop : Adaflight.ExpressLRS.Hopping;
   ELRS_LQ  : Adaflight.ExpressLRS.Link_Quality;

   procedure Check_ELRS_Line is
      use Adaflight.ExpressLRS;
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
      if Name = "elrstable" then
         declare
            R : constant Rate_Index := Integer (Int (3));
            M : constant Mod_Settings := (if Int (2) = 0 then Rates_900 (R) else Rates_2400 (R));
            P : constant Perf_Params := (if Int (2) = 0 then Perf_900 (R) else Perf_2400 (R));
         begin
            K := 4;
            Expect_Next ("index", Integer_64 (M.Index));
            Expect_Next ("radio", Radio_Type'Pos (M.Radio));
            Expect_Next ("rate", RF_Rate'Pos (M.Rate));
            Expect_Next ("v4_rate", Integer_64 (M.V4_Rate));
            Expect_Next ("bandwidth", Integer_64 (M.Bandwidth));
            Expect_Next ("spreading", Integer_64 (M.Spreading));
            Expect_Next ("coding", Integer_64 (M.Coding));
            Expect_Next ("interval", Integer_64 (M.Interval_Us));
            Expect_Next ("ratio", Telemetry_Ratio'Pos (M.Ratio));
            Expect_Next ("hop_interval", Integer_64 (M.Hop_Interval));
            Expect_Next ("preamble", Integer_64 (M.Preamble));
            Expect_Next ("perf_index", Integer_64 (P.Index));
            Expect_Next ("perf_rate", RF_Rate'Pos (P.Rate));
            Expect_Next ("sensitivity", Integer_64 (P.Sensitivity_Dbm));
            Expect_Next ("time_on_air", Integer_64 (P.Time_On_Air_Us));
            Expect_Next ("disconnect", Integer_64 (P.Disconnect_Timeout_Ms));
            Expect_Next ("lock", Integer_64 (P.Lock_Timeout_Ms));
            Expect_Next ("sync_disconnected", Integer_64 (P.Sync_Interval_Disconnected_Ms));
            Expect_Next ("sync_connected", Integer_64 (P.Sync_Interval_Connected_Ms));
            Check_Fields;
         end;
      elsif Name = "elrsdomain" then
         declare
            D : constant Domain_Config := Domains (Frequency_Domain'Val (Int (2)));
         begin
            K := 3;
            Expect_Next ("domain", Int (2));
            Expect_Next ("start", Integer_64 (D.Start_Reg));
            Expect_Next ("stop", Integer_64 (D.Stop_Reg));
            Expect_Next ("channels", Integer_64 (D.Channels));
            Check_Fields;
         end;
      elsif Name = "elrsinit" then
         declare
            UID  : Byte_Array (0 .. 5);
            Seed : Unsigned_32;
         begin
            for B in 0 .. 5 loop
               UID (B) := Byte (Int (3 + B));
            end loop;
            Seed := UID_Seed (UID);
            Reset (ELRS_LQ);
            K := 9;
            Record_Int (Name & ".seed", Int (K), Integer_64 (Seed));
            K := K + 1;
            ELRS_Hop := (others => <>);
            Generate (ELRS_Hop, Seed, Frequency_Domain'Val (Int (K)));
            K := K + 1;
            Expect_Next ("count", Integer_64 (ELRS_Hop.Count));
            Expect_Next ("sync_channel", Integer_64 (ELRS_Hop.Sync_Channel));
            Expect_Next ("spread", Integer_64 (ELRS_Hop.Spread));
            Expect_Next ("entries", Integer_64 (Entry_Count (ELRS_Hop)));
            Expect_Next ("index", Integer_64 (ELRS_Hop.Index));
            for I in 0 .. ELRS_Hop.Count - 1 loop
               Expect_Next ("sequence", Integer_64 (ELRS_Hop.Sequence (I)));
            end loop;
            Check_Fields;
         end;
      elsif Name = "elrshop" then
         declare
            Correction : constant Interfaces.Integer_32 := Interfaces.Integer_32 (Int (4));
            Freq       : Unsigned_32;
         begin
            if Int (5) >= 0 then
               Set_Index (ELRS_Hop, Byte (Int (5)));
            end if;
            K := 6;
            Expect_Next ("initial", Integer_64 (Initial_Frequency (ELRS_Hop, Correction)));
            Next_Frequency (ELRS_Hop, Correction, Freq);
            Expect_Next ("next", Integer_64 (Freq));
            Expect_Next ("index", Integer_64 (ELRS_Hop.Index));
            Check_Fields;
         end;
      elsif Name = "elrscrc" then
         declare
            Len  : constant Natural := Integer (Int (4));
            Data : Byte_Array (0 .. 15) := (others => 0);
         begin
            for B in 0 .. Len - 1 loop
               Data (B) := Byte (Int (6 + B));
            end loop;
            K := 6 + Len;
            Expect_Next ("crc", Integer_64 (CRC14 (Data (0 .. Len - 1), Unsigned_16 (Int (5)))));
            Check_Fields;
         end;
      elsif Name = "elrslq" then
         case Int (4) is
            when 0 => Reset (ELRS_LQ);
            when 1 => New_Period (ELRS_LQ);
            when 2 => Increase (ELRS_LQ);
            when others =>
               New_Period (ELRS_LQ);
               Increase (ELRS_LQ);
         end case;
         K := 5;
         Expect_Next ("value", Integer_64 (ELRS_LQ.Value));
         Expect_Next ("period_set", Boolean'Pos (Period_Is_Set (ELRS_LQ)));
         Expect_Next ("index", Integer_64 (ELRS_LQ.Index));
         Expect_Next ("mask", Integer_64 (Mask (ELRS_LQ)));
         for W in 0 .. LQ_Depth - 1 loop
            Expect_Next ("bits", Integer_64 (ELRS_LQ.Bits (W)));
         end loop;
         Check_Fields;
      elsif Name = "elrsconv" then
         K := 3;
         for V in 0 .. 1 loop
            Expect_Next ("switch_1b", Integer_64 (Switch_1b (V)));
         end loop;
         for V in 0 .. 7 loop
            Expect_Next ("switch_3b", Integer_64 (Switch_3b (V)));
         end loop;
         for J in 1 .. 12 loop
            declare
               V   : constant Natural := Integer (Int (K));
               Max : constant Natural := Integer (Int (K + 1));
            begin
               K := K + 2;
               Expect_Next ("switch_nb", Integer_64 (Switch_Nb (V, Max)));
            end;
         end loop;
         for R in Telemetry_Ratio loop
            Expect_Next ("ratio", Integer_64 (Ratio_Value (R)));
         end loop;
         for R in RF_Rate loop
            Expect_Next ("rate_hz", Integer_64 (Rate_Hz (R)));
         end loop;
         for P in 0 .. 9 loop
            Expect_Next ("power", Integer_64 (Power_Mw (P)));
         end loop;
         Check_Fields;
      elsif Name = "elrsair" then
         K := 3;
         for A in 0 .. 7 loop
            for C in Rate_Index loop
               Expect_Next ("index_900", Integer_64 (Rate_Index_900 (A, C)));
            end loop;
         end loop;
         for A in 0 .. 15 loop
            for C in Rate_Index loop
               Expect_Next ("index_2400", Integer_64 (Rate_Index_2400 (A, C)));
            end loop;
         end loop;
         Check_Fields;
      elsif Name = "elrsnonce" then
         K := 4;
         for N in 0 .. 127 loop
            Expect_Next ("switch_index", Integer_64 (Hybrid_Wide_Switch_Index (Byte (Integer (Int (3)) * 128 + N))));
         end loop;
         Check_Fields;
      else
         Put_Line ("unknown elrs case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_ELRS_Line;

   TLM_Sender   : Adaflight.ExpressLRS_Telemetry.Sender;
   TLM_Receiver : Adaflight.ExpressLRS_Telemetry.Receiver;

   procedure Check_Telemetry_Line is
      use Adaflight.ExpressLRS_Telemetry;
      Name : constant String := Str (1);
      K    : Positive := 1;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Expect_State is
      begin
         Expect_Next ("state", Sender_State'Pos (TLM_Sender.State));
         Expect_Next ("offset", Integer_64 (TLM_Sender.Offset));
         Expect_Next ("bytes_last", Integer_64 (TLM_Sender.Bytes_Last_Payload));
         Expect_Next ("package", Integer_64 (TLM_Sender.Current_Package));
         Expect_Next ("wait_until", Boolean'Pos (TLM_Sender.Wait_Until_Confirm));
         Expect_Next ("wait_count", Integer_64 (TLM_Sender.Wait_Count));
         Expect_Next ("max_wait", Integer_64 (TLM_Sender.Max_Wait_Count));
         Expect_Next ("active", Boolean'Pos (Is_Active (TLM_Sender)));
         Expect_Next ("msp_offset", Integer_64 (TLM_Receiver.Offset));
         Expect_Next ("msp_package", Integer_64 (TLM_Receiver.Current_Package));
         Expect_Next ("msp_confirm", Boolean'Pos (TLM_Receiver.Confirm));
         Expect_Next ("msp_finished", Boolean'Pos (Has_Finished (TLM_Receiver)));
         Record_Result (Name & ".msp_digest", Bits (K),
                        FNV_Update (FNV_Offset_Basis, TLM_Receiver.Data (0 .. TLM_Receiver.Length - 1)));
         K := K + 1;
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Expect_State;
   begin
      if Name = "tlminit" then
         Reset_Sender (TLM_Sender);
         TLM_Receiver := (others => <>);
         Set_Receive_Length (TLM_Receiver, MSP_Buffer_Size);
         K := 3;
         Expect_State;
      elsif Name = "tlmstep" then
         declare
            Op : constant Integer_64 := Int (4);
         begin
            K := 5;
            case Op is
               when 0 =>
                  declare
                     Len  : constant Natural := Integer (Int (K));
                     Data : Byte_Array (0 .. Frame_Max - 1);
                  begin
                     for J in 0 .. Frame_Max - 1 loop
                        Data (J) := Byte ((Integer (Int (2)) * 7 + Integer (Int (3)) + 13 * J) mod 256);
                     end loop;
                     Set_Data (TLM_Sender, Data (0 .. Len - 1));
                     K := K + 1;
                  end;
               when 1 =>
                  declare
                     Max_Len : constant Chunk_Length := Integer (Int (K));
                     Out_Data : Chunk;
                     Index    : Byte;
                  begin
                     K := K + 2;
                     Current_Payload (TLM_Sender, Out_Data, Max_Len, Index);
                     Expect_Next ("index", Integer_64 (Index));
                     Expect_Next ("bytes_last", Integer_64 (TLM_Sender.Bytes_Last_Payload));
                     for B in 0 .. TLM_Sender.Bytes_Last_Payload - 1 loop
                        Expect_Next ("byte", Integer_64 (Out_Data (B)));
                     end loop;
                  end;
               when 2 =>
                  if Int (K) >= 0 then
                     Confirm (TLM_Sender, Int (K) /= 0);
                  end if;
                  K := K + 1;
               when 3 =>
                  Update_Rate (TLM_Sender, Integer (Int (K)), Integer (Int (K + 1)));
                  K := K + 2;
               when 4 =>
                  TLM_Receiver.Data := (others => 0);
                  Set_Receive_Length (TLM_Receiver, Integer (Int (K)));
                  K := K + 1;
               when 5 =>
                  declare
                     Payload : Chunk;
                  begin
                     for B in 0 .. Bytes_Per_Call - 1 loop
                        Payload (B) := Byte (Int (K + 1 + B));
                     end loop;
                     Receive (TLM_Receiver, Byte (Int (K)), Payload);
                     K := K + 1 + Bytes_Per_Call;
                  end;
               when 6 =>
                  Unlock (TLM_Receiver);
               when others =>
                  Reset_Receiver (TLM_Receiver);
            end case;
            Expect_State;
         end;
      else
         Put_Line ("unknown telemetry case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Telemetry_Line;

   BB_Buffer : Byte_Array (0 .. 63) := (others => 0);
   BB_Stream : Adaflight.Stream_Buffers.Stream;

   procedure Check_Blackbox_Line is
      use Adaflight.Blackbox_Encoding;
      Name : constant String := Str (1);
      Kind : constant Integer_64 := Int (4);
      K    : Positive := 5;
      procedure Expect_Next (N : String; Actual : Integer_64) is
      begin
         Record_Int (Name & "." & N, Int (K), Actual);
         K := K + 1;
      end Expect_Next;
      procedure Expect_Bytes is
      begin
         Expect_Next ("count", Integer_64 (BB_Stream.Next));
         for I in 0 .. BB_Stream.Next - 1 loop
            Expect_Next ("byte", Integer_64 (BB_Buffer (I)));
         end loop;
         if K /= NF + 1 then
            Put_Line (Name & ": consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
            Failures := Failures + 1;
         end if;
      end Expect_Bytes;
      function Values (Count : Natural) return Int32_Array is
         V : Int32_Array (0 .. 7) := (others => 0);
      begin
         for J in 0 .. Count - 1 loop
            V (J) := Interfaces.Integer_32 (Int (K + J));
         end loop;
         return V;
      end Values;
   begin
      if Name /= "bbenc" then
         Put_Line ("unknown blackbox case " & Name);
         Failures := Failures + 1;
         return;
      end if;
      BB_Buffer := (others => 0);
      Adaflight.Stream_Buffers.Init (BB_Stream, 0, 64);
      case Kind is
         when 0 =>
            Write_Unsigned_VB (BB_Buffer, BB_Stream, Unsigned_32 (Int (K)));
            K := K + 1;
         when 1 =>
            Write_Signed_VB (BB_Buffer, BB_Stream, Interfaces.Integer_32 (Int (K)));
            K := K + 1;
         when 2 =>
            Write_S16 (BB_Buffer, BB_Stream, Interfaces.Integer_16 (Int (K)));
            K := K + 1;
         when 3 =>
            Write_Tag2_3S32 (BB_Buffer, BB_Stream, Values (3) (0 .. 2));
            K := K + 3;
         when 4 =>
            declare
               Selector : Natural;
            begin
               Write_Tag2_3S_Variable (BB_Buffer, BB_Stream, Values (3) (0 .. 2), Selector);
               K := K + 3;
               Expect_Next ("selector", Integer_64 (Selector));
            end;
         when 5 =>
            Write_Tag8_4S16 (BB_Buffer, BB_Stream, Values (4) (0 .. 3));
            K := K + 4;
         when 6 =>
            declare
               Count : constant Natural := Integer (Int (K));
            begin
               K := K + 1;
               Write_Tag8_8SVB (BB_Buffer, BB_Stream, Values (Count), Count);
               K := K + Count;
            end;
         when 7 =>
            Write_U32 (BB_Buffer, BB_Stream, Unsigned_32'Mod (Int (K)));
            K := K + 1;
         when 8 =>
            Write_Float (BB_Buffer, BB_Stream, Flt (K));
            K := K + 1;
         when 9 =>
            declare
               Count : constant Natural := Integer (Int (K));
            begin
               K := K + 1;
               Write_Signed_VB_Array (BB_Buffer, BB_Stream, Values (Count) (0 .. Count - 1));
               K := K + Count;
            end;
         when others =>
            declare
               Count : constant Natural := Integer (Int (K));
               V     : Int16_Array (0 .. 3) := (others => 0);
            begin
               K := K + 1;
               for J in 0 .. Count - 1 loop
                  V (J) := Interfaces.Integer_16 (Int (K + J));
               end loop;
               Write_Signed16_VB_Array (BB_Buffer, BB_Stream, V (0 .. Count - 1));
               K := K + Count;
            end;
      end case;
      Expect_Bytes;
   end Check_Blackbox_Line;

   function Hex_String (I : Positive) return String is
      S : constant String := Str (I);
      R : String (1 .. S'Length / 2);
   begin
      for K in R'Range loop
         R (K) := Character'Val (Natural'Value ("16#" & S (S'First + 2 * (K - 1) .. S'First + 2 * K - 1) & "#"));
      end loop;
      return R;
   end Hex_String;

   procedure Record_Text (Name : String; Expected, Actual : String) is
   begin
      if Expected'Length /= Actual'Length then
         Record_Int (Name & ".length", Integer_64 (Expected'Length), Integer_64 (Actual'Length));
      else
         for K in 0 .. Expected'Length - 1 loop
            Record_Int (Name, Integer_64 (Character'Pos (Expected (Expected'First + K))),
                        Integer_64 (Character'Pos (Actual (Actual'First + K))));
         end loop;
      end if;
   end Record_Text;

   Text_Buffer : String (1 .. 400) := (others => ' ');
   Text_Pool   : String (1 .. 256) := (others => ' ');

   procedure Check_Text_Line is
      use Adaflight.Text;
      Name   : constant String := Str (1);
      Sub    : constant Integer_64 := Int (4);
      Length : Natural := 0;
   begin
      if Name = "textnum" then
         if Sub = 0 then
            Put_Unsigned (Unsigned_32 (Int (5)), Adaflight.Text.Number_Base (Int (6)), Int (7) = 1,
                          Text_Buffer, Length);
            Record_Text (Name, Hex_String (8), Text_Buffer (1 .. Length));
         elsif Sub = 1 then
            Put_Integer (I32 (5), Text_Buffer, Length);
            Record_Text (Name, Hex_String (6), Text_Buffer (1 .. Length));
         else
            Put_Integer_In_Base (I32 (5), Integer (Int (6)), Text_Buffer, Length);
            Record_Text (Name, Hex_String (7), Text_Buffer (1 .. Length));
         end if;
      elsif Name = "textfixed" then
         Put_Fixed (Flt (5), Text_Buffer, Length);
         Record_Text (Name, Hex_String (6), Text_Buffer (1 .. Length));
      elsif Name = "textfloat" then
         Record_Result (Name, Bits (6), To_Bits (To_Float (Hex_String (5))));
      elsif Name = "textcase" then
         if Sub = 0 then
            Record_Int (Name & ".count", Int (8),
                        Integer_64 (Compare_Ignoring_Case (Hex_String (5), Hex_String (6), Natural (Int (7)))));
         elsif Sub = 1 then
            Record_Int (Name, Int (7), Integer_64 (Compare_Ignoring_Case (Hex_String (5), Hex_String (6))));
         else
            declare
               H : constant String := Hex_String (5);
               R : constant Natural := Find_Ignoring_Case (H, Hex_String (6));
            begin
               Record_Int (Name & ".find", Int (7), (if R = 0 then -1 else Integer_64 (R - H'First)));
            end;
         end if;
      elsif Name = "textclass" then
         declare
            C : constant Character := Character'Val (Int (5));
         begin
            Record_Int (Name & ".alnum", Int (6), Boolean'Pos (Is_Alnum (C)));
            Record_Int (Name & ".digit", Int (7), Boolean'Pos (Is_Digit (C)));
            Record_Int (Name & ".upper", Int (8), Boolean'Pos (Is_Upper (C)));
            Record_Int (Name & ".lower", Int (9), Boolean'Pos (Is_Lower (C)));
            Record_Int (Name & ".space", Int (10), Boolean'Pos (Is_Space (C)));
            Record_Int (Name & ".tolower", Int (11), Integer_64 (Character'Pos (To_Lower (C))));
            Record_Int (Name & ".toupper", Int (12), Integer_64 (Character'Pos (To_Upper (C))));
         end;
      elsif Name = "textfmt" then
         declare
            Template : constant String := Hex_String (5);
            Count    : constant Natural := Natural (Int (6));
            Args     : Argument_List (1 .. 4);
            K        : Positive := 7;
            Pool_Len : Natural := 0;
         begin
            for J in 1 .. Count loop
               case Int (K) is
                  when 0 =>
                     Args (J) := Int_Argument (I32 (K + 1));
                  when 1 =>
                     Args (J) := Unsigned_Argument (Unsigned_32 (Int (K + 1)));
                  when 2 =>
                     Args (J) := Char_Argument (Character'Val (Int (K + 1)));
                  when others =>
                     declare
                        S : constant String := Hex_String (K + 1);
                     begin
                        Text_Pool (Pool_Len + 1 .. Pool_Len + S'Length) := S;
                        Args (J) := Text_Argument (Pool_Len + 1, Pool_Len + S'Length);
                        Pool_Len := Pool_Len + S'Length;
                     end;
               end case;
               K := K + 2;
            end loop;
            Format (Template, Args (1 .. Count), Text_Pool (1 .. Pool_Len), Text_Buffer, Length);
            Record_Int (Name & ".written", Int (K), Integer_64 (Length));
            Record_Text (Name, Hex_String (K + 1), Text_Buffer (1 .. Length));
         end;
      else
         Put_Line ("unknown text case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Text_Line;

   DShot_Seq     : Integer_64 := -1;
   Edge_State    : Adaflight.DShot.Edge_Decoder;
   Quality_State : Adaflight.DShot.Quality;
   Tlm           : Adaflight.DShot.Telemetry;
   Edge_Buffer   : Adaflight.DShot.Samples (0 .. Adaflight.DShot.Max_Samples - 1) := (others => 0);

   procedure Check_DShot_Line is
      use Adaflight.DShot;
      use type Interfaces.Unsigned_8;
      use type Interfaces.Unsigned_16;
      subtype Unsigned_8 is Interfaces.Unsigned_8;
      subtype Unsigned_16 is Interfaces.Unsigned_16;
      subtype Integer_16 is Interfaces.Integer_16;
      Name : constant String := Str (1);
   begin
      if Int (2) /= DShot_Seq then
         DShot_Seq := Int (2);
         Edge_State := (others => <>);
         Quality_State := (others => <>);
         Tlm := (others => <>);
      end if;
      if Name = "dsframe" then
         Record_Int (Name, Int_Hex (7), Integer_64 (Frame (Natural (Int (4)), Int (5) = 1, Int (6) = 1)));
      elsif Name = "dsconv" then
         if Int (4) = 0 then
            Record_Result (Name & ".from", Bits (7), To_Bits (From_External (Unsigned_16 (Int (6)), Int (5) = 1)));
         else
            Record_Int (Name & ".to", Int (7), Integer_64 (To_External (Flt (6), Int (5) = 1)));
         end if;
      elsif Name = "dsend" then
         declare
            Low, High, Disarm : Motor_Value;
            DBH, DBL          : Float := 0.0;
         begin
            Endpoints (Natural (Int (5)), Flt (6), Int (4) = 1, Low, High, Disarm, DBH, DBL);
            Record_Result (Name & ".low", Bits (7), To_Bits (Low));
            Record_Result (Name & ".high", Bits (8), To_Bits (High));
            Record_Result (Name & ".disarm", Bits (9), To_Bits (Disarm));
            Record_Result (Name & ".dbhigh", Bits (10), To_Bits (DBH));
            Record_Result (Name & ".dblow", Bits (11), To_Bits (DBL));
         end;
      elsif Name = "dsedge" then
         declare
            Count  : constant Natural := Natural (Int (6));
            K      : constant Positive := 7 + Count;
            Result : Unsigned_32;
         begin
            for J in 0 .. Count - 1 loop
               Edge_Buffer (J) := Unsigned_16 (Int (7 + J));
            end loop;
            Decode_Samples (Edge_State, Edge_Buffer, Count, Natural (Int (5)), Unsigned_32 (Int (4)), Result);
            Record_Int (Name, Int (K), Integer_64 (Result));
            Record_Int (Name & ".skip", Int (K + 1), Integer_64 (Edge_State.Preamble_Skip));
            Record_Int (Name & ".margin", Int (K + 2), Integer_64 (Edge_State.Min_Margin));
            Record_Int (Name & ".next", Int (K + 3), Integer_64 (Edge_State.Next_Margin_Check));
         end;
      elsif Name = "dserpm" then
         declare
            Value : Unsigned_32;
            Kind  : Telemetry_Kind;
         begin
            Decode_Value (Raw_Value (Int (4)), Int (6) = 1 or else (Unsigned_8 (Int (5)) and 16#FE#) /= 0, Value, Kind);
            Record_Int (Name, Int (7), Integer_64 (Value));
            Record_Int (Name & ".kind", Int (8), Integer_64 (Telemetry_Kind'Pos (Kind)));
         end;
      elsif Name = "dstlminit" then
         Init (Tlm, Natural (Int (4)), Positive (Int (5)), Int (6) = 2, Natural (Int (7)), Positive (Int (8)));
         Record_Result (Name & ".factor", Bits (9), To_Bits (Tlm.Erpm_To_Hz));
      elsif Name = "dstlm" then
         declare
            Op      : constant Integer_64 := Int (4);
            Count   : constant Natural := Natural (Int (5));
            K       : Positive := 7;
            Present : Boolean;
            Erpm_H  : Integer_16;
            Temp    : Unsigned_8;
            Cur     : Unsigned_16;
         begin
            Tlm.State := Raw_State'Val (Int (6));
            if Op = 0 then
               for M in 0 .. Count - 1 loop
                  Tlm.Motors (M).Raw := Raw_Value (Int (K));
                  K := K + 1;
               end loop;
               Update (Tlm);
            elsif Op = 1 then
               Clean (Tlm);
            end if;
            Record_Int (Name & ".state", Int (K), Integer_64 (Raw_State'Pos (Tlm.State)));
            Record_Result (Name & ".average", Bits (K + 1), To_Bits (Tlm.Rpm_Average));
            Record_Result (Name & ".minfreq", Bits (K + 2), To_Bits (Tlm.Min_Frequency));
            Record_Int (Name & ".active", Int (K + 3), Boolean'Pos (Active (Tlm)));
            K := K + 4;
            for M in 0 .. Count - 1 loop
               for Kind in Telemetry_Kind loop
                  Record_Int (Name & ".value", Int (K), Integer_64 (Tlm.Motors (M).Values (Kind)));
                  K := K + 1;
               end loop;
               Record_Int (Name & ".received", Int (K), Integer_64 (Tlm.Motors (M).Received));
               Record_Int (Name & ".maxtemp", Int (K + 1), Integer_64 (Tlm.Motors (M).Max_Temperature));
               Record_Result (Name & ".rpm", Bits (K + 2), To_Bits (Tlm.Rpm (M)));
               Record_Result (Name & ".freq", Bits (K + 3), To_Bits (Tlm.Frequency (M)));
               K := K + 4;
            end loop;
            Sensor_Data (Tlm, 0, Present, Erpm_H, Temp, Cur);
            Record_Int (Name & ".present", Int (K), Boolean'Pos (Present));
            Record_Int (Name & ".erpm16", Int (K + 1), Integer_64 (Erpm_H));
            Record_Int (Name & ".temp", Int (K + 2), Integer_64 (Temp));
            Record_Int (Name & ".current", Int (K + 3), Integer_64 (Cur));
            if K + 3 /= NF then
               Put_Line ("dstlm: consumed" & Integer'Image (K + 3) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      elsif Name = "dsqual" then
         Count_Packet (Quality_State, Int (4) = 1, Unsigned_32 (Int (5)));
         Record_Int (Name & ".packets", Int (7), Integer_64 (Quality_State.Packet_Sum));
         Record_Int (Name & ".invalids", Int (8), Integer_64 (Quality_State.Invalid_Sum));
         Record_Int (Name & ".last", Int (9), Integer_64 (Quality_State.Last_Bucket));
         for B in Bucket_Index loop
            Record_Int (Name & ".bucket", Int (10 + B), Integer_64 (Quality_State.Packets (B)));
            Record_Int (Name & ".invalid", Int (20 + B), Integer_64 (Quality_State.Invalids (B)));
         end loop;
         Record_Int (Name & ".percent", Int (30), Integer_64 (Invalid_Percent (Quality_State, Int (6) = 1)));
      elsif Name = "dsorder" then
         declare
            N     : constant Natural := Natural (Int (4));
            Order : Output_Order (0 .. N - 1);
         begin
            for J in 0 .. N - 1 loop
               Order (J) := Unsigned_8 (Int (5 + J));
            end loop;
            Validate_Order (Order);
            for J in 0 .. N - 1 loop
               Record_Int (Name, Int (5 + N + J), Integer_64 (Order (J)));
            end loop;
         end;
      else
         Put_Line ("unknown dshot case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_DShot_Line;

   function Hex_Chars (I : Positive) return String is
      S : constant String := Str (I);
      R : String (1 .. S'Length / 2);
   begin
      for K in R'Range loop
         R (K) := Character'Val (Natural'Value ("16#" & S (S'First + 2 * (K - 1) .. S'First + 2 * K - 1) & "#"));
      end loop;
      return R;
   end Hex_Chars;

   CRSF_Seq   : Integer_64 := -1;
   CT_State : Adaflight.CRSF_Telemetry.Telemetry;
   CRSF_Out   : Byte_Array (0 .. 1023) := (others => 0);

   --  The sources start at field K in the order the generator prints them.
   function CRSF_Sources (K : Positive) return Adaflight.CRSF_Telemetry.Sources is
      use Adaflight.CRSF_Telemetry;
      Src  : Sources;
      Name : constant String := Hex_Chars (K + 61);
   begin
      Src.GPS := (Latitude => I32 (K), Longitude => I32 (K + 1), Altitude_Cm => I32 (K + 2),
                  Ground_Speed => Interfaces.Unsigned_16 (Int (K + 3)),
                  Ground_Course => Interfaces.Unsigned_16 (Int (K + 4)),
                  Satellites => Interfaces.Unsigned_8 (Int (K + 5)), Fix => Int (K + 6) = 1,
                  Time => Unsigned_32 (Int (K + 7)),
                  Velocity_North => Interfaces.Integer_16 (Int (K + 8)),
                  Velocity_East => Interfaces.Integer_16 (Int (K + 9)),
                  Velocity_Down => Interfaces.Integer_16 (Int (K + 10)),
                  Horizontal_Accuracy => Unsigned_32 (Int (K + 11)), Vertical_Accuracy => Unsigned_32 (Int (K + 12)),
                  Speed_Accuracy => Unsigned_32 (Int (K + 13)), Heading_Accuracy => Unsigned_32 (Int (K + 14)),
                  HDOP => Interfaces.Unsigned_16 (Int (K + 15)), VDOP => Interfaces.Unsigned_16 (Int (K + 16)),
                  Date_Valid => Int (K + 17) = 1, Year => Interfaces.Unsigned_16 (Int (K + 18)),
                  Month => Interfaces.Unsigned_8 (Int (K + 19)), Day => Interfaces.Unsigned_8 (Int (K + 20)),
                  Hour => Interfaces.Unsigned_8 (Int (K + 21)), Minute => Interfaces.Unsigned_8 (Int (K + 22)),
                  Second => Interfaces.Unsigned_8 (Int (K + 23)), Millisecond => Interfaces.Unsigned_16 (Int (K + 24)));
      Src.Baro := (Pressure => I32 (K + 25), Temperature => I32 (K + 26), Altitude_Cm => Flt (K + 27));
      Src.Vario := Interfaces.Integer_16 (Int (K + 28));
      Src.Mag := (X => Flt (K + 29), Y => Flt (K + 30), Z => Flt (K + 31));
      Src.Battery := (Legacy_Voltage => Interfaces.Unsigned_16 (Int (K + 32)),
                      Cell_Voltage => Interfaces.Unsigned_16 (Int (K + 33)),
                      Amperage => I32 (K + 34), Drawn_Mah => I32 (K + 35),
                      Remaining_Percent => Interfaces.Unsigned_8 (Int (K + 36)),
                      Report_Cell_Voltage => Int (K + 37) = 1);
      Src.Attitude := (Pitch => Interfaces.Integer_16 (Int (K + 38)), Roll => Interfaces.Integer_16 (Int (K + 39)),
                       Yaw => Interfaces.Integer_16 (Int (K + 40)));
      Src.IMU := (Fresh => Int (K + 41) = 1, Gyro => (Flt (K + 42), Flt (K + 43), Flt (K + 44)),
                  Acc => (Flt (K + 45), Flt (K + 46), Flt (K + 47)), Acc_1G_Reciprocal => Flt (K + 48),
                  Temperature => Interfaces.Integer_16 (Int (K + 49)));
      Src.Flight := (Mode_Flags => Interfaces.Unsigned_16 (Bits (K + 50)), Armed => Int (K + 51) = 1,
                     Failsafe_Switch => Int (K + 52) = 1, Rescue_Switch => Int (K + 53) = 1,
                     Rescue_Plan => Int (K + 54) = 1, Position_Hold_Failure => Int (K + 55) = 1,
                     Airmode => Int (K + 56) = 1, Arming_Disabled => Int (K + 57) = 1,
                     GPS_Feature => Int (K + 58) = 1, Rescue_Configured => Int (K + 59) = 1,
                     Rescue_Min_Satellites => Interfaces.Unsigned_8 (Int (K + 60)));
      Src.Name (1 .. Name'Length) := Name;
      Src.Name_Last := Name'Length;
      return Src;
   end CRSF_Sources;

   --  Compares the frames written between two stream positions with the
   --  hex fields from K on, one frame per field, and returns the frame count.
   function CRSF_Frames (Name : String; From, To : Natural; K : Positive) return Natural is
      P     : Natural := From;
      Count : Natural := 0;
   begin
      while P < To loop
         declare
            Len  : constant Natural := Natural (CRSF_Out (P + 1)) + 2;
            Last : constant Natural := Natural'Min (P + Len - 1, To - 1);
         begin
            if K + Count <= NF then
               Record_Bytes (Name, Hex_Bytes (K + Count), CRSF_Out (P .. Last));
            else
               Record_Int (Name & ".extra", 0, 1);
            end if;
            Count := Count + 1;
            P := P + Len;
         end;
      end loop;
      return Count;
   end CRSF_Frames;

   procedure Check_CRSF_Telemetry_Line is
      use Adaflight.CRSF_Telemetry;
      use type Interfaces.Unsigned_8;
      use type Interfaces.Unsigned_16;
      Name : constant String := Str (1);
      S    : Adaflight.Stream_Buffers.Stream;
   begin
      if Int (2) /= CRSF_Seq then
         CRSF_Seq := Int (2);
         CT_State := (others => <>);
      end if;
      Adaflight.Stream_Buffers.Init (S, 0, 1024);
      if Name = "crsfinit" then
         declare
            Mask : constant Integer_64 := Int (4);
            Cfg  : constant Config :=
              (Gyro_Present => Mask mod 2 = 1, Acc_Present => (Mask / 2) mod 2 = 1,
               Baro_Present => (Mask / 4) mod 2 = 1,
               Mag_Present => (Mask / 8) mod 2 = 1, Disabled_Kinds => Bits (5), Voltage_Configured => Int (7) = 1,
               Amperage_Configured => Int (8) = 1, GPS_Feature => Int (9) = 1, Event_Driven => Int (10) = 1,
               Use_Negotiated_Baud => Int (11) = 1, Inertial_Frames => Int (12) = 1, Telemetry_Feature => Int (13) = 1);
            Count : constant Natural := Natural (Int (14));
         begin
            Init (CT_State, Cfg, True);
            Record_Int (Name & ".count", Int (14), Integer_64 (CT_State.Count));
            for J in 0 .. Natural'Min (Count, CT_State.Count) - 1 loop
               Record_Int (Name & ".slot", Int_Hex (15 + J), Integer_64 (CT_State.Schedule (J)));
            end loop;
            Record_Int (Name & ".timed", Int_Hex (15 + Count), Integer_64 (CT_State.Timed));
         end;
      elsif Name = "crsfstep" then
         declare
            Now      : constant Unsigned_32 := Unsigned_32 (Int (4));
            Src      : constant Sources := CRSF_Sources (11);
            K        : constant Positive := 73;
            Run      : Boolean;
            New_Baud : Unsigned_32;
            Mid      : Natural;
            Count    : Natural;
         begin
            if Int (8) = 1 then
               declare
                  Rate    : constant Unsigned_32 := Unsigned_32 (Int (9));
                  Payload : constant Byte_Array (0 .. 7) :=
                    (Command_General, Command_Speed_Proposal, Byte (Int (10)),
                     Byte (Interfaces.Shift_Right (Rate, 24) and 255), Byte (Interfaces.Shift_Right (Rate, 16) and 255),
                     Byte (Interfaces.Shift_Right (Rate, 8) and 255), Byte (Rate and 255), 0);
               begin
                  Process_Command (CT_State, Payload);
               end;
            end if;
            if Int (6) = 1 then
               Schedule_Response (CT_State);
            end if;
            if Int (7) = 1 then
               Schedule_Device_Info (CT_State);
            end if;
            Update_Check (CT_State, Now, Run);
            Negotiate (CT_State, Now, CRSF_Out, S, New_Baud);
            Mid := S.Next;
            Update (CT_State, Now, Src, CRSF_Out, S);
            Record_Int (Name & ".check", Int (K), Boolean'Pos (Run));
            Record_Int (Name & ".negotiating", Int (K + 1), Boolean'Pos (Negotiation_In_Progress (CT_State)));
            Record_Int (Name & ".desired", Int (K + 2), Integer_64 (Desired_Speed (CT_State)));
            Record_Int (Name & ".v3", Int (K + 3), Boolean'Pos (CT_State.V3_Running));
            Record_Int (Name & ".pending", Int (K + 4), Boolean'Pos (CT_State.Speed.Pending_Reply));
            Record_Int (Name & ".baud", Int (K + 5), Integer_64 (New_Baud));
            Record_Int (Name & ".devinfo", Int (K + 6), Boolean'Pos (CT_State.Device_Info_Pending));
            Record_Int (Name & ".response", Int (K + 7), Boolean'Pos (CT_State.Response_Pending));
            Count := CRSF_Frames (Name & ".frame", 0, S.Next, K + 10);
            Record_Int (Name & ".negotiation_frames", Int (K + 8),
                        Integer_64 (CRSF_Frames (Name & ".nframe", 0, Mid, K + 10)));
            Record_Int (Name & ".frames", Int (K + 9), Integer_64 (Count));
         end;
      elsif Name = "crsfframe" then
         declare
            Kind : constant String := Str (4);
            Src  : constant Sources := CRSF_Sources (5);
            K    : Positive := 67;
         begin
            if Kind = "gps" then
               Write_GPS (CRSF_Out, S, Src.GPS);
            elsif Kind = "gpstime" then
               Write_GPS_Time (CRSF_Out, S, Src.GPS);
            elsif Kind = "gpsext" then
               Write_GPS_Extended (CRSF_Out, S, Src.GPS);
            elsif Kind = "vario" then
               Write_Vario (CRSF_Out, S, Src.Vario);
            elsif Kind = "baro" then
               Write_Baro (CRSF_Out, S, Src.Baro);
            elsif Kind = "mag" then
               Write_Mag (CRSF_Out, S, Src.Mag);
            elsif Kind = "battery" then
               Write_Battery (CRSF_Out, S, Src.Battery);
            elsif Kind = "altitude" then
               Write_Altitude (CRSF_Out, S, Src.Baro, Src.Vario);
            elsif Kind = "heartbeat" then
               Write_Heartbeat (CRSF_Out, S);
            elsif Kind = "ping" then
               Write_Ping (CRSF_Out, S);
            elsif Kind = "attitude" then
               Write_Attitude (CRSF_Out, S, Src.Attitude);
            elsif Kind = "flightmode" then
               Write_Flight_Mode (CRSF_Out, S, Src.Flight, Src.GPS.Satellites, Src.GPS.Fix);
            elsif Kind = "deviceinfo" then
               Write_Device_Info (CRSF_Out, S, Src.Name (1 .. Src.Name_Last));
            elsif Kind = "accgyro" then
               Write_Inertial (CRSF_Out, S, Unsigned_32 (Int (67)), Src.IMU);
               K := 68;
            else
               Put_Line ("unknown crsf frame " & Kind);
               Failures := Failures + 1;
            end if;
            Record_Int (Name & "." & Kind & ".length", Int (K), Integer_64 (S.Next));
            if S.Next > 0 then
               Record_Bytes (Name & "." & Kind, Hex_Bytes (K + 1), CRSF_Out (0 .. S.Next - 1));
            end if;
         end;
      elsif Name = "crsfpack" then
         Record_Int (Name & ".altitude", Int (6), Integer_64 (Packed_Altitude (I32 (4))));
         Record_Int (Name & ".climb", Int (7), Integer_64 (Packed_Climb (Interfaces.Integer_16 (Int (5)))));
         Record_Int (Name & ".radians", Int (9), Integer_64 (Radians_10000 (Interfaces.Integer_16 (Int (8)))));
      elsif Name = "crsfmsp" then
         declare
            Payload : constant Byte_Array := Hex_Bytes (5);
         begin
            Write_MSP_Response (CRSF_Out, S, Address_Radio_Transmitter, Payload);
            Record_Int (Name & ".length", Int (6), Integer_64 (S.Next));
            Record_Bytes (Name, Hex_Bytes (7), CRSF_Out (0 .. S.Next - 1));
         end;
      else
         Put_Line ("unknown crsf case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_CRSF_Telemetry_Line;

   ESC_Seq   : Integer_64 := -1;
   ESC_State : Adaflight.ESC_Sensor.Sensor;

   procedure Record_ESC_Reading (Name : String; K : Positive; R : Adaflight.ESC_Sensor.Reading) is
   begin
      Record_Int (Name & ".age", Int (K), Integer_64 (R.Data_Age));
      Record_Int (Name & ".temperature", Int (K + 1), Integer_64 (R.Temperature));
      Record_Int (Name & ".voltage", Int (K + 2), Integer_64 (R.Voltage));
      Record_Int (Name & ".current", Int (K + 3), Integer_64 (R.Current));
      Record_Int (Name & ".consumption", Int (K + 4), Integer_64 (R.Consumption));
      Record_Int (Name & ".rpm", Int (K + 5), Integer_64 (R.Rpm));
   end Record_ESC_Reading;

   procedure Check_ESC_Line is
      use Adaflight.ESC_Sensor;
      Name    : constant String := Str (1);
      Count   : constant Motor_Count := Motor_Count (Int (5));
      Event   : constant Integer_64 := Int (7);
      Motor   : constant Natural := Natural (Int (8));
      Fed     : constant Byte_Array := Hex_Bytes (16);
      Request : Boolean;
      R       : Reading;
   begin
      if Int (2) /= ESC_Seq then
         ESC_Seq := Int (2);
         ESC_State := (others => <>);
         Init (ESC_State);
      end if;
      if Event = 1 and then Motor in Motor_Index then
         Set_External (ESC_State, Motor,
                       (Data_Age => Interfaces.Unsigned_8 (Int (9)), Temperature => Interfaces.Unsigned_8 (Int (10)),
                        Voltage => Interfaces.Unsigned_16 (Int (11)), Current => I32 (12), Consumption => I32 (13),
                        Rpm => Interfaces.Integer_16 (Int (14))));
      elsif Event = 2 and then Motor in Motor_Index then
         External_Age (ESC_State, Motor);
      elsif Event = 3 then
         Init (ESC_State);
      end if;
      for B of Fed loop
         Receive (ESC_State, B);
      end loop;
      Process (ESC_State, Unsigned_32 (Int (4)), Count, Int (6) = 1, Request);
      Record_Int (Name & ".requests", Int (17), Boolean'Pos (Request));
      if Request then
         Record_Int (Name & ".requested", Int (18), Integer_64 (ESC_State.Motor));
      end if;
      Record_Int (Name & ".state", Int (19), Integer_64 (Trigger_State'Pos (ESC_State.State)));
      Record_Int (Name & ".motor", Int (20), Integer_64 (ESC_State.Motor));
      Record_Int (Name & ".trigger", Int (21), Integer_64 (ESC_State.Trigger_Time_Ms));
      Record_Int (Name & ".position", Int (22), Integer_64 (ESC_State.Position));
      Record_Int (Name & ".size", Int (23), Integer_64 (ESC_State.Size));
      Record_Int (Name & ".stale", Int (26), Boolean'Pos (ESC_State.Combined_Stale));
      Combined_Reading (ESC_State, Count, R);
      Record_ESC_Reading (Name & ".combined", 27, R);
      for M in 0 .. Count - 1 loop
         Record_ESC_Reading (Name & ".motor", 33 + 6 * M, ESC_State.Data (M));
      end loop;
   end Check_ESC_Line;

   SP_Seq     : Integer_64 := -1;
   SP_Stream  : Adaflight.SmartPort_Telemetry.Stream;
   SP_Base    : Adaflight.SmartPort_Telemetry.Inputs;
   SP_Pending : Byte_Array (0 .. 4095) := (others => 0);
   SP_Count   : Natural := 0;
   SP_ESC     : Boolean := False;

   procedure Check_SmartPort_Line is
      use Adaflight.SmartPort_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "sportinit" then
         declare
            Disabled : constant Integer_64 := Int (3);
            B        : Build_Inputs;
         begin
            SP_Seq := Int (2);
            SP_Stream := (others => <>);
            SP_Count := 0;
            for Se in Sensor loop
               B.Enabled (Se) := (Disabled / 2 ** Sensor'Pos (Se)) mod 2 = 0;
            end loop;
            B.Voltage_Configured := Int (6) = 1;
            B.Amperage_Configured := Int (7) = 1;
            B.Acc_Present := Int (8) = 1;
            B.Baro_Present := Int (9) = 1;
            B.GPS_Feature := Int (10) = 1;
            SP_Base := (others => <>);
            SP_Base.Report_Cell_Voltage := Int (4) = 1;
            SP_Base.Pid_Values := Int (5) = 1;
            SP_Base.GPS_Feature := Int (10) = 1;
            SP_ESC := Int (11) = 1;
            SP_Base.Motors := Motor_Count (Int (12));
            SP_Base.Pole_Count := Interfaces.Unsigned_8 (Int (13));
            SP_Base.Acc_1G_Rec := Flt (14);
            SP_Base.Capacity_Set := Int (15) > 0;
            SP_Base.P := (Interfaces.Unsigned_8 (Int (42)), Interfaces.Unsigned_8 (Int (46)),
                          Interfaces.Unsigned_8 (Int (50)));
            SP_Base.I := (Interfaces.Unsigned_8 (Int (43)), Interfaces.Unsigned_8 (Int (47)),
                          Interfaces.Unsigned_8 (Int (51)));
            SP_Base.D := (Interfaces.Unsigned_8 (Int (44)), Interfaces.Unsigned_8 (Int (48)),
                          Interfaces.Unsigned_8 (Int (52)));
            SP_Base.Rates := (Interfaces.Unsigned_8 (Int (45)), Interfaces.Unsigned_8 (Int (49)),
                              Interfaces.Unsigned_8 (Int (53)));
            Build (SP_Stream, B);
            Record_Int (Name & ".size", Int (16), Integer_64 (SP_Stream.Size));
            for I in 1 .. 20 loop
               Record_Int (Name & ".id", Int (16 + I), Integer_64 (SP_Stream.Table (I)));
            end loop;
            Record_Int (Name & ".escsize", Int (37), Integer_64 (SP_Stream.ESC_Size));
            for I in 1 .. Max_ESC_Values loop
               Record_Int (Name & ".escid", Int (37 + I), Integer_64 (SP_Stream.ESC_Table (I)));
            end loop;
         end;
      elsif Name = "sportstep" then
         if Int (2) /= SP_Seq then
            Put_Line ("smartport step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp      : Inputs := SP_Base;
            Modes    : constant Integer_64 := Int (20);
            Rx       : constant Byte_Array := SP_Pending (0 .. SP_Count - 1) & Hex_Bytes (69);
            O        : Output;
            Consumed : Natural;

            function Flag (Bit : Natural) return Boolean is ((Modes / 2 ** Bit) mod 2 = 1);
         begin
            Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (4));
            Inp.Cell_Voltage_Cv := Interfaces.Unsigned_16 (Int (5));
            Inp.Amperage_Ca := I32 (7);
            Inp.Mah_Drawn := I32 (8);
            Inp.Percent_Remaining := Interfaces.Unsigned_8 (Int (9));
            Inp.Altitude_Cm := I32 (10);
            Inp.Vario_Cms := Interfaces.Integer_16 (Int (11));
            Inp.Pitch := Interfaces.Integer_16 (Int (12));
            Inp.Roll := Interfaces.Integer_16 (Int (13));
            Inp.Yaw := Interfaces.Integer_16 (Int (14));
            Inp.Acc_X := Flt (15);
            Inp.Acc_Y := Flt (16);
            Inp.Acc_Z := Flt (17);
            Inp.Arming_Disabled := Int (18) = 1;
            Inp.Armed := Int (19) mod 2 = 1;
            Inp.Angle_Like := Flag (0) or else Flag (3) or else Flag (5);
            Inp.Horizon := Flag (1);
            Inp.Passthru := Flag (8);
            Inp.Mag := Flag (2);
            Inp.Headfree := Flag (6);
            Inp.GPS_Present := Int (21) = 1;
            Inp.Fix := Int (22) = 1;
            Inp.Fix_Home := Int (23) = 1;
            Inp.Pdop := Interfaces.Unsigned_16 (Int (24));
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (25));
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (26));
            Inp.Lat := I32 (27);
            Inp.Lon := I32 (28);
            Inp.Home_Distance_M := Interfaces.Unsigned_16 (Int (29));
            Inp.Core_Temperature := Interfaces.Integer_16 (Int (30));
            Inp.GPS_Altitude_Cm := I32 (31);
            for M in 0 .. 7 loop
               Inp.ESC (M) := (Present     => SP_ESC and then M < Inp.Motors,
                               Voltage     => Interfaces.Unsigned_16 (Int (32 + 4 * M)),
                               Current     => I32 (33 + 4 * M),
                               Temperature => Interfaces.Unsigned_8 (Int (34 + 4 * M)),
                               Rpm         => Interfaces.Integer_16 (Int (35 + 4 * M)));
            end loop;
            Inp.ESC_Combined := (Present     => SP_ESC,
                                 Voltage     => Interfaces.Unsigned_16 (Int (64)),
                                 Current     => I32 (65),
                                 Temperature => Interfaces.Unsigned_8 (Int (66)),
                                 Rpm         => Interfaces.Integer_16 (Int (67)));
            Update (SP_Stream, Inp, Rx, 9, O, Consumed);
            Record_Int (Name & ".consumed", Int (70), Integer_64 (Consumed));
            Record_Int (Name & ".index", Int (71), Integer_64 (SP_Stream.Index));
            Record_Int (Name & ".escindex", Int (72), Integer_64 (SP_Stream.ESC_Index));
            Record_Bytes (Name & ".tx", Hex_Bytes (74), O.Tx (0 .. O.Count - 1));
            SP_Count := Rx'Length - Consumed;
            SP_Pending (0 .. SP_Count - 1) := Rx (Rx'First + Consumed .. Rx'Last);
         end;
      else
         Put_Line ("unknown smartport case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SmartPort_Line;

   RC_Seq     : Integer_64 := -1;
   RC_Dev     : Adaflight.RunCam_Device.Device;
   RC_Set     : Adaflight.RunCam_Device.Settings;
   RC_Pending : Byte_Array (0 .. 8191) := (others => 0);
   RC_Count   : Natural := 0;

   procedure Check_RunCam_Line is
      use Adaflight.RunCam_Device;
      Name : constant String := Str (1);

      function Flag (B : Boolean) return Integer_64 is (if B then 1 else 0);

      procedure Record_State (B : Positive) is
         Version : constant Integer_64 := Int (B + 5);
         Active  : constant Boolean := RC_Dev.Wait.Active;
      begin
         Record_Int (Name & ".wait", Int (B), Flag (Active));
         Record_Int (Name & ".waitcmd", Int (B + 1), (if Active then Integer_64 (RC_Dev.Wait.Command) else 0));
         Record_Int (Name & ".waitrecv", Int (B + 2), (if Active then Integer_64 (RC_Dev.Wait.Received) else 0));
         Record_Int (Name & ".retries", Int (B + 3), (if Active then Integer_64 (RC_Dev.Wait.Retries) else 0));
         Record_Int (Name & ".timeout", Int (B + 4), (if Active then Integer_64 (RC_Dev.Wait.Timeout_At) else 0));
         Record_Int (Name & ".version", (if Version > 2 then 2 else Version),
                     Integer_64 (Protocol'Pos (RC_Dev.Device_Info.Version)));
         Record_Int (Name & ".features", Int (B + 6), Integer_64 (RC_Dev.Device_Info.Features));
         Record_Int (Name & ".ready", Int (B + 7), Flag (RC_Dev.Ready));
         Record_Int (Name & ".inmenu", Int (B + 8), Flag (RC_Dev.In_Menu));
         Record_Int (Name & ".pressed", Int (B + 9), Flag (RC_Dev.Button_Pressed));
         Record_Int (Name & ".waiting", Int (B + 10), Flag (RC_Dev.Waiting_Response));
         for I in 1 .. 3 loop
            Record_Int (Name & ".switch", Int (B + 10 + I), Flag (RC_Dev.Switch_Active (I)));
         end loop;
         Record_Int (Name & ".reqstate", Int (B + 14), Integer_64 (RC_Dev.Req.State));
         Record_Int (Name & ".reqdone", Int (B + 15), Flag (RC_Dev.Req.Done));
         Record_Int (Name & ".reqcmd", Int (B + 16), Integer_64 (RC_Dev.Req.Command));
         Record_Int (Name & ".reqlast", Int (B + 17), Integer_64 (RC_Dev.Req.Last_Byte_Ms));
      end Record_State;
   begin
      if Name = "rcdinit" then
         declare
            E : Events;
         begin
            RC_Seq := Int (2);
            RC_Count := 0;
            RC_Set := (Protocol_Setting => (case Int (6) is when 0 => Split, when 1 => V1_0, when others => Unknown),
                       Feature          => Interfaces.Unsigned_16 (Int (5)),
                       Init_Attempts    => Natural (Int (3)),
                       Init_Interval_Ms => Interfaces.Unsigned_32 (Int (4)));
            Init (RC_Dev, RC_Set, Int (7) = 1, Interfaces.Unsigned_32 (Int (8)), E);
            Record_Bytes (Name & ".tx", Hex_Bytes (10), E.Line.Tx (0 .. E.Line.Count - 1));
            Record_State (11);
         end;
      elsif Name = "rcdstep" then
         if Int (2) /= RC_Seq then
            Put_Line ("rcdevice step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : Inputs;
            Rx  : constant Byte_Array := RC_Pending (0 .. RC_Count - 1) & Hex_Bytes (20);
            E   : Events;
         begin
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (4));
            Inp.Armed := Int (5) = 1;
            Inp.Blocked := Int (6) = 1;
            Inp.Menu_Open := Int (7) = 1;
            Inp.Sticks_Disabled := Int (8) = 1;
            Inp.Camera := (Int (9) = 1, Int (10) = 1, Int (11) = 1);
            Inp.Throttle := Float (Int (12));
            Inp.Roll := Float (Int (13));
            Inp.Pitch := Float (Int (14));
            Inp.Yaw := Float (Int (15));
            Inp.Att_Roll := Interfaces.Integer_16 (Int (16));
            Inp.Att_Pitch := Interfaces.Integer_16 (Int (17));
            Inp.Att_Yaw := Interfaces.Integer_16 (Int (18));
            Update (RC_Dev, RC_Set, Inp, Rx, E);
            Record_Bytes (Name & ".tx", Hex_Bytes (22), E.Line.Tx (0 .. E.Line.Count - 1));
            Record_Int (Name & ".beep", Int (23), Integer_64 (Beep'Pos (E.Sound)));
            Record_Int (Name & ".consumed", Int (24), Integer_64 (E.Consumed));
            Record_State (25);
            RC_Count := Rx'Length - E.Consumed;
            RC_Pending (0 .. RC_Count - 1) := Rx (Rx'First + E.Consumed .. Rx'Last);
         end;
      else
         Put_Line ("unknown rcdevice case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_RunCam_Line;

   FH_Seq    : Integer_64 := -1;
   FH_Stream : Adaflight.FrSky_Hub_Telemetry.Stream;
   FH_Set    : Adaflight.FrSky_Hub_Telemetry.Settings;

   procedure Check_FrSky_Hub_Line is
      use Adaflight.FrSky_Hub_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "fhubinit" then
         declare
            Disabled : constant Integer_64 := Int (3);
         begin
            FH_Seq := Int (2);
            FH_Stream := (others => <>);
            FH_Set := (others => <>);
            for Se in Sensor loop
               FH_Set.Enabled (Se) := (Disabled / 2 ** Sensor'Pos (Se)) mod 2 = 0;
            end loop;
            FH_Set.Format := (if Int (4) = 0 then DMS else NMEA);
            FH_Set.Unit := (if Int (5) = 0 then Imperial else Metric);
            FH_Set.Precision := (if Int (6) = 0 then Low else High);
            FH_Set.Report_Cell_Voltage := Int (7) = 1;
            FH_Set.No_Fix_Latitude := No_Fix_Coordinate (Int (8));
            FH_Set.No_Fix_Longitude := No_Fix_Coordinate (Int (9));
            FH_Set.Acc_Present := Int (10) = 1;
            FH_Set.Altitude_Present := Int (11) = 1;
            FH_Set.GPS_Present := Int (12) = 1;
            FH_Set.Mag_Present := Int (13) = 1;
            FH_Set.Pole_Count := Interfaces.Unsigned_8 (Int (14));
            FH_Set.Acc_1G_Rec := Flt (15);
         end;
      elsif Name = "fhubstep" then
         if Int (2) /= FH_Seq then
            Put_Line ("frsky hub step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : Inputs;
            O   : Output;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (5));
            Inp.Acc_X := Flt (6);
            Inp.Acc_Y := Flt (7);
            Inp.Acc_Z := Flt (8);
            Inp.ESC_Valid := Int (9) = 1;
            Inp.ESC_Rpm := Interfaces.Integer_16 (Int (10));
            Inp.ESC_Temperature := Interfaces.Unsigned_8 (Int (11));
            Inp.Fix := Int (12) = 1;
            Inp.Lat := I32 (13);
            Inp.Lon := I32 (14);
            Inp.Alt_Cm := I32 (15);
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (16));
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (17));
            Inp.Pdop := Interfaces.Unsigned_16 (Int (18));
            Inp.Voltage_Configured := Int (19) = 1;
            Inp.Amperage_Configured := Int (20) = 1;
            Inp.Cell_Count := Interfaces.Unsigned_8 (Int (21));
            Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (22));
            Inp.Amperage_Ca := I32 (23);
            Inp.Capacity := Interfaces.Unsigned_16 (Int (24));
            Inp.Percent := Interfaces.Unsigned_8 (Int (25));
            Inp.Mah_Drawn := I32 (26);
            Inp.Vario_Cms := Interfaces.Integer_16 (Int (27));
            Inp.Altitude_Cm := I32 (28);
            Inp.Yaw := Interfaces.Integer_16 (Int (29));
            Update (FH_Stream, FH_Set, Inp, O);
            Record_Bytes (Name & ".tx", Hex_Bytes (31), O.Tx (0 .. O.Count - 1));
         end;
      else
         Put_Line ("unknown frsky hub case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_FrSky_Hub_Line;

   IB_Seq  : Integer_64 := -1;
   IB_Link : Adaflight.IBus_Telemetry.Link;
   IB_Set  : Adaflight.IBus_Telemetry.Settings;

   procedure Check_IBus_Telemetry_Line is
      use Adaflight.IBus_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "ibusinit" then
         IB_Seq := Int (2);
         IB_Link := (others => <>);
         IB_Set := (others => <>);
         for I in Sensor_Table'Range loop
            IB_Set.Sensors (I) := Interfaces.Unsigned_8 (Int (3 + I));
         end loop;
         IB_Set.Report_Cell_Voltage := Int (18) = 1;
         IB_Set.Acc_1G_Rec := Flt (19);
      elsif Name = "ibusstep" then
         if Int (2) /= IB_Seq then
            Put_Line ("ibus telemetry step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp   : Inputs;
            Modes : constant Integer_64 := Int (14);
            O     : Output;

            function Flag (Bit : Natural) return Boolean is ((Modes / 2 ** Bit) mod 2 = 1);
         begin
            Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (4));
            Inp.Cell_Cv := Interfaces.Unsigned_16 (Int (5));
            Inp.Amperage_Ca := I32 (6);
            Inp.Capacity := Interfaces.Unsigned_16 (Int (7));
            Inp.Percent := Interfaces.Unsigned_8 (Int (8));
            Inp.Mah_Drawn := I32 (9);
            Inp.Armed := Int (10) = 1;
            Inp.Throttle_Low := Int (11) = 1;
            Inp.Motor_Stop := Int (12) = 1;
            Inp.Throttle := Flt (13);
            Inp.Angle_Like := Flag (0) or else Flag (3) or else Flag (5);
            Inp.Passthru := Flag (8);
            Inp.Headfree_Or_Mag := Flag (2) or else Flag (6);
            Inp.Horizon := Flag (1);
            Inp.Failsafe := Flag (10);
            Inp.Acc_X := Flt (15);
            Inp.Acc_Y := Flt (16);
            Inp.Acc_Z := Flt (17);
            Inp.Roll := Interfaces.Integer_16 (Int (18));
            Inp.Pitch := Interfaces.Integer_16 (Int (19));
            Inp.Yaw := Interfaces.Integer_16 (Int (20));
            Inp.Baro_Present := Int (21) = 1;
            Inp.Baro_Temperature := I32 (22);
            Inp.Baro_Pressure := I32 (23);
            Inp.Baro_Altitude := Flt (24);
            Inp.Gyro_Temperature := Interfaces.Integer_16 (Int (25));
            Inp.Vario_Cms := Interfaces.Integer_16 (Int (26));
            Inp.GPS_Present := Int (27) = 1;
            Inp.Fix := Int (28) = 1;
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (29));
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (30));
            Inp.Ground_Course := Interfaces.Unsigned_16 (Int (31));
            Inp.Lat := I32 (32);
            Inp.Lon := I32 (33);
            Inp.Alt_Cm := I32 (34);
            Inp.Distance_Home := Interfaces.Unsigned_16 (Int (35));
            Update (IB_Link, IB_Set, Inp, Hex_Bytes (37), O);
            Record_Bytes (Name & ".tx", Hex_Bytes (39), O.Tx (0 .. O.Count - 1));
            Record_Int (Name & ".base", Int (40), Integer_64 (IB_Link.Base_Address));
            Record_Int (Name & ".ignore", Int (41), Integer_64 (IB_Link.Ignore));
            Record_Bytes (Name & ".window", Hex_Bytes (42), IB_Link.Window);
         end;
      else
         Put_Line ("unknown ibus telemetry case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_IBus_Telemetry_Line;

   HT_Seq     : Integer_64 := -1;
   HT_Link    : Adaflight.HoTT_Telemetry.Link;
   HT_Set     : Adaflight.HoTT_Telemetry.Settings;
   HT_Pending : Byte_Array (0 .. 4095) := (others => 0);
   HT_Count   : Natural := 0;

   procedure Check_HoTT_Line is
      use Adaflight.HoTT_Telemetry;
      Name : constant String := Str (1);

      function State (I : Positive) return Battery_State is
        (case Int (I) is when 0 => OK, when 1 => Warning, when 2 => Critical, when 3 => Not_Present,
         when others => Init_State);
   begin
      if Name = "hottinit" then
         HT_Seq := Int (2);
         HT_Count := 0;
         HT_Set := (Alarm_Interval_S => Interfaces.Unsigned_8 (Int (3)), GPS_Present => Int (4) = 1);
         Init (HT_Link);
         Record_Bytes (Name & ".eam", Hex_Bytes (5), HT_Link.EAM);
         Record_Bytes (Name & ".gps", Hex_Bytes (6), HT_Link.GPS);
      elsif Name = "hottstep" then
         if Int (2) /= HT_Seq then
            Put_Line ("hott step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : Inputs;
            Rx  : constant Byte_Array := HT_Pending (0 .. HT_Count - 1) & Hex_Bytes (21);
            O   : Output;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (5));
            Inp.Voltage_Dv := Interfaces.Unsigned_16 (Int (6));
            Inp.Voltage_State := State (7);
            Inp.Consumption_State := State (8);
            Inp.Amperage_Ca := I32 (9);
            Inp.Mah_Drawn := I32 (10);
            Inp.Altitude_Cm := I32 (11);
            Inp.Vario_Cms := Interfaces.Integer_16 (Int (12));
            Inp.Fix := Int (13) = 1;
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (14));
            Inp.Lat := I32 (15);
            Inp.Lon := I32 (16);
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (17));
            Inp.Distance_Home := Interfaces.Unsigned_16 (Int (18));
            Inp.Direction_Home := Interfaces.Integer_16 (Int (19));
            Update (HT_Link, HT_Set, Inp, Rx, O);
            if O.Sent then
               Record_Bytes (Name & ".tx", Hex_Bytes (23), Byte_Array'(0 => O.B));
            else
               Record_Int (Name & ".tx", Int (22), 0);
            end if;
            Record_Int (Name & ".consumed", Int (24), Integer_64 (O.Consumed));
            Record_Int (Name & ".sending", Int (25), (if HT_Link.Sending then 1 else 0));
            Record_Int (Name & ".kind", Int (26), Integer_64 (Message_Kind'Pos (HT_Link.Pending)));
            Record_Int (Name & ".position", Int (27),
                        (if HT_Link.Pending = No_Message then 0 else Integer_64 (HT_Link.Position)));
            Record_Int (Name & ".remaining", Int (28), Integer_64 (HT_Link.Remaining));
            Record_Int (Name & ".crc", Int (29), Integer_64 (HT_Link.Crc));
            Record_Int (Name & ".lastrequest", Int (30), Integer_64 (HT_Link.Last_Request_Us));
            Record_Int (Name & ".lastprepared", Int (31), Integer_64 (HT_Link.Last_Prepared_Us));
            Record_Int (Name & ".lastalarm", Int (32), Integer_64 (HT_Link.Last_Alarm_Ms));
            Record_Bytes (Name & ".eam", Hex_Bytes (33), HT_Link.EAM);
            Record_Bytes (Name & ".gps", Hex_Bytes (34), HT_Link.GPS);
            HT_Count := Rx'Length - O.Consumed;
            HT_Pending (0 .. HT_Count - 1) := Rx (Rx'First + O.Consumed .. Rx'Last);
         end;
      else
         Put_Line ("unknown hott case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_HoTT_Line;

   GT_Seq  : Integer_64 := -1;
   GT_Link : Adaflight.GHST_Telemetry.Link;
   GT_Set  : Adaflight.GHST_Telemetry.Settings;

   procedure Check_GHST_Telemetry_Line is
      use Adaflight.GHST_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "ghstinit" then
         declare
            Disabled : constant Integer_64 := Int (3);
            function Enabled (Bit : Natural) return Boolean is ((Disabled / 2 ** Bit) mod 2 = 0);
         begin
            GT_Seq := Int (2);
            GT_Set := (Voltage_Enabled      => Enabled (0),
                       Current_Enabled      => Enabled (1),
                       Fuel_Enabled         => Enabled (2),
                       Altitude_Enabled     => Enabled (10),
                       Lat_Long_Enabled     => Enabled (12),
                       Ground_Speed_Enabled => Enabled (13),
                       Heading_Enabled      => Enabled (9),
                       Report_Cell_Voltage  => Int (4) = 1,
                       Voltage_Configured   => Int (5) = 1,
                       Amperage_Configured  => Int (6) = 1,
                       GPS_Feature          => Int (7) = 1,
                       Baro_Present         => Int (8) = 1,
                       Mag_Present          => Int (9) = 1);
            Init (GT_Link, GT_Set);
            Record_Int (Name & ".count", Int (10), Integer_64 (GT_Link.Count));
            for I in Schedule_Index loop
               Record_Int (Name & ".entry", Int (11 + I),
                           (if I < GT_Link.Count then 2 ** Frame_Kind'Pos (GT_Link.Table (I)) else 0));
            end loop;
         end;
      elsif Name = "ghststep" then
         if Int (2) /= GT_Seq then
            Put_Line ("ghst telemetry step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : Inputs;
            O   : Output;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (5));
            Inp.Cell_Cv := Interfaces.Unsigned_16 (Int (6));
            Inp.Amperage_Ca := I32 (7);
            Inp.Mah_Drawn := I32 (8);
            Inp.Armed := Int (9) = 1;
            Inp.Lat := I32 (10);
            Inp.Lon := I32 (11);
            Inp.Alt_Cm := I32 (12);
            Inp.Fix := Int (13) = 1;
            Inp.Fix_Home := Int (14) = 1;
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (15));
            Inp.Ground_Course := Interfaces.Unsigned_16 (Int (16));
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (17));
            Inp.Distance_Home := Interfaces.Unsigned_16 (Int (18));
            Inp.Direction_Home := Interfaces.Integer_16 (Int (19));
            Inp.Altitude_Cm := I32 (21);
            Inp.Yaw := Interfaces.Integer_16 (Int (22));
            Update (GT_Link, GT_Set, Inp, O);
            Record_Bytes (Name & ".tx", Hex_Bytes (24), O.Tx (0 .. O.Count - 1));
         end;
      else
         Put_Line ("unknown ghst telemetry case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_GHST_Telemetry_Line;

   TP_Seq   : Integer_64 := -1;
   TP_Sched : Adaflight.Transponder.Schedule;

   procedure Check_Transponder_Line is
      use Adaflight.Transponder;
      Name : constant String := Str (1);
   begin
      if Name = "tpcode" then
         declare
            P      : constant Provider := Provider'Val (Int (3));
            Toggle : constant Interfaces.Unsigned_16 := Interfaces.Unsigned_16 (Int (4));
            S      : constant String := Str (15);
            Data   : Code;
            R      : Pattern;
         begin
            if Int (2) /= TP_Seq then
               TP_Seq := Int (2);
               TP_Sched := (others => <>);
            end if;
            for I in Code'Range loop
               Data (I) := Interfaces.Unsigned_8 (Int (5 + I));
            end loop;
            Encode (P, Data, Toggle, R);
            Record_Int (Name & ".length", Int (14), Integer_64 (R.Length));
            if Integer_64 (R.Length) = Int (14) and then S'Length = R.Length then
               for I in 0 .. R.Length - 1 loop
                  Record_Int (Name & ".toggle",
                              (case S (S'First + I) is
                                 when '0' => 0,
                                 when '1' => Integer_64 (Toggle),
                                 when others => Integer_64 (Toggle) mod 256),
                              Integer_64 (R.Buffer (I)));
               end loop;
            end if;
         end;
      elsif Name = "tpstep" then
         if Int (2) /= TP_Seq then
            Put_Line ("transponder step without its code");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Transmit : Boolean;
         begin
            Update (TP_Sched, Provider'Val (Int (6)), Interfaces.Unsigned_32 (Int (4)), Int (5) = 1, Transmit);
            Record_Int (Name & ".transmit", Int (7), (if Transmit then 1 else 0));
            Record_Int (Name & ".next", Int (8), Integer_64 (TP_Sched.Next_Update_Us));
         end;
      else
         Put_Line ("unknown transponder case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Transponder_Line;

   SX_Seq    : Integer_64 := -1;
   SX_Stream : Adaflight.SRXL_Telemetry.Stream;
   SX_Set    : Adaflight.SRXL_Telemetry.Settings;

   procedure Check_SRXL_Telemetry_Line is
      use Adaflight.SRXL_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "srxlinit" then
         SX_Seq := Int (2);
         SX_Stream := (others => <>);
         SX_Set := (Report_Cell_Voltage => Int (3) = 1, GPS_Feature => Int (4) = 1);
      elsif Name = "srxlstep" then
         if Int (2) /= SX_Seq then
            Put_Line ("srxl telemetry step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp   : Inputs;
            O     : Output;
            Text  : constant Byte_Array := Hex_Bytes (30);
            Flags : constant String := Str (31);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Buffer_Empty := Int (5) = 1;
            Inp.Menu_On_Display := Int (6) = 1;
            Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (7));
            Inp.Cell_Cv := Interfaces.Unsigned_16 (Int (8));
            Inp.Core_Temperature := Interfaces.Integer_16 (Int (9));
            Inp.ESC_Valid := Int (10) = 1;
            Inp.ESC_Rpm := Interfaces.Integer_16 (Int (11));
            Inp.Dshot_Telemetry := Int (12) = 1;
            Inp.Dshot_Rpm := Flt (13);
            Inp.Amperage_Ca := I32 (14);
            Inp.Mah_Drawn := I32 (15);
            Inp.Fix := Int (16) = 1;
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (17));
            Inp.Lat := I32 (18);
            Inp.Lon := I32 (19);
            Inp.Alt_Cm := I32 (20);
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (21));
            Inp.Ground_Course := Interfaces.Unsigned_16 (Int (22));
            Inp.Pdop := Interfaces.Unsigned_16 (Int (23));
            if Int (24) = 1 then
               Put_Char (SX_Stream, Natural (Int (25)), Natural (Int (26)), Byte (Int (27)));
            end if;
            Update (SX_Stream, SX_Set, Inp, O);
            Record_Bytes (Name & ".tx", Hex_Bytes (29), O.Tx (0 .. O.Count - 1));
            if Text'Length = Rows * Columns then
               for R in Row_Index loop
                  for Col in Column_Index loop
                     Record_Int (Name & ".text", Integer_64 (Text (R * Columns + Col)),
                                 Integer_64 (SX_Stream.Text (R, Col)));
                  end loop;
                  Record_Int (Name & ".linesent", (if Flags (Flags'First + R) = '1' then 1 else 0),
                              (if SX_Stream.Line_Sent (R) then 1 else 0));
               end loop;
            end if;
         end;
      else
         Put_Line ("unknown srxl telemetry case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SRXL_Telemetry_Line;

   OS_Seq  : Integer_64 := -1;
   OS_Link : Adaflight.FrSky_OSD.Link;

   procedure Check_FrSky_OSD_Line is
      use Adaflight.FrSky_OSD;
      Name : constant String := Str (1);

      function Col (I : Positive) return Color is (Color'Val (Int (I)));

      procedure Record_State (B : Positive) is
      begin
         Record_Int (Name & ".initialized", Int (B), (if OS_Link.Initialized then 1 else 0));
         Record_Int (Name & ".major", Int (B + 1), Integer_64 (OS_Link.Major));
         Record_Int (Name & ".minor", Int (B + 2), Integer_64 (OS_Link.Minor));
         Record_Int (Name & ".rows", Int (B + 3), Integer_64 (OS_Link.Rows));
         Record_Int (Name & ".columns", Int (B + 4), Integer_64 (OS_Link.Columns));
         Record_Int (Name & ".width", Int (B + 5), Integer_64 (OS_Link.Width));
         Record_Int (Name & ".height", Int (B + 6), Integer_64 (OS_Link.Height));
         Record_Int (Name & ".nextinfo", Int (B + 7), Integer_64 (OS_Link.Next_Info_Ms));
         Record_Int (Name & ".sendpos", Int (B + 8), Integer_64 (OS_Link.Send_Pos));
         Record_Int (Name & ".recvstate", Int (B + 9), Integer_64 (Receive_State'Pos (OS_Link.Recv_State)));
         Record_Int (Name & ".recvpos", Int (B + 10), Integer_64 (OS_Link.Recv_Pos));
         Record_Int (Name & ".expected", Int (B + 11), Integer_64 (OS_Link.Expected));
         Record_Int (Name & ".fontaddr", Int (B + 12), Integer_64 (OS_Link.Font_Address));
      end Record_State;
   begin
      if Name = "osdinit" then
         declare
            O : Output;
         begin
            OS_Seq := Int (2);
            Init (OS_Link, Int (3) = 1, Interfaces.Unsigned_32 (Int (4)), O);
            Record_Bytes (Name & ".tx", Hex_Bytes (5), O.Tx (0 .. O.Count - 1));
            Record_State (6);
         end;
      elsif Name = "osdstep" then
         if Int (2) /= OS_Seq then
            Put_Line ("frsky osd step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Op     : constant Integer_64 := Int (4);
            Now    : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (5));
            S      : constant Byte_Array := Hex_Bytes (12);
            Before : constant Byte_Array := Hex_Bytes (13);
            Reply  : constant Byte_Array := Hex_Bytes (14);
            O      : Output;
            OK     : Boolean := False;

            function Arg (I : Positive) return Integer is (Integer (Int (I)));
         begin
            case Op is
               when 0 => Update (OS_Link, Before, Now, O);
               when 1 =>
                  Begin_Transaction (OS_Link, (Profiled => Arg (6) mod 2 = 1, Reset_Drawing => Arg (6) / 2 mod 2 = 1),
                                     O);
               when 2 => Commit_Transaction (OS_Link, O);
               when 3 => Flush (OS_Link, O);
               when 4 => Draw_String_In_Grid (OS_Link, Interfaces.Unsigned_8 (Arg (6)), Interfaces.Unsigned_8 (Arg (7)),
                                              S, O);
               when 5 => Draw_Char_In_Grid (OS_Link, Interfaces.Unsigned_8 (Arg (6)), Interfaces.Unsigned_8 (Arg (7)),
                                            Interfaces.Unsigned_16 (Arg (8)), O);
               when 6 => Clear_Screen (OS_Link, O);
               when 7 => Set_Stroke_Color (OS_Link, Col (6), O);
               when 8 => Set_Fill_Color (OS_Link, Col (6), O);
               when 9 => Set_Stroke_And_Fill_Color (OS_Link, Col (6), O);
               when 10 => Set_Color_Inversion (OS_Link, Arg (6) = 1, O);
               when 11 => Set_Pixel (OS_Link, Arg (6), Arg (7), Col (8), O);
               when 12 => Set_Pixel_To_Stroke_Color (OS_Link, Arg (6), Arg (7), O);
               when 13 => Set_Pixel_To_Fill_Color (OS_Link, Arg (6), Arg (7), O);
               when 14 => Set_Stroke_Width (OS_Link, Interfaces.Unsigned_8 (Arg (6)), O);
               when 15 => Set_Line_Outline_Type (OS_Link, Interfaces.Unsigned_8 (Arg (6)), O);
               when 16 => Set_Line_Outline_Color (OS_Link, Col (6), O);
               when 17 => Clip_To_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 18 => Clear_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 19 => Reset_Drawing_State (OS_Link, O);
               when 20 => Draw_Character (OS_Link, Arg (6), Arg (7), Interfaces.Unsigned_16 (Arg (8)),
                                          Interfaces.Unsigned_8 (Arg (9)), O);
               when 21 => Draw_Character_Mask (OS_Link, Arg (6), Arg (7), Interfaces.Unsigned_16 (Arg (8)), Col (9),
                                               Interfaces.Unsigned_8 (Arg (10)), O);
               when 22 => Draw_String (OS_Link, Arg (6), Arg (7), S, Interfaces.Unsigned_8 (Arg (8)), O);
               when 23 => Draw_String_Mask (OS_Link, Arg (6), Arg (7), S, Col (8), Interfaces.Unsigned_8 (Arg (9)), O);
               when 24 => Move_To_Point (OS_Link, Arg (6), Arg (7), O);
               when 25 => Stroke_Line_To_Point (OS_Link, Arg (6), Arg (7), O);
               when 26 => Stroke_Triangle (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), Arg (10), Arg (11), O);
               when 27 => Fill_Triangle (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), Arg (10), Arg (11), O);
               when 28 => Fill_Stroke_Triangle (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), Arg (10), Arg (11), O);
               when 29 => Stroke_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 30 => Fill_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 31 => Fill_Stroke_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 32 => Stroke_Ellipse_In_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 33 => Fill_Ellipse_In_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 34 => Fill_Stroke_Ellipse_In_Rect (OS_Link, Arg (6), Arg (7), Arg (8), Arg (9), O);
               when 35 => Ctm_Reset (OS_Link, O);
               when 36 => Ctm_Set (OS_Link, Flt (6), Flt (7), Flt (8), Flt (9), Flt (10), Flt (11), O);
               when 37 => Ctm_Translate (OS_Link, Flt (6), Flt (7), O);
               when 38 => Ctm_Scale (OS_Link, Flt (6), Flt (7), O);
               when 39 => Ctm_Rotate (OS_Link, Flt (6), O);
               when 40 => Context_Push (OS_Link, O);
               when 41 => Context_Pop (OS_Link, O);
               when 42 =>
                  Read_Font_Character (OS_Link, Interfaces.Unsigned_16 (Arg (6)), Before, Reply, O, OK);
                  Record_Int (Name & ".ok", Int (16), (if OK then 1 else 0));
                  if OK then
                     Record_Bytes (Name & ".chr", Hex_Bytes (17), OS_Link.Font);
                  end if;
               when 43 =>
                  Write_Font_Character (OS_Link, Interfaces.Unsigned_16 (Arg (6)), S, Before, Reply, O);
               when others =>
                  Put_Line ("unknown frsky osd op");
                  Failures := Failures + 1;
            end case;
            Record_Bytes (Name & ".tx", Hex_Bytes (15), O.Tx (0 .. O.Count - 1));
            Record_State (18);
         end;
      else
         Put_Line ("unknown frsky osd case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_FrSky_OSD_Line;

   LS_Seq    : Integer_64 := -1;
   LS_Set    : Adaflight.LED_Strip.Settings;
   LS_Layout : Adaflight.LED_Strip.Layout;
   LS_Strip  : Adaflight.LED_Strip.Strip;

   procedure Check_LED_Strip_Line is
      use Adaflight.LED_Strip;
      Name : constant String := Str (1);

      function Text_Of (I : Positive) return String is
         B : constant Byte_Array := Hex_Bytes (I);
         R : String (1 .. B'Length);
      begin
         for K in R'Range loop
            R (K) := Character'Val (B (B'First + K - 1));
         end loop;
         return R;
      end Text_Of;

      procedure Record_Output (I : Positive) is
         Expected : constant Byte_Array := Hex_Bytes (I);
      begin
         if Expected'Length = 3 * Max_Leds then
            for K in Led_Index loop
               Record_Int (Name & ".r", Integer_64 (Expected (3 * K)), Integer_64 (LS_Strip.Output (K).R));
               Record_Int (Name & ".g", Integer_64 (Expected (3 * K + 1)), Integer_64 (LS_Strip.Output (K).G));
               Record_Int (Name & ".b", Integer_64 (Expected (3 * K + 2)), Integer_64 (LS_Strip.Output (K).B));
            end loop;
         else
            Record_Int (Name & ".rgblength", Integer_64 (Expected'Length), 3 * Max_Leds);
         end if;
      end Record_Output;
   begin
      if Name = "ledcfg" then
         declare
            Cfg : Interfaces.Unsigned_32;
            OK  : Boolean;
         begin
            if Int (2) /= LS_Seq then
               LS_Seq := Int (2);
               LS_Set := (others => <>);
               for I in Color_Index loop
                  LS_Set.Colors (I) := (case I is
                                          when 0 => (0, 0, 0), when 1 => (0, 255, 255), when 2 => (0, 0, 255),
                                          when 3 => (15, 0, 255), when 4 => (50, 0, 255), when 5 => (100, 0, 255),
                                          when 6 => (115, 0, 255), when 7 => (125, 0, 255), when 8 => (180, 0, 255),
                                          when 9 => (210, 0, 255), when 10 => (240, 0, 255), when 11 => (270, 0, 255),
                                          when 12 => (300, 0, 255), when 13 => (330, 0, 255), when others => (0, 0, 0));
               end loop;
            end if;
            Parse_Led (Text_Of (4), Cfg, OK);
            Record_Int (Name & ".ok", Int (5), (if OK then 1 else 0));
            Record_Int (Name & ".cfg", Int (6), Integer_64 (Cfg));
            LS_Set.Leds (Led_Index (Int (3))) := Cfg;
         end;
      elsif Name = "ledcolor" then
         declare
            C  : Adaflight.Color.HSV;
            OK : Boolean;
         begin
            Parse_Color (Text_Of (4), C, OK);
            Record_Int (Name & ".ok", Int (5), (if OK then 1 else 0));
            Record_Int (Name & ".h", Int (6), Integer_64 (C.H));
            Record_Int (Name & ".s", Int (7), Integer_64 (C.S));
            Record_Int (Name & ".v", Int (8), Integer_64 (C.V));
            LS_Set.Colors (Color_Index (Int (3))) := C;
         end;
      elsif Name = "ledinit" then
         declare
            Modes    : constant Byte_Array := Hex_Bytes (14);
            Specials : constant Byte_Array := Hex_Bytes (15);
         begin
            if Int (2) /= LS_Seq then
               LS_Seq := Int (2);
               LS_Set := (others => <>);
            end if;
            LS_Set.Visual_Beeper := Int (3) = 1;
            LS_Set.Prof := (case Int (4) is when 0 => Race, when 1 => Beacon, when others => Status);
            LS_Set.Race_Color := Named_Color (Int (5));
            LS_Set.Beacon_Color := Named_Color (Int (6));
            LS_Set.Beacon_Period := Period_Ms (Int (7));
            LS_Set.Beacon_Percent := Interfaces.Unsigned_8 (Int (8));
            LS_Set.Visual_Beeper_Color := Named_Color (Int (9));
            LS_Set.Brightness := Brightness_Percent (Int (10));
            LS_Set.Rainbow_Delta := Interfaces.Unsigned_16 (Int (11));
            LS_Set.Rainbow_Freq := Interfaces.Unsigned_16 (Int (12));
            LS_Set.Aux_Channel := Channel_Index (Int (13));
            for M in Mode_Id loop
               for D in Direction_Id loop
                  LS_Set.Modes (M) (D) :=
                    Color_Index (Modes (Mode_Id'Pos (M) * 6 + Direction_Id'Pos (D)));
               end loop;
            end loop;
            for Sp in Special_Id loop
               LS_Set.Specials (Sp) := Color_Index (Specials (Special_Id'Pos (Sp)));
            end loop;
            LS_Layout := Evaluate (LS_Set);
            Record_Int (Name & ".count", Int (16), Integer_64 (LS_Layout.Count));
            Record_Int (Name & ".ring", Int (17), Integer_64 (LS_Layout.Ring));
            Record_Int (Name & ".larson", Int (18), Integer_64 (LS_Layout.Larson));
            Record_Int (Name & ".seqlen", Int (19), Integer_64 (LS_Layout.Ring_Seq_Len));
            Record_Int (Name & ".ynorth", Int (20), Integer_64 (LS_Layout.Highest_Y_North));
            Record_Int (Name & ".ysouth", Int (21), Integer_64 (LS_Layout.Lowest_Y_South));
            Record_Int (Name & ".xwest", Int (22), Integer_64 (LS_Layout.Highest_X_West));
            Record_Int (Name & ".xeast", Int (23), Integer_64 (LS_Layout.Lowest_X_East));
            declare
               Mask : Integer_64 := 0;
            begin
               for T in Timer_Id loop
                  if LS_Layout.Disabled (T) then
                     Mask := Mask + 2 ** Timer_Id'Pos (T);
                  end if;
               end loop;
               Record_Int (Name & ".disabled", Int (24), Mask);
            end;
            Record_Int (Name & ".gpsbars", Int (25), Integer_64 (LS_Layout.GPS_Bars));
            Record_Int (Name & ".batterybars", Int (26), Integer_64 (LS_Layout.Battery_Bars));
            Init (LS_Strip, LS_Set, LS_Layout);
            Record_Output (27);
         end;
      elsif Name = "ledstep" then
         if Int (2) /= LS_Seq then
            Put_Line ("led strip step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp     : Inputs;
            Flags   : constant Integer_64 := Int (13);
            Updated : Boolean;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (5));
            Inp.Led_Low := Int (6) = 1;
            Inp.Beeper_Box := Int (7) = 1;
            Inp.Armed := Int (8) = 1;
            Inp.Arming_Disabled := Int (9) = 1;
            Inp.Failsafe := Int (10) = 1;
            Inp.Crash_Flip := Int (11) = 1;
            Inp.Beeper_On := Int (12) = 1;
            Inp.Headfree := Flags mod 2 = 1;
            Inp.Mag := (Flags / 2) mod 2 = 1;
            Inp.Horizon := (Flags / 4) mod 2 = 1;
            Inp.Angle := (Flags / 8) mod 2 = 1;
            Inp.Battery := (case Int (14) is when 0 => OK, when 1 => Warning, when 2 => Critical, when 3 => Not_Present,
                            when others => Init_State);
            Inp.Voltage_Meter := Int (15) = 1;
            Inp.Battery_Percent := Interfaces.Unsigned_8 (Int (16));
            Inp.Rssi_Percent := Interfaces.Unsigned_8 (Int (17));
            Inp.Rx_Signal := Int (18) = 1;
            Inp.GPS_Present := Int (19) = 1;
            Inp.Fix := Int (20) = 1;
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (21));
            Inp.Min_Sats := Interfaces.Unsigned_8 (Int (22));
            Inp.Altitude_Cm := I32 (23);
            Inp.Roll_Command := Flt (24);
            Inp.Pitch_Command := Flt (25);
            Inp.Aux := Flt (26);
            Inp.Throttle := Flt (27);
            Update (LS_Strip, LS_Set, LS_Layout, Inp, Updated);
            Record_Int (Name & ".updated", Int (28), (if Updated then 1 else 0));
            Record_Output (29);
         end;
      else
         Put_Line ("unknown led strip case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_LED_Strip_Line;

   RF_Seq    : Integer_64 := -1;
   RF_Sensor : Adaflight.Rangefinder.Sensor;

   procedure Check_Rangefinder_Line is
      use Adaflight.Rangefinder;
      Name : constant String := Str (1);
   begin
      if Name = "rfinit" then
         RF_Seq := Int (2);
         Init (RF_Sensor, (Max_Range_Cm => Range_Cm (Int (3)), Cone_Extended_Decidegrees => Decidegrees (Int (4))),
               Interfaces.Unsigned_32 (Int (5)));
         Record_Result (Name & ".maxtiltcos", Bits (6), To_Bits (RF_Sensor.Max_Tilt_Cos));
         Record_Int (Name & ".maxalt", Int (7), Integer_64 (RF_Sensor.Max_Alt_With_Tilt_Cm));
         Record_Int (Name & ".cfalt", Int (8), Integer_64 (RF_Sensor.Cf_Altitude_Cm));
      elsif Name = "rfstep" then
         if Int (2) /= RF_Seq then
            Put_Line ("rangefinder step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Processed : Boolean;
            Now_Ms    : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (5));
         begin
            Process (RF_Sensor, Interfaces.Unsigned_32 (Int (4)), Now_Ms, Reading (Int (6)), Flt (7), Processed);
            Record_Int (Name & ".processed", Int (8), (if Processed then 1 else 0));
            Record_Int (Name & ".raw", Int (9), Integer_64 (RF_Sensor.Raw_Altitude));
            Record_Int (Name & ".calc", Int (10), Integer_64 (RF_Sensor.Calculated_Altitude));
            Record_Int (Name & ".snr", Int (11), Integer_64 (RF_Sensor.Snr));
            Record_Int (Name & ".reached", Int (12), (if RF_Sensor.Threshold_Reached then 1 else 0));
            Record_Int (Name & ".dynamic", Int (13), Integer_64 (RF_Sensor.Dynamic_Threshold));
            Record_Int (Name & ".lastvalid", Int (14), Integer_64 (RF_Sensor.Last_Valid_Ms));
            Record_Int (Name & ".lastdata", Int (15), Integer_64 (RF_Sensor.Last_Data_Us));
            Record_Int (Name & ".interval", Int (16), Integer_64 (RF_Sensor.Interval_Us));
            Record_Int (Name & ".healthy", Int (17), (if Is_Healthy (RF_Sensor, Now_Ms) then 1 else 0));
            Record_Int (Name & ".valid", Int (18), (if Surface_Altitude_Valid (RF_Sensor) then 1 else 0));
         end;
      else
         Put_Line ("unknown rangefinder case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Rangefinder_Line;

   OF_Seq    : Integer_64 := -1;
   OF_Sensor : Adaflight.Optical_Flow.Sensor;

   procedure Check_Optical_Flow_Line is
      use Adaflight.Optical_Flow;
      Name : constant String := Str (1);
   begin
      if Name = "ofinit" then
         OF_Seq := Int (2);
         Init (OF_Sensor, (Rotation_Degrees => Interfaces.Unsigned_16 (Int (3)), Flip_X => Int (4) /= 0),
               Flt (7), Flt (8), Gyro_Delay (Int (5)), Interfaces.Unsigned_32 (Int (6)));
         Record_Int (Name & ".quality", Int (9), Integer_64 (OF_Sensor.Quality));
         Record_Int (Name & ".stamp", Int (10), Integer_64 (OF_Sensor.Time_Stamp_Us));
      elsif Name = "ofstep" then
         if Int (2) /= OF_Seq then
            Put_Line ("optical flow step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            D      : constant Sample := (Time_Stamp_Us => Interfaces.Unsigned_32 (Int (5)),
                                         Quality       => Interfaces.Integer_16 (Int (6)),
                                         Flow_X        => Flt (7),
                                         Flow_Y        => Flt (8));
            Now_Us : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (4));
         begin
            Process (OF_Sensor, D, Flt (9), Flt (10));
            Record_Int (Name & ".quality", Int (11), Integer_64 (OF_Sensor.Quality));
            Record_Result (Name & ".rawx", Bits (12), To_Bits (OF_Sensor.Raw_Flow.X));
            Record_Result (Name & ".rawy", Bits (13), To_Bits (OF_Sensor.Raw_Flow.Y));
            Record_Result (Name & ".procx", Bits (14), To_Bits (OF_Sensor.Processed_Flow.X));
            Record_Result (Name & ".procy", Bits (15), To_Bits (OF_Sensor.Processed_Flow.Y));
            Record_Int (Name & ".xvalid", Int (16), (if OF_Sensor.X_Valid then 1 else 0));
            Record_Int (Name & ".yvalid", Int (17), (if OF_Sensor.Y_Valid then 1 else 0));
            Record_Int (Name & ".stamp", Int (18), Integer_64 (OF_Sensor.Time_Stamp_Us));
            Record_Int (Name & ".healthy", Int (19), (if Is_Healthy (OF_Sensor, Now_Us) then 1 else 0));
         end;
      else
         Put_Line ("unknown optical flow case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Optical_Flow_Line;

   PT_Seq    : Integer_64 := -1;
   PT_Config : Adaflight.Pitot.Settings;
   PT_Sensor : Adaflight.Pitot.Sensor;

   procedure Check_Pitot_Line is
      use Adaflight.Pitot;
      Name : constant String := Str (1);
   begin
      if Name = "ptinit" then
         PT_Seq := Int (2);
         PT_Config := (Hardware => Source'Val (Int (3)));
         Init (PT_Sensor, PT_Config, Int (4) /= 0);
         Record_Int (Name & ".i2cready", Int (5), (if PT_Sensor.I2C_Ready then 1 else 0));
      elsif Name = "ptstep" then
         if Int (2) /= PT_Seq then
            Put_Line ("pitot step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : constant Inputs := (Now_Us          => Interfaces.Unsigned_32 (Int (4)),
                                      Armed           => Int (5) /= 0,
                                      I2C_Read        => Int (6) /= 0,
                                      I2C_Pressure    => Flt (7),
                                      I2C_Temperature => Flt (8),
                                      Can_Frame       => Int (9) /= 0,
                                      Can_Pressure    => Flt (10),
                                      Can_Temperature => Flt (11),
                                      Can_Update_Us   => Interfaces.Unsigned_32 (Int (12)));
         begin
            if Int (13) /= 0 then
               Start_Calibration (PT_Sensor);
            end if;
            Update (PT_Sensor, PT_Config, Inp);
            Record_Int (Name & ".active", Int (14), Integer_64 (Source'Pos (PT_Sensor.Active)));
            Record_Result (Name & ".airspeed", Bits (15), To_Bits (PT_Sensor.Airspeed));
            Record_Result (Name & ".diff", Bits (16), To_Bits (PT_Sensor.Diff_Pressure));
            Record_Result (Name & ".temp", Bits (17), To_Bits (PT_Sensor.Temperature));
            Record_Result (Name & ".zero", Bits (18), To_Bits (PT_Sensor.Pressure_Zero));
            Record_Int (Name & ".calcount", Int (19), Integer_64 (PT_Sensor.Calibration_Count));
            Record_Int (Name & ".calibrated", Int (20), (if Is_Calibrated (PT_Sensor) then 1 else 0));
            Record_Int (Name & ".lastvalid", Int (21), Integer_64 (PT_Sensor.Last_Valid_Us));
         end;
      else
         Put_Line ("unknown pitot case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Pitot_Line;

   RTC_Seq    : Integer_64 := -1;
   RTC_Config : Adaflight.RTC.Settings;
   RTC_Clock  : Adaflight.RTC.Clock;

   procedure Check_RTC_Line is
      use Adaflight.RTC;
      Name : constant String := Str (1);
      Now  : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (4));

      function Date_Arg return Date_Time is
        ((Year    => Interfaces.Unsigned_16 (Int (6)),
          Month   => Interfaces.Unsigned_8 (Int (7)),
          Day     => Interfaces.Unsigned_8 (Int (8)),
          Hours   => Interfaces.Unsigned_8 (Int (9)),
          Minutes => Interfaces.Unsigned_8 (Int (10)),
          Seconds => Interfaces.Unsigned_8 (Int (11)),
          Millis  => Interfaces.Unsigned_16 (Int (12))));

      procedure Expect_Date (D : Date_Time) is
      begin
         Record_Int (Name & ".year", Int (16), Integer_64 (D.Year));
         Record_Int (Name & ".month", Int (17), Integer_64 (D.Month));
         Record_Int (Name & ".day", Int (18), Integer_64 (D.Day));
         Record_Int (Name & ".hours", Int (19), Integer_64 (D.Hours));
         Record_Int (Name & ".minutes", Int (20), Integer_64 (D.Minutes));
         Record_Int (Name & ".seconds", Int (21), Integer_64 (D.Seconds));
         Record_Int (Name & ".millis", Int (22), Integer_64 (D.Millis));
      end Expect_Date;

      procedure Expect_Clock is
         D  : Date_Time;
         OK : Boolean;
      begin
         Get_Date_Time (RTC_Clock, Now, D, OK);
         Record_Int (Name & ".ok", Int (14), (if OK then 1 else 0));
         Record_Int (Name & ".t", Int (15), (if OK then Get (RTC_Clock, Now) else 0));
         Expect_Date (D);
      end Expect_Clock;

      procedure Expect_Text (Text : Formatted; Length : Natural; Valid : Boolean) is
         Actual : Byte_Array (0 .. Length - 1);
      begin
         for I in Actual'Range loop
            Actual (I) := Interfaces.Unsigned_8 (Character'Pos (Text (I + 1)));
         end loop;
         Record_Int (Name & ".valid", Int (23), (if Valid then 1 else 0));
         Record_Bytes (Name & ".text", Hex_Bytes (24), Actual);
      end Expect_Text;

      Text   : Formatted;
      Length : Natural;
      Valid  : Boolean;
   begin
      if Name = "rtcinit" then
         RTC_Seq := Int (2);
         RTC_Config := (Zone => Zone_Minutes (Int (3)));
         RTC_Clock := (Started => 0);
         Record_Int (Name & ".hastime", Int (5), (if Has_Time (RTC_Clock) then 1 else 0));
      elsif Name = "rtcstep" then
         if Int (2) /= RTC_Seq then
            Put_Line ("clock step without its start");
            Failures := Failures + 1;
            return;
         end if;
         case Int (5) is
            when 0 =>
               Set (RTC_Clock, Int (6), Now);
               Expect_Clock;
            when 1 =>
               Set_Date_Time (RTC_Clock, Date_Arg, Now);
               Expect_Clock;
            when 2 =>
               Format_UTC (Date_Arg, Text, Length, Valid);
               Expect_Text (Text, Length, Valid);
            when 3 =>
               Format_Local (Date_Arg, RTC_Config, Text, Length, Valid);
               Expect_Text (Text, Length, Valid);
            when 4 =>
               Format_Local_Short (Date_Arg, RTC_Config, Text, Length, Valid);
               Expect_Text (Text, Length, Valid);
            when 5 =>
               Expect_Date (UTC_To_Local (Date_Arg, RTC_Config));
            when 6 =>
               Format_UTC (Date_Arg, Text, Length, Valid);
               Expect_Text (Text, Length, Valid);
               declare
                  Position : Natural;
                  Found    : Boolean;
               begin
                  Split (Text (1 .. Length), Position, Found);
                  Record_Int (Name & ".pos", Int (25), (if Found then Integer_64 (Position) else 0));
               end;
            when 7 =>
               declare
                  High, Low : Interfaces.Unsigned_32;
                  T         : Time;
                  OK        : Boolean;
               begin
                  Persist_Write (RTC_Clock, Now, Zone_Minutes (Int (6)), High, Low);
                  Record_Int (Name & ".high", Int (26), Integer_64 (High));
                  Record_Int (Name & ".low", Int (27), Integer_64 (Low));
                  Persist_Read (High, Low, T, OK);
                  Record_Int (Name & ".ok", Int (14), (if OK then 1 else 0));
                  Record_Int (Name & ".t", Int (15), (if OK then T else 0));
               end;
            when others =>
               Expect_Clock;
         end case;
      else
         Put_Line ("unknown clock case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_RTC_Line;

   ADC_Seq     : Integer_64 := -1;
   ADC_Cal     : Adaflight.Internal_ADC.Calibration;
   ADC_Sampler : Adaflight.Internal_ADC.Sampler;

   procedure Check_Internal_ADC_Line is
      use Adaflight.Internal_ADC;
      Name : constant String := Str (1);

      procedure Expect_State (First : Positive) is
      begin
         Record_Int (Name & ".vrefmv", Int (First), Integer_64 (ADC_Sampler.Vref_Mv));
         Record_Int (Name & ".temperature", Int (First + 1), Integer_64 (ADC_Sampler.Core_Temperature));
         Record_Int (Name & ".vrefvalue", Int (First + 2), Integer_64 (ADC_Sampler.Vref_Value));
         Record_Int (Name & ".tempvalue", Int (First + 3), Integer_64 (ADC_Sampler.Temp_Value));
      end Expect_State;
   begin
      if Name = "adcinit" then
         ADC_Seq := Int (2);
         ADC_Cal := (Vrefint_Cal => Interfaces.Integer_32 (Int (3)),
                     Ts_Cal1     => Interfaces.Integer_32 (Int (4)),
                     Ts_Slope_K  => Interfaces.Integer_32 (Int (5)));
         Init (ADC_Sampler);
         for I in 0 .. 8 loop
            Process (ADC_Sampler, ADC_Cal, ADC_Value (Int (6 + 2 * I)), ADC_Value (Int (7 + 2 * I)));
         end loop;
         Expect_State (24);
      elsif Name = "adcstep" then
         if Int (2) /= ADC_Seq then
            Put_Line ("internal ADC step without its start");
            Failures := Failures + 1;
            return;
         end if;
         if Int (4) = 0 then
            Process (ADC_Sampler, ADC_Cal, ADC_Value (Int (5)), ADC_Value (Int (6)));
         end if;
         Expect_State (7);
      else
         Put_Line ("unknown internal ADC case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Internal_ADC_Line;

   ST_Seq     : Integer_64 := -1;
   ST_Config  : Adaflight.Flight_Stats.Settings;
   ST_Totals  : Adaflight.Flight_Stats.Totals;
   ST_Tracker : Adaflight.Flight_Stats.Tracker;

   procedure Check_Flight_Stats_Line is
      use Adaflight.Flight_Stats;
      Name : constant String := Str (1);
   begin
      if Name = "stinit" then
         ST_Seq := Int (2);
         ST_Config := (Min_Armed_Time_S => Interfaces.Integer_8 (Int (3)),
                       Save_Move_Limit  => Interfaces.Unsigned_8 (Int (4)));
         ST_Totals := (Flights  => Interfaces.Unsigned_32 (Int (5)),
                       Time_S   => Interfaces.Unsigned_32 (Int (6)),
                       Dist_M   => Interfaces.Unsigned_32 (Int (7)),
                       Mah_Used => Interfaces.Unsigned_32 (Int (8)));
         ST_Tracker := (Arm_Ms => 0, Arm_Distance_Cm => 0, Save_Required => False);
      elsif Name = "ststep" then
         if Int (2) /= ST_Seq then
            Put_Line ("statistics step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Now       : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Int (4));
            Scheduled : Boolean := False;
            Written   : Boolean := False;
         begin
            case Int (5) is
               when 0 =>
                  On_Arm (ST_Tracker, Now, Interfaces.Unsigned_32 (Int (6)));
               when 1 =>
                  On_Disarm (ST_Tracker, ST_Config, ST_Totals, Now, Interfaces.Unsigned_32 (Int (6)),
                             Interfaces.Integer_32 (Int (7)), Scheduled);
               when others =>
                  declare
                     Action : Save_Action;
                  begin
                     Write (ST_Tracker, ST_Config, Int (6) /= 0, Int (7) /= 0, Flt (8), Flt (9), Flt (10), Action);
                     Written := Action = Save;
                     Scheduled := Action = Retry;
                  end;
            end case;
            Record_Int (Name & ".flights", Int (12), Integer_64 (ST_Totals.Flights));
            Record_Int (Name & ".time", Int (13), Integer_64 (ST_Totals.Time_S));
            Record_Int (Name & ".dist", Int (14), Integer_64 (ST_Totals.Dist_M));
            Record_Int (Name & ".mah", Int (15), Integer_64 (ST_Totals.Mah_Used));
            Record_Int (Name & ".pending", Int (16), (if ST_Tracker.Save_Required then 1 else 0));
            Record_Int (Name & ".scheduled", Int (17), (if Scheduled then 1 else 0));
            Record_Int (Name & ".written", Int (18), (if Written then 1 else 0));
            Record_Int (Name & ".beeped", Int (19), (if Written then 1 else 0));
         end;
      else
         Put_Line ("unknown statistics case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Flight_Stats_Line;

   WL_Seq         : Integer_64 := -1;
   WL_Config      : Adaflight.Wing_Launch.Settings;
   WL_Launch      : Adaflight.Wing_Launch.Launch;
   WL_Angle_Roll  : Adaflight.Wing_Launch.Angle_Deg := 0.0;
   WL_Angle_Pitch : Adaflight.Wing_Launch.Angle_Deg := 0.0;

   procedure Check_Wing_Launch_Line is
      use Adaflight.Wing_Launch;
      Name : constant String := Str (1);

      function U8 (I : Positive) return Interfaces.Unsigned_8 is (Interfaces.Unsigned_8 (Int (I)));
      function U16 (I : Positive) return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16 (Int (I)));
      function Flag (I : Positive) return Boolean is (Int (I) /= 0);
   begin
      if Name = "wlinit" then
         WL_Seq := Int (2);
         WL_Config := (Climb_Angle_Deg        => U8 (3),
                       Max_Angle_Deg          => U8 (4),
                       Detect_Accel_Decig     => U8 (5),
                       Detect_Velocity_Cms    => U16 (6),
                       Detect_Time_Ms         => U16 (7),
                       Idle_Throttle_Percent  => U8 (8),
                       Idle_Delay_Ms          => U16 (9),
                       Throttle_Percent       => U8 (10),
                       Motor_Delay_Ms         => U16 (11),
                       Spinup_Time_Ms         => U16 (12),
                       Min_Time_Ms            => U16 (13),
                       Timeout_Ms             => U16 (14),
                       Max_Altitude_M         => U16 (15),
                       End_Time_Ms            => U16 (16),
                       Abort_Deadband_Percent => U8 (17),
                       Abort_Angle_Deg        => U8 (18));
         Init (WL_Launch);
         WL_Angle_Roll := 0.0;
         WL_Angle_Pitch := 0.0;
      elsif Name = "wlstep" then
         if Int (2) /= WL_Seq then
            Put_Line ("wing launch step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : constant Inputs := (Now_Us              => Interfaces.Unsigned_32 (Int (5)),
                                      Launch_Mode         => Flag (9),
                                      Failsafe_Active     => Flag (10),
                                      Throttle_Low        => Flag (11),
                                      Roll_Deflection     => Flt (12),
                                      Pitch_Deflection    => Flt (13),
                                      Attitude_Roll       => Interfaces.Integer_16 (Int (14)),
                                      Attitude_Pitch      => Interfaces.Integer_16 (Int (15)),
                                      Acc_X               => Flt (16),
                                      Acc_Y               => Flt (17),
                                      Acc_1G_Rec          => Flt (18),
                                      Acc_Magnitude       => Flt (19),
                                      Gyro_Roll           => Flt (20),
                                      Gyro_Pitch          => Flt (21),
                                      Gyro_Yaw            => Flt (22),
                                      Cos_Tilt            => Flt (23),
                                      Altitude_Available  => Flag (24),
                                      Altitude_Cm         => Flt (25),
                                      Altitude_Derivative => Flt (26),
                                      GPS_Fix             => Flag (27),
                                      Num_Sat             => U8 (28),
                                      Ground_Speed_Cms    => U16 (29));
         begin
            case Int (4) is
               when 0 =>
                  Arm (WL_Launch, Flag (6), Flag (7), Flag (8), Inp);
               when 1 =>
                  Init (WL_Launch);
               when 2 =>
                  Switch_Off (WL_Launch);
               when others =>
                  Update (WL_Launch, WL_Config, Inp, WL_Angle_Roll, WL_Angle_Pitch);
            end case;
            Record_Int (Name & ".state", Int (30), Integer_64 (State'Pos (WL_Launch.Current)));
            Record_Int (Name & ".latched", Int (31), (if WL_Launch.Latched then 1 else 0));
            Record_Result (Name & ".throttle", Bits (32), To_Bits (WL_Launch.Throttle));
            Record_Result (Name & ".pitch", Bits (33), To_Bits (WL_Launch.Pitch_Target_Deg));
            Record_Result (Name & ".handover", Bits (34), To_Bits (WL_Launch.Handover));
            Record_Int (Name & ".exit", Int (35), Integer_64 (Exit_Reason'Pos (WL_Launch.Why)));
            Record_Int (Name & ".active", Int (36), (if Is_Active (WL_Launch) then 1 else 0));
            Record_Int (Name & ".prelaunch", Int (37), (if Is_Pre_Launch (WL_Launch) then 1 else 0));
            Record_Int (Name & ".holds", Int (38), (if Holds_Iterm (WL_Launch) then 1 else 0));
            Record_Result (Name & ".angleroll", Bits (39), To_Bits (WL_Angle_Roll));
            Record_Result (Name & ".anglepitch", Bits (40), To_Bits (WL_Angle_Pitch));
         end;
      else
         Put_Line ("unknown wing launch case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Wing_Launch_Line;

   TR_Seq   : Integer_64 := -1;
   TR_Trail : Adaflight.Nav_Trail.Trail;

   procedure Check_Nav_Trail_Line is
      use Adaflight.Nav_Trail;
      Name : constant String := Str (1);

      function Trail_Hash return Unsigned_32 is
         H : Unsigned_32 := 2166136261;
      begin
         for I in 0 .. TR_Trail.Length - 1 loop
            H := (H xor Unsigned_32 (Interfaces.Unsigned_16'Mod (TR_Trail.Points (I).East_M))) * 16777619;
            H := (H xor Unsigned_32 (Interfaces.Unsigned_16'Mod (TR_Trail.Points (I).North_M))) * 16777619;
         end loop;
         return H;
      end Trail_Hash;
   begin
      if Name = "trinit" then
         TR_Seq := Int (2);
         TR_Trail := (Points         => (others => (East_M => 0, North_M => 0)),
                      Length         => 0,
                      Spacing_Now    => Spacing_M,
                      Was_Armed      => False,
                      Last_Update_Us => 0);
      elsif Name = "trstep" then
         if Int (2) /= TR_Seq then
            Put_Line ("trail step without its start");
            Failures := Failures + 1;
            return;
         end if;
         case Int (4) is
            when 0 =>
               Update (TR_Trail, Interfaces.Unsigned_32 (Int (5)), Int (6) /= 0, Int (7) /= 0, Int (8) /= 0,
                       Flt (9), Flt (10));
            when 1 =>
               Ingest (TR_Trail, Flt (9), Flt (10));
            when others =>
               Reset (TR_Trail);
         end case;
         Record_Int (Name & ".count", Int (11), Integer_64 (TR_Trail.Length));
         Record_Int (Name & ".spacing", Int (12), Integer_64 (TR_Trail.Spacing_Now));
         if TR_Trail.Length > 0 then
            Record_Int (Name & ".laste", Int (13), Integer_64 (Point_At (TR_Trail, TR_Trail.Length - 1).East_M));
            Record_Int (Name & ".lastn", Int (14), Integer_64 (Point_At (TR_Trail, TR_Trail.Length - 1).North_M));
         else
            Record_Int (Name & ".laste", Int (13), 0);
            Record_Int (Name & ".lastn", Int (14), 0);
         end if;
         Record_Result (Name & ".hash", Bits (15), Trail_Hash);
      else
         Put_Line ("unknown trail case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Nav_Trail_Line;

   GPS_Seq   : Integer_64 := -1;
   GPS_State : Adaflight.GPS_Frames.Receiver;
   GPS_Clock : Adaflight.GPS_Frames.Clock_Request;

   procedure Check_GPS_Line is
      use Adaflight.GPS_Frames;
      Name      : constant String := Str (1);
      UBX_Line  : constant Boolean := Int (4) = 1;
      Event     : constant Integer_64 := Int (5);
      Fed       : constant Byte_Array := Hex_Bytes (9);
      Has_Time  : Boolean := Int (7) = 1;
      New_Count : Natural := 0;
      Sets      : Natural := 0;
      New_Sol   : Boolean;
      Clock     : Clock_Request;
      K         : Positive;
   begin
      if Int (2) /= GPS_Seq then
         GPS_Seq := Int (2);
         GPS_State := (others => <>);
         GPS_Clock := (others => <>);
      end if;
      if Event = 1 then
         GPS_State.UBX.Ack := Waiting;
         GPS_State.UBX.Ack_Message := Interfaces.Unsigned_8 (Int (6));
      end if;
      for B of Fed loop
         if UBX_Line then
            Receive_UBX (GPS_State, B, Has_Time, New_Sol, Clock);
         else
            Receive_NMEA (GPS_State, B, Has_Time, New_Sol, Clock);
         end if;
         if New_Sol then
            New_Count := New_Count + 1;
         end if;
         if Clock.Set then
            Has_Time := True;
            Sets := Sets + 1;
            GPS_Clock := Clock;
         end if;
      end loop;
      Record_Int (Name & ".new", Int (10), Integer_64 (New_Count));
      Record_Int (Name & ".fix", Int (11), Boolean'Pos (GPS_State.Fix));
      Record_Int (Name & ".fix_ever", Int (12), Boolean'Pos (GPS_State.Fix_Ever));
      Record_Int (Name & ".lat", Int (13), Integer_64 (GPS_State.Sol.Llh.Lat));
      Record_Int (Name & ".lon", Int (14), Integer_64 (GPS_State.Sol.Llh.Lon));
      Record_Int (Name & ".alt", Int (15), Integer_64 (GPS_State.Sol.Llh.Alt_Cm));
      Record_Int (Name & ".pdop", Int (16), Integer_64 (GPS_State.Sol.Dop.Pdop));
      Record_Int (Name & ".hdop", Int (17), Integer_64 (GPS_State.Sol.Dop.Hdop));
      Record_Int (Name & ".vdop", Int (18), Integer_64 (GPS_State.Sol.Dop.Vdop));
      Record_Int (Name & ".hacc", Int (19), Integer_64 (GPS_State.Sol.Acc.Horizontal));
      Record_Int (Name & ".vacc", Int (20), Integer_64 (GPS_State.Sol.Acc.Vertical));
      Record_Int (Name & ".sacc", Int (21), Integer_64 (GPS_State.Sol.Acc.Speed));
      Record_Int (Name & ".headacc", Int (22), Integer_64 (GPS_State.Sol.Acc.Heading));
      Record_Int (Name & ".veln", Int (23), Integer_64 (GPS_State.Sol.Velned.North));
      Record_Int (Name & ".vele", Int (24), Integer_64 (GPS_State.Sol.Velned.East));
      Record_Int (Name & ".veld", Int (25), Integer_64 (GPS_State.Sol.Velned.Down));
      Record_Int (Name & ".speed3d", Int (26), Integer_64 (GPS_State.Sol.Speed_3d));
      Record_Int (Name & ".gspeed", Int (27), Integer_64 (GPS_State.Sol.Ground_Speed));
      Record_Int (Name & ".gcourse", Int (28), Integer_64 (GPS_State.Sol.Ground_Course));
      Record_Int (Name & ".numsat", Int (29), Integer_64 (GPS_State.Sol.Num_Sat));
      Record_Int (Name & ".time", Int (30), Integer_64 (GPS_State.Sol.Time));
      Record_Int (Name & ".navint", Int (31), Integer_64 (GPS_State.Sol.Nav_Interval_Ms));
      Record_Int (Name & ".year", Int (32), Integer_64 (GPS_State.Sol.Utc.Year));
      Record_Int (Name & ".month", Int (33), Integer_64 (GPS_State.Sol.Utc.Month));
      Record_Int (Name & ".day", Int (34), Integer_64 (GPS_State.Sol.Utc.Day));
      Record_Int (Name & ".hour", Int (35), Integer_64 (GPS_State.Sol.Utc.Hour));
      Record_Int (Name & ".minute", Int (36), Integer_64 (GPS_State.Sol.Utc.Minute));
      Record_Int (Name & ".second", Int (37), Integer_64 (GPS_State.Sol.Utc.Second));
      Record_Int (Name & ".millis", Int (38), Integer_64 (GPS_State.Sol.Utc.Millis));
      Record_Int (Name & ".valid", Int (39), Boolean'Pos (GPS_State.Sol.Utc.Valid));
      Record_Int (Name & ".lastnav", Int (40), Integer_64 (GPS_State.Last_Nav_Time));
      Record_Int (Name & ".numch", Int (41), Integer_64 (GPS_State.Num_Channels));
      Record_Int (Name & ".phase", Int (42), Integer_64 (UBX_Phase'Pos (GPS_State.UBX.Phase)));
      Record_Int (Name & ".class", Int (43), Integer_64 (GPS_State.UBX.Class));
      Record_Int (Name & ".id", Int (44), Integer_64 (GPS_State.UBX.Id));
      Record_Int (Name & ".length", Int (45), Integer_64 (GPS_State.UBX.Length));
      Record_Int (Name & ".counter", Int (46), Integer_64 (GPS_State.UBX.Counter));
      Record_Int (Name & ".cka", Int (47), Integer_64 (GPS_State.UBX.Ck_A));
      Record_Int (Name & ".ckb", Int (48), Integer_64 (GPS_State.UBX.Ck_B));
      Record_Int (Name & ".validfix", Int (49), Boolean'Pos (GPS_State.UBX.Valid_Fix));
      Record_Int (Name & ".newpos", Int (50), Boolean'Pos (GPS_State.UBX.New_Position));
      Record_Int (Name & ".newspeed", Int (51), Boolean'Pos (GPS_State.UBX.New_Speed));
      Record_Int (Name & ".almost", Int (52), Boolean'Pos (GPS_State.UBX.Almost_Done));
      Record_Int (Name & ".ack", Int (53), Integer_64 (Ack_State'Pos (GPS_State.UBX.Ack)));
      Record_Int (Name & ".ackid", Int (54), Integer_64 (GPS_State.UBX.Ack_Message));
      Record_Int (Name & ".version", Int (55), Integer_64 (Platform'Pos (GPS_State.UBX.Version)));
      Record_Int (Name & ".m7", Int (56), Boolean'Pos (GPS_State.UBX.M7_Or_Above));
      Record_Int (Name & ".m8", Int (57), Boolean'Pos (GPS_State.UBX.M8_Or_Above));
      Record_Int (Name & ".m9", Int (58), Boolean'Pos (GPS_State.UBX.M9_Or_Above));
      Record_Int (Name & ".sets", Int (59), Integer_64 (Sets));
      Record_Int (Name & ".cyear", Int (60), Integer_64 (GPS_Clock.Year));
      Record_Int (Name & ".cmonth", Int (61), Integer_64 (GPS_Clock.Month));
      Record_Int (Name & ".cday", Int (62), Integer_64 (GPS_Clock.Day));
      Record_Int (Name & ".chours", Int (63), Integer_64 (GPS_Clock.Hours));
      Record_Int (Name & ".cminutes", Int (64), Integer_64 (GPS_Clock.Minutes));
      Record_Int (Name & ".cseconds", Int (65), Integer_64 (GPS_Clock.Seconds));
      Record_Int (Name & ".cmillis", Int (66), Integer_64 (GPS_Clock.Millis));
      K := 67;
      for S in Satellite_Index loop
         Record_Int (Name & ".chn", Int (K), Integer_64 (GPS_State.Sats (S).Channel));
         Record_Int (Name & ".svid", Int (K + 1), Integer_64 (GPS_State.Sats (S).Id));
         Record_Int (Name & ".quality", Int (K + 2), Integer_64 (GPS_State.Sats (S).Quality));
         Record_Int (Name & ".cno", Int (K + 3), Integer_64 (GPS_State.Sats (S).Cno));
         K := K + 4;
      end loop;
   end Check_GPS_Line;

   procedure Check_UBX_Config_Line is
      use Adaflight.UBX_Config;
      Kind  : constant Integer_64 := Int (4);
      M8    : constant Boolean := Int (7) = 1;
      M9    : constant Boolean := Int (8) = 1;
      Sbas  : constant Sbas_Mode := Sbas_Mode'Val (Int (9));
      Integ : constant Boolean := Int (10) = 1;
      UTC   : constant UTC_Standard := UTC_Standard'Val (Int (11));
      Gal   : constant Boolean := Int (12) = 1;
      A1    : constant Integer_64 := Int (13);
      A2    : constant Integer_64 := Int (14);
      A3    : constant Integer_64 := Int (15);
      Reply : constant Byte_Array := Hex_Bytes (17);
      Sent  : Boolean := True;
      F     : Frame;
   begin
      case Kind is
         when 0 =>
            F := Poll (Class_Mon, Msg_Mon_Ver);
         when 1 =>
            F := Poll (Class_Cfg, Msg_Cfg_Gnss);
         when 2 =>
            F := Message_Rate (Unsigned_8 (A1), Unsigned_8 (A2), Unsigned_8 (A3));
         when 3 =>
            F := Message_Rate_Key ((case A1 is
                                      when 0      => Key_Nav_Pvt_UART1,
                                      when 1      => Key_Nav_Sat_UART1,
                                      when others => Key_Nav_Dop_UART1), Unsigned_8 (A2));
         when 4 =>
            F := Nav_Rate (Measurement_Rate_Hz (A1), Unsigned_16 (A2), Unsigned_8 (A3), M9);
         when 5 =>
            F := Model_Message (Dynamic_Model'Val (A1), UTC, M9);
         when 6 =>
            F := Assistance_Message (M9);
         when 7 =>
            if M8 or M9 then
               F := Power_Mode_Message (M9);
            else
               Sent := False;
            end if;
         when 8 =>
            F := Sbas_Message (Sbas, Integ, M9);
         when 9 =>
            F := Disable_NMEA_Message;
         when 10 =>
            F := Satellite_Info_Rate (Unsigned_8 (A1), M8, M9);
         when others =>
            declare
               Full : Gnss_Reply := (others => 0);
            begin
               for I in Reply'Range loop
                  Full (I) := Reply (I);
               end loop;
               F := Gnss_Message (Full, Sbas = None, Gal);
            end;
      end case;
      if Sent then
         Record_Bytes ("ubxcfg.frame", Hex_Bytes (19), Byte_Array (F.Data (0 .. F.Length - 1)));
         Record_Int ("ubxcfg.ack", Int (20), (if F.Skip_Ack then 2 else 1));
         Record_Int ("ubxcfg.ackid", Int (21), Integer_64 (F.Id));
         Record_Int ("ubxcfg.sent_at", Int (22), Int (16));
      else
         Record_Int ("ubxcfg.len", Int (18), 0);
         Record_Int ("ubxcfg.ack", Int (20), 0);
         Record_Int ("ubxcfg.ackid", Int (21), 0);
         Record_Int ("ubxcfg.sent_at", Int (22), 0);
      end if;
   end Check_UBX_Config_Line;

   GPSL_Seq      : Integer_64 := -1;
   GPSL_Link     : Adaflight.GPS_Link.Link;
   GPSL_Receiver : Adaflight.GPS_Frames.Receiver;
   GPSL_Settings : Adaflight.GPS_Link.Settings;
   GPSL_Has_Time : Boolean := False;
   GPSL_Clock    : Adaflight.GPS_Frames.Clock_Request;

   procedure Check_GPS_Link_Line is
      use Adaflight.GPS_Link;
      use Adaflight.GPS_Frames;
      Name : constant String := Str (1);

      function State_Code (S : Link_State) return Integer_64 is
        (if S = Lost_Communication then 7 else Link_State'Pos (S));

      function Rate_Code (B : Baud_Rate; Open : Boolean) return Integer_64 is
        (if Open then Integer_64 (Rate_Of (B)) else 0);

      procedure Record_Link (K : Positive) is
         L : Link renames GPSL_Link;
         R : Receiver renames GPSL_Receiver;
      begin
         Record_Int (Name & ".state", Int (K), State_Code (L.State));
         Record_Int (Name & ".position", Int (K + 1), Integer_64 (L.Position));
         Record_Int (Name & ".ack", Int (K + 2), Integer_64 (Ack_State'Pos (R.UBX.Ack)));
         Record_Int (Name & ".ackid", Int (K + 3), Integer_64 (R.UBX.Ack_Message));
         Record_Int (Name & ".version", Int (K + 4), Integer_64 (Platform'Pos (R.UBX.Version)));
         Record_Int (Name & ".m7", Int (K + 5), Boolean'Pos (R.UBX.M7_Or_Above));
         Record_Int (Name & ".m8", Int (K + 6), Boolean'Pos (R.UBX.M8_Or_Above));
         Record_Int (Name & ".m9", Int (K + 7), Boolean'Pos (R.UBX.M9_Or_Above));
         Record_Int (Name & ".flightmodel", Int (K + 8), Boolean'Pos (L.Using_Flight_Model));
         Record_Int (Name & ".userbaud", Int (K + 9), Integer_64 (Baud_Rate'Pos (L.User_Baud)));
         Record_Int (Name & ".tempbaud", Int (K + 10), Integer_64 (Baud_Rate'Pos (L.Temp_Baud)));
         Record_Int (Name & ".rate", Int (K + 11), Integer_64 (L.Update_Rate));
         Record_Int (Name & ".timeouts", Int (K + 12), Integer_64 (L.Timeouts));
         Record_Int (Name & ".lastnav", Int (K + 13), Integer_64 (L.Last_Nav_Message));
         Record_Int (Name & ".lastsent", Int (K + 14), Integer_64 (L.Last_Message_Sent));
         Record_Int (Name & ".state_ts", Int (K + 15), Integer_64 (L.State_Ts));
         Record_Int (Name & ".sensor", Int (K + 16), Boolean'Pos (L.Sensor_Present));
         Record_Int (Name & ".fix", Int (K + 17), Boolean'Pos (R.Fix));
         Record_Int (Name & ".fixhome", Int (K + 18), Boolean'Pos (L.Fix_Home));
         Record_Int (Name & ".fixever", Int (K + 19), Boolean'Pos (R.Fix_Ever));
         Record_Int (Name & ".tick", Int (K + 20), Boolean'Pos (L.Tick));
         Record_Int (Name & ".pending", Int (K + 21), Boolean'Pos (L.Solution_Offered));
         Record_Int (Name & ".numsat", Int (K + 22), Integer_64 (R.Sol.Num_Sat));
         Record_Int (Name & ".navint", Int (K + 23), Integer_64 (R.Sol.Nav_Interval_Ms));
         Record_Int (Name & ".lat", Int (K + 24), Integer_64 (R.Sol.Llh.Lat));
         Record_Int (Name & ".lon", Int (K + 25), Integer_64 (R.Sol.Llh.Lon));
         Record_Int (Name & ".alt", Int (K + 26), Integer_64 (R.Sol.Llh.Alt_Cm));
         Record_Int (Name & ".homelat", Int (K + 27), Integer_64 (L.Home.Lat));
         Record_Int (Name & ".homelon", Int (K + 28), Integer_64 (L.Home.Lon));
         Record_Int (Name & ".homealt", Int (K + 29), Integer_64 (L.Home.Alt_Cm));
         Record_Int (Name & ".disthome_m", Int (K + 30), Integer_64 (L.Distance_To_Home_M));
         Record_Int (Name & ".disthome_cm", Int (K + 31), Integer_64 (L.Distance_To_Home_Cm));
         Record_Int (Name & ".dirhome", Int (K + 32), Integer_64 (L.Direction_To_Home));
         Record_Int (Name & ".flown", Int (K + 33), Integer_64 (L.Distance_Flown_Cm));
         Record_Result (Name & ".coslat", Bits (K + 34), To_Bits (L.Cos_Lat));
         Record_Result (Name & ".interval", Bits (K + 35), To_Bits (L.Data_Interval_S));
         Record_Result (Name & ".frequency", Bits (K + 36), To_Bits (L.Data_Frequency_Hz));
         Record_Int (Name & ".stamp", Int (K + 37), Integer_64 (L.Stamp));
         Record_Int (Name & ".portbaud", Int (K + 38), Rate_Code (L.Port_Baud, L.Port_Open));
      end Record_Link;
   begin
      if Name = "gpslinit" then
         GPSL_Seq := Int (2);
         GPSL_Receiver := (others => <>);
         GPSL_Has_Time := False;
         GPSL_Clock := (others => <>);
         GPSL_Settings := (others => <>);
         GPSL_Settings.Source := (case Int (3) is when 0 => NMEA, when 1 => UBlox, when others => MSP);
         GPSL_Settings.Sbas := Adaflight.UBX_Config.Sbas_Mode'Val (Int (4));
         GPSL_Settings.Auto_Config := Int (5) = 1;
         GPSL_Settings.Acquire_Model := Adaflight.UBX_Config.Dynamic_Model'Val (Int (6));
         GPSL_Settings.Flight_Model := Adaflight.UBX_Config.Dynamic_Model'Val (Int (7));
         GPSL_Settings.Update_Rate := Update_Rate_Hz (Int (8));
         GPSL_Settings.Use_Galileo := Int (9) = 1;
         GPSL_Settings.Set_Home_Once := Int (10) = 1;
         GPSL_Settings.Use_3D_Speed := Int (11) = 1;
         GPSL_Settings.Sbas_Integrity := Int (12) = 1;
         GPSL_Settings.UTC := Adaflight.UBX_Config.UTC_Standard'Val (Int (13));
         GPSL_Settings.Enable_Assistance := Int (14) = 1;
         GPSL_Settings.Baud := (case Int (15) is
                                   when 1      => B_9600,
                                   when 2      => B_19200,
                                   when 3      => B_38400,
                                   when 4      => B_57600,
                                   when 5      => B_115200,
                                   when others => B_230400);
         GPSL_Settings.Min_Sats := Satellite_Minimum (Int (16));
         declare
            Cmds : constant Byte_Array := Hex_Bytes (17);
         begin
            GPSL_Settings.Commands_Length := Cmds'Length;
            for I in Cmds'Range loop
               GPSL_Settings.Commands (I + 1) := Character'Val (Cmds (I));
            end loop;
         end;
         GPSL_Settings.Port_Assigned := Int (18) = 1;
         Init (GPSL_Link, GPSL_Receiver, GPSL_Settings, Unsigned_32 (Int (20)), Int (19) = 1);
         Record_Int (Name & ".state", Int (21), State_Code (GPSL_Link.State));
         Record_Int (Name & ".position", Int (22), Integer_64 (GPSL_Link.Position));
         Record_Int (Name & ".userbaud", Int (23), Integer_64 (Baud_Rate'Pos (GPSL_Link.User_Baud)));
         Record_Int (Name & ".tempbaud", Int (24), Integer_64 (Baud_Rate'Pos (GPSL_Link.Temp_Baud)));
         Record_Int (Name & ".rate", Int (25), Integer_64 (GPSL_Link.Update_Rate));
         Record_Int (Name & ".timeouts", Int (26), Integer_64 (GPSL_Link.Timeouts));
         Record_Int (Name & ".state_ts", Int (27), Integer_64 (GPSL_Link.State_Ts));
         Record_Int (Name & ".lastnav", Int (28), Integer_64 (GPSL_Link.Last_Nav_Message));
         Record_Int (Name & ".ack", Int (29), Integer_64 (Ack_State'Pos (GPSL_Receiver.UBX.Ack)));
         Record_Int (Name & ".version", Int (30), Integer_64 (Platform'Pos (GPSL_Receiver.UBX.Version)));
         Record_Int (Name & ".portbaud", Int (31), Rate_Code (GPSL_Link.Port_Baud, GPSL_Link.Port_Open));
         Record_Int (Name & ".sensor", Int (32), Boolean'Pos (GPSL_Link.Sensor_Present));
         Record_Int (Name & ".sweep", Int (33), Integer_64 (GPSL_Link.Sweep_Steps));
         Record_Int (Name & ".lastsweep", Int (34), Integer_64 (GPSL_Link.Last_Sweep_Step));
      elsif Name = "gpslstep" then
         if Int (2) /= GPSL_Seq then
            Put_Line ("gps link step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Rx      : constant Byte_Array := Hex_Bytes (19);
            Armed   : constant Boolean := Int (6) = 1;
            E       : Events;
            Home_Tx : Transmission;
            Tx      : Byte_Array (0 .. 2 * Max_Tx - 1) := (others => 0);
            Tx_Len  : Natural := 0;
         begin
            if Int (9) = 1 then
               GPSL_Has_Time := False;
            end if;
            Record_Int (Name & ".hastime", Int (10), Boolean'Pos (GPSL_Has_Time));
            if Int (11) = 1 then
               Offer_Solution (GPSL_Link, GPSL_Receiver, Int (12) = 1, Interfaces.Unsigned_8 (Int (13)),
                               I32 (14), I32 (15), Interfaces.Unsigned_16 (Int (16)),
                               Interfaces.Unsigned_16 (Int (17)));
            end if;
            if Int (7) = 1 then
               Reset_Home (GPSL_Link, GPSL_Receiver, GPSL_Settings, Home_Tx);
               for I in 0 .. Home_Tx.Length - 1 loop
                  Tx (Tx_Len + I) := Home_Tx.Data (I);
               end loop;
               Tx_Len := Tx_Len + Home_Tx.Length;
            end if;
            Update (GPSL_Link, GPSL_Receiver, GPSL_Settings, Unsigned_32 (Int (4)), Unsigned_32 (Int (5)), Rx,
                    Int (8) = 1, Armed, GPSL_Has_Time, E);
            for I in 0 .. E.Tx.Length - 1 loop
               Tx (Tx_Len + I) := E.Tx.Data (I);
            end loop;
            Tx_Len := Tx_Len + E.Tx.Length;
            if E.Clock_Sets > 0 then
               GPSL_Clock := E.Clock;
            end if;
            Record_Link (20);
            Record_Int (Name & ".baudset", Int (59), (if E.Baud_Changed then Integer_64 (Rate_Of (E.New_Baud)) else 0));
            Record_Int (Name & ".taskrate", Int (60), Integer_64 (Task_Rate'Pos (E.Rate)));
            Record_Int (Name & ".indicator", Int (61), Boolean'Pos (E.Indicator));
            Record_Int (Name & ".beep", Int (62), Boolean'Pos (E.Ready_Beep));
            Record_Int (Name & ".clocksets", Int (63), Integer_64 (E.Clock_Sets));
            Record_Int (Name & ".cyear", Int (64), Integer_64 (GPSL_Clock.Year));
            Record_Int (Name & ".cmonth", Int (65), Integer_64 (GPSL_Clock.Month));
            Record_Int (Name & ".cday", Int (66), Integer_64 (GPSL_Clock.Day));
            Record_Int (Name & ".chours", Int (67), Integer_64 (GPSL_Clock.Hours));
            Record_Int (Name & ".cminutes", Int (68), Integer_64 (GPSL_Clock.Minutes));
            Record_Int (Name & ".cseconds", Int (69), Integer_64 (GPSL_Clock.Seconds));
            Record_Int (Name & ".cmillis", Int (70), Integer_64 (GPSL_Clock.Millis));
            Record_Bytes (Name & ".tx", Hex_Bytes (72), Tx (0 .. Tx_Len - 1));
            Record_Int (Name & ".overflow", 0, Boolean'Pos (E.Tx.Overflow or else Home_Tx.Overflow));
            Record_Int (Name & ".sweep", Int (73), Integer_64 (GPSL_Link.Sweep_Steps));
            Record_Int (Name & ".lastsweep", Int (74), Integer_64 (GPSL_Link.Last_Sweep_Step));
         end;
      else
         Put_Line ("unknown gps link case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_GPS_Link_Line;

   Pos_State            : Adaflight.Position_Estimator.State;
   Pos_Settings         : Adaflight.Position_Estimator.Settings;
   Pos_Baro_Present     : Boolean := False;
   Pos_GPS_Present      : Boolean := False;
   Pos_One_G_Reciprocal : Float := 1.0 / 4096.0;

   procedure Check_Posest_Line is
      use Adaflight.Position_Estimator;
      Name : constant String := Str (1);
   begin
      if Name = "posinit" then
         Pos_Settings := (Source         => Altitude_Source'Val (Int (3)),
                          Prefer_Baro    => Integer (Int (4)),
                          Altitude_LPF   => Integer (Int (5)),
                          Derivative_LPF => Integer (Int (6)),
                          Horizontal     => Horizontal_Source'Val (Int (7)));
         Pos_Baro_Present := Int (8) /= 0;
         Pos_GPS_Present := Int (9) /= 0;
         Pos_One_G_Reciprocal := Flt (10);
         Init (Pos_State, Pos_Settings, Armed => False);
         Record_Result ("posinit.altitude_k", Bits (11), To_Bits (Pos_State.Altitude_Filter.K));
         Record_Result ("posinit.derivative_k", Bits (12), To_Bits (Pos_State.Derivative_Filter.K));
      elsif Name = "posstep" then
         declare
            Inp   : Inputs;
            K     : Positive := 39;
            Taken : Boolean;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("posstep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("posstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            procedure Expect_Filter (N : String; F : Adaflight.Position_Filter.Filter) is
            begin
               for Comp in Adaflight.Position_Filter.Component loop
                  Expect_Float (N & ".x", F.X (Comp));
               end loop;
               for Row in Adaflight.Position_Filter.Component loop
                  for Col in Adaflight.Position_Filter.Component loop
                     Expect_Float (N & ".p", F.P (Row, Col));
                  end loop;
               end loop;
            end Expect_Filter;
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
            Inp.Baro_Present := Pos_Baro_Present;
            Inp.One_G_Reciprocal := Pos_One_G_Reciprocal;
            Inp.GPS_Present := Pos_GPS_Present;
            Inp.GPS_Fix := Int (21) /= 0;
            Inp.GPS_Stamp := Interfaces.Unsigned_16 (Int (22));
            Inp.GPS_Rate_Hz := Flt (23);
            Inp.GPS_Location := (Lat => I32 (24), Lon => I32 (25), Alt_Cm => I32 (26));
            Inp.GPS_Velocity_North := Interfaces.Integer_16 (Int (27));
            Inp.GPS_Velocity_East := Interfaces.Integer_16 (Int (28));
            Inp.GPS_Velocity_Down := Interfaces.Integer_16 (Int (29));
            Inp.GPS_H_Acc := Interfaces.Unsigned_32 (Int (30));
            Inp.GPS_S_Acc := Interfaces.Unsigned_32 (Int (31));
            Inp.GPS_V_Acc := Interfaces.Unsigned_32 (Int (32));
            Inp.Cos_Lat := Flt (33);
            Inp.Position_Hold_Mode := Int (34) /= 0;
            Inp.Rescue_Mode := Int (35) /= 0;
            if Int (36) = 1 then
               Take_Update (Pos_State, Consumer'Val (Int (37)), Taken);
               Record_Int ("posstep.taken", Int (38), Boolean'Pos (Taken));
            elsif Int (36) = 2 then
               Enable_XY (Pos_State, Inp, True);
            end if;
            Update (Pos_State, Pos_Settings, Inp);
            Expect_Filter ("up", Pos_State.Up);
            Expect_Filter ("east", Pos_State.East);
            Expect_Filter ("north", Pos_State.North);
            Expect_Float ("baro_offset", Pos_State.Baro_Offset_Cm);
            Expect_Int ("baro_offset_set", Boolean'Pos (Pos_State.Baro_Offset_Set));
            Expect_Int ("baro_available", Boolean'Pos (Pos_State.Baro_Data_Available));
            Expect_Int ("baro_timestamp", Integer_64 (Pos_State.Baro_Timestamp_Us));
            Expect_Int ("baro_hold", Integer_64 (Pos_State.Baro_Hold_Us));
            Expect_Float ("gate_last", Pos_State.Baro_Gate.Last_Accepted_Cm);
            Expect_Int ("gate_reference", Boolean'Pos (Pos_State.Baro_Gate.Has_Reference));
            Expect_Int ("gate_rejects", Integer_64 (Pos_State.Baro_Gate.Rejects));
            Expect_Float ("baro_raw", Pos_State.Baro_Raw_Cm);
            Expect_Int ("xy_enabled", Boolean'Pos (Pos_State.XY_Enabled));
            Expect_Int ("last_xy", Integer_64 (Pos_State.Last_XY_Measurement_Us));
            Expect_Int ("gps_stamp", Integer_64 (Pos_State.GPS_Stamp));
            Expect_Int ("gps_available", Boolean'Pos (Pos_State.GPS_Data_Available));
            Expect_Int ("gps_received", Integer_64 (Pos_State.GPS_Received_At_Us));
            Expect_Int ("gps_hold", Integer_64 (Pos_State.GPS_Hold_Us));
            Expect_Int ("origin_set", Boolean'Pos (Pos_State.Origin_Set));
            Expect_Int ("origin_lat", Integer_64 (Pos_State.Origin.Lat));
            Expect_Int ("origin_lon", Integer_64 (Pos_State.Origin.Lon));
            Expect_Int ("origin_alt", Integer_64 (Pos_State.Origin.Alt_Cm));
            Expect_Float ("gps_alt_offset", Pos_State.GPS_Alt_Offset_Cm);
            Expect_Int ("gps_alt_offset_set", Boolean'Pos (Pos_State.GPS_Alt_Offset_Set));
            Expect_Float ("anchor_tau", Pos_State.GPS_Anchor_Tau_S);
            Expect_Int ("last_z", Integer_64 (Pos_State.Last_Z_Measurement_Us));
            Expect_Int ("valid_z", Boolean'Pos (Pos_State.Valid_Z));
            Expect_Int ("valid_xy", Boolean'Pos (Pos_State.Valid_XY));
            Expect_Float ("trust_z", Pos_State.Trust_Z);
            Expect_Float ("trust_xy", Pos_State.Trust_XY);
            Expect_Float ("position_east", Pos_State.Position_East);
            Expect_Float ("position_north", Pos_State.Position_North);
            Expect_Float ("position_up", Pos_State.Position_Up);
            Expect_Float ("velocity_east", Pos_State.Velocity_East);
            Expect_Float ("velocity_north", Pos_State.Velocity_North);
            Expect_Float ("velocity_up", Pos_State.Velocity_Up);
            Expect_Float ("acceleration_east", Pos_State.Acceleration_East);
            Expect_Float ("acceleration_north", Pos_State.Acceleration_North);
            Expect_Float ("acceleration_up", Pos_State.Acceleration_Up);
            Expect_Int ("heading_required", Boolean'Pos (Heading_Required (Pos_Settings, Inp)));
            Expect_Float ("altitude", Pos_State.Filtered_Altitude_Cm);
            Expect_Float ("derivative", Pos_State.Filtered_Derivative);
            Expect_Float ("control_altitude", Pos_State.Control_Altitude_Cm);
            Expect_Float ("control_derivative", Pos_State.Control_Derivative);
            Expect_Float ("control_acceleration", Pos_State.Control_Acceleration);
            Expect_Int ("estimated", Integer_64 (Estimated_Altitude_Cm (Pos_State)));
            if K /= NF + 1 then
               Put_Line ("posstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown posest case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Posest_Line;

   PH_State    : Adaflight.Position_Hold.State;
   PH_Settings : Adaflight.Position_Hold.Settings;
   PC_Settings : Adaflight.Position_Control.Settings;

   procedure Check_Poshold_Line is
      use Adaflight.Position_Control;
      Name : constant String := Str (1);
   begin
      if Name = "phinit" then
         PC_Settings := (Position_P       => Integer (Int (3)),
                         Position_I       => Integer (Int (4)),
                         Position_D       => Integer (Int (5)),
                         Position_A       => Integer (Int (6)),
                         Position_F       => Integer (Int (7)),
                         Position_Cutoff  => Integer (Int (8)),
                         Stop_Threshold   => Integer (Int (9)),
                         Max_Angle        => Integer (Int (10)),
                         Drag_Coefficient => Integer (Int (11)),
                         Max_Velocity     => Integer (Int (12)),
                         Stick_Deadband   => Integer (Int (13)),
                         Yaw_P            => Integer (Int (14)),
                         Max_Yaw_Rate     => Integer (Int (15)),
                         Yaw_Reversed     => Int (16) /= 0);
         PH_Settings := (Deadband => Integer (Int (17)));
         Adaflight.Position_Hold.Init (PH_State, PH_Settings, PC_Settings);
         Record_Result ("phinit.kp", Bits (20), To_Bits (PH_State.Control.Pid.Kp));
         Record_Result ("phinit.ki", Bits (21), To_Bits (PH_State.Control.Pid.Ki));
         Record_Result ("phinit.kd", Bits (22), To_Bits (PH_State.Control.Pid.Kd));
         Record_Result ("phinit.ka", Bits (23), To_Bits (PH_State.Control.Pid.Ka));
         Record_Result ("phinit.kf", Bits (24), To_Bits (PH_State.Control.Pid.Kf));
         Record_Result ("phinit.kdrag", Bits (25), To_Bits (PH_State.Control.Pid.K_Drag));
         Record_Result ("phinit.yawkp", Bits (26), To_Bits (PH_State.Control.Yaw_Kp));
         Record_Result ("phinit.maxangle", Bits (27), To_Bits (PH_State.Control.Max_Angle));
         Record_Result ("phinit.lpfdt", Bits (28), To_Bits (PH_State.Control.Lpf_Dt_S));
         Record_Result ("phinit.lpfk", Bits (29), To_Bits (PH_State.Control.F_East.K));
      elsif Name = "phstep" then
         declare
            Inp       : Inputs;
            K         : Positive := 33;
            Enable_XY : Boolean;
            Event     : constant Integer_64 := Int (28);
            Ev_A      : constant Float := Flt (29);
            Ev_B      : constant Float := Flt (30);
            Ev_C      : constant Boolean := Int (31) /= 0;
            procedure Expect_Float (N : String; Actual : Float) is
            begin
               Record_Result ("phstep." & N, Bits (K), To_Bits (Actual));
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("phstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            procedure Expect_Bool (N : String; Actual : Boolean) is
            begin
               Expect_Int (N, Boolean'Pos (Actual));
            end Expect_Bool;
            procedure Expect_PT3 (N : String; F : Adaflight.Filters.PT3) is
            begin
               Expect_Float (N & ".state", F.State);
               Expect_Float (N & ".state1", F.State1);
               Expect_Float (N & ".state2", F.State2);
               Expect_Float (N & ".k", F.K);
            end Expect_PT3;
         begin
            Inp.Armed := Int (4) /= 0;
            Inp.Failsafe_Active := Int (5) /= 0;
            Inp.Pos_Hold_Mode := Int (6) /= 0;
            Inp.Rescue_Mode := Int (7) /= 0;
            Inp.Autopilot_Mode := Int (8) /= 0;
            Inp.Mag_Mode := Int (9) /= 0;
            Inp.Interval_Us := Interfaces.Integer_32 (Int (10));
            Inp.Position := (X => Flt (11), Y => Flt (12));
            Inp.Velocity := (X => Flt (13), Y => Flt (14));
            Inp.Acceleration := (X => Flt (15), Y => Flt (16));
            Inp.Valid_XY := Int (17) /= 0;
            Inp.Heading_Required := Int (18) /= 0;
            Inp.Yaw := Integer (Int (19));
            Inp.Heading_Valid := Int (20) /= 0;
            Inp.Setpoint_Pitch := Flt (21);
            Inp.Setpoint_Roll := Flt (22);
            Inp.Max_Rate_Pitch := Flt (23);
            Inp.Max_Rate_Roll := Flt (24);
            Inp.Yaw_Command := Flt (25);
            Inp.Deflection_Pitch := Flt (26);
            Inp.Deflection_Roll := Flt (27);
            case Event is
               when 1 => Set_Target_Velocity (PH_State.Control, (X => Ev_A, Y => Ev_B), Ev_C);
               when 2 => Set_Yaw_Target (PH_State.Control, Ev_A);
               when 3 => Set_Heading_Recovery (PH_State.Control, Ev_C, Ev_A);
               when 4 => Set_Force_Level_Park (PH_State.Control, Ev_C);
               when 5 => Set_Yaw_Rate_Limit (PH_State.Control, Ev_A);
               when 6 => Set_Heading_Recovery (PH_State.Control, Ev_C, 35.0);
               when 7 => Disable_Yaw_Control (PH_State.Control);
               when others => null;
            end case;
            Adaflight.Position_Hold.Update (PH_State, PC_Settings, Inp, Enable_XY);
            Update_Heading_Hold (PH_State.Control, PC_Settings, Inp);
            Record_Int ("phstep.enable_xy", Int (32), Boolean'Pos (Enable_XY));
            Expect_Float ("angle_roll", PH_State.Control.Angle_Roll);
            Expect_Float ("angle_pitch", PH_State.Control.Angle_Pitch);
            Expect_Float ("yaw_rate", PH_State.Control.Yaw_Rate_Dps);
            Expect_Bool ("yaw_active", PH_State.Control.Yaw_Active);
            Expect_Float ("attenuator", PH_State.Control.Yaw_Attenuator);
            Expect_Int ("reason", Integer_64 (PH_State.Control.Yaw_Disable_Reason));
            Expect_Bool ("rate_limited", PH_State.Control.Yaw_Rate_Limit > 0.0);
            Expect_Bool ("hold_heading_valid", PH_State.Control.Hold_Heading_Valid);
            Expect_Float ("hold_heading", PH_State.Control.Hold_Heading_Deg);
            Expect_Float ("external_target", PH_State.Control.External_Yaw_Target);
            Expect_Float ("yaw_rate_limit", PH_State.Control.Yaw_Rate_Limit);
            Expect_Bool ("position_held", PH_State.Control.Position_Held);
            Expect_Float ("target_x", PH_State.Control.Target_Position.X);
            Expect_Float ("target_y", PH_State.Control.Target_Position.Y);
            Expect_Float ("target_vel_x", PH_State.Control.Target_Velocity.X);
            Expect_Float ("target_vel_y", PH_State.Control.Target_Velocity.Y);
            Expect_Float ("prev_target_x", PH_State.Control.Previous_Target.X);
            Expect_Float ("prev_target_y", PH_State.Control.Previous_Target.Y);
            Expect_Float ("start_x", PH_State.Control.Hold_Start.X);
            Expect_Float ("start_y", PH_State.Control.Hold_Start.Y);
            Expect_Float ("error_x", PH_State.Control.Distance_Error.X);
            Expect_Float ("error_y", PH_State.Control.Distance_Error.Y);
            Expect_Float ("integral_x", PH_State.Control.Distance_Integral.X);
            Expect_Float ("integral_y", PH_State.Control.Distance_Integral.Y);
            Expect_Float ("prev_vel_x", PH_State.Control.Previous_Velocity.X);
            Expect_Float ("prev_vel_y", PH_State.Control.Previous_Velocity.Y);
            Expect_PT3 ("f_east", PH_State.Control.F_East);
            Expect_PT3 ("f_north", PH_State.Control.F_North);
            Expect_Float ("lpf_dt", PH_State.Control.Lpf_Dt_S);
            Expect_Float ("sanity", PH_State.Control.Sanity_Distance);
            Expect_Float ("violation", PH_State.Control.Sanity_Violation_S);
            Expect_Float ("violation_free", PH_State.Control.Violation_Free_S);
            Expect_Bool ("retry_used", PH_State.Control.Sanity_Retry_Used);
            Expect_Bool ("sticks", PH_State.Control.Sticks_Active);
            Expect_Bool ("was_sticks", PH_State.Control.Was_Sticks_Active);
            Expect_Float ("speed", PH_State.Control.Speed_XY);
            Expect_Float ("trend", PH_State.Control.Speed_Trend);
            Expect_Bool ("slowing", PH_State.Control.Speed_Slowing);
            Expect_Bool ("braking", PH_State.Control.Braking);
            Expect_Float ("braking_time", PH_State.Control.Braking_Time_S);
            Expect_Float ("entry_x", PH_State.Control.Braking_Entry_Direction.X);
            Expect_Float ("entry_y", PH_State.Control.Braking_Entry_Direction.Y);
            Expect_Float ("exit_speed", PH_State.Control.Braking_Exit_Speed);
            Expect_Int ("anchor", Integer_64 (Anchor_Mode'Pos (PH_State.Control.Anchor)));
            Expect_Int ("ipolicy", Integer_64 (Integral_Policy'Pos (PH_State.Control.I_Policy)));
            Expect_Int ("mode", (case PH_State.Control.Mode is
                                   when Settled_Hold => 0, when Braking => 1, when Stick_Velocity => 2,
                                   when Rescue_Velocity => 6));
            Expect_Bool ("abort", PH_State.Control.Abort_Requested);
            Expect_Bool ("heading_recovery", PH_State.Control.Heading_Recovery);
            Expect_Float ("recovery_pitch", PH_State.Control.Heading_Recovery_Pitch);
            Expect_Bool ("force_level_park", PH_State.Control.Force_Level_Park);
            Expect_Bool ("was_saturated", PH_State.Control.Was_Angle_Saturated);
            Expect_Bool ("enabled", PH_State.Enabled);
            Expect_Bool ("control_ok", PH_State.Control_Ok);
            Expect_Bool ("sensors_ok", PH_State.Sensors_Ok);
            Expect_Bool ("failure", Adaflight.Position_Hold.Failure (PH_State, Inp));
            Expect_Bool ("ready", Adaflight.Position_Hold.Ready (Inp));
            Expect_Bool ("in_control", Adaflight.Position_Hold.In_Control (PH_State));
            Expect_Bool ("yaw_control_active", Yaw_Control_Active (PH_State.Control, Inp));
            if K /= NF + 1 then
               Put_Line ("phstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown poshold case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Poshold_Line;

   RS_State    : Adaflight.GPS_Rescue.State;
   RS_Settings : Adaflight.GPS_Rescue.Settings;
   RS_AC       : Adaflight.Altitude_Control.Settings;
   RS_Altitude : Adaflight.Altitude_Control.State;
   RS_PC       : Adaflight.Position_Control.Settings;
   RS_Hold     : Adaflight.Position_Hold.State;
   RS_Max_Rate_Pitch, RS_Max_Rate_Roll : Float := 670.0;

   procedure Check_Rescue_Line is
      use Adaflight.GPS_Rescue;
      Name : constant String := Str (1);
   begin
      if Name = "rsinit" then
         RS_Settings := (Min_Start_Distance_M => Integer (Int (3)),
                         Mode                 => Altitude_Mode'Val (Int (4)),
                         Initial_Climb_M      => Integer (Int (5)),
                         Ascend_Rate          => Integer (Int (6)),
                         Return_Altitude_M    => Integer (Int (7)),
                         Ground_Speed_Cms     => Integer (Int (8)),
                         Descent_Distance_M   => Integer (Int (9)),
                         Descend_Rate         => Integer (Int (10)),
                         Sanity               => Sanity_Checks'Val (Int (11)),
                         Min_Sats             => Integer (Int (12)),
                         Landing_Altitude_M   => Integer (Int (14)),
                         Set_Home_Once        => Int (13) /= 0);
         RS_AC := (Hover_Throttle => Integer (Int (15)),
                   Throttle_Min   => Integer (Int (16)),
                   Throttle_Max   => Integer (Int (17)),
                   Altitude_P     => Integer (Int (18)),
                   Altitude_I     => Integer (Int (19)),
                   Altitude_D     => Integer (Int (20)),
                   Altitude_A     => Integer (Int (21)),
                   Altitude_F     => Integer (Int (24)),
                   Min_Check      => Integer (Int (25)));
         RS_Max_Rate_Pitch := Flt (22);
         RS_Max_Rate_Roll := Flt (23);
         RS_PC := (others => <>);
         Adaflight.Altitude_Control.Init (RS_Altitude, RS_AC);
         Adaflight.Position_Hold.Init (RS_Hold, (Deadband => 5), RS_PC);
         Init (RS_State, RS_Settings);
         Record_Result ("rsinit.initial_climb", Bits (26), To_Bits (RS_State.Want.Initial_Climb_Cm));
         Record_Result ("rsinit.descent_distance", Bits (27), To_Bits (RS_State.Want.Descent_Distance_Cm));
         Record_Result ("rsinit.slowdown", Bits (28), To_Bits (RS_State.Want.Slowdown_Distance_Cm));
      elsif Name = "rsstep" then
         declare
            Inp   : Inputs;
            P_Inp : Adaflight.Position_Control.Inputs;
            K     : Positive := 27;
            Disarm, Arming_Disabled, Enable_XY : Boolean;
            procedure Expect_Float (N : String; Actual : Float; Tolerance : Integer_64 := 0) is
            begin
               Record_Result ("rsstep." & N, Bits (K), To_Bits (Actual), Tolerance);
               K := K + 1;
            end Expect_Float;
            procedure Expect_Int (N : String; Actual : Integer_64) is
            begin
               Record_Int ("rsstep." & N, Int (K), Actual);
               K := K + 1;
            end Expect_Int;
            procedure Expect_Bool (N : String; Actual : Boolean) is
            begin
               Expect_Int (N, Boolean'Pos (Actual));
            end Expect_Bool;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (4));
            Inp.Rescue_Mode := Int (5) /= 0;
            Inp.Armed := Int (6) /= 0;
            Inp.GPS_Stamp := Interfaces.Unsigned_16 (Int (7));
            Inp.Heading_Valid := Int (8) /= 0;
            Inp.GPS_Healthy := Int (9) /= 0;
            Inp.Altitude_Control_Cm := Flt (10);
            Inp.Altitude_Filtered_Cm := Flt (11);
            Inp.Altitude_Available := Int (12) /= 0;
            Inp.Valid_XY := Int (13) /= 0;
            Inp.Position := (X => Flt (14), Y => Flt (15));
            Inp.Velocity := (X => Flt (16), Y => Flt (17));
            Inp.Yaw := Integer (Int (18));
            Inp.GPS_Fix := Int (19) /= 0;
            Inp.GPS_Fix_Home := Int (20) /= 0;
            Inp.Num_Sat := Interfaces.Unsigned_8 (Int (21));
            Inp.Crash_Recovery_Active := Int (22) /= 0;
            Inp.Rx_Receiving := Int (23) /= 0;
            Inp.Vertical_Velocity := Flt (24);
            Inp.Vertical_Acceleration := Flt (25);
            Inp.Cos_Tilt := 1.0;
            P_Inp.Armed := Inp.Armed;
            P_Inp.Rescue_Mode := Inp.Rescue_Mode;
            P_Inp.Interval_Us := 10_000;
            P_Inp.Position := Inp.Position;
            P_Inp.Velocity := Inp.Velocity;
            P_Inp.Acceleration := (X => Flt (NF - 1), Y => Flt (NF));
            P_Inp.Valid_XY := Inp.Valid_XY;
            P_Inp.Heading_Required := Int (26) /= 0;
            P_Inp.Yaw := Inp.Yaw;
            P_Inp.Heading_Valid := Inp.Heading_Valid;
            P_Inp.Max_Rate_Pitch := RS_Max_Rate_Pitch;
            P_Inp.Max_Rate_Roll := RS_Max_Rate_Roll;
            Update (RS_State, RS_Settings, Inp, RS_AC, RS_Altitude, RS_PC, P_Inp, RS_Hold.Control,
                    Disarm, Arming_Disabled);
            Adaflight.Position_Hold.Update (RS_Hold, RS_PC, P_Inp, Enable_XY);
            Expect_Bool ("disarm", Disarm);
            Expect_Bool ("arming_disabled", Arming_Disabled);
            Expect_Bool ("enable_xy", Enable_XY);
            Expect_Int ("phase", Integer_64 (Rescue_Phase'Pos (RS_State.Phase)));
            Expect_Int ("failure", Integer_64 (Failure_State'Pos (RS_State.Failure)));
            Expect_Bool ("available", RS_State.Is_Available);
            Expect_Bool ("ok", RS_State.Is_OK);
            Expect_Bool ("new_gps", RS_State.Sense.New_GPS_Data);
            Expect_Bool ("xy_available", RS_State.Sense.Position_XY_Available);
            Expect_Float ("heading", RS_State.Sense.Aircraft_Heading_Deg);
            Expect_Float ("error_angle", RS_State.Sense.Error_Angle_Deg, Tolerance => 256);
            Expect_Bool ("heading_ok", RS_State.Sense.Heading_OK);
            Expect_Float ("distance", RS_State.Sense.Distance_To_Home_Cm);
            Expect_Float ("speed", RS_State.Sense.Current_Speed_Cms);
            Expect_Float ("position_x", RS_State.Sense.Current_Position.X);
            Expect_Float ("position_y", RS_State.Sense.Current_Position.Y);
            Expect_Float ("max_altitude", RS_State.Want.Max_Altitude_Cm);
            Expect_Float ("return_altitude", RS_State.Want.Return_Altitude_Cm);
            Expect_Float ("target_altitude", RS_State.Want.Target_Altitude_Cm);
            Expect_Float ("target_altitude_vel", RS_State.Want.Target_Altitude_Vel);
            Expect_Int ("seconds_failing", Integer_64 (RS_State.Want.Seconds_Failing));
            Expect_Float ("yaw_attenuator", RS_State.Want.Yaw_Attenuator);
            Expect_Float ("target_heading", RS_State.Want.Target_Heading_Deg, Tolerance => 1);
            Expect_Float ("xy_attenuator", RS_State.Want.XY_Start_Attenuator);
            Expect_Float ("target_speed", RS_State.Want.Target_Speed_Cms);
            Expect_Float ("target_vel_x", RS_State.Want.Target_Velocity.X);
            Expect_Float ("target_vel_y", RS_State.Want.Target_Velocity.Y);
            Expect_Float ("altitude_i", RS_Altitude.Altitude_I);
            Expect_Float ("throttle", RS_Altitude.Throttle_Out);
            Expect_Float ("yaw_target", RS_Hold.Control.External_Yaw_Target);
            Expect_Float ("ap_target_vel_x", RS_Hold.Control.Target_Velocity.X);
            Expect_Float ("ap_target_vel_y", RS_Hold.Control.Target_Velocity.Y);
            Expect_Float ("recovery_pitch", RS_Hold.Control.Heading_Recovery_Pitch);
            Expect_Bool ("heading_recovery", RS_Hold.Control.Heading_Recovery);
            Expect_Float ("yaw_rate", RS_Hold.Control.Yaw_Rate_Dps);
            Expect_Bool ("abort", RS_Hold.Control.Abort_Requested);
            Expect_Bool ("hold_enabled", RS_Hold.Enabled);
            Expect_Float ("angle_roll", RS_Hold.Control.Angle_Roll);
            Expect_Float ("angle_pitch", RS_Hold.Control.Angle_Pitch);
            Expect_Bool ("control_ok", RS_Hold.Control_Ok);
            Expect_Bool ("sensors_ok", RS_Hold.Sensors_Ok);
            Expect_Bool ("position_held", RS_Hold.Control.Position_Held);
            if K /= NF - 1 then
               Put_Line ("rsstep: consumed" & Integer'Image (K - 1) & " of" & Integer'Image (NF) & " fields");
               Failures := Failures + 1;
            end if;
         end;
      else
         Put_Line ("unknown rescue case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Rescue_Line;

   SA_Seq     : Integer_64 := -1;
   SA_Driver  : Adaflight.SmartAudio.Driver;
   SA_Table   : Adaflight.VTX_Table.Table;
   SA_Prepend : Boolean := False;

   function Signed (M : Interfaces.Unsigned_8) return Integer_64 is
     (if Integer_64 (M) >= 128 then Integer_64 (M) - 256 else Integer_64 (M));

   --  The SmartAudio driver state and its getters from field K on.
   procedure Record_SA_State (Name : String; K : Positive; D : Adaflight.SmartAudio.Driver;
                              T : Adaflight.VTX_Table.Table) is
      use Adaflight.SmartAudio;
      Band   : Interfaces.Unsigned_8;
      Chan   : Interfaces.Unsigned_8;
      Index  : Interfaces.Unsigned_8;
      Freq   : Interfaces.Unsigned_16;
      Known  : Boolean;
      Pit    : Boolean;
      Count  : Level_Count;
      Levels : Level_Values;
      Powers : Level_Values;
   begin
      Record_Int (Name & ".version", Int (K), Integer_64 (Version'Pos (D.Device.Version_Seen)));
      Record_Int (Name & ".channel", Int (K + 1), Integer_64 (D.Device.Channel));
      Record_Int (Name & ".power", Int (K + 2), Integer_64 (D.Device.Power));
      Record_Int (Name & ".mode", Int (K + 3), Signed (D.Device.Mode));
      Record_Int (Name & ".freq", Int (K + 4), Integer_64 (D.Device.Freq));
      Record_Int (Name & ".pitfreq", Int (K + 5), Integer_64 (D.Device.Pit_Freq));
      Record_Int (Name & ".willboot", Int (K + 6), Boolean'Pos (D.Device.Will_Boot_Into_Pit_Mode));
      Record_Int (Name & ".sent", Int (K + 7), Integer_64 (D.Stat.Sent));
      Record_Int (Name & ".received", Int (K + 8), Integer_64 (D.Stat.Received));
      Record_Int (Name & ".badpre", Int (K + 9), Integer_64 (D.Stat.Bad_Preamble));
      Record_Int (Name & ".badlen", Int (K + 10), Integer_64 (D.Stat.Bad_Length));
      Record_Int (Name & ".crc", Int (K + 11), Integer_64 (D.Stat.Crc_Errors));
      Record_Int (Name & ".ooo", Int (K + 12), Integer_64 (D.Stat.Out_Of_Order));
      Record_Int (Name & ".badcode", Int (K + 13), Integer_64 (D.Stat.Bad_Code));
      Record_Int (Name & ".baud", Int (K + 14), Integer_64 (Rate_Of (D.Smart_Baud)));
      Record_Int (Name & ".outstanding", Int (K + 15), Integer_64 (D.Outstanding));
      Record_Int (Name & ".lasttx", Int (K + 16), Integer_64 (D.Last_Tx_Ms));
      Record_Int (Name & ".queued", Int (K + 17), Integer_64 ((D.Head + Queue_Size - D.Tail) mod Queue_Size));
      Record_Int (Name & ".nlevels", Int (K + 18), Integer_64 (D.Levels));
      for I in 0 .. 7 loop
         Record_Int (Name & ".level", Int (K + 19 + I), Integer_64 (D.Level_Value (I)));
      end loop;
      Record_Int (Name & ".ready", Int (K + 27), Boolean'Pos (Ready (D)));
      Get_Band_Channel (D, T, Band, Chan, Known);
      Record_Int (Name & ".bc_known", Int (K + 28), Boolean'Pos (Known));
      Record_Int (Name & ".band", Int (K + 29), Integer_64 (Band));
      Record_Int (Name & ".chan", Int (K + 30), Integer_64 (Chan));
      Get_Power_Index (D, Index, Known);
      Record_Int (Name & ".pi_known", Int (K + 31), Boolean'Pos (Known));
      Record_Int (Name & ".pindex", Int (K + 32), Integer_64 (Index));
      Get_Frequency (D, T, Freq, Known);
      Record_Int (Name & ".fr_known", Int (K + 33), Boolean'Pos (Known));
      Record_Int (Name & ".frequency", Int (K + 34), Integer_64 (Freq));
      Get_Status (D, Pit, Known);
      Record_Int (Name & ".st_known", Int (K + 35), Boolean'Pos (Known));
      Record_Int (Name & ".status", Int (K + 36), Boolean'Pos (Pit));
      Get_Power_Levels (D, Count, Levels, Powers);
      Record_Int (Name & ".nl", Int (K + 37), Integer_64 (Count));
      for I in 0 .. 7 loop
         Record_Int (Name & ".levels", Int (K + 38 + I), Integer_64 (Levels (I)));
         Record_Int (Name & ".powers", Int (K + 46 + I), Integer_64 (Powers (I)));
      end loop;
      if D.Port_Open then
         Record_Bytes (Name & ".custom", Hex_Bytes (K + 54), Custom_Status (D));
      else
         Record_Int (Name & ".custom_len", Integer_64 (Hex_Bytes (K + 54)'Length), 0);
      end if;
   end Record_SA_State;

   --  The Tramp driver state and its getters from field K on.
   procedure Record_Tramp_State (Name : String; K : Positive; D : Adaflight.Tramp.Driver;
                                 T : Adaflight.VTX_Table.Table) is
      use Adaflight.Tramp;
      Band   : Interfaces.Unsigned_8;
      Chan   : Interfaces.Unsigned_8;
      Index  : Interfaces.Unsigned_8 := 0;
      Freq   : Interfaces.Unsigned_16;
      Known  : Boolean;
      Pit    : Boolean;
      Locked : Boolean;
   begin
      Record_Int (Name & ".status", Int (K), Integer_64 (Status'Pos (D.Current)));
      Record_Int (Name & ".rfmin", Int (K + 1), Integer_64 (D.Freq_Min));
      Record_Int (Name & ".rfmax", Int (K + 2), Integer_64 (D.Freq_Max));
      Record_Int (Name & ".pmax", Int (K + 3), Integer_64 (D.Power_Max));
      Record_Int (Name & ".curfreq", Int (K + 4), Integer_64 (D.Cur_Freq));
      Record_Int (Name & ".curconfpower", Int (K + 5), Integer_64 (D.Cur_Conf_Power));
      Record_Int (Name & ".curactpower", Int (K + 6), Integer_64 (D.Cur_Act_Power));
      Record_Int (Name & ".curpit", Int (K + 7), Integer_64 (D.Cur_Pit_Mode));
      Record_Int (Name & ".curtemp", Int (K + 8), Integer_64 (D.Cur_Temp));
      Record_Int (Name & ".curctrl", Int (K + 9), Integer_64 (D.Cur_Control_Mode));
      Record_Int (Name & ".conffreq", Int (K + 10), Integer_64 (D.Conf_Freq));
      Record_Int (Name & ".confpower", Int (K + 11), Integer_64 (D.Conf_Power));
      Record_Int (Name & ".confpit", Int (K + 12), Integer_64 (D.Conf_Pit_Mode));
      Record_Int (Name & ".lastconffreq", Int (K + 13), Integer_64 (D.Last_Conf_Freq));
      Record_Int (Name & ".lastconfpower", Int (K + 14), Integer_64 (D.Last_Conf_Power));
      Record_Int (Name & ".lastconfpit", Int (K + 15), Integer_64 (D.Last_Conf_Pit_Mode));
      Record_Int (Name & ".retry", Int (K + 16), Integer_64 (D.Retry_Count));
      Record_Int (Name & ".rxstate", Int (K + 17), Integer_64 (Receive_Phase'Pos (D.Phase)));
      Record_Int (Name & ".rxpos", Int (K + 18), Integer_64 (D.Rx_Pos));
      Record_Int (Name & ".lasttime", Int (K + 19), Integer_64 (D.Last_Time_Us));
      Record_Int (Name & ".ready", Int (K + 20), Boolean'Pos (Ready (D)));
      Get_Band_Channel (D, Band, Chan, Known);
      Record_Int (Name & ".bc_known", Int (K + 21), Boolean'Pos (Known));
      Record_Int (Name & ".band", Int (K + 22), Integer_64 (Band));
      Record_Int (Name & ".chan", Int (K + 23), Integer_64 (Chan));
      Get_Power_Index (D, T, Index, Known);
      Record_Int (Name & ".pi_known", Int (K + 24), Boolean'Pos (Known));
      Record_Int (Name & ".pindex", Int (K + 25), Integer_64 (Index));
      Get_Frequency (D, Freq, Known);
      Record_Int (Name & ".fr_known", Int (K + 26), Boolean'Pos (Known));
      Record_Int (Name & ".frequency", Int (K + 27), Integer_64 (Freq));
      Get_Status (D, Pit, Locked, Known);
      Record_Int (Name & ".st_known", Int (K + 28), Boolean'Pos (Known));
      Record_Int (Name & ".status_bits", Int (K + 29), Boolean'Pos (Pit) + 2 * Boolean'Pos (Locked));
      Record_Int (Name & ".actpower", Int (K + 30), Integer_64 (Actual_Power (D)));
      Record_Int (Name & ".temp", Int (K + 31), Integer_64 (Interfaces.Unsigned_16'Mod (Temperature (D))));
   end Record_Tramp_State;

   --  The bytes a device case still holds for its driver, ahead of the
   --  next step's bytes.
   Max_Pending : constant := 8192;
   subtype Pending_Count is Natural range 0 .. Max_Pending;
   subtype Pending_Bytes is Byte_Array (0 .. Max_Pending - 1);

   --  The table of an init line from field F on: the counts, the
   --  frequencies, the factory flags, the level count and the values.
   procedure Read_Table (T : out Adaflight.VTX_Table.Table; F : Positive) is
      use Adaflight.VTX_Table;
   begin
      T := Default;
      T.Bands := Band_Count (Int (F));
      T.Channels := Channel_Count (Int (F + 1));
      for B in Band_Index loop
         for C in Channel_Index loop
            T.Frequency (B, C) := Interfaces.Unsigned_16 (Int (F + 2 + (B - 1) * 8 + (C - 1)));
         end loop;
         T.Is_Factory (B) := Int (F + 65 + B) = 1;
      end loop;
      T.Power_Levels := Power_Count (Int (F + 74));
      for P in Power_Index loop
         T.Power_Value (P) := Interfaces.Unsigned_16 (Int (F + 74 + P));
      end loop;
   end Read_Table;

   procedure Check_SmartAudio_Line is
      use Adaflight.SmartAudio;
      use Adaflight.VTX_Table;
      Name : constant String := Str (1);
   begin
      if Name = "vtxsainit" then
         SA_Seq := Int (2);
         Read_Table (SA_Table, 8);
         SA_Prepend := Int (6) = 1 and then Int (7) = 1;
         Init (SA_Driver, Int (5) = 1);
         Record_Int (Name & ".init_ok", Int (91), Boolean'Pos (SA_Driver.Port_Open));
         Record_SA_State (Name, 92, SA_Driver, SA_Table);
      elsif Name = "vtxsastep" then
         if Int (2) /= SA_Seq then
            Put_Line ("smartaudio step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Rx       : constant Byte_Array := Hex_Bytes (10);
            Disabled : constant Boolean := Int (5) = 1;
            Op       : constant Integer_64 := Int (6);
            A1       : constant Integer_64 := Int (7);
            A2       : constant Integer_64 := Int (8);
            E        : Events;
         begin
            case Op is
               when 1 =>
                  Set_Band_Channel (SA_Driver, SA_Table, Interfaces.Unsigned_8 (A1), Interfaces.Unsigned_8 (A2));
               when 2 =>
                  Set_Power_Index (SA_Driver, SA_Table, Interfaces.Unsigned_8 (A1));
               when 3 =>
                  Set_Pit_Mode (SA_Driver, A1 = 1);
               when 4 =>
                  Set_Frequency (SA_Driver, Interfaces.Unsigned_16 (A1));
               when 5 =>
                  Set_Mode (SA_Driver, Interfaces.Unsigned_8 (A1));
               when 6 =>
                  Set_Pit_Frequency (SA_Driver, Interfaces.Unsigned_16 (A1));
               when 7 =>
                  if SA_Driver.Port_Open then
                     Set_Band_Channel (SA_Driver, SA_Table, Interfaces.Unsigned_8 (A1), Interfaces.Unsigned_8 (A2));
                     Set_Band_Channel (SA_Driver, SA_Table, Interfaces.Unsigned_8 (A2), Interfaces.Unsigned_8 (A1));
                  end if;
               when others =>
                  null;
            end case;
            Process (SA_Driver, SA_Table, Unsigned_32 (Int (4)), Rx, Disabled, SA_Prepend, E);
            Record_SA_State (Name, 11, SA_Driver, SA_Table);
            Record_Bytes (Name & ".tx", Hex_Bytes (67), E.Tx (0 .. E.Tx_Count - 1));
            Record_Int (Name & ".baudset", Int (68), (if E.Baud_Changed then Integer_64 (Rate_Of (E.New_Baud)) else 0));
         end;
      else
         Put_Line ("unknown smartaudio case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_SmartAudio_Line;

   TM_Seq     : Integer_64 := -1;
   TM_Driver  : Adaflight.Tramp.Driver;
   TM_Table   : Adaflight.VTX_Table.Table;
   TM_Pending : Pending_Bytes := (others => 0);
   TM_Count   : Pending_Count := 0;

   procedure Check_Tramp_Line is
      use Adaflight.Tramp;
      Name : constant String := Str (1);
   begin
      if Name = "vtxtrinit" then
         TM_Seq := Int (2);
         Read_Table (TM_Table, 12);
         TM_Count := 0;
         Init (TM_Driver, Int (3) = 1);
         Record_Int (Name & ".init_ok", Int (95), Boolean'Pos (TM_Driver.Port_Open));
         Record_Tramp_State (Name, 96, TM_Driver, TM_Table);
      elsif Name = "vtxtrstep" then
         if Int (2) /= TM_Seq then
            Put_Line ("tramp step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Fresh    : constant Byte_Array := Hex_Bytes (10);
            Rx       : constant Byte_Array := TM_Pending (0 .. TM_Count - 1) & Fresh;
            Op       : constant Integer_64 := Int (6);
            A1       : constant Integer_64 := Int (7);
            E        : Events;
            Consumed : Natural;
         begin
            if TM_Driver.Port_Open then
               case Op is
                  when 2 => Set_Power_Index (TM_Driver, TM_Table, Interfaces.Unsigned_8 (A1));
                  when 3 => Set_Pit_Mode (TM_Driver, A1 = 1);
                  when 4 => Set_Frequency (TM_Driver, Interfaces.Unsigned_16 (A1));
                  when others => null;
               end case;
            end if;
            Process (TM_Driver, Unsigned_32 (Int (4)), Rx, Int (5) = 1, E, Consumed);
            Record_Tramp_State (Name, 11, TM_Driver, TM_Table);
            Record_Bytes (Name & ".tx", Hex_Bytes (44), E.Tx (0 .. E.Tx_Count - 1));
            Record_Int (Name & ".consumed", Int (45), Integer_64 (Consumed));
            TM_Count := Rx'Length - Consumed;
            TM_Pending (0 .. TM_Count - 1) := Rx (Rx'First + Consumed .. Rx'Last);
         end;
      else
         Put_Line ("unknown tramp case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Tramp_Line;

   VC_Seq        : Integer_64 := -1;
   VC_State      : Adaflight.VTX.State;
   VC_Settings   : Adaflight.VTX.Settings;
   VC_Table      : Adaflight.VTX_Table.Table;
   VC_Conditions : Adaflight.VTX.Conditions;
   VC_Pending    : Pending_Bytes := (others => 0);
   VC_Count      : Pending_Count := 0;
   VC_Kind       : Adaflight.VTX.Device_Kind := Adaflight.VTX.SmartAudio_Device;

   procedure Check_VTX_Control_Line is
      use Adaflight.VTX;
      Name : constant String := Str (1);

      procedure Record_Settings (K : Positive) is
      begin
         Record_Int (Name & ".band", Int (K), Integer_64 (VC_Settings.Band));
         Record_Int (Name & ".channel", Int (K + 1), Integer_64 (VC_Settings.Channel));
         Record_Int (Name & ".power", Int (K + 2), Integer_64 (VC_Settings.Power));
         Record_Int (Name & ".freq", Int (K + 3), Integer_64 (VC_Settings.Freq));
         Record_Int (Name & ".pitfreq", Int (K + 4), Integer_64 (VC_Settings.Pit_Mode_Freq));
         Record_Int (Name & ".lowpower", Int (K + 5), Integer_64 (Low_Power_Disarm'Pos (VC_Settings.Low_Power)));
      end Record_Settings;
   begin
      if Name = "vtxcinit" then
         declare
            Save : Boolean;
         begin
            VC_Seq := Int (2);
            Read_Table (VC_Table, 8);
            VC_Settings := (others => <>);
            VC_Settings.Softserial_Alt := Int (7) = 1;
            VC_Settings.Band := Interfaces.Unsigned_8 (Int (91));
            VC_Settings.Channel := Interfaces.Unsigned_8 (Int (92));
            VC_Settings.Power := Interfaces.Unsigned_8 (Int (93));
            VC_Settings.Freq := Interfaces.Unsigned_16 (Int (94));
            VC_Settings.Pit_Mode_Freq := Interfaces.Unsigned_16 (Int (95));
            VC_Settings.Low_Power := Low_Power_Disarm'Val (Int (96));
            for I in Condition_Index loop
               declare
                  F : constant Positive := 97 + (I - 1) * 6;
               begin
                  VC_Conditions (I) :=
                    (Aux     => Adaflight.Modes.Aux_Channel (Int (F)),
                     Band    => Interfaces.Unsigned_8 (Int (F + 1)),
                     Channel => Interfaces.Unsigned_8 (Int (F + 2)),
                     Power   => Interfaces.Unsigned_8 (Int (F + 3)),
                     Span    => (Adaflight.Modes.Range_Step (Int (F + 4)),
                                 Adaflight.Modes.Range_Step (Int (F + 5))));
               end;
            end loop;
            VC_Count := 0;
            VC_Kind := (if Int (219) = 1 then Tramp_Device else SmartAudio_Device);
            Init (VC_State, VC_Settings, VC_Table, VC_Kind, Int (5) = 1, Int (6) = 1, Save);
            Record_Int (Name & ".save", Int (157), Boolean'Pos (Save));
            Record_Settings (158);
            if VC_Kind = Tramp_Device then
               Record_Tramp_State (Name, 164, VC_State.TR, VC_Table);
            else
               Record_SA_State (Name, 164, VC_State.SA, VC_Table);
            end if;
         end;
      elsif Name = "vtxcstep" then
         if Int (2) /= VC_Seq then
            Put_Line ("vtx control step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Inp : Inputs;
            Aux : Adaflight.Modes.Aux_Values;
            Op  : constant Integer_64 := Int (11);
            A1  : constant Integer_64 := Int (12);
            A2  : constant Integer_64 := Int (13);
            Rx  : constant Byte_Array := VC_Pending (0 .. VC_Count - 1) & Hex_Bytes (30);
            E   : Events;
         begin
            Inp.Now_Ms := Unsigned_32 (Int (4));
            Inp.Now_Us := Unsigned_32 (Int (4)) * 1000;
            Inp.Armed := Int (5) = 1;
            Inp.Was_Ever_Armed := Int (6) = 1;
            Inp.Failsafe := Int (7) = 1;
            Inp.Cli_Mode := Int (8) = 1;
            Inp.Pit_Switch := Int (9) = 1;
            Inp.Control_Disabled := Int (10) = 1;
            for C in Adaflight.Modes.Aux_Channel loop
               Aux (C) := Flt (15 + C);
            end loop;
            case Op is
               when 1 =>
                  Increment_Band (VC_State, VC_Settings, Inp.Armed);
               when 2 =>
                  Decrement_Band (VC_State, VC_Settings, Inp.Armed);
               when 3 =>
                  Increment_Channel (VC_State, VC_Settings, Inp.Armed);
               when 4 =>
                  Decrement_Channel (VC_State, VC_Settings, Inp.Armed);
               when 5 =>
                  Cycle_Band_Or_Channel (VC_State, VC_Settings, VC_Table, Interfaces.Unsigned_8 (A1),
                                         Interfaces.Unsigned_8 (A2));
               when 6 =>
                  Cycle_Power (VC_State, VC_Settings, VC_Table, Interfaces.Unsigned_8 (A1));
               when 7 =>
                  case A1 is
                     when 1 => VC_Settings.Band := Interfaces.Unsigned_8 (A2);
                     when 2 => VC_Settings.Channel := Interfaces.Unsigned_8 (A2);
                     when 3 => VC_Settings.Power := Interfaces.Unsigned_8 (A2);
                     when 4 => VC_Settings.Freq := Interfaces.Unsigned_16 (A2);
                     when 5 => VC_Settings.Pit_Mode_Freq := Interfaces.Unsigned_16 (A2);
                     when others => VC_Settings.Low_Power := Low_Power_Disarm'Val (A2);
                  end case;
               when 8 =>
                  Offer_Spektrum_Control (VC_State, Unsigned_32 (A1));
               when others =>
                  null;
            end case;
            if Int (14) = 1 then
               Update_Activated_Channel (VC_State, VC_Settings, VC_Conditions, Aux, Inp.Armed);
            end if;
            Update (VC_State, VC_Settings, VC_Table, Inp, Rx, E);
            Record_Int (Name & ".save", Int (31), Boolean'Pos (E.Save));
            Record_Settings (32);
            Record_Int (Name & ".locked", Int (38), Boolean'Pos (VC_State.Locked));
            Record_Int (Name & ".selband", Int (39), Integer_64 (VC_State.Selected_Band));
            Record_Int (Name & ".selchan", Int (40), Integer_64 (VC_State.Selected_Channel));
            Record_Int (Name & ".spekword", Int (41), Integer_64 (VC_State.Spektrum_Word));
            if VC_Kind = Tramp_Device then
               Record_Tramp_State (Name, 42, VC_State.TR, VC_Table);
               Record_Bytes (Name & ".tx", Hex_Bytes (98), E.Tramp_Tx.Tx (0 .. E.Tramp_Tx.Tx_Count - 1));
            else
               Record_SA_State (Name, 42, VC_State.SA, VC_Table);
               Record_Bytes (Name & ".tx", Hex_Bytes (98), E.Device.Tx (0 .. E.Device.Tx_Count - 1));
            end if;
            Record_Int (Name & ".baudset", Int (99),
                        (if E.Device.Baud_Changed then Integer_64 (Adaflight.SmartAudio.Rate_Of (E.Device.New_Baud))
                         else 0));
            Record_Int (Name & ".consumed", Int (100), Integer_64 (E.Consumed));
            VC_Count := Rx'Length - E.Consumed;
            VC_Pending (0 .. VC_Count - 1) := Rx (Rx'First + E.Consumed .. Rx'Last);
         end;
      else
         Put_Line ("unknown vtx control case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_VTX_Control_Line;

   LTM_Seq    : Integer_64 := -1;
   LTM_Stream : Adaflight.LTM_Telemetry.Stream;

   procedure Check_LTM_Line is
      use Adaflight.LTM_Telemetry;
      Modes : constant Integer_64 := Int (9);
      Inp   : Inputs;
      O     : Output;

      function Flag (Bit : Natural) return Boolean is ((Modes / 2 ** Bit) mod 2 = 1);
   begin
      if Int (2) /= LTM_Seq then
         LTM_Seq := Int (2);
         LTM_Stream := (others => <>);
      end if;
      Inp.Pitch := Interfaces.Integer_16 (Int (6));
      Inp.Roll := Interfaces.Integer_16 (Int (7));
      Inp.Yaw := Interfaces.Integer_16 (Int (8));
      Inp.Angle := Flag (0);
      Inp.Horizon := Flag (1);
      Inp.Altitude_Hold := Flag (3);
      Inp.Position_Hold := Flag (5);
      Inp.Headfree := Flag (6);
      Inp.Passthru := Flag (8);
      Inp.Rescue := Flag (11);
      Inp.Armed := Int (10) mod 2 = 1;
      Inp.Failsafe := Int (11) = 1;
      Inp.Voltage_Cv := Interfaces.Unsigned_16 (Int (12));
      Inp.Mah_Drawn := I32 (13);
      Inp.Rssi := Interfaces.Unsigned_16 (Int (14));
      Inp.GPS_Present := Int (15) = 1;
      Inp.Fix := Int (16) = 1;
      Inp.Num_Sat := Interfaces.Unsigned_8 (Int (17));
      Inp.Lat := I32 (18);
      Inp.Lon := I32 (19);
      Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (20));
      Inp.Altitude_Cm := I32 (21);
      Inp.Home_Lat := I32 (22);
      Inp.Home_Lon := I32 (23);
      Inp.Fix_Home := Int (24) = 1;
      Update (LTM_Stream, Inp, Unsigned_32 (Int (4)), Int (5) = 1, O);
      Record_Bytes ("ltm.frames", Hex_Bytes (25), O.Data (0 .. O.Count - 1));
   end Check_LTM_Line;

   LT_Seq      : Integer_64 := -1;
   LT_Timer    : Adaflight.GPS_Lap_Timer.Timer;
   LT_Settings : Adaflight.GPS_Lap_Timer.Settings;
   LT_Cos_Lat  : Adaflight.Maths.Cosine := 1.0;

   procedure Check_Lap_Timer_Line is
      package LT renames Adaflight.GPS_Lap_Timer;
      Name : constant String := Str (1);

      procedure Record_State (K : Positive) is
         T : LT.Timer renames LT_Timer;
      begin
         Record_Int (Name & ".gatelat", Int (K), Integer_64 (T.Gate.Lat));
         Record_Int (Name & ".gatelon", Int (K + 1), Integer_64 (T.Gate.Lon));
         Record_Int (Name & ".nset", Int (K + 2), Integer_64 (T.Set_Readings));
         Record_Int (Name & ".dist", Int (K + 3), Integer_64 (T.Distance_To_Gate_Cm));
         Record_Int (Name & ".dir", Int (K + 4), Integer_64 (T.Direction_To_Gate));
         Record_Int (Name & ".running", Int (K + 5), Boolean'Pos (T.Timer_Running));
         Record_Int (Name & ".lastlap", Int (K + 6), Integer_64 (T.Time_Of_Last_Lap));
         Record_Int (Name & ".nlaps", Int (K + 7), Integer_64 (T.Laps_Recorded));
         Record_Int (Name & ".best", Int (K + 8), Integer_64 (T.Best_Lap_Time));
         Record_Int (Name & ".best3", Int (K + 9), Integer_64 (T.Best_Three));
         for I in LT.Lap_Index loop
            Record_Int (Name & ".prev", Int (K + 10 + I), Integer_64 (T.Previous (I)));
         end loop;
         Record_Int (Name & ".mindist", Int (K + 13), Integer_64 (T.Min_Distance));
         Record_Int (Name & ".mindisttime", Int (K + 14), Integer_64 (T.Min_Distance_Time));
         Record_Int (Name & ".wasin", Int (K + 15), Boolean'Pos (T.Was_In_Circle));
         Record_Int (Name & ".setting", Int (K + 16), Boolean'Pos (T.Setting_Gate));
         Record_Int (Name & ".cfglat", Int (K + 17), Integer_64 (LT_Settings.Gate_Lat));
         Record_Int (Name & ".cfglon", Int (K + 18), Integer_64 (LT_Settings.Gate_Lon));
      end Record_State;
   begin
      if Name = "ltinit" then
         LT_Seq := Int (2);
         LT_Settings := (Gate_Lat           => Interfaces.Integer_32 (Int (3)),
                         Gate_Lon           => Interfaces.Integer_32 (Int (4)),
                         Minimum_Lap_Time_S => Interfaces.Unsigned_16 (Int (5)),
                         Gate_Tolerance_M   => Interfaces.Unsigned_8 (Int (6)));
         LT_Cos_Lat := Flt (7);
         LT_Timer := (Gate => (others => 0), others => <>);
         LT.Init (LT_Timer, LT_Settings);
      elsif Name = "ltstep" then
         if Int (2) /= LT_Seq then
            Put_Line ("lap timer step without its start");
            Failures := Failures + 1;
            return;
         end if;
         case Int (4) is
            when 0 =>
               LT.New_GPS_Data (LT_Timer, LT_Settings,
                                (Lat    => Interfaces.Integer_32 (Int (5)),
                                 Lon    => Interfaces.Integer_32 (Int (6)),
                                 Alt_Cm => 0),
                                Interfaces.Unsigned_32 (Int (7)), LT_Cos_Lat, Int (8) /= 0);
            when 1 =>
               LT.Start_Set_Gate (LT_Timer);
            when others =>
               LT.End_Set_Gate (LT_Timer, LT_Settings);
         end case;
         Record_State (9);
      else
         Put_Line ("unknown lap timer case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Lap_Timer_Line;

   MB_Seq    : Integer_64 := -1;
   MB_Wing   : Boolean := False;
   MB_Buffer : Byte_Array (0 .. 1023) := (others => 0);

   procedure Check_MSP_Box_Line is
      package MB renames Adaflight.MSP_Box;
      use type Interfaces.Unsigned_8;
      Name : constant String := Str (1);

      function Mask_Of (Low, High : Integer_64) return MB.Active_Mask is
         M : MB.Active_Mask := (others => False);
         W : constant array (0 .. 1) of Unsigned_32 := (Unsigned_32 (Low), Unsigned_32 (High));
      begin
         for Bx in MB.Box loop
            M (Bx) := (W (MB.Box'Pos (Bx) / 32) and Interfaces.Shift_Left (1, MB.Box'Pos (Bx) mod 32)) /= 0;
         end loop;
         return M;
      end Mask_Of;

      function Modes_Of (Bits : Integer_64) return MB.Mode_Set is
         Shift : constant array (Adaflight.Arming.Flight_Mode) of Natural :=
           (Adaflight.Arming.Angle_Mode => 0, Adaflight.Arming.Horizon_Mode => 1, Adaflight.Arming.Mag_Mode => 2,
            Adaflight.Arming.Alt_Hold_Mode => 3, Adaflight.Arming.Pos_Hold_Mode => 5,
            Adaflight.Arming.Headfree_Mode => 6, Adaflight.Arming.Chirp_Mode => 7,
            Adaflight.Arming.Passthru_Mode => 8, Adaflight.Arming.Failsafe_Mode => 10,
            Adaflight.Arming.GPS_Rescue_Mode => 11, Adaflight.Arming.Autopilot_Mode => 12,
            Adaflight.Arming.Launch_Mode => 13);
         M : MB.Mode_Set := (others => False);
      begin
         for F in Adaflight.Arming.Flight_Mode loop
            M (F) := (Unsigned_32 (Bits) and Interfaces.Shift_Left (1, Shift (F))) /= 0;
         end loop;
         return M;
      end Modes_Of;

      function User_Name_Of (I : Positive) return MB.User_Name is
         Raw : constant Byte_Array := Hex_Bytes (I);
         N   : MB.User_Name;
      begin
         for K in Raw'Range loop
            exit when Raw (K) = 0;
            N.Text (K + 1) := Character'Val (Raw (K));
            N.Length := K + 1;
         end loop;
         return N;
      end User_Name_Of;
   begin
      if Name = "mbinit" then
         MB_Seq := Int (2);
         MB_Wing := Int (3) /= 0;
      elsif Name = "mbstep" then
         if Int (2) /= MB_Seq then
            Put_Line ("box step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Active   : constant MB.Active_Mask := Mask_Of (Int (5), Int (6));
            Flight   : constant MB.Mode_Set := Modes_Of (Int (7));
            Armed    : constant Boolean := Int (8) /= 0;
            Switches : constant MB.Active_Mask := Mask_Of (Int (9), Int (10));
            Page     : constant Natural := Natural (Int (11));
            Name_Cap : constant Natural := Natural (Int (12));
            Id_Cap   : constant Natural := Natural (Int (13));
            Names    : constant MB.User_Names :=
              (Adaflight.Modes.User_1 => User_Name_Of (14), Adaflight.Modes.User_2 => User_Name_Of (15),
               Adaflight.Modes.User_3 => User_Name_Of (16), Adaflight.Modes.User_4 => User_Name_Of (17));
            Perm     : constant Byte := Byte (Int (18));
            Packed   : MB.Packed_Words;
            Count    : Natural;
            S        : Adaflight.Stream_Buffers.Stream;
            Found    : Boolean;
            Which    : MB.Box;
         begin
            MB.Pack_Flight_Mode_Flags (Active, Armed, Flight, Switches, MB_Wing, Packed, Count);
            Record_Int (Name & ".count", Int (19), Integer_64 (Count));
            Record_Int (Name & ".packed0", Int (20), Integer_64 (Packed (0)));
            Record_Int (Name & ".packed1", Int (21), Integer_64 (Packed (1)));
            Adaflight.Stream_Buffers.Init (S, 0, Name_Cap);
            MB.Serialize_Box_Reply (MB_Buffer, S, Active, Page, MB.Box_Names, Names);
            Record_Int (Name & ".namelen", Int (22), Integer_64 (S.Next));
            Record_Bytes (Name & ".names", Hex_Bytes (23), MB_Buffer (0 .. S.Next - 1));
            Adaflight.Stream_Buffers.Init (S, 0, Id_Cap);
            MB.Serialize_Box_Reply (MB_Buffer, S, Active, Page, MB.Box_Permanent_Ids, Names);
            Record_Int (Name & ".idlen", Int (24), Integer_64 (S.Next));
            Record_Bytes (Name & ".ids", Hex_Bytes (25), MB_Buffer (0 .. S.Next - 1));
            MB.Find_By_Permanent_Id (Perm, Found, Which);
            Record_Int (Name & ".found", Int (26), (if Found then Integer_64 (MB.Box'Pos (Which)) else -1));
         end;
      else
         Put_Line ("unknown box case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_MSP_Box_Line;

   subtype DQ_Target is Adaflight.Dispatch.Target;
   package DQ renames Adaflight.Dispatch;
   DQ_Seq   : Integer_64 := -1;
   DQ_Queue : DQ.Queue;

   procedure Check_Dispatch_Line is
      Name : constant String := Str (1);
   begin
      if Name = "dqinit" then
         DQ_Seq := Int (2);
         DQ_Queue := (others => <>);
      elsif Name = "dqstep" then
         if Int (2) /= DQ_Seq then
            Put_Line ("dispatch step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Now   : constant Unsigned_32 := Unsigned_32 (Int (7));
            Fired : constant String := Str (8);
            Pos   : Positive := Fired'First;
            T     : DQ_Target;
            Due   : Boolean;
            Seen  : Natural := 0;
            Want  : Natural := 0;
         begin
            case Int (4) is
               when 0 =>
                  DQ.Add (DQ_Queue, DQ_Target'Val (Int (5)), Now, Interfaces.Integer_32 (Int (6)));
               when 2 =>
                  --  each fired item is a target, with its requeue delay after a colon
                  if Fired /= "-" then
                     for C of Fired loop
                        if C = ';' then
                           Want := Want + 1;
                        end if;
                     end loop;
                     Want := Want + 1;
                  end if;
                  loop
                     DQ.Take_Due (DQ_Queue, Now, T, Due);
                     exit when not Due;
                     Seen := Seen + 1;
                     if Seen > Want then
                        Record_Int (Name & ".fired", Integer_64 (Want), Integer_64 (Seen));
                        exit;
                     end if;
                     declare
                        Item_End : Natural := Pos;
                     begin
                        while Item_End <= Fired'Last and then Fired (Item_End) /= ';' loop
                           Item_End := Item_End + 1;
                        end loop;
                        declare
                           Item  : constant String := Fired (Pos .. Item_End - 1);
                           Colon : Natural := 0;
                        begin
                           for I in Item'Range loop
                              if Item (I) = ':' then
                                 Colon := I;
                              end if;
                           end loop;
                           if Colon = 0 then
                              Record_Int (Name & ".fired", Integer_64'Value (Item), Integer_64 (DQ_Target'Pos (T)));
                           else
                              Record_Int (Name & ".fired", Integer_64'Value (Item (Item'First .. Colon - 1)),
                                          Integer_64 (DQ_Target'Pos (T)));
                              DQ.Add (DQ_Queue, T, Now,
                                      Interfaces.Integer_32 (Integer_64'Value (Item (Colon + 1 .. Item'Last))));
                           end if;
                        end;
                        Pos := Item_End + 1;
                     end;
                  end loop;
                  if Seen < Want then
                     Record_Int (Name & ".fired", Integer_64 (Want), Integer_64 (Seen));
                  end if;
               when 3 =>
                  DQ.Enable (DQ_Queue);
               when others =>
                  null;
            end case;
            Record_Int (Name & ".enabled", Int (9), Boolean'Pos (DQ_Queue.Enabled));
            Record_Int (Name & ".length", Int (10), Integer_64 (DQ_Queue.Length));
            declare
               Order : String (1 .. DQ_Queue.Length);
            begin
               for I in Order'Range loop
                  Order (I) := Character'Val (Character'Pos ('0') + DQ_Target'Pos (DQ_Queue.Queued (I)));
               end loop;
               if Order'Length = 0 then
                  Record_Int (Name & ".order", (if Str (11) = "-" then 0 else 1), 0);
               else
                  Record_Int (Name & ".order", (if Str (11) = Order then 0 else 1), 0);
               end if;
            end;
            for E in DQ_Target loop
               Record_Int (Name & ".due", Int (12 + 2 * DQ_Target'Pos (E)), Integer_64 (DQ_Queue.Due_Us (E)));
               Record_Int (Name & ".inq", Int (13 + 2 * DQ_Target'Pos (E)), Boolean'Pos (DQ_Queue.In_Queue (E)));
            end loop;
         end;
      else
         Put_Line ("unknown dispatch case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Dispatch_Line;

   ER_Seq      : Integer_64 := -1;
   ER_Receiver : Adaflight.ExpressLRS_Receiver.Receiver;
   ER_Settings : Adaflight.ExpressLRS_Receiver.Settings;
   ER_Payload  : Adaflight.ExpressLRS_Receiver.Packet := (others => 0);
   ER_Channels : Adaflight.ExpressLRS_Receiver.Channels := (others => 0);

   procedure Check_ELRS_Receiver_Line is
      package ER renames Adaflight.ExpressLRS_Receiver;
      use type Adaflight.ExpressLRS_Receiver.Tick_Tock;
      Name : constant String := Str (1);

      function Packet_Of (I : Positive) return ER.Packet is
         Raw : constant Byte_Array := Hex_Bytes (I);
         P   : ER.Packet := (others => 0);
      begin
         for K in P'Range loop
            exit when K > Raw'Last;
            P (K) := Raw (K);
         end loop;
         return P;
      end Packet_Of;

      procedure Record_State (S : Positive) is
         R : ER.Receiver renames ER_Receiver;
         T : ER.Timer renames ER_Receiver.Timing;
         L : ER.Phase_Lock renames ER_Receiver.Lock;
         G : ER.Radio_Config renames ER_Receiver.Config;
      begin
         Record_Int (Name & ".connection", Int (S), Integer_64 (ER.Connection_State'Pos (R.Connection)));
         Record_Int (Name & ".timerstate", Int (S + 1), Integer_64 (ER.Timer_State'Pos (R.Timer_St)));
         Record_Int (Name & ".nonce", Int (S + 2), Integer_64 (R.Nonce));
         Record_Int (Name & ".rate", Int (S + 3), Integer_64 (R.Rate));
         Record_Int (Name & ".nextrate", Int (S + 4), Integer_64 (R.Next_Rate));
         Record_Int (Name & ".switchmode", Int (S + 5), Integer_64 (R.Switch_Mode));
         Record_Int (Name & ".binding", Int (S + 6), Boolean'Pos (R.In_Binding_Mode));
         Record_Int (Name & ".started", Int (S + 7), Boolean'Pos (R.Started));
         Record_Int (Name & ".cfgchanged", Int (S + 8), Boolean'Pos (R.Config_Changed));
         Record_Int (Name & ".initpending", Int (S + 9), Boolean'Pos (R.Initialize_Pending));
         Record_Int (Name & ".lockrf", Int (S + 10), Boolean'Pos (R.Lock_RF_Mode));
         Record_Int (Name & ".alreadyfhss", Int (S + 11), Boolean'Pos (R.Already_FHSS));
         Record_Int (Name & ".alreadytelem", Int (S + 12), Boolean'Pos (R.Already_Telem_Resp));
         Record_Int (Name & ".freqoffset", Int (S + 13), Integer_64 (R.Freq_Offset));
         Record_Int (Name & ".currentfreq", Int (S + 14), Integer_64 (R.Current_Freq));
         Record_Int (Name & ".cycleinterval", Int (S + 15), Integer_64 (R.Cycle_Interval_Ms));
         Record_Int (Name & ".cyclemult", Int (S + 16), Integer_64 (R.RF_Mode_Cycle_Multiplier));
         Record_Int (Name & ".rssi", Int (S + 17), Integer_64 (R.RSSI));
         Record_Int (Name & ".snr", Int (S + 18), Integer_64 (R.SNR));
         Record_Int (Name & ".rssifiltered", Int (S + 19), Integer_64 (R.RSSI_Filtered));
         Record_Int (Name & ".rsnrfiltered", Int (S + 20), Integer_64 (R.RSNR_Filtered));
         Record_Int (Name & ".uplinklq", Int (S + 21), Integer_64 (R.Uplink_LQ));
         Record_Int (Name & ".lq", Int (S + 22), Integer_64 (R.LQ.Value));
         Record_Int (Name & ".modelmatch", Int (S + 23), Boolean'Pos (R.Model_Match));
         Record_Int (Name & ".txpower", Int (S + 24), Integer_64 (R.Tx_Power));
         Record_Int (Name & ".wideindex", Int (S + 25), Integer_64 (R.Wide_Switch_Index));
         Record_Int (Name & ".tlmdenom", Int (S + 26), Integer_64 (R.Tlm_Denom));
         Record_Int (Name & ".nexttelem", Int (S + 27), Integer_64 (ER.Telemetry_Type'Pos (R.Next_Telemetry) + 1));
         Record_Int (Name & ".burstcount", Int (S + 28), Integer_64 (R.Burst_Count));
         Record_Int (Name & ".burstmax", Int (S + 29), Integer_64 (R.Burst_Max));
         Record_Int (Name & ".burstvalid", Int (S + 30), Boolean'Pos (R.Burst_Valid));
         Record_Int (Name & ".lost", Int (S + 31), Integer_64 (R.Lost_Connections));
         Record_Int (Name & ".crcinit", Int (S + 32), Integer_64 (R.CRC_Initializer));
         Record_Bytes (Name & ".uid", Hex_Bytes (S + 33), R.UID);
         Record_Int (Name & ".cfgrate", Int (S + 34), Integer_64 (ER_Settings.Rate));
         Record_Int (Name & ".cfgmodel", Int (S + 35), Integer_64 (ER_Settings.Model_Id));
         Record_Bytes (Name & ".cfguid", Hex_Bytes (S + 36), ER_Settings.UID);
         Record_Int (Name & ".trunning", Int (S + 37), Boolean'Pos (T.Running));
         Record_Int (Name & ".tphase", Int (S + 38), Integer_64 (ER.Tick_Tock'Pos (T.Phase)));
         Record_Int (Name & ".tinterval", Int (S + 39), Integer_64 (T.Interval));
         Record_Int (Name & ".tticks", Int (S + 40), Integer_64 (T.Frequency_Offset_Ticks));
         Record_Int (Name & ".tshift", Int (S + 41), Integer_64 (T.Phase_Shift_Us));
         Record_Int (Name & ".tperiod", Int (S + 42), Integer_64 (T.Period));
         Record_Int (Name & ".tmaxperiod", Int (S + 43), Integer_64 (T.Max_Period));
         Record_Int (Name & ".tperiods", Int (S + 44), Integer_64 (T.Period_Count));
         Record_Int (Name & ".tresets", Int (S + 45), Integer_64 (T.Counter_Resets));
         Record_Int (Name & ".plraw", Int (S + 46), Integer_64 (L.Raw_Offset_Us));
         Record_Int (Name & ".plprev", Int (S + 47), Integer_64 (L.Previous_Raw_Offset_Us));
         Record_Int (Name & ".ploffset", Int (S + 48), Integer_64 (L.Offset_Us));
         Record_Int (Name & ".pldelta", Int (S + 49), Integer_64 (L.Offset_Delta_Us));
         Record_Int (Name & ".evinternal", Int (S + 50), Boolean'Pos (R.Events.Internal_Seen));
         Record_Int (Name & ".evexternal", Int (S + 51), Boolean'Pos (R.Events.External_Seen));
         Record_Int (Name & ".configs", Int (S + 52), Integer_64 (R.Config_Count));
         Record_Int (Name & ".cfgbw", Int (S + 53), Integer_64 (G.Bandwidth));
         Record_Int (Name & ".cfgsf", Int (S + 54), Integer_64 (G.Spreading));
         Record_Int (Name & ".cfgcr", Int (S + 55), Integer_64 (G.Coding));
         Record_Int (Name & ".cfgfreq", Int (S + 56), Integer_64 (G.Frequency));
         Record_Int (Name & ".cfgpre", Int (S + 57), Integer_64 (G.Preamble));
         Record_Int (Name & ".cfgiq", Int (S + 58), Boolean'Pos (G.IQ_Inverted));
         Record_Int (Name & ".cfgsync", Int (S + 59), Integer_64 (G.FLRC_Sync_Word));
         Record_Int (Name & ".cfgseed", Int (S + 60), Integer_64 (G.FLRC_CRC_Seed));
         Record_Int (Name & ".cfgflrc", Int (S + 61), Boolean'Pos (G.Is_FLRC));
         Record_Int (Name & ".starts", Int (S + 62), Integer_64 (R.Start_Count));
         Record_Int (Name & ".powers", Int (S + 63), Integer_64 (R.Power_Count));
         Record_Int (Name & ".rfmode", Int (S + 64), Integer_64 (R.RF_Mode_Report));
         Record_Int (Name & ".rssireport", Int (S + 65), Integer_64 (R.RSSI_Report));
         Record_Int (Name & ".rssidirect", Int (S + 66), Boolean'Pos (R.RSSI_Direct));
         Record_Int (Name & ".rssidbm", Int (S + 67), Integer_64 (R.RSSI_Dbm_Report));
         Record_Int (Name & ".rsnrreport", Int (S + 68), Integer_64 (R.RSNR_Report));
         Record_Int (Name & ".lqreport", Int (S + 69), Integer_64 (R.LQ_Report));
         Record_Int (Name & ".uplinkpower", Int (S + 70), Integer_64 (R.Uplink_Power_Report));
         Record_Int (Name & ".reports", Int (S + 71), Integer_64 (R.Report_Count));
         Record_Int (Name & ".saves", Int (S + 72), Integer_64 (R.Save_Count));
         Record_Int (Name & ".mspready", Int (S + 73), Integer_64 (R.MSP_Ready_Count));
         Record_Int (Name & ".fhssindex", Int (S + 74), Integer_64 (R.Hops.Index));
         Record_Int (Name & ".snrsum", Int (S + 75), Integer_64 (R.SNR_Mean.Sum));
         Record_Int (Name & ".snrcount", Int (S + 76), Integer_64 (R.SNR_Mean.Count));
         Record_Bytes (Name & ".telemetry", Hex_Bytes (S + 77), R.Telemetry_Packet);
         Record_Int (Name & ".packetstatus", Int (S + 78), Integer_64 (ER.Packet_Status'Pos (R.Packet_St)));
         Record_Int (Name & ".mspconfirm", Int (S + 79), Boolean'Pos (R.MSP.Confirm));
         Record_Int (Name & ".senderstate", Int (S + 80),
                     Integer_64 (Adaflight.ExpressLRS_Telemetry.Sender_State'Pos (R.Sender.State)));
         Record_Int (Name & ".senderoffset", Int (S + 81), Integer_64 (R.Sender.Offset));
         Record_Int (Name & ".senderlength", Int (S + 82), Integer_64 (R.Sender.Length));
         Record_Int (Name & ".senderpackage", Int (S + 83), Integer_64 (R.Sender.Current_Package));
         Record_Int (Name & ".senderwait", Int (S + 84), Boolean'Pos (R.Sender.Wait_Until_Confirm));
         Record_Int (Name & ".senderwaitcount", Int (S + 85), Integer_64 (R.Sender.Wait_Count));
         Record_Int (Name & ".sendermaxwait", Int (S + 86), Integer_64 (R.Sender.Max_Wait_Count));
         Record_Int (Name & ".senderlast", Int (S + 87), Integer_64 (R.Sender.Bytes_Last_Payload));
         Record_Int (Name & ".mspoffset", Int (S + 88), Integer_64 (R.MSP.Offset));
         Record_Int (Name & ".msppackage", Int (S + 89), Integer_64 (R.MSP.Current_Package));
         Record_Int (Name & ".msplength", Int (S + 90), Integer_64 (R.MSP.Length));
         Record_Int (Name & ".mspfinished", Int (S + 91), Boolean'Pos (R.MSP.Finished));
      end Record_State;
   begin
      if Name = "erinit" then
         ER_Seq := Int (2);
         ER_Settings := (Domain   => Adaflight.ExpressLRS.Frequency_Domain'Val (Int (3)),
                         Rate     => Natural (Int (4)),
                         UID      => Packet_Of (5) (0 .. 5),
                         Model_Id => Byte (Int (6)));
         ER_Payload := (others => 0);
         ER_Channels := (others => 0);
         ER.Init (ER_Receiver, ER_Settings, Unsigned_32 (Int (8)));
         Record_State (9);
      elsif Name = "erstep" then
         if Int (2) /= ER_Seq then
            Put_Line ("receiver step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Op     : constant Integer_64 := Int (4);
            Now_Us : constant Unsigned_32 := Unsigned_32 (Int (5));
            Now_Ms : constant Unsigned_32 := Unsigned_32 (Int (6));
            Status : ER.Packet_Status;
            Hop    : Boolean := False;
         begin
            case Op is
               when 0 =>
                  declare
                     Frame : constant Byte_Array := Hex_Bytes (15);
                     Len   : constant Natural := Natural (Int (11));
                  begin
                     ER.Process_Packet (ER_Receiver, ER_Settings, Packet_Of (10), Now_Us, Now_Ms,
                                        Interfaces.Integer_8 (Int (7)), Interfaces.Integer_8 (Int (8)),
                                        ER_Payload, Status);
                     ER.Hop_Required (ER_Receiver, Hop);
                     if ER.Telemetry_Response_Required (ER_Receiver) then
                        ER.Do_Telemetry (ER_Receiver, Frame (0 .. Len - 1), Int (9) /= 0);
                     end if;
                     Record_Int (Name & ".hop", Int (12), Boolean'Pos (Hop));
                     Record_Bytes (Name & ".payload", Hex_Bytes (14), ER_Payload);
                  end;
               when 1 =>
                  declare
                     Was_Tock : constant Boolean := ER_Receiver.Timing.Phase = ER.Tock;
                  begin
                     if Int (9) /= 0 then
                        ER.Timer_Update (ER_Receiver, ER_Settings, Now_Us);
                     end if;
                     if Was_Tock then
                        ER.Hop_Required (ER_Receiver, Hop);
                     end if;
                     Record_Int (Name & ".hop", Int (12), Boolean'Pos (Hop));
                  end;
               when 2 =>
                  ER.Data_Received (ER_Receiver, ER_Settings, Now_Ms, Int (7) /= 0, Int (8) /= 0, Status);
                  Record_Int (Name & ".status", Int (12), Integer_64 (ER.Packet_Status'Pos (Status)));
               when others =>
                  ER.Set_RC_Data (ER_Receiver, Packet_Of (10), ER_Channels);
                  declare
                     Text : constant String := Str (14);
                     From : Positive := Text'First;
                     Ch   : Natural := 0;
                  begin
                     for I in Text'Range loop
                        if Text (I) = ';' or else I = Text'Last then
                           declare
                              Last : constant Natural := (if Text (I) = ';' then I - 1 else I);
                           begin
                              if Ch <= ER.Channel_Index'Last then
                                 Record_Int (Name & ".rc", Integer_64'Value (Text (From .. Last)),
                                             Integer_64 (ER_Channels (Ch)));
                              end if;
                           end;
                           Ch := Ch + 1;
                           From := I + 1;
                        end if;
                     end loop;
                  end;
            end case;
            Record_Int (Name & ".freq", Int (13), Integer_64 (ER_Receiver.Current_Freq));
            Record_State (16);
         end;
      else
         Put_Line ("unknown receiver case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_ELRS_Receiver_Line;

   package BH renames Adaflight.Blackbox_Header;
   BH_Seq   : Integer_64 := -1;
   BH_Wing  : Boolean := False;
   BH_W     : BH.Writer;
   BH_H     : BH.Header_State;
   BH_In    : BH.Condition_Inputs;
   BH_Cache : BH.Condition_Set := (others => False);
   BH_Info  : BH.Sysinfo;
   BH_Buf   : Byte_Array (0 .. 4095) := (others => 0);

   procedure Check_Blackbox_Header_Line is
      Name : constant String := Str (1);
   begin
      if Name = "hdrinit" then
         BH_Seq := Int (2);
         BH_Wing := Int (3) = 1;
         BH_W := (Kind => BH.Device_Kind'Val (Int (4)), Max_Per_Iteration => Natural (Int (5)),
                  Buffer_Size => Natural (Int (6)), others => <>);
         BH_In := (Fields_Disabled_Mask => Unsigned_32 (Int (7)), Motors => Natural (Int (8)),
                   Has_Servos => Int (9) = 1, DShot_Telemetry => Int (10) = 1, Mag_Present => Int (11) = 1,
                   Baro_Present => Int (12) = 1, Rangefinder_Present => Int (13) = 1, Acc_Present => Int (14) = 1,
                   RSSI_Configured => Int (15) = 1, Debug_Active => Int (16) = 1,
                   Voltage_Meter => Adaflight.Battery.Voltage_Source'Val (Int (17)),
                   Current_Meter => Adaflight.Battery.Current_Source'Val (Int (18)),
                   PID_D => (Interfaces.Integer_32 (Int (19)), Interfaces.Integer_32 (Int (20)),
                             Interfaces.Integer_32 (Int (21))),
                   PID_S => (Interfaces.Integer_32 (Int (22)), Interfaces.Integer_32 (Int (23)),
                             Interfaces.Integer_32 (Int (24))),
                   I_Interval => Interfaces.Integer_32 (Int (27)), P_Interval => Interfaces.Integer_32 (Int (28)));
         BH.Build_Cache (BH_Cache, BH_In);
         for V in BH.Value_Name loop
            BH_Info.Values (V) := Interfaces.Integer_32 (Int (27 + BH.Value_Name'Pos (V)));
         end loop;
         for T in BH.Text_Name loop
            declare
               Raw : constant Byte_Array := Hex_Bytes (289 + BH.Text_Name'Pos (T));
               L   : constant Natural := Natural'Min (Raw'Length, BH.Text_Max);
            begin
               BH_Info.Texts (T).Data := (others => ' ');
               for K in 0 .. L - 1 loop
                  BH_Info.Texts (T).Data (1 + K) := Character'Val (Raw (Raw'First + K));
               end loop;
               BH_Info.Texts (T).Length := L;
            end;
         end loop;
         BH_H := (others => <>);
      elsif Name = "hdrstep" then
         if Int (2) /= BH_Seq then
            Put_Line ("flight log header step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Op     : constant Integer_64 := Int (4);
            Now    : constant Unsigned_32 := Unsigned_32 (Int (5));
            Strm   : Adaflight.Stream_Buffers.Stream;
            Result : Boolean := False;
         begin
            Adaflight.Stream_Buffers.Init (Strm, 0, BH_Buf'Length);
            case Op is
               when 10 =>
                  BH_W.Budget := 0;
                  BH_H.Index := 0;
                  BH_H.Start_Time_Ms := Now;
               when 11 =>
                  BH_H.Index := 0;
                  BH_H.Field := -1;
               when 12 =>
                  BH_H.Index := 0;
               when 0 .. 5 =>
                  BH_W.Free := Natural (Int (6));
                  BH.Replenish (BH_W);
                  case Op is
                     when 0 =>
                        BH.Send_Header_Text (BH_H, BH_W, BH_Buf, Strm, Now, Result);
                     when 1 =>
                        BH.Send_Field_Definition (BH_H, BH_W, BH_Buf, Strm, BH.Main_Fields, BH_Wing, BH_Cache, Result);
                     when 2 =>
                        BH.Send_Field_Definition (BH_H, BH_W, BH_Buf, Strm, BH.GPS_Home_Fields, BH_Wing, BH_Cache,
                                                  Result);
                     when 3 =>
                        BH.Send_Field_Definition (BH_H, BH_W, BH_Buf, Strm, BH.GPS_Fields, BH_Wing, BH_Cache, Result);
                     when 4 =>
                        BH.Send_Field_Definition (BH_H, BH_W, BH_Buf, Strm, BH.Slow_Fields, BH_Wing, BH_Cache, Result);
                     when others =>
                        BH.Send_Sysinfo (BH_H, BH_W, BH_Buf, Strm, BH_Wing, BH_Info, BH_Cache, BH_In.Current_Meter,
                                         Result);
                  end case;
               when others =>
                  null;
            end case;
            if Op in 0 .. 5 then
               Record_Int (Name & ".result", Int (7), Boolean'Pos (Result));
            end if;
            Record_Int (Name & ".budget", Int (8), Integer_64 (BH_W.Budget));
            Record_Int (Name & ".index", Int (9), Integer_64 (BH_H.Index));
            if Op in 0 | 10 then
               Record_Int (Name & ".start", Int (10), Integer_64 (BH_H.Start_Time_Ms));
            else
               Record_Int (Name & ".field", Int (10), Integer_64 (BH_H.Field));
            end if;
            Record_Bytes (Name & ".bytes", Hex_Bytes (11), BH_Buf (0 .. Strm.Next - 1));
         end;
      else
         Put_Line ("unknown flight log header case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Blackbox_Header_Line;

   package BR renames Adaflight.Blackbox;
   BR_Seq  : Integer_64 := -1;
   BR_L    : BR.Recorder;
   BR_C    : BR.Settings;
   BR_In   : BR.Inputs;
   BR_Loop : BR.Loop_Time_Us := 125;
   BR_Buf  : Byte_Array (0 .. 8191) := (others => 0);

   function BR_I32 (I : Positive) return Interfaces.Integer_32 is (Interfaces.Integer_32 (Int (I)));
   function BR_U32 (I : Positive) return Unsigned_32 is (Unsigned_32 (Int (I)));
   function BR_U16 (I : Positive) return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16 (Int (I)));
   function BR_I16 (I : Positive) return Interfaces.Integer_16 is (Interfaces.Integer_16 (Int (I)));
   function BR_Axis (I : Positive) return BR.Axis_Floats is (Flt (I), Flt (I + 1), Flt (I + 2));
   function BR_Signed_Start (V : Unsigned_32) return Integer_64 is
     (if V >= 2 ** 31 then Integer_64 (V) - 2 ** 32 else Integer_64 (V));

   procedure BR_Text (T : in out Adaflight.Blackbox_Header.Text; I : Positive) is
      Raw : constant Byte_Array := Hex_Bytes (I);
      L   : constant Natural := Natural'Min (Raw'Length, Adaflight.Blackbox_Header.Text_Max);
   begin
      T.Data := (others => ' ');
      for K in 0 .. L - 1 loop
         T.Data (1 + K) := Character'Val (Raw (Raw'First + K));
      end loop;
      T.Length := L;
   end BR_Text;

   procedure Check_Blackbox_Recorder_Line is
      Name : constant String := Str (1);
      use type BR.Log_State;
   begin
      if Name = "recinit" then
         BR_Seq := Int (2);
         BR_C := (Fields_Disabled_Mask => BR_U32 (8), Sample_Rate => Natural (Int (5)),
                  Device => Adaflight.Blackbox_Header.Device_Kind'Val (Int (4)), Mode => BR.Log_Mode'Val (Int (6)),
                  High_Resolution => Int (7) = 1, Serial_Fast_Baud => Int (9) = 1, Wing => Int (3) = 1);
         BR_Loop := BR.Loop_Time_Us (Int (10));
         BR_In := (others => <>);
         BR_In.Device.Buffer_Size := Natural (Int (11));
         BR_In.Conditions := (Motors => Natural (Int (12)), Has_Servos => Int (13) = 1, DShot_Telemetry => Int (14) = 1,
                              Mag_Present => Int (15) = 1, Baro_Present => Int (16) = 1,
                              Rangefinder_Present => Int (17) = 1, Acc_Present => Int (18) = 1,
                              RSSI_Configured => Int (19) = 1, Debug_Active => Int (20) = 1,
                              Voltage_Meter => Adaflight.Battery.Voltage_Source'Val (Int (21)),
                              Current_Meter => Adaflight.Battery.Current_Source'Val (Int (22)),
                              PID_D => (BR_I32 (23), BR_I32 (24), BR_I32 (25)),
                              PID_S => (BR_I32 (26), BR_I32 (27), BR_I32 (28)), others => <>);
         BR_In.GPS_Feature := Int (29) = 1;
         BR_In.Mode_Activation_Present := Int (30) = 1;
         for V in Adaflight.Blackbox_Header.Value_Name loop
            BR_In.Info.Values (V) := BR_I32 (32 + Adaflight.Blackbox_Header.Value_Name'Pos (V));
         end loop;
         for T in Adaflight.Blackbox_Header.Text_Name loop
            BR_Text (BR_In.Info.Texts (T), 294 + Adaflight.Blackbox_Header.Text_Name'Pos (T));
         end loop;
         BR.Init (BR_L, BR_C, BR_Loop);
         Record_Int (Name & ".rate", Int (5), Integer_64 (BR_C.Sample_Rate));
         Record_Int (Name & ".state", Int (308), Integer_64 (BR.Log_State'Pos (BR_L.State)));
         Record_Int (Name & ".iinterval", Int (309), Integer_64 (BR_L.I_Interval));
         Record_Int (Name & ".pinterval", Int (310), Integer_64 (BR_L.P_Interval));
         Record_Int (Name & ".sinterval", Int (311), Integer_64 (BR_L.S_Interval));
      elsif Name = "recstep" then
         if Int (2) /= BR_Seq then
            Put_Line ("flight log step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            Op   : constant Integer_64 := Int (4);
            Strm : Adaflight.Stream_Buffers.Stream;
            M    : BR.Main_Inputs renames BR_In.Main;
         begin
            BR_In.Now_Us := BR_U32 (5);
            BR_In.Now_Ms := BR_U32 (6);
            BR_In.Armed := Int (7) = 1;
            BR_In.Blackbox_Box := Int (8) = 1;
            BR_In.Erase_Box := Int (9) = 1;
            BR_In.Motors_Running := Int (10) = 1;
            BR_In.GPS_Feature := Int (11) = 1;
            BR_In.Mode_Activation_Present := Int (12) = 1;
            BR_In.Arming_Beep_Time_Us := BR_U32 (13);
            BR_In.Battery_Voltage := BR_U16 (14);
            BR_In.Device := (Free => Natural (Int (15)), Open_OK => Int (16) = 1, Buffer_Size => Natural (Int (17)),
                             Begin_Log_Done => Int (18) = 1, End_Log_Done => Int (19) = 1,
                             Flush_Complete => Int (20) = 1, Flush_Forced => Int (21) = 1, Full => Int (22) = 1,
                             Erased => Int (23) = 1, Shared_MSP_Port => Int (24) = 1);
            M.PID_P := BR_Axis (25);
            M.PID_I := BR_Axis (28);
            M.PID_D := BR_Axis (31);
            M.PID_F := BR_Axis (34);
            M.PID_S := BR_Axis (37);
            M.Gyro_Filtered := BR_Axis (40);
            M.Gyro_Raw := BR_Axis (43);
            M.Acc := BR_Axis (46);
            M.Mag := BR_Axis (49);
            M.Quaternion_W := Flt (52);
            M.Quaternion_XYZ := (Flt (53), Flt (54), Flt (55));
            M.RC_Command := (Flt (56), Flt (57), Flt (58), Flt (59));
            M.Setpoint := BR_Axis (60);
            M.Throttle := Flt (63);
            for I in 0 .. 7 loop
               M.Debug (I) := BR_I16 (64 + I);
               M.Motor (I) := Flt (72 + I);
               M.ERPM (I) := BR_U16 (80 + I);
               M.Servo (I) := BR_I16 (95 + I);
            end loop;
            M.VBat_Latest := BR_U16 (88);
            M.Amperage_Latest := BR_I32 (89);
            M.Baro_Alt := BR_I32 (90);
            M.Surface_Raw := BR_I32 (91);
            M.RSSI := BR_U16 (92);
            M.Airspeed := Flt (93);
            M.Diff_Pressure := Flt (94);
            M.Motor_Output_Low := Flt (103);
            BR_In.Slow := (Flight_Mode_Flags => BR_U32 (104), State_Flags => Byte (Int (105)),
                           Failsafe_Phase => Adaflight.Failsafe.Phase'Val (Int (106)),
                           RX_Signal_Received => Int (107) = 1, RX_Flight_Channels_Valid => Int (108) = 1);
            BR_In.GPS := (Home => (Lat => BR_I32 (109), Lon => BR_I32 (110), Alt_Cm => BR_I32 (111)),
                          Position => (Lat => BR_I32 (112), Lon => BR_I32 (113), Alt_Cm => BR_I32 (114)),
                          Num_Sat => Byte (Int (115)), Speed_3D => BR_U16 (116), Ground_Speed => BR_U16 (117),
                          Ground_Course => BR_U16 (118), Vel_N => BR_I16 (119), Vel_E => BR_I16 (120),
                          Vel_D => BR_I16 (121), Time_Ms => BR_U32 (122), Epoch => BR_U32 (123),
                          Use_3D_Speed => Int (124) = 1);
            Adaflight.Stream_Buffers.Init (Strm, 0, BR_Buf'Length);
            case Op is
               when 1 =>
                  BR.Update (BR_L, BR_C, BR_In, BR_Buf, Strm);
               when 2 =>
                  BR.Finish (BR_L, BR_In.Now_Ms, BR_Buf, Strm);
               when 3 =>
                  declare
                     Kind : constant BR.Event_Kind :=
                       (case Int (125) is
                          when 0 => BR.Sync_Beep, when 13 => BR.Inflight_Adjustment, when 14 => BR.Logging_Resume,
                          when 15 => BR.Disarm, when 30 => BR.Flight_Mode, when others => BR.Log_End);
                  begin
                     BR.Log_Event (BR_L, Kind,
                                   (Time_Us => BR_U32 (126), Flags => BR_U32 (127), Last_Flags => BR_U32 (128),
                                    Reason => BR_U32 (129), Adjustment_Function => Byte (Int (130)),
                                    Float_Flag => Int (131) = 1, New_Value => BR_I32 (132), New_Float => Flt (133),
                                    Log_Iteration => BR_U32 (134), Current_Time => BR_U32 (135)),
                                   BR_Buf, Strm);
                  end;
               when others =>
                  BR.Init (BR_L, BR_C, BR_Loop);
            end case;
            Record_Bytes (Name & ".bytes", Hex_Bytes (136), BR_Buf (0 .. Strm.Next - 1));
            Record_Int (Name & ".state", Int (137), Integer_64 (BR.Log_State'Pos (BR_L.State)));
            Record_Int (Name & ".iteration", Int (138), Integer_64 (BR_L.Iteration));
            Record_Int (Name & ".loopindex", Int (139), Integer_64 (BR_L.Loop_Index));
            Record_Int (Name & ".pframe", Int (140), Integer_64 (BR_L.P_Frame_Index));
            Record_Int (Name & ".iframe", Int (141), Integer_64 (BR_L.I_Frame_Index));
            Record_Int (Name & ".slowtimer", Int (142), Integer_64 (BR_L.Slow_Frame_Timer));
            Record_Int (Name & ".loggedany", Int (143), Boolean'Pos (BR_L.Logged_Any_Frames));
            Record_Int (Name & ".headerindex", Int (144), Integer_64 (BR_L.Header_St.Index));
            if BR_L.State in BR.Send_Main_Field_Header .. BR.Send_Sysinfo then
               Record_Int (Name & ".field", Int (145), Integer_64 (BR_L.Header_St.Field));
            elsif BR_L.State in BR.Send_Header | BR.Shutting_Down then
               Record_Int (Name & ".start", Int (145), BR_Signed_Start (BR_L.Header_St.Start_Time_Ms));
            end if;
            Record_Int (Name & ".budget", Int (146), Integer_64 (BR_L.Writer.Budget));
            Record_Int (Name & ".vbatref", Int (147), Integer_64 (BR_L.VBat_Reference));
            Record_Int (Name & ".testmode", Int (148), Boolean'Pos (BR_L.Started_In_Test_Mode));
            Record_Int (Name & ".lastbeep", Int (149), Integer_64 (BR_L.Last_Arming_Beep));
            Record_Int (Name & ".lastflags", Int (150), Integer_64 (BR_L.Last_Flight_Mode_Flags));
            Record_Int (Name & ".modeact", Int (151), Boolean'Pos (BR_L.Mode_Condition_Present));
            Record_Int (Name & ".homelat", Int (152), Integer_64 (BR_L.GPS_Hist.Home.Lat));
            Record_Int (Name & ".homelon", Int (153), Integer_64 (BR_L.GPS_Hist.Home.Lon));
            Record_Int (Name & ".homealt", Int (154), Integer_64 (BR_L.GPS_Hist.Home.Alt_Cm));
            Record_Int (Name & ".poslat", Int (155), Integer_64 (BR_L.GPS_Hist.Position.Lat));
            Record_Int (Name & ".poslon", Int (156), Integer_64 (BR_L.GPS_Hist.Position.Lon));
            Record_Int (Name & ".posalt", Int (157), Integer_64 (BR_L.GPS_Hist.Position.Alt_Cm));
            Record_Int (Name & ".numsat", Int (158), Integer_64 (BR_L.GPS_Hist.Num_Sat));
            Record_Int (Name & ".slowflags", Int (159), Integer_64 (BR_L.Slow_Hist.Flight_Mode_Flags));
            Record_Int (Name & ".slowstate", Int (160), Integer_64 (BR_L.Slow_Hist.State_Flags));
            Record_Int (Name & ".slowphase", Int (161), Integer_64 (BR_L.Slow_Hist.Failsafe_Phase));
            Record_Int (Name & ".slowsig", Int (162), Boolean'Pos (BR_L.Slow_Hist.RX_Signal_Received));
            Record_Int (Name & ".slowvalid", Int (163), Boolean'Pos (BR_L.Slow_Hist.RX_Flight_Channels_Valid));
            if Int (164) in 0 .. 2 then
               Record_Int (Name & ".ring0", Int (164), Integer_64 (BR_L.Current));
               Record_Int (Name & ".ring1", Int (165), Integer_64 (BR_L.Previous));
               Record_Int (Name & ".ring2", Int (166), Integer_64 (BR_L.Previous_2));
            end if;
            for R in BR.Ring_Index loop
               Record_Int (Name & ".ringtime", Int (167 + Integer (R)), Integer_64 (BR_L.Ring (R).Time));
            end loop;
            Record_Int (Name & ".flushes", Int (170), Integer_64 (BR_L.Flush_Requests));
            Record_Int (Name & ".forces", Int (171), Integer_64 (BR_L.Flush_Forces) + Integer_64 (BR_L.Writer.Flushes));
            Record_Int (Name & ".erases", Int (172), Integer_64 (BR_L.Erase_Requests));
            Record_Int (Name & ".beeps", Int (173), Integer_64 (BR_L.Beeps));
            Record_Int (Name & ".opens", Int (174), Integer_64 (BR_L.Opens));
            Record_Int (Name & ".closes", Int (175), Integer_64 (BR_L.Closes));
            Record_Int (Name & ".iinterval", Int (176), Integer_64 (BR_L.I_Interval));
            Record_Int (Name & ".pinterval", Int (177), Integer_64 (BR_L.P_Interval));
            Record_Int (Name & ".sinterval", Int (178), Integer_64 (BR_L.S_Interval));
         end;
      else
         Put_Line ("unknown flight log case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Blackbox_Recorder_Line;

   package PN renames Adaflight.Position_Nav;
   PN_Seq          : Integer_64 := -1;
   PN_N            : PN.Navigator;
   PN_Next_Pending : Boolean := False;
   PN_Next_Target  : PN.Position_M;
   PN_Next_Cruise  : PN.Speed_Mps := 0.0;
   PN_Next_Radius  : PN.Radius_M := 0.0;
   PN_Next_Done    : PN.Speed_Mps := 0.0;
   PN_Next_Alt     : Boolean := False;

   procedure PN_Record_State (Name : String; S : Positive) is
      C : PN.Command renames PN_N.Cmd;
   begin
      Record_Int (Name & ".active", Int (S), Boolean'Pos (C.Active));
      Record_Int (Name & ".sequence", Int (S + 1), Integer_64 (C.Sequence));
      Record_Int (Name & ".completed", Int (S + 2), Boolean'Pos (C.Completed));
      Record_Int (Name & ".signalled", Int (S + 3), Boolean'Pos (C.Completion_Signalled));
      Record_Result (Name & ".te", Bits (S + 4), To_Bits (C.Target.East));
      Record_Result (Name & ".tn", Bits (S + 5), To_Bits (C.Target.North));
      Record_Result (Name & ".tu", Bits (S + 6), To_Bits (C.Target.Up));
      Record_Int (Name & ".fixed", Int (S + 7), Boolean'Pos (C.Fixed_Target));
      Record_Int (Name & ".incalt", Int (S + 8), Boolean'Pos (C.Include_Altitude));
      Record_Result (Name & ".cruise", Bits (S + 9), To_Bits (C.Cruise_Speed));
      Record_Result (Name & ".vertrate", Bits (S + 10), To_Bits (C.Vert_Rate));
      Record_Result (Name & ".radius", Bits (S + 11), To_Bits (C.Acceptance_Radius));
      Record_Result (Name & ".completion", Bits (S + 12), To_Bits (C.Completion_Speed));
      Record_Result (Name & ".settletimeout", Bits (S + 13), To_Bits (C.Settle_Timeout));
      Record_Result (Name & ".settle", Bits (S + 14), To_Bits (C.Settle));
      Record_Result (Name & ".rampalt", Bits (S + 15), To_Bits (C.Ramp_Alt));
      Record_Int (Name & ".rampvalid", Int (S + 16), Boolean'Pos (C.Ramp_Valid));
      Record_Result (Name & ".ramprate", Bits (S + 17), To_Bits (C.Ramp_Rate));
      Record_Int (Name & ".rampslewed", Int (S + 18), Boolean'Pos (C.Ramp_Rate_Slewed));
      Record_Result (Name & ".apdecel", Bits (S + 19), To_Bits (C.Approach_Decel));
      Record_Result (Name & ".apstillr", Bits (S + 20), To_Bits (C.Approach_Still_Radius));
      Record_Int (Name & ".apstill", Int (S + 21), Boolean'Pos (C.Approach_Still));
      Record_Int (Name & ".ffvalid", Int (S + 22), Boolean'Pos (C.Velocity_FF_Valid));
      Record_Result (Name & ".ffe", Bits (S + 23), To_Bits (C.Velocity_FF.East));
      Record_Result (Name & ".ffn", Bits (S + 24), To_Bits (C.Velocity_FF.North));
      Record_Int (Name & ".fromcraft", Int (S + 25), Boolean'Pos (C.Velocity_From_Craft));
      Record_Result (Name & ".maxaccel", Bits (S + 26), To_Bits (C.Max_Accel));
      Record_Result (Name & ".maxdecel", Bits (S + 27), To_Bits (C.Max_Decel));
      Record_Result (Name & ".maxangle", Bits (S + 28), To_Bits (C.Max_Angle));
      Record_Int (Name & ".autoclear", Int (S + 29), Boolean'Pos (C.Auto_Clear_On_Reach));
      Record_Int (Name & ".altarrival", Int (S + 30), Boolean'Pos (C.Altitude_Arrival_Required));
      Record_Result (Name & ".preve", Bits (S + 31), To_Bits (PN_N.Previous_Vel.East));
      Record_Result (Name & ".prevn", Bits (S + 32), To_Bits (PN_N.Previous_Vel.North));
      Record_Result (Name & ".prevu", Bits (S + 33), To_Bits (PN_N.Previous_Vel.Up));
      Record_Int (Name & ".prevvalid", Int (S + 34), Boolean'Pos (PN_N.Previous_Valid));
      Record_Result (Name & ".cure", Bits (S + 35), To_Bits (PN_N.Target_Vel.East));
      Record_Result (Name & ".curn", Bits (S + 36), To_Bits (PN_N.Target_Vel.North));
      Record_Result (Name & ".curu", Bits (S + 37), To_Bits (PN_N.Target_Vel.Up));
      Record_Int (Name & ".withinr", Int (S + 38), Boolean'Pos (PN_N.Within_Radius));
      Record_Int (Name & ".withina", Int (S + 39), Boolean'Pos (PN_N.Within_Altitude));
      Record_Result (Name & ".targetalt", Bits (S + 40), To_Bits (PN.Target_Altitude_Cm (PN_N)));
      Record_Result (Name & ".vertlimit", Bits (S + 41), To_Bits (PN.Vertical_Rate_Limit_Cm_S (PN_N)));
      Record_Int (Name & ".hasactive", Int (S + 42), Boolean'Pos (PN.Has_Active_Target (PN_N)));
      Record_Int (Name & ".reached", Int (S + 43), Boolean'Pos (PN.Target_Reached (PN_N)));
   end PN_Record_State;

   procedure Check_Position_Nav_Line is
      Name : constant String := Str (1);
   begin
      if Name = "pninit" then
         PN_Seq := Int (2);
         PN_N := (others => <>);
         PN.Init (PN_N);
         PN_Next_Pending := False;
      elsif Name = "pnstep" then
         if Int (2) /= PN_Seq then
            Put_Line ("position nav step without its start");
            Failures := Failures + 1;
            return;
         end if;
         case Int (4) is
            when 1 =>
               PN_Next_Pending := Int (12) = 1;
               PN_Next_Target := (East => Flt (13), North => Flt (14), Up => Flt (15));
               PN_Next_Cruise := Flt (16);
               PN_Next_Radius := Flt (17);
               PN_Next_Done := Flt (18);
               PN_Next_Alt := Int (19) = 1;
               PN.Set_Target (PN_N, (East => Flt (5), North => Flt (6), Up => Flt (7)), Flt (8), Flt (9), Flt (10),
                              Int (11) = 1);
               PN_Record_State (Name, 20);
            when 2 =>
               PN.Move_Target (PN_N, (East => Flt (5), North => Flt (6), Up => Flt (7)));
               PN_Record_State (Name, 8);
            when 3 =>
               PN.Lower_Target_Altitude (PN_N, Flt (5));
               PN_Record_State (Name, 6);
            when 4 =>
               PN.Clear_Target (PN_N);
               PN_Record_State (Name, 5);
            when 5 =>
               PN.Set_Vertical_Profile (PN_N, Flt (5), Flt (6));
               PN_Record_State (Name, 7);
            when 6 =>
               PN.Set_Accel_Limits (PN_N, Flt (5), Flt (6));
               PN_Record_State (Name, 7);
            when 7 =>
               PN.Set_Velocity_Feedforward (PN_N, (East => Flt (5), North => Flt (6)));
               PN_Record_State (Name, 7);
            when 8 =>
               PN.Start_Afresh (PN_N);
               PN_Record_State (Name, 5);
            when 9 =>
               PN.Set_Approach_Brake (PN_N, Flt (5), Flt (6));
               PN_Record_State (Name, 7);
            when 10 =>
               PN.Set_Altitude_Arrival_Required (PN_N, Int (5) = 1);
               PN_Record_State (Name, 6);
            when 11 =>
               PN.Set_Settle_Timeout (PN_N, Flt (5));
               PN_Record_State (Name, 6);
            when 12 =>
               PN.Set_Max_Angle (PN_N, Flt (5));
               PN_Record_State (Name, 6);
            when 13 =>
               PN.Set_Auto_Clear_On_Reach (PN_N, Int (5) = 1);
               PN_Record_State (Name, 6);
            when 14 =>
               declare
                  Est     : constant PN.Estimate :=
                    (Position => (East => Flt (6), North => Flt (7), Up => Flt (8)),
                     Velocity => (East => Flt (9), North => Flt (10), Up => Flt (11)));
                  Reached : Boolean;
               begin
                  PN.Update (PN_N, Flt (5), Est, Reached);
                  Record_Int (Name & ".reachednow", Int (12), Boolean'Pos (Reached));
                  if Reached then
                     if PN_Next_Pending then
                        PN.Set_Target (PN_N, PN_Next_Target, PN_Next_Cruise, PN_Next_Radius, PN_Next_Done, PN_Next_Alt);
                        PN_Next_Pending := False;
                     else
                        PN.Finish_Leg (PN_N);
                     end if;
                  end if;
                  PN_Record_State (Name, 14);
               end;
            when 15 =>
               Record_Result (Name & ".approach", Bits (9),
                              To_Bits (PN.Approach_Speed (Flt (5), Flt (6), Flt (7), Flt (8))));
               PN_Record_State (Name, 10);
            when 16 =>
               PN.Reset (PN_N);
               PN_Record_State (Name, 5);
            when others =>
               PN.Init (PN_N);
               PN_Record_State (Name, 5);
         end case;
      else
         Put_Line ("unknown position nav case " & Name);
         Failures := Failures + 1;
      end if;
   end Check_Position_Nav_Line;

   --  The OSD warnings line: the settings and the per-sequence readings
   --  from the start line, the rest per step, the line compared as bytes.

   OW_Seq    : Integer_64 := -1;
   OW_Config : Adaflight.OSD_Warnings.Settings;
   OW_Const  : Adaflight.OSD_Warnings.Inputs;
   OW_State  : Adaflight.OSD_Warnings.State;

   procedure OW_Read_Init (Config : out Adaflight.OSD_Warnings.Settings; Const : out Adaflight.OSD_Warnings.Inputs) is
      use Adaflight.OSD_Warnings;
   begin
      Config := (others => <>);
      for W in Warning_Kind loop
         Config.Enabled (W) := (Bits (3) and Interfaces.Shift_Left (1, Warning_Kind'Pos (W))) /= 0;
      end loop;
      Config.Units := Unit_System'Val (Int (4));
      Config.RSSI_Alarm := Integer (Int (5));
      Config.RSSI_Dbm_Alarm := Integer (Int (6));
      Config.RSNR_Alarm := Integer (Int (7));
      Config.Link_Quality_Alarm := Integer (Int (8));
      Config.Core_Temp_Alarm := Integer (Int (9));
      Config.Cap_Alarm := Integer (Int (10));
      Config.ESC_RPM_Alarm := Integer (Int (11));
      Config.ESC_Current_Alarm := Integer (Int (12));
      Config.ESC_Temp_Alarm := Integer (Int (13));
      Const := (others => <>);
      Const.Motors := Integer (Int (14));
      Const.Erpm_To_Hz := Flt (15);
      Const.Battery_Capacity := Integer (Int (16));
      Const.Full_Cell_Voltage := Integer (Int (17));
      Const.Launch_Throttle_Percent := Integer (Int (18));
   end OW_Read_Init;

   procedure OW_Read_Step (Const : Adaflight.OSD_Warnings.Inputs; I : out Adaflight.OSD_Warnings.Inputs;
                           B : out Positive) is
      M : constant Natural := Const.Motors;
   begin
      I := Const;
      B := 16 + 9 * M;
      I.Now_Us := Interfaces.Unsigned_32 (Int (3));
      I.Battery := Adaflight.Battery.Battery_State'Val (Int (4));
      I.Armed := Int (5) = 1;
      I.Was_Ever_Armed := Int (6) = 1;
      I.GPS_Rescue_Mode := Int (7) = 1;
      I.GPS_Rescue_OK := Int (8) = 1;
      I.Arm_Box := Int (9) = 1;
      for R in Adaflight.Arming.Disable_Reason loop
         I.Disable_Flags (R) :=
           (Bits (10) and Interfaces.Shift_Left (1, Adaflight.Arming.Disable_Reason'Pos (R))) /= 0;
      end loop;
      I.Trying_To_Arm := Int (11) = 1;
      I.Last_Beacon_Time_Us := Interfaces.Unsigned_32 (Int (12));
      I.Failsafe_Active := Int (13) = 1;
      I.ESC_Sensor_Feature := Int (14) = 1;
      I.DShot_Telemetry := Int (15) = 1;
      for K in 0 .. M - 1 loop
         I.ESC_Sensor (K) := (Present => Int (16 + 4 * K) = 1, RPM => Interfaces.Integer_16 (Int (17 + 4 * K)),
                              Current => Interfaces.Integer_32 (Int (18 + 4 * K)),
                              Temperature => Interfaces.Unsigned_8 (Int (19 + 4 * K)));
         I.DShot_Sensor (K) := (Present => Int (16 + 4 * M + 4 * K) = 1,
                                RPM => Interfaces.Integer_16 (Int (17 + 4 * M + 4 * K)),
                                Current => Interfaces.Integer_32 (Int (18 + 4 * M + 4 * K)),
                                Temperature => Interfaces.Unsigned_8 (Int (19 + 4 * M + 4 * K)));
         I.Motor_Active (K) := Int (16 + 8 * M + K) = 1;
      end loop;
      I.Crash_Flip_Box := Int (B) = 1;
      I.Crash_Flip_Active := Int (B + 1) = 1;
      I.Launch_Control_Active := Int (B + 2) = 1;
      I.Acc_Present := Int (B + 3) = 1;
      I.Pitch_Decidegrees := Interfaces.Integer_16 (Int (B + 4));
      I.Pitch_Trim := Interfaces.Integer_16 (Int (B + 5));
      I.Throttle_Percent := Integer (Int (B + 6));
      I.RSSI_Percent := Integer (Int (B + 7));
      I.RSSI_Dbm := Interfaces.Integer_16 (Int (B + 8));
      I.RSNR := Interfaces.Integer_16 (Int (B + 9));
      I.Link_Quality_Percent := Integer (Int (B + 10));
      I.Rescue_Configured := Int (B + 11) = 1;
      I.Rescue_Available := Int (B + 12) = 1;
      I.Rescue_Heading_OK := Int (B + 13) = 1;
      I.Armed_Time_Us := Interfaces.Unsigned_32 (Int (B + 14));
      I.Pos_Hold_Failure := Int (B + 15) = 1;
      I.Headfree_Mode := Int (B + 16) = 1;
      I.Core_Temperature := Interfaces.Integer_16 (Int (B + 17));
      I.MAh_Drawn := Integer (Int (B + 18));
      I.Has_Used_MAh := Int (B + 19) = 1;
      I.Average_Cell_Voltage := Integer (Int (B + 20));
      I.Visual_Beeper := Int (B + 21) = 1;
      I.Chirp_Repeat_Total := Integer (Int (B + 22));
      I.Chirp_Repeat_Current := Integer (Int (B + 23));
      I.Chirp_Finished := Int (B + 24) = 1;
      I.Chirp_Series_Finished := Int (B + 25) = 1;
      I.Chirp_Axis := Integer (Int (B + 26));
   end OW_Read_Step;

   procedure Check_OSD_Warnings_Line is
      use Adaflight.OSD_Warnings;
      Name : constant String := Str (1);
   begin
      if Name = "owinit" then
         OW_Seq := Int (2);
         OW_State := (others => <>);
         OW_Read_Init (OW_Config, OW_Const);
      elsif Name = "owstep" then
         if Int (2) /= OW_Seq then
            Put_Line ("OSD warnings step without its start");
            Failures := Failures + 1;
            return;
         end if;
         declare
            I        : Inputs;
            B        : Positive;
            Line     : Text;
            Blinking : Boolean;
            Attr     : Severity;
            Beeper   : Boolean;
         begin
            OW_Read_Step (OW_Const, I, B);
            Render (OW_State, OW_Config, I, Line, Blinking, Attr, Beeper);
            declare
               Actual : Byte_Array (0 .. Line.Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (Character'Pos (Line.Data (K + 1)));
               end loop;
               Record_Bytes (Name & ".text", Hex_Bytes (B + 27), Actual);
            end;
            Record_Int (Name & ".blink", Int (B + 28), Boolean'Pos (Blinking));
            Record_Int (Name & ".attr", Int (B + 29), Severity'Pos (Attr));
            Record_Int (Name & ".beeper", Int (B + 30), Boolean'Pos (Beeper));
         end;
      end if;
   end Check_OSD_Warnings_Line;

   --  The MSP tunnel over telemetry: request chunks, the scripted processor's
   --  reply, and the reply chunks pulled at the links' sizes.

   MT_Seq : Integer_64 := -1;
   MT_T   : Adaflight.MSP_Telemetry.Tunnel;

   procedure Check_MSP_Tunnel_Line is
      use Adaflight.MSP_Telemetry;
      Name : constant String := Str (1);
   begin
      if Name = "mtinit" then
         MT_Seq := Int (2);
         MT_T := (others => <>);
      elsif Int (2) /= MT_Seq then
         Put_Line ("MSP tunnel line without its start");
         Failures := Failures + 1;
      elsif Name = "mtframe" then
         declare
            Frame  : constant Byte_Array := Hex_Bytes (3);
            Result : Outcome;
            EEPROM : Boolean;
         begin
            Handle_Frame (MT_T, Frame, Result, EEPROM);
            Record_Int (Name & ".ret", Int (4), Boolean'Pos (Result /= Ignored));
            Record_Int (Name & ".skips", Int (5), (if EEPROM then Skips_After_EEPROM_Write else 0));
            Record_Int (Name & ".processed", Int (6), Boolean'Pos (Result = Request_Ready));
            Record_Int (Name & ".reqcmd", Int (9), Integer_64 (MT_T.Request_Command));
            Record_Int (Name & ".reqflags", Int (10), Integer_64 (MT_T.Request_Flags));
            Record_Int (Name & ".expected", Int (11), Integer_64 (MT_T.Request_Expected));
            Record_Int (Name & ".filled", Int (12), Integer_64 (MT_T.Request_Filled));
            if Result = Request_Ready then
               Record_Bytes (Name & ".reqdata", Hex_Bytes (13), Request_Data (MT_T));
               Prepare_Reply (MT_T, Integer (Int (7)), Hex_Bytes (8));
            else
               Record_Bytes (Name & ".reqdata", Hex_Bytes (13), MT_T.Request_Buffer (0 .. MT_T.Request_Filled - 1));
            end if;
            if Result /= Ignored then
               Record_Int (Name & ".respcmd", Int (14), Integer_64 (MT_T.Response_Command));
               Record_Int (Name & ".respresult", Int (15), Integer_64 (MT_T.Response_Result));
               Record_Int (Name & ".resplen", Int (16), Integer_64 (MT_T.Response_Length));
               Record_Bytes (Name & ".respdata", Hex_Bytes (17), Response_Data (MT_T));
            end if;
         end;
      elsif Name = "mtchunk" then
         declare
            Chunk  : Chunk_Buffer;
            Length : Natural;
            More   : Boolean;
         begin
            Send_Reply (MT_T, Integer (Int (3)), Chunk, Length, More);
            Record_Bytes (Name, Hex_Bytes (4), Chunk (0 .. Length - 1));
            Record_Int (Name & ".more", Int (5), Boolean'Pos (More));
         end;
      end if;
   end Check_MSP_Tunnel_Line;

   --  The OSD formatting: each helper under its scripted readings, the
   --  text compared as bytes.

   OSF_Seq : Integer_64 := -1;

   type OSF_Format_Table is array (0 .. 3) of Adaflight.OSD_Format.Number_Format;
   OSF_Formats : constant OSF_Format_Table :=
     (0 => Adaflight.OSD_Format.Default_Format,
      1 => (Lead => '-', Has_Lead => True, Width => 2, Zero_Pad => True),
      2 => (Lead => ' ', Has_Lead => True, Width => 2, Zero_Pad => True),
      3 => (Lead => ' ', Has_Lead => False, Width => 3, Zero_Pad => False));

   procedure OSF_Record_Text (Name : String; Field : Positive; T : Adaflight.OSD_Format.Text) is
      Actual : Byte_Array (0 .. T.Length - 1);
   begin
      for K in Actual'Range loop
         Actual (K) := Byte (Character'Pos (T.Data (K + 1)));
      end loop;
      Record_Bytes (Name, Hex_Bytes (Field), Actual);
   end OSF_Record_Text;

   procedure Check_OSD_Format_Line is
      use Adaflight.OSD_Format;
      Name : constant String := Str (1);
      T    : Adaflight.OSD_Format.Text;
      function Units (I : Positive) return Unit_System is (Unit_System'Val (Int (I)));
      function Variant (I : Positive) return Element_Type is (Element_Type'Val (Int (I)));
      function Chr (I : Positive) return Character is (Character'Val (Int (I)));
      function I32 (I : Positive) return Interfaces.Integer_32 is (Interfaces.Integer_32 (Int (I)));
      function U32 (I : Positive) return Interfaces.Unsigned_32 is (Interfaces.Unsigned_32 (Int (I)));
   begin
      if Name = "ofinit" then
         OSF_Seq := Int (2);
      elsif Int (2) /= OSF_Seq then
         Put_Line ("OSD format line without its start");
         Failures := Failures + 1;
      elsif Name = "ofpf" then
         Print_Float (T, Chr (4), Flt (5), OSF_Formats (Integer (Int (6))), Integer (Int (7)), Int (8) = 1,
                      Chr (9));
         OSF_Record_Text (Name, 10, T);
         Record_Int (Name & ".pos", Int (11), Integer_64 (T.Length));
      elsif Name = "ofalt" then
         Altitude_String (T, I32 (4), Variant (5), Flt (6), Units (3));
         OSF_Record_Text (Name, 7, T);
      elsif Name = "ofcoord" then
         Adaflight.OSD_Format.Coordinate (T, Int (4) = 1, Variant (5), Int (6) = 1, I32 (7), I32 (8));
         OSF_Record_Text (Name, 9, T);
      elsif Name = "ofdist" then
         Distance_String (T, I32 (4), Chr (5), Units (3));
         OSF_Record_Text (Name, 6, T);
      elsif Name = "ofpid" then
         declare
            L     : constant Byte_Array := Hex_Bytes (3);
            Label : String (1 .. L'Length);
         begin
            for K in Label'Range loop
               Label (K) := Character'Val (L (L'First + K - 1));
            end loop;
            PID_Line (T, Label, Interfaces.Unsigned_8 (Int (4)), Interfaces.Unsigned_8 (Int (5)),
                      Interfaces.Unsigned_8 (Int (6)), Interfaces.Unsigned_8 (Int (7)),
                      Interfaces.Unsigned_16 (Int (8)));
            OSF_Record_Text (Name, 9, T);
         end;
      elsif Name = "ofrtc" then
         declare
            D : constant Adaflight.RTC.Date_Time :=
              (Year => Interfaces.Unsigned_16 (Int (5)), Month => Interfaces.Unsigned_8 (Int (6)),
               Day => Interfaces.Unsigned_8 (Int (7)), Hours => Interfaces.Unsigned_8 (Int (8)),
               Minutes => Interfaces.Unsigned_8 (Int (9)), Seconds => Interfaces.Unsigned_8 (Int (10)),
               Millis => Interfaces.Unsigned_16 (Int (11)));
            Z     : constant Adaflight.RTC.Settings := (Zone => Interfaces.Integer_16 (Int (12)));
            Valid : Boolean;
         begin
            RTC_Date_Time (T, Variant (3), Int (4) = 1, D, Z, Valid);
            OSF_Record_Text (Name, 13, T);
            Record_Int (Name & ".valid", Int (14), Boolean'Pos (Valid));
         end;
      elsif Name = "oftime" then
         Time_String (T, Integer (Int (3)), U32 (4));
         OSF_Record_Text (Name, 5, T);
      elsif Name = "oftimer" then
         Timer_String (T, Int (4) = 1, Int (5) = 1, Interfaces.Unsigned_16 (Int (3)),
                       (Now_Us => U32 (6), Fly_Time_Us => U32 (7), Armed_Time_Us => U32 (8),
                        Launch_Time_Us => U32 (9), Armed => Int (10) = 1));
         OSF_Record_Text (Name, 11, T);
      elsif Name = "ofbatt" then
         Record_Int (Name, Int (7),
                     Character'Pos (Battery_Symbol (Integer (Int (3)),
                                                    Adaflight.Battery.Battery_State'Val (Int (4)),
                                                    Interfaces.Unsigned_16 (Int (5)),
                                                    Interfaces.Unsigned_16 (Int (6)))));
      elsif Name = "ofdir" then
         Record_Int (Name, Int (4), Character'Pos (Direction_Symbol (Integer (Int (3)))));
      elsif Name = "ofunit" then
         Record_Result (Name & ".meters", Bits (5), To_Bits (Meters_To_Unit (I32 (4), Units (3))));
         Record_Int (Name & ".msym", Int (6), Character'Pos (Meters_Symbol (Units (3))));
         Record_Int (Name & ".speed", Int (8), Integer_64 (Speed_To_Unit (I32 (7), Units (3))));
         Record_Int (Name & ".ssym", Int (9), Character'Pos (Speed_Symbol (Units (3))));
         Record_Int (Name & ".vsym", Int (10), Character'Pos (Vario_Symbol (Units (3))));
         Record_Int (Name & ".temp", Int (12), Integer_64 (Temperature_In_Units (Integer (Int (11)), Units (3))));
         Record_Int (Name & ".tsym", Int (13), Character'Pos (Temperature_Symbol (Units (3))));
      end if;
   end Check_OSD_Format_Line;

   --  The transmitter over MSP: the driver under its table and settings, each
   --  operation followed by its state and the frames it sends.

   VM_Seq      : Integer_64 := -1;
   VM_Table    : Adaflight.VTX_Table.Table;
   VM_Settings : Adaflight.VTX.Settings;
   VM_Driver   : Adaflight.VTX_MSP.Driver;

   procedure VM_Record_State (Name : String) is
      use Adaflight.VTX_MSP;
   begin
      Record_Int (Name & ".conffreq", Int (9), Integer_64 (VM_Driver.Conf_Freq));
      Record_Int (Name & ".confband", Int (10), Integer_64 (VM_Driver.Conf_Band));
      Record_Int (Name & ".confchan", Int (11), Integer_64 (VM_Driver.Conf_Channel));
      Record_Int (Name & ".confpower", Int (12), Integer_64 (VM_Driver.Conf_Power));
      Record_Int (Name & ".confpit", Int (13), Integer_64 (VM_Driver.Conf_Pit_Mode));
      Record_Int (Name & ".changed", Int (14), Boolean'Pos (VM_Driver.Config_Changed));
      Record_Int (Name & ".lasttime", Int (15), Integer_64 (VM_Driver.Last_Time_Us));
      Record_Int (Name & ".prevlow", Int (16), Boolean'Pos (VM_Driver.Prev_Low_Power));
      Record_Int (Name & ".status", Int (17), Status'Pos (VM_Driver.Current));
      Record_Int (Name & ".packets", Int (18), Integer_64 (VM_Driver.Packets));
   end VM_Record_State;

   procedure VM_Record_Frame (Name : String; Field : Positive; F : Byte_Array) is
   begin
      Record_Bytes (Name, Hex_Bytes (Field), F);
   end VM_Record_Frame;

   procedure Check_VTX_MSP_Line is
      use Adaflight.VTX_MSP;
      Name : constant String := Str (1);
   begin
      if Name = "vminit" then
         VM_Seq := Int (2);
         Read_Table (VM_Table, 3);
         VM_Driver := (others => <>);
         VM_Settings := (others => <>);
      elsif Int (2) /= VM_Seq then
         Put_Line ("VTX MSP line without its start");
         Failures := Failures + 1;
      elsif Name = "vmstep" then
         VM_Settings.Band := Interfaces.Unsigned_8 (Int (19));
         VM_Settings.Channel := Interfaces.Unsigned_8 (Int (20));
         VM_Settings.Power := Interfaces.Unsigned_8 (Int (21));
         VM_Settings.Freq := Interfaces.Unsigned_16 (Int (22));
         VM_Settings.Pit_Mode_Freq := Interfaces.Unsigned_16 (Int (23));
         VM_Settings.Low_Power := Adaflight.VTX.Low_Power_Disarm'Val (Int (24));
         case Int (3) is
            when 0 =>
               declare
                  Inp   : constant Inputs := (Now_Us => Interfaces.Unsigned_32 (Int (4)), Armed => Int (5) = 1,
                                              Was_Ever_Armed => Int (6) = 1, Failsafe => Int (7) = 1);
                  Frame : Config_Frame;
                  Send  : Boolean;
               begin
                  Process (VM_Driver, VM_Settings, VM_Table, Inp, Frame, Send);
                  VM_Record_State (Name);
                  Record_Int (Name & ".sent", Int (25) + Int (30), Boolean'Pos (Send));
                  if Send then
                     if Int (8) = 1 then
                        declare
                           Wrapped : CRSF_Frame;
                           Length  : Natural;
                        begin
                           CRSF_Push (Config_Command, Frame, Wrapped, Length);
                           Record_Int (Name & ".crsfsends", Int (31), 2);
                           VM_Record_Frame (Name & ".crsf", 32, Wrapped (0 .. Length - 1));
                        end;
                     else
                        Record_Int (Name & ".pushcmd", Int (26), Config_Command);
                        Record_Int (Name & ".pushdir", Int (27), 0);
                        Record_Int (Name & ".pushver", Int (28), 2);
                        VM_Record_Frame (Name & ".push", 29, Frame);
                     end if;
                  end if;
               end;
            when 1 =>
               Set_Band_Channel (VM_Driver, Interfaces.Unsigned_8 (Int (4)), Interfaces.Unsigned_8 (Int (5)));
               VM_Record_State (Name);
            when 2 =>
               Set_Power_Index (VM_Driver, VM_Table, Interfaces.Unsigned_8 (Int (4)));
               VM_Record_State (Name);
            when 3 =>
               Set_Pit_Mode (VM_Driver, Int (4) = 1);
               VM_Record_State (Name);
            when 4 =>
               Set_Frequency (VM_Driver, Interfaces.Unsigned_16 (Int (4)));
               VM_Record_State (Name);
            when 5 =>
               Set_Ready (VM_Driver, VM_Table, Int (5) = (if Int (4) = 1 then 7 else 3) or else Int (5) = 5);
               VM_Record_State (Name);
            when 6 =>
               declare
                  Band, Channel : Interfaces.Unsigned_8;
                  Known         : Boolean;
               begin
                  Get_Band_Channel (VM_Driver, Band, Channel, Known);
                  VM_Record_State (Name);
                  Record_Int (Name & ".known", Int (25), Boolean'Pos (Known));
                  if Known then
                     Record_Int (Name & ".band", Int (26), Integer_64 (Band));
                     Record_Int (Name & ".chan", Int (27), Integer_64 (Channel));
                  end if;
               end;
            when 7 =>
               declare
                  Index : Interfaces.Unsigned_8 := 16#AA#;
                  Known : Boolean;
               begin
                  Get_Power_Index (VM_Driver, VM_Table, Index, Known);
                  VM_Record_State (Name);
                  Record_Int (Name & ".known", Int (25), Boolean'Pos (Known));
                  Record_Int (Name & ".index", Int (26), Integer_64 (Index));
               end;
            when 8 =>
               declare
                  Freq  : Interfaces.Unsigned_16;
                  Known : Boolean;
               begin
                  Get_Frequency (VM_Driver, VM_Table, Freq, Known);
                  VM_Record_State (Name);
                  Record_Int (Name & ".known", Int (25), Boolean'Pos (Known));
                  if Known then
                     Record_Int (Name & ".freq", Int (26), Integer_64 (Freq));
                  end if;
               end;
            when 9 =>
               declare
                  Pit_Mode, Known : Boolean;
               begin
                  Get_Status (VM_Driver, Pit_Mode, Known);
                  VM_Record_State (Name);
                  Record_Int (Name & ".known", Int (25), Boolean'Pos (Known));
                  if Known then
                     Record_Int (Name & ".status", Int (26), Boolean'Pos (Pit_Mode));
                  end if;
               end;
            when 10 =>
               declare
                  Count          : Adaflight.VTX_Table.Power_Count;
                  Levels, Powers : Level_Values;
               begin
                  Get_Power_Levels (VM_Driver, VM_Table, Count, Levels, Powers);
                  VM_Record_State (Name);
                  Record_Int (Name & ".count", Int (25), Integer_64 (Count));
                  for I in 1 .. Count loop
                     Record_Int (Name & ".level", Int (24 + 2 * I), Integer_64 (Levels (I)));
                     Record_Int (Name & ".power", Int (25 + 2 * I), Integer_64 (Powers (I)));
                  end loop;
               end;
            when others =>
               declare
                  Frame : Config_Frame;
               begin
                  Prepare_Frame (VM_Driver, VM_Settings, VM_Table,
                                 Low_Power_Disarmed (VM_Settings, Int (5) = 1, Int (6) = 1, Int (7) = 1), Frame);
                  VM_Record_State (Name);
                  VM_Record_Frame (Name & ".frame", 25, Frame);
               end;
         end case;
      end if;
   end Check_VTX_MSP_Line;

   --  The MSP display port: the port under its profile, each operation
   --  followed by its state and the payloads it pushed.

   DP_Seq  : Integer_64 := -1;
   DP_Font : Adaflight.Display_Port_MSP.Font_Selection;
   DP_Port : Adaflight.Display_Port_MSP.Port;

   procedure DP_Record_State (Name : String; F : Positive) is
   begin
      Record_Int (Name & ".rows", Int (F), Integer_64 (DP_Port.Rows));
      Record_Int (Name & ".cols", Int (F + 1), Integer_64 (DP_Port.Cols));
      Record_Int (Name & ".grabs", Int (F + 2), Integer_64 (DP_Port.Grab_Count));
      Record_Int (Name & ".cleared", Int (F + 3), Boolean'Pos (DP_Port.Cleared));
      Record_Int (Name & ".cursor", Int (F + 4), Integer_64 (DP_Port.Cursor_Row));
      Record_Int (Name & ".devblink", Int (F + 5), Boolean'Pos (DP_Port.Use_Device_Blink));
   end DP_Record_State;

   --  The pushes expected after an operation: their count at F, then each
   --  as the command, direction, version and payload.
   procedure DP_Record_Push (Name : String; F : Positive; Index : Natural;
                             Data : Adaflight.Display_Port_MSP.Payload; Length : Natural) is
      B : constant Positive := F + 1 + 4 * Index;
   begin
      Record_Int (Name & ".cmd", Int (B), Adaflight.Display_Port_MSP.Command);
      Record_Int (Name & ".dir", Int (B + 1), 0);
      Record_Int (Name & ".ver", Int (B + 2), 0);
      Record_Bytes (Name & ".payload", Hex_Bytes (B + 3), Data (0 .. Length - 1));
   end DP_Record_Push;

   procedure Check_Display_Port_MSP_Line is
      use Adaflight.Display_Port_MSP;
      Name   : constant String := Str (1);
      Data   : Payload;
      Length : Natural;
   begin
      if Name = "dpinit" then
         DP_Seq := Int (2);
         DP_Font := (Interfaces.Unsigned_8 (Int (4)), Interfaces.Unsigned_8 (Int (5)), Interfaces.Unsigned_8 (Int (6)),
                     Interfaces.Unsigned_8 (Int (7)));
         Init (DP_Port, Video_System'Val (Int (3)),
               (Font => DP_Font, Use_Device_Blink => Int (8) = 1, Row_Adjust => Interfaces.Integer_8 (Int (9)),
                Col_Adjust => Interfaces.Integer_8 (Int (10))),
               Interfaces.Unsigned_8 (Int (11)), Interfaces.Unsigned_8 (Int (12)));
         DP_Record_State (Name, 13);
         Record_Int (Name & ".pushes", Int (19), 2);
         Clear_Screen_Payload (Data, Length);
         DP_Record_Push (Name, 19, 0, Data, Length);
         Draw_Screen_Payload (Data, Length);
         DP_Record_Push (Name, 19, 1, Data, Length);
      elsif Int (2) /= DP_Seq then
         Put_Line ("display port line without its start");
         Failures := Failures + 1;
      elsif Name = "dpstep" then
         declare
            Op     : constant Integer_64 := Int (3);
            A1     : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Int (4) mod 256);
            A2     : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Int (5));
            A3     : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Int (6));
            Bytes  : constant Byte_Array := Hex_Bytes (7);
            Pushes : Natural := 0;
         begin
            case Op is
               when 0 =>
                  Grab (DP_Port);
                  Heartbeat (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Clear_Screen_Payload (Data, Length);
                  DP_Record_Push (Name, 15, 1, Data, Length);
                  Pushes := 2;
               when 1 =>
                  Release (DP_Port);
                  Release_Payload (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 2 =>
                  Release_All (DP_Port);
                  Release_Payload (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 3 =>
                  Clear (DP_Port);
                  Clear_Screen_Payload (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 4 | 6 =>
                  Draw_Screen_Payload (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Record_Int (Name & ".result", Int (8), 0);
                  Pushes := 1;
               when 5 =>
                  Heartbeat (Data, Length);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Record_Int (Name & ".result", Int (8), 0);
                  Pushes := 1;
               when 7 =>
                  Record_Int (Name & ".result", Int (8), Boolean'Pos (Is_Grabbed (DP_Port)));
               when 8 =>
                  Record_Int (Name & ".result", Int (8), Integer_64 (Screen_Size (DP_Port)));
               when 10 =>
                  declare
                     Text : String (1 .. Bytes'Length);
                  begin
                     for K in Text'Range loop
                        Text (K) := Character'Val (Bytes (Bytes'First + K - 1));
                     end loop;
                     Write_String (DP_Font, A1, A2, A3, Text, Data, Length);
                     Record_Int (Name & ".result", Int (8), Integer_64 (Length));
                     if Length > 0 then
                        DP_Record_Push (Name, 15, 0, Data, Length);
                        Pushes := 1;
                     end if;
                  end;
               when 11 =>
                  Write_Char (DP_Font, A1, A2, A3,
                              (if Bytes'Length = 0 then Character'Val (0) else Character'Val (Bytes (Bytes'First))),
                              Data, Length);
                  Record_Int (Name & ".result", Int (8), Integer_64 (Length));
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 12 =>
                  Write_Sys (A1, A2, A3, Data, Length);
                  Record_Int (Name & ".result", Int (8), Integer_64 (Length));
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 13 =>
                  Write_Font_Character (Interfaces.Unsigned_16 (Int (4)), Bytes, Data, Length);
                  Record_Int (Name & ".result", Int (8), 11);
                  DP_Record_Push (Name, 15, 0, Data, Length);
                  Pushes := 1;
               when 14 =>
                  Record_Int (Name & ".result", Int (8),
                              Boolean'Pos (Is_Ready) * 2 + Boolean'Pos (Transfer_In_Progress)
                              + 4 * Boolean'Pos (Is_Synced));
               when others =>
                  null;
            end case;
            DP_Record_State (Name, 9);
            if Op /= 9 then
               Record_Int (Name & ".pushes", Int (15), Integer_64 (Pushes));
            end if;
         end;
      end if;
   end Check_Display_Port_MSP_Line;

   --  The OSD statistics: resets, updates under scripted readings, and the
   --  text of each statistic against the display writes the reference made.

   OST_Seq   : Integer_64 := -1;
   OST_Cols  : Natural := 30;
   OST_Stats : Adaflight.OSD_Stats.Statistics;

   procedure OST_Record_Stats (Name : String; F : Positive) is
   begin
      Record_Int (Name & ".armedtime", Int (F), Integer_64 (OST_Stats.Armed_Time_Us));
      Record_Int (Name & ".maxspeed", Int (F + 1), Integer_64 (OST_Stats.Max_Speed));
      Record_Int (Name & ".minvolt", Int (F + 2), Integer_64 (OST_Stats.Min_Voltage));
      Record_Int (Name & ".endvolt", Int (F + 3), Integer_64 (OST_Stats.End_Voltage));
      Record_Int (Name & ".maxcurrent", Int (F + 4), Integer_64 (OST_Stats.Max_Current));
      Record_Int (Name & ".minrssi", Int (F + 5), Integer_64 (OST_Stats.Min_RSSI));
      Record_Int (Name & ".maxalt", Int (F + 6), Integer_64 (OST_Stats.Max_Altitude));
      Record_Int (Name & ".maxdist", Int (F + 7), Integer_64 (OST_Stats.Max_Distance));
      Record_Result (Name & ".maxg", Bits (F + 8), To_Bits (OST_Stats.Max_G_Force));
      Record_Int (Name & ".esctempix", Int (F + 9), Integer_64 (OST_Stats.Max_ESC_Temp_Ix));
      Record_Int (Name & ".esctemp", Int (F + 10), Integer_64 (OST_Stats.Max_ESC_Temp));
      Record_Int (Name & ".escrpm", Int (F + 11), Integer_64 (OST_Stats.Max_ESC_RPM));
      Record_Int (Name & ".minlq", Int (F + 12), Integer_64 (OST_Stats.Min_Link_Quality));
      Record_Int (Name & ".minrssidbm", Int (F + 13), Integer_64 (OST_Stats.Min_RSSI_Dbm));
      Record_Int (Name & ".minrsnr", Int (F + 14), Integer_64 (OST_Stats.Min_RSNR));
   end OST_Record_Stats;

   procedure OST_Record_Text (Name : String; Field : Positive; T : Adaflight.OSD_Format.Text) is
      Actual : Byte_Array (0 .. T.Length - 1);
   begin
      for K in Actual'Range loop
         Actual (K) := Byte (Character'Pos (T.Data (K + 1)));
      end loop;
      Record_Bytes (Name, Hex_Bytes (Field), Actual);
   end OST_Record_Text;

   procedure Check_OSD_Stats_Line is
      use Adaflight.OSD_Stats;
      Name : constant String := Str (1);
   begin
      if Name = "osinit" then
         OST_Seq := Int (2);
         OST_Cols := Integer (Int (3));
         OST_Stats := (others => <>);
      elsif Int (2) /= OST_Seq then
         Put_Line ("OSD stats line without its start");
         Failures := Failures + 1;
      elsif Name = "osreset" then
         Reset (OST_Stats, Int (3) = 1);
         OST_Record_Stats (Name, 4);
      elsif Name = "osupdate" then
         declare
            R : Readings;
         begin
            R.Speed_3D := Interfaces.Unsigned_16 (Int (3));
            R.Ground_Speed := Interfaces.Unsigned_16 (Int (4));
            R.Use_3D_Speed := Int (5) = 1;
            R.Pack_Voltage := Interfaces.Unsigned_16 (Int (6));
            R.Cell_Voltage := Interfaces.Unsigned_16 (Int (7));
            R.Show_Cell_Value := Int (8) = 1;
            R.Amperage := Interfaces.Integer_32 (Int (9));
            R.RSSI_Percent := Interfaces.Unsigned_8 (Int (10));
            R.Altitude_Cm := Interfaces.Integer_32 (Int (11));
            R.Acceleration := Flt (12);
            R.Link_Quality_Percent := Interfaces.Unsigned_16 (Int (13));
            R.RSSI_Dbm := Interfaces.Integer_16 (Int (14));
            R.RSNR := Interfaces.Integer_16 (Int (15));
            R.GPS_Fix := Int (16) = 1;
            R.GPS_Fix_Home := Int (17) = 1;
            R.Distance_To_Home := Interfaces.Unsigned_16 (Int (18));
            R.ESC_Sensor_Feature := Int (19) = 1;
            R.ESC_Temperature := Interfaces.Unsigned_8 (Int (20));
            R.ESC_Erpm := Integer (Int (21));
            R.Erpm_To_Hz := Flt (22);
            R.DShot_Telemetry := Int (23) = 1;
            R.Motors := Integer (Int (24));
            for K in Motor_Index loop
               R.DShot_Max_Temp (K) := Interfaces.Unsigned_8 (Int (25 + K));
            end loop;
            R.DShot_RPM_Average := Flt (33);
            Update (OST_Stats, R);
            OST_Record_Stats (Name, 34);
         end;
      elsif Name = "osstat" then
         declare
            P     : Adaflight.OSD_Stats.Page;
            Line  : Stat_Line;
            Which : constant Stat := Stat'Val (Int (3));
            Mid   : constant Integer_64 := Integer_64 (OST_Cols / 2);
         begin
            P.Units := Adaflight.OSD_Format.Unit_System'Val (Int (4));
            P.Timer_1 := Interfaces.Unsigned_16 (Int (5));
            P.Timer_2 := Interfaces.Unsigned_16 (Int (6));
            OST_Stats.Armed_Time_Us := Interfaces.Unsigned_32 (Int (9));
            P.Clocks := (Now_Us => Interfaces.Unsigned_32 (Int (7)), Fly_Time_Us => Interfaces.Unsigned_32 (Int (8)),
                         Armed_Time_Us => Interfaces.Unsigned_32 (Int (9)),
                         Launch_Time_Us => Interfaces.Unsigned_32 (Int (10)), Armed => Int (11) = 1);
            P.Show_Cell_Value := Int (12) = 1;
            P.GPS_Feature := Int (13) = 1;
            P.Current_Meter := Int (14) = 1;
            P.Pack_Voltage := Interfaces.Unsigned_16 (Int (15));
            P.Cell_Voltage := Interfaces.Unsigned_16 (Int (16));
            P.Flight_Distance_Cm := Interfaces.Unsigned_32 (Int (17));
            P.MAh_Drawn := Interfaces.Integer_32 (Int (18));
            P.Wh_Drawn := Flt (19);
            P.Blackbox_Device := Integer (Int (20));
            P.Blackbox_Working := Int (21) = 1;
            P.SD_Blocks := Interfaces.Unsigned_32 (Int (22));
            P.SD_Free_Bytes := Interfaces.Unsigned_32 (Int (23));
            P.Flash_Sectors := Interfaces.Unsigned_32 (Int (24));
            P.Flash_Sector_Size := Interfaces.Unsigned_32 (Int (25));
            P.Flash_Offset := Interfaces.Unsigned_32 (Int (26));
            P.Log_Number := Interfaces.Integer_32 (Int (27));
            P.Acc_Present := Int (28) = 1;
            P.Dyn_Notch_Active := Int (29) = 1;
            P.Max_FFT := Interfaces.Integer_32 (Int (30));
            P.Total_Flights := Interfaces.Unsigned_32 (Int (31));
            P.Total_Time_S := Interfaces.Unsigned_32 (Int (32));
            P.Total_Dist_M := Interfaces.Unsigned_32 (Int (33));
            P.Best_3_Consec_Ms := Interfaces.Unsigned_32 (Int (34));
            P.Best_Lap_Ms := Interfaces.Unsigned_32 (Int (35));
            P.Full_Throttle_Time_Us := Interfaces.Unsigned_32 (Int (36));
            P.Full_Throttle_Count := Interfaces.Unsigned_32 (Int (37));
            P.Average_Throttle := Interfaces.Integer_8 (Int (38));
            P.RTC_Variant := Adaflight.OSD_Format.Element_Type'Val (Int (39));
            P.Has_Time := Int (40) = 1;
            P.Date := (Year => Interfaces.Unsigned_16 (Int (41)), Month => Interfaces.Unsigned_8 (Int (42)),
                       Day => Interfaces.Unsigned_8 (Int (43)), Hours => Interfaces.Unsigned_8 (Int (44)),
                       Minutes => Interfaces.Unsigned_8 (Int (45)), Seconds => Interfaces.Unsigned_8 (Int (46)),
                       Millis => Interfaces.Unsigned_16 (Int (47)));
            P.Zone := (Zone => Interfaces.Integer_16 (Int (48)));
            Stat_Text (Which, OST_Stats, P, Line);
            Record_Int (Name & ".shown", Int (49), Boolean'Pos (Line.Shown));
            if Line.Shown then
               if Line.Labeled then
                  Record_Int (Name & ".writes", Int (51), 3);
                  Record_Int (Name & ".labelx", Int (52), (Mid - 13) mod 256);
                  Record_Int (Name & ".labely", Int (53), Int (50));
                  OST_Record_Text (Name & ".label", 54, Line.Label);
                  Record_Int (Name & ".colonx", Int (55), (Mid + 5) mod 256);
                  Record_Bytes (Name & ".colon", Hex_Bytes (57), (0 => Character'Pos (':')));
                  Record_Int (Name & ".valuex", Int (58), (Mid + 7) mod 256);
                  Record_Int (Name & ".valuey", Int (59), Int (50));
                  OST_Record_Text (Name & ".value", 60, Line.Value);
               else
                  Record_Int (Name & ".writes", Int (51), 1);
                  Record_Int (Name & ".valuex", Int (52), (Mid - 13) mod 256);
                  Record_Int (Name & ".valuey", Int (53), Int (50));
                  OST_Record_Text (Name & ".value", 54, Line.Value);
               end if;
            else
               Record_Int (Name & ".writes", Int (51), 0);
            end if;
         end;
      end if;
   end Check_OSD_Stats_Line;

   --  The OSD page: the cycle's steps, the page refresh, the armed and
   --  boot screens, each against the display writes the reference made.

   OP_Seq     : Integer_64 := -1;
   OP_Version : String (1 .. 20) := (others => ' ');
   OP_Len     : Natural := 0;
   OP_State   : Adaflight.OSD_Page.State;
   OP_Stats   : Adaflight.OSD_Stats.Statistics;

   procedure OP_Settings (F : Positive; C : out Adaflight.OSD_Page.Settings) is
   begin
      C := (others => <>);
      C.Rows := Interfaces.Unsigned_8 (Int (F));
      C.Cols := Interfaces.Unsigned_8 (Int (F + 1));
      for St in Adaflight.OSD_Stats.Stat loop
         C.Enabled (St) := (Bits (F + 2) and Interfaces.Shift_Left (1, Adaflight.OSD_Stats.Stat'Pos (St))) /= 0;
      end loop;
      C.Logo_On_Arming := Integer (Int (F + 3));
      C.Logo_Duration_Tenths := Interfaces.Unsigned_8 (Int (F + 4));
      C.Arming_Logo := Integer (Int (F + 5));
      C.Logo_Supported := Int (F + 6) = 1;
      C.Aux_Scale := Interfaces.Unsigned_16 (Int (F + 7));
      C.Aux_Visible := Int (F + 8) = 1;
      C.G_Force_Visible := Int (F + 9) = 1;
      C.Warnings_Visible := Int (F + 10) = 1;
   end OP_Settings;

   procedure OP_Read_Page (F : Positive; P : out Adaflight.OSD_Stats.Page) is
   begin
      P := (others => <>);
      P.Units := Adaflight.OSD_Format.Unit_System'Val (Int (F));
      P.Timer_1 := Interfaces.Unsigned_16 (Int (F + 1));
      P.Timer_2 := Interfaces.Unsigned_16 (Int (F + 2));
      P.Clocks := (Now_Us => Interfaces.Unsigned_32 (Int (F + 3)), Fly_Time_Us => Interfaces.Unsigned_32 (Int (F + 4)),
                   Armed_Time_Us => Interfaces.Unsigned_32 (Int (F + 5)),
                   Launch_Time_Us => Interfaces.Unsigned_32 (Int (F + 6)), Armed => Int (F + 7) = 1);
      P.Show_Cell_Value := Int (F + 8) = 1;
      P.GPS_Feature := Int (F + 9) = 1;
      P.Current_Meter := Int (F + 10) = 1;
      P.Pack_Voltage := Interfaces.Unsigned_16 (Int (F + 11));
      P.Cell_Voltage := Interfaces.Unsigned_16 (Int (F + 12));
      P.Flight_Distance_Cm := Interfaces.Unsigned_32 (Int (F + 13));
      P.MAh_Drawn := Interfaces.Integer_32 (Int (F + 14));
      P.Wh_Drawn := Flt (F + 15);
      P.Blackbox_Device := Integer (Int (F + 16));
      P.Blackbox_Working := Int (F + 17) = 1;
      P.SD_Blocks := Interfaces.Unsigned_32 (Int (F + 18));
      P.SD_Free_Bytes := Interfaces.Unsigned_32 (Int (F + 19));
      P.Flash_Sectors := Interfaces.Unsigned_32 (Int (F + 20));
      P.Flash_Sector_Size := Interfaces.Unsigned_32 (Int (F + 21));
      P.Flash_Offset := Interfaces.Unsigned_32 (Int (F + 22));
      P.Log_Number := Interfaces.Integer_32 (Int (F + 23));
      P.Acc_Present := Int (F + 24) = 1;
      P.Dyn_Notch_Active := Int (F + 25) = 1;
      P.Max_FFT := Interfaces.Integer_32 (Int (F + 26));
      P.Total_Flights := Interfaces.Unsigned_32 (Int (F + 27));
      P.Total_Time_S := Interfaces.Unsigned_32 (Int (F + 28));
      P.Total_Dist_M := Interfaces.Unsigned_32 (Int (F + 29));
      P.Best_3_Consec_Ms := Interfaces.Unsigned_32 (Int (F + 30));
      P.Best_Lap_Ms := Interfaces.Unsigned_32 (Int (F + 31));
      P.Full_Throttle_Time_Us := Interfaces.Unsigned_32 (Int (F + 32));
      P.Full_Throttle_Count := Interfaces.Unsigned_32 (Int (F + 33));
      P.Average_Throttle := Interfaces.Integer_8 (Int (F + 34));
      P.RTC_Variant := Adaflight.OSD_Format.Element_Type'Val (Int (F + 35));
      P.Has_Time := Int (F + 36) = 1;
      P.Date := (Year => Interfaces.Unsigned_16 (Int (F + 37)), Month => Interfaces.Unsigned_8 (Int (F + 38)),
                 Day => Interfaces.Unsigned_8 (Int (F + 39)), Hours => Interfaces.Unsigned_8 (Int (F + 40)),
                 Minutes => Interfaces.Unsigned_8 (Int (F + 41)), Seconds => Interfaces.Unsigned_8 (Int (F + 42)),
                 Millis => Interfaces.Unsigned_16 (Int (F + 43)));
      P.Zone := (Zone => Interfaces.Integer_16 (Int (F + 44)));
   end OP_Read_Page;

   procedure OP_Read_Readings (F : Positive; R : out Adaflight.OSD_Stats.Readings) is
   begin
      R := (others => <>);
      R.Speed_3D := Interfaces.Unsigned_16 (Int (F));
      R.Ground_Speed := Interfaces.Unsigned_16 (Int (F + 1));
      R.Use_3D_Speed := Int (F + 2) = 1;
      R.Pack_Voltage := Interfaces.Unsigned_16 (Int (F + 3));
      R.Cell_Voltage := Interfaces.Unsigned_16 (Int (F + 4));
      R.Show_Cell_Value := Int (F + 5) = 1;
      R.Amperage := Interfaces.Integer_32 (Int (F + 6));
      R.RSSI_Percent := Interfaces.Unsigned_8 (Int (F + 7));
      R.Altitude_Cm := Interfaces.Integer_32 (Int (F + 8));
      R.Acceleration := Flt (F + 9);
      R.Link_Quality_Percent := Interfaces.Unsigned_16 (Int (F + 10));
      R.RSSI_Dbm := Interfaces.Integer_16 (Int (F + 11));
      R.RSNR := Interfaces.Integer_16 (Int (F + 12));
      R.GPS_Fix := Int (F + 13) = 1;
      R.GPS_Fix_Home := Int (F + 14) = 1;
      R.Distance_To_Home := Interfaces.Unsigned_16 (Int (F + 15));
      R.ESC_Sensor_Feature := Int (F + 16) = 1;
      R.ESC_Temperature := Interfaces.Unsigned_8 (Int (F + 17));
      R.ESC_Erpm := Integer (Int (F + 18));
      R.Erpm_To_Hz := Flt (F + 19);
      R.DShot_Telemetry := Int (F + 20) = 1;
      R.Motors := Integer (Int (F + 21));
      for K in Adaflight.OSD_Stats.Motor_Index loop
         R.DShot_Max_Temp (K) := Interfaces.Unsigned_8 (Int (F + 22 + K));
      end loop;
      R.DShot_RPM_Average := Flt (F + 30);
   end OP_Read_Readings;

   procedure OP_Set_Stats (F : Positive) is
   begin
      OP_Stats := (Armed_Time_Us => Interfaces.Unsigned_32 (Int (F)),
                   Max_Speed => Interfaces.Integer_16 (Int (F + 1)),
                   Min_Voltage => Interfaces.Integer_16 (Int (F + 2)),
                   End_Voltage => Interfaces.Unsigned_16 (Int (F + 3)),
                   Max_Current => Interfaces.Integer_16 (Int (F + 4)),
                   Min_RSSI => Interfaces.Unsigned_8 (Int (F + 5)),
                   Max_Altitude => Interfaces.Integer_32 (Int (F + 6)),
                   Max_Distance => Interfaces.Integer_16 (Int (F + 7)),
                   Max_G_Force => Flt (F + 8),
                   Max_ESC_Temp_Ix => Interfaces.Integer_16 (Int (F + 9)),
                   Max_ESC_Temp => Interfaces.Integer_16 (Int (F + 10)),
                   Max_ESC_RPM => Interfaces.Integer_32 (Int (F + 11)),
                   Min_Link_Quality => Interfaces.Unsigned_16 (Int (F + 12)),
                   Min_RSSI_Dbm => Interfaces.Integer_16 (Int (F + 13)),
                   Min_RSNR => Interfaces.Integer_16 (Int (F + 14)));
   end OP_Set_Stats;

   procedure OP_Record_Stats (Name : String; F : Positive) is
   begin
      Record_Int (Name & ".armedtime", Int (F), Integer_64 (OP_Stats.Armed_Time_Us));
      Record_Int (Name & ".maxspeed", Int (F + 1), Integer_64 (OP_Stats.Max_Speed));
      Record_Int (Name & ".minvolt", Int (F + 2), Integer_64 (OP_Stats.Min_Voltage));
      Record_Int (Name & ".endvolt", Int (F + 3), Integer_64 (OP_Stats.End_Voltage));
      Record_Int (Name & ".maxcurrent", Int (F + 4), Integer_64 (OP_Stats.Max_Current));
      Record_Int (Name & ".minrssi", Int (F + 5), Integer_64 (OP_Stats.Min_RSSI));
      Record_Int (Name & ".maxalt", Int (F + 6), Integer_64 (OP_Stats.Max_Altitude));
      Record_Int (Name & ".maxdist", Int (F + 7), Integer_64 (OP_Stats.Max_Distance));
      Record_Result (Name & ".maxg", Bits (F + 8), To_Bits (OP_Stats.Max_G_Force));
      Record_Int (Name & ".esctempix", Int (F + 9), Integer_64 (OP_Stats.Max_ESC_Temp_Ix));
      Record_Int (Name & ".esctemp", Int (F + 10), Integer_64 (OP_Stats.Max_ESC_Temp));
      Record_Int (Name & ".escrpm", Int (F + 11), Integer_64 (OP_Stats.Max_ESC_RPM));
      Record_Int (Name & ".minlq", Int (F + 12), Integer_64 (OP_Stats.Min_Link_Quality));
      Record_Int (Name & ".minrssidbm", Int (F + 13), Integer_64 (OP_Stats.Min_RSSI_Dbm));
      Record_Int (Name & ".minrsnr", Int (F + 14), Integer_64 (OP_Stats.Min_RSNR));
   end OP_Record_Stats;

   procedure OP_Record_State (Name : String; F : Positive) is
   begin
      Record_Int (Name & ".armstate", Int (F), Boolean'Pos (OP_State.Arm_State));
      Record_Int (Name & ".statsenabled", Int (F + 1), Boolean'Pos (OP_State.Stats_Enabled));
      Record_Int (Name & ".statsvisible", Int (F + 2), Boolean'Pos (OP_State.Stats_Visible));
      Record_Int (Name & ".resume", Int (F + 3), Integer_64 (OP_State.Resume_Refresh_At));
      Record_Int (Name & ".flytime", Int (F + 4), Integer_64 (OP_State.Fly_Time_Us));
      Record_Int (Name & ".launchtime", Int (F + 5), Integer_64 (OP_State.Launch_Time_Us));
      Record_Int (Name & ".auxvalue", Int (F + 6), Integer_64 (OP_State.Aux_Value));
      Record_Result (Name & ".gforce", Bits (F + 7), To_Bits (OP_State.G_Force));
      Record_Int (Name & ".suppress", Int (F + 8), Boolean'Pos (OP_State.Suppress_Stats));
   end OP_Record_State;

   --  The writes expected: their count at F, then each as kind, wait,
   --  column, row, font and text.
   procedure OP_Record_Writes (Name : String; F : Positive; W : Adaflight.OSD_Page.Writes) is
      use Adaflight.OSD_Page;
   begin
      Record_Int (Name & ".writes", Int (F), Integer_64 (W.Count));
      if Integer_64 (W.Count) /= Int (F) then
         return;
      end if;
      for I in 1 .. W.Count loop
         declare
            B      : constant Positive := F + 1 + 6 * (I - 1);
            Item   : constant Write := W.List (I);
            Actual : Byte_Array (0 .. (if Item.Kind = Char_Write then 0 else Item.Text.Length - 1));
         begin
            Record_Int (Name & ".kind", Int (B), Write_Kind'Pos (Item.Kind));
            Record_Int (Name & ".wait", Int (B + 1), Boolean'Pos (Item.Wait));
            Record_Int (Name & ".x", Int (B + 2), Integer_64 (Item.X));
            Record_Int (Name & ".y", Int (B + 3), Integer_64 (Item.Y));
            Record_Int (Name & ".font", Int (B + 4), Integer_64 (Item.Font_Sel));
            if Item.Kind = Char_Write then
               Actual (0) := Byte (Character'Pos (Item.Char));
            else
               for K in Actual'Range loop
                  Actual (K) := Byte (Character'Pos (Item.Text.Data (K + 1)));
               end loop;
            end if;
            if Item.Kind in Char_Write | Text_Write then
               Record_Bytes (Name & ".text", Hex_Bytes (B + 5), Actual);
            end if;
         end;
      end loop;
   end OP_Record_Writes;

   procedure Check_OSD_Page_Line is
      use Adaflight.OSD_Page;
      Name : constant String := Str (1);
      C    : Settings;
      W    : Writes;
   begin
      if Name = "opinit" then
         OP_Seq := Int (2);
         OP_State := (others => <>);
         OP_Stats := (others => <>);
         declare
            V : constant Byte_Array := Hex_Bytes (3);
         begin
            OP_Len := V'Length;
            for K in 1 .. OP_Len loop
               OP_Version (K) := Character'Val (V (V'First + K - 1));
            end loop;
         end;
      elsif Int (2) /= OP_Seq then
         Put_Line ("OSD page line without its start");
         Failures := Failures + 1;
      elsif Name = "opstep1" then
         declare
            Inp     : Inputs;
            R       : Adaflight.OSD_Stats.Readings;
            Armed   : Boolean;
            Cleared : Boolean;
            Refresh : Boolean;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Armed := Int (4) = 1;
            Inp.Was_Ever_Armed := Int (5) = 1;
            Inp.Has_Link_Quality_Source := Int (6) = 1;
            Inp.Failsafe_Active := Int (7) = 1;
            Inp.Runaway_Or_Crash_Disable := Int (8) = 1;
            Inp.Display_Grabbed := Int (9) = 1;
            Inp.OSD_Switch := Int (10) = 1;
            Inp.Launch_Control_Active := Int (11) = 1;
            Inp.Aux_Rc := Flt (12);
            Inp.Crash_Flip_Active := Int (13) = 1;
            OP_Settings (14, C);
            OP_Read_Readings (25, R);
            OP_State.Suppress_Stats := Int (65) = 1;
            OP_State.G_Force := Flt (34);
            Process_Stats_1 (OP_State, OP_Stats, C, Inp, R, Armed, Cleared, Refresh);
            Record_Int (Name & ".refresh", Int (56), Boolean'Pos (Refresh));
            OP_Record_State (Name, 57);
            OP_Record_Stats (Name, 66);
            if Armed then
               Show_Armed (C, Inp, W);
            elsif Cleared then
               Clear_Writes (W);
               W.Count := 1;
               W.List (1) := (Kind => Clear, others => <>);
            else
               Clear_Writes (W);
            end if;
            OP_Record_Writes (Name, 81, W);
         end;
      elsif Name = "oprefresh" then
         declare
            P         : Adaflight.OSD_Stats.Page;
            Completed : Boolean;
         begin
            OP_Settings (3, C);
            OP_Read_Page (14, P);
            OP_Set_Stats (59);
            OP_State.Fly_Time_Us := P.Clocks.Fly_Time_Us;
            OP_State.Launch_Time_Us := P.Clocks.Launch_Time_Us;
            Refresh_Stats (OP_State, C, OP_Stats, P, W, Completed);
            Record_Int (Name & ".completed", Int (74), Boolean'Pos (Completed));
            Record_Int (Name & ".row", Int (75), Integer_64 (OP_State.Render.Row));
            Record_Int (Name & ".index", Int (76), Integer_64 (OP_State.Render.Index));
            Record_Int (Name & ".rowcount", Int (77), Integer_64 (OP_State.Render.Row_Count));
            OP_Record_Writes (Name, 78, W);
         end;
      elsif Name = "opstep2" then
         declare
            Inp     : Inputs;
            Skip    : Boolean;
            Cleared : Boolean;
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Armed := Int (4) = 1;
            Inp.Throttle_High := Int (5) = 1;
            Inp.Pitch_High := Int (6) = 1;
            Inp.Crash_Flip_Box := Int (7) = 1;
            OP_State.Resume_Refresh_At := Interfaces.Unsigned_32 (Int (8));
            OP_State.Suppress_Stats := Int (17) = 1;
            OP_State.G_Force := Flt (16);
            Process_Stats_2 (OP_State, OP_Stats, Inp, Skip, Cleared);
            OP_Record_State (Name, 9);
            OP_Record_Stats (Name, 18);
            Clear_Writes (W);
            if Cleared then
               W.Count := 1;
               W.List (1) := (Kind => Clear, others => <>);
            end if;
            OP_Record_Writes (Name, 33, W);
         end;
      elsif Name = "opstep3" then
         declare
            Inp : Inputs;
         begin
            Inp.Acc_Present := Int (3) = 1;
            Inp.Acc_Magnitude := Flt (4);
            OP_Settings (5, C);
            Process_Stats_3 (OP_State, C, Inp);
            Record_Result (Name & ".gforce", Bits (16), To_Bits (OP_State.G_Force));
         end;
      elsif Name = "oparmed" then
         declare
            Inp : Inputs;
         begin
            Inp.Was_Ever_Armed := Int (3) = 1;
            Inp.Crash_Flip_Active := Int (4) = 1;
            OP_Settings (5, C);
            Show_Armed (C, Inp, W);
            Record_Int (Name & ".delay", Int (16), Integer_64 (Armed_Delay_Us (C, Inp.Was_Ever_Armed)));
            OP_Record_Writes (Name, 17, W);
         end;
      elsif Name = "opboot" then
         declare
            D : constant Adaflight.RTC.Date_Time :=
              (Year => Interfaces.Unsigned_16 (Int (6)), Month => Interfaces.Unsigned_8 (Int (7)),
               Day => Interfaces.Unsigned_8 (Int (8)), Hours => Interfaces.Unsigned_8 (Int (9)),
               Minutes => Interfaces.Unsigned_8 (Int (10)), Seconds => Interfaces.Unsigned_8 (Int (11)),
               Millis => Interfaces.Unsigned_16 (Int (12)));
            Z : constant Adaflight.RTC.Settings := (Zone => Interfaces.Integer_16 (Int (13)));
         begin
            OP_Settings (14, C);
            Boot_Screen (C, OP_Version (1 .. OP_Len), Adaflight.OSD_Format.Element_Type'Val (Int (4)),
               Int (5) = 1, D, Z,
                         W);
            OP_State.Arm_State := Int (26) = 1;
            OP_State.Resume_Refresh_At := Interfaces.Unsigned_32 (Int (3)) + 4 * Refresh_1S;
            Record_Int (Name & ".resume", Int (25), Integer_64 (OP_State.Resume_Refresh_At));
            OP_Record_Writes (Name, 27, W);
         end;
      end if;
   end Check_OSD_Page_Line;

   OE_Seq   : Integer_64 := -1;
   OE_Blink : Adaflight.OSD_Elements.Blink;

   procedure OE_Record_Bits (Name : String; F : Positive) is
      use Adaflight.OSD_Elements;
      Words : array (0 .. 2) of Unsigned_32 := (others => 0);
   begin
      for I in Item loop
         if OE_Blink.Bits (I) then
            Words (Item'Pos (I) / 32) := Words (Item'Pos (I) / 32) or Interfaces.Shift_Left (1, Item'Pos (I) mod 32);
         end if;
      end loop;
      for W in Words'Range loop
         Record_Result (Name & ".bits", Bits (F + W), Words (W));
      end loop;
      Record_Int (Name & ".state", Int (F + 3), Boolean'Pos (OE_Blink.State));
   end OE_Record_Bits;

   procedure Check_OSD_Elements_Line is
      use Adaflight.OSD_Elements;
      Name : constant String := Str (1);
   begin
      if Name = "oeinit" then
         OE_Seq := Int (2);
         OE_Blink := (others => <>);
         Record_Int (Name & ".items", Int (3), Item_Count);
         Record_Int (Name & ".order", Int (4), Display_Order'Length);
      elsif Int (2) /= OE_Seq then
         Put_Line ("OSD elements line without its start");
         Failures := Failures + 1;
      elsif Name = "oeactive" then
         declare
            Inp   : Element_Inputs;
            Pos   : Positions;
            A     : Active_List;
            Count : Natural;
         begin
            Inp.Acc_Present := Int (4) = 1;
            Inp.GPS_Present := Int (5) = 1;
            Inp.ESC_Sensor_Feature := Int (6) = 1;
            Inp.DShot_Telemetry := Int (7) = 1;
            for I in Item loop
               Pos (I) := Interfaces.Unsigned_16 (Bits (8 + Item'Pos (I)));
            end loop;
            Add_Active_Elements (A, Pos, Profile_Of (Integer (Int (3))), Inp);
            Count := Natural (Int (8 + Item_Count));
            Record_Int (Name & ".count", Int (8 + Item_Count), Integer_64 (A.Count));
            for K in 1 .. Natural'Min (Count, A.Count) loop
               Record_Int (Name & ".item", Int (8 + Item_Count + K), Integer_64 (Item'Pos (A.Items (K))));
            end loop;
            Record_Int (Name & ".needacc", Int (9 + Item_Count + Count), Boolean'Pos (Need_Accelerometer (A)));
         end;
      elsif Name = "oealarm" then
         declare
            C   : Alarm_Settings;
            Inp : Alarm_Inputs;
         begin
            C.Units := Adaflight.OSD_Format.Unit_System'Val (Int (3));
            C.RSSI_Alarm := Interfaces.Unsigned_8 (Int (4));
            C.RSSI_Dbm_Alarm := Interfaces.Integer_16 (Int (5));
            C.Link_Quality_Alarm := Interfaces.Unsigned_16 (Int (6));
            C.Timers := (Interfaces.Unsigned_16 (Int (7)), Interfaces.Unsigned_16 (Int (8)));
            C.Cap_Alarm := Interfaces.Unsigned_16 (Int (9));
            C.Alt_Alarm := Interfaces.Unsigned_16 (Int (10));
            C.Distance_Alarm := Interfaces.Unsigned_16 (Int (11));
            C.ESC_Temp_Alarm := Interfaces.Unsigned_8 (Int (12));
            C.Rescue_Min_Sats := Interfaces.Unsigned_8 (Int (13));
            Inp.Altitude_Cm := Interfaces.Integer_32 (Int (14));
            Inp.RSSI_Percent := Interfaces.Unsigned_8 (Int (15));
            Inp.RSSI_Dbm := Interfaces.Integer_16 (Int (16));
            Inp.Link_Quality := Interfaces.Unsigned_16 (Int (17));
            Inp.Battery := Adaflight.Battery.Battery_State'Val (Int (18));
            Inp.GPS_Present := Int (19) = 1;
            Inp.GPS_Fix := Int (20) = 1;
            Inp.GPS_Fix_Home := Int (21) = 1;
            Inp.Satellites := Interfaces.Unsigned_8 (Int (22));
            Inp.Rescue_Configured := Int (23) = 1;
            Inp.Clocks := (Now_Us         => Interfaces.Unsigned_32 (Int (24)),
                           Fly_Time_Us    => Interfaces.Unsigned_32 (Int (25)),
                           Armed_Time_Us  => Interfaces.Unsigned_32 (Int (26)),
                           Launch_Time_Us => Interfaces.Unsigned_32 (Int (27)),
                           Armed          => Int (28) = 1);
            Inp.Profile_Capacity := (if Int (29) = 1 then Interfaces.Unsigned_16 (Int (30)) else 0);
            Inp.MAh_Drawn := Interfaces.Integer_32 (Int (31));
            Inp.Home_Distance_M := Interfaces.Unsigned_16 (Int (32));
            Inp.ESC_Sensor_Feature := Int (33) = 1;
            Inp.ESC_Temperature := Interfaces.Unsigned_8 (Int (34));
            Inp.Motors := Natural (Int (35));
            for K in Adaflight.OSD_Elements.Motor_Index loop
               Inp.DShot (K) := (Has_Temperature => (Int (36 + 2 * K) / 2) mod 2 = 1,
                                 Temperature     => Interfaces.Unsigned_16 (Int (37 + 2 * K)));
            end loop;
            Update_Alarms (OE_Blink, C, Inp);
            Sync_Blink (OE_Blink, Inp.Clocks.Now_Us);
            OE_Record_Bits (Name, 52);
            Record_Int (Name & ".isblink", Int (57), Boolean'Pos (Is_Blink (OE_Blink, Item'Val (Int (56)))));
         end;
      elsif Name = "oereset" then
         Reset_Alarms (OE_Blink);
         OE_Record_Bits (Name, 3);
      end if;
   end Check_OSD_Elements_Line;

   OR_Seq   : Integer_64 := -1;
   OR_State : Adaflight.OSD_Render.State;

   procedure Check_OSD_Render_Line is
      use Adaflight.OSD_Render;
      Name : constant String := Str (1);
   begin
      if Name = "orinit" then
         OR_Seq := Int (2);
         OR_State := (others => <>);
      elsif Int (2) /= OR_Seq then
         Put_Line ("OSD render line without its start");
         Failures := Failures + 1;
      elsif Name = "orrender" then
         declare
            C        : Settings;
            Inp      : Inputs;
            O        : Output;
            Modes    : constant Unsigned_32 := Bits (79);
            Expected : constant Byte_Array := Hex_Bytes (96);
         begin
            C.Units := Adaflight.OSD_Format.Unit_System'Val (Int (7));
            C.Alt_Alarm := Interfaces.Unsigned_16 (Int (8));
            C.Cap_Alarm := Interfaces.Unsigned_16 (Int (9));
            C.RSSI_Alarm := Interfaces.Unsigned_8 (Int (10));
            C.RSSI_Dbm_Alarm := Interfaces.Integer_16 (Int (11));
            C.Timers := (Interfaces.Unsigned_16 (Int (12)), Interfaces.Unsigned_16 (Int (13)));
            C.Aux_Symbol := Interfaces.Unsigned_8 (Int (14));
            Inp.Altitude_Cm := Interfaces.Integer_32 (Int (15));
            Inp.Altitude_Asl_Cm := Flt (16);
            Inp.Baro_Present := Int (17) = 1;
            Inp.GPS_Present := Int (18) = 1;
            Inp.GPS_Fix := Int (19) = 1;
            Inp.Roll := Interfaces.Integer_16 (Int (21));
            Inp.Pitch := Interfaces.Integer_16 (Int (22));
            Inp.Yaw := Interfaces.Integer_16 (Int (23));
            Inp.Anti_Gravity := Int (24) = 1;
            Inp.Cell_Voltage := Interfaces.Unsigned_16 (Int (25));
            Inp.Battery := Adaflight.Battery.Battery_State'Val (Int (26));
            Inp.Min_Cell := Interfaces.Unsigned_16 (Int (27));
            Inp.Max_Cell := Interfaces.Unsigned_16 (Int (28));
            Inp.Core_Temperature := Interfaces.Integer_16 (Int (29));
            Inp.Amperage := Interfaces.Integer_32 (Int (30));
            for K in Debug_Index loop
               Inp.Debug (K) := Interfaces.Integer_16 (Int (31 + K));
            end loop;
            Inp.G_Force := Flt (39);
            Inp.MAh_Drawn := Interfaces.Integer_32 (Int (40));
            Inp.Wh_Drawn := Flt (41);
            Inp.Profile_Capacity := Interfaces.Unsigned_16 (Int (42));
            Inp.Battery_Percent := Interfaces.Unsigned_8 (Int (43));
            Inp.Pack_Voltage := Interfaces.Unsigned_16 (Int (44));
            Inp.Vario_Cm_S := Interfaces.Integer_16 (Int (45));
            Inp.PID_Index := Interfaces.Unsigned_8 (Int (46));
            Inp.Rate_Index := Interfaces.Unsigned_8 (Int (47));
            for A in Axis_Index loop
               Inp.PIDs (A) := (P     => Interfaces.Unsigned_8 (Int (48 + 5 * A)),
                                I     => Interfaces.Unsigned_8 (Int (49 + 5 * A)),
                                D     => Interfaces.Unsigned_8 (Int (50 + 5 * A)),
                                F     => Interfaces.Unsigned_16 (Int (51 + 5 * A)),
                                D_Max => Interfaces.Unsigned_8 (Int (52 + 5 * A)));
            end loop;
            Inp.Clocks := (Now_Us         => Interfaces.Unsigned_32 (Int (63)),
                           Fly_Time_Us    => Interfaces.Unsigned_32 (Int (64)),
                           Armed_Time_Us  => Interfaces.Unsigned_32 (Int (65)),
                           Launch_Time_Us => Interfaces.Unsigned_32 (Int (66)),
                           Armed          => Int (20) = 1);
            Inp.RSSI_Percent := Interfaces.Unsigned_8 (Int (67));
            Inp.RSSI_Dbm := Interfaces.Integer_16 (Int (68));
            Inp.Antenna := Interfaces.Integer_8 (Int (69));
            Inp.RSNR := Interfaces.Integer_16 (Int (70));
            Inp.Throttle_Percent := Interfaces.Integer_8 (Int (71));
            Inp.Aux_Value := Interfaces.Unsigned_16 (Int (72));
            Inp.Ready_Box := Int (73) = 1;
            Inp.Pos_Hold_Ready := Int (74) = 1;
            Inp.Total_Flights := Interfaces.Unsigned_32 (Int (75));
            Inp.Crash_Flip := Int (76) = 1;
            Inp.Upright := Int (77) = 1;
            Inp.Small_Angle := Interfaces.Unsigned_8 (Int (78));
            Inp.Modes := (Failsafe   => (Modes and 1024) /= 0,
                          GPS_Rescue => (Modes and 2048) /= 0,
                          Headfree   => (Modes and 64) /= 0,
                          Passthru   => (Modes and 256) /= 0,
                          Pos_Hold   => (Modes and 32) /= 0,
                          Alt_Hold   => (Modes and 8) /= 0,
                          Chirp      => (Modes and 128) /= 0,
                          Angle      => (Modes and 1) /= 0,
                          Horizon    => (Modes and 2) /= 0);
            Inp.Acro_Trainer_Box := Int (80) = 1;
            Inp.Airmode := Int (81) = 1;
            Inp.Chirp_Total := Interfaces.Unsigned_8 (Int (82));
            Inp.Chirp_Current := Interfaces.Unsigned_8 (Int (83));
            Inp.Chirp_Finished := Int (84) = 1;
            Inp.Chirp_Series_Finished := Int (85) = 1;
            Inp.Chirp_Axis := Natural (Int (86));
            Inp.Has_Time := Int (87) = 1;
            if Inp.Has_Time then
               Inp.Date := (Year    => Interfaces.Unsigned_16 (Int (88)),
                            Month   => Interfaces.Unsigned_8 (Int (89)),
                            Day     => Interfaces.Unsigned_8 (Int (90)),
                            Hours   => Interfaces.Unsigned_8 (Int (91)),
                            Minutes => Interfaces.Unsigned_8 (Int (92)),
                            Seconds => Interfaces.Unsigned_8 (Int (93)),
                            Millis  => Interfaces.Unsigned_16 (Int (94)));
            end if;
            Inp.Zone := (Zone => Interfaces.Integer_16 (Int (95)));
            Render (Item'Val (Int (3)), Adaflight.OSD_Format.Element_Type'Val (Int (4)), OR_State, C, Inp, O);
            Record_Int (Name & ".len", Integer_64 (Expected'Length), Integer_64 (O.Line.Length));
            for K in 1 .. Natural'Min (Expected'Length, O.Line.Length) loop
               Record_Int (Name & ".text", Integer_64 (Expected (Expected'First + K - 1)),
                           Integer_64 (Character'Pos (O.Line.Data (K))));
            end loop;
            Record_Int (Name & ".offx", Int (97), Integer_64 (O.Offset_X));
            Record_Int (Name & ".offy", Int (98), Integer_64 (O.Offset_Y));
            Record_Int (Name & ".attr", Int (99), Integer_64 (Severity'Pos (O.Attr)));
            Record_Int (Name & ".draw", Int (100), Boolean'Pos (O.Draw));
            Record_Int (Name & ".rendered", Int (101), Boolean'Pos (O.Rendered));
         end;
      end if;
   end Check_OSD_Render_Line;

   OR2_Seq   : Integer_64 := -1;
   OR2_State : Adaflight.OSD_Render.State;
   OR2_Bits  : Adaflight.OSD_Elements.Item_Set := (others => False);

   function OR2_Name (I : Positive) return Adaflight.OSD_Render.Name is
      B : constant Byte_Array := Hex_Bytes (I);
      N : Adaflight.OSD_Render.Name;
   begin
      N.Length := Natural'Min (B'Length, Adaflight.OSD_Render.Max_Name);
      for K in 1 .. N.Length loop
         N.Data (K) := Character'Val (B (B'First + K - 1));
      end loop;
      return N;
   end OR2_Name;

   procedure Check_OSD_Render_2_Line is
      use Adaflight.OSD_Render;
      Name : constant String := Str (1);
      C    : Settings;
      Inp  : Inputs;
      O    : Output;
   begin
      if Name = "o2init" then
         OR2_Seq := Int (2);
         C.Framerate_Hz := Interfaces.Unsigned_16 (Int (3));
         Init (OR2_State, C);
         OR2_Bits := (others => False);
      elsif Int (2) /= OR2_Seq then
         Put_Line ("OSD render line without its start");
         Failures := Failures + 1;
      elsif Name = "o2render" or else Name = "o2bg" then
         declare
            I        : constant Item := Item'Val (Int (3));
            Expected : constant Byte_Array := Hex_Bytes (116);
         begin
            C.Units := Adaflight.OSD_Format.Unit_System'Val (Int (7));
            C.Link_Quality_Alarm := Interfaces.Unsigned_16 (Int (8));
            C.Show_PDOP := Int (9) = 1;
            C.OSD_Profile_Index := Positive (Int (10));
            for P in Profile_Number loop
               C.OSD_Profile_Names (P) := OR2_Name (10 + P);
            end loop;
            Inp.GPS_Fix := Int (14) = 1;
            Inp.GPS_Fix_Home := Int (15) = 1;
            Inp.GPS_Fix_Ever := Int (16) = 1;
            Inp.Latitude := Interfaces.Integer_32 (Int (17));
            Inp.Longitude := Interfaces.Integer_32 (Int (18));
            Inp.Satellites := Interfaces.Unsigned_8 (Int (19));
            Inp.PDOP := Interfaces.Unsigned_16 (Int (20));
            Inp.Speed_3D := Interfaces.Unsigned_16 (Int (21));
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (22));
            Inp.GPS_Time_Ms := Interfaces.Unsigned_32 (Int (23));
            Inp.Home_Distance_M := Interfaces.Unsigned_16 (Int (24));
            Inp.Home_Direction := Interfaces.Integer_16 (Int (25));
            Inp.Flown_Cm := Interfaces.Unsigned_32 (Int (26));
            Inp.Use_3D_Speed := Int (27) = 1;
            Inp.GPS_Healthy := Int (28) = 1;
            Inp.Lap_Running := Int (29) = 1;
            Inp.Lap_Last_Ms := Interfaces.Unsigned_32 (Int (30));
            Inp.Lap_Previous_Ms := Interfaces.Unsigned_32 (Int (31));
            Inp.Lap_Best3_Ms := Interfaces.Unsigned_32 (Int (32));
            Inp.Lap_Direction_Cdeg := Interfaces.Integer_32 (Int (33));
            Inp.Lap_Distance_Cm := Interfaces.Unsigned_32 (Int (34));
            Inp.Yaw := Interfaces.Integer_16 (Int (35));
            Inp.Rescue_Min_Sats := Interfaces.Unsigned_8 (Int (36));
            Inp.Rescue_Configured := Int (37) = 1;
            Inp.GPS_Present := Int (38) = 1;
            Inp.Clocks.Armed := Int (39) = 1;
            Inp.Amperage := Interfaces.Integer_32 (Int (40));
            Inp.Link_Source := Link_Quality_Source'Val (Int (41));
            Inp.Link_Quality := Interfaces.Unsigned_16 (Int (42));
            Inp.RF_Mode := Interfaces.Unsigned_8 (Int (43));
            Inp.Link_Quality_Percent := Interfaces.Unsigned_16 (Int (44));
            Inp.Uplink_Mw := Interfaces.Unsigned_16 (Int (45));
            Inp.Blackbox_Box := Int (46) = 1;
            Inp.Blackbox_Working := Int (47) = 1;
            Inp.Blackbox_Full := Int (48) = 1;
            Inp.Log_Number := Interfaces.Integer_32 (Int (49));
            Inp.ESC_Sensor_Feature := Int (50) = 1;
            Inp.ESC_Temperature := Interfaces.Unsigned_8 (Int (51));
            Inp.Motors := Positive (Int (52));
            for K in Motor_Index loop
               Inp.DShot (K) := (Has_Temperature => (Int (53 + 2 * K) / 2) mod 2 = 1,
                                 Temperature     => Interfaces.Unsigned_16 (Int (54 + 2 * K)));
               Inp.DShot_RPM (K) := Flt (70 + K);
               Inp.ESC_RPM (K) := Natural (Int (78 + K));
               Inp.Motor_Output (K) := Flt (88 + K);
            end loop;
            Inp.DShot_Telemetry := Int (69) = 1;
            Inp.ERPM_To_Hz := Flt (86);
            Inp.Motors_Running := Int (87) = 1;
            Inp.Output_Low := Flt (96);
            Inp.Output_High := Flt (97);
            Inp.Craft_Name := OR2_Name (98);
            Inp.Pilot_Name := OR2_Name (99);
            Inp.Rate_Profile_Name := OR2_Name (100);
            Inp.PID_Profile_Name := OR2_Name (101);
            Inp.Rate_Index := Interfaces.Unsigned_8 (Int (102));
            Inp.PID_Index := Interfaces.Unsigned_8 (Int (103));
            Inp.Battery_Index := Interfaces.Unsigned_8 (Int (104));
            Inp.Battery_Profile_Name := OR2_Name (105);
            for M in Message_Index loop
               Inp.Messages (M) := OR2_Name (106 + M);
            end loop;
            Inp.Custom_Text_Present := Int (110) = 1;
            declare
               B : constant Byte_Array := Hex_Bytes (111);
            begin
               Inp.Custom.Length := Natural'Min (B'Length, Max_Custom_Text);
               for K in 1 .. Inp.Custom.Length loop
                  Inp.Custom.Data (K) := Character'Val (B (B'First + K - 1));
               end loop;
            end;
            Inp.Adjustment_Present := Int (112) = 1;
            Inp.Adjustment_Name := OR2_Name (113);
            Inp.Adjustment_Value := Interfaces.Integer_32 (Int (114));
            Inp.Rangefinder_Cm := Interfaces.Integer_32 (Int (115));
            if Name = "o2bg" then
               Render_Background
                 (I, OR2_State, C, Inp, Interfaces.Unsigned_8 (Int (5)), Interfaces.Unsigned_8 (Int (6)), O);
            else
               Render (I, Adaflight.OSD_Format.Element_Type'Val (Int (4)), OR2_State, C, Inp, O);
            end if;
            case O.Blink is
               when Set => OR2_Bits (I) := True;
               when Clear => OR2_Bits (I) := False;
               when Keep => null;
            end case;
            Record_Int (Name & ".len", Integer_64 (Expected'Length), Integer_64 (O.Line.Length));
            for K in 1 .. Natural'Min (Expected'Length, O.Line.Length) loop
               Record_Int (Name & ".text", Integer_64 (Expected (Expected'First + K - 1)),
                           Integer_64 (Character'Pos (O.Line.Data (K))));
            end loop;
            Record_Int (Name & ".offx", Int (117), Integer_64 (O.Offset_X));
            Record_Int (Name & ".offy", Int (118), Integer_64 (O.Offset_Y));
            Record_Int (Name & ".attr", Int (119), Integer_64 (Severity'Pos (O.Attr)));
            Record_Int (Name & ".draw", Int (120), Boolean'Pos (O.Draw));
            Record_Int (Name & ".rendered", Int (121), Boolean'Pos (O.Rendered));
            Record_Int (Name & ".blink", Int (122), Boolean'Pos (OR2_Bits (I)));
            Record_Result (Name & ".filter", Bits (123), To_Bits (OR2_State.Efficiency.State));
         end;
      end if;
   end Check_OSD_Render_2_Line;

   OR3_Seq   : Integer_64 := -1;
   OR3_State : Adaflight.OSD_Render.State;
   OR3_Table : Adaflight.VTX_Table.Table;

   procedure OR3_Read_Table (F : Positive) is
      use Adaflight.VTX_Table;
      Letters : constant Byte_Array := Hex_Bytes (F + 66);
      Names   : constant Byte_Array := Hex_Bytes (F + 67);
   begin
      OR3_Table := Default;
      OR3_Table.Bands := Band_Count (Int (F));
      OR3_Table.Channels := Channel_Count (Int (F + 1));
      for B in Band_Index loop
         for C in Channel_Index loop
            OR3_Table.Frequency (B, C) := Interfaces.Unsigned_16 (Int (F + 2 + (B - 1) * 8 + (C - 1)));
         end loop;
         OR3_Table.Letters (B) := Character'Val (Letters (Letters'First + B - 1));
         OR3_Table.Is_Factory (B) := Int (F + 67 + B) = 1;
      end loop;
      for C in Channel_Index loop
         OR3_Table.Channel_Name (C) := Character'Val (Names (Names'First + C - 1));
      end loop;
      OR3_Table.Power_Levels := Power_Count (Int (F + 76));
      for P in Power_Index loop
         OR3_Table.Power_Value (P) := Interfaces.Unsigned_16 (Int (F + 76 + P));
         declare
            L : constant Byte_Array := Hex_Bytes (F + 84 + P);
         begin
            for K in 1 .. 3 loop
               OR3_Table.Label (P) (K) := Character'Val (L (L'First + K - 1));
            end loop;
         end;
      end loop;
   end OR3_Read_Table;

   procedure Check_OSD_Render_3_Line is
      use Adaflight.OSD_Render;
      use type Adaflight.OSD_Elements.Item;
      Name : constant String := Str (1);
      C    : Settings;
      Inp  : Inputs;
      O    : Output;
   begin
      if Name = "o3init" then
         OR3_Seq := Int (2);
         Record_Int (Name & ".framew", Int (3), 30);
         Record_Int (Name & ".frameh", Int (4), 16);
         OR3_Read_Table (5);
         Init (OR3_State, C);
      elsif Int (2) /= OR3_Seq then
         Put_Line ("OSD render line without its start");
         Failures := Failures + 1;
      elsif Name = "o3render" or else Name = "o3bg" then
         declare
            I        : constant Item := Item'Val (Int (3));
            Expected : constant Byte_Array := Hex_Bytes (43);
            Writes   : constant Natural := Natural (Int (49));
         begin
            Inp.Item_Blinks := Int (7) = 1;
            C.AH_Max_Pitch := Interfaces.Unsigned_8 (Int (8));
            C.AH_Max_Roll := Interfaces.Unsigned_8 (Int (9));
            C.AH_Invert := Int (10) = 1;
            C.Overlay_Radio_Mode := Positive (Int (11));
            for K in 0 .. 3 loop
               C.RC_Channels (K) := Interfaces.Integer_8 (Int (12 + K));
            end loop;
            C.Camera_Frame_Width := Interfaces.Unsigned_8 (Int (16));
            C.Camera_Frame_Height := Interfaces.Unsigned_8 (Int (17));
            C.VTX_Band := Interfaces.Unsigned_8 (Int (18));
            C.VTX_Channel := Interfaces.Unsigned_8 (Int (19));
            C.VTX_Frequency := Interfaces.Unsigned_16 (Int (20));
            C.VTX_Power := Interfaces.Unsigned_8 (Int (21));
            C.VTX_Low_Power_Disarm := Interfaces.Unsigned_8 (Int (22));
            Inp.Roll := Interfaces.Integer_16 (Int (23));
            Inp.Pitch := Interfaces.Integer_16 (Int (24));
            Inp.Yaw := Interfaces.Integer_16 (Int (25));
            for K in 0 .. 2 loop
               Inp.Earth_Up (K) := Flt (26 + K);
            end loop;
            for K in 0 .. 7 loop
               Inp.RC_Data (K) := Flt (29 + K);
            end loop;
            Inp.VTX := OR3_Table;
            Inp.VTX_Present := Int (37) = 1;
            Inp.VTX_Status_OK := Int (38) = 1;
            Inp.VTX_Status := Interfaces.Unsigned_8 (Int (39));
            Inp.VTX_Power_OK := Int (40) = 1;
            Inp.VTX_Power_Index := Interfaces.Unsigned_8 (Int (41));
            Inp.VTX_Control_Disable_Box := Int (42) = 1;
            if Name = "o3bg" then
               Render_Background
                 (I, OR3_State, C, Inp, Interfaces.Unsigned_8 (Int (5)), Interfaces.Unsigned_8 (Int (6)), O);
            else
               Render (I, Adaflight.OSD_Format.Element_Type'Val (Int (4)), OR3_State, C, Inp, O);
            end if;
            Record_Int (Name & ".len", Integer_64 (Expected'Length), Integer_64 (O.Line.Length));
            for K in 1 .. Natural'Min (Expected'Length, O.Line.Length) loop
               declare
                  E : Integer_64 := Integer_64 (Expected (Expected'First + K - 1));
               begin
                  --  The reference prints the low byte of the symbol's address
                  --  for the up and down reference (DESIGN.md D6); the bytes
                  --  recorded stand for U and D.
                  if I = Adaflight.OSD_Elements.Up_Down_Reference then
                     E := (if E = 255 then Character'Pos ('U') elsif E = 1 then Character'Pos ('D') else E);
                  end if;
                  Record_Int (Name & ".text", E, Integer_64 (Character'Pos (O.Line.Data (K))));
               end;
            end loop;
            Record_Int (Name & ".offx", Int (44), Integer_64 (O.Offset_X));
            Record_Int (Name & ".offy", Int (45), Integer_64 (O.Offset_Y));
            Record_Int (Name & ".attr", Int (46), Integer_64 (Severity'Pos (O.Attr)));
            Record_Int (Name & ".draw", Int (47), Boolean'Pos (O.Draw));
            Record_Int (Name & ".rendered", Int (48), Boolean'Pos (O.Rendered));
            Record_Int (Name & ".writes", Int (49), Integer_64 (O.Written));
            for W in 1 .. Natural'Min (Writes, O.Written) loop
               declare
                  F : constant Positive := 50 + (W - 1) * 5;
                  T : constant Byte_Array := Hex_Bytes (F + 4);
               begin
                  Record_Int (Name & ".wkind", Int (F), 1);
                  Record_Int (Name & ".wx", Int (F + 1), Integer_64 (O.Writes (W).X));
                  Record_Int (Name & ".wy", Int (F + 2), Integer_64 (O.Writes (W).Y));
                  Record_Int (Name & ".wattr", Int (F + 3), Integer_64 (O.Writes (W).Attr));
                  Record_Int (Name & ".wchar", (if T'Length = 1 then Integer_64 (T (T'First)) else -1),
                              Integer_64 (Character'Pos (O.Writes (W).Char)));
               end;
            end loop;
         end;
      end if;
   end Check_OSD_Render_3_Line;

   WE_Seq    : Integer_64 := -1;
   WE_Config : Adaflight.OSD_Warnings.Settings;
   WE_Const  : Adaflight.OSD_Warnings.Inputs;
   WE_State  : Adaflight.OSD_Warnings.State;

   procedure Check_OSD_Warnings_Element_Line is
      use Adaflight.OSD_Render;
      Name : constant String := Str (1);
   begin
      if Name = "weinit" then
         WE_Seq := Int (2);
         WE_State := (others => <>);
         OW_Read_Init (WE_Config, WE_Const);
      elsif Int (2) /= WE_Seq then
         Put_Line ("OSD warnings element line without its start");
         Failures := Failures + 1;
      elsif Name = "westep" then
         declare
            WI     : Adaflight.OSD_Warnings.Inputs;
            B      : Positive;
            Inp    : Inputs;
            O      : Output;
            Beeper : Boolean;
            Craft  : Craft_Name_Buffer;
         begin
            OW_Read_Step (WE_Const, WI, B);
            Inp.Link_Source := Link_Quality_Source'Val (Int (B + 28));
            Inp.Link_Quality := Interfaces.Unsigned_16 (Int (B + 29));
            Inp.RF_Mode := Interfaces.Unsigned_8 (Int (B + 30));
            Inp.RSSI_Dbm := WI.RSSI_Dbm;
            declare
               Before : constant Byte_Array := Hex_Bytes (B + 32);
            begin
               for K in Craft'Range loop
                  Craft (K) := Character'Val (Before (Before'First + K - 1));
               end loop;
            end;
            Render_Warnings (WE_State, WE_Config, WI, Int (B + 27) = 1, Int (B + 31) = 1, Inp, Craft, O, Beeper);
            declare
               Actual : Byte_Array (0 .. O.Line.Length - 1);
               After  : Byte_Array (0 .. Craft'Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (Character'Pos (O.Line.Data (K + 1)));
               end loop;
               for K in After'Range loop
                  After (K) := Byte (Character'Pos (Craft (Craft'First + K)));
               end loop;
               Record_Bytes (Name & ".text", Hex_Bytes (B + 33), Actual);
               Record_Bytes (Name & ".craft", Hex_Bytes (B + 37), After);
            end;
            Record_Int (Name & ".blink", Int (B + 34), Boolean'Pos (O.Blink = Set));
            Record_Int (Name & ".attr", Int (B + 35), Severity'Pos (O.Attr));
            Record_Int (Name & ".beeper", Int (B + 36), Boolean'Pos (Beeper));
         end;
      end if;
   end Check_OSD_Warnings_Element_Line;

   OD_Seq          : Integer_64 := -1;
   OD_Cycle        : Adaflight.OSD_Draw.Cycle;
   OD_Context      : Adaflight.OSD_Draw.Context;
   OD_Render_State : Adaflight.OSD_Render.State;
   OD_Warn_State   : Adaflight.OSD_Warnings.State;
   OD_Active       : Adaflight.OSD_Elements.Active_List;
   OD_Pos          : Adaflight.OSD_Elements.Positions := (others => 0);
   OD_Device_Blink : Boolean := False;

   function OD_Craft (F : Positive) return Adaflight.OSD_Render.Craft_Name_Buffer is
      Raw : constant Byte_Array := Hex_Bytes (F);
      C   : Adaflight.OSD_Render.Craft_Name_Buffer;
   begin
      for K in C'Range loop
         C (K) := Character'Val (Raw (Raw'First + K - 1));
      end loop;
      return C;
   end OD_Craft;

   procedure OD_Read_Blink (F : Positive; B : out Adaflight.OSD_Elements.Blink) is
      use Adaflight.OSD_Elements;
   begin
      B := (others => <>);
      for I in Item loop
         B.Bits (I) := (Bits (F + Item'Pos (I) / 32) and Interfaces.Shift_Left (1, Item'Pos (I) mod 32)) /= 0;
      end loop;
   end OD_Read_Blink;

   procedure OD_Record_Blink (Name : String; F : Positive; B : Adaflight.OSD_Elements.Blink) is
      use Adaflight.OSD_Elements;
      Words : array (0 .. 2) of Unsigned_32 := (others => 0);
   begin
      for I in Item loop
         if B.Bits (I) then
            Words (Item'Pos (I) / 32) := Words (Item'Pos (I) / 32) or Interfaces.Shift_Left (1, Item'Pos (I) mod 32);
         end if;
      end loop;
      for W in Words'Range loop
         Record_Result (Name & ".blink", Bits (F + W), Words (W));
      end loop;
   end OD_Record_Blink;

   procedure OD_Record_Ops (Name : String; F : Positive; O : Adaflight.OSD_Draw.Ops) is
      use Adaflight.OSD_Draw;
      Count : constant Natural := Natural (Int (F));
   begin
      Record_Int (Name & ".ops", Int (F), Integer_64 (O.Count));
      for K in 1 .. Natural'Min (Count, O.Count) loop
         declare
            P    : constant Op := O.List (K);
            G    : constant Positive := F + 1 + (K - 1) * 5;
            Kind : constant Integer_64 :=
              (case P.Kind is
                 when Write => 1, when Write_Sys => 2, when Select_Layer => 3, when Clear_Screen => 4,
                 when Redraw_Background => 5);
            Attr : constant Integer_64 :=
              (case P.Kind is
                 when Write => Integer_64 (P.Attr), when Write_Sys => Integer_64 (P.Sys),
                 when Select_Layer => Layer'Pos (P.Target), when Clear_Screen => Integer_64 (P.Attr),
                 when Redraw_Background => 0);
            Actual : Byte_Array (0 .. (if P.Kind = Write then P.Line.Length else 0) - 1);
         begin
            Record_Int (Name & ".opkind", Int (G), Kind);
            Record_Int (Name & ".opx", Int (G + 1), Integer_64 (P.X));
            Record_Int (Name & ".opy", Int (G + 2), Integer_64 (P.Y));
            Record_Int (Name & ".opattr", Int (G + 3), Attr);
            for J in Actual'Range loop
               Actual (J) := Byte (Character'Pos (P.Line.Data (J + 1)));
            end loop;
            Record_Bytes (Name & ".optext", Hex_Bytes (G + 4), Actual);
         end;
      end loop;
   end OD_Record_Ops;

   procedure OD_Read_Readings (X : in out Adaflight.OSD_Draw.Context) is
   begin
      X.Inputs.Roll := Interfaces.Integer_16 (Int (3));
      X.Inputs.Pitch := Interfaces.Integer_16 (Int (4));
      X.Inputs.RSSI_Percent := Interfaces.Unsigned_8 (Int (5));
      X.Warn_Inputs.RSSI_Percent := Integer (Int (5));
      X.Warn_Inputs.Battery := Adaflight.Battery.Battery_State'Val (Int (6));
      X.Inputs.Battery := Adaflight.Battery.Battery_State'Val (Int (6));
      X.Inputs.Clocks := (Now_Us         => Interfaces.Unsigned_32 (Int (8)),
                          Fly_Time_Us    => Interfaces.Unsigned_32 (Int (9)),
                          Armed_Time_Us  => Interfaces.Unsigned_32 (Int (10)),
                          Launch_Time_Us => Interfaces.Unsigned_32 (Int (11)),
                          Armed          => Int (7) = 1);
      X.Warn_Inputs.Armed := Int (7) = 1;
      X.Warn_Inputs.Now_Us := Interfaces.Unsigned_32 (Int (8));
      X.Inputs.Throttle_Percent := Interfaces.Integer_8 (Int (12));
      for K in 0 .. 3 loop
         X.Inputs.Debug (K) := Interfaces.Integer_16 (Int (13 + K));
      end loop;
      for K in 0 .. 7 loop
         X.Inputs.RC_Data (K) := Flt (17 + K);
         X.Inputs.DShot_RPM (K) := Flt (25 + K);
         X.Inputs.ESC_RPM (K) := Natural (Int (33 + K));
      end loop;
      X.Inputs.ERPM_To_Hz := Flt (41);
      X.Inputs.GPS_Fix := Int (42) = 1;
      X.Inputs.GPS_Fix_Ever := Int (43) = 1;
      X.Inputs.Latitude := Interfaces.Integer_32 (Int (44));
      X.Inputs.Longitude := Interfaces.Integer_32 (Int (45));
      X.Inputs.Link_Source := Adaflight.OSD_Render.Link_Quality_Source'Val (Int (50));
      X.Inputs.Link_Quality := Interfaces.Unsigned_16 (Int (51));
      X.Inputs.RF_Mode := Interfaces.Unsigned_8 (Int (52));
      X.Inputs.RSSI_Dbm := Interfaces.Integer_16 (Int (53));
   end OD_Read_Readings;

   procedure Check_OSD_Draw_Line is
      use Adaflight.OSD_Draw;
      Name : constant String := Str (1);
   begin
      if Name = "odinit" then
         OD_Seq := Int (2);
         OD_Context := (others => <>);
         OD_Warn_State := (others => <>);
         OD_Active := (others => <>);
         OD_Pos := (others => 0);
         Init (OD_Cycle, Int (3) = 1);
         OD_Device_Blink := Int (4) = 1;
         OD_Context.Settings.RSSI_Alarm := Interfaces.Unsigned_8 (Int (5));
         OD_Context.Warn_Settings.RSSI_Alarm := Integer (Int (5));
         OD_Context.Settings.Units := Adaflight.OSD_Format.Unit_System'Val (Int (6));
         OD_Context.Warn_Settings.Units := Adaflight.OSD_Warnings.Unit_System'Val (Int (6));
         OD_Context.Settings.Timers := (Interfaces.Unsigned_16 (Int (7)), Interfaces.Unsigned_16 (Int (8)));
         OD_Context.Settings.AH_Max_Pitch := Interfaces.Unsigned_8 (Int (9));
         OD_Context.Settings.AH_Max_Roll := Interfaces.Unsigned_8 (Int (10));
         OD_Context.Settings.AH_Invert := Int (11) = 1;
         OD_Context.Settings.Camera_Frame_Width := Interfaces.Unsigned_8 (Int (12));
         OD_Context.Settings.Camera_Frame_Height := Interfaces.Unsigned_8 (Int (13));
         OD_Context.Settings.Overlay_Radio_Mode := Positive (Int (14));
         for K in 0 .. 3 loop
            OD_Context.Settings.RC_Channels (K) := Interfaces.Integer_8 (Int (15 + K));
         end loop;
         OD_Context.Craft_Name_Messages := Int (19) = 1;
         OD_Context.Inputs.Motors := Positive (Int (20));
         for W in Adaflight.OSD_Warnings.Warning_Kind loop
            OD_Context.Warn_Settings.Enabled (W) :=
              (Bits (21) and Interfaces.Shift_Left (1, Adaflight.OSD_Warnings.Warning_Kind'Pos (W))) /= 0;
         end loop;
         declare
            Pilot : constant Adaflight.OSD_Render.Craft_Name_Buffer := OD_Craft (22);
         begin
            OD_Context.Inputs.Pilot_Name.Length := 0;
            for K in 1 .. Adaflight.OSD_Render.Max_Name loop
               exit when Pilot (K) = Character'Val (0);
               OD_Context.Inputs.Pilot_Name.Data (K) := Pilot (K);
               OD_Context.Inputs.Pilot_Name.Length := K;
            end loop;
         end;
         Adaflight.OSD_Render.Init (OD_Render_State, OD_Context.Settings);
      elsif Int (2) /= OD_Seq then
         Put_Line ("OSD draw line without its start");
         Failures := Failures + 1;
      elsif Name = "odanalyze" then
         declare
            Inp   : Adaflight.OSD_Elements.Element_Inputs;
            B     : Adaflight.OSD_Elements.Blink;
            O     : Ops;
            N     : constant Natural := Natural (Int (100));
            Craft : constant Adaflight.OSD_Render.Craft_Name_Buffer := OD_Craft (99);
         begin
            Inp := (Acc_Present => Int (3) = 1, GPS_Present => Int (4) = 1, ESC_Sensor_Feature => Int (5) = 1,
                    DShot_Telemetry => Int (6) = 1);
            OD_Context.Inputs.ESC_Sensor_Feature := Inp.ESC_Sensor_Feature;
            OD_Context.Inputs.DShot_Telemetry := Inp.DShot_Telemetry;
            OD_Context.Inputs.GPS_Present := Inp.GPS_Present;
            for I in Adaflight.OSD_Elements.Item loop
               OD_Pos (I) := Interfaces.Unsigned_16 (Bits (7 + Adaflight.OSD_Elements.Item'Pos (I)));
            end loop;
            OD_Read_Blink (96, B);
            Adaflight.OSD_Elements.Add_Active_Elements (OD_Active, OD_Pos, 1, Inp);
            Record_Int (Name & ".count", Int (100), Integer_64 (OD_Active.Count));
            for K in 1 .. Natural'Min (N, OD_Active.Count) loop
               Record_Int (Name & ".item", Int (100 + K),
                           Integer_64 (Adaflight.OSD_Elements.Item'Pos (OD_Active.Items (K))));
            end loop;
            Draw_Backgrounds (OD_Cycle, OD_Active, OD_Pos, B, OD_Render_State, OD_Context, Craft, O);
            Record_Int (Name & ".pendingbg", Int (101 + N), Boolean'Pos (OD_Cycle.Pending_Background));
            Record_Int (Name & ".pendingfg", Int (102 + N), Boolean'Pos (OD_Cycle.Pending_Foreground));
            Record_Int (Name & ".number", Int (103 + N), Integer_64 (OD_Cycle.Active_Number));
            OD_Record_Ops (Name, 104 + N, O);
         end;
      elsif Name = "oddraw" or else Name = "oddisplay" then
         declare
            B     : Adaflight.OSD_Elements.Blink;
            O     : Ops;
            More  : Boolean;
            Craft : Adaflight.OSD_Render.Craft_Name_Buffer := OD_Craft (54);
         begin
            OD_Read_Readings (OD_Context);
            OD_Read_Blink (46, B);
            B.State := Int (49) = 1;
            if Name = "oddraw" then
               Draw_Next (OD_Cycle, OD_Active, OD_Pos, B, OD_Device_Blink, OD_Render_State, OD_Warn_State, OD_Context,
                          Craft, More, O);
            else
               Display_Active (OD_Cycle, OD_Active, B, More, O);
            end if;
            Record_Int (Name & ".ret", Int (55), Boolean'Pos (More));
            Record_Int (Name & ".pendingbg", Int (56), Boolean'Pos (OD_Cycle.Pending_Background));
            Record_Int (Name & ".pendingfg", Int (57), Boolean'Pos (OD_Cycle.Pending_Foreground));
            Record_Int (Name & ".number", Int (58), Integer_64 (OD_Cycle.Active_Number));
            OD_Record_Blink (Name, 59, B);
            declare
               Expected : constant Adaflight.OSD_Render.Craft_Name_Buffer := OD_Craft (62);
               E, A     : Byte_Array (0 .. Craft'Length - 1);
            begin
               for K in E'Range loop
                  E (K) := Byte (Character'Pos (Expected (Expected'First + K)));
                  A (K) := Byte (Character'Pos (Craft (Craft'First + K)));
               end loop;
               Record_Bytes (Name & ".craft", E, A);
            end;
            OD_Record_Ops (Name, 63, O);
         end;
      end if;
   end Check_OSD_Draw_Line;

   PS_Seq     : Integer_64 := -1;
   PS_State   : Adaflight.OSD_Spec.State;
   PS_Version : String (1 .. 31) := (others => ' ');
   PS_Length  : Natural := 0;

   procedure Check_OSD_Spec_Line is
      use Adaflight.OSD_Spec;
      Name : constant String := Str (1);
   begin
      if Name = "psinit" then
         PS_Seq := Int (2);
         PS_State := (others => <>);
         declare
            V : constant Byte_Array := Hex_Bytes (3);
         begin
            PS_Length := V'Length;
            for K in 1 .. PS_Length loop
               PS_Version (K) := Character'Val (V (V'First + K - 1));
            end loop;
         end;
      elsif Int (2) /= PS_Seq then
         Put_Line ("OSD spec line without its start");
         Failures := Failures + 1;
      elsif Name = "psstep" then
         declare
            C        : Settings;
            Inp      : Inputs;
            X, Y     : Interfaces.Unsigned_8;
            Line     : Adaflight.OSD_Format.Text;
            Complete : Boolean;
         begin
            C.RPM_Limit := Int (5) = 1;
            Inp.Bidir_DShot := Int (6) = 1;
            C.RPM_Limit_Value := Interfaces.Unsigned_16 (Int (7));
            C.RPM_Limit_P := Interfaces.Unsigned_16 (Int (8));
            C.RPM_Limit_I := Interfaces.Unsigned_16 (Int (9));
            C.RPM_Limit_D := Interfaces.Unsigned_16 (Int (10));
            C.KV := Interfaces.Unsigned_16 (Int (11));
            C.Pole_Count := Interfaces.Unsigned_8 (Int (12));
            C.Throttle_Limit := Natural (Int (13));
            C.Throttle_Limit_Percent := Interfaces.Unsigned_8 (Int (14));
            C.Motor_Output_Limit := Interfaces.Unsigned_8 (Int (15));
            Inp.Pack_Voltage := Interfaces.Unsigned_16 (Int (16));
            Inp.Cell_Voltage := Interfaces.Unsigned_16 (Int (17));
            Inp.Battery := Adaflight.Battery.Battery_State'Val (Int (18));
            C.Min_Cell := Interfaces.Unsigned_16 (Int (19));
            C.Max_Cell := Interfaces.Unsigned_16 (Int (20));
            Draw (PS_State, C, Inp, Interfaces.Unsigned_8 (Int (3)), Interfaces.Unsigned_8 (Int (4)),
                  PS_Version (1 .. PS_Length), X, Y, Line, Complete);
            Record_Int (Name & ".done", Int (21), Boolean'Pos (Complete));
            Record_Int (Name & ".writes", Int (22), 1);
            Record_Int (Name & ".x", Int (23), Integer_64 (X));
            Record_Int (Name & ".y", Int (24), Integer_64 (Y));
            Record_Int (Name & ".attr", Int (25), 0);
            declare
               Actual : Byte_Array (0 .. Line.Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (Character'Pos (Line.Data (K + 1)));
               end loop;
               Record_Bytes (Name & ".text", Hex_Bytes (26), Actual);
            end;
         end;
      end if;
   end Check_OSD_Spec_Line;

   OT_Seq     : Integer_64 := -1;
   OT_OSD     : Adaflight.OSD_Task.OSD;
   OT_Context : Adaflight.OSD_Task.Context;
   OT_Sched   : Adaflight.Scheduler.State;

   procedure OT_Record_Ops (Name : String; F : Positive; O : Adaflight.OSD_Task.Ops) is
      use Adaflight.OSD_Task;
      Count : constant Natural := Natural (Int (F));
   begin
      Record_Int (Name & ".ops", Int (F), Integer_64 (O.Count));
      for K in 1 .. Natural'Min (Count, O.Count) loop
         declare
            P      : constant Op := O.List (K);
            G      : constant Positive := F + 1 + (K - 1) * 5;
            Actual : Byte_Array (0 .. (if P.Kind in Write | Write_Char then P.Line.Length else 0) - 1);
         begin
            Record_Int (Name & ".opkind", Int (G), Op_Kind'Pos (P.Kind));
            Record_Int (Name & ".opx", Int (G + 1), Integer_64 (P.X));
            Record_Int (Name & ".opy", Int (G + 2), Integer_64 (P.Y));
            Record_Int (Name & ".opattr", Int (G + 3), Integer_64 (P.Attr));
            for J in Actual'Range loop
               Actual (J) := Byte (Character'Pos (P.Line.Data (J + 1)));
            end loop;
            Record_Bytes (Name & ".optext", Hex_Bytes (G + 4), Actual);
         end;
      end loop;
   end OT_Record_Ops;

   procedure Check_OSD_Task_Line is
      use Adaflight.OSD_Task;
      Name : constant String := Str (1);
      C    : Context renames OT_Context;
   begin
      if Name = "otinit" then
         OT_Seq := Int (2);
         OT_OSD := (others => <>);
         C := (others => <>);
         C.Device := Device_Kind'Val (Int (3));
         OP_Settings (4, C.Page_Settings);
         C.Alarm_Settings.Units := Adaflight.OSD_Format.Unit_System'Val (Int (15));
         C.Alarm_Settings.RSSI_Alarm := Interfaces.Unsigned_8 (Int (16));
         C.Alarm_Settings.RSSI_Dbm_Alarm := Interfaces.Integer_16 (Int (17));
         C.Alarm_Settings.Link_Quality_Alarm := Interfaces.Unsigned_16 (Int (18));
         C.Alarm_Settings.Timers := (Interfaces.Unsigned_16 (Int (19)), Interfaces.Unsigned_16 (Int (20)));
         C.Alarm_Settings.Cap_Alarm := Interfaces.Unsigned_16 (Int (21));
         C.Alarm_Settings.Alt_Alarm := Interfaces.Unsigned_16 (Int (22));
         C.Alarm_Settings.Distance_Alarm := Interfaces.Unsigned_16 (Int (23));
         C.Alarm_Settings.ESC_Temp_Alarm := Interfaces.Unsigned_8 (Int (24));
         C.Alarm_Settings.Rescue_Min_Sats := Interfaces.Unsigned_8 (Int (27));
         C.Rate_Hz := Interfaces.Unsigned_16 (Int (25));
         C.Show_Spec := Int (26) = 1;
         C.Alarm_Inputs.Rescue_Configured := Int (28) = 1;
         C.Alarm_Inputs.Profile_Capacity := Interfaces.Unsigned_16 (Int (29));
         C.Spec_Settings.Min_Cell := Interfaces.Unsigned_16 (Int (30));
         C.Spec_Settings.RPM_Limit := Int (31) = 1;
         C.Spec_Inputs.Bidir_DShot := Int (32) = 1;
         C.Spec_Settings.RPM_Limit_Value := Interfaces.Unsigned_16 (Int (33));
         C.Spec_Settings.RPM_Limit_P := Interfaces.Unsigned_16 (Int (34));
         C.Spec_Settings.RPM_Limit_I := Interfaces.Unsigned_16 (Int (35));
         C.Spec_Settings.RPM_Limit_D := Interfaces.Unsigned_16 (Int (36));
         C.Spec_Settings.KV := Interfaces.Unsigned_16 (Int (37));
         C.Spec_Settings.Pole_Count := Interfaces.Unsigned_8 (Int (38));
         C.Spec_Settings.Throttle_Limit := Natural (Int (39));
         C.Spec_Settings.Throttle_Limit_Percent := Interfaces.Unsigned_8 (Int (40));
         C.Spec_Settings.Max_Cell := Interfaces.Unsigned_16 (Int (41));
         C.Spec_Settings.Motor_Output_Limit := Interfaces.Unsigned_8 (Int (42));
         C.Draw.Settings.RSSI_Alarm := Interfaces.Unsigned_8 (Int (16));
         C.Draw.Settings.Units := Adaflight.OSD_Format.Unit_System'Val (Int (15));
         C.Draw.Settings.Timers := (Interfaces.Unsigned_16 (Int (19)), Interfaces.Unsigned_16 (Int (20)));
         C.Draw.Settings.Framerate_Hz := Interfaces.Unsigned_16 (Int (25));
         for I in Adaflight.OSD_Elements.Item loop
            C.Positions (I) := Interfaces.Unsigned_16 (Bits (43 + Adaflight.OSD_Elements.Item'Pos (I)));
         end loop;
         declare
            Craft   : constant Byte_Array := Hex_Bytes (132);
            Version : constant Byte_Array := Hex_Bytes (133);
         begin
            for K in Craft'Range loop
               OT_OSD.Craft (K - Craft'First + 1) := Character'Val (Craft (K));
            end loop;
            C.Version_Length := Version'Length;
            for K in Version'Range loop
               C.Version (K - Version'First + 1) := Character'Val (Version (K));
            end loop;
         end;
      elsif Int (2) /= OT_Seq then
         Put_Line ("OSD task line without its start");
         Failures := Failures + 1;
      elsif Name = "otcheck" then
         declare
            Due : Boolean;
         begin
            Record_Int (Name & ".before", Int (5), Task_State'Pos (OT_OSD.State));
            Update_Check (OT_OSD, C, Interfaces.Unsigned_32 (Int (3)), Int (4) = 1, Due);
            Record_Int (Name & ".due", Int (6), Boolean'Pos (Due));
            Record_Int (Name & ".after", Int (7), Task_State'Pos (OT_OSD.State));
         end;
      elsif Name = "otupdate" then
         declare
            Answers : constant Display_Answers :=
              (Ready => Int (6) = 1, Transfer_In_Progress => Int (7) = 1, Heartbeat_Taken => Int (8) = 1,
               More_To_Draw => Int (9) = 1, Grabbed => Int (10) = 1);
            O       : Ops;
         begin
            C.Page_Inputs := (others => <>);
            C.Page_Inputs.Now_Us := Interfaces.Unsigned_32 (Int (3));
            C.Page_Inputs.Armed := Int (11) = 1;
            C.Page_Inputs.Was_Ever_Armed := Int (12) = 1;
            C.Page_Inputs.Has_Link_Quality_Source := Int (13) = 1;
            C.Page_Inputs.Failsafe_Active := Int (14) = 1;
            C.Page_Inputs.Display_Grabbed := Int (10) = 1;
            C.Page_Inputs.OSD_Switch := Int (15) = 1;
            C.Page_Inputs.Launch_Control_Active := Int (16) = 1;
            C.Page_Inputs.Crash_Flip_Box := Int (17) = 1;
            C.Page_Inputs.Crash_Flip_Active := Int (18) = 1;
            C.Page_Inputs.Aux_Rc := Flt (19);
            C.Page_Inputs.Throttle_High := Int (20) = 1;
            C.Page_Inputs.Pitch_High := Int (21) = 1;
            C.Page_Inputs.Acc_Present := Int (22) = 1;
            C.Page_Inputs.Acc_Magnitude := Flt (23);
            OP_Read_Readings (24, C.Readings);
            C.Alarm_Inputs.Altitude_Cm := Interfaces.Integer_32 (Int (32));
            C.Alarm_Inputs.RSSI_Percent := Interfaces.Unsigned_8 (Int (31));
            C.Alarm_Inputs.RSSI_Dbm := Interfaces.Integer_16 (Int (35));
            C.Alarm_Inputs.Link_Quality := Interfaces.Unsigned_16 (Int (34));
            C.Alarm_Inputs.Battery := Adaflight.Battery.Battery_State'Val (Int (55));
            C.Alarm_Inputs.GPS_Present := Int (57) = 1;
            C.Alarm_Inputs.GPS_Fix := Int (37) = 1;
            C.Alarm_Inputs.GPS_Fix_Home := Int (38) = 1;
            C.Alarm_Inputs.Satellites := Interfaces.Unsigned_8 (Int (56));
            C.Alarm_Inputs.MAh_Drawn := Interfaces.Integer_32 (Int (58));
            C.Alarm_Inputs.Home_Distance_M := Interfaces.Unsigned_16 (Int (39));
            C.Alarm_Inputs.ESC_Sensor_Feature := Int (40) = 1;
            C.Alarm_Inputs.ESC_Temperature := Interfaces.Unsigned_8 (Int (41));
            C.Alarm_Inputs.Motors := Natural (Int (45));
            for K in Adaflight.OSD_Elements.Motor_Index loop
               C.Alarm_Inputs.DShot (K) := (Has_Temperature => (Int (60 + 2 * K) / 2) mod 2 = 1,
                                            Temperature     => Interfaces.Unsigned_16 (Int (61 + 2 * K)));
            end loop;
            C.Element_Inputs := (Acc_Present => Int (22) = 1, GPS_Present => Int (57) = 1,
                                 ESC_Sensor_Feature => Int (40) = 1, DShot_Telemetry => Int (44) = 1);
            C.Draw.Inputs.RSSI_Percent := Interfaces.Unsigned_8 (Int (31));
            C.Spec_Inputs.Pack_Voltage := Interfaces.Unsigned_16 (Int (27));
            C.Spec_Inputs.Cell_Voltage := Interfaces.Unsigned_16 (Int (28));
            C.Spec_Inputs.Battery := Adaflight.Battery.Battery_State'Val (Int (55));
            C.RTC_Variant := Adaflight.OSD_Format.Element_Type'Val (Int (76));
            C.Has_Time := Int (77) = 1;
            if C.Has_Time then
               C.Date := (Year    => Interfaces.Unsigned_16 (Int (78)), Month => Interfaces.Unsigned_8 (Int (79)),
                          Day     => Interfaces.Unsigned_8 (Int (80)), Hours => Interfaces.Unsigned_8 (Int (81)),
                          Minutes => Interfaces.Unsigned_8 (Int (82)), Seconds => Interfaces.Unsigned_8 (Int (83)),
                          Millis  => Interfaces.Unsigned_16 (Int (84)));
            end if;
            C.Zone := (Zone => Interfaces.Integer_16 (Int (85)));
            Record_Int (Name & ".before", Int (86), Task_State'Pos (OT_OSD.State));
            OT_Sched.Ignore_Exec_Rate := False;
            OT_Sched.Ignore_Exec_Time := False;
            OT_Sched.Next_State_Time := -1;
            Update (OT_OSD, C, Interfaces.Unsigned_32 (Int (3)), Interfaces.Unsigned_32 (Int (4)),
                    Interfaces.Unsigned_32 (Int (5)), Answers, OT_Sched, O);
            Record_Int (Name & ".after", Int (87), Task_State'Pos (OT_OSD.State));
            Record_Int (Name & ".ignorerate", Int (89), Boolean'Pos (OT_Sched.Ignore_Exec_Rate));
            Record_Int (Name & ".ignoretime", Int (90), Boolean'Pos (OT_Sched.Ignore_Exec_Time));
            Record_Int (Name & ".nextstate", Int (92), Integer_64 (OT_Sched.Next_State_Time));
            OP_State := OT_OSD.Page;
            OP_Record_State (Name, 93);
            OP_Stats := OT_OSD.Stats;
            OP_Record_Stats (Name, 102);
            OT_Record_Ops (Name, 117, O);
         end;
      end if;
   end Check_OSD_Task_Line;

   package MVT renames Adaflight.MAVLink_Telemetry;
   MV_Seq    : Integer_64 := -1;
   MV_State  : Adaflight.MAVLink_Telemetry.State;
   MV_Config : Adaflight.MAVLink_Telemetry.Settings;

   procedure MV_Record_Streams (Name : String; F : Positive) is
   begin
      for M in MVT.Output_Message loop
         Record_Int
           (Name & ".interval", Int (F + 2 * MVT.Output_Message'Pos (M)),
            Integer_64 (MV_State.Streams (M).Interval_Ms));
         Record_Int
           (Name & ".due", Int (F + 1 + 2 * MVT.Output_Message'Pos (M)), Integer_64 (MV_State.Streams (M).Due_Ms));
      end loop;
      Record_Int (Name & ".seq", Int (F + 20), Integer_64 (MV_State.Tx_Seq));
   end MV_Record_Streams;

   procedure Check_MAVLink_Telemetry_Line is
      Name : constant String := Str (1);
   begin
      if Name = "mvinit" then
         MV_Seq := Int (2);
         MV_State := (others => <>);
         MV_Config := (others => <>);
         for St in MVT.Stream loop
            MV_Config.Rates (St) := Interfaces.Unsigned_8 (Int (3 + MVT.Stream'Pos (St)));
         end loop;
         MVT.Configure_Intervals (MV_State, MV_Config, Interfaces.Unsigned_32 (Int (9)));
         MV_Record_Streams (Name, 10);
      elsif Int (2) /= MV_Seq then
         Put_Line ("MAVLink telemetry line without its start");
         Failures := Failures + 1;
      elsif Name = "mvhandle" then
         declare
            Inp   : MVT.Inputs;
            O     : MVT.Output;
            Flags : constant Unsigned_32 := Bits (56);
         begin
            Inp.Battery := Adaflight.Battery.Battery_State'Val (Int (5));
            Inp.Voltage_Configured := Int (6) = 1;
            Inp.Amperage_Configured := Int (7) = 1;
            Inp.Pack_Voltage := Interfaces.Unsigned_16 (Int (8));
            Inp.Cell_Voltage := Interfaces.Unsigned_16 (Int (9));
            Inp.Amperage := Interfaces.Integer_32 (Int (10));
            Inp.MAh_Drawn := Interfaces.Integer_32 (Int (11));
            Inp.Battery_Percent := Interfaces.Unsigned_8 (Int (12));
            Inp.Cell_Count := Interfaces.Unsigned_8 (Int (13));
            Inp.RSSI := Interfaces.Unsigned_16 (Int (14));
            Inp.Channel_Count := Natural (Int (15));
            for K in 0 .. 7 loop
               Inp.RC (K) := Flt (16 + K);
            end loop;
            Inp.Roll := Interfaces.Integer_16 (Int (24));
            Inp.Pitch := Interfaces.Integer_16 (Int (25));
            Inp.Yaw := Interfaces.Integer_16 (Int (26));
            Inp.GPS_Present := Int (27) = 1;
            Inp.Mag_Present := Int (28) = 1;
            Inp.Baro_Present := Int (29) = 1;
            Inp.GPS_Fix := Int (30) = 1;
            Inp.GPS_Fix_Home := Int (31) = 1;
            Inp.Latitude := Interfaces.Integer_32 (Int (32));
            Inp.Longitude := Interfaces.Integer_32 (Int (33));
            Inp.Altitude_Cm := Interfaces.Integer_32 (Int (34));
            Inp.HDOP := Interfaces.Unsigned_16 (Int (35));
            Inp.VDOP := Interfaces.Unsigned_16 (Int (36));
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (37));
            Inp.Ground_Course := Interfaces.Unsigned_16 (Int (38));
            Inp.Satellites := Interfaces.Unsigned_8 (Int (39));
            Inp.H_Acc := Interfaces.Unsigned_32 (Int (40));
            Inp.V_Acc := Interfaces.Unsigned_32 (Int (41));
            Inp.S_Acc := Interfaces.Unsigned_32 (Int (42));
            Inp.Vel_N := Interfaces.Integer_16 (Int (43));
            Inp.Vel_E := Interfaces.Integer_16 (Int (44));
            Inp.Vel_D := Interfaces.Integer_16 (Int (45));
            Inp.Home_Latitude := Interfaces.Integer_32 (Int (46));
            Inp.Home_Longitude := Interfaces.Integer_32 (Int (47));
            Inp.Home_Altitude_Cm := Interfaces.Integer_32 (Int (48));
            Inp.Estimated_Alt_Cm := Interfaces.Integer_32 (Int (49));
            Inp.Mixer_Mode := Interfaces.Unsigned_8 (Int (50));
            Inp.Armed := Int (51) = 1;
            Inp.Failsafe_Active := Int (52) = 1;
            Inp.Modes := Interfaces.Unsigned_16 (Int_Hex (53));
            Inp.Has_Time := Int (54) = 1;
            Inp.RTC_Ms := Int (55);
            for R in Adaflight.Arming.Disable_Reason loop
               Inp.Disable_Flags (R) :=
                 (Flags and Interfaces.Shift_Left (1, Adaflight.Arming.Disable_Reason'Pos (R))) /= 0;
            end loop;
            MV_Config.MAh_Heading_Divisor := Interfaces.Unsigned_16 (Int (59));
            MV_Config.Report_Cell_Voltage := Int (60) = 1;
            MVT.Handle (MV_State, MV_Config, Inp, Interfaces.Unsigned_32 (Int (3)), Interfaces.Unsigned_32 (Int (4)),
                    Int (57) = 1, Int (58) = 1, O);
            Record_Int (Name & ".lastsend", Int (61), Integer_64 (MV_State.Last_Message_Us));
            MV_Record_Streams (Name, 62);
            declare
               Actual : Byte_Array (0 .. O.Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (O.Data (K + 1));
               end loop;
               Record_Int (Name & ".length", Int (83), Integer_64 (O.Length));
               Record_Bytes (Name & ".bytes", Hex_Bytes (84), Actual);
            end;
         end;
      elsif Name = "mvsetint" then
         declare
            Found : Boolean;
         begin
            MVT.Set_Message_Interval (MV_State, MV_Config, Natural (Int (3)), Interfaces.Unsigned_32 (Int (4)), Found);
            Record_Int (Name & ".found", Int (5), Boolean'Pos (Found));
            MV_Record_Streams (Name, 6);
         end;
      elsif Name = "mvgetint" then
         Record_Int (Name & ".interval", Int (4), Integer_64 (MVT.Message_Interval_Us (MV_State, Natural (Int (3)))));
      end if;
   end Check_MAVLink_Telemetry_Line;

   package MVC renames Adaflight.MAVLink_Commands;
   MC_Seq       : Integer_64 := -1;
   MC_Queue     : Boolean := False;
   MC_State     : MVC.State;
   MC_Config    : MVC.Settings;
   MC_Link      : Adaflight.MAVLink_Telemetry.State;
   MC_Link_Conf : Adaflight.MAVLink_Telemetry.Settings;
   MC_Rx        : Adaflight.MAVLink.State;
   MC_Receiver  : Adaflight.Receiver.State;
   MC_Fifo      : Adaflight.MAVLink_Frames.Byte_Buffer (1 .. 8192) := (others => 0);
   MC_Waiting   : Natural := 0;

   procedure MC_Record_State (Name : String; F : Positive) is
   begin
      for M in MVT.Output_Message loop
         Record_Int
           (Name & ".interval", Int (F + MVT.Output_Message'Pos (M)), Integer_64 (MC_Link.Streams (M).Interval_Ms));
      end loop;
      Record_Int (Name & ".seq", Int (F + 10), Integer_64 (MC_Link.Tx_Seq));
      Record_Int
        (Name & ".parse_state", Int (F + 11), Adaflight.MAVLink.Parse_State'Pos (MC_State.Port.Status.State));
      Record_Int (Name & ".packet_idx", Int (F + 12), Integer_64 (MC_State.Port.Status.Packet_Idx));
      Record_Int (Name & ".pending", Int (F + 13), Boolean'Pos (MC_State.Reboot_Pending));
      Record_Int (Name & ".bootloader", Int (F + 14), Boolean'Pos (MC_State.To_Bootloader));
   end MC_Record_State;

   procedure Check_MAVLink_Commands_Line is
      Name : constant String := Str (1);
   begin
      if Name = "mcinit" then
         MC_Seq := Int (2);
         MC_Queue := Int (3) = 1;
         MC_State := (others => <>);
         MC_Config := (others => <>);
         MC_Link := (others => <>);
         MC_Link_Conf := (others => <>);
         MC_Waiting := 0;
         for K in 0 .. 2 loop
            MC_Config.UID (K) := Interfaces.Unsigned_32 (Int (4 + K));
         end loop;
         for St in MVT.Stream loop
            MC_Link_Conf.Rates (St) := Interfaces.Unsigned_8 (Int (7 + MVT.Stream'Pos (St)));
         end loop;
         MVT.Configure_Intervals (MC_Link, MC_Link_Conf, Interfaces.Unsigned_32 (Int (13)));
         Adaflight.MAVLink.Init (MC_Rx, 1500);
         MC_Record_State (Name, 14);
      elsif Int (2) /= MC_Seq then
         Put_Line ("MAVLink command line without its start");
         Failures := Failures + 1;
      elsif Name = "mcstep" then
         declare
            Inp      : MVC.Inputs;
            O        : MVC.Output;
            R        : MVC.Requests;
            Incoming : constant Byte_Array := Hex_Bytes (12);
            Consumed : Natural;
            Ops      : String (1 .. 80);
            Op_Count : Natural := 0;
            Boxes    : String (1 .. 200);
            Box_Len  : Natural := 0;
            Overrides : Natural := 0;
            Fix_Home : Boolean := Int (7) = 1;
            Lat      : Integer_64 := Int (8);
            Lon      : Integer_64 := Int (9);
            Alt      : Integer_64 := Int (10);

            procedure Op (C : Character) is
            begin
               Op_Count := Op_Count + 1;
               Ops (Op_Count) := C;
            end Op;
         begin
            Inp.Armed := Int (5) = 1;
            Inp.GPS_Fix := Int (6) = 1;
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Interfaces.Unsigned_32 (Int (4));
            if MC_Queue then
               for B of Incoming loop
                  Adaflight.MAVLink.Receive_Byte (MC_Rx, MC_Receiver, Natural (B), Inp.Now_Us);
               end loop;
               MVC.Process_Queue (MC_State, MC_Link, MC_Link_Conf, MC_Config, Inp, MC_Rx, O, R);
               Record_Int
                 (Name & ".queue", Int (14),
                  Integer_64
                    ((MC_Rx.Head - MC_Rx.Tail + Adaflight.MAVLink.Queue_Size) mod Adaflight.MAVLink.Queue_Size));
            else
               for B of Incoming loop
                  MC_Waiting := MC_Waiting + 1;
                  MC_Fifo (MC_Waiting) := Interfaces.Unsigned_8 (B);
               end loop;
               MVC.Process_Port
                 (MC_State, MC_Link, MC_Link_Conf, MC_Config, Inp, MC_Fifo (1 .. MC_Waiting), Consumed, O, R);
               MC_Fifo (1 .. MC_Waiting - Consumed) := MC_Fifo (Consumed + 1 .. MC_Waiting);
               MC_Waiting := MC_Waiting - Consumed;
               Record_Int (Name & ".waiting", Int (13), Integer_64 (MC_Waiting));
            end if;
            declare
               Actual : Byte_Array (0 .. O.Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (O.Data (K + 1));
               end loop;
               Record_Int (Name & ".length", Int (15), Integer_64 (O.Length));
               Record_Bytes (Name & ".bytes", Hex_Bytes (16), Actual);
            end;
            for K in 1 .. R.Count loop
               case R.List (K).Kind is
                  when MVC.Disarm =>
                     Op ('D');
                  when MVC.Clear_Overrides =>
                     Op ('C');
                  when MVC.Set_Override =>
                     Op ('S');
                     declare
                        Img : constant String := Integer'Image (Adaflight.Modes.Box'Pos (R.List (K).Box));
                     begin
                        if Overrides > 0 then
                           Box_Len := Box_Len + 1;
                           Boxes (Box_Len) := ':';
                        end if;
                        Boxes (Box_Len + 1 .. Box_Len + Img'Length - 1) := Img (Img'First + 1 .. Img'Last);
                        Box_Len := Box_Len + Img'Length - 1;
                        Overrides := Overrides + 1;
                     end;
                  when MVC.Reset_Home =>
                     Op ('H');
                  when MVC.Set_Home =>
                     Fix_Home := True;
                     Lat := Integer_64 (R.List (K).Latitude);
                     Lon := Integer_64 (R.List (K).Longitude);
                     Alt := Integer_64 (R.List (K).Altitude_Cm);
               end case;
            end loop;
            case R.Reboot is
               when MVC.None => null;
               when MVC.Reset => Op ('W'); Op ('M'); Op ('R');
               when MVC.Bootloader => Op ('W'); Op ('M'); Op ('B');
            end case;
            Record_Text (Name & ".ops", Str (17), (if Op_Count = 0 then "-" else Ops (1 .. Op_Count)));
            Record_Int (Name & ".overrides", Int (18), Integer_64 (Overrides));
            Record_Text (Name & ".boxes", Str (19), Boxes (1 .. Box_Len));
            Record_Int (Name & ".fix_home", Int (20), Boolean'Pos (Fix_Home));
            Record_Int (Name & ".home_lat", Int (21), Lat);
            Record_Int (Name & ".home_lon", Int (22), Lon);
            Record_Int (Name & ".home_alt", Int (23), Alt);
            MC_Record_State (Name, 24);
         end;
      end if;
   end Check_MAVLink_Commands_Line;

   package JTL renames Adaflight.Jeti_Telemetry;
   JT_Seq    : Integer_64 := -1;
   JT_State  : JTL.State;
   JT_Config : JTL.Settings;
   JT_Rx     : Adaflight.Jeti_Ex_Bus.State;
   JT_Clock  : Interfaces.Unsigned_32 := 0;
   JT_One_G  : Positive := 1;
   JT_Erpm   : Float := 0.0;
   JT_Motors : Natural := 0;

   function JT_Mask return Integer_64 is
      M : Integer_64 := 0;
   begin
      for I in JTL.Sensor_Index loop
         if JT_State.Enabled (I) then
            M := M + 2 ** I;
         end if;
      end loop;
      return M;
   end JT_Mask;

   procedure Check_Jeti_Telemetry_Line is
      Name : constant String := Str (1);
   begin
      if Name = "jtinit" then
         JT_Seq := Int (2);
         JT_Config :=
           (Voltage_Meter => Int (3) /= 0,
            Current_Meter => Int (4) /= 0,
            Baro          => Int (5) / 4 mod 2 = 1,
            Acc           => Int (5) / 2 mod 2 = 1,
            Mag           => Int (5) / 8 mod 2 = 1,
            GPS_Feature   => Int (6) / 2 ** 7 mod 2 = 1,
            ESC_Feature   => Int (6) / 2 ** 27 mod 2 = 1,
            Debug_Mode    => Int (7) /= 0);
         JT_One_G := Positive (Int (8));
         JT_Erpm := To_Float (Bits (9));
         JT_Motors := Natural (Int (10));
         JT_Clock := Interfaces.Unsigned_32 (Int (11));
         Adaflight.Jeti_Ex_Bus.Init (JT_Rx);
         JTL.Init (JT_State, JT_Config);
         Record_Int (Name & ".enabled", Int_Hex (12), JT_Mask);
         Record_Int (Name & ".first", Int (13), Integer_64 (JT_State.First_Active));
      elsif Int (2) /= JT_Seq then
         Put_Line ("Jeti telemetry line without its start");
         Failures := Failures + 1;
      elsif Name = "jtstep" then
         declare
            Incoming : constant Byte_Array := Hex_Bytes (6);
            Inp      : JTL.Inputs;
            O        : JTL.Output;
         begin
            JT_Clock := JT_Clock + Interfaces.Unsigned_32 (Int (3));
            for K in Incoming'Range loop
               if K > Incoming'First then
                  JT_Clock := JT_Clock + 87;
               end if;
               Adaflight.Jeti_Ex_Bus.Receive_Byte (JT_Rx, Natural (Incoming (K)), JT_Clock);
            end loop;
            JT_Clock := JT_Clock + Interfaces.Unsigned_32 (Int (7));
            Record_Int (Name & ".clock", Int (4), Integer_64 (JT_Clock));
            Inp.Legacy_Voltage := Interfaces.Unsigned_16 (Int (9));
            Inp.Pack_Voltage := Interfaces.Unsigned_16 (Int (10));
            Inp.Amperage := Interfaces.Integer_32 (Int (11));
            Inp.Altitude_Cm := Interfaces.Integer_32 (Int (12));
            Inp.MAh_Drawn := Interfaces.Integer_32 (Int (13));
            Inp.Vario := Interfaces.Integer_16 (Int (14));
            Inp.Roll := Interfaces.Integer_16 (Int (15));
            Inp.Pitch := Interfaces.Integer_16 (Int (16));
            Inp.Yaw := Interfaces.Integer_16 (Int (17));
            Inp.Satellites := Interfaces.Unsigned_8 (Int (18));
            Inp.Longitude := Interfaces.Integer_32 (Int (19));
            Inp.Latitude := Interfaces.Integer_32 (Int (20));
            Inp.Ground_Speed := Interfaces.Unsigned_16 (Int (21));
            Inp.Home_Distance := Interfaces.Unsigned_16 (Int (22));
            Inp.Home_Direction := Interfaces.Integer_16 (Int (23));
            Inp.Ground_Course := Interfaces.Unsigned_16 (Int (24));
            Inp.GPS_Altitude_Cm := Interfaces.Integer_32 (Int (25));
            Inp.GPS_Sensor := Int (26) / 2 ** 5 mod 2 = 1;
            for A in 0 .. 2 loop
               Inp.Acc_ADC (A) := To_Float (Bits (27 + A));
            end loop;
            Inp.One_G := JT_One_G;
            Inp.Motor_Count := JT_Motors;
            for M in JTL.Motor_Index loop
               Inp.Rpm (M) := Natural (Int (30 + 2 * M));
               Inp.Data_Age (M) := Interfaces.Unsigned_8 (Int (31 + 2 * M));
            end loop;
            Inp.Erpm_To_Hz := JT_Erpm;
            for D in 0 .. 7 loop
               Inp.Debug (D) := Interfaces.Integer_16 (Int (46 + D));
            end loop;
            JTL.Handle (JT_State, JT_Rx, JT_Config, Inp, JT_Clock, Natural (Int (8)), O);
            Record_Int
              (Name & ".request_state", Int (54), Adaflight.Jeti_Ex_Bus.Frame_State_Kind'Pos (JT_Rx.Request_State));
            Record_Int (Name & ".can_tx", Int (55), Boolean'Pos (JT_Rx.Can_Tx));
            Record_Int (Name & ".enabled", Int_Hex (56), JT_Mask);
            declare
               Actual : Byte_Array (0 .. O.Length - 1);
            begin
               for K in Actual'Range loop
                  Actual (K) := Byte (O.Data (K + 1));
               end loop;
               Record_Int (Name & ".length", Int (57), Integer_64 (O.Length));
               Record_Bytes (Name & ".bytes", Hex_Bytes (58), Actual);
            end;
         end;
      end if;
   end Check_Jeti_Telemetry_Line;

   package FSP renames Adaflight.FrSky_SPI;
   package SPR renames Adaflight.SPI_Radio;
   use type SPR.Op_Kind;
   use type FSP.Received;
   FD_Seq    : Integer_64 := -1;
   FD_State  : FSP.State;
   FD_Config : FSP.Settings;
   FD_Rc     : FSP.Channel_Values := (others => 1_500);

   function FD_Hex (V : Natural; Width : Natural) return String is
      Digits_Of : constant String := "0123456789abcdef";
      R         : String (1 .. Width);
      X         : Natural := V;
   begin
      for K in reverse R'Range loop
         R (K) := Digits_Of (X mod 16 + 1);
         X := X / 16;
      end loop;
      return R;
   end FD_Hex;

   function FD_Short_Hex (V : Natural) return String is
      Img : constant String := FD_Hex (V, 8);
      K   : Positive := Img'First;
   begin
      while K < Img'Last and then Img (K) = '0' loop
         K := K + 1;
      end loop;
      return Img (K .. Img'Last);
   end FD_Short_Hex;

   function FD_Ops (O : FSP.Output) return String is
      Buffer : String (1 .. 8192);
      Len    : Natural := 0;

      procedure Put (T : String) is
      begin
         if Len > 0 then
            Len := Len + 1;
            Buffer (Len) := ':';
         end if;
         Buffer (Len + 1 .. Len + T'Length) := T;
         Len := Len + T'Length;
      end Put;

      function Pin_Letter (P : SPR.Pin) return Character is
        (case P is
            when SPR.LED => 'L', when SPR.Tx_Enable => 'T', when SPR.LNA_Enable => 'N',
            when SPR.Antenna_Select => 'A');
   begin
      for K in 1 .. O.Count loop
         declare
            X : constant SPR.Op := O.Ops (K);
         begin
            case X.Kind is
               when SPR.Reset => Put ("x");
               when SPR.Startup_Speed => Put ("h");
               when SPR.Normal_Speed => Put ("n");
               when SPR.Strobe => Put ("s" & FD_Hex (Natural (X.A), 2));
               when SPR.Write_Register => Put ("w" & FD_Hex (Natural (X.A), 2) & FD_Hex (Natural (X.B), 2));
               when SPR.Read_Fifo => Put ("r" & FD_Short_Hex (Natural (X.A)));
               when SPR.Write_Fifo =>
                  declare
                     T : String (1 .. 1 + 2 * Natural (X.A));
                  begin
                     T (1) := 'f';
                     for B in 0 .. Natural (X.A) - 1 loop
                        T (2 + 2 * B .. 3 + 2 * B) := FD_Hex (Natural (O.Tx_Data (B)), 2);
                     end loop;
                     Put (T);
                  end;
               when SPR.Set_Power => Put ("p" & FD_Short_Hex (Natural (X.A)));
               when SPR.Delay_Ms => Put ("d" & FD_Short_Hex (Natural (X.Value)));
               when SPR.Delay_Us => Put ("u" & FD_Short_Hex (Natural (X.Value)));
               when SPR.Calibrate => Put ("C");
               when SPR.Pin_High => Put (Pin_Letter (X.On) & "1");
               when SPR.Pin_Low => Put (Pin_Letter (X.On) & "0");
               when SPR.Pin_Toggle => Put (Pin_Letter (X.On) & "t");
               when SPR.Set_RSSI => Put ("R" & FD_Short_Hex (Natural (X.Value)) & ".3");
               when SPR.Set_RSSI_Direct => Put ("D" & FD_Short_Hex (Natural (X.Value)) & ".3");
               when SPR.Save_Config => Put ("E");
               when SPR.Write_Id =>
                  Put ("i" & FD_Hex (Natural (X.Word / 2 ** 16), 4) & FD_Hex (Natural (X.Word mod 2 ** 16), 4));
               when SPR.Read_Register => Put ("q" & FD_Hex (Natural (X.A), 2));
               when SPR.Await_Clear => Put ("a" & FD_Hex (Natural (X.A), 2));
               when SPR.Reset_Exti => Put ("X");
               when SPR.Write_Block =>
                  declare
                     T : String (1 .. 3 + 2 * Natural (X.B));
                  begin
                     T (1 .. 3) := "b" & FD_Hex (Natural (X.A), 2);
                     for B in 0 .. Natural (X.B) - 1 loop
                        T (4 + 2 * B .. 5 + 2 * B) := FD_Hex (Natural (O.Blocks (Natural (X.Value) + B)), 2);
                     end loop;
                     Put (T);
                  end;
               when SPR.Await_Value => Put ("a" & FD_Hex (Natural (X.A), 2));
            end case;
         end;
      end loop;
      return (if Len = 0 then "-" else Buffer (1 .. Len));
   end FD_Ops;

   procedure FD_Calibrate (O : FSP.Output) is
      Table : FSP.Calibration_Table := (others => (others => 0));
   begin
      for K in 1 .. O.Count loop
         if O.Ops (K).Kind = SPR.Calibrate then
            for Ch in 0 .. 254 loop
               Table (Ch) :=
                 (Interfaces.Unsigned_8 ((Ch * 37 + 5) mod 256), Interfaces.Unsigned_8 ((Ch * 59 + 16) mod 256),
                  Interfaces.Unsigned_8 ((Ch * 83 + 27) mod 256));
            end loop;
            FSP.Set_Calibration (FD_State, Table);
         end if;
      end loop;
   end FD_Calibrate;

   function FD_Hops return String is
      R : String (1 .. 100);
   begin
      for K in FSP.Hop_Table'Range loop
         R (1 + 2 * K .. 2 + 2 * K) := FD_Hex (Natural (FD_Config.Bind_Hop_Data (K)), 2);
      end loop;
      return R;
   end FD_Hops;

   function FD_Tx_Id return String is
     (FD_Hex (Natural (FD_Config.Bind_Tx_Id (0)), 2) & FD_Hex (Natural (FD_Config.Bind_Tx_Id (1)), 2)
      & FD_Hex (Natural (FD_Config.Bind_Tx_Id (2)), 2));

   procedure Check_FrSky_D_Line is
      Name : constant String := Str (1);
   begin
      if Name = "fdinit" then
         FD_Seq := Int (2);
         declare
            Ids  : constant Byte_Array := Hex_Bytes (15);
            Hops : constant Byte_Array := Hex_Bytes (16);
            Inp  : FSP.Inputs;
            O    : FSP.Output;
            Ok   : Boolean;
            Claim : Boolean;
         begin
            FD_Config :=
              (Auto_Bind     => Int (3) /= 0,
               Bind_Offset   => Interfaces.Integer_8 (Int (4)),
               A1            => FSP.A1_Source'Val (Int (5)),
               Pins          =>
                 (Chip_Detect   => Int (6) /= 0,
                  Tx_Enable     => Int (7) /= 0,
                  LNA           => Int (8) /= 0,
                  Antenna       => Int (9) /= 0,
                  LED           => Int (10) /= 0,
                  LED_Inversion => Int (11) /= 0,
                  Bind          => Int (12) /= 0),
               Rx_Num        => Interfaces.Unsigned_8 (Int (19)),
               others        => <>);
            for K in 0 .. 2 loop
               FD_Config.Bind_Tx_Id (K) := Interfaces.Unsigned_8 (Ids (Ids'First + K));
            end loop;
            for K in FSP.Hop_Table'Range loop
               FD_Config.Bind_Hop_Data (K) := Interfaces.Unsigned_8 (Hops (Hops'First + K));
            end loop;
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (13));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Bind_Pin_Level := True;
            FD_Config.Protocol :=
              (if NF < 36 then FSP.FrSky_D
               else (case Int (36) is
                        when 9 => FSP.FrSky_X, when 15 => FSP.FrSky_X_LBT, when 17 => FSP.FrSky_X_V2,
                        when 18 => FSP.FrSky_X_LBT_V2, when others => FSP.FrSky_D));
            FD_Config.Telemetry := Int (21) /= 0;
            declare
               use Adaflight.FrSky_Hub_Telemetry;
            begin
               for Se in Sensor loop
                  FD_Config.Hub.Enabled (Se) := (Int (22) / 2 ** Sensor'Pos (Se)) mod 2 = 0;
               end loop;
               FD_Config.Hub.Format := (if Int (23) = 0 then DMS else NMEA);
               FD_Config.Hub.Unit := (if Int (24) = 0 then Imperial else Metric);
               FD_Config.Hub.Precision := (if Int (25) = 0 then Low else High);
               FD_Config.Hub.Report_Cell_Voltage := Int (26) = 1;
               FD_Config.Hub.No_Fix_Latitude := No_Fix_Coordinate (Int (27));
               FD_Config.Hub.No_Fix_Longitude := No_Fix_Coordinate (Int (28));
               FD_Config.Hub.Acc_Present := Int (29) = 1;
               FD_Config.Hub.Altitude_Present := Int (30) = 1;
               FD_Config.Hub.GPS_Present := Int (31) = 1;
               FD_Config.Hub.Mag_Present := Int (32) = 1;
               FD_Config.Hub.Pole_Count := 14;
               FD_Config.Hub.Acc_1G_Rec := Flt (33);
            end;
            FSP.Start (FD_State, FD_Config, Inp, O, Ok, Claim);
            FD_Rc := (others => 1_500);
            Record_Int (Name & ".ok", Int (14), Boolean'Pos (Ok));
            Record_Int (Name & ".channels", Int (18), Integer_64 (FSP.Channel_Count (FD_Config)));
            Record_Int (Name & ".claim", 1, Boolean'Pos (Claim));
            Record_Text (Name & ".ops", Str (20), FD_Ops (O));
         end;
      elsif Int (2) /= FD_Seq then
         Put_Line ("FrSky D line without its start");
         Failures := Failures + 1;
      elsif Name = "fdstep" then
         declare
            Inp    : FSP.Inputs;
            O      : FSP.Output;
            Result : FSP.Received;
            Fifo   : constant Byte_Array := Hex_Bytes (8);
            Rc_Text : constant String := Str (26);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Exti := Int (4) /= 0;
            Inp.Rx_Bytes := Interfaces.Unsigned_8 (Int (5));
            Inp.Bind_Pin_Level := Int (6) /= 0;
            for K in Fifo'Range loop
               Inp.Fifo (K - Fifo'First) := Interfaces.Unsigned_8 (Fifo (K));
            end loop;
            Inp.ADC_External := Interfaces.Unsigned_16 (Int (9));
            Inp.ADC_RSSI := Interfaces.Unsigned_16 (Int (10));
            Inp.Battery_Voltage := Interfaces.Unsigned_16 (Int (11));
            Inp.Legacy_Voltage := Interfaces.Unsigned_16 ((Int (11) + 5) / 10);
            Inp.Hub.Acc_X := Flt (29);
            Inp.Hub.Acc_Y := Flt (30);
            Inp.Hub.Acc_Z := Flt (31);
            Inp.Hub.ESC_Valid := Int (32) = 1;
            Inp.Hub.ESC_Rpm := Interfaces.Integer_16 (Int (33));
            Inp.Hub.ESC_Temperature := Interfaces.Unsigned_8 (Int (34));
            Inp.Hub.Fix := Int (35) = 1;
            Inp.Hub.Lat := I32 (36);
            Inp.Hub.Lon := I32 (37);
            Inp.Hub.Alt_Cm := I32 (38);
            Inp.Hub.Ground_Speed := Interfaces.Unsigned_16 (Int (39));
            Inp.Hub.Num_Sat := Interfaces.Unsigned_8 (Int (40));
            Inp.Hub.Pdop := Interfaces.Unsigned_16 (Int (41));
            Inp.Hub.Voltage_Configured := Int (42) = 1;
            Inp.Hub.Amperage_Configured := Int (43) = 1;
            Inp.Hub.Cell_Count := Interfaces.Unsigned_8 (Int (44));
            Inp.Hub.Voltage_Cv := Interfaces.Unsigned_16 (Int (45));
            Inp.Hub.Amperage_Ca := I32 (46);
            Inp.Hub.Capacity := Interfaces.Unsigned_16 (Int (47));
            Inp.Hub.Percent := Interfaces.Unsigned_8 (Int (48));
            Inp.Hub.Mah_Drawn := I32 (49);
            Inp.Hub.Vario_Cms := Interfaces.Integer_16 (Int (50));
            Inp.Hub.Altitude_Cm := I32 (51);
            Inp.Hub.Yaw := Interfaces.Integer_16 (Int (52));
            if Int (7) /= 0 then
               FSP.Request_Bind (FD_State);
            end if;
            FSP.Data_Received (FD_State, FD_Config, Inp, O, Result);
            if Result = FSP.Data_Ready then
               FSP.Set_Rc_Data (FD_State, FD_Config, FD_Rc);
            end if;
            FD_Calibrate (O);
            Record_Int (Name & ".result", Int (12), (case Result is when FSP.None => 0, when FSP.Bind_Done => 1,
                                                                    when FSP.Data_Ready => 2));
            Record_Int (Name & ".state", Int (13), FSP.Protocol_State'Pos (FD_State.Protocol));
            Record_Int (Name & ".missing", Int (14), Integer_64 (FD_State.Missing_Packets));
            Record_Int (Name & ".timeout", Int (15), Integer_64 (FD_State.Timeout_Us));
            Record_Int (Name & ".offset", Int (16), Integer_64 (FD_State.Bind_Offset));
            Record_Int (Name & ".offset_min", Int (17), Integer_64 (FD_State.Bind_Offset_Min));
            Record_Int (Name & ".offset_max", Int (18), Integer_64 (FD_State.Bind_Offset_Max));
            Record_Int (Name & ".bind_state", Int (19), Integer_64 (FD_State.Bind_State));
            Record_Int (Name & ".list_length", Int (20), Integer_64 (FD_State.List_Length));
            Record_Int (Name & ".bind_requested", Int (21), Boolean'Pos (FD_State.Radio.Bind_Requested));
            Record_Text (Name & ".tx_id", Str (22), FD_Tx_Id);
            Record_Text (Name & ".hops", Str (23), FD_Hops);
            Record_Int (Name & ".config_offset", Int (24), Integer_64 (FD_Config.Bind_Offset));
            Record_Int (Name & ".rx_num", Int (25), Integer_64 (FD_Config.Rx_Num));
            declare
               Image : String (1 .. 128);
               Len   : Natural := 0;
            begin
               for K in 0 .. FSP.Channel_Count (FD_Config) - 1 loop
                  declare
                     T : constant String := Interfaces.Unsigned_16'Image (FD_Rc (K));
                  begin
                     if K > 0 then
                        Len := Len + 1;
                        Image (Len) := '.';
                     end if;
                     Image (Len + 1 .. Len + T'Length - 1) := T (T'First + 1 .. T'Last);
                     Len := Len + T'Length - 1;
                  end;
               end loop;
               Record_Text (Name & ".rc", Rc_Text, Image (1 .. Len));
            end;
            Record_Int (Name & ".rssi_dbm", Int (27), Integer_64 (FD_State.Radio.RSSI_Dbm));
            Record_Text (Name & ".ops", Str (28), FD_Ops (O));
            Record_Int (Name & ".hub_generated", Int (53), Integer_64 (FD_State.Hub_Generated));
         end;
      end if;
   end Check_FrSky_D_Line;

   package SFH renames Adaflight.SFHSS;
   use type SFH.Received;
   SF_Seq    : Integer_64 := -1;
   SF_State  : SFH.State;
   SF_Config : SFH.Settings;
   SF_Rc     : SFH.Channel_Values := (others => 1_500);

   procedure SF_Calibrate (O : SFH.Output) is
      Table : SFH.Calibration_Table := (others => (others => 0));
   begin
      for K in 1 .. O.Count loop
         if O.Ops (K).Kind = SPR.Calibrate then
            for C in SFH.Calibration_Table'Range loop
               declare
                  Ch : constant Natural := C * 6 + 16;
               begin
                  Table (C) :=
                    (Interfaces.Unsigned_8 ((Ch * 37 + 5) mod 256), Interfaces.Unsigned_8 ((Ch * 59 + 16) mod 256),
                     Interfaces.Unsigned_8 ((Ch * 83 + 27) mod 256));
               end;
            end loop;
            SFH.Set_Calibration (SF_State, Table);
         end if;
      end loop;
   end SF_Calibrate;

   procedure Check_SFHSS_Line is
      Name : constant String := Str (1);

      function State_Code (P : SFH.Protocol_State) return Integer_64 is
        (case P is
            when SFH.Init => 0, when SFH.Hunt => 1, when SFH.Sync => 2, when SFH.Bind => 10,
            when SFH.Bind_Tuning_1 => 11, when SFH.Bind_Tuning_2 => 12, when SFH.Bind_Tuning_3 => 13,
            when SFH.Bind_Complete => 14);

      function Tx_Id_Text return String is
        (FD_Hex (Natural (SF_Config.Bind_Tx_Id (0)), 2) & FD_Hex (Natural (SF_Config.Bind_Tx_Id (1)), 2));

      function Rc_Text return String is
         Image : String (1 .. 64);
         Len   : Natural := 0;
      begin
         for K in SF_Rc'Range loop
            declare
               T : constant String := Interfaces.Unsigned_16'Image (SF_Rc (K));
            begin
               if K > 0 then
                  Len := Len + 1;
                  Image (Len) := '.';
               end if;
               Image (Len + 1 .. Len + T'Length - 1) := T (T'First + 1 .. T'Last);
               Len := Len + T'Length - 1;
            end;
         end loop;
         return Image (1 .. Len);
      end Rc_Text;
   begin
      if Name = "sfinit" then
         SF_Seq := Int (2);
         declare
            Ids    : constant Byte_Array := Hex_Bytes (13);
            Before : constant Integer_64 := Int (18);
            Inp    : SFH.Inputs;
            O      : SFH.Output;
            Ok     : Boolean;
            Claim  : Boolean;
         begin
            SF_Config :=
              (Bind_Tx_Id  => (Interfaces.Unsigned_8 (Ids (Ids'First)), Interfaces.Unsigned_8 (Ids (Ids'First + 1))),
               Bind_Offset => Interfaces.Integer_8 (Int (14)),
               Pins        =>
                 (Chip_Detect   => Int (3) /= 0,
                  Tx_Enable     => Int (5) /= 0,
                  LNA           => Int (6) /= 0,
                  Antenna       => Int (7) /= 0,
                  LED           => Int (8) /= 0,
                  LED_Inversion => Int (9) /= 0,
                  Bind          => Int (10) /= 0));
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (11));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Bind_Pin_Level := True;
            Inp.Chip_Ok := Int (4) /= 0;
            SFH.Start (SF_State, SF_Config, Inp, O, Ok, Claim);
            SF_Rc := (others => 1_500);
            Record_Int (Name & ".ok", Int (12), Boolean'Pos (Ok));
            Record_Int (Name & ".rssi_source", Int (15), (if Before = 0 and then Claim then 3 else Before));
            Record_Int (Name & ".channels", Int (16), SFH.Channel_Count);
            Record_Text (Name & ".ops", Str (17), FD_Ops (O));
         end;
      elsif Int (2) /= SF_Seq then
         Put_Line ("S-FHSS line without its start");
         Failures := Failures + 1;
      elsif Name = "sfstep" then
         declare
            Inp    : SFH.Inputs;
            O      : SFH.Output;
            Result : SFH.Received;
            Fifo   : constant Byte_Array := Hex_Bytes (8);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Exti := Int (4) /= 0;
            Inp.Rx_Bytes := Interfaces.Unsigned_8 (Int (5));
            Inp.Bind_Pin_Level := Int (6) /= 0;
            for K in Fifo'Range loop
               Inp.Fifo (K - Fifo'First) := Interfaces.Unsigned_8 (Fifo (K));
            end loop;
            if Int (7) /= 0 then
               SFH.Request_Bind (SF_State);
            end if;
            SFH.Data_Received (SF_State, SF_Config, Inp, O, Result);
            if Result = SFH.Data_Ready then
               SFH.Set_Rc_Data (SF_State, SF_Rc);
            end if;
            SF_Calibrate (O);
            Record_Int (Name & ".result", Int (9), (case Result is when SFH.None => 0, when SFH.Bind_Done => 1,
                                                                    when SFH.Data_Ready => 2));
            Record_Int (Name & ".state", Int (10), State_Code (SF_State.Protocol));
            Record_Int (Name & ".missing", Int (11), Integer_64 (SF_State.Missing_Packets));
            Record_Int (Name & ".channel", Int (12), Integer_64 (SF_State.Channel));
            Record_Int (Name & ".code", Int (13), Integer_64 (SF_State.Code));
            Record_Int (Name & ".offset_min", Int (14), Integer_64 (SF_State.Offset_Min));
            Record_Int (Name & ".offset_max", Int (15), Integer_64 (SF_State.Offset_Max));
            Record_Int (Name & ".tuned_ms", Int (16), Integer_64 (SF_State.Time_Tuned_Ms));
            Record_Text (Name & ".tx_id", Str (17), Tx_Id_Text);
            Record_Int (Name & ".config_offset", Int (18), Integer_64 (SF_Config.Bind_Offset));
            Record_Text (Name & ".rc", Str (19), Rc_Text);
            Record_Int (Name & ".rssi_dbm", Int (20), Integer_64 (SF_State.Radio.RSSI_Dbm));
            Record_Int (Name & ".bind_requested", Int (21), Boolean'Pos (SF_State.Radio.Bind_Requested));
            Record_Text (Name & ".ops", Str (22), FD_Ops (O));
         end;
      end if;
   end Check_SFHSS_Line;

   package RPN renames Adaflight.Redpine;
   use type RPN.Received;
   RP_Seq     : Integer_64 := -1;
   RP_State   : RPN.State;
   RP_Config  : RPN.Settings;
   RP_Rc      : RPN.Channel_Values := (others => 1_500);
   RP_Band    : Integer_64 := 1;
   RP_Channel : Integer_64 := 1;
   RP_Power   : Integer_64 := 0;
   RP_Saves   : Integer_64 := 0;

   procedure RP_Calibrate (O : RPN.Output) is
      Table : RPN.Calibration_Table := (others => (others => 0));
   begin
      for K in 1 .. O.Count loop
         if O.Ops (K).Kind = SPR.Calibrate then
            for Ch in RPN.Calibration_Table'Range loop
               Table (Ch) :=
                 (Interfaces.Unsigned_8 ((Ch * 37 + 5) mod 256), Interfaces.Unsigned_8 ((Ch * 59 + 16) mod 256),
                  Interfaces.Unsigned_8 ((Ch * 83 + 27) mod 256));
            end loop;
            RPN.Set_Calibration (RP_State, Table);
         end if;
      end loop;
   end RP_Calibrate;

   procedure Check_Redpine_Line is
      Name : constant String := Str (1);

      function Hops_Text return String is
         R : String (1 .. 100);
      begin
         for K in RPN.Hop_Table'Range loop
            R (1 + 2 * K .. 2 + 2 * K) := FD_Hex (Natural (RP_Config.Bind_Hop_Data (K)), 2);
         end loop;
         return R;
      end Hops_Text;

      function Tx_Id_Text return String is
        (FD_Hex (Natural (RP_Config.Bind_Tx_Id (0)), 2) & FD_Hex (Natural (RP_Config.Bind_Tx_Id (1)), 2));

      function Rc_Text return String is
         Image : String (1 .. 128);
         Len   : Natural := 0;
      begin
         for K in RP_Rc'Range loop
            declare
               T : constant String := Interfaces.Unsigned_16'Image (RP_Rc (K));
            begin
               if K > 0 then
                  Len := Len + 1;
                  Image (Len) := '.';
               end if;
               Image (Len + 1 .. Len + T'Length - 1) := T (T'First + 1 .. T'Last);
               Len := Len + T'Length - 1;
            end;
         end loop;
         return Image (1 .. Len);
      end Rc_Text;
   begin
      if Name = "rpinit" then
         RP_Seq := Int (2);
         declare
            Ids    : constant Byte_Array := Hex_Bytes (14);
            Hops   : constant Byte_Array := Hex_Bytes (16);
            Before : constant Integer_64 := Int (20);
            Inp    : RPN.Inputs;
            O      : RPN.Output;
            Ok     : Boolean;
            Claim  : Boolean;
         begin
            RP_Config :=
              (Auto_Bind     => Int (3) /= 0,
               Bind_Tx_Id    => (Interfaces.Unsigned_8 (Ids (Ids'First)), Interfaces.Unsigned_8 (Ids (Ids'First + 1))),
               Bind_Offset   => Interfaces.Integer_8 (Int (15)),
               Bind_Hop_Data => (others => 0),
               Pins          =>
                 (Chip_Detect   => Int (4) /= 0,
                  Tx_Enable     => Int (6) /= 0,
                  LNA           => Int (7) /= 0,
                  Antenna       => Int (8) /= 0,
                  LED           => Int (9) /= 0,
                  LED_Inversion => Int (10) /= 0,
                  Bind          => Int (11) /= 0));
            for K in RPN.Hop_Table'Range loop
               RP_Config.Bind_Hop_Data (K) := Interfaces.Unsigned_8 (Hops (Hops'First + K));
            end loop;
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (12));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Bind_Pin_Level := True;
            Inp.Chip_Ok := Int (5) /= 0;
            RPN.Start (RP_State, RP_Config, Inp, O, Ok, Claim);
            RP_Rc := (others => 1_500);
            RP_Band := 1;
            RP_Channel := 1;
            RP_Power := 0;
            RP_Saves := 0;
            Record_Int (Name & ".ok", Int (13), Boolean'Pos (Ok));
            Record_Int (Name & ".rssi_source", Int (17), (if Before = 0 and then Claim then 3 else Before));
            Record_Int (Name & ".channels", Int (18), (if Ok then RPN.Channel_Count else 0));
            Record_Text (Name & ".ops", Str (19), FD_Ops (O));
         end;
      elsif Int (2) /= RP_Seq then
         Put_Line ("Redpine line without its start");
         Failures := Failures + 1;
      elsif Name = "rpstep" then
         declare
            Inp    : RPN.Inputs;
            O      : RPN.Output;
            Result : RPN.Received;
            VTX    : RPN.VTX_Request;
            Fifo   : constant Byte_Array := Hex_Bytes (9);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Exti := Int (4) /= 0;
            Inp.Rx_Bytes := Interfaces.Unsigned_8 (Int (5));
            Inp.Bind_Pin_Level := Int (6) /= 0;
            for K in Fifo'Range loop
               Inp.Fifo (K - Fifo'First) := Interfaces.Unsigned_8 (Fifo (K));
            end loop;
            if Int (7) /= 0 then
               RPN.Request_Bind (RP_State);
            end if;
            RPN.Data_Received (RP_State, RP_Config, Inp, O, Result);
            if Result = RPN.Data_Ready then
               RPN.Set_Rc_Data (RP_State, Int (8) /= 0, RP_Rc, VTX);
               if VTX.Present then
                  RP_Band := Integer_64 (VTX.Band);
                  RP_Channel := Integer_64 (VTX.Channel);
                  RP_Power := Integer_64 (VTX.Power);
                  RP_Saves := RP_Saves + 1;
               end if;
            end if;
            RP_Calibrate (O);
            Record_Int (Name & ".result", Int (10), (case Result is when RPN.None => 0, when RPN.Bind_Done => 1,
                                                                     when RPN.Data_Ready => 2));
            Record_Int (Name & ".state", Int (11), RPN.Protocol_State'Pos (RP_State.Protocol));
            Record_Int (Name & ".missing", Int (12), Integer_64 (RP_State.Missing_Packets));
            Record_Int (Name & ".offset_min", Int (13), Integer_64 (RP_State.Offset_Min));
            Record_Int (Name & ".offset_max", Int (14), Integer_64 (RP_State.Offset_Max));
            Record_Int (Name & ".tuned_ms", Int (15), Integer_64 (RP_State.Time_Tuned_Ms));
            Record_Int (Name & ".fast", Int (16), Boolean'Pos (RP_State.Fast));
            Record_Text (Name & ".tx_id", Str (17), Tx_Id_Text);
            Record_Int (Name & ".config_offset", Int (18), Integer_64 (RP_Config.Bind_Offset));
            Record_Text (Name & ".hops", Str (19), Hops_Text);
            Record_Text (Name & ".rc", Str (20), Rc_Text);
            Record_Int (Name & ".rssi_dbm", Int (21), Integer_64 (RP_State.Radio.RSSI_Dbm));
            Record_Int (Name & ".bind_requested", Int (22), Boolean'Pos (RP_State.Radio.Bind_Requested));
            Record_Int (Name & ".vtx_band", Int (23), RP_Band);
            Record_Int (Name & ".vtx_channel", Int (24), RP_Channel);
            Record_Int (Name & ".vtx_power", Int (25), RP_Power);
            Record_Int (Name & ".saves", Int (26), RP_Saves);
            Record_Text (Name & ".ops", Str (27), FD_Ops (O));
         end;
      end if;
   end Check_Redpine_Line;

   package FSK renames Adaflight.FlySky;
   use type FSK.Received;
   FY_Seq    : Integer_64 := -1;
   FY_State  : FSK.State;
   FY_Config : FSK.Settings;
   FY_Rc     : FSK.Channel_Values := (others => 1_500);

   function Hex_Word (I : Positive) return Interfaces.Unsigned_32 is
      B : constant Byte_Array := Hex_Bytes (I);
      W : Interfaces.Unsigned_32 := 0;
   begin
      for K in B'Range loop
         W := W * 256 + Interfaces.Unsigned_32 (B (K));
      end loop;
      return W;
   end Hex_Word;

   function Word_Text (W : Interfaces.Unsigned_32) return String is
     (FD_Hex (Natural (W / 2 ** 16), 4) & FD_Hex (Natural (W mod 2 ** 16), 4));

   function Map_Text (M : FSK.Channel_Map) return String is
      R : String (1 .. 32);
   begin
      for K in M'Range loop
         R (1 + 2 * K .. 2 + 2 * K) := FD_Hex (Natural (M (K)), 2);
      end loop;
      return R;
   end Map_Text;

   procedure Check_FlySky_Line is
      Name : constant String := Str (1);

      function Rc_Text return String is
         Image : String (1 .. 128);
         Len   : Natural := 0;
      begin
         for K in 0 .. FSK.Channel_Count (FY_Config) - 1 loop
            declare
               T : constant String := Interfaces.Unsigned_16'Image (FY_Rc (K));
            begin
               if K > 0 then
                  Len := Len + 1;
                  Image (Len) := '.';
               end if;
               Image (Len + 1 .. Len + T'Length - 1) := T (T'First + 1 .. T'Last);
               Len := Len + T'Length - 1;
            end;
         end loop;
         return Image (1 .. Len);
      end Rc_Text;
   begin
      if Name = "fyinit" then
         FY_Seq := Int (2);
         declare
            Map    : constant Byte_Array := Hex_Bytes (10);
            Before : constant Integer_64 := Int (15);
            Inp    : FSK.Inputs;
            O      : FSK.Output;
            Ok     : Boolean;
            Claim  : Boolean;
         begin
            FY_Config :=
              (Protocol    => (if Int (3) /= 0 then FSK.AFHDS_2A else FSK.AFHDS),
               Tx_Id       => Hex_Word (9),
               Rf_Map      => (others => 0),
               Receiver_Id => Hex_Word (11),
               Pins        =>
                 (LED => Int (4) /= 0, LED_Inversion => Int (5) /= 0, Bind => Int (6) /= 0, others => <>));
            for K in FSK.Channel_Map'Range loop
               FY_Config.Rf_Map (K) := Interfaces.Unsigned_8 (Map (Map'First + K));
            end loop;
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (7));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Bind_Pin_Level := True;
            FSK.Start (FY_State, FY_Config, Inp, O, Ok, Claim);
            FY_Rc := (others => 1_500);
            Record_Int (Name & ".ok", Int (8), Boolean'Pos (Ok));
            Record_Int (Name & ".rssi_source", Int (12), (if Before = 0 and then Claim then 3 else Before));
            Record_Int (Name & ".channels", Int (13), Integer_64 (FSK.Channel_Count (FY_Config)));
            Record_Text (Name & ".ops", Str (14), FD_Ops (O));
         end;
      elsif Int (2) /= FY_Seq then
         Put_Line ("FlySky line without its start");
         Failures := Failures + 1;
      elsif Name = "fystep" then
         declare
            Inp    : FSK.Inputs;
            O      : FSK.Output;
            Result : FSK.Received;
            Fifo   : constant Byte_Array := Hex_Bytes (11);
            Mode   : constant Byte_Array := Hex_Bytes (6);
            Level  : constant Byte_Array := Hex_Bytes (7);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Exti_Flag := Int (4) /= 0;
            Inp.Exti_Time_Us := Interfaces.Unsigned_32 (Int (5));
            Inp.Mode_Register := Interfaces.Unsigned_8 (Mode (Mode'First));
            Inp.RSSI_Register := Interfaces.Unsigned_8 (Level (Level'First));
            Inp.Bind_Pin_Level := Int (8) /= 0;
            Inp.Battery_Voltage := Interfaces.Unsigned_16 (Int (10));
            for K in Fifo'Range loop
               Inp.Fifo (K - Fifo'First) := Interfaces.Unsigned_8 (Fifo (K));
            end loop;
            if Int (9) /= 0 then
               FSK.Request_Bind (FY_State);
            end if;
            FSK.Data_Received (FY_State, FY_Config, Inp, O, Result);
            if Result = FSK.Data_Ready then
               FSK.Set_Rc_Data (FY_State, FY_Config, FY_Rc);
            end if;
            Record_Int (Name & ".result", Int (12), (case Result is when FSK.None => 0, when FSK.Bind_Done => 1,
                                                                     when FSK.Data_Ready => 2));
            Record_Int (Name & ".bound", Int (13), Boolean'Pos (FY_State.Bound));
            Record_Text (Name & ".tx_id", Str (14), Word_Text (FY_State.Tx_Id));
            Record_Int (Name & ".timeout", Int (15), Integer_64 (FY_State.Timeout_Us));
            Record_Int (Name & ".last_packet", Int (16), Integer_64 (FY_State.Last_Packet_Us));
            Record_Int (Name & ".count_timeout", Int (17), Integer_64 (FY_State.Count_Timeout));
            Record_Int (Name & ".count_packet", Int (18), Integer_64 (FY_State.Count_Packet));
            Record_Int (Name & ".error_rate", Int (19), Integer_64 (FY_State.Error_Rate));
            Record_Int (Name & ".rssi_dbm", Int (20), Integer_64 (FY_State.RSSI_Dbm));
            Record_Int (Name & ".send_telemetry", Int (21), Boolean'Pos (FY_State.Send_Telemetry));
            Record_Int (Name & ".wait_tx", Int (22), Boolean'Pos (FY_State.Wait_Tx));
            Record_Text (Name & ".map", Str (23), Map_Text (FY_State.Rf_Map));
            Record_Text (Name & ".config_tx_id", Str (24), Word_Text (FY_Config.Tx_Id));
            Record_Text (Name & ".config_map", Str (25), Map_Text (FY_Config.Rf_Map));
            Record_Text (Name & ".rc", Str (26), Rc_Text);
            Record_Int (Name & ".consume_exti", Int (27), Boolean'Pos (FY_State.Consume_Exti));
            Record_Int (Name & ".bind_requested", Int (28), Boolean'Pos (FY_State.Radio.Bind_Requested));
            Record_Text (Name & ".ops", Str (29), FD_Ops (O));
         end;
      end if;
   end Check_FlySky_Line;

   package SPK renames Adaflight.Spektrum_SPI;
   use type SPK.Received;
   SK_Seq    : Integer_64 := -1;
   SK_State  : SPK.State;
   SK_Config : SPK.Settings;
   SK_Rc     : SPK.Channel_Values := (others => 1_500);

   function SK_Mfg_Text (M : SPK.Manufacturer_Id) return String is
     (FD_Hex (Natural (M (0)), 2) & FD_Hex (Natural (M (1)), 2) & FD_Hex (Natural (M (2)), 2)
      & FD_Hex (Natural (M (3)), 2));

   procedure Check_Spektrum_Line is
      Name : constant String := Str (1);

      function Channels_Text return String is
         R : String (1 .. 46);
      begin
         for K in SPK.Channel_List'Range loop
            R (1 + 2 * K .. 2 + 2 * K) := FD_Hex (Natural (SK_State.Rf_Channels (K)), 2);
         end loop;
         return R;
      end Channels_Text;

      function Rc_Text return String is
         Image : String (1 .. 128);
         Len   : Natural := 0;
      begin
         for K in 0 .. SPK.Channel_Count - 1 loop
            declare
               T : constant String := Interfaces.Unsigned_16'Image (SK_Rc (K));
            begin
               if K > 0 then
                  Len := Len + 1;
                  Image (Len) := '.';
               end if;
               Image (Len + 1 .. Len + T'Length - 1) := T (T'First + 1 .. T'Last);
               Len := Len + T'Length - 1;
            end;
         end loop;
         return Image (1 .. Len);
      end Rc_Text;

      function Byte_At (I : Positive) return Interfaces.Unsigned_8 is
         B : constant Byte_Array := Hex_Bytes (I);
      begin
         return Interfaces.Unsigned_8 (B (B'First));
      end Byte_At;
   begin
      if Name = "spinit" then
         SK_Seq := Int (2);
         declare
            Mfg    : constant Byte_Array := Hex_Bytes (10);
            Before : constant Integer_64 := Int (15);
            Inp    : SPK.Inputs;
            O      : SPK.Output;
            Ok     : Boolean;
            Claim  : Boolean;
         begin
            SK_Config :=
              (Protocol     => Byte_At (9),
               Mfg_Id       => (others => 0),
               Num_Channels => Interfaces.Unsigned_8 (Int (11)),
               Telemetry    => Int (16) /= 0,
               Pins         =>
                 (LED => Int (4) /= 0, LED_Inversion => Int (5) /= 0, Bind => Int (6) /= 0, others => <>));
            for K in SPK.Manufacturer_Id'Range loop
               SK_Config.Mfg_Id (K) := Interfaces.Unsigned_8 (Mfg (Mfg'First + K));
            end loop;
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (7));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Bind_Pin_Level := True;
            Inp.Chip_Ok := Int (3) /= 0;
            SPK.Start (SK_State, SK_Config, Inp, O, Ok, Claim);
            SK_Rc := (others => 1_500);
            Record_Int (Name & ".ok", Int (8), Boolean'Pos (Ok));
            Record_Int (Name & ".rssi_source", Int (12), (if Before = 0 and then Claim then 3 else Before));
            Record_Int (Name & ".channels", Int (13), SPK.Channel_Count);
            Record_Text (Name & ".ops", Str (14), FD_Ops (O));
         end;
      elsif Int (2) /= SK_Seq then
         Put_Line ("Spektrum line without its start");
         Failures := Failures + 1;
      elsif Name = "spstep" then
         declare
            Inp    : SPK.Inputs;
            O      : SPK.Output;
            Result : SPK.Received;
            Fifo   : constant Byte_Array := Hex_Bytes (14);
         begin
            Inp.Now_Us := Interfaces.Unsigned_32 (Int (3));
            Inp.Now_Ms := Inp.Now_Us / 1_000;
            Inp.Exti_Flag := Int (4) /= 0;
            Inp.Exti_Time_Us := Interfaces.Unsigned_32 (Int (5));
            Inp.IRQ_Status := Byte_At (6);
            Inp.Rx_Count := Byte_At (7);
            Inp.Rx_Status := Byte_At (8);
            Inp.RSSI_Register := Byte_At (9);
            Inp.Bind_Pin_Level := Int (10) /= 0;
            Inp.Battery_Voltage := Interfaces.Unsigned_16 (Int (12));
            Inp.RSSI_Percent := Interfaces.Unsigned_8 (Int (13));
            for K in Fifo'Range loop
               Inp.Fifo (K - Fifo'First) := Interfaces.Unsigned_8 (Fifo (K));
            end loop;
            if Int (11) /= 0 then
               SPK.Request_Bind (SK_State);
            end if;
            SPK.Data_Received (SK_State, SK_Config, Inp, O, Result);
            if Result = SPK.Data_Ready then
               SPK.Set_Rc_Data (SK_State, SK_Rc);
            end if;
            Record_Int (Name & ".result", Int (15), (case Result is when SPK.None => 0, when SPK.Bind_Done => 1,
                                                                     when SPK.Data_Ready => 2));
            Record_Int (Name & ".status", Int (16), SPK.Receiver_Status'Pos (SK_State.Status));
            Record_Int (Name & ".bound", Int (17), Boolean'Pos (SK_State.Bound));
            Record_Int (Name & ".protocol", Integer_64 (Byte_At (18)), Integer_64 (SK_State.Protocol));
            Record_Text (Name & ".mfg", Str (19), SK_Mfg_Text (SK_State.Mfg_Id));
            Record_Int (Name & ".channel", Int (20), Integer_64 (SK_State.Rf_Channel));
            Record_Int (Name & ".channel_idx", Int (21), Integer_64 (SK_State.Rf_Channel_Idx));
            Record_Int (Name & ".sop_col", Int (22), Integer_64 (SK_State.Sop_Col));
            Record_Int (Name & ".data_col", Int (23), Integer_64 (SK_State.Data_Col));
            Record_Text (Name & ".crc_seed", Str (24), FD_Hex (Natural (SK_State.Crc_Seed), 4));
            Record_Int (Name & ".missed", Int (25), Integer_64 (SK_State.Missed_Packets));
            Record_Int (Name & ".num_channels", Int (26), Integer_64 (SK_State.Num_Channels));
            Record_Int (Name & ".timeout", Int (27), Integer_64 (SK_State.Timeout_Us));
            Record_Int (Name & ".last_packet", Int (28), Integer_64 (SK_State.Last_Packet_Us));
            Record_Int (Name & ".bind_packets", Int (29), Integer_64 (SK_State.Bind_Packets));
            Record_Int (Name & ".last_telemetry", Int (30), Integer_64 (SK_State.Last_Telemetry_Us));
            Record_Int (Name & ".send_telemetry", Int (31), Boolean'Pos (SK_State.Send_Telemetry));
            Record_Int (Name & ".is_error", Int (32), Boolean'Pos (SK_State.Is_Error));
            Record_Text (Name & ".channels", Str (33), Channels_Text);
            Record_Int (Name & ".config_protocol", Integer_64 (Byte_At (34)), Integer_64 (SK_Config.Protocol));
            Record_Text (Name & ".config_mfg", Str (35), SK_Mfg_Text (SK_Config.Mfg_Id));
            Record_Int (Name & ".config_channels", Int (36), Integer_64 (SK_Config.Num_Channels));
            Record_Text (Name & ".rc", Str (37), Rc_Text);
            Record_Int (Name & ".bind_requested", Int (38), Boolean'Pos (SK_State.Radio.Bind_Requested));
            Record_Text (Name & ".ops", Str (39), FD_Ops (O));
         end;
      end if;
   end Check_Spektrum_Line;

   RS_Seq   : Integer_64 := -1;
   RS_Stats : Adaflight.RC_Stats.Stats;
   RS_Armed : Boolean := False;

   procedure Check_RC_Stats_Line is
      Name : constant String := Str (1);
   begin
      if Name = "rcsinit" then
         RS_Seq := Int (2);
         RS_Stats := (others => <>);
         RS_Armed := False;
      elsif Int (2) /= RS_Seq then
         Put_Line ("RC statistics line without its start");
         Failures := Failures + 1;
      elsif Name = "rcsstep" then
         declare
            Armed : constant Boolean := Int (4) /= 0;
         begin
            if Armed and then not RS_Armed then
               Adaflight.RC_Stats.Notify_Arming (RS_Stats);
            end if;
            RS_Armed := Armed;
            Adaflight.RC_Stats.Update (RS_Stats, Interfaces.Unsigned_32 (Int (3)), Armed, Int (5) /= 0,
                                       Adaflight.RC_Stats.Throttle_Percent (Int (6)));
            Record_Int (Name & ".raised", Int (7), Boolean'Pos (RS_Stats.Throttle_Raised));
            Record_Int (Name & ".count", Int (8), Integer_64 (RS_Stats.Count));
            Record_Int (Name & ".total", Int (9), Integer_64 (RS_Stats.Total));
            Record_Int (Name & ".full_us", Int (10), Integer_64 (RS_Stats.Full_Throttle_Us));
            Record_Int (Name & ".full_count", Int (11), Integer_64 (RS_Stats.Full_Throttles));
            Record_Int (Name & ".previous", Int (12), Integer_64 (RS_Stats.Previous_Percent));
            Record_Int (Name & ".previous_us", Int (13), Integer_64 (RS_Stats.Previous_Us));
            if Str (14) /= "-" then
               Record_Int (Name & ".average", Int (14), Integer_64 (Adaflight.RC_Stats.Average_Throttle (RS_Stats)));
            end if;
         end;
      end if;
   end Check_RC_Stats_Line;

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
               elsif Kind = "mavlink" then
                  Check_MAVLink_Line;
               elsif Kind = "mspserial" then
                  Check_MSP_Serial_Line;
               elsif Kind = "elrs" then
                  Check_ELRS_Line;
               elsif Kind = "elrstlm" then
                  Check_Telemetry_Line;
               elsif Kind = "bbenc" then
                  Check_Blackbox_Line;
               elsif Kind = "text" then
                  Check_Text_Line;
               elsif Kind = "dshot" then
                  Check_DShot_Line;
               elsif Kind = "crsftlm" then
                  Check_CRSF_Telemetry_Line;
               elsif Kind = "escsensor" then
                  Check_ESC_Line;
               elsif Kind = "sport" then
                  Check_SmartPort_Line;
               elsif Kind = "rcdevice" then
                  Check_RunCam_Line;
               elsif Kind = "frskyhub" then
                  Check_FrSky_Hub_Line;
               elsif Kind = "ibustlm" then
                  Check_IBus_Telemetry_Line;
               elsif Kind = "hott" then
                  Check_HoTT_Line;
               elsif Kind = "ghsttlm" then
                  Check_GHST_Telemetry_Line;
               elsif Kind = "transponder" then
                  Check_Transponder_Line;
               elsif Kind = "srxltlm" then
                  Check_SRXL_Telemetry_Line;
               elsif Kind = "frskyosd" then
                  Check_FrSky_OSD_Line;
               elsif Kind = "ledstrip" then
                  Check_LED_Strip_Line;
               elsif Kind = "rangefinder" then
                  Check_Rangefinder_Line;
               elsif Kind = "opticalflow" then
                  Check_Optical_Flow_Line;
               elsif Kind = "pitot" then
                  Check_Pitot_Line;
               elsif Kind = "rtc" then
                  Check_RTC_Line;
               elsif Kind = "adcint" then
                  Check_Internal_ADC_Line;
               elsif Kind = "stats" then
                  Check_Flight_Stats_Line;
               elsif Kind = "wlaunch" then
                  Check_Wing_Launch_Line;
               elsif Kind = "trail" then
                  Check_Nav_Trail_Line;
               elsif Kind = "gps" then
                  Check_GPS_Line;
               elsif Kind = "ubxcfg" then
                  Check_UBX_Config_Line;
               elsif Kind = "gpslink" then
                  Check_GPS_Link_Line;
               elsif Kind = "posest" then
                  Check_Posest_Line;
               elsif Kind = "poshold" then
                  Check_Poshold_Line;
               elsif Kind = "rescue" then
                  Check_Rescue_Line;
               elsif Kind = "vtxsa" then
                  Check_SmartAudio_Line;
               elsif Kind = "vtxctl" then
                  Check_VTX_Control_Line;
               elsif Kind = "vtxtramp" then
                  Check_Tramp_Line;
               elsif Kind = "ltm" then
                  Check_LTM_Line;
               elsif Kind = "laptimer" then
                  Check_Lap_Timer_Line;
               elsif Kind = "mspbox" then
                  Check_MSP_Box_Line;
               elsif Kind = "dispatch" then
                  Check_Dispatch_Line;
               elsif Kind = "elrsrx" then
                  Check_ELRS_Receiver_Line;
               elsif Kind = "bbhdr" then
                  Check_Blackbox_Header_Line;
               elsif Kind = "bbrec" then
                  Check_Blackbox_Recorder_Line;
               elsif Kind = "posnav" then
                  Check_Position_Nav_Line;
               elsif Kind = "osdwarn" then
                  Check_OSD_Warnings_Line;
               elsif Kind = "msptun" then
                  Check_MSP_Tunnel_Line;
               elsif Kind = "osdfmt" then
                  Check_OSD_Format_Line;
               elsif Kind = "vtxmsp" then
                  Check_VTX_MSP_Line;
               elsif Kind = "dpmsp" then
                  Check_Display_Port_MSP_Line;
               elsif Kind = "osdstats" then
                  Check_OSD_Stats_Line;
               elsif Kind = "osdpage" then
                  Check_OSD_Page_Line;
               elsif Kind = "osdelem" then
                  Check_OSD_Elements_Line;
               elsif Kind = "osdrender" then
                  Check_OSD_Render_Line;
               elsif Kind = "osdrender2" then
                  Check_OSD_Render_2_Line;
               elsif Kind = "osdrender3" then
                  Check_OSD_Render_3_Line;
               elsif Kind = "osdwarnel" then
                  Check_OSD_Warnings_Element_Line;
               elsif Kind = "osddraw" then
                  Check_OSD_Draw_Line;
               elsif Kind = "osdspec" then
                  Check_OSD_Spec_Line;
               elsif Kind = "osdtask" then
                  Check_OSD_Task_Line;
               elsif Kind = "mavtlm" then
                  Check_MAVLink_Telemetry_Line;
               elsif Kind = "mavcmd" then
                  Check_MAVLink_Commands_Line;
               elsif Kind = "jetitlm" then
                  Check_Jeti_Telemetry_Line;
               elsif Kind = "frskyd" then
                  Check_FrSky_D_Line;
               elsif Kind = "sfhss" then
                  Check_SFHSS_Line;
               elsif Kind = "redpine" then
                  Check_Redpine_Line;
               elsif Kind = "flysky" then
                  Check_FlySky_Line;
               elsif Kind = "spektrum" then
                  Check_Spektrum_Line;
               elsif Kind = "rcstats" then
                  Check_RC_Stats_Line;
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
   Run (Dir & "/mavlink.csv", "mavlink");
   Run (Dir & "/mspserial.csv", "mspserial");
   Run (Dir & "/elrs.csv", "elrs");
   Run (Dir & "/elrstlm.csv", "elrstlm");
   Run (Dir & "/bbenc.csv", "bbenc");
   Run (Dir & "/text.csv", "text");
   Run (Dir & "/dshot.csv", "dshot");
   Run (Dir & "/crsftlm.csv", "crsftlm");
   Run (Dir & "/escsensor.csv", "escsensor");
   Run (Dir & "/sport.csv", "sport");
   Run (Dir & "/rcdevice.csv", "rcdevice");
   Run (Dir & "/frskyhub.csv", "frskyhub");
   Run (Dir & "/ibustlm.csv", "ibustlm");
   Run (Dir & "/hott.csv", "hott");
   Run (Dir & "/ghsttlm.csv", "ghsttlm");
   Run (Dir & "/transponder.csv", "transponder");
   Run (Dir & "/srxltlm.csv", "srxltlm");
   Run (Dir & "/frskyosd.csv", "frskyosd");
   Run (Dir & "/ledstrip.csv", "ledstrip");
   Run (Dir & "/rangefinder.csv", "rangefinder");
   Run (Dir & "/opticalflow.csv", "opticalflow");
   Run (Dir & "/pitot.csv", "pitot");
   Run (Dir & "/rtc.csv", "rtc");
   Run (Dir & "/adcint.csv", "adcint");
   Run (Dir & "/stats.csv", "stats");
   Run (Dir & "/wlaunch.csv", "wlaunch");
   Run (Dir & "/trail.csv", "trail");
   Run (Dir & "/gps.csv", "gps");
   Run (Dir & "/ubxcfg.csv", "ubxcfg");
   Run (Dir & "/gpslink.csv", "gpslink");
   Run (Dir & "/posest.csv", "posest");
   Run (Dir & "/poshold.csv", "poshold");
   Run (Dir & "/rescue.csv", "rescue");
   Run (Dir & "/vtxsa.csv", "vtxsa");
   Run (Dir & "/vtxctl.csv", "vtxctl");
   Run (Dir & "/vtxtramp.csv", "vtxtramp");
   Run (Dir & "/ltm.csv", "ltm");
   Run (Dir & "/laptimer.csv", "laptimer");
   Run (Dir & "/mspbox.csv", "mspbox");
   Run (Dir & "/dispatch.csv", "dispatch");
   Run (Dir & "/elrsrx.csv", "elrsrx");
   Run (Dir & "/bbhdr.csv", "bbhdr");
   Run (Dir & "/bbrec.csv", "bbrec");
   Run (Dir & "/posnav.csv", "posnav");
   Run (Dir & "/osdwarn.csv", "osdwarn");
   Run (Dir & "/msptun.csv", "msptun");
   Run (Dir & "/osdfmt.csv", "osdfmt");
   Run (Dir & "/vtxmsp.csv", "vtxmsp");
   Run (Dir & "/dpmsp.csv", "dpmsp");
   Run (Dir & "/osdstats.csv", "osdstats");
   Run (Dir & "/osdpage.csv", "osdpage");
   Run (Dir & "/osdelem.csv", "osdelem");
   Run (Dir & "/osdrender.csv", "osdrender");
   Run (Dir & "/osdrender2.csv", "osdrender2");
   Run (Dir & "/osdrender3.csv", "osdrender3");
   Run (Dir & "/osdwarnel.csv", "osdwarnel");
   Run (Dir & "/osddraw.csv", "osddraw");
   Run (Dir & "/osdspec.csv", "osdspec");
   Run (Dir & "/osdtask.csv", "osdtask");
   Run (Dir & "/mavtlm.csv", "mavtlm");
   Run (Dir & "/mavcmd.csv", "mavcmd");
   Run (Dir & "/jetitlm.csv", "jetitlm");
   Run (Dir & "/frskyd.csv", "frskyd");
   Run (Dir & "/frskyx.csv", "frskyd");
   Run (Dir & "/sfhss.csv", "sfhss");
   Run (Dir & "/redpine.csv", "redpine");
   Run (Dir & "/flysky.csv", "flysky");
   Run (Dir & "/spektrum.csv", "spektrum");
   Run (Dir & "/rcstats.csv", "rcstats");
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
