--  The MSP in messages that set the board's information and its signature
--  once, and reset the configuration. A request reads zero past its end.
--  Board information or a signature the board already holds, or board
--  information shorter than its declared name and manufacturer, is an error
--  that writes and changes nothing.
with Interfaces;
with Adaflight.Board_Info;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Board_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Board_Info.State;

   Reset_Config_Command   : constant := 208;
   Set_Board_Info_Command : constant := 248;
   Set_Signature_Command  : constant := 249;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Reset_Config_Command | Set_Board_Info_Command | Set_Signature_Command);

   type Result is (Ack, Error);

   --  The runtime work a message asks for: the configuration written, a
   --  restart after the reply, and the reset's reply byte, whether it reset.
   type Effects is record
      Save        : Boolean := False;
      Reboot      : Boolean := False;
      Reply       : Boolean := False;
      Reply_Value : Byte := 0;
   end record;

   No_Effects : constant Effects := (Save | Reboot | Reply => False, Reply_Value => 0);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  The reset happens only while disarmed.
   procedure Process
     (C : in out Configuration; Board : in out Board_Info.State; Command : Interfaces.Unsigned_16;
      Request : Byte_Array; Armed : Boolean; R : out Result; E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then Board = Board'Old and then E = No_Effects);

end Adaflight.MSP_Board_In;
