--  The core loop's timing debug values as the reference records them: the
--  PID task's gyro, controller, motor update and subprocess times, its cycle
--  time with the system load and the motor update interval against the loop
--  period, and the scheduler's own values under its four modes.
with Interfaces;
with Adaflight.Debug;
with Adaflight.Scheduler;

package Adaflight.Loop_Debug with SPARK_Mode is

   --  After one PID task run, its four durations in microseconds.
   procedure Record_PID_Loop
     (D : in out Debug.State; Gyro_Us, Controller_Us, Motor_Us, Subprocess_Us : Interfaces.Unsigned_32)
     with Global => null;

   --  After one PID task run: the task's delta time, the system load, and
   --  the motor update interval against the loop period.
   procedure Record_Cycle
     (D : in out Debug.State; Delta_Us : Scheduler.Time_Delta; Load_Percent : Natural;
      Interval_Us : Interfaces.Unsigned_32; Target_Us : Interfaces.Unsigned_32)
     with Global => null;

   --  After a scheduler pass, the scheduler's values under its modes.
   procedure Record_Scheduler (D : in out Debug.State; S : Scheduler.State)
     with Global => null;

end Adaflight.Loop_Debug;
