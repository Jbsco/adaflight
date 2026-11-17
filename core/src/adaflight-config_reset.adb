with Adaflight.Simplified_Tuning.Stored;

package body Adaflight.Config_Reset with SPARK_Mode is

   procedure Apply_Tuning (C : in out Configuration) is
   begin
      for I in C.Pid_Profiles'Range loop
         Simplified_Tuning.Stored.Apply (C.Pid_Profiles (I), C.Gyro_Config);
      end loop;
   end Apply_Tuning;

   procedure Reset (Board : Board_Info.State; Wing : Boolean; Gyros : Positive; C : out Configuration) is
   begin
      C := Defaults;
      if Wing then
         Apply_Wing_Groups (C);
      end if;
      if Gyros > 1 then
         Apply_Second_Gyro (C);
      end if;
      Apply_Tuning (C);
      Board_Info.Reset_Config (C, Board);
   end Reset;

   function Reset
     (Board : Board_Info.State; Wing : Boolean := False; Gyros : Positive := 1) return Configuration is
   begin
      return C : Configuration do
         Reset (Board, Wing, Gyros, C);
      end return;
   end Reset;

end Adaflight.Config_Reset;
