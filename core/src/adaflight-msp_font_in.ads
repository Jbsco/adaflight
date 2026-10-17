--  The MSP in message that writes an OSD font character: an 8 or 16 bit
--  address and the character's 54 visible bytes or its full 64, by the
--  request's length. A request reads zero past its end. Without an OSD
--  display port the message is an error.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.MSP_Write_Plans;

package Adaflight.MSP_Font_In with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   Write_Character_Command : constant := 87;

   function Handles (Command : Interfaces.Unsigned_16) return Boolean is (Command = Write_Character_Command);

   type Result is (Ack, Error);

   Visible_Bytes   : constant := 54;
   Character_Bytes : constant := 64;
   subtype Character_Size is Natural range 0 .. Character_Bytes;
   type Character_Data is array (0 .. Character_Bytes - 1) of Byte;

   --  The character handed to the display port: its address, the bytes the
   --  request gave, and zero past them. The port's answer decides the
   --  message's result, and a character it takes marks the font updated for
   --  the next restart.
   type Effects is record
      Write   : Boolean := False;
      Address : Interfaces.Unsigned_16 := 0;
      Size    : Character_Size := 0;
      Data    : Character_Data := (others => 0);
   end record;

   No_Effects : constant Effects := (Write => False, Address => 0, Size => 0, Data => (others => 0));

   Max_Request : constant := MSP_Write_Plans.Max_Request;

   procedure Process (Request : Byte_Array; Port_Present : Boolean; R : out Result; E : out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then E = No_Effects);

end Adaflight.MSP_Font_In;
