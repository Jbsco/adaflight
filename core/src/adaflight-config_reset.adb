with Adaflight.Simplified_Tuning.Stored;

package body Adaflight.Config_Reset with SPARK_Mode is

   procedure Apply_Tuning (C : in out Configuration) is
   begin
      for I in C.Pid_Profiles'Range loop
         Simplified_Tuning.Stored.Apply (C.Pid_Profiles (I), C.Gyro_Config);
      end loop;
   end Apply_Tuning;

   procedure Reset (Board : Board_Info.State; Wing : Boolean; C : out Configuration) is
   begin
      C := Defaults;
      if Wing then
         Apply_Wing_Groups (C);
      end if;
      Apply_Tuning (C);
      Board_Info.Reset_Config (C, Board);
   end Reset;

   function Reset (Board : Board_Info.State; Wing : Boolean := False) return Configuration is
   begin
      return C : Configuration do
         Reset (Board, Wing, C);
      end return;
   end Reset;

end Adaflight.Config_Reset;
