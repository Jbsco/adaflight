with Interfaces;
with System.Machine_Code;
with System.Storage_Elements;

package body Adaflight.STM32.Cache is
   use type Interfaces.Unsigned_32;
   use type System.Storage_Elements.Integer_Address;

   CCR     : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED14#);
   CCSIDR  : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED80#);
   CSSELR  : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED84#);
   ICIALLU : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF50#);
   DCIMVAC : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF5C#);
   DCISW   : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF60#);
   DC      : constant Interfaces.Unsigned_32 := 2 ** 16;
   IC      : constant Interfaces.Unsigned_32 := 2 ** 17;
   Line    : constant := 32;

   procedure Barrier is
   begin
      System.Machine_Code.Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
   end Barrier;

   procedure Enable is
      Sets, Ways : Interfaces.Unsigned_32;
   begin
      Barrier;
      ICIALLU := 0;
      CSSELR := 0;
      Barrier;
      Sets := Interfaces.Shift_Right (CCSIDR, 13) and 16#7FFF#;
      loop
         Ways := Interfaces.Shift_Right (CCSIDR, 3) and 16#3FF#;
         loop
            DCISW := Interfaces.Shift_Left (Sets, 5) or Interfaces.Shift_Left (Ways, 30);
            exit when Ways = 0;
            Ways := Ways - 1;
         end loop;
         exit when Sets = 0;
         Sets := Sets - 1;
      end loop;
      Barrier;
      CCR := CCR or IC or DC;
      Barrier;
   end Enable;

   procedure Invalidate_Data (Address : System.Address; Length : Natural) is
      use System.Storage_Elements;
      Start : constant Integer_Address := To_Integer (Address);
      Next  : Integer_Address := Start - Start mod Line;
   begin
      Barrier;
      while Next < Start + Integer_Address (Length) loop
         DCIMVAC := Interfaces.Unsigned_32 (Next);
         Next := Next + Line;
      end loop;
      Barrier;
   end Invalidate_Data;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Enable'Access
     with Export, External_Name => "adaflight_cache_entry", Linker_Section => ".init_array.00000";

end Adaflight.STM32.Cache;
