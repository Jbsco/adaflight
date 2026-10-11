--  The RPM filter: a bank of weighted notches, one per motor and harmonic,
--  on the three downsampled rates ahead of the static notches. Each loop
--  moves a share of the notches to their motor's reported frequency, faded
--  out as the notch nears the minimum frequency, then applies every notch
--  whose harmonic carries a weight.
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Config;
with Adaflight.Mixer;

package Adaflight.RPM_Filter with SPARK_Mode, Pure is

   Max_Harmonics : constant := 3;
   subtype Harmonic_Count is Natural range 0 .. Max_Harmonics;
   subtype Harmonic is Natural range 0 .. Max_Harmonics - 1;
   subtype Weight_Percent is Natural range 0 .. 255;
   type Harmonic_Weights is array (Harmonic) of Weight_Percent;

   --  The configuration interface's ranges. The lowpass on the reported
   --  motor speed belongs to the motor driver.
   type Settings is record
      Harmonics     : Harmonic_Count := 3;
      Weights       : Harmonic_Weights := (others => 100);
      Min_Hz        : Positive range 30 .. 200 := 100;
      Fade_Range_Hz : Natural range 0 .. 1_000 := 50;
      Q             : Positive range 250 .. 3_000 := 500;
   end record;

   subtype Motor_Count is Mixer.Motor_Count;
   subtype Motor_Index is Mixer.Motor_Index;
   --  A motor's rotation frequency as the telemetry lowpass reports it.
   subtype Motor_Frequency is Float range 0.0 .. 2.0 ** 16;
   type Motor_Frequencies is array (Motor_Index) of Motor_Frequency;
   --  The loop's measured period over its configured period.
   subtype Cycle_Multiplier is Float range 0.25 .. 4.0;

   type Harmonic_Gains is array (Harmonic) of Unit_Interval;
   type Notch_Bank is array (Motor_Index, Harmonic) of Weighted_Notch;
   --  The notch ceiling at the fastest loop.
   subtype Notch_Frequency is Float range 0.0 .. 4_800.0;
   --  The notches a loop updates: every notch of the bank at the slowest
   --  loop the ceiling admits, with room beyond it.
   subtype Update_Count is Natural range 0 .. 2_500;

   type State is record
      Harmonics        : Harmonic_Count := 0;
      Weights          : Harmonic_Gains := (others => 0.0);
      Min_Hz           : Notch_Frequency := 0.0;
      Max_Hz           : Notch_Frequency := 0.0;
      Fade_Range_Hz    : Float range 0.0 .. 1_000.0 := 0.0;
      Q                : Quality := 1.0;
      Dt               : PID_Config.Seconds := 1.0e-3;
      Motors           : Motor_Count := 1;
      Notches          : Notch_Bank;
      Updates_Per_Loop : Update_Count := 0;
      Motor            : Motor_Index := 0;
      Harmonic_Index   : Harmonic := 0;
   end record
     with Dynamic_Predicate => State.Harmonics = 0 or else State.Min_Hz <= State.Max_Hz;

   --  The filter runs with motor telemetry, a harmonic count, and a loop
   --  fast enough to put the minimum frequency under the notch ceiling.
   procedure Init
     (S : out State; C : Settings; Loop_Time_Us : PID_Config.Loop_Time_Us;
      Motors : Motor_Count; Telemetry : Boolean);

   function Active (S : State) return Boolean is (S.Harmonics > 0);

   --  One loop: the scheduled notch updates at the corrected period, then
   --  every weighted notch over the three rates.
   procedure Run
     (S : in out State; Motor_Hz : Motor_Frequencies; Dt_Scale : Cycle_Multiplier;
      Values : in out Axis_Signals)
     with Post => S.Harmonics = S.Harmonics'Old;

end Adaflight.RPM_Filter;
