--  The optical flow readings: each new sample from the driver is turned
--  into the craft frame by the sensor's mounting rotation, the gyro rate
--  whose age matches the sensor's delay is subtracted after its conversion
--  to radians per second, and an axis turning faster than the compensation
--  can recover keeps its previous rate and drops its validity. The drivers
--  and the detection stay with the target, as does the trigonometry of the
--  mounting rotation, computed once at init.
with Interfaces;
with Adaflight.Clock;
with Adaflight.Vectors;

package Adaflight.Optical_Flow with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_16;

   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Vector2 is Adaflight.Vectors.Vector2;

   Out_Of_Range     : constant Integer_16 := -1;
   Hardware_Failure : constant Integer_16 := -2;
   No_New_Data      : constant Integer_16 := -3;

   Hardware_Timeout_Us : constant := 100_000;

   --  Beyond this body rate in degrees per second the compensation cannot
   --  recover a translation rate.
   Rotation_Gyro_Limit : constant := 200.0;

   subtype Cosine is Float range -1.0 .. 1.0;

   --  The flow rates in radians per second and the gyro rates in degrees
   --  per second, bounded far past any sensor.
   subtype Flow_Rate is Float range -1.0e6 .. 1.0e6;
   subtype Gyro_Rate is Float range -1.0e6 .. 1.0e6;

   --  A rate in the craft frame: within twice the flow bound after the
   --  rotation, and a little past it after the compensation.
   subtype Rotated_Rate is Float range -2.0e6 .. 2.0e6;
   subtype Frame_Rate is Float range -4.0e6 .. 4.0e6;

   --  The age of the gyro reading that belongs to a flow sample.
   subtype Gyro_Delay is Unsigned_32 range 0 .. 2 ** 31 - 1;

   type Settings is record
      Rotation_Degrees : Unsigned_16 := 0;
      Flip_X           : Boolean := False;
   end record;

   --  The driver's sample: its time stamp, its quality in percent or one
   --  of the codes above, and the flow rates about the sensor's axes.
   type Sample is record
      Time_Stamp_Us : Unsigned_32 := 0;
      Quality       : Integer_16 := No_New_Data;
      Flow_X        : Flow_Rate := 0.0;
      Flow_Y        : Flow_Rate := 0.0;
   end record;

   --  One gyro reading is kept per flow sample, as deep as the slowest
   --  delay a driver asks for at the fastest rate it delivers.
   History_Depth : constant := 16;
   subtype History_Index is Natural range 0 .. History_Depth - 1;
   type Rate_History is array (History_Index) of Gyro_Rate;
   type Time_History is array (History_Index) of Unsigned_32;

   --  What the processing of a sample wrote where upstream records a debug
   --  value: that the sample held new data, the rates after the mounting
   --  rotation, the delayed gyro rates and the compensated rates before an
   --  axis past the gyro limit keeps its previous rate.
   type Debug_Taps is record
      Processed     : Boolean := False;
      Rotated_X     : Rotated_Rate := 0.0;
      Rotated_Y     : Rotated_Rate := 0.0;
      Gyro_X        : Gyro_Rate := 0.0;
      Gyro_Y        : Gyro_Rate := 0.0;
      Compensated_X : Frame_Rate := 0.0;
      Compensated_Y : Frame_Rate := 0.0;
   end record;

   type Sensor is record
      Rotation_Cos   : Cosine := 1.0;
      Rotation_Sin   : Cosine := 0.0;
      Flip_X         : Boolean := False;
      Gyro_Delay_Us  : Gyro_Delay := 0;
      Quality        : Integer_16 := No_New_Data;
      Raw_Flow       : Vector2;
      Processed_Flow : Vector2;
      X_Valid        : Boolean := True;
      Y_Valid        : Boolean := True;
      Time_Stamp_Us  : Unsigned_32 := 0;
      Sample_Index   : History_Index := 0;
      Roll_Rates     : Rate_History := (others => 0.0);
      Pitch_Rates    : Rate_History := (others => 0.0);
      Sample_Times   : Time_History := (others => 0);
      Taps           : Debug_Taps;
   end record;

   --  The sensor after detection, with the cosine and sine of the mounting
   --  rotation and the driver's gyro delay; nothing read yet.
   procedure Init (S : out Sensor; C : Settings; Rotation_Cos, Rotation_Sin : Cosine; Gyro_Delay_Us : Gyro_Delay;
                   Now_Us : Unsigned_32);

   --  One read of the driver with the filtered gyro rates about roll and
   --  pitch; a sample whose time stamp did not move only updates the
   --  quality.
   procedure Process (S : in out Sensor; D : Sample; Roll_Rate, Pitch_Rate : Gyro_Rate);

   function Is_Healthy (S : Sensor; Now_Us : Unsigned_32) return Boolean is
     (Adaflight.Clock.Elapsed (Now_Us, S.Time_Stamp_Us) < Hardware_Timeout_Us);

end Adaflight.Optical_Flow;
