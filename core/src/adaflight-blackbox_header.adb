with Adaflight.Text;

package body Adaflight.Blackbox_Header with SPARK_Mode is
   use type Interfaces.Integer_64;

   ----------------
   -- The writer --
   ----------------

   procedure Replenish (W : in out Writer) is
      Grown : constant Integer_32 := W.Budget + Integer_32 (W.Max_Per_Iteration);
   begin
      W.Budget := Integer_32'Min (Integer_32'Min (Integer_32 (W.Free), Grown), Max_Accumulated_Budget);
   end Replenish;

   procedure Reserve (W : in out Writer; Bytes : Natural; Status : out Reserve_Status) is
   begin
      if Bytes <= Max_Accumulated_Budget and then Integer_32 (Bytes) <= W.Budget then
         Status := Reserved;
         return;
      end if;
      case W.Kind is
         when Serial =>
            if W.Buffer_Size > 0 and then Bytes > W.Buffer_Size - 1 then
               Status := Permanent_Failure;
            else
               Status := Temporary_Failure;
            end if;
         when Flash =>
            if Bytes > W.Buffer_Size then
               Status := Permanent_Failure;
            else
               if Bytes > W.Free then
                  W.Flushes := W.Flushes + 1;
               end if;
               Status := Temporary_Failure;
            end if;
         when SD_Card =>
            Status := Temporary_Failure;
         when No_Device =>
            Status := Permanent_Failure;
      end case;
   end Reserve;

   procedure Put (W : in out Writer; B : in out Byte_Array; S : in out Stream; V : Byte) is
   begin
      W.Written := W.Written + 1;
      if (W.Kind = Serial and then W.Free = 0) or else Remaining (S) < 1 then
         W.Dropped := W.Dropped + 1;
         return;
      end if;
      Write_U8 (B, S, V);
      if W.Free > 0 then
         W.Free := W.Free - 1;
      end if;
   end Put;

   procedure Put_Char (W : in out Writer; B : in out Byte_Array; S : in out Stream; C : Character)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
   is
   begin
      Put (W, B, S, Character'Pos (C));
   end Put_Char;

   procedure Put_String (W : in out Writer; B : in out Byte_Array; S : in out Stream; Str : String)
     with Pre  => Fits (S, B) and then Str'Length <= 1024,
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
   is
   begin
      for I in Str'Range loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry and then Same_Device (W, W'Loop_Entry));
         Put_Char (W, B, S, Str (I));
      end loop;
   end Put_String;

   procedure Put_Text (W : in out Writer; B : in out Byte_Array; S : in out Stream; T : Text)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
   is
   begin
      Put_String (W, B, S, T.Data (1 .. T.Length));
   end Put_Text;

   procedure Put_Decimal (W : in out Writer; B : in out Byte_Array; S : in out Stream; V : Integer_32;
                          Count : out Natural)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
                  and then Count in 1 .. Adaflight.Text.Max_Decimal_Length
   is
      Buffer : String (1 .. Adaflight.Text.Max_Decimal_Length) := (others => ' ');
   begin
      Adaflight.Text.Put_Integer (V, Buffer, Count);
      Put_String (W, B, S, Buffer (1 .. Count));
   end Put_Decimal;

   procedure Put_Unsigned (W : in out Writer; B : in out Byte_Array; S : in out Stream; V : Unsigned_32;
                           Count : out Natural)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
                  and then Count in 1 .. Adaflight.Text.Max_Digits
   is
      Buffer : String (1 .. Adaflight.Text.Max_Digits) := (others => ' ');
   begin
      Adaflight.Text.Put_Unsigned (V, 10, False, Buffer, Count);
      Put_String (W, B, S, Buffer (1 .. Count));
   end Put_Unsigned;

   --  Eight hexadecimal digits, zero filled, in lower case.
   procedure Put_Hex_8 (W : in out Writer; B : in out Byte_Array; S : in out Stream; V : Unsigned_32)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
   is
      Digits_Lower : constant String := "0123456789abcdef";
   begin
      for I in reverse 0 .. 7 loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry and then Same_Device (W, W'Loop_Entry));
         Put_Char (W, B, S, Digits_Lower (1 + Natural (Interfaces.Shift_Right (V, 4 * I) and 16#F#)));
      end loop;
   end Put_Hex_8;

   --------------------
   -- The conditions --
   --------------------

   function Test_Uncached (C : Condition; In_Flight : Condition_Inputs) return Boolean is
      Mask : constant Unsigned_32 := In_Flight.Fields_Disabled_Mask;
   begin
      case C is
         when Always =>
            return True;
         when At_Least_Motors_1 .. At_Least_Motors_8 =>
            return In_Flight.Motors >= Condition'Pos (C) - Condition'Pos (At_Least_Motors_1) + 1
              and then Field_Enabled (Mask, Select_Motor);
         when Motor_1_Has_RPM .. Motor_8_Has_RPM =>
            return In_Flight.Motors >= Condition'Pos (C) - Condition'Pos (Motor_1_Has_RPM) + 1
              and then In_Flight.DShot_Telemetry and then Field_Enabled (Mask, Select_RPM);
         when Servos =>
            return In_Flight.Has_Servos and then Field_Enabled (Mask, Select_Servo);
         when PID =>
            return Field_Enabled (Mask, Select_PID);
         when Nonzero_PID_D_0 .. Nonzero_PID_D_2 =>
            return In_Flight.PID_D (Condition'Pos (C) - Condition'Pos (Nonzero_PID_D_0)) /= 0
              and then Field_Enabled (Mask, Select_PID);
         when Nonzero_Wing_S_0 .. Nonzero_Wing_S_2 =>
            return In_Flight.PID_S (Condition'Pos (C) - Condition'Pos (Nonzero_Wing_S_0)) /= 0
              and then Field_Enabled (Mask, Select_PID);
         when RC_Commands =>
            return Field_Enabled (Mask, Select_RC_Commands);
         when Setpoint =>
            return Field_Enabled (Mask, Select_Setpoint);
         when Mag =>
            return In_Flight.Mag_Present and then Field_Enabled (Mask, Select_Mag);
         when Baro =>
            return In_Flight.Baro_Present and then Field_Enabled (Mask, Select_Altitude);
         when VBat =>
            return In_Flight.Voltage_Meter /= Adaflight.Battery.None and then Field_Enabled (Mask, Select_Battery);
         when Amperage_ADC =>
            return In_Flight.Current_Meter /= Adaflight.Battery.None
              and then In_Flight.Current_Meter /= Adaflight.Battery.Virtual
              and then Field_Enabled (Mask, Select_Battery);
         when Rangefinder =>
            return In_Flight.Rangefinder_Present and then Field_Enabled (Mask, Select_Altitude);
         when RSSI =>
            return In_Flight.RSSI_Configured and then Field_Enabled (Mask, Select_RSSI);
         when Pitot =>
            return Field_Enabled (Mask, Select_Pitot);
         when Not_Logging_Every_Frame =>
            return In_Flight.P_Interval /= In_Flight.I_Interval;
         when Gyro =>
            return Field_Enabled (Mask, Select_Gyro);
         when Gyro_Unfilt =>
            return Field_Enabled (Mask, Select_Gyro_Unfilt);
         when Acc =>
            return In_Flight.Acc_Present and then Field_Enabled (Mask, Select_Acc);
         when Attitude =>
            return In_Flight.Acc_Present and then Field_Enabled (Mask, Select_Attitude);
         when Debug_Log =>
            return In_Flight.Debug_Active and then Field_Enabled (Mask, Select_Debug_Log);
         when Tricopter | Never =>
            return False;
      end case;
   end Test_Uncached;

   procedure Build_Cache (Cache : out Condition_Set; In_Flight : Condition_Inputs) is
   begin
      Cache := (others => False);
      for C in Condition loop
         pragma Loop_Invariant (for all D in Condition => (if D < C then Cache (D) = Test_Uncached (D, In_Flight)));
         Cache (C) := Test_Uncached (C, In_Flight);
      end loop;
   end Build_Cache;

   ----------------
   -- The fields --
   ----------------

   function Delta_Field (Name : Field_Name; Index : Name_Index; Signed : Boolean; I_Predict : Predictor;
                         I_Encode : Encoding; P_Predict : Predictor; P_Encode : Encoding; Cond : Condition)
                         return Field_Definition is
     (Name, Index, Signed, I_Predict, I_Encode, P_Predict, P_Encode, Cond);

   function Simple_Field (Name : Field_Name; Index : Name_Index; Signed : Boolean; Predict : Predictor;
                          Encode : Encoding; Cond : Condition := Always) return Field_Definition is
     (Name, Index, Signed, Predict, Encode, Predict_Zero, Encode_Unsigned_VB, Cond);

   type Field_Table is array (Field_Position range <>) of Field_Definition;

   function DF (Name : Field_Name; Index : Name_Index; Signed : Boolean; I_Predict : Predictor; I_Encode : Encoding;
                P_Predict : Predictor; P_Encode : Encoding; Cond : Condition)
                return Field_Definition renames Delta_Field;
   function SF (Name : Field_Name; Index : Name_Index; Signed : Boolean; Predict : Predictor; Encode : Encoding;
                Cond : Condition := Always) return Field_Definition renames Simple_Field;

   Z     : constant Predictor := Predict_Zero;
   Prev  : constant Predictor := Predict_Previous;
   SLine : constant Predictor := Predict_Straight_Line;
   Avg2  : constant Predictor := Predict_Average_2;
   Inc   : constant Predictor := Predict_Increment;
   VRef  : constant Predictor := Predict_VBat_Reference;
   MinM  : constant Predictor := Predict_Min_Motor;
   M0    : constant Predictor := Predict_Motor_0;
   P1500 : constant Predictor := Predict_1500;
   LastT : constant Predictor := Predict_Last_Main_Frame_Time;
   Home  : constant Predictor := Predict_Home_Coord;
   SVB   : constant Encoding := Encode_Signed_VB;
   UVB   : constant Encoding := Encode_Unsigned_VB;
   T2    : constant Encoding := Encode_Tag2_3S32;
   T4    : constant Encoding := Encode_Tag8_4S16;
   T8    : constant Encoding := Encode_Tag8_8SVB;
   N14   : constant Encoding := Encode_Neg_14_Bit;
   Nul   : constant Encoding := Encode_Null;

   Main_Head : constant Field_Table :=
     (DF (Loop_Iteration, -1, False, Z, UVB, Inc, Nul, Always),
      DF (Time, -1, False, Z, UVB, SLine, SVB, Always),
      DF (Axis_P, 0, True, Z, SVB, Prev, SVB, PID),
      DF (Axis_P, 1, True, Z, SVB, Prev, SVB, PID),
      DF (Axis_P, 2, True, Z, SVB, Prev, SVB, PID),
      DF (Axis_I, 0, True, Z, SVB, Prev, T2, PID),
      DF (Axis_I, 1, True, Z, SVB, Prev, T2, PID),
      DF (Axis_I, 2, True, Z, SVB, Prev, T2, PID),
      DF (Axis_D, 0, True, Z, SVB, Prev, SVB, Nonzero_PID_D_0),
      DF (Axis_D, 1, True, Z, SVB, Prev, SVB, Nonzero_PID_D_1),
      DF (Axis_D, 2, True, Z, SVB, Prev, SVB, Nonzero_PID_D_2),
      DF (Axis_F, 0, True, Z, SVB, Prev, SVB, PID),
      DF (Axis_F, 1, True, Z, SVB, Prev, SVB, PID),
      DF (Axis_F, 2, True, Z, SVB, Prev, SVB, PID));

   Main_Wing : constant Field_Table :=
     (DF (Axis_S, 0, True, Z, SVB, Prev, SVB, Nonzero_Wing_S_0),
      DF (Axis_S, 1, True, Z, SVB, Prev, SVB, Nonzero_Wing_S_1),
      DF (Axis_S, 2, True, Z, SVB, Prev, SVB, Nonzero_Wing_S_2));

   Main_Tail : constant Field_Table :=
     (DF (RC_Command, 0, True, Z, SVB, Prev, T4, RC_Commands),
      DF (RC_Command, 1, True, Z, SVB, Prev, T4, RC_Commands),
      DF (RC_Command, 2, True, Z, SVB, Prev, T4, RC_Commands),
      DF (RC_Command, 3, False, Z, UVB, Prev, T4, RC_Commands),
      DF (Setpoint_Field, 0, True, Z, SVB, Prev, T4, Setpoint),
      DF (Setpoint_Field, 1, True, Z, SVB, Prev, T4, Setpoint),
      DF (Setpoint_Field, 2, True, Z, SVB, Prev, T4, Setpoint),
      DF (Setpoint_Field, 3, True, Z, SVB, Prev, T4, Setpoint),
      DF (VBat_Latest, -1, False, VRef, N14, Prev, T8, VBat),
      DF (Amperage_Latest, -1, True, Z, SVB, Prev, T8, Amperage_ADC),
      DF (Mag_ADC, 0, True, Z, SVB, Prev, T8, Mag),
      DF (Mag_ADC, 1, True, Z, SVB, Prev, T8, Mag),
      DF (Mag_ADC, 2, True, Z, SVB, Prev, T8, Mag),
      DF (Baro_Alt, -1, True, Z, SVB, Prev, T8, Baro),
      DF (Surface_Raw, -1, True, Z, SVB, Prev, T8, Rangefinder),
      DF (RSSI_Field, -1, False, Z, UVB, Prev, T8, RSSI),
      DF (Pitot_Field, 0, True, Z, SVB, Prev, SVB, Pitot),
      DF (Pitot_Field, 1, True, Z, SVB, Prev, SVB, Pitot),
      DF (Gyro_ADC, 0, True, Z, SVB, Avg2, SVB, Gyro),
      DF (Gyro_ADC, 1, True, Z, SVB, Avg2, SVB, Gyro),
      DF (Gyro_ADC, 2, True, Z, SVB, Avg2, SVB, Gyro),
      DF (Gyro_Unfilt_Field, 0, True, Z, SVB, Avg2, SVB, Gyro_Unfilt),
      DF (Gyro_Unfilt_Field, 1, True, Z, SVB, Avg2, SVB, Gyro_Unfilt),
      DF (Gyro_Unfilt_Field, 2, True, Z, SVB, Avg2, SVB, Gyro_Unfilt),
      DF (Acc_Smooth, 0, True, Z, SVB, Avg2, SVB, Acc),
      DF (Acc_Smooth, 1, True, Z, SVB, Avg2, SVB, Acc),
      DF (Acc_Smooth, 2, True, Z, SVB, Avg2, SVB, Acc),
      DF (IMU_Quaternion, 0, True, Z, SVB, Avg2, SVB, Attitude),
      DF (IMU_Quaternion, 1, True, Z, SVB, Avg2, SVB, Attitude),
      DF (IMU_Quaternion, 2, True, Z, SVB, Avg2, SVB, Attitude),
      DF (Debug_Field, 0, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 1, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 2, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 3, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 4, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 5, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 6, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Debug_Field, 7, True, Z, SVB, Avg2, SVB, Debug_Log),
      DF (Motor, 0, False, MinM, UVB, Avg2, SVB, At_Least_Motors_1),
      DF (Motor, 1, False, M0, SVB, Avg2, SVB, At_Least_Motors_2),
      DF (Motor, 2, False, M0, SVB, Avg2, SVB, At_Least_Motors_3),
      DF (Motor, 3, False, M0, SVB, Avg2, SVB, At_Least_Motors_4),
      DF (Motor, 4, False, M0, SVB, Avg2, SVB, At_Least_Motors_5),
      DF (Motor, 5, False, M0, SVB, Avg2, SVB, At_Least_Motors_6),
      DF (Motor, 6, False, M0, SVB, Avg2, SVB, At_Least_Motors_7),
      DF (Motor, 7, False, M0, SVB, Avg2, SVB, At_Least_Motors_8),
      DF (Servo, 0, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 1, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 2, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 3, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 4, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 5, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 6, False, P1500, T8, Prev, T8, Servos),
      DF (Servo, 7, False, P1500, T8, Prev, T8, Servos),
      DF (ERPM, 0, False, Z, UVB, Prev, SVB, Motor_1_Has_RPM),
      DF (ERPM, 1, False, Z, UVB, Prev, SVB, Motor_2_Has_RPM),
      DF (ERPM, 2, False, Z, UVB, Prev, SVB, Motor_3_Has_RPM),
      DF (ERPM, 3, False, Z, UVB, Prev, SVB, Motor_4_Has_RPM),
      DF (ERPM, 4, False, Z, UVB, Prev, SVB, Motor_5_Has_RPM),
      DF (ERPM, 5, False, Z, UVB, Prev, SVB, Motor_6_Has_RPM),
      DF (ERPM, 6, False, Z, UVB, Prev, SVB, Motor_7_Has_RPM),
      DF (ERPM, 7, False, Z, UVB, Prev, SVB, Motor_8_Has_RPM));

   GPS_Home_Table : constant Field_Table :=
     (SF (GPS_Home, 0, True, Z, SVB),
      SF (GPS_Home, 1, True, Z, SVB),
      SF (GPS_Home, 2, True, Z, SVB),
      SF (GPS_Home_Epoch, -1, False, Z, UVB));

   GPS_Table : constant Field_Table :=
     (SF (Time, -1, False, LastT, UVB, Not_Logging_Every_Frame),
      SF (GPS_Num_Sat, -1, False, Z, UVB),
      SF (GPS_Coord, 0, True, Home, SVB),
      SF (GPS_Coord, 1, True, Home, SVB),
      SF (GPS_Altitude, -1, True, Z, SVB),
      SF (GPS_Speed, -1, False, Z, UVB),
      SF (GPS_Ground_Course, -1, False, Z, UVB),
      SF (GPS_Vel_NED, 0, True, Z, SVB),
      SF (GPS_Vel_NED, 1, True, Z, SVB),
      SF (GPS_Vel_NED, 2, True, Z, SVB),
      SF (GPS_Time, -1, False, Z, UVB));

   Slow_Table : constant Field_Table :=
     (SF (Flight_Mode_Flags, -1, False, Z, UVB),
      SF (State_Flags, -1, False, Z, UVB),
      SF (Failsafe_Phase, -1, False, Z, T2),
      SF (RX_Signal_Received, -1, False, Z, T2),
      SF (RX_Flight_Channels_Valid, -1, False, Z, T2));

   function Wing_Rows (Wing : Boolean) return Natural is (if Wing then Main_Wing'Length else 0);

   function Field_Count_Of (T : Header_Table; Wing : Boolean) return Field_Count is
     (case T is
        when Main_Fields => Main_Head'Length + Wing_Rows (Wing) + Main_Tail'Length,
        when GPS_Home_Fields => GPS_Home_Table'Length,
        when GPS_Fields => GPS_Table'Length, when Slow_Fields => Slow_Table'Length);

   function Field_Of (T : Header_Table; Wing : Boolean; I : Field_Position) return Field_Definition is
     (case T is
        when Main_Fields =>
          (if I < Main_Head'Length then Main_Head (I)
           elsif Wing and then I < Main_Head'Length + Main_Wing'Length then Main_Wing (I - Main_Head'Length)
           else Main_Tail (I - Main_Head'Length - Wing_Rows (Wing))),
        when GPS_Home_Fields => GPS_Home_Table (I),
        when GPS_Fields => GPS_Table (I), when Slow_Fields => Slow_Table (I));

   --  The header's frame letters.
   function Main_Char (T : Header_Table) return Character is
     (case T is when Main_Fields => 'I', when GPS_Home_Fields => 'H', when GPS_Fields => 'G', when Slow_Fields => 'S');

   subtype Header_Name_Index is Natural range 0 .. 5;
   function Header_Name (I : Header_Name_Index) return String is
     (case I is
        when 0 => "name", when 1 => "signed", when 2 => "predictor", when 3 => "encoding",
        when 4 => "predictor", when 5 => "encoding");

   --  The attribute a header line lists for a field: its sign, then the
   --  predictors and encodings of the intra and delta frames.
   function Attribute (F : Field_Definition; I : Positive) return Natural is
     (case I is
        when 1 => Boolean'Pos (F.Signed), when 2 => Predictor'Pos (F.I_Predict),
        when 3 => Encoding_Code (F.I_Encode), when 4 => Predictor'Pos (F.P_Predict),
        when others => Encoding_Code (F.P_Encode));

   -------------------
   -- The sysinfo --
   -------------------

   function Label (V : Value_Name) return String is
     (case V is
        when I_Interval => "I interval", when P_Interval => "P interval", when Max_Throttle => "maxthrottle",
        when Motor_Output_Low => "motorOutput", when Motor_KV => "motor_kv", when Acc_1G => "acc_1G",
        when VBat_Scale => "vbat_scale", when VBat_Min_Cell => "vbatcellvoltage", when VBat_Reference => "vbatref",
        when Current_Offset => "currentSensor", when Loop_Time => "looptime",
        when PID_Process_Denom => "pid_process_denom", when Thr_Mid => "thr_mid", when Thr_Expo => "thr_expo",
        when Thr_Hover => "thr_hover", when TPA_Mode => "tpa_mode", when TPA_Rate => "tpa_rate",
        when TPA_Breakpoint => "tpa_breakpoint", when TPA_Low_Rate => "tpa_low_rate",
        when TPA_Low_Breakpoint => "tpa_low_breakpoint", when TPA_Low_Always => "tpa_low_always",
        when Mixer_Type => "mixer_type", when EZ_Landing_Threshold => "ez_landing_threshold",
        when EZ_Landing_Limit => "ez_landing_limit", when EZ_Landing_Speed => "ez_landing_speed",
        when Landing_Disarm_Threshold => "landing_disarm_threshold", when SPA_Roll_Center => "spa_roll_center",
        when SPA_Roll_Width => "spa_roll_width", when SPA_Roll_Mode => "spa_roll_mode",
        when SPA_Pitch_Center => "spa_pitch_center", when SPA_Pitch_Width => "spa_pitch_width",
        when SPA_Pitch_Mode => "spa_pitch_mode", when SPA_Yaw_Center => "spa_yaw_center",
        when SPA_Yaw_Width => "spa_yaw_width", when SPA_Yaw_Mode => "spa_yaw_mode",
        when TPA_Curve_Type => "tpa_curve_type", when TPA_Curve_Stall_Throttle => "tpa_curve_stall_throttle",
        when TPA_Curve_PID_Thr0 => "tpa_curve_pid_thr0", when TPA_Curve_PID_Thr100 => "tpa_curve_pid_thr100",
        when TPA_Curve_Expo => "tpa_curve_expo", when RC_Rate_Roll => "rc_rates", when RC_Expo_Roll => "rc_expo",
        when Rate_Roll => "rates", when Rate_Limit_Roll => "rate_limits", when Roll_P => "rollPID",
        when Pitch_P => "pitchPID", when Yaw_P => "yawPID", when Level_P => "levelPID", when D_Max_Roll => "d_max",
        when D_Max_Gain => "d_max_gain", when D_Max_Advance => "d_max_advance",
        when DTerm_LPF1_Type => "dterm_lpf1_type", when DTerm_LPF1_Static_Hz => "dterm_lpf1_static_hz",
        when DTerm_LPF1_Dyn_Min_Hz => "dterm_lpf1_dyn_hz", when DTerm_LPF1_Dyn_Expo => "dterm_lpf1_dyn_expo",
        when DTerm_LPF2_Type => "dterm_lpf2_type", when DTerm_LPF2_Static_Hz => "dterm_lpf2_static_hz",
        when Yaw_Lowpass_Hz => "yaw_lowpass_hz", when DTerm_Notch_Hz => "dterm_notch_hz",
        when DTerm_Notch_Cutoff => "dterm_notch_cutoff", when ITerm_Windup => "iterm_windup",
        when ITerm_Relax => "iterm_relax", when ITerm_Relax_Type => "iterm_relax_type",
        when ITerm_Relax_Cutoff => "iterm_relax_cutoff", when PID_At_Min_Throttle => "pid_at_min_throttle",
        when Anti_Gravity_Gain => "anti_gravity_gain", when Anti_Gravity_Cutoff_Hz => "anti_gravity_cutoff_hz",
        when Anti_Gravity_P_Gain => "anti_gravity_p_gain", when FF_Weight_Roll => "ff_weight",
        when Feedforward_Transition => "feedforward_transition",
        when Feedforward_Averaging => "feedforward_averaging",
        when Feedforward_Smooth_Factor => "feedforward_smooth_factor",
        when Feedforward_Jitter_Factor => "feedforward_jitter_factor", when Feedforward_Boost => "feedforward_boost",
        when Feedforward_Max_Rate_Limit => "feedforward_max_rate_limit", when Angle_Feedforward => "angle_feedforward",
        when Angle_FF_Smoothing_Ms => "angle_feedforward_smoothing_ms",
        when Feedforward_Yaw_Hold_Gain => "feedforward_yaw_hold_gain",
        when Feedforward_Yaw_Hold_Time => "feedforward_yaw_hold_time", when Angle_Limit => "angle_limit",
        when Angle_Earth_Ref => "angle_earth_ref", when Horizon_Limit_Degrees => "horizon_limit_degrees",
        when Horizon_Delay_Ms => "horizon_delay_ms", when Acc_Limit_Yaw => "acc_limit_yaw",
        when Acc_Limit => "acc_limit", when PID_Sum_Limit => "pidsum_limit",
        when PID_Sum_Limit_Yaw => "pidsum_limit_yaw", when S_Roll => "s_roll", when S_Pitch => "s_pitch",
        when S_Yaw => "s_yaw", when Chirp_Lag_Freq_Hz => "chirp_lag_freq_hz",
        when Chirp_Lead_Freq_Hz => "chirp_lead_freq_hz", when Chirp_Amplitude_Roll => "chirp_amplitude_roll",
        when Chirp_Amplitude_Pitch => "chirp_amplitude_pitch", when Chirp_Amplitude_Yaw => "chirp_amplitude_yaw",
        when Chirp_Frequency_Start_Deci_Hz => "chirp_frequency_start_deci_hz",
        when Chirp_Frequency_End_Deci_Hz => "chirp_frequency_end_deci_hz",
        when Chirp_Time_Seconds => "chirp_time_seconds", when Deadband => "deadband",
        when Yaw_Deadband => "yaw_deadband", when Gyro_Hardware_LPF => "gyro_hardware_lpf",
        when Gyro_LPF1_Type => "gyro_lpf1_type", when Gyro_LPF1_Static_Hz => "gyro_lpf1_static_hz",
        when Gyro_LPF1_Dyn_Min_Hz => "gyro_lpf1_dyn_hz", when Gyro_LPF1_Dyn_Expo => "gyro_lpf1_dyn_expo",
        when Gyro_LPF2_Type => "gyro_lpf2_type", when Gyro_LPF2_Static_Hz => "gyro_lpf2_static_hz",
        when Gyro_Notch_Hz_1 => "gyro_notch_hz", when Gyro_Notch_Cutoff_1 => "gyro_notch_cutoff",
        when Gyro_Enabled_Bitmask => "gyro_enabled_bitmask", when Gyro_Debug_Axis => "gyro_debug_axis",
        when Dyn_Notch_Max_Hz => "dyn_notch_max_hz", when Dyn_Notch_Count => "dyn_notch_count",
        when Dyn_Notch_Q => "dyn_notch_q", when Dyn_Notch_Min_Hz => "dyn_notch_min_hz",
        when DShot_Bidir => "dshot_bidir", when Motor_Poles => "motor_poles",
        when RPM_Filter_Harmonics => "rpm_filter_harmonics", when RPM_Filter_Weight_1 => "rpm_filter_weights",
        when RPM_Filter_Q => "rpm_filter_q", when RPM_Filter_Min_Hz => "rpm_filter_min_hz",
        when RPM_Filter_Fade_Range_Hz => "rpm_filter_fade_range_hz", when RPM_Filter_LPF_Hz => "rpm_filter_lpf_hz",
        when Acc_LPF_Hz_Hundredths => "acc_lpf_hz", when Acc_Hardware => "acc_hardware",
        when Baro_Hardware => "baro_hardware", when Baro_Drift => "baro_drift",
        when Altitude_Source => "altitude_source", when Altitude_Prefer_Baro => "altitude_prefer_baro",
        when Altitude_LPF => "altitude_lpf", when Altitude_D_LPF => "altitude_d_lpf",
        when AP_Landing_Altitude_M => "ap_landing_altitude_m", when AP_Hover_Throttle => "ap_hover_throttle",
        when AP_Throttle_Min => "ap_throttle_min", when AP_Throttle_Max => "ap_throttle_max",
        when AP_Altitude_P => "ap_altitude_p", when AP_Altitude_I => "ap_altitude_i",
        when AP_Altitude_D => "ap_altitude_d", when AP_Altitude_A => "ap_altitude_a",
        when AP_Altitude_F => "ap_altitude_f", when AP_Position_P => "ap_position_p",
        when AP_Position_I => "ap_position_i", when AP_Position_D => "ap_position_d",
        when AP_Position_A => "ap_position_a", when AP_Position_F => "ap_position_f",
        when AP_Position_Cutoff => "ap_position_cutoff", when AP_Stop_Threshold => "ap_stop_threshold",
        when AP_Max_Angle => "ap_max_angle", when AP_Max_Yaw_Rate => "ap_max_yaw_rate", when AP_Yaw_P => "ap_yaw_p",
        when Mag_Hardware => "mag_hardware", when Opticalflow_Hardware => "opticalflow_hardware",
        when Opticalflow_Rotation => "opticalflow_rotation", when Opticalflow_Flip_X => "opticalflow_flip_x",
        when Gyro_Cal_On_First_Arm => "gyro_cal_on_first_arm",
        when Airmode_Activate_Throttle => "airmode_activate_throttle",
        when Serial_RX_Provider => "serialrx_provider", when Use_Unsynced_PWM => "use_unsynced_pwm",
        when Motor_PWM_Protocol => "motor_pwm_protocol", when Motor_PWM_Rate => "motor_pwm_rate",
        when Motor_Idle => "motor_idle", when Debug_Mode => "debug_mode", when Features => "features",
        when RC_Smoothing => "rc_smoothing", when RC_Smoothing_Auto_Factor => "rc_smoothing_auto_factor",
        when RC_Smoothing_Auto_Factor_Throttle => "rc_smoothing_auto_factor_throttle",
        when RC_Smoothing_Setpoint_Cutoff => "rc_smoothing_setpoint_cutoff",
        when RC_Smoothing_Throttle_Cutoff => "rc_smoothing_throttle_cutoff",
        when RC_Smoothing_Debug_Axis => "rc_smoothing_debug_axis",
        when RC_Smoothing_Setpoint_Cutoff_Frequency => "rc_smoothing_active_cutoffs_ff_sp_thr",
        when RC_Smoothing_RX_Rate => "rc_smoothing_rx_smoothed", when Rates_Type => "rates_type",
        when Fields_Disabled_Mask => "fields_disabled_mask", when High_Resolution => "blackbox_high_resolution",
        when VBat_Sag_Compensation => "vbat_sag_compensation", when Dyn_Idle_Min_RPM => "dyn_idle_min_rpm",
        when Dyn_Idle_P_Gain => "dyn_idle_p_gain", when Dyn_Idle_I_Gain => "dyn_idle_i_gain",
        when Dyn_Idle_D_Gain => "dyn_idle_d_gain", when Dyn_Idle_Max_Increase => "dyn_idle_max_increase",
        when Simplified_PIDs_Mode => "simplified_pids_mode",
        when Simplified_Master_Multiplier => "simplified_master_multiplier",
        when Simplified_I_Gain => "simplified_i_gain", when Simplified_D_Gain => "simplified_d_gain",
        when Simplified_PI_Gain => "simplified_pi_gain", when Simplified_D_Max_Gain => "simplified_d_max_gain",
        when Simplified_Feedforward_Gain => "simplified_feedforward_gain",
        when Simplified_Pitch_D_Gain => "simplified_pitch_d_gain",
        when Simplified_Pitch_PI_Gain => "simplified_pitch_pi_gain",
        when Simplified_DTerm_Filter => "simplified_dterm_filter",
        when Simplified_DTerm_Filter_Multiplier => "simplified_dterm_filter_multiplier",
        when Simplified_Gyro_Filter => "simplified_gyro_filter",
        when Simplified_Gyro_Filter_Multiplier => "simplified_gyro_filter_multiplier",
        when Motor_Output_Limit => "motor_output_limit", when Throttle_Limit_Type => "throttle_limit_type",
        when Throttle_Limit_Percent => "throttle_limit_percent", when Throttle_Boost => "throttle_boost",
        when Throttle_Boost_Cutoff => "throttle_boost_cutoff", when Thrust_Linearization => "thrust_linear",
        when GPS_Provider => "gps_provider", when GPS_Set_Home_Point_Once => "gps_set_home_point_once",
        when GPS_Use_3D_Speed => "gps_use_3d_speed", when GPS_Rescue_Min_Start_Dist => "gps_rescue_min_start_dist",
        when GPS_Rescue_Alt_Mode => "gps_rescue_alt_mode", when GPS_Rescue_Initial_Climb => "gps_rescue_initial_climb",
        when GPS_Rescue_Ascend_Rate => "gps_rescue_ascend_rate", when GPS_Rescue_Return_Alt => "gps_rescue_return_alt",
        when GPS_Rescue_Ground_Speed => "gps_rescue_ground_speed",
        when GPS_Rescue_Descent_Dist => "gps_rescue_descent_dist",
        when GPS_Rescue_Descend_Rate => "gps_rescue_descend_rate",
        when GPS_Rescue_Sanity_Checks => "gps_rescue_sanity_checks", when GPS_Rescue_Min_Sats => "gps_rescue_min_sats",
        when GPS_Rescue_Allow_Arming_Without_Fix => "gps_rescue_allow_arming_without_fix",
        when GPS_Rescue_Yaw_P => "gps_rescue_yaw_p", when Alt_Hold_Climb_Rate => "alt_hold_climb_rate",
        when Alt_Hold_Deadband => "alt_hold_deadband", when Pos_Hold_Deadband => "pos_hold_deadband",
        when TPA_Speed_Type => "tpa_speed_type", when TPA_Speed_Basic_Delay => "tpa_speed_basic_delay",
        when TPA_Speed_Basic_Gravity => "tpa_speed_basic_gravity",
        when TPA_Speed_Adv_Prop_Pitch => "tpa_speed_adv_prop_pitch", when TPA_Speed_Adv_Mass => "tpa_speed_adv_mass",
        when TPA_Speed_Adv_Drag_K => "tpa_speed_adv_drag_k", when TPA_Speed_Adv_Thrust => "tpa_speed_adv_thrust",
        when TPA_Speed_Max_Voltage => "tpa_speed_max_voltage",
        when TPA_Speed_Pitch_Offset => "tpa_speed_pitch_offset", when Yaw_Type => "yaw_type",
        when Angle_Pitch_Offset => "angle_pitch_offset", when Device_UID_0 => "DeviceUID",
        when others => "");

   function D (V : Value_Name) return Line is (One_Decimal, V);
   function U (V : Value_Name) return Line is (One_Unsigned, V);
   function D2 (V : Value_Name) return Line is (Two_Decimal, V);
   function D3 (V : Value_Name) return Line is (Three_Decimal, V);
   function L (F : Line_Format) return Line is (F, I_Interval);

   type Line_List is array (Line_Position range <>) of Line;

   --  The lines every craft lists first.
   Common_Lines : constant Line_List :=
     (L (Firmware_Type_Line), L (Firmware_Revision_Line), L (Firmware_Date_Line), L (Build_Key_Line),
      L (Release_Name_Line), L (Device_UID_Line), L (Board_Information_Line), L (Start_Date_Time_Line),
      L (Craft_Name_Line), D (I_Interval), D (P_Interval), L (P_Ratio_Line), D (Max_Throttle),
      L (Gyro_Scale_Line), D2 (Motor_Output_Low), D (Motor_KV), U (Acc_1G), L (VBat_Scale_Line),
      (Three_Unsigned, VBat_Min_Cell), U (VBat_Reference), L (Current_Sensor_Line), D (Loop_Time),
      L (Gyro_Sync_Denom_Line), D (PID_Process_Denom), D (Thr_Mid), D (Thr_Expo), D (Thr_Hover), D (TPA_Mode),
      D (TPA_Rate), D (TPA_Breakpoint), D (TPA_Low_Rate), D (TPA_Low_Breakpoint), D (TPA_Low_Always),
      L (Mixer_Type_Line), D (EZ_Landing_Threshold), D (EZ_Landing_Limit), D (EZ_Landing_Speed),
      D (Landing_Disarm_Threshold));

   Wing_SPA_Lines : constant Line_List :=
     (D (SPA_Roll_Center), D (SPA_Roll_Width), D (SPA_Roll_Mode), D (SPA_Pitch_Center), D (SPA_Pitch_Width),
      D (SPA_Pitch_Mode), D (SPA_Yaw_Center), D (SPA_Yaw_Width), D (SPA_Yaw_Mode));

   Tuning_Lines : constant Line_List :=
     (D (TPA_Curve_Type), D (TPA_Curve_Stall_Throttle), D (TPA_Curve_PID_Thr0), D (TPA_Curve_PID_Thr100),
      D (TPA_Curve_Expo), D3 (RC_Rate_Roll), D3 (RC_Expo_Roll), D3 (Rate_Roll), D3 (Rate_Limit_Roll),
      D3 (Roll_P), D3 (Pitch_P), D3 (Yaw_P), D3 (Level_P), D3 (D_Max_Roll), D (D_Max_Gain), D (D_Max_Advance),
      D (DTerm_LPF1_Type), D (DTerm_LPF1_Static_Hz), D2 (DTerm_LPF1_Dyn_Min_Hz), D (DTerm_LPF1_Dyn_Expo),
      D (DTerm_LPF2_Type), D (DTerm_LPF2_Static_Hz), D (Yaw_Lowpass_Hz), D (DTerm_Notch_Hz),
      D (DTerm_Notch_Cutoff), D (ITerm_Windup), D (ITerm_Relax), D (ITerm_Relax_Type), D (ITerm_Relax_Cutoff),
      D (PID_At_Min_Throttle), D (Anti_Gravity_Gain), D (Anti_Gravity_Cutoff_Hz), D (Anti_Gravity_P_Gain),
      D3 (FF_Weight_Roll), D (Feedforward_Transition), D (Feedforward_Averaging), D (Feedforward_Smooth_Factor),
      D (Feedforward_Jitter_Factor), D (Feedforward_Boost), D (Feedforward_Max_Rate_Limit),
      D (Angle_Feedforward), D (Angle_FF_Smoothing_Ms), D (Feedforward_Yaw_Hold_Gain),
      D (Feedforward_Yaw_Hold_Time), D (Angle_Limit), D (Angle_Earth_Ref), D (Horizon_Limit_Degrees),
      D (Horizon_Delay_Ms), D (Acc_Limit_Yaw), D (Acc_Limit), D (PID_Sum_Limit), D (PID_Sum_Limit_Yaw));

   Wing_S_Lines : constant Line_List := (D (S_Roll), D (S_Pitch), D (S_Yaw));

   Sensor_Lines : constant Line_List :=
     (D (Chirp_Lag_Freq_Hz), D (Chirp_Lead_Freq_Hz), D (Chirp_Amplitude_Roll), D (Chirp_Amplitude_Pitch),
      D (Chirp_Amplitude_Yaw), D (Chirp_Frequency_Start_Deci_Hz), D (Chirp_Frequency_End_Deci_Hz),
      D (Chirp_Time_Seconds), D (Deadband), D (Yaw_Deadband), D (Gyro_Hardware_LPF), D (Gyro_LPF1_Type),
      D (Gyro_LPF1_Static_Hz), D2 (Gyro_LPF1_Dyn_Min_Hz), D (Gyro_LPF1_Dyn_Expo), D (Gyro_LPF2_Type),
      D (Gyro_LPF2_Static_Hz), D2 (Gyro_Notch_Hz_1), D2 (Gyro_Notch_Cutoff_1), D (Gyro_Enabled_Bitmask),
      D (Gyro_Debug_Axis), D (Dyn_Notch_Max_Hz), D (Dyn_Notch_Count), D (Dyn_Notch_Q), D (Dyn_Notch_Min_Hz),
      D (DShot_Bidir), D (Motor_Poles), D (RPM_Filter_Harmonics), D3 (RPM_Filter_Weight_1), D (RPM_Filter_Q),
      D (RPM_Filter_Min_Hz), D (RPM_Filter_Fade_Range_Hz), D (RPM_Filter_LPF_Hz), D (Acc_LPF_Hz_Hundredths),
      D (Acc_Hardware), D (Baro_Hardware), D (Baro_Drift), D (Altitude_Source), D (Altitude_Prefer_Baro),
      D (Altitude_LPF), D (Altitude_D_LPF));

   Autopilot_Lines : constant Line_List :=
     (D (AP_Landing_Altitude_M), D (AP_Hover_Throttle), D (AP_Throttle_Min), D (AP_Throttle_Max),
      D (AP_Altitude_P), D (AP_Altitude_I), D (AP_Altitude_D), D (AP_Altitude_A), D (AP_Altitude_F),
      D (AP_Position_P), D (AP_Position_I), D (AP_Position_D), D (AP_Position_A), D (AP_Position_F),
      D (AP_Position_Cutoff), D (AP_Stop_Threshold), D (AP_Max_Angle), D (AP_Max_Yaw_Rate), D (AP_Yaw_P));

   System_Lines : constant Line_List :=
     (D (Mag_Hardware), D (Opticalflow_Hardware), D (Opticalflow_Rotation), D (Opticalflow_Flip_X),
      D (Gyro_Cal_On_First_Arm), D (Airmode_Activate_Throttle), D (Serial_RX_Provider), D (Use_Unsynced_PWM),
      D (Motor_PWM_Protocol), D (Motor_PWM_Rate), D (Motor_Idle), D (Debug_Mode), L (Debug_Mode_Name_Line),
      D (Features), D (RC_Smoothing), D (RC_Smoothing_Auto_Factor), D (RC_Smoothing_Auto_Factor_Throttle),
      D (RC_Smoothing_Setpoint_Cutoff), D (RC_Smoothing_Throttle_Cutoff), D (RC_Smoothing_Debug_Axis),
      D2 (RC_Smoothing_Setpoint_Cutoff_Frequency), D (RC_Smoothing_RX_Rate), D (Rates_Type),
      D (Fields_Disabled_Mask), D (High_Resolution), D (VBat_Sag_Compensation), D (Dyn_Idle_Min_RPM),
      D (Dyn_Idle_P_Gain), D (Dyn_Idle_I_Gain), D (Dyn_Idle_D_Gain), D (Dyn_Idle_Max_Increase),
      D (Simplified_PIDs_Mode), D (Simplified_Master_Multiplier), D (Simplified_I_Gain), D (Simplified_D_Gain),
      D (Simplified_PI_Gain), D (Simplified_D_Max_Gain), D (Simplified_Feedforward_Gain),
      D (Simplified_Pitch_D_Gain), D (Simplified_Pitch_PI_Gain), D (Simplified_DTerm_Filter),
      D (Simplified_DTerm_Filter_Multiplier), D (Simplified_Gyro_Filter), D (Simplified_Gyro_Filter_Multiplier),
      D (Motor_Output_Limit), D (Throttle_Limit_Type), D (Throttle_Limit_Percent), D (Throttle_Boost),
      D (Throttle_Boost_Cutoff), D (Thrust_Linearization), D (GPS_Provider), D (GPS_Set_Home_Point_Once),
      D (GPS_Use_3D_Speed));

   Rescue_Lines : constant Line_List :=
     (D (GPS_Rescue_Min_Start_Dist), D (GPS_Rescue_Alt_Mode), D (GPS_Rescue_Initial_Climb),
      D (GPS_Rescue_Ascend_Rate), D (GPS_Rescue_Return_Alt), D (GPS_Rescue_Ground_Speed),
      D (GPS_Rescue_Descent_Dist), D (GPS_Rescue_Descend_Rate), D (GPS_Rescue_Sanity_Checks),
      D (GPS_Rescue_Min_Sats), D (GPS_Rescue_Allow_Arming_Without_Fix), D (GPS_Rescue_Yaw_P),
      D (Alt_Hold_Climb_Rate), D (Alt_Hold_Deadband), D (Pos_Hold_Deadband));

   Wing_Speed_Lines : constant Line_List :=
     (D (TPA_Speed_Type), D (TPA_Speed_Basic_Delay), D (TPA_Speed_Basic_Gravity), D (TPA_Speed_Adv_Prop_Pitch),
      D (TPA_Speed_Adv_Mass), D (TPA_Speed_Adv_Drag_K), D (TPA_Speed_Adv_Thrust), D (TPA_Speed_Max_Voltage),
      D (TPA_Speed_Pitch_Offset), D (Yaw_Type), D (Angle_Pitch_Offset));

   Multirotor_Lines : constant Line_List :=
     Common_Lines & Tuning_Lines & Sensor_Lines & Autopilot_Lines & System_Lines & Rescue_Lines;

   Wing_Lines : constant Line_List :=
     Common_Lines & Wing_SPA_Lines & Tuning_Lines & Wing_S_Lines & Sensor_Lines & System_Lines & Wing_Speed_Lines;

   function Line_Count_Of (Wing : Boolean) return Line_Count is
     (if Wing then Wing_Lines'Length else Multirotor_Lines'Length);

   function Line_Of (Wing : Boolean; I : Line_Position) return Line is
     (if Wing then Wing_Lines (I) else Multirotor_Lines (I));

   -------------------------
   -- The chunked writers --
   -------------------------

   Header_Text : constant String :=
     "H Product:Blackbox flight data recorder by Nicholas Sherlock" & ASCII.LF & "H Data version:2" & ASCII.LF;

   procedure Send_Header_Text (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                               S : in out Stream; Now_Ms : Unsigned_32; Done : out Boolean) is
      Status : Reserve_Status;
   begin
      Done := False;
      if Now_Ms > H.Start_Time_Ms + 100 then
         Reserve (W, Target_Budget_Per_Iteration, Status);
         if Status = Reserved then
            for I in 1 .. Target_Budget_Per_Iteration loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
               pragma Loop_Invariant (W.Budget >= Integer_32 (Target_Budget_Per_Iteration - (I - 1)));
               exit when H.Index >= Header_Text'Length;
               Put_Char (W, B, S, Header_Text (Header_Text'First + H.Index));
               W.Budget := W.Budget - 1;
               H.Index := H.Index + 1;
            end loop;
            Done := H.Index >= Header_Text'Length;
         end if;
      end if;
   end Send_Header_Text;

   procedure Send_Field_Definition (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                                    S : in out Stream; T : Header_Table; Wing : Boolean;
                                    Cache : Condition_Set; More : out Boolean) is
      Header_Count : constant Positive := Header_Count_Of (T);
      Count        : constant Field_Count := Field_Count_Of (T, Wing);
      Status       : Reserve_Status;
   begin
      More := True;
      if H.Index >= Header_Count then
         More := False;
         return;
      end if;
      if H.Field = -1 then
         declare
            Name  : constant String := Header_Name (H.Index);
            Bytes : constant Natural := 11 + Name'Length;
         begin
            Reserve (W, Bytes, Status);
            if Status /= Reserved then
               return;
            end if;
            Put_String (W, B, S, "H Field ");
            Put_Char (W, B, S, (if H.Index >= 4 then 'P' else Main_Char (T)));
            Put_Char (W, B, S, ' ');
            Put_String (W, B, S, Name);
            Put_Char (W, B, S, ':');
            W.Budget := W.Budget - Integer_32 (Bytes);
         end;
         H.Field := 0;
         H.Need_Comma := False;
      end if;
      while H.Field < Count loop
         pragma Loop_Invariant (H.Field in 0 .. Count - 1);
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
         pragma Loop_Invariant (H.Index < Header_Count);
         declare
            F     : constant Field_Definition := Field_Of (T, Wing, H.Field);
            Bytes : Natural;
            Digit_Count : Natural;
         begin
            if not Is_Conditional (T) or else Cache (F.Cond) then
               Bytes := 1 + (if H.Index = 0 then Name_Text (F.Name)'Length + 4 else 2);
               Reserve (W, Bytes, Status);
               if Status /= Reserved then
                  return;
               end if;
               W.Budget := W.Budget - Integer_32 (Bytes);
               if H.Need_Comma then
                  Put_Char (W, B, S, ',');
               else
                  H.Need_Comma := True;
               end if;
               if H.Index = 0 then
                  Put_String (W, B, S, Name_Text (F.Name));
                  if F.Index /= -1 then
                     Put_Char (W, B, S, '[');
                     Put_Decimal (W, B, S, Integer_32 (F.Index), Digit_Count);
                     pragma Assert (Digit_Count >= 1);
                     Put_Char (W, B, S, ']');
                  end if;
               else
                  Put_Decimal (W, B, S, Integer_32 (Attribute (F, H.Index)), Digit_Count);
                  pragma Assert (Digit_Count >= 1);
               end if;
            end if;
         end;
         H.Field := H.Field + 1;
      end loop;
      Reserve (W, 1, Status);
      if Status = Reserved then
         W.Budget := W.Budget - 1;
         Put_Char (W, B, S, ASCII.LF);
         H.Index := H.Index + 1;
         H.Field := -1;
      end if;
      More := H.Index < Header_Count;
   end Send_Field_Definition;

   --  A header line: "H ", the label, ':', the values the caller writes
   --  between Line_Start and Line_End, and the line feed, charged to the
   --  budget by their lengths.
   procedure Line_Start (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String)
     with Pre  => Fits (S, B) and then Name'Length <= 64,
          Post => Fits (S, B) and then S.Last = S.Last'Old and then Same_Device (W, W'Old)
   is
   begin
      Put_Char (W, B, S, 'H');
      Put_Char (W, B, S, ' ');
      Put_String (W, B, S, Name);
      Put_Char (W, B, S, ':');
   end Line_Start;

   procedure Line_End (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name_Length : Natural;
                       Written : Natural)
     with Pre  => Fits (S, B) and then Name_Length <= 64 and then Written <= 160
                  and then W.Budget >= Target_Budget_Per_Iteration,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Put_Char (W, B, S, ASCII.LF);
      W.Budget := W.Budget - Integer_32 (Name_Length + Written + 4);
   end Line_End;

   procedure Line_Decimal (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String;
                           V : Integer_32)
     with Pre  => Fits (S, B) and then Name'Length <= 64 and then W.Budget >= Target_Budget_Per_Iteration,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Count : Natural;
   begin
      Line_Start (W, B, S, Name);
      Put_Decimal (W, B, S, V, Count);
      Line_End (W, B, S, Name'Length, Count);
   end Line_Decimal;

   procedure Line_Unsigned (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String;
                            V : Integer_32)
     with Pre  => Fits (S, B) and then Name'Length <= 64 and then W.Budget >= Target_Budget_Per_Iteration,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Count : Natural;
   begin
      Line_Start (W, B, S, Name);
      Put_Unsigned (W, B, S, Unsigned_32'Mod (V), Count);
      Line_End (W, B, S, Name'Length, Count);
   end Line_Unsigned;

   --  Two or three values separated by commas, in decimal or unsigned.
   procedure Line_Values (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String;
                          Info : Sysinfo; First : Value_Name; Count : Positive; Unsigned : Boolean)
     with Pre  => Fits (S, B) and then Name'Length <= 64 and then W.Budget >= Target_Budget_Per_Iteration
                  and then Count <= 3 and then Value_Name'Pos (First) + Count - 1 <= Value_Name'Pos (Value_Name'Last),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Written : Natural := 0;
      Width   : Natural;
   begin
      Line_Start (W, B, S, Name);
      for I in 0 .. Count - 1 loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry and then Same_Device (W, W'Loop_Entry));
         pragma Loop_Invariant (Written <= I * (Adaflight.Text.Max_Digits + 1));
         declare
            V : constant Integer_32 := Info.Values (Value_Name'Val (Value_Name'Pos (First) + I));
         begin
            if I > 0 then
               Put_Char (W, B, S, ',');
               Written := Written + 1;
            end if;
            if Unsigned then
               Put_Unsigned (W, B, S, Unsigned_32'Mod (V), Width);
            else
               Put_Decimal (W, B, S, V, Width);
            end if;
            Written := Written + Width;
         end;
      end loop;
      Line_End (W, B, S, Name'Length, Written);
   end Line_Values;

   procedure Line_Text (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String; T : Text)
     with Pre  => Fits (S, B) and then Name'Length <= 64 and then W.Budget >= Target_Budget_Per_Iteration,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Line_Start (W, B, S, Name);
      Put_Text (W, B, S, T);
      Line_End (W, B, S, Name'Length, T.Length);
   end Line_Text;

   procedure Line_String (W : in out Writer; B : in out Byte_Array; S : in out Stream; Name : String;
                          Value : String)
     with Pre  => Fits (S, B) and then Name'Length <= 64 and then Value'Length <= 32
                  and then W.Budget >= Target_Budget_Per_Iteration,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Line_Start (W, B, S, Name);
      Put_String (W, B, S, Value);
      Line_End (W, B, S, Name'Length, Value'Length);
   end Line_String;

   procedure Send_Sysinfo (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                           S : in out Stream; Wing : Boolean; Info : Sysinfo; Cache : Condition_Set;
                           Current_Meter : Adaflight.Battery.Current_Source; Done : out Boolean) is
      Status : Reserve_Status;
   begin
      Done := False;
      Reserve (W, Target_Budget_Per_Iteration, Status);
      if Status /= Reserved then
         return;
      end if;
      if H.Index >= Line_Count_Of (Wing) then
         Done := True;
         return;
      end if;
      declare
         Item  : constant Line := Line_Of (Wing, H.Index);
         Name  : constant String := Label (Item.First);
         Texts : Text_Table renames Info.Texts;
      begin
         case Item.Format is
            when One_Decimal =>
               Line_Decimal (W, B, S, Name, Info.Values (Item.First));
            when One_Unsigned =>
               Line_Unsigned (W, B, S, Name, Info.Values (Item.First));
            when Two_Decimal =>
               Line_Values (W, B, S, Name, Info, Item.First, 2, False);
            when Three_Decimal =>
               Line_Values (W, B, S, Name, Info, Item.First, 3, False);
            when Three_Unsigned =>
               Line_Values (W, B, S, Name, Info, Item.First, 3, True);
            when Gyro_Scale_Line =>
               Line_String (W, B, S, "gyro_scale", "0x3f800000");
            when Device_UID_Line =>
               Line_Start (W, B, S, "DeviceUID");
               Put_Hex_8 (W, B, S, Unsigned_32'Mod (Info.Values (Device_UID_0)));
               Put_Hex_8 (W, B, S, Unsigned_32'Mod (Info.Values (Device_UID_1)));
               Put_Hex_8 (W, B, S, Unsigned_32'Mod (Info.Values (Device_UID_2)));
               Line_End (W, B, S, 9, 24);
            when Firmware_Type_Line =>
               Line_Text (W, B, S, "Firmware type", Texts (Firmware_Type));
            when Firmware_Revision_Line =>
               Line_Start (W, B, S, "Firmware revision");
               Put_Text (W, B, S, Texts (Firmware_Name));
               Put_Char (W, B, S, ' ');
               Put_Text (W, B, S, Texts (Firmware_Version));
               Put_String (W, B, S, " (");
               Put_Text (W, B, S, Texts (Git_Revision));
               Put_String (W, B, S, ") ");
               Put_Text (W, B, S, Texts (Target_Name));
               Line_End (W, B, S, 17, Texts (Firmware_Name).Length + Texts (Firmware_Version).Length
                                      + Texts (Git_Revision).Length + Texts (Target_Name).Length + 5);
            when Firmware_Date_Line =>
               Line_Start (W, B, S, "Firmware date");
               Put_Text (W, B, S, Texts (Build_Date));
               Put_Char (W, B, S, ' ');
               Put_Text (W, B, S, Texts (Build_Time));
               Line_End (W, B, S, 13, Texts (Build_Date).Length + Texts (Build_Time).Length + 1);
            when Build_Key_Line =>
               Line_Text (W, B, S, "Build key", Texts (Build_Key));
            when Release_Name_Line =>
               Line_Text (W, B, S, "Release name", Texts (Release_Name));
            when Board_Information_Line =>
               Line_Start (W, B, S, "Board information");
               Put_Text (W, B, S, Texts (Manufacturer_Id));
               Put_Char (W, B, S, ' ');
               Put_Text (W, B, S, Texts (Board_Name));
               Line_End (W, B, S, 17, Texts (Manufacturer_Id).Length + Texts (Board_Name).Length + 1);
            when Start_Date_Time_Line =>
               Line_Text (W, B, S, "Log start datetime", Texts (Start_Date_Time));
            when Craft_Name_Line =>
               Line_Text (W, B, S, "Craft name", Texts (Craft_Name));
            when Mixer_Type_Line =>
               Line_String (W, B, S, "mixer_type", Mixer_Type_Name (Info.Values (Mixer_Type)));
            when Debug_Mode_Name_Line =>
               Line_Text (W, B, S, "debug_mode_name", Texts (Debug_Mode_Name));
            when P_Ratio_Line =>
               declare
                  Ratio : Integer_32 := 0;
               begin
                  if Info.Values (P_Interval) /= 0 then
                     Ratio := Integer_32 (Interfaces.Unsigned_16'Mod
                                            (Interfaces.Integer_64 (Info.Values (I_Interval))
                                             / Interfaces.Integer_64 (Info.Values (P_Interval))));
                  end if;
                  Line_Decimal (W, B, S, "P ratio", Ratio);
               end;
            when Gyro_Sync_Denom_Line =>
               Line_Decimal (W, B, S, "gyro_sync_denom", 1);
            when VBat_Scale_Line =>
               if Cache (VBat) then
                  Line_Unsigned (W, B, S, "vbat_scale", Info.Values (VBat_Scale));
               else
                  H.Index := H.Index + 2;
               end if;
            when Current_Sensor_Line =>
               if Current_Meter = Adaflight.Battery.Analog then
                  Line_Values (W, B, S, "currentSensor", Info, Current_Offset, 2, False);
               end if;
         end case;
      end;
      H.Index := H.Index + 1;
   end Send_Sysinfo;

end Adaflight.Blackbox_Header;
