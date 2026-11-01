with Ada.Numerics.Elementary_Functions;
with Adaflight.Build_Features;
with Adaflight.MT_Sensor;
with Adaflight.Optical_Flow_Detect;
with Adaflight.Optical_Flow_Detect.Probe;
with Adaflight.STM32.MT;
package body Adaflight.STM32.Optical_Flow is
   use type Interfaces.Unsigned_8;
   package Core renames Adaflight.Optical_Flow;
   package Detect renames Adaflight.Optical_Flow_Detect;

   type Device is limited record
      Period_Us : Natural := 0;
   end record;

   --  The MT device the bridge holds for the rangefinder hardware; the UP-T1
   --  waits for its UART driver.
   procedure Detect_Chip
     (D : in out Device; Chip : Detect.Driver; Rangefinder : Interfaces.Unsigned_8; Found : out Boolean;
      Reported : out Detect.Delay_Ms)
   is
      pragma Unreferenced (D, Rangefinder);
   begin
      case Chip is
         when Detect.MT =>
            Found := Adaflight.STM32.MT.Present;
            Reported := Detect.Delay_Ms (Natural'Min (Detect.Delay_Ms'Last, Adaflight.STM32.MT.Delay_Ms));
         when Detect.UPT1 =>
            Found := False;
            Reported := 0;
      end case;
   end Detect_Chip;

   procedure Reschedule (D : in out Device; Period_Us : Natural) is
   begin
      D.Period_Us := Period_Us;
   end Reschedule;

   package Probe is new Detect.Probe (Device => Device, Detect_Chip => Detect_Chip, Reschedule => Reschedule);

   Dev         : Device;
   Sensor      : Core.Sensor;
   Found       : Boolean := False;
   Hardware_Id : Interfaces.Unsigned_8 := Detect.Hardware_None;
   Roll_Dps    : Core.Gyro_Rate := 0.0;
   Pitch_Dps   : Core.Gyro_Rate := 0.0;

   function Unit (X : Float) return Core.Cosine is (Float'Max (-1.0, Float'Min (1.0, X)));

   procedure Init (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32) is
      O           : Adaflight.Config_Groups.Opticalflow_Config_Record renames C.Opticalflow_Config;
      Detected_Id : Interfaces.Unsigned_8 := Detect.Hardware_None;
      Radians     : constant Float := Float (O.Rotation) * (Ada.Numerics.Pi / 180.0);
   begin
      Found := False;
      Hardware_Id := Detect.Hardware_None;
      Dev.Period_Us := 0;
      Probe.Detect
        (Dev, Adaflight.Build_Features.Rangefinder, O.Opticalflow_Hardware, C.Rangefinder_Config.Rangefinder_Hardware,
         Detected_Id, Found);
      if Found then
         Hardware_Id := Detected_Id;
         Core.Init
           (Sensor, (Rotation_Degrees => O.Rotation, Flip_X => O.Flip_X /= 0),
            Rotation_Cos  => Unit (Ada.Numerics.Elementary_Functions.Cos (Radians)),
            Rotation_Sin  => Unit (Ada.Numerics.Elementary_Functions.Sin (Radians)),
            Gyro_Delay_Us => Adaflight.MT_Sensor.Flow_Gyro_Delay_Us,
            Now_Us        => Now_Us);
      end if;
   end Init;

   function Detected return Boolean is (Found);
   function Hardware return Interfaces.Unsigned_8 is (Hardware_Id);
   function Period_Us return Natural is (Dev.Period_Us);

   procedure Set_Gyro (Roll_Rate, Pitch_Rate : Float) is
   begin
      Roll_Dps := Core.Gyro_Rate (Float'Max (Core.Gyro_Rate'First, Float'Min (Core.Gyro_Rate'Last, Roll_Rate)));
      Pitch_Dps := Core.Gyro_Rate (Float'Max (Core.Gyro_Rate'First, Float'Min (Core.Gyro_Rate'Last, Pitch_Rate)));
   end Set_Gyro;

   procedure Update is null;

   procedure Process is
   begin
      if Found then
         Core.Process (Sensor, Adaflight.STM32.MT.Flow_Sample, Roll_Dps, Pitch_Dps);
      end if;
   end Process;

   function Readings return Adaflight.Optical_Flow.Sensor is (Sensor);

end Adaflight.STM32.Optical_Flow;
