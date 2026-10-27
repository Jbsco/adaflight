--  The LTM telemetry on a UART: the stream of the core's LTM telemetry unit
--  on the telemetry port of the first provider with the LTM protocol, at the
--  provider's rate or 19200 baud.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.LTM_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.LTM is
   --  The provider's port and its sharing, with the telemetry feature on.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task.
   procedure Run (Now_Ms : Interfaces.Unsigned_32; Inp : Adaflight.LTM_Telemetry.Inputs);
end Adaflight.STM32.LTM;
