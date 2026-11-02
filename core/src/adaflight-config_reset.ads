--  The configuration reset: the defaults, the simplified tuning applied to
--  every PID profile, and the board's information kept.
with Adaflight.Board_Info;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Config_Reset with SPARK_Mode is

   --  The simplified tuning of every PID profile with the gyro settings.
   procedure Apply_Tuning (C : in out Configuration);

   --  The reset configuration for a board.
   function Reset (Board : Board_Info.State; Wing : Boolean := False) return Configuration;

end Adaflight.Config_Reset;
