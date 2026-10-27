--  A blocking command's run through the caller's motor table: the initial
--  delay less one command delay, then for each repeat a command delay, the
--  telemetry decode, a telemetry request and a write for each motor, the
--  command to its motor or to all and the stop to the others, and the
--  update's completion, then the delay after the command and the queue's
--  current entry back to the stop. The write takes the queue, which holds
--  the command in its current entry, as the timer layer's write reads it,
--  and the completion takes it for the queue's output gate.
generic
   type Motor_Table is limited private;
   with procedure Delay_Us (T : in out Motor_Table; Us : Unsigned_32);
   with procedure Decode_Telemetry (T : in out Motor_Table);
   with procedure Request_Telemetry (T : in out Motor_Table; Index : Motor_Index);
   with procedure Write_Int (T : in out Motor_Table; Q : Queue; Index : Motor_Index; Value : Unsigned_16);
   with procedure Update_Complete (T : in out Motor_Table; Q : in out Queue);
package Adaflight.DShot_Command.Blocking_Run with SPARK_Mode is
   procedure Run (Q : in out Queue; T : in out Motor_Table; Plan : Blocking_Plan);
end Adaflight.DShot_Command.Blocking_Run;
