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
   --  A bind request from the bind command.
   procedure Bind;
   --  The time of the last frame, the interrupt edge that announced it.
   function Last_Frame_Us return Adaflight.Receiver.Time_Us;
   --  Whether the protocol takes the RSSI when no other source is set.
   function Claims_RSSI return Boolean;
   --  The bind data into the configuration when a completed bind asked to
   --  save it, once.
   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean);
end Adaflight.STM32.RX_SPI;
