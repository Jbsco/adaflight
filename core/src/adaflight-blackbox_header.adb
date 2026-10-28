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

   --  The labels in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Label_Pool_Length : constant := 3777;
   Label_Text : constant String (1 .. Label_Pool_Length + 37) :=
     "I intervalP intervalmaxthrottlemotorOutputmotor_kvacc_1Gvbat_scalevbatcellvoltagevbatrefcurrentSensorloo"
     & "ptimepid_process_denomthr_midthr_expothr_hovertpa_modetpa_ratetpa_breakpointtpa_low_ratetpa_low_breakpoi"
     & "nttpa_low_alwaysmixer_typeez_landing_thresholdez_landing_limitez_landing_speedlanding_disarm_thresholdsp"
     & "a_roll_centerspa_roll_widthspa_roll_modespa_pitch_centerspa_pitch_widthspa_pitch_modespa_yaw_centerspa_y"
     & "aw_widthspa_yaw_modetpa_curve_typetpa_curve_stall_throttletpa_curve_pid_thr0tpa_curve_pid_thr100tpa_curv"
     & "e_exporc_ratesrc_exporate_limitsrollPIDpitchPIDyawPIDlevelPIDd_maxd_max_gaind_max_advancedterm_lpf1_type"
     & "dterm_lpf1_static_hzdterm_lpf1_dyn_hzdterm_lpf1_dyn_expodterm_lpf2_typedterm_lpf2_static_hzyaw_lowpass_h"
     & "zdterm_notch_hzdterm_notch_cutoffiterm_windupiterm_relaxiterm_relax_typeiterm_relax_cutoffpid_at_min_thr"
     & "ottleanti_gravity_gainanti_gravity_cutoff_hzanti_gravity_p_gainff_weightfeedforward_transitionfeedforwar"
     & "d_averagingfeedforward_smooth_factorfeedforward_jitter_factorfeedforward_boostfeedforward_max_rate_limit"
     & "angle_feedforwardangle_feedforward_smoothing_msfeedforward_yaw_hold_gainfeedforward_yaw_hold_timeangle_l"
     & "imitangle_earth_refhorizon_limit_degreeshorizon_delay_msacc_limit_yawpidsum_limitpidsum_limit_yaws_rolls"
     & "_pitchs_yawchirp_lag_freq_hzchirp_lead_freq_hzchirp_amplitude_rollchirp_amplitude_pitchchirp_amplitude_y"
     & "awchirp_frequency_start_deci_hzchirp_frequency_end_deci_hzchirp_time_secondsdeadbandyaw_deadbandgyro_har"
     & "dware_lpfgyro_lpf1_typegyro_lpf1_static_hzgyro_lpf1_dyn_hzgyro_lpf1_dyn_expogyro_lpf2_typegyro_lpf2_stat"
     & "ic_hzgyro_notch_hzgyro_notch_cutoffgyro_enabled_bitmaskgyro_debug_axisdyn_notch_max_hzdyn_notch_countdyn"
     & "_notch_qdyn_notch_min_hzdshot_bidirmotor_polesrpm_filter_harmonicsrpm_filter_weightsrpm_filter_qrpm_filt"
     & "er_min_hzrpm_filter_fade_range_hzrpm_filter_lpf_hzacc_lpf_hzacc_hardwarebaro_hardwarebaro_driftaltitude_"
     & "sourcealtitude_prefer_baroaltitude_lpfaltitude_d_lpfap_landing_altitude_map_hover_throttleap_throttle_mi"
     & "nap_throttle_maxap_altitude_pap_altitude_iap_altitude_dap_altitude_aap_altitude_fap_position_pap_positio"
     & "n_iap_position_dap_position_aap_position_fap_position_cutoffap_stop_thresholdap_max_angleap_max_yaw_rate"
     & "ap_yaw_pmag_hardwareopticalflow_hardwareopticalflow_rotationopticalflow_flip_xgyro_cal_on_first_armairmo"
     & "de_activate_throttleserialrx_provideruse_unsynced_pwmmotor_pwm_protocolmotor_pwm_ratemotor_idledebug_mod"
     & "efeaturesrc_smoothingrc_smoothing_auto_factorrc_smoothing_auto_factor_throttlerc_smoothing_setpoint_cuto"
     & "ffrc_smoothing_throttle_cutoffrc_smoothing_debug_axisrc_smoothing_active_cutoffs_ff_sp_thrrc_smoothing_r"
     & "x_smoothedrates_typefields_disabled_maskblackbox_high_resolutionvbat_sag_compensationdyn_idle_min_rpmdyn"
     & "_idle_p_gaindyn_idle_i_gaindyn_idle_d_gaindyn_idle_max_increasesimplified_pids_modesimplified_master_mul"
     & "tipliersimplified_i_gainsimplified_d_gainsimplified_pi_gainsimplified_d_max_gainsimplified_feedforward_g"
     & "ainsimplified_pitch_d_gainsimplified_pitch_pi_gainsimplified_dterm_filtersimplified_dterm_filter_multipl"
     & "iersimplified_gyro_filtersimplified_gyro_filter_multipliermotor_output_limitthrottle_limit_typethrottle_"
     & "limit_percentthrottle_boostthrottle_boost_cutoffthrust_lineargps_providergps_set_home_point_oncegps_use_"
     & "3d_speedgps_rescue_min_start_distgps_rescue_alt_modegps_rescue_initial_climbgps_rescue_ascend_rategps_re"
     & "scue_return_altgps_rescue_ground_speedgps_rescue_descent_distgps_rescue_descend_rategps_rescue_sanity_ch"
     & "ecksgps_rescue_min_satsgps_rescue_allow_arming_without_fixgps_rescue_yaw_palt_hold_climb_ratealt_hold_de"
     & "adbandpos_hold_deadbandtpa_speed_typetpa_speed_basic_delaytpa_speed_basic_gravitytpa_speed_adv_prop_pitc"
     & "htpa_speed_adv_masstpa_speed_adv_drag_ktpa_speed_adv_thrusttpa_speed_max_voltagetpa_speed_pitch_offsetya"
     & "w_typeangle_pitch_offsetDeviceUID                                     ";
   type Label_Start is range 0 .. Label_Pool_Length;
   type Label_Length is range 0 .. 37;
   Label_Starts : constant array (Value_Name) of Label_Start :=
     (I_Interval => 0, P_Interval => 10, Max_Throttle => 20, Motor_Output_Low => 31, Motor_KV => 42, Acc_1G => 50,
      VBat_Scale => 56, VBat_Min_Cell => 66, VBat_Reference => 81, Current_Offset => 88, Loop_Time => 101,
      PID_Process_Denom => 109, Thr_Mid => 126, Thr_Expo => 133, Thr_Hover => 141, TPA_Mode => 150, TPA_Rate => 158,
      TPA_Breakpoint => 166, TPA_Low_Rate => 180, TPA_Low_Breakpoint => 192, TPA_Low_Always => 210,
      Mixer_Type => 224, EZ_Landing_Threshold => 234, EZ_Landing_Limit => 254, EZ_Landing_Speed => 270,
      Landing_Disarm_Threshold => 286, SPA_Roll_Center => 310, SPA_Roll_Width => 325, SPA_Roll_Mode => 339,
      SPA_Pitch_Center => 352, SPA_Pitch_Width => 368, SPA_Pitch_Mode => 383, SPA_Yaw_Center => 397,
      SPA_Yaw_Width => 411, SPA_Yaw_Mode => 424, TPA_Curve_Type => 436, TPA_Curve_Stall_Throttle => 450,
      TPA_Curve_PID_Thr0 => 474, TPA_Curve_PID_Thr100 => 492, TPA_Curve_Expo => 512, RC_Rate_Roll => 526,
      RC_Expo_Roll => 534, Rate_Roll => 529, Rate_Limit_Roll => 541, Roll_P => 552, Pitch_P => 559, Yaw_P => 567,
      Level_P => 573, D_Max_Roll => 581, D_Max_Gain => 586, D_Max_Advance => 596, DTerm_LPF1_Type => 609,
      DTerm_LPF1_Static_Hz => 624, DTerm_LPF1_Dyn_Min_Hz => 644, DTerm_LPF1_Dyn_Expo => 661, DTerm_LPF2_Type => 680,
      DTerm_LPF2_Static_Hz => 695, Yaw_Lowpass_Hz => 715, DTerm_Notch_Hz => 729, DTerm_Notch_Cutoff => 743,
      ITerm_Windup => 761, ITerm_Relax => 773, ITerm_Relax_Type => 784, ITerm_Relax_Cutoff => 800,
      PID_At_Min_Throttle => 818, Anti_Gravity_Gain => 837, Anti_Gravity_Cutoff_Hz => 854,
      Anti_Gravity_P_Gain => 876, FF_Weight_Roll => 895, Feedforward_Transition => 904,
      Feedforward_Averaging => 926, Feedforward_Smooth_Factor => 947, Feedforward_Jitter_Factor => 972,
      Feedforward_Boost => 997, Feedforward_Max_Rate_Limit => 1014, Angle_Feedforward => 1040,
      Angle_FF_Smoothing_Ms => 1057, Feedforward_Yaw_Hold_Gain => 1087, Feedforward_Yaw_Hold_Time => 1112,
      Angle_Limit => 1137, Angle_Earth_Ref => 1148, Horizon_Limit_Degrees => 1163, Horizon_Delay_Ms => 1184,
      Acc_Limit_Yaw => 1200, Acc_Limit => 1200, PID_Sum_Limit => 1213, PID_Sum_Limit_Yaw => 1225, S_Roll => 1241,
      S_Pitch => 1247, S_Yaw => 1254, Chirp_Lag_Freq_Hz => 1259, Chirp_Lead_Freq_Hz => 1276,
      Chirp_Amplitude_Roll => 1294, Chirp_Amplitude_Pitch => 1314, Chirp_Amplitude_Yaw => 1335,
      Chirp_Frequency_Start_Deci_Hz => 1354, Chirp_Frequency_End_Deci_Hz => 1383, Chirp_Time_Seconds => 1410,
      Deadband => 1428, Yaw_Deadband => 1436, Gyro_Hardware_LPF => 1448, Gyro_LPF1_Type => 1465,
      Gyro_LPF1_Static_Hz => 1479, Gyro_LPF1_Dyn_Min_Hz => 1498, Gyro_LPF1_Dyn_Expo => 1514, Gyro_LPF2_Type => 1532,
      Gyro_LPF2_Static_Hz => 1546, Gyro_Notch_Hz_1 => 1565, Gyro_Notch_Cutoff_1 => 1578,
      Gyro_Enabled_Bitmask => 1595, Gyro_Debug_Axis => 1615, Dyn_Notch_Max_Hz => 1630, Dyn_Notch_Count => 1646,
      Dyn_Notch_Q => 1661, Dyn_Notch_Min_Hz => 1672, DShot_Bidir => 1688, Motor_Poles => 1699,
      RPM_Filter_Harmonics => 1710, RPM_Filter_Weight_1 => 1730, RPM_Filter_Q => 1748, RPM_Filter_Min_Hz => 1760,
      RPM_Filter_Fade_Range_Hz => 1777, RPM_Filter_LPF_Hz => 1801, Acc_LPF_Hz_Hundredths => 1818,
      Acc_Hardware => 1828, Baro_Hardware => 1840, Baro_Drift => 1853, Altitude_Source => 1863,
      Altitude_Prefer_Baro => 1878, Altitude_LPF => 1898, Altitude_D_LPF => 1910, AP_Landing_Altitude_M => 1924,
      AP_Hover_Throttle => 1945, AP_Throttle_Min => 1962, AP_Throttle_Max => 1977, AP_Altitude_P => 1992,
      AP_Altitude_I => 2005, AP_Altitude_D => 2018, AP_Altitude_A => 2031, AP_Altitude_F => 2044,
      AP_Position_P => 2057, AP_Position_I => 2070, AP_Position_D => 2083, AP_Position_A => 2096,
      AP_Position_F => 2109, AP_Position_Cutoff => 2122, AP_Stop_Threshold => 2140, AP_Max_Angle => 2157,
      AP_Max_Yaw_Rate => 2169, AP_Yaw_P => 2184, Mag_Hardware => 2192, Opticalflow_Hardware => 2204,
      Opticalflow_Rotation => 2224, Opticalflow_Flip_X => 2244, Gyro_Cal_On_First_Arm => 2262,
      Airmode_Activate_Throttle => 2283, Serial_RX_Provider => 2308, Use_Unsynced_PWM => 2325,
      Motor_PWM_Protocol => 2341, Motor_PWM_Rate => 2359, Motor_Idle => 2373, Debug_Mode => 2383, Features => 2393,
      RC_Smoothing => 2401, RC_Smoothing_Auto_Factor => 2413, RC_Smoothing_Auto_Factor_Throttle => 2437,
      RC_Smoothing_Setpoint_Cutoff => 2470, RC_Smoothing_Throttle_Cutoff => 2498, RC_Smoothing_Debug_Axis => 2526,
      RC_Smoothing_Setpoint_Cutoff_Frequency => 2549, RC_Smoothing_RX_Rate => 2586, Rates_Type => 2610,
      Fields_Disabled_Mask => 2620, High_Resolution => 2640, VBat_Sag_Compensation => 2664,
      Dyn_Idle_Min_RPM => 2685, Dyn_Idle_P_Gain => 2701, Dyn_Idle_I_Gain => 2716, Dyn_Idle_D_Gain => 2731,
      Dyn_Idle_Max_Increase => 2746, Simplified_PIDs_Mode => 2767, Simplified_Master_Multiplier => 2787,
      Simplified_I_Gain => 2815, Simplified_D_Gain => 2832, Simplified_PI_Gain => 2849,
      Simplified_D_Max_Gain => 2867, Simplified_Feedforward_Gain => 2888, Simplified_Pitch_D_Gain => 2915,
      Simplified_Pitch_PI_Gain => 2938, Simplified_DTerm_Filter => 2962, Simplified_DTerm_Filter_Multiplier => 2985,
      Simplified_Gyro_Filter => 3019, Simplified_Gyro_Filter_Multiplier => 3041, Motor_Output_Limit => 3074,
      Throttle_Limit_Type => 3092, Throttle_Limit_Percent => 3111, Throttle_Boost => 3133,
      Throttle_Boost_Cutoff => 3147, Thrust_Linearization => 3168, GPS_Provider => 3181,
      GPS_Set_Home_Point_Once => 3193, GPS_Use_3D_Speed => 3216, GPS_Rescue_Min_Start_Dist => 3232,
      GPS_Rescue_Alt_Mode => 3257, GPS_Rescue_Initial_Climb => 3276, GPS_Rescue_Ascend_Rate => 3300,
      GPS_Rescue_Return_Alt => 3322, GPS_Rescue_Ground_Speed => 3343, GPS_Rescue_Descent_Dist => 3366,
      GPS_Rescue_Descend_Rate => 3389, GPS_Rescue_Sanity_Checks => 3412, GPS_Rescue_Min_Sats => 3436,
      GPS_Rescue_Allow_Arming_Without_Fix => 3455, GPS_Rescue_Yaw_P => 3490, Alt_Hold_Climb_Rate => 3506,
      Alt_Hold_Deadband => 3525, Pos_Hold_Deadband => 3542, TPA_Speed_Type => 3559, TPA_Speed_Basic_Delay => 3573,
      TPA_Speed_Basic_Gravity => 3594, TPA_Speed_Adv_Prop_Pitch => 3617, TPA_Speed_Adv_Mass => 3641,
      TPA_Speed_Adv_Drag_K => 3659, TPA_Speed_Adv_Thrust => 3679, TPA_Speed_Max_Voltage => 3699,
      TPA_Speed_Pitch_Offset => 3720, Yaw_Type => 3742, Angle_Pitch_Offset => 3750, Device_UID_0 => 3768,
      others => 0);
   Label_Lengths : constant array (Value_Name) of Label_Length :=
     (I_Interval => 10, P_Interval => 10, Max_Throttle => 11, Motor_Output_Low => 11, Motor_KV => 8, Acc_1G => 6,
      VBat_Scale => 10, VBat_Min_Cell => 15, VBat_Reference => 7, Current_Offset => 13, Loop_Time => 8,
      PID_Process_Denom => 17, Thr_Mid => 7, Thr_Expo => 8, Thr_Hover => 9, TPA_Mode => 8, TPA_Rate => 8,
      TPA_Breakpoint => 14, TPA_Low_Rate => 12, TPA_Low_Breakpoint => 18, TPA_Low_Always => 14, Mixer_Type => 10,
      EZ_Landing_Threshold => 20, EZ_Landing_Limit => 16, EZ_Landing_Speed => 16, Landing_Disarm_Threshold => 24,
      SPA_Roll_Center => 15, SPA_Roll_Width => 14, SPA_Roll_Mode => 13, SPA_Pitch_Center => 16,
      SPA_Pitch_Width => 15, SPA_Pitch_Mode => 14, SPA_Yaw_Center => 14, SPA_Yaw_Width => 13, SPA_Yaw_Mode => 12,
      TPA_Curve_Type => 14, TPA_Curve_Stall_Throttle => 24, TPA_Curve_PID_Thr0 => 18, TPA_Curve_PID_Thr100 => 20,
      TPA_Curve_Expo => 14, RC_Rate_Roll => 8, RC_Expo_Roll => 7, Rate_Roll => 5, Rate_Limit_Roll => 11,
      Roll_P => 7, Pitch_P => 8, Yaw_P => 6, Level_P => 8, D_Max_Roll => 5, D_Max_Gain => 10, D_Max_Advance => 13,
      DTerm_LPF1_Type => 15, DTerm_LPF1_Static_Hz => 20, DTerm_LPF1_Dyn_Min_Hz => 17, DTerm_LPF1_Dyn_Expo => 19,
      DTerm_LPF2_Type => 15, DTerm_LPF2_Static_Hz => 20, Yaw_Lowpass_Hz => 14, DTerm_Notch_Hz => 14,
      DTerm_Notch_Cutoff => 18, ITerm_Windup => 12, ITerm_Relax => 11, ITerm_Relax_Type => 16,
      ITerm_Relax_Cutoff => 18, PID_At_Min_Throttle => 19, Anti_Gravity_Gain => 17, Anti_Gravity_Cutoff_Hz => 22,
      Anti_Gravity_P_Gain => 19, FF_Weight_Roll => 9, Feedforward_Transition => 22, Feedforward_Averaging => 21,
      Feedforward_Smooth_Factor => 25, Feedforward_Jitter_Factor => 25, Feedforward_Boost => 17,
      Feedforward_Max_Rate_Limit => 26, Angle_Feedforward => 17, Angle_FF_Smoothing_Ms => 30,
      Feedforward_Yaw_Hold_Gain => 25, Feedforward_Yaw_Hold_Time => 25, Angle_Limit => 11, Angle_Earth_Ref => 15,
      Horizon_Limit_Degrees => 21, Horizon_Delay_Ms => 16, Acc_Limit_Yaw => 13, Acc_Limit => 9, PID_Sum_Limit => 12,
      PID_Sum_Limit_Yaw => 16, S_Roll => 6, S_Pitch => 7, S_Yaw => 5, Chirp_Lag_Freq_Hz => 17,
      Chirp_Lead_Freq_Hz => 18, Chirp_Amplitude_Roll => 20, Chirp_Amplitude_Pitch => 21, Chirp_Amplitude_Yaw => 19,
      Chirp_Frequency_Start_Deci_Hz => 29, Chirp_Frequency_End_Deci_Hz => 27, Chirp_Time_Seconds => 18,
      Deadband => 8, Yaw_Deadband => 12, Gyro_Hardware_LPF => 17, Gyro_LPF1_Type => 14, Gyro_LPF1_Static_Hz => 19,
      Gyro_LPF1_Dyn_Min_Hz => 16, Gyro_LPF1_Dyn_Expo => 18, Gyro_LPF2_Type => 14, Gyro_LPF2_Static_Hz => 19,
      Gyro_Notch_Hz_1 => 13, Gyro_Notch_Cutoff_1 => 17, Gyro_Enabled_Bitmask => 20, Gyro_Debug_Axis => 15,
      Dyn_Notch_Max_Hz => 16, Dyn_Notch_Count => 15, Dyn_Notch_Q => 11, Dyn_Notch_Min_Hz => 16, DShot_Bidir => 11,
      Motor_Poles => 11, RPM_Filter_Harmonics => 20, RPM_Filter_Weight_1 => 18, RPM_Filter_Q => 12,
      RPM_Filter_Min_Hz => 17, RPM_Filter_Fade_Range_Hz => 24, RPM_Filter_LPF_Hz => 17, Acc_LPF_Hz_Hundredths => 10,
      Acc_Hardware => 12, Baro_Hardware => 13, Baro_Drift => 10, Altitude_Source => 15, Altitude_Prefer_Baro => 20,
      Altitude_LPF => 12, Altitude_D_LPF => 14, AP_Landing_Altitude_M => 21, AP_Hover_Throttle => 17,
      AP_Throttle_Min => 15, AP_Throttle_Max => 15, AP_Altitude_P => 13, AP_Altitude_I => 13, AP_Altitude_D => 13,
      AP_Altitude_A => 13, AP_Altitude_F => 13, AP_Position_P => 13, AP_Position_I => 13, AP_Position_D => 13,
      AP_Position_A => 13, AP_Position_F => 13, AP_Position_Cutoff => 18, AP_Stop_Threshold => 17,
      AP_Max_Angle => 12, AP_Max_Yaw_Rate => 15, AP_Yaw_P => 8, Mag_Hardware => 12, Opticalflow_Hardware => 20,
      Opticalflow_Rotation => 20, Opticalflow_Flip_X => 18, Gyro_Cal_On_First_Arm => 21,
      Airmode_Activate_Throttle => 25, Serial_RX_Provider => 17, Use_Unsynced_PWM => 16, Motor_PWM_Protocol => 18,
      Motor_PWM_Rate => 14, Motor_Idle => 10, Debug_Mode => 10, Features => 8, RC_Smoothing => 12,
      RC_Smoothing_Auto_Factor => 24, RC_Smoothing_Auto_Factor_Throttle => 33, RC_Smoothing_Setpoint_Cutoff => 28,
      RC_Smoothing_Throttle_Cutoff => 28, RC_Smoothing_Debug_Axis => 23,
      RC_Smoothing_Setpoint_Cutoff_Frequency => 37, RC_Smoothing_RX_Rate => 24, Rates_Type => 10,
      Fields_Disabled_Mask => 20, High_Resolution => 24, VBat_Sag_Compensation => 21, Dyn_Idle_Min_RPM => 16,
      Dyn_Idle_P_Gain => 15, Dyn_Idle_I_Gain => 15, Dyn_Idle_D_Gain => 15, Dyn_Idle_Max_Increase => 21,
      Simplified_PIDs_Mode => 20, Simplified_Master_Multiplier => 28, Simplified_I_Gain => 17,
      Simplified_D_Gain => 17, Simplified_PI_Gain => 18, Simplified_D_Max_Gain => 21,
      Simplified_Feedforward_Gain => 27, Simplified_Pitch_D_Gain => 23, Simplified_Pitch_PI_Gain => 24,
      Simplified_DTerm_Filter => 23, Simplified_DTerm_Filter_Multiplier => 34, Simplified_Gyro_Filter => 22,
      Simplified_Gyro_Filter_Multiplier => 33, Motor_Output_Limit => 18, Throttle_Limit_Type => 19,
      Throttle_Limit_Percent => 22, Throttle_Boost => 14, Throttle_Boost_Cutoff => 21, Thrust_Linearization => 13,
      GPS_Provider => 12, GPS_Set_Home_Point_Once => 23, GPS_Use_3D_Speed => 16, GPS_Rescue_Min_Start_Dist => 25,
      GPS_Rescue_Alt_Mode => 19, GPS_Rescue_Initial_Climb => 24, GPS_Rescue_Ascend_Rate => 22,
      GPS_Rescue_Return_Alt => 21, GPS_Rescue_Ground_Speed => 23, GPS_Rescue_Descent_Dist => 23,
      GPS_Rescue_Descend_Rate => 23, GPS_Rescue_Sanity_Checks => 24, GPS_Rescue_Min_Sats => 19,
      GPS_Rescue_Allow_Arming_Without_Fix => 35, GPS_Rescue_Yaw_P => 16, Alt_Hold_Climb_Rate => 19,
      Alt_Hold_Deadband => 17, Pos_Hold_Deadband => 17, TPA_Speed_Type => 14, TPA_Speed_Basic_Delay => 21,
      TPA_Speed_Basic_Gravity => 23, TPA_Speed_Adv_Prop_Pitch => 24, TPA_Speed_Adv_Mass => 18,
      TPA_Speed_Adv_Drag_K => 20, TPA_Speed_Adv_Thrust => 20, TPA_Speed_Max_Voltage => 21,
      TPA_Speed_Pitch_Offset => 22, Yaw_Type => 8, Angle_Pitch_Offset => 18, Device_UID_0 => 9, others => 0);

   function Label (V : Value_Name) return String is
     (Label_Text (Natural (Label_Starts (V)) + 1 .. Natural (Label_Starts (V)) + Natural (Label_Lengths (V))));

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
