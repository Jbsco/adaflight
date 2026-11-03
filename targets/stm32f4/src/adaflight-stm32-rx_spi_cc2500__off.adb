--  The CC2500 receivers of a build without the chip: every family's start
--  fails, so the SPI receiver reports nothing for them.
package body Adaflight.STM32.RX_SPI_CC2500 is

   procedure FrSky_Init
     (Spi       : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500    : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Telemetry : Boolean;
      Ok        : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      pragma Unreferenced (Spi, CC2500, Telemetry);
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
   end FrSky_Init;

   procedure FrSky_Data_Received (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end FrSky_Data_Received;

   procedure FrSky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is null;

   procedure FrSky_Request_Bind is null;

   procedure SFHSS_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      pragma Unreferenced (Spi, CC2500);
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
   end SFHSS_Init;

   procedure SFHSS_Data_Received (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end SFHSS_Data_Received;

   procedure SFHSS_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is null;

   procedure SFHSS_Request_Bind is null;

   procedure Redpine_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      pragma Unreferenced (Spi, CC2500);
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
   end Redpine_Init;

   procedure Redpine_Data_Received (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end Redpine_Data_Received;

   procedure Redpine_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is null;

   procedure Redpine_Request_Bind is null;

   procedure Set_Armed (Armed : Boolean) is null;

   function FrSky_Hub_Taken return Boolean is (False);

   function FrSky_SmartPort_Taken return Boolean is (False);

   procedure Set_Readings (R : Adaflight.STM32.RX_SPI.Telemetry_Readings) is null;

   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings) is null;

   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs) is null;

   procedure Set_SmartPort_Values (V : Adaflight.SmartPort_Telemetry.Inputs) is null;

   procedure FrSky_Process_Frame (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end FrSky_Process_Frame;

   function FrSky_MSP_Pending return Boolean is (False);

   procedure FrSky_Answer_MSP is
   begin
      null;
   end FrSky_Answer_MSP;

   procedure Take_Save
     (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean; Notify : out Boolean)
   is
      pragma Unreferenced (C);
   begin
      Requested := False;
      Notify := False;
   end Take_Save;

end Adaflight.STM32.RX_SPI_CC2500;
