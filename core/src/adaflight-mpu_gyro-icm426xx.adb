package body Adaflight.MPU_Gyro.ICM426xx with SPARK_Mode is

   Bank_Register         : constant Byte := 16#76#;
   Device_Config         : constant Byte := 16#11#;
   Who_Am_I_Register     : constant Byte := 16#75#;
   Power_Register        : constant Byte := 16#4E#;
   Gyro_Config_0         : constant Byte := 16#4F#;
   Accel_Config_0        : constant Byte := 16#50#;
   Gyro_Static_3         : constant Byte := 16#0C#;
   Gyro_Static_4         : constant Byte := 16#0D#;
   Gyro_Static_5         : constant Byte := 16#0E#;
   Accel_Static_2        : constant Byte := 16#03#;
   Accel_Static_3        : constant Byte := 16#04#;
   Accel_Static_4        : constant Byte := 16#05#;
   Filter_Config_0       : constant Byte := 16#52#;
   Interrupt_Config      : constant Byte := 16#14#;
   Interrupt_Config_0    : constant Byte := 16#63#;
   Interrupt_Config_1    : constant Byte := 16#64#;
   Interrupt_Source_0    : constant Byte := 16#65#;
   Interface_Config_1    : constant Byte := 16#4D#;
   Interface_Config_5    : constant Byte := 16#7B#;
   Gyro_Data_Register    : constant Byte := 16#25#;
   Accel_Data_Register   : constant Byte := 16#1F#;
   Temp_Data_Register    : constant Byte := 16#1D#;
   Soft_Reset            : constant Byte := 16#01#;
   Sensors_Off           : constant Byte := 0;
   Sensors_Low_Noise     : constant Byte := 3 + 3 * 4;
   Low_Latency_Filters   : constant Byte := 15 * 16 + 15;
   Pulsed_Push_Pull_High : constant Byte := 16#02# or 16#01#;
   Clear_On_Status_Read  : constant Byte := 0;
   Data_Ready_Int1       : constant Byte := 16#08#;
   Async_Reset           : constant Byte := 16#10#;
   Pulse_8_No_Deassert   : constant Byte := 16#40# or 16#20#;
   AFSR_Mask             : constant Byte := 16#C0#;
   AFSR_Disable          : constant Byte := 16#40#;
   Pin9_Mask             : constant Byte := 16#06#;
   Pin9_Clock_In         : constant Byte := 16#04#;
   Clock_In_Enable       : constant Byte := 16#04#;
   Max_SPI_Clock_Hz      : constant := 24_000_000;
   Detect_Attempts       : constant := 20;

   --  An anti-alias filter: its delta, its square and the shift.
   type AAF_Config is record
      Delt      : Byte;
      Delt_Sqr  : Natural range 0 .. 4095;
      Bit_Shift : Byte range 0 .. 15;
   end record;

   type AAF_Table is array (0 .. 3) of AAF_Config;

   AAF_42688 : constant AAF_Table :=
     ((6, 36, 10), (12, 144, 8), (21, 440, 6), (37, 1376, 4));
   AAF_42605 : constant AAF_Table :=
     ((21, 440, 6), (39, 1536, 4), (63, 3968, 3), (63, 3968, 3));

   type ODR_Table is array (0 .. 3) of Byte;
   ODR_LUT : constant ODR_Table := (3, 4, 5, 6);

   function AAF_Of (Sensor : Byte; Setting : Byte) return AAF_Config is
     (if Sensor = Sensor_ICM42605
      then (if Setting <= 2 then AAF_42605 (Natural (Setting)) else AAF_42605 (0))
      else (if Setting <= 2 then AAF_42688 (Natural (Setting)) else AAF_42688 (0)))
     with Global => null;

   --  The base 2 logarithm rounded down, of at least 1.
   function Log_2 (N : Positive) return Natural is
     (if N >= 256 then 8 elsif N >= 128 then 7 elsif N >= 64 then 6 elsif N >= 32 then 5 elsif N >= 16 then 4
      elsif N >= 8 then 3 elsif N >= 4 then 2 elsif N >= 2 then 1 else 0)
     with Global => null,
          Pre    => N <= 256;

   function Sensor_Of (Identity : Byte) return Byte is
     (case Identity is
         when 16#42# => Sensor_ICM42605,
         when 16#46# => Sensor_ICM42622P,
         when 16#44# => Sensor_ICM42686P,
         when 16#47# => Sensor_ICM42688P,
         when 16#6F# => Sensor_IIM42652,
         when 16#56# => Sensor_IIM42653,
         when others => No_Sensor);

   procedure Set_Bank (D : in out SPI_Device; Bank : Byte) is
   begin
      Write_Register (D, Bank_Register, Bank and 7);
   end Set_Bank;

   procedure Enable_External_Clock (D : in out SPI_Device) is
      Started : Boolean;
      Value   : Byte;
   begin
      Start_Clock_In (D, Started);
      if Started then
         Set_Bank (D, 1);
         Read_Register (D, Interface_Config_5, Value);
         Value := (Value and not Pin9_Mask) or Pin9_Clock_In;
         Write_Register (D, Interface_Config_5, Value);
         Set_Bank (D, 0);
         Read_Register (D, Interface_Config_1, Value);
         Value := Value or Clock_In_Enable;
         Write_Register (D, Interface_Config_1, Value);
      end if;
   end Enable_External_Clock;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Attempts : Natural := Detect_Attempts;
      Identity : Byte;
   begin
      Delay_Ms (D, 1);
      Set_Bank (D, 0);
      Write_Register (D, Device_Config, Soft_Reset);
      Delay_Ms (D, 1);
      Write_Register (D, Power_Register, 0);
      loop
         Delay_Ms (D, 1);
         Read_Register (D, Who_Am_I_Register, Identity);
         Sensor := Sensor_Of (Identity);
         exit when Sensor /= No_Sensor;
         if Attempts = 0 then
            return;
         end if;
         Attempts := Attempts - 1;
      end loop;
      if External_Clock and then Sensor = Sensor_ICM42688P then
         Enable_External_Clock (D);
      end if;
   end Detect;

   procedure Gyro_Detect (S : in out State; Found : out Boolean; Scale : out Float) is
   begin
      Scale := 0.0;
      Found := Is_ICM426xx (S.Sensor);
      if Found then
         Scale := (if S.Sensor = Sensor_IIM42653 then 4000.0 / 32768.0 else 2000.0 / 32768.0);
         S.Temp_Scale := 1.0 / 132.48;
         S.Temp_Zero := 25.0;
      end if;
   end Gyro_Detect;

   procedure Gyro_Init
     (D             : in out SPI_Device;
      S             : in out State;
      Filter        : Byte;
      Divider_Drops : Byte)
   is
      Divisor  : Interfaces.Unsigned_16;
      AAF      : AAF_Config;
      Value    : Byte;
      ODR      : Byte;
      Decim    : Natural;
      Range_Sel : Byte := 0;
   begin
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Init (D, S);
      S.Acc_Data_Reg := Accel_Data_Register;
      S.Gyro_Data_Reg := Gyro_Data_Register;
      S.Temp_Data_Reg := Temp_Data_Register;
      S.DMA_Read_Start := Temp_Data_Register;
      Set_Bank (D, 0);
      Write_Register (D, Power_Register, Sensors_Off);
      AAF := AAF_Of (S.Sensor, Filter);
      Set_Bank (D, 1);
      Write_Register (D, Gyro_Static_3, AAF.Delt);
      Write_Register (D, Gyro_Static_4, Byte (AAF.Delt_Sqr mod 256));
      Write_Register (D, Gyro_Static_5, Byte (AAF.Delt_Sqr / 256) or AAF.Bit_Shift * 16);
      AAF := AAF_Of (S.Sensor, 0);
      Set_Bank (D, 2);
      Write_Register (D, Accel_Static_2, AAF.Delt * 2);
      Write_Register (D, Accel_Static_3, Byte (AAF.Delt_Sqr mod 256));
      Write_Register (D, Accel_Static_4, Byte (AAF.Delt_Sqr / 256) or AAF.Bit_Shift * 16);
      Set_Bank (D, 0);
      Write_Register (D, Filter_Config_0, Low_Latency_Filters);
      Write_Register (D, Interrupt_Config, Pulsed_Push_Pull_High);
      Write_Register (D, Interrupt_Config_0, Clear_On_Status_Read);
      Write_Register (D, Interrupt_Source_0, Data_Ready_Int1);
      Read_Register (D, Interrupt_Config_1, Value);
      Value := (Value and not Async_Reset) or Pulse_8_No_Deassert;
      Write_Register (D, Interrupt_Config_1, Value);
      Read_Register (D, Interface_Config_1, Value);
      Value := (Value and not AFSR_Mask) or AFSR_Disable;
      Write_Register (D, Interface_Config_1, Value);
      Write_Register (D, Power_Register, Sensors_Low_Noise);
      Delay_Ms (D, 1);
      Decim := Log_2 (Natural (Divider_Drops) + 1);
      if S.Rate_KHz /= 0 and then Decim < 4 then
         ODR := ODR_LUT (Decim);
      else
         ODR := ODR_LUT (3);
         S.Rate_KHz := 0;
      end if;
      if S.Sensor = Sensor_ICM42686P then
         Range_Sel := 1;
      end if;
      Write_Register (D, Gyro_Config_0, Range_Sel * 32 or (ODR and 16#0F#));
      Delay_Ms (D, 15);
      Write_Register (D, Accel_Config_0, Range_Sel * 32 or (ODR and 16#0F#));
      Delay_Ms (D, 15);
   end Gyro_Init;

end Adaflight.MPU_Gyro.ICM426xx;
