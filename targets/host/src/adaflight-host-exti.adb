package body Adaflight.STM32.EXTI is
   procedure Enable_Rising (P : Pin) is null;
   procedure Configure_Falling (P : Pin) is null;
   procedure Unmask (P : Pin) is null;
   procedure Mask (P : Pin) is null;
   procedure Take_Pending (Mask : Adaflight.EXTI_Lines.Line_Mask; Active : out Adaflight.EXTI_Lines.Line_Mask) is
   begin
      Active := 0;
   end Take_Pending;
end Adaflight.STM32.EXTI;
