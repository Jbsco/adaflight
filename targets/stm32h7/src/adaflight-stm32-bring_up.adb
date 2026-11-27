with Interfaces; use Interfaces;
with Adaflight.Board;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timer_Dispatch;
package body Adaflight.STM32.Bring_Up is
   use Adaflight.STM32.Timers;

   Count : Natural := 0 with Atomic;

   procedure Rise is
   begin
      Count := (if Count = Natural'Last then 0 else Count + 1);
   end Rise;

   procedure Watch_Gyro_Interrupt is
      P : constant Pin := Adaflight.Board.Gyro_1_EXTI_Pin;
   begin
      GPIO.Enable_Port (P.Port);
      GPIO.Set_Input (P);
      EXTI_Dispatch.Register (P.Number, Rise'Access);
      EXTI.Enable_Rising (P);
   end Watch_Gyro_Interrupt;

   function Edges return Natural is (Count);

   UIF : constant Unsigned_32 := 2 ** 0;
   UIE : constant Unsigned_32 := 2 ** 0;

   Ticks : array (Timer_Name) of Natural := (others => 0) with Atomic_Components;

   procedure Tick (T : Timer_Name) is
      Regs : Timer_Registers with Import, Address => Timer_Base (T);
   begin
      if (Regs.SR and UIF) /= 0 then
         Regs.SR := not UIF;
         if T in Counted_Timer then
            Ticks (T) := (if Ticks (T) = Natural'Last then 0 else Ticks (T) + 1);
         end if;
      end if;
   end Tick;

   procedure Start_Timers is
   begin
      for T in Counted_Timer loop
         declare
            Regs : Timer_Registers with Import, Address => Timer_Base (T);
         begin
            Enable_Clock (T);
            Reset (T);
            Set_Time_Base (T, Reload => 999, Prescale => Timer_Clock_Hz (T) / 1_000_000 - 1);
            Regs.SR := 0;
            Timer_Dispatch.Register (T, Tick'Access);
            Regs.DIER := UIE;
            Regs.CR1 := Regs.CR1 or CEN;
         end;
      end loop;
   end Start_Timers;

   function Updates (T : Counted_Timer) return Natural is (Ticks (T));
end Adaflight.STM32.Bring_Up;
