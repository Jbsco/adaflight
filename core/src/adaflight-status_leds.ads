--  The three status LEDs. Each has a pin tag from the stored configuration,
--  or none, and an inversion bit; an LED is on at a low pin level unless its
--  bit is set. A start claims each pin there is, makes it an output and
--  writes its off level. A set writes a level and a toggle toggles the pin.
--  An index outside the three, or an LED without a pin, gives no operation.
with Interfaces;

package Adaflight.Status_LEDs with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;

   LED_Count : constant := 3;
   subtype LED_Index is Natural range 0 .. LED_Count - 1;
   type Tag_List is array (LED_Index) of Unsigned_8;

   type State is record
      Tags      : Tag_List := (others => 0);
      Inversion : Unsigned_8 := 0;
   end record;

   --  A pin operation: a claim with its resource index from one, an output
   --  set-up, a level written, or a toggle.
   type Op_Kind is (Nothing, Claim, Set_Output, Write_Level, Toggle_Pin);
   type Op is record
      Kind  : Op_Kind := Nothing;
      Tag   : Unsigned_8 := 0;
      Index : Natural range 0 .. LED_Count := 0;
      High  : Boolean := False;
   end record;

   Max_Ops : constant := 3 * LED_Count;
   type Op_List is array (1 .. Max_Ops) of Op;
   type Ops is record
      Count : Natural range 0 .. Max_Ops := 0;
      List  : Op_List;
   end record;

   --  The pin level that turns an LED on or off.
   function Level (S : State; LED : LED_Index; On : Boolean) return Boolean is
     (if (S.Inversion and Interfaces.Shift_Left (1, LED)) /= 0 then On else not On);

   procedure Init (S : out State; Tags : Tag_List; Inversion : Unsigned_8; O : out Ops)
     with Post => S.Tags = Tags and then S.Inversion = Inversion;

   function Set (S : State; LED : Integer; On : Boolean) return Op
     with Post => Set'Result.Kind in Nothing | Write_Level
                  and then (Set'Result.Kind = Write_Level) = (LED in LED_Index and then S.Tags (LED) /= 0);

   function Toggle (S : State; LED : Integer) return Op
     with Post => Toggle'Result.Kind in Nothing | Toggle_Pin
                  and then (Toggle'Result.Kind = Toggle_Pin) = (LED in LED_Index and then S.Tags (LED) /= 0);

end Adaflight.Status_LEDs;
