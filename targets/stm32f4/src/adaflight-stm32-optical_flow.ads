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
   --  The driver's sample delay in milliseconds, and whether its latest
   --  sample is within the hardware timeout.
   function Delay_Ms return Natural;
   function Healthy return Boolean;
   --  The latest processed sample: its quality, time stamp, rates in
   --  radians per second and their validity, and the driver's gyro delay.
   type Latest_Sample is record
      Quality       : Interfaces.Integer_16 := Adaflight.Optical_Flow.No_New_Data;
      Time_Stamp_Us : Interfaces.Unsigned_32 := 0;
      Rate_X        : Float := 0.0;
      Rate_Y        : Float := 0.0;
      Valid_X       : Boolean := False;
      Valid_Y       : Boolean := False;
      Gyro_Delay_Us : Interfaces.Unsigned_32 := 0;
   end record;
   function Latest return Latest_Sample;
   --  The filtered gyro rates about roll and pitch the next process reads.
   procedure Set_Gyro (Roll_Rate, Pitch_Rate : Float);
   procedure Update;
   procedure Process;
   function Readings return Adaflight.Optical_Flow.Sensor;
end Adaflight.STM32.Optical_Flow;
