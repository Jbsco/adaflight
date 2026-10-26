--  GPIO ports of the STM32F405: the port clock in the RCC, a pin as a
--  push-pull output or on an alternate function, and its level.
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.GPIO is

   type Alternate_Function is range 0 .. 15;

   procedure Enable_Port (Port : Port_Name);

   procedure Set_Output (P : Pin);

   --  The pin on an alternate function, push-pull at high speed, with a
   --  pull-up when asked.
   procedure Set_Alternate (P : Pin; Func : Alternate_Function; Pull_Up : Boolean := False);

   procedure Set_High (P : Pin);

   procedure Set_Low (P : Pin);

   procedure Toggle (P : Pin);

end Adaflight.STM32.GPIO;
