--  The pitot of a build without it: not configured, no task and no airspeed.
package body Adaflight.STM32.Pitot is

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   function Configured return Boolean is (False);

   function Detected return Boolean is (False);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
   begin
      Next_Period_Us := 50_000;
   end Update;

   procedure Start_Calibration is null;

   function Calibrated return Boolean is (False);

   function Airspeed_Cm_S return Float is (0.0);

   function Diff_Pressure_Pa return Float is (0.0);

   function Temperature_K return Float is (0.0);

end Adaflight.STM32.Pitot;
