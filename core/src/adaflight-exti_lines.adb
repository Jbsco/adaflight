package body Adaflight.EXTI_Lines with SPARK_Mode is

   procedure Take_Highest (Pending : in out Line_Mask; Taken : out Line) is
   begin
      Taken := 0;
      for L in reverse Line loop
         if (Pending and Bit (L)) /= 0 then
            Taken := L;
            exit;
         end if;
         pragma Loop_Invariant ((Pending and not (Bit (L) - 1)) = 0);
      end loop;
      Pending := Pending and not Bit (Taken);
   end Take_Highest;

end Adaflight.EXTI_Lines;
