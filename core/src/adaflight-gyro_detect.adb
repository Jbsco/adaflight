package body Adaflight.Gyro_Detect with SPARK_Mode is

   MPU_60x0        : constant Byte := 2;
   MPU_60x0_SPI    : constant Byte := 3;
   MPU_65xx_I2C    : constant Byte := 4;
   MPU_65xx_SPI    : constant Byte := 5;
   MPU_9250_SPI    : constant Byte := 6;
   ICM_20601_SPI   : constant Byte := 7;
   ICM_20602_SPI   : constant Byte := 8;
   ICM_20608_SPI   : constant Byte := 9;
   ICM_20649_SPI   : constant Byte := 10;
   ICM_20689_SPI   : constant Byte := 11;
   ICM_42605_SPI   : constant Byte := 12;
   ICM_42622P_SPI  : constant Byte := 13;
   ICM_42686P_SPI  : constant Byte := 14;
   ICM_42688P_SPI  : constant Byte := 15;
   IIM_42652_SPI   : constant Byte := 16;
   IIM_42653_SPI   : constant Byte := 17;
   BMI_160_SPI     : constant Byte := 18;
   BMI_270_SPI     : constant Byte := 19;
   BMI_423_SPI     : constant Byte := 20;
   LSM6DSO_SPI     : constant Byte := 21;
   LSM6DSV16X_SPI  : constant Byte := 23;
   LSM6DSK320X_SPI : constant Byte := 24;
   ICM_45605_SPI   : constant Byte := 25;
   ICM_45686_SPI   : constant Byte := 26;
   ICM_56686_SPI   : constant Byte := 27;
   ICM_40609_SPI   : constant Byte := 28;
   LSM6DSV32X_SPI  : constant Byte := 29;

   Gyro_MPU6050     : constant Byte := 2;
   Gyro_L3GD20      : constant Byte := 3;
   Gyro_MPU6000     : constant Byte := 4;
   Gyro_MPU6500     : constant Byte := 5;
   Gyro_MPU9250     : constant Byte := 6;
   Gyro_ICM20601    : constant Byte := 7;
   Gyro_ICM20602    : constant Byte := 8;
   Gyro_ICM20608G   : constant Byte := 9;
   Gyro_ICM20649    : constant Byte := 10;
   Gyro_ICM20689    : constant Byte := 11;
   Gyro_ICM42605    : constant Byte := 12;
   Gyro_ICM42688P   : constant Byte := 13;
   Gyro_BMI160      : constant Byte := 14;
   Gyro_BMI270      : constant Byte := 15;
   Gyro_LSM6DSO     : constant Byte := 16;
   Gyro_LSM6DSV16X  : constant Byte := 17;
   Gyro_IIM42653    : constant Byte := 18;
   Gyro_ICM45605    : constant Byte := 19;
   Gyro_ICM45686    : constant Byte := 20;
   Gyro_ICM40609D   : constant Byte := 21;
   Gyro_IIM42652    : constant Byte := 22;
   Gyro_LSM6DSK320X : constant Byte := 23;
   Gyro_ICM42622P   : constant Byte := 24;
   Gyro_ICM42686P   : constant Byte := 25;
   Gyro_ICM56686    : constant Byte := 26;
   Gyro_BMI423      : constant Byte := 27;
   Gyro_Virtual     : constant Byte := 28;
   Gyro_LSM6DSV32X  : constant Byte := 29;

   function Hardware (Build : Driver_Set; Sensor : Byte) return Byte is
   begin
      if Build (MPU6050) and then Sensor = MPU_60x0 then
         return Gyro_MPU6050;
      elsif Build (L3GD20) then
         return Gyro_L3GD20;
      elsif Build (MPU6000) and then Sensor = MPU_60x0_SPI then
         return Gyro_MPU6000;
      end if;
      if Build (MPU6500_SPI) then
         case Sensor is
            when MPU_65xx_SPI =>
               return Gyro_MPU6500;
            when MPU_9250_SPI =>
               return Gyro_MPU9250;
            when ICM_20601_SPI =>
               return Gyro_ICM20601;
            when ICM_20602_SPI =>
               return Gyro_ICM20602;
            when ICM_20608_SPI =>
               return Gyro_ICM20608G;
            when others =>
               null;
         end case;
      elsif Build (MPU6500) and then Sensor = MPU_65xx_I2C then
         return Gyro_MPU6500;
      end if;
      if Build (MPU9250) and then Sensor = MPU_9250_SPI then
         return Gyro_MPU9250;
      elsif Build (ICM20649) and then Sensor = ICM_20649_SPI then
         return Gyro_ICM20649;
      elsif Build (ICM20689) and then Sensor in ICM_20601_SPI | ICM_20602_SPI | ICM_20608_SPI | ICM_20689_SPI then
         return Gyro_ICM20689;
      end if;
      if Build (ICM426xx) then
         case Sensor is
            when ICM_42605_SPI =>
               return Gyro_ICM42605;
            when ICM_42622P_SPI =>
               return Gyro_ICM42622P;
            when ICM_42688P_SPI =>
               return Gyro_ICM42688P;
            when ICM_42686P_SPI =>
               return Gyro_ICM42686P;
            when IIM_42652_SPI =>
               return Gyro_IIM42652;
            when IIM_42653_SPI =>
               return Gyro_IIM42653;
            when others =>
               null;
         end case;
      end if;
      if Build (ICM456xx) then
         case Sensor is
            when ICM_45686_SPI =>
               return Gyro_ICM45686;
            when ICM_45605_SPI =>
               return Gyro_ICM45605;
            when others =>
               null;
         end case;
      end if;
      if Build (ICM56686) and then Sensor = ICM_56686_SPI then
         return Gyro_ICM56686;
      elsif Build (BMI160) and then Sensor = BMI_160_SPI then
         return Gyro_BMI160;
      elsif Build (BMI270) and then Sensor = BMI_270_SPI then
         return Gyro_BMI270;
      elsif Build (BMI423) and then Sensor = BMI_423_SPI then
         return Gyro_BMI423;
      elsif Build (LSM6DSO) and then Sensor = LSM6DSO_SPI then
         return Gyro_LSM6DSO;
      elsif Build (LSM6DSV16X) and then Sensor = LSM6DSV16X_SPI then
         return Gyro_LSM6DSV16X;
      elsif Build (LSM6DSV32X) and then Sensor = LSM6DSV32X_SPI then
         return Gyro_LSM6DSV32X;
      elsif Build (LSM6DSK320X) and then Sensor = LSM6DSK320X_SPI then
         return Gyro_LSM6DSK320X;
      elsif Build (ICM40609D) and then Sensor = ICM_40609_SPI then
         return Gyro_ICM40609D;
      elsif Build (Virtual) then
         return Gyro_Virtual;
      end if;
      return Hardware_None;
   end Hardware;

   procedure Detect_Sensor
     (Build         : Driver_Set;
      Chip_Found    : Boolean;
      Sensor        : Byte;
      Gyro_Hardware : in out Byte;
      Found         : out Boolean) is
   begin
      if Needs_Chip (Build) and then not Chip_Found then
         Found := False;
         return;
      end if;
      Gyro_Hardware := Hardware (Build, Sensor);
      Found := Gyro_Hardware /= Hardware_None;
   end Detect_Sensor;

end Adaflight.Gyro_Detect;
