--  The MSP in messages that write the features in use, the beeper and
--  DShot beacon conditions with the beacon's tone, and the motor output
--  order. A request reads zero past its end. A request with a field outside
--  its range is an error that writes and changes nothing: the features, the
--  beeper conditions and the beacon conditions take the names the command
--  line's feature, beeper and beacon commands know.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Feature_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Set_Feature_Config_Command        : constant := 37;
   Set_Beeper_Config_Command         : constant := 185;
   Set_Motor_Output_Reordering_Command : constant := 16#3002#;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Feature_Config_Command | Set_Beeper_Config_Command | Set_Motor_Output_Reordering_Command);

   --  The feature bits that have names, and the beeper and beacon conditions
   --  their commands can switch.
   Named_Features : constant Interfaces.Unsigned_32 := 16#1A77_F7FF#;
   Beeper_Allowed : constant Interfaces.Unsigned_32 := 16#7F_FFFF#;
   Beacon_Allowed : constant Interfaces.Unsigned_32 := 16#202#;

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old);

end Adaflight.MSP_Feature_In;
