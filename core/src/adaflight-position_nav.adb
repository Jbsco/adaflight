with Adaflight.Maths;

package body Adaflight.Position_Nav with SPARK_Mode is

   Slew_Error_Floor_M : constant := 5.0e-7;
   Slew_Decel_Ceiling : constant := 2.0 ** 100;
   Want_Floor_Mps     : constant := 1.0e-10;

   function Sq (X : Float) return Float is (X * X)
     with Pre => abs X <= 2.0 ** 62;

   function Sqrt (X : Float) return Float is (Adaflight.Maths.Sqrt_Non_Negative (X))
     with Pre => X >= 0.0;

   function Clamped (X : Float) return Rate_Mps is (Float'Max (-Rate_Bound, Float'Min (Rate_Bound, X)));
   function Clamped_Ramp (X : Float) return Ramp_Rate_Mps is
     (Float'Max (-Ramp_Rate_Bound, Float'Min (Ramp_Rate_Bound, X)));
   Dist_Bound : constant := 2.0 ** 20;
   function Clamped_M (X : Float) return Metres is (Float'Max (-Metres_Bound, Float'Min (Metres_Bound, X)));

   procedure Reset (N : in out Navigator) is
      Sequence : constant Unsigned_32 := N.Cmd.Sequence;
   begin
      N.Cmd := (others => <>);
      N.Cmd.Sequence := Sequence;
      N.Previous_Vel := (others => <>);
      N.Previous_Valid := False;
      N.Target_Vel := (others => <>);
      N.Within_Radius := False;
      N.Within_Altitude := False;
   end Reset;

   procedure Set_Target (N : in out Navigator; Target : Position_M; Cruise_Speed : Speed_Mps;
                         Acceptance_Radius : Acceptance_M; Completion_Speed : Speed_Mps; Include_Altitude : Boolean) is
      Hand_Over : constant Boolean := N.Cmd.Active;
   begin
      N.Cmd.Active := True;
      N.Cmd.Sequence := N.Cmd.Sequence + 1;
      N.Cmd.Completed := False;
      N.Cmd.Completion_Signalled := False;
      N.Cmd.Target := Target;
      N.Cmd.Fixed_Target := True;
      N.Cmd.Include_Altitude := Include_Altitude;
      N.Cmd.Cruise_Speed := Cruise_Speed;
      N.Cmd.Vert_Rate := 0.0;
      N.Cmd.Ramp_Alt := 0.0;
      N.Cmd.Ramp_Valid := False;
      N.Cmd.Ramp_Rate := Clamped_Ramp (N.Target_Vel.Up * 0.01);
      N.Cmd.Ramp_Rate_Slewed := Hand_Over;
      N.Cmd.Approach_Decel := 0.0;
      N.Cmd.Approach_Still_Radius := 0.0;
      N.Cmd.Approach_Still := False;
      N.Cmd.Velocity_FF_Valid := False;
      N.Cmd.Velocity_From_Craft := False;
      N.Cmd.Acceptance_Radius := Acceptance_Radius;
      N.Cmd.Completion_Speed := Completion_Speed;
      N.Cmd.Settle_Timeout := 0.0;
      N.Cmd.Settle := 0.0;
      N.Cmd.Max_Angle := 0.0;
      N.Cmd.Altitude_Arrival_Required := True;
      N.Previous_Vel.East := N.Target_Vel.East * 0.01;
      N.Previous_Vel.North := N.Target_Vel.North * 0.01;
      N.Previous_Vel.Up := 0.0;
      N.Previous_Valid := Hand_Over;
      N.Within_Radius := False;
      N.Within_Altitude := False;
   end Set_Target;

   procedure Move_Target (N : in out Navigator; Target : Position_M) is
   begin
      if not N.Cmd.Active then
         return;
      end if;
      N.Cmd.Target := Target;
      N.Cmd.Fixed_Target := False;
   end Move_Target;

   procedure Lower_Target_Altitude (N : in out Navigator; Up_M : Metres) is
   begin
      if N.Cmd.Active and then Up_M < N.Cmd.Target.Up then
         N.Cmd.Target.Up := Up_M;
      end if;
   end Lower_Target_Altitude;

   procedure Clear_Target (N : in out Navigator) is
   begin
      N.Cmd.Active := False;
      N.Cmd.Completed := False;
      N.Cmd.Completion_Signalled := False;
      N.Target_Vel := (others => <>);
      N.Previous_Vel := (others => <>);
      N.Previous_Valid := False;
      N.Within_Radius := False;
      N.Within_Altitude := False;
   end Clear_Target;

   --  The leg's vertical rate: stated, or the cruise speed.
   function Leg_Vert_Rate (C : Command) return Speed_Mps is
     (if C.Vert_Rate > 0.0 then C.Vert_Rate else C.Cruise_Speed);

   --  The signed rate the altitude ramp moves at: the leg's rate, braked
   --  into the leg altitude.
   function Vertical_Ramp_Rate (C : Command) return Ramp_Rate_Mps is
      Error_M : constant Float := C.Target.Up - C.Ramp_Alt;
      Rate    : constant Float :=
        Float'Min (Leg_Vert_Rate (C), Sqrt (2.0 * Vert_Ramp_Decel_Mps2 * abs Error_M));
   begin
      return (if Error_M < 0.0 then -Rate else Rate);
   end Vertical_Ramp_Rate;

   --  A ramp taking over from a leg still moving the altitude target slews
   --  out of that leg's rate at the brake deceleration, or harder where that
   --  would carry it through the leg altitude.
   function Slewed_Vertical_Ramp_Rate (C : Command; Dt : Seconds) return Ramp_Rate_Mps is
      Rate : constant Ramp_Rate_Mps := Vertical_Ramp_Rate (C);
   begin
      if not C.Ramp_Rate_Slewed then
         return Rate;
      end if;
      declare
         Error_M : constant Float := C.Target.Up - C.Ramp_Alt;
         Decel   : Float := Vert_Ramp_Decel_Mps2;
         Step    : Float;
         Low     : Float;
         High    : Float;
      begin
         if C.Ramp_Rate * Error_M > 0.0 then
            if abs Error_M >= Slew_Error_Floor_M then
               Decel := Float'Max (Decel, Sq (C.Ramp_Rate) / (2.0 * abs Error_M));
            else
               Decel := Slew_Decel_Ceiling;
            end if;
         end if;
         Step := Decel * Dt;
         Low := C.Ramp_Rate - Step;
         High := C.Ramp_Rate + Step;
         if Rate < Low then
            return Clamped_Ramp (Low);
         elsif Rate > High then
            return Clamped_Ramp (High);
         else
            return Rate;
         end if;
      end;
   end Slewed_Vertical_Ramp_Rate;

   procedure Set_Vertical_Profile (N : in out Navigator; Rate : Stated_Speed_Mps; Start_Alt_M : Metres) is
   begin
      if not N.Cmd.Active then
         return;
      end if;
      N.Cmd.Vert_Rate := Rate;
      N.Cmd.Ramp_Alt := Start_Alt_M;
      N.Cmd.Ramp_Valid := True;
      if not N.Cmd.Ramp_Rate_Slewed then
         N.Cmd.Ramp_Rate := Vertical_Ramp_Rate (N.Cmd);
      end if;
      N.Target_Vel.Up := (if N.Cmd.Include_Altitude then N.Cmd.Ramp_Rate * 100.0 else 0.0);
   end Set_Vertical_Profile;

   procedure Set_Accel_Limits (N : in out Navigator; Max_Accel, Max_Decel : Accel_Mps2) is
   begin
      N.Cmd.Max_Accel := Max_Accel;
      N.Cmd.Max_Decel := Max_Decel;
   end Set_Accel_Limits;

   procedure Set_Velocity_Feedforward (N : in out Navigator; Vel : Velocity_M) is
   begin
      if not N.Cmd.Active then
         return;
      end if;
      N.Cmd.Velocity_FF_Valid := True;
      N.Cmd.Velocity_FF := Vel;
   end Set_Velocity_Feedforward;

   procedure Start_Afresh (N : in out Navigator) is
   begin
      N.Previous_Valid := False;
   end Start_Afresh;

   procedure Set_Approach_Brake (N : in out Navigator; Decel : Accel_Mps2; Still_Radius : Radius_M) is
   begin
      N.Cmd.Approach_Decel := Decel;
      N.Cmd.Approach_Still_Radius := Still_Radius;
      N.Cmd.Approach_Still := False;
   end Set_Approach_Brake;

   function Approach_Speed (Cruise_Speed : Speed_Mps; Decel : Accel_Mps2; Still_Radius : Radius_M;
                            Dist : Float) return Float is
      Gap_M  : constant Float := Float'Max (Dist - Still_Radius, 0.0);
      Knee_M : constant Float := Decel / Sq (Position_Gain);
      Speed  : constant Float :=
        (if Gap_M <= Knee_M then Position_Gain * Gap_M else Sqrt (Decel * (2.0 * Gap_M - Knee_M)));
   begin
      return Float'Min (Cruise_Speed, Speed);
   end Approach_Speed;

   procedure Set_Altitude_Arrival_Required (N : in out Navigator; Required : Boolean) is
   begin
      N.Cmd.Altitude_Arrival_Required := Required;
   end Set_Altitude_Arrival_Required;

   procedure Set_Settle_Timeout (N : in out Navigator; Timeout : Seconds) is
   begin
      N.Cmd.Settle_Timeout := Timeout;
   end Set_Settle_Timeout;

   procedure Set_Max_Angle (N : in out Navigator; Angle : Angle_Deg) is
   begin
      N.Cmd.Max_Angle := Angle;
   end Set_Max_Angle;

   procedure Set_Auto_Clear_On_Reach (N : in out Navigator; Auto_Clear : Boolean) is
   begin
      N.Cmd.Auto_Clear_On_Reach := Auto_Clear;
   end Set_Auto_Clear_On_Reach;

   --  The commanded altitude marched toward the leg altitude at the leg's
   --  rate, held within a leash of the craft; returns the rate.
   procedure Update_Vertical_Ramp (C : in out Command; Dt : Seconds; Pos_Up_M : Float; Rate : out Ramp_Rate_Mps)
     with Pre => abs Pos_Up_M <= Metres_Bound and then (Dt = 0.0 or else Dt >= 1.0e-4)
   is
   begin
      if not C.Ramp_Valid then
         C.Ramp_Alt := Pos_Up_M;
         C.Ramp_Valid := True;
      end if;
      C.Ramp_Rate := Slewed_Vertical_Ramp_Rate (C, Dt);
      if Dt > 0.0 then
         declare
            Target_Alt_M   : constant Metres := C.Target.Up;
            Ramp_Before_M  : constant Metres := C.Ramp_Alt;
            Error_Before_M : constant Float := Target_Alt_M - Ramp_Before_M;
            Alt            : Float := Ramp_Before_M + C.Ramp_Rate * Dt;
            Leash_M        : constant Float := Float'Max (Vert_Ramp_Leash_Min_M, Leg_Vert_Rate (C) * Vert_Ramp_Leash_S);
            Walk_M         : constant Float := Leg_Vert_Rate (C) * Dt;
         begin
            if (Error_Before_M >= 0.0 and then Alt > Target_Alt_M)
              or else (Error_Before_M <= 0.0 and then Alt < Target_Alt_M)
            then
               Alt := Target_Alt_M;
               C.Ramp_Rate := Clamped_Ramp (Error_Before_M / Dt);
            end if;
            if Alt > Pos_Up_M + Leash_M then
               Alt := Float'Max (Pos_Up_M + Leash_M, Float'Min (Alt, Ramp_Before_M) - Walk_M);
            elsif Alt < Pos_Up_M - Leash_M then
               Alt := Float'Min (Pos_Up_M - Leash_M, Float'Max (Alt, Ramp_Before_M) + Walk_M);
            end if;
            C.Ramp_Alt := Clamped_M (Alt);
         end;
      end if;
      Rate := C.Ramp_Rate;
   end Update_Vertical_Ramp;

   procedure Update (N : in out Navigator; Dt : Seconds; Est : Estimate; Reached : out Boolean) is
      Pos_East_M  : constant Float := Est.Position.East * 0.01;
      Pos_North_M : constant Float := Est.Position.North * 0.01;
      Pos_Up_M    : constant Float := Est.Position.Up * 0.01;
      Ramp_Rate   : Ramp_Rate_Mps;
   begin
      Reached := False;
      if not N.Cmd.Active then
         N.Target_Vel := (others => <>);
         return;
      end if;
      if N.Cmd.Completed then
         N.Target_Vel := (others => <>);
         if N.Cmd.Include_Altitude then
            Update_Vertical_Ramp (N.Cmd, Dt, Pos_Up_M, Ramp_Rate);
            N.Target_Vel.Up := Ramp_Rate * 100.0;
         end if;
         return;
      end if;
      if N.Cmd.Velocity_FF_Valid then
         N.Cmd.Target.East := Clamped_M (N.Cmd.Target.East + N.Cmd.Velocity_FF.East * Dt);
         N.Cmd.Target.North := Clamped_M (N.Cmd.Target.North + N.Cmd.Velocity_FF.North * Dt);
      end if;
      declare
         Error_East_M  : constant Float := N.Cmd.Target.East - Pos_East_M;
         Error_North_M : constant Float := N.Cmd.Target.North - Pos_North_M;
         Horiz_Dist_M  : constant Float := Float'Min (Sqrt (Sq (Error_East_M) + Sq (Error_North_M)), Dist_Bound);
         Target_Vel    : Velocity_3_Mps;
      begin
         if N.Cmd.Velocity_FF_Valid then
            Target_Vel.East := N.Cmd.Velocity_FF.East;
            Target_Vel.North := N.Cmd.Velocity_FF.North;
         else
            declare
               Desired_Speed : Float := Float'Min (N.Cmd.Cruise_Speed, Position_Gain * Horiz_Dist_M);
            begin
               if N.Cmd.Approach_Decel > 0.0 then
                  if Horiz_Dist_M <= N.Cmd.Approach_Still_Radius then
                     N.Cmd.Approach_Still := True;
                  end if;
                  Desired_Speed :=
                    (if N.Cmd.Approach_Still then 0.0
                     else Approach_Speed (N.Cmd.Cruise_Speed, N.Cmd.Approach_Decel, N.Cmd.Approach_Still_Radius,
                                          Horiz_Dist_M));
               end if;
               if N.Cmd.Max_Decel > 0.0 then
                  Desired_Speed := Float'Min (Desired_Speed, Sqrt (2.0 * N.Cmd.Max_Decel * Horiz_Dist_M));
               end if;
               if Horiz_Dist_M > Min_Distance_M then
                  Target_Vel.East := Clamped (Error_East_M / Horiz_Dist_M * Desired_Speed);
                  Target_Vel.North := Clamped (Error_North_M / Horiz_Dist_M * Desired_Speed);
               end if;
            end;
            if not N.Previous_Valid then
               N.Previous_Vel := (others => <>);
               declare
                  Want_Mps : constant Float := Sqrt (Sq (Target_Vel.East) + Sq (Target_Vel.North));
               begin
                  if Want_Mps >= Want_Floor_Mps then
                     declare
                        Toward_Mps : constant Float :=
                          (Est.Velocity.East * Target_Vel.East + Est.Velocity.North * Target_Vel.North) * 0.01
                          / Want_Mps;
                        Ratio      : constant Float := Float'Max (0.0, Float'Min (Toward_Mps, Want_Mps)) / Want_Mps;
                     begin
                        N.Previous_Vel.East := Clamped (Target_Vel.East * Ratio);
                        N.Previous_Vel.North := Clamped (Target_Vel.North * Ratio);
                        N.Previous_Vel.Up := 0.0;
                     end;
                  end if;
               end;
            end if;
            if N.Cmd.Max_Accel > 0.0 and then Dt > 0.0 then
               declare
                  Delta_East  : Float := Target_Vel.East - N.Previous_Vel.East;
                  Delta_North : Float := Target_Vel.North - N.Previous_Vel.North;
                  Delta_Up    : Float := Target_Vel.Up - N.Previous_Vel.Up;
                  Delta_Mag   : constant Float := Sqrt (Sq (Delta_East) + Sq (Delta_North) + Sq (Delta_Up));
                  Max_Delta   : constant Float := N.Cmd.Max_Accel * Dt;
               begin
                  if Delta_Mag > Max_Delta and then Delta_Mag > 0.0 then
                     declare
                        Ratio : constant Float := Float'Min (1.0, Max_Delta / Delta_Mag);
                     begin
                        Delta_East := Delta_East * Ratio;
                        Delta_North := Delta_North * Ratio;
                        Delta_Up := Delta_Up * Ratio;
                     end;
                  end if;
                  Target_Vel.East := Clamped (N.Previous_Vel.East + Delta_East);
                  Target_Vel.North := Clamped (N.Previous_Vel.North + Delta_North);
                  Target_Vel.Up := Clamped (N.Previous_Vel.Up + Delta_Up);
               end;
            end if;
         end if;
         if not N.Previous_Valid then
            N.Cmd.Velocity_From_Craft := N.Cmd.Velocity_FF_Valid or else N.Cmd.Max_Accel > 0.0;
         end if;
         N.Previous_Vel := Target_Vel;
         N.Previous_Valid := True;
         if N.Cmd.Include_Altitude then
            Update_Vertical_Ramp (N.Cmd, Dt, Pos_Up_M, Ramp_Rate);
            Target_Vel.Up := Ramp_Rate;
         end if;
         N.Target_Vel := (East => Target_Vel.East * 100.0, North => Target_Vel.North * 100.0,
                          Up => Target_Vel.Up * 100.0);
         declare
            Horiz_Speed_Mps : constant Float := Sqrt (Sq (Est.Velocity.East) + Sq (Est.Velocity.North)) * 0.01;
            Abs_Vz_Mps      : constant Float := abs (Est.Velocity.Up * 0.01);
            Abs_Err_Z_M     : constant Float := abs (N.Cmd.Target.Up - Pos_Up_M);
            Horiz_Speed_Ok  : Boolean;
            Vert_Speed_Ok   : Boolean;
            Altitude_Ok     : Boolean;
            In_Place        : Boolean;
            Slow_Enough     : Boolean;
            Settle_Timed    : Boolean;
         begin
            if not N.Within_Radius then
               if Horiz_Dist_M <= N.Cmd.Acceptance_Radius then
                  N.Within_Radius := True;
               end if;
            else
               if Horiz_Dist_M > N.Cmd.Acceptance_Radius * Hysteresis_Factor then
                  N.Within_Radius := False;
               end if;
            end if;
            if N.Cmd.Include_Altitude then
               if not N.Within_Altitude then
                  if Abs_Err_Z_M <= Vert_Acceptance_M then
                     N.Within_Altitude := True;
                  end if;
               else
                  if Abs_Err_Z_M > Vert_Acceptance_M * Hysteresis_Factor then
                     N.Within_Altitude := False;
                  end if;
               end if;
            else
               N.Within_Altitude := True;
            end if;
            Horiz_Speed_Ok := Horiz_Speed_Mps <= N.Cmd.Completion_Speed;
            Vert_Speed_Ok := not N.Cmd.Include_Altitude or else Abs_Vz_Mps <= N.Cmd.Completion_Speed;
            Altitude_Ok := N.Within_Altitude or else not N.Cmd.Altitude_Arrival_Required;
            In_Place := N.Within_Radius and then Altitude_Ok;
            Slow_Enough := Horiz_Speed_Ok and then Vert_Speed_Ok;
            N.Cmd.Settle :=
              (if In_Place and then not Slow_Enough then Float'Min (N.Cmd.Settle + Dt, Settle_Seconds'Last) else 0.0);
            Settle_Timed := N.Cmd.Settle_Timeout > 0.0 and then N.Cmd.Settle >= N.Cmd.Settle_Timeout;
            if In_Place and then (Slow_Enough or else Settle_Timed) and then not N.Cmd.Completion_Signalled then
               N.Cmd.Completed := True;
               N.Cmd.Completion_Signalled := True;
               Reached := True;
            end if;
         end;
      end;
   end Update;

   procedure Finish_Leg (N : in out Navigator) is
   begin
      N.Target_Vel.East := 0.0;
      N.Target_Vel.North := 0.0;
      if N.Cmd.Auto_Clear_On_Reach then
         Clear_Target (N);
      end if;
   end Finish_Leg;

   function Vertical_Rate_Limit_Cm_S (N : Navigator) return Float is
     (if N.Cmd.Active then Float'Max (Leg_Vert_Rate (N.Cmd), abs N.Cmd.Ramp_Rate) * 100.0 else 0.0);

end Adaflight.Position_Nav;
