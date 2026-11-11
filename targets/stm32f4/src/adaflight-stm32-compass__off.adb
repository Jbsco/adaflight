--  The compass of a build without it: no chip, no task and no field.
with Adaflight.Compass_Detect;
package body Adaflight.STM32.Compass is

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   function Detected return Boolean is (False);

   function Hardware return Interfaces.Unsigned_8 is (Adaflight.Compass_Detect.Hardware_None);

   function Bus_Type return Interfaces.Unsigned_8 is (0);

   function Bus_Number return Natural is (0);

   function Bus_Address return Interfaces.Unsigned_8 is (0);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
   begin
      Next_Period_Us := 0;
   end Update;

   procedure Set_Gyro (Rates : Adaflight.Vectors.Vector3) is null;

   procedure Start_Calibration is null;

   function Calibration_Complete return Boolean is (True);
   function Calibrated return Boolean is (False);

   function Enabled_And_Calibrated return Boolean is (False);

   function Field return Adaflight.Vectors.Vector3 is (0.0, 0.0, 0.0);

   procedure Take_Beep (B : out Adaflight.Compass.Beep) is
   begin
      B := Adaflight.Compass.Silence;
   end Take_Beep;

   procedure Take_Save (Requested : out Boolean; Zero : out Adaflight.Compass.Zero_Offsets) is
   begin
      Requested := False;
      Zero := (others => 0);
   end Take_Save;

end Adaflight.STM32.Compass;
