--  The pitot airspeed: the differential pressure of the source that
--  answered goes through a first-order low-pass at five hertz, twenty
--  samples at rest set the source's zero, and the zero-corrected pressure
--  gives the indicated airspeed in centimetres per second. The drivers,
--  the bus and the DroneCAN frames stay with the target.
with Interfaces;
with Adaflight.Filters;
with Adaflight.Maths;

package Adaflight.Pitot with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   --  The sources in the reference's order: the default tries the I2C
   --  sensor and falls back to DroneCAN.
   type Source is (Default, None, MS4525, Dronecan);

   Rate_Hz             : constant := 20;
   Calibration_Samples : constant := Rate_Hz;
   Air_Density         : constant Float := 1.225;
   Lpf_Hz              : constant Float := 5.0;
   Dronecan_Stale_Us   : constant := 500_000;
   Signal_Timeout_Us   : constant := 1_000_000;

   --  Pressures in pascals and temperatures in kelvin, bounded far past
   --  any sensor.
   subtype Pressure is Float range -1.0e6 .. 1.0e6;
   subtype Kelvin is Float range 0.0 .. 1.0e4;

   type Settings is record
      Hardware : Source := None;
   end record;

   --  What the platform read this pass: the I2C sensor's sample when the
   --  transfer succeeded, and the latest DroneCAN frame with its arrival.
   type Inputs is record
      Now_Us          : Unsigned_32 := 0;
      Armed           : Boolean := False;
      I2C_Read        : Boolean := False;
      I2C_Pressure    : Pressure := 0.0;
      I2C_Temperature : Kelvin := 0.0;
      Can_Frame       : Boolean := False;
      Can_Pressure    : Pressure := 0.0;
      Can_Temperature : Kelvin := 0.0;
      Can_Update_Us   : Unsigned_32 := 0;
   end record;

   Signal_Bound : constant := Adaflight.Maths.Signal_Bound;

   subtype Sample_Count is Natural range 0 .. Calibration_Samples;
   subtype Accumulated is Float range -Float (Calibration_Samples) * Signal_Bound
                                    .. Float (Calibration_Samples) * Signal_Bound;
   subtype Zero_Pressure is Float range -Signal_Bound .. Signal_Bound;
   type Source_Zeros is array (Source) of Zero_Pressure;
   type Source_Flags is array (Source) of Boolean;

   --  What the debug values read of the updates: whether one ran with a
   --  source, with its airspeed, differential pressure, filtered pressure
   --  before the zero offset, and temperature. Each tap holds what its site
   --  last wrote.
   type Debug_Taps is record
      Updated       : Boolean := False;
      Airspeed      : Float := 0.0;
      Diff_Pressure : Float := 0.0;
      Filtered      : Float := 0.0;
      Temperature   : Float := 0.0;
   end record;

   type Sensor is record
      Airspeed          : Float := 0.0;
      Diff_Pressure     : Float := 0.0;
      Temperature       : Kelvin := 0.0;
      Pressure_Zero     : Zero_Pressure := 0.0;
      Calibration_Count : Sample_Count := 0;
      Calibration_Accum : Accumulated := 0.0;
      Zeros             : Source_Zeros := (others => 0.0);
      Calibrated        : Source_Flags := (others => False);
      Lpf               : Adaflight.Filters.PT1;
      Lpf_Initialised   : Boolean := False;
      I2C_Ready         : Boolean := False;
      Active            : Source := None;
      Last_Valid_Us     : Unsigned_32 := 0;
      Taps              : Debug_Taps;
   end record;

   --  The sensor after init: the I2C sensor counts as ready when the
   --  configuration names it or the default and the platform found it.
   procedure Init (S : out Sensor; C : Settings; I2C_Detected : Boolean);

   --  One pass of the task.
   procedure Update (S : in out Sensor; C : Settings; Inp : Inputs);

   --  Twenty at-rest samples set the active source's zero again.
   procedure Start_Calibration (S : in out Sensor);

   function Is_Configured (C : Settings) return Boolean is (C.Hardware /= None);

   function Is_Calibrated (S : Sensor) return Boolean is
     (S.Active /= None and then S.Calibrated (S.Active));

end Adaflight.Pitot;
