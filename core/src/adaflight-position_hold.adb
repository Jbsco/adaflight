package body Adaflight.Position_Hold with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; PC : Position_Control.Settings) is
      Control : Position_Control.State;
   begin
      Position_Control.Init (Control, PC);
      S := (Deadband => Float (C.Deadband) * 0.01, Control => Control, others => <>);
   end Init;

   ------------------
   -- Begin_Update --
   ------------------

   procedure Begin_Update
     (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : in out Navigator; Enable_XY : out Boolean;
      Proceed : out Boolean)
   is
      Rescue_Starting : constant Boolean := Inp.Rescue_Mode and then not S.Rescue_Was_Active;
   begin
      Enable_XY := False;
      Proceed := False;
      if Rescue_Starting and then S.Enabled then
         Position_Control.Init_Position_Hold (S.Control, PC, Inp);
      end if;
      if Inp.Pos_Hold_Mode or else Inp.Rescue_Mode then
         if not S.Enabled then
            Position_Control.Reset_Position_Control (S.Control, PC, Inp, N, Enable_XY);
            S.Control_Ok := True;
            S.Enabled := True;
         end if;
      else
         if S.Enabled then
            Position_Control.Set_Sticks_Active (S.Control, False);
            Position_Control.Disable_Yaw_Control (S.Control);
         end if;
         S.Enabled := False;
      end if;
      S.Rescue_Was_Active := Inp.Rescue_Mode;
      if S.Enabled then
         if Inp.Failsafe_Active or else Inp.Rescue_Mode then
            Position_Control.Set_Sticks_Active (S.Control, False);
         else
            Position_Control.Set_Sticks_Active
              (S.Control, Inp.Deflection_Roll > S.Deadband or else Inp.Deflection_Pitch > S.Deadband);
         end if;
         declare
            Sensors_Were_Ok : constant Boolean := S.Sensors_Ok;
         begin
            S.Sensors_Ok := Sensors_Ok_Now (Inp, S.Control.Heading_Recovery);
            if S.Sensors_Ok then
               if not Sensors_Were_Ok then
                  Position_Control.Reanchor (S.Control, PC, Inp);
               end if;
               Position_Control.Begin_Step (S.Control, PC, Inp, Proceed, S.Control_Ok);
            else
               S.Control.Angle_Roll := 0.0;
               S.Control.Angle_Pitch := 0.0;
               Position_Control.Disable_Yaw_Control (S.Control);
            end if;
         end;
      end if;
   end Begin_Update;

   -------------------
   -- Finish_Update --
   -------------------

   procedure Finish_Update (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : Navigator) is
   begin
      Position_Control.Finish_Step (S.Control, PC, Inp, N, S.Control_Ok);
   end Finish_Update;

   ------------
   -- Update --
   ------------

   procedure Update
     (S : in out State; PC : Position_Control.Settings; Inp : Inputs; N : in out Navigator; Enable_XY : out Boolean)
   is
      Proceed : Boolean;
      Reached : Boolean;
   begin
      Begin_Update (S, PC, Inp, N, Enable_XY, Proceed);
      if Proceed then
         Position_Nav.Update (N, Position_Control.Interval (Inp.Interval_Us), Position_Control.Nav_Estimate (Inp),
                              Reached);
         if Reached then
            Position_Nav.Finish_Leg (N);
         end if;
         Finish_Update (S, PC, Inp, N);
      end if;
   end Update;

end Adaflight.Position_Hold;
