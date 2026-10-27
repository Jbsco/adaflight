--  The FrSky hub telemetry on a UART: the core's hub stream sent every
--  125 ms on the telemetry port of the first provider with the FrSky hub
--  protocol, at 9600 baud, inverted unless the telemetry's inversion setting
--  says otherwise.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.FrSky_Hub is
   --  The provider's port and its sharing, with the telemetry feature on, and
   --  the stream's settings.
   procedure Init
     (Config   : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
      Settings : Adaflight.FrSky_Hub_Telemetry.Settings);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task: the frames due, sent on the port.
   procedure Run (Inp : Adaflight.FrSky_Hub_Telemetry.Inputs);
end Adaflight.STM32.FrSky_Hub;
