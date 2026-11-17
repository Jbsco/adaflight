with Adaflight.MSP_Allocation;
with Adaflight.Sensor_Alignment;
with Adaflight.Serial_Feature_Map;

package body Adaflight.Board_Info with SPARK_Mode is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;

   --  A gyro's custom angles as its alignment gives them: a standard
   --  alignment's own, a custom alignment's as the board names them, none
   --  for the default alignment.
   function Gyro_Angles (Alignment : Interfaces.Unsigned_8; Custom : Integer_16_List_3) return Integer_16_List_3 is
      use Adaflight.Sensor_Alignment;
      A : Alignment_Angles;
   begin
      if Alignment in 1 .. 8 then
         From_Standard (A, Standard_Alignment'Val (Alignment));
         return (A.Roll, A.Pitch, A.Yaw);
      elsif Alignment = 9 then
         return Custom;
      end if;
      return (others => 0);
   end Gyro_Angles;

   function To_Identity (Text : String) return Identity_Text is
      T : Identity_Text;
   begin
      for K in 1 .. Text'Length loop
         T.Data (K) := Text (Text'First + (K - 1));
      end loop;
      T.Length := Text'Length;
      return T;
   end To_Identity;

   --  The stored bytes before the first zero.
   function Stored_Text (B : Bytes) return String
     with Pre => B'Length <= 32, Post => Stored_Text'Result'First = 1 and then Stored_Text'Result'Length <= B'Length
   is
      Text : String (1 .. B'Length) := (others => ' ');
      Last : Natural := 0;
   begin
      for K in B'Range loop
         pragma Loop_Invariant (Last = K - B'First and then Last < B'Length);
         exit when B (K) = 0;
         Last := Last + 1;
         Text (Last) := Character'Val (B (K));
      end loop;
      return Text (1 .. Last);
   end Stored_Text;

   procedure Init (Board : in out State; C : Configuration) is
   begin
      Board.Information_Set := C.Board_Config.Board_Information_Set /= 0;
      if Board.Information_Set then
         Board.Manufacturer :=
           To_Identity (Stored_Text (C.Board_Config.Manufacturer_Id (0 .. Manufacturer_Length - 1)));
         Board.Name := To_Identity (Stored_Text (C.Board_Config.Board_Name (0 .. Board_Name_Length - 1)));
      end if;
      Board.Signature_Set := C.Board_Config.Signature_Set /= 0;
      if Board.Signature_Set then
         for K in Board.Signature'Range loop
            Board.Signature (K) := C.Board_Config.Signature (K);
         end loop;
      end if;
   end Init;

   procedure Store_Information (C : in out Configuration; Board : State) is
   begin
      C.Board_Config.Manufacturer_Id := (others => 0);
      for K in 0 .. Natural'Min (Board.Manufacturer.Length, Manufacturer_Length) - 1 loop
         C.Board_Config.Manufacturer_Id (K) := Character'Pos (Board.Manufacturer.Data (K + 1));
      end loop;
      C.Board_Config.Board_Name := (others => 0);
      for K in 0 .. Natural'Min (Board.Name.Length, Board_Name_Length) - 1 loop
         C.Board_Config.Board_Name (K) := Character'Pos (Board.Name.Data (K + 1));
      end loop;
      C.Board_Config.Board_Information_Set := 1;
   end Store_Information;

   procedure Store_Signature (C : in out Configuration; Board : State) is
   begin
      for K in Board.Signature'Range loop
         C.Board_Config.Signature (K) := Board.Signature (K);
      end loop;
      C.Board_Config.Signature_Set := 1;
   end Store_Signature;

   procedure Reset_Config (C : in out Configuration; Board : State) is
      H : Hardware_Defaults renames Board.Hardware;
   begin
      if Board.Information_Set then
         Store_Information (C, Board);
      end if;
      if Board.Signature_Set then
         Store_Signature (C, Board);
      end if;
      C.Adc_Config.Vbat.Enabled := H.Vbat.Enabled;
      C.Adc_Config.Vbat.Io_Tag := H.Vbat.Io_Tag;
      C.Adc_Config.External1.Enabled := H.External1.Enabled;
      C.Adc_Config.External1.Io_Tag := H.External1.Io_Tag;
      C.Adc_Config.Current.Enabled := H.Current.Enabled;
      C.Adc_Config.Current.Io_Tag := H.Current.Io_Tag;
      C.Adc_Config.Rssi.Enabled := H.RSSI.Enabled;
      C.Adc_Config.Rssi.Io_Tag := H.RSSI.Io_Tag;
      C.Beeper_Dev_Config.Is_Open_Drain := (if H.Beeper_Inverted then 0 else 1);
      C.Beeper_Dev_Config.Is_Inverted := (if H.Beeper_Inverted then 1 else 0);
      C.Beeper_Dev_Config.Io_Tag := H.Beeper_Tag;
      C.Beeper_Dev_Config.Frequency := H.Beeper_Frequency;
      C.Battery_Config.Voltage_Meter_Source := H.Voltage_Source;
      C.Battery_Config.Current_Meter_Source := H.Current_Source;
      C.Voltage_Sensor_Adc_Config (0).Vbatscale := H.Voltage_Scale;
      C.Current_Sensor_Adc_Config.Scale := H.Current_Scale;
      C.Max7456_Config.Cs_Tag := H.OSD_CS_Tag;
      C.Max7456_Config.Spi_Device := H.OSD_SPI_Device;
      C.Sdcard_Config.Device := H.SD_SPI_Device;
      C.Barometer_Config.Baro_Bus_Type := H.Baro_Bus_Type;
      C.Barometer_Config.Baro_I2c_Device := H.Baro_I2C_Device;
      C.Barometer_Config.Baro_I2c_Address := H.Baro_I2C_Address;
      C.Barometer_Config.Baro_Spi_Device := H.Baro_SPI_Device;
      C.Barometer_Config.Baro_Spi_Csn := H.Baro_CS_Tag;
      C.Barometer_Config.Baro_Eoc_Tag := H.Baro_EOC_Tag;
      C.Barometer_Config.Baro_Xclr_Tag := H.Baro_XCLR_Tag;
      C.Barometer_Config.Baro_Hardware := H.Baro_Hardware;
      C.Compass_Config.Mag_Bus_Type := H.Mag_Bus_Type;
      C.Compass_Config.Mag_I2c_Device := H.Mag_I2C_Device;
      C.Compass_Config.Mag_I2c_Address := H.Mag_I2C_Address;
      C.Compass_Config.Mag_Spi_Device := H.Mag_SPI_Device;
      C.Compass_Config.Mag_Spi_Csn := H.Mag_CS_Tag;
      C.Compass_Config.Interrupt_Tag := H.Mag_EXTI_Tag;
      C.Compass_Config.Mag_Alignment := H.Mag_Align;
      C.Timer_Io_Config := H.Timer_Map;
      C.Camera_Control_Config.Io_Tag := H.Camera_Control_Tag;
      C.Adc_Config.Dmaopt := H.ADC_DMA_Options;
      C.Esc_Serial_Config.Io_Tag := H.ESC_Serial_Tag;
      C.Status_Led_Config := (Io_Tags => (H.LED0_Tag, H.LED1_Tag, H.LED2_Tag), Inversion => H.LED_Inversion);
      C.Vtx_Io_Config :=
        (Cs_Tag => H.VTX_CS_Tag, Power_Tag => H.VTX_Power_Tag, Data_Tag => H.VTX_Data_Tag,
         Clock_Tag => H.VTX_Clock_Tag, Spi_Device => H.VTX_SPI_Device);
      C.Rx_Spi_Config.Rx_Spi_Protocol := H.RX_SPI_Protocol;
      C.Rx_Spi_Config.Csn_Tag := H.RX_SPI_CS_Tag;
      C.Rx_Spi_Config.Spibus := H.RX_SPI_Bus;
      C.Rx_Spi_Config.Exti_Io_Tag := H.RX_SPI_EXTI_Tag;
      C.Rx_Spi_Config.Bind_Io_Tag := H.RX_SPI_Bind_Tag;
      C.Rx_Spi_Config.Led_Io_Tag := H.RX_SPI_LED_Tag;
      C.Rx_Spi_Config.Led_Inversion := (if H.RX_SPI_LED_Inverted then 1 else 0);
      C.Rx_Express_Lrs_Spi_Config.Reset_Io_Tag := H.ELRS_Reset_Tag;
      C.Rx_Express_Lrs_Spi_Config.Busy_Io_Tag := H.ELRS_Busy_Tag;
      C.Rx_Cc2500_Spi_Config.Chip_Detect_Enabled := (if H.CC2500_Chip_Detect then 1 else 0);
      C.Rx_Cc2500_Spi_Config.Tx_En_Io_Tag := H.CC2500_TX_En_Tag;
      C.Rx_Cc2500_Spi_Config.Lna_En_Io_Tag := H.CC2500_LNA_En_Tag;
      C.Rx_Cc2500_Spi_Config.Ant_Sel_Io_Tag := H.CC2500_Ant_Sel_Tag;
      C.Sdcard_Config.Chip_Select_Tag := H.SD_CS_Tag;
      C.Sdcard_Config.Card_Detect_Tag := H.SD_Detect_Tag;
      C.Sdcard_Config.Card_Detect_Inverted := (if H.SD_Detect_Low then 1 else 0);
      C.Sdcard_Config.Mode := (if H.SD_SPI_Device > 0 and then H.SD_CS_Tag /= 0 then 1 else 0);
      C.Flash_Config.Spi_Device := H.Flash_SPI_Device;
      C.Flash_Config.Cs_Tag := H.Flash_CS_Tag;
      if H.Gyro_SPI_Device /= 0 then
         C.Gyro_Device_Config (0) :=
           (Index            => 0,
            Bus_Type         => 2,
            Spi_Bus          => H.Gyro_SPI_Device,
            Csn_Tag          => H.Gyro_CS_Tag,
            I2c_Bus          => 0,
            I2c_Address      => 0,
            Exti_Tag         => H.Gyro_EXTI_Tag,
            Alignment        => H.Gyro_Align,
            Custom_Alignment => Gyro_Angles (H.Gyro_Align, H.Gyro_Custom_Align),
            Clk_In           => H.Gyro_Clkin_Tag);
      end if;
      C.Blackbox_Config.Device := H.Blackbox_Device;
      for I in PINIO_Bytes'Range loop
         C.Pinio_Config.Io_Tag (I) := H.PINIO_Tags (I);
         C.Pinio_Config.Config (I) := H.PINIO_Configs (I);
         C.Pinio_Box_Config.Permanent_Id (I) := H.PINIO_Boxes (I);
      end loop;
      for I in Motor_Bytes'Range loop
         C.Motor_Config.Dev.Io_Tags (I) := H.Motor_Tags (I);
      end loop;
      C.Led_Strip_Config.Io_Tag := H.LED_Strip_Tag;
      declare
         Slots : constant Serial_Feature_Map.MSP_Ports :=
           MSP_Allocation.Default_Slots (H.MSP_First_Port, H.MSP_UART, H.MSP_Other_UART, H.MSP_Display_Port_UART);
      begin
         for S in Slots'Range loop
            C.Msp_Config.Msp_Uart (Natural (S) - 1) := Interfaces.Integer_8 (Slots (S));
         end loop;
      end;
   end Reset_Config;

   procedure Persist_Information (C : in out Configuration; Board : in out State) is
   begin
      Store_Information (C, Board);
      Init (Board, C);
   end Persist_Information;

   procedure Persist_Signature (C : in out Configuration; Board : in out State) is
   begin
      Store_Signature (C, Board);
      Init (Board, C);
   end Persist_Signature;

end Adaflight.Board_Info;
