with Adaflight.Settings_Table;
with Adaflight.Text;

package body Adaflight.Blackbox_Header with SPARK_Mode is
   use type Interfaces.Integer_64;

   --  The field names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Field_Name_Pool_Length : constant := 345;
   Field_Name_Text : constant String (1 .. Field_Name_Pool_Length + 21) :=
     "loopIterationtimeaxisPaxisIaxisDaxisFaxisSrcCommandsetpointvbatLatestamperageLatestmagADCbaroAltsurfaceR"
     & "awrssipitotgyroADCgyroUnfiltaccSmoothimuQuaterniondebugmotorservoeRPMGPS_numSatGPS_coordGPS_altitudeGPS_"
     & "speedGPS_ground_courseGPS_velnedGPS_timeGPS_homeGPS_home_epochflightModeFlagsstateFlagsfailsafePhaserxSi"
     & "gnalReceivedrxFlightChannelsValid                     ";
   type Field_Name_Start is range 0 .. Field_Name_Pool_Length;
   type Field_Name_Length is range 4 .. 21;
   Field_Name_Starts : constant array (Field_Name) of Field_Name_Start :=
     (Loop_Iteration => 0, Time => 13, Axis_P => 17, Axis_I => 22, Axis_D => 27, Axis_F => 32, Axis_S => 37,
      RC_Command => 42, Setpoint_Field => 51, VBat_Latest => 59, Amperage_Latest => 69, Mag_ADC => 83,
      Baro_Alt => 89, Surface_Raw => 96, RSSI_Field => 106, Pitot_Field => 110, Gyro_ADC => 115,
      Gyro_Unfilt_Field => 122, Acc_Smooth => 132, IMU_Quaternion => 141, Debug_Field => 154, Motor => 159,
      Servo => 164, ERPM => 169, GPS_Num_Sat => 173, GPS_Coord => 183, GPS_Altitude => 192, GPS_Speed => 204,
      GPS_Ground_Course => 213, GPS_Vel_NED => 230, GPS_Time => 240, GPS_Home => 248, GPS_Home_Epoch => 256,
      Flight_Mode_Flags => 270, State_Flags => 285, Failsafe_Phase => 295, RX_Signal_Received => 308,
      RX_Flight_Channels_Valid => 324);
   Field_Name_Lengths : constant array (Field_Name) of Field_Name_Length :=
     (Loop_Iteration => 13, Time => 4, Axis_P => 5, Axis_I => 5, Axis_D => 5, Axis_F => 5, Axis_S => 5,
      RC_Command => 9, Setpoint_Field => 8, VBat_Latest => 10, Amperage_Latest => 14, Mag_ADC => 6, Baro_Alt => 7,
      Surface_Raw => 10, RSSI_Field => 4, Pitot_Field => 5, Gyro_ADC => 7, Gyro_Unfilt_Field => 10, Acc_Smooth => 9,
      IMU_Quaternion => 13, Debug_Field => 5, Motor => 5, Servo => 5, ERPM => 4, GPS_Num_Sat => 10, GPS_Coord => 9,
      GPS_Altitude => 12, GPS_Speed => 9, GPS_Ground_Course => 17, GPS_Vel_NED => 10, GPS_Time => 8, GPS_Home => 8,
      GPS_Home_Epoch => 14, Flight_Mode_Flags => 15, State_Flags => 10, Failsafe_Phase => 13,
      RX_Signal_Received => 16, RX_Flight_Channels_Valid => 21);

   function Name_Text (N : Field_Name) return String is
     (Field_Name_Text (Natural (Field_Name_Starts (N)) + 1
                       .. Natural (Field_Name_Starts (N)) + Natural (Field_Name_Lengths (N))));

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

   --  The labels that are no setting's name in one text, each at its start for its length. The text ends
   --  with room for a longest one, so every slice stays within it by its types.
   Label_Pool_Length : constant := 824;
   Label_Text : constant String (1 .. Label_Pool_Length + 37) :=
     "I intervalP intervalmaxthrottlemotorOutputacc_1GvbatcellvoltagevbatrefcurrentSensorlooptimespa_roll_cent"
     & "erspa_roll_widthspa_roll_modespa_pitch_centerspa_pitch_widthspa_pitch_modespa_yaw_centerspa_yaw_widthspa"
     & "_yaw_modetpa_curve_typetpa_curve_stall_throttletpa_curve_pid_thr0tpa_curve_pid_thr100tpa_curve_exporc_ra"
     & "tesrc_exporate_limitsrollPIDpitchPIDyawPIDlevelPIDd_maxdterm_lpf1_dyn_hzff_weights_rolls_pitchs_yawgyro_"
     & "lpf1_dyn_hzgyro_notch_hzgyro_notch_cutoffgyro_enabled_bitmaskgyro_debug_axisairmode_activate_throttlefea"
     & "turesrc_smoothing_active_cutoffs_ff_sp_thrrc_smoothing_rx_smoothedfields_disabled_masktpa_speed_typetpa_"
     & "speed_basic_delaytpa_speed_basic_gravitytpa_speed_adv_prop_pitchtpa_speed_adv_masstpa_speed_adv_drag_ktp"
     & "a_speed_adv_thrusttpa_speed_max_voltagetpa_speed_pitch_offsetyaw_typeangle_pitch_offsetDeviceUID        "
     & "                             ";
   type Label_Start is range 0 .. Label_Pool_Length;
   type Label_Length is range 0 .. 37;
   Label_Starts : constant array (Value_Name) of Label_Start :=
     (I_Interval => 0, P_Interval => 10, Max_Throttle => 20, Motor_Output_Low => 31, Acc_1G => 42,
      VBat_Min_Cell => 48, VBat_Reference => 63, Current_Offset => 70, Loop_Time => 83, SPA_Roll_Center => 91,
      SPA_Roll_Width => 106, SPA_Roll_Mode => 120, SPA_Pitch_Center => 133, SPA_Pitch_Width => 149,
      SPA_Pitch_Mode => 164, SPA_Yaw_Center => 178, SPA_Yaw_Width => 192, SPA_Yaw_Mode => 205,
      TPA_Curve_Type => 217, TPA_Curve_Stall_Throttle => 231, TPA_Curve_PID_Thr0 => 255,
      TPA_Curve_PID_Thr100 => 273, TPA_Curve_Expo => 293, RC_Rate_Roll => 307, RC_Expo_Roll => 315,
      Rate_Roll => 310, Rate_Limit_Roll => 322, Roll_P => 333, Pitch_P => 340, Yaw_P => 348, Level_P => 354,
      D_Max_Roll => 362, DTerm_LPF1_Dyn_Min_Hz => 367, FF_Weight_Roll => 384, S_Roll => 393, S_Pitch => 399,
      S_Yaw => 406, Gyro_LPF1_Dyn_Min_Hz => 411, Gyro_Notch_Hz_1 => 427, Gyro_Notch_Cutoff_1 => 440,
      Gyro_Enabled_Bitmask => 457, Gyro_Debug_Axis => 477, Airmode_Activate_Throttle => 492, Features => 517,
      RC_Smoothing_Setpoint_Cutoff_Frequency => 525, RC_Smoothing_RX_Rate => 562, Fields_Disabled_Mask => 586,
      TPA_Speed_Type => 606, TPA_Speed_Basic_Delay => 620, TPA_Speed_Basic_Gravity => 641,
      TPA_Speed_Adv_Prop_Pitch => 664, TPA_Speed_Adv_Mass => 688, TPA_Speed_Adv_Drag_K => 706,
      TPA_Speed_Adv_Thrust => 726, TPA_Speed_Max_Voltage => 746, TPA_Speed_Pitch_Offset => 767, Yaw_Type => 789,
      Angle_Pitch_Offset => 797, Device_UID_0 => 815, others => 0);
   Label_Lengths : constant array (Value_Name) of Label_Length :=
     (I_Interval => 10, P_Interval => 10, Max_Throttle => 11, Motor_Output_Low => 11, Acc_1G => 6,
      VBat_Min_Cell => 15, VBat_Reference => 7, Current_Offset => 13, Loop_Time => 8, SPA_Roll_Center => 15,
      SPA_Roll_Width => 14, SPA_Roll_Mode => 13, SPA_Pitch_Center => 16, SPA_Pitch_Width => 15,
      SPA_Pitch_Mode => 14, SPA_Yaw_Center => 14, SPA_Yaw_Width => 13, SPA_Yaw_Mode => 12, TPA_Curve_Type => 14,
      TPA_Curve_Stall_Throttle => 24, TPA_Curve_PID_Thr0 => 18, TPA_Curve_PID_Thr100 => 20,
      TPA_Curve_Expo => 14, RC_Rate_Roll => 8, RC_Expo_Roll => 7, Rate_Roll => 5, Rate_Limit_Roll => 11,
      Roll_P => 7, Pitch_P => 8, Yaw_P => 6, Level_P => 8, D_Max_Roll => 5, DTerm_LPF1_Dyn_Min_Hz => 17,
      FF_Weight_Roll => 9, S_Roll => 6, S_Pitch => 7, S_Yaw => 5, Gyro_LPF1_Dyn_Min_Hz => 16,
      Gyro_Notch_Hz_1 => 13, Gyro_Notch_Cutoff_1 => 17, Gyro_Enabled_Bitmask => 20, Gyro_Debug_Axis => 15,
      Airmode_Activate_Throttle => 25, Features => 8, RC_Smoothing_Setpoint_Cutoff_Frequency => 37,
      RC_Smoothing_RX_Rate => 24, Fields_Disabled_Mask => 20, TPA_Speed_Type => 14, TPA_Speed_Basic_Delay => 21,
      TPA_Speed_Basic_Gravity => 23, TPA_Speed_Adv_Prop_Pitch => 24, TPA_Speed_Adv_Mass => 18,
      TPA_Speed_Adv_Drag_K => 20, TPA_Speed_Adv_Thrust => 20, TPA_Speed_Max_Voltage => 21,
      TPA_Speed_Pitch_Offset => 22, Yaw_Type => 8, Angle_Pitch_Offset => 18, Device_UID_0 => 9, others => 0);

   --  The labels that are a setting's name, by the setting plus one, zero for the others.
   type Setting_Ref is range 0 .. Settings_Table.Setting'Pos (Settings_Table.Setting'Last) + 1;
   Label_Settings : constant array (Value_Name) of Setting_Ref :=
     (Motor_KV => Settings_Table.Setting'Pos (Settings_Table.Motor_Kv) + 1,
      VBat_Scale => Settings_Table.Setting'Pos (Settings_Table.Vbat_Scale) + 1,
      PID_Process_Denom => Settings_Table.Setting'Pos (Settings_Table.Pid_Process_Denom) + 1,
      Thr_Mid => Settings_Table.Setting'Pos (Settings_Table.Thr_Mid) + 1,
      Thr_Expo => Settings_Table.Setting'Pos (Settings_Table.Thr_Expo) + 1,
      Thr_Hover => Settings_Table.Setting'Pos (Settings_Table.Thr_Hover) + 1,
      TPA_Mode => Settings_Table.Setting'Pos (Settings_Table.Tpa_Mode) + 1,
      TPA_Rate => Settings_Table.Setting'Pos (Settings_Table.Tpa_Rate) + 1,
      TPA_Breakpoint => Settings_Table.Setting'Pos (Settings_Table.Tpa_Breakpoint) + 1,
      TPA_Low_Rate => Settings_Table.Setting'Pos (Settings_Table.Tpa_Low_Rate) + 1,
      TPA_Low_Breakpoint => Settings_Table.Setting'Pos (Settings_Table.Tpa_Low_Breakpoint) + 1,
      TPA_Low_Always => Settings_Table.Setting'Pos (Settings_Table.Tpa_Low_Always) + 1,
      Mixer_Type => Settings_Table.Setting'Pos (Settings_Table.Mixer_Type) + 1,
      EZ_Landing_Threshold => Settings_Table.Setting'Pos (Settings_Table.Ez_Landing_Threshold) + 1,
      EZ_Landing_Limit => Settings_Table.Setting'Pos (Settings_Table.Ez_Landing_Limit) + 1,
      EZ_Landing_Speed => Settings_Table.Setting'Pos (Settings_Table.Ez_Landing_Speed) + 1,
      Landing_Disarm_Threshold => Settings_Table.Setting'Pos (Settings_Table.Landing_Disarm_Threshold) + 1,
      D_Max_Gain => Settings_Table.Setting'Pos (Settings_Table.D_Max_Gain) + 1,
      D_Max_Advance => Settings_Table.Setting'Pos (Settings_Table.D_Max_Advance) + 1,
      DTerm_LPF1_Type => Settings_Table.Setting'Pos (Settings_Table.Dterm_Lpf1_Type) + 1,
      DTerm_LPF1_Static_Hz => Settings_Table.Setting'Pos (Settings_Table.Dterm_Lpf1_Static_Hz) + 1,
      DTerm_LPF1_Dyn_Expo => Settings_Table.Setting'Pos (Settings_Table.Dterm_Lpf1_Dyn_Expo) + 1,
      DTerm_LPF2_Type => Settings_Table.Setting'Pos (Settings_Table.Dterm_Lpf2_Type) + 1,
      DTerm_LPF2_Static_Hz => Settings_Table.Setting'Pos (Settings_Table.Dterm_Lpf2_Static_Hz) + 1,
      Yaw_Lowpass_Hz => Settings_Table.Setting'Pos (Settings_Table.Yaw_Lowpass_Hz) + 1,
      DTerm_Notch_Hz => Settings_Table.Setting'Pos (Settings_Table.Dterm_Notch_Hz) + 1,
      DTerm_Notch_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Dterm_Notch_Cutoff) + 1,
      ITerm_Windup => Settings_Table.Setting'Pos (Settings_Table.Iterm_Windup) + 1,
      ITerm_Relax => Settings_Table.Setting'Pos (Settings_Table.Iterm_Relax) + 1,
      ITerm_Relax_Type => Settings_Table.Setting'Pos (Settings_Table.Iterm_Relax_Type) + 1,
      ITerm_Relax_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Iterm_Relax_Cutoff) + 1,
      PID_At_Min_Throttle => Settings_Table.Setting'Pos (Settings_Table.Pid_At_Min_Throttle) + 1,
      Anti_Gravity_Gain => Settings_Table.Setting'Pos (Settings_Table.Anti_Gravity_Gain) + 1,
      Anti_Gravity_Cutoff_Hz => Settings_Table.Setting'Pos (Settings_Table.Anti_Gravity_Cutoff_Hz) + 1,
      Anti_Gravity_P_Gain => Settings_Table.Setting'Pos (Settings_Table.Anti_Gravity_P_Gain) + 1,
      Feedforward_Transition => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Transition) + 1,
      Feedforward_Averaging => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Averaging) + 1,
      Feedforward_Smooth_Factor => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Smooth_Factor) + 1,
      Feedforward_Jitter_Factor => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Jitter_Factor) + 1,
      Feedforward_Boost => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Boost) + 1,
      Feedforward_Max_Rate_Limit => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Max_Rate_Limit) + 1,
      Angle_Feedforward => Settings_Table.Setting'Pos (Settings_Table.Angle_Feedforward) + 1,
      Angle_FF_Smoothing_Ms => Settings_Table.Setting'Pos (Settings_Table.Angle_Feedforward_Smoothing_Ms) + 1,
      Feedforward_Yaw_Hold_Gain => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Yaw_Hold_Gain) + 1,
      Feedforward_Yaw_Hold_Time => Settings_Table.Setting'Pos (Settings_Table.Feedforward_Yaw_Hold_Time) + 1,
      Angle_Limit => Settings_Table.Setting'Pos (Settings_Table.Angle_Limit) + 1,
      Angle_Earth_Ref => Settings_Table.Setting'Pos (Settings_Table.Angle_Earth_Ref) + 1,
      Horizon_Limit_Degrees => Settings_Table.Setting'Pos (Settings_Table.Horizon_Limit_Degrees) + 1,
      Horizon_Delay_Ms => Settings_Table.Setting'Pos (Settings_Table.Horizon_Delay_Ms) + 1,
      Acc_Limit_Yaw => Settings_Table.Setting'Pos (Settings_Table.Acc_Limit_Yaw) + 1,
      Acc_Limit => Settings_Table.Setting'Pos (Settings_Table.Acc_Limit) + 1,
      PID_Sum_Limit => Settings_Table.Setting'Pos (Settings_Table.Pidsum_Limit) + 1,
      PID_Sum_Limit_Yaw => Settings_Table.Setting'Pos (Settings_Table.Pidsum_Limit_Yaw) + 1,
      Chirp_Lag_Freq_Hz => Settings_Table.Setting'Pos (Settings_Table.Chirp_Lag_Freq_Hz) + 1,
      Chirp_Lead_Freq_Hz => Settings_Table.Setting'Pos (Settings_Table.Chirp_Lead_Freq_Hz) + 1,
      Chirp_Amplitude_Roll => Settings_Table.Setting'Pos (Settings_Table.Chirp_Amplitude_Roll) + 1,
      Chirp_Amplitude_Pitch => Settings_Table.Setting'Pos (Settings_Table.Chirp_Amplitude_Pitch) + 1,
      Chirp_Amplitude_Yaw => Settings_Table.Setting'Pos (Settings_Table.Chirp_Amplitude_Yaw) + 1,
      Chirp_Frequency_Start_Deci_Hz => Settings_Table.Setting'Pos (Settings_Table.Chirp_Frequency_Start_Deci_Hz) + 1,
      Chirp_Frequency_End_Deci_Hz => Settings_Table.Setting'Pos (Settings_Table.Chirp_Frequency_End_Deci_Hz) + 1,
      Chirp_Time_Seconds => Settings_Table.Setting'Pos (Settings_Table.Chirp_Time_Seconds) + 1,
      Deadband => Settings_Table.Setting'Pos (Settings_Table.Deadband) + 1,
      Yaw_Deadband => Settings_Table.Setting'Pos (Settings_Table.Yaw_Deadband) + 1,
      Gyro_Hardware_LPF => Settings_Table.Setting'Pos (Settings_Table.Gyro_Hardware_Lpf) + 1,
      Gyro_LPF1_Type => Settings_Table.Setting'Pos (Settings_Table.Gyro_Lpf1_Type) + 1,
      Gyro_LPF1_Static_Hz => Settings_Table.Setting'Pos (Settings_Table.Gyro_Lpf1_Static_Hz) + 1,
      Gyro_LPF1_Dyn_Expo => Settings_Table.Setting'Pos (Settings_Table.Gyro_Lpf1_Dyn_Expo) + 1,
      Gyro_LPF2_Type => Settings_Table.Setting'Pos (Settings_Table.Gyro_Lpf2_Type) + 1,
      Gyro_LPF2_Static_Hz => Settings_Table.Setting'Pos (Settings_Table.Gyro_Lpf2_Static_Hz) + 1,
      Dyn_Notch_Max_Hz => Settings_Table.Setting'Pos (Settings_Table.Dyn_Notch_Max_Hz) + 1,
      Dyn_Notch_Count => Settings_Table.Setting'Pos (Settings_Table.Dyn_Notch_Count) + 1,
      Dyn_Notch_Q => Settings_Table.Setting'Pos (Settings_Table.Dyn_Notch_Q) + 1,
      Dyn_Notch_Min_Hz => Settings_Table.Setting'Pos (Settings_Table.Dyn_Notch_Min_Hz) + 1,
      DShot_Bidir => Settings_Table.Setting'Pos (Settings_Table.Dshot_Bidir) + 1,
      Motor_Poles => Settings_Table.Setting'Pos (Settings_Table.Motor_Poles) + 1,
      RPM_Filter_Harmonics => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Harmonics) + 1,
      RPM_Filter_Weight_1 => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Weights) + 1,
      RPM_Filter_Q => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Q) + 1,
      RPM_Filter_Min_Hz => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Min_Hz) + 1,
      RPM_Filter_Fade_Range_Hz => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Fade_Range_Hz) + 1,
      RPM_Filter_LPF_Hz => Settings_Table.Setting'Pos (Settings_Table.Rpm_Filter_Lpf_Hz) + 1,
      Acc_LPF_Hz_Hundredths => Settings_Table.Setting'Pos (Settings_Table.Acc_Lpf_Hz) + 1,
      Acc_Hardware => Settings_Table.Setting'Pos (Settings_Table.Acc_Hardware) + 1,
      Baro_Hardware => Settings_Table.Setting'Pos (Settings_Table.Baro_Hardware) + 1,
      Baro_Drift => Settings_Table.Setting'Pos (Settings_Table.Baro_Drift) + 1,
      Altitude_Source => Settings_Table.Setting'Pos (Settings_Table.Altitude_Source) + 1,
      Altitude_Prefer_Baro => Settings_Table.Setting'Pos (Settings_Table.Altitude_Prefer_Baro) + 1,
      Altitude_LPF => Settings_Table.Setting'Pos (Settings_Table.Altitude_Lpf) + 1,
      Altitude_D_LPF => Settings_Table.Setting'Pos (Settings_Table.Altitude_D_Lpf) + 1,
      AP_Landing_Altitude_M => Settings_Table.Setting'Pos (Settings_Table.Ap_Landing_Altitude_M) + 1,
      AP_Hover_Throttle => Settings_Table.Setting'Pos (Settings_Table.Ap_Hover_Throttle) + 1,
      AP_Throttle_Min => Settings_Table.Setting'Pos (Settings_Table.Ap_Throttle_Min) + 1,
      AP_Throttle_Max => Settings_Table.Setting'Pos (Settings_Table.Ap_Throttle_Max) + 1,
      AP_Altitude_P => Settings_Table.Setting'Pos (Settings_Table.Ap_Altitude_P) + 1,
      AP_Altitude_I => Settings_Table.Setting'Pos (Settings_Table.Ap_Altitude_I) + 1,
      AP_Altitude_D => Settings_Table.Setting'Pos (Settings_Table.Ap_Altitude_D) + 1,
      AP_Altitude_A => Settings_Table.Setting'Pos (Settings_Table.Ap_Altitude_A) + 1,
      AP_Altitude_F => Settings_Table.Setting'Pos (Settings_Table.Ap_Altitude_F) + 1,
      AP_Position_P => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_P) + 1,
      AP_Position_I => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_I) + 1,
      AP_Position_D => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_D) + 1,
      AP_Position_A => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_A) + 1,
      AP_Position_F => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_F) + 1,
      AP_Position_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Ap_Position_Cutoff) + 1,
      AP_Stop_Threshold => Settings_Table.Setting'Pos (Settings_Table.Ap_Stop_Threshold) + 1,
      AP_Max_Angle => Settings_Table.Setting'Pos (Settings_Table.Ap_Max_Angle) + 1,
      AP_Max_Yaw_Rate => Settings_Table.Setting'Pos (Settings_Table.Ap_Max_Yaw_Rate) + 1,
      AP_Yaw_P => Settings_Table.Setting'Pos (Settings_Table.Ap_Yaw_P) + 1,
      Mag_Hardware => Settings_Table.Setting'Pos (Settings_Table.Mag_Hardware) + 1,
      Opticalflow_Hardware => Settings_Table.Setting'Pos (Settings_Table.Opticalflow_Hardware) + 1,
      Opticalflow_Rotation => Settings_Table.Setting'Pos (Settings_Table.Opticalflow_Rotation) + 1,
      Opticalflow_Flip_X => Settings_Table.Setting'Pos (Settings_Table.Opticalflow_Flip_X) + 1,
      Gyro_Cal_On_First_Arm => Settings_Table.Setting'Pos (Settings_Table.Gyro_Cal_On_First_Arm) + 1,
      Serial_RX_Provider => Settings_Table.Setting'Pos (Settings_Table.Serialrx_Provider) + 1,
      Use_Unsynced_PWM => Settings_Table.Setting'Pos (Settings_Table.Use_Unsynced_Pwm) + 1,
      Motor_PWM_Protocol => Settings_Table.Setting'Pos (Settings_Table.Motor_Pwm_Protocol) + 1,
      Motor_PWM_Rate => Settings_Table.Setting'Pos (Settings_Table.Motor_Pwm_Rate) + 1,
      Motor_Idle => Settings_Table.Setting'Pos (Settings_Table.Motor_Idle) + 1,
      Debug_Mode => Settings_Table.Setting'Pos (Settings_Table.Debug_Mode) + 1,
      RC_Smoothing => Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing) + 1,
      RC_Smoothing_Auto_Factor => Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing_Auto_Factor) + 1,
      RC_Smoothing_Auto_Factor_Throttle =>
        Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing_Auto_Factor_Throttle) + 1,
      RC_Smoothing_Setpoint_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing_Setpoint_Cutoff) + 1,
      RC_Smoothing_Throttle_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing_Throttle_Cutoff) + 1,
      RC_Smoothing_Debug_Axis => Settings_Table.Setting'Pos (Settings_Table.Rc_Smoothing_Debug_Axis) + 1,
      Rates_Type => Settings_Table.Setting'Pos (Settings_Table.Rates_Type) + 1,
      High_Resolution => Settings_Table.Setting'Pos (Settings_Table.Blackbox_High_Resolution) + 1,
      VBat_Sag_Compensation => Settings_Table.Setting'Pos (Settings_Table.Vbat_Sag_Compensation) + 1,
      Dyn_Idle_Min_RPM => Settings_Table.Setting'Pos (Settings_Table.Dyn_Idle_Min_Rpm) + 1,
      Dyn_Idle_P_Gain => Settings_Table.Setting'Pos (Settings_Table.Dyn_Idle_P_Gain) + 1,
      Dyn_Idle_I_Gain => Settings_Table.Setting'Pos (Settings_Table.Dyn_Idle_I_Gain) + 1,
      Dyn_Idle_D_Gain => Settings_Table.Setting'Pos (Settings_Table.Dyn_Idle_D_Gain) + 1,
      Dyn_Idle_Max_Increase => Settings_Table.Setting'Pos (Settings_Table.Dyn_Idle_Max_Increase) + 1,
      Simplified_PIDs_Mode => Settings_Table.Setting'Pos (Settings_Table.Simplified_Pids_Mode) + 1,
      Simplified_Master_Multiplier => Settings_Table.Setting'Pos (Settings_Table.Simplified_Master_Multiplier) + 1,
      Simplified_I_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_I_Gain) + 1,
      Simplified_D_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_D_Gain) + 1,
      Simplified_PI_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_Pi_Gain) + 1,
      Simplified_D_Max_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_D_Max_Gain) + 1,
      Simplified_Feedforward_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_Feedforward_Gain) + 1,
      Simplified_Pitch_D_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_Pitch_D_Gain) + 1,
      Simplified_Pitch_PI_Gain => Settings_Table.Setting'Pos (Settings_Table.Simplified_Pitch_Pi_Gain) + 1,
      Simplified_DTerm_Filter => Settings_Table.Setting'Pos (Settings_Table.Simplified_Dterm_Filter) + 1,
      Simplified_DTerm_Filter_Multiplier =>
        Settings_Table.Setting'Pos (Settings_Table.Simplified_Dterm_Filter_Multiplier) + 1,
      Simplified_Gyro_Filter => Settings_Table.Setting'Pos (Settings_Table.Simplified_Gyro_Filter) + 1,
      Simplified_Gyro_Filter_Multiplier =>
        Settings_Table.Setting'Pos (Settings_Table.Simplified_Gyro_Filter_Multiplier) + 1,
      Motor_Output_Limit => Settings_Table.Setting'Pos (Settings_Table.Motor_Output_Limit) + 1,
      Throttle_Limit_Type => Settings_Table.Setting'Pos (Settings_Table.Throttle_Limit_Type) + 1,
      Throttle_Limit_Percent => Settings_Table.Setting'Pos (Settings_Table.Throttle_Limit_Percent) + 1,
      Throttle_Boost => Settings_Table.Setting'Pos (Settings_Table.Throttle_Boost) + 1,
      Throttle_Boost_Cutoff => Settings_Table.Setting'Pos (Settings_Table.Throttle_Boost_Cutoff) + 1,
      Thrust_Linearization => Settings_Table.Setting'Pos (Settings_Table.Thrust_Linear) + 1,
      GPS_Provider => Settings_Table.Setting'Pos (Settings_Table.Gps_Provider) + 1,
      GPS_Set_Home_Point_Once => Settings_Table.Setting'Pos (Settings_Table.Gps_Set_Home_Point_Once) + 1,
      GPS_Use_3D_Speed => Settings_Table.Setting'Pos (Settings_Table.Gps_Use_3d_Speed) + 1,
      GPS_Rescue_Min_Start_Dist => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Min_Start_Dist) + 1,
      GPS_Rescue_Alt_Mode => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Alt_Mode) + 1,
      GPS_Rescue_Initial_Climb => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Initial_Climb) + 1,
      GPS_Rescue_Ascend_Rate => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Ascend_Rate) + 1,
      GPS_Rescue_Return_Alt => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Return_Alt) + 1,
      GPS_Rescue_Ground_Speed => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Ground_Speed) + 1,
      GPS_Rescue_Descent_Dist => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Descent_Dist) + 1,
      GPS_Rescue_Descend_Rate => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Descend_Rate) + 1,
      GPS_Rescue_Sanity_Checks => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Sanity_Checks) + 1,
      GPS_Rescue_Min_Sats => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Min_Sats) + 1,
      GPS_Rescue_Allow_Arming_Without_Fix =>
        Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Allow_Arming_Without_Fix) + 1,
      GPS_Rescue_Yaw_P => Settings_Table.Setting'Pos (Settings_Table.Gps_Rescue_Yaw_P) + 1,
      Alt_Hold_Climb_Rate => Settings_Table.Setting'Pos (Settings_Table.Alt_Hold_Climb_Rate) + 1,
      Alt_Hold_Deadband => Settings_Table.Setting'Pos (Settings_Table.Alt_Hold_Deadband) + 1,
      Pos_Hold_Deadband => Settings_Table.Setting'Pos (Settings_Table.Pos_Hold_Deadband) + 1, others => 0);

   function Label (V : Value_Name) return String is
     (if Label_Settings (V) = 0
      then Label_Text (Natural (Label_Starts (V)) + 1 .. Natural (Label_Starts (V)) + Natural (Label_Lengths (V)))
      else Settings_Table.Name (Settings_Table.Setting'Val (Label_Settings (V) - 1)));

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
