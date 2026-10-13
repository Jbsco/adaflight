with Adaflight.Text;

package body Adaflight.OSD_Page with SPARK_Mode is
   use Adaflight.OSD_Format;
   use type Adaflight.OSD_Stats.Stat;
   use type Interfaces.Integer_64;

   function To_Int32 (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Integer_32 (U));

   procedure Clear_Writes (W : out Writes) is
   begin
      W := (List => (others => <>), Count => 0);
   end Clear_Writes;

   procedure Add (W : in out Writes; Item : Write)
     with Pre  => W.Count < Max_Writes,
          Post => W.Count = W.Count'Old + 1
   is
   begin
      W.Count := W.Count + 1;
      W.List (W.Count) := Item;
   end Add;

   procedure Add_Clear (W : in out Writes; Wait : Boolean)
     with Pre  => W.Count < Max_Writes,
          Post => W.Count = W.Count'Old + 1
   is
      Item : Write;
   begin
      Item.Kind := Clear;
      Item.Wait := Wait;
      Add (W, Item);
   end Add_Clear;

   procedure Add_Text (W : in out Writes; X, Y : Unsigned_8; S : String)
     with Pre  => W.Count < Max_Writes and then S'Length <= Max_Length,
          Post => W.Count = W.Count'Old + 1
   is
      Item : Write;
   begin
      Item.Kind := Text_Write;
      Item.X := X;
      Item.Y := Y;
      Append_String (Item.Text, S);
      Add (W, Item);
   end Add_Text;

   procedure Add_Line (W : in out Writes; X, Y : Unsigned_8; T : Adaflight.OSD_Format.Text)
     with Pre  => W.Count < Max_Writes,
          Post => W.Count = W.Count'Old + 1
   is
      Item : Write;
   begin
      Item.Kind := Text_Write;
      Item.X := X;
      Item.Y := Y;
      Item.Text := T;
      Add (W, Item);
   end Add_Line;

   procedure Draw_Logo (C : Settings; X, Y : Unsigned_8; Font_Sel : Font; W : in out Writes) is
      Offset : Natural := Logo_Start;
   begin
      if C.Logo_Supported then
         declare
            Item : Write;
         begin
            Item.Kind := Logo_Write;
            Add (W, Item);
         end;
         return;
      end if;
      for Row in 0 .. Logo_Rows - 1 loop
         pragma Loop_Invariant (W.Count = W.Count'Loop_Entry + Row * Logo_Cols);
         pragma Loop_Invariant (Offset = Logo_Start + Row * Logo_Cols);
         for Column in 0 .. Logo_Cols - 1 loop
            pragma Loop_Invariant (W.Count = W.Count'Loop_Entry + Column);
            pragma Loop_Invariant (Offset = Logo_Start + Row * Logo_Cols + Column);
            declare
               Item : Write;
            begin
               Item.Kind := Char_Write;
               Item.X := X + Unsigned_8 (Column);
               Item.Y := Y + Unsigned_8 (Row);
               Item.Font_Sel := Font_Sel;
               Item.Char := Character'Val (Offset);
               Add (W, Item);
            end;
            Offset := Offset + 1;
         end loop;
      end loop;
   end Draw_Logo;

   procedure Show_Armed (C : Settings; Inp : Inputs; W : out Writes) is
      Mid_Row : constant Unsigned_8 := C.Rows / 2;
      Mid_Col : constant Unsigned_8 := C.Cols / 2;
   begin
      Clear_Writes (W);
      Add_Clear (W, True);
      if C.Logo_On_Arming = 1 or else (C.Logo_On_Arming = 2 and then not Inp.Was_Ever_Armed) then
         Draw_Logo (C, Mid_Col - Logo_Cols / 2, Mid_Row - 5, C.Arming_Logo, W);
      end if;
      Add_Text (W, Mid_Col - Armed_Word'Length / 2, Mid_Row, Armed_Word);
      if Inp.Crash_Flip_Active then
         Add_Text (W, Mid_Col - Crash_Warning'Length / 2, Mid_Row + 1, Crash_Warning);
      end if;
   end Show_Armed;

   procedure Boot_Screen (C : Settings; Version : String; RTC_Variant : Adaflight.OSD_Format.Element_Type;
                          Has_Time : Boolean; Date : Adaflight.RTC.Date_Time; Zone : Adaflight.RTC.Settings;
                          W : out Writes) is
      Mid_Row : constant Unsigned_8 := C.Rows / 2;
      Mid_Col : constant Unsigned_8 := C.Cols / 2;
      Upper   : String (1 .. Version'Length + 1) := (others => 'V');
   begin
      Clear_Writes (W);
      Add_Clear (W, True);
      Draw_Logo (C, Mid_Col - Logo_Cols / 2, Mid_Row - 5, 0, W);
      for K in Version'Range loop
         Upper (2 + (K - Version'First)) := Adaflight.Text.To_Upper (Version (K));
      end loop;
      Add_Text (W, Mid_Col + 12 - Unsigned_8 (Upper'Length + 1), Mid_Row, Upper);
      Add_Text (W, Mid_Col - 8, Mid_Row + 2, Help_1);
      Add_Text (W, Mid_Col - 4, Mid_Row + 3, Help_2);
      Add_Text (W, Mid_Col - 4, Mid_Row + 4, Help_3);
      declare
         Clock : Adaflight.OSD_Format.Text;
         Valid : Boolean;
      begin
         RTC_Date_Time (Clock, RTC_Variant, Has_Time, Date, Zone, Valid);
         if Valid then
            Add_Line (W, Mid_Col - 10, Mid_Row + 6, Clock);
         end if;
      end;
   end Boot_Screen;

   procedure Render_Continue (R : in out Render_State; C : Settings; S : Adaflight.OSD_Stats.Statistics;
                              P : Adaflight.OSD_Stats.Page; W : out Writes; Done : out Boolean) is
      Mid_Col  : constant Unsigned_8 := C.Cols / 2;
      Rendered : Boolean := False;
   begin
      Clear_Writes (W);
      Done := False;
      if R.Row = 0 then
         declare
            Display_Label : Boolean := False;
         begin
            if R.Row_Count > 0 then
               declare
                  Available    : constant Natural := Natural (C.Rows);
                  Display_Rows : Natural := Natural'Min (Natural (R.Row_Count), Available);
               begin
                  if Natural (R.Row_Count) < Available then
                     Display_Label := True;
                     Display_Rows := Display_Rows + 1;
                  end if;
                  R.Row := Unsigned_8 ((Available - Display_Rows) / 2);
               end;
            end if;
            if Display_Label then
               Add_Text (W, Mid_Col - Heading'Length / 2, R.Row, Heading);
               R.Row := R.Row + 1;
               return;
            end if;
         end;
      end if;
      while R.Index < Adaflight.OSD_Stats.Display_Order'Length loop
         pragma Loop_Invariant (W.Count = 0);
         declare
            Which : constant Adaflight.OSD_Stats.Stat := Adaflight.OSD_Stats.Order (Natural (R.Index) + 1);
            Line  : Adaflight.OSD_Stats.Stat_Line;
         begin
            R.Index := R.Index + 1;
            if C.Enabled (Which) then
               Adaflight.OSD_Stats.Stat_Text (Which, S, P, Line);
               if Line.Shown then
                  if Line.Labeled then
                     Add_Line (W, Mid_Col - 13, R.Row, Line.Label);
                     Add_Text (W, Mid_Col + 5, R.Row, ":");
                     Add_Line (W, Mid_Col + 7, R.Row, Line.Value);
                  else
                     Add_Line (W, Mid_Col - 13, R.Row, Line.Value);
                  end if;
                  R.Row := R.Row + 1;
                  Rendered := True;
                  exit;
               end if;
            end if;
         end;
      end loop;
      if Rendered and then R.Row < C.Rows then
         return;
      end if;
      if R.Row_Count = 0 then
         R.Row_Count := R.Row;
      end if;
      Done := True;
   end Render_Continue;

   procedure Refresh_Stats (ST : in out State; C : Settings; S : Adaflight.OSD_Stats.Statistics;
                            P : Adaflight.OSD_Stats.Page; W : out Writes; Completed : out Boolean) is
   begin
      Clear_Writes (W);
      Completed := False;
      case ST.Phase is
         when Initial_Clear =>
            ST.Render.Row := 0;
            ST.Render.Index := 0;
            ST.Phase := (if ST.Render.Row_Count > 0 then Render_Stats else Count_Stats);
            Add_Clear (W, False);
         when Count_Stats =>
            declare
               Count_Done : Boolean;
            begin
               Render_Continue (ST.Render, C, S, P, W, Count_Done);
               if Count_Done then
                  ST.Phase := Clear_Between;
               end if;
            end;
         when Clear_Between =>
            ST.Render.Row := 0;
            ST.Render.Index := 0;
            Add_Clear (W, False);
            ST.Phase := Render_Stats;
         when Render_Stats =>
            Render_Continue (ST.Render, C, S, P, W, Completed);
      end case;
      if Completed then
         ST.Phase := Initial_Clear;
      end if;
   end Refresh_Stats;

   function Aux_Value_Of (Rc : Float; Scale : Unsigned_16) return Unsigned_16 is
      Clamped : constant Float := Float'Max (1_000.0, Float'Min (2_000.0, Rc));
      Scaled  : constant Float := (Clamped - 1_000.0) * Float (Scale) / 1_000.0;
   begin
      return Unsigned_16 (Float'Truncation (Scaled));
   end Aux_Value_Of;

   procedure Process_Stats_1 (ST : in out State; S : in out Adaflight.OSD_Stats.Statistics; C : Settings; Inp : Inputs;
                              R : Adaflight.OSD_Stats.Readings; Show_Armed : out Boolean; Clear_Now : out Boolean;
                              Refresh : out Boolean) is
      Delta_T : Integer_32;
   begin
      Show_Armed := False;
      Clear_Now := False;
      Refresh := False;
      if ST.Arm_State /= Inp.Armed then
         if Inp.Armed then
            ST.Stats_Enabled := False;
            ST.Stats_Visible := False;
            Adaflight.OSD_Stats.Reset (S, Inp.Has_Link_Quality_Source);
            ST.Resume_Refresh_At := Armed_Delay_Us (C, Inp.Was_Ever_Armed) + Inp.Now_Us;
            Show_Armed := True;
         elsif (for some St in Adaflight.OSD_Stats.Stat => C.Enabled (St))
           and then not ST.Suppress_Stats and then not Inp.Failsafe_Active
           and then (not Inp.Runaway_Or_Crash_Disable or else not C.Warnings_Visible)
         then
            ST.Stats_Enabled := True;
            ST.Resume_Refresh_At := Inp.Now_Us + 60 * Refresh_1S;
            S.End_Voltage := Adaflight.OSD_Stats.Stats_Voltage (R);
            ST.Render.Row_Count := 0;
         end if;
         ST.Arm_State := Inp.Armed;
      end if;
      if Inp.Armed then
         Adaflight.OSD_Stats.Update (S, R);
         Delta_T := To_Int32 (Inp.Now_Us - ST.Last_Time_Us);
         ST.Fly_Time_Us := ST.Fly_Time_Us + Unsigned_32'Mod (Delta_T);
         S.Armed_Time_Us := S.Armed_Time_Us + Unsigned_32'Mod (Delta_T);
         if not Inp.Launch_Control_Active then
            ST.Launch_Time_Us := ST.Launch_Time_Us + Unsigned_32'Mod (Delta_T);
         else
            ST.Launch_Time_Us := 0;
         end if;
      elsif ST.Stats_Enabled then
         if Inp.Display_Grabbed then
            ST.Stats_Enabled := False;
            ST.Resume_Refresh_At := 0;
            S.Armed_Time_Us := 0;
         elsif Inp.OSD_Switch and then ST.Stats_Visible then
            ST.Stats_Visible := False;
            Clear_Now := True;
         elsif not Inp.OSD_Switch then
            if not ST.Stats_Visible then
               ST.Stats_Visible := True;
               ST.Stats_Refresh_Time_Us := 0;
            end if;
            if Inp.Now_Us >= ST.Stats_Refresh_Time_Us then
               ST.Stats_Refresh_Time_Us := Inp.Now_Us + Refresh_1S;
               Refresh := True;
            end if;
         end if;
      end if;
      if C.Aux_Visible then
         if Inp.Now_Us > ST.Aux_Refresh_Time_Us then
            ST.Aux_Value := Aux_Value_Of (Inp.Aux_Rc, C.Aux_Scale);
            ST.Aux_Refresh_Time_Us := Inp.Now_Us + Refresh_1S;
         end if;
      end if;
      ST.Last_Time_Us := Inp.Now_Us;
   end Process_Stats_1;

   procedure Process_Stats_2 (ST : in out State; S : in out Adaflight.OSD_Stats.Statistics; Inp : Inputs;
                              Skip : out Boolean; Clear_Now : out Boolean) is
   begin
      Skip := False;
      Clear_Now := False;
      if ST.Resume_Refresh_At /= 0 then
         if To_Int32 (Inp.Now_Us - ST.Resume_Refresh_At) < 0 then
            if not Inp.Armed and then (Inp.Throttle_High or else Inp.Pitch_High or else Inp.Crash_Flip_Box) then
               ST.Resume_Refresh_At := Inp.Now_Us;
            end if;
            Skip := True;
         else
            Clear_Now := True;
            ST.Resume_Refresh_At := 0;
            ST.Stats_Enabled := False;
            S.Armed_Time_Us := 0;
         end if;
      end if;
   end Process_Stats_2;

   procedure Process_Stats_3 (ST : in out State; C : Settings; Inp : Inputs) is
   begin
      ST.G_Force := 0.0;
      if Inp.Acc_Present and then (C.G_Force_Visible or else C.Enabled (Adaflight.OSD_Stats.Max_G_Force)) then
         ST.G_Force := Inp.Acc_Magnitude;
      end if;
   end Process_Stats_3;

end Adaflight.OSD_Page;
