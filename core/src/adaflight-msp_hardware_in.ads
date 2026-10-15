--  The MSP in messages that write the hardware's configuration: the mixer
--  type, the sensors in use, the motor limits and protocol telemetry, the
--  GPS link, the compass declination, and the GPS rescue with its
--  controller gains. A request reads zero past its end. A request with a
--  field outside its setting's range is an error that writes and changes
--  nothing; the mixer type takes the bounds of the command line's mixer
--  command.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Hardware_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Mixer_Config_Command     : constant := 43;
   Set_Sensor_Config_Command    : constant := 97;
   Set_Motor_Config_Command     : constant := 222;
   Set_GPS_Config_Command       : constant := 223;
   Set_Compass_Config_Command   : constant := 224;
   Set_GPS_Rescue_Command       : constant := 225;
   Set_GPS_Rescue_PIDs_Command  : constant := 226;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Mixer_Config_Command | Set_Sensor_Config_Command
        | Set_Motor_Config_Command .. Set_GPS_Rescue_PIDs_Command);

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old);

end Adaflight.MSP_Hardware_In;
