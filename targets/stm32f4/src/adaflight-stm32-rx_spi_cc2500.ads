--  The CC2500 receivers on the board: the chip's registers over the SPI
--  receiver's device, the operations a family hands back run in order, and
--  the FrSky family's calls with the measurements each one reads.
with Adaflight.Config_Groups;
with Adaflight.RX_SPI;
package Adaflight.STM32.RX_SPI_CC2500 is
   --  The FrSky family started for the configured protocol, with its channel
   --  count and whether it takes the RSSI.
   procedure FrSky_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure FrSky_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure FrSky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure FrSky_Request_Bind;
   --  The bind data into the configuration when a completed bind asked to
   --  save it, once.
   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean);
end Adaflight.STM32.RX_SPI_CC2500;
