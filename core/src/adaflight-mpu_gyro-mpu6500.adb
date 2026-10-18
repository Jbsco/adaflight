package body Adaflight.MPU_Gyro.MPU6500 with SPARK_Mode is

   Config_Register       : constant Byte := 16#1A#;
   Sample_Rate_Register  : constant Byte := 16#19#;
   Gyro_Config_Register  : constant Byte := 16#1B#;
   Accel_Config_Register : constant Byte := 16#1C#;
   Pin_Config_Register   : constant Byte := 16#37#;
   Interrupt_Register    : constant Byte := 16#38#;
   Signal_Reset_Register : constant Byte := 16#68#;
   User_Control_Register : constant Byte := 16#6A#;
   Power_1_Register      : constant Byte := 16#6B#;
   Who_Am_I_Register     : constant Byte := 16#75#;
   Device_Reset          : constant Byte := 16#80#;
   Signal_Paths          : constant Byte := 16#04# or 16#02# or 16#01#;
   Clock_PLL             : constant Byte := 16#01#;
   Full_Scale_2000       : constant Byte := 3;
   Full_Scale_16G        : constant Byte := 3;
   High_Range_2000       : constant Byte := 2;
   High_Range_4000       : constant Byte := 3;
   High_Range_16G        : constant Byte := 2;
   Any_Read_Clears       : constant Byte := 16#10#;
   Raw_Ready_Enable      : constant Byte := 16#01#;
   I2C_Disable           : constant Byte := 16#10#;
   Max_SPI_Clock_Hz      : constant := 20_000_000;
   Sensor_ICM42605       : constant Byte := 12;
   Sensor_ICM42686P      : constant Byte := 14;
   Sensor_ICM42688P      : constant Byte := 15;

   function Sensor_Of (Identity : Byte) return Byte is
     (case Identity is
         when 16#70# => Sensor_MPU6500,
         when 16#71# | 16#73# => Sensor_MPU9250,
         when 16#AC# => Sensor_ICM20601,
         when 16#12# => Sensor_ICM20602,
         when 16#AF# => Sensor_ICM20608,
         when 16#42# => Sensor_ICM42605,
         when 16#47# => Sensor_ICM42688P,
         when 16#44# => Sensor_ICM42686P,
         when others => No_Sensor)
     with Global => null;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Identity : Byte;
   begin
      Read_Register (D, Who_Am_I_Register, Identity);
      Sensor := Sensor_Of (Identity);
   end Detect;

   procedure Gyro_Detect (S : State; High_Range : Boolean; Found : out Boolean; Scale : out Float) is
   begin
      Found := Acc_Detect (S);
      Scale := 0.0;
      if Found then
         Scale := (if S.Sensor = Sensor_ICM20601 and then High_Range then 4000.0 / 32768.0 else 2000.0 / 32768.0);
      end if;
   end Gyro_Detect;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; High_Range : Boolean; Divider_Drops : Byte) is
      Gyro_Range  : Byte := Full_Scale_2000;
      Accel_Range : Byte := Full_Scale_16G;
      Divisor     : Interfaces.Unsigned_16;
   begin
      Init (D, S);
      if S.Sensor = Sensor_ICM20601 then
         Gyro_Range := (if High_Range then High_Range_4000 else High_Range_2000);
         Accel_Range := High_Range_16G;
      end if;
      Bus_Write_Register (D, Power_1_Register, Device_Reset);
      Delay_Ms (D, 100);
      Bus_Write_Register (D, Signal_Reset_Register, Signal_Paths);
      Delay_Ms (D, 100);
      Bus_Write_Register (D, Power_1_Register, 0);
      Delay_Ms (D, 100);
      Bus_Write_Register (D, Power_1_Register, Clock_PLL);
      Delay_Ms (D, 15);
      Bus_Write_Register (D, Gyro_Config_Register, Gyro_Range * 8);
      Delay_Ms (D, 15);
      Bus_Write_Register (D, Accel_Config_Register, Accel_Range * 8);
      Delay_Ms (D, 15);
      Bus_Write_Register (D, Config_Register, Gyro_DLPF (S));
      Delay_Ms (D, 15);
      Bus_Write_Register (D, Sample_Rate_Register, Divider_Drops);
      Delay_Ms (D, 100);
      Bus_Write_Register (D, Pin_Config_Register, Any_Read_Clears);
      Delay_Ms (D, 15);
      Bus_Write_Register (D, Interrupt_Register, Raw_Ready_Enable);
      Delay_Ms (D, 15);
      S.Temp_Scale := 1.0 / 340.0;
      S.Temp_Zero := 36.53;
      Write_Register (D, User_Control_Register, I2C_Disable);
      Delay_Ms (D, 100);
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Delay_Us (D, 1);
   end Gyro_Init;

end Adaflight.MPU_Gyro.MPU6500;
