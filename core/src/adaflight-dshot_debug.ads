--  The DShot debug values as the reference records them: under the RPM
--  telemetry mode each motor's decoded period in hundreds of electrical
--  revolutions per minute whenever its reply decodes as a period, under the
--  RPM filter mode each motor's filtered frequency in hertz after each
--  processing of the replies, under the telemetry counts mode the samples a
--  bit-banged decode skipped before its search and the replies read, missed
--  and timed out, each added to its value while that mode is selected, and
--  under the RPM errors mode the invalid share of the first four motors'
--  replies after each motor write. Each value comes from the telemetry's
--  taps and state, so it stays as its site last wrote it.
with Adaflight.Debug;
with Adaflight.DShot;

package Adaflight.DShot_Debug with SPARK_Mode is

   --  After one processing of the replies.
   procedure Record_Update (D : in out Debug.State; T : DShot.Telemetry)
     with Global => null;

   --  After a bit-banged read of the replies.
   procedure Record_Decode (D : in out Debug.State; E : DShot.Edge_Decoder)
     with Global => null;

   --  After a bit-banged read: its replies read and its missed replies.
   procedure Record_Read (D : in out Debug.State; C : DShot.Read_Counts)
     with Global => null;

   --  After a bit-banged wait that gave up on its ports.
   procedure Record_Timeout (D : in out Debug.State)
     with Global => null;

   --  After a motor write, with the motor count and whether telemetry runs.
   procedure Record_Errors (D : in out Debug.State; T : DShot.Telemetry; Q : DShot.Qualities;
                            Count : DShot.Motor_Total; Use_Telemetry : Boolean)
     with Global => null;

end Adaflight.DShot_Debug;
