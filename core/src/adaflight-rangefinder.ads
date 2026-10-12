--  The rangefinder readings: each distance the driver reports goes
--  through a median of five, a pseudo signal ratio from the squared
--  changes decides a dynamic ceiling on the usable distance, and the tilt
--  of the craft corrects the distance into an altitude, or discards it
--  past the sensor's cone. The drivers and the detection stay with the
--  target.
with Interfaces;

package Adaflight.Rangefinder with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_16;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_16 is Interfaces.Integer_16;

   Out_Of_Range     : constant Integer_32 := -1;
   Hardware_Failure : constant Integer_32 := -2;
   No_New_Data      : constant Integer_32 := -3;

   --  The driver's reading: a distance in centimetres, one of the codes
   --  above, or any other negative value, which counts as a failure.
   subtype Reading is Integer_32 range -1000 .. 40_000;
   subtype Distance_Cm is Integer_32 range -2 .. 40_000;
   subtype Cosine is Float range -1.0 .. 1.0;
   subtype Range_Cm is Integer_16 range 0 .. Integer_16'Last;
   subtype Decidegrees is Integer_16 range 0 .. 3600;

   type Settings is record
      Max_Range_Cm              : Range_Cm := 400;
      Cone_Extended_Decidegrees : Decidegrees := 300;
   end record;

   subtype Sample_Cm is Integer_32 range 0 .. 40_000;
   subtype Snr_Sample is Integer_16 range 0 .. 6400;
   type Int32_Window is array (0 .. 4) of Sample_Cm;
   type Snr_Window is array (0 .. 4) of Snr_Sample;

   type Sensor is record
      Max_Tilt_Cos          : Cosine := 1.0;
      Raw_Altitude          : Distance_Cm := Out_Of_Range;
      Calculated_Altitude   : Integer_32 := Out_Of_Range;
      Last_Valid_Ms         : Unsigned_32 := 0;
      Last_Data_Us          : Unsigned_32 := 0;
      Interval_Us           : Integer_32 := 0;
      Threshold_Reached     : Boolean := False;
      Dynamic_Threshold     : Distance_Cm := 0;
      Snr                   : Integer_16 := 0;
      Median_Samples        : Int32_Window := (others => 0);
      Median_Index          : Natural range 0 .. 4 := 0;
      Median_Ready          : Boolean := False;
      Snr_Samples           : Snr_Window := (others => 0);
      Snr_Index             : Natural range 0 .. 4 := 0;
      Previous_Reading      : Reading := Out_Of_Range;
      Snr_Ready             : Boolean := False;
      Max_Alt_With_Tilt_Cm  : Integer_16 := 0;
      Cf_Altitude_Cm        : Integer_16 := 0;
   end record;

   --  The sensor after detection: the tilt limit from the cone, the
   --  legacy altitude bounds, nothing read yet.
   procedure Init (S : out Sensor; C : Settings; Now_Ms : Unsigned_32);

   --  One reading from the driver with the cosine of the craft's tilt;
   --  Processed says the driver had new data.
   procedure Process (S : in out Sensor; Now_Us, Now_Ms : Unsigned_32; Distance : Reading; Cos_Tilt : Cosine;
                      Processed : out Boolean);

   --  The surface altitude is usable with positive readings, a quiet
   --  signal and a distance under the dynamic ceiling once one was set.
   function Surface_Altitude_Valid (S : Sensor) return Boolean;

   function Is_Healthy (S : Sensor; Now_Ms : Unsigned_32) return Boolean is
     (Now_Ms - S.Last_Valid_Ms < 500);

end Adaflight.Rangefinder;
