package body Adaflight.OSD_Task with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   Exec_Time_Shift : constant := 5;
   Task_Margin     : constant := 1;
   Element_Margin  : constant := 4;
   Reset_Drawing   : constant := 2;

   function To_Int32 (U : Unsigned_32) return Interfaces.Integer_32 is
     (if U >= 2 ** 31 then Interfaces.Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Interfaces.Integer_32 (U));

   procedure Add (O : in out Ops; P : Op)
     with Global => null
   is
   begin
      if O.Count < Max_Ops then
         O.Count := O.Count + 1;
         O.List (O.Count) := P;
      end if;
   end Add;

   procedure Add_Page_Writes (O : in out Ops; W : Adaflight.OSD_Page.Writes)
     with Global => null
   is
      use Adaflight.OSD_Page;
   begin
      for K in 1 .. W.Count loop
         declare
            P : constant Adaflight.OSD_Page.Write := W.List (K);
            T : Adaflight.OSD_Format.Text;
         begin
            case P.Kind is
               when Clear =>
                  Add (O, (Kind => Clear, Attr => (if P.Wait then 1 else 0), others => <>));
               when Text_Write =>
                  if P.Text.Length > 0 then
                     Add (O, (Kind => Write, X => P.X, Y => P.Y, Attr => Unsigned_8 (P.Font_Sel), Line => P.Text));
                  end if;
               when Char_Write =>
                  Adaflight.OSD_Format.Append (T, P.Char);
                  Add (O, (Kind => Write_Char, X => P.X, Y => P.Y, Attr => Unsigned_8 (P.Font_Sel), Line => T));
               when Logo_Write =>
                  Add (O, (Kind => Write_Logo, others => <>));
            end case;
         end;
      end loop;
   end Add_Page_Writes;

   procedure Add_Draw_Ops (O : in out Ops; D : Adaflight.OSD_Draw.Ops)
     with Global => null
   is
      use Adaflight.OSD_Draw;
   begin
      for K in 1 .. D.Count loop
         declare
            P : constant Adaflight.OSD_Draw.Op := D.List (K);
         begin
            case P.Kind is
               when Adaflight.OSD_Draw.Write =>
                  Add (O, (Kind => Write, X => P.X, Y => P.Y, Attr => P.Attr, Line => P.Line));
               when Adaflight.OSD_Draw.Write_Sys =>
                  Add (O, (Kind => Write_Sys, X => P.X, Y => P.Y, Attr => Unsigned_8 (P.Sys), others => <>));
               when Adaflight.OSD_Draw.Select_Layer =>
                  Add (O, (Kind => Select_Layer, Attr => Layer'Pos (P.Target), others => <>));
               when Adaflight.OSD_Draw.Clear_Screen =>
                  Add (O, (Kind => Clear, Attr => P.Attr, others => <>));
               when Adaflight.OSD_Draw.Redraw_Background =>
                  Add (O, (Kind => Redraw_Background, others => <>));
            end case;
         end;
      end loop;
      O.Reported :=
        (Beeper_Shown => O.Reported.Beeper_Shown or else D.Reported.Beeper_Shown,
         Capture_Read => O.Reported.Capture_Read or else D.Reported.Capture_Read);
   end Add_Draw_Ops;

   function Clocks (O : OSD; C : Context; Clock_Us : Unsigned_32) return Adaflight.OSD_Format.Timer_Clocks is
     ((Now_Us         => Clock_Us,
       Fly_Time_Us    => O.Page.Fly_Time_Us,
       Armed_Time_Us  => O.Stats.Armed_Time_Us,
       Launch_Time_Us => O.Page.Launch_Time_Us,
       Armed          => C.Page_Inputs.Armed));

   function Draw_Context (O : OSD; C : Context; Clock_Us : Unsigned_32) return Adaflight.OSD_Draw.Context
     with Post => Adaflight.OSD_Draw.Context_Valid (Draw_Context'Result) = Adaflight.OSD_Draw.Context_Valid (C.Draw)
                  and then Draw_Context'Result.Inputs.Motors = C.Draw.Inputs.Motors
   is
      X : Adaflight.OSD_Draw.Context := C.Draw;
   begin
      X.Inputs.Clocks := Clocks (O, C, Clock_Us);
      X.Inputs.Aux_Value := O.Page.Aux_Value;
      return X;
   end Draw_Context;

   procedure Analyze
     (O : in out OSD; C : Context; Clock_Us : Unsigned_32; Sched : in out Adaflight.Scheduler.State;
      Result : in out Ops)
     with Global => null
   is
      D : Adaflight.OSD_Draw.Ops;
   begin
      Adaflight.Scheduler.Ignore_Task_Exec_Time (Sched);
      Adaflight.OSD_Elements.Add_Active_Elements (O.Active, C.Positions, 1, C.Element_Inputs);
      Adaflight.OSD_Draw.Draw_Backgrounds
        (O.Cycle, O.Active, C.Positions, O.Blink, O.Render, Draw_Context (O, C, Clock_Us), O.Craft, D);
      Add_Draw_Ops (Result, D);
   end Analyze;

   procedure Complete_Initialization
     (O : in out OSD; C : Context; Clock_Us : Unsigned_32; Sched : in out Adaflight.Scheduler.State;
      Result : in out Ops)
     with Global => null,
          Pre    => Context_Valid (C)
   is
      W : Adaflight.OSD_Page.Writes;
   begin
      O.Page.Arm_State := C.Page_Inputs.Armed;
      Adaflight.OSD_Elements.Reset_Alarms (O.Blink);
      O.Background_Layer := C.Background_Layer;
      Add (Result, (Kind => Select_Layer, Attr => 0, others => <>));
      Add (Result, (Kind => Begin_Transaction, Attr => Reset_Drawing, others => <>));
      Adaflight.OSD_Page.Boot_Screen
        (C.Page_Settings, C.Version (1 .. C.Version_Length), C.RTC_Variant, C.Has_Time, C.Date, C.Zone, W);
      Add_Page_Writes (Result, W);
      O.Page.Resume_Refresh_At := Clock_Us + 4 * Adaflight.OSD_Page.Refresh_1S;
      Adaflight.OSD_Render.Init (O.Render, C.Draw.Settings);
      Adaflight.OSD_Draw.Init (O.Cycle, O.Background_Layer);
      O.Active := (others => <>);
      Analyze (O, C, Clock_Us, Sched, Result);
   end Complete_Initialization;

   procedure Update_Check
     (O : in out OSD; C : Context; Now_Us : Unsigned_32; Transfer_In_Progress : Boolean; Due : out Boolean)
   is
      Interval : constant Unsigned_32 := 1_000_000 / Unsigned_32 (C.Rate_Hz);
   begin
      if O.State = Idle and then To_Int32 (Now_Us - O.Due_Us) > 0 then
         O.State := Check;
         if O.Due_Us /= 0 then
            if To_Int32 (O.Due_Us - Now_Us) < 0 then
               declare
                  Behind : constant Unsigned_32 := Now_Us - O.Due_Us;
               begin
                  pragma Assert (Behind in 1 .. 2 ** 31);
                  O.Due_Us := O.Due_Us + ((Behind + Interval - 1) / Interval) * Interval;
               end;
            end if;
         else
            O.Due_Us := Now_Us + Interval;
         end if;
      end if;
      Due := not ((O.State = Check or else O.State = Transfer) and then Transfer_In_Progress) and then O.State /= Idle;
   end Update_Check;

   function After_Elements (C : Context) return Task_State is
     (if not C.Page_Inputs.Armed and then C.Show_Spec then Refresh_Prearm else Commit);

   procedure Update
     (O : in out OSD; C : Context; Now_Us, Clock_Us, Draw_End_Us : Unsigned_32; Answers : Display_Answers;
      Sched : in out Adaflight.Scheduler.State; Result : out Ops)
   is
      Current : constant Task_State := O.State;
   begin
      Result := (others => <>);
      if O.State /= Update_Canvas then
         Adaflight.Scheduler.Ignore_Task_Exec_Rate (Sched);
      end if;
      case O.State is
         when Init =>
            if not Answers.Ready then
               if C.Device = FrSky_OSD then
                  Add (Result, (Kind => Redraw, others => <>));
               else
                  Adaflight.Scheduler.Ignore_Task_Exec_Time (Sched);
               end if;
               return;
            end if;
            Complete_Initialization (O, C, Clock_Us, Sched, Result);
            Add (Result, (Kind => Redraw, others => <>));
            O.State := Commit;
         when Check =>
            if not Answers.Transfer_In_Progress then
               O.State := Update_Heartbeat;
            end if;
         when Update_Heartbeat =>
            Add (Result, (Kind => Heartbeat, others => <>));
            if Answers.Heartbeat_Taken then
               return;
            end if;
            O.State := Process_Stats_1;
         when Process_Stats_1 =>
            declare
               R       : Adaflight.OSD_Stats.Readings := C.Readings;
               Armed   : Boolean;
               Cleared : Boolean;
               Refresh : Boolean;
               W       : Adaflight.OSD_Page.Writes;
            begin
               R.Acceleration := O.Page.G_Force;
               Adaflight.OSD_Page.Process_Stats_1 (O.Page, O.Stats, C.Page_Settings, C.Page_Inputs, R, Armed, Cleared,
                                                   Refresh);
               if Armed then
                  Adaflight.OSD_Page.Show_Armed (C.Page_Settings, C.Page_Inputs, W);
                  Add_Page_Writes (Result, W);
               elsif Cleared then
                  Add (Result, (Kind => Clear, Attr => 0, others => <>));
               end if;
               O.State := (if Refresh then Refresh_Stats else Process_Stats_2);
            end;
         when Refresh_Stats =>
            declare
               W         : Adaflight.OSD_Page.Writes;
               Completed : Boolean := True;
            begin
               if Adaflight.OSD_Page.Page_Ready (O.Stats, C.Page) then
                  Adaflight.OSD_Page.Refresh_Stats (O.Page, C.Page_Settings, O.Stats, C.Page, W, Completed);
                  Add_Page_Writes (Result, W);
               end if;
               if Completed then
                  O.State := Process_Stats_2;
               end if;
            end;
         when Process_Stats_2 =>
            declare
               Skip    : Boolean;
               Cleared : Boolean;
            begin
               Add (Result, (Kind => Begin_Transaction, Attr => Reset_Drawing, others => <>));
               Adaflight.OSD_Page.Process_Stats_2 (O.Page, O.Stats, C.Page_Inputs, Skip, Cleared);
               pragma Unreferenced (Skip);
               if Cleared then
                  Add (Result, (Kind => Clear, Attr => 0, others => <>));
                  Adaflight.Scheduler.Ignore_Task_Exec_Time (Sched);
               end if;
               O.State := Process_Stats_3;
            end;
         when Process_Stats_3 =>
            Adaflight.OSD_Page.Process_Stats_3 (O.Page, C.Page_Settings, C.Page_Inputs);
            O.State := (if not Answers.Grabbed then Update_Alarms else Commit);
         when Update_Alarms =>
            declare
               Inp : Adaflight.OSD_Elements.Alarm_Inputs := C.Alarm_Inputs;
            begin
               Inp.Clocks := Clocks (O, C, Clock_Us);
               Adaflight.OSD_Elements.Update_Alarms (O.Blink, C.Alarm_Settings, Inp);
               O.State := Update_Canvas;
            end;
         when Update_Canvas =>
            if O.Page.Resume_Refresh_At /= 0 then
               O.State := Transfer;
            elsif C.Page_Inputs.OSD_Switch then
               Add (Result, (Kind => Clear, Attr => 0, others => <>));
               O.State := Commit;
            else
               if O.Background_Layer then
                  Add (Result, (Kind => Layer_Copy, others => <>));
               else
                  Add (Result, (Kind => Clear, Attr => 0, others => <>));
               end if;
               if O.Last_GPS /= C.Element_Inputs.GPS_Present then
                  O.Last_GPS := C.Element_Inputs.GPS_Present;
                  Analyze (O, C, Clock_Us, Sched, Result);
               end if;
               Adaflight.OSD_Elements.Sync_Blink (O.Blink, Now_Us);
               O.State := Draw_Element;
            end if;
         when Draw_Element =>
            declare
               Element : constant Natural := O.Cycle.Active_Number;
               Exec    : constant Unsigned_32 := Draw_End_Us - Clock_Us;
               D       : Adaflight.OSD_Draw.Ops;
            begin
               Adaflight.OSD_Draw.Draw_Next
                 (O.Cycle, O.Active, C.Positions, O.Blink, C.Device_Blink, O.Render, O.Warnings,
                  Draw_Context (O, C, Clock_Us), O.Craft, O.More_Elements, D);
               Add_Draw_Ops (Result, D);
               if Exec > Interfaces.Shift_Right (O.Element_Time (Element), Exec_Time_Shift) then
                  O.Element_Time (Element) := Interfaces.Shift_Left (Exec, Exec_Time_Shift);
               elsif O.Element_Time (Element) > 0 then
                  O.Element_Time (Element) := O.Element_Time (Element) - 1;
               end if;
               if Adaflight.OSD_Draw.Render_Pending (O.Cycle) then
                  O.State := Display_Element;
               elsif not O.More_Elements then
                  O.State := After_Elements (C);
               end if;
            end;
         when Display_Element =>
            declare
               Pending : Boolean;
               D       : Adaflight.OSD_Draw.Ops;
            begin
               Adaflight.OSD_Draw.Display_Active (O.Cycle, O.Active, O.Blink, Pending, D);
               Add_Draw_Ops (Result, D);
               if not Pending then
                  O.State := (if O.More_Elements then Draw_Element else After_Elements (C));
               end if;
            end;
         when Refresh_Prearm =>
            declare
               X, Y     : Unsigned_8;
               Line     : Adaflight.OSD_Format.Text;
               Complete : Boolean;
            begin
               Adaflight.OSD_Spec.Draw
                 (O.Spec, C.Spec_Settings, C.Spec_Inputs, C.Page_Settings.Rows, C.Page_Settings.Cols,
                  C.Version (1 .. C.Version_Length), X, Y, Line, Complete);
               Add (Result, (Kind => Write, X => X, Y => Y, Attr => 0, Line => Line));
               if Complete then
                  O.State := Commit;
               end if;
            end;
         when Commit =>
            Add (Result, (Kind => Commit_Transaction, others => <>));
            O.State := (if O.Page.Resume_Refresh_At /= 0 then Idle else Transfer);
         when Transfer =>
            if not Answers.Transfer_In_Progress then
               Add (Result, (Kind => Draw_Screen, others => <>));
               if not Answers.More_To_Draw then
                  O.State := Idle;
               end if;
            end if;
         when Idle =>
            null;
      end case;
      if not Adaflight.Scheduler.Ignoring_Task_Exec_Time (Sched) then
         declare
            Exec : constant Unsigned_32 := (if Current = Draw_Element then Draw_End_Us else Clock_Us) - Now_Us;
         begin
            if Exec > Unsigned_32 (Interfaces.Shift_Right (O.State_Time (Current), Exec_Time_Shift)) then
               O.State_Time (Current) := Unsigned_16 (Interfaces.Shift_Left (Exec, Exec_Time_Shift) and 16#FFFF#);
            elsif O.State_Time (Current) > 0 then
               O.State_Time (Current) := O.State_Time (Current) - 1;
            end if;
         end;
      end if;
      Adaflight.Scheduler.Set_Next_State_Time
        (Sched,
         (case O.State is
            when Idle => Interfaces.Integer_32 (Interfaces.Shift_Right (O.State_Time (Check), Exec_Time_Shift)),
            when Draw_Element =>
              Interfaces.Integer_32 (Interfaces.Shift_Right (O.Element_Time (O.Cycle.Active_Number), Exec_Time_Shift))
              + Element_Margin,
            when others =>
              Interfaces.Integer_32 (Interfaces.Shift_Right (O.State_Time (O.State), Exec_Time_Shift)) + Task_Margin));
   end Update;

end Adaflight.OSD_Task;
