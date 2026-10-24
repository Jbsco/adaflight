with Adaflight.BMI270_Config;

package body Adaflight.MPU_Gyro.BMI270 with SPARK_Mode is

   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_32;

   Chip_Id_Register       : constant Byte := 16#00#;
   Acc_Data_Register      : constant Byte := 16#0C#;
   Gyro_Data_Register     : constant Byte := 16#12#;
   FIFO_Length_Register   : constant Byte := 16#24#;
   Acc_Config_Register    : constant Byte := 16#40#;
   Acc_Range_Register     : constant Byte := 16#41#;
   Gyro_Config_Register   : constant Byte := 16#42#;
   Gyro_Range_Register    : constant Byte := 16#43#;
   FIFO_Downs_Register    : constant Byte := 16#45#;
   FIFO_Watermark_Low     : constant Byte := 16#46#;
   FIFO_Watermark_High    : constant Byte := 16#47#;
   FIFO_Config_0_Register : constant Byte := 16#48#;
   FIFO_Config_1_Register : constant Byte := 16#49#;
   Int1_Pin_Register      : constant Byte := 16#53#;
   Int_Map_Register       : constant Byte := 16#58#;
   Load_Control_Register  : constant Byte := 16#59#;
   Load_Data_Register     : constant Byte := 16#5E#;
   Power_Config_Register  : constant Byte := 16#7C#;
   Power_Control_Register : constant Byte := 16#7D#;
   Command_Register       : constant Byte := 16#7E#;
   Read_Bit               : constant Byte := 16#80#;
   Chip_Id                : constant Byte := 16#24#;
   Soft_Reset             : constant Byte := 16#B6#;
   FIFO_Flush             : constant Byte := 16#B0#;
   Sensors_On             : constant Byte := 16#0E#;
   FIFO_Self_Wake         : constant Byte := 16#02#;
   Acc_800Hz_Performance  : constant Byte := 16#9B#;
   Acc_16G                : constant Byte := 16#03#;
   Gyro_3200Hz_Performance : constant Byte := 16#CD#;
   Gyro_2000DPS           : constant Byte := 16#08#;
   Int_Data_Ready         : constant Byte := 16#04#;
   Int_FIFO_Watermark     : constant Byte := 16#02#;
   Int_Push_Pull_High     : constant Byte := 16#0A#;
   FIFO_Keep_Full         : constant Byte := 16#00#;
   FIFO_Gyro_Headerless   : constant Byte := 16#80#;
   FIFO_No_Downsampling   : constant Byte := 16#00#;
   FIFO_One_Frame         : constant Byte := 16#06#;
   Oversampling_4         : constant Byte := 0;
   Oversampling_2         : constant Byte := 1;
   Oversampling_Normal    : constant Byte := 2;
   Oversampling_Shift     : constant Byte := 16;
   Max_SPI_Clock_Hz       : constant := 10_000_000;
   Frame_Bytes            : constant := 6;
   Payload_Offset         : constant := 2;
   Sensor_Read_Bytes      : constant := Payload_Offset + Frame_Bytes;
   DMA_Read_Bytes         : constant := Payload_Offset + 2 * Frame_Bytes;
   FIFO_Read_Bytes        : constant := 4 + Frame_Bytes;
   FIFO_Frame_Offset      : constant := 4;

   --  The value behind the dummy byte, 0 when the read fails.
   procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte)
     with Global => null;

   procedure Read_Register (D : in out SPI_Device; Register : Byte; Value : out Byte) is
      Data : Byte_Array (0 .. 1) := (others => 0);
      OK   : Boolean;
   begin
      Read_Masked (D, Register, Data, OK);
      Value := (if OK then Data (1) else 0);
   end Read_Register;

   procedure Set_Register (D : in out SPI_Device; Register : Byte; Value : Byte; Wait_Ms : Natural)
     with Global => null;

   procedure Set_Register (D : in out SPI_Device; Register : Byte; Value : Byte; Wait_Ms : Natural) is
   begin
      Write_Register (D, Register, Value);
      if Wait_Ms > 0 then
         Delay_Ms (D, Wait_Ms);
      end if;
   end Set_Register;

   --  The select pin low then high, which selects the SPI interface.
   procedure Enable_SPI (D : in out SPI_Device)
     with Global => null;

   procedure Enable_SPI (D : in out SPI_Device) is
   begin
      Set_CS (D, False);
      Delay_Ms (D, 1);
      Set_CS (D, True);
      Delay_Ms (D, 10);
   end Enable_SPI;

   procedure Detect (D : in out SPI_Device; Sensor : out Byte) is
      Value : Byte;
   begin
      Enable_SPI (D);
      Read_Register (D, Chip_Id_Register, Value);
      Sensor := (if Value = Chip_Id then Sensor_BMI270 else No_Sensor);
   end Detect;

   procedure Gyro_Detect (S : State; Found : out Boolean; Scale : in out Float) is
   begin
      Found := S.Sensor = Sensor_BMI270;
      if Found then
         Scale := 2000.0 / 32768.0;
      end if;
   end Gyro_Detect;

   procedure Upload_Config (D : in out SPI_Device)
     with Global => null;

   procedure Upload_Config (D : in out SPI_Device) is
   begin
      Set_Register (D, Power_Config_Register, 0, 1);
      Set_Register (D, Load_Control_Register, 0, 1);
      Write_Buffer (D, Load_Data_Register, Adaflight.BMI270_Config.Maximum_FIFO);
      Delay_Ms (D, 10);
      Set_Register (D, Load_Control_Register, 1, 1);
   end Upload_Config;

   function Oversampling_Of (Filter : Byte) return Byte is
     (case Filter is
         when 1 => Oversampling_2,
         when 2 | LPF_Experimental => Oversampling_Normal,
         when others => Oversampling_4)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Filter : Byte)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Filter : Byte) is
      FIFO_Mode : constant Boolean := Filter = LPF_Experimental;
   begin
      Set_Register (D, Command_Register, Soft_Reset, 100);
      Enable_SPI (D);
      Upload_Config (D);
      if FIFO_Mode then
         Set_Register (D, FIFO_Config_0_Register, FIFO_Keep_Full, 1);
         Set_Register (D, FIFO_Config_1_Register, FIFO_Gyro_Headerless, 1);
         Set_Register (D, FIFO_Downs_Register, FIFO_No_Downsampling, 1);
         Set_Register (D, FIFO_Watermark_Low, FIFO_One_Frame, 1);
         Set_Register (D, FIFO_Watermark_High, 0, 1);
      end if;
      Set_Register (D, Acc_Config_Register, Acc_800Hz_Performance, 1);
      Set_Register (D, Acc_Range_Register, Acc_16G, 1);
      Set_Register
        (D, Gyro_Config_Register, Gyro_3200Hz_Performance or Oversampling_Of (Filter) * Oversampling_Shift, 1);
      Set_Register (D, Gyro_Range_Register, Gyro_2000DPS, 1);
      Set_Register (D, Int_Map_Register, (if FIFO_Mode then Int_FIFO_Watermark else Int_Data_Ready), 1);
      Set_Register (D, Int1_Pin_Register, Int_Push_Pull_High, 1);
      Set_Register (D, Power_Config_Register, FIFO_Self_Wake, 1);
      Set_Register (D, Power_Control_Register, Sensors_On, 1);
      if FIFO_Mode then
         Set_Register (D, Command_Register, FIFO_Flush, 1);
      end if;
   end Configure;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State) is
      Divisor : Interfaces.Unsigned_16;
   begin
      Configure (D, S.Hardware_LPF);
      if S.Hardware_LPF = LPF_Experimental then
         S.Mode := EXTI_Int;
      end if;
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

   --  The FIFO length and the first frame; a whole frame is kept unless
   --  every word is -32768, and the FIFO is flushed when bytes remain.
   procedure Read_FIFO (D : in out SPI_Device; S : in out State; OK : out Boolean)
     with Global => null;

   procedure Read_FIFO (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Tx     : constant Byte_Array (0 .. FIFO_Read_Bytes - 1) := (FIFO_Length_Register or Read_Bit, others => 0);
      Rx     : Buffer_Bytes;
      Length : Natural;
      Frame  : Axis_Values;
   begin
      OK := False;
      Start_Sequence (D, Tx, False);
      Wait (D);
      Fetch (D, Rx);
      Length := Natural (Rx (3)) * 256 + Natural (Rx (2));
      if Length >= Frame_Bytes then
         Frame := Sample_At (Rx, FIFO_Frame_Offset);
         if Frame (0) /= Interfaces.Integer_16'First
           or else Frame (1) /= Interfaces.Integer_16'First
           or else Frame (2) /= Interfaces.Integer_16'First
         then
            S.Raw := Frame;
            OK := True;
         end if;
         Length := Length - Frame_Bytes;
      end if;
      if Length > 0 then
         Set_Register (D, Command_Register, FIFO_Flush, 0);
      end if;
   end Read_FIFO;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      OK := True;
      if S.Hardware_LPF = LPF_Experimental then
         Read_FIFO (D, S, OK);
      else
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
            when EXTI_Int | EXTI_No_Int =>
               S.Tx (0) := Gyro_Data_Register or Read_Bit;
               Start_Sequence (D, S.Tx (0 .. Sensor_Read_Bytes - 1), False);
               Wait (D);
               Fetch (D, Rx);
               S.Raw := Sample_At (Rx, Payload_Offset);
            when EXTI_Int_DMA =>
               Fetch (D, Rx);
               S.Raw := Sample_At (Rx, Payload_Offset + Frame_Bytes);
         end case;
      end if;
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      OK := True;
      case S.Mode is
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := Acc_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sensor_Read_Bytes - 1), False);
            Wait (D);
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, Payload_Offset);
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, Payload_Offset);
         when EXTI_Init =>
            null;
      end case;
   end Read_Acc;

end Adaflight.MPU_Gyro.BMI270;
