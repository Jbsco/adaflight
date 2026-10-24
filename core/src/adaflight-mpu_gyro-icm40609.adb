with Ada.Numerics.Elementary_Functions;

package body Adaflight.MPU_Gyro.ICM40609 with SPARK_Mode is

   Bank_Register        : constant Byte := 16#76#;
   Device_Config        : constant Byte := 16#11#;
   Who_Am_I_Register    : constant Byte := 16#75#;
   Power_Register       : constant Byte := 16#4E#;
   Interface_Config_0   : constant Byte := 16#4C#;
   Accel_Config_0       : constant Byte := 16#50#;
   Gyro_Config_0        : constant Byte := 16#4F#;
   Gyro_Config_1        : constant Byte := 16#51#;
   Filter_Config_0      : constant Byte := 16#52#;
   Filter_Config_1      : constant Byte := 16#53#;
   Interrupt_Config     : constant Byte := 16#14#;
   Interrupt_Config_0   : constant Byte := 16#63#;
   Interrupt_Config_1   : constant Byte := 16#64#;
   Interrupt_Source_0   : constant Byte := 16#65#;
   Gyro_Static_2        : constant Byte := 16#0B#;
   Gyro_Static_3        : constant Byte := 16#0C#;
   Gyro_Static_4        : constant Byte := 16#0D#;
   Gyro_Static_5        : constant Byte := 16#0E#;
   Gyro_Static_6        : constant Byte := 16#0F#;
   Gyro_Static_7        : constant Byte := 16#10#;
   Gyro_Static_8        : constant Byte := 16#11#;
   Gyro_Static_9        : constant Byte := 16#12#;
   Gyro_Static_10       : constant Byte := 16#13#;
   Accel_Static_2       : constant Byte := 16#03#;
   Accel_Static_3       : constant Byte := 16#04#;
   Accel_Static_4       : constant Byte := 16#05#;
   Temp_Data_Register   : constant Byte := 16#1D#;
   Accel_Data_Register  : constant Byte := 16#1F#;
   Gyro_Data_Register   : constant Byte := 16#25#;
   Identity             : constant Byte := 16#3B#;
   Soft_Reset           : constant Byte := 16#01#;
   Sensors_Low_Noise    : constant Byte := 16#10# or 16#0C# or 16#03#;
   Big_Endian_Bit       : constant Byte := 16#10#;
   Accel_16G_1kHz       : constant Byte := 16#20# or 16#06#;
   Gyro_2000DPS_8kHz    : constant Byte := 16#00# or 16#03#;
   Temp_Filter_Mask     : constant Byte := 16#E0#;
   Temp_Filter_4kHz     : constant Byte := 0;
   Gyro_UI_Order_Mask   : constant Byte := 16#0C#;
   Accel_UI_Order_Mask  : constant Byte := 16#18#;
   Third_Order          : constant Byte := 2;
   Decimator_Mask       : constant Byte := 16#03#;
   Decimator_Second     : constant Byte := 2;
   Low_Latency_Filters  : constant Byte := 15 * 16 + 15;
   Accel_AAF_Disable    : constant Byte := 16#01#;
   Gyro_AAF_Disable     : constant Byte := 16#02#;
   Notch_Disable        : constant Byte := 16#01#;
   Notch_Bandwidth_Mask : constant Byte := 16#70#;
   Notch_Widest         : constant Byte := 0;
   HPF_Mask             : constant Byte := 16#0E# or 16#01#;
   HPF_Bandwidth_1      : constant Byte := 1;
   HPF_First_Order      : constant Byte := 0;
   Data_Ready_Int1      : constant Byte := 16#08#;
   Pulsed_Push_Pull_High : constant Byte := 16#02# or 16#01#;
   Clear_On_Status_Read : constant Byte := 0;
   Pulse_8_No_Deassert  : constant Byte := 16#40# or 16#20#;
   Max_SPI_Clock_Hz     : constant := 24_000_000;
   Power_Settle_Us      : constant := 200;
   Startup_Ms           : constant := 35;
   Accel_Settle_Ms      : constant := 10;
   Notch_kHz            : constant Float := 1.5;

   --  An anti-alias filter profile: its corner, delta, squared delta and
   --  shift.
   type AAF_Profile is record
      Hz        : Natural range 0 .. 4000;
      Delt      : Byte;
      Delt_Sqr  : Natural range 0 .. 4095;
      Bit_Shift : Byte range 0 .. 15;
   end record;

   type AAF_Table is array (0 .. 62) of AAF_Profile;

   Profiles : constant AAF_Table :=
     ((42, 1, 1, 15), (84, 2, 4, 13), (126, 3, 9, 12), (170, 4, 16, 11), (213, 5, 25, 10), (258, 6, 36, 10),
      (303, 7, 49, 9), (348, 8, 64, 9), (394, 9, 81, 9), (441, 10, 100, 8), (488, 11, 122, 8), (536, 12, 144, 8),
      (585, 13, 170, 8), (634, 14, 196, 8), (684, 15, 224, 7), (734, 16, 256, 7), (785, 17, 288, 7),
      (837, 18, 324, 7), (890, 19, 360, 6), (943, 20, 400, 6), (997, 21, 440, 6), (1051, 22, 488, 6),
      (1107, 23, 528, 6), (1163, 24, 576, 6), (1220, 25, 624, 6), (1277, 26, 680, 6), (1336, 27, 736, 5),
      (1395, 28, 784, 5), (1454, 29, 848, 5), (1515, 30, 896, 5), (1577, 31, 960, 5), (1639, 32, 1024, 5),
      (1702, 33, 1088, 5), (1766, 34, 1152, 5), (1830, 35, 1232, 5), (1896, 36, 1296, 5), (1962, 37, 1376, 4),
      (2029, 38, 1440, 4), (2097, 39, 1536, 4), (2166, 40, 1600, 4), (2235, 41, 1696, 4), (2306, 42, 1760, 4),
      (2377, 43, 1856, 4), (2449, 44, 1952, 4), (2522, 45, 2016, 4), (2596, 46, 2112, 4), (2671, 47, 2208, 4),
      (2746, 48, 2304, 4), (2823, 49, 2400, 4), (2900, 50, 2496, 4), (2978, 51, 2592, 4), (3057, 52, 2720, 4),
      (3137, 53, 2816, 4), (3217, 54, 2944, 3), (3299, 55, 3008, 3), (3381, 56, 3136, 3), (3464, 57, 3264, 3),
      (3548, 58, 3392, 3), (3633, 59, 3456, 3), (3718, 60, 3584, 3), (3805, 61, 3712, 3), (3892, 62, 3840, 3),
      (3979, 63, 3968, 3));

   --  The anti-alias filter corner of a filter setting.
   function Bandwidth_Of (Filter : Byte) return Natural is
     (case Filter is
         when 0 => 213,
         when 1 => 488,
         when 2 => 997,
         when LPF_Experimental => 1962,
         when others => 213)
     with Global => null;

   --  The first profile at or past a corner, or the last one.
   function Profile_Of (Target : Natural) return AAF_Profile
     with Global => null;

   function Profile_Of (Target : Natural) return AAF_Profile is
   begin
      for I in Profiles'Range loop
         if Target <= Profiles (I).Hz then
            return Profiles (I);
         end if;
      end loop;
      return Profiles (Profiles'Last);
   end Profile_Of;

   procedure Set_Bank (D : in out SPI_Device; Bank : Byte)
     with Global => null;

   procedure Set_Bank (D : in out SPI_Device; Bank : Byte) is
   begin
      Write_Register (D, Bank_Register, Bank and 7);
   end Set_Bank;

   --  A masked update of a register of bank 0.
   procedure Update (D : in out SPI_Device; Register : Byte; Mask : Byte; Value : Byte)
     with Global => null;

   procedure Update (D : in out SPI_Device; Register : Byte; Mask : Byte; Value : Byte) is
      Current : Byte;
   begin
      Set_Bank (D, 0);
      Read_Register (D, Register, Current);
      Write_Register (D, Register, (Current and not Mask) or Value);
   end Update;

   procedure Set_Gyro_AAF (D : in out SPI_Device; Target : Natural)
     with Global => null;

   procedure Set_Gyro_AAF (D : in out SPI_Device; Target : Natural) is
      P       : constant AAF_Profile := Profile_Of (Target);
      Current : Byte;
   begin
      Set_Bank (D, 1);
      Read_Register (D, Gyro_Static_2, Current);
      Write_Register (D, Gyro_Static_2, Current and not Gyro_AAF_Disable);
      Write_Register (D, Gyro_Static_3, P.Delt and 16#3F#);
      Write_Register (D, Gyro_Static_4, Byte (P.Delt_Sqr mod 256));
      Write_Register (D, Gyro_Static_5, P.Bit_Shift * 16 or Byte (P.Delt_Sqr / 256));
      Set_Bank (D, 0);
   end Set_Gyro_AAF;

   procedure Set_Accel_AAF (D : in out SPI_Device; Target : Natural)
     with Global => null;

   procedure Set_Accel_AAF (D : in out SPI_Device; Target : Natural) is
      P       : constant AAF_Profile := Profile_Of (Target);
      Current : Byte;
   begin
      Set_Bank (D, 2);
      Read_Register (D, Accel_Static_2, Current);
      Current := Current and not Accel_AAF_Disable;
      Write_Register (D, Accel_Static_2, (Current and 16#81#) or (P.Delt * 2));
      Write_Register (D, Accel_Static_3, Byte (P.Delt_Sqr mod 256));
      Write_Register (D, Accel_Static_4, P.Bit_Shift * 16 or Byte (P.Delt_Sqr / 256));
      Set_Bank (D, 0);
   end Set_Accel_AAF;

   --  The notch at its frequency in kHz: the cosine of its angle at the 32
   --  kHz rate as a 9-bit coefficient, scaled by eight from one when the
   --  cosine is past 0.875 in magnitude.
   procedure Set_Gyro_Notch (D : in out SPI_Device)
     with Global => null;

   procedure Set_Gyro_Notch (D : in out SPI_Device) is
      use Ada.Numerics.Elementary_Functions;
      Cos_Wz   : constant Float := Cos (2.0 * Ada.Numerics.Pi * Notch_kHz / 32.0);
      Scaled   : Float;
      Coeff    : Natural;
      Selected : Byte;
      Current  : Byte;
   begin
      Set_Bank (D, 1);
      Read_Register (D, Gyro_Static_2, Current);
      Write_Register (D, Gyro_Static_2, Current and not Notch_Disable);
      Read_Register (D, Gyro_Static_10, Current);
      Write_Register (D, Gyro_Static_10, (Current and not Notch_Bandwidth_Mask) or (Notch_Widest * 16));
      if abs Cos_Wz <= 0.875 then
         Scaled := Cos_Wz * 256.0;
         Selected := 0;
      elsif Cos_Wz > 0.875 then
         Scaled := 8.0 * (1.0 - Cos_Wz) * 256.0;
         Selected := 1;
      else
         Scaled := 8.0 * (1.0 + Cos_Wz) * 256.0;
         Selected := 1;
      end if;
      Coeff := Natural (abs Float'Rounding (Scaled)) mod 512;
      Write_Register (D, Gyro_Static_6, Byte (Coeff mod 256));
      Write_Register (D, Gyro_Static_7, Byte (Coeff mod 256));
      Write_Register (D, Gyro_Static_8, Byte (Coeff mod 256));
      Write_Register (D, Gyro_Static_9, Byte (Coeff / 256) * 7 or (Selected * 8) or (Selected * 16) or (Selected * 32));
      Set_Bank (D, 0);
   end Set_Gyro_Notch;

   procedure Set_Gyro_HPF (D : in out SPI_Device)
     with Global => null;

   procedure Set_Gyro_HPF (D : in out SPI_Device) is
      Current : Byte;
   begin
      Set_Bank (D, 1);
      Read_Register (D, Gyro_Static_10, Current);
      Write_Register (D, Gyro_Static_10, (Current and not HPF_Mask) or (HPF_Bandwidth_1 * 2) or HPF_First_Order);
      Set_Bank (D, 0);
   end Set_Gyro_HPF;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Value : Byte;
   begin
      Sensor := No_Sensor;
      Set_Bank (D, 0);
      Write_Register (D, Device_Config, Soft_Reset);
      Delay_Ms (D, 1);
      Read_Register (D, Who_Am_I_Register, Value);
      if Value = Identity then
         Sensor := Sensor_ICM40609;
      end if;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean) is
   begin
      Found := S.Sensor = Sensor_ICM40609;
   end Gyro_Detect;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Filter : Byte; Scale : out Float) is
      Divisor : Interfaces.Unsigned_16;
      Corner  : constant Natural := Bandwidth_Of (Filter);
   begin
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Init (D, S);
      S.Acc_Data_Reg := Accel_Data_Register;
      S.Gyro_Data_Reg := Gyro_Data_Register;
      S.Temp_Data_Reg := Temp_Data_Register;
      S.DMA_Read_Start := Temp_Data_Register;
      S.Temp_Scale := 1.0 / 132.48;
      S.Temp_Zero := 25.0;
      Set_Bank (D, 0);
      Write_Register (D, Power_Register, Sensors_Low_Noise);
      Delay_Us (D, Power_Settle_Us);
      Delay_Ms (D, Startup_Ms);
      Update (D, Interface_Config_0, Big_Endian_Bit, Big_Endian_Bit);
      Set_Bank (D, 0);
      Write_Register (D, Accel_Config_0, Accel_16G_1kHz);
      Delay_Ms (D, Accel_Settle_Ms);
      Update (D, Gyro_Config_1, Temp_Filter_Mask, Temp_Filter_4kHz * 32);
      Update (D, Gyro_Config_1, Gyro_UI_Order_Mask, Third_Order * 4);
      Update (D, Filter_Config_1, Accel_UI_Order_Mask, Third_Order * 8);
      Update (D, Gyro_Config_1, Decimator_Mask, Decimator_Second);
      Write_Register (D, Filter_Config_0, Low_Latency_Filters);
      Set_Gyro_AAF (D, Corner);
      Set_Accel_AAF (D, Corner);
      Set_Gyro_Notch (D);
      Set_Gyro_HPF (D);
      Write_Register (D, Gyro_Config_0, Gyro_2000DPS_8kHz);
      Scale := 2000.0 / 32768.0;
      S.Rate_KHz := Rate_8_kHz;
      Delay_Ms (D, Startup_Ms);
      Write_Register (D, Interrupt_Source_0, Data_Ready_Int1);
      Write_Register (D, Interrupt_Config, Pulsed_Push_Pull_High);
      Write_Register (D, Interrupt_Config_0, Clear_On_Status_Read);
      Write_Register (D, Interrupt_Config_1, Pulse_8_No_Deassert);
   end Gyro_Init;

end Adaflight.MPU_Gyro.ICM40609;
