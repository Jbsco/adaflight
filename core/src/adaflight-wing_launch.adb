with Adaflight.Clock;
with Adaflight.Maths;

package body Adaflight.Wing_Launch with SPARK_Mode is

   function Elapsed_Ms (L : Launch; Now_Us : Unsigned_32) return Float is
     (Float (Adaflight.Clock.Elapsed (Now_Us, L.State_Entered_Us)) * 1.0e-3);

   --  Progress through a ramp of the given length, complete at once for a
   --  ramp of no length.
   function Ramp_Progress (L : Launch; Now_Us : Unsigned_32; Duration_Ms : Float) return Factor
     with Pre => Duration_Ms = 0.0 or else Duration_Ms in 1.0 .. 70_000.0
   is
   begin
      if Duration_Ms <= 0.0 then
         return 1.0;
      end if;
      return Adaflight.Maths.Constrain_F (Elapsed_Ms (L, Now_Us) / Duration_Ms, 0.0, 1.0);
   end Ramp_Progress;

   procedure Set_State (L : in out Launch; S : State; Now_Us : Unsigned_32) is
   begin
      L.Current := S;
      L.State_Entered_Us := Now_Us;
   end Set_State;

   --  Every exit hands the aircraft straight back.
   procedure End_Launch (L : in out Launch; Terminal : State; Why : Exit_Reason) is
   begin
      L.Current := Terminal;
      L.Handover := 1.0;
      L.Why := Why;
   end End_Launch;

   -------------------
   -- Is_Stationary --
   -------------------

   function Is_Stationary (Inp : Inputs) return Boolean is
   begin
      if abs (Inp.Acc_Magnitude - 1.0) > Stationary_Acc_Band then
         return False;
      end if;
      if abs Inp.Gyro_Roll > Stationary_Gyro_Dps or else abs Inp.Gyro_Pitch > Stationary_Gyro_Dps
        or else abs Inp.Gyro_Yaw > Stationary_Gyro_Dps
      then
         return False;
      end if;
      if Inp.Altitude_Available and then abs Inp.Altitude_Derivative > Stationary_Vario_Cms then
         return False;
      end if;
      if Inp.GPS_Fix and then Inp.Num_Sat >= Min_Sats and then Inp.Ground_Speed_Cms >= Stationary_Speed_Cms then
         return False;
      end if;
      return True;
   end Is_Stationary;

   --  A bungee pull: forward specific force past the threshold while level.
   --  A swing: the tangential speed about the thrower's shoulder past the
   --  threshold with a forward force. A run: the ground speed past the
   --  threshold with a forward force.
   function Launch_Detected (C : Settings; Inp : Inputs) return Boolean is
      Ax_G      : constant Float := Inp.Acc_X * Inp.Acc_1G_Rec;
      Ay_G      : constant Float := Inp.Acc_Y * Inp.Acc_1G_Rec;
      Yaw       : constant Rate := Inp.Gyro_Yaw;
      Is_Level  : constant Boolean :=
        Inp.Cos_Tilt >= Adaflight.Maths.Cos_Approx (Float (C.Max_Angle_Deg) * Adaflight.Maths.Rad_Per_Degree);
      Bungee    : constant Boolean := Ax_G >= Float (C.Detect_Accel_Decig) * 0.1 and then Is_Level;
      Swing_Cms : Float := 0.0;
      Swing     : Boolean;
      Forward   : Boolean;
   begin
      if abs Yaw > Swing_Min_Yaw_Dps then
         Swing_Cms := abs Ay_G * Gravity_Cmss / (abs Yaw * Adaflight.Maths.Rad_Per_Degree);
      end if;
      Swing := Swing_Cms > Float (C.Detect_Velocity_Cms) and then Ax_G > 0.0;
      Forward := Inp.GPS_Fix and then Inp.Num_Sat >= Min_Sats and then Inp.Ground_Speed_Cms > C.Detect_Velocity_Cms
        and then Ax_G > 0.0;
      return Bungee or else Swing or else Forward;
   end Launch_Detected;

   function Sticks_Moved (C : Settings; Inp : Inputs) return Boolean is
      Deadband : constant Float := Float (C.Abort_Deadband_Percent) / 100.0;
   begin
      return Inp.Roll_Deflection > Deadband or else Inp.Pitch_Deflection > Deadband;
   end Sticks_Moved;

   --  The sticks abort only once the minimum time from detection has run.
   function Abort_Requested (L : Launch; C : Settings; Inp : Inputs) return Boolean is
   begin
      if Adaflight.Clock.Elapsed (Inp.Now_Us, L.Detected_Us) < Integer_32 (C.Min_Time_Ms) * 1000 then
         return False;
      end if;
      return Sticks_Moved (C, Inp);
   end Abort_Requested;

   function Max_Altitude_Reached (C : Settings; Inp : Inputs) return Boolean is
     (C.Max_Altitude_M > 0 and then Inp.Altitude_Available
      and then Inp.Altitude_Cm >= Float (C.Max_Altitude_M) * 100.0);

   --  Bank past the bound either way or a dive past it, held for the hold
   --  time; any frame inside the bound seeds the clock again.
   procedure Attitude_Lost (L : in out Launch; C : Settings; Inp : Inputs; Lost : out Boolean) is
      Limit        : constant Integer_32 := Integer_32 (C.Abort_Angle_Deg) * 10;
      Out_Of_Bound : constant Boolean :=
        Limit > 0 and then (abs Integer_32 (Inp.Attitude_Roll) > Limit or else Integer_32 (Inp.Attitude_Pitch) > Limit);
   begin
      if not Out_Of_Bound then
         L.Attitude_Lost_Us := Inp.Now_Us;
         Lost := False;
      else
         Lost := Adaflight.Clock.Elapsed (Inp.Now_Us, L.Attitude_Lost_Us) >= Attitude_Hold_Ms * 1000;
      end if;
   end Attitude_Lost;

   ----------
   -- Init --
   ----------

   procedure Init (L : out Launch) is
   begin
      L := (Current          => Idle,
            Latched          => False,
            State_Entered_Us => 0,
            Detected_Us      => 0,
            Attitude_Lost_Us => 0,
            Pitch_Target_Deg => 0.0,
            Throttle         => 0.0,
            Handover         => 0.0,
            Why              => None);
   end Init;

   ---------
   -- Arm --
   ---------

   procedure Arm (L : out Launch; Switch_On, Fixed_Wing, Acc_Present : Boolean; Inp : Inputs) is
   begin
      Init (L);
      L.Latched := Switch_On and then Fixed_Wing and then Acc_Present and then Is_Stationary (Inp);
   end Arm;

   ----------------
   -- Switch_Off --
   ----------------

   procedure Switch_Off (L : in out Launch) is
   begin
      if Is_Active (L) then
         End_Launch (L, Aborted, Mode_Off);
      end if;
   end Switch_Off;

   ------------
   -- Update --
   ------------

   procedure Update (L : in out Launch; C : Settings; Inp : Inputs; Angle_Roll, Angle_Pitch : in out Angle_Deg) is
      Idle_Throttle   : constant Float range 0.0 .. 2.55 := Float (C.Idle_Throttle_Percent) * 0.01;
      Launch_Throttle : constant Float range 0.0 .. 2.55 := Float (C.Throttle_Percent) * 0.01;
      Climb_Angle     : constant Float range 0.0 .. 255.0 := Float (C.Climb_Angle_Deg);
      Lost            : Boolean;
      K               : Factor;
   begin
      if not Inp.Launch_Mode or else Inp.Failsafe_Active then
         if L.Current /= Idle and then not Is_Terminal (L) then
            End_Launch (L, Aborted, Mode_Off);
         end if;
         return;
      end if;

      if L.Current >= Motor_Delay and then not Is_Terminal (L) then
         Attitude_Lost (L, C, Inp, Lost);
         if Lost then
            End_Launch (L, Aborted, Attitude);
         end if;
      end if;

      case L.Current is
         when Idle | Wait_Throttle =>
            if L.Current = Idle then
               Set_State (L, Wait_Throttle, Inp.Now_Us);
            end if;
            L.Throttle := 0.0;
            L.Pitch_Target_Deg := 0.0;
            if not Inp.Throttle_Low and then Elapsed_Ms (L, Inp.Now_Us) >= Float (C.Idle_Delay_Ms) then
               Set_State (L, Motor_Idle, Inp.Now_Us);
            elsif Inp.Throttle_Low then
               L.State_Entered_Us := Inp.Now_Us;
            end if;
         when Motor_Idle =>
            if Inp.Throttle_Low then
               Set_State (L, Wait_Throttle, Inp.Now_Us);
            else
               K := Ramp_Progress (L, Inp.Now_Us, Float (Idle_Ramp_Ms));
               L.Throttle := Idle_Throttle * K;
               L.Pitch_Target_Deg := Climb_Angle * K;
               if K >= 1.0 then
                  Set_State (L, Wait_Detection, Inp.Now_Us);
               end if;
            end if;
         when Wait_Detection =>
            L.Throttle := Idle_Throttle;
            L.Pitch_Target_Deg := Climb_Angle;
            if Inp.Throttle_Low then
               Set_State (L, Wait_Throttle, Inp.Now_Us);
            elsif not Launch_Detected (C, Inp) then
               L.State_Entered_Us := Inp.Now_Us;
            elsif Elapsed_Ms (L, Inp.Now_Us) >= Float (C.Detect_Time_Ms) then
               L.Detected_Us := Inp.Now_Us;
               L.Attitude_Lost_Us := Inp.Now_Us;
               Set_State (L, Motor_Delay, Inp.Now_Us);
            end if;
         when Motor_Delay =>
            L.Throttle := Idle_Throttle;
            L.Pitch_Target_Deg := Climb_Angle;
            if Abort_Requested (L, C, Inp) then
               End_Launch (L, Aborted, Sticks);
            elsif Elapsed_Ms (L, Inp.Now_Us) >= Float (C.Motor_Delay_Ms) then
               Set_State (L, Spinup, Inp.Now_Us);
            end if;
         when Spinup =>
            L.Pitch_Target_Deg := Climb_Angle;
            K := Ramp_Progress (L, Inp.Now_Us, Float (C.Spinup_Time_Ms));
            L.Throttle := Idle_Throttle + (Launch_Throttle - Idle_Throttle) * K;
            if Abort_Requested (L, C, Inp) then
               End_Launch (L, Aborted, Sticks);
            elsif K >= 1.0 then
               Set_State (L, In_Progress, Inp.Now_Us);
            end if;
         when In_Progress =>
            L.Throttle := Launch_Throttle;
            L.Pitch_Target_Deg := Climb_Angle;
            if Abort_Requested (L, C, Inp) then
               End_Launch (L, Aborted, Sticks);
            elsif Max_Altitude_Reached (C, Inp) then
               L.Why := Altitude;
               Set_State (L, Finish, Inp.Now_Us);
            elsif C.Timeout_Ms > 0 and then Elapsed_Ms (L, Inp.Now_Us) >= Float (C.Timeout_Ms) then
               L.Why := Timeout;
               Set_State (L, Finish, Inp.Now_Us);
            end if;
         when Finish =>
            L.Throttle := Launch_Throttle;
            L.Pitch_Target_Deg := Climb_Angle;
            L.Handover := Ramp_Progress (L, Inp.Now_Us, Float (C.End_Time_Ms));
            if Sticks_Moved (C, Inp) then
               End_Launch (L, Flying, Sticks);
            elsif L.Handover >= 1.0 then
               End_Launch (L, Flying, Handover);
            end if;
         when Flying | Aborted =>
            null;
      end case;

      if Is_Active (L) then
         Angle_Roll := 0.0;
         Angle_Pitch := -L.Pitch_Target_Deg;
      end if;
   end Update;

end Adaflight.Wing_Launch;
