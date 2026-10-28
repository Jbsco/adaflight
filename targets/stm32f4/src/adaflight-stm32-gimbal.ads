--  The gimbal on a UART: the port the gimbal setting names at 115200 baud,
--  opened when the devices that open before it leave that UART free, and
--  the gimbal task, which passes the head tracker's bytes on to the gimbal
--  and sends the gimbal its command frames mixed with the sticks.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Gimbal_Control;
with Adaflight.STM32.USART;
package Adaflight.STM32.Gimbal is
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Sticks : Adaflight.Gimbal_Control.Sticks);
   --  Whether the port holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the gimbal task over every byte received since the last,
   --  with the stored gimbal settings and the sticks, and whether the task
   --  stops for want of a port.
   procedure Update
     (Config : Adaflight.Config_Groups.Configuration; Sticks : Adaflight.Gimbal_Control.Sticks;
      Now_Us : Interfaces.Unsigned_32; Stop_Task : out Boolean);
end Adaflight.STM32.Gimbal;
