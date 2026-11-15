package body Adaflight.Status_LEDs with SPARK_Mode is

   procedure Init (S : out State; Tags : Tag_List; Inversion : Unsigned_8; O : out Ops) is
   begin
      S := (Tags => Tags, Inversion => Inversion);
      O := (Count => 0, List => (others => <>));
      for I in LED_Index loop
         if Tags (I) /= 0 then
            O.List (O.Count + 1) := (Kind => Claim, Tag => Tags (I), Index => I + 1, High => False);
            O.List (O.Count + 2) := (Kind => Set_Output, Tag => Tags (I), Index => 0, High => False);
            O.List (O.Count + 3) := (Kind => Write_Level, Tag => Tags (I), Index => 0, High => Level (S, I, False));
            O.Count := O.Count + 3;
         end if;
         pragma Loop_Invariant (O.Count <= 3 * (I + 1));
      end loop;
   end Init;

   function Set (S : State; LED : Integer; On : Boolean) return Op is
     (if LED in LED_Index and then S.Tags (LED) /= 0
      then (Kind => Write_Level, Tag => S.Tags (LED), Index => 0, High => Level (S, LED, On))
      else (others => <>));

   function Toggle (S : State; LED : Integer) return Op is
     (if LED in LED_Index and then S.Tags (LED) /= 0
      then (Kind => Toggle_Pin, Tag => S.Tags (LED), Index => 0, High => False)
      else (others => <>));

end Adaflight.Status_LEDs;
