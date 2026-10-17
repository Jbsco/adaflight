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
   Max_Writes : constant := 20;

   type Planned is record
      S       : Setting := P_Roll;
      Value   : Integer_64 := 0;
      Profile : Natural := 0;
   end record;

   type Planned_List is array (1 .. Max_Writes) of Planned;

   type Plan is record
      Items : Planned_List;
      Count : Natural range 0 .. Max_Writes := 0;
   end record;

   function Fits (P : Plan) return Boolean is
     (for all K in 1 .. P.Count => P.Items (K).Profile < Profile_Count (P.Items (K).S));

   procedure Add (P : in out Plan; S : Setting; Value : Integer_64; Profile : Natural)
     with Pre  => P.Count < Max_Writes and then Fits (P) and then Profile < Profile_Count (S),
          Post => Fits (P) and then P.Count = P.Count'Old + 1
   is
   begin
      P.Count := P.Count + 1;
      P.Items (P.Count) := (S => S, Value => Value, Profile => Profile);
   end Add;

   function Valid (P : Plan) return Boolean is
     (for all K in 1 .. P.Count => In_Range (P.Items (K).S, P.Items (K).Value));

   procedure Apply (C : in out Configuration; P : Plan)
     with Pre => Fits (P)
   is
   begin
      for K in 1 .. P.Count loop
         Set (C, P.Items (K).S, P.Items (K).Value, P.Items (K).Profile);
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
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
      P : Plan;
   begin
      E := (PID_Init => False, RC_Init => False);
      case Command is
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
