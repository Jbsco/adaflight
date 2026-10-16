--  The PID loop's pass over the units in the task's order: the yaw reset
--  before the RC command, the launch wing in a wing build, the controller
--  with the runaway check and the PID audio after it, the mix, the servos
--  when the mixer drives them, the motors, and the flight log outside the
--  command line when a log device is set. The units come in as the
--  instantiation's procedures.
generic
   with procedure Reset_Yaw;
   with procedure RC_Command;
   with procedure Launch_Wing;
   with procedure PID_Controller;
   with procedure Runaway_Check;
   with procedure PID_Audio;
   with procedure Mix_Table;
   with procedure Write_Servos;
   with procedure Write_Motors;
   with procedure Blackbox_Update;
package Adaflight.Main_Loop with SPARK_Mode is

   --  The build's options: whether it launches a wing.
   type Options is record
      Wing_Launch : Boolean := False;
   end record;

   --  What a pass reads: whether the yaw command is reset, whether the
   --  mixer drives servos, whether a flight log device is set, whether the
   --  command line is open, and whether a PID audio condition exists.
   type Pass_Inputs is record
      Resets_Yaw  : Boolean := False;
      Uses_Servos : Boolean := False;
      Log_Device  : Boolean := False;
      CLI_Open    : Boolean := False;
      PID_Audio   : Boolean := False;
   end record;

   procedure PID_Loop (O : Options; I : Pass_Inputs);

end Adaflight.Main_Loop;
