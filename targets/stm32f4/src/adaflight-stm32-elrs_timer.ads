--  The ExpressLRS receiver's timer: TIM5 counting up at 1 MHz, its update
--  interrupt calling the handler set, and the time base, period, counter and
--  run state the receiver programs.
with Interfaces;
package Adaflight.STM32.ELRS_Timer is
   type Handler is access procedure;

   --  The timer the board names, set up stopped with its interrupt off;
   --  false for a timer this build does not drive.
   procedure Init (Number : Natural; H : Handler; Ok : out Boolean);
   --  A count at 1 MHz up to the longest period the receiver expects.
   procedure Set_Time_Base (Max_Period : Natural)
     with Pre => Max_Period > 0;
   procedure Set_Period (Period : Interfaces.Unsigned_32);
   procedure Reset_Counter;
   procedure Set_Running (Running : Boolean);
   --  The update interrupt on, once the receiver is ready for it.
   procedure Enable_Interrupt;
end Adaflight.STM32.ELRS_Timer;
