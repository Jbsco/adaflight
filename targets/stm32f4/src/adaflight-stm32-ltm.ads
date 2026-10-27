--  The LTM telemetry on a UART: the port the telemetry provider with the LTM
--  protocol names, at the provider's rate or 19200 baud, sending the stream
--  while its port has no other function, or, on a port shared with MSP,
--  while armed or while the telemetry box is on when it has a range.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.LTM_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.LTM is
   --  The provider's port and its sharing, with the telemetry feature on,
   --  and the port opened when its state allows.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  Whether the port is shared with MSP, which gives it up to the stream.
   function Shared_Port (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task.
   procedure Run (Now_Ms : Interfaces.Unsigned_32; Inp : Adaflight.LTM_Telemetry.Inputs);
end Adaflight.STM32.LTM;
