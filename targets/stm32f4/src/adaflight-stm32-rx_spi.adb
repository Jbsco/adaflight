with Adaflight.RX_SPI;
with Adaflight.RX_SPI_Provider;
with Adaflight.STM32.RX_SPI_Device;
package body Adaflight.STM32.RX_SPI is
   package Layer renames Adaflight.RX_SPI;

   Device_Config  : Adaflight.Config_Groups.Rx_Spi_Config_Record;
   Exti_Pull_Down : constant Boolean := False;
   Channels       : constant Natural := 0;
   State          : Layer.State;
   Frame_Us       : Adaflight.Receiver.Time_Us := 0;
   Started        : Boolean := False;

   procedure Device_Init (Ok : out Boolean) is
   begin
      RX_SPI_Device.Init (Device_Config, Ok);
   end Device_Init;

   --  No family runs on the board yet, so every protocol's start fails.
   procedure Family_Init (F : Layer.Family; Ok : out Boolean) is
      pragma Unreferenced (F);
   begin
      Ok := False;
   end Family_Init;

   procedure Exti_Init is
   begin
      RX_SPI_Device.Exti_Init (Exti_Pull_Down);
   end Exti_Init;

   procedure Dispatch_Enable is null;

   procedure Family_Data_Received (F : Layer.Family; R : out Layer.Received) is
      pragma Unreferenced (F);
   begin
      R := (others => False);
   end Family_Data_Received;

   procedure Family_Process_Frame (F : Layer.Family; R : out Layer.Received) is
      pragma Unreferenced (F);
   begin
      R := (others => False);
   end Family_Process_Frame;

   procedure Family_Set_Channels (F : Layer.Family; Data : in out Layer.Channel_Data) is null;

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

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      Ok, Providing : Boolean;
   begin
      Device_Config := C.Rx_Spi_Config;
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
   begin
      Provider.Process_Frame (State);
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

   function Last_Frame_Us return Adaflight.Receiver.Time_Us is (Frame_Us);
end Adaflight.STM32.RX_SPI;
