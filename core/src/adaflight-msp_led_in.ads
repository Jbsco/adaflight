--  The MSP in messages that write the LED strip's colors, one LED's
--  configuration, and a mode color. A request reads zero past its end. A
--  request with a field outside the bounds of the command line's color, led
--  and mode_color commands is an error that writes and changes nothing.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_LED_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Set_LED_Colors_Command           : constant := 47;
   Set_LED_Strip_Config_Command     : constant := 49;
   Set_LED_Strip_Mode_Color_Command : constant := 221;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is
     (Command in Set_LED_Colors_Command | Set_LED_Strip_Config_Command | Set_LED_Strip_Mode_Color_Command);

   type Result is (Ack, Error);

   --  The runtime work a write asks for: the LED strip's layout evaluated
   --  again.
   type Effects is record
      Layout : Boolean := False;
   end record;

   No_Effects : constant Effects := (others => False);

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
     with Pre  => Handles (Command) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = No_Effects);

end Adaflight.MSP_LED_In;
