--  GPIO ports of the STM32F405: the port clock in the RCC, a pin as a
--  push-pull output, and its level.
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.GPIO is

   procedure Enable_Port (Port : Port_Name);

   procedure Set_Output (P : Pin);

   procedure Set_High (P : Pin);

   procedure Set_Low (P : Pin);

   procedure Toggle (P : Pin);

end Adaflight.STM32.GPIO;
