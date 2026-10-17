--  The board's information as the board holds it: its name and
--  manufacturer and whether the stored configuration set them, whether a
--  command changed them, and the same for its signature. It is taken in from
--  the stored configuration as the board starts, stored back when a command
--  or a message sets it, and written back into a reset configuration.
with Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Board_Info with SPARK_Mode is

   --  A name the version line or the board's lines print: up to 32
   --  characters.
   Identity_Max : constant := 32;
   subtype Identity_Length is Natural range 0 .. Identity_Max;
   type Identity_Text is record
      Data   : String (1 .. Identity_Max) := (others => ' ');
      Length : Identity_Length := 0;
   end record;

   function To_Identity (Text : String) return Identity_Text
     with Pre  => Text'Length <= Identity_Max,
          Post => To_Identity'Result.Length = Text'Length;

   type Signature_Bytes is array (0 .. 31) of Interfaces.Unsigned_8;

   Board_Name_Length   : constant := 20;
   Manufacturer_Length : constant := 4;

   type State is record
      Name                : Identity_Text;
      Manufacturer        : Identity_Text;
      Information_Set     : Boolean := False;
      Information_Updated : Boolean := False;
      Signature           : Signature_Bytes := (others => 0);
      Signature_Set       : Boolean := False;
      Signature_Updated   : Boolean := False;
   end record;

   --  The stored board information taken in as the board starts: the name
   --  and the manufacturer when they are set, the signature when it is set.
   procedure Init (Board : in out State; C : Configuration);

   --  The board's name and manufacturer as the board holds them, stored up
   --  to their lengths with the information marked set.
   procedure Store_Information (C : in out Configuration; Board : State);

   --  The board's signature as the board holds it, stored and marked set.
   procedure Store_Signature (C : in out Configuration; Board : State);

   --  The board configuration's reset: a reset configuration keeps the
   --  information and the signature the board has taken in.
   procedure Reset_Config (C : in out Configuration; Board : State);

   --  The board's information as a command set it, stored and taken in
   --  again.
   procedure Persist_Information (C : in out Configuration; Board : in out State);

   --  The board's signature as a command set it, stored and taken in again.
   procedure Persist_Signature (C : in out Configuration; Board : in out State);

end Adaflight.Board_Info;
