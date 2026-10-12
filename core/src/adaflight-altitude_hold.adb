with Adaflight.Maths; use Adaflight.Maths;

package body Adaflight.Altitude_Hold with SPARK_Mode is
   use type Altitude_Control.State;

   Pwm_Min : constant Float := 1_000.0;
   Pwm_Max : constant Float := 2_000.0;
   subtype Interval_Us is Altitude_Control.Interval_Us;

   function Held (V : Float) return Altitude_Cm is
     (Constrain_F (V, -Altitude_Cm'Last, Altitude_Cm'Last));

   function Climb_Limit_Of (S : State) return Climb_Rate_Cms is
     (if S.Emergency_Rate > 0.0 then S.Emergency_Rate else S.Max_Climb_Rate);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Altitude_Cm : Altitude_Hold.Altitude_Cm) is
      Control : Altitude_Control.State;
   begin
      Altitude_Control.Init (Control, Control_Settings (C));
      S := (Control            => Control,
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
     with Post => S.Active = S.Active'Old and then S.Control = S.Control'Old
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

   procedure Update (S : in out State; C : Settings; Inp : Inputs) is
   begin
      S.Emergency_Rate := (if Inp.Emergency_Descent then Inp.Emergency_Rate_Cms else 0.0);
      if Inp.Hold_Mode then
         if not S.Active then
            Altitude_Control.Reset (S.Control);
            S.Target_Altitude_Cm := Inp.Altitude_Cm;
            S.Target_Velocity := 0.0;
            Altitude_Control.Capture_Hover (S.Control, Control_Settings (C), Inp.Throttle_Command);
            S.Active := True;
         end if;
      else
         if S.Active then
            Altitude_Control.Reset (S.Control);
            Altitude_Control.Clear_Hover (S.Control);
         end if;
         S.Active := False;
      end if;
      if S.Active then
         declare
            Interval : constant Interval_Us := Altitude_Control.Task_Interval (Inp.Interval_Us);
         begin
            if C.Climb_Rate /= 0 then
               Update_Target (S, C, Inp, Interval);
            end if;
            Altitude_Control.Control
              (S.Control, Control_Settings (C),
               (Altitude_Cm => Inp.Altitude_Cm, Vertical_Velocity => Inp.Vertical_Velocity,
                Vertical_Acceleration => Inp.Vertical_Acceleration, Cos_Tilt => Inp.Cos_Tilt),
               S.Target_Altitude_Cm, Interval, S.Target_Velocity, Climb_Limit_Of (S));
         end;
      end if;
   end Update;

end Adaflight.Altitude_Hold;
