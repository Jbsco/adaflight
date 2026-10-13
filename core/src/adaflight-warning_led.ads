--  The warning LED: off, on, or flashing with a toggle every 500 ms. A
--  refresh drives the LED at once and sets the next refresh 500 ms later; an
--  update refreshes once that time has come, by the wrapping difference.
with Interfaces;

package Adaflight.Warning_LED with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Mode is (Off, On, Flashing);
   type LED_Call is (None, Set_Off, Set_On, Toggle);

   type State is record
      Current : Mode := Off;
      Next_Us : Unsigned_32 := 0;
   end record;

   procedure Enable (S : in out State) with Post => S.Current = On and then S.Next_Us = S.Next_Us'Old;
   procedure Disable (S : in out State) with Post => S.Current = Off and then S.Next_Us = S.Next_Us'Old;
   procedure Flash (S : in out State) with Post => S.Current = Flashing and then S.Next_Us = S.Next_Us'Old;

   procedure Refresh (S : in out State; Now_Us : Unsigned_32; Call : out LED_Call)
     with Post => S.Current = S.Current'Old and then S.Next_Us = Now_Us + 500_000
                  and then Call = (case S.Current is
                                      when Off => Set_Off, when On => Set_On, when Flashing => Toggle);

   procedure Update (S : in out State; Now_Us : Unsigned_32; Call : out LED_Call)
     with Post => S.Current = S.Current'Old;

end Adaflight.Warning_LED;
