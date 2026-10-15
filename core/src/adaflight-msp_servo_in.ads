--  The MSP in messages that write a servo's parameters and a servo mix
--  rule. A request reads zero past its end. A request with a field outside
--  the bounds of the command line's servo and smix commands is an error that
--  writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Servo_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_Servo_Configuration_Command : constant := 212;
   Set_Servo_Mix_Rule_Command      : constant := 242;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_Servo_Configuration_Command | Set_Servo_Mix_Rule_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the servo mixer's rules loaded
   --  again.
   type Effects is record
      Mixer_Load : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_Servo_In;
