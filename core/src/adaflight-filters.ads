--  Discrete-time filters over Signals.
--
--  Each filter is a record holding its coefficients and its state. Apply
--  advances the state by one sample and returns the output. The state of
--  every recursive filter is saturated at the Signal bound by Lerp or by
--  Constrain_F, so a filter output is a Signal by type and no filter can
--  produce an infinity whatever its input history.

with Interfaces;
with Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.Filters with SPARK_Mode, Pure is

   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype Frequency is Float range 0.0 .. 2.0 ** 20;
   subtype Period is Float range 0.0 .. 2.0 ** 20;

   --  Product of a cutoff frequency and a sample period, limited so that
   --  the coefficient computations of the state-variable filters stay away
   --  from the tangent singularity at half the sample rate.
   ---------------------------------------------------------------------------
   --  First, second, and third order low-pass filters
   ---------------------------------------------------------------------------

   type PT1 is record
      State : Signal := 0.0;
      K     : Unit_Interval := 0.0;
   end record;

   type PT2 is record
      State  : Signal := 0.0;
      State1 : Signal := 0.0;
      K      : Unit_Interval := 0.0;
   end record;

   type PT3 is record
      State  : Signal := 0.0;
      State1 : Signal := 0.0;
      State2 : Signal := 0.0;
      K      : Unit_Interval := 0.0;
   end record;

   subtype Delay_Seconds is Float range -2.0 ** 20 .. 2.0 ** 20;

   function PT1_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval;
   function PT1_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval;
   procedure PT1_Init (F : out PT1; K : Unit_Interval)
     with Post => F.State = 0.0 and then F.K = K;
   procedure PT1_Update_Cutoff (F : in out PT1; K : Unit_Interval)
     with Post => F.K = K and then F.State = F.State'Old;
   procedure PT1_Apply (F : in out PT1; Input : Signal; Output : out Signal)
     with Inline, Post => Output = F.State and then F.K = F.K'Old;

   function PT2_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval;
   function PT2_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval;
   procedure PT2_Init (F : out PT2; K : Unit_Interval)
     with Post => F.State = 0.0 and then F.State1 = 0.0 and then F.K = K;
   procedure PT2_Update_Cutoff (F : in out PT2; K : Unit_Interval)
     with Post => F.K = K and then F.State = F.State'Old and then F.State1 = F.State1'Old;
   procedure PT2_Apply (F : in out PT2; Input : Signal; Output : out Signal)
     with Inline, Post => Output = F.State and then F.K = F.K'Old;

   function PT3_Gain (Cutoff : Frequency; Dt : Period) return Unit_Interval;
   function PT3_Gain_From_Delay (Delay_S : Delay_Seconds; Dt : Period) return Unit_Interval;
   procedure PT3_Init (F : out PT3; K : Unit_Interval)
     with Post => F.State = 0.0 and then F.State1 = 0.0 and then F.State2 = 0.0 and then F.K = K;
   procedure PT3_Update_Cutoff (F : in out PT3; K : Unit_Interval)
     with Post => F.K = K and then F.State = F.State'Old
       and then F.State1 = F.State1'Old and then F.State2 = F.State2'Old;
   procedure PT3_Apply (F : in out PT3; Input : Signal; Output : out Signal)
     with Inline, Post => Output = F.State and then F.K = F.K'Old;

   ---------------------------------------------------------------------------
   --  State-variable filters in topology-preserving transform form
   ---------------------------------------------------------------------------

   --  Notch quality factor from the center and lower cutoff frequencies.
   --  Center must exceed Cutoff by at least one hertz so the difference of
   --  squares is positive.
   Max_Quality : constant := 2.0 ** 20;
   subtype Quality is Float range 2.0 ** (-20) .. Max_Quality;

   function Notch_Q (Center : Frequency; Cutoff : Frequency) return Quality
     with Pre => Cutoff >= 1.0 and then Center >= Cutoff + 1.0;

   subtype Warped_Frequency is Float range 0.0 .. Max_Tan;
   subtype Scaled_Coefficient is Float range 0.0 .. Max_Tan * Max_Quality;

   type SVF_Lowpass is record
      F   : Warped_Frequency := 0.0;
      A1  : Unit_Interval := 1.0;
      A2  : Warped_Frequency := 0.0;
      IC1 : Signal := 0.0;
      IC2 : Signal := 0.0;
   end record;

   procedure SVF_Lowpass_Init
     (Filt : out SVF_Lowpass; Cutoff : Frequency; Dt : Period);
   procedure SVF_Lowpass_Update
     (Filt : in out SVF_Lowpass; Cutoff : Frequency; Dt : Period);
   procedure SVF_Lowpass_Apply
     (Filt : in out SVF_Lowpass; Input : Signal; Output : out Signal)
     with Inline;

   type SVF_Notch is record
      A1   : Unit_Interval := 1.0;
      A2Q  : Scaled_Coefficient := 0.0;
      FQ   : Scaled_Coefficient := 0.0;
      IC1Q : Signal := 0.0;
      IC2  : Signal := 0.0;
   end record;

   procedure SVF_Notch_Init
     (Filt : out SVF_Notch; Center : Frequency; Dt : Period; Q : Quality);
   procedure SVF_Notch_Update
     (Filt : in out SVF_Notch; Center : Frequency; Dt : Period; Q : Quality);
   procedure SVF_Notch_Apply
     (Filt : in out SVF_Notch; Input : Signal; Output : out Signal)
     with Inline;

   --  A notch applied to three axes at once with a blend weight, as used
   --  for motor harmonic rejection.
   subtype Axis is Adaflight.Axes.Axis;
   type Axis_Signals is array (Axis) of Signal;

   type Weighted_Notch is record
      F   : Warped_Frequency := 0.0;
      A1  : Unit_Interval := 1.0;
      A2  : Warped_Frequency := 0.0;
      WQ  : Scaled_Coefficient := 0.0;
      IC1 : Axis_Signals := (others => 0.0);
      IC2 : Axis_Signals := (others => 0.0);
   end record;

   procedure Weighted_Notch_Init
     (Filt : out Weighted_Notch; Center : Frequency; Dt : Period;
      Q : Quality; Weight : Unit_Interval);
   procedure Weighted_Notch_Update
     (Filt : in out Weighted_Notch; Center : Frequency; Dt : Period;
      Q : Quality; Weight : Unit_Interval);
   procedure Weighted_Notch_Apply (Filt : in out Weighted_Notch; Values : in out Axis_Signals)
     with Inline;

   ---------------------------------------------------------------------------
   --  Phase compensator (first order lead-lag)
   ---------------------------------------------------------------------------

   subtype Phase_Degrees is Float range (-89.0) .. 89.0;
   subtype Loop_Time_Us is Positive range 1 .. 1_000_000;
   subtype Comp_Coefficient is Float range -2.0 ** 48 .. 2.0 ** 48;

   type Phase_Comp is record
      B0 : Comp_Coefficient := 1.0;
      B1 : Comp_Coefficient := 0.0;
      A1 : Comp_Coefficient := 0.0;
      X1 : Signal := 0.0;
      Y1 : Signal := 0.0;
   end record;

   procedure Phase_Comp_Init
     (Filt : out Phase_Comp; Center : Frequency; Phase : Phase_Degrees;
      Loop_Time : Loop_Time_Us)
     with Pre => Center >= 1.0 and then Center * Float (Loop_Time) <= 400_000.0;
   procedure Phase_Comp_Update
     (Filt : in out Phase_Comp; Center : Frequency; Phase : Phase_Degrees;
      Loop_Time : Loop_Time_Us)
     with Pre => Center >= 1.0 and then Center * Float (Loop_Time) <= 400_000.0;
   procedure Phase_Comp_Apply (Filt : in out Phase_Comp; Input : Signal; Output : out Signal)
     with Inline;
   procedure Phase_Comp_Reset (Filt : in out Phase_Comp)
     with Post => Filt.X1 = 0.0 and then Filt.Y1 = 0.0;

   ---------------------------------------------------------------------------
   --  Slew limiter with a release threshold
   ---------------------------------------------------------------------------

   subtype Slew_Bound is Float range 0.0 .. Signal_Bound;

   type Slew_Filter is record
      State      : Signal := 0.0;
      Slew_Limit : Slew_Bound := 0.0;
      Threshold  : Slew_Bound := 0.0;
   end record;

   procedure Slew_Init (Filt : out Slew_Filter; Slew_Limit : Slew_Bound; Threshold : Slew_Bound)
     with Post => Filt.State = 0.0 and then Filt.Slew_Limit = Slew_Limit
       and then Filt.Threshold = Threshold;
   procedure Slew_Apply (Filt : in out Slew_Filter; Input : Signal; Output : out Signal)
     with Post => Output = Filt.State;

   ---------------------------------------------------------------------------
   --  Moving average over a window of up to Max_Window samples
   ---------------------------------------------------------------------------

   Max_Window : constant := 32;
   subtype Window_Size is Positive range 1 .. Max_Window;
   subtype Window_Index is Natural range 0 .. Max_Window - 1;
   type Window_Buffer is array (Window_Index) of Signal;

   --  The sum is recomputed from the window on every update, so rounding
   --  cannot accumulate across samples.
   type Moving_Average is record
      Index  : Window_Index := 0;
      Size   : Window_Size := 1;
      Buffer : Window_Buffer := (others => 0.0);
      Primed : Boolean := False;
   end record
     with Dynamic_Predicate => Moving_Average.Index < Moving_Average.Size;

   procedure Moving_Average_Init (Filt : out Moving_Average; Size : Window_Size)
     with Post => Filt.Size = Size and then not Filt.Primed and then Filt.Index = 0;
   procedure Moving_Average_Update
     (Filt : in out Moving_Average; Input : Signal; Output : out Signal)
     with Post => Filt.Size = Filt.Size'Old;

   ---------------------------------------------------------------------------
   --  Integer low-pass with a fixed-point accumulator
   ---------------------------------------------------------------------------

   subtype Shift_Amount is Natural range 0 .. 15;
   subtype Simple_Input is Integer_32 range -2 ** 15 .. 2 ** 15;
   subtype Shift_Scale is Integer_32 range 1 .. 2 ** 15;

   Shift_Scales : constant array (Shift_Amount) of Shift_Scale :=
     (1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768);

   type Simple_Lowpass is record
      FP          : Integer_32 := 0;
      Beta_Scale  : Shift_Scale := 1;
      Input_Scale : Shift_Scale := 1;
   end record
     with Dynamic_Predicate =>
       Simple_Lowpass.FP in -(2 ** 15 * Simple_Lowpass.Input_Scale)
                         .. 2 ** 15 * Simple_Lowpass.Input_Scale;

   procedure Simple_Lowpass_Init
     (Filt : out Simple_Lowpass; Beta : Shift_Amount; FP_Shift : Shift_Amount)
     with Post => Filt.FP = 0 and then Filt.Beta_Scale = Shift_Scales (Beta)
       and then Filt.Input_Scale = Shift_Scales (FP_Shift);
   procedure Simple_Lowpass_Update
     (Filt : in out Simple_Lowpass; Input : Simple_Input; Output : out Simple_Input)
     with Post => Filt.Beta_Scale = Filt.Beta_Scale'Old
       and then Filt.Input_Scale = Filt.Input_Scale'Old;

   ---------------------------------------------------------------------------
   --  Mean of small signed samples between reads
   ---------------------------------------------------------------------------

   Max_Mean_Count : constant := 2 ** 20;
   subtype Mean_Count is Natural range 0 .. Max_Mean_Count;

   type Mean_Accumulator is record
      Sum   : Integer_32 := 0;
      Count : Mean_Count := 0;
   end record
     with Dynamic_Predicate =>
       Mean_Accumulator.Sum in (-128) * Integer_32 (Mean_Accumulator.Count)
                            .. 127 * Integer_32 (Mean_Accumulator.Count);

   procedure Mean_Init (Acc : out Mean_Accumulator)
     with Post => Acc.Sum = 0 and then Acc.Count = 0;
   procedure Mean_Add (Acc : in out Mean_Accumulator; Value : Integer_8)
     with Pre  => Acc.Count < Max_Mean_Count,
          Post => Acc.Count = Acc.Count'Old + 1;
   --  Returns the mean and clears the accumulator, or the default when no
   --  sample was added.
   procedure Mean_Calc
     (Acc : in out Mean_Accumulator; Default : Integer_8; Result : out Integer_8)
     with Post => Acc.Count = 0 and then Acc.Sum = 0;

end Adaflight.Filters;
