package body Adaflight.CLI_Resources with SPARK_Mode is

   Softserial_Offset : constant := 6;

   function Name (O : Owner) return String is
     (case O is
         when Beeper                  => "BEEPER",
         when Motor                   => "MOTOR",
         when Servo                   => "SERVO",
         when PPM                     => "PPM",
         when PWM                     => "PWM",
         when Sonar_Trigger           => "SONAR_TRIGGER",
         when Sonar_Echo              => "SONAR_ECHO",
         when LED_Strip               => "LED_STRIP",
         when Serial_TX               => "SERIAL_TX",
         when Serial_RX               => "SERIAL_RX",
         when Inverter                => "INVERTER",
         when Softserial_TX           => "SOFTSERIAL_TX",
         when Softserial_RX           => "SOFTSERIAL_RX",
         when I2C_SCL                 => "I2C_SCL",
         when I2C_SDA                 => "I2C_SDA",
         when LED                     => "LED",
         when RX_Bind                 => "RX_BIND",
         when RX_Bind_Plug            => "RX_BIND_PLUG",
         when Transponder             => "TRANSPONDER",
         when SPI_SCK                 => "SPI_SCK",
         when SPI_SDI                 => "SPI_SDI",
         when SPI_SDO                 => "SPI_SDO",
         when ADC_Batt                => "ADC_BATT",
         when ADC_RSSI                => "ADC_RSSI",
         when ADC_Curr                => "ADC_CURR",
         when ADC_Ext                 => "ADC_EXT",
         when Baro_CS                 => "BARO_CS",
         when Baro_EOC                => "BARO_EOC",
         when Baro_XCLR               => "BARO_XCLR",
         when Compass_CS              => "COMPASS_CS",
         when Compass_EXTI            => "COMPASS_EXTI",
         when SD_Card_Detect          => "SDCARD_DETECT",
         when PINIO                   => "PINIO",
         when USB_MSC_Pin             => "USB_MSC_PIN",
         when Flash_CS                => "FLASH_CS",
         when OSD_CS                  => "OSD_CS",
         when RX_SPI_CS               => "RX_SPI_CS",
         when RX_SPI_EXTI             => "RX_SPI_EXTI",
         when RX_SPI_Bind             => "RX_SPI_BIND",
         when RX_SPI_LED              => "RX_SPI_LED",
         when RX_SPI_CC2500_TX_EN     => "RX_SPI_CC2500_TX_EN",
         when RX_SPI_CC2500_LNA_EN    => "RX_SPI_CC2500_LNA_EN",
         when RX_SPI_CC2500_Ant_Sel   => "RX_SPI_CC2500_ANT_SEL",
         when RX_SPI_ExpressLRS_Reset => "RX_SPI_EXPRESSLRS_RESET",
         when RX_SPI_ExpressLRS_Busy  => "RX_SPI_EXPRESSLRS_BUSY",
         when Gyro_EXTI               => "GYRO_EXTI",
         when Gyro_CS                 => "GYRO_CS",
         when USB_Detect              => "USB_DETECT",
         when VTX_Power               => "VTX_POWER",
         when VTX_CS                  => "VTX_CS",
         when VTX_Data                => "VTX_DATA",
         when VTX_CLK                 => "VTX_CLK",
         when Pullup                  => "PULLUP",
         when Pulldown                => "PULLDOWN");

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
         when ADC_Batt                => C.Adc_Config.Vbat.Io_Tag,
         when ADC_RSSI                => C.Adc_Config.Rssi.Io_Tag,
         when ADC_Curr                => C.Adc_Config.Current.Io_Tag,
         when ADC_Ext                 => C.Adc_Config.External1.Io_Tag,
         when Baro_CS                 => C.Barometer_Config.Baro_Spi_Csn,
         when Baro_EOC                => C.Barometer_Config.Baro_Eoc_Tag,
         when Baro_XCLR               => C.Barometer_Config.Baro_Xclr_Tag,
         when Compass_CS              => C.Compass_Config.Mag_Spi_Csn,
         when Compass_EXTI            => C.Compass_Config.Interrupt_Tag,
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
         when ADC_Batt                => C.Adc_Config.Vbat.Io_Tag := T;
         when ADC_RSSI                => C.Adc_Config.Rssi.Io_Tag := T;
         when ADC_Curr                => C.Adc_Config.Current.Io_Tag := T;
         when ADC_Ext                 => C.Adc_Config.External1.Io_Tag := T;
         when Baro_CS                 => C.Barometer_Config.Baro_Spi_Csn := T;
         when Baro_EOC                => C.Barometer_Config.Baro_Eoc_Tag := T;
         when Baro_XCLR               => C.Barometer_Config.Baro_Xclr_Tag := T;
         when Compass_CS              => C.Compass_Config.Mag_Spi_Csn := T;
         when Compass_EXTI            => C.Compass_Config.Interrupt_Tag := T;
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
