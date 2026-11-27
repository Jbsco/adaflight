with Interfaces;
with System.Machine_Code;
with Adaflight.STM32.Cache;
--  The STM32H7's flash: bank 1's registers, the sector erased with 32-bit
--  parallelism, and the region programmed in flash words of 32 bytes, each
--  written as eight words in a row and queued until the bank has written it.
package body Adaflight.STM32.Flash is
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;

   KEYR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5200_2004#);
   CR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5200_200C#);
   SR   : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5200_2010#);
   CCR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#5200_2014#);

   Key_1 : constant Unsigned_32 := 16#4567_0123#;
   Key_2 : constant Unsigned_32 := 16#CDEF_89AB#;

   Lock           : constant Unsigned_32 := 2 ** 0;
   Program        : constant Unsigned_32 := 2 ** 1;
   Sector_Erase   : constant Unsigned_32 := 2 ** 2;
   Parallelism_32 : constant Unsigned_32 := 2#10# * 2 ** 4;
   Parallelism    : constant Unsigned_32 := 2#11# * 2 ** 4;
   Start          : constant Unsigned_32 := 2 ** 7;
   Sector_Shift   : constant := 8;
   Sector_Mask    : constant Unsigned_32 := 7 * 2 ** Sector_Shift;
   --  Busy, write buffer not empty and queue wait.
   Busy   : constant Unsigned_32 := 2#111#;
   --  Write protection, programming sequence, strobe, inconsistency and operation errors.
   Errors : constant Unsigned_32 := 2 ** 17 or 2 ** 18 or 2 ** 19 or 2 ** 21 or 2 ** 22;
   --  Every flag the clear register clears, end of operation to CRC end.
   Clear_All : constant Unsigned_32 := 16#0FEF_0000#;

   Flash_Word : constant := 8;
   subtype Word_Index is Natural range 0 .. Config_Size / 4 - 1;
   Words : array (Word_Index) of Unsigned_32
     with Import, Volatile, Address => System'To_Address (Config_Address);

   procedure Barrier is
   begin
      System.Machine_Code.Asm ("dsb" & ASCII.LF & ASCII.HT & "isb", Volatile => True);
   end Barrier;

   procedure Wait is
   begin
      while (SR and Busy) /= 0 loop
         null;
      end loop;
   end Wait;

   function Error return Boolean is ((SR and Errors) /= 0);

   procedure Write (Data : Byte_Array; OK : out Boolean) is
      Count : constant Natural := (Data'Length + 4 * Flash_Word - 1) / (4 * Flash_Word);
      Row   : array (0 .. Flash_Word - 1) of Unsigned_32;
      Byte_At : Natural;
   begin
      Wait;
      if (CR and Lock) /= 0 then
         KEYR := Key_1;
         KEYR := Key_2;
      end if;
      CCR := Clear_All;
      CR := (CR and not (Parallelism or Sector_Mask)) or Parallelism_32 or Sector_Erase
        or Shift_Left (Config_Sector, Sector_Shift);
      CR := CR or Start;
      Wait;
      CR := CR and not (Sector_Erase or Sector_Mask);
      Adaflight.STM32.Cache.Invalidate_Data (Config'Address, Config'Length);
      if not Error then
         CR := CR or Program;
         for F in 0 .. Count - 1 loop
            for W in Row'Range loop
               Row (W) := 0;
               for K in reverse 0 .. 3 loop
                  Byte_At := 4 * (Flash_Word * F + W) + K;
                  Row (W) := Shift_Left (Row (W), 8)
                    or (if Byte_At < Data'Length then Unsigned_32 (Data (Data'First + Byte_At)) else 16#FF#);
               end loop;
            end loop;
            Barrier;
            for W in Row'Range loop
               Words (Flash_Word * F + W) := Row (W);
            end loop;
            Barrier;
            Wait;
            exit when Error;
         end loop;
         CR := CR and not Program;
      end if;
      OK := not Error;
      CCR := Clear_All;
      CR := CR or Lock;
      Adaflight.STM32.Cache.Invalidate_Data (Config'Address, Config'Length);
   end Write;
end Adaflight.STM32.Flash;
