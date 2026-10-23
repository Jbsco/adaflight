package body Adaflight.Compass_Detect with SPARK_Mode is

   Mag_HMC5883  : constant Byte := 2;
   Mag_AK8975   : constant Byte := 3;
   Mag_AK8963   : constant Byte := 4;
   Mag_QMC5883L : constant Byte := 5;
   Mag_LIS2MDL  : constant Byte := 6;
   Mag_LIS3MDL  : constant Byte := 7;
   Mag_IST8310  : constant Byte := 9;
   Mag_MMC560X  : constant Byte := 10;
   Mag_QMC5883P : constant Byte := 11;
   Mag_BMM350   : constant Byte := 13;
   Mag_AK9916   : constant Byte := 14;

   function Named (Chip : Scanned) return Byte is
     (case Chip is
         when HMC5883  => Mag_HMC5883,
         when LIS2MDL  => Mag_LIS2MDL,
         when LIS3MDL  => Mag_LIS3MDL,
         when AK9916   => Mag_AK9916,
         when AK8975   => Mag_AK8975,
         when AK8963   => Mag_AK8963,
         when QMC5883L => Mag_QMC5883L,
         when QMC5883P => Mag_QMC5883P,
         when IST8310  => Mag_IST8310,
         when MMC560X  => Mag_MMC560X,
         when BMM350   => Mag_BMM350);

   function Starts_At (Chip : Scanned; Hardware : Byte) return Boolean is (Hardware = Named (Chip));

end Adaflight.Compass_Detect;
