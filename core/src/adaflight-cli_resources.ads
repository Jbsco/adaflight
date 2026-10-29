--  The command line's resource table: each pin owner the build names, in
--  the order the resource command lists them, how many of each it has, and
--  where the configuration keeps each one's pin.
with Interfaces; use Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.CLI_Resources with SPARK_Mode is

   type Owner is
     (Beeper, Motor, Servo, PPM, PWM, Sonar_Trigger, Sonar_Echo, LED_Strip, Serial_TX, Serial_RX, Inverter,
      Softserial_TX, Softserial_RX, I2C_SCL, I2C_SDA, LED, RX_Bind, RX_Bind_Plug, Transponder, SPI_SCK, SPI_SDI,
      SPI_SDO, ESC_Serial, Camera_Control, ADC_Batt, ADC_RSSI, ADC_Curr, ADC_Ext, Baro_CS, Baro_EOC, Baro_XCLR,
      Compass_CS, Compass_EXTI, SD_Card_CS, SD_Card_Detect, PINIO, USB_MSC_Pin, Flash_CS, OSD_CS, RX_SPI_CS,
      RX_SPI_EXTI, RX_SPI_Bind, RX_SPI_LED, RX_SPI_CC2500_TX_EN, RX_SPI_CC2500_LNA_EN, RX_SPI_CC2500_Ant_Sel,
      RX_SPI_ExpressLRS_Reset, RX_SPI_ExpressLRS_Busy, Gyro_EXTI, Gyro_CS, USB_Detect, VTX_Power, VTX_CS, VTX_Data,
      VTX_CLK, Pullup, Pulldown);

   --  The owner's name as the command line prints and reads it.
   function Name (O : Owner) return String
     with Post => Name'Result'First = 1 and then Name'Result'Length in 3 .. 23;

   --  The owners with an ordinal on the command line, and how many there
   --  are; zero for a single pin.
   function Max_Index (O : Owner) return Natural is
     (case O is
         when Motor | Servo | PWM => 8,
         when Serial_TX | Serial_RX | Inverter => 6,
         when Softserial_TX | Softserial_RX => 2,
         when I2C_SCL | I2C_SDA | LED | SPI_SCK | SPI_SDI | SPI_SDO => 3,
         when PINIO | Pullup | Pulldown => 4,
         when Gyro_EXTI | Gyro_CS => 1,
         when others => 0);

   --  The pins of an owner.
   function Count (O : Owner) return Positive is (if Max_Index (O) = 0 then 1 else Max_Index (O));

   --  The pin an owner's index holds in the configuration, zero for none.
   function Tag (C : Configuration; O : Owner; I : Natural) return Unsigned_8
     with Pre => I < Count (O);

   procedure Set_Tag (C : in out Configuration; O : Owner; I : Natural; T : Unsigned_8)
     with Pre => I < Count (O);

end Adaflight.CLI_Resources;
