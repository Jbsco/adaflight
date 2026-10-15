--  The MSP in messages that write a name or a text, the LED strip's
--  brightness and rainbow, and a battery profile. A request reads zero past
--  its end. A text type outside the named ones, a battery profile request
--  shorter than its thirteen bytes, a profile past the three, cell voltages
--  out of order, or a field outside its setting's range is an error that
--  writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Text_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Name_Command             : constant := 11;
   Set_Text_Command             : constant := 16#3007#;
   Set_LED_Strip_Values_Command : constant := 16#3009#;
   Set_Battery_Profile_Command  : constant := 16#300F#;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Name_Command | Set_Text_Command | Set_LED_Strip_Values_Command | Set_Battery_Profile_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the OSD's active elements analyzed
   --  again after a craft or pilot name changes.
   type Effects is record
      OSD_Elements : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The current PID, rate and battery profiles are within their lists.
   function Profiles_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < C.Pid_Profiles'Length
      and then Natural (C.System_Config.Active_Rate_Profile) < C.Control_Rate_Profiles'Length
      and then Natural (C.System_Config.Active_Battery_Profile) < C.Battery_Profiles'Length);

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_Text_In;
