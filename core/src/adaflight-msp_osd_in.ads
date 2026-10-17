--  The MSP in messages that write the OSD's configuration and canvas: the
--  general settings with the video system, units, alarms, warnings,
--  profile, stick overlay and camera frame; a timer; an element's position
--  or a statistic's switch; and the canvas size an HD transmitter reports.
--  A request reads zero past its end. A timer past the two, an element past
--  the 99, or a field outside its setting's range is an error that writes
--  and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_OSD_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_OSD_Config_Command : constant := 85;
   Set_OSD_Canvas_Command : constant := 188;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_OSD_Config_Command | Set_OSD_Canvas_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the OSD's active elements analyzed
   --  again after an element's position or a profile selection, the OSD
   --  profile taken up after a profile selection, and the configuration
   --  written with a restart after the canvas switches the board to HD.
   type Effects is record
      OSD_Elements   : Boolean := False;
      Profile_Change : Boolean := False;
      Profile        : Byte := 0;
      Save           : Boolean := False;
      Reboot         : Boolean := False;
   end record;

   No_Effects : constant Effects :=
     (OSD_Elements | Profile_Change | Save | Reboot => False, Profile => 0);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_OSD_In;
