--  The optical flow sensor: an MT device whose flow arrives over MSP through
--  the bridge, found at the start when the configuration names it and the
--  rangefinder setting names an MT device, and the optical flow task, which
--  turns each new sample into craft frame rates less the delayed gyro rates.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Optical_Flow;
package Adaflight.STM32.Optical_Flow is
   procedure Init (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32);
   function Detected return Boolean;
   function Hardware return Interfaces.Unsigned_8;
   --  The task period its driver reports, microseconds, zero without one.
   function Period_Us return Natural;
   --  The filtered gyro rates about roll and pitch the next process reads.
   procedure Set_Gyro (Roll_Rate, Pitch_Rate : Float);
   procedure Update;
   procedure Process;
   function Readings return Adaflight.Optical_Flow.Sensor;
end Adaflight.STM32.Optical_Flow;
