with System;
with System.Machine_Code;
with Adaflight.STM32.Memory;
package body Adaflight.STM32.MCU is
   use type Interfaces.Unsigned_32;
   subtype Word is Interfaces.Unsigned_32;

   Unique : Identifier with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.UID_Address);

   --  The key in the high half with the system reset request.
   AIRCR : Word with Import, Volatile, Address => System'To_Address (16#E000_ED0C#);
   System_Reset_Request : constant Word := 16#05FA_0004#;

   RCC_CR      : Word with Import, Volatile, Address => System'To_Address (16#4002_3800#);
   RCC_PLLCFGR : Word with Import, Volatile, Address => System'To_Address (16#4002_3804#);
   RCC_CFGR    : Word with Import, Volatile, Address => System'To_Address (16#4002_3808#);
   RCC_CIR     : Word with Import, Volatile, Address => System'To_Address (16#4002_380C#);
   RCC_APB1ENR : Word with Import, Volatile, Address => System'To_Address (16#4002_3840#);
   RCC_APB2ENR : Word with Import, Volatile, Address => System'To_Address (16#4002_3844#);
   RCC_CSR     : Word with Import, Volatile, Address => System'To_Address (16#4002_3874#);
   PWR_CR      : Word with Import, Volatile, Address => System'To_Address (16#4000_7000#);
   MEMRMP      : Word with Import, Volatile, Address => System'To_Address (16#4001_3800#);
   SYST_CSR    : Word with Import, Volatile, Address => System'To_Address (16#E000_E010#);
   VTOR        : Word with Import, Volatile, Address => System'To_Address (16#E000_ED08#);

   type Words is array (Natural range <>) of Word;
   Backup : Words (0 .. 19) with Import, Volatile, Address => System'To_Address (16#4000_2850#);
   ICER   : Words (0 .. 7) with Import, Volatile, Address => System'To_Address (16#E000_E180#);
   ICPR   : Words (0 .. 7) with Import, Volatile, Address => System'To_Address (16#E000_E280#);

   --  The bootloader's stack top and reset handler in system memory.
   Boot_Stack : Word with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.Bootloader_Address);
   Boot_Entry : Word with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.Bootloader_Address + 4);

   --  The persistent words: the magic word, then the reset reason at three,
   --  seven words in all.
   Object_Magic        : constant := 0;
   Object_Reset_Reason : constant := 3;
   Object_Count        : constant := 7;
   Magic               : constant Word := 16#4265_6631#;
   Bootloader_ROM      : constant Word := 1;

   PWREN         : constant Word := 2 ** 28;
   DBP           : constant Word := 2 ** 8;
   SFTRSTF       : constant Word := 2 ** 28;
   RMVF          : constant Word := 2 ** 24;
   HSION         : constant Word := 2 ** 0;
   HSIRDY        : constant Word := 2 ** 1;
   HSEON         : constant Word := 2 ** 16;
   CSSON         : constant Word := 2 ** 19;
   PLLON         : constant Word := 2 ** 24;
   PLLRDY        : constant Word := 2 ** 25;
   SWS           : constant Word := 16#C#;
   SYSCFGEN      : constant Word := 2 ** 14;
   PLLCFGR_Reset : constant Word := 16#2400_3010#;

   function UID return Identifier is (Unique);

   procedure Reset is
   begin
      System.Machine_Code.Asm ("dsb", Volatile => True);
      AIRCR := System_Reset_Request;
      System.Machine_Code.Asm ("dsb", Volatile => True);
      loop
         null;
      end loop;
   end Reset;

   Soft_Start : Boolean := False;

   function Software_Reset return Boolean is (Soft_Start);

   procedure Init_Persistent is
      Software_Reset : constant Boolean := (RCC_CSR and SFTRSTF) /= 0;
   begin
      Soft_Start := Software_Reset;
      RCC_APB1ENR := RCC_APB1ENR or PWREN;
      PWR_CR := PWR_CR or DBP;
      if not Software_Reset or else Backup (Object_Magic) /= Magic then
         for I in Object_Magic + 1 .. Object_Count - 1 loop
            Backup (I) := 0;
         end loop;
         Backup (Object_Magic) := Magic;
      end if;
      RCC_CSR := RCC_CSR or RMVF;
   end Init_Persistent;

   procedure Reset_To_Bootloader is
   begin
      Backup (Object_Reset_Reason) := Bootloader_ROM;
      Reset;
   end Reset_To_Bootloader;

   procedure Check_Bootloader_Request is
      Stack_Top   : Word;
      Entry_Point : Word;
   begin
      if Backup (Object_Reset_Reason) /= Bootloader_ROM then
         return;
      end if;
      Backup (Object_Reset_Reason) := 0;
      System.Machine_Code.Asm ("cpsid i", Volatile => True);
      SYST_CSR := 0;
      for I in ICER'Range loop
         ICER (I) := Word'Last;
         ICPR (I) := Word'Last;
      end loop;
      RCC_CR := RCC_CR or HSION;
      loop
         exit when (RCC_CR and HSIRDY) /= 0;
      end loop;
      RCC_CFGR := 0;
      loop
         exit when (RCC_CFGR and SWS) = 0;
      end loop;
      RCC_CR := RCC_CR and not (PLLON or HSEON or CSSON);
      loop
         exit when (RCC_CR and PLLRDY) = 0;
      end loop;
      RCC_PLLCFGR := PLLCFGR_Reset;
      RCC_CIR := 0;
      RCC_APB2ENR := RCC_APB2ENR or SYSCFGEN;
      MEMRMP := 1;
      VTOR := 0;
      Stack_Top := Boot_Stack;
      Entry_Point := Boot_Entry;
      System.Machine_Code.Asm
        ("msr msp, %0" & ASCII.LF & ASCII.HT & "cpsie i" & ASCII.LF & ASCII.HT & "bx %1",
         Inputs   => (Word'Asm_Input ("r", Stack_Top), Word'Asm_Input ("r", Entry_Point)),
         Volatile => True);
   end Check_Bootloader_Request;

   function Simulated return Boolean is (False);

   procedure Simulator_Poll is null;

   procedure Simulator_Attitude
     (Fresh : out Boolean; Q : out Adaflight.Attitude.Quaternion; Legacy_Bridge : out Boolean) is
   begin
      Fresh := False;
      Q := (others => <>);
      Legacy_Bridge := False;
   end Simulator_Attitude;

   procedure Simulator_GPS (Fresh : out Boolean; Fix : out Simulator_Fix) is
   begin
      Fresh := False;
      Fix := (others => <>);
   end Simulator_GPS;

   procedure Simulator_Pressure (Pascals : out Interfaces.Integer_32) is
   begin
      Pascals := 101_325;
   end Simulator_Pressure;

   function UDP_Receiver_Available return Boolean is (False);

   procedure Simulator_RC (Fresh : out Boolean; Pulses : out RC_Pulses) is
   begin
      Fresh := False;
      Pulses := (others => 0);
   end Simulator_RC;
end Adaflight.STM32.MCU;
