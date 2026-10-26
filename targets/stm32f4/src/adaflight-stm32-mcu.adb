with System;
package body Adaflight.STM32.MCU is
   Unique : Identifier with Import, Volatile, Address => System'To_Address (16#1FFF_7A10#);

   --  The key in the high half with the system reset request.
   AIRCR : Interfaces.Unsigned_32 with Import, Volatile, Address => System'To_Address (16#E000_ED0C#);
   System_Reset_Request : constant Interfaces.Unsigned_32 := 16#05FA_0004#;

   function UID return Identifier is (Unique);

   procedure Reset is
   begin
      AIRCR := System_Reset_Request;
      loop
         null;
      end loop;
   end Reset;
end Adaflight.STM32.MCU;
