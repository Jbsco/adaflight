--  Rangefinder detection: the rangefinder drivers, the configured hardware each
--  one serves, and the period a found driver gives the rangefinder task.
with Interfaces;

package Adaflight.Rangefinder_Detect with SPARK_Mode, Pure is

   subtype Byte is Interfaces.Unsigned_8;

   type Driver is (HCSR04, TF, MT, Nooploop, UPT1);

   Hardware_None : constant Byte := 0;
   Hardware_Last : constant Byte := 15;

   subtype Delay_Ms is Natural range 0 .. 65_535;

   function Has_Driver (Hardware : Byte) return Boolean is (Hardware in 1 .. Hardware_Last)
     with Global => null;

   function Driver_Of (Hardware : Byte) return Driver
     with Global => null,
          Pre    => Has_Driver (Hardware);

   --  The HC-SR04 and the UPT-1 run at their own periods, the others at the
   --  delay their driver reports.
   function Period_Ms (Chip : Driver; Reported : Delay_Ms) return Delay_Ms
     with Global => null;

end Adaflight.Rangefinder_Detect;
