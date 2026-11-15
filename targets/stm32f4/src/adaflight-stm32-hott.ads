--  The HoTT telemetry on a UART: the core's HoTT link on the telemetry port
--  of the first provider with the HoTT protocol, at 19200 baud. A receiver
--  asks with two bytes and the link answers a byte per task run. The link
--  takes the port's waiting bytes as it reads or drops them.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.HoTT_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.HoTT is
   --  The provider's port and its sharing, with the telemetry feature on.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the telemetry task: whether the link asks for a new task
   --  period, and that period.
   procedure Run
     (Inp : Adaflight.HoTT_Telemetry.Inputs; GPS_Present : Boolean; Reschedule : out Boolean;
      Period_Us : out Interfaces.Integer_32);
end Adaflight.STM32.HoTT;
