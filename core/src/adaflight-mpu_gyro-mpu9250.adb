package body Adaflight.MPU_Gyro.MPU9250 with SPARK_Mode is
   use type Interfaces.Integer_16;

   Sample_Rate_Register  : constant Byte := 16#19#;
   Config_Register       : constant Byte := 16#1A#;
   Gyro_Config_Register  : constant Byte := 16#1B#;
   Accel_Config_Register : constant Byte := 16#1C#;
   Pin_Config_Register   : constant Byte := 16#37#;
   Interrupt_Register    : constant Byte := 16#38#;
   Power_1_Register      : constant Byte := 16#6B#;
   Who_Am_I_Register     : constant Byte := 16#75#;
   Device_Reset          : constant Byte := 16#80#;
   Clock_PLL             : constant Byte := 16#01#;
   Full_Scale_2000       : constant Byte := 3;
   Full_Scale_16G        : constant Byte := 3;
   --  Interrupt status cleared by any read, I2C bypass on.
   Pin_Config            : constant Byte := 16#12#;
   Raw_Ready_Enable      : constant Byte := 16#01#;
   Read_Flag             : constant Byte := 16#80#;
   Attempts              : constant := 21;
   Max_SPI_Clock_Hz      : constant := 20_000_000;

   procedure Write (D : in out SPI_Device; Register : Byte; Value : Byte) is
   begin
      Delay_Us (D, 1);
      Write_Buffer (D, Register, Value);
      Delay_Us (D, 1);
   end Write;

   procedure Slow_Read (D : in out SPI_Device; Register : Byte; Value : out Byte) is
   begin
      Delay_Us (D, 1);
      Read_Buffer (D, Register or Read_Flag, Value);
      Delay_Us (D, 1);
   end Slow_Read;

   --  A register written, then read back up to 21 times 100 microseconds after
   --  each write, and written again while it differs.
   procedure Write_Verify (D : in out SPI_Device; Register : Byte; Value : Byte) is
      Read_Back : Byte;
   begin
      Write (D, Register, Value);
      Delay_Us (D, 100);
      for Attempt in 1 .. Attempts loop
         Slow_Read (D, Register, Read_Back);
         exit when Read_Back = Value;
         Write (D, Register, Value);
         Delay_Us (D, 100);
      end loop;
   end Write_Verify;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Identity : Byte;
   begin
      Write (D, Power_1_Register, Device_Reset);
      Sensor := No_Sensor;
      for Attempt in 1 .. Attempts loop
         Delay_Ms (D, 150);
         Read_Register (D, Who_Am_I_Register, Identity);
         if Identity in 16#71# | 16#73# then
            Sensor := Sensor_MPU9250;
            exit;
         end if;
      end loop;
   end Detect;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Divider_Drops : Byte) is
      Divisor   : Interfaces.Unsigned_16;
      Unused_OK : Boolean;
   begin
      Init (D, S);
      Write (D, Power_1_Register, Device_Reset);
      Delay_Ms (D, 50);
      Write_Verify (D, Power_1_Register, Clock_PLL);
      Write_Verify (D, Gyro_Config_Register, Full_Scale_2000 * 8);
      Write_Verify (D, Config_Register, Gyro_DLPF (S));
      Write_Verify (D, Sample_Rate_Register, Divider_Drops);
      Write_Verify (D, Accel_Config_Register, Full_Scale_16G * 8);
      Write_Verify (D, Pin_Config_Register, Pin_Config);
      Write_Verify (D, Interrupt_Register, Raw_Ready_Enable);
      S.Temp_Scale := 2.99517787E-03;
      S.Temp_Zero := 21.0;
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Read_Gyro (D, S, Unused_OK);
      if S.Raw (1) mod 256 = 255 and then S.Raw (0) mod 256 = 255 then
         Failure (D);
      end if;
   end Gyro_Init;

end Adaflight.MPU_Gyro.MPU9250;
