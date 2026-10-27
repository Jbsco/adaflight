--  The iBus telemetry on a UART: the core's iBus sensors answering the
--  receiver's polls on the telemetry port of the first provider with the
--  iBus protocol, at 115200 baud on one wire, inverted when the telemetry's
--  inversion setting asks.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.IBus_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.IBus is
   --  The provider's port and its sharing, with the telemetry feature on, and
   --  the sensors' settings.
   procedure Init
     (Config   : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Settings : Adaflight.IBus_Telemetry.Settings);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task: every byte received, and the answers
   --  sent.
   procedure Run (Inp : Adaflight.IBus_Telemetry.Inputs);
end Adaflight.STM32.IBus;
