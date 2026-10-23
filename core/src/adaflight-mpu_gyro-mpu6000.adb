package body Adaflight.MPU_Gyro.MPU6000 with SPARK_Mode is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;

   Config_Register        : constant Byte := 16#1A#;
   Sample_Rate_Register   : constant Byte := 16#19#;
   Gyro_Config_Register   : constant Byte := 16#1B#;
   Accel_Config_Register  : constant Byte := 16#1C#;
   Pin_Config_Register    : constant Byte := 16#37#;
   Interrupt_Register     : constant Byte := 16#38#;
   Signal_Reset_Register  : constant Byte := 16#68#;
   User_Control_Register  : constant Byte := 16#6A#;
   Power_1_Register       : constant Byte := 16#6B#;
   Power_2_Register       : constant Byte := 16#6C#;
   Who_Am_I_Register      : constant Byte := 16#75#;
   Product_Register       : constant Byte := 16#0C#;
   Who_Am_I               : constant Byte := 16#68#;
   Device_Reset           : constant Byte := 16#80#;
   Signal_Paths           : constant Byte := 16#04# or 16#02# or 16#01#;
   Clock_PLL_Gyro_Z       : constant Byte := 16#03#;
   I2C_Disable            : constant Byte := 16#10#;
   Full_Scale_2000        : constant Byte := 3 * 8;
   Full_Scale_16G         : constant Byte := 3 * 8;
   Any_Read_Clears        : constant Byte := 16#10#;
   Data_Ready_Enable      : constant Byte := 16#01#;
   Max_SPI_Clock_Hz       : constant := 20_000_000;
   Short_Threshold_Us     : constant := 82;

   function Known_Revision (Product : Byte) return Boolean is
     (Product in 16#14# .. 16#18# | 16#54# .. 16#5A#);

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Identity : Byte;
      Product  : Byte;
   begin
      Write_Register (D, Power_1_Register, Device_Reset);
      Delay_Ms (D, 100);
      Write_Register (D, Signal_Reset_Register, Signal_Paths);
      Delay_Ms (D, 100);
      Read_Register (D, Who_Am_I_Register, Identity);
      Delay_Us (D, 1);
      Sensor := No_Sensor;
      if Identity = Who_Am_I then
         Read_Register (D, Product_Register, Product);
         if Known_Revision (Product) then
            Sensor := Sensor_MPU6000;
         end if;
      end if;
   end Detect;

   procedure Gyro_Detect (S : in out State; Found : out Boolean; Scale : out Float) is
   begin
      Scale := 0.0;
      if S.Sensor /= Sensor_MPU6000 then
         Found := False;
         return;
      end if;
      Scale := Gyro_Scale;
      S.Short_Period := Interfaces.Integer_32 (Micros_To_Cycles (Short_Threshold_Us) mod 2 ** 31);
      Found := True;
   end Gyro_Detect;

   procedure Acc_And_Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte) is
   begin
      Write_Register (D, Power_1_Register, Clock_PLL_Gyro_Z);
      Delay_Us (D, 15);
      Write_Register (D, User_Control_Register, I2C_Disable);
      Delay_Us (D, 15);
      Write_Register (D, Power_2_Register, 0);
      Delay_Us (D, 15);
      Write_Register (D, Sample_Rate_Register, Divider_Drops);
      Delay_Us (D, 15);
      Write_Register (D, Gyro_Config_Register, Full_Scale_2000);
      Delay_Us (D, 15);
      Write_Register (D, Accel_Config_Register, Full_Scale_16G);
      Delay_Us (D, 15);
      Write_Register (D, Pin_Config_Register, Any_Read_Clears);
      Delay_Us (D, 15);
      Write_Register (D, Interrupt_Register, Data_Ready_Enable);
      Delay_Us (D, 15);
      S.Temp_Scale := 1.0 / 340.0;
      S.Temp_Zero := 36.53;
   end Acc_And_Gyro_Init;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte) is
      Divisor   : Interfaces.Unsigned_16;
      Unused_OK : Boolean;
   begin
      Init (D, S);
      Acc_And_Gyro_Init (D, S, Divider_Drops);
      Write_Register (D, Config_Register, Gyro_DLPF (S));
      Delay_Us (D, 1);
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Read_Gyro (D, S, Unused_OK);
      if S.Raw (1) mod 256 = 255 and then S.Raw (0) mod 256 = 255 then
         Failure (D);
      end if;
   end Gyro_Init;

end Adaflight.MPU_Gyro.MPU6000;
