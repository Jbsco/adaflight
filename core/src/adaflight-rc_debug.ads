--  The RC command path's debug values as the reference records them: the
--  frame timing and rates, the smoothing's counts, cutoffs and gains, the
--  smoothing inputs, the setpoint rates, and the debug axis's feedforward
--  terms, with the link quality and signal state the receiver reports. Each
--  site's values come from the command state's taps, so a value stays as its
--  site last wrote it.
with Adaflight.Axes;
with Adaflight.Debug;
with Adaflight.RC_Command;

package Adaflight.RC_Debug with SPARK_Mode is

   --  After one command pass, with the gyro configuration's debug axis.
   procedure Record_Pass
     (D : in out Debug.State; S : RC_Command.State; Debug_Axis : Axes.Axis; Link_Quality_Percent : Natural;
      Receiving : Boolean)
     with Global => null, Pre => Link_Quality_Percent <= 100;

end Adaflight.RC_Debug;
