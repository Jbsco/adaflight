package body Adaflight.Passthrough_Escape
  with SPARK_Mode
is

   procedure Host_Byte
     (S : in out State; C : Interfaces.Unsigned_8; Now_Ms : Interfaces.Unsigned_32; Reset : out Boolean)
   is
   begin
      Reset := False;
      if not S.Enabled then
         return;
      end if;
      if C = Character'Pos ('+') and then (S.Count > 0 or else Now_Ms - S.Host_Idle_Ms >= 1_000) then
         if S.Count = Plus_Count'Last then
            Reset := True;
         else
            S.Count := S.Count + 1;
         end if;
      else
         S.Count := 0;
      end if;
      S.Host_Idle_Ms := Now_Ms;
   end Host_Byte;

end Adaflight.Passthrough_Escape;
