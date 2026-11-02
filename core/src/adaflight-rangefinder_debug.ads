--  The rangefinder's debug values as the reference records them: after a
--  processed reading the raw and tilt corrected altitudes, the signal
--  quality, the tilt cosine and its usable limit, the threshold state and
--  whether the surface altitude stood valid; after a lidar frame its
--  distance, strength, two frame bytes and the checksum error count; after a
--  UPT1 frame its distance, confidence, flow, status, integration time, the
--  reported distance and the parser phase. Each value comes from the units'
--  own last values, so it stays as its site last wrote it.
with Interfaces;
with Adaflight.Debug;
with Adaflight.Rangefinder;

package Adaflight.Rangefinder_Debug with SPARK_Mode is
   use type Interfaces.Integer_32;

   --  After one rangefinder process call.
   procedure Record_Process (D : in out Debug.State; S : Rangefinder.Sensor)
     with Global => null;

   --  After a lidar driver update, with its last frame's values and its
   --  checksum error count.
   procedure Record_Lidar_TF
     (D : in out Debug.State; Distance, Strength : Interfaces.Unsigned_16; Byte_4, Byte_5 : Natural;
      Errors : Interfaces.Unsigned_32)
     with Global => null, Pre => Byte_4 <= 255 and then Byte_5 <= 255;

   --  After a UPT1 driver update, with its last frame's values and the
   --  parser phase seen before its last byte.
   procedure Record_UPT1
     (D : in out Debug.State; Distance_Mm : Interfaces.Unsigned_16; Confidence : Natural;
      Flow_X, Flow_Y : Interfaces.Integer_16; Valid_Status : Natural; Integration_Us : Interfaces.Unsigned_16;
      Reported : Interfaces.Integer_32; Phase : Natural)
     with Global => null,
          Pre => Confidence <= 255 and then Valid_Status <= 255 and then Reported in -99 .. 1_200 and then Phase <= 7;

end Adaflight.Rangefinder_Debug;
