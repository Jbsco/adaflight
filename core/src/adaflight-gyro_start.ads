--  A gyro sensor's start: the gyro and accelerometer sample rates and the
--  rate code from the detected sensor and the hardware filter setting, the
--  divider drops the drivers no longer use, the overflow protection by gyro
--  hardware, and the data ready check that takes the flag.
with Interfaces;

package Adaflight.Gyro_Start with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;

   subtype Byte is Interfaces.Unsigned_8;

   Rate_3200_Hz : constant Byte := 2;
   Rate_6400_Hz : constant Byte := 3;
   Rate_6664_Hz : constant Byte := 4;
   Rate_8_kHz   : constant Byte := 5;
   Rate_9_kHz   : constant Byte := 6;

   Divider_Drops : constant Byte := 0;

   type Rates is record
      Rate_Code : Byte := Rate_8_kHz;
      Gyro_Hz   : Natural range 0 .. 65_535 := 8_000;
      Acc_Hz    : Natural range 0 .. 65_535 := 1_000;
   end record;

   function Sample_Rates (Sensor : Byte; Hardware_LPF : Byte) return Rates
     with Global => null;

   function Overflow_Protected (Hardware : Byte) return Boolean
     with Global => null;

   procedure Check_Update (Data_Ready : in out Boolean; Updated : out Boolean)
     with Global => null, Post => Updated = Data_Ready'Old and then not Data_Ready;

end Adaflight.Gyro_Start;
