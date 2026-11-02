--  The receiver core's debug values as the reference records them. Under
--  the signal loss mode: the task interval in tenths of a millisecond at
--  every frame check, the frame's failsafe flag when a serial-class frame
--  was read, the signal verdict after each check past a running task, and
--  the throttle channel after each signal loss pass. Under the failsafe
--  mode: that signal verdict, the receiving verdict at the entry of each
--  monitored pass, the switch flag and the phase. Under the receiver state
--  time mode: each step's estimate in microseconds. Each value comes from
--  taps and state, so it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.Failsafe;
with Adaflight.Receiver;
with Adaflight.RX_Task;

package Adaflight.Receiver_Debug with SPARK_Mode is

   --  After a frame check, with the interval since the last one.
   procedure Record_Frame_Check (D : in out Debug.State; S : Receiver.State; Delta_Us : Receiver.Time_Delta)
     with Global => null;

   --  After a channel calculation.
   procedure Record_Channels (D : in out Debug.State; S : Receiver.State)
     with Global => null;

   --  After a failsafe pass.
   procedure Record_Failsafe (D : in out Debug.State; F : Failsafe.State)
     with Global => null;

   --  After a receiver task step, with the step it left.
   procedure Record_State_Time (D : in out Debug.State; T : RX_Task.State; Left : RX_Task.Step)
     with Global => null;

end Adaflight.Receiver_Debug;
