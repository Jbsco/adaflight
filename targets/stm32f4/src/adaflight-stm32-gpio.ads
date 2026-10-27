--  GPIO ports of the STM32F405: the port clock in the RCC, a pin as a
--  push-pull output, an input or on an alternate function, and its level.
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.GPIO is

   type Alternate_Function is range 0 .. 15;

   type Pull is (No_Pull, Up, Down);

   --  The output speed classes of a pin.
   type Speed is (Low, Medium, High, Very_High);

   procedure Enable_Port (Port : Port_Name);

   procedure Set_Output (P : Pin);

   --  An output pin switched to open drain.
   procedure Set_Open_Drain (P : Pin);

   procedure Set_Input (P : Pin; Resistor : Pull := No_Pull);

   --  The pin in analog mode for the ADC, without pull resistors.
   procedure Set_Analog (P : Pin);

   --  The pin on an alternate function, push-pull at the given speed.
   procedure Set_Alternate
     (P : Pin; Func : Alternate_Function; Resistor : Pull := No_Pull; Rate : Speed := High);

   procedure Set_High (P : Pin);

   procedure Set_Low (P : Pin);

   procedure Toggle (P : Pin);

end Adaflight.STM32.GPIO;
