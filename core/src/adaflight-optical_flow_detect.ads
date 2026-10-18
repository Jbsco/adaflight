--  Optical flow detection: the optical flow drivers, which come with the
--  rangefinder drivers of the same modules, and the hardware each one serves.
with Interfaces;

package Adaflight.Optical_Flow_Detect with SPARK_Mode, Pure is

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is (MT, UPT1);

   Hardware_None : constant Byte := 0;
   Hardware_MT   : constant Byte := 1;
   Hardware_UPT1 : constant Byte := 2;

   subtype Delay_Ms is Natural range 0 .. 65_535;

end Adaflight.Optical_Flow_Detect;
