package body Adaflight.RC_Stats with SPARK_Mode is

   procedure Update (S : in out Stats; Now_Us : Unsigned_32; Armed, Crash_Flip : Boolean; Percent : Throttle_Percent) is
      Delta_Us : constant Unsigned_32 := Now_Us - S.Previous_Us;
   begin
      S.Previous_Us := Now_Us;
      if Armed and then not Crash_Flip and then not S.Throttle_Raised and then abs Percent >= 15 then
         S.Throttle_Raised := True;
      end if;
      if Armed and then not Crash_Flip and then S.Throttle_Raised then
         S.Count := S.Count + 1;
         S.Total := S.Total + Unsigned_32'Mod (Percent);
         if abs Percent = 100 then
            S.Full_Throttle_Us := S.Full_Throttle_Us + Delta_Us;
            if abs S.Previous_Percent /= 100 then
               S.Full_Throttles := S.Full_Throttles + 1;
            end if;
         end if;
      end if;
      S.Previous_Percent := Percent;
   end Update;

   procedure Notify_Arming (S : in out Stats) is
   begin
      S.Throttle_Raised := False;
   end Notify_Arming;

   function Average_Throttle (S : Stats) return Integer_8 is
      Average : Float;
   begin
      if S.Count = 0 then
         return 0;
      end if;
      Average := Float (S.Total) / Float (S.Count) + 0.5;
      if Average >= 128.0 then
         return Integer_8'Last;
      end if;
      pragma Assert (Average >= 0.0);
      declare
         Whole : constant Float := Float'Truncation (Average);
      begin
         pragma Assert (Whole <= Average);
         pragma Assert (Whole >= 0.0);
         return Integer_8 (Whole);
      end;
   end Average_Throttle;

end Adaflight.RC_Stats;
