--  The SPI receiver of a build without it: no device, so its start fails.
package body Adaflight.STM32.RX_SPI is

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Init (C : Adaflight.Config_Groups.Configuration; Telemetry : Boolean) is null;

   procedure Frame_Status (Report : out Adaflight.Receiver.Frame_Report) is
   begin
      Report := (others => False);
   end Frame_Status;

   procedure Process_Frame is
   begin
      null;
   end Process_Frame;

   function Channel_Count return Natural is (0);

   procedure Read_Raw (Ch : Natural; Value : out Float) is
      pragma Unreferenced (Ch);
   begin
      Value := 0.0;
   end Read_Raw;

   procedure Stop is null;

   procedure Bind is null;

   function Last_Frame_Us return Adaflight.Receiver.Time_Us is (0);

   function Claims_RSSI return Boolean is (False);

   function Takes_Readings return Boolean is (False);

   function Hub_Taken return Boolean is (False);

   function SmartPort_Taken return Boolean is (False);

   procedure Set_Readings (R : Telemetry_Readings) is null;

   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings) is null;

   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs) is null;

   procedure Set_Armed (Armed : Boolean) is null;

   procedure Take_Save
     (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean; Notify : out Boolean)
   is
      pragma Unreferenced (C);
   begin
      Requested := False;
      Notify := False;
   end Take_Save;

end Adaflight.STM32.RX_SPI;
