package body Adaflight.Flight_Stats with SPARK_Mode is

   ------------
   -- On_Arm --
   ------------

   procedure On_Arm (S : in out Tracker; Now_Ms : Unsigned_32; Distance_Cm : Unsigned_32) is
   begin
      S.Arm_Ms := Now_Ms;
      S.Arm_Distance_Cm := Distance_Cm;
   end On_Arm;

   ---------------
   -- On_Disarm --
   ---------------

   procedure On_Disarm (S : in out Tracker; C : Settings; T : in out Totals; Now_Ms, Distance_Cm : Unsigned_32;
                        Mah_Drawn : Integer_32; Schedule : out Boolean) is
   begin
      Schedule := False;
      if C.Min_Armed_Time_S >= 0 then
         declare
            Dt_S : constant Unsigned_32 := (Now_Ms - S.Arm_Ms) / 1000;
         begin
            if Dt_S >= Unsigned_32 (C.Min_Armed_Time_S) then
               T.Flights := T.Flights + 1;
               T.Time_S := T.Time_S + Dt_S;
               T.Dist_M := T.Dist_M + (Distance_Cm - S.Arm_Distance_Cm) / 100;
               T.Mah_Used := Unsigned_32'Mod (Mah_Drawn);
               S.Save_Required := True;
            end if;
         end;
         Schedule := S.Save_Required;
      end if;
   end On_Disarm;

   -----------
   -- Write --
   -----------

   procedure Write (S : in out Tracker; C : Settings; Armed, Config_Dirty : Boolean; Roll, Pitch, Yaw : Rate;
                    Action : out Save_Action) is
      Limit : constant Float := Float (C.Save_Move_Limit);
   begin
      Action := Nothing;
      if not Armed then
         if not Config_Dirty then
            if (abs Roll < Limit and then abs Pitch < Limit and then abs Yaw < Limit) or else C.Save_Move_Limit = 0 then
               Action := Save;
            else
               Action := Retry;
            end if;
         end if;
         S.Save_Required := False;
      end if;
   end Write;

end Adaflight.Flight_Stats;
