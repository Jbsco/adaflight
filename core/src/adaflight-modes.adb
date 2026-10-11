package body Adaflight.Modes with SPARK_Mode is

   Sticky_Boot_Delay_Us : constant Unsigned_32 := 5_000_000;

   ------------------
   -- Range_Active --
   ------------------

   function Range_Active (Aux : Aux_Values; Channel : Aux_Channel; Span : Channel_Range) return Boolean is
      Value : constant Float := Normalized (Aux (Channel));
   begin
      if not Usable (Span) then
         return False;
      end if;
      return (Span.Start_Step = 0 or else Value >= Step_Normalized (Span.Start_Step))
        and then (Span.End_Step = Max_Range_Step or else Value < Step_Normalized (Span.End_Step));
   end Range_Active;

   -------------
   -- Analyze --
   -------------

   procedure Analyze (S : in out State; C : Conditions) is
   begin
      S.Active_Count := 0;
      S.Linked_Count := 0;
      for I in Condition_Index loop
         pragma Loop_Invariant (S.Active_Count + S.Linked_Count <= I);
         if C (I).Linked_To /= Arm then
            S.Linked (S.Linked_Count) := I;
            S.Linked_Count := S.Linked_Count + 1;
         elsif C (I) /= Empty then
            S.Active (S.Active_Count) := I;
            S.Active_Count := S.Active_Count + 1;
         end if;
      end loop;
   end Analyze;

   ------------
   -- Update --
   ------------

   procedure Update (
      S               : in out State;
      C               : Conditions;
      Aux             : Aux_Values;
      Now_Us          : Unsigned_32;
      Airmode_Feature : Boolean
   ) is
      And_Mask : Mask := (others => False);
      New_Mask : Mask := (others => False);
      Sticky   : constant Mask := (Paralyze | Blackbox_Erase => True, others => False);
      Latch    : constant Mask := (Paralyze => True, others => False);

      --  One condition's vote. An any-of box takes the first active range and
      --  latches; an all-of box fails on the first inactive range.
      procedure Vote (Item : Condition; Active : Boolean) is
      begin
         if And_Mask (Item.Mode) or else not New_Mask (Item.Mode) then
            case Item.Combine is
               when Any_Range =>
                  if Active then
                     And_Mask (Item.Mode) := False;
                     New_Mask (Item.Mode) := True;
                  end if;
               when All_Ranges =>
                  And_Mask (Item.Mode) := True;
                  if not Active then
                     New_Mask (Item.Mode) := True;
                  end if;
            end case;
         end if;
      end Vote;

      --  A sticky box stays off until its range has been inactive once after
      --  the boot delay, and a latching box stays on once active.
      procedure Vote_Sticky (Item : Condition; Latch_Forever : Boolean) is
         Active : constant Boolean := Range_Active (Aux, Item.Aux, Item.Span);
      begin
         if Latch_Forever and then S.Active_Mask (Item.Mode) then
            And_Mask (Item.Mode) := False;
            New_Mask (Item.Mode) := True;
            return;
         end if;
         if S.Sticky_Ever_Disabled (Item.Mode) then
            Vote (Item, Active);
         elsif Now_Us >= Sticky_Boot_Delay_Us and then not Active then
            S.Sticky_Ever_Disabled (Item.Mode) := True;
         end if;
      end Vote_Sticky;
   begin
      for I in 0 .. S.Active_Count - 1 loop
         declare
            Item : constant Condition := C (S.Active (I));
         begin
            if Sticky (Item.Mode) then
               Vote_Sticky (Item, Latch (Item.Mode));
            else
               Vote (Item, Range_Active (Aux, Item.Aux, Item.Span));
            end if;
         end;
      end loop;
      for I in 0 .. S.Linked_Count - 1 loop
         declare
            Item : constant Condition := C (S.Linked (I));
         begin
            Vote (Item, And_Mask (Item.Linked_To) /= New_Mask (Item.Linked_To));
         end;
      end loop;
      for B in Box loop
         S.Active_Mask (B) := New_Mask (B) xor And_Mask (B);
      end loop;
      S.Airmode_Enabled := Airmode_Feature or else S.Active_Mask (Airmode);
   end Update;

end Adaflight.Modes;
