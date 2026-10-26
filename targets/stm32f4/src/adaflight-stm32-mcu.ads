--  The microcontroller itself: its unique identifier and the system reset.
with Interfaces;
package Adaflight.STM32.MCU is
   type Identifier is array (1 .. 3) of Interfaces.Unsigned_32;
   --  The device's unique identifier, the three words the status prints.
   function UID return Identifier;
   --  The core's reset through its application interrupt and reset control
   --  register.
   procedure Reset
     with No_Return;
end Adaflight.STM32.MCU;
