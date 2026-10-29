with Interfaces.STM32.FLASH;
--  The STM32F7's flash: the F4's sequence with the ART accelerator's cache
--  reset after programming in place of the data cache's.
package body Adaflight.STM32.Flash is
   use type Interfaces.STM32.Bit;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;
   Regs : Interfaces.STM32.FLASH.FLASH_Peripheral renames Interfaces.STM32.FLASH.FLASH_Periph;

   --  The access control register as a word, for the ART accelerator's
   --  enable and reset bits, which the F4 binding names otherwise.
   ACR : Unsigned_32 with Import, Volatile, Address => System'To_Address (16#4002_3C00#);
   ART_Enable : constant Unsigned_32 := 2 ** 9;
   ART_Reset  : constant Unsigned_32 := 2 ** 11;
   Key_1 : constant Interfaces.STM32.UInt32 := 16#4567_0123#;
   Key_2 : constant Interfaces.STM32.UInt32 := 16#CDEF_89AB#;
   --  Programming by 32-bit words, which the 3.3 V supply allows.
   Word_Size : constant Interfaces.STM32.UInt2 := 2;

   subtype Word_Index is Natural range 0 .. Config_Size / 4 - 1;
   Words : array (Word_Index) of Unsigned_32
     with Import, Volatile, Address => System'To_Address (Config_Address);

   procedure Wait is
   begin
      while Regs.SR.BSY = 1 loop
         null;
      end loop;
   end Wait;

   function Error return Boolean is
     (Regs.SR.OPERR = 1 or else Regs.SR.WRPERR = 1 or else Regs.SR.PGAERR = 1 or else Regs.SR.PGPERR = 1
      or else Regs.SR.PGSERR = 1);

   procedure Clear_Errors is
   begin
      Regs.SR := (EOP => 1, OPERR => 1, WRPERR => 1, PGAERR => 1, PGPERR => 1, PGSERR => 1, others => <>);
   end Clear_Errors;

   procedure Write (Data : Byte_Array; OK : out Boolean) is
      Count : constant Natural := (Data'Length + 3) / 4;
      Word  : Unsigned_32;
   begin
      Wait;
      if Regs.CR.LOCK = 1 then
         Regs.KEYR := Key_1;
         Regs.KEYR := Key_2;
      end if;
      Clear_Errors;
      Regs.CR.PSIZE := Word_Size;
      Regs.CR.SNB := Config_Sector;
      Regs.CR.SER := 1;
      Regs.CR.STRT := 1;
      Wait;
      Regs.CR.SER := 0;
      Regs.CR.PG := 1;
      for I in 0 .. Count - 1 loop
         Word := 0;
         for K in reverse 0 .. 3 loop
            Word := Shift_Left (Word, 8);
            if 4 * I + K < Data'Length then
               Word := Word or Unsigned_32 (Data (Data'First + 4 * I + K));
            else
               Word := Word or 16#FF#;
            end if;
         end loop;
         Words (I) := Word;
         Wait;
         exit when Error;
      end loop;
      Regs.CR.PG := 0;
      OK := not Error;
      Clear_Errors;
      Regs.CR.LOCK := 1;
      --  The data cache is reset after programming so the region reads back
      --  what was written.
      ACR := ACR and not ART_Enable;
      ACR := ACR or ART_Reset;
      ACR := ACR and not ART_Reset;
      ACR := ACR or ART_Enable;
   end Write;
end Adaflight.STM32.Flash;
