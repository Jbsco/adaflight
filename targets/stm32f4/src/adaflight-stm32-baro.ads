--  The board's barometer: detected on the bus the configuration names at
--  the start, read in the 40 Hz cycle the task schedules, and its altitude
--  kept for the estimator, the flight log and the replies.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Scheduler;
package Adaflight.STM32.Baro is
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   function Detected return Boolean;
   --  The detected hardware as the configuration numbers it, and the bus
   --  the status names: 1 for I2C and 2 for SPI, its number and the address.
   function Hardware return Interfaces.Unsigned_8;
   function Bus_Type return Interfaces.Unsigned_8;
   function Bus_Number return Natural;
   function Bus_Address return Interfaces.Unsigned_8;
   --  One call of the read cycle, with the time to its next call.
   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   --  The power-on calibration, the ground level, and the altitude.
   procedure Start_Calibration;
   procedure Set_Ground_Level;
   function Calibrated return Boolean;
   function Altitude_Cm return Float;
   function Temperature_Centi return Interfaces.Integer_32;
end Adaflight.STM32.Baro;
