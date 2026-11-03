--  The optical flow sensor of a build without it: no chip, no task and no readings.
with Adaflight.Optical_Flow_Detect;
package body Adaflight.STM32.Optical_Flow is

   procedure Init (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32) is null;

   function Detected return Boolean is (False);

   function Hardware return Interfaces.Unsigned_8 is (Adaflight.Optical_Flow_Detect.Hardware_None);

   function Period_Us return Natural is (0);

   procedure Set_Gyro (Roll_Rate, Pitch_Rate : Float) is null;

   procedure Update is null;

   procedure Process is null;

   function Readings return Adaflight.Optical_Flow.Sensor is (others => <>);

end Adaflight.STM32.Optical_Flow;
