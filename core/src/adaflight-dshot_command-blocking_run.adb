package body Adaflight.DShot_Command.Blocking_Run with SPARK_Mode is

   procedure Run (Q : in out Queue; T : in out Motor_Table; Plan : Blocking_Plan) is
   begin
      if not Plan.Run then
         return;
      end if;
      Delay_Us (T, Initial_Delay_Us - Command_Delay_Us);
      for Count in 1 .. Plan.Repeats loop
         Delay_Us (T, Command_Delay_Us);
         Decode_Telemetry (T);
         for I in 0 .. Plan.Count - 1 loop
            Request_Telemetry (T, I);
            Write_Int (T, Q, I,
                       (if Unsigned_8 (I) = Plan.Index or else Plan.Index = All_Motors then Unsigned_16 (Plan.Command)
                        else Unsigned_16 (Motor_Stop)));
         end loop;
         Update_Complete (T, Q);
      end loop;
      Delay_Us (T, Plan.Delay_After_Us);
      Finish_Blocking (Q, Plan.Count);
   end Run;

end Adaflight.DShot_Command.Blocking_Run;
