--  GPIO ports of the STM32F405: the port clock in the RCC, a pin as a
--  push-pull output, an input or on an alternate function, and its level.
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.GPIO is

   type Alternate_Function is range 0 .. 15;

   type Pull is (No_Pull, Up, Down);

   procedure Enable_Port (Port : Port_Name);

   procedure Set_Output (P : Pin);

   procedure Set_Input (P : Pin; Resistor : Pull := No_Pull);

   --  The pin on an alternate function, push-pull at high speed.
   procedure Set_Alternate (P : Pin; Func : Alternate_Function; Resistor : Pull := No_Pull);

   procedure Set_High (P : Pin);

   procedure Set_Low (P : Pin);

   procedure Toggle (P : Pin);

end Adaflight.STM32.GPIO;
