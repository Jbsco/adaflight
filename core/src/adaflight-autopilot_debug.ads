--  The autopilot's debug values as the reference records them: the altitude
--  controller's throttle, altitudes and terms, the yaw controller's headings,
--  error, rate, proportional term and disable reason, the position hold's
--  sensor status, and the position controller's velocities, errors, terms,
--  sums, lean angles, speeds, distances and status flags. Each site's values
--  come from the controllers' taps, so a value stays as its site last wrote
--  it. The debug axis selects north for pitch and east otherwise, as the
--  reference maps it.
with Adaflight.Axes;
with Adaflight.Altitude_Control;
with Adaflight.Debug;
with Adaflight.Position_Control;
with Adaflight.Position_Hold;

package Adaflight.Autopilot_Debug with SPARK_Mode is

   --  After an altitude controller run.
   procedure Record_Altitude (D : in out Debug.State; S : Altitude_Control.State)
     with Global => null;

   --  After a position hold or rescue update.
   procedure Record_Heading (D : in out Debug.State; S : Position_Control.State)
     with Global => null;

   --  After a position hold update.
   procedure Record_Hold (D : in out Debug.State; H : Position_Hold.State)
     with Global => null;

   --  After a position hold or rescue update, with the gyro configuration's
   --  debug axis.
   procedure Record_Position (D : in out Debug.State; S : Position_Control.State; Debug_Axis : Axes.Axis)
     with Global => null;

end Adaflight.Autopilot_Debug;
