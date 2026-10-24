package body Adaflight.MPU_Gyro.BMI160 with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   Chip_Id_Register    : constant Byte := 16#00#;
   Power_Status        : constant Byte := 16#03#;
   Gyro_Data_Register  : constant Byte := 16#0C#;
   Acc_Data_Register   : constant Byte := 16#12#;
   Acc_Config          : constant Byte := 16#40#;
   Acc_Range           : constant Byte := 16#41#;
   Gyro_Config         : constant Byte := 16#42#;
   Gyro_Range          : constant Byte := 16#43#;
   Int_Enable_1        : constant Byte := 16#51#;
   Int_Out_Control     : constant Byte := 16#53#;
   Int_Map_1           : constant Byte := 16#56#;
   Offset_0            : constant Byte := 16#77#;
   Command_Register    : constant Byte := 16#7E#;
   Read_Bit            : constant Byte := 16#80#;
   Chip_Id             : constant Byte := 16#D1#;
   Select_SPI          : constant Byte := 16#FF#;
   Acc_Normal_Mode     : constant Byte := 16#11#;
   Gyro_Normal_Mode    : constant Byte := 16#15#;
   Power_Status_Mask   : constant Byte := 16#3C#;
   Power_Both_Normal   : constant Byte := 16#14#;
   Acc_800Hz_OSR2      : constant Byte := 16#1B#;
   Gyro_3200Hz         : constant Byte := 16#0D#;
   Oversampling_4      : constant Byte := 16#00#;
   Oversampling_2      : constant Byte := 16#10#;
   Oversampling_None   : constant Byte := 16#20#;
   Range_8G            : constant Byte := 16#08#;
   Range_2000DPS       : constant Byte := 16#00#;
   Offset_Enable_Bits  : constant Byte := 16#C0#;
   Data_Ready_Enable   : constant Byte := 16#10#;
   Int1_Pushed_Enabled : constant Byte := 16#0A#;
   Int1_Data_Ready     : constant Byte := 16#80#;
   Max_SPI_Clock_Hz    : constant := 10_000_000;
   Select_Wait_Ms      : constant := 100;
   Gyro_Power_Wait_Ms  : constant := 100;
   Acc_Power_Wait_Ms   : constant := 5;
   Sample_Bytes        : constant := 6;
   DMA_Read_Bytes      : constant := 1 + 2 * Sample_Bytes;

   --  The gyro oversampling of a filter setting.
   function Oversampling_Of (Filter : Byte) return Byte is
     (case Filter is
         when 0 => Oversampling_4,
         when 1 => Oversampling_2,
         when 2 => Oversampling_None,
         when LPF_Experimental => Oversampling_None,
         when others => Oversampling_4)
     with Global => null;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Value : Byte;
   begin
      Sensor := No_Sensor;
      Write_Byte (D, Select_SPI);
      Delay_Ms (D, Select_Wait_Ms);
      Read_Register (D, Chip_Id_Register, Value);
      if Value = Chip_Id then
         Sensor := Sensor_BMI160;
      end if;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float) is
   begin
      Found := S.Sensor = Sensor_BMI160;
      if Found then
         Scale := 2000.0 / 32768.0;
      end if;
   end Gyro_Detect;

   --  The power modes, checked, then the rates, ranges, offsets and the
   --  interrupt.
   procedure Configure (D : in out SPI_Device; Filter : Byte)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Filter : Byte) is
      Value : Byte;
   begin
      Write_Register (D, Command_Register, Gyro_Normal_Mode);
      Delay_Ms (D, Gyro_Power_Wait_Ms);
      Write_Register (D, Command_Register, Acc_Normal_Mode);
      Delay_Ms (D, Acc_Power_Wait_Ms);
      Read_Register (D, Power_Status, Value);
      if (Value and Power_Status_Mask) /= Power_Both_Normal then
         return;
      end if;
      Write_Register (D, Acc_Config, Acc_800Hz_OSR2);
      Delay_Ms (D, 1);
      Write_Register (D, Gyro_Config, Oversampling_Of (Filter) or Gyro_3200Hz);
      Delay_Ms (D, 1);
      Write_Register (D, Acc_Range, Range_8G);
      Delay_Ms (D, 1);
      Write_Register (D, Gyro_Range, Range_2000DPS);
      Delay_Ms (D, 1);
      Read_Register (D, Offset_0, Value);
      Write_Register (D, Offset_0, Value or Offset_Enable_Bits);
      Write_Register (D, Int_Enable_1, Data_Ready_Enable);
      Delay_Ms (D, 1);
      Write_Register (D, Int_Out_Control, Int1_Pushed_Enabled);
      Delay_Ms (D, 1);
      Write_Register (D, Int_Map_1, Int1_Data_Ready);
      Delay_Ms (D, 1);
   end Configure;

   procedure Gyro_Init (D : in out SPI_Device; S : State; Filter : Byte) is
      Divisor : Interfaces.Unsigned_16;
   begin
      Configure (D, Filter);
      if S.Interrupt_Pin then
         Enable_Interrupt (D);
      end if;
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
   end Gyro_Init;

   --  A little-endian pair as the signed count.
   function Little_16 (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128
      then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   --  The three little-endian words at an offset of the receive buffer.
   function Sample_At (Rx : Buffer_Bytes; Offset : Natural) return Axis_Values is
     (Little_16 (Rx (Offset), Rx (Offset + 1)),
      Little_16 (Rx (Offset + 2), Rx (Offset + 3)),
      Little_16 (Rx (Offset + 4), Rx (Offset + 5)))
     with Global => null,
          Pre    => Offset <= Buffer_Bytes'Last - 5;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      OK := True;
      case S.Mode is
         when EXTI_Init =>
            S.Tx (0 .. DMA_Read_Bytes) := (others => 0);
            S.DMA_Max_Duration := 5;
            if S.Detected_EXTI > Detect_Count then
               if Uses_DMA (D) then
                  S.Tx (0) := Gyro_Data_Register or Read_Bit;
                  S.DMA_Length := DMA_Read_Bytes;
                  S.Mode := EXTI_Int_DMA;
               else
                  S.Mode := EXTI_Int;
               end if;
            else
               S.Mode := EXTI_No_Int;
            end if;
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := Gyro_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sample_Bytes), False);
            Wait (D);
            Fetch (D, Rx);
            S.Raw := Sample_At (Rx, 2);
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Raw := Sample_At (Rx, 2);
      end case;
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      OK := True;
      case S.Mode is
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := Acc_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sample_Bytes), False);
            Wait (D);
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, 2);
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, 2 + Sample_Bytes);
         when EXTI_Init =>
            null;
      end case;
   end Read_Acc;

end Adaflight.MPU_Gyro.BMI160;
