package body Adaflight.MPU_Gyro.LSM6DSO with SPARK_Mode is

   Who_Am_I_Register   : constant Byte := 16#0F#;
   Int1_Control        : constant Byte := 16#0D#;
   Int2_Control        : constant Byte := 16#0E#;
   Control_1_XL        : constant Byte := 16#10#;
   Control_2_G         : constant Byte := 16#11#;
   Control_3_C         : constant Byte := 16#12#;
   Control_4_C         : constant Byte := 16#13#;
   Control_6_C         : constant Byte := 16#15#;
   Control_9_XL        : constant Byte := 16#18#;
   Gyro_Out            : constant Byte := 16#22#;
   Accel_Out           : constant Byte := 16#28#;
   Identity            : constant Byte := 16#6C#;
   Data_Ready_Pin      : constant Byte := 16#02#;
   Accel_833Hz_16G     : constant Byte := 16#74#;
   Gyro_6664Hz_2000DPS : constant Byte := 16#AC#;
   Reset_Mask          : constant Byte := 16#01#;
   Control_3_Mask      : constant Byte := 16#7C#;
   Block_Update_Inc    : constant Byte := 16#44#;
   Control_4_Mask      : constant Byte := 16#06#;
   I2C_Off_LPF1        : constant Byte := 16#06#;
   Control_6_Mask      : constant Byte := 16#17#;
   High_Perf_335Hz     : constant Byte := 16#00#;
   Control_9_Mask      : constant Byte := 16#02#;
   I3C_Off             : constant Byte := 16#02#;
   Max_SPI_Clock_Hz    : constant := 10_000_000;
   Reset_Delay_Ms      : constant := 100;
   Write_Delay_Ms      : constant := 1;
   Read_Gap_Us         : constant := 2;
   Scale_2000DPS       : constant Float := 0.070;
   Frame_Length        : constant := 6;

   procedure Write (D : in out SPI_Device; Register : Byte; Value : Byte; Delay_After : Natural)
     with Global => null;

   procedure Write (D : in out SPI_Device; Register : Byte; Value : Byte; Delay_After : Natural) is
   begin
      Write_Register (D, Register, Value);
      if Delay_After > 0 then
         Delay_Ms (D, Delay_After);
      end if;
   end Write;

   --  A masked write after a read of the register, skipped when the read
   --  fails.
   procedure Write_Bits (D : in out SPI_Device; Register : Byte; Mask : Byte; Value : Byte; Delay_After : Natural)
     with Global => null;

   procedure Write_Bits (D : in out SPI_Device; Register : Byte; Mask : Byte; Value : Byte; Delay_After : Natural) is
      Current : Byte_Array (0 .. 0) := (others => 0);
      OK      : Boolean;
   begin
      Read_Registers (D, Register, Current, OK);
      if OK then
         Delay_Us (D, Read_Gap_Us);
         Write (D, Register, (Current (0) and not Mask) or Value, Delay_After);
      end if;
   end Write_Bits;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Id : Byte_Array (0 .. 0) := (others => 0);
      OK : Boolean;
   begin
      Sensor := No_Sensor;
      Read_Registers (D, Who_Am_I_Register, Id, OK);
      if OK and then Id (0) = Identity then
         Sensor := Sensor_LSM6DSO;
      end if;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : out Float) is
   begin
      Found := S.Sensor = Sensor_LSM6DSO;
      Scale := (if Found then Scale_2000DPS else 0.0);
   end Gyro_Detect;

   procedure Gyro_Init (D : in out SPI_Device; S : State) is
      Divisor : Interfaces.Unsigned_16;
   begin
      Write_Bits (D, Control_3_C, Reset_Mask, Reset_Mask, Reset_Delay_Ms);
      Write (D, Int1_Control, Data_Ready_Pin, Write_Delay_Ms);
      Write (D, Int2_Control, Data_Ready_Pin, Write_Delay_Ms);
      Write (D, Control_1_XL, Accel_833Hz_16G, Write_Delay_Ms);
      Write (D, Control_2_G, Gyro_6664Hz_2000DPS, Write_Delay_Ms);
      Write_Bits (D, Control_3_C, Control_3_Mask, Block_Update_Inc, Write_Delay_Ms);
      Write_Bits (D, Control_4_C, Control_4_Mask, I2C_Off_LPF1, Write_Delay_Ms);
      Write_Bits (D, Control_6_C, Control_6_Mask, High_Perf_335Hz, Write_Delay_Ms);
      Write_Bits (D, Control_9_XL, Control_9_Mask, I3C_Off, Write_Delay_Ms);
      if S.Interrupt_Pin then
         Enable_Interrupt (D);
      end if;
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
   end Gyro_Init;

   procedure Interrupt (S : in out State) is
   begin
      S.Data_Ready := True;
   end Interrupt;

   --  A little-endian pair as the signed count.
   function Little_16 (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128
      then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Data : Byte_Array (0 .. Frame_Length - 1) := (others => 0);
   begin
      Read_Registers (D, Gyro_Out, Data, OK);
      if not OK then
         return;
      end if;
      S.Raw := (Little_16 (Data (0), Data (1)), Little_16 (Data (2), Data (3)), Little_16 (Data (4), Data (5)));
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Data : Byte_Array (0 .. Frame_Length - 1) := (others => 0);
   begin
      Read_Registers (D, Accel_Out, Data, OK);
      if not OK then
         return;
      end if;
      S.Acc_Raw := (Little_16 (Data (0), Data (1)), Little_16 (Data (2), Data (3)), Little_16 (Data (4), Data (5)));
   end Read_Acc;

end Adaflight.MPU_Gyro.LSM6DSO;
