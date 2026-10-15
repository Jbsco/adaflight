with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Peripheral_In with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_8;

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

   Table_Size         : constant := 8;
   Band_Name_Length   : constant := 8;
   Power_Label_Length : constant := 3;

   --  The request's byte at an offset, zero past its end.
   function Byte_At (Request : Byte_Array; Offset : Natural) return Byte is
     (if Offset < Request'Length then Request (Request'First + Offset) else 0)
     with Pre => Request'Length <= Max_Request;

   --  A letter in upper case.
   function Upper (B : Byte) return Byte is
     (if B in Character'Pos ('a') .. Character'Pos ('z') then B - 32 else B);

   --  A text's bytes up to a length and before its first zero, padded with
   --  spaces to the length and ended with a zero byte.
   procedure Put_Padded (Dst : out Config_Groups.Bytes; Text : Config_Groups.Bytes; Length : Natural)
     with Pre => Length <= Band_Name_Length and then Text'First = 0 and then Text'Last >= Length
                 and then Dst'First = 0 and then Dst'Last = Length
   is
      Ended : Boolean := False;
   begin
      Dst := (others => 0);
      for K in 0 .. Length - 1 loop
         if Text (K) = 0 then
            Ended := True;
         end if;
         Dst (K) := (if Ended then Character'Pos (' ') else Text (K));
      end loop;
   end Put_Padded;

   --  A band, its name, letter and factory flag, and its frequencies, up to
   --  the table's channels and zero past those the request gives. When the
   --  band is the VTX's, the VTX frequency follows its channel.
   procedure Set_Band (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Length    : constant Natural := Request'Length;
      Band      : constant Natural := Natural (Byte_At (Request, 0));
      Name_Size : constant Natural := Natural (Byte_At (Request, 1));
      Base      : constant Natural := 2 + Name_Size;
      Count     : constant Natural := Natural (Byte_At (Request, Base + 2));
      Bands     : constant Natural := Natural'Min (Natural (C.Vtx_Table_Config.Bands), Table_Size);
      Channels  : constant Natural := Natural'Min (Natural (C.Vtx_Table_Config.Channels), Table_Size);
      Name      : Config_Groups.Bytes (0 .. Band_Name_Length) := (others => 0);
      Freqs     : Unsigned_16_List_8 := (others => 0);
      P         : Plan;
   begin
      if Length < Base + 3 or else Length - (Base + 3) < 2 * Count or else Band < 1 or else Band > Bands then
         R := Error;
         return;
      end if;
      for K in 0 .. Natural'Min (Name_Size, Band_Name_Length) - 1 loop
         Name (K) := Upper (Byte_At (Request, 2 + K));
      end loop;
      for I in 0 .. Natural'Min (Count, Channels) - 1 loop
         Freqs (I) := Interfaces.Unsigned_16 (Byte_At (Request, Base + 3 + 2 * I))
           + 256 * Interfaces.Unsigned_16 (Byte_At (Request, Base + 4 + 2 * I));
      end loop;
      if Band = Natural (C.Vtx_Settings_Config.Band) then
         declare
            Channel : constant Natural := Natural (C.Vtx_Settings_Config.Channel);
         begin
            Add (P, Vtx_Freq, (if Channel in 1 .. Channels then Integer_64 (Freqs (Channel - 1)) else 0), 0);
         end;
         if not Valid (P) then
            R := Error;
            return;
         end if;
      end if;
      Put_Padded (C.Vtx_Table_Config.Band_Names (Band - 1), Name, Band_Name_Length);
      C.Vtx_Table_Config.Band_Letters (Band - 1) := Upper (Byte_At (Request, Base));
      C.Vtx_Table_Config.Is_Factory_Band (Band - 1) := Byte_At (Request, Base + 1) /= 0;
      for I in 0 .. Channels - 1 loop
         C.Vtx_Table_Config.Frequency (Band - 1) (I) := Freqs (I);
      end loop;
      Apply (C, P);
      E.Table_Init := True;
      E.VTX_Ready := True;
      R := Ack;
   end Set_Band;

   --  A power level, its value and its label, the level within the table's
   --  count.
   procedure Set_Power_Level (C : in out Configuration; Request : Byte_Array; R : out Result; E : in out Effects)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old and then E = E'Old)
   is
      Level  : constant Natural := Natural (Byte_At (Request, 0));
      Size   : constant Natural := Natural (Byte_At (Request, 3));
      Levels : constant Natural := Natural'Min (Natural (C.Vtx_Table_Config.Power_Levels), Table_Size);
      Label  : Config_Groups.Bytes (0 .. Power_Label_Length) := (others => 0);
   begin
      if (Size > 0 and then Request'Length < 4 + Size) or else Level < 1 or else Level > Levels then
         R := Error;
         return;
      end if;
      for K in 0 .. Natural'Min (Size, Power_Label_Length) - 1 loop
         Label (K) := Upper (Byte_At (Request, 4 + K));
      end loop;
      C.Vtx_Table_Config.Power_Values (Level - 1) := Interfaces.Unsigned_16 (U16 (Request, 1));
      Put_Padded (C.Vtx_Table_Config.Power_Labels (Level - 1), Label, Power_Label_Length);
      E.Table_Init := True;
      E.VTX_Ready := True;
      R := Ack;
   end Set_Power_Level;

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
         when Set_VTX_Table_Band_Command =>
            Set_Band (C, Request, R, E);
         when Set_VTX_Table_Power_Level_Command =>
            Set_Power_Level (C, Request, R, E);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Peripheral_In;
