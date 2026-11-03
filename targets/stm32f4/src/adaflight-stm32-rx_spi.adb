with Adaflight.RX_SPI;
with Adaflight.RX_SPI_Provider;
with Adaflight.STM32.RX_SPI_CC2500;
with Adaflight.STM32.RX_SPI_Device;
package body Adaflight.STM32.RX_SPI is
   package Layer renames Adaflight.RX_SPI;
   use type Layer.Family;

   Spi_Config     : Adaflight.Config_Groups.Rx_Spi_Config_Record;
   CC2500_Config  : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
   Exti_Pull_Down : constant Boolean := False;
   Channels       : Natural := 0;
   RSSI_Claimed   : Boolean := False;
   Telemetry_On   : Boolean := False;
   State          : Layer.State;
   Frame_Us       : Adaflight.Receiver.Time_Us := 0;
   Started        : Boolean := False;

   procedure Device_Init (Ok : out Boolean) is
   begin
      RX_SPI_Device.Init (Spi_Config, Ok);
   end Device_Init;

   --  The FrSky, SFHSS and Redpine families run on the board; every other
   --  protocol's start fails.
   procedure Family_Init (F : Layer.Family; Ok : out Boolean) is
   begin
      case F is
         when Layer.FrSky =>
            RX_SPI_CC2500.FrSky_Init (Spi_Config, CC2500_Config, Telemetry_On, Ok, Channels, RSSI_Claimed);
         when Layer.SFHSS =>
            RX_SPI_CC2500.SFHSS_Init (Spi_Config, CC2500_Config, Ok, Channels, RSSI_Claimed);
         when Layer.Redpine =>
            RX_SPI_CC2500.Redpine_Init (Spi_Config, CC2500_Config, Ok, Channels, RSSI_Claimed);
         when others =>
            Ok := False;
      end case;
   end Family_Init;

   procedure Exti_Init is
   begin
      RX_SPI_Device.Exti_Init (Exti_Pull_Down);
   end Exti_Init;

   procedure Dispatch_Enable is null;

   procedure Family_Data_Received (F : Layer.Family; R : out Layer.Received) is
   begin
      case F is
         when Layer.FrSky =>
            RX_SPI_CC2500.FrSky_Data_Received (R);
         when Layer.SFHSS =>
            RX_SPI_CC2500.SFHSS_Data_Received (R);
         when Layer.Redpine =>
            RX_SPI_CC2500.Redpine_Data_Received (R);
         when others =>
            R := (others => False);
      end case;
   end Family_Data_Received;

   procedure Family_Process_Frame (F : Layer.Family; R : out Layer.Received) is
   begin
      case F is
         when Layer.FrSky =>
            RX_SPI_CC2500.FrSky_Process_Frame (R);
         when others =>
            R := (others => False);
      end case;
   end Family_Process_Frame;

   procedure Family_Set_Channels (F : Layer.Family; Data : in out Layer.Channel_Data) is
   begin
      case F is
         when Layer.FrSky =>
            RX_SPI_CC2500.FrSky_Set_Channels (Data);
         when Layer.SFHSS =>
            RX_SPI_CC2500.SFHSS_Set_Channels (Data);
         when Layer.Redpine =>
            RX_SPI_CC2500.Redpine_Set_Channels (Data);
         when others =>
            null;
      end case;
   end Family_Set_Channels;

   procedure Family_Stop (F : Layer.Family) is null;

   package Provider is new Adaflight.RX_SPI_Provider
     (Device_Init          => Device_Init,
      Family_Init          => Family_Init,
      Exti_Configured      => RX_SPI_Device.Exti_Configured,
      Exti_Init            => Exti_Init,
      Dispatch_Enable      => Dispatch_Enable,
      Family_Data_Received => Family_Data_Received,
      Family_Process_Frame => Family_Process_Frame,
      Family_Set_Channels  => Family_Set_Channels,
      Family_Stop          => Family_Stop,
      Last_Exti_Time       => RX_SPI_Device.Last_Exti_Time);

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is
   begin
      RX_SPI_Device.Preinit (C.Rx_Spi_Config);
   end Preinit;

   procedure Init (C : Adaflight.Config_Groups.Configuration; Telemetry : Boolean) is
      Ok, Providing : Boolean;
   begin
      Telemetry_On := Telemetry;
      Spi_Config := C.Rx_Spi_Config;
      CC2500_Config := C.Rx_Cc2500_Spi_Config;
      Provider.Init (State, C.Rx_Spi_Config.Rx_Spi_Protocol, Ok, Providing);
      Started := Ok and then Providing;
   end Init;

   procedure Frame_Status (Report : out Adaflight.Receiver.Frame_Report) is
   begin
      if Started then
         Provider.Frame_Status (State, Report, Frame_Us);
      else
         Report := (others => False);
      end if;
   end Frame_Status;

   procedure Process_Frame is
      procedure Answer_MSP is new RX_SPI_CC2500.FrSky_Answer_MSP (Answer);
   begin
      if SmartPort_Taken then
         RX_SPI_CC2500.Set_SmartPort_Values (SmartPort_Values);
      end if;
      Provider.Process_Frame (State);
      if SmartPort_Taken and then RX_SPI_CC2500.FrSky_MSP_Pending then
         Answer_MSP;
      end if;
   end Process_Frame;

   function Channel_Count return Natural is (Channels);

   procedure Read_Raw (Ch : Natural; Value : out Float) is
   begin
      if Started then
         Provider.Read_Raw (State, Channels, Ch, Value);
      else
         Value := 0.0;
      end if;
   end Read_Raw;

   procedure Stop is
   begin
      Provider.Stop (State);
   end Stop;

   procedure Bind is
   begin
      if Started and then State.Selected = Layer.FrSky then
         RX_SPI_CC2500.FrSky_Request_Bind;
      elsif Started and then State.Selected = Layer.SFHSS then
         RX_SPI_CC2500.SFHSS_Request_Bind;
      elsif Started and then State.Selected = Layer.Redpine then
         RX_SPI_CC2500.Redpine_Request_Bind;
      end if;
   end Bind;

   function Last_Frame_Us return Adaflight.Receiver.Time_Us is (Frame_Us);

   function Claims_RSSI return Boolean is (Started and then RSSI_Claimed);

   function Takes_Readings return Boolean is (Started and then State.Selected = Layer.FrSky);

   function Hub_Taken return Boolean is (Takes_Readings and then RX_SPI_CC2500.FrSky_Hub_Taken);

   function SmartPort_Taken return Boolean is (Takes_Readings and then RX_SPI_CC2500.FrSky_SmartPort_Taken);

   procedure Set_Readings (R : Telemetry_Readings) is
   begin
      RX_SPI_CC2500.Set_Readings (R);
   end Set_Readings;

   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings) is
   begin
      RX_SPI_CC2500.Set_Hub_Settings (S);
   end Set_Hub_Settings;

   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs) is
   begin
      RX_SPI_CC2500.Set_SmartPort_Build (B);
   end Set_SmartPort_Build;

   procedure Set_Armed (Armed : Boolean) is
   begin
      RX_SPI_CC2500.Set_Armed (Armed);
   end Set_Armed;

   procedure Take_Save
     (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean; Notify : out Boolean)
   is
   begin
      if Started and then State.Selected in Layer.FrSky | Layer.SFHSS | Layer.Redpine then
         RX_SPI_CC2500.Take_Save (C, Requested, Notify);
      else
         Requested := False;
         Notify := False;
      end if;
   end Take_Save;
end Adaflight.STM32.RX_SPI;
