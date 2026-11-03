--  The CC2500 receivers on the board: the chip's registers over the SPI
--  receiver's device, the operations a family hands back run in order, and
--  the FrSky, SFHSS and Redpine families' calls with the measurements each
--  one reads.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.RX_SPI;
with Adaflight.SmartPort_Telemetry;
with Adaflight.STM32.RX_SPI;
package Adaflight.STM32.RX_SPI_CC2500 is
   --  The FrSky family started for the configured protocol, with its channel
   --  count and whether it takes the RSSI.
   procedure FrSky_Init
     (Spi       : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500    : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Telemetry : Boolean;
      Ok        : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure FrSky_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure FrSky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure FrSky_Request_Bind;
   --  The SFHSS family started, with its channel count and whether it takes
   --  the RSSI; it starts whether or not the chip answers.
   procedure SFHSS_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure SFHSS_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure SFHSS_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure SFHSS_Request_Bind;
   --  The Redpine family started, with its channel count and whether it takes
   --  the RSSI; false when the chip does not start.
   procedure Redpine_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean);
   procedure Redpine_Data_Received (R : out Adaflight.RX_SPI.Received);
   procedure Redpine_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data);
   procedure Redpine_Request_Bind;
   --  Whether the craft is armed, which a Redpine status frame reads.
   procedure Set_Armed (Armed : Boolean);
   --  Whether the FrSky D telemetry took the hub stream at start-up, and the
   --  FrSky X telemetry the SmartPort stream.
   function FrSky_Hub_Taken return Boolean;
   function FrSky_SmartPort_Taken return Boolean;
   procedure Set_Readings (R : Adaflight.STM32.RX_SPI.Telemetry_Readings);
   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings);
   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs);
   procedure Set_SmartPort_Values (V : Adaflight.SmartPort_Telemetry.Inputs);
   --  One processing pass of the X telemetry, and whether it left an MSP
   --  request over its link waiting for the reply.
   procedure FrSky_Process_Frame (R : out Adaflight.RX_SPI.Received);
   function FrSky_MSP_Pending return Boolean;
   --  The waiting MSP request answered through Answer, its reply prepared and
   --  the processing pass finished.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
   procedure FrSky_Answer_MSP;
   --  The bind data into the configuration when a completed bind asked to
   --  save it, or the VTX settings a status frame asked for, once; Notify for
   --  a save the pilot hears confirmed.
   procedure Take_Save
     (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean; Notify : out Boolean);
end Adaflight.STM32.RX_SPI_CC2500;
