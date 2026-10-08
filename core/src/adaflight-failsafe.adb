with Interfaces; use type Interfaces.Integer_64;

package body Adaflight.Failsafe with SPARK_Mode is

   Millis_Per_Tenth  : constant Time_Ms := 100;
   Millis_Per_Second : constant Time_Ms := 1_000;
   Max_Passes        : constant := 8;

   --  The signed difference of two wrapping millisecond counters.
   function Elapsed (Later : Time_Ms; Earlier : Time_Ms) return Integer is
      D : constant Interfaces.Integer_64 := Interfaces.Integer_64 (Later) - Interfaces.Integer_64 (Earlier);
   begin
      if D > Interfaces.Integer_64 (Integer'Last) then
         return Integer (D - 2 ** 32);
      elsif D < Interfaces.Integer_64 (Integer'First) then
         return Integer (D + 2 ** 32);
      else
         return Integer (D);
      end if;
   end Elapsed;

   --  Now is past the deadline. Wrap-safe where the reference compares the
   --  counters directly (DESIGN.md D6).
   function After (Now : Time_Ms; Deadline : Time_Ms) return Boolean is
     (Elapsed (Now, Deadline) > 0);

   function Longer_Than (Difference : Integer; Period : Time_Ms) return Boolean is
     (Interfaces.Integer_64 (Difference) > Interfaces.Integer_64 (Period));

   -----------
   -- Reset --
   -----------

   procedure Reset (S : in out State; C : Settings) is
   begin
      S.Rx_Data_Failure_Period := Time_Ms (C.Signal_Delay) * Millis_Per_Tenth;
      S.Rx_Data_Recovery_Period := Time_Ms (C.Recovery_Delay) * Millis_Per_Tenth;
      S.Valid_Rx_Data_Received_At := 0;
      S.Valid_Rx_Data_Failed_At := 0;
      S.Throttle_Low_Period := 0;
      S.Landing_Should_Be_Finished_At := 0;
      S.Receiving_Rx_Data_Period := 0;
      S.Receiving_Rx_Data_Period_Preset := S.Rx_Data_Recovery_Period;
      S.Current := Idle;
      S.Rx_Link := Down;
      S.Switch_Was_On := False;
   end Reset;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
   begin
      S := (others => <>);
      Reset (S, C);
   end Init;

   ----------------------
   -- Start_Monitoring --
   ----------------------

   procedure Start_Monitoring (S : in out State) is
   begin
      S.Monitoring := True;
   end Start_Monitoring;

   ----------------------------
   -- On_Valid_Data_Received --
   ----------------------------

   procedure On_Valid_Data_Received (S : in out State; Now : Time_Ms) is
   begin
      S.Valid_Rx_Data_Received_At := Now;
      if S.Valid_Rx_Data_Failed_At = 0 then
         S.Valid_Rx_Data_Failed_At := S.Valid_Rx_Data_Received_At;
         S.Arming_Disabled_Rx := True;
      end if;
      if Longer_Than (Elapsed (S.Valid_Rx_Data_Received_At, S.Valid_Rx_Data_Failed_At),
                      S.Receiving_Rx_Data_Period_Preset)
      then
         S.Rx_Link := Up;
         S.Arming_Disabled_Rx := False;
      end if;
   end On_Valid_Data_Received;

   --------------------------
   -- On_Valid_Data_Failed --
   --------------------------

   procedure On_Valid_Data_Failed (S : in out State; Now : Time_Ms) is
   begin
      S.Arming_Disabled_Rx := True;
      S.Valid_Rx_Data_Failed_At := Now;
      if Longer_Than (Elapsed (S.Valid_Rx_Data_Failed_At, S.Valid_Rx_Data_Received_At), S.Rx_Data_Failure_Period) then
         S.Rx_Link := Down;
      end if;
   end On_Valid_Data_Failed;

   -------------------------------
   -- Check_Data_Failure_Period --
   -------------------------------

   procedure Check_Data_Failure_Period (S : in out State; Now : Time_Ms) is
   begin
      if Longer_Than (Elapsed (Now, S.Valid_Rx_Data_Received_At), S.Rx_Data_Failure_Period) then
         S.Rx_Link := Down;
         S.Arming_Disabled_Rx := True;
      end if;
   end Check_Data_Failure_Period;

   -------------------
   -- On_Rx_Suspend --
   -------------------

   procedure On_Rx_Suspend (S : in out State; Suspend_Period_Us : Unsigned_32) is
   begin
      S.Valid_Rx_Data_Received_At := S.Valid_Rx_Data_Received_At + Suspend_Period_Us / 1_000;
   end On_Rx_Suspend;

   ------------------
   -- On_Rx_Resume --
   ------------------

   procedure On_Rx_Resume (S : in out State; Now : Time_Ms) is
   begin
      S.Valid_Rx_Data_Received_At := Now;
      S.Rx_Link := Up;
   end On_Rx_Resume;

   ------------
   -- Update --
   ------------

   procedure Update (
      S         : in out State;
      C         : Settings;
      Now       : Time_Ms;
      In_Flight : Inputs;
      Beeper    : out Beep;
      Disarm    : out Boolean
   ) is
      Receiving : Boolean := Receiving_Rx_Data (S);
      Reprocess : Boolean;

      procedure Count_Event is
      begin
         if S.Events < Event_Count'Last then
            S.Events := S.Events + 1;
         end if;
      end Count_Event;

      procedure Start_Procedure is
      begin
         case C.Action is
            when Auto_Landing =>
               S.Failsafe_Mode := True;
               S.Current := Landing;
               S.Landing_Should_Be_Finished_At := Now + Time_Ms (C.Landing_Time) * Millis_Per_Second;
            when Drop =>
               S.Failsafe_Mode := True;
               S.Current := Landed;
         end case;
      end Start_Procedure;
   begin
      Beeper := Silence;
      Disarm := False;
      if not S.Monitoring then
         return;
      end if;
      if In_Flight.Switch_On and then C.Switch = Stage_2 then
         Receiving := False;
      end if;
      if not Receiving and then not In_Flight.Configurator_Active then
         Beeper := Rx_Lost;
      end if;
      --  The reference reprocesses until a stage holds; the stages form a
      --  chain of at most five within one pass, so eight is inert.
      for Pass in 1 .. Max_Passes loop
         Reprocess := False;
         case S.Current is
            when Idle =>
               S.Switch_Was_On := In_Flight.Switch_On;
               if In_Flight.Armed then
                  if not In_Flight.Throttle_Low then
                     S.Throttle_Low_Period := Now + Time_Ms (C.Throttle_Low_Delay) * Millis_Per_Tenth;
                  end if;
                  if S.Switch_Was_On and then C.Switch = Kill then
                     S.Active := True;
                     Count_Event;
                     S.Failsafe_Mode := True;
                     S.Current := Landed;
                     S.Receiving_Rx_Data_Period_Preset := S.Rx_Data_Recovery_Period;
                     Reprocess := True;
                  elsif not Receiving then
                     if After (Now, S.Throttle_Low_Period) then
                        S.Active := True;
                        Count_Event;
                        S.Failsafe_Mode := True;
                        S.Current := Landed;
                        S.Receiving_Rx_Data_Period_Preset := S.Rx_Data_Recovery_Period;
                     else
                        S.Current := Rx_Loss_Detected;
                     end if;
                     Reprocess := True;
                  end if;
               else
                  S.Failsafe_Mode := S.Switch_Was_On;
                  S.Throttle_Low_Period := 0;
               end if;
            when Rx_Loss_Detected =>
               if Receiving then
                  S.Current := Rx_Loss_Recovered;
               else
                  S.Active := True;
                  Count_Event;
                  Start_Procedure;
                  S.Receiving_Rx_Data_Period_Preset := (if S.Switch_Was_On then 0 else S.Rx_Data_Recovery_Period);
               end if;
               Reprocess := True;
            when Landing =>
               if Receiving then
                  S.Current := Rx_Loss_Recovered;
                  Reprocess := True;
               else
                  if In_Flight.Armed then
                     Beeper := Rx_Lost_Landing;
                  end if;
                  if After (Now, S.Landing_Should_Be_Finished_At) or else In_Flight.Crash_Recovery
                    or else not In_Flight.Armed
                  then
                     S.Current := Landed;
                     Reprocess := True;
                  end if;
               end if;
            when Landed =>
               Disarm := True;
               S.Arming_Disabled := True;
               S.Receiving_Rx_Data_Period := Now + S.Receiving_Rx_Data_Period_Preset;
               S.Current := Rx_Loss_Monitoring;
               Reprocess := True;
            when Rx_Loss_Monitoring =>
               if Receiving then
                  if After (Now, S.Receiving_Rx_Data_Period) then
                     S.Current := Rx_Loss_Recovered;
                     Reprocess := True;
                  end if;
               else
                  S.Receiving_Rx_Data_Period := Now + S.Receiving_Rx_Data_Period_Preset;
               end if;
            when Rx_Loss_Recovered =>
               S.Throttle_Low_Period := Now + Time_Ms (C.Throttle_Low_Delay) * Millis_Per_Tenth;
               S.Current := Idle;
               S.Active := False;
               S.Failsafe_Mode := False;
               S.Arming_Disabled := False;
               Reprocess := True;
         end case;
         exit when not Reprocess;
      end loop;
   end Update;

end Adaflight.Failsafe;
