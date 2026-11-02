with Adaflight.Simplified_Tuning.Stored;

package body Adaflight.Config_Reset with SPARK_Mode is

   procedure Apply_Tuning (C : in out Configuration) is
   begin
      for I in C.Pid_Profiles'Range loop
         Simplified_Tuning.Stored.Apply (C.Pid_Profiles (I), C.Gyro_Config);
      end loop;
   end Apply_Tuning;

   function Reset (Board : Board_Info.State; Wing : Boolean := False) return Configuration is
      C : Configuration := (if Wing then Wing_Defaults else Defaults);
   begin
      Apply_Tuning (C);
      Board_Info.Reset_Config (C, Board);
      return C;
   end Reset;

end Adaflight.Config_Reset;
