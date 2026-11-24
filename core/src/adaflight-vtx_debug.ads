--  The video transmitter drivers' debug values as the reference records
--  them. Under the Tramp mode, after each task call: the driver's status,
--  the reply code it read, its pit modes and powers packed with the change
--  flags, and the retries left. Under the SmartAudio mode, after each
--  settings reply: the version and mode, the channel, the frequency and the
--  power index. Each value comes from taps, so it stays as its site last
--  wrote it. Under the MSP mode, after each driver cycle: the count of
--  configuration frames sent, whether the link is the CRSF receiver's,
--  whether low power while disarmed applies, and the link's MSP descriptor.
with Adaflight.Debug;
with Adaflight.SmartAudio;
with Adaflight.Tramp;
with Adaflight.VTX_MSP;

package Adaflight.VTX_Debug with SPARK_Mode is

   --  After a Tramp task call.
   procedure Record_Tramp (D : in out Debug.State; T : Tramp.Driver)
     with Global => null;

   --  After a SmartAudio task call.
   procedure Record_SmartAudio (D : in out Debug.State; A : SmartAudio.Driver)
     with Global => null;

   --  After an MSP driver cycle. The descriptor is the telemetry link's on
   --  a CRSF port, else the serial MSP port's, negative when none is open.
   procedure Record_MSP
     (D : in out Debug.State; M : VTX_MSP.Driver; Low_Power, CRSF_Port : Boolean;
      Serial_Descriptor, Telemetry_Descriptor : Debug.Integer_16)
     with Global => null;

end Adaflight.VTX_Debug;
