--  The MAVLink receiver's state and line, which the MAVLink telemetry rides
--  on when it shares the receiver's port. The state sits in core coupled
--  memory and starts at the receiver's init.
with Adaflight.MAVLink;
with Adaflight.STM32.USART;
package Adaflight.STM32.MAVLink_Link is
   State : Adaflight.MAVLink.State with Linker_Section => ".bss.ccm", Suppress_Initialization;
   Open  : Boolean := False;
   Line  : Adaflight.STM32.USART.Number := Adaflight.STM32.USART.Number'First;
end Adaflight.STM32.MAVLink_Link;
