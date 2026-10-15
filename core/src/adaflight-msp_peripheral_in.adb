with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Peripheral_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Wing_Bytes     : constant := 45;
   Provider_Count : constant := 3;

   --  The data each provider sends: ILAP, ARCITIMER, ERLT.
   type Length_List is array (1 .. Provider_Count) of Natural range 0 .. 9;
   Data_Length : constant Length_List := (6, 9, 1);

   --  A provider, then for one of the three exactly its data's length of
   --  bytes: the stored data cleared and the request's data written.
   procedure Set_Transponder (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Provider : constant Integer_64 := U8 (Request, 0);
   begin
      if Request'Length < 1
        or else Provider > Provider_Count
        or else (Provider > 0 and then Request'Length - 1 /= Data_Length (Positive (Provider)))
      then
         R := Error;
         return;
      end if;
      C.Transponder_Config.Provider := Byte (Provider);
      if Provider > 0 then
         C.Transponder_Config.Data := (others => 0);
         for K in 0 .. Data_Length (Positive (Provider)) - 1 loop
            C.Transponder_Config.Data (K) := Byte (U8 (Request, 1 + K));
         end loop;
         E.Transponder_Data := True;
      end if;
      R := Ack;
   end Set_Transponder;

   --  The wing's tuning into the current PID profile, in at least 45 bytes:
   --  the S gains, the setpoint attenuation centers, widths and modes, the
   --  TPA curve and speed settings, the yaw type and the angle pitch offset.
   procedure Set_Wing (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Profile_Valid (C) and then Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Index : constant Natural := Natural (C.System_Config.Pid_Profile_Index);
   begin
      if Request'Length < Wing_Bytes then
         R := Error;
         return;
      end if;
      for Axis in 0 .. 2 loop
         C.Pid_Profiles (Index).Pid (Axis).S := Byte (U8 (Request, Axis));
      end loop;
      for Axis in 0 .. 2 loop
         C.Pid_Profiles (Index).Spa_Center (Axis) := Interfaces.Unsigned_16 (U16 (Request, 3 + 2 * Axis));
      end loop;
      for Axis in 0 .. 2 loop
         C.Pid_Profiles (Index).Spa_Width (Axis) := Interfaces.Unsigned_16 (U16 (Request, 9 + 2 * Axis));
      end loop;
      for Axis in 0 .. 2 loop
         C.Pid_Profiles (Index).Spa_Mode (Axis) := Byte (U8 (Request, 15 + Axis));
      end loop;
      C.Pid_Profiles (Index).Tpa_Curve_Type := Byte (U8 (Request, 18));
      C.Pid_Profiles (Index).Tpa_Curve_Stall_Throttle := Byte (U8 (Request, 19));
      C.Pid_Profiles (Index).Tpa_Curve_Pid_Thr0 := Interfaces.Unsigned_16 (U16 (Request, 20));
      C.Pid_Profiles (Index).Tpa_Curve_Pid_Thr100 := Interfaces.Unsigned_16 (U16 (Request, 22));
      C.Pid_Profiles (Index).Tpa_Curve_Expo := Interfaces.Integer_8 (S8 (Request, 24));
      C.Pid_Profiles (Index).Tpa_Speed_Type := Byte (U8 (Request, 25));
      C.Pid_Profiles (Index).Tpa_Speed_Basic_Delay := Interfaces.Unsigned_16 (U16 (Request, 26));
      C.Pid_Profiles (Index).Tpa_Speed_Basic_Gravity := Interfaces.Unsigned_16 (U16 (Request, 28));
      C.Pid_Profiles (Index).Tpa_Speed_Adv_Prop_Pitch := Interfaces.Unsigned_16 (U16 (Request, 30));
      C.Pid_Profiles (Index).Tpa_Speed_Adv_Mass := Interfaces.Unsigned_16 (U16 (Request, 32));
      C.Pid_Profiles (Index).Tpa_Speed_Adv_Drag_K := Interfaces.Unsigned_16 (U16 (Request, 34));
      C.Pid_Profiles (Index).Tpa_Speed_Adv_Thrust := Interfaces.Unsigned_16 (U16 (Request, 36));
      C.Pid_Profiles (Index).Tpa_Speed_Max_Voltage := Interfaces.Unsigned_16 (U16 (Request, 38));
      C.Pid_Profiles (Index).Tpa_Speed_Pitch_Offset := Interfaces.Integer_16 (S16 (Request, 40));
      C.Pid_Profiles (Index).Yaw_Type := Byte (U8 (Request, 42));
      C.Pid_Profiles (Index).Angle_Pitch_Offset := Interfaces.Integer_16 (S16 (Request, 43));
      E.PID_Init := True;
      R := Ack;
   end Set_Wing;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result;
      E : out Effects)
   is
   begin
      E := No_Effects;
      case Command is
         when Set_Transponder_Config_Command =>
            Set_Transponder (C, Request, R, E);
         when Set_Wing_Command =>
            Set_Wing (C, Request, R, E);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Peripheral_In;
