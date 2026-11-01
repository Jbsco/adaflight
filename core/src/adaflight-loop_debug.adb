package body Adaflight.Loop_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   --  The low sixteen bits of an unsigned value, as the reference's store of
   --  an unsigned into the debug array keeps them.
   function Low (U : Interfaces.Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (U mod 2 ** 16)));

   procedure Record_PID_Loop
     (D : in out Debug.State; Gyro_Us, Controller_Us, Motor_Us, Subprocess_Us : Interfaces.Unsigned_32)
   is
   begin
      if Debug.Selected (D, Debug.PID_Loop) then
         Debug.Set (D, Debug.PID_Loop, 0, Low (Gyro_Us));
         Debug.Set (D, Debug.PID_Loop, 1, Low (Controller_Us));
         Debug.Set (D, Debug.PID_Loop, 2, Low (Motor_Us));
         Debug.Set (D, Debug.PID_Loop, 3, Low (Subprocess_Us));
      end if;
   end Record_PID_Loop;

   procedure Record_Cycle
     (D : in out Debug.State; Delta_Us : Scheduler.Time_Delta; Load_Percent : Natural;
      Interval_Us : Interfaces.Unsigned_32; Target_Us : Interfaces.Unsigned_32)
   is
   begin
      if Debug.Selected (D, Debug.Cycle_Time) then
         Debug.Set (D, Debug.Cycle_Time, 0, Debug.Wrapped (Interfaces.Integer_32 (Delta_Us)));
         Debug.Set (D, Debug.Cycle_Time, 1,
                    Debug.Wrapped (Interfaces.Integer_32 (Natural'Min (Load_Percent, 65_535))));
         Debug.Set (D, Debug.Cycle_Time, 2, Low (Interval_Us));
         Debug.Set (D, Debug.Cycle_Time, 3, Low (Interval_Us - Target_Us));
      end if;
   end Record_Cycle;

   procedure Record_Scheduler (D : in out Debug.State; S : Scheduler.State) is
      Modes : constant array (1 .. 4) of Debug.Mode :=
        (Debug.Scheduler, Debug.Scheduler_Determinism, Debug.Timing_Accuracy, Debug.Tasks);
   begin
      pragma Assert (Debug.Mode'Pos (Debug.Scheduler) = Scheduler.Scheduler_Debug
                     and then Debug.Mode'Pos (Debug.Scheduler_Determinism) = Scheduler.Determinism_Debug
                     and then Debug.Mode'Pos (Debug.Timing_Accuracy) = Scheduler.Timing_Accuracy_Debug
                     and then Debug.Mode'Pos (Debug.Tasks) = Scheduler.Task_Debug);
      for M of Modes loop
         if Debug.Selected (D, M) then
            for I in Debug.Index loop
               Debug.Set (D, M, I, S.Debug (I));
            end loop;
         end if;
      end loop;
   end Record_Scheduler;

end Adaflight.Loop_Debug;
