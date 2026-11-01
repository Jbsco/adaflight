package body Adaflight.Altitude_Control with SPARK_Mode is

   P_Scale : constant Float := 0.018;
   I_Scale : constant Float := 0.005;
   D_Scale : constant Float := 0.03;
   A_Scale : constant Float := 0.006;
   F_Scale : constant Float := 0.02;
   Velocity_Command_Max : constant Float := 1_500.0;
   Integral_Limit       : constant Float := 150.0;
   Hover_Default        : constant := 1_275;
   Capture_Min          : constant Float := 1_100.0;
   Capture_Max          : constant Float := 1_700.0;
   Pwm_Min              : constant Float := 1_000.0;
   Pwm_Max              : constant Float := 2_000.0;
   Boost_Threshold_Cms  : constant Float := 500.0;

   function Hover_Throttle (S : State; C : Settings) return Positive is
     (if C.Hover_Throttle /= 0 then C.Hover_Throttle
      elsif S.Captured_Hover /= 0 then S.Captured_Hover
      else Hover_Default);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
   begin
      S := (Kp     => Float (C.Altitude_P) * P_Scale,
            Ki     => Float (C.Altitude_I) * I_Scale,
            Kd     => Float (C.Altitude_D) * D_Scale,
            Ka     => Float (C.Altitude_A) * A_Scale,
            Kf     => Float (C.Altitude_F) * F_Scale,
            others => <>);
   end Init;

   -----------
   -- Reset --
   -----------

   procedure Reset (S : in out State) is
   begin
      S.Altitude_I := 0.0;
      S.Throttle_Out := 0.0;
   end Reset;

   -------------------
   -- Capture_Hover --
   -------------------

   procedure Capture_Hover (S : in out State; C : Settings; Throttle_Command : Float) is
   begin
      if C.Hover_Throttle /= 0 then
         S.Captured_Hover := 0;
      else
         S.Captured_Hover :=
           Integer'Max (0, Integer'Min (1_700,
                                        Round_Half_Even (Constrain_F (Throttle_Command, Capture_Min, Capture_Max))));
      end if;
   end Capture_Hover;

   procedure Clear_Hover (S : in out State) is
   begin
      S.Captured_Hover := 0;
   end Clear_Hover;

   -------------
   -- Control --
   -------------

   procedure Control (S : in out State; C : Settings; Inp : Inputs; Target_Altitude_Cm : Altitude_Cm;
                      Interval : Interval_Us; Target : Target_Velocity; Velocity_Limit : Climb_Rate_Cms) is
      subtype Error_Cm is Float range -2.0 ** 25 .. 2.0 ** 25;
      subtype Term is Float range -2.0 ** 30 .. 2.0 ** 30;
      Dt_S      : constant Float range 0.0 .. 0.05 := Float (Interval) * 1.0e-6;
      Error     : constant Error_Cm := Target_Altitude_Cm - Inp.Altitude_Cm;
      Relax     : constant Float := (if abs Error < 200.0 then 1.0 else 0.1);
      Vel_Max   : constant Float range 1.0 .. 8_000.0 :=
        (if Velocity_Limit > 1.0 then Velocity_Limit else Velocity_Command_Max);
      P         : Term := Error * S.Kp;
      Target_V  : constant Float := Constrain_F (Target, -Vel_Max, Vel_Max);
      D_Boost   : Float range 1.0 .. 3.0 := 1.0;
      Abs_Vz    : constant Float := abs Inp.Vertical_Velocity;
   begin
      S.Altitude_I := Constrain_F (S.Altitude_I + Error * S.Ki * Relax * Dt_S, -Integral_Limit, Integral_Limit);
      if S.Kd > 0.0 then
         declare
            P_Limit : constant Float range 0.0 .. 64_000.0 := Vel_Max * S.Kd;
         begin
            P := Constrain_F (P, -P_Limit, P_Limit);
         end;
      end if;
      if Abs_Vz > Boost_Threshold_Cms then
         declare
            Ratio : constant Float range 1.0 .. 2.0 ** 16 := Abs_Vz / Boost_Threshold_Cms;
         begin
            D_Boost := (3.0 * Ratio - 2.0) / Ratio;
         end;
      end if;
      declare
         D : constant Term := (-Inp.Vertical_Velocity) * S.Kd * D_Boost;
         A : constant Term := (-Inp.Vertical_Acceleration) * S.Ka;
         F : constant Term := Target_V * S.Kf;
         Hover_Offset : constant Float range -999.0 .. 700.0 := Float (Hover_Throttle (S, C) - 1_000);
         Offset       : constant Float := ((((P + S.Altitude_I) + D) + A) + F) + Hover_Offset;
         Tilt_Mult    : constant Float range 1.0 .. 2.0 := 1.0 / Float'Max (Inp.Cos_Tilt, 0.5);
         Throttle     : constant Float :=
           Constrain_F (Pwm_Min + Offset * Tilt_Mult, Float (C.Throttle_Min), Float (C.Throttle_Max));
         Low_End      : constant Float := Float (Integer'Max (C.Min_Check, 1_000));
      begin
         S.Throttle_Out := Constrain_F (Scale_Range_F (Throttle, Low_End, Pwm_Max, 0.0, 1.0), 0.0, 1.0);
         S.Taps := (Controlled => True, Throttle => Throttle, Target_Cm => Target_Altitude_Cm,
                    Current_Cm => Inp.Altitude_Cm, P => P, I => S.Altitude_I, D => D, A => A, F => F);
      end;
   end Control;

end Adaflight.Altitude_Control;
