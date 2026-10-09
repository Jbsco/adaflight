--  The dynamic notch filter: the filtered rates downsampled into a sliding
--  DFT per axis, the windowed spectrum searched for its largest peaks above
--  a noise floor, each peak's frequency refined by a parabola over its
--  neighbours and smoothed toward a notch center, and the notches applied to
--  the rates, in the reference's four-step cycle over the three axes.
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Config;
with Adaflight.SDFT;

package Adaflight.Dyn_Notch with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;

   Max_Notches : constant := 7;
   subtype Notch_Count is Natural range 0 .. Max_Notches;
   subtype Notch_Index is Natural range 0 .. Max_Notches - 1;

   --  The configuration interface's ranges; the quality in hundredths.
   type Settings is record
      Count  : Notch_Count := 3;
      Q      : Positive range 1 .. 1_000 := 300;
      Min_Hz : Positive range 20 .. 250 := 100;
      Max_Hz : Positive range 200 .. 1_000 := 600;
   end record;

   --  A center stays between the configured limits, zero for a notch not in
   --  use.
   subtype Center_Hz is Float range 0.0 .. 1_000.0;
   type Center_Table is array (Axis, Notch_Index) of Center_Hz;
   type Notch_Table is array (Axis, Notch_Index) of SVF_Notch;

   --  A spectral power; the windowed spectrum of saturated transforms stays
   --  far inside the bound.
   Power_Bound : constant := 2.0 ** 104;
   subtype Power is Float range 0.0 .. Power_Bound;
   subtype Noise_Level is Float range -Power_Bound .. Power_Bound;

   --  A peak bin of zero is a void peak.
   type Peak is record
      Bin   : SDFT.Bin := 0;
      Value : Power := 0.0;
   end record;
   type Peak_List is array (Notch_Index) of Peak;

   type Step is (Window, Detect_Peaks, Calc_Frequencies, Update_Filters);
   type Axis_Transforms is array (Axis) of SDFT.Transform;

   --  The samples averaged per transform push: the loop rate over twice the
   --  upper limit, at most 25 for the fastest loop and the lowest limit.
   subtype Batch_Size is Positive range 1 .. SDFT.Bin_Count;
   subtype Batch_Position is Natural range 0 .. SDFT.Bin_Count;
   Calc_Ticks : constant := 12;

   type State is record
      Active           : Boolean := False;
      Count            : Notch_Count := 0;
      Q                : Quality := 3.0;
      Min_Hz           : Float range 20.0 .. 250.0 := 100.0;
      Max_Hz           : Float range 200.0 .. 1_000.0 := 600.0;
      Dt               : Float range 9.0e-5 .. 5.1e-4 := 1.25e-4;
      Max_Center       : Natural range 0 .. 1_000 := 0;
      Center           : Center_Table := (others => (others => 0.0));
      Notch            : Notch_Table;
      Sample_Index     : Batch_Position := 0;
      Sample_Count     : Batch_Size := 1;
      Sample_Count_Rcp : Float range 0.0 .. 1.0 := 1.0;
      Accumulator      : Axis_Signals := (others => 0.0);
      Average          : Axis_Signals := (others => 0.0);
      Tick             : Natural range 0 .. Calc_Ticks := 0;
      Current_Step     : Step := Window;
      Current_Axis     : Axis := Roll;
      Transforms       : Axis_Transforms;
      Peaks            : Peak_List;
      Data             : SDFT.Magnitudes := (others => 0.0);
      Resolution_Hz    : Float range 0.5 .. 200.0 := 18.5;
      Start_Bin        : SDFT.Bin := 1;
      End_Bin          : SDFT.Bin := SDFT.Bin_Count - 1;
      Floor_Start_Bin  : SDFT.Bin := 1;
      Noise_Threshold  : Noise_Level := 0.0;
      PT1_Looptime_S   : Float range 0.0 .. 1.0 := 0.0015;
   end record;

   --  Inactive when the count is zero or the loop runs below 2 kHz.
   procedure Init (S : out State; C : Settings; Loop_Time_Us : PID_Config.Loop_Time_Us);

   --  One filtered rate joins the axis's accumulator.
   procedure Push (S : in out State; A : Axis; Sample : Signal);

   --  One loop: the averaged samples into the transforms, and one step of
   --  the peak search and notch update. The throttle percent gates the
   --  record of the highest center.
   procedure Update (S : in out State; Throttle_Percent : Natural);

   --  The rate through the axis's notches.
   procedure Filter (S : in out State; A : Axis; Value : in out Signal);

end Adaflight.Dyn_Notch;
