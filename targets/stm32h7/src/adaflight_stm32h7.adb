--  The STM32H7 image so far: the board's first LED blinks at 1 Hz on the
--  run-time library's clock, which shows its start-up, clock setup and
--  timing working on a board or an emulator.
with Ada.Real_Time;           use Ada.Real_Time;
with Interfaces;              use Interfaces;
with System.Storage_Elements; use System.Storage_Elements;
with Adaflight.Board;
with Adaflight.Pins;          use Adaflight.Pins;

procedure Adaflight_Stm32h7 is
   LED  : constant Pin := Adaflight.Board.LED0_Pin;
   Port : constant Natural := Port_Name'Pos (LED.Port);
   Bit  : constant Unsigned_32 := 2 ** Natural (LED.Number);
   GPIO : constant Integer_Address := 16#5802_0000# + 16#400# * Integer_Address (Port);

   RCC_AHB4ENR : Unsigned_32 with Volatile, Import, Address => To_Address (16#5802_44E0#);
   MODER       : Unsigned_32 with Volatile, Import, Address => To_Address (GPIO);
   BSRR        : Unsigned_32 with Volatile, Import, Address => To_Address (GPIO + 16#18#);

   Next : Time := Clock;
begin
   RCC_AHB4ENR := RCC_AHB4ENR or 2 ** Port;
   MODER := (MODER and not (2#11# * Bit * Bit)) or Bit * Bit;
   loop
      BSRR := Bit;
      Next := Next + Milliseconds (500);
      delay until Next;
      BSRR := Bit * 2 ** 16;
      Next := Next + Milliseconds (500);
      delay until Next;
   end loop;
end Adaflight_Stm32h7;
