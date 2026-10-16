--  PWM motor output: the output range of the analog protocols, PWM,
--  OneShot, MultiShot and brushed, from the motor and 3D groups' pulse
--  widths.
with Adaflight.Maths;

package Adaflight.PWM_Output with SPARK_Mode is

   subtype Pulse_Width is Natural range 0 .. 65_535;

   --  The minimum command raised by a tenth of the idle setting, up to the
   --  maximum throttle brought down by what the output limit leaves of the
   --  span, with the disarm output at the minimum command; in the two
   --  direction mode the 3D limits brought in by half the limited span, the
   --  disarm output at the neutral pulse, and the deadband edges, written
   --  only in that mode.
   procedure Endpoints
     (Min_Command, Max_Throttle, Idle, Limit_3D_Low, Limit_3D_High, Neutral_3D, Deadband_3D_Low,
      Deadband_3D_High : Pulse_Width; Output_Limit : Maths.Unit_Interval; Two_Direction : Boolean;
      Low, High, Disarm : out Float; Deadband_High, Deadband_Low : in out Float)
     with Post => (if not Two_Direction
                   then Deadband_High = Deadband_High'Old and then Deadband_Low = Deadband_Low'Old);

end Adaflight.PWM_Output;
