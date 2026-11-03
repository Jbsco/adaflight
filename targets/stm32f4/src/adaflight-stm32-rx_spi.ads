--  The SPI receiver as the receiver core's provider: the device and the
--  protocol's family started from the configuration, the frame check, the
--  frame processing and the channel reads.
with Adaflight.Config_Groups;
with Adaflight.Receiver;
package Adaflight.STM32.RX_SPI is
   --  The receiver's select pin, before the buses start.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);
   --  The device and the protocol's family; when either fails to start, the
   --  frame check reports nothing and the channels read zero.
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   procedure Frame_Status (Report : out Adaflight.Receiver.Frame_Report);
   procedure Process_Frame;
   --  The channels the protocol carries.
   function Channel_Count return Natural;
   procedure Read_Raw (Ch : Natural; Value : out Float);
   procedure Stop;
   --  The time of the last frame, the interrupt edge that announced it.
   function Last_Frame_Us return Adaflight.Receiver.Time_Us;
end Adaflight.STM32.RX_SPI;
