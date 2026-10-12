with Ada.Numerics.Long_Elementary_Functions;

package body Adaflight.GPS_Rescue with SPARK_Mode is
   use Vectors;

   --  The two-argument arctangent through the double-precision elementary
   --  functions of the Ada runtime, rounded to single (D6). The body is
   --  outside SPARK; it saturates its result to honor the postcondition.
   function Arctan2 (Y, X : Float) return Float
     with Global => null, Post => Arctan2'Result in -4.0 .. 4.0;

   function Arctan2 (Y, X : Float) return Float with SPARK_Mode => Off is
      Wide : Long_Float := 0.0;
   begin
      if X /= 0.0 or else Y /= 0.0 then
         Wide := Ada.Numerics.Long_Elementary_Functions.Arctan (Long_Float (Y), Long_Float (X));
      end if;
      return Float (Long_Float'Min (4.0, Long_Float'Max (-4.0, Wide)));
   end Arctan2;

   Task_Interval_S    : constant Float := 1.0 / Float (Task_Rate_Hz);
   Task_Interval_Us   : constant := 1_000_000 / Task_Rate_Hz;
   Allowed_Yaw_Range  : constant := 30.0;
   Accept_Radius_Cm   : constant := 20.0;
   --  The radian per degree as the C forms it: pi as a float, divided by 180.
   Radians_Per_Degree : constant Float := Float'Machine (Float'Machine (3.14159265358979323846) / 180.0);
   Min_Sat_Count      : constant := 4;
   Pitch_Forward_Deg  : constant := 35.0;

   function Held (V : Float) return Cm is (Constrain_F (V, -Estimate_Bound, Estimate_Bound));

   --  The C remainder with the sign of the dividend, exact for these bounds.
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

   --  The length of a bounded vector, held at a bound its components cannot
   --  reach.
   function Length_Of (V : Vector2_Cm) return Cm is (Held (Norm (Vector2'(X => V.X, Y => V.Y))));

   function Below_Landing_Altitude (C : Settings; Inp : Inputs) return Boolean is
     (Inp.Altitude_Control_Cm < 100.0 * Float (C.Landing_Altitude_M));

   procedure Stop (S : in out State; Position : in out Position_Control.State) is
   begin
      S.Phase := Idle;
      Position_Control.Set_Heading_Recovery (Position, False, Pitch_Forward_Deg);
   end Stop;

   procedure Disarm_Now (S : in out State; Position : in out Position_Control.State;
                         Disarm : out Boolean; Arming_Disabled : out Boolean) is
   begin
      S.Want.Seconds_Failing := 0;
      Stop (S, Position);
      Arming_Disabled := True;
      Disarm := True;
   end Disarm_Now;

   --  The emergency descent, which needs an altitude; without one the craft
   --  disarms.
   procedure Emergency_Descent_Now (S : in out State; Inp : Inputs; Position : in out Position_Control.State;
                                    Disarm : in out Boolean; Arming_Disabled : in out Boolean) is
   begin
      if Inp.Altitude_Available then
         S.Phase := Emergency_Descent;
      else
         Disarm_Now (S, Position, Disarm, Arming_Disabled);
      end if;
   end Emergency_Descent_Now;

   --  While idle, the altitudes: the maximum held for the armed period, or
   --  across arming when the home point is kept, and the target following.
   procedure Update_Max_Altitude (S : in out State; C : Settings; Inp : Inputs) is
   begin
      if not Inp.Armed and then not C.Set_Home_Once then
         S.Want.Max_Altitude_Cm := 0.0;
         return;
      end if;
      S.Want.Max_Altitude_Cm := Float'Max (S.Sense.Current_Altitude_Cm, S.Want.Max_Altitude_Cm);
      S.Want.Target_Altitude_Cm := S.Sense.Current_Altitude_Cm;
   end Update_Max_Altitude;

   --  The sensors read: the fix count, the heading, the GPS health, the
   --  altitude, the estimate while valid, the distance and speed, the
   --  heading toward home past the acceptance radius and the heading error.
   procedure Sensor_Update (S : in out State; Inp : Inputs)
     with Pre => Bounded (Inp)
   is
   begin
      S.Sense.New_GPS_Data := Inp.GPS_Stamp /= S.GPS_Stamp;
      if S.Sense.New_GPS_Data then
         S.GPS_Stamp := Inp.GPS_Stamp;
      end if;
      S.Sense.Heading_OK := Inp.Heading_Valid;
      S.Sense.GPS_Healthy := Inp.GPS_Healthy;
      S.Sense.Current_Altitude_Cm := Inp.Altitude_Control_Cm;
      S.Sense.Position_XY_Available := Inp.Valid_XY;
      if S.Sense.Position_XY_Available then
         S.Sense.Current_Position := (X => Inp.Position.X, Y => Inp.Position.Y);
         S.Sense.Current_Velocity := (X => Inp.Velocity.X, Y => Inp.Velocity.Y);
      end if;
      S.Sense.Distance_To_Home_Cm := Length_Of (S.Sense.Current_Position);
      S.Sense.Current_Speed_Cms := Length_Of (S.Sense.Current_Velocity);
      S.Sense.Aircraft_Heading_Deg := Float (Inp.Yaw / 10);
      if S.Sense.Distance_To_Home_Cm > Accept_Radius_Cm then
         declare
            Rad : constant Float range -4.0 .. 4.0 :=
              Constrain_F (Arctan2 (-S.Sense.Current_Position.X, -S.Sense.Current_Position.Y), -4.0, 4.0);
            Deg : Heading_Deg := Constrain_F (Rad / Radians_Per_Degree, -230.0, 230.0);
         begin
            if Deg < 0.0 then
               Deg := Deg + 360.0;
            end if;
            S.Want.Target_Heading_Deg := Constrain_F (Deg, -360.0, 360.0);
         end;
      end if;
      S.Sense.Error_Angle_Deg :=
        Constrain_F (Fmod ((S.Sense.Aircraft_Heading_Deg - S.Want.Target_Heading_Deg) + 540.0, 360.0) - 180.0,
                     -180.0, 180.0);
   end Sensor_Update;

   procedure Check_Available (S : in out State; Inp : Inputs) is
   begin
      S.Is_Available := Inp.GPS_Fix_Home and then S.Sense.GPS_Healthy and then S.Sense.Heading_OK
        and then Inp.Altitude_Available and then S.Sense.Position_XY_Available;
   end Check_Available;

   function Add_Second (N : Seconds_Count; Up : Boolean) return Seconds_Count is
     (if Up then Integer'Min (N + 1, Seconds_Count'Last) else Integer'Max (N - 1, 0));

   --  The sanity checks: the home point at the start, the crash flip, the
   --  failure response by the setting, then once a second the GPS health,
   --  the satellite count, and the phase's own test of progress.
   procedure Perform_Sanity_Checks (S : in out State; C : Settings; Inp : Inputs;
                                    Position : in out Position_Control.State;
                                    Disarm : in out Boolean; Arming_Disabled : in out Boolean)
     with Pre => Bounded (Inp)
   is
      Hard_Failsafe : constant Boolean := not Inp.Rx_Receiving;
   begin
      if S.Phase = Idle then
         S.Failure := Healthy;
         return;
      end if;
      if S.Phase = Initialize then
         if S.Sense.Distance_To_Home_Cm < Accept_Radius_Cm and then Below_Landing_Altitude (C, Inp) then
            Disarm_Now (S, Position, Disarm, Arming_Disabled);
            return;
         end if;
         S.Failure := (if Inp.GPS_Fix_Home then Healthy else No_Home_Point);
         S.Prev_Altitude_Cm := Inp.Altitude_Filtered_Cm;
         S.Prev_Target_Alt_Cm := S.Want.Target_Altitude_Cm;
         S.Prev_Distance_Cm := S.Sense.Distance_To_Home_Cm;
         S.Want.Seconds_Failing := 0;
         S.Seconds_Low_Sats := 0;
         S.Seconds_Doing_Nothing := 0;
      end if;
      if Inp.Crash_Recovery_Active then
         Disarm_Now (S, Position, Disarm, Arming_Disabled);
      end if;
      if S.Failure = Healthy then
         S.Is_OK := True;
      else
         S.Is_OK := False;
         case C.Sanity is
            when On =>
               Emergency_Descent_Now (S, Inp, Position, Disarm, Arming_Disabled);
               return;
            when Failsafe_Only =>
               if Hard_Failsafe then
                  Emergency_Descent_Now (S, Inp, Position, Disarm, Arming_Disabled);
                  return;
               end if;
            when Off =>
               if not S.Is_Available and then Hard_Failsafe then
                  Emergency_Descent_Now (S, Inp, Position, Disarm, Arming_Disabled);
                  return;
               end if;
         end case;
      end if;
      if Inp.Now_Us - S.Last_Sanity_Check_Us < 1_000_000 then
         return;
      end if;
      S.Last_Sanity_Check_Us := Inp.Now_Us;
      if not S.Sense.GPS_Healthy then
         S.Failure := GPS_Lost;
      end if;
      S.Seconds_Low_Sats := Add_Second (S.Seconds_Low_Sats, not Inp.GPS_Fix or else Inp.Num_Sat < Min_Sat_Count);
      if S.Seconds_Low_Sats >= 15 then
         S.Failure := Low_Sats;
      end if;
      declare
         Measured_Change : constant Float := Inp.Altitude_Filtered_Cm - S.Prev_Altitude_Cm;
         Target_Change   : constant Float := S.Want.Target_Altitude_Cm - S.Prev_Target_Alt_Cm;
         Control_Error   : Float;
         Velocity_Home   : Float;
      begin
         S.Prev_Altitude_Cm := Inp.Altitude_Filtered_Cm;
         S.Prev_Target_Alt_Cm := S.Want.Target_Altitude_Cm;
         if abs Target_Change < 2.0 ** (-24) then
            Control_Error := abs Measured_Change;
         else
            Control_Error := Measured_Change / Target_Change;
         end if;
         Velocity_Home := S.Prev_Distance_Cm - S.Sense.Distance_To_Home_Cm;
         S.Prev_Distance_Cm := S.Sense.Distance_To_Home_Cm;
         case S.Phase is
            when Attain_Alt =>
               S.Want.Seconds_Failing := Add_Second (S.Want.Seconds_Failing, not (Control_Error > 0.5));
               if S.Want.Seconds_Failing >= 10 then
                  S.Want.Target_Altitude_Cm := Inp.Altitude_Filtered_Cm;
                  S.Failure := Stalled;
                  S.Want.Seconds_Failing := 0;
               end if;
            when Pitch_Forward =>
               S.Want.Seconds_Failing := Add_Second (S.Want.Seconds_Failing, True);
               if S.Want.Seconds_Failing >= 15 then
                  Position_Control.Set_Heading_Recovery (Position, False, Pitch_Forward_Deg);
                  Emergency_Descent_Now (S, Inp, Position, Disarm, Arming_Disabled);
                  if S.Phase = Emergency_Descent then
                     S.Want.Seconds_Failing := 0;
                  end if;
               end if;
            when Rotate =>
               S.Want.Seconds_Failing := Add_Second (S.Want.Seconds_Failing, True);
               if S.Want.Seconds_Failing >= 10 then
                  S.Phase := Fly_Home;
                  S.Want.Target_Speed_Cms := Float (C.Ground_Speed_Cms);
                  S.Want.Seconds_Failing := 0;
               end if;
            when Fly_Home =>
               S.Want.Seconds_Failing :=
                 Add_Second (S.Want.Seconds_Failing, Velocity_Home < 0.2 * S.Want.Target_Speed_Cms);
               if S.Want.Seconds_Failing >= 20 then
                  S.Want.Seconds_Failing := 0;
                  S.Failure := Flyaway;
               end if;
            when Do_Nothing =>
               S.Seconds_Doing_Nothing := Add_Second (S.Seconds_Doing_Nothing, True);
               if S.Seconds_Doing_Nothing >= 15 then
                  S.Seconds_Doing_Nothing := 0;
                  S.Phase := Descent;
               end if;
            when Descent =>
               S.Want.Seconds_Failing := Add_Second (S.Want.Seconds_Failing, not (Control_Error > 0.5));
               if S.Want.Seconds_Failing >= 15 then
                  S.Phase := Landing;
                  S.Want.Seconds_Failing := 0;
               end if;
            when Landing =>
               S.Want.Seconds_Failing := Add_Second (S.Want.Seconds_Failing, not (Control_Error > 0.5));
               if S.Want.Seconds_Failing >= 15 then
                  Disarm_Now (S, Position, Disarm, Arming_Disabled);
               end if;
            when others =>
               null;
         end case;
      end;
   end Perform_Sanity_Checks;

   --  The descent rate, attenuated toward the ground from three times the
   --  setting at fifty metres to six tenths at ten.
   procedure Descend (S : in out State; C : Settings) is
      Attenuator : constant Float range 0.0 .. 4.0 :=
        Constrain_F (Scale_Range_F (Constrain_F (S.Want.Target_Altitude_Cm, 1_000.0, 5_000.0),
                                    1_000.0, 5_000.0, 0.6, 3.0), 0.0, 4.0);
   begin
      S.Want.Target_Altitude_Vel := Constrain_F ((-Float (C.Descend_Rate)) * Attenuator, -8_000.0, 8_000.0);
   end Descend;

   procedure Descend_If_Needed (S : in out State; Needed : out Boolean) is
   begin
      Needed := S.Sense.Distance_To_Home_Cm < S.Want.Descent_Distance_Cm;
      if Needed then
         S.Phase := Descent;
         S.Want.Seconds_Failing := 0;
      end if;
   end Descend_If_Needed;

   --  The speed toward home: the setting, slowed within the slowdown
   --  distance and ramped in at the start.
   procedure Update_Target_Speed (S : in out State; C : Settings) is
      Slowdown : constant Unit_Interval :=
        Constrain_F (S.Sense.Distance_To_Home_Cm / S.Want.Slowdown_Distance_Cm, 0.0, 1.0);
   begin
      S.Want.Target_Speed_Cms :=
        Constrain_F (Float (C.Ground_Speed_Cms) * Slowdown * S.Want.XY_Start_Attenuator, 0.0, 3_000.0);
   end Update_Target_Speed;

   --  The velocity toward home at the target speed, zero within the
   --  acceptance radius, handed to the horizontal controller.
   procedure Control_Velocity (S : in out State; Position : in out Position_Control.State) is
   begin
      if S.Sense.Distance_To_Home_Cm > Accept_Radius_Cm then
         declare
            Distance : constant Float range Accept_Radius_Cm .. Estimate_Bound := S.Sense.Distance_To_Home_Cm;
            Scale    : constant Float range 0.0 .. 3_000.0 / Accept_Radius_Cm := S.Want.Target_Speed_Cms / Distance;
         begin
            S.Want.Target_Velocity :=
              (X => Constrain_F (S.Sense.Current_Position.X * (-Scale), -2.0 ** 26, 2.0 ** 26),
               Y => Constrain_F (S.Sense.Current_Position.Y * (-Scale), -2.0 ** 26, 2.0 ** 26));
         end;
      else
         S.Want.Target_Velocity := (0.0, 0.0);
      end if;
      Position_Control.Set_Target_Velocity (Position, S.Want.Target_Velocity, False);
   end Control_Velocity;

   procedure Clear_Target_Velocity (S : in out State; Position : in out Position_Control.State) is
   begin
      S.Want.Target_Speed_Cms := 0.0;
      S.Want.Target_Velocity := (0.0, 0.0);
      Position_Control.Set_Target_Velocity (Position, S.Want.Target_Velocity, False);
   end Clear_Target_Velocity;

   --  The heading target: the heading error taken off the aircraft heading
   --  as the ramp lets it.
   procedure Control_Yaw (S : State; Position : in out Position_Control.State) is
      Target : constant Float range -720.0 .. 720.0 :=
        Constrain_F (S.Sense.Aircraft_Heading_Deg - S.Sense.Error_Angle_Deg * S.Want.Yaw_Attenuator, -720.0, 720.0);
   begin
      Position_Control.Set_Yaw_Target (Position, Target);
   end Control_Yaw;

   procedure Ramp (A : in out Unit_Interval) is
   begin
      if A < 1.0 then
         A := Float'Min (A + Task_Interval_S, 1.0);
      end if;
   end Ramp;

   --  The targets fixed at the start: the return altitude from the mode,
   --  or a climb above the current altitude close to home, the heading
   --  held, the rates and the ramps at zero, and the altitude controller
   --  reset.
   procedure Init_Rescue_Values (S : in out State; C : Settings; Inp : Inputs;
                                 Altitude : in out Altitude_Control.State; Position : in out Position_Control.State) is
      Current : constant Cm := S.Sense.Current_Altitude_Cm;
   begin
      if S.Sense.Distance_To_Home_Cm < Float (C.Min_Start_Distance_M) * 100.0 then
         S.Want.Return_Altitude_Cm := Held (Float'Max (750.0, Current + S.Want.Initial_Climb_Cm));
      else
         case C.Mode is
            when Fixed_Altitude =>
               S.Want.Return_Altitude_Cm := Held (Float (C.Return_Altitude_M) * 100.0);
            when Current_Altitude =>
               S.Want.Return_Altitude_Cm :=
                 Held (Float'Max (S.Want.Initial_Climb_Cm, Current + S.Want.Initial_Climb_Cm));
            when Max_Altitude =>
               S.Want.Return_Altitude_Cm := Held (S.Want.Max_Altitude_Cm + S.Want.Initial_Climb_Cm);
         end case;
      end if;
      S.Want.Target_Altitude_Cm := Current;
      Position_Control.Set_Yaw_Target (Position, Float (Inp.Yaw / 10));
      S.Want.Target_Altitude_Vel := 0.0;
      S.Want.Yaw_Attenuator := 0.0;
      S.Want.XY_Start_Attenuator := 0.0;
      Clear_Target_Velocity (S, Position);
      Altitude_Control.Reset (Altitude);
   end Init_Rescue_Values;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
      Descent_Cm : constant Cm := Float (C.Descent_Distance_M) * 100.0;
   begin
      S := (others => <>);
      S.Want.Initial_Climb_Cm := Float (C.Initial_Climb_M) * 100.0;
      S.Want.Descent_Distance_Cm := Descent_Cm;
      S.Want.Slowdown_Distance_Cm := Constrain_F (Float'Max (2.0 * Descent_Cm, 500.0), 500.0, 100_000.0);
      S.Is_Available := True;
      S.Sense.Heading_OK := True;
      S.Is_OK := True;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update
     (S : in out State; C : Settings; Inp : Inputs;
      AC : Altitude_Control.Settings; Altitude : in out Altitude_Control.State;
      PC : Position_Control.Settings; P_Inp : Position_Control.Inputs; Position : in out Position_Control.State;
      Disarm : out Boolean; Arming_Disabled : out Boolean)
   is
      Needed : Boolean;
   begin
      Disarm := False;
      Arming_Disabled := False;
      if not Inp.Rescue_Mode then
         Stop (S, Position);
      elsif S.Phase = Idle then
         S.Phase := Initialize;
      end if;
      Sensor_Update (S, Inp);
      Check_Available (S, Inp);
      Perform_Sanity_Checks (S, C, Inp, Position, Disarm, Arming_Disabled);
      case S.Phase is
         when Idle =>
            Update_Max_Altitude (S, C, Inp);
         when Initialize =>
            if not Inp.GPS_Fix_Home then
               S.Failure := No_Home_Point;
            elsif S.Sense.Distance_To_Home_Cm < Accept_Radius_Cm and then Below_Landing_Altitude (C, Inp) then
               S.Phase := Do_Nothing;
            else
               Init_Rescue_Values (S, C, Inp, Altitude, Position);
               S.Return_Altitude_Low := S.Sense.Current_Altitude_Cm < S.Want.Return_Altitude_Cm;
               S.Phase := Attain_Alt;
            end if;
         when Attain_Alt =>
            Clear_Target_Velocity (S, Position);
            if S.Return_Altitude_Low = (S.Sense.Current_Altitude_Cm < S.Want.Return_Altitude_Cm) then
               S.Want.Target_Altitude_Vel :=
                 (if S.Return_Altitude_Low then Float (C.Ascend_Rate) else -Float (C.Descend_Rate));
            else
               S.Want.Target_Altitude_Cm := S.Want.Return_Altitude_Cm;
               S.Want.Target_Altitude_Vel := 0.0;
               S.Want.Seconds_Failing := 0;
               S.Phase := (if S.Sense.Heading_OK then Rotate else Pitch_Forward);
            end if;
         when Pitch_Forward =>
            if not S.Sense.Heading_OK then
               Clear_Target_Velocity (S, Position);
               Position_Control.Set_Heading_Recovery (Position, True, Pitch_Forward_Deg);
            else
               Position_Control.Set_Heading_Recovery (Position, False, Pitch_Forward_Deg);
               Position_Control.Init_Position_Hold (Position, PC, P_Inp);
               S.Phase := Rotate;
               S.Want.Seconds_Failing := 0;
            end if;
         when Rotate =>
            Clear_Target_Velocity (S, Position);
            Descend_If_Needed (S, Needed);
            if not Needed then
               Ramp (S.Want.Yaw_Attenuator);
               Control_Yaw (S, Position);
               if abs S.Sense.Error_Angle_Deg < Allowed_Yaw_Range then
                  S.Phase := Fly_Home;
                  S.Want.Seconds_Failing := 0;
               end if;
            end if;
         when Fly_Home =>
            Ramp (S.Want.XY_Start_Attenuator);
            Descend_If_Needed (S, Needed);
            if not Needed then
               Update_Target_Speed (S, C);
               Control_Velocity (S, Position);
               Control_Yaw (S, Position);
            end if;
         when Descent =>
            Ramp (S.Want.XY_Start_Attenuator);
            Update_Target_Speed (S, C);
            Control_Velocity (S, Position);
            Descend (S, C);
            if Below_Landing_Altitude (C, Inp) then
               S.Phase := Landing;
               S.Want.Seconds_Failing := 0;
            end if;
         when Landing =>
            Descend (S, C);
            Clear_Target_Velocity (S, Position);
         when Emergency_Descent =>
            Descend (S, C);
            S.Want.Target_Velocity := (0.0, 0.0);
            Position_Control.Set_Target_Velocity (Position, S.Want.Target_Velocity, True);
         when Do_Nothing =>
            Clear_Target_Velocity (S, Position);
            S.Want.Target_Altitude_Vel := 0.0;
      end case;
      if S.Phase > Initialize then
         S.Want.Target_Altitude_Cm := Held (S.Want.Target_Altitude_Cm + S.Want.Target_Altitude_Vel * Task_Interval_S);
         Altitude_Control.Control
           (Altitude, AC,
            (Altitude_Cm => Inp.Altitude_Control_Cm, Vertical_Velocity => Inp.Vertical_Velocity,
             Vertical_Acceleration => Inp.Vertical_Acceleration, Cos_Tilt => Inp.Cos_Tilt),
            S.Want.Target_Altitude_Cm, Task_Interval_Us, S.Want.Target_Altitude_Vel,
            Constrain_F (3.0 * Float'Max (Float (C.Ascend_Rate), Float (C.Descend_Rate)), 0.0, 8_000.0));
      end if;
   end Update;

end Adaflight.GPS_Rescue;
