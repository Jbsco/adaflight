with Interfaces; use Interfaces;
with Adaflight.Adjustments;
with Adaflight.Config_Fix;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.MSP_Box;
with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package body Adaflight.Command_Line with SPARK_Mode is

   CRLF : constant String := (ASCII.CR, ASCII.LF);

   function Decimal (V : Integer_64) return String renames CLI_Text.Decimal;

   --  The profile a setting reads: its scope's, none outside the profiles.
   function Profile_Of (S : Setting; P : Profiles) return Natural is
     (case Profile_Count (S) is
         when 3 => P.Battery,
         when 4 => (if Describe (S).Where = Rate_Profile then P.Rate else P.PID),
         when others => 0)
     with Pre  => Valid (P),
          Post => Profile_Of'Result < Profile_Count (S);

   --  A value's text, with the direct range after it for Full, then a
   --  corrupted value's error on a line of its own.
   procedure Put_Value
     (Into : in out Sink; C : Configuration; S : Setting; Profile : Natural; Command : String; Full : Boolean;
      Ports : Port_List)
     with Pre => Profile < Profile_Count (S) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      I         : constant Info := Describe (S);
      V         : Integer_64;
      Corrupted : Boolean := False;
   begin
      if I.How = List then
         for K in 0 .. Element_Count (S) - 1 loop
            if K > 0 then
               Put (Into, ",");
            end if;
            Put (Into, Decimal (Get (C, S, Profile, K)));
         end loop;
         return;
      end if;
      V := Get (C, S, Profile);
      case I.How is
         when Direct =>
            Put (Into, Decimal (V));
            case I.Kind is
               when U32 =>
                  Corrupted := V > I.Max;
                  if Full and then not Corrupted then
                     Put (Into, " 0 " & Decimal (I.Max));
                  end if;
               when I32 =>
                  Corrupted := V > I.Max or else V < -I.Max;
                  if Full and then not Corrupted then
                     Put (Into, " 0 " & Decimal (I.Max));
                  end if;
               when U8 | I8 | U16 | I16 =>
                  Corrupted := V < I.Min or else V > I.Max;
                  if Full and then not Corrupted then
                     Put (Into, " " & Decimal (I.Min) & " " & Decimal (I.Max));
                  end if;
            end case;
         when Lookup =>
            if V >= 0 and then V < Integer_64 (Value_Count (I.Table))
              and then Value_Name (I.Table, Natural (V))'Length > 0
            then
               Put (Into, Value_Name (I.Table, Natural (V)));
            else
               Corrupted := True;
            end if;
         when Identifier =>
            if CLI_Text.Port_Name (V, Ports)'Length > 0 then
               Put (Into, CLI_Text.Port_Name (V, Ports));
            else
               Corrupted := True;
            end if;
         when Bitset =>
            Put (Into, (if V /= 0 then "ON" else "OFF"));
         when Text =>
            declare
               T : constant String := Get_Text (C, S, Profile);
            begin
               if T'Length = 0 then
                  Put (Into, "-");
               else
                  Put (Into, T (T'First .. T'First + (Natural'Min (T'Length, I.Count) - 1)));
               end if;
            end;
         when List =>
            null;
      end case;
      if Corrupted then
         Put (Into, CRLF);
         Put (Into, "###ERROR IN ");
         Put (Into, Command);
         Put (Into, ": CORRUPTED CONFIG: ");
         Put (Into, Name (S));
         Put (Into, " = " & Decimal (if I.Kind = U32 and then V > 2 ** 31 - 1 then V - 2 ** 32 else V) & "###");
      end if;
   end Put_Value;

   --  The values a setting takes, on a line; nothing for a port.
   procedure Put_Range (Into : in out Sink; S : Setting) is
      I     : constant Info := Describe (S);
      First : Boolean := True;
   begin
      case I.How is
         when Direct =>
            case I.Kind is
               when U32 =>
                  Put (Into, "Allowed range: 0 - " & Decimal (I.Max) & CRLF);
               when I32 =>
                  Put (Into, "Allowed range: " & Decimal (-I.Max) & " - " & Decimal (I.Max) & CRLF);
               when U8 | I8 | U16 | I16 =>
                  Put (Into, "Allowed range: " & Decimal (I.Min) & " - " & Decimal (I.Max) & CRLF);
            end case;
         when Lookup =>
            Put (Into, "Allowed values: ");
            for K in 0 .. Value_Count (I.Table) - 1 loop
               if Value_Name (I.Table, K)'Length > 0 then
                  if not First then
                     Put (Into, ", ");
                  end if;
                  Put (Into, Value_Name (I.Table, K));
                  First := False;
               end if;
            end loop;
            Put (Into, CRLF);
         when List =>
            Put (Into, "Array length: " & Decimal (Integer_64 (I.Count)) & CRLF);
         when Text =>
            Put (Into, "String length: " & Decimal (Integer_64 (I.Min_Length)) & " - " & Decimal (Integer_64 (I.Count))
                 & CRLF);
         when Bitset =>
            Put (Into, "Allowed values: OFF, ON" & CRLF);
         when Identifier =>
            null;
      end case;
   end Put_Range;

   --  Whether a setting holds its default; a text compares its first byte.
   function Equals_Default (C : Configuration; S : Setting; Profile : Natural) return Boolean
     with Pre => Profile < Profile_Count (S)
   is
      I : constant Info := Describe (S);
   begin
      case I.How is
         when List =>
            for K in 0 .. Element_Count (S) - 1 loop
               if Get (C, S, Profile, K) /= Get (Defaults, S, Profile, K) then
                  return False;
               end if;
            end loop;
            return True;
         when Text =>
            declare
               T : constant String := Get_Text (C, S, Profile);
               D : constant String := Get_Text (Defaults, S, Profile);
            begin
               return (if T'Length = 0 then D'Length = 0 else D'Length > 0 and then T (T'First) = D (D'First));
            end;
         when Direct | Lookup | Bitset | Identifier =>
            return Get (C, S, Profile) = Get (Defaults, S, Profile);
      end case;
   end Equals_Default;

   ---------
   -- Get --
   ---------

   procedure Get (Into : in out Sink; C : Configuration; Command : String; Fragment : String; Ports : Port_List)
   is
      P       : constant Profiles := Current (C);
      Matched : Boolean := False;
   begin
      for S in Setting loop
         if CLI_Text.Contains_Ignoring_Case (Name (S), Fragment) then
            if Matched then
               Put (Into, CRLF);
            end if;
            Put (Into, Name (S));
            Put (Into, " = ");
            Put_Value (Into, C, S, Profile_Of (S, P), Command, False, Ports);
            Put (Into, CRLF);
            case Describe (S).Where is
               when PID_Profile =>
                  Put (Into, "profile " & Decimal (Integer_64 (P.PID)) & CRLF);
               when Rate_Profile =>
                  Put (Into, "rateprofile " & Decimal (Integer_64 (P.Rate)) & CRLF);
               when Battery_Profile =>
                  Put (Into, "battery_profile " & Decimal (Integer_64 (P.Battery)) & CRLF);
               when Master | Hardware =>
                  null;
            end case;
            Put_Range (Into, S);
            if not Equals_Default (C, S, Profile_Of (S, P)) then
               Put (Into, "Default value: ");
               Put_Value (Into, Defaults, S, Profile_Of (S, P), Command, False, Ports);
               Put (Into, CRLF);
            end if;
            Matched := True;
         end if;
      end loop;
      if not Matched then
         Put (Into, "###ERROR IN ");
         Put (Into, Command);
         Put (Into, ": INVALID NAME: ");
         Put (Into, Fragment);
         Put (Into, "###" & CRLF);
      end if;
   end Get;

   --  Up to 50 numbers between commas, as many as the array setting has,
   --  each within its type, written to every element; or nothing written.
   procedure Set_Array (C : in out Configuration; S : Setting; Profile : Natural; Text : String; Done : out Boolean)
     with Pre => Profile < Profile_Count (S) and then Text'First >= 1 and then Text'Last < Positive'Last
   is
      I      : constant Info := Describe (S);
      Length : constant Positive := Element_Count (S);
      Values : array (0 .. 49) of Integer_64 := (others => 0);
      Count  : Natural := 0;
      P      : Positive := Text'First;
      Next   : Positive;
   begin
      Done := False;
      if Text'Length = 0 or else Length > Values'Length then
         return;
      end if;
      while P <= Text'Last loop
         pragma Loop_Invariant (Count <= Length and then P in Text'First .. Text'Last);
         while P <= Text'Last and then Text (P) = ' ' loop
            pragma Loop_Invariant (P in Text'First .. Text'Last);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         exit when P > Text'Last;
         if Text (P) = ',' or else Count >= Length then
            return;
         end if;
         case I.Kind is
            when U8 | U16 | U32 =>
               if Text (P) = '-' then
                  return;
               end if;
               declare
                  U : Unsigned_32;
               begin
                  CLI_Text.Parse_Unsigned (Text (P .. Text'Last), U, Next);
                  Values (Count) := Integer_64 (U);
               end;
            when I8 | I16 | I32 =>
               declare
                  V : Integer_32;
               begin
                  CLI_Text.Parse_Signed (Text (P .. Text'Last), V, Next);
                  Values (Count) := Integer_64 (V);
               end;
         end case;
         if Next = P then
            return;
         end if;
         while Next <= Text'Last and then Text (Next) = ' ' loop
            pragma Loop_Invariant (Next in P + 1 .. Text'Last);
            pragma Loop_Variant (Increases => Next);
            Next := Next + 1;
         end loop;
         if Next <= Text'Last and then Text (Next) /= ',' then
            return;
         end if;
         Count := Count + 1;
         if Next > Text'Last then
            P := Next;
            exit;
         end if;
         P := Next + 1;
      end loop;
      if Count /= Length or else (P > Text'First and then Text (P - 1) = ',') then
         return;
      end if;
      for K in 0 .. Length - 1 loop
         case I.Kind is
            when U8 =>
               if Values (K) > 255 then
                  return;
               end if;
            when I8 =>
               if Values (K) not in -128 .. 127 then
                  return;
               end if;
            when U16 =>
               if Values (K) > 65_535 then
                  return;
               end if;
            when I16 =>
               if Values (K) not in -32_768 .. 32_767 then
                  return;
               end if;
            when U32 | I32 =>
               null;
         end case;
      end loop;
      for K in 0 .. Length - 1 loop
         Config_Groups.Set (C, S, Values (K), Profile, K);
      end loop;
      Done := True;
   end Set_Array;

   ---------
   -- Set --
   ---------

   procedure Set (Into : in out Sink; C : in out Configuration; Arguments : String; Ports : Port_List) is
      P      : constant Profiles := Current (C);
      Equals : Natural := 0;
   begin
      if Arguments'Length = 0 or else Arguments = "*" then
         Put (Into, "Current settings: " & CRLF);
         for S in Setting loop
            Put (Into, Name (S));
            Put (Into, " = ");
            Put_Value (Into, C, S, Profile_Of (S, P), "set", Arguments'Length = 1, Ports);
            Put (Into, CRLF);
         end loop;
         return;
      end if;
      for K in Arguments'Range loop
         if Arguments (K) = '=' then
            Equals := K;
            exit;
         end if;
      end loop;
      if Equals = 0 then
         Get (Into, C, "set", Arguments, Ports);
         return;
      end if;
      declare
         Name_Last   : Natural := Equals - 1;
         Value_First : Positive := Equals + 1;
         Found       : Boolean := False;
         Target      : Setting := Setting'First;
      begin
         while Name_Last >= Arguments'First and then Arguments (Name_Last) = ' ' loop
            pragma Loop_Invariant (Name_Last in Arguments'First .. Equals - 1);
            pragma Loop_Variant (Decreases => Name_Last);
            Name_Last := Name_Last - 1;
         end loop;
         while Value_First <= Arguments'Last and then Arguments (Value_First) = ' ' loop
            pragma Loop_Invariant (Value_First in Equals + 1 .. Arguments'Last);
            pragma Loop_Variant (Increases => Value_First);
            Value_First := Value_First + 1;
         end loop;
         for S in Setting loop
            if CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Name_Last), Name (S)) then
               Found := True;
               Target := S;
               exit;
            end if;
         end loop;
         if not Found then
            Put (Into, "###ERROR IN set: INVALID NAME: ");
            Put (Into, Arguments);
            Put (Into, "###" & CRLF);
            return;
         end if;
         declare
            Value   : constant String := Arguments (Value_First .. Arguments'Last);
            I       : constant Info := Describe (Target);
            Profile : constant Natural := Profile_Of (Target, P);
            Changed : Boolean := False;
         begin
            case I.How is
               when Direct =>
                  case I.Kind is
                     when U32 =>
                        declare
                           U    : Unsigned_32;
                           Next : Positive;
                        begin
                           CLI_Text.Parse_Unsigned (Value, U, Next);
                           pragma Unreferenced (Next);
                           if Integer_64 (U) <= I.Max then
                              Config_Groups.Set (C, Target, Integer_64 (U), Profile);
                              Changed := True;
                           end if;
                        end;
                     when I32 =>
                        declare
                           V    : Integer_32;
                           Next : Positive;
                        begin
                           CLI_Text.Parse_Signed (Value, V, Next);
                           pragma Unreferenced (Next);
                           if Integer_64 (V) <= I.Max and then Integer_64 (V) >= -I.Max then
                              Config_Groups.Set (C, Target, Integer_64 (V), Profile);
                              Changed := True;
                           end if;
                        end;
                     when U8 | I8 | U16 | I16 =>
                        declare
                           V : constant Integer_32 := CLI_Text.To_Integer (Value);
                        begin
                           if Integer_64 (V) >= I.Min and then Integer_64 (V) <= I.Max then
                              Config_Groups.Set (C, Target, Integer_64 (V), Profile);
                              Changed := True;
                           end if;
                        end;
                  end case;
               when Lookup | Bitset =>
                  declare
                     Table : constant Lookup_Table := (if I.How = Bitset then Table_Off_On else I.Table);
                  begin
                     for K in 0 .. Value_Count (Table) - 1 loop
                        if Value_Name (Table, K)'Length > 0
                          and then CLI_Text.Same_Ignoring_Case (Value_Name (Table, K), Value)
                        then
                           Config_Groups.Set (C, Target, Integer_64 (K), Profile);
                           Changed := True;
                           exit;
                        end if;
                     end loop;
                  end;
               when Identifier =>
                  declare
                     Known_Port : Boolean;
                     Id         : Integer_64;
                  begin
                     CLI_Text.Port_From_Name (Value, Ports, Known_Port, Id);
                     if Known_Port then
                        Config_Groups.Set (C, Target, Id, Profile);
                        Changed := True;
                     end if;
                  end;
               when List =>
                  Set_Array (C, Target, Profile, Value, Changed);
               when Text =>
                  declare
                     Stored    : constant String := Get_Text (C, Target, Profile);
                     Updatable : constant Boolean :=
                       not I.Write_Once or else Stored'Length = 0
                       or else (Stored'Length >= Value'Length
                                and then Stored (Stored'First .. Stored'First + (Value'Length - 1)) = Value);
                  begin
                     if Updatable and then Value'Length > 0 and then Value'Length <= I.Count then
                        Config_Groups.Set_Text
                          (C, Target, (if Value'Length >= I.Min_Length and then Value /= "-" then Value else ""),
                           Profile);
                        Changed := True;
                     else
                        Put (Into, "###ERROR IN set: STRING MUST BE 1-" & Decimal (Integer_64 (I.Count))
                             & " CHARACTERS OR '-' FOR EMPTY###" & CRLF);
                     end if;
                  end;
            end case;
            if Changed then
               Put (Into, Name (Target));
               Put (Into, " set to ");
               Put_Value (Into, C, Target, Profile, "set", False, Ports);
            else
               Put (Into, "###ERROR IN set: INVALID VALUE###" & CRLF);
               Put_Range (Into, Target);
            end if;
         end;
      end;
   end Set;

   type Profile_Kind is (PID, Rate, Battery);

   function Profile_Word (Kind : Profile_Kind) return String is
     (case Kind is
         when PID => "profile",
         when Rate => "rateprofile",
         when Battery => "battery_profile");

   --  The selected profile, or a profile selected by number with its
   --  runtime work asked for.
   procedure Profile_Command
     (Into : in out Sink; C : in out Configuration; Kind : Profile_Kind; Arguments : String;
      Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Count : constant Integer_32 := (if Kind = Battery then 3 else 4);
      Index : Integer_32;
   begin
      if Arguments'Length > 0 then
         Index := CLI_Text.To_Integer (Arguments);
         if Index not in 0 .. Count - 1 then
            Put (Into, "###ERROR IN " & Profile_Word (Kind) & ": "
                 & (case Kind is
                       when PID => "PROFILE",
                       when Rate => "RATE PROFILE",
                       when Battery => "BATTERY PROFILE")
                 & " OUTSIDE OF [0.." & Decimal (Integer_64 (Count - 1)) & "]###" & CRLF);
            return;
         end if;
         case Kind is
            when PID =>
               C.System_Config.Pid_Profile_Index := Unsigned_8 (Index);
               Changes.PID_Profile := True;
            when Rate =>
               C.System_Config.Active_Rate_Profile := Unsigned_8 (Index);
               Changes.Rate_Profile := True;
            when Battery =>
               C.System_Config.Active_Battery_Profile := Unsigned_8 (Index);
               Changes.Battery_Profile := True;
         end case;
      end if;
      Put (Into, Profile_Word (Kind) & " "
           & Decimal (Integer_64 (case Kind is
                                     when PID => C.System_Config.Pid_Profile_Index,
                                     when Rate => C.System_Config.Active_Rate_Profile,
                                     when Battery => C.System_Config.Active_Battery_Profile))
           & CRLF);
   end Profile_Command;

   --  A profile's or a rate profile's settings as set lines under a heading;
   --  for a diff only those off their default, under a heading printed with
   --  the first of them, each after its default for Show_Defaults.
   procedure Dump_Profile
     (Into : in out Sink; C : Configuration; Kind : Profile_Kind; Index : Natural; Command : String; Diff : Boolean;
      Show_Defaults : Boolean; Ports : Port_List)
     with Pre => Kind in PID | Rate and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      P       : constant Profiles := (PID => Index, Rate => Index, Battery => 0);
      Pending : Boolean := True;
   begin
      if Index >= 4 then
         return;
      end if;
      Put (Into, CRLF & Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)) & CRLF);
      if not Diff then
         Put (Into, CRLF & "# " & Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)) & CRLF);
         Pending := False;
      end if;
      for S in Setting loop
         if Describe (S).Where = (if Kind = PID then PID_Profile else Rate_Profile) then
            declare
               Profile : constant Natural := Profile_Of (S, P);
               Equal   : constant Boolean := Equals_Default (C, S, Profile);
            begin
               if Diff and then Pending and then not Equal then
                  Put (Into, CRLF & "# " & Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)) & CRLF);
                  Pending := False;
               end if;
               if not Diff or else not Equal then
                  if Show_Defaults and then not Equal then
                     Put (Into, "#set ");
                     Put (Into, Name (S));
                     Put (Into, " = ");
                     Put_Value (Into, Defaults, S, Profile, Command, False, Ports);
                     Put (Into, CRLF);
                  end if;
                  Put (Into, "set ");
                  Put (Into, Name (S));
                  Put (Into, " = ");
                  Put_Value (Into, C, S, Profile, Command, False, Ports);
                  Put (Into, CRLF);
               end if;
            end;
         end if;
      end loop;
   end Dump_Profile;

   --  Whether a text starts a word, without regard to case.
   function Starts (Text, Word : String) return Boolean is
     (Text'Length <= Word'Length
      and then CLI_Text.Same_Ignoring_Case (Text, Word (Word'First .. Word'First + (Text'Length - 1))));

   subtype Feature_Bit is Natural range 0 .. 28;

   function Feature_Name (Bit : Feature_Bit) return String is
     (case Bit is
         when 0 => "RX_PPM",
         when 1 => "RX_UDP",
         when 2 => "INFLIGHT_ACC_CAL",
         when 3 => "RX_SERIAL",
         when 4 => "MOTOR_STOP",
         when 5 => "SERVO_TILT",
         when 6 => "SOFTSERIAL",
         when 7 => "GPS",
         when 8 => "OPTICALFLOW",
         when 9 => "RANGEFINDER",
         when 10 => "TELEMETRY",
         when 12 => "3D",
         when 13 => "RX_PARALLEL_PWM",
         when 14 => "RX_MSP",
         when 15 => "RSSI_ADC",
         when 16 => "LED_STRIP",
         when 17 => "DISPLAY",
         when 18 => "OSD",
         when 20 => "CHANNEL_FORWARDING",
         when 21 => "TRANSPONDER",
         when 22 => "AIRMODE",
         when 25 => "RX_SPI",
         when 27 => "ESC_SENSOR",
         when 28 => "ANTI_GRAVITY",
         when 11 | 19 | 23 | 24 | 26 => "")
     with Post => Feature_Name'Result'Length <= 18;

   --  A header, then the names of a mask's features, each after a space but
   --  the first feature's.
   procedure Put_Features (Into : in out Sink; Header : String; Mask : Unsigned_32) is
   begin
      Put (Into, Header);
      for Bit in Feature_Bit loop
         if Feature_Name (Bit)'Length > 0 and then (Mask and Shift_Left (1, Bit)) /= 0 then
            if Bit > 0 then
               Put (Into, " ");
            end if;
            Put (Into, Feature_Name (Bit));
         end if;
      end loop;
      Put (Into, CRLF);
   end Put_Features;

   --  feature: the enabled, available and unavailable features; a feature,
   --  the first whose name the text starts, enabled or, after a minus,
   --  disabled in the configuration.
   procedure Feature_Command (Into : in out Sink; C : in out Configuration; Arguments : String)
     with Pre => Arguments'Last < Positive'Last
   is
      Mask      : constant Unsigned_32 := C.Feature_Config.Enabled_Features;
      Supported : constant Unsigned_32 := Config_Fix.Supported_Features;
   begin
      if Arguments'Length = 0 or else Starts (Arguments, "list") then
         Put_Features (Into, "Enabled: ", Mask);
         Put_Features (Into, "Available: ", (not Mask) and Supported);
         Put_Features (Into, "Unavailable: ", not Supported);
         return;
      end if;
      declare
         Remove : constant Boolean := Arguments (Arguments'First) = '-';
         Text   : constant String :=
           (if Remove then Arguments (Arguments'First + 1 .. Arguments'Last) else Arguments);
      begin
         for Bit in Feature_Bit loop
            if Feature_Name (Bit)'Length > 0 and then Starts (Text, Feature_Name (Bit)) then
               declare
                  Feature : constant Unsigned_32 := Shift_Left (1, Bit);
               begin
                  if (Feature and Supported) = 0 then
                     Put (Into, "Unavailable");
                  elsif Remove then
                     C.Feature_Config.Enabled_Features := C.Feature_Config.Enabled_Features and not Feature;
                     Put (Into, (if (Mask and Feature) /= 0 then "Disabled" else "AlreadyDisabled"));
                  else
                     C.Feature_Config.Enabled_Features := C.Feature_Config.Enabled_Features or Feature;
                     Put (Into, (if (Mask and Feature) /= 0 then "AlreadyEnabled" else "Enabled"));
                  end if;
                  Put (Into, " " & Feature_Name (Bit) & CRLF);
               end;
               return;
            end if;
         end loop;
         Put (Into, "###ERROR IN feature: INVALID NAME: ");
         Put (Into, Text);
         Put (Into, "###" & CRLF);
      end;
   end Feature_Command;

   subtype Beeper_Index is Natural range 0 .. 23;
   All_Beepers : constant Beeper_Index := 23;

   function Beeper_Name (I : Beeper_Index) return String is
     (case I is
         when 0 => "GYRO_CALIBRATED",
         when 1 => "RX_LOST",
         when 2 => "RX_LOST_LANDING",
         when 3 => "DISARMING",
         when 4 => "ARMING",
         when 5 => "ARMING_GPS_FIX",
         when 6 => "ARMING_GPS_NO_FIX",
         when 7 => "BAT_CRIT_LOW",
         when 8 => "BAT_LOW",
         when 9 => "GPS_STATUS",
         when 10 => "RX_SET",
         when 11 => "ACC_CALIBRATION",
         when 12 => "ACC_CALIBRATION_FAIL",
         when 13 => "READY_BEEP",
         when 14 => "MULTI_BEEPS",
         when 15 => "DISARM_REPEAT",
         when 16 => "ARMED",
         when 17 => "SYSTEM_INIT",
         when 18 => "ON_USB",
         when 19 => "BLACKBOX_ERASE",
         when 20 => "CRASHFLIP",
         when 21 => "CAM_CONNECTION_OPEN",
         when 22 => "CAM_CONNECTION_CLOSE",
         when 23 => "ALL")
     with Post => Beeper_Name'Result'Length in 1 .. 20;

   --  The flag of a beeper table entry's mode.
   function Beeper_Mask (I : Beeper_Index) return Unsigned_32 is
     (Shift_Left (1, (case I is
                         when 6 => 22,
                         when 7 .. 22 => I - 1,
                         when 23 => 23,
                         when 0 .. 5 => I)));

   --  beeper and beacon: the disabled conditions, the available ones, or a
   --  condition, the first allowed one whose name the text starts, enabled
   --  or, after a minus, disabled; ALL sets every allowed one.
   procedure Beeper_Command
     (Into : in out Sink; Command : String; Flags : in out Unsigned_32; Allowed : Unsigned_32; Arguments : String)
     with Pre => Arguments'Last < Positive'Last
   is
   begin
      if Arguments'Length = 0 then
         Put (Into, "Disabled:");
         for I in 0 .. All_Beepers - 1 loop
            if (Beeper_Mask (I) and Flags) /= 0 then
               Put (Into, "  " & Beeper_Name (I));
            end if;
         end loop;
         if Flags = 0 then
            Put (Into, "  none");
         end if;
         Put (Into, CRLF);
         return;
      end if;
      if Starts (Arguments, "list") then
         Put (Into, "Available:");
         for I in Beeper_Index loop
            if (Beeper_Mask (I) and Allowed) /= 0 then
               Put (Into, " " & Beeper_Name (I));
            end if;
         end loop;
         Put (Into, CRLF);
         return;
      end if;
      declare
         Remove : constant Boolean := Arguments (Arguments'First) = '-';
         Text   : constant String :=
           (if Remove then Arguments (Arguments'First + 1 .. Arguments'Last) else Arguments);
      begin
         for I in Beeper_Index loop
            if Starts (Text, Beeper_Name (I)) and then (Beeper_Mask (I) and (Allowed or Beeper_Mask (All_Beepers))) /= 0
            then
               if Remove then
                  Flags := (if I = All_Beepers then Allowed else Flags or Beeper_Mask (I));
                  Put (Into, "Disabled");
               else
                  Flags := (if I = All_Beepers then 0 else Flags and not Beeper_Mask (I));
                  Put (Into, "Enabled");
               end if;
               Put (Into, " " & Beeper_Name (I) & CRLF);
               return;
            end if;
         end loop;
         Put (Into, "###ERROR IN ");
         Put (Into, Command);
         Put (Into, ": INVALID NAME: ");
         Put (Into, Text);
         Put (Into, "###" & CRLF);
      end;
   end Beeper_Command;

   Condition_Count : constant := Mode_Activation_Condition_Record_List_20'Length;

   --  A box's permanent id by its box id; 0 for an id outside the box table.
   function Permanent_Of (Box_Id : Unsigned_8) return Unsigned_8 is
     (if Box_Id <= Modes.Box'Pos (Modes.Box'Last) then MSP_Box.Permanent_Id (Modes.Box'Val (Box_Id)) else 0);

   --  A mode condition as an aux line: index, mode's permanent id, aux channel,
   --  range ends as channel values, logic, and the linked mode's permanent id.
   procedure Put_Condition (Into : in out Sink; Index : Natural; M : Mode_Activation_Condition_Record) is
   begin
      Put (Into, "aux " & Decimal (Integer_64 (Index)) & " " & Decimal (Integer_64 (Permanent_Of (M.Mode_Id))) & " "
           & Decimal (Integer_64 (M.Aux_Channel_Index)) & " "
           & Decimal (900 + 25 * Integer_64 (M.Range_Value.Start_Step)) & " "
           & Decimal (900 + 25 * Integer_64 (M.Range_Value.End_Step)) & " "
           & Decimal (Integer_64 (M.Mode_Logic)) & " " & Decimal (Integer_64 (Permanent_Of (M.Linked_To))) & CRLF);
   end Put_Condition;

   --  The position of the next argument: past the first space at or after a
   --  position and the spaces that follow; zero when no space follows.
   function Next_Argument (Text : String; From : Natural) return Natural
     with Pre  => Text'Last < Positive'Last,
          Post => Next_Argument'Result = 0 or else Next_Argument'Result in Text'First .. Text'Last + 1
   is
      P : Natural := 0;
   begin
      if From = 0 or else From < Text'First then
         return 0;
      end if;
      for K in From .. Text'Last loop
         if Text (K) = ' ' then
            P := K;
            exit;
         end if;
      end loop;
      if P = 0 then
         return 0;
      end if;
      while P <= Text'Last and then Text (P) = ' ' loop
         pragma Loop_Invariant (P in Text'First .. Text'Last);
         pragma Loop_Variant (Increases => P);
         P := P + 1;
      end loop;
      return P;
   end Next_Argument;

   --  The number an argument starts, as atoi reads it.
   function Argument (Text : String; From : Positive) return Integer_32 is
     (if From > Text'Last then 0 else CLI_Text.To_Integer (Text (From .. Text'Last)))
     with Pre => From >= Text'First and then Text'Last < Positive'Last;

   --  aux: every mode condition, or one condition's mode, aux channel, range,
   --  logic and link from its arguments, the valid ones counted; four valid
   --  take the default logic and no link, five no link, and any other count
   --  clears the condition. A negative index gets the index range error.
   procedure Aux_Command (Into : in out Sink; C : in out Configuration; Arguments : String; Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Index : Integer_32;
      Valid : Natural := 0;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         for I in 0 .. Condition_Count - 1 loop
            if C.Mode_Activation_Conditions (I).Mode_Id <= Modes.Box'Pos (Modes.Box'Last) then
               Put_Condition (Into, I, C.Mode_Activation_Conditions (I));
            end if;
         end loop;
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. Condition_Count - 1 then
         Put (Into, "###ERROR IN aux: INDEX NOT BETWEEN 0 AND " & Decimal (Condition_Count - 1) & "###" & CRLF);
         return;
      end if;
      declare
         Slot  : constant Natural := Natural (Index);
         M     : Mode_Activation_Condition_Record renames C.Mode_Activation_Conditions (Slot);
         Found : Boolean;
         B     : Modes.Box;
         V     : Integer_32;
      begin
         P := Next_Argument (Arguments, Arguments'First + 1);
         if P > 0 then
            MSP_Box.Find_By_Permanent_Id (Unsigned_8'Mod (Argument (Arguments, P)), Found, B);
            if Found then
               M.Mode_Id := Modes.Box'Pos (B);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            V := Argument (Arguments, P);
            if V in 0 .. Modes.Aux_Channel_Count - 1 then
               M.Aux_Channel_Index := Unsigned_8 (V);
               Valid := Valid + 1;
            end if;
         end if;
         for End_Index in 0 .. 1 loop
            P := Next_Argument (Arguments, P);
            if P > 0 then
               V := Argument (Arguments, P);
               V := (Integer_32'Max (900, Integer_32'Min (2100, V)) - 900) / 25;
               if End_Index = 0 then
                  M.Range_Value.Start_Step := Unsigned_8 (V);
               else
                  M.Range_Value.End_Step := Unsigned_8 (V);
               end if;
               Valid := Valid + 1;
            end if;
         end loop;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            V := Argument (Arguments, P);
            if V in 0 .. 1 then
               M.Mode_Logic := Unsigned_8 (V);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            MSP_Box.Find_By_Permanent_Id (Unsigned_8'Mod (Argument (Arguments, P)), Found, B);
            if Found then
               M.Linked_To := Modes.Box'Pos (B);
               Valid := Valid + 1;
            end if;
         end if;
         if Valid = 4 then
            M.Mode_Logic := 0;
            M.Linked_To := 0;
         elsif Valid = 5 then
            M.Linked_To := 0;
         elsif Valid /= 6 then
            M := (Mode_Id => 0, Aux_Channel_Index => 0, Range_Value => (Start_Step => 0, End_Step => 0),
                  Mode_Logic => 0, Linked_To => 0);
         end if;
         Changes.Modes := True;
         Put_Condition (Into, Slot, M);
      end;
   end Aux_Command;

   --  adjrange: every adjustment range, or one range's aux channel, range ends,
   --  function and switch channel from the arguments after a slot argument,
   --  each valid one counted, then its optional center and scale. Any other
   --  count than six clears the range. A negative index gets the index range
   --  error.
   procedure Adjustment_Range_Command
     (Into : in out Sink; C : in out Configuration; Arguments : String; Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Range_Count    : constant := Adjustment_Range_Record_List_30'Length;
      Function_Count : constant := Adjustments.Function_Kind'Pos (Adjustments.Function_Kind'Last) + 1;

      procedure Put_Range (Index : Natural; A : Adjustment_Range_Record) is
      begin
         Put (Into, "adjrange " & Decimal (Integer_64 (Index)) & " 0 "
              & Decimal (Integer_64 (A.Aux_Channel_Index)) & " "
              & Decimal (900 + 25 * Integer_64 (A.Range_Value.Start_Step)) & " "
              & Decimal (900 + 25 * Integer_64 (A.Range_Value.End_Step)) & " "
              & Decimal (Integer_64 (A.Adjustment_Config)) & " " & Decimal (Integer_64 (A.Aux_Switch_Channel_Index))
              & " " & Decimal (Integer_64 (A.Adjustment_Center)) & " " & Decimal (Integer_64 (A.Adjustment_Scale))
              & CRLF);
      end Put_Range;

      Index : Integer_32;
      Valid : Natural := 0;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         for I in 0 .. Range_Count - 1 loop
            Put_Range (I, C.Adjustment_Ranges (I));
         end loop;
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. Range_Count - 1 then
         Put (Into, "###ERROR IN adjrange: INDEX NOT BETWEEN 0 AND " & Decimal (Range_Count - 1) & "###" & CRLF);
         return;
      end if;
      declare
         Slot : constant Natural := Natural (Index);
         A    : Adjustment_Range_Record renames C.Adjustment_Ranges (Slot);
         V    : Integer_32;
      begin
         P := Next_Argument (Arguments, Arguments'First + 1);
         if P > 0 then
            Valid := Valid + 1;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            V := Argument (Arguments, P);
            if V in 0 .. Modes.Aux_Channel_Count - 1 then
               A.Aux_Channel_Index := Unsigned_8 (V);
               Valid := Valid + 1;
            end if;
         end if;
         for End_Index in 0 .. 1 loop
            P := Next_Argument (Arguments, P);
            if P > 0 then
               V := Argument (Arguments, P);
               V := (Integer_32'Max (900, Integer_32'Min (2100, V)) - 900) / 25;
               if End_Index = 0 then
                  A.Range_Value.Start_Step := Unsigned_8 (V);
               else
                  A.Range_Value.End_Step := Unsigned_8 (V);
               end if;
               Valid := Valid + 1;
            end if;
         end loop;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            V := Argument (Arguments, P);
            if V in 0 .. Function_Count - 1 then
               A.Adjustment_Config := Unsigned_8 (V);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            V := Argument (Arguments, P);
            if V in 0 .. Modes.Aux_Channel_Count - 1 then
               A.Aux_Switch_Channel_Index := Unsigned_8 (V);
               Valid := Valid + 1;
            end if;
         end if;
         if Valid /= 6 then
            A := (Aux_Channel_Index => 0, Range_Value => (Start_Step => 0, End_Step => 0), Adjustment_Config => 0,
                  Aux_Switch_Channel_Index => 0, Adjustment_Center => 0, Adjustment_Scale => 0);
            Put (Into, "###ERROR IN adjrange: INVALID ARGUMENT COUNT###" & CRLF);
            return;
         end if;
         A.Adjustment_Center := 0;
         A.Adjustment_Scale := 0;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            A.Adjustment_Center := Unsigned_16'Mod (Argument (Arguments, P));
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            A.Adjustment_Scale := Unsigned_16'Mod (Argument (Arguments, P));
         end if;
         Changes.Adjustments := True;
         Put_Range (Slot, A);
      end;
   end Adjustment_Range_Command;

   Baud_Rates : constant array (Serial_Feature_Map.Baud_Index) of Unsigned_32 :=
     (0, 9600, 19200, 38400, 57600, 115200, 230400, 250000, 400000, 460800, 500000, 921600, 1000000, 1500000,
      2000000, 2470000);

   --  The setting a name names, without regard to case.
   procedure Find_Setting (Text : String; Found : out Boolean; S : out Setting) is
   begin
      for T in Setting loop
         if CLI_Text.Same_Ignoring_Case (Name (T), Text) then
            Found := True;
            S := T;
            return;
         end if;
      end loop;
      Found := False;
      S := Setting'First;
   end Find_Setting;

   --  serial: every claim on the board's ports as the settings that make it,
   --  or a port, a function mask and the msp, gps, telemetry and blackbox
   --  baud rates, each within its class's range, moved onto the feature
   --  settings, then a deprecation line and the port's claims.
   procedure Serial_Command (Into : in out Sink; C : in out Configuration; Arguments : String; Ports : Port_List)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
                 and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      package Map renames Serial_Feature_Map;

      --  A setting's line where its value differs from its default.
      procedure Put_If_Changed (Setting_Name : String)
        with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
      is
         Found : Boolean;
         S     : Setting;
      begin
         if Setting_Name'Length > 0 then
            Find_Setting (Setting_Name, Found, S);
            if Found and then not Equals_Default (C, S, 0) then
               Put (Into, "set ");
               Put (Into, Name (S));
               Put (Into, " = ");
               Put_Value (Into, C, S, 0, "serial", False, Ports);
               Put (Into, CRLF);
            end if;
         end if;
      end Put_If_Changed;

      --  The port's claims, each as its port setting, then its selection and
      --  its baud rate where they differ from their defaults.
      procedure Put_Claims (Port : Map.Port_Id)
        with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
      is
         Claims : Map.Claim_Array;
         Count  : Map.Claim_Count;
      begin
         Map.Port_Claims
           (Config_Fix.Serial_Options, Config_Fix.Serial_Assignments (C), Port, Map.Max_Claims, Claims, Count);
         for K in 1 .. Count loop
            Put (Into, "set ");
            Put (Into, Map.Claim_Setting (Claims (K).Kind));
            Put (Into, " = ");
            Put (Into, CLI_Text.Port_Name (Integer_64 (Port), Ports));
            Put (Into, CRLF);
            Put_If_Changed (Map.Claim_Selector (Claims (K).Kind));
            Put_If_Changed (Map.Claim_Baud_Setting (Claims (K).Kind));
         end loop;
      end Put_Claims;

      --  The text up to the next space or the end, and the position after
      --  that space, zero at the end.
      procedure Next_Token (P : in out Natural; First : out Positive; Last : out Natural)
        with Pre  => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                     and then P in Arguments'First .. Arguments'Last + 1,
             Post => First = P'Old and then Last in First - 1 .. Arguments'Last
                     and then (P = 0 or else P in Arguments'First .. Arguments'Last + 1)
      is
      begin
         First := P;
         Last := P - 1;
         while Last < Arguments'Last and then Arguments (Last + 1) /= ' ' loop
            pragma Loop_Invariant (Last in First - 1 .. Arguments'Last - 1);
            pragma Loop_Variant (Increases => Last);
            Last := Last + 1;
         end loop;
         P := (if Last < Arguments'Last then Last + 2 else 0);
      end Next_Token;

      Order : constant array (1 .. 4) of Map.Baud_Class :=
        (Map.MSP_Baud, Map.GPS_Baud, Map.Telemetry_Baud, Map.Blackbox_Baud);
      Bauds : array (Map.Baud_Class) of Map.Baud_Index :=
        (Map.MSP_Baud       => Map.Default_Port_Baud (Map.MSP_Baud),
         Map.GPS_Baud       => Map.Default_Port_Baud (Map.GPS_Baud),
         Map.Telemetry_Baud => Map.Default_Port_Baud (Map.Telemetry_Baud),
         Map.Blackbox_Baud  => Map.Default_Port_Baud (Map.Blackbox_Baud));
      Valid : Natural;
      Mask  : Unsigned_32 := 0;
      P     : Natural := Arguments'First;
      First : Positive;
      Last  : Natural;
      Found : Boolean;
      Id    : Integer_64;
   begin
      if Arguments'Length = 0 then
         for Port of Ports loop
            Put_Claims (Port);
         end loop;
         return;
      end if;
      Next_Token (P, First, Last);
      CLI_Text.Port_From_Name (Arguments (First .. Last), Ports, Found, Id);
      if not Found then
         declare
            V    : Unsigned_32;
            Next : Positive;
         begin
            CLI_Text.Parse_Unsigned (Arguments (First .. Last), V, Next);
            if Next /= Last + 1 then
               Id := -1;
            else
               Id := (if V > 2 ** 31 - 1 then Integer_64 (V) - 2 ** 32 else Integer_64 (V));
               if Id in 0 .. 19 then
                  Id := Id + 51;
               end if;
            end if;
         end;
      end if;
      if Id = -1 or else not (for some Port of Ports => Integer_64 (Port) = Id) then
         Put (Into, "###ERROR IN serial: PARSING FAILED###" & CRLF);
         return;
      end if;
      Valid := 1;
      if P > 0 then
         Next_Token (P, First, Last);
         declare
            Next : Positive;
         begin
            CLI_Text.Parse_Unsigned (Arguments (First .. Last), Mask, Next);
            pragma Unreferenced (Next);
         end;
         Valid := Valid + 1;
      end if;
      for I in Order'Range loop
         exit when P = 0;
         pragma Loop_Invariant (Valid <= I + 1 and then P in Arguments'First .. Arguments'Last + 1);
         Next_Token (P, First, Last);
         declare
            Val   : constant Unsigned_32 := Unsigned_32'Mod (CLI_Text.To_Integer (Arguments (First .. Last)));
            Index : Map.Baud_Index := Map.Baud_Auto;
         begin
            for K in Map.Baud_Index loop
               if Baud_Rates (K) = Val then
                  Index := K;
                  exit;
               end if;
            end loop;
            exit when Baud_Rates (Index) /= Val;
            if (case Order (I) is
                  when Map.MSP_Baud => Index in 1 .. 12,
                  when Map.GPS_Baud => Index in 1 .. 6,
                  when Map.Telemetry_Baud => Index <= 9,
                  when Map.Blackbox_Baud => Index in 2 .. 15)
            then
               Bauds (Order (I)) := Index;
               Valid := Valid + 1;
            end if;
         end;
      end loop;
      if Valid < 6 then
         Put (Into, "###ERROR IN serial: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      declare
         Port    : constant Map.Port_Id := Map.Port_Id (Id);
         Before  : constant Map.Assignments := Config_Fix.Serial_Assignments (C);
         A       : Map.Assignments := Before;
         Applied : Boolean;
      begin
         Map.Apply_Function_Mask (Config_Fix.Serial_Options, A, Port, Mask, Applied);
         if not Applied then
            Put (Into, "###ERROR IN serial: PARSING FAILED###" & CRLF);
            return;
         end if;
         for K in Map.Baud_Class loop
            Map.Apply_Port_Baud (Config_Fix.Serial_Options, A, Port, K, Bauds (K));
         end loop;
         Config_Fix.Store_Serial_Assignments (C, Before, A);
         Put (Into, "# WARNING: 'serial' is deprecated, assign ports with the <feature>_uart settings" & CRLF);
         Put_Claims (Port);
      end;
   end Serial_Command;

   function Mixer_Name (M : Mixer_Init.Mixer_Mode) return String is
     (case M is
         when Mixer_Init.Tri => "TRI",
         when Mixer_Init.Quad_P => "QUADP",
         when Mixer_Init.Quad_X => "QUADX",
         when Mixer_Init.Bicopter => "BI",
         when Mixer_Init.Gimbal => "GIMBAL",
         when Mixer_Init.Y6 => "Y6",
         when Mixer_Init.Hex6 => "HEX6",
         when Mixer_Init.Flying_Wing => "FLYING_WING",
         when Mixer_Init.Y4 => "Y4",
         when Mixer_Init.Hex6X => "HEX6X",
         when Mixer_Init.Octo_X8 => "OCTOX8",
         when Mixer_Init.Octo_Flat_P => "OCTOFLATP",
         when Mixer_Init.Octo_Flat_X => "OCTOFLATX",
         when Mixer_Init.Airplane => "AIRPLANE",
         when Mixer_Init.Heli_120_CCPM => "HELI_120_CCPM",
         when Mixer_Init.Heli_90_Deg => "HELI_90_DEG",
         when Mixer_Init.Vtail4 => "VTAIL4",
         when Mixer_Init.Hex6H => "HEX6H",
         when Mixer_Init.PPM_To_Servo => "PPM_TO_SERVO",
         when Mixer_Init.Dualcopter => "DUALCOPTER",
         when Mixer_Init.Singlecopter => "SINGLECOPTER",
         when Mixer_Init.Atail4 => "ATAIL4",
         when Mixer_Init.Custom => "CUSTOM",
         when Mixer_Init.Custom_Airplane => "CUSTOMAIRPLANE",
         when Mixer_Init.Custom_Tri => "CUSTOMTRI",
         when Mixer_Init.Quad_X_1234 => "QUADX1234",
         when Mixer_Init.Octo_X8P => "OCTOX8P")
     with Post => Mixer_Name'Result'Length in 2 .. 14;

   --  The first mode whose name a text starts, without regard to case.
   procedure Find_Mixer (Text : String; Found : out Boolean; M : out Mixer_Init.Mixer_Mode) is
   begin
      for N in Mixer_Init.Mixer_Mode loop
         if Starts (Text, Mixer_Name (N)) then
            Found := True;
            M := N;
            return;
         end if;
      end loop;
      Found := False;
      M := Mixer_Init.Mixer_Mode'First;
   end Find_Mixer;

   --  mixer: the mixer mode's name, the list of names, or the first mode a
   --  name starts set and its name. A mode outside the names prints no name.
   procedure Mixer_Command (Into : in out Sink; Mode : in out Unsigned_8; Arguments : String) is
      use Mixer_Init;
      Found : Boolean;
      M     : Mixer_Mode;
   begin
      if Arguments'Length > 0 then
         if Starts (Arguments, "list") then
            Put (Into, "Available:");
            for N in Mixer_Mode loop
               Put (Into, " ");
               Put (Into, Mixer_Name (N));
            end loop;
            Put (Into, CRLF);
            return;
         end if;
         Find_Mixer (Arguments, Found, M);
         if not Found then
            Put (Into, "###ERROR IN mixer: INVALID NAME: ");
            Put (Into, Arguments);
            Put (Into, "###" & CRLF);
            return;
         end if;
         Mode := Mixer_Mode'Pos (M) + 1;
      end if;
      Put (Into, "Mixer: ");
      if Mode in 1 .. Mixer_Mode'Pos (Mixer_Mode'Last) + 1 then
         Put (Into, Mixer_Name (Mixer_Mode'Val (Mode - 1)));
      end if;
      Put (Into, CRLF);
   end Mixer_Command;

   --  The custom motor mix up to its first motor without throttle.
   procedure Put_Motor_Mix (Into : in out Sink; Mix : Motor_Mixer_Record_List_8) is
   begin
      for I in Mix'Range loop
         exit when Mix (I).Throttle = 0.0;
         Put (Into, "mmix " & Decimal (Integer_64 (I)) & " ");
         Put (Into, CLI_Text.Float_Text (Mix (I).Throttle));
         Put (Into, " ");
         Put (Into, CLI_Text.Float_Text (Mix (I).Roll));
         Put (Into, " ");
         Put (Into, CLI_Text.Float_Text (Mix (I).Pitch));
         Put (Into, " ");
         Put (Into, CLI_Text.Float_Text (Mix (I).Yaw));
         Put (Into, CRLF);
      end loop;
   end Put_Motor_Mix;

   --  mmix: the custom motor mix, every motor's throttle cleared, a mode's
   --  table loaded by the first name the text starts, or one motor's
   --  throttle, roll, pitch and yaw, each argument read as a float and kept
   --  even when fewer than four are given.
   procedure Motor_Mix_Command (Into : in out Sink; Mix : in out Motor_Mixer_Record_List_8; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Found : Boolean;
      M     : Mixer_Init.Mixer_Mode;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Motor_Mix (Into, Mix);
      elsif Arguments'Length >= 5
        and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 4), "reset")
      then
         for I in Mix'Range loop
            Mix (I).Throttle := 0.0;
         end loop;
      elsif Arguments'Length >= 4
        and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 3), "load")
      then
         P := Next_Argument (Arguments, Arguments'First);
         if P > 0 and then P <= Arguments'Last then
            Find_Mixer (Arguments (P .. Arguments'Last), Found, M);
            if not Found then
               Put (Into, "###ERROR IN mmix: INVALID NAME: ");
               Put (Into, Arguments);
               Put (Into, "###" & CRLF);
               return;
            end if;
            declare
               O       : constant Mixer_Init.Options := (others => <>);
               Scratch : Mixer_Init.Mix_Table := (others => <>);
            begin
               Mixer_Init.Load_Mix (O, M, Scratch);
               for I in Mix'Range loop
                  Mix (I).Throttle := 0.0;
               end loop;
               if Mixer_Init.Has_Table (O, M) then
                  for I in 0 .. Mixer_Init.Motor_Count_Of (M) - 1 loop
                     Mix (I) :=
                       (Throttle => Scratch (I).Throttle, Roll => Scratch (I).Roll, Pitch => Scratch (I).Pitch,
                        Yaw => Scratch (I).Yaw);
                  end loop;
               end if;
            end;
            Put (Into, "Loaded ");
            Put (Into, Mixer_Name (M));
            Put (Into, CRLF);
            Put_Motor_Mix (Into, Mix);
         end if;
      else
         declare
            Index : constant Unsigned_32 := Unsigned_32'Mod (CLI_Text.To_Integer (Arguments));
            Count : Natural := 0;
         begin
            if Index >= Unsigned_32 (Mix'Length) then
               Put (Into, "###ERROR IN mmix: INDEX NOT BETWEEN 0 AND 7###" & CRLF);
               return;
            end if;
            P := Arguments'First;
            for Field in 1 .. 4 loop
               pragma Loop_Invariant
                 (Count < Field and then (P = 0 or else P in Arguments'First .. Arguments'Last + 1));
               P := Next_Argument (Arguments, P);
               if P > 0 then
                  declare
                     V : constant Float :=
                       (if P <= Arguments'Last then CLI_Text.Parse_Float (Arguments (P .. Arguments'Last)) else 0.0);
                     R : Motor_Mixer_Record renames Mix (Natural (Index));
                  begin
                     case Field is
                        when 1 => R.Throttle := V;
                        when 2 => R.Roll := V;
                        when 3 => R.Pitch := V;
                        when others => R.Yaw := V;
                     end case;
                  end;
                  Count := Count + 1;
               end if;
            end loop;
            if Count /= 4 then
               Put (Into, "###ERROR IN mmix: INVALID ARGUMENT COUNT###" & CRLF);
            else
               Put_Motor_Mix (Into, Mix);
            end if;
         end;
      end if;
   end Motor_Mix_Command;

   Channel_Letters : constant String := "AERT12345678abcdefgh";
   Mappable        : constant := 8;

   function Upper (Ch : Character) return Character is
     (if Ch in 'a' .. 'z' then Character'Val (Character'Pos (Ch) - 32) else Ch);

   --  The position of a character in the channel letters, zero when absent.
   function Letter_Position (Ch : Character) return Natural
     with Post => Letter_Position'Result <= Channel_Letters'Length
   is
   begin
      for K in Channel_Letters'Range loop
         if Channel_Letters (K) = Ch then
            return K;
         end if;
      end loop;
      return 0;
   end Letter_Position;

   --  map: a new channel order of the eight mappable channels, each letter
   --  once, then the order as a map line, each channel's letter at its
   --  position over the typed text, or over a cleared buffer for a query.
   procedure Map_Command (Into : in out Sink; C : in out Configuration; Arguments : String) is
      Buffer : String (1 .. Mappable) := (others => ASCII.NUL);
      Last   : Natural := 0;
   begin
      if Arguments'Length = Mappable then
         for I in 0 .. Mappable - 1 loop
            Buffer (I + 1) := Upper (Arguments (Arguments'First + I));
         end loop;
         for I in 1 .. Mappable loop
            if Letter_Position (Buffer (I)) = 0
              or else (for some J in I + 1 .. Mappable => Buffer (J) = Buffer (I))
            then
               Put (Into, "###ERROR IN map: PARSING FAILED###" & CRLF);
               return;
            end if;
         end loop;
         for I in 1 .. Mappable loop
            if Letter_Position (Buffer (I)) in 1 .. Mappable then
               C.Rx_Config.Rcmap (Letter_Position (Buffer (I)) - 1) := Unsigned_8 (I - 1);
            end if;
         end loop;
      elsif Arguments'Length > 0 then
         Put (Into, "###ERROR IN map: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      for I in 0 .. Mappable - 1 loop
         if C.Rx_Config.Rcmap (I) < Mappable then
            Buffer (Natural (C.Rx_Config.Rcmap (I)) + 1) := Channel_Letters (Channel_Letters'First + I);
         end if;
      end loop;
      for I in 1 .. Mappable loop
         exit when Buffer (I) = ASCII.NUL;
         Last := I;
         pragma Loop_Invariant (Last = I);
      end loop;
      Put (Into, "map " & Buffer (1 .. Last) & CRLF);
   end Map_Command;

   --  rxrange: the four sticks' channel ranges, all reset to 1000 to 2000, or
   --  one stick's range of two values within 750 to 2250.
   procedure Range_Command (Into : in out Sink; C : in out Configuration; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Index : Integer_32;
      Count : Natural := 0;
      Low   : Integer_32 := 750;
      High  : Integer_32 := 2250;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         for I in C.Rx_Channel_Range_Configs'Range loop
            Put (Into, "rxrange " & Decimal (Integer_64 (I)) & " "
                 & Decimal (Integer_64 (C.Rx_Channel_Range_Configs (I).Min)) & " "
                 & Decimal (Integer_64 (C.Rx_Channel_Range_Configs (I).Max)) & CRLF);
         end loop;
         return;
      end if;
      if CLI_Text.Same_Ignoring_Case (Arguments, "reset") then
         C.Rx_Channel_Range_Configs := (others => (Min => 1000, Max => 2000));
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. 3 then
         Put (Into, "###ERROR IN rxrange: CHANNEL NOT BETWEEN 0 AND 3###" & CRLF);
         return;
      end if;
      P := Next_Argument (Arguments, Arguments'First);
      if P > 0 then
         Low := Argument (Arguments, P);
         Count := Count + 1;
      end if;
      P := Next_Argument (Arguments, P);
      if P > 0 then
         High := Argument (Arguments, P);
         Count := Count + 1;
      end if;
      if Count /= 2 then
         Put (Into, "###ERROR IN rxrange: INVALID ARGUMENT COUNT###" & CRLF);
      elsif Low not in 750 .. 2250 or else High not in 750 .. 2250 then
         Put (Into, "###ERROR IN rxrange: range min/max NOT BETWEEN 750 AND 2250###" & CRLF);
      else
         C.Rx_Channel_Range_Configs (Natural (Index)) := (Min => Unsigned_16 (Low), Max => Unsigned_16 (High));
         Put (Into, "rxrange " & Decimal (Integer_64 (Index)) & " " & Decimal (Integer_64 (Low)) & " "
              & Decimal (Integer_64 (High)) & CRLF);
      end if;
   end Range_Command;

   Failsafe_Characters : constant String := "ahs";

   --  rxfail: every channel's failsafe line, or one channel's mode and, for
   --  the set mode, its value; the channel number is taken modulo 256.
   procedure Failsafe_Command (Into : in out Sink; C : in out Configuration; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Channel_Count : constant := Rx_Failsafe_Channel_Config_Record_List_18'Length;

      procedure Put_Line_Of (Channel : Natural; Require_Value : Boolean)
        with Pre => Channel < Channel_Count
      is
         F : constant Rx_Failsafe_Channel_Config_Record := C.Rx_Failsafe_Channel_Configs (Channel);
      begin
         Put (Into, "rxfail " & Decimal (Integer_64 (Channel)) & " "
              & (if F.Mode <= 2 then (1 => Failsafe_Characters (Natural (F.Mode) + 1)) else ""));
         if Require_Value then
            Put (Into, " " & Decimal (750 + 25 * Integer_64 (F.Step)));
         end if;
         Put (Into, CRLF);
      end Put_Line_Of;

      Channel : Unsigned_8;
      P       : Natural;
   begin
      if Arguments'Length = 0 then
         for I in 0 .. Channel_Count - 1 loop
            Put_Line_Of (I, C.Rx_Failsafe_Channel_Configs (I).Mode = 2);
         end loop;
         return;
      end if;
      Channel := Unsigned_8'Mod (CLI_Text.To_Integer (Arguments));
      if Channel >= Channel_Count then
         Put (Into, "###ERROR IN rxfail: CHANNEL NOT BETWEEN 0 AND 17###" & CRLF);
         return;
      end if;
      declare
         Index         : constant Natural := Natural (Channel);
         Mode          : Unsigned_8 := C.Rx_Failsafe_Channel_Configs (Index).Mode;
         Require_Value : Boolean := Mode = 2;
         Requested     : Natural;
         Value         : Unsigned_16;
      begin
         P := Next_Argument (Arguments, Arguments'First + 1);
         if P > 0 then
            Requested := 0;
            if P <= Arguments'Last then
               for K in Failsafe_Characters'Range loop
                  if Failsafe_Characters (K) = Arguments (P) then
                     Requested := K;
                     exit;
                  end if;
               end loop;
            end if;
            if Requested = 0 or else (Index >= 4 and then Requested = 1) then
               Put (Into, "###ERROR IN rxfail: PARSING FAILED###" & CRLF);
               return;
            end if;
            Mode := Unsigned_8 (Requested - 1);
            Require_Value := Mode = 2;
            P := Next_Argument (Arguments, P);
            if P > 0 then
               if not Require_Value then
                  Put (Into, "###ERROR IN rxfail: PARSING FAILED###" & CRLF);
                  return;
               end if;
               Value := Unsigned_16'Mod (Argument (Arguments, P));
               Value := (Unsigned_16'Max (750, Unsigned_16'Min (2250, Value)) - 750) / 25;
               C.Rx_Failsafe_Channel_Configs (Index).Step := Unsigned_8 (Value);
            elsif Require_Value then
               Put (Into, "###ERROR IN rxfail: INVALID ARGUMENT COUNT###" & CRLF);
               return;
            end if;
            C.Rx_Failsafe_Channel_Configs (Index).Mode := Mode;
         end if;
         Put_Line_Of (Index, Require_Value);
      end;
   end Failsafe_Command;

   subtype Line_Buffer is String (1 .. Line_Size);

   --  The text from a position up to the next terminator in the buffer.
   function Text_At (Buffer : Line_Buffer; From : Positive) return String
     with Post => Text_At'Result'First >= 1 and then Text_At'Result'Last <= Line_Size
                  and then Text_At'Result'First <= Text_At'Result'Last + 1
   is
      Last : Natural;
   begin
      if From > Line_Size then
         return "";
      end if;
      Last := From - 1;
      while Last < Line_Size and then Buffer (Last + 1) /= ASCII.NUL loop
         pragma Loop_Invariant (Last in From - 1 .. Line_Size - 1);
         pragma Loop_Variant (Increases => Last);
         Last := Last + 1;
      end loop;
      return Buffer (From .. Last);
   end Text_At;

   --  The position of the arguments after a command word at a position, past
   --  the one character after the word and any spaces; zero when the text
   --  there does not start with the word followed by a space or a terminator.
   function Command_At (Buffer : Line_Buffer; From : Positive; Word : String) return Natural
     with Pre  => Word'Length in 1 .. 15,
          Post => Command_At'Result <= Line_Size + 1
   is
      Next : Positive;
   begin
      if From > Line_Size or else Word'Length > Line_Size - From then
         return 0;
      end if;
      if not CLI_Text.Same_Ignoring_Case (Buffer (From .. From + Word'Length - 1), Word)
        or else Buffer (From + Word'Length) not in ' ' | ASCII.NUL
      then
         return 0;
      end if;
      Next := From + Word'Length + 1;
      for K in Next .. Line_Size loop
         pragma Loop_Invariant (Next = K);
         exit when Buffer (K) /= ' ';
         Next := K + 1;
      end loop;
      return Next;
   end Command_At;

   type Command_Kind is
     (No_Command, Adjustment_Range_Command_Word, Aux_Command_Word, Battery_Profile_Command, Beacon_Command,
      Beeper_Command_Word, Diff_Command, Dump_Command, Feature_Command_Word, Get_Command, Map_Command_Word,
      Mixer_Command_Word, Motor_Mix_Command_Word, Profile_Command, Rate_Profile_Command, Rx_Failsafe_Command,
      Rx_Range_Command, Serial_Command_Word, Set_Command);
   subtype Known_Command is Command_Kind range Adjustment_Range_Command_Word .. Set_Command;

   function Command_Word (K : Known_Command) return String is
     (case K is
         when Adjustment_Range_Command_Word => "adjrange",
         when Aux_Command_Word => "aux",
         when Battery_Profile_Command => "battery_profile",
         when Beacon_Command => "beacon",
         when Beeper_Command_Word => "beeper",
         when Diff_Command => "diff",
         when Dump_Command => "dump",
         when Feature_Command_Word => "feature",
         when Get_Command => "get",
         when Map_Command_Word => "map",
         when Mixer_Command_Word => "mixer",
         when Motor_Mix_Command_Word => "mmix",
         when Profile_Command => "profile",
         when Rate_Profile_Command => "rateprofile",
         when Rx_Failsafe_Command => "rxfail",
         when Rx_Range_Command => "rxrange",
         when Serial_Command_Word => "serial",
         when Set_Command => "set")
     with Post => Command_Word'Result'Length in 1 .. 15;

   --  The line's command and the position of its arguments.
   procedure Find_Command (Buffer : Line_Buffer; Kind : out Command_Kind; Arguments : out Natural)
     with Post => Arguments <= Line_Size + 1 and then (Kind = No_Command or else Arguments >= 1)
   is
   begin
      for K in Known_Command loop
         Arguments := Command_At (Buffer, 1, Command_Word (K));
         if Arguments > 0 then
            Kind := K;
            return;
         end if;
      end loop;
      Kind := No_Command;
      Arguments := 0;
   end Find_Command;

   --  dump or diff: a profile's or a rate profile's settings, with their
   --  defaults after the option defaults; Known is false for other sections.
   procedure Print_Config
     (Into : in out Sink; C : Configuration; Buffer : Line_Buffer; Arguments : Positive; Command : String;
      Diff : Boolean; Ports : Port_List; Known : out Boolean)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Options : Natural := Command_At (Buffer, Arguments, "profile");
      Kind    : Profile_Kind := PID;
   begin
      Known := False;
      if Options = 0 then
         Options := Command_At (Buffer, Arguments, "rates");
         Kind := Rate;
         if Options = 0 then
            return;
         end if;
      end if;
      Known := True;
      Dump_Profile
        (Into, C, Kind,
         Natural (if Kind = PID then C.System_Config.Pid_Profile_Index else C.System_Config.Active_Rate_Profile),
         Command, Diff, Command_At (Buffer, Options, "defaults") > 0, Ports);
   end Print_Config;

   ------------------
   -- Process_Line --
   ------------------

   procedure Process_Line
     (Into : in out Sink; C : in out Configuration; Line : String; Ports : Port_List; Known : out Boolean;
      Changes : out Effects)
   is
      Buffer    : Line_Buffer := (others => ASCII.NUL);
      Length    : Natural := 0;
      Kind      : Command_Kind;
      Arguments : Natural;
   begin
      Known := False;
      Changes := (others => False);
      for Ch of Line loop
         if Length < Line_Size - 1 and then Ch in ' ' .. '~' and then (Length > 0 or else Ch /= ' ') then
            Length := Length + 1;
            Buffer (Length) := Ch;
         end if;
         pragma Loop_Invariant (Length < Line_Size);
      end loop;
      if Length = 0 then
         return;
      end if;
      for K in 1 .. Length loop
         pragma Loop_Invariant (Length < Line_Size);
         if Buffer (K) = '#' then
            Length := K - 1;
            exit;
         end if;
      end loop;
      while Length > 0 and then Buffer (Length) = ' ' loop
         pragma Loop_Invariant (Length < Line_Size);
         pragma Loop_Variant (Decreases => Length);
         Length := Length - 1;
      end loop;
      if Length = 0 then
         return;
      end if;
      Buffer (Length + 1) := ASCII.NUL;
      Find_Command (Buffer, Kind, Arguments);
      case Kind is
         when No_Command =>
            null;
         when Adjustment_Range_Command_Word =>
            Known := True;
            Adjustment_Range_Command (Into, C, Text_At (Buffer, Arguments), Changes);
         when Aux_Command_Word =>
            Known := True;
            Aux_Command (Into, C, Text_At (Buffer, Arguments), Changes);
         when Battery_Profile_Command =>
            Known := True;
            Profile_Command (Into, C, Battery, Text_At (Buffer, Arguments), Changes);
         when Beacon_Command =>
            Known := True;
            Beeper_Command
              (Into, "beacon", C.Beeper_Config.Dshot_Beacon_Off_Flags, 16#202#, Text_At (Buffer, Arguments));
         when Beeper_Command_Word =>
            Known := True;
            Beeper_Command (Into, "beeper", C.Beeper_Config.Beeper_Off_Flags, 16#7F_FFFF#, Text_At (Buffer, Arguments));
         when Diff_Command =>
            Print_Config (Into, C, Buffer, Arguments, "diff", True, Ports, Known);
         when Dump_Command =>
            Print_Config (Into, C, Buffer, Arguments, "dump", False, Ports, Known);
         when Feature_Command_Word =>
            Known := True;
            Feature_Command (Into, C, Text_At (Buffer, Arguments));
         when Get_Command =>
            Known := True;
            Get (Into, C, "get", Text_At (Buffer, Arguments), Ports);
         when Map_Command_Word =>
            Known := True;
            Map_Command (Into, C, Text_At (Buffer, Arguments));
         when Mixer_Command_Word =>
            Known := True;
            Mixer_Command (Into, C.Mixer_Config.Mixer_Mode, Text_At (Buffer, Arguments));
         when Motor_Mix_Command_Word =>
            Known := True;
            Motor_Mix_Command (Into, C.Custom_Motor_Mixer, Text_At (Buffer, Arguments));
         when Profile_Command =>
            Known := True;
            Profile_Command (Into, C, PID, Text_At (Buffer, Arguments), Changes);
         when Rate_Profile_Command =>
            Known := True;
            Profile_Command (Into, C, Rate, Text_At (Buffer, Arguments), Changes);
         when Rx_Failsafe_Command =>
            Known := True;
            Failsafe_Command (Into, C, Text_At (Buffer, Arguments));
         when Rx_Range_Command =>
            Known := True;
            Range_Command (Into, C, Text_At (Buffer, Arguments));
         when Serial_Command_Word =>
            Known := True;
            Serial_Command (Into, C, Text_At (Buffer, Arguments), Ports);
         when Set_Command =>
            Known := True;
            Set (Into, C, Text_At (Buffer, Arguments), Ports);
      end case;
   end Process_Line;

end Adaflight.Command_Line;
