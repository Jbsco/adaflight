--  The barometer of a build without it: no chip, no task and no altitude.
with Adaflight.Baro_Detect;
package body Adaflight.STM32.Baro is

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   function Detected return Boolean is (False);

   function Hardware return Interfaces.Unsigned_8 is (Adaflight.Baro_Detect.Hardware_None);

   function Bus_Type return Interfaces.Unsigned_8 is (0);

   function Bus_Number return Natural is (0);

   function Bus_Address return Interfaces.Unsigned_8 is (0);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
   begin
      Next_Period_Us := 0;
   end Update;

   procedure Start_Calibration is null;

   procedure Set_Ground_Level is null;

   function Calibrated return Boolean is (False);

   function Altitude_Cm return Float is (0.0);

   function Sample_Time_Us return Interfaces.Unsigned_32 is (0);

   function Interval_Us return Interfaces.Integer_32 is (0);

   function Temperature_Centi return Interfaces.Integer_32 is (0);
   function Pressure return Interfaces.Integer_32 is (0);

end Adaflight.STM32.Baro;
