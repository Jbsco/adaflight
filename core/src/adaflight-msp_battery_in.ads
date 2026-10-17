--  The MSP in messages that write the battery's configuration: the voltage
--  meter's scale and divider, the current meters' scale and offset, and the
--  battery's cell voltages, capacity and meter sources, the voltages and the
--  capacity to the current battery profile. A request reads zero past its
--  end. A request with a field outside its setting's range, or with cell
--  voltages out of order, is an error that writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Battery_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Battery_Config_Command       : constant := 33;
   Set_Current_Meter_Config_Command : constant := 41;
   Set_Voltage_Meter_Config_Command : constant := 57;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Battery_Config_Command | Set_Current_Meter_Config_Command
        | Set_Voltage_Meter_Config_Command);

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   function Battery_Profile_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Active_Battery_Profile) < C.Battery_Profiles'Length);

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
     with Pre  => Handles (Command) and then Battery_Profile_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old);

end Adaflight.MSP_Battery_In;
