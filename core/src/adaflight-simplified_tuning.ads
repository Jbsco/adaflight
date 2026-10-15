--  Simplified tuning: the PID gains of a profile and the D term and gyro
--  lowpass filters recomputed from the defaults through the sliders.
with Adaflight.Axes;
with Adaflight.PID_Profile;
with Adaflight.Gyro_Filters;

package Adaflight.Simplified_Tuning with SPARK_Mode is

   --  Every gain and D max of the axes the mode covers, from the defaults
   --  through the master multiplier and the slider of each term; nothing
   --  while the mode is off.
   procedure Apply_PIDs (P : in out PID_Profile.Profile);

   --  The D term lowpass filters in use from their defaults through the
   --  filter slider: the dynamic range when it is on, then each static
   --  cutoff that is on; nothing while the slider is off.
   procedure Apply_Dterm_Filters (P : in out PID_Profile.Profile);

   --  The gyro lowpass filters the same way through the gyro filter slider.
   procedure Apply_Gyro_Filters (G : in out Gyro_Filters.Settings);

   --  The gains, the D term filters and the gyro filters, in that order.
   procedure Apply (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings);

   --  Every slider turned off.
   procedure Disable (P : in out PID_Profile.Profile; G : in out Gyro_Filters.Settings);

private

   --  A slider in hundredths as a factor; a stored slider reaches 255.
   subtype Factor is Float range 0.0 .. 2.55;

   function Hundredths (V : Natural) return Factor is (Float (V) / 100.0)
     with Pre => V <= 255;

   --  The sliders one axis's gains come from: the master multiplier, the
   --  PI, D, feedforward and I gains, the D max slider, and the pitch D and
   --  PI gains, which are one off the pitch axis.
   type Sliders is record
      Master        : Factor;
      PI_Gain       : Factor;
      D_Gain        : Factor;
      FF_Gain       : Factor;
      I_Gain        : Factor;
      D_Max_Slider  : Factor;
      Pitch_D_Gain  : Factor;
      Pitch_PI_Gain : Factor;
   end record;

   --  One axis's gains and D max from its defaults through the sliders.
   type Tuned_Gains is record
      P     : PID_Profile.Gain;
      I     : PID_Profile.Gain;
      D     : PID_Profile.Gain;
      F     : PID_Profile.F_Gain;
      D_Max : PID_Profile.Gain;
   end record;

   function Tuned (S : Sliders; A : Axes.Axis) return Tuned_Gains;

   Dyn_LPF_Max_Hz : constant := 1_000;
   LPF_Max_Hz     : constant := 1_000;

   --  A default cutoff through a filter slider in percent, held to a limit.
   function Scaled (Default : Positive; Multiplier : Natural; Limit : Positive) return PID_Profile.Hertz is
     (Natural'Min (Default * Multiplier / 100, Limit))
     with Pre  => Default <= 1_000 and then Multiplier <= 255 and then Limit <= 1_000,
          Post => Scaled'Result <= Limit;

end Adaflight.Simplified_Tuning;
