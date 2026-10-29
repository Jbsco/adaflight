--  The microcontroller itself: its unique identifier, the system reset, and
--  the reset into the ROM bootloader through a request kept in the RTC
--  backup registers, which a system reset leaves alone.
with Interfaces;
package Adaflight.STM32.MCU is
   type Identifier is array (1 .. 3) of Interfaces.Unsigned_32;
   --  The device's unique identifier, the three words the status prints.
   function UID return Identifier;
   --  The core's reset through its application interrupt and reset control
   --  register.
   procedure Reset
     with No_Return;
   --  The persistent words in the backup registers: kept over a software
   --  reset with their magic word, cleared after any other reset.
   procedure Init_Persistent;
   --  Whether this start follows a software reset, read at the persistent
   --  words' start.
   function Software_Reset return Boolean;
   --  A reset that the next start turns into the ROM bootloader.
   procedure Reset_To_Bootloader
     with No_Return;
   --  At the start, before the board's devices: a pending bootloader request
   --  cleared, and the jump into the system memory's bootloader with the
   --  clocks and interrupts back as a reset leaves them.
   procedure Check_Bootloader_Request;
end Adaflight.STM32.MCU;
