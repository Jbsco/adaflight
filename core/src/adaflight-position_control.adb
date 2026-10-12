with Ada.Numerics.Elementary_Functions;

package body Adaflight.Position_Control with SPARK_Mode is
   use Vectors;

   Distance_Scale           : constant := 0.004;
   Distance_I_Scale         : constant := 0.00017;
   Velocity_Scale           : constant := 0.01;
   Accel_Scale              : constant := 0.0015;
   F_Scale                  : constant := 0.0001;
   Drag_Scale               : constant := 0.0002;
   Yaw_P_Scale              : constant := 0.06;
   Yaw_Ramp_Time_S          : constant := 1.0;
   Braking_Exit_Speed_Min   : constant := 1.0;
   Braking_Timeout_S        : constant := 1.2;
   Sanity_Check_Distance    : constant := 2_000.0;
   Sanity_Violation_Latch_S : constant := 1.0;
   Sanity_Retry_Replenish_S : constant := 10.0;
   Error_Distance_Limit     : constant := 2_000.0;
   Position_I_Limit         : constant := 2_000.0;
   Degrees_To_Radians       : constant Float := 0.0174532925;
   Nominal_Interval_S       : constant Float := 1.0 / Float (Task_Rate_Hz);

   type Step_Result is (Continue, Hold_Previous, Fence_Tripped);

   function Held (V : Float) return Cm is (Constrain_F (V, -Estimate_Bound, Estimate_Bound));

   --  The length of a bounded vector, held at a bound the components cannot
   --  reach, for the provers.
   subtype Length_Cm is Float range 0.0 .. 2.0 ** 27;
   function Length_Of (V : Vector2) return Length_Cm is (Constrain_F (Norm (V), 0.0, 2.0 ** 27))
     with Pre => Bounded (V, 2.0 ** 25);
   function Held_Velocity (V : Float) return Velocity_Cm is (Constrain_F (V, -2.0 ** 26, 2.0 ** 26));
   function Held_Signal (V : Float) return Signal is (Constrain_F (V, -Signal_Bound, Signal_Bound));

   function Sin_Lib (X : Float) return Cosine is
     (Constrain_F (Ada.Numerics.Elementary_Functions.Sin (X), -1.0, 1.0))
     with Pre => abs X <= 100.0;

   function Cos_Lib (X : Float) return Cosine is
     (Constrain_F (Ada.Numerics.Elementary_Functions.Cos (X), -1.0, 1.0))
     with Pre => abs X <= 100.0;

   --  The C remainder: the dividend less the truncated quotient times the
   --  divisor, with the sign of the dividend. Exact for these bounds, so
   --  the correction of a quotient rounded past an integer is exact too.
   function Fmod (X : Float; Y : Float) return Float
     with Pre  => Y in 1.0 .. 1_000.0 and then abs X <= 2.0 ** 20,
          Post => abs Fmod'Result <= Y
   is
      Q : constant Float := Float'Truncation (X / Y);
      R : Float := Constrain_F (X - Q * Y, -Y, Y);
   begin
      if X >= 0.0 and then R < 0.0 then
         R := R + Y;
      elsif X < 0.0 and then R > 0.0 then
         R := R - Y;
      end if;
      return R;
   end Fmod;

   --  The task interval in seconds, the nominal one before a measurement,
   --  held between a quarter and four times the nominal.
   function Interval (Interval_Us : Integer_32) return Interval_S is
      Us : constant Integer_32 := (if Interval_Us <= 0 then Nominal_Interval_Us else Interval_Us);
      Held_Us : constant Integer_32 range Nominal_Interval_Us / 4 .. Nominal_Interval_Us * 4 :=
        Integer_32'Max (Nominal_Interval_Us / 4, Integer_32'Min (Nominal_Interval_Us * 4, Us));
   begin
      return Constrain_F (Float (Held_Us) * 1.0E-6, 0.0025, 0.04);
   end Interval;

   function Lpf_Gain (C : Settings; Dt : Interval_S) return Unit_Interval is
     (Filters.PT3_Gain (Float'Max (Float (C.Position_Cutoff) * 0.1, 0.1), Dt));

   procedure Init_Lpfs (S : in out State; C : Settings) is
      K : constant Unit_Interval := Lpf_Gain (C, Nominal_Interval_S);
   begin
      S.Lpf_Dt_S := Nominal_Interval_S;
      Filters.PT3_Init (S.F_East, K);
      Filters.PT3_Init (S.F_North, K);
   end Init_Lpfs;

   --  The feedforward filters retuned, states kept, when the measured
   --  interval moves by a twentieth.
   procedure Update_Lpf_Gains (S : in out State; C : Settings; Dt : Interval_S) is
   begin
      if abs (Dt - S.Lpf_Dt_S) < 0.05 * S.Lpf_Dt_S then
         return;
      end if;
      S.Lpf_Dt_S := Dt;
      declare
         K : constant Unit_Interval := Lpf_Gain (C, Dt);
      begin
         Filters.PT3_Update_Cutoff (S.F_East, K);
         Filters.PT3_Update_Cutoff (S.F_North, K);
      end;
   end Update_Lpf_Gains;

   procedure Disable_Yaw (S : in out State) is
   begin
      S.Yaw_Active := False;
      S.Yaw_Attenuator := 0.0;
      S.Yaw_Rate_Dps := 0.0;
      S.Hold_Heading_Valid := False;
   end Disable_Yaw;

   procedure Reset_Distance_Error (S : in out State) is
   begin
      S.Distance_Error := (0.0, 0.0);
   end Reset_Distance_Error;

   procedure Reset_Distance_Integral (S : in out State) is
   begin
      S.Distance_Integral := (0.0, 0.0);
   end Reset_Distance_Integral;

   --  The fence: twenty metres, or twice the ground speed past ten metres a
   --  second.
   function Sanity_Distance_Now (Inp : Inputs) return Cm is
     (Held (Float'Max (Sanity_Check_Distance, Length_Of (Inp.Velocity) * 2.0)))
     with Pre => Bounded (Inp);

   --  Braking entered: the exit speed as the configured fraction of the
   --  entry speed, at least a centimetre a second, and the entry direction.
   procedure Set_Braking_Mode (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Bounded (Inp)
   is
      Speed : constant Length_Cm := Length_Of (Inp.Velocity);
   begin
      S.Braking := True;
      S.Braking_Time_S := 0.0;
      S.Braking_Exit_Speed := Held (Float'Max (Braking_Exit_Speed_Min, Speed * Float (C.Stop_Threshold) * 0.01));
      if Speed > Braking_Exit_Speed_Min then
         S.Braking_Entry_Direction := (X => Constrain_F (Inp.Velocity.X / Speed, -1.0, 1.0),
                                       Y => Constrain_F (Inp.Velocity.Y / Speed, -1.0, 1.0));
      else
         S.Braking_Entry_Direction := (0.0, 0.0);
      end if;
   end Set_Braking_Mode;

   procedure Update_Hold_Target (S : in out State; Inp : Inputs)
     with Pre => Bounded (Inp)
   is
   begin
      S.Target_Position := (X => Held (Inp.Position.X), Y => Held (Inp.Position.Y));
      S.Hold_Start := S.Target_Position;
   end Update_Hold_Target;

   ------------------------
   -- Init_Position_Hold --
   ------------------------

   procedure Init_Position_Hold (S : in out State; C : Settings; Inp : Inputs) is
   begin
      Update_Hold_Target (S, Inp);
      Reset_Distance_Error (S);
      Set_Braking_Mode (S, C, Inp);
      S.Target_Velocity := (0.0, 0.0);
      S.Previous_Target := (0.0, 0.0);
   end Init_Position_Hold;

   --------------
   -- Reanchor --
   --------------

   procedure Reanchor (S : in out State; C : Settings; Inp : Inputs) is
   begin
      Init_Position_Hold (S, C, Inp);
      S.Sanity_Distance := Sanity_Distance_Now (Inp);
      S.Sanity_Violation_S := 0.0;
      S.Violation_Free_S := 0.0;
   end Reanchor;

   ----------------------------
   -- Reset_Position_Control --
   ----------------------------

   procedure Reset_Position_Control (S : in out State; C : Settings; Inp : Inputs; Enable_XY : out Boolean) is
   begin
      S.Abort_Requested := False;
      S.Heading_Recovery := False;
      S.Force_Level_Park := False;
      S.Sticks_Active := False;
      S.Was_Sticks_Active := False;
      Disable_Yaw (S);
      S.Yaw_Disable_Reason := 1;
      S.Was_Angle_Saturated := False;
      Enable_XY := True;
      S.Sanity_Distance := Sanity_Distance_Now (Inp);
      S.Sanity_Violation_S := 0.0;
      S.Violation_Free_S := 0.0;
      S.Sanity_Retry_Used := False;
      Init_Position_Hold (S, C, Inp);
      S.Previous_Velocity := (X => Held (Inp.Velocity.X), Y => Held (Inp.Velocity.Y));
      Reset_Distance_Integral (S);
   end Reset_Position_Control;

   procedure Handle_Failure (S : in out State) is
   begin
      Reset_Distance_Error (S);
      Reset_Distance_Integral (S);
   end Handle_Failure;

   --  Full stick commands the configured velocity; the sticks turn from the
   --  body frame into the earth frame by the heading.
   procedure Sticks_Set_Target_Velocity (S : in out State; C : Settings; Inp : Inputs) is
      subtype Stick_Gain is Float range 0.0 .. 5_000.0;
      subtype Stick_Velocity is Float range -2.0 ** 24 .. 2.0 ** 24;
      Gain_Pitch  : constant Stick_Gain := Float (C.Max_Velocity) / Inp.Max_Rate_Pitch;
      Gain_Roll   : constant Stick_Gain := Float (C.Max_Velocity) / Inp.Max_Rate_Roll;
      Stick_Pitch : constant Stick_Velocity := Inp.Setpoint_Pitch * Gain_Pitch;
      Stick_Roll  : constant Stick_Velocity := Inp.Setpoint_Roll * Gain_Roll;
      Heading_Rad : constant Float := Float (Inp.Yaw) / 10.0 * Degrees_To_Radians;
      Cos_Yaw     : constant Cosine := Cos_Lib (Heading_Rad);
      Sin_Yaw     : constant Cosine := Sin_Lib (Heading_Rad);
   begin
      S.Target_Velocity.Y := Held_Velocity ((Stick_Pitch * Cos_Yaw) - (Stick_Roll * Sin_Yaw));
      S.Target_Velocity.X := Held_Velocity ((Stick_Pitch * Sin_Yaw) + (Stick_Roll * Cos_Yaw));
   end Sticks_Set_Target_Velocity;

   -------------------------
   -- Disable_Yaw_Control --
   -------------------------

   procedure Disable_Yaw_Control (S : in out State) is
   begin
      Disable_Yaw (S);
      S.Yaw_Disable_Reason := 3;
   end Disable_Yaw_Control;

   --  The yaw rate toward the rescue's heading, or toward the heading held
   --  since the hold engaged or the pilot last moved the yaw stick, ramped
   --  in over a second and held to the rate limits.
   procedure Update_Yaw_Control (S : in out State; C : Settings; Inp : Inputs; Dt : Interval_S) is
      Heading : constant Float range 0.0 .. 360.0 := Float (Inp.Yaw) * 0.1;
      Desired : Float;
      Error   : Float;
      Rate    : Float;
      Max_Rate : Float range 0.0 .. 1_000.0;
   begin
      if not Inp.Armed then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 4;
         return;
      end if;
      if not Inp.Rescue_Mode and then not (Inp.Pos_Hold_Mode or else Inp.Mag_Mode or else Inp.Autopilot_Mode) then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 5;
         return;
      end if;
      if not Inp.Heading_Valid then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 6;
         return;
      end if;
      if Inp.Rescue_Mode then
         Desired := S.External_Yaw_Target;
         S.Hold_Heading_Valid := False;
      else
         if not S.Hold_Heading_Valid or else abs Inp.Yaw_Command >= Float (C.Stick_Deadband) then
            S.Hold_Heading_Deg := Heading;
            S.Hold_Heading_Valid := True;
         end if;
         Desired := S.Hold_Heading_Deg;
      end if;
      Desired := Fmod (Desired + 360.0, 360.0);
      S.Yaw_Attenuator := Float'Min (S.Yaw_Attenuator + Dt / Yaw_Ramp_Time_S, 1.0);
      Error := Heading - Desired;
      Error := Fmod (Error + 540.0, 360.0) - 180.0;
      Rate := (Error * S.Yaw_Kp) * S.Yaw_Attenuator;
      Max_Rate := Float (C.Max_Yaw_Rate);
      if S.Yaw_Rate_Limit > 0.0 then
         Max_Rate := Float'Min (Max_Rate, S.Yaw_Rate_Limit);
      end if;
      Rate := Constrain_F (Rate, -Max_Rate, Max_Rate);
      S.Yaw_Rate_Dps := Rate * (if C.Yaw_Reversed then -1.0 else 1.0);
      S.Yaw_Active := True;
   end Update_Yaw_Control;

   -------------------------
   -- Update_Heading_Hold --
   -------------------------

   procedure Update_Heading_Hold (S : in out State; C : Settings; Inp : Inputs) is
   begin
      if Inp.Pos_Hold_Mode or else Inp.Rescue_Mode then
         return;
      end if;
      Update_Yaw_Control (S, C, Inp, Interval (Inp.Interval_Us));
   end Update_Heading_Hold;

   --  Entering and leaving the hold and the stick flight: the hold point
   --  taken on the first task, the distance error dropped and the braking
   --  ended when the sticks move, the point recaptured with braking when
   --  they release.
   procedure Process_Transitions (S : in out State; C : Settings; Inp : Inputs)
     with Pre => Bounded (Inp)
   is
   begin
      if not S.Position_Held then
         Init_Position_Hold (S, C, Inp);
         S.Sanity_Distance := Sanity_Distance_Now (Inp);
         S.Position_Held := True;
      end if;
      if S.Sticks_Active then
         if not S.Was_Sticks_Active then
            Reset_Distance_Error (S);
            S.Sanity_Distance := Sanity_Distance_Now (Inp);
            S.Braking := False;
         end if;
      elsif S.Was_Sticks_Active then
         Update_Hold_Target (S, Inp);
         S.Sanity_Distance := Sanity_Distance_Now (Inp);
         Set_Braking_Mode (S, C, Inp);
      end if;
   end Process_Transitions;

   --  A fence violation that outlived its latch: the one re-anchor when it
   --  is available, else a level lean and the failure.
   procedure Sanity_Violation_Expired (S : in out State; C : Settings; Inp : Inputs; Ok : out Boolean)
     with Pre => Bounded (Inp)
   is
   begin
      if not S.Sanity_Retry_Used then
         S.Sanity_Retry_Used := True;
         Reanchor (S, C, Inp);
         Ok := True;
         return;
      end if;
      Disable_Yaw (S);
      S.Yaw_Disable_Reason := 2;
      S.Angle_Roll := 0.0;
      S.Angle_Pitch := 0.0;
      Handle_Failure (S);
      Ok := False;
   end Sanity_Violation_Expired;

   function Add_Seconds (T : Seconds; Dt : Interval_S) return Seconds is (Float'Min (T + Dt, Seconds'Last));

   --  The rescue's velocity: the target walks at it, the fence rides on the
   --  target, the integral accumulates.
   procedure Rescue_Velocity_Update (S : in out State; Inp : Inputs; Dt : Interval_S)
     with Pre => Bounded (Inp)
   is
   begin
      S.Target_Position := (X => Held (S.Target_Position.X + S.Target_Velocity.X * Dt),
                            Y => Held (S.Target_Position.Y + S.Target_Velocity.Y * Dt));
      S.Hold_Start := S.Target_Position;
      S.Anchor := Anchor_Hold;
      S.I_Policy := Accumulate;
   end Rescue_Velocity_Update;

   --  The braking mode: the target dragged to the craft, the integral
   --  frozen, the stop on the exit speed, the timeout or a reversal of the
   --  velocity along the entry direction, and the fence that rides ahead of
   --  a craft still slowing.
   procedure Braking_Update (S : in out State; C : Settings; Inp : Inputs; Dt : Interval_S; Result : out Step_Result)
     with Pre => Bounded (Inp)
   is
      Along : constant Float :=
        (Inp.Velocity.Y * S.Braking_Entry_Direction.Y) + (Inp.Velocity.X * S.Braking_Entry_Direction.X);
   begin
      S.Braking_Time_S := Float'Min (S.Braking_Time_S + Dt, Braking_Timeout_S);
      S.Anchor := Anchor_Hold;
      S.I_Policy := Freeze;
      Sticks_Set_Target_Velocity (S, C, Inp);
      S.Target_Position := (X => Held (Inp.Position.X), Y => Held (Inp.Position.Y));
      if S.Speed_XY < S.Braking_Exit_Speed or else S.Braking_Time_S >= Braking_Timeout_S or else Along < 0.0 then
         Update_Hold_Target (S, Inp);
         S.Braking := False;
         S.Braking_Time_S := 0.0;
         Result := Continue;
         return;
      end if;
      declare
         Brake_Distance : constant Length_Cm :=
           Length_Of (Vector2'(X => S.Hold_Start.X - Inp.Position.X, Y => S.Hold_Start.Y - Inp.Position.Y));
      begin
         if Brake_Distance > S.Sanity_Distance then
            if S.Speed_Slowing then
               S.Sanity_Distance := Held (Brake_Distance + 2.0 * S.Speed_XY);
               S.Sanity_Violation_S := 0.0;
            else
               S.Violation_Free_S := 0.0;
               S.Sanity_Violation_S := Add_Seconds (S.Sanity_Violation_S, Dt);
               if S.Sanity_Violation_S > Sanity_Violation_Latch_S then
                  Result := Fence_Tripped;
                  return;
               end if;
            end if;
         else
            S.Sanity_Violation_S := 0.0;
         end if;
      end;
      Result := Continue;
   end Braking_Update;

   --  The settled hold: anchored to the point, integrating against the
   --  wind, with the fence that holds the previous lean through a brief
   --  excursion and trips on a lasting one; a clean stretch earns the retry
   --  back.
   procedure Settled_Hold_Update (S : in out State; Inp : Inputs; Dt : Interval_S; Result : out Step_Result)
     with Pre => Bounded (Inp)
   is
      Away : constant Length_Cm :=
        Length_Of (Vector2'(X => S.Hold_Start.X - Inp.Position.X, Y => S.Hold_Start.Y - Inp.Position.Y));
   begin
      S.Anchor := Anchor_Hold;
      S.I_Policy := Accumulate;
      if not Inp.Rescue_Mode then
         S.Target_Velocity := (0.0, 0.0);
      end if;
      if Away > S.Sanity_Distance then
         S.Violation_Free_S := 0.0;
         S.Sanity_Violation_S := Add_Seconds (S.Sanity_Violation_S, Dt);
         if S.Sanity_Violation_S > Sanity_Violation_Latch_S then
            Result := Fence_Tripped;
         else
            Result := Hold_Previous;
         end if;
         return;
      end if;
      S.Sanity_Violation_S := 0.0;
      S.Violation_Free_S := Add_Seconds (S.Violation_Free_S, Dt);
      if S.Violation_Free_S > Sanity_Retry_Replenish_S then
         S.Sanity_Retry_Used := False;
      end if;
      Result := Continue;
   end Settled_Hold_Update;

   --  One axis of the control law: the distance error real or virtual,
   --  its integral under the policy, and the five terms.
   procedure Axis_Terms
     (Pid : Gains; I_Policy : Integral_Policy; Was_Angle_Saturated : Boolean;
      Target_Velocity : Velocity_Cm; Previous_Target : in out Velocity_Cm; Distance_Error, Integral : in out Cm;
      Previous_Velocity : out Cm; Position, Velocity, Acceleration : Cm; Dt : Interval_S; Anchor_Off : Boolean;
      Target_Position : Cm; Unfiltered_F : out Angle_Term; Sum_Without_F : out Angle_Term)
     with Post => abs Unfiltered_F <= 2.0 ** 45 and then abs Sum_Without_F <= 2.0 ** 47
   is
      subtype Error_Cm is Float range -Error_Distance_Limit .. Error_Distance_Limit;
      subtype Boost is Float range 1.0 .. 2.0 ** 14;
      subtype Gain_Product is Float range -2.0 ** 30 .. 2.0 ** 30;
      subtype Boosted is Float range -2.0 ** 44 .. 2.0 ** 44;
      subtype Target_Rate is Float range -2.0 ** 36 .. 2.0 ** 36;
      Velocity_Error : constant Velocity_Cm := Held_Velocity (Target_Velocity - Velocity);
      Target_Delta   : constant Target_Rate := (Target_Velocity - Previous_Target) / Dt;
      Brake_Boost    : constant Boost := 1.0 + abs Velocity * 0.0005;
      Damping        : constant Gain_Product := (-Velocity) * Pid.Kd;
      Drag           : constant Gain_Product := Velocity * Pid.K_Drag;
      F_Base         : constant Gain_Product := Target_Velocity * Pid.Kd;
      Delta_F        : constant Boosted := Target_Delta * Pid.Kf;
      P, I, D, A, F  : Angle_Term;
   begin
      Previous_Velocity := Velocity;
      if Anchor_Off then
         if not Was_Angle_Saturated or else (Velocity_Error * Distance_Error) < 0.0 then
            Distance_Error := Held (Distance_Error + Velocity_Error * Dt);
         end if;
      else
         Distance_Error := Held (Target_Position - Position);
      end if;
      Distance_Error := Error_Cm'(Constrain_F (Distance_Error, -Error_Distance_Limit, Error_Distance_Limit));
      case I_Policy is
         when Accumulate =>
            Integral := Held (Integral + Distance_Error * Dt);
         when Zero =>
            Integral := 0.0;
         when Freeze =>
            null;
      end case;
      Integral := Constrain_F (Integral, -Position_I_Limit, Position_I_Limit);
      Previous_Target := Target_Velocity;
      P := Distance_Error * Pid.Kp;
      I := Integral * Pid.Ki;
      D := Boosted'(Damping * Brake_Boost) + Drag;
      A := (-Acceleration) * Pid.Ka;
      F := Boosted'(F_Base * Brake_Boost) + Delta_F;
      Unfiltered_F := F;
      declare
         subtype Small_Term is Float range -2.0 ** 15 .. 2.0 ** 15;
         subtype Partial is Float range -2.0 ** 46 .. 2.0 ** 46;
         PI  : constant Small_Term := P + I;
         PID : constant Partial := PI + D;
      begin
         Sum_Without_F := PID + A;
      end;
   end Axis_Terms;

   --  The two axes' sums turned into the body frame by the heading and held
   --  to the lean limit; a lean past the limit is reported as saturated.
   procedure Lean
     (Base_East, Base_North : Angle_Term; Smoothed_East, Smoothed_North : Signal; Heading : Unit_Vector2;
      Max_Angle : Float; Roll, Pitch : out Float; Saturated : out Boolean)
     with Pre  => Max_Angle in 10.0 .. 70.0,
          Post => abs Roll <= 90.0 and then abs Pitch <= 90.0
   is
      subtype Lean_Sum is Float range -2.0 ** 49 .. 2.0 ** 49;
      subtype Lean_Term is Float range -2.0 ** 51 .. 2.0 ** 51;
      Sum_X   : constant Lean_Sum := Base_East + Smoothed_East;
      Sum_Y   : constant Lean_Sum := Base_North + Smoothed_North;
      Sum     : constant Vector2 := (X => Sum_X, Y => Sum_Y);
      H       : constant Vector2 := (X => Heading.X, Y => Heading.Y);
      Pitch_V : Lean_Term := Constrain_F (Dot (H, Sum), -2.0 ** 51, 2.0 ** 51);
      Roll_V  : Lean_Term := Constrain_F (Cross (H, Sum), -2.0 ** 51, 2.0 ** 51);
      Mag     : constant Float range 0.0 .. 2.0 ** 53 :=
        Constrain_F (Norm (Vector2'(X => Roll_V, Y => Pitch_V)), 0.0, 2.0 ** 53);
   begin
      Saturated := Mag > Max_Angle;
      if Mag > Max_Angle and then Mag > 0.001 then
         declare
            Mag_Safe : constant Float range 0.001 .. 2.0 ** 53 := Mag;
            Scale    : constant Float range 0.0 .. 1.0 := Constrain_F (Max_Angle / Mag_Safe, 0.0, 1.0);
         begin
            Roll_V := Roll_V * Scale;
            Pitch_V := Pitch_V * Scale;
         end;
      end if;
      Roll := Constrain_F (-Roll_V, -90.0, 90.0);
      Pitch := Constrain_F (Pitch_V, -90.0, 90.0);
   end Lean;

   ----------
   -- Step --
   ----------

   procedure Step (S : in out State; C : Settings; Inp : Inputs; Ok : out Boolean) is
      Dt     : constant Interval_S := Interval (Inp.Interval_Us);
      Result : Step_Result;
   begin
      Update_Lpf_Gains (S, C, Dt);
      if not Inp.Valid_XY then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 8;
         Ok := False;
         return;
      end if;
      if S.Abort_Requested then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 9;
         Handle_Failure (S);
         Ok := False;
         return;
      end if;
      if S.Force_Level_Park then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 10;
         Handle_Failure (S);
         Ok := False;
         return;
      end if;
      if S.Heading_Recovery then
         Disable_Yaw (S);
         S.Yaw_Disable_Reason := 11;
         S.Angle_Roll := 0.0;
         S.Angle_Pitch := S.Heading_Recovery_Pitch;
         Ok := True;
         return;
      end if;
      S.Speed_XY := Held (Length_Of (Inp.Velocity));
      S.Speed_Slowing := S.Speed_XY < S.Speed_Trend - 20.0;
      S.Speed_Trend := Held (S.Speed_Trend + (Dt / (0.5 + Dt)) * (S.Speed_XY - S.Speed_Trend));
      Process_Transitions (S, C, Inp);
      S.Mode := (if Inp.Rescue_Mode then Rescue_Velocity
                 elsif S.Sticks_Active then Stick_Velocity
                 elsif S.Braking then Braking
                 else Settled_Hold);
      case S.Mode is
         when Rescue_Velocity =>
            Rescue_Velocity_Update (S, Inp, Dt);
            Result := Continue;
         when Stick_Velocity =>
            Sticks_Set_Target_Velocity (S, C, Inp);
            S.Hold_Start := (X => Held (Inp.Position.X), Y => Held (Inp.Position.Y));
            S.Anchor := Anchor_Off;
            S.I_Policy := Freeze;
            Result := Continue;
         when Braking =>
            Braking_Update (S, C, Inp, Dt, Result);
         when Settled_Hold =>
            Settled_Hold_Update (S, Inp, Dt, Result);
      end case;
      case Result is
         when Hold_Previous =>
            Ok := True;
            return;
         when Fence_Tripped =>
            Sanity_Violation_Expired (S, C, Inp, Ok);
            return;
         when Continue =>
            null;
      end case;
      Update_Yaw_Control (S, C, Inp, Dt);
      S.Was_Sticks_Active := S.Sticks_Active;
      declare
         Anchor_Off : constant Boolean := S.Anchor = Position_Control.Anchor_Off;
         F_East, F_North, Base_East, Base_North : Angle_Term;
         Smoothed_East, Smoothed_North : Signal;
         Heading_Rad : constant Float := Float (Inp.Yaw) / 10.0 * Degrees_To_Radians;
         Heading_V : constant Unit_Vector2 := (X => Sin_Lib (Heading_Rad), Y => Cos_Lib (Heading_Rad));
         Roll, Pitch : Float;
         Saturated : Boolean;
      begin
         Axis_Terms (S.Pid, S.I_Policy, S.Was_Angle_Saturated,
                     S.Target_Velocity.X, S.Previous_Target.X, S.Distance_Error.X, S.Distance_Integral.X,
                     S.Previous_Velocity.X, Held (Inp.Position.X), Held (Inp.Velocity.X), Held (Inp.Acceleration.X),
                     Dt, Anchor_Off, S.Target_Position.X, F_East, Base_East);
         Axis_Terms (S.Pid, S.I_Policy, S.Was_Angle_Saturated,
                     S.Target_Velocity.Y, S.Previous_Target.Y, S.Distance_Error.Y, S.Distance_Integral.Y,
                     S.Previous_Velocity.Y, Held (Inp.Position.Y), Held (Inp.Velocity.Y), Held (Inp.Acceleration.Y),
                     Dt, Anchor_Off, S.Target_Position.Y, F_North, Base_North);
         Filters.PT3_Apply (S.F_East, Held_Signal (F_East), Smoothed_East);
         Filters.PT3_Apply (S.F_North, Held_Signal (F_North), Smoothed_North);
         Lean (Base_East, Base_North, Smoothed_East, Smoothed_North, Heading_V, S.Max_Angle, Roll, Pitch, Saturated);
         S.Was_Angle_Saturated := Saturated;
         S.Angle_Roll := Constrain_F (Roll, -90.0, 90.0);
         S.Angle_Pitch := Constrain_F (Pitch, -90.0, 90.0);
      end;
      Ok := True;
   end Step;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
      Kd : constant Gain := Float (C.Position_D) * Velocity_Scale;
   begin
      S := (others => <>);
      Init_Lpfs (S, C);
      S.Max_Angle := Float (C.Max_Angle);
      S.Yaw_Kp := Float (C.Yaw_P) * Yaw_P_Scale;
      S.Pid := (Kp     => Float (C.Position_P) * Distance_Scale,
                Ki     => Float (C.Position_I) * Distance_I_Scale,
                Kd     => Kd,
                Ka     => Float (C.Position_A) * Accel_Scale,
                Kf     => Float (C.Position_F) * F_Scale,
                K_Drag => Float'Min (Float (C.Drag_Coefficient) * Drag_Scale, 0.5 * Kd));
      Disable_Yaw (S);
      S.Yaw_Disable_Reason := 0;
   end Init;

   procedure Set_Sticks_Active (S : in out State; Active : Boolean) is
   begin
      S.Sticks_Active := Active;
   end Set_Sticks_Active;

   procedure Set_Target_Velocity (S : in out State; V : Vector2_Velocity; Force_Abort : Boolean) is
   begin
      S.Abort_Requested := Force_Abort;
      S.Target_Velocity := V;
   end Set_Target_Velocity;

   procedure Set_Yaw_Target (S : in out State; Heading_Deg : Degrees) is
   begin
      S.External_Yaw_Target := Heading_Deg;
   end Set_Yaw_Target;

   procedure Set_Heading_Recovery (S : in out State; Active : Boolean; Pitch_Deg : Pitch_Degrees) is
   begin
      S.Heading_Recovery := Active;
      S.Heading_Recovery_Pitch := Pitch_Deg;
   end Set_Heading_Recovery;

   procedure Set_Force_Level_Park (S : in out State; Request : Boolean) is
   begin
      S.Force_Level_Park := Request;
   end Set_Force_Level_Park;

   procedure Set_Yaw_Rate_Limit (S : in out State; Limit_Dps : Rate_Limit_Dps) is
   begin
      S.Yaw_Rate_Limit := Limit_Dps;
   end Set_Yaw_Rate_Limit;

end Adaflight.Position_Control;
