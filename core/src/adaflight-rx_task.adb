package body Adaflight.RX_Task with SPARK_Mode is

   Margin_Us : constant := 1;

   --  An estimate in microseconds, its 64ths dropped toward minus infinity.
   function Whole_Us (E : Estimate) return Integer_32 is (if E >= 0 then E / 64 else -1);

   procedure Finish
     (T                : in out State;
      Rx_Ready         : Boolean;
      Ignore_Exec_Time : Boolean;
      Anticipated_Us   : Execution_Us;
      Elapsed_Us       : Unsigned_32;
      Next_State_Us    : out Integer_32)
   is
      Old : constant Step := T.Current;
   begin
      case T.Current is
         when Check =>
            if Rx_Ready then
               T.Current := Modes;
            end if;
         when Modes =>
            T.Current := Update;
         when Update =>
            T.Current := Check;
      end case;
      if not Ignore_Exec_Time then
         declare
            Execute : constant Execution_Us :=
              (if Elapsed_Us < Max_Execution_Us then Integer_32 (Elapsed_Us) + Margin_Us else Max_Execution_Us);
         begin
            if Anticipated_Us /= Whole_Us (T.Duration (Old)) then
               T.Duration (Old) := Anticipated_Us * 64;
            end if;
            if Execute > Whole_Us (T.Duration (Old)) then
               T.Duration (Old) := Execute * 64;
            else
               T.Duration (Old) := T.Duration (Old) - 1;
            end if;
         end;
      end if;
      Next_State_Us := Whole_Us (T.Duration (T.Current));
   end Finish;

end Adaflight.RX_Task;
