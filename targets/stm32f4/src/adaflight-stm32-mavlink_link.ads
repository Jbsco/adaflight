--  The MAVLink receiver's state and line, which the MAVLink telemetry rides
--  on when it shares the receiver's port. The state takes room only in a
--  build with a MAVLink feature, sits in core coupled memory and starts at
--  the receiver's init.
with Adaflight.Build_Features;
with Adaflight.MAVLink;
with Adaflight.STM32.USART;
package Adaflight.STM32.MAVLink_Link is
   Present : constant Boolean :=
     Adaflight.Build_Features.MAVLink_Receiver or else Adaflight.Build_Features.MAVLink_Telemetry;
   type State_Slot is array (1 .. (if Present then 1 else 0)) of Adaflight.MAVLink.State;
   Slot  : State_Slot with Linker_Section => ".bss.ccm", Suppress_Initialization;
   Open  : Boolean := False;
   Line  : Adaflight.STM32.USART.Number := Adaflight.STM32.USART.Number'First;
end Adaflight.STM32.MAVLink_Link;
