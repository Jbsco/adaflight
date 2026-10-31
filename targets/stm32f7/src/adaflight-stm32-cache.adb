with Interfaces;
with System;
with System.Machine_Code;

package body Adaflight.STM32.Cache is
   use type Interfaces.Unsigned_32;

   CCR     : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);
   ICIALLU : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF50#);
   IC      : constant Interfaces.Unsigned_32 := 2 ** 17;

   procedure Barrier is
   begin
      System.Machine_Code.Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
   end Barrier;

   procedure Enable is
   begin
      Barrier;
      ICIALLU := 0;
      Barrier;
      CCR := CCR or IC;
      Barrier;
   end Enable;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Enable'Access
     with Export, External_Name => "adaflight_cache_entry", Linker_Section => ".init_array.00000";

end Adaflight.STM32.Cache;
