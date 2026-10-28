with Adaflight.DShot_Command.Blocking_Run;
with Adaflight.STM32.Motors;
with Adaflight.STM32.Time;
package body Adaflight.STM32.DShot_Output is
   use Adaflight.DShot_Command;
   use type Interfaces.Unsigned_16;

   Queue     : Adaflight.DShot_Command.Queue;
   Is_DShot  : Boolean := False;
   Enable_Ms : Interfaces.Unsigned_32 := 0;
   --  Each motor's last value, the stop when it idles, and its telemetry
   --  request for the next frame.
   Last      : array (Motor_Index) of Interfaces.Unsigned_16 := (others => 0);
   Requests  : array (Motor_Index) of Boolean := (others => False);

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
   begin
      Is_DShot := C.Motor_Config.Dev.Motor_Protocol in 5 .. 8;
   end Init;

   function Protocol_Is_DShot return Boolean is (Is_DShot);

   function Driven return Motor_Count is (Natural'Min (Adaflight.STM32.Motors.Count, Max_Motors));

   function Facts return Motor_Facts is
      F : Motor_Facts;
   begin
      F.DShot := Is_DShot;
      F.Enabled := Adaflight.STM32.Motors.Enabled;
      F.Enable_Time_Ms := Enable_Ms;
      F.Now_Ms := Adaflight.STM32.Time.Millis;
      F.Count := Driven;
      for I in Motor_Index loop
         F.Idle (I) := Last (I) = 0;
      end loop;
      return F;
   end Facts;

   procedure Enable is
   begin
      Adaflight.STM32.Motors.Enable;
      if Adaflight.STM32.Motors.Enabled then
         Enable_Ms := Adaflight.STM32.Time.Millis;
      end if;
   end Enable;

   procedure Disable is
   begin
      Adaflight.STM32.Motors.Disable;
      Enable_Ms := 0;
   end Disable;

   procedure Set_Loop_Time (Us : Adaflight.DShot_Command.Loop_Time_Us) is
   begin
      Adaflight.DShot_Command.Set_Loop_Time (Queue, Us);
   end Set_Loop_Time;

   procedure Streaming_Enabled (Enabled : out Boolean) is
   begin
      Adaflight.DShot_Command.Streaming_Enabled (Queue, Facts, Enabled);
   end Streaming_Enabled;

   --  A motor's value as the timer layer writes it: the current command in
   --  its place while one is processing, with a telemetry request when it is
   --  not the stop, then the value kept as the motor's idle state and the
   --  request taken by the frame.
   procedure Write_Int (Q : Adaflight.DShot_Command.Queue; Index : Motor_Index; Value : Interfaces.Unsigned_16) is
      V : Interfaces.Unsigned_16 := Value;
      R : Boolean := Requests (Index);
   begin
      if not Adaflight.STM32.Motors.Motor_Enabled (Index) then
         return;
      end if;
      Command_Value (Q, Index, V, R);
      Last (Index) := V;
      Requests (Index) := False;
      Adaflight.STM32.Motors.Send_Frame (Index, V, R);
   end Write_Int;

   --  The end of a motor update: with commands queued, the queue's output
   --  gate decides whether the transfers start.
   procedure Complete (Q : in out Adaflight.DShot_Command.Queue) is
      Open : Boolean := True;
   begin
      if not Queue_Empty (Q) then
         Output_Is_Enabled (Q, Facts, Open);
         if not Open then
            return;
         end if;
      end if;
      Adaflight.STM32.Motors.Start_Transfers;
   end Complete;

   type Table is null record;

   procedure Table_Delay (T : in out Table; Us : Interfaces.Unsigned_32) is
      pragma Unreferenced (T);
   begin
      Adaflight.STM32.Time.Delay_Us (Natural (Us));
   end Table_Delay;

   procedure Table_Decode (T : in out Table) is
      pragma Unreferenced (T);
   begin
      null;
   end Table_Decode;

   procedure Table_Request (T : in out Table; Index : Motor_Index) is
      pragma Unreferenced (T);
   begin
      Requests (Index) := True;
   end Table_Request;

   procedure Table_Write
     (T : in out Table; Q : Adaflight.DShot_Command.Queue; Index : Motor_Index; Value : Interfaces.Unsigned_16)
   is
      pragma Unreferenced (T);
   begin
      Write_Int (Q, Index, Value);
   end Table_Write;

   procedure Table_Complete (T : in out Table; Q : in out Adaflight.DShot_Command.Queue) is
      pragma Unreferenced (T);
   begin
      Complete (Q);
   end Table_Complete;

   package Blocking_Commands is new Adaflight.DShot_Command.Blocking_Run
     (Motor_Table       => Table,
      Delay_Us          => Table_Delay,
      Decode_Telemetry  => Table_Decode,
      Request_Telemetry => Table_Request,
      Write_Int         => Table_Write,
      Update_Complete   => Table_Complete);

   procedure Write_Command
     (Index   : Interfaces.Unsigned_8;
      Motors  : Natural;
      Command : Interfaces.Unsigned_8;
      Kind    : Adaflight.DShot_Command.Command_Type)
   is
      Plan : Blocking_Plan;
      T    : Table;
   begin
      Write (Queue, Facts, Index, Natural'Min (Motors, Max_Motors), Command, Kind, Plan);
      Blocking_Commands.Run (Queue, T, Plan);
   end Write_Command;

   procedure Write_Blocking (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8) is
   begin
      Write_Command (Interfaces.Unsigned_8 (Natural'Min (Index, 255)), Motors, Command, Blocking);
   end Write_Blocking;

   procedure Write_All (Values : Adaflight.Mixer.Motor_Outputs) is
   begin
      if not Adaflight.STM32.Motors.Enabled then
         return;
      end if;
      for M in 0 .. Driven - 1 loop
         declare
            Clamped : constant Float := Float'Max (0.0, Float'Min (2_047.0, Float (Values (M))));
         begin
            Write_Int (Queue, M, Interfaces.Unsigned_16 (Float'Unbiased_Rounding (Clamped)));
         end;
      end loop;
      Complete (Queue);
   end Write_All;
end Adaflight.STM32.DShot_Output;
