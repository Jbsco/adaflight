--  The pitot airspeed sensor: an MS4525 on the I2C bus the configuration
--  names, found at the start by one frame read, and the pitot task, which
--  reads a frame each pass into the core's sensor at twenty hertz.
with Adaflight.Config_Groups;
with Adaflight.Scheduler;
package Adaflight.STM32.Pitot is
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   --  A pitot named by the configuration, which enables its task.
   function Configured return Boolean;
   --  A source delivering samples, which sets the sensor flag.
   function Detected return Boolean;
   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   procedure Start_Calibration;
   function Calibrated return Boolean;
   --  The indicated airspeed in centimetres per second, the zeroed
   --  differential pressure in pascals and the temperature in kelvin.
   function Airspeed_Cm_S return Float;
   function Diff_Pressure_Pa return Float;
   function Temperature_K return Float;
end Adaflight.STM32.Pitot;
