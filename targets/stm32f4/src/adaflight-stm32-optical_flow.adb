with Ada.Numerics.Elementary_Functions;
with Adaflight.Build_Features;
with Adaflight.MT_Sensor;
with Adaflight.Optical_Flow_Detect;
with Adaflight.Optical_Flow_Detect.Probe;
with Adaflight.Optical_Flow_Debug;
with Adaflight.STM32.Debug_Values;
with Adaflight.STM32.MT;
with Adaflight.STM32.Rangefinder;
package body Adaflight.STM32.Optical_Flow is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_8;
   package Core renames Adaflight.Optical_Flow;
   package Detect renames Adaflight.Optical_Flow_Detect;
   use type Detect.Driver;

   type Device is limited record
      Period_Us     : Natural := 0;
      Flow_Uart     : Interfaces.Integer_8 := -1;
      Gyro_Delay_Us : Core.Gyro_Delay := 0;
      Kind          : Detect.Driver := Detect.MT;
   end record;

   --  The MT device the bridge holds for the rangefinder hardware, or the
   --  UP-T1 module on the optical flow port through the rangefinder unit.
   procedure Detect_Chip
     (D : in out Device; Chip : Detect.Driver; Rangefinder : Interfaces.Unsigned_8; Found : out Boolean;
      Reported : out Detect.Delay_Ms)
   is
      pragma Unreferenced (Rangefinder);
   begin
      case Chip is
         when Detect.MT =>
            Found := Adaflight.STM32.MT.Present;
            Reported := Detect.Delay_Ms (Natural'Min (Detect.Delay_Ms'Last, Adaflight.STM32.MT.Delay_Ms));
            D.Gyro_Delay_Us := Adaflight.MT_Sensor.Flow_Gyro_Delay_Us;
         when Detect.UPT1 =>
            declare
               Delay_Ms      : Natural;
               Gyro_Delay_Us : Interfaces.Unsigned_32;
            begin
               Adaflight.STM32.Rangefinder.Detect_UPT1_Flow (D.Flow_Uart, Found, Delay_Ms, Gyro_Delay_Us);
               Reported := Detect.Delay_Ms (Natural'Min (Detect.Delay_Ms'Last, Delay_Ms));
               D.Gyro_Delay_Us := Core.Gyro_Delay (Interfaces.Unsigned_32'Min (Core.Gyro_Delay'Last, Gyro_Delay_Us));
            end;
      end case;
      if Found then
         D.Kind := Chip;
      end if;
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
      Dev.Flow_Uart := O.Opticalflow_Uart;
      Probe.Detect
        (Dev, Adaflight.Build_Features.Rangefinder, O.Opticalflow_Hardware, C.Rangefinder_Config.Rangefinder_Hardware,
         Detected_Id, Found);
      if Found then
         Hardware_Id := Detected_Id;
         Core.Init
           (Sensor, (Rotation_Degrees => O.Rotation, Flip_X => O.Flip_X /= 0),
            Rotation_Cos  => Unit (Ada.Numerics.Elementary_Functions.Cos (Radians)),
            Rotation_Sin  => Unit (Ada.Numerics.Elementary_Functions.Sin (Radians)),
            Gyro_Delay_Us => Dev.Gyro_Delay_Us,
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

   procedure Update is
   begin
      if Found and then Dev.Kind = Detect.UPT1 then
         Adaflight.STM32.Rangefinder.Update_UPT1;
      end if;
   end Update;

   procedure Process is
   begin
      if Found then
         Core.Process
           (Sensor,
            (if Dev.Kind = Detect.UPT1 then Adaflight.STM32.Rangefinder.UPT1_Flow else Adaflight.STM32.MT.Flow_Sample),
            Roll_Dps, Pitch_Dps);
         Adaflight.Optical_Flow_Debug.Record_Process (Adaflight.STM32.Debug_Values.State, Sensor);
      end if;
   end Process;

   function Readings return Adaflight.Optical_Flow.Sensor is (Sensor);

end Adaflight.STM32.Optical_Flow;
