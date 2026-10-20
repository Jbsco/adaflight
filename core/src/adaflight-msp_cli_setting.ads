--  The MSP message of the command line's settings by name. A request reads
--  as text up to its first zero byte. Without an equals sign the text names a
--  setting, without regard to case, and the reply is the setting's name,
--  " = " and its value as the command line prints it; no such setting, or a
--  value the command line cannot name, is an error. With an equals sign the
--  name before it takes the value after it, spaces cut around both, parsed
--  strictly: a number whole and within the setting's range, a lookup value
--  one of the setting's names, an array with exactly its elements, each
--  within its type. A value that does not parse is an error that writes
--  nothing. One that does is written, and the reply is the setting's text,
--  empty where the new value has none.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.CLI_Text;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;
with Adaflight.Serial_Feature_Map;

package Adaflight.MSP_CLI_Setting with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Setting_Command : constant := 16#3010#;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Setting_Command);

   type Result is (Ack, Error);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The reply's text; the longest setting's name, " = " and value fit.
   Max_Reply : constant := 256;
   subtype Reply_Length is Natural range 0 .. Max_Reply;

   type Reply_Text is record
      Length : Reply_Length := 0;
      Text   : String (1 .. Max_Reply) := (others => ' ');
   end record;

   subtype Port_List is CLI_Text.Port_List;

   --  The profiles the configuration selects are among its profiles.
   function Valid_Profiles (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < Pid_Profile_Record_List_4'Length
      and then Natural (C.System_Config.Active_Rate_Profile) < Control_Rate_Config_Record_List_4'Length
      and then Natural (C.System_Config.Active_Battery_Profile) < Battery_Profile_Record_List_3'Length);

   procedure Process (C : in out Configuration; Request : Byte_Array; Ports : Port_List; R : out Result;
                      Reply : out Reply_Text)
     with Pre  => Request'Length <= Max_Request and then Ports'Length <= Serial_Feature_Map.Max_Ports
                  and then Valid_Profiles (C),
          Post => (if R = Error then Reply.Length = 0);

end Adaflight.MSP_CLI_Setting;
