--  Bring-up checks of the STM32H7 image: rising edges on the first gyro's
--  interrupt pin, counted from its external interrupt line.
package Adaflight.STM32.Bring_Up is
   procedure Watch_Gyro_Interrupt;
   function Edges return Natural;
end Adaflight.STM32.Bring_Up;
