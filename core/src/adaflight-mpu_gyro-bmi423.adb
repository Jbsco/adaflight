package body Adaflight.MPU_Gyro.BMI423 with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype U16 is Interfaces.Unsigned_16;

   Chip_Id_Register    : constant Byte := 16#00#;
   Filter_Register     : constant Byte := 16#25#;
   Acc_Register        : constant Byte := 16#26#;
   Gyro_Register       : constant Byte := 16#27#;
   Int_Control         : constant Byte := 16#33#;
   Int_Config          : constant Byte := 16#34#;
   Int_Map             : constant Byte := 16#35#;
   Acc_Data_Register   : constant Byte := 16#56#;
   Gyro_Data_Register  : constant Byte := 16#59#;
   Legacy_Register     : constant Byte := 16#7B#;
   Command_Register    : constant Byte := 16#7E#;
   Read_Bit            : constant Byte := 16#80#;
   Chip_Id             : constant Byte := 16#AB#;
   Acc_IIR2            : constant U16 := 16#0002#;
   Gyro_IIR2           : constant U16 := 16#0200#;
   Acc_16G_800Hz       : constant U16 := 16#E03B#;
   Gyro_2000DPS_6400Hz : constant U16 := 16#E04E#;
   Int_Push_Pull_High  : constant U16 := 16#0005#;
   Int_Long_Pulse      : constant U16 := 16#0003#;
   Int_Gyro_Ready      : constant U16 := 16#0004#;
   Legacy_16_Bit       : constant U16 := 16#0001#;
   Soft_Reset          : constant U16 := 16#DEAF#;
   Bandwidth_Auto      : constant U16 := 0;
   Bandwidth_200Hz     : constant U16 := 4;
   Bandwidth_400Hz     : constant U16 := 5;
   Bandwidth_800Hz     : constant U16 := 6;
   Bandwidth_Shift     : constant U16 := 128;
   Max_SPI_Clock_Hz    : constant := 10_000_000;
   Dummy_Bytes         : constant := 2;
   Sample_Bytes        : constant := 6;
   Register_Read_Bytes : constant := Dummy_Bytes + 2;
   Sensor_Read_Bytes   : constant := 1 + Dummy_Bytes + Sample_Bytes;
   DMA_Read_Bytes      : constant := 1 + Dummy_Bytes + 2 * Sample_Bytes;
   Payload_Offset      : constant := 1 + Dummy_Bytes;
   Gyro_Settle_Ms      : constant := 55;

   --  The 16-bit value behind the dummy bytes, 0 when the read fails.
   procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out U16; OK : out Boolean)
     with Global => null;

   procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out U16; OK : out Boolean) is
      Data : Byte_Array (0 .. Register_Read_Bytes - 1) := (others => 0);
   begin
      Value := 0;
      Read_Masked (D, Register, Data, OK);
      if OK then
         Value := U16 (Data (Dummy_Bytes)) + U16 (Data (Dummy_Bytes + 1)) * 256;
      end if;
   end Read_Register;

   procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : U16; Wait_Ms : Natural)
     with Global => null;

   procedure Write_Register (D : in out SPI_Device; Register : Byte; Value : U16; Wait_Ms : Natural) is
   begin
      Write_Buffer (D, Register, (Byte (Value mod 256), Byte (Value / 256)));
      if Wait_Ms > 0 then
         Delay_Ms (D, Wait_Ms);
      end if;
   end Write_Register;

   --  The select pin low then high and a discarded identity read, which
   --  select the SPI interface.
   procedure Enable_SPI (D : in out SPI_Device)
     with Global => null;

   procedure Enable_SPI (D : in out SPI_Device) is
      Unused_Value : U16;
      Unused_OK    : Boolean;
   begin
      Set_CS (D, False);
      Delay_Ms (D, 1);
      Set_CS (D, True);
      Delay_Ms (D, 2);
      Read_Register (D, Chip_Id_Register, Unused_Value, Unused_OK);
   end Enable_SPI;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Value : U16;
      OK    : Boolean;
   begin
      Sensor := No_Sensor;
      Enable_SPI (D);
      Read_Register (D, Chip_Id_Register, Value, OK);
      if OK and then Byte (Value mod 256) = Chip_Id then
         Sensor := Sensor_BMI423;
      end if;
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float) is
   begin
      Found := S.Sensor = Sensor_BMI423;
      if Found then
         Scale := 2000.0 / 32768.0;
      end if;
   end Gyro_Detect;

   function Bandwidth_Of (Filter : Byte) return U16 is
     (case Filter is
         when 0 => Bandwidth_200Hz,
         when 1 => Bandwidth_400Hz,
         when 2 => Bandwidth_800Hz,
         when LPF_Experimental => Bandwidth_Auto,
         when others => Bandwidth_200Hz)
     with Global => null;

   function Filter_Of (Filter : Byte) return U16 is
     (if Filter = LPF_Experimental then Acc_IIR2 else Acc_IIR2 or Gyro_IIR2)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Filter : Byte)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Filter : Byte) is
   begin
      Write_Register (D, Command_Register, Soft_Reset, 2);
      Enable_SPI (D);
      Write_Register (D, Legacy_Register, Legacy_16_Bit, 1);
      Write_Register (D, Filter_Register, Filter_Of (Filter), 1);
      Write_Register (D, Acc_Register, Acc_16G_800Hz, 1);
      Write_Register (D, Filter_Register, Filter_Of (Filter), 1);
      Write_Register (D, Gyro_Register, Gyro_2000DPS_6400Hz or Bandwidth_Of (Filter) * Bandwidth_Shift, Gyro_Settle_Ms);
      Write_Register (D, Int_Control, Int_Push_Pull_High, 1);
      Write_Register (D, Int_Config, Int_Long_Pulse, 1);
      Write_Register (D, Int_Map, Int_Gyro_Ready, 1);
   end Configure;

   procedure Gyro_Init (D : in out SPI_Device; S : State) is
      Divisor : Interfaces.Unsigned_16;
   begin
      Configure (D, S.Hardware_LPF);
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
      if S.Mode = EXTI_No_Int and then S.Detected_EXTI > Detect_Count then
         S.Mode := EXTI_Init;
      end if;
      OK := True;
      case S.Mode is
         when EXTI_Init =>
            S.Tx (0 .. DMA_Read_Bytes - 1) := (others => 0);
            S.DMA_Max_Duration := 5;
            if S.Detected_EXTI > Detect_Count then
               if Uses_DMA (D) then
                  S.Tx (0) := Acc_Data_Register or Read_Bit;
                  S.DMA_Length := DMA_Read_Bytes;
                  S.Mode := EXTI_Int_DMA;
               else
                  S.Mode := EXTI_Int;
               end if;
            else
               S.Mode := EXTI_No_Int;
            end if;
            OK := False;
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0 .. Sensor_Read_Bytes - 1) := (others => 0);
            S.Tx (0) := Gyro_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sensor_Read_Bytes - 1), False);
            Wait (D);
            Fetch (D, Rx);
            S.Raw := Sample_At (Rx, Payload_Offset);
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Raw := Sample_At (Rx, Payload_Offset + Sample_Bytes);
      end case;
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      OK := True;
      case S.Mode is
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0 .. Sensor_Read_Bytes - 1) := (others => 0);
            S.Tx (0) := Acc_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sensor_Read_Bytes - 1), False);
            Wait (D);
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, Payload_Offset);
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, Payload_Offset);
         when EXTI_Init =>
            OK := False;
      end case;
   end Read_Acc;

end Adaflight.MPU_Gyro.BMI423;
