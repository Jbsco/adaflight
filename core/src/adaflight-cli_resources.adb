package body Adaflight.CLI_Resources with SPARK_Mode is

   Softserial_Offset : constant := 6;

   --  The owner names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Owner_Name_Pool_Length : constant := 539;
   Owner_Name_Text : constant String (1 .. Owner_Name_Pool_Length + 23) :=
     "BEEPERMOTORSERVOPPMPWMSONAR_TRIGGERSONAR_ECHOLED_STRIPSERIAL_TXSERIAL_RXINVERTERSOFTSERIAL_TXSOFTSER"
     & "IAL_RXI2C_SCLI2C_SDARX_BINDRX_BIND_PLUGTRANSPONDERSPI_SCKSPI_SDISPI_SDOESCSERIALCAMERA_CONTROLADC_BA"
     & "TTADC_RSSIADC_CURRADC_EXTBARO_CSBARO_EOCBARO_XCLRCOMPASS_CSCOMPASS_EXTISDCARD_CSSDCARD_DETECTPINIOUS"
     & "B_MSC_PINFLASH_CSOSD_CSRX_SPI_CSRX_SPI_EXTIRX_SPI_BINDRX_SPI_LEDRX_SPI_CC2500_TX_ENRX_SPI_CC2500_LNA"
     & "_ENRX_SPI_CC2500_ANT_SELRX_SPI_EXPRESSLRS_RESETRX_SPI_EXPRESSLRS_BUSYGYRO_EXTIGYRO_CSUSB_DETECTVTX_P"
     & "OWERVTX_CSVTX_DATAVTX_CLKPULLUPPULLDOWN                       ";
   type Owner_Name_Start is range 0 .. Owner_Name_Pool_Length;
   type Owner_Name_Length is range 3 .. 23;
   Owner_Name_Starts : constant array (Owner) of Owner_Name_Start :=
     (Beeper => 0, Motor => 6, Servo => 11, PPM => 16, PWM => 19, Sonar_Trigger => 22, Sonar_Echo => 35, LED_Strip
      => 45, Serial_TX => 54, Serial_RX => 63, Inverter => 72, Softserial_TX => 80, Softserial_RX => 93, I2C_SCL =>
      106, I2C_SDA => 113, LED => 45, RX_Bind => 120, RX_Bind_Plug => 127, Transponder => 139, SPI_SCK => 150,
      SPI_SDI => 157, SPI_SDO => 164, ESC_Serial => 171, Camera_Control => 180, ADC_Batt => 194, ADC_RSSI => 202,
      ADC_Curr => 210, ADC_Ext => 218, Baro_CS => 225, Baro_EOC => 232, Baro_XCLR => 240, Compass_CS => 249,
      Compass_EXTI => 259, SD_Card_CS => 271, SD_Card_Detect => 280, PINIO => 293, USB_MSC_Pin => 298, Flash_CS =>
      309, OSD_CS => 317, RX_SPI_CS => 323, RX_SPI_EXTI => 332, RX_SPI_Bind => 343, RX_SPI_LED => 354,
      RX_SPI_CC2500_TX_EN => 364, RX_SPI_CC2500_LNA_EN => 383, RX_SPI_CC2500_Ant_Sel => 403, RX_SPI_ExpressLRS_Reset
      => 424, RX_SPI_ExpressLRS_Busy => 447, Gyro_EXTI => 469, Gyro_CS => 478, USB_Detect => 485, VTX_Power => 495,
      VTX_CS => 504, VTX_Data => 510, VTX_CLK => 518, Pullup => 525, Pulldown => 531);
   Owner_Name_Lengths : constant array (Owner) of Owner_Name_Length :=
     (Beeper => 6, Motor => 5, Servo => 5, PPM => 3, PWM => 3, Sonar_Trigger => 13, Sonar_Echo => 10, LED_Strip =>
      9, Serial_TX => 9, Serial_RX => 9, Inverter => 8, Softserial_TX => 13, Softserial_RX => 13, I2C_SCL => 7,
      I2C_SDA => 7, LED => 3, RX_Bind => 7, RX_Bind_Plug => 12, Transponder => 11, SPI_SCK => 7, SPI_SDI => 7,
      SPI_SDO => 7, ESC_Serial => 9, Camera_Control => 14, ADC_Batt => 8, ADC_RSSI => 8, ADC_Curr => 8, ADC_Ext =>
      7, Baro_CS => 7, Baro_EOC => 8, Baro_XCLR => 9, Compass_CS => 10, Compass_EXTI => 12, SD_Card_CS => 9,
      SD_Card_Detect => 13, PINIO => 5, USB_MSC_Pin => 11, Flash_CS => 8, OSD_CS => 6, RX_SPI_CS => 9, RX_SPI_EXTI
      => 11, RX_SPI_Bind => 11, RX_SPI_LED => 10, RX_SPI_CC2500_TX_EN => 19, RX_SPI_CC2500_LNA_EN => 20,
      RX_SPI_CC2500_Ant_Sel => 21, RX_SPI_ExpressLRS_Reset => 23, RX_SPI_ExpressLRS_Busy => 22, Gyro_EXTI => 9,
      Gyro_CS => 7, USB_Detect => 10, VTX_Power => 9, VTX_CS => 6, VTX_Data => 8, VTX_CLK => 7, Pullup => 6,
      Pulldown => 8);

   function Name (O : Owner) return String
   is
      Start : constant Natural := Natural (Owner_Name_Starts (O));
      Text  : constant String (1 .. Natural (Owner_Name_Lengths (O))) :=
        Owner_Name_Text (Start + 1 .. Start + Natural (Owner_Name_Lengths (O)));
   begin
      return Text;
   end Name;

   function Tag (C : Configuration; O : Owner; I : Natural) return Unsigned_8 is
     (case O is
         when Beeper                  => C.Beeper_Dev_Config.Io_Tag,
         when Motor                   => C.Motor_Config.Dev.Io_Tags (I),
         when Servo                   => C.Servo_Config.Dev.Io_Tags (I),
         when PPM                     => C.Ppm_Config.Io_Tag,
         when PWM                     => C.Pwm_Config.Io_Tags (I),
         when Sonar_Trigger           => C.Sonar_Config.Trigger_Tag,
         when Sonar_Echo              => C.Sonar_Config.Echo_Tag,
         when LED_Strip               => C.Led_Strip_Config.Io_Tag,
         when Serial_TX               => C.Serial_Pin_Config.Io_Tag_Tx (I),
         when Serial_RX               => C.Serial_Pin_Config.Io_Tag_Rx (I),
         when Inverter                => C.Serial_Pin_Config.Io_Tag_Inverter (I),
         when Softserial_TX           => C.Serial_Pin_Config.Io_Tag_Tx (Softserial_Offset + I),
         when Softserial_RX           => C.Serial_Pin_Config.Io_Tag_Rx (Softserial_Offset + I),
         when I2C_SCL                 => C.I2c_Config (I).Io_Tag_Scl,
         when I2C_SDA                 => C.I2c_Config (I).Io_Tag_Sda,
         when LED                     => C.Status_Led_Config.Io_Tags (I),
         when RX_Bind                 => C.Rx_Config.Spektrum_Bind_Pin_Override_Io_Tag,
         when RX_Bind_Plug            => C.Rx_Config.Spektrum_Bind_Plug_Io_Tag,
         when Transponder             => C.Transponder_Config.Io_Tag,
         when SPI_SCK                 => C.Spi_Pin_Config (I).Io_Tag_Sck,
         when SPI_SDI                 => C.Spi_Pin_Config (I).Io_Tag_Miso,
         when SPI_SDO                 => C.Spi_Pin_Config (I).Io_Tag_Mosi,
         when ESC_Serial              => C.Esc_Serial_Config.Io_Tag,
         when Camera_Control          => C.Camera_Control_Config.Io_Tag,
         when ADC_Batt                => C.Adc_Config.Vbat.Io_Tag,
         when ADC_RSSI                => C.Adc_Config.Rssi.Io_Tag,
         when ADC_Curr                => C.Adc_Config.Current.Io_Tag,
         when ADC_Ext                 => C.Adc_Config.External1.Io_Tag,
         when Baro_CS                 => C.Barometer_Config.Baro_Spi_Csn,
         when Baro_EOC                => C.Barometer_Config.Baro_Eoc_Tag,
         when Baro_XCLR               => C.Barometer_Config.Baro_Xclr_Tag,
         when Compass_CS              => C.Compass_Config.Mag_Spi_Csn,
         when Compass_EXTI            => C.Compass_Config.Interrupt_Tag,
         when SD_Card_CS              => C.Sdcard_Config.Chip_Select_Tag,
         when SD_Card_Detect          => C.Sdcard_Config.Card_Detect_Tag,
         when PINIO                   => C.Pinio_Config.Io_Tag (I),
         when USB_MSC_Pin             => C.Usb_Dev_Config.Msc_Button_Pin,
         when Flash_CS                => C.Flash_Config.Cs_Tag,
         when OSD_CS                  => C.Max7456_Config.Cs_Tag,
         when RX_SPI_CS               => C.Rx_Spi_Config.Csn_Tag,
         when RX_SPI_EXTI             => C.Rx_Spi_Config.Exti_Io_Tag,
         when RX_SPI_Bind             => C.Rx_Spi_Config.Bind_Io_Tag,
         when RX_SPI_LED              => C.Rx_Spi_Config.Led_Io_Tag,
         when RX_SPI_CC2500_TX_EN     => C.Rx_Cc2500_Spi_Config.Tx_En_Io_Tag,
         when RX_SPI_CC2500_LNA_EN    => C.Rx_Cc2500_Spi_Config.Lna_En_Io_Tag,
         when RX_SPI_CC2500_Ant_Sel   => C.Rx_Cc2500_Spi_Config.Ant_Sel_Io_Tag,
         when RX_SPI_ExpressLRS_Reset => C.Rx_Express_Lrs_Spi_Config.Reset_Io_Tag,
         when RX_SPI_ExpressLRS_Busy  => C.Rx_Express_Lrs_Spi_Config.Busy_Io_Tag,
         when Gyro_EXTI               => C.Gyro_Device_Config (I).Exti_Tag,
         when Gyro_CS                 => C.Gyro_Device_Config (I).Csn_Tag,
         when USB_Detect              => C.Usb_Dev_Config.Detect_Pin,
         when VTX_Power               => C.Vtx_Io_Config.Power_Tag,
         when VTX_CS                  => C.Vtx_Io_Config.Cs_Tag,
         when VTX_Data                => C.Vtx_Io_Config.Data_Tag,
         when VTX_CLK                 => C.Vtx_Io_Config.Clock_Tag,
         when Pullup                  => C.Pin_Pullup_Config (I).Io_Tag,
         when Pulldown                => C.Pin_Pulldown_Config (I).Io_Tag);

   procedure Set_Tag (C : in out Configuration; O : Owner; I : Natural; T : Unsigned_8) is
   begin
      case O is
         when Beeper                  => C.Beeper_Dev_Config.Io_Tag := T;
         when Motor                   => C.Motor_Config.Dev.Io_Tags (I) := T;
         when Servo                   => C.Servo_Config.Dev.Io_Tags (I) := T;
         when PPM                     => C.Ppm_Config.Io_Tag := T;
         when PWM                     => C.Pwm_Config.Io_Tags (I) := T;
         when Sonar_Trigger           => C.Sonar_Config.Trigger_Tag := T;
         when Sonar_Echo              => C.Sonar_Config.Echo_Tag := T;
         when LED_Strip               => C.Led_Strip_Config.Io_Tag := T;
         when Serial_TX               => C.Serial_Pin_Config.Io_Tag_Tx (I) := T;
         when Serial_RX               => C.Serial_Pin_Config.Io_Tag_Rx (I) := T;
         when Inverter                => C.Serial_Pin_Config.Io_Tag_Inverter (I) := T;
         when Softserial_TX           => C.Serial_Pin_Config.Io_Tag_Tx (Softserial_Offset + I) := T;
         when Softserial_RX           => C.Serial_Pin_Config.Io_Tag_Rx (Softserial_Offset + I) := T;
         when I2C_SCL                 => C.I2c_Config (I).Io_Tag_Scl := T;
         when I2C_SDA                 => C.I2c_Config (I).Io_Tag_Sda := T;
         when LED                     => C.Status_Led_Config.Io_Tags (I) := T;
         when RX_Bind                 => C.Rx_Config.Spektrum_Bind_Pin_Override_Io_Tag := T;
         when RX_Bind_Plug            => C.Rx_Config.Spektrum_Bind_Plug_Io_Tag := T;
         when Transponder             => C.Transponder_Config.Io_Tag := T;
         when SPI_SCK                 => C.Spi_Pin_Config (I).Io_Tag_Sck := T;
         when SPI_SDI                 => C.Spi_Pin_Config (I).Io_Tag_Miso := T;
         when SPI_SDO                 => C.Spi_Pin_Config (I).Io_Tag_Mosi := T;
         when ESC_Serial              => C.Esc_Serial_Config.Io_Tag := T;
         when Camera_Control          => C.Camera_Control_Config.Io_Tag := T;
         when ADC_Batt                => C.Adc_Config.Vbat.Io_Tag := T;
         when ADC_RSSI                => C.Adc_Config.Rssi.Io_Tag := T;
         when ADC_Curr                => C.Adc_Config.Current.Io_Tag := T;
         when ADC_Ext                 => C.Adc_Config.External1.Io_Tag := T;
         when Baro_CS                 => C.Barometer_Config.Baro_Spi_Csn := T;
         when Baro_EOC                => C.Barometer_Config.Baro_Eoc_Tag := T;
         when Baro_XCLR               => C.Barometer_Config.Baro_Xclr_Tag := T;
         when Compass_CS              => C.Compass_Config.Mag_Spi_Csn := T;
         when Compass_EXTI            => C.Compass_Config.Interrupt_Tag := T;
         when SD_Card_CS              => C.Sdcard_Config.Chip_Select_Tag := T;
         when SD_Card_Detect          => C.Sdcard_Config.Card_Detect_Tag := T;
         when PINIO                   => C.Pinio_Config.Io_Tag (I) := T;
         when USB_MSC_Pin             => C.Usb_Dev_Config.Msc_Button_Pin := T;
         when Flash_CS                => C.Flash_Config.Cs_Tag := T;
         when OSD_CS                  => C.Max7456_Config.Cs_Tag := T;
         when RX_SPI_CS               => C.Rx_Spi_Config.Csn_Tag := T;
         when RX_SPI_EXTI             => C.Rx_Spi_Config.Exti_Io_Tag := T;
         when RX_SPI_Bind             => C.Rx_Spi_Config.Bind_Io_Tag := T;
         when RX_SPI_LED              => C.Rx_Spi_Config.Led_Io_Tag := T;
         when RX_SPI_CC2500_TX_EN     => C.Rx_Cc2500_Spi_Config.Tx_En_Io_Tag := T;
         when RX_SPI_CC2500_LNA_EN    => C.Rx_Cc2500_Spi_Config.Lna_En_Io_Tag := T;
         when RX_SPI_CC2500_Ant_Sel   => C.Rx_Cc2500_Spi_Config.Ant_Sel_Io_Tag := T;
         when RX_SPI_ExpressLRS_Reset => C.Rx_Express_Lrs_Spi_Config.Reset_Io_Tag := T;
         when RX_SPI_ExpressLRS_Busy  => C.Rx_Express_Lrs_Spi_Config.Busy_Io_Tag := T;
         when Gyro_EXTI               => C.Gyro_Device_Config (I).Exti_Tag := T;
         when Gyro_CS                 => C.Gyro_Device_Config (I).Csn_Tag := T;
         when USB_Detect              => C.Usb_Dev_Config.Detect_Pin := T;
         when VTX_Power               => C.Vtx_Io_Config.Power_Tag := T;
         when VTX_CS                  => C.Vtx_Io_Config.Cs_Tag := T;
         when VTX_Data                => C.Vtx_Io_Config.Data_Tag := T;
         when VTX_CLK                 => C.Vtx_Io_Config.Clock_Tag := T;
         when Pullup                  => C.Pin_Pullup_Config (I).Io_Tag := T;
         when Pulldown                => C.Pin_Pulldown_Config (I).Io_Tag := T;
      end case;
   end Set_Tag;

end Adaflight.CLI_Resources;
