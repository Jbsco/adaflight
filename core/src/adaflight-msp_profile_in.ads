--  The MSP in messages that select a PID, rate or battery profile and copy
--  one PID or rate profile over another. A request reads zero past its end.
--  A profile past its list selects the first; a copy with a profile past its
--  list, or onto itself, changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Profile_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Copy_Profile_Command   : constant := 183;
   Select_Setting_Command : constant := 210;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Copy_Profile_Command | Select_Setting_Command);

   --  The runtime work a selection asks for: the PID profile taken up with
   --  the PID settings, motor output endpoints, mixer profile and a
   --  confirmation beep per profile number; the rate profile taken up with
   --  the stick processing; or the battery profile taken up.
   type Effects is record
      PID_Profile     : Boolean := False;
      Rate_Profile    : Boolean := False;
      Battery_Profile : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   --  A PID profile is selected only while disarmed. Every request succeeds.
   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; Armed : Boolean;
      E : out Effects)
     with Pre => Handles (Command) and then Request'Length <= Max_Request;

end Adaflight.MSP_Profile_In;
