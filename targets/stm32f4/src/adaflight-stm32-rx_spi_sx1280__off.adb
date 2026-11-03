--  The SX1280 receivers of a build without the chip: the ExpressLRS start
--  fails, so the SPI receiver reports nothing for it.
package body Adaflight.STM32.RX_SPI_SX1280 is

   procedure ExpressLRS_Init
     (Spi  : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      ELRS : Adaflight.Config_Groups.Rx_Express_Lrs_Spi_Config_Record;
      Ok   : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      pragma Unreferenced (Spi, ELRS);
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
   end ExpressLRS_Init;

   procedure ExpressLRS_Data_Received (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end ExpressLRS_Data_Received;

   procedure ExpressLRS_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is null;

   procedure ExpressLRS_Request_Bind is null;

   procedure ExpressLRS_Stop is null;

   procedure Start_Telemetry (Inp : Adaflight.ExpressLRS_Telemetry.Start_Inputs) is null;

   procedure Set_Telemetry_Sources (Src : Adaflight.CRSF_Telemetry.Sources) is null;

   procedure Serve_MSP is
   begin
      null;
   end Serve_MSP;

   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean) is
      pragma Unreferenced (C);
   begin
      Requested := False;
   end Take_Save;

end Adaflight.STM32.RX_SPI_SX1280;
