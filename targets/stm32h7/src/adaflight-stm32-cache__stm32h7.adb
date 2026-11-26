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
   DCCMVAC : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EF68#);
   MPU_CTRL : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED94#);
   MPU_RNR  : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED98#);
   MPU_RBAR : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_ED9C#);
   MPU_RASR : Interfaces.Unsigned_32 with Volatile, Import, Address => System'To_Address (16#E000_EDA0#);
   D2_RAM   : constant Interfaces.Unsigned_32 := 16#3000_0000#;
   --  No execution, full access, TEX 1 with C and B clear (normal memory, not cacheable), shareable, 256 KB,
   --  enabled.
   D2_Attributes : constant Interfaces.Unsigned_32 :=
     2 ** 28 or 2#011# * 2 ** 24 or 2#001# * 2 ** 19 or 2 ** 18 or 17 * 2 or 1;
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
      --  The D2 RAM keeps the DMA buffers, so the data cache must not hold its lines.
      Barrier;
      MPU_RNR := 0;
      MPU_RBAR := D2_RAM;
      MPU_RASR := D2_Attributes;
      MPU_CTRL := 2 ** 2 or 1;
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

   procedure Sync_Code (Address : System.Address; Length : Natural) is
      use System.Storage_Elements;
      Start : constant Integer_Address := To_Integer (Address);
      Next  : Integer_Address := Start - Start mod Line;
   begin
      Barrier;
      while Next < Start + Integer_Address (Length) loop
         DCCMVAC := Interfaces.Unsigned_32 (Next);
         Next := Next + Line;
      end loop;
      Barrier;
      ICIALLU := 0;
      Barrier;
   end Sync_Code;

   type Start_Hook is access procedure with Convention => C;
   Entry_Hook : constant Start_Hook := Enable'Access
     with Export, External_Name => "adaflight_cache_entry", Linker_Section => ".init_array.00000";

end Adaflight.STM32.Cache;
