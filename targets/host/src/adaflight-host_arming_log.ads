--  The host's log of arming events: one line for each arm and each disarm,
--  with the uptime in milliseconds and a disarm's reason, appended to the
--  file the environment variable ADAFLIGHT_ARMING_LOG names. Without the
--  variable nothing is written. A check that finds the craft disarmed reads
--  the reason here.
package Adaflight.Host_Arming_Log is
   --  Notes a change of the armed state, once per scheduler pass.
   procedure Poll;
end Adaflight.Host_Arming_Log;
