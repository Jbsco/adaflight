package body Adaflight.Main_Loop with SPARK_Mode is

   procedure PID_Loop (O : Options; I : Pass_Inputs) is
   begin
      if I.Resets_Yaw then
         Reset_Yaw;
      end if;
      RC_Command;
      if O.Wing_Launch then
         Launch_Wing;
      end if;
      PID_Controller;
      Runaway_Check;
      if I.PID_Audio then
         PID_Audio;
      end if;
      Mix_Table;
      if I.Uses_Servos then
         Write_Servos;
      end if;
      Write_Motors;
      if not I.CLI_Open and then I.Log_Device then
         Blackbox_Update;
      end if;
   end PID_Loop;

end Adaflight.Main_Loop;
