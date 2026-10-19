package body Adaflight.MPU_Gyro.ICM456xx with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype U16 is Interfaces.Unsigned_16;

   Who_Am_I_Register    : constant Byte := 16#72#;
   Misc_2               : constant Byte := 16#7F#;
   Int1_Config_0        : constant Byte := 16#16#;
   Int1_Config_2        : constant Byte := 16#18#;
   Gyro_Config_0        : constant Byte := 16#1C#;
   Accel_Config_0       : constant Byte := 16#1B#;
   Power_Register       : constant Byte := 16#10#;
   IREG_Address_High    : constant Byte := 16#7C#;
   IREG_Data            : constant Byte := 16#7E#;
   Soft_Reset           : constant Byte := 16#02#;
   IREG_Done            : constant Byte := 16#01#;
   Sensors_Low_Noise    : constant Byte := 16#0F#;
   Accel_16G_1600Hz     : constant Byte := 16#15#;
   Gyro_2000DPS_6400Hz  : constant Byte := 16#13#;
   Int1_Pulsed_PP_High  : constant Byte := 16#01#;
   Int1_Data_Ready      : constant Byte := 16#04#;
   Accel_Data_Register  : constant Byte := 16#00#;
   Gyro_Data_Register   : constant Byte := 16#06#;
   Identity_ICM45686    : constant Byte := 16#E9#;
   Identity_ICM45605    : constant Byte := 16#E5#;
   Accel_Source_Control : constant U16 := 16#A57B#;
   Accel_Source_Mask    : constant Byte := 16#03#;
   Accel_Interpolator   : constant Byte := 16#02#;
   Gyro_Source_Control  : constant U16 := 16#A4A6#;
   Gyro_Source_Mask     : constant Byte := 16#60#;
   Gyro_Interpolator    : constant Byte := 16#40#;
   Gyro_LPF_Config      : constant U16 := 16#A4AC#;
   Accel_LPF_Config     : constant U16 := 16#A583#;
   LPF_Mask             : constant Byte := 16#07#;
   LPF_Bypass           : constant Byte := 0;
   Accel_LPF_Div_8      : constant Byte := 2;
   Max_SPI_Clock_Hz     : constant := 24_000_000;
   Reset_Timeout_Us     : constant := 20_000;
   Reset_Poll_Us        : constant := 10;
   IREG_Timeout_Us      : constant := 5_000;
   IREG_Delay_Us        : constant := 4;
   Update_Retries       : constant := 3;
   Detect_Attempts      : constant := 20;
   Sample_Period_Us     : constant := 1_000_000 / 6_400;
   Enable_Delay_Ms      : constant := 1;
   Accel_Startup_Ms     : constant := 10;
   Gyro_Startup_Ms      : constant := 35;
   Rate_6400_Hz         : constant Byte := 3;
   Frame_Length         : constant := 6;

   function Gyro_LPF_Of (Filter : Byte) return Byte is
     (case Filter is
         when 0 => 4,
         when 1 => 3,
         when 2 => 2,
         when LPF_Experimental => 1,
         when others => LPF_Bypass)
     with Global => null;

   function Sensor_Of (Identity : Byte) return Byte is
     (case Identity is
         when Identity_ICM45686 => Sensor_ICM45686,
         when Identity_ICM45605 => Sensor_ICM45605,
         when others => No_Sensor)
     with Global => null;

   procedure Wait_IREG_Ready (D : in out SPI_Device; Ready : out Boolean)
     with Global => null;

   procedure Wait_IREG_Ready (D : in out SPI_Device; Ready : out Boolean) is
      Waited : Natural := 0;
      Value  : Byte;
   begin
      Ready := False;
      while Waited < IREG_Timeout_Us loop
         Read_Register (D, Misc_2, Value);
         if (Value and IREG_Done) /= 0 then
            Ready := True;
            return;
         end if;
         Delay_Us (D, IREG_Delay_Us);
         Waited := Waited + IREG_Delay_Us;
      end loop;
   end Wait_IREG_Ready;

   procedure Read_IREG (D : in out SPI_Device; Address : U16; Armed : Boolean; Value : out Byte; OK : out Boolean)
     with Global => null;

   procedure Read_IREG (D : in out SPI_Device; Address : U16; Armed : Boolean; Value : out Byte; OK : out Boolean) is
      Ready : Boolean;
   begin
      Value := 0;
      OK := False;
      if Armed then
         return;
      end if;
      Wait_IREG_Ready (D, Ready);
      if not Ready then
         return;
      end if;
      Write_Buffer (D, IREG_Address_High, (Byte (Address / 256), Byte (Address mod 256)));
      Delay_Us (D, IREG_Delay_Us);
      Read_Register (D, IREG_Data, Value);
      Delay_Us (D, IREG_Delay_Us);
      OK := True;
   end Read_IREG;

   procedure Write_IREG (D : in out SPI_Device; Address : U16; Value : Byte; OK : out Boolean)
     with Global => null;

   procedure Write_IREG (D : in out SPI_Device; Address : U16; Value : Byte; OK : out Boolean) is
      Ready : Boolean;
   begin
      Wait_IREG_Ready (D, Ready);
      OK := Ready;
      if not Ready then
         return;
      end if;
      Write_Buffer (D, IREG_Address_High, (Byte (Address / 256), Byte (Address mod 256), Value));
      Delay_Us (D, IREG_Delay_Us);
   end Write_IREG;

   procedure Update_IREG
     (D : in out SPI_Device; Address : U16; Mask : Byte; Value : Byte; Armed : Boolean; OK : out Boolean)
     with Global => null;

   procedure Update_IREG
     (D : in out SPI_Device; Address : U16; Mask : Byte; Value : Byte; Armed : Boolean; OK : out Boolean)
   is
      Current  : Byte;
      Expected : Byte;
      Back     : Byte;
      Read_OK  : Boolean;
   begin
      OK := False;
      for Attempt in 1 .. Update_Retries loop
         Read_IREG (D, Address, Armed, Current, Read_OK);
         if not Read_OK then
            return;
         end if;
         Expected := (Current and not Mask) or (Value and Mask);
         if Expected /= Current then
            Write_IREG (D, Address, Expected, Read_OK);
            if not Read_OK then
               return;
            end if;
         end if;
         Read_IREG (D, Address, Armed, Back, Read_OK);
         if Read_OK and then (Back and Mask) = (Value and Mask) then
            OK := True;
            return;
         end if;
      end loop;
   end Update_IREG;

   procedure Configure_LPF (D : in out SPI_Device; Address : U16; Division : Byte; Armed : Boolean; OK : out Boolean)
     with Global => null;

   procedure Configure_LPF (D : in out SPI_Device; Address : U16; Division : Byte; Armed : Boolean; OK : out Boolean) is
   begin
      if Division > LPF_Mask then
         OK := False;
         return;
      end if;
      Update_IREG (D, Address, LPF_Mask, Division, Armed, OK);
   end Configure_LPF;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Waited   : Natural := 0;
      Attempts : Natural := Detect_Attempts;
      Value    : Byte;
   begin
      Sensor := No_Sensor;
      Write_Register (D, Misc_2, Soft_Reset);
      loop
         pragma Loop_Invariant (Waited < Reset_Timeout_Us);
         Read_Register (D, Misc_2, Value);
         exit when (Value and Soft_Reset) = 0;
         Delay_Us (D, Reset_Poll_Us);
         Waited := Waited + Reset_Poll_Us;
         if Waited >= Reset_Timeout_Us then
            return;
         end if;
      end loop;
      Write_Register (D, Power_Register, 0);
      loop
         Delay_Ms (D, 1);
         Read_Register (D, Who_Am_I_Register, Value);
         Sensor := Sensor_Of (Value);
         exit when Sensor /= No_Sensor;
         if Attempts = 0 then
            return;
         end if;
         Attempts := Attempts - 1;
      end loop;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean) is
   begin
      Found := Is_ICM456xx (S.Sensor);
   end Gyro_Detect;

   procedure Gyro_Init
     (D      : in out SPI_Device;
      S      : in out State;
      Filter : Byte;
      Armed  : Boolean;
      Scale  : out Float)
   is
      Divisor   : Interfaces.Unsigned_16;
      OK        : Boolean;
      Unused_OK : Boolean;
   begin
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Init (D, S);
      Write_Register (D, Power_Register, Sensors_Low_Noise);
      Delay_Ms (D, Enable_Delay_Ms);
      Write_Register (D, Accel_Config_0, Accel_16G_1600Hz);
      Delay_Ms (D, Accel_Startup_Ms);
      Update_IREG (D, Gyro_Source_Control, Gyro_Source_Mask, Gyro_Interpolator, Armed, OK);
      if not OK then
         Update_IREG (D, Gyro_Source_Control, Gyro_Source_Mask, 0, Armed, Unused_OK);
      end if;
      Configure_LPF (D, Gyro_LPF_Config, Gyro_LPF_Of (Filter), Armed, OK);
      if not OK then
         Configure_LPF (D, Gyro_LPF_Config, LPF_Bypass, Armed, Unused_OK);
      end if;
      Scale := 2000.0 / 32768.0;
      S.Rate_KHz := Rate_6400_Hz;
      Write_Register (D, Gyro_Config_0, Gyro_2000DPS_6400Hz);
      Delay_Ms (D, Gyro_Startup_Ms);
      S.Short_Period := Interfaces.Integer_32 (Micros_To_Cycles (Sample_Period_Us) mod 2 ** 31);
      Write_Register (D, Int1_Config_2, Int1_Pulsed_PP_High);
      Write_Register (D, Int1_Config_0, Int1_Data_Ready);
      S.Acc_Data_Reg := Accel_Data_Register;
      S.Gyro_Data_Reg := Gyro_Data_Register;
      S.DMA_Max_Duration := 0;
   end Gyro_Init;

   procedure Acc_Init (D : in out SPI_Device; S : in out State; Armed : Boolean) is
      OK        : Boolean;
      Unused_OK : Boolean;
   begin
      Update_IREG (D, Accel_Source_Control, Accel_Source_Mask, Accel_Interpolator, Armed, OK);
      if not OK then
         Update_IREG (D, Accel_Source_Control, Accel_Source_Mask, 0, Armed, Unused_OK);
      end if;
      Configure_LPF (D, Accel_LPF_Config, Accel_LPF_Div_8, Armed, OK);
      if not OK then
         Configure_LPF (D, Accel_LPF_Config, LPF_Bypass, Armed, Unused_OK);
      end if;
      S.Acc_Data_Reg := Accel_Data_Register;
   end Acc_Init;

   --  A little-endian pair as the signed count.
   function Little_16 (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128
      then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Data : Byte_Array (0 .. Frame_Length - 1) := (others => 0);
      Rx   : Buffer_Bytes;
   begin
      OK := True;
      case S.Mode is
         when EXTI_Init =>
            S.Tx (0 .. Frame_Length) := (others => 16#FF#);
            S.DMA_Max_Duration := 0;
            S.Mode := EXTI_Int;
         when EXTI_Int | EXTI_No_Int =>
            Read_Masked (D, Gyro_Data_Register, Data, OK);
            if not OK then
               return;
            end if;
            S.Raw := (Little_16 (Data (0), Data (1)), Little_16 (Data (2), Data (3)), Little_16 (Data (4), Data (5)));
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Raw := (Little_16 (Rx (1), Rx (2)), Little_16 (Rx (3), Rx (4)), Little_16 (Rx (5), Rx (6)));
      end case;
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Data : Byte_Array (0 .. Frame_Length - 1) := (others => 0);
   begin
      Read_Masked (D, Accel_Data_Register, Data, OK);
      if not OK then
         return;
      end if;
      S.Acc_Raw := (Little_16 (Data (0), Data (1)), Little_16 (Data (2), Data (3)), Little_16 (Data (4), Data (5)));
   end Read_Acc;

end Adaflight.MPU_Gyro.ICM456xx;
