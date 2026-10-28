--  A telemetry protocol's port on a UART: the port the first telemetry
--  provider with the protocol names, at the provider's rate or the
--  protocol's own default, open while the port has no other function, or,
--  on a port shared with MSP, while armed or while the telemetry box is on
--  when it has a range. A port another board function holds stays closed.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.USART;
generic
   Protocol     : Interfaces.Unsigned_8;
   Function_Bit : Interfaces.Unsigned_32;
   Default_Baud : Adaflight.Serial_Feature_Map.Baud_Index;
package Adaflight.STM32.Telemetry_Port is
   --  The provider's port and its sharing, with the telemetry feature on.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Enabled return Boolean;
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   function Line return Adaflight.STM32.USART.Number;
end Adaflight.STM32.Telemetry_Port;
