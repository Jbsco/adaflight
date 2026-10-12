package body Adaflight.Altitude_Hold with SPARK_Mode is

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
   Interval_Min_Us      : constant Integer_32 := Nominal_Interval_Us / 4;
   Interval_Max_Us      : constant Integer_32 := Nominal_Interval_Us * 4;
   subtype Interval_Us is Integer_32 range Interval_Min_Us .. Interval_Max_Us;

   function Hover_Throttle (S : State; C : Settings) return Positive is
     (if C.Hover_Throttle /= 0 then C.Hover_Throttle
      elsif S.Captured_Hover /= 0 then S.Captured_Hover
      else Hover_Default);

   function Held (V : Float) return Altitude_Cm is
     (Constrain_F (V, -Altitude_Cm'Last, Altitude_Cm'Last));

   function Climb_Limit_Of (S : State) return Climb_Rate_Cms is
     (if S.Emergency_Rate > 0.0 then S.Emergency_Rate else S.Max_Climb_Rate);

   --  The task's measured interval held between a quarter and four times
   --  the nominal one, and the nominal one before the first measurement.
   function Task_Interval (Measured : Integer_32) return Interval_Us is
     (if Measured <= 0 then Nominal_Interval_Us
      else Integer_32'Max (Interval_Min_Us, Integer_32'Min (Interval_Max_Us, Measured)));

   procedure Reset_Control (S : in out State) is
   begin
      S.Altitude_I := 0.0;
      S.Throttle_Out := 0.0;
   end Reset_Control;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Altitude_Cm : Altitude_Hold.Altitude_Cm) is
   begin
      S := (Kp                 => Float (C.Altitude_P) * P_Scale,
            Ki                 => Float (C.Altitude_I) * I_Scale,
            Kd                 => Float (C.Altitude_D) * D_Scale,
            Ka                 => Float (C.Altitude_A) * A_Scale,
            Kf                 => Float (C.Altitude_F) * F_Scale,
            Deadband           => Float (C.Deadband) / 100.0,
            Allow_Stick        => C.Deadband /= 0,
            Max_Climb_Rate     => Float (C.Climb_Rate) * 10.0,
            Target_Altitude_Cm => Altitude_Cm,
            others             => <>);
   end Init;

   ------------
   -- Update --
   ------------

   --  The target moved by the stick outside the deadband around the hover
   --  throttle, or driven down at a rate that grows with the altitude under
   --  a failsafe or an emergency descent, while the estimate stays within a
   --  second of climb from the target. A stick beyond the receiver's range
   --  against a hover throttle at the range's edge leaves the factor at
   --  zero, where the reference divides by zero (DESIGN.md D34).
   procedure Update_Target (S : in out State; C : Settings; Inp : Inputs; Interval : Interval_Us)
     with Post => S.Active = S.Active'Old and then S.Altitude_I = S.Altitude_I'Old
                  and then S.Throttle_Out = S.Throttle_Out'Old
   is
      --  A stick within the receiver's range gives a factor within one; the
      --  bound covers a stick far outside it.
      subtype Stick_Scale is Float range -2.0 ** 16 .. 2.0 ** 16;
      Stick_Factor : Stick_Scale := 0.0;
      Max_Climb    : constant Climb_Rate_Cms := Climb_Limit_Of (S);
   begin
      if S.Allow_Stick and then not Inp.Throttle_Low then
         declare
            Hover : constant Float range 1.0 .. 1_700.0 := Float (Hover_Throttle (S, C));
            Low   : constant Float := Hover - S.Deadband * (Hover - Pwm_Min);
            High  : constant Float := Hover + S.Deadband * (Pwm_Max - Hover);
         begin
            if Inp.Throttle_Command < Low and then Low - Pwm_Min >= 0.25 then
               Stick_Factor :=
                 Constrain_F (Scale_Range_F (Inp.Throttle_Command, Pwm_Min, Low, -1.0, 0.0), -2.0 ** 16, 2.0 ** 16);
            elsif Inp.Throttle_Command > High and then Pwm_Max - High >= 0.25 then
               Stick_Factor :=
                 Constrain_F (Scale_Range_F (Inp.Throttle_Command, High, Pwm_Max, 0.0, 1.0), -2.0 ** 16, 2.0 ** 16);
            end if;
         end;
      end if;
      if Inp.Failsafe_Active or else S.Emergency_Rate > 0.0 then
         Stick_Factor := -(0.9 + Constrain_F (Inp.Altitude_Cm / 2_000.0, 0.1, 9.0));
      end if;
      S.Target_Velocity := Constrain_F (Stick_Factor * Max_Climb, -2.0 ** 16, 2.0 ** 16);
      if abs (Inp.Altitude_Cm - S.Target_Altitude_Cm) < Max_Climb * 1.0 then
         S.Target_Altitude_Cm := Held (S.Target_Altitude_Cm + S.Target_Velocity * (Float (Interval) * 1.0e-6));
      end if;
   end Update_Target;

   --  The autopilot's altitude controller: the integral relaxed past two
   --  meters of error, the proportional term held to the velocity limit
   --  through the derivative gain, the derivative boosted above five meters
   --  per second, the acceleration and feedforward terms, the hover offset,
   --  the tilt compensation, and the throttle limits into a fraction of the
   --  receiver's range.
   procedure Altitude_Control (S : in out State; C : Settings; Inp : Inputs; Interval : Interval_Us)
     with Post => S.Active = S.Active'Old and then S.Target_Altitude_Cm = S.Target_Altitude_Cm'Old
                  and then S.Target_Velocity = S.Target_Velocity'Old
   is
      subtype Error_Cm is Float range -2.0 ** 25 .. 2.0 ** 25;
      subtype Term is Float range -2.0 ** 30 .. 2.0 ** 30;
      Dt_S      : constant Float range 0.0 .. 0.05 := Float (Interval) * 1.0e-6;
      Error     : constant Error_Cm := S.Target_Altitude_Cm - Inp.Altitude_Cm;
      Relax     : constant Float := (if abs Error < 200.0 then 1.0 else 0.1);
      Vel_Limit : constant Climb_Rate_Cms := Climb_Limit_Of (S);
      Vel_Max   : constant Float range 1.0 .. 4_000.0 := (if Vel_Limit > 1.0 then Vel_Limit else Velocity_Command_Max);
      P         : Term := Error * S.Kp;
      Target_V  : constant Float := Constrain_F (S.Target_Velocity, -Vel_Max, Vel_Max);
      D_Boost   : Float range 1.0 .. 3.0 := 1.0;
      Abs_Vz    : constant Float := abs Inp.Vertical_Velocity;
   begin
      S.Altitude_I := Constrain_F (S.Altitude_I + Error * S.Ki * Relax * Dt_S, -Integral_Limit, Integral_Limit);
      if S.Kd > 0.0 then
         declare
            P_Limit : constant Float range 0.0 .. 32_000.0 := Vel_Max * S.Kd;
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
      end;
   end Altitude_Control;

   procedure Update (S : in out State; C : Settings; Inp : Inputs) is
   begin
      S.Emergency_Rate := (if Inp.Emergency_Descent then Inp.Emergency_Rate_Cms else 0.0);
      if Inp.Hold_Mode then
         if not S.Active then
            Reset_Control (S);
            S.Target_Altitude_Cm := Inp.Altitude_Cm;
            S.Target_Velocity := 0.0;
            if C.Hover_Throttle /= 0 then
               S.Captured_Hover := 0;
            else
               S.Captured_Hover :=
                 Integer'Max (0, Integer'Min (1_700,
                   Round_Half_Even (Constrain_F (Inp.Throttle_Command, Capture_Min, Capture_Max))));
            end if;
            S.Active := True;
         end if;
      else
         if S.Active then
            Reset_Control (S);
            S.Captured_Hover := 0;
         end if;
         S.Active := False;
      end if;
      if S.Active then
         declare
            Interval : constant Interval_Us := Task_Interval (Inp.Interval_Us);
         begin
            if C.Climb_Rate /= 0 then
               Update_Target (S, C, Inp, Interval);
            end if;
            Altitude_Control (S, C, Inp, Interval);
         end;
      end if;
   end Update;

end Adaflight.Altitude_Hold;
