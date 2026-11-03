--  The main stack's extent from the linker, and in a stack check build its
--  free part filled with a pattern once at start, so the deepest use shows
--  as the lowest byte that no longer holds the pattern.
with Interfaces;
package Adaflight.STM32.Stack_Check is
   --  The stack's size in bytes, and the address past its top.
   function Total return Interfaces.Unsigned_32;
   function High return Interfaces.Unsigned_32;
   --  The pattern from the stack's bottom up to below the caller's frame.
   procedure Paint;
   --  The bytes from the stack's top down to the lowest one written since
   --  the paint.
   function Used return Interfaces.Unsigned_32;
end Adaflight.STM32.Stack_Check;
