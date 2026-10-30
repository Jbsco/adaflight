--  GPIO ports of the STM32F405: the port clock in the RCC, a pin as a
--  push-pull output, an input or on an alternate function, and its level.
with Interfaces; use Interfaces;
with System;
with Adaflight.Pins; use Adaflight.Pins;

package Adaflight.STM32.GPIO is

   type Alternate_Function is range 0 .. 15;

   type Pull is (No_Pull, Up, Down);

   --  The output speed classes of a pin.
   type Speed is (Low, Medium, High, Very_High);

   type Port_Registers is record
      MODER   : Unsigned_32;
      OTYPER  : Unsigned_32;
      OSPEEDR : Unsigned_32;
      PUPDR   : Unsigned_32;
      IDR     : Unsigned_32;
      ODR     : Unsigned_32;
      BSRR    : Unsigned_32;
      LCKR    : Unsigned_32;
      AFRL    : Unsigned_32;
      AFRH    : Unsigned_32;
   end record with Volatile;

   for Port_Registers use record
      MODER   at 16#00# range 0 .. 31;
      OTYPER  at 16#04# range 0 .. 31;
      OSPEEDR at 16#08# range 0 .. 31;
      PUPDR   at 16#0C# range 0 .. 31;
      IDR     at 16#10# range 0 .. 31;
      ODR     at 16#14# range 0 .. 31;
      BSRR    at 16#18# range 0 .. 31;
      LCKR    at 16#1C# range 0 .. 31;
      AFRL    at 16#20# range 0 .. 31;
      AFRH    at 16#24# range 0 .. 31;
   end record;

   --  A port's registers, the ports 16#400# apart from GPIOA on the AHB1 bus.
   Port_Base : constant array (Port_Name) of System.Address :=
     (Port_A => System'To_Address (16#4002_0000#),
      Port_B => System'To_Address (16#4002_0400#),
      Port_C => System'To_Address (16#4002_0800#),
      Port_D => System'To_Address (16#4002_0C00#),
      Port_E => System'To_Address (16#4002_1000#),
      Port_F => System'To_Address (16#4002_1400#),
      Port_G => System'To_Address (16#4002_1800#),
      Port_H => System'To_Address (16#4002_1C00#),
      Port_I => System'To_Address (16#4002_2000#),
      Port_J => System'To_Address (16#4002_2400#),
      Port_K => System'To_Address (16#4002_2800#));

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

   --  The level of a pin.
   function Is_High (P : Pin) return Boolean;

   procedure Set_High (P : Pin);

   procedure Set_Low (P : Pin);

   procedure Toggle (P : Pin);

end Adaflight.STM32.GPIO;
