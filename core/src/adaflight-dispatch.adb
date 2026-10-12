with Adaflight.Clock;

package body Adaflight.Dispatch with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   ------------
   -- Enable --
   ------------

   procedure Enable (Q : in out Queue) is
   begin
      Q.Enabled := True;
   end Enable;

   ---------
   -- Add --
   ---------

   procedure Add (Q : in out Queue; T : Target; Now_Us : Unsigned_32; Delay_Us : Interfaces.Integer_32) is
      Due      : constant Unsigned_32 :=
        (if Delay_Us < 0 then Now_Us - Unsigned_32 (-(Delay_Us + 1)) - 1 else Now_Us + Unsigned_32 (Delay_Us));
      Position : Count := 0;
   begin
      if Q.In_Queue (T) or else Q.Length = Capacity then
         return;
      end if;
      while Position < Q.Length and then Adaflight.Clock.Elapsed (Q.Due_Us (Q.Queued (Position + 1)), Due) < 0 loop
         pragma Loop_Invariant (Position < Q.Length);
         Position := Position + 1;
      end loop;
      for I in reverse Position + 1 .. Q.Length loop
         Q.Queued (I + 1) := Q.Queued (I);
      end loop;
      Q.Queued (Position + 1) := T;
      Q.Due_Us (T) := Due;
      Q.In_Queue (T) := True;
      Q.Length := Q.Length + 1;
   end Add;

   --------------
   -- Take_Due --
   --------------

   procedure Take_Due (Q : in out Queue; Now_Us : Unsigned_32; T : out Target; Due : out Boolean) is
   begin
      T := 0;
      Due := False;
      if Q.Length = 0 or else Adaflight.Clock.Elapsed (Now_Us, Q.Due_Us (Q.Queued (1))) < 0 then
         return;
      end if;
      T := Q.Queued (1);
      for I in 1 .. Q.Length - 1 loop
         Q.Queued (I) := Q.Queued (I + 1);
      end loop;
      Q.Length := Q.Length - 1;
      Q.In_Queue (T) := False;
      Due := True;
   end Take_Due;

end Adaflight.Dispatch;
