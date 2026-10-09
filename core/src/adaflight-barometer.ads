--  The barometer: the altitude from each pressure sample, the ground level
--  from the power-on calibration or a later reset, the temperature drift
--  correction, and the sample timing the altitude estimator reads. The
--  device state machine that schedules the reads belongs to the driver.
with Interfaces;

package Adaflight.Barometer with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Time_Us is Interfaces.Unsigned_32;

   --  Drift in centimeters per ten degrees; a virtual device skips the
   --  calibration and the drift correction.
   type Settings is record
      Temperature_Drift_Cm_Per_10C : Integer range -500 .. 500 := 0;
      Virtual_Device               : Boolean := False;
   end record;

   Calibration_Cycles  : constant := 100;
   Ground_Level_Cycles : constant := 10;
   subtype Cycle_Count is Natural range 0 .. Calibration_Cycles;

   --  Temperature in hundredths of a degree, well beyond any device range.
   subtype Temperature_Centi is Integer_32 range -1_000_000 .. 1_000_000;

   --  Altitude in centimeters from a pressure within the 32-bit range. The
   --  calibration sums at most one hundred altitudes and temperatures and
   --  saturates at the sum types' bounds, which it cannot reach.
   Altitude_Bound : constant := 4.0e7;
   subtype Altitude_Cm is Float range -Altitude_Bound .. Altitude_Bound;
   subtype Altitude_Sum is Float range -4.0e9 .. 4.0e9;
   subtype Temperature_Sum is Integer_32 range -200_000_000 .. 200_000_000;
   subtype Altitude_Value is Float range -2.0e10 .. 2.0e10;

   type State is record
      Ground_Altitude            : Altitude_Sum := 0.0;
      Temperature_At_Calibration : Temperature_Sum := 0;
      Calibrated                 : Boolean := False;
      Cycles                     : Cycle_Count := 0;
      Count                      : Cycle_Count := 0;
      Altitude                   : Altitude_Value := 0.0;
      Pressure                   : Integer_32 := 0;
      Temperature                : Temperature_Centi := 0;
      Last_Data_Time_Us          : Time_Us := 0;
      Data_Interval_Us           : Integer_32 := 0;
   end record;

   procedure Init (S : out State);

   procedure Start_Calibration (S : in out State; C : Settings)
     with Post => S.Calibrated = C.Virtual_Device;

   procedure Set_Ground_Level (S : in out State)
     with Post => not S.Calibrated and then S.Cycles = Ground_Level_Cycles and then S.Count = 0;

   --  One pressure sample as the device reports it, at the time of the read.
   procedure Sample (
      S           : in out State;
      C           : Settings;
      Pressure    : Integer_32;
      Temperature : Temperature_Centi;
      Now_Us      : Time_Us
   ) with Post => S.Pressure = Pressure and then S.Temperature = Temperature;

end Adaflight.Barometer;
