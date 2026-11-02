--  The MAVLink debug values as the reference records them: after each
--  receiver byte that completed a radio status, the transmitter's free
--  buffer, and after each telemetry pass, whether a valid buffer report let
--  it send and the count before each counted message it sent. Each value
--  comes from taps, so it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.MAVLink;
with Adaflight.MAVLink_Telemetry;

package Adaflight.MAVLink_Debug with SPARK_Mode is

   --  After a receiver byte.
   procedure Record_Receiver (D : in out Debug.State; R : MAVLink.State)
     with Global => null;

   --  After a telemetry pass, with the buffer report it took.
   procedure Record_Telemetry
     (D : in out Debug.State; T : MAVLink_Telemetry.State; Tx_Valid, Tx_Should_Send : Boolean)
     with Global => null;

end Adaflight.MAVLink_Debug;
