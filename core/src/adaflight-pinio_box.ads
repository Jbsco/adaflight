--  The PINIO boxes: each of the four PINIO outputs follows the state of the
--  box that its setting names by permanent id. An unknown or unset id leaves
--  its output alone. The task runs while any assigned box has a mode
--  condition.
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Modes;

package Adaflight.PINIO_Box with SPARK_Mode is

   PINIO_Count : constant := 4;
   subtype PINIO_Index is Natural range 0 .. PINIO_Count - 1;
   type Permanent_Ids is array (PINIO_Index) of Byte;

   type Assignment is record
      Assigned : Boolean := False;
      Which    : Adaflight.Modes.Box := Adaflight.Modes.Box'First;
   end record;
   type State is array (PINIO_Index) of Assignment;

   type Box_Flags is array (Adaflight.Modes.Box) of Boolean;

   --  Whether an output is set this update, and to which level.
   type Output_Set is record
      Set   : Boolean := False;
      Level : Boolean := False;
   end record;
   type Output_Sets is array (PINIO_Index) of Output_Set;

   procedure Init (S : out State; Ids : Permanent_Ids);

   --  The outputs of the assigned boxes, in index order, from the boxes'
   --  states.
   function Update (S : State; On : Box_Flags) return Output_Sets
     with Post => (for all I in PINIO_Index =>
                     Update'Result (I).Set = S (I).Assigned
                     and then (if S (I).Assigned then Update'Result (I).Level = On (S (I).Which)));

   function Task_Enabled (S : State; Present : Box_Flags) return Boolean is
     (for some I in PINIO_Index => S (I).Assigned and then Present (S (I).Which));

end Adaflight.PINIO_Box;
