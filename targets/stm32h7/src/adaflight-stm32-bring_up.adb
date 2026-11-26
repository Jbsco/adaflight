with Adaflight.Board;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.Bring_Up is
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
end Adaflight.STM32.Bring_Up;
