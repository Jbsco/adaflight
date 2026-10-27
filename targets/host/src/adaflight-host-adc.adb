package body Adaflight.STM32.ADC is
   procedure Init is null;

   function Has_Channel (P : Pin) return Boolean is
     (case P.Port is
         when Port_A => P.Number <= 7,
         when Port_B => P.Number <= 1,
         when Port_C => P.Number <= 5,
         when others => False);

   procedure Enable (P : Pin) is null;

   --  No analog input is connected on the host.
   function Read (P : Pin) return Sample is (0);
end Adaflight.STM32.ADC;
