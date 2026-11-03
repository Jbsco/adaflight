--  The host's stack belongs to its operating system: the image reports the
--  STM32F405's stack size and top, and no use.
package body Adaflight.STM32.Stack_Check is

   function Total return Interfaces.Unsigned_32 is (40_960);

   function High return Interfaces.Unsigned_32 is (16#2002_0000#);

   procedure Paint is null;

   function Used return Interfaces.Unsigned_32 is (0);

end Adaflight.STM32.Stack_Check;
