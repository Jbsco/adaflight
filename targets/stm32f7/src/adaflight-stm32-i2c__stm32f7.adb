--  The STM32F7's I2C as a master: the bus clock from the platform through
--  the timing register, the pins on the alternate function in open drain
--  with pull-ups, a register read as a write of the register with the
--  transfer kept open and a read of the bytes ended automatically, and a
--  register write as one two-byte transfer ended automatically. A missing
--  acknowledge or a wait past the timeout fails the transfer and restarts
--  the peripheral.
with System;
with Interfaces;
with Adaflight.I2C_Timing;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Platform;
with Adaflight.STM32.Time;
package body Adaflight.STM32.I2C is
   package GPIO renames Adaflight.STM32.GPIO;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_32;
   function Shift_Left (Value : Unsigned_32; Amount : Natural) return Unsigned_32 renames Interfaces.Shift_Left;

   type Registers is record
      CR1      : Unsigned_32;
      CR2      : Unsigned_32;
      OAR1     : Unsigned_32;
      OAR2     : Unsigned_32;
      TIMINGR  : Unsigned_32;
      TIMEOUTR : Unsigned_32;
      ISR      : Unsigned_32;
      ICR      : Unsigned_32;
      PECR     : Unsigned_32;
      RXDR     : Unsigned_32;
      TXDR     : Unsigned_32;
   end record with Volatile;
   for Registers use record
      CR1      at 16#00# range 0 .. 31;
      CR2      at 16#04# range 0 .. 31;
      OAR1     at 16#08# range 0 .. 31;
      OAR2     at 16#0C# range 0 .. 31;
      TIMINGR  at 16#10# range 0 .. 31;
      TIMEOUTR at 16#14# range 0 .. 31;
      ISR      at 16#18# range 0 .. 31;
      ICR      at 16#1C# range 0 .. 31;
      PECR     at 16#20# range 0 .. 31;
      RXDR     at 16#24# range 0 .. 31;
      TXDR     at 16#28# range 0 .. 31;
   end record;
   Base : constant array (Bus) of System.Address :=
     (I2C1 => System'To_Address (16#4000_5400#), I2C2 => System'To_Address (16#4000_5800#),
      I2C3 => System'To_Address (16#4000_5C00#), I2C4 => System'To_Address (16#4000_6000#));
   Clock_Bit : constant array (Bus) of Unsigned_32 := (I2C1 => 2 ** 21, I2C2 => 2 ** 22, I2C3 => 2 ** 23, I2C4 => 2 ** 24);
   RCC_APB1ENR  : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3840#);
   RCC_APB1RSTR : Unsigned_32 with Volatile, Import, Address => System'To_Address (16#4002_3820#);
   Alternate_Function : constant GPIO.Alternate_Function := 4;

   Enable       : constant Unsigned_32 := 2 ** 0;
   Read_Request : constant Unsigned_32 := 2 ** 10;
   Start        : constant Unsigned_32 := 2 ** 13;
   Stop         : constant Unsigned_32 := 2 ** 14;
   Auto_End     : constant Unsigned_32 := 2 ** 25;
   Transmit_Interrupt_Status : constant Unsigned_32 := 2 ** 1;
   Receive_Not_Empty         : constant Unsigned_32 := 2 ** 2;
   Not_Acknowledged          : constant Unsigned_32 := 2 ** 4;
   Stop_Detected             : constant Unsigned_32 := 2 ** 5;
   Transfer_Complete         : constant Unsigned_32 := 2 ** 6;
   Busy                      : constant Unsigned_32 := 2 ** 15;

   Running : array (Bus) of Boolean := (others => False);

   procedure Init (B : Bus; SCL, SDA : Adaflight.Pins.Pin) is
      Regs : Registers with Import, Address => Base (B);
   begin
      RCC_APB1ENR := RCC_APB1ENR or Clock_Bit (B);
      RCC_APB1RSTR := RCC_APB1RSTR or Clock_Bit (B);
      RCC_APB1RSTR := RCC_APB1RSTR and not Clock_Bit (B);
      GPIO.Enable_Port (SCL.Port);
      GPIO.Enable_Port (SDA.Port);
      GPIO.Set_Alternate (SCL, Alternate_Function, GPIO.Up);
      GPIO.Set_Open_Drain (SCL);
      GPIO.Set_Alternate (SDA, Alternate_Function, GPIO.Up);
      GPIO.Set_Open_Drain (SDA);
      Regs.CR1 := 0;
      Regs.TIMINGR := Adaflight.I2C_Timing.Timing (Adaflight.STM32.Platform.APB1_Hz, Speed_KHz, 0);
      Regs.CR1 := Enable;
      Running (B) := True;
   end Init;

   function Started (B : Bus) return Boolean is (Running (B));

   --  The transfer's control word for a device: its address, the byte count
   --  and the direction, with the end automatic when asked.
   function Control (Address : Byte; Count : Natural; Reading : Boolean; Auto : Boolean) return Unsigned_32 is
     (Shift_Left (Unsigned_32 (Address), 1) or Shift_Left (Unsigned_32 (Count), 16)
      or (if Reading then Read_Request else 0) or (if Auto then Auto_End else 0) or Start);

   --  Wait for any of the flags, failing at a missing acknowledge or the
   --  timeout; the failure restarts the peripheral, which clears its state.
   procedure Wait (B : Bus; Flags : Unsigned_32; OK : out Boolean) is
      Regs  : Registers with Import, Address => Base (B);
      Since : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
   begin
      loop
         if (Regs.ISR and Not_Acknowledged) /= 0 then
            Regs.ICR := Not_Acknowledged or Stop_Detected;
            OK := False;
            return;
         end if;
         if (Regs.ISR and Flags) /= 0 then
            OK := True;
            return;
         end if;
         if Adaflight.STM32.Time.Micros - Since > Timeout_Us then
            Regs.CR1 := 0;
            Regs.CR1 := Enable;
            OK := False;
            return;
         end if;
      end loop;
   end Wait;

   procedure Read (B : Bus; Address : Byte; Register : Byte; Data : out Byte_Array; OK : out Boolean) is
      Regs : Registers with Import, Address => Base (B);
   begin
      Data := (others => 0);
      OK := False;
      if not Running (B) then
         return;
      end if;
      Regs.CR2 := Control (Address, 1, Reading => False, Auto => False);
      Wait (B, Transmit_Interrupt_Status, OK);
      if not OK then
         return;
      end if;
      Regs.TXDR := Unsigned_32 (Register);
      Wait (B, Transfer_Complete, OK);
      if not OK then
         return;
      end if;
      Regs.CR2 := Control (Address, Data'Length, Reading => True, Auto => True);
      for I in Data'Range loop
         Wait (B, Receive_Not_Empty, OK);
         if not OK then
            return;
         end if;
         Data (I) := Byte (Regs.RXDR and 16#FF#);
      end loop;
      Wait (B, Stop_Detected, OK);
      Regs.ICR := Stop_Detected;
   end Read;

   procedure Write (B : Bus; Address : Byte; Register : Byte; Value : Byte; OK : out Boolean) is
      Regs : Registers with Import, Address => Base (B);
   begin
      OK := False;
      if not Running (B) then
         return;
      end if;
      Regs.CR2 := Control (Address, 2, Reading => False, Auto => True);
      Wait (B, Transmit_Interrupt_Status, OK);
      if not OK then
         return;
      end if;
      Regs.TXDR := Unsigned_32 (Register);
      Wait (B, Transmit_Interrupt_Status, OK);
      if not OK then
         return;
      end if;
      Regs.TXDR := Unsigned_32 (Value);
      Wait (B, Stop_Detected, OK);
      Regs.ICR := Stop_Detected;
   end Write;
end Adaflight.STM32.I2C;
