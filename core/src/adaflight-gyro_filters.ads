--  The gyro filtering chain: sample accumulation at the sensor rate with the
--  optional second lowpass as the downsampler, then per loop the two notches,
--  the first lowpass with its dynamic cutoff, and the lowpass that feeds the
--  attitude estimate, in the operation order of the reference.

with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters; use Adaflight.Filters;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.PID_Config; use Adaflight.PID_Config;
with Adaflight.PID_Filters;

package Adaflight.Gyro_Filters with SPARK_Mode, Pure is

   subtype Axis is Adaflight.Axes.Axis;

   IMU_Downsample_Cutoff_Hz : constant Float := 200.0;

   --  Raw sensor readings in the sensor's units, as a 16-bit device gives them.
   subtype Raw is Integer range -32_768 .. 32_767;
   type Raw_Vector is array (Axis) of Raw;
   subtype Offset is Float range -32_768.0 .. 32_767.0;
   type Offsets is array (Axis) of Offset;

   type Settings is record
      LPF1_Type        : Lowpass_Kind := PID_Profile.PT1;
      LPF1_Static_Hz   : Hertz := 250;
      LPF1_Dyn_Min_Hz  : Hertz := 250;
      LPF1_Dyn_Max_Hz  : Hertz := 500;
      LPF1_Dyn_Expo    : Natural range 0 .. 10 := 5;
      LPF2_Type        : Lowpass_Kind := PID_Profile.PT1;
      LPF2_Static_Hz   : Hertz := 500;
      Notch1_Hz        : Hertz := 0;
      Notch1_Cutoff    : Hertz := 0;
      Notch2_Hz        : Hertz := 0;
      Notch2_Cutoff    : Hertz := 0;
      Sample_Time_Us   : PID_Config.Loop_Time_Us := 125;
      Loop_Time_Us     : PID_Config.Loop_Time_Us := 125;
      Scale            : Float range 2.0 ** (-10) .. 1.0 := 1.0;
      Zero             : Offsets := (others => 0.0);
   end record
     with Dynamic_Predicate =>
       (Settings.LPF1_Dyn_Min_Hz = 0 or else Settings.LPF1_Dyn_Min_Hz <= Settings.LPF1_Dyn_Max_Hz)
       and then (Settings.Notch1_Hz = 0 or else Settings.Notch1_Cutoff < Settings.Notch1_Hz)
       and then (Settings.Notch2_Hz = 0 or else Settings.Notch2_Cutoff < Settings.Notch2_Hz)
       and then Settings.Sample_Time_Us <= Settings.Loop_Time_Us;

   subtype Stage is PID_Filters.Lowpass_Stage;
   type Axis_Stage is array (Axis) of Stage;
   type Axis_Notch is array (Axis) of SVF_Notch;
   type Axis_PT1 is array (Axis) of Filters.PT1;
   subtype Sample_Count is Natural range 0 .. 255;

   type State is record
      Lowpass1          : Axis_Stage;
      Lowpass2          : Axis_Stage;
      Downsample_Filter : Boolean := False;
      Notch1_Used       : Boolean := False;
      Notch1            : Axis_Notch;
      Notch2_Used       : Boolean := False;
      Notch2            : Axis_Notch;
      IMU_Filter        : Axis_PT1;
      Dyn_LPF           : PID_Config.Dyn_Lowpass := None;
      Dyn_LPF_Min       : Hertz := 0;
      Dyn_LPF_Max       : Hertz := 0;
      Dyn_LPF_Expo      : Natural range 0 .. 10 := 0;
      Rate              : Axis_Signals := (others => 0.0);
      Filtered          : Axis_Signals := (others => 0.0);
      Downsampled       : Axis_Signals := (others => 0.0);
      Sample_Sum        : Axis_Signals := (others => 0.0);
      Samples           : Sample_Count := 0;
   end record;

   procedure Init (S : out State; C : Settings);

   --  One sensor sample: offset, scale, and the downsampling accumulation.
   procedure Accumulate (S : in out State; C : Settings; Sample : Raw_Vector);

   --  One loop: the downsampled rate through the notches and the lowpass, and
   --  the attitude lowpass.
   procedure Filter (S : in out State; C : Settings);

   --  The first lowpass follows the throttle, as the mixer requests.
   procedure Update_Dynamic_Lowpass (S : in out State; C : Settings; Throttle : Unit_Interval);

end Adaflight.Gyro_Filters;
