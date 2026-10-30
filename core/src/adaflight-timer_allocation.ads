--  The owners of the configured timer map's entries, as the reference holds
--  them. An entry's channel is its pin's tag at the entry's occurrence in the
--  timer table, none for an empty entry or an occurrence past the pin's
--  channels. A pin's first entry answers for the pin. A channel's owner comes
--  from the first entry whose channel it is. An allocation takes the pin's
--  first entry when its channel is free: the entry holds the owner and the
--  ordinal from then on, even when it has no channel, and the channel comes
--  back, none for a pin without an entry, a held channel or an entry without
--  one.
with Interfaces; use Interfaces;
with Adaflight.CLI_Resources;
with Adaflight.Config_Groups;
with Adaflight.Timer_Tables;

package Adaflight.Timer_Allocation with SPARK_Mode is

   use type Config_Groups.Timer_Io_Config_Record_List_21;

   subtype Slot is Natural range 0 .. 20;
   subtype Channel_Index is Natural range 0 .. Timer_Tables.Channels'Last;
   subtype Ordinal_Number is Natural range 0 .. 16;

   type Table is record
      Map    : Config_Groups.Timer_Io_Config_Record_List_21 := (others => (0, 0, 0));
      Owners : CLI_Resources.Timer_Owner_List := (others => <>);
   end record;

   --  The map taken in, every entry free.
   procedure Load (T : out Table; Map : Config_Groups.Timer_Io_Config_Record_List_21)
     with Global => null, Post => T.Map = Map and then (for all S in Slot => not T.Owners (S).Held);

   --  An entry's channel, zero for none.
   function Channel_Of (T : Table; S : Slot) return Channel_Index is
     (Timer_Tables.By_Tag_And_Index (T.Map (S).Io_Tag, Natural (T.Map (S).Index)));

   --  The channel of a pin's first entry, zero without one.
   function Configured_Channel (T : Table; Tag : Unsigned_8) return Channel_Index
     with Global => null;

   --  A channel's owner through the first entry whose channel it is, free
   --  when no entry has it.
   function Channel_Owner (T : Table; K : Positive) return CLI_Resources.Timer_Owner
     with Global => null, Pre => K <= Timer_Tables.Channels'Last;

   --  An allocation: the channel the owner got, zero for none, and the entry
   --  that took the owner, one past the last for none.
   procedure Allocate
     (T : in out Table; Tag : Unsigned_8; Who : CLI_Resources.Owner; Ordinal : Ordinal_Number;
      K : out Channel_Index; S : out Natural)
     with Global => null, Post => S <= Slot'Last + 1;

   --  An entry's DMA option, minus one for none.
   function Option_Of (T : Table; S : Slot) return Integer_8 is (T.Map (S).Dmaopt);

end Adaflight.Timer_Allocation;
