--  The in-flight accelerometer calibration the arming logic and the
--  accelerometer share: armed or saved by a stick command, measured over a
--  run of samples once flying or with the calibration switch, and saved
--  once landed and disarmed.

package Adaflight.Acc_Inflight with SPARK_Mode, Pure is

   Measurement_Samples : constant := 50;
   subtype Countdown is Natural range 0 .. Measurement_Samples;

   type State is record
      Armed            : Boolean := False;
      Measurement_Done : Boolean := False;
      Save_Pending     : Boolean := False;
      Active           : Boolean := False;
      Remaining        : Countdown := 0;
   end record;

end Adaflight.Acc_Inflight;
