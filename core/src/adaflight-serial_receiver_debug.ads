--  The SBUS and FPORT receivers' debug values as the reference records
--  them. Under the SBUS mode: the flags byte of each frame the status takes,
--  and the time from a frame's first byte to its last at each completed
--  frame. Under the FPORT mode: the interval between closed frames, the
--  frame error count and the last error's reason, and the interval between
--  telemetry replies. Each value comes from taps and state, so it stays as
--  its site last wrote it.
with Adaflight.Debug;
with Adaflight.FPORT;
with Adaflight.SBUS;

package Adaflight.Serial_Receiver_Debug with SPARK_Mode is

   --  After an SBUS frame status, or after the bytes of a pass without one.
   procedure Record_SBUS (D : in out Debug.State; S : SBUS.State)
     with Global => null;

   --  After an FPORT frame status or frame processing.
   procedure Record_FPORT (D : in out Debug.State; S : FPORT.State)
     with Global => null;

end Adaflight.Serial_Receiver_Debug;
