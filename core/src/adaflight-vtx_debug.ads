--  The video transmitter drivers' debug values as the reference records
--  them. Under the Tramp mode, after each task call: the driver's status,
--  the reply code it read, its pit modes and powers packed with the change
--  flags, and the retries left. Under the SmartAudio mode, after each
--  settings reply: the version and mode, the channel, the frequency and the
--  power index. Each value comes from taps, so it stays as its site last
--  wrote it.
with Adaflight.Debug;
with Adaflight.SmartAudio;
with Adaflight.Tramp;

package Adaflight.VTX_Debug with SPARK_Mode is

   --  After a Tramp task call.
   procedure Record_Tramp (D : in out Debug.State; T : Tramp.Driver)
     with Global => null;

   --  After a SmartAudio task call.
   procedure Record_SmartAudio (D : in out Debug.State; A : SmartAudio.Driver)
     with Global => null;

end Adaflight.VTX_Debug;
