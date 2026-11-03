--  The SPI receiver of a build without it: no device, so its start fails.
package body Adaflight.STM32.RX_SPI is

   procedure Preinit (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Frame_Status (Report : out Adaflight.Receiver.Frame_Report) is
   begin
      Report := (others => False);
   end Frame_Status;

   procedure Process_Frame is null;

   function Channel_Count return Natural is (0);

   procedure Read_Raw (Ch : Natural; Value : out Float) is
      pragma Unreferenced (Ch);
   begin
      Value := 0.0;
   end Read_Raw;

   procedure Stop is null;

   function Last_Frame_Us return Adaflight.Receiver.Time_Us is (0);

end Adaflight.STM32.RX_SPI;
