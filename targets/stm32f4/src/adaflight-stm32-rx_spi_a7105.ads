--  The FlySky receivers on the board's A7105 radio: the chip's registers over
--  the SPI receiver's device, and the operations the receiver hands back run
--  in order with the registers and the FIFO it reads.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.RX_SPI;
package Adaflight.STM32.RX_SPI_A7105 is
   --  The receiver started for the configured protocol, with its channel
   --  count and whether it takes the RSSI; false without the interrupt line.
   procedure FlySky_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      FlySky : Adaflight.Config_Groups.Fly_Sky_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure FlySky_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure FlySky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure FlySky_Request_Bind;
   --  The battery voltage in centivolts, which an AFHDS 2A telemetry packet
   --  sends.
   procedure Set_Battery_Voltage (Centivolts : Interfaces.Unsigned_16);
   --  The bind data into the configuration when a completed bind asked to
   --  save it, once.
   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean);
end Adaflight.STM32.RX_SPI_A7105;
