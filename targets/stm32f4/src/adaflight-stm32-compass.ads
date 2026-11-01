--  The board's compass: the chip the configuration names found over its
--  I2C or SPI bus, or the simulator's virtual compass on a simulated image,
--  then read by the compass task into the core's compass state, whose
--  calibration a stick command or an MSP command starts.
with Interfaces;
with Adaflight.Compass;
with Adaflight.Config_Groups;
with Adaflight.Scheduler;
with Adaflight.Vectors;
package Adaflight.STM32.Compass is
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   function Detected return Boolean;
   function Hardware return Interfaces.Unsigned_8;
   function Bus_Type return Interfaces.Unsigned_8;
   function Bus_Number return Natural;
   function Bus_Address return Interfaces.Unsigned_8;
   --  One compass task call: a read when the chip has data, into the core's
   --  read cycle, which sets the time to the next call.
   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   --  The gyro rates the calibration watches for movement, degrees per second.
   procedure Set_Gyro (Rates : Adaflight.Vectors.Vector3);
   procedure Start_Calibration;
   function Calibrated return Boolean;
   function Enabled_And_Calibrated return Boolean;
   --  The aligned, zeroed field of the last read.
   function Field return Adaflight.Vectors.Vector3;
   --  The beep a read asked for since the last take, once.
   procedure Take_Beep (B : out Adaflight.Compass.Beep);
   --  Whether a calibration ended since the last take, with its zero.
   procedure Take_Save (Requested : out Boolean; Zero : out Adaflight.Compass.Zero_Offsets);
end Adaflight.STM32.Compass;
