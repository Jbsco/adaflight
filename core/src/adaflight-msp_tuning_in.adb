with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package body Adaflight.MSP_Tuning_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   subtype Integer_64 is Interfaces.Integer_64;

   subtype Offset_Range is Natural range 0 .. 64;

   --  The request's byte at an offset, zero past its end.
   function U8 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if Offset < Request'Length then Integer_64 (Request (Request'First + Offset)) else 0)
     with Pre  => Request'Length <= Max_Request,
          Post => U8'Result in 0 .. 255;

   --  The request's little-endian 16-bit value at an offset.
   function U16 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (U8 (Request, Offset) + 256 * U8 (Request, Offset + 1))
     with Pre  => Request'Length <= Max_Request and then Offset < Offset_Range'Last,
          Post => U16'Result in 0 .. 65_535;

   --  The byte read into a signed 8-bit field.
   function S8 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if U8 (Request, Offset) >= 2 ** 7 then U8 (Request, Offset) - 2 ** 8 else U8 (Request, Offset))
     with Pre => Request'Length <= Max_Request;

   --  The same value read into a signed 16-bit field.
   function S16 (Request : Byte_Array; Offset : Offset_Range) return Integer_64 is
     (if U16 (Request, Offset) >= 2 ** 15 then U16 (Request, Offset) - 2 ** 16 else U16 (Request, Offset))
     with Pre => Request'Length <= Max_Request and then Offset < Offset_Range'Last;

   --  Whether a value is within a setting's range: its bounds for a direct
   --  setting, a named value of its table for a lookup setting.
   function In_Range (S : Setting; V : Integer_64) return Boolean is
      I : constant Info := Describe (S);
   begin
      case I.How is
         when Direct =>
            return V in I.Min .. I.Max;
         when Lookup =>
            return V in 0 .. Integer_64 (Value_Count (I.Table)) - 1
              and then Value_Name (I.Table, Natural (V))'Length > 0;
         when List | Bitset | Text | Identifier =>
            return True;
      end case;
   end In_Range;

   --  The setting writes of one request in the reference's order, checked
   --  together before any is made.
   Max_Writes : constant := 36;

   type Planned is record
      S       : Setting := P_Roll;
      Value   : Integer_64 := 0;
      Profile : Natural := 0;
      Index   : Natural := 0;
   end record;

   type Planned_List is array (1 .. Max_Writes) of Planned;

   type Plan is record
      Items : Planned_List;
      Count : Natural range 0 .. Max_Writes := 0;
   end record;

   function Fits (P : Plan) return Boolean is
     (for all K in 1 .. P.Count =>
        P.Items (K).Profile < Profile_Count (P.Items (K).S) and then P.Items (K).Index < Element_Count (P.Items (K).S));

   procedure Add (P : in out Plan; S : Setting; Value : Integer_64; Profile : Natural; Index : Natural := 0)
     with Pre  => P.Count < Max_Writes and then Fits (P) and then Profile < Profile_Count (S)
                  and then Index < Element_Count (S),
          Post => Fits (P) and then P.Count = P.Count'Old + 1
   is
   begin
      P.Count := P.Count + 1;
      P.Items (P.Count) := (S => S, Value => Value, Profile => Profile, Index => Index);
   end Add;

   function Valid (P : Plan) return Boolean is
     (for all K in 1 .. P.Count => In_Range (P.Items (K).S, P.Items (K).Value));

   procedure Apply (C : in out Configuration; P : Plan)
     with Pre => Fits (P)
   is
   begin
      for K in 1 .. P.Count loop
         Set (C, P.Items (K).S, P.Items (K).Value, P.Items (K).Profile, P.Items (K).Index);
      end loop;
   end Apply;

   --  The gains of roll, pitch, yaw and level from the settings, then the
   --  heading gains, which no setting names.
   procedure Set_PID (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Profile : constant Natural := Natural (C.System_Config.Pid_Profile_Index);
      P       : Plan;
   begin
      Add (P, P_Roll, U8 (Request, 0), Profile);
      Add (P, I_Roll, U8 (Request, 1), Profile);
      Add (P, D_Roll, U8 (Request, 2), Profile);
      Add (P, P_Pitch, U8 (Request, 3), Profile);
      Add (P, I_Pitch, U8 (Request, 4), Profile);
      Add (P, D_Pitch, U8 (Request, 5), Profile);
      Add (P, P_Yaw, U8 (Request, 6), Profile);
      Add (P, I_Yaw, U8 (Request, 7), Profile);
      Add (P, D_Yaw, U8 (Request, 8), Profile);
      Add (P, Angle_P_Gain, U8 (Request, 9), Profile);
      Add (P, Horizon_Level_Strength, U8 (Request, 10), Profile);
      Add (P, Horizon_Limit_Sticks, U8 (Request, 11), Profile);
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      C.Pid_Profiles (Profile).Pid (4).P := Byte (U8 (Request, 12));
      C.Pid_Profiles (Profile).Pid (4).I := Byte (U8 (Request, 13));
      C.Pid_Profiles (Profile).Pid (4).D := Byte (U8 (Request, 14));
      E.PID_Init := True;
      R := Ack;
   end Set_PID;

   --  The roll rate and expo, which the pitch follows while it equals the
   --  roll, the super rates, the throttle curve, then each later field the
   --  request's length reaches. A request shorter than ten bytes is an error.
   procedure Set_RC_Tuning (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Rate   : constant Natural := Natural (C.System_Config.Active_Rate_Profile);
      Length : constant Natural := Request'Length;
      Offset : Offset_Range := 10;
      P      : Plan;
   begin
      if Length < 10 then
         R := Error;
         return;
      end if;
      if Get (C, Pitch_Rc_Rate, Rate) = Get (C, Roll_Rc_Rate, Rate) then
         Add (P, Pitch_Rc_Rate, U8 (Request, 0), Rate);
      end if;
      Add (P, Roll_Rc_Rate, U8 (Request, 0), Rate);
      if Get (C, Pitch_Expo, Rate) = Get (C, Roll_Expo, Rate) then
         Add (P, Pitch_Expo, U8 (Request, 1), Rate);
      end if;
      Add (P, Roll_Expo, U8 (Request, 1), Rate);
      Add (P, Roll_Srate, U8 (Request, 2), Rate);
      Add (P, Pitch_Srate, U8 (Request, 3), Rate);
      Add (P, Yaw_Srate, U8 (Request, 4), Rate);
      Add (P, Thr_Mid, U8 (Request, 6), Rate);
      Add (P, Thr_Expo, U8 (Request, 7), Rate);
      pragma Assert (P.Count <= 9);
      if Length - Offset >= 1 then
         Add (P, Yaw_Expo, U8 (Request, Offset), Rate);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Yaw_Rc_Rate, U8 (Request, Offset), Rate);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Pitch_Rc_Rate, U8 (Request, Offset), Rate);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Pitch_Expo, U8 (Request, Offset), Rate);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 2 then
         Add (P, Throttle_Limit_Type, U8 (Request, Offset), Rate);
         Add (P, Throttle_Limit_Percent, U8 (Request, Offset + 1), Rate);
         Offset := Offset + 2;
      end if;
      if Length - Offset >= 6 then
         Add (P, Roll_Rate_Limit, U16 (Request, Offset), Rate);
         Add (P, Pitch_Rate_Limit, U16 (Request, Offset + 2), Rate);
         Add (P, Yaw_Rate_Limit, U16 (Request, Offset + 4), Rate);
         Offset := Offset + 6;
      end if;
      if Length - Offset >= 1 then
         Add (P, Rates_Type, U8 (Request, Offset), Rate);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 1 then
         Add (P, Thr_Hover, U8 (Request, Offset), Rate);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      E.RC_Init := True;
      R := Ack;
   end Set_RC_Tuning;

   --  The disarm delay, a reserved byte, then the small angle and the gyro
   --  calibration on the first arm while bytes remain.
   procedure Set_Arming_Config (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Length : constant Integer := Request'Length;
      Offset : Offset_Range := 2;
      P      : Plan;
   begin
      Add (P, Auto_Disarm_Delay, U8 (Request, 0), 0);
      if Length > Offset then
         Add (P, Small_Angle, U8 (Request, Offset), 0);
         Offset := Offset + 1;
      end if;
      if Length > Offset then
         Add (P, Gyro_Cal_On_First_Arm, U8 (Request, Offset), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      R := Ack;
   end Set_Arming_Config;

   --  The mag alignment, the gyros in use, which no setting names, and the
   --  mag's custom alignment when six more bytes follow.
   procedure Set_Sensor_Alignment (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Length : constant Integer := Request'Length;
      P      : Plan;
   begin
      Add (P, Align_Mag, U8 (Request, 2), 0);
      if Length - 4 >= 6 then
         Add (P, Mag_Align_Roll, S16 (Request, 4), 0);
         Add (P, Mag_Align_Pitch, S16 (Request, 6), 0);
         Add (P, Mag_Align_Yaw, S16 (Request, 8), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      C.Gyro_Config.Gyro_Enabled_Bitmask := Byte (U8 (Request, 3));
      R := Ack;
   end Set_Sensor_Alignment;

   --  The PID loop's divider, the motor update mode, protocol and rate, then
   --  as the request's length reaches them the idle value, a deprecated
   --  byte while bytes remain, the motor inversion while bytes remain, the
   --  gyro's range, which no setting names, calibration and overflow
   --  settings, and the debug mode; then the gyro's checks.
   procedure Set_Advanced_Config
     (C : in out Configuration; Request : Byte_Array; Gyro_Sample_Rate_Hz : Config_Fix.Gyro_Rate; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      Length    : constant Natural := Request'Length;
      Offset    : Offset_Range := 6;
      High_Fsr  : Integer_64 := -1;
      P         : Plan;
   begin
      Add (P, Pid_Process_Denom, U8 (Request, 1), 0);
      Add (P, Use_Unsynced_Pwm, U8 (Request, 2), 0);
      Add (P, Motor_Pwm_Protocol, U8 (Request, 3), 0);
      Add (P, Motor_Pwm_Rate, U16 (Request, 4), 0);
      if Length - Offset >= 2 then
         Add (P, Motor_Idle, U16 (Request, Offset), 0);
         Offset := Offset + 2;
      end if;
      if Length > Offset then
         Offset := Offset + 1;
      end if;
      if Length > Offset then
         Add (P, Motor_Pwm_Inversion, U8 (Request, Offset), 0);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 8 then
         High_Fsr := U8 (Request, Offset + 1);
         Add (P, Gyro_Calib_Noise_Limit, U8 (Request, Offset + 2), 0);
         Add (P, Gyro_Calib_Duration, U16 (Request, Offset + 3), 0);
         Add (P, Gyro_Offset_Yaw, S16 (Request, Offset + 5), 0);
         Add (P, Gyro_Overflow_Detect, U8 (Request, Offset + 7), 0);
         Offset := Offset + 8;
      end if;
      if Length - Offset >= 1 then
         Add (P, Debug_Mode, U8 (Request, Offset), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      if High_Fsr >= 0 then
         C.Gyro_Config.Gyro_High_Fsr := Byte (High_Fsr);
      end if;
      Config_Fix.Fix_Gyro (C, Gyro_Sample_Rate_Hz);
      R := Ack;
   end Set_Advanced_Config;

   --  The gyro's first lowpass in one byte, the D term and yaw lowpasses,
   --  then each group the request's length reaches: notches, the D term
   --  lowpass type, the gyro's hardware and software lowpasses with the
   --  second D term lowpass, the dynamic lowpasses, the dynamic notch and the
   --  RPM filter's harmonics, the dynamic notch's top, the D term's dynamic
   --  expo with the notch count, and the RPM filter's fade, Q and weights,
   --  each weight at most 100; then the gyro's checks.
   procedure Set_Filter_Config
     (C : in out Configuration; Request : Byte_Array; Gyro_Sample_Rate_Hz : Config_Fix.Gyro_Rate; R : out Result;
      E : in out Effects)
     with Pre  => Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Profile    : constant Natural := Natural (C.System_Config.Pid_Profile_Index);
      Length     : constant Natural := Request'Length;
      Offset     : Offset_Range := 5;
      Weights_Ok : Boolean := True;
      P          : Plan;
   begin
      Add (P, Gyro_Lpf1_Static_Hz, U8 (Request, 0), 0);
      Add (P, Dterm_Lpf1_Static_Hz, U16 (Request, 1), Profile);
      Add (P, Yaw_Lowpass_Hz, U16 (Request, 3), Profile);
      if Length - Offset >= 8 then
         Add (P, Gyro_Notch1_Hz, U16 (Request, Offset), 0);
         Add (P, Gyro_Notch1_Cutoff, U16 (Request, Offset + 2), 0);
         Add (P, Dterm_Notch_Hz, U16 (Request, Offset + 4), Profile);
         Add (P, Dterm_Notch_Cutoff, U16 (Request, Offset + 6), Profile);
         Offset := Offset + 8;
      end if;
      if Length - Offset >= 4 then
         Add (P, Gyro_Notch2_Hz, U16 (Request, Offset), 0);
         Add (P, Gyro_Notch2_Cutoff, U16 (Request, Offset + 2), 0);
         Offset := Offset + 4;
      end if;
      if Length - Offset >= 1 then
         Add (P, Dterm_Lpf1_Type, U8 (Request, Offset), Profile);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 10 then
         Add (P, Gyro_Hardware_Lpf, U8 (Request, Offset), 0);
         Add (P, Gyro_Lpf1_Static_Hz, U16 (Request, Offset + 2), 0);
         Add (P, Gyro_Lpf2_Static_Hz, U16 (Request, Offset + 4), 0);
         Add (P, Gyro_Lpf1_Type, U8 (Request, Offset + 6), 0);
         Add (P, Gyro_Lpf2_Type, U8 (Request, Offset + 7), 0);
         Add (P, Dterm_Lpf2_Static_Hz, U16 (Request, Offset + 8), Profile);
         Offset := Offset + 10;
      end if;
      if Length - Offset >= 9 then
         Add (P, Dterm_Lpf2_Type, U8 (Request, Offset), Profile);
         Add (P, Gyro_Lpf1_Dyn_Min_Hz, U16 (Request, Offset + 1), 0);
         Add (P, Gyro_Lpf1_Dyn_Max_Hz, U16 (Request, Offset + 3), 0);
         Add (P, Dterm_Lpf1_Dyn_Min_Hz, U16 (Request, Offset + 5), Profile);
         Add (P, Dterm_Lpf1_Dyn_Max_Hz, U16 (Request, Offset + 7), Profile);
         Offset := Offset + 9;
      end if;
      if Length - Offset >= 8 then
         Add (P, Dyn_Notch_Q, U16 (Request, Offset + 2), 0);
         Add (P, Dyn_Notch_Min_Hz, U16 (Request, Offset + 4), 0);
         Add (P, Rpm_Filter_Harmonics, U8 (Request, Offset + 6), 0);
         Add (P, Rpm_Filter_Min_Hz, U8 (Request, Offset + 7), 0);
         Offset := Offset + 8;
      end if;
      if Length - Offset >= 2 then
         Add (P, Dyn_Notch_Max_Hz, U16 (Request, Offset), 0);
         Offset := Offset + 2;
      end if;
      if Length - Offset >= 2 then
         Add (P, Dterm_Lpf1_Dyn_Expo, U8 (Request, Offset), Profile);
         Add (P, Dyn_Notch_Count, U8 (Request, Offset + 1), 0);
         Offset := Offset + 2;
      end if;
      if Length - Offset >= 7 then
         Add (P, Rpm_Filter_Fade_Range_Hz, U16 (Request, Offset), 0);
         Add (P, Rpm_Filter_Q, U16 (Request, Offset + 2), 0);
         for J in 0 .. 2 loop
            pragma Loop_Invariant (P.Count = P.Count'Loop_Entry + J and then Fits (P));
            Add (P, Rpm_Filter_Weights, U8 (Request, Offset + 4 + J), 0, J);
            Weights_Ok := Weights_Ok and then U8 (Request, Offset + 4 + J) <= 100;
         end loop;
      end if;
      if not Valid (P) or else not Weights_Ok then
         R := Error;
         return;
      end if;
      Apply (C, P);
      Config_Fix.Fix_Gyro (C, Gyro_Sample_Rate_Hz);
      E.Gyro_Filters := True;
      E.PID_Filters := True;
      R := Ack;
   end Set_Filter_Config;

   --  Deprecated and reserved fields around the feedforward transition and
   --  the acceleration limits, then each group the request's length reaches:
   --  the angle limit, the anti gravity gain, a deprecated word, the I term
   --  rotation and relax, throttle boost, acro trainer limit and the
   --  feedforward gains, the D max settings, the I term relax cutoff, the
   --  motor output limit, profile cell count and dynamic idle, the
   --  feedforward smoothing with sag compensation and thrust linearization,
   --  and the throttle PID attenuation, whose rate is held at 100.
   procedure Set_PID_Advanced
     (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Profiles_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Profile : constant Natural := Natural (C.System_Config.Pid_Profile_Index);
      Length  : constant Natural := Request'Length;
      Offset  : Offset_Range := 17;
      P       : Plan;
   begin
      Add (P, Feedforward_Transition, U8 (Request, 8), Profile);
      Add (P, Acc_Limit, U16 (Request, 13), Profile);
      Add (P, Acc_Limit_Yaw, U16 (Request, 15), Profile);
      if Length - Offset >= 2 then
         Add (P, Angle_Limit, U8 (Request, Offset), Profile);
         Offset := Offset + 2;
      end if;
      if Length - Offset >= 4 then
         Add (P, Anti_Gravity_Gain, U16 (Request, Offset + 2), Profile);
         Offset := Offset + 4;
      end if;
      if Length - Offset >= 2 then
         Offset := Offset + 2;
      end if;
      if Length - Offset >= 14 then
         Add (P, Iterm_Rotation, U8 (Request, Offset), Profile);
         Add (P, Iterm_Relax, U8 (Request, Offset + 2), Profile);
         Add (P, Iterm_Relax_Type, U8 (Request, Offset + 3), Profile);
         Add (P, Throttle_Boost, U8 (Request, Offset + 5), Profile);
         Add (P, Acro_Trainer_Angle_Limit, U8 (Request, Offset + 6), Profile);
         Add (P, F_Roll, U16 (Request, Offset + 7), Profile);
         Add (P, F_Pitch, U16 (Request, Offset + 9), Profile);
         Add (P, F_Yaw, U16 (Request, Offset + 11), Profile);
         Offset := Offset + 14;
      end if;
      if Length - Offset >= 7 then
         Add (P, D_Max_Roll, U8 (Request, Offset), Profile);
         Add (P, D_Max_Pitch, U8 (Request, Offset + 1), Profile);
         Add (P, D_Max_Yaw, U8 (Request, Offset + 2), Profile);
         Add (P, D_Max_Gain, U8 (Request, Offset + 3), Profile);
         Add (P, D_Max_Advance, U8 (Request, Offset + 4), Profile);
         Offset := Offset + 7;
      end if;
      if Length - Offset >= 1 then
         Add (P, Iterm_Relax_Cutoff, U8 (Request, Offset), Profile);
         Offset := Offset + 1;
      end if;
      if Length - Offset >= 3 then
         Add (P, Motor_Output_Limit, U8 (Request, Offset), Profile);
         Add (P, Auto_Profile_Cell_Count, S8 (Request, Offset + 1), Profile);
         Add (P, Dyn_Idle_Min_Rpm, U8 (Request, Offset + 2), Profile);
         Offset := Offset + 3;
      end if;
      if Length - Offset >= 7 then
         Add (P, Feedforward_Averaging, U8 (Request, Offset), Profile);
         Add (P, Feedforward_Smooth_Factor, U8 (Request, Offset + 1), Profile);
         Add (P, Feedforward_Boost, U8 (Request, Offset + 2), Profile);
         Add (P, Feedforward_Max_Rate_Limit, U8 (Request, Offset + 3), Profile);
         Add (P, Feedforward_Jitter_Factor, U8 (Request, Offset + 4), Profile);
         Add (P, Vbat_Sag_Compensation, U8 (Request, Offset + 5), Profile);
         Add (P, Thrust_Linear, U8 (Request, Offset + 6), Profile);
         Offset := Offset + 7;
      end if;
      if Length - Offset >= 4 then
         Add (P, Tpa_Mode, U8 (Request, Offset), Profile);
         Add (P, Tpa_Rate, Integer_64'Min (U8 (Request, Offset + 1), 100), Profile);
         Add (P, Tpa_Breakpoint, U16 (Request, Offset + 2), Profile);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      Apply (C, P);
      E.PID_Init := True;
      E.ESC_Endpoints := True;
      E.Mixer_Profile := True;
      R := Ack;
   end Set_PID_Advanced;

   --  A request of fixed fields: each value from its offset and width, in
   --  order, checked together.
   procedure Set_Fields
     (C : in out Configuration; Request : Byte_Array; Fields : Plan; R : out Result)
     with Pre  => Request'Length <= Max_Request and then Fits (Fields),
          Post => (if R = Error then C = C'Old)
   is
   begin
      if not Valid (Fields) then
         R := Error;
         return;
      end if;
      Apply (C, Fields);
      R := Ack;
   end Set_Fields;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array;
      Gyro_Sample_Rate_Hz : Config_Fix.Gyro_Rate; R : out Result; E : out Effects)
   is
      P : Plan;
   begin
      E := No_Effects;
      case Command is
         when Set_Advanced_Config_Command =>
            Set_Advanced_Config (C, Request, Gyro_Sample_Rate_Hz, R);
         when Set_Filter_Config_Command =>
            Set_Filter_Config (C, Request, Gyro_Sample_Rate_Hz, R, E);
         when Set_PID_Advanced_Command =>
            Set_PID_Advanced (C, Request, R, E);
         when Set_PID_Command =>
            Set_PID (C, Request, R, E);
         when Set_RC_Tuning_Command =>
            Set_RC_Tuning (C, Request, R, E);
         when Set_Arming_Config_Command =>
            Set_Arming_Config (C, Request, R);
         when Set_PID_Controller_Command =>
            R := Ack;
         when Set_Acc_Trim_Command =>
            Add (P, Acc_Trim_Pitch, S16 (Request, 0), 0);
            Add (P, Acc_Trim_Roll, S16 (Request, 2), 0);
            Set_Fields (C, Request, P, R);
         when Set_Motor_3D_Config_Command =>
            Add (P, Three_D_Deadband_Low, U16 (Request, 0), 0);
            Add (P, Three_D_Deadband_High, U16 (Request, 2), 0);
            Add (P, Three_D_Neutral, U16 (Request, 4), 0);
            Set_Fields (C, Request, P, R);
         when Set_RC_Deadband_Command =>
            Add (P, Deadband, U8 (Request, 0), 0);
            Add (P, Yaw_Deadband, U8 (Request, 1), 0);
            Add (P, Pos_Hold_Deadband, U8 (Request, 2), 0);
            Add (P, Three_D_Deadband_Throttle, U16 (Request, 3), 0);
            Set_Fields (C, Request, P, R);
         when Set_Reset_Current_PID_Command =>
            C.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index)) :=
              Defaults.Pid_Profiles (Natural (C.System_Config.Pid_Profile_Index));
            R := Ack;
         when Set_Sensor_Alignment_Command =>
            Set_Sensor_Alignment (C, Request, R);
         when Set_Board_Alignment_Config_Command =>
            Add (P, Align_Board_Roll, S16 (Request, 0), 0);
            Add (P, Align_Board_Pitch, S16 (Request, 2), 0);
            Add (P, Align_Board_Yaw, S16 (Request, 4), 0);
            Set_Fields (C, Request, P, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Tuning_In;
