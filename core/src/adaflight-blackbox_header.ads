--  The flight log header: the field definition tables with their
--  predictors, encodings and conditions, the condition cache built once at
--  the log start, and the chunked writers that send the fixed header text,
--  the field definitions and the system information lines under the
--  device's byte budget. The device stays with the target: the writer
--  appends to a caller owned array, takes the device's free space from the
--  caller, and drops a byte the device cannot take.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers; use Adaflight.Stream_Buffers;
with Adaflight.Battery;

package Adaflight.Blackbox_Header with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Adaflight.Battery.Voltage_Source;
   use type Adaflight.Battery.Current_Source;

   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   -----------------
   -- The devices --
   -----------------

   type Device_Kind is (No_Device, Flash, SD_Card, Serial);
   type Reserve_Status is (Reserved, Temporary_Failure, Permanent_Failure);

   Max_Accumulated_Budget      : constant := 256;
   Target_Budget_Per_Iteration : constant := 64;
   subtype Budget_Per_Iteration is Natural range 0 .. Target_Budget_Per_Iteration;
   subtype Budget_Count is Integer_32 range -Max_Accumulated_Budget .. Max_Accumulated_Budget;
   subtype Device_Space is Natural range 0 .. 2 ** 24;

   --  The byte budget the header writers spend, replenished each iteration
   --  from the device's free space up to the accumulated limit, the device's
   --  free space and buffer size as the target reports them, the flushes a
   --  flash reservation asked for, and the counts of bytes written and
   --  dropped.
   type Writer is record
      Kind              : Device_Kind := No_Device;
      Budget            : Budget_Count := 0;
      Max_Per_Iteration : Budget_Per_Iteration := 0;
      Free              : Device_Space := 0;
      Buffer_Size       : Device_Space := 0;
      Flushes           : Unsigned_32 := 0;
      Written           : Unsigned_32 := 0;
      Dropped           : Unsigned_32 := 0;
   end record;

   --  The device settings and the budget of W are those of Old.
   function Same_Device (W, Old : Writer) return Boolean is
     (W.Kind = Old.Kind and then W.Budget = Old.Budget and then W.Max_Per_Iteration = Old.Max_Per_Iteration
      and then W.Buffer_Size = Old.Buffer_Size and then W.Flushes = Old.Flushes);

   --  The budget after an iteration: the device's free space or the budget
   --  grown by the per-iteration allowance, whichever is less, held at the
   --  accumulated limit.
   procedure Replenish (W : in out Writer)
     with Post => W.Kind = W.Kind'Old and then W.Max_Per_Iteration = W.Max_Per_Iteration'Old
                  and then W.Buffer_Size = W.Buffer_Size'Old and then W.Free = W.Free'Old
                  and then W.Flushes = W.Flushes'Old;

   --  Whether Bytes can go out now: within the budget, or a failure that is
   --  permanent when the device's buffer could never hold them.
   procedure Reserve (W : in out Writer; Bytes : Natural; Status : out Reserve_Status)
     with Post => W.Budget = W.Budget'Old and then W.Kind = W.Kind'Old
                  and then W.Max_Per_Iteration = W.Max_Per_Iteration'Old and then W.Buffer_Size = W.Buffer_Size'Old
                  and then W.Free = W.Free'Old
                  and then (Status = Reserved) = (Bytes <= Max_Accumulated_Budget
                                                  and then Integer_32 (Bytes) <= W.Budget'Old);

   --  One byte to the device: appended when the device and the array have
   --  room, counted as dropped otherwise.
   procedure Put (W : in out Writer; B : in out Byte_Array; S : in out Stream; V : Byte)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + 1
                  and then Same_Device (W, W'Old);

   --------------------
   -- The conditions --
   --------------------

   type Condition is
     (Always, At_Least_Motors_1, At_Least_Motors_2, At_Least_Motors_3, At_Least_Motors_4,
      At_Least_Motors_5, At_Least_Motors_6, At_Least_Motors_7, At_Least_Motors_8, Tricopter,
      Motor_1_Has_RPM, Motor_2_Has_RPM, Motor_3_Has_RPM, Motor_4_Has_RPM, Motor_5_Has_RPM,
      Motor_6_Has_RPM, Motor_7_Has_RPM, Motor_8_Has_RPM, Servos, Mag, Baro, VBat, Amperage_ADC,
      Rangefinder, RSSI, PID, Nonzero_PID_D_0, Nonzero_PID_D_1, Nonzero_PID_D_2, Nonzero_Wing_S_0,
      Nonzero_Wing_S_1, Nonzero_Wing_S_2, RC_Commands, Setpoint, Not_Logging_Every_Frame, Gyro,
      Gyro_Unfilt, Acc, Debug_Log, Attitude, Pitot, Never);
   type Condition_Set is array (Condition) of Boolean;

   --  The field groups a mask bit disables, in the bit order.
   type Field_Select is
     (Select_PID, Select_RC_Commands, Select_Setpoint, Select_Battery, Select_Mag, Select_Altitude,
      Select_RSSI, Select_Gyro, Select_Attitude, Select_Acc, Select_Debug_Log, Select_Motor, Select_GPS,
      Select_RPM, Select_Gyro_Unfilt, Select_Servo, Select_Pitot);

   subtype Motor_Count is Natural range 0 .. 8;
   type Axis_Gains is array (0 .. 2) of Integer_32;

   --  What the conditions read at the log start.
   type Condition_Inputs is record
      Fields_Disabled_Mask : Unsigned_32 := 0;
      Motors               : Motor_Count := 4;
      Has_Servos           : Boolean := False;
      DShot_Telemetry      : Boolean := False;
      Mag_Present          : Boolean := False;
      Baro_Present         : Boolean := False;
      Rangefinder_Present  : Boolean := False;
      Acc_Present          : Boolean := False;
      RSSI_Configured      : Boolean := False;
      Debug_Active         : Boolean := False;
      Voltage_Meter        : Adaflight.Battery.Voltage_Source := Adaflight.Battery.None;
      Current_Meter        : Adaflight.Battery.Current_Source := Adaflight.Battery.None;
      PID_D                : Axis_Gains := (others => 0);
      PID_S                : Axis_Gains := (others => 0);
      I_Interval           : Integer_32 := 0;
      P_Interval           : Integer_32 := 0;
   end record;

   function Field_Enabled (Mask : Unsigned_32; F : Field_Select) return Boolean is
     ((Mask and Interfaces.Shift_Left (Unsigned_32'(1), Field_Select'Pos (F))) = 0);

   function Test_Uncached (C : Condition; In_Flight : Condition_Inputs) return Boolean;

   procedure Build_Cache (Cache : out Condition_Set; In_Flight : Condition_Inputs)
     with Post => (for all C in Condition => Cache (C) = Test_Uncached (C, In_Flight));

   ----------------
   -- The fields --
   ----------------

   type Predictor is
     (Predict_Zero, Predict_Previous, Predict_Straight_Line, Predict_Average_2, Predict_Min_Throttle,
      Predict_Motor_0, Predict_Increment, Predict_Home_Coord, Predict_1500, Predict_VBat_Reference,
      Predict_Last_Main_Frame_Time, Predict_Min_Motor);
   type Encoding is
     (Encode_Signed_VB, Encode_Unsigned_VB, Encode_Neg_14_Bit, Encode_Tag8_8SVB, Encode_Tag2_3S32,
      Encode_Tag8_4S16, Encode_Null, Encode_Tag2_3S_Variable);

   --  The codes the header names them by.
   function Encoding_Code (E : Encoding) return Natural is
     (case E is
        when Encode_Signed_VB => 0, when Encode_Unsigned_VB => 1, when Encode_Neg_14_Bit => 3,
        when Encode_Tag8_8SVB => 6, when Encode_Tag2_3S32 => 7, when Encode_Tag8_4S16 => 8,
        when Encode_Null => 9, when Encode_Tag2_3S_Variable => 10);

   type Field_Name is
     (Loop_Iteration, Time, Axis_P, Axis_I, Axis_D, Axis_F, Axis_S, RC_Command, Setpoint_Field,
      VBat_Latest, Amperage_Latest, Mag_ADC, Baro_Alt, Surface_Raw, RSSI_Field, Pitot_Field, Gyro_ADC,
      Gyro_Unfilt_Field, Acc_Smooth, IMU_Quaternion, Debug_Field, Motor, Servo, ERPM, GPS_Num_Sat,
      GPS_Coord, GPS_Altitude, GPS_Speed, GPS_Ground_Course, GPS_Vel_NED, GPS_Time, GPS_Home,
      GPS_Home_Epoch, Flight_Mode_Flags, State_Flags, Failsafe_Phase, RX_Signal_Received,
      RX_Flight_Channels_Valid);

   function Name_Text (N : Field_Name) return String
     with Post => Name_Text'Result'Length in 4 .. 21;

   subtype Name_Index is Integer range -1 .. 7;

   --  A field of a frame: its name and index, sign, the predictor and
   --  encoding of its intra frame and of its delta frame, and the condition
   --  that includes it.
   type Field_Definition is record
      Name      : Field_Name := Time;
      Index     : Name_Index := -1;
      Signed    : Boolean := False;
      I_Predict : Predictor := Predict_Zero;
      I_Encode  : Encoding := Encode_Unsigned_VB;
      P_Predict : Predictor := Predict_Zero;
      P_Encode  : Encoding := Encode_Unsigned_VB;
      Cond      : Condition := Always;
   end record;

   type Header_Table is (Main_Fields, GPS_Home_Fields, GPS_Fields, Slow_Fields);
   Max_Fields : constant := 80;
   subtype Field_Count is Natural range 0 .. Max_Fields;
   subtype Field_Position is Natural range 0 .. Max_Fields - 1;

   --  A wing's main table has the three stabilization terms after the
   --  feedforward terms.
   function Field_Count_Of (T : Header_Table; Wing : Boolean) return Field_Count;
   function Field_Of (T : Header_Table; Wing : Boolean; I : Field_Position) return Field_Definition
     with Pre => I < Field_Count_Of (T, Wing);

   --  A delta table names its delta frame's predictors and encodings too;
   --  a conditional table includes a field by its condition.
   function Is_Delta (T : Header_Table) return Boolean is (T = Main_Fields);
   function Is_Conditional (T : Header_Table) return Boolean is (T in Main_Fields | GPS_Fields);

   --------------------
   -- The sysinfo --
   --------------------

   Text_Max : constant := 32;
   subtype Text_Length is Natural range 0 .. Text_Max;
   type Text is record
      Data   : String (1 .. Text_Max) := (others => ' ');
      Length : Text_Length := 0;
   end record;

   type Text_Name is
     (Firmware_Type, Firmware_Name, Firmware_Version, Git_Revision, Target_Name, Build_Date,
      Build_Time, Build_Key, Release_Name, Manufacturer_Id, Board_Name, Start_Date_Time, Craft_Name,
      Debug_Mode_Name);
   type Text_Table is array (Text_Name) of Text;

   --  The settings the header lists, in the order of the lines, with the
   --  values of one line consecutive.
   type Value_Name is
     (I_Interval, P_Interval, Max_Throttle, Motor_Output_Low, Motor_Output_High, Motor_KV, Acc_1G,
      VBat_Scale, VBat_Min_Cell, VBat_Warning_Cell, VBat_Max_Cell, VBat_Reference, Current_Offset,
      Current_Scale, Loop_Time, PID_Process_Denom, Thr_Mid, Thr_Expo, Thr_Hover, TPA_Mode, TPA_Rate,
      TPA_Breakpoint, TPA_Low_Rate, TPA_Low_Breakpoint, TPA_Low_Always, Mixer_Type, EZ_Landing_Threshold,
      EZ_Landing_Limit, EZ_Landing_Speed, Landing_Disarm_Threshold, SPA_Roll_Center, SPA_Roll_Width,
      SPA_Roll_Mode, SPA_Pitch_Center, SPA_Pitch_Width, SPA_Pitch_Mode, SPA_Yaw_Center, SPA_Yaw_Width,
      SPA_Yaw_Mode, TPA_Curve_Type, TPA_Curve_Stall_Throttle, TPA_Curve_PID_Thr0, TPA_Curve_PID_Thr100,
      TPA_Curve_Expo, RC_Rate_Roll, RC_Rate_Pitch, RC_Rate_Yaw, RC_Expo_Roll, RC_Expo_Pitch, RC_Expo_Yaw,
      Rate_Roll, Rate_Pitch, Rate_Yaw, Rate_Limit_Roll, Rate_Limit_Pitch, Rate_Limit_Yaw, Roll_P, Roll_I,
      Roll_D, Pitch_P, Pitch_I, Pitch_D, Yaw_P, Yaw_I, Yaw_D, Level_P, Level_I, Level_D, D_Max_Roll,
      D_Max_Pitch, D_Max_Yaw, D_Max_Gain, D_Max_Advance, DTerm_LPF1_Type, DTerm_LPF1_Static_Hz,
      DTerm_LPF1_Dyn_Min_Hz, DTerm_LPF1_Dyn_Max_Hz, DTerm_LPF1_Dyn_Expo, DTerm_LPF2_Type,
      DTerm_LPF2_Static_Hz, Yaw_Lowpass_Hz, DTerm_Notch_Hz, DTerm_Notch_Cutoff, ITerm_Windup, ITerm_Relax,
      ITerm_Relax_Type, ITerm_Relax_Cutoff, PID_At_Min_Throttle, Anti_Gravity_Gain, Anti_Gravity_Cutoff_Hz,
      Anti_Gravity_P_Gain, FF_Weight_Roll, FF_Weight_Pitch, FF_Weight_Yaw, Feedforward_Transition,
      Feedforward_Averaging, Feedforward_Smooth_Factor, Feedforward_Jitter_Factor, Feedforward_Boost,
      Feedforward_Max_Rate_Limit, Angle_Feedforward, Angle_FF_Smoothing_Ms, Feedforward_Yaw_Hold_Gain,
      Feedforward_Yaw_Hold_Time, Angle_Limit, Angle_Earth_Ref, Horizon_Limit_Degrees, Horizon_Delay_Ms,
      Acc_Limit_Yaw, Acc_Limit, PID_Sum_Limit, PID_Sum_Limit_Yaw, S_Roll, S_Pitch, S_Yaw,
      Chirp_Lag_Freq_Hz, Chirp_Lead_Freq_Hz, Chirp_Amplitude_Roll, Chirp_Amplitude_Pitch,
      Chirp_Amplitude_Yaw, Chirp_Frequency_Start_Deci_Hz, Chirp_Frequency_End_Deci_Hz, Chirp_Time_Seconds,
      Deadband, Yaw_Deadband, Gyro_Hardware_LPF, Gyro_LPF1_Type, Gyro_LPF1_Static_Hz, Gyro_LPF1_Dyn_Min_Hz,
      Gyro_LPF1_Dyn_Max_Hz, Gyro_LPF1_Dyn_Expo, Gyro_LPF2_Type, Gyro_LPF2_Static_Hz, Gyro_Notch_Hz_1,
      Gyro_Notch_Hz_2, Gyro_Notch_Cutoff_1, Gyro_Notch_Cutoff_2, Gyro_Enabled_Bitmask, Gyro_Debug_Axis,
      Dyn_Notch_Max_Hz, Dyn_Notch_Count, Dyn_Notch_Q, Dyn_Notch_Min_Hz, DShot_Bidir, Motor_Poles,
      RPM_Filter_Harmonics, RPM_Filter_Weight_1, RPM_Filter_Weight_2, RPM_Filter_Weight_3, RPM_Filter_Q,
      RPM_Filter_Min_Hz, RPM_Filter_Fade_Range_Hz, RPM_Filter_LPF_Hz, Acc_LPF_Hz_Hundredths, Acc_Hardware,
      Baro_Hardware, Baro_Drift, Altitude_Source, Altitude_Prefer_Baro, Altitude_LPF, Altitude_D_LPF,
      AP_Landing_Altitude_M, AP_Hover_Throttle, AP_Throttle_Min, AP_Throttle_Max, AP_Altitude_P,
      AP_Altitude_I, AP_Altitude_D, AP_Altitude_A, AP_Altitude_F, AP_Position_P, AP_Position_I,
      AP_Position_D, AP_Position_A, AP_Position_F, AP_Position_Cutoff, AP_Stop_Threshold, AP_Max_Angle,
      AP_Max_Yaw_Rate, AP_Yaw_P, Mag_Hardware, Opticalflow_Hardware, Opticalflow_Rotation,
      Opticalflow_Flip_X, Gyro_Cal_On_First_Arm, Airmode_Activate_Throttle, Serial_RX_Provider,
      Use_Unsynced_PWM, Motor_PWM_Protocol, Motor_PWM_Rate, Motor_Idle, Debug_Mode, Features, RC_Smoothing,
      RC_Smoothing_Auto_Factor, RC_Smoothing_Auto_Factor_Throttle, RC_Smoothing_Setpoint_Cutoff,
      RC_Smoothing_Throttle_Cutoff, RC_Smoothing_Debug_Axis, RC_Smoothing_Setpoint_Cutoff_Frequency,
      RC_Smoothing_Throttle_Cutoff_Frequency, RC_Smoothing_RX_Rate, Rates_Type, Fields_Disabled_Mask,
      High_Resolution, VBat_Sag_Compensation, Dyn_Idle_Min_RPM, Dyn_Idle_P_Gain, Dyn_Idle_I_Gain,
      Dyn_Idle_D_Gain, Dyn_Idle_Max_Increase, Simplified_PIDs_Mode, Simplified_Master_Multiplier,
      Simplified_I_Gain, Simplified_D_Gain, Simplified_PI_Gain, Simplified_D_Max_Gain,
      Simplified_Feedforward_Gain, Simplified_Pitch_D_Gain, Simplified_Pitch_PI_Gain,
      Simplified_DTerm_Filter, Simplified_DTerm_Filter_Multiplier, Simplified_Gyro_Filter,
      Simplified_Gyro_Filter_Multiplier, Motor_Output_Limit, Throttle_Limit_Type, Throttle_Limit_Percent,
      Throttle_Boost, Throttle_Boost_Cutoff, Thrust_Linearization, GPS_Provider, GPS_Set_Home_Point_Once,
      GPS_Use_3D_Speed, GPS_Rescue_Min_Start_Dist, GPS_Rescue_Alt_Mode, GPS_Rescue_Initial_Climb,
      GPS_Rescue_Ascend_Rate, GPS_Rescue_Return_Alt, GPS_Rescue_Ground_Speed, GPS_Rescue_Descent_Dist,
      GPS_Rescue_Descend_Rate, GPS_Rescue_Sanity_Checks, GPS_Rescue_Min_Sats,
      GPS_Rescue_Allow_Arming_Without_Fix, GPS_Rescue_Yaw_P, Alt_Hold_Climb_Rate, Alt_Hold_Deadband,
      Pos_Hold_Deadband, TPA_Speed_Type, TPA_Speed_Basic_Delay, TPA_Speed_Basic_Gravity,
      TPA_Speed_Adv_Prop_Pitch, TPA_Speed_Adv_Mass, TPA_Speed_Adv_Drag_K, TPA_Speed_Adv_Thrust,
      TPA_Speed_Max_Voltage, TPA_Speed_Pitch_Offset, Yaw_Type, Angle_Pitch_Offset, Device_UID_0,
      Device_UID_1, Device_UID_2);
   type Value_Table is array (Value_Name) of Integer_32;

   --  The mixer types by their setting value.
   function Mixer_Type_Name (V : Integer_32) return String is
     (case V is when 0 => "LEGACY", when 1 => "LINEAR", when 2 => "DYNAMIC", when 3 => "EZLANDING",
      when others => "");

   type Sysinfo is record
      Values : Value_Table := (others => 0);
      Texts  : Text_Table;
   end record;

   --  The ways a line shows its values: decimals, unsigned decimals, the
   --  pairs and triples of them, the unique id in hexadecimal, the float
   --  scale as its bits, the texts, and the two lines that depend on the
   --  battery meters.
   type Line_Format is
     (One_Decimal, One_Unsigned, Two_Decimal, Three_Decimal, Three_Unsigned, Gyro_Scale_Line,
      Device_UID_Line, Firmware_Type_Line, Firmware_Revision_Line, Firmware_Date_Line, Build_Key_Line,
      Release_Name_Line, Board_Information_Line, Start_Date_Time_Line, Craft_Name_Line,
      Mixer_Type_Line, Debug_Mode_Name_Line, P_Ratio_Line, Gyro_Sync_Denom_Line, VBat_Scale_Line,
      Current_Sensor_Line);

   type Line is record
      Format : Line_Format := One_Decimal;
      First  : Value_Name := I_Interval;
   end record;

   Max_Lines : constant := 256;
   subtype Line_Count is Natural range 0 .. Max_Lines;
   subtype Line_Position is Natural range 0 .. Max_Lines - 1;

   function Line_Count_Of (Wing : Boolean) return Line_Count;
   function Line_Of (Wing : Boolean; I : Line_Position) return Line
     with Pre => I < Line_Count_Of (Wing);

   --  The setting name a line is labelled with, keyed by its first value.
   function Label (V : Value_Name) return String;

   ------------------------
   -- The chunked writers --
   ------------------------

   subtype Header_Index is Natural range 0 .. 2 ** 16;
   subtype Field_Cursor is Integer range -1 .. Max_Fields;

   --  Where a header transmission is: the line or name index, the field the
   --  definition writer is at, whether a comma precedes the next field, and
   --  the time the fixed text started.
   type Header_State is record
      Index         : Header_Index := 0;
      Field         : Field_Cursor := -1;
      Need_Comma    : Boolean := False;
      Start_Time_Ms : Unsigned_32 := 0;
   end record;

   --  The fixed text, sent in chunks of the per-iteration budget once the
   --  port has had a tenth of a second to settle.
   procedure Send_Header_Text (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                               S : in out Stream; Now_Ms : Unsigned_32; Done : out Boolean)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old;

   --  The header lines of a table: name, sign, predictor and encoding, and
   --  the delta frame's predictor and encoding for a delta table.
   function Header_Count_Of (T : Header_Table) return Positive is (if Is_Delta (T) then 6 else 4);

   --  One header line of a field table per call, continued across calls
   --  under the budget; More is clear once the table's lines are all sent.
   procedure Send_Field_Definition (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                                    S : in out Stream; T : Header_Table; Wing : Boolean;
                                    Cache : Condition_Set; More : out Boolean)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old;

   --  One system information line per call; Done once the lines are all
   --  sent.
   procedure Send_Sysinfo (H : in out Header_State; W : in out Writer; B : in out Byte_Array;
                           S : in out Stream; Wing : Boolean; Info : Sysinfo; Cache : Condition_Set;
                           Current_Meter : Adaflight.Battery.Current_Source; Done : out Boolean)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old;

end Adaflight.Blackbox_Header;
