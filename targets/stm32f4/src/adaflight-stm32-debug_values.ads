--  The debug values the board records and shows: one state every recorder
--  writes and every reader takes, and the gyro configuration's debug axis
--  the recorders follow.
with Adaflight.Axes;
with Adaflight.Debug;
package Adaflight.STM32.Debug_Values is
   State : Adaflight.Debug.State;
   Axis  : Adaflight.Axes.Axis := Adaflight.Axes.Roll;
end Adaflight.STM32.Debug_Values;
