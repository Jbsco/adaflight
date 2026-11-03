--  The SX1280 receivers on the board: the ExpressLRS receiver on the chip,
--  its interrupt chain run from the receiver's interrupt line and from the
--  radio's busy pin, its timer, and the receiver task's calls with the
--  requests the receiver records carried out in order.
with Adaflight.Config_Groups;
with Adaflight.RX_SPI;
package Adaflight.STM32.RX_SPI_SX1280 is
   --  The ExpressLRS receiver started, with its channel count and whether it
   --  takes the RSSI; false without the interrupt line, for a band the chip
   --  does not cover, a timer this build does not drive, or a chip that does
   --  not start.
   procedure ExpressLRS_Init
     (Spi  : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      ELRS : Adaflight.Config_Groups.Rx_Express_Lrs_Spi_Config_Record;
      Ok   : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure ExpressLRS_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure ExpressLRS_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure ExpressLRS_Request_Bind;
   procedure ExpressLRS_Stop;
   --  The receiver's settings into the configuration when it changed them,
   --  once.
   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean);
end Adaflight.STM32.RX_SPI_SX1280;
