package body Adaflight.Acc_Detect with SPARK_Mode is

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

   Acc_MPU6050     : constant Byte := 2;
   Acc_MPU6000     : constant Byte := 3;
   Acc_MPU6500     : constant Byte := 4;
   Acc_MPU9250     : constant Byte := 5;
   Acc_ICM20601    : constant Byte := 6;
   Acc_ICM20602    : constant Byte := 7;
   Acc_ICM20608G   : constant Byte := 8;
   Acc_ICM20649    : constant Byte := 9;
   Acc_ICM20689    : constant Byte := 10;
   Acc_ICM42605    : constant Byte := 11;
   Acc_ICM42688P   : constant Byte := 12;
   Acc_BMI160      : constant Byte := 13;
   Acc_BMI270      : constant Byte := 14;
   Acc_LSM6DSO     : constant Byte := 15;
   Acc_LSM6DSV16X  : constant Byte := 16;
   Acc_IIM42653    : constant Byte := 17;
   Acc_ICM45605    : constant Byte := 18;
   Acc_ICM45686    : constant Byte := 19;
   Acc_ICM40609D   : constant Byte := 20;
   Acc_IIM42652    : constant Byte := 21;
   Acc_LSM6DSK320X : constant Byte := 22;
   Acc_ICM42622P   : constant Byte := 23;
   Acc_ICM42686P   : constant Byte := 24;
   Acc_ICM56686    : constant Byte := 25;
   Acc_BMI423      : constant Byte := 26;
   Acc_Virtual     : constant Byte := 27;
   Acc_LSM6DSV32X  : constant Byte := 28;

   function Scan (Build : Driver_Set; Start : Byte; Sensor : Byte) return Byte is
      Started : Boolean := Start = Hardware_Default;
   begin
      if Build (MPU6050) then
         Started := Started or else Start = Acc_MPU6050;
         if Started and then Sensor = MPU_60x0 then
            return Acc_MPU6050;
         end if;
      end if;
      if Build (MPU6000) then
         Started := Started or else Start = Acc_MPU6000;
         if Started and then Sensor = MPU_60x0_SPI then
            return Acc_MPU6000;
         end if;
      end if;
      if Build (MPU9250) then
         Started := Started or else Start = Acc_MPU9250;
         if Started and then Sensor = MPU_9250_SPI then
            return Acc_MPU9250;
         end if;
      end if;
      if Build (MPU6500) or else Build (MPU6500_SPI) then
         Started := Started or else Start in Acc_MPU6500 | Acc_ICM20601 | Acc_ICM20602 | Acc_ICM20608G;
         if Started and then Build (MPU6500_SPI) then
            case Sensor is
               when MPU_65xx_SPI =>
                  return Acc_MPU6500;
               when MPU_9250_SPI =>
                  return Acc_MPU9250;
               when ICM_20601_SPI =>
                  return Acc_ICM20601;
               when ICM_20602_SPI =>
                  return Acc_ICM20602;
               when ICM_20608_SPI =>
                  return Acc_ICM20608G;
               when others =>
                  null;
            end case;
         elsif Started and then Sensor = MPU_65xx_I2C then
            return Acc_MPU6500;
         end if;
      end if;
      if Build (ICM20649) then
         Started := Started or else Start = Acc_ICM20649;
         if Started and then Sensor = ICM_20649_SPI then
            return Acc_ICM20649;
         end if;
      end if;
      if Build (ICM20689) then
         Started := Started or else Start = Acc_ICM20689;
         if Started and then Sensor in ICM_20602_SPI | ICM_20689_SPI then
            return Acc_ICM20689;
         end if;
      end if;
      if Build (ICM426xx) then
         Started := Started
           or else Start in Acc_ICM42605 | Acc_ICM42622P | Acc_ICM42686P | Acc_ICM42688P | Acc_IIM42652 | Acc_IIM42653;
         if Started then
            case Sensor is
               when ICM_42605_SPI =>
                  return Acc_ICM42605;
               when ICM_42622P_SPI =>
                  return Acc_ICM42622P;
               when ICM_42686P_SPI =>
                  return Acc_ICM42686P;
               when ICM_42688P_SPI =>
                  return Acc_ICM42688P;
               when IIM_42652_SPI =>
                  return Acc_IIM42652;
               when IIM_42653_SPI =>
                  return Acc_IIM42653;
               when others =>
                  null;
            end case;
         end if;
      end if;
      if Build (ICM456xx) then
         Started := Started or else Start in Acc_ICM45686 | Acc_ICM45605;
         if Started then
            case Sensor is
               when ICM_45686_SPI =>
                  return Acc_ICM45686;
               when ICM_45605_SPI =>
                  return Acc_ICM45605;
               when others =>
                  null;
            end case;
         end if;
      end if;
      if Build (ICM56686) then
         Started := Started or else Start = Acc_ICM56686;
         if Started and then Sensor = ICM_56686_SPI then
            return Acc_ICM56686;
         end if;
      end if;
      if Build (BMI160) then
         Started := Started or else Start = Acc_BMI160;
         if Started and then Sensor = BMI_160_SPI then
            return Acc_BMI160;
         end if;
      end if;
      if Build (BMI270) then
         Started := Started or else Start = Acc_BMI270;
         if Started and then Sensor = BMI_270_SPI then
            return Acc_BMI270;
         end if;
      end if;
      if Build (BMI423) then
         Started := Started or else Start = Acc_BMI423;
         if Started and then Sensor = BMI_423_SPI then
            return Acc_BMI423;
         end if;
      end if;
      if Build (LSM6DSO) then
         Started := Started or else Start = Acc_LSM6DSO;
         if Started and then Sensor = LSM6DSO_SPI then
            return Acc_LSM6DSO;
         end if;
      end if;
      if Build (LSM6DSV16X) or else Build (LSM6DSV32X) then
         Started := Started
           or else (Build (LSM6DSV16X) and then Start = Acc_LSM6DSV16X)
           or else (Build (LSM6DSV32X) and then Start = Acc_LSM6DSV32X);
         if Started and then Build (LSM6DSV16X) and then Sensor = LSM6DSV16X_SPI then
            return Acc_LSM6DSV16X;
         elsif Started and then Build (LSM6DSV32X) and then Sensor = LSM6DSV32X_SPI then
            return Acc_LSM6DSV32X;
         end if;
      end if;
      if Build (ICM40609D) then
         Started := Started or else Start = Acc_ICM40609D;
         if Started and then Sensor = ICM_40609_SPI then
            return Acc_ICM40609D;
         end if;
      end if;
      if Build (LSM6DSK320X) then
         Started := Started or else Start = Acc_LSM6DSK320X;
         if Started and then Sensor = LSM6DSK320X_SPI then
            return Acc_LSM6DSK320X;
         end if;
      end if;
      if Build (Virtual) and then (Started or else Start = Acc_Virtual) then
         return Acc_Virtual;
      end if;
      return Hardware_None;
   end Scan;

   procedure Detect
     (Build      : Driver_Set;
      Configured : Byte;
      Sensor     : Byte;
      Detected   : in out Byte;
      Found      : out Boolean)
   is
      Hardware : Byte := Scan (Build, Configured, Sensor);
   begin
      if Hardware = Hardware_None and then Configured /= Hardware_Default and then Configured /= Hardware_None then
         Hardware := Scan (Build, Hardware_Default, Sensor);
      end if;
      Found := Hardware /= Hardware_None;
      if Found then
         Detected := Hardware;
      end if;
   end Detect;

end Adaflight.Acc_Detect;
