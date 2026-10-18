with Adaflight.Text;

package body Adaflight.OSD_Warnings with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Adaflight.Arming.Disable_Reason;
   use type Adaflight.Flight_Plan_Nav.Abort_Reason;

   Half_Second_Us        : constant := 500_000;
   Beacon_Guard_Delay_Us : constant := 1_200_000;
   Rescue_Warning_Us     : constant := 5_000_000;
   Symbol_Temperature    : constant Character := Character'Val (16#7A#);

   function To_Int32 (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Integer_32 (U));

   --  The signed difference of two microsecond stamps.
   function Elapsed (Now, Then_Us : Unsigned_32) return Integer_32 is (To_Int32 (Now - Then_Us));

   function Arming_Disabled (F : Adaflight.Arming.Disable_Set) return Boolean is
     (for some R in Adaflight.Arming.Disable_Reason => F (R));

   procedure Append (T : in out Text; S : String)
     with Pre  => S'Length <= Max_Size,
          Post => T.Length = Natural'Min (Max_Size, T.Length'Old + S'Length)
   is
   begin
      for K in S'Range loop
         pragma Loop_Invariant (T.Length = Natural'Min (Max_Size, T.Length'Loop_Entry + (K - S'First)));
         if T.Length < Max_Size then
            T.Length := T.Length + 1;
            T.Data (T.Length) := S (K);
         end if;
      end loop;
   end Append;

   procedure Set (T : out Text; S : String)
     with Pre => S'Length <= Max_Size
   is
   begin
      T := (others => <>);
      Append (T, S);
   end Set;

   procedure Append_Integer (T : in out Text; V : Integer_32) is
      Buffer : String (1 .. Adaflight.Text.Max_Decimal_Length) := (others => ' ');
      Length : Natural;
   begin
      Adaflight.Text.Put_Integer (V, Buffer, Length);
      Append (T, Buffer (1 .. Length));
   end Append_Integer;

   --  A decimal right aligned in three places.
   procedure Append_Integer_Width_3 (T : in out Text; V : Integer_32) is
      Buffer : String (1 .. Adaflight.Text.Max_Decimal_Length) := (others => ' ');
      Length : Natural;
   begin
      Adaflight.Text.Put_Integer (V, Buffer, Length);
      for I in Length + 1 .. 3 loop
         Append (T, " ");
      end loop;
      Append (T, Buffer (1 .. Length));
   end Append_Integer_Width_3;

   function Only_Arm_Switch (F : Adaflight.Arming.Disable_Set) return Boolean is
     (F (Adaflight.Arming.Arm_Switch)
      and then (for all R in Adaflight.Arming.Disable_Reason =>
                  (if R /= Adaflight.Arming.Arm_Switch then not F (R))));

   --  The next reason to show: the lowest set above the one on display, or
   --  the lowest set of all.
   procedure Rotate_Reason (S : in out State; Flags : Adaflight.Arming.Disable_Set) is
      Found : Boolean := False;
   begin
      if S.Display_Set and then S.Display_Reason < Adaflight.Arming.Disable_Reason'Last then
         for R in Adaflight.Arming.Disable_Reason'Succ (S.Display_Reason) .. Adaflight.Arming.Disable_Reason'Last loop
            if Flags (R) then
               S.Display_Reason := R;
               Found := True;
               exit;
            end if;
         end loop;
      end if;
      if not Found then
         for R in Adaflight.Arming.Disable_Reason loop
            if Flags (R) then
               S.Display_Reason := R;
               Found := True;
               exit;
            end if;
         end loop;
      end if;
      S.Display_Set := Found;
   end Rotate_Reason;

   function Erpm_To_Rpm (RPM : Integer_16; Erpm_To_Hz : Float) return Float
     with Pre => Erpm_To_Hz in 0.0 .. 1.0
   is
   begin
      return Float (Unsigned_32'Mod (RPM)) * Erpm_To_Hz * 60.0;
   end Erpm_To_Rpm;

   --  The alarm letters of one ESC: R below the rotation alarm while the
   --  motor runs, C at the current alarm, T at the temperature alarm.
   procedure Alarm_Letters (D : ESC_Data; Active : Boolean; C : Settings; Erpm_To_Hz : Float;
                            Letters : out String; Count : out Natural)
     with Pre  => Letters'First = 1 and then Letters'Length = 3 and then Erpm_To_Hz in 0.0 .. 1.0,
          Post => Count <= 3
   is
   begin
      Letters := (others => ' ');
      Count := 0;
      if Active and then D.RPM /= 0 and then C.ESC_RPM_Alarm /= Alarm_Off
        and then Erpm_To_Rpm (D.RPM, Erpm_To_Hz) <= Float (C.ESC_RPM_Alarm)
      then
         Count := Count + 1;
         Letters (Count) := 'R';
      end if;
      if D.Current /= 0 and then C.ESC_Current_Alarm /= Alarm_Off
        and then D.Current >= Integer_32 (C.ESC_Current_Alarm)
      then
         Count := Count + 1;
         Letters (Count) := 'C';
      end if;
      if D.Temperature /= 0 and then C.ESC_Temp_Alarm /= 0 and then Natural (D.Temperature) >= C.ESC_Temp_Alarm then
         Count := Count + 1;
         Letters (Count) := 'T';
      end if;
   end Alarm_Letters;

   --  The ESC line: the motors with alarms, a plus where the line runs out,
   --  centred when short.
   procedure Build_ESC_Message (T : out Text; Data : ESC_Array; C : Settings; In_Flight : Inputs;
                                Any : out Boolean) is
      Letters : String (1 .. 3);
      Count   : Natural;
   begin
      Set (T, "ESC");
      Any := False;
      for I in 0 .. In_Flight.Motors - 1 loop
         if Data (I).Present then
            Alarm_Letters (Data (I), In_Flight.Motor_Active (I), C, In_Flight.Erpm_To_Hz, Letters, Count);
            if Count > 0 then
               declare
                  Needed : constant Natural := 1 + 1 + Count;
               begin
                  if T.Length + Needed >= Max_Size then
                     if T.Length < Max_Size - 1 then
                        Append (T, "+");
                     end if;
                     Any := True;
                     exit;
                  end if;
                  Append (T, " ");
                  Append_Integer (T, Integer_32 (I + 1));
                  Append (T, Letters (1 .. Count));
                  Any := True;
               end;
            end if;
         end if;
      end loop;
      if Any then
         if T.Length < Preferred_Size - 1 then
            declare
               Offset  : constant Natural := (Preferred_Size - T.Length) / 2;
               Shifted : Text;
            begin
               Shifted.Length := Natural'Min (Max_Size, T.Length + Offset);
               for K in 1 .. Shifted.Length loop
                  Shifted.Data (K) := (if K <= Offset then ' ' else T.Data (K - Offset));
               end loop;
               T := Shifted;
            end;
         end if;
      else
         T := (others => <>);
      end if;
   end Build_ESC_Message;

   function Capacity_Alarm (C : Settings; In_Flight : Inputs) return Natural is
     (if In_Flight.Battery_Capacity > 0 then In_Flight.Battery_Capacity else C.Cap_Alarm);

   procedure Render (S : in out State; C : Settings; In_Flight : Inputs; Line : out Text; Blinking : out Boolean;
                     Attr : out Severity; Reported : out Reports) is
      Now           : constant Unsigned_32 := In_Flight.Now_Us;
      Mission_Abort : constant Boolean :=
        In_Flight.Autopilot_Mode and then In_Flight.Abort_Reason /= Adaflight.Flight_Plan_Nav.None;
   begin
      Line := (others => <>);
      Reported := (Beeper_Shown => False, Capture_Read => False);
      if C.Enabled (GPS_Rescue_Unavailable)
        and then ((In_Flight.GPS_Rescue_Mode and then not In_Flight.GPS_Rescue_OK)
                  or else In_Flight.Rescue_Descent_Active)
      then
         Set (Line, "RESCUE FAIL");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      Attr := Normal;
      Blinking := False;
      if C.Enabled (Arming_Disable) then
         if In_Flight.Arm_Box and then Arming_Disabled (In_Flight.Disable_Flags) then
            declare
               Flags : Adaflight.Arming.Disable_Set := In_Flight.Disable_Flags;
            begin
               if not Only_Arm_Switch (Flags) then
                  Flags (Adaflight.Arming.Arm_Switch) := False;
               end if;
               if Elapsed (Now, S.Update_Time_Us) > Half_Second_Us or else not S.Display_Set
                 or else not Flags (S.Display_Reason)
               then
                  S.Update_Time_Us := Now;
                  Rotate_Reason (S, Flags);
               end if;
            end;
            if S.Display_Set then
               Set (Line, Reason_Name (S.Display_Reason));
            end if;
            Attr := Warning;
            return;
         else
            S.Display_Set := False;
         end if;
      end if;
      if In_Flight.Trying_To_Arm and then not In_Flight.Armed then
         declare
            Guard  : constant Integer_32 := Elapsed (Now, In_Flight.Last_Beacon_Time_Us);
            Tenths : constant Integer_32 :=
              Integer_32 (Interfaces.Integer_64'Max (Beacon_Guard_Delay_Us - Interfaces.Integer_64 (Guard), 0)
                          / 100_000);
         begin
            if Guard < Half_Second_Us then
               Set (Line, " BEACON ON");
            else
               Set (Line, "ARM IN ");
               Append_Integer (Line, Tenths / 10);
               Append (Line, ".");
               Append_Integer (Line, Tenths mod 10);
            end if;
            Attr := Info;
            return;
         end;
      end if;
      if C.Enabled (Fail_Safe) and then In_Flight.Failsafe_Active then
         Set (Line, "FAIL SAFE");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if In_Flight.ESC_Sensor_Feature and then C.Enabled (ESC_Fail) and then In_Flight.Armed then
         declare
            Any : Boolean;
         begin
            Build_ESC_Message (Line, In_Flight.ESC_Sensor, C, In_Flight, Any);
            if Any then
               Attr := Warning;
               Blinking := True;
               return;
            end if;
         end;
      end if;
      if In_Flight.DShot_Telemetry and then C.Enabled (ESC_Fail) and then In_Flight.Armed then
         declare
            Any : Boolean;
         begin
            Build_ESC_Message (Line, In_Flight.DShot_Sensor, C, In_Flight, Any);
            if Any then
               Attr := Warning;
               Blinking := True;
               return;
            end if;
         end;
      end if;
      if C.Enabled (Crash_Flip) and then In_Flight.Crash_Flip_Box then
         if In_Flight.Crash_Flip_Active then
            Set (Line, ">CRASH FLIP<");
            Attr := Warning;
            return;
         elsif not In_Flight.Armed then
            Set (Line, "CRASHFLIP SW");
            Attr := Info;
            return;
         end if;
      end if;
      if C.Enabled (Launch_Control) and then In_Flight.Launch_Control_Active then
         if In_Flight.Acc_Present then
            declare
               Pitch : constant Integer_32 :=
                 Integer_32'Max (-90, Integer_32'Min (90, (Integer_32 (In_Flight.Pitch_Decidegrees)
                                                           - Integer_32 (In_Flight.Pitch_Trim)) / 10));
            begin
               Set (Line, "LAUNCH ");
               Append_Integer (Line, Pitch);
            end;
         else
            Set (Line, "LAUNCH");
         end if;
         if In_Flight.Throttle_Percent >= Integer'Max (In_Flight.Launch_Throttle_Percent - 10, 0) then
            Blinking := True;
         end if;
         Attr := Info;
         return;
      end if;
      if C.Enabled (RSSI) and then In_Flight.RSSI_Percent < C.RSSI_Alarm then
         Set (Line, "RSSI LOW");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (RSSI_Dbm) and then Integer (In_Flight.RSSI_Dbm) < C.RSSI_Dbm_Alarm then
         Set (Line, "RSSI DBM");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (RSNR) and then Integer (In_Flight.RSNR) < C.RSNR_Alarm then
         Set (Line, "RSNR LOW");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Link_Quality) and then In_Flight.Link_Quality_Percent < C.Link_Quality_Alarm then
         Set (Line, "LINK QUALITY");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Battery_Critical) and then In_Flight.Battery = Adaflight.Battery.Critical then
         Set (Line, " LAND NOW");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Load) and then In_Flight.Disable_Flags (Adaflight.Arming.CPU_Load) then
         Set (Line, "CPU OVERLOAD");
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      if C.Enabled (GPS_Rescue_Unavailable) and then In_Flight.Armed and then In_Flight.Rescue_Configured
        and then not In_Flight.Rescue_Available
        and then To_Int32 (In_Flight.Armed_Time_Us - Rescue_Warning_Us) < 0
      then
         Set (Line, "RESCUE N/A");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      if C.Enabled (GPS_Rescue_Failing) and then In_Flight.Armed and then In_Flight.Rescue_Configured
        and then not In_Flight.Rescue_Heading_OK
      then
         Set (Line, "HEADING N/A");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Pos_Hold_Failed) and then In_Flight.Pos_Hold_Failure and then not Mission_Abort then
         Set (Line, "POSHOLD FAIL");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Autopilot_Abort) and then Mission_Abort then
         case In_Flight.Abort_Reason is
            when Adaflight.Flight_Plan_Nav.Estimator =>
               Set (Line, "WP GPS LOST");
            when Adaflight.Flight_Plan_Nav.Stalled =>
               Set (Line, "WP STALLED");
            when Adaflight.Flight_Plan_Nav.Flyaway =>
               Set (Line, "WP FLYAWAY");
            when Adaflight.Flight_Plan_Nav.Heading =>
               Set (Line, "WP HEADING");
            when Adaflight.Flight_Plan_Nav.Mag_Fault =>
               Set (Line, "WP MAG FAULT");
            when Adaflight.Flight_Plan_Nav.None =>
               Set (Line, "WP ABORT");
         end case;
         Attr := Critical;
         Blinking := True;
         return;
      end if;
      Reported.Capture_Read := True;
      declare
         Capture : Adaflight.Flight_Plan_Capture.Capture := In_Flight.Capture;
         Valid   : Boolean;
      begin
         Adaflight.Flight_Plan_Capture.Read_Message (Capture, Now, Valid);
         if Valid then
            Set (Line, Adaflight.Flight_Plan_Capture.Message_Text (Capture));
            Attr := Info;
            return;
         end if;
      end;
      if In_Flight.Autopilot_Mode then
         case In_Flight.Nav_State is
            when Adaflight.Flight_Plan_Nav.Landing =>
               Set (Line, "WP LANDING");
               Attr := Info;
               return;
            when Adaflight.Flight_Plan_Nav.Complete =>
               Set (Line, "WP COMPLETE");
               Attr := Info;
               Blinking := True;
               return;
            when Adaflight.Flight_Plan_Nav.Idle | Adaflight.Flight_Plan_Nav.Targeting
               | Adaflight.Flight_Plan_Nav.Holding | Adaflight.Flight_Plan_Nav.Aborted =>
               null;
         end case;
      end if;
      if In_Flight.Headfree_Mode then
         Set (Line, "HEADFREE");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Core_Temperature) and then Integer (In_Flight.Core_Temperature) >= C.Core_Temp_Alarm then
         Set (Line, "CORE " & Symbol_Temperature & ": ");
         Append_Integer_Width_3
           (Line, Integer_32 (Adaflight.OSD_Format.Temperature_In_Units (Integer (In_Flight.Core_Temperature),
                                                                         C.Units)));
         Append (Line, (1 => Adaflight.OSD_Format.Temperature_Symbol (C.Units)));
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      if C.Enabled (Battery_Warning) and then In_Flight.Battery = Adaflight.Battery.Warning then
         Set (Line, "LOW BATTERY");
         Attr := Warning;
         Blinking := True;
         return;
      end if;
      declare
         Alarm : constant Natural := Capacity_Alarm (C, In_Flight);
      begin
         if C.Enabled (Over_Cap) and then In_Flight.Armed and then Alarm > 0 and then In_Flight.MAh_Drawn >= Alarm then
            Set (Line, "OVER CAP");
            Attr := Warning;
            Blinking := True;
            return;
         end if;
      end;
      if In_Flight.Has_Used_MAh then
         Set (Line, "BATTERY CONT");
         Attr := Info;
         return;
      end if;
      if C.Enabled (Battery_Not_Full) and then not (In_Flight.Armed or else In_Flight.Was_Ever_Armed)
        and then In_Flight.Battery = Adaflight.Battery.OK
        and then In_Flight.Average_Cell_Voltage < In_Flight.Full_Cell_Voltage
      then
         Set (Line, "BATT < FULL");
         Attr := Warning;
         return;
      end if;
      if C.Enabled (Visual_Beeper) and then In_Flight.Visual_Beeper then
         Set (Line, "  * * * *");
         Attr := Info;
         Reported.Beeper_Shown := True;
         return;
      end if;
      if In_Flight.Chirp_Repeat_Total <= 1 then
         if In_Flight.Chirp_Finished then
            Set (Line, "CHIRP EXC FINISHED");
            Attr := Info;
            Blinking := True;
            return;
         end if;
      else
         if In_Flight.Chirp_Series_Finished then
            Set (Line, "CHIRP ");
            Append_Integer (Line, Integer_32 (In_Flight.Chirp_Repeat_Current));
            Append (Line, "/");
            Append_Integer (Line, Integer_32 (In_Flight.Chirp_Repeat_Total));
            Append (Line, " FINISHED");
            Attr := Info;
            Blinking := True;
            return;
         end if;
         if In_Flight.Chirp_Finished then
            declare
               Axis_Char : constant String := "RPY";
               Just_Done : constant Natural := (In_Flight.Chirp_Repeat_Current + 255) mod 256;
            begin
               Set (Line, "CHIRP ");
               Append (Line, (1 => Axis_Char (1 + In_Flight.Chirp_Axis)));
               Append (Line, " ");
               Append_Integer (Line, Integer_32 (Just_Done));
               Append (Line, "/");
               Append_Integer (Line, Integer_32 (In_Flight.Chirp_Repeat_Total));
               Append (Line, " DONE");
               Attr := Info;
               Blinking := False;
               return;
            end;
         end if;
      end if;
   end Render;

end Adaflight.OSD_Warnings;
