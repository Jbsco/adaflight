package body Adaflight.Blackbox_Output_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Window_Ms : constant := 100;

   function Low_Half (V : Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (V mod 65_536)));

   procedure Record_Write
     (D : in out Debug.State; S : in out State; Serial : Boolean; Count : Natural; Free : Unsigned_32;
      Now_Ms : Unsigned_32)
   is
      Room    : Unsigned_32 := Free;
      Written : Boolean;
      Elapsed : Unsigned_32;
      Rate    : Unsigned_16;
   begin
      for I in 1 .. Count loop
         S.Bits := S.Bits + 8;
         Written := True;
         if Serial then
            S.Bits := S.Bits + 2;
            Debug.Set (D, Debug.Blackbox_Output, 3, Low_Half (Room));
            if Room = 0 then
               S.Drops := S.Drops + 1;
               Debug.Set (D, Debug.Blackbox_Output, 2, Low_Half (S.Drops));
               Written := False;
            else
               Room := Room - 1;
            end if;
         end if;
         if Written and then Now_Ms > S.Last_Clear_Ms + Window_Ms then
            --  A window of no length arises only where the clock wraps; the
            --  boards' division gives zero there.
            Elapsed := Now_Ms - S.Last_Clear_Ms;
            Rate := (if Elapsed = 0 then 0 else Unsigned_16 ((((S.Bits * 10 + 5) / Elapsed) / 10) mod 65_536));
            Debug.Set (D, Debug.Blackbox_Output, 0, Low_Half (Unsigned_32 (Rate)));
            if Rate > S.Rate_Max then
               S.Rate_Max := Rate;
               Debug.Set (D, Debug.Blackbox_Output, 1, Low_Half (Unsigned_32 (S.Rate_Max)));
            end if;
            S.Last_Clear_Ms := Now_Ms;
            S.Bits := 0;
         end if;
      end loop;
   end Record_Write;

end Adaflight.Blackbox_Output_Debug;
