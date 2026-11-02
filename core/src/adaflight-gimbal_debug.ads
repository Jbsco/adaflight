--  The gimbal's debug values as the reference records them: after each call
--  that set the gimbal, the head tracker's roll, pitch and yaw, then the
--  roll, pitch and yaw before their limits. Each value comes from taps, so
--  it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.Gimbal_Control;

package Adaflight.Gimbal_Debug with SPARK_Mode is

   --  After an init or update of the gimbal control.
   procedure Record_Set (D : in out Debug.State; T : Gimbal_Control.State)
     with Global => null;

end Adaflight.Gimbal_Debug;
