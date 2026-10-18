package body Adaflight.MPU_Gyro.ICM20689 with SPARK_Mode is

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
   Accel_Temp_Reset      : constant Byte := 16#02# or 16#01#;
   I2C_Disable           : constant Byte := 16#10#;
   Clock_PLL             : constant Byte := 16#01#;
   Full_Scale_2000       : constant Byte := 3 * 8;
   Full_Scale_16G        : constant Byte := 3 * 8;
   Any_Read_Clears       : constant Byte := 16#10#;
   Data_Ready_Enable     : constant Byte := 16#01#;
   Max_SPI_Clock_Hz      : constant := 8_000_000;
   Clock_Settle_Us       : constant := 120;

   function Sensor_Of (Identity : Byte) return Byte is
     (case Identity is
         when 16#AC# => Sensor_ICM20601,
         when 16#12# => Sensor_ICM20602,
         when 16#AF# => Sensor_ICM20608,
         when 16#98# => Sensor_ICM20689,
         when others => No_Sensor)
     with Global => null;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Identity : Byte;
   begin
      Write_Register (D, Power_1_Register, Device_Reset);
      Delay_Ms (D, 100);
      Read_Register (D, Who_Am_I_Register, Identity);
      Sensor := Sensor_Of (Identity);
      if Sensor /= No_Sensor then
         Write_Register (D, User_Control_Register, I2C_Disable);
         Write_Register (D, Signal_Reset_Register, Accel_Temp_Reset);
         Delay_Ms (D, 100);
      end if;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : out Float) is
   begin
      Found := S.Sensor in Sensor_ICM20601 .. Sensor_ICM20608 | Sensor_ICM20689;
      Scale := (if Found then Gyro_Scale else 0.0);
   end Gyro_Detect;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte) is
      Divisor : Interfaces.Unsigned_16;
   begin
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Init (D, S);
      Write_Register (D, Power_1_Register, Clock_PLL);
      Delay_Us (D, Clock_Settle_Us);
      Write_Register (D, Gyro_Config_Register, Full_Scale_2000);
      Write_Register (D, Accel_Config_Register, Full_Scale_16G);
      Write_Register (D, Config_Register, Gyro_DLPF (S));
      Write_Register (D, Sample_Rate_Register, Divider_Drops);
      Write_Register (D, Pin_Config_Register, Any_Read_Clears);
      Write_Register (D, Interrupt_Register, Data_Ready_Enable);
      S.Temp_Scale := 0.003;
      S.Temp_Zero := 25.0;
   end Gyro_Init;

end Adaflight.MPU_Gyro.ICM20689;
