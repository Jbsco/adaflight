--  The PID controller's debug values as the reference records them: the TPA
--  factor and wing speed terms, the anti-gravity throttle derivative and
--  boosts, the level modes' targets, errors and angles, roll's I term relax,
--  the landing check's inputs, the wing's S terms, attenuations and
--  setpoints, the D term's raw deltas and values before TPA, and the debug
--  axis's D max factors.
with Adaflight.Axes;
with Adaflight.Debug;
with Adaflight.PID_Config;
with Adaflight.PID_Controller;

package Adaflight.PID_Debug with SPARK_Mode is

   --  After one controller loop with the inputs it took, and the debug axis.
   procedure Record_Loop
     (D : in out Debug.State; S : PID_Controller.State; R : PID_Config.Runtime; Inp : PID_Controller.Inputs;
      Debug_Axis : Axes.Axis);

end Adaflight.PID_Debug;
