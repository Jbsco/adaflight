--  The USB controller's 48 MHz clock and supply, started before its clock
--  enable: nothing on F4 and F7, whose run time sets the PLL's 48 MHz output.
package Adaflight.STM32.USB_Clock is
   procedure Start;
end Adaflight.STM32.USB_Clock;
