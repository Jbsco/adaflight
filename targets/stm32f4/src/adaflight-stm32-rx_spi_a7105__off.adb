--  The FlySky receivers of a build without the SPI radio receivers: the start
--  fails, so the SPI receiver reports nothing for them.
package body Adaflight.STM32.RX_SPI_A7105 is

   procedure FlySky_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      FlySky : Adaflight.Config_Groups.Fly_Sky_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      pragma Unreferenced (Spi, CC2500, FlySky);
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
   end FlySky_Init;

   procedure FlySky_Data_Received (R : out Adaflight.RX_SPI.Received) is
   begin
      R := (others => False);
   end FlySky_Data_Received;

   procedure FlySky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is null;

   procedure FlySky_Request_Bind is null;

   procedure Set_Battery_Voltage (Centivolts : Interfaces.Unsigned_16) is null;

   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean) is
      pragma Unreferenced (C);
   begin
      Requested := False;
   end Take_Save;

end Adaflight.STM32.RX_SPI_A7105;
