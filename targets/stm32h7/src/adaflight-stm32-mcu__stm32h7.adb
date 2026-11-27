with System;
with System.Machine_Code;
with Adaflight.STM32.Memory;
with Adaflight.STM32.USB;
--  The STM32H743's reset flags in RCC_RSR and backup words in the RTC's
--  backup registers. A start with no reset flag came from the ROM
--  bootloader's jump, which keeps the words, and its bootloader request
--  leaves a mark there that restarts that start through a system reset.
--  The jump into system memory leaves the clocks as they are.
package body Adaflight.STM32.MCU is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   subtype Word is Interfaces.Unsigned_32;

   Unique : Identifier with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.UID_Address);

   --  The key in the high half with the system reset request.
   AIRCR : Word with Import, Volatile, Address => System'To_Address (16#E000_ED0C#);
   System_Reset_Request : constant Word := 16#05FA_0004#;

   RCC_RSR     : Word with Import, Volatile, Address => System'To_Address (16#5802_44D0#);
   RCC_APB4ENR : Word with Import, Volatile, Address => System'To_Address (16#5802_44F4#);
   PWR_CR1     : Word with Import, Volatile, Address => System'To_Address (16#5802_4800#);
   SYST_CSR    : Word with Import, Volatile, Address => System'To_Address (16#E000_E010#);
   VTOR        : Word with Import, Volatile, Address => System'To_Address (16#E000_ED08#);

   type Words is array (Natural range <>) of Word;
   Backup : Words (0 .. 19) with Import, Volatile, Address => System'To_Address (16#5800_4050#);
   ICER   : Words (0 .. 7) with Import, Volatile, Address => System'To_Address (16#E000_E180#);
   ICPR   : Words (0 .. 7) with Import, Volatile, Address => System'To_Address (16#E000_E280#);

   --  The bootloader's stack top and reset handler in system memory.
   Boot_Stack : Word with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.Bootloader_Address);
   Boot_Entry : Word
     with Import, Volatile, Address => System'To_Address (Adaflight.STM32.Memory.Bootloader_Address + 4);

   --  The persistent words: the magic word, the reset reason at three, then
   --  the two halves of a mass storage request's time, seven words in all.
   Object_Magic        : constant := 0;
   Object_Reset_Reason : constant := 3;
   Object_Time_High    : constant := 4;
   Object_Time_Low     : constant := 5;
   Object_Count        : constant := 7;
   Magic               : constant Word := 16#4265_6631#;
   Bootloader_ROM      : constant Word := 1;
   Mass_Storage        : constant Word := 3;

   Bootloader_Post : constant Word := 2;

   RTCAPBEN : constant Word := 2 ** 16;
   DBP      : constant Word := 2 ** 8;
   RMVF     : constant Word := 2 ** 16;
   SFTRSTF  : constant Word := 2 ** 24;
   --  Every reset's flag: CPU, D1, D2, brownout, pin, power-on, software,
   --  both watchdogs and low power. A start with none is no reset at all.
   Any_Reset : constant Word :=
     2 ** 17 or 2 ** 19 or 2 ** 20 or 2 ** 21 or 2 ** 22 or 2 ** 23 or 2 ** 24 or 2 ** 26 or 2 ** 28 or 2 ** 30;

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
      Flags          : constant Word := RCC_RSR;
      Software_Reset : constant Boolean := (Flags and SFTRSTF) /= 0;
      Not_Reset      : constant Boolean := (Flags and Any_Reset) = 0;
   begin
      Soft_Start := Software_Reset;
      RCC_APB4ENR := RCC_APB4ENR or RTCAPBEN;
      PWR_CR1 := PWR_CR1 or DBP;
      if not (Software_Reset or Not_Reset) or else Backup (Object_Magic) /= Magic then
         for I in Object_Magic + 1 .. Object_Count - 1 loop
            Backup (I) := 0;
         end loop;
         Backup (Object_Magic) := Magic;
      end if;
      RCC_RSR := RCC_RSR or RMVF;
   end Init_Persistent;

   procedure Reset_To_Bootloader is
   begin
      Backup (Object_Reset_Reason) := Bootloader_ROM;
      Reset;
   end Reset_To_Bootloader;

   procedure Reset_To_Mass_Storage (Time_Ms : Interfaces.Unsigned_64) is
   begin
      Backup (Object_Reset_Reason) := Mass_Storage;
      Backup (Object_Time_High) := Word (Interfaces.Shift_Right (Time_Ms, 32));
      Backup (Object_Time_Low) := Word (Time_Ms and 16#FFFF_FFFF#);
      Reset;
   end Reset_To_Mass_Storage;

   procedure Take_Mass_Storage_Request (Asked : out Boolean; Time_Ms : out Interfaces.Unsigned_64) is
   begin
      Asked := Backup (Object_Reset_Reason) = Mass_Storage;
      Time_Ms := 0;
      if Asked then
         Backup (Object_Reset_Reason) := 0;
         Time_Ms :=
           Interfaces.Shift_Left (Interfaces.Unsigned_64 (Backup (Object_Time_High)), 32)
           or Interfaces.Unsigned_64 (Backup (Object_Time_Low));
      end if;
      Backup (Object_Time_High) := 0;
      Backup (Object_Time_Low) := 0;
   end Take_Mass_Storage_Request;

   procedure Check_Bootloader_Exit is
   begin
      if Backup (Object_Reset_Reason) = Bootloader_Post then
         Backup (Object_Reset_Reason) := 0;
         Reset;
      end if;
   end Check_Bootloader_Exit;

   procedure Check_Bootloader_Request is
      Stack_Top   : Word;
      Entry_Point : Word;
   begin
      if Backup (Object_Reset_Reason) /= Bootloader_ROM then
         return;
      end if;
      Backup (Object_Reset_Reason) := Bootloader_Post;
      Adaflight.STM32.USB.Disconnect;
      System.Machine_Code.Asm ("cpsid i", Volatile => True);
      SYST_CSR := 0;
      for I in ICER'Range loop
         ICER (I) := Word'Last;
         ICPR (I) := Word'Last;
      end loop;
      VTOR := Adaflight.STM32.Memory.Bootloader_Address;
      Stack_Top := Boot_Stack;
      Entry_Point := Boot_Entry;
      System.Machine_Code.Asm
        ("msr msp, %0" & ASCII.LF & ASCII.HT & "msr basepri, %2" & ASCII.LF & ASCII.HT & "msr control, %2" & ASCII.LF &
         ASCII.HT & "isb" & ASCII.LF & ASCII.HT & "cpsie i" & ASCII.LF & ASCII.HT & "bx %1",
         Inputs   => (Word'Asm_Input ("r", Stack_Top), Word'Asm_Input ("r", Entry_Point), Word'Asm_Input ("r", 0)),
         Volatile => True);
   end Check_Bootloader_Request;

   function Simulated return Boolean is (False);

   function Simulator_Attitude_Direct return Boolean is (False);

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

   procedure Simulator_Mag (Field : out Mag_Field) is
   begin
      Field := (others => 0);
   end Simulator_Mag;
end Adaflight.STM32.MCU;
