with Adaflight.DShot;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Motor_In with SPARK_Mode is

   procedure Process
     (Request : Byte_Array; Motors : Motor_Count; Device : Device_Kind; Three_D : Boolean; R : out Result;
      E : out Effects)
   is
   begin
      E := No_Effects;
      if Request'Length < 2 * Motors then
         R := Error;
         return;
      end if;
      for I in 0 .. Motors - 1 loop
         declare
            Value : constant Interfaces.Unsigned_16 := Interfaces.Unsigned_16 (U16 (Request, 2 * I));
         begin
            E.Values (I) :=
              (case Device is
                  when No_Device => 0.0,
                  when PWM       => Float (Value),
                  when DShot     => Float (Adaflight.DShot.From_External (Value, Three_D)));
         end;
      end loop;
      E.Set := True;
      R := Ack;
   end Process;

end Adaflight.MSP_Motor_In;
