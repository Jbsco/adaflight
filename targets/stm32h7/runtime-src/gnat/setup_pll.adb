--  The STM32H7's clocks at start-up: the LDO supply, the voltage scale its
--  system clock needs, the crystal, PLL1 from it with the core on its P
--  output, the flash wait states for the bus clock, and the buses at half
--  the core's bus clock. A PLL1 that already drives the system clock, as a
--  boot loader leaves it, stays as it is.

pragma Suppress (All_Checks);

with Interfaces;                 use Interfaces;
with System.BB.Board_Parameters; use System.BB.Board_Parameters;

procedure Setup_Pll is

   RCC   : constant := 16#5802_4400#;
   PWR   : constant := 16#5802_4800#;
   FLASH : constant := 16#5200_2000#;

   RCC_CR        : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#00#);
   RCC_CFGR      : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#10#);
   RCC_D1CFGR    : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#18#);
   RCC_D2CFGR    : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#1C#);
   RCC_D3CFGR    : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#20#);
   RCC_PLLCKSELR : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#28#);
   RCC_PLLCFGR   : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#2C#);
   RCC_PLL1DIVR  : Unsigned_32
     with Volatile, Import, Address => System'To_Address (RCC + 16#30#);
   PWR_CSR1      : Unsigned_32
     with Volatile, Import, Address => System'To_Address (PWR + 16#04#);
   PWR_CR3       : Unsigned_32
     with Volatile, Import, Address => System'To_Address (PWR + 16#0C#);
   PWR_D3CR      : Unsigned_32
     with Volatile, Import, Address => System'To_Address (PWR + 16#18#);
   FLASH_ACR     : Unsigned_32
     with Volatile, Import, Address => System'To_Address (FLASH);

   HSEON     : constant Unsigned_32 := 2 ** 16;
   HSERDY    : constant Unsigned_32 := 2 ** 17;
   PLL1ON    : constant Unsigned_32 := 2 ** 24;
   PLL1RDY   : constant Unsigned_32 := 2 ** 25;
   ACTVOSRDY : constant Unsigned_32 := 2 ** 13;
   VOSRDY    : constant Unsigned_32 := 2 ** 13;
   VOS_Mask  : constant Unsigned_32 := 2#11# * 2 ** 14;
   VOS       : constant Unsigned_32 :=
     (if Voltage_Scale = 0 then 0 else 2#11# * 2 ** 14);
   Half_AHB  : constant Unsigned_32 := 2#1000#;
   Half_APB  : constant Unsigned_32 := 2#100#;
   Latency   : constant Unsigned_32 := Unsigned_32 (FLASH_Latency);

begin
   --  The LDO supplies the core. The supply configuration locks after
   --  this write.
   PWR_CR3 := (PWR_CR3 and not 2#111#) or 2#010#;
   loop
      exit when (PWR_CSR1 and ACTVOSRDY) /= 0;
   end loop;

   PWR_D3CR := (PWR_D3CR and not VOS_Mask) or VOS;
   loop
      exit when (PWR_D3CR and VOSRDY) /= 0;
   end loop;

   if (RCC_CFGR and 2#111_000#) /= 2#011_000# then
      RCC_CR := RCC_CR or HSEON;
      loop
         exit when (RCC_CR and HSERDY) /= 0;
      end loop;

      RCC_CR := RCC_CR and not PLL1ON;
      loop
         exit when (RCC_CR and PLL1RDY) = 0;
      end loop;
      RCC_PLLCKSELR := (RCC_PLLCKSELR and not 2#11_1111_0011#)
        or 2#10# or Unsigned_32 (PLL1_M) * 2 ** 4;
      RCC_PLLCFGR := (RCC_PLLCFGR and not (2#1111# or 2#111# * 2 ** 16))
        or Unsigned_32 (PLL1_Range) * 2 ** 2 or 2#111# * 2 ** 16;
      RCC_PLL1DIVR := Unsigned_32 (PLL1_N - 1)
        or Unsigned_32 (PLLP_Value - 1) * 2 ** 9
        or Unsigned_32 (PLLQ_Value - 1) * 2 ** 16
        or Unsigned_32 (PLL1_R - 1) * 2 ** 24;
      RCC_CR := RCC_CR or PLL1ON;
      loop
         exit when (RCC_CR and PLL1RDY) /= 0;
      end loop;
   end if;

   --  Wait states and write delay for the bus clock, before it rises.
   FLASH_ACR := (FLASH_ACR and not 2#11_1111#) or Latency
     or Unsigned_32 (Flash_Write_Delay) * 2 ** 4;
   loop
      exit when (FLASH_ACR and 2#1111#) = Latency;
   end loop;

   RCC_D1CFGR := Half_AHB or Half_APB * 2 ** 4;
   RCC_D2CFGR := Half_APB * 2 ** 4 or Half_APB * 2 ** 8;
   RCC_D3CFGR := Half_APB * 2 ** 4;

   RCC_CFGR := (RCC_CFGR and not 2#111#) or 2#011#;
   loop
      exit when (RCC_CFGR and 2#111_000#) = 2#011_000#;
   end loop;
end Setup_Pll;
