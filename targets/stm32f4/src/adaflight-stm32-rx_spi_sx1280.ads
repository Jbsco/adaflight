--  The SX1280 receivers on the board: the ExpressLRS receiver on the chip,
--  its interrupt chain run from the receiver's interrupt line and from the
--  radio's busy pin, its timer, and the receiver task's calls with the
--  requests the receiver records carried out in order.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.CRSF_Telemetry;
with Adaflight.ExpressLRS_Telemetry;
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
   --  The telemetry's start: the payloads its sensors allow.
   procedure Start_Telemetry (Inp : Adaflight.ExpressLRS_Telemetry.Start_Inputs);
   --  The readings the telemetry frames send, as the telemetry task last
   --  read them.
   procedure Set_Telemetry_Sources (Src : Adaflight.CRSF_Telemetry.Sources);
   --  The MSP frames the transmitter sent since the last run: the reply's
   --  next chunk, or each frame through the MSP tunnel with a completed
   --  request answered through Answer, and the reply marked waiting.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
   procedure Serve_MSP;
   --  The receiver's settings into the configuration when it changed them,
   --  once.
   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean);
end Adaflight.STM32.RX_SPI_SX1280;
