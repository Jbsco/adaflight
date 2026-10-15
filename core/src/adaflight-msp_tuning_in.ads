--  The MSP in messages that write the tuning to the stored configuration:
--  the PID gains, the rate profile, the arming configuration, the
--  accelerometer trims, the 3D throttle, the stick deadbands, the sensor and
--  board alignments, the reset of the current PID profile, the advanced
--  configuration, the filters and the advanced PID settings. The gains go to
--  the current PID profile and the rates to the current rate profile; the
--  advanced configuration and the filters end with the gyro's checks of the
--  configuration fix. A request reads zero past its end. A request with a
--  field outside its setting's range is an error that writes and changes
--  nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Config_Fix;

package Adaflight.MSP_Tuning_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Board_Alignment_Config_Command : constant := 39;
   Set_PID_Controller_Command         : constant := 60;
   Set_Arming_Config_Command          : constant := 62;
   Set_Advanced_Config_Command        : constant := 91;
   Set_Filter_Config_Command          : constant := 93;
   Set_PID_Advanced_Command           : constant := 95;
   Set_PID_Command                    : constant := 202;
   Set_RC_Tuning_Command              : constant := 204;
   Set_Motor_3D_Config_Command        : constant := 217;
   Set_RC_Deadband_Command            : constant := 218;
   Set_Reset_Current_PID_Command      : constant := 219;
   Set_Sensor_Alignment_Command       : constant := 220;
   Set_Acc_Trim_Command               : constant := 239;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Board_Alignment_Config_Command | Set_PID_Controller_Command | Set_Arming_Config_Command
        | Set_Advanced_Config_Command | Set_Filter_Config_Command | Set_PID_Advanced_Command | Set_PID_Command
        | Set_RC_Tuning_Command | Set_Motor_3D_Config_Command .. Set_Sensor_Alignment_Command | Set_Acc_Trim_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the PID controller's settings taken
   --  in again, the stick processing set up again, the gyro's or the PID
   --  controller's filters set up again, the motor output endpoints, or the
   --  mixer's profile settings.
   type Effects is record
      PID_Init      : Boolean := False;
      RC_Init       : Boolean := False;
      Gyro_Filters  : Boolean := False;
      PID_Filters   : Boolean := False;
      ESC_Endpoints : Boolean := False;
      Mixer_Profile : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   --  The current PID and rate profiles are within their lists.
   function Profiles_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < C.Pid_Profiles'Length
      and then Natural (C.System_Config.Active_Rate_Profile) < C.Control_Rate_Profiles'Length);

   Max_Request : constant := 255;

   --  One in message on the configuration; the gyro's checks read the gyro's
   --  sample rate.
   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      Gyro_Sample_Rate_Hz : Config_Fix.Gyro_Rate; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_Tuning_In;
