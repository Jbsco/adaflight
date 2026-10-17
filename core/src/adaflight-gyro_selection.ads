--  The gyro sensors chosen at startup: the sensors to scan from the stored
--  detected flags, the enabled setting and the configured buses; the
--  detected and enabled sensors, falling back to the lowest; the stored flags
--  and setting brought up to date with a configuration write when either
--  changes; the overflow protection the enabled sensors share; and the first
--  enabled sensor's scale and sample rate.
with Interfaces;

package Adaflight.Gyro_Selection with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Mask is Interfaces.Unsigned_8;

   Max_Gyros : constant := 4;
   subtype Gyro_Index is Natural range 0 .. Max_Gyros - 1;
   subtype Gyro_Count is Positive range 1 .. Max_Gyros;
   type Gyro_Flags is array (Gyro_Index) of Boolean;

   --  What a detected sensor reports after its start.
   type Sensor_Report is record
      Sample_Rate_Hz     : Natural range 0 .. 65_535 := 0;
      Scale              : Float range 0.0 .. 1.0 := 1.0;
      Overflow_Protected : Boolean := False;
   end record;
   type Sensor_Reports is array (Gyro_Index) of Sensor_Report;

   --  The build's sensor count, the stored detected flags and enabled
   --  setting, the sensors with a configured bus, and the sensors that answer
   --  detection.
   type Inputs is record
      Count           : Gyro_Count := 1;
      Stored_Detected : Mask := 0;
      Enabled_Setting : Mask := 0;
      Configured      : Gyro_Flags := (others => False);
      Present         : Gyro_Flags := (others => False);
      Reports         : Sensor_Reports;
   end record;

   type Result is record
      Found              : Boolean := False;
      Detected           : Mask := 0;
      Enabled            : Mask := 0;
      Stored_Detected    : Mask := 0;
      Enabled_Setting    : Mask := 0;
      Write              : Boolean := False;
      First              : Integer range -1 .. Max_Gyros - 1 := -1;
      Overflow_Protected : Boolean := True;
      Scale              : Float range 0.0 .. 1.0 := 1.0;
      Sample_Rate_Hz     : Natural range 0 .. 65_535 := 0;
   end record;

   --  Without a detected sensor nothing is stored, and the scale is one and
   --  the sample rate 1 kHz.
   procedure Choose (I : Inputs; R : out Result)
     with Global => null;

end Adaflight.Gyro_Selection;
