--  A motor table as steps that do nothing, the shape the blocking DShot
--  command's proof takes.
with Interfaces;
with Adaflight.DShot_Command;

package Adaflight.DShot_Table_Steps with SPARK_Mode is

   type Table is null record;

   procedure Step_Delay_Us (T : in out Table; Us : Interfaces.Unsigned_32)
     with Global => null;

   procedure Step_Decode (T : in out Table)
     with Global => null;

   procedure Step_Request (T : in out Table; Index : Adaflight.DShot_Command.Motor_Index)
     with Global => null;

   procedure Step_Write
     (T : in out Table; Q : Adaflight.DShot_Command.Queue; Index : Adaflight.DShot_Command.Motor_Index;
      Value : Interfaces.Unsigned_16)
     with Global => null;

   procedure Step_Complete (T : in out Table; Q : in out Adaflight.DShot_Command.Queue)
     with Global => null;

end Adaflight.DShot_Table_Steps;
