with Interfaces; use Interfaces;
with Adaflight.Adjustments;
with Adaflight.Config_Fix;
with Adaflight.LED_Strip;
with Adaflight.Maths;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.MSP_Box;
with Adaflight.MSP_Common_Out;
with Adaflight.Servo_Rules;
with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package body Adaflight.Command_Line with SPARK_Mode is

   CRLF : constant String := (ASCII.CR, ASCII.LF);

   function Decimal (V : Integer_64) return String renames CLI_Text.Decimal;

   function To_Identity (Text : String) return Identity_Text is
      T : Identity_Text;
   begin
      for K in 1 .. Text'Length loop
         T.Data (K) := Text (Text'First + (K - 1));
      end loop;
      T.Length := Text'Length;
      return T;
   end To_Identity;

   function Text_Of (T : Identity_Text) return String is (T.Data (1 .. T.Length));

   --  A heading after an empty line, after a number sign.
   procedure Put_Hash_Line (Into : in out Sink; Heading : String) is
   begin
      Put (Into, CRLF & "# ");
      Put (Into, Heading);
      Put (Into, CRLF);
   end Put_Hash_Line;

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

   --  A scope's settings in the given profiles as set lines under a heading,
   --  the hardware settings with the master settings; for a diff only those
   --  off their default, under a heading printed with the first of them, each
   --  after its default for Show_Defaults.
   procedure Dump_Values
     (Into : in out Sink; C : Configuration; Where : Value_Scope; P : Profiles; Heading : String; Command : String;
      Diff : Boolean; Show_Defaults : Boolean; Ports : Port_List)
     with Pre => Valid (P) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Pending : Boolean := True;
   begin
      if not Diff then
         Put_Hash_Line (Into, Heading);
         Pending := False;
      end if;
      for S in Setting loop
         if Describe (S).Where = Where or else (Where = Master and then Describe (S).Where = Hardware) then
            declare
               Profile : constant Natural := Profile_Of (S, P);
               Equal   : constant Boolean := Equals_Default (C, S, Profile);
            begin
               if Diff and then Pending and then not Equal then
                  Put_Hash_Line (Into, Heading);
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
   end Dump_Values;

   --  A profile's line, then its settings under its heading.
   procedure Dump_Profile
     (Into : in out Sink; C : Configuration; Kind : Profile_Kind; Index : Natural; Command : String; Diff : Boolean;
      Show_Defaults : Boolean; Ports : Port_List)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
   begin
      if Index >= (if Kind = Battery then 3 else 4) then
         return;
      end if;
      Put (Into, CRLF & Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)) & CRLF);
      Dump_Values
        (Into, C,
         (case Kind is
             when PID => PID_Profile,
             when Rate => Rate_Profile,
             when Battery => Battery_Profile),
         (PID     => (if Kind = PID then Index else 0),
          Rate    => (if Kind = Rate then Index else 0),
          Battery => (if Kind = Battery then Index else 0)),
         Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)), Command, Diff, Show_Defaults, Ports);
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

   --  The features as commands: every feature disabled, then each enabled
   --  one enabled.
   procedure Put_Feature_Dump (Into : in out Sink; Mask : Unsigned_32) is
   begin
      for Bit in Feature_Bit loop
         if Feature_Name (Bit)'Length > 0 then
            Put (Into, "feature -" & Feature_Name (Bit) & CRLF);
         end if;
      end loop;
      for Bit in Feature_Bit loop
         if Feature_Name (Bit)'Length > 0 and then (Mask and Shift_Left (1, Bit)) /= 0 then
            Put (Into, "feature " & Feature_Name (Bit) & CRLF);
         end if;
      end loop;
   end Put_Feature_Dump;

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

   Beeper_Allowed : constant Unsigned_32 := 16#7F_FFFF#;
   Beacon_Allowed : constant Unsigned_32 := 16#202#;

   --  The beeper or beacon conditions as commands: each allowed one but ALL
   --  enabled or, after a minus, disabled.
   procedure Put_Beeper_Dump (Into : in out Sink; Command : String; Flags : Unsigned_32; Allowed : Unsigned_32) is
   begin
      for I in 0 .. All_Beepers - 1 loop
         pragma Loop_Invariant (I in 0 .. All_Beepers - 1);
         if (Beeper_Mask (I) and Allowed) /= 0 then
            Put (Into, Command);
            Put (Into, (if (Flags and Beeper_Mask (I)) /= 0 then " -" else " ") & Beeper_Name (I) & CRLF);
         end if;
      end loop;
   end Put_Beeper_Dump;

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

   --  Every mode condition whose mode is in the box table.
   procedure Put_Conditions (Into : in out Sink; Conditions : Mode_Activation_Condition_Record_List_20) is
   begin
      for I in Conditions'Range loop
         pragma Loop_Invariant (I in Conditions'Range);
         if Conditions (I).Mode_Id <= Modes.Box'Pos (Modes.Box'Last) then
            Put_Condition (Into, I, Conditions (I));
         end if;
      end loop;
   end Put_Conditions;

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
         Put_Conditions (Into, C.Mode_Activation_Conditions);
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

   --  One adjustment range's line.
   procedure Put_Adjustment_Range (Into : in out Sink; Index : Natural; A : Adjustment_Range_Record)
     with Pre => Index <= 29
   is
   begin
      Put (Into, "adjrange " & Decimal (Integer_64 (Index)) & " 0 "
           & Decimal (Integer_64 (A.Aux_Channel_Index)) & " "
           & Decimal (900 + 25 * Integer_64 (A.Range_Value.Start_Step)) & " "
           & Decimal (900 + 25 * Integer_64 (A.Range_Value.End_Step)) & " "
           & Decimal (Integer_64 (A.Adjustment_Config)) & " " & Decimal (Integer_64 (A.Aux_Switch_Channel_Index))
           & " " & Decimal (Integer_64 (A.Adjustment_Center)) & " " & Decimal (Integer_64 (A.Adjustment_Scale))
           & CRLF);
   end Put_Adjustment_Range;

   --  Every adjustment range's line.
   procedure Put_Adjustment_Ranges (Into : in out Sink; Ranges : Adjustment_Range_Record_List_30) is
   begin
      for I in Ranges'Range loop
         pragma Loop_Invariant (I in Ranges'Range);
         Put_Adjustment_Range (Into, I, Ranges (I));
      end loop;
   end Put_Adjustment_Ranges;

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

      Index : Integer_32;
      Valid : Natural := 0;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Adjustment_Ranges (Into, C.Adjustment_Ranges);
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
         Put_Adjustment_Range (Into, Slot, A);
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

   Input_Source_Count : constant := 14;

   --  Each servo's line, then a reverse line for each input source it
   --  reverses.
   procedure Put_Servos (Into : in out Sink; Params : Servo_Param_Record_List_8) is
   begin
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         Put (Into, "servo " & Decimal (Integer_64 (I)) & " " & Decimal (Integer_64 (Params (I).Min)) & " "
              & Decimal (Integer_64 (Params (I).Max)) & " "
              & Decimal (Integer_64 (Params (I).Middle)) & " "
              & Decimal (Integer_64 (Params (I).Rate)) & " "
              & Decimal (Integer_64 (Params (I).Forward_From_Channel)) & CRLF);
      end loop;
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         for Input in 0 .. Input_Source_Count - 1 loop
            pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
            if (Params (I).Reversed_Sources and Shift_Left (1, Input)) /= 0 then
               Put (Into, "smix reverse " & Decimal (Integer_64 (I)) & " " & Decimal (Integer_64 (Input)) & " r"
                    & CRLF);
            end if;
         end loop;
      end loop;
   end Put_Servos;

   --  servo: every servo's parameters, or one servo's minimum, maximum,
   --  middle, rate and forwarded channel from six numbers, each wrapped to
   --  16 bits; anything but numbers and spaces is the parse error.
   procedure Servo_Command (Into : in out Sink; Params : in out Servo_Param_Record_List_8; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Values : array (0 .. 5) of Integer_16 := (others => 0);
      Count  : Natural := 0;
      P      : Positive := Arguments'First;
   begin
      if Arguments'Length = 0 then
         Put_Servos (Into, Params);
         return;
      end if;
      while P <= Arguments'Last loop
         pragma Loop_Invariant (Count <= 6 and then P in Arguments'Range);
         pragma Loop_Variant (Increases => P);
         if Arguments (P) = '-' or else Arguments (P) in '0' .. '9' then
            if Count >= 6 then
               Put (Into, "###ERROR IN servo: INVALID ARGUMENT COUNT###" & CRLF);
               return;
            end if;
            Values (Count) :=
              Integer_16 ((Integer_64 (CLI_Text.To_Integer (Arguments (P .. Arguments'Last))) + 32_768) mod 65_536
                          - 32_768);
            Count := Count + 1;
            loop
               pragma Loop_Invariant (P in Arguments'Range and then P >= P'Loop_Entry);
               pragma Loop_Variant (Increases => P);
               exit when P = Arguments'Last or else Arguments (P + 1) not in '0' .. '9';
               P := P + 1;
            end loop;
            exit when P = Arguments'Last;
            P := P + 1;
         elsif Arguments (P) = ' ' then
            exit when P = Arguments'Last;
            P := P + 1;
         else
            Put (Into, "###ERROR IN servo: PARSING FAILED###" & CRLF);
            return;
         end if;
      end loop;
      if Count /= 6 or else Values (0) not in 0 .. 7 then
         Put (Into, "###ERROR IN servo: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      if Values (1) not in 500 .. 2500 or else Values (2) not in 500 .. 2500 or else Values (3) < Values (1)
        or else Values (3) > Values (2) or else Values (1) > Values (2) or else Values (4) not in -100 .. 100
        or else Values (5) >= 18
      then
         Put (Into, "###ERROR IN servo: ARGUMENT OUT OF RANGE###" & CRLF);
         return;
      end if;
      declare
         Index : constant Natural := Natural (Values (0));
         S     : Servo_Param_Record renames Params (Index);
      begin
         S.Min := Values (1);
         S.Max := Values (2);
         S.Middle := Values (3);
         S.Rate := Integer_8 (Values (4));
         S.Forward_From_Channel := Integer_8 ((Integer_32 (Values (5)) + 128) mod 256 - 128);
         Put (Into, "servo " & Decimal (Integer_64 (Index)) & " " & Decimal (Integer_64 (S.Min)) & " "
              & Decimal (Integer_64 (S.Max)) & " " & Decimal (Integer_64 (S.Middle)) & " "
              & Decimal (Integer_64 (S.Rate)) & " " & Decimal (Integer_64 (S.Forward_From_Channel)) & CRLF);
      end;
   end Servo_Command;

   --  The servo rules up to the first without a rate.
   procedure Put_Servo_Rules (Into : in out Sink; Rules : Servo_Mixer_Record_List_16) is
   begin
      for I in Rules'Range loop
         pragma Loop_Invariant (I in Rules'Range);
         exit when Rules (I).Rate = 0;
         declare
            R : constant Servo_Mixer_Record := Rules (I);
         begin
            Put (Into, "smix " & Decimal (Integer_64 (I)) & " " & Decimal (Integer_64 (R.Target_Channel)) & " "
                 & Decimal (Integer_64 (R.Input_Source)) & " " & Decimal (Integer_64 (R.Rate)) & " "
                 & Decimal (Integer_64 (R.Speed)) & " " & Decimal (Integer_64 (R.Min)) & " "
                 & Decimal (Integer_64 (R.Max)) & " " & Decimal (Integer_64 (R.Box)) & CRLF);
         end;
      end loop;
   end Put_Servo_Rules;

   --  Each servo's reversed input sources as a table.
   procedure Put_Reversed (Into : in out Sink; Params : Servo_Param_Record_List_8) is
   begin
      Put (Into, "s");
      for Input in 0 .. Input_Source_Count - 1 loop
         pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
         Put (Into, ASCII.HT & "i" & Decimal (Integer_64 (Input)));
      end loop;
      Put (Into, CRLF);
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         Put (Into, Decimal (Integer_64 (I)));
         for Input in 0 .. Input_Source_Count - 1 loop
            pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
            Put (Into, ASCII.HT
                 & (if (Params (I).Reversed_Sources and Shift_Left (1, Input)) /= 0 then 'r' else 'n')
                 & "  ");
         end loop;
         Put (Into, CRLF);
      end loop;
   end Put_Reversed;

   --  The text of the next word from a position, past the spaces before it:
   --  its first and last positions, and zero for First where no word is left.
   procedure Next_Word (Text : String; From : Positive; First : out Natural; Last : out Natural)
     with Pre  => Text'First >= 1 and then Text'Last < Positive'Last and then From >= Text'First,
          Post => (if First > 0 then First in Text'Range and then First >= From and then Last in First .. Text'Last)
   is
      P : Positive := From;
   begin
      First := 0;
      Last := 0;
      while P <= Text'Last and then Text (P) = ' ' loop
         pragma Loop_Invariant (P in Text'Range and then P >= From);
         pragma Loop_Variant (Increases => P);
         P := P + 1;
      end loop;
      if P > Text'Last then
         return;
      end if;
      First := P;
      Last := P;
      while Last < Text'Last and then Text (Last + 1) /= ' ' loop
         pragma Loop_Invariant (Last in First .. Text'Last - 1);
         pragma Loop_Variant (Increases => Last);
         Last := Last + 1;
      end loop;
   end Next_Word;

   --  smix: the servo rules, every rule and reversed source cleared, a
   --  mode's rules loaded by the first name the text starts, the reversed
   --  sources, one source of one servo reversed or not, or one rule's servo,
   --  input, rate, speed, range and box from eight numbers.
   procedure Servo_Mix_Command
     (Into : in out Sink; Rules : in out Servo_Mixer_Record_List_16; Params : in out Servo_Param_Record_List_8;
      Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Found : Boolean;
      M     : Mixer_Init.Mixer_Mode;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Servo_Rules (Into, Rules);
      elsif Arguments'Length >= 5
        and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 4), "reset")
      then
         Rules :=
           (others => (Target_Channel => 0, Input_Source => 0, Rate => 0, Speed => 0, Min => 0, Max => 0, Box => 0));
         for I in Params'Range loop
            Params (I).Reversed_Sources := 0;
         end loop;
      elsif Arguments'Length >= 4
        and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 3), "load")
      then
         P := Next_Argument (Arguments, Arguments'First);
         if P > 0 and then P <= Arguments'Last then
            Find_Mixer (Arguments (P .. Arguments'Last), Found, M);
            if not Found then
               Put (Into, "###ERROR IN smix: INVALID NAME: ");
               Put (Into, Arguments);
               Put (Into, "###" & CRLF);
               return;
            end if;
            declare
               Loaded : Servo_Rules.Rule_List;
               Count  : Servo_Rules.Rule_Count;
            begin
               Servo_Rules.Mode_Rules ((others => <>), M, Loaded, Count);
               for I in Rules'Range loop
                  Rules (I).Target_Channel := 0;
                  Rules (I).Input_Source := 0;
                  Rules (I).Rate := 0;
                  Rules (I).Box := 0;
               end loop;
               for I in 1 .. Count loop
                  Rules (I - 1) :=
                    (Target_Channel => Loaded (I).Target, Input_Source => Loaded (I).Input, Rate => Loaded (I).Rate,
                     Speed => Loaded (I).Speed, Min => Loaded (I).Min, Max => Loaded (I).Max, Box => Loaded (I).Box);
               end loop;
            end;
            Put (Into, "Loaded ");
            Put (Into, Mixer_Name (M));
            Put (Into, CRLF);
            Put_Servo_Rules (Into, Rules);
         end if;
      elsif Arguments'Length >= 7
        and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 6), "reverse")
      then
         P := 0;
         for K in Arguments'Range loop
            if Arguments (K) = ' ' then
               P := K;
               exit;
            end if;
         end loop;
         if P > 0 then
            declare
               Servo, Input : Integer_32 := 0;
               First, Last  : Natural;
               Unused_Last  : Natural;
            begin
               Next_Word (Arguments, P, First, Last);
               if First > 0 then
                  Servo := CLI_Text.To_Integer (Arguments (First .. Last));
                  Next_Word (Arguments, Last + 1, First, Last);
                  if First > 0 then
                     Input := CLI_Text.To_Integer (Arguments (First .. Last));
                     Next_Word (Arguments, Last + 1, First, Unused_Last);
                  end if;
               end if;
               if First = 0 then
                  Put (Into, "###ERROR IN smix: INVALID ARGUMENT COUNT###" & CRLF);
                  return;
               end if;
               if Servo not in 0 .. 7 or else Input not in 0 .. Input_Source_Count - 1
                 or else Arguments (First) not in 'r' | 'n'
               then
                  Put (Into, "###ERROR IN smix: servo NOT BETWEEN 0 AND 8###" & CRLF);
                  return;
               end if;
               if Arguments (First) = 'r' then
                  Params (Natural (Servo)).Reversed_Sources :=
                    Params (Natural (Servo)).Reversed_Sources or Shift_Left (1, Natural (Input));
               else
                  Params (Natural (Servo)).Reversed_Sources :=
                    Params (Natural (Servo)).Reversed_Sources and not Shift_Left (1, Natural (Input));
               end if;
            end;
         end if;
         Put_Reversed (Into, Params);
      else
         declare
            Values      : array (0 .. 7) of Integer_32 := (others => 0);
            Count       : Natural := 0;
            First, Last : Natural;
            From        : Positive := Arguments'First;
         begin
            loop
               pragma Loop_Invariant (Count <= 8 and then From in Arguments'First .. Arguments'Last + 1);
               pragma Loop_Variant (Increases => From);
               Next_Word (Arguments, From, First, Last);
               exit when First = 0 or else Count = 8;
               Values (Count) := CLI_Text.To_Integer (Arguments (First .. Last));
               Count := Count + 1;
               From := Last + 1;
            end loop;
            if First > 0 or else Count /= 8 then
               Put (Into, "###ERROR IN smix: INVALID ARGUMENT COUNT###" & CRLF);
               return;
            end if;
            if Values (0) in 0 .. 15 and then Values (1) in 0 .. 7 and then Values (2) in 0 .. Input_Source_Count - 1
              and then Values (3) in -100 .. 100 and then Values (4) in 0 .. 255 and then Values (5) in 0 .. 100
              and then Values (6) in 0 .. 100 and then Values (5) < Values (6) and then Values (7) in 0 .. 3
            then
               Rules (Natural (Values (0))) :=
                 (Target_Channel => Unsigned_8 (Values (1)), Input_Source => Unsigned_8 (Values (2)),
                  Rate => Integer_8 (Values (3)), Speed => Unsigned_8 (Values (4)), Min => Integer_8 (Values (5)),
                  Max => Integer_8 (Values (6)), Box => Unsigned_8 (Values (7)));
               Put_Servo_Rules (Into, Rules);
            else
               Put (Into, "###ERROR IN smix: ARGUMENT OUT OF RANGE###" & CRLF);
            end if;
         end;
      end if;
   end Servo_Mix_Command;

   --  A LED's configuration as text: position, direction letters, function
   --  letter with overlay letters, and color. A function past the function
   --  letters has no letter.
   procedure Put_Led_Text (Into : in out Sink; Config : Unsigned_32) is
      Direction_Codes : constant String := "NESWUD";
      Function_Codes  : constant String := "CFALSGRPEU";
      Overlay_Codes   : constant String := "TYOBVIW";
      Directions      : constant Unsigned_32 := Shift_Right (Config, 26) and 16#3F#;
      Fn              : constant Unsigned_32 := Shift_Right (Config, 8) and 16#F#;
      Overlays        : constant Unsigned_32 := Shift_Right (Config, 12) and 16#FF#;
      Dir_Text        : String (1 .. 6) := (others => ' ');
      Dir_Last        : Natural := 0;
      Fn_Text         : String (1 .. 8) := (others => ' ');
      Fn_Last         : Natural := 0;
   begin
      for D in 0 .. 5 loop
         pragma Loop_Invariant (Dir_Last <= D);
         if (Directions and Shift_Left (1, D)) /= 0 then
            Dir_Last := Dir_Last + 1;
            Dir_Text (Dir_Last) := Direction_Codes (D + 1);
         end if;
      end loop;
      if Fn <= 9 then
         Fn_Last := 1;
         Fn_Text (1) := Function_Codes (Natural (Fn) + 1);
      end if;
      for O in 0 .. 6 loop
         pragma Loop_Invariant (Fn_Last <= O + 1);
         if (Overlays and Shift_Left (1, O)) /= 0 then
            Fn_Last := Fn_Last + 1;
            Fn_Text (Fn_Last) := Overlay_Codes (O + 1);
         end if;
      end loop;
      Put (Into, Decimal (Integer_64 (Shift_Right (Config, 4) and 16#F#)));
      Put (Into, ",");
      Put (Into, Decimal (Integer_64 (Config and 16#F#)));
      Put (Into, ":" & Dir_Text (1 .. Dir_Last) & ":" & Fn_Text (1 .. Fn_Last) & ":");
      Put (Into, Decimal (Integer_64 (Shift_Right (Config, 22) and 16#F#)));
   end Put_Led_Text;

   --  Every LED's configuration line.
   procedure Put_Leds (Into : in out Sink; Configs : Unsigned_32_List_32) is
   begin
      for I in Configs'Range loop
         pragma Loop_Invariant (I in Configs'Range);
         Put (Into, "led " & Decimal (Integer_64 (I)) & " ");
         Put_Led_Text (Into, Configs (I));
         Put (Into, CRLF);
      end loop;
   end Put_Leds;

   --  led: every LED's configuration, or one LED's configuration cleared and
   --  then read from its text; a reading LED asks for the strip's layout.
   procedure Led_Command
     (Into : in out Sink; Configs : in out Unsigned_32_List_32; Arguments : String; Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Index : Integer_32;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Leds (Into, Configs);
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. 31 then
         Put (Into, "###ERROR IN led: INDEX NOT BETWEEN 0 AND 31###" & CRLF);
         return;
      end if;
      P := Next_Argument (Arguments, Arguments'First);
      if P = 0 then
         Put (Into, "###ERROR IN led: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      Configs (Natural (Index)) := 0;
      if Arguments'Last - P + 1 > LED_Strip.Max_Text then
         Put (Into, "###ERROR IN led: PARSING FAILED###" & CRLF);
         return;
      end if;
      declare
         Start  : constant Positive := P;
         Text   : constant String (1 .. Arguments'Last - Start + 1) := Arguments (Start .. Arguments'Last);
         Config : Unsigned_32;
         OK     : Boolean;
      begin
         LED_Strip.Parse_Led (Text, Config, OK);
         if not OK then
            Put (Into, "###ERROR IN led: PARSING FAILED###" & CRLF);
            return;
         end if;
         Configs (Natural (Index)) := Config;
         Changes.LEDs := True;
         Put (Into, "led " & Decimal (Integer_64 (Index)) & " ");
         Put_Led_Text (Into, Config);
         Put (Into, CRLF);
      end;
   end Led_Command;

   --  Every color's line.
   procedure Put_Colors (Into : in out Sink; Colors : Hsv_Color_Record_List_16) is
   begin
      for I in Colors'Range loop
         pragma Loop_Invariant (I in Colors'Range);
         Put (Into, "color " & Decimal (Integer_64 (I)) & " "
              & Decimal (Integer_64 (Colors (I).H)) & ","
              & Decimal (Integer_64 (Colors (I).S)) & ","
              & Decimal (Integer_64 (Colors (I).V)) & CRLF);
      end loop;
   end Put_Colors;

   --  color: every color, or one color's hue, saturation and value read in
   --  turn, each stored as it is read and the color cleared when one is past
   --  its limit or a comma is missing.
   procedure Color_Command (Into : in out Sink; Colors : in out Hsv_Color_Record_List_16; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Index : Integer_32;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Colors (Into, Colors);
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. 15 then
         Put (Into, "###ERROR IN color: INDEX NOT BETWEEN 0 AND 15###" & CRLF);
         return;
      end if;
      P := Next_Argument (Arguments, Arguments'First);
      if P = 0 then
         Put (Into, "###ERROR IN color: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      declare
         Slot   : constant Natural := Natural (Index);
         Limits : constant array (0 .. 2) of Integer_32 := (359, 255, 255);
         OK     : Boolean := True;
         V      : Integer_32;
      begin
         for Component in 0 .. 2 loop
            pragma Loop_Invariant (P in Arguments'First .. Arguments'Last + 1);
            V := (if P <= Arguments'Last then CLI_Text.To_Integer (Arguments (P .. Arguments'Last)) else 0);
            if V > Limits (Component) then
               OK := False;
               exit;
            end if;
            case Component is
               when 0 =>
                  Colors (Slot).H := Unsigned_16'Mod (V);
               when 1 =>
                  Colors (Slot).S := Unsigned_8'Mod (V);
               when others =>
                  Colors (Slot).V := Unsigned_8'Mod (V);
            end case;
            declare
               Comma : Natural := 0;
            begin
               for K in P .. Arguments'Last loop
                  if Arguments (K) = ',' then
                     Comma := K;
                     exit;
                  end if;
               end loop;
               if Comma > 0 then
                  P := Comma + 1;
               else
                  if Component < 2 then
                     OK := False;
                  end if;
                  exit;
               end if;
            end;
         end loop;
         if not OK then
            Colors (Slot) := (H => 0, S => 0, V => 0);
            Put (Into, "###ERROR IN color: PARSING FAILED###" & CRLF);
            return;
         end if;
         Put (Into, "color " & Decimal (Integer_64 (Slot)) & " "
              & Decimal (Integer_64 (Colors (Slot).H)) & ","
              & Decimal (Integer_64 (Colors (Slot).S)) & ","
              & Decimal (Integer_64 (Colors (Slot).V)) & CRLF);
      end;
   end Color_Command;

   --  Every mode's direction colors, the special colors and the aux channel.
   procedure Put_Mode_Colors (Into : in out Sink; L : Led_Strip_Status_Mode_Config_Record) is
   begin
      for M in L.Mode_Colors'Range loop
         pragma Loop_Invariant (M in L.Mode_Colors'Range);
         for D in L.Mode_Colors (M).Color'Range loop
            pragma Loop_Invariant (D in L.Mode_Colors (M).Color'Range);
            Put (Into, "mode_color " & Decimal (Integer_64 (M)) & " " & Decimal (Integer_64 (D)) & " "
                 & Decimal (Integer_64 (L.Mode_Colors (M).Color (D))) & CRLF);
         end loop;
      end loop;
      for D in L.Special_Colors.Color'Range loop
         pragma Loop_Invariant (D in L.Special_Colors.Color'Range);
         Put (Into, "mode_color 6 " & Decimal (Integer_64 (D)) & " "
              & Decimal (Integer_64 (L.Special_Colors.Color (D))) & CRLF);
      end loop;
      Put (Into, "mode_color 7 0 " & Decimal (Integer_64 (L.Ledstrip_Aux_Channel)) & CRLF);
   end Put_Mode_Colors;

   --  mode_color: every mode's direction colors, the special colors and the
   --  strip's aux channel, or one of them set from three numbers.
   procedure Mode_Color_Command (Into : in out Sink; L : in out Led_Strip_Status_Mode_Config_Record; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Values      : array (0 .. 2) of Integer_32 := (others => 0);
      Count       : Natural := 0;
      First, Last : Natural;
      From        : Positive := Arguments'First;
      OK          : Boolean := False;
   begin
      if Arguments'Length = 0 then
         Put_Mode_Colors (Into, L);
         return;
      end if;
      loop
         pragma Loop_Invariant (Count <= 3 and then From in Arguments'First .. Arguments'Last + 1);
         pragma Loop_Variant (Increases => From);
         Next_Word (Arguments, From, First, Last);
         exit when First = 0 or else Count = 3;
         Values (Count) := CLI_Text.To_Integer (Arguments (First .. Last));
         Count := Count + 1;
         From := Last + 1;
      end loop;
      if First > 0 or else Count /= 3 then
         Put (Into, "###ERROR IN mode_color: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      if Values (2) in 0 .. 15 then
         if Values (0) in 0 .. 5 then
            if Values (1) in 0 .. 5 then
               L.Mode_Colors (Natural (Values (0))).Color (Natural (Values (1))) := Unsigned_8 (Values (2));
               OK := True;
            end if;
         elsif Values (0) = 6 then
            if Values (1) in 0 .. 10 then
               L.Special_Colors.Color (Natural (Values (1))) := Unsigned_8 (Values (2));
               OK := True;
            end if;
         elsif Values (0) = 7 then
            if Values (1) = 0 then
               L.Ledstrip_Aux_Channel := Unsigned_8 (Values (2));
               OK := True;
            end if;
         end if;
      end if;
      if not OK then
         Put (Into, "###ERROR IN mode_color: PARSING FAILED###" & CRLF);
         return;
      end if;
      Put (Into, "mode_color " & Decimal (Integer_64 (Values (0))) & " " & Decimal (Integer_64 (Values (1))) & " "
           & Decimal (Integer_64 (Values (2))) & CRLF);
   end Mode_Color_Command;

   --  One VTX channel condition's line.
   procedure Put_Vtx_Condition (Into : in out Sink; Index : Natural; V : Vtx_Channel_Activation_Condition_Record)
     with Pre => Index <= 9
   is
   begin
      Put (Into, "vtx " & Decimal (Integer_64 (Index)) & " " & Decimal (Integer_64 (V.Aux_Channel_Index)) & " "
           & Decimal (Integer_64 (V.Band)) & " " & Decimal (Integer_64 (V.Channel)) & " "
           & Decimal (Integer_64 (V.Power)) & " " & Decimal (900 + 25 * Integer_64 (V.Range_Value.Start_Step))
           & " " & Decimal (900 + 25 * Integer_64 (V.Range_Value.End_Step)) & CRLF);
   end Put_Vtx_Condition;

   --  Every VTX channel condition's line.
   procedure Put_Vtx_Conditions (Into : in out Sink; Conditions : Vtx_Channel_Activation_Condition_Record_List_10) is
   begin
      for I in Conditions'Range loop
         pragma Loop_Invariant (I in Conditions'Range);
         Put_Vtx_Condition (Into, I, Conditions (I));
      end loop;
   end Put_Vtx_Conditions;

   --  vtx: every VTX channel condition, or one condition's aux channel, band,
   --  channel, power and range ends from its arguments, each valid one
   --  counted against the VTX table's counts; any other count than six
   --  clears the condition. A negative index gets the index range error.
   procedure Vtx_Command
     (Into : in out Sink; Conditions : in out Vtx_Channel_Activation_Condition_Record_List_10;
      Table : Vtx_Table_Config_Record; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is

      Index : Integer_32;
      Valid : Natural := 0;
      P     : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Vtx_Conditions (Into, Conditions);
         return;
      end if;
      Index := CLI_Text.To_Integer (Arguments);
      if Index not in 0 .. 9 then
         Put (Into, "###ERROR IN vtx: INDEX NOT BETWEEN 0 AND 9###" & CRLF);
         return;
      end if;
      declare
         Slot : constant Natural := Natural (Index);
         V    : Vtx_Channel_Activation_Condition_Record renames Conditions (Slot);
         Val  : Integer_32;
      begin
         P := Next_Argument (Arguments, Arguments'First + 1);
         if P > 0 then
            Val := Argument (Arguments, P);
            if Val in 0 .. Modes.Aux_Channel_Count - 1 then
               V.Aux_Channel_Index := Unsigned_8 (Val);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            Val := Argument (Arguments, P);
            if Val >= 0 and then Val <= Integer_32 (Table.Bands) then
               V.Band := Unsigned_8 (Val);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            Val := Argument (Arguments, P);
            if Val >= 0 and then Val <= Integer_32 (Table.Channels) then
               V.Channel := Unsigned_8 (Val);
               Valid := Valid + 1;
            end if;
         end if;
         P := Next_Argument (Arguments, P);
         if P > 0 then
            Val := Argument (Arguments, P);
            if Val >= 0 and then Val <= Integer_32 (Table.Power_Levels) then
               V.Power := Unsigned_8 (Val);
               Valid := Valid + 1;
            end if;
         end if;
         for End_Index in 0 .. 1 loop
            P := Next_Argument (Arguments, P);
            if P > 0 then
               Val := Argument (Arguments, P);
               Val := (Integer_32'Max (900, Integer_32'Min (2100, Val)) - 900) / 25;
               if End_Index = 0 then
                  V.Range_Value.Start_Step := Unsigned_8 (Val);
               else
                  V.Range_Value.End_Step := Unsigned_8 (Val);
               end if;
               Valid := Valid + 1;
            end if;
         end loop;
         if Valid /= 6 then
            V := (Aux_Channel_Index => 0, Band => 0, Channel => 0, Power => 0,
                  Range_Value => (Start_Step => 0, End_Step => 0));
            Put (Into, "###ERROR IN vtx: INVALID ARGUMENT COUNT###" & CRLF);
         else
            Put_Vtx_Condition (Into, Slot, V);
         end if;
      end;
   end Vtx_Command;

   Table_Bands      : constant := 8;
   Table_Channels   : constant := 8;
   Table_Powers     : constant := 8;
   Band_Name_Length : constant := 8;
   Label_Length     : constant := 3;

   function Upper_Char (Ch : Character) return Character is
     (if Ch in 'a' .. 'z' then Character'Val (Character'Pos (Ch) - 32) else Ch);

   --  A stored text up to its first zero byte.
   function Stored_Text (B : Bytes) return String
     with Pre => B'Length <= 32, Post => Stored_Text'Result'First = 1 and then Stored_Text'Result'Length <= B'Length
   is
      Text : String (1 .. B'Length) := (others => ' ');
      Last : Natural := 0;
   begin
      for K in B'Range loop
         pragma Loop_Invariant (Last = K - B'First and then Last < B'Length);
         exit when B (K) = 0;
         Last := Last + 1;
         Text (Last) := Character'Val (B (K));
      end loop;
      return Text (1 .. Last);
   end Stored_Text;

   --  A text copied into stored bytes up to a length, padded with spaces,
   --  then ended with a zero byte.
   procedure Store_Padded (Dst : out Bytes; Src : String; Length : Natural)
     with Pre => Length <= 16 and then Dst'First = 0 and then Dst'Last = Length and then Src'Length <= Length
   is
   begin
      Dst := (others => 0);
      for K in 0 .. Length - 1 loop
         Dst (Dst'First + K) :=
           (if K < Src'Length then Character'Pos (Src (Src'First + K)) else Character'Pos (' '));
      end loop;
   end Store_Padded;

   --  A band's channels from one on set to zero.
   procedure Clear_Channels (T : in out Vtx_Table_Config_Record; Band : Natural; From : Natural)
     with Pre => Band < Table_Bands
   is
   begin
      for C in From .. Table_Channels - 1 loop
         T.Frequency (Band) (C) := 0;
      end loop;
   end Clear_Channels;

   --  A band cleared: its frequencies zero, every channel named by its
   --  number, the band named BAND and its number, lettered by its number, and
   --  custom.
   procedure Clear_Band (T : in out Vtx_Table_Config_Record; Band : Natural)
     with Pre => Band < Table_Bands
   is
   begin
      Clear_Channels (T, Band, 0);
      for C in 0 .. Table_Channels - 1 loop
         T.Channel_Names (C) := (Unsigned_8 (Character'Pos ('1') + C), 0);
      end loop;
      Store_Padded (T.Band_Names (Band), "BAND" & Character'Val (Character'Pos ('1') + Band), Band_Name_Length);
      T.Band_Letters (Band) := Unsigned_8 (Character'Pos ('1') + Band);
      T.Is_Factory_Band (Band) := False;
   end Clear_Band;

   --  The table's bands, channels, each band's line, power levels, power
   --  values and power labels.
   procedure Put_Vtx_Table (Into : in out Sink; T : Vtx_Table_Config_Record) is
   begin
      Put (Into, "vtxtable bands " & Decimal (Integer_64 (T.Bands)) & CRLF);
      Put (Into, "vtxtable channels " & Decimal (Integer_64 (T.Channels)) & CRLF);
      for Band in 0 .. Natural'Min (Natural (T.Bands), Table_Bands) - 1 loop
         pragma Loop_Invariant (Band < Table_Bands);
         Put (Into, "vtxtable band " & Decimal (Integer_64 (Band + 1)) & " ");
         Put (Into, Stored_Text (T.Band_Names (Band)));
         Put (Into, " " & Character'Val (T.Band_Letters (Band))
              & (if T.Is_Factory_Band (Band) then " FACTORY" else " CUSTOM "));
         for C in 0 .. Natural'Min (Natural (T.Channels), Table_Channels) - 1 loop
            pragma Loop_Invariant (C < Table_Channels);
            declare
               Digits_Text : constant String := Decimal (Integer_64 (T.Frequency (Band) (C)));
            begin
               Put (Into, " ");
               if Digits_Text'Length < 4 then
                  Put (Into, (1 .. 4 - Digits_Text'Length => ' '));
               end if;
               Put (Into, Digits_Text);
            end;
         end loop;
         Put (Into, CRLF);
      end loop;
      Put (Into, "vtxtable powerlevels " & Decimal (Integer_64 (T.Power_Levels)) & CRLF);
      Put (Into, "vtxtable powervalues");
      for L in 0 .. Natural'Min (Natural (T.Power_Levels), Table_Powers) - 1 loop
         pragma Loop_Invariant (L < Table_Powers);
         Put (Into, " " & Decimal (Integer_64 (T.Power_Values (L))));
      end loop;
      Put (Into, CRLF);
      Put (Into, "vtxtable powerlabels");
      for L in 0 .. Natural'Min (Natural (T.Power_Levels), Table_Powers) - 1 loop
         pragma Loop_Invariant (L < Table_Powers);
         declare
            Label : constant String := Stored_Text (T.Power_Labels (L));
            Cut   : Natural := Label'Length;
         begin
            for K in Label'Range loop
               if Label (K) = ' ' then
                  Cut := K - Label'First;
                  exit;
               end if;
            end loop;
            Put (Into, " ");
            Put (Into, Label (Label'First .. Label'First + Cut - 1));
         end;
      end loop;
      Put (Into, CRLF);
   end Put_Vtx_Table;

   --  vtxtable: the table, or one of its parts set: the band count, the
   --  channel count, the power level count, the power values, the power
   --  labels, or one band's name, letter, factory flag and frequencies.
   procedure Vtx_Table_Command (Into : in out Sink; T : in out Vtx_Table_Config_Record; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      --  Whether a word follows a position.
      function Has_Word (At_Position : Positive) return Boolean is
        (for some K in At_Position .. Arguments'Last => Arguments (K) /= ' ')
        with Pre => At_Position >= Arguments'First;

      --  The number the next word from a position starts, as atoi reads it,
      --  and whether there is a word.
      procedure Read_Number (At_Position : Positive; Found : out Boolean; Value : out Integer_32)
        with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                    and then At_Position in Arguments'First .. Arguments'Last + 1
      is
         F, L : Natural;
      begin
         Next_Word (Arguments, At_Position, F, L);
         Found := F > 0;
         Value := (if F > 0 then CLI_Text.To_Integer (Arguments (F .. L)) else 0);
      end Read_Number;

      First, Last : Natural;
      From        : Positive;
      Found       : Boolean;
      Value       : Integer_32;
   begin
      Next_Word (Arguments, Arguments'First, First, Last);
      if First = 0 then
         Put_Vtx_Table (Into, T);
         return;
      end if;
      From := Last + 1;
      declare
         Sub : constant String := Arguments (First .. Last);
      begin
         if CLI_Text.Same_Ignoring_Case (Sub, "bands") then
            Read_Number (From, Found, Value);
            if not Found then
               Put (Into, "###ERROR IN vtxtable: INVALID ARGUMENT COUNT###" & CRLF);
            elsif Value not in 0 .. Table_Bands then
               Put (Into, "###ERROR IN vtxtable: BAND COUNT NOT BETWEEN 0 AND 8###" & CRLF);
            else
               for Band in Natural (Value) .. Natural'Min (Natural (T.Bands), Table_Bands) - 1 loop
                  Clear_Band (T, Band);
               end loop;
               T.Bands := Unsigned_8 (Value);
            end if;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "channels") then
            Read_Number (From, Found, Value);
            if not Found then
               Put (Into, "###ERROR IN vtxtable: INVALID ARGUMENT COUNT###" & CRLF);
            elsif Value not in 0 .. Table_Channels then
               Put (Into, "###ERROR IN vtxtable: CHANNEL COUNT NOT BETWEEN 0 AND 8###" & CRLF);
            else
               if Unsigned_8 (Value) < T.Channels then
                  for Band in 0 .. Table_Bands - 1 loop
                     Clear_Channels (T, Band, Natural (Value));
                  end loop;
               end if;
               T.Channels := Unsigned_8 (Value);
            end if;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "powerlevels") then
            Read_Number (From, Found, Value);
            if Found then
               if Value not in 0 .. Table_Powers then
                  Put (Into, "###ERROR IN vtxtable: POWER LEVEL COUNT NOT BETWEEN 0 AND 8###" & CRLF);
               else
                  if Unsigned_8 (Value) < T.Power_Levels then
                     for L in Natural (Value) .. Table_Powers - 1 loop
                        T.Power_Values (L) := 0;
                     end loop;
                     for L in Natural (Value) .. Table_Powers - 1 loop
                        Store_Padded (T.Power_Labels (L), "LV" & Character'Val (Character'Pos ('0') + L), Label_Length);
                     end loop;
                  end if;
                  T.Power_Levels := Unsigned_8 (Value);
               end if;
            end if;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "powervalues") then
            declare
               Levels : constant Natural := Natural'Min (Natural (T.Power_Levels), Table_Powers);
               Power  : Unsigned_16_List_8 := (others => 0);
               Count  : Natural := 0;
            begin
               while Count < Levels loop
                  pragma Loop_Invariant (Count < Levels and then From in Arguments'First .. Arguments'Last + 1);
                  pragma Loop_Variant (Increases => Count);
                  Next_Word (Arguments, From, First, Last);
                  exit when First = 0;
                  Power (Count) := Unsigned_16'Mod (CLI_Text.To_Integer (Arguments (First .. Last)));
                  From := Last + 1;
                  Count := Count + 1;
               end loop;
               if Count < Natural (T.Power_Levels) then
                  Put (Into, "###ERROR IN vtxtable: NOT ENOUGH VALUES (EXPECTED "
                       & Decimal (Integer_64 (T.Power_Levels)) & ")###" & CRLF);
               elsif Has_Word (From) then
                  Put (Into, "###ERROR IN vtxtable: TOO MANY VALUES (EXPECTED "
                       & Decimal (Integer_64 (T.Power_Levels)) & ")###" & CRLF);
               else
                  T.Power_Values := Power;
               end if;
            end;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "powerlabels") then
            declare
               Levels : constant Natural := Natural'Min (Natural (T.Power_Levels), Table_Powers);
               Labels : array (0 .. Table_Powers - 1) of String (1 .. Label_Length) := (others => (others => ' '));
               Sizes  : array (0 .. Table_Powers - 1) of Natural range 0 .. Label_Length := (others => 0);
               Count  : Natural := 0;
            begin
               while Count < Levels loop
                  pragma Loop_Invariant (Count < Levels and then From in Arguments'First .. Arguments'Last + 1);
                  pragma Loop_Variant (Increases => Count);
                  Next_Word (Arguments, From, First, Last);
                  exit when First = 0;
                  Sizes (Count) := Natural'Min (Last - First + 1, Label_Length);
                  for K in 1 .. Sizes (Count) loop
                     Labels (Count) (K) := Upper_Char (Arguments (First + K - 1));
                  end loop;
                  From := Last + 1;
                  Count := Count + 1;
               end loop;
               if Count < Natural (T.Power_Levels) then
                  Put (Into, "###ERROR IN vtxtable: NOT ENOUGH LABELS (EXPECTED "
                       & Decimal (Integer_64 (T.Power_Levels)) & ")###" & CRLF);
               elsif Has_Word (From) then
                  Put (Into, "###ERROR IN vtxtable: TOO MANY LABELS (EXPECTED "
                       & Decimal (Integer_64 (T.Power_Levels)) & ")###" & CRLF);
               else
                  for L in 0 .. Count - 1 loop
                     Store_Padded (T.Power_Labels (L), Labels (L) (1 .. Sizes (L)), Label_Length);
                  end loop;
               end if;
            end;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "band") then
            declare
               Band      : Integer_64;
               Name      : String (1 .. Band_Name_Length) := (others => ' ');
               Name_Size : Natural range 0 .. Band_Name_Length;
               Letter    : Character;
               Freqs     : Unsigned_16_List_8 := (others => 0);
               Channel   : Natural := 0;
               Channels  : constant Natural := Natural'Min (Natural (T.Channels), Table_Channels);
               Factory   : Boolean := False;
            begin
               Next_Word (Arguments, From, First, Last);
               if First = 0 then
                  return;
               end if;
               Band := Integer_64 (CLI_Text.To_Integer (Arguments (First .. Last))) - 1;
               if Band < 0 or else Band >= Integer_64 (T.Bands) or else Band >= Table_Bands then
                  Put (Into, "###ERROR IN vtxtable: BAND NUMBER NOT BETWEEN 1 AND " & Decimal (Integer_64 (T.Bands))
                       & "###" & CRLF);
                  return;
               end if;
               Next_Word (Arguments, Last + 1, First, Last);
               if First = 0 then
                  return;
               end if;
               Name_Size := Natural'Min (Last - First + 1, Band_Name_Length);
               for K in 1 .. Name_Size loop
                  Name (K) := Upper_Char (Arguments (First + K - 1));
               end loop;
               Next_Word (Arguments, Last + 1, First, Last);
               if First = 0 then
                  return;
               end if;
               Letter := Upper_Char (Arguments (First));
               From := Last + 1;
               while Channel < Channels loop
                  pragma Loop_Invariant (Channel < Channels and then From in Arguments'First .. Arguments'Last + 1);
                  pragma Loop_Variant (Increases => From);
                  Next_Word (Arguments, From, First, Last);
                  exit when First = 0;
                  From := Last + 1;
                  if Channel = 0 and then Arguments (First) not in '0' .. '9' then
                     if CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "FACTORY") then
                        Factory := True;
                     elsif CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "CUSTOM") then
                        Factory := False;
                     else
                        Put (Into, "###ERROR IN vtxtable: INVALID FACTORY FLAG ");
                        Put (Into, Arguments (First .. Last));
                        Put (Into, " (EXPECTED FACTORY OR CUSTOM)###" & CRLF);
                        return;
                     end if;
                  else
                     Value := CLI_Text.To_Integer (Arguments (First .. Last));
                     if Value < 0 then
                        Put (Into, "###ERROR IN vtxtable: INVALID FREQUENCY ");
                        Put (Into, Arguments (First .. Last));
                        Put (Into, "###" & CRLF);
                        return;
                     end if;
                     Freqs (Channel) := Unsigned_16'Mod (Value);
                     Channel := Channel + 1;
                  end if;
               end loop;
               if Channel < Natural (T.Channels) then
                  Put (Into, "###ERROR IN vtxtable: NOT ENOUGH FREQUENCIES (EXPECTED "
                       & Decimal (Integer_64 (T.Channels)) & ")###" & CRLF);
               elsif Has_Word (From) then
                  Put (Into, "###ERROR IN vtxtable: TOO MANY FREQUENCIES (EXPECTED "
                       & Decimal (Integer_64 (T.Channels)) & ")###" & CRLF);
               else
                  Store_Padded (T.Band_Names (Natural (Band)), Name (1 .. Name_Size), Band_Name_Length);
                  T.Band_Letters (Natural (Band)) := Character'Pos (Letter);
                  for C in 0 .. Channel - 1 loop
                     T.Frequency (Natural (Band)) (C) := Freqs (C);
                  end loop;
                  T.Is_Factory_Band (Natural (Band)) := Factory;
               end if;
            end;
         else
            Put (Into, "###ERROR IN vtxtable: INVALID SUBCOMMAND ");
            Put (Into, Sub);
            Put (Into, "###" & CRLF);
         end if;
      end;
   end Vtx_Table_Command;

   Max_Waypoints : constant := 30;

   subtype Waypoint_List is Flight_Plan_Config_Record_Waypoints_Record_List_30;
   subtype Waypoint is Flight_Plan_Config_Record_Waypoints_Record;

   function Type_Name (T : Unsigned_8) return String is
     (case T is
         when 0 => "FLYOVER", when 1 => "FLYBY", when 2 => "HOLD", when 3 => "LAND", when 4 => "TAKEOFF",
         when 5 => "ALT_CHANGE", when 6 => "DELAY", when 7 => "YAW_RATE", when others => "UNKNOWN")
     with Post => Type_Name'Result'Length in 4 .. 10;

   function Pattern_Name (P : Unsigned_8) return String is
     (case P is
         when 0 => "NONE", when 1 => "ORBIT", when 2 => "FIGURE8", when others => "UNKNOWN")
     with Post => Pattern_Name'Result'Length in 4 .. 7;

   function Yaw_Name (Y : Unsigned_8) return String is
     (case Y is
         when 0 => "DEFAULT", when 1 => "FACE_TARGET", when 2 => "FACE_NEXT", when 3 => "HOLD",
         when others => "UNKNOWN")
     with Post => Yaw_Name'Result'Length in 4 .. 11;

   --  A length in centimeters as meters with two decimals.
   procedure Put_Meters (Into : in out Sink; Length_Cm : Integer_64)
     with Pre => Length_Cm in -2 ** 32 .. 2 ** 32
   is
      Magnitude  : constant Integer_64 := abs Length_Cm;
      Hundredths : constant String (1 .. 2) :=
        (Character'Val (Character'Pos ('0') + Natural (Magnitude mod 100 / 10)),
         Character'Val (Character'Pos ('0') + Natural (Magnitude mod 10)));
   begin
      if Length_Cm < 0 then
         Put (Into, "-");
      end if;
      Put (Into, Decimal (Magnitude / 100));
      Put (Into, "." & Hundredths & "m");
   end Put_Meters;

   --  A distance in meters as whole centimeters, rounded as the target's C
   --  library rounds and held at the 32-bit range.
   function Centimeters (Meters : Float) return Integer_64
     with Pre => Meters >= 0.0, Post => Centimeters'Result in 0 .. 2_147_483_647
   is
   begin
      if Meters >= 1.0E9 then
         return 2_147_483_647;
      end if;
      declare
         P : constant Float := Meters * 100.0;
      begin
         if P >= 2_147_483_648.0 then
            return 2_147_483_647;
         elsif P > Float (Maths.Rounding_Bound) - 1.0 then
            return Integer_64'Min (2_147_483_647, Integer_64 (P));
         else
            return Integer_64'Max (0, Integer_64 (Maths.Round_Half_Even (P)));
         end if;
      end;
   end Centimeters;

   --  The plan as a clear line and an insert line for each waypoint.
   procedure Put_Waypoints (Into : in out Sink; Count : Unsigned_8; Points : Waypoint_List) is
   begin
      Put (Into, "waypoint clear" & CRLF);
      for I in 0 .. Natural'Min (Natural (Count), Max_Waypoints) - 1 loop
         pragma Loop_Invariant (I < Max_Waypoints);
         declare
            W : constant Waypoint := Points (I);
         begin
            Put (Into, "waypoint insert " & Decimal (Integer_64 (I)) & " " & CLI_Text.Coordinate_Text (W.Latitude) & " "
                 & CLI_Text.Coordinate_Text (W.Longitude) & " " & Decimal (Integer_64 (W.Altitude)) & " "
                 & Decimal (Integer_64 (W.Speed)) & " ");
            Put (Into, Type_Name (W.Type_Value) & " " & Decimal (Integer_64 (W.Duration)) & " "
                 & Pattern_Name (W.Pattern) & " " & Decimal (Integer_64 (W.Vert_Rate)) & " "
                 & Yaw_Name (W.Yaw_Behaviour) & CRLF);
         end;
      end loop;
   end Put_Waypoints;

   --  waypoint: the plan, cleared, its status with the executor's, one
   --  waypoint removed, or one inserted or updated from its index,
   --  coordinates, altitude, speed, type, duration and pattern, with an
   --  optional vertical rate and yaw behaviour. A stored count past the plan
   --  is cleared first.
   procedure Waypoint_Command
     (Into : in out Sink; Plan : in out Flight_Plan_Config_Record; Navigation : Navigation_Status;
      Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Max_Args : constant := 11;
      Firsts   : array (1 .. Max_Args) of Positive := (others => Arguments'First);
      Lasts    : array (1 .. Max_Args) of Natural := (others => 0);
      Count    : Natural := 0;
      First    : Natural;
      Last     : Natural;
      From     : Positive := Arguments'First;

      function Arg (K : Positive) return String is (Arguments (Firsts (K) .. Lasts (K)))
        with Pre => K <= Count and then K <= Max_Args and then Firsts (K) in Arguments'Range
                    and then Lasts (K) in Firsts (K) .. Arguments'Last;

      function Is_Op (Name : String) return Boolean is
        (Count >= 1 and then Firsts (1) in Arguments'Range and then Lasts (1) in Firsts (1) .. Arguments'Last
         and then CLI_Text.Same_Ignoring_Case (Arguments (Firsts (1) .. Lasts (1)), Name));

      procedure Error (Text : String) is
      begin
         Put (Into, "###ERROR IN waypoint: ");
         Put (Into, Text);
         Put (Into, "###" & CRLF);
      end Error;
   begin
      if Plan.Waypoint_Count > Max_Waypoints then
         Plan.Waypoint_Count := 0;
         Error ("WAYPOINT COUNT CORRUPTED, CLEARED");
      end if;
      if Arguments'Length = 0 then
         Put_Waypoints (Into, Plan.Waypoint_Count, Plan.Waypoints);
         return;
      end if;
      loop
         pragma Loop_Invariant
           (Count <= Max_Args and then From in Arguments'First .. Arguments'Last + 1
            and then (for all K in 1 .. Count =>
                        Firsts (K) in Arguments'Range and then Lasts (K) in Firsts (K) .. Arguments'Last));
         pragma Loop_Variant (Increases => From);
         Next_Word (Arguments, From, First, Last);
         exit when First = 0 or else Count = Max_Args;
         Count := Count + 1;
         Firsts (Count) := First;
         Lasts (Count) := Last;
         From := Last + 1;
      end loop;
      if First > 0 then
         Error ("INVALID ARGUMENT COUNT");
         return;
      end if;
      if Count = 0 then
         return;
      end if;
      if Is_Op ("clear") then
         if Count /= 1 then
            Error ("INVALID ARGUMENT COUNT");
            return;
         end if;
         Plan.Waypoint_Count := 0;
         Put (Into, "Waypoints cleared" & CRLF);
      elsif Is_Op ("list") then
         if Count /= 1 then
            Error ("INVALID ARGUMENT COUNT");
            return;
         end if;
         Put_Waypoints (Into, Plan.Waypoint_Count, Plan.Waypoints);
      elsif Is_Op ("status") then
         if Count /= 1 then
            Error ("INVALID ARGUMENT COUNT");
            return;
         end if;
         Put (Into, "Waypoint count: " & Decimal (Integer_64 (Plan.Waypoint_Count)) & CRLF);
         if Plan.Waypoint_Count > 0 then
            Put (Into, ASCII.LF & "Configured waypoints:" & CRLF);
            for I in 0 .. Natural (Plan.Waypoint_Count) - 1 loop
               pragma Loop_Invariant (I < Max_Waypoints);
               declare
                  W : constant Waypoint := Plan.Waypoints (I);
               begin
                  Put (Into, "  [" & Decimal (Integer_64 (I)) & "] " & CLI_Text.Coordinate_Text (W.Latitude) & " "
                       & CLI_Text.Coordinate_Text (W.Longitude) & " ");
                  Put_Meters (Into, Integer_64 (W.Altitude));
                  Put (Into, " " & Type_Name (W.Type_Value) & CRLF);
               end;
            end loop;
         end if;
         Put (Into, ASCII.LF & "Runtime status:" & CRLF);
         if not Navigation.Active then
            Put (Into, "  inactive" & CRLF);
            return;
         end if;
         Put (Into, "  state: "
              & (case Navigation.State is
                    when 0 => "IDLE", when 1 => "TARGETING", when 2 => "HOLDING", when 3 => "COMPLETE",
                    when 4 => "LANDING", when 5 => "ABORTED", when others => "UNKNOWN") & CRLF);
         Put (Into, "  current waypoint: "
              & Decimal (if Plan.Waypoint_Count = 0 then 0 else Integer_64 (Navigation.Current_Index + 1)) & "/"
              & Decimal (Integer_64 (Plan.Waypoint_Count)) & CRLF);
         if Navigation.Distance_M >= 0.0 then
            Put (Into, "  distance: ");
            Put_Meters (Into, Centimeters (Navigation.Distance_M));
            Put (Into, "  bearing: " & Decimal (Integer_64 (Navigation.Bearing_Deci / 10)) & " deg  eta: "
                 & Decimal (Integer_64 (Navigation.ETA_S)) & "s" & CRLF);
         end if;
         if Navigation.State = 5 then
            Put (Into, "  abort reason: "
                 & (case Navigation.Abort_Reason is
                       when 0 => "NONE", when 1 => "GPS LOST", when 2 => "STALLED", when 3 => "FLYAWAY",
                       when 4 => "HEADING", when 5 => "MAG FAULT", when others => "UNKNOWN") & CRLF);
         end if;
      elsif Is_Op ("remove") then
         if Count /= 2 then
            Error ("INVALID ARGUMENT COUNT");
            return;
         end if;
         if Plan.Waypoint_Count = 0 then
            Error ("NO WAYPOINTS TO REMOVE");
            return;
         end if;
         declare
            Index : Integer_64;
            OK    : Boolean;
         begin
            CLI_Text.Parse_Whole (Arg (2), Index, OK);
            if not OK then
               Error ("INVALID INDEX");
               return;
            end if;
            if Index < 0 or else Index >= Integer_64 (Plan.Waypoint_Count) then
               Error ("index NOT BETWEEN 0 AND " & Decimal (Integer_64 (Plan.Waypoint_Count) - 1));
               return;
            end if;
            for I in Natural (Index) .. Natural (Plan.Waypoint_Count) - 2 loop
               Plan.Waypoints (I) := Plan.Waypoints (I + 1);
            end loop;
            Plan.Waypoint_Count := Plan.Waypoint_Count - 1;
            Put (Into, "Waypoint " & Decimal (Index) & " removed, " & Decimal (Integer_64 (Plan.Waypoint_Count))
                 & " waypoints remaining" & CRLF);
         end;
      elsif Is_Op ("insert") or else Is_Op ("update") then
         declare
            Insert    : constant Boolean := Is_Op ("insert");
            Index     : Integer_64;
            Latitude  : Integer_32;
            Longitude : Integer_32;
            Altitude  : Integer_64;
            Speed     : Integer_64;
            Duration  : Integer_64;
            Rate      : Integer_64 := 0;
            Kind      : Unsigned_8 := 0;
            Pattern   : Unsigned_8 := 0;
            Yaw       : Unsigned_8 := 0;
            Found     : Boolean;
            OK        : Boolean;
         begin
            if Count /= 9 and then Count /= 11 then
               Error ("INVALID ARGUMENT COUNT");
               return;
            end if;
            CLI_Text.Parse_Whole (Arg (2), Index, OK);
            if not OK then
               Error ("INVALID INDEX");
               return;
            end if;
            if Insert then
               if Index < 0 or else Index > Integer_64 (Plan.Waypoint_Count)
                 or else Plan.Waypoint_Count >= Max_Waypoints
               then
                  if Plan.Waypoint_Count >= Max_Waypoints then
                     Error ("WAYPOINT LIST FULL");
                  else
                     Error ("index NOT BETWEEN 0 AND " & Decimal (Integer_64 (Plan.Waypoint_Count)));
                  end if;
                  return;
               end if;
            else
               if Plan.Waypoint_Count = 0 then
                  Error ("NO WAYPOINTS TO UPDATE");
                  return;
               end if;
               if Index < 0 or else Index >= Integer_64 (Plan.Waypoint_Count) then
                  Error ("index NOT BETWEEN 0 AND " & Decimal (Integer_64 (Plan.Waypoint_Count) - 1));
                  return;
               end if;
            end if;
            CLI_Text.Parse_Coordinate (Arg (3), Latitude, OK);
            if not OK then
               Error ("INVALID LATITUDE FORMAT. USE: -90.0000000 to 90.0000000");
               return;
            end if;
            CLI_Text.Parse_Coordinate (Arg (4), Longitude, OK);
            if not OK then
               Error ("INVALID LONGITUDE FORMAT. USE: -180.0000000 to 180.0000000");
               return;
            end if;
            CLI_Text.Parse_Whole (Arg (5), Altitude, OK);
            if not OK then
               Error ("INVALID ALTITUDE");
               return;
            end if;
            if Altitude not in Integer_64 (Integer_32'First) .. Integer_64 (Integer_32'Last) then
               Error ("ALTITUDE OUT OF RANGE");
               return;
            end if;
            CLI_Text.Parse_Whole (Arg (6), Speed, OK);
            if not OK then
               Error ("INVALID SPEED");
               return;
            end if;
            CLI_Text.Parse_Whole (Arg (8), Duration, OK);
            if not OK then
               Error ("INVALID DURATION");
               return;
            end if;
            if Speed not in 0 .. 65_535 then
               Error ("speed NOT BETWEEN 0 AND 65535");
               return;
            end if;
            if Duration not in 0 .. 65_535 then
               Error ("duration NOT BETWEEN 0 AND 65535");
               return;
            end if;
            Found := False;
            for T in Unsigned_8 range 0 .. 7 loop
               if CLI_Text.Same_Ignoring_Case (Arg (7), Type_Name (T)) then
                  Kind := T;
                  Found := True;
                  exit;
               end if;
            end loop;
            if not Found then
               Error ("INVALID TYPE. USE: FLYOVER, FLYBY, HOLD, LAND, TAKEOFF, ALT_CHANGE, DELAY, YAW_RATE");
               return;
            end if;
            Found := False;
            for P in Unsigned_8 range 0 .. 2 loop
               if CLI_Text.Same_Ignoring_Case (Arg (9), Pattern_Name (P)) then
                  Pattern := P;
                  Found := True;
                  exit;
               end if;
            end loop;
            if not Found then
               Error ("INVALID PATTERN. USE: NONE, ORBIT, FIGURE8");
               return;
            end if;
            if Count = 11 then
               CLI_Text.Parse_Whole (Arg (10), Rate, OK);
               if not OK then
                  Error ("INVALID VERTICAL RATE");
                  return;
               end if;
               if Rate not in 0 .. 65_535 then
                  Error ("vertical rate NOT BETWEEN 0 AND 65535");
                  return;
               end if;
               Found := False;
               for Y in Unsigned_8 range 0 .. 3 loop
                  if CLI_Text.Same_Ignoring_Case (Arg (11), Yaw_Name (Y)) then
                     Yaw := Y;
                     Found := True;
                     exit;
                  end if;
               end loop;
               if not Found then
                  Error ("INVALID YAW BEHAVIOUR. USE: DEFAULT, FACE_TARGET, FACE_NEXT, HOLD");
                  return;
               end if;
            end if;
            if Latitude not in -900_000_000 .. 900_000_000 then
               Error ("LATITUDE OUT OF RANGE. USE: -90.0 to 90.0");
               return;
            end if;
            if Longitude not in -1_800_000_000 .. 1_800_000_000 then
               Error ("LONGITUDE OUT OF RANGE. USE: -180.0 to 180.0");
               return;
            end if;
            if Insert then
               for I in reverse Natural (Index) + 1 .. Natural (Plan.Waypoint_Count) loop
                  Plan.Waypoints (I) := Plan.Waypoints (I - 1);
               end loop;
               Plan.Waypoint_Count := Plan.Waypoint_Count + 1;
            end if;
            Plan.Waypoints (Natural (Index)) :=
              (Latitude => Latitude, Longitude => Longitude, Altitude => Integer_32 (Altitude),
               Speed => Unsigned_16 (Speed), Duration => Unsigned_16 (Duration), Vert_Rate => Unsigned_16 (Rate),
               Type_Value => Kind, Pattern => Pattern, Yaw_Behaviour => Yaw);
            Put (Into, "waypoint " & (if Insert then "insert" else "update") & " " & Decimal (Index) & " "
                 & CLI_Text.Coordinate_Text (Latitude) & " " & CLI_Text.Coordinate_Text (Longitude) & " ");
            Put_Meters (Into, Altitude);
            Put (Into, " " & Decimal (Speed) & " " & Type_Name (Kind) & " " & Decimal (Duration) & " "
                 & Pattern_Name (Pattern) & " " & Decimal (Rate) & " " & Yaw_Name (Yaw) & CRLF);
         end;
      else
         Error ("INVALID OPERATION. USE: list, status, insert, update, remove, clear");
      end if;
   end Waypoint_Command;

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

   subtype Map_Text is String (1 .. Mappable);

   --  The map line: each stick's letter at its channel over a starting text,
   --  up to the first position without a letter.
   procedure Put_Map (Into : in out Sink; Start : Map_Text; Rcmap : Bytes_8) is
      Buffer : Map_Text := Start;
      Last   : Natural := 0;
   begin
      for I in 0 .. Mappable - 1 loop
         if Rcmap (I) < Mappable then
            Buffer (Natural (Rcmap (I)) + 1) := Channel_Letters (Channel_Letters'First + I);
         end if;
      end loop;
      for I in 1 .. Mappable loop
         exit when Buffer (I) = ASCII.NUL;
         Last := I;
         pragma Loop_Invariant (Last = I);
      end loop;
      Put (Into, "map " & Buffer (1 .. Last) & CRLF);
   end Put_Map;

   --  map: a new channel order of the eight mappable channels, each letter
   --  once, then the order as a map line, each channel's letter at its
   --  position over the typed text, or over a cleared buffer for a query.
   procedure Map_Command (Into : in out Sink; C : in out Configuration; Arguments : String) is
      Buffer : Map_Text := (others => ASCII.NUL);
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
      Put_Map (Into, Buffer, C.Rx_Config.Rcmap);
   end Map_Command;

   --  The four sticks' channel range lines.
   procedure Put_Ranges (Into : in out Sink; Ranges : Rx_Channel_Range_Config_Record_List_4) is
   begin
      for I in Ranges'Range loop
         pragma Loop_Invariant (I in Ranges'Range);
         Put (Into, "rxrange " & Decimal (Integer_64 (I)) & " " & Decimal (Integer_64 (Ranges (I).Min)) & " "
              & Decimal (Integer_64 (Ranges (I).Max)) & CRLF);
      end loop;
   end Put_Ranges;

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
         Put_Ranges (Into, C.Rx_Channel_Range_Configs);
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

   --  A channel's failsafe line: its mode's letter and, for the set mode, its
   --  value.
   procedure Put_Failsafe (Into : in out Sink; Channel : Natural; F : Rx_Failsafe_Channel_Config_Record) is
   begin
      Put (Into, "rxfail " & Decimal (Integer_64 (Channel)) & " "
           & (if F.Mode <= 2 then (1 => Failsafe_Characters (Natural (F.Mode) + 1)) else ""));
      if F.Mode = 2 then
         Put (Into, " " & Decimal (750 + 25 * Integer_64 (F.Step)));
      end if;
      Put (Into, CRLF);
   end Put_Failsafe;

   --  Every channel's failsafe line.
   procedure Put_Failsafes (Into : in out Sink; Configs : Rx_Failsafe_Channel_Config_Record_List_18) is
   begin
      for I in Configs'Range loop
         pragma Loop_Invariant (I in Configs'Range);
         Put_Failsafe (Into, I, Configs (I));
      end loop;
   end Put_Failsafes;

   --  rxfail: every channel's failsafe line, or one channel's mode and, for
   --  the set mode, its value; the channel number is taken modulo 256.
   procedure Failsafe_Command (Into : in out Sink; C : in out Configuration; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      Channel_Count : constant := Rx_Failsafe_Channel_Config_Record_List_18'Length;
      Channel       : Unsigned_8;
      P             : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Failsafes (Into, C.Rx_Failsafe_Channel_Configs);
         return;
      end if;
      Channel := Unsigned_8'Mod (CLI_Text.To_Integer (Arguments));
      if Channel >= Channel_Count then
         Put (Into, "###ERROR IN rxfail: CHANNEL NOT BETWEEN 0 AND 17###" & CRLF);
         return;
      end if;
      declare
         Index         : constant Natural := Natural (Channel);
         Mode          : Unsigned_8;
         Require_Value : Boolean;
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
         Put_Failsafe (Into, Index, C.Rx_Failsafe_Channel_Configs (Index));
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
      Beeper_Command_Word, Color_Command_Word, Diff_Command, Dump_Command, Feature_Command_Word, Get_Command,
      Led_Command_Word, Map_Command_Word, Mode_Color_Command_Word,
      Mixer_Command_Word, Motor_Mix_Command_Word, Profile_Command, Rate_Profile_Command, Rx_Failsafe_Command,
      Rx_Range_Command, Serial_Command_Word, Servo_Command_Word, Servo_Mix_Command_Word, Set_Command,
      Vtx_Command_Word, Vtx_Table_Command_Word, Waypoint_Command_Word);
   subtype Known_Command is Command_Kind range Adjustment_Range_Command_Word .. Waypoint_Command_Word;

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
         when Color_Command_Word => "color",
         when Led_Command_Word => "led",
         when Mode_Color_Command_Word => "mode_color",
         when Map_Command_Word => "map",
         when Mixer_Command_Word => "mixer",
         when Motor_Mix_Command_Word => "mmix",
         when Profile_Command => "profile",
         when Rate_Profile_Command => "rateprofile",
         when Rx_Failsafe_Command => "rxfail",
         when Rx_Range_Command => "rxrange",
         when Serial_Command_Word => "serial",
         when Servo_Command_Word => "servo",
         when Servo_Mix_Command_Word => "smix",
         when Set_Command => "set",
         when Vtx_Command_Word => "vtx",
         when Vtx_Table_Command_Word => "vtxtable",
         when Waypoint_Command_Word => "waypoint")
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

   --  The version line: the firmware's name, the target's name, a board
   --  identifier, the version, the build's date, time and revision, and the
   --  MSP API version.
   procedure Put_Version (Into : in out Sink; Env : Environment; Identifier : Bytes_6) is
   begin
      Put (Into, "# ");
      Put (Into, Text_Of (Env.Firmware));
      Put (Into, " / ");
      Put (Into, Text_Of (Env.Target));
      Put (Into, " (");
      Put (Into, Stored_Text (Identifier));
      Put (Into, ") ");
      Put (Into, Text_Of (Env.Version));
      Put (Into, " ");
      Put (Into, Text_Of (Env.Build_Date));
      Put (Into, " / ");
      Put (Into, Text_Of (Env.Build_Time));
      Put (Into, " (");
      Put (Into, Text_Of (Env.Revision));
      Put (Into, ") MSP API: " & Decimal (MSP_Common_Out.API_Version_Major) & "."
           & Decimal (MSP_Common_Out.API_Version_Minor) & CRLF);
   end Put_Version;

   --  The master dump: the version line with the default board identifier,
   --  the command batch's start, the board's name and manufacturer, the craft
   --  name, then under their headings the features, the mixer with its custom
   --  motor mix, the servos, the servo rules, the beepers, the beacons, the
   --  channel map, the LEDs, the colors, the mode colors, the mode
   --  conditions, the adjustment ranges, the channel ranges, the VTX table,
   --  the VTX conditions, the channel failsafe, the flight plan and the
   --  master settings, then the selected profiles and the batch's end. A bare
   --  dump leaves out the batch.
   procedure Dump_Master
     (Into : in out Sink; C : Configuration; Env : Environment; Command : String; Bare : Boolean; Ports : Port_List)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Craft : constant String := Stored_Text (C.Pilot_Config.Craft_Name);
      Mode  : constant Unsigned_8 := C.Mixer_Config.Mixer_Mode;
   begin
      Put_Hash_Line (Into, "version");
      Put_Version (Into, Env, Defaults.System_Config.Board_Identifier);
      if not Bare then
         Put_Hash_Line (Into, "start the command batch");
         Put (Into, "batch start" & CRLF);
      end if;
      Put (Into, CRLF & "board_name ");
      Put (Into, Text_Of (Env.Board_Name));
      Put (Into, CRLF & "manufacturer_id ");
      Put (Into, Text_Of (Env.Manufacturer_Id));
      Put (Into, CRLF & CRLF & "# name: ");
      Put (Into, (if Craft'Length = 0 then "-" else Craft));
      Put (Into, CRLF);
      Put_Hash_Line (Into, "feature");
      Put_Feature_Dump (Into, C.Feature_Config.Enabled_Features);
      Put_Hash_Line (Into, "mixer");
      Put (Into, "mixer ");
      if Mode in 1 .. Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1 then
         Put (Into, Mixer_Name (Mixer_Init.Mixer_Mode'Val (Mode - 1)));
      end if;
      Put (Into, CRLF & CRLF & "mmix reset" & CRLF & CRLF);
      Put_Motor_Mix (Into, C.Custom_Motor_Mixer);
      Put_Hash_Line (Into, "servo");
      Put_Servos (Into, C.Servo_Params);
      Put_Hash_Line (Into, "servo mixer");
      Put (Into, "smix reset" & CRLF & CRLF);
      Put_Servo_Rules (Into, C.Custom_Servo_Mixers);
      Put_Hash_Line (Into, "beeper");
      Put_Beeper_Dump (Into, "beeper", C.Beeper_Config.Beeper_Off_Flags, Beeper_Allowed);
      Put_Hash_Line (Into, "beacon");
      Put_Beeper_Dump (Into, "beacon", C.Beeper_Config.Dshot_Beacon_Off_Flags, Beacon_Allowed);
      Put_Hash_Line (Into, "map");
      Put_Map (Into, (others => ASCII.NUL), C.Rx_Config.Rcmap);
      Put_Hash_Line (Into, "led");
      Put_Leds (Into, C.Led_Strip_Status_Mode_Config.Led_Configs);
      Put_Hash_Line (Into, "color");
      Put_Colors (Into, C.Led_Strip_Status_Mode_Config.Colors);
      Put_Hash_Line (Into, "mode_color");
      Put_Mode_Colors (Into, C.Led_Strip_Status_Mode_Config);
      Put_Hash_Line (Into, "aux");
      Put_Conditions (Into, C.Mode_Activation_Conditions);
      Put_Hash_Line (Into, "adjrange");
      Put_Adjustment_Ranges (Into, C.Adjustment_Ranges);
      Put_Hash_Line (Into, "rxrange");
      Put_Ranges (Into, C.Rx_Channel_Range_Configs);
      Put_Hash_Line (Into, "vtxtable");
      Put_Vtx_Table (Into, C.Vtx_Table_Config);
      Put_Hash_Line (Into, "vtx");
      Put_Vtx_Conditions (Into, C.Vtx_Config.Vtx_Channel_Activation_Conditions);
      Put_Hash_Line (Into, "rxfail");
      Put_Failsafes (Into, C.Rx_Failsafe_Channel_Configs);
      Put_Hash_Line (Into, "waypoint");
      Put_Waypoints (Into, C.Flight_Plan_Config.Waypoint_Count, C.Flight_Plan_Config.Waypoints);
      Dump_Values (Into, C, Master, Current (C), "master", Command, False, False, Ports);
      Dump_Profile (Into, C, PID, Natural (C.System_Config.Pid_Profile_Index), Command, False, False, Ports);
      Dump_Profile (Into, C, Rate, Natural (C.System_Config.Active_Rate_Profile), Command, False, False, Ports);
      Dump_Profile (Into, C, Battery, Natural (C.System_Config.Active_Battery_Profile), Command, False, False, Ports);
      if not Bare then
         Put_Hash_Line (Into, "end the command batch");
         Put (Into, "batch end" & CRLF);
      end if;
   end Dump_Master;

   --  dump or diff: a profile's or a rate profile's settings, with their
   --  defaults after the option defaults, or the master dump, without the
   --  command batch after the option bare; Known is false for other sections
   --  and for a master diff or a master dump with defaults.
   procedure Print_Config
     (Into : in out Sink; C : Configuration; Env : Environment; Buffer : Line_Buffer; Arguments : Positive;
      Command : String; Diff : Boolean; Ports : Port_List; Known : out Boolean)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Master_At     : constant Natural := Command_At (Buffer, Arguments, "master");
      Profile_At    : constant Natural := Command_At (Buffer, Arguments, "profile");
      Rates_At      : constant Natural := Command_At (Buffer, Arguments, "rates");
      Hardware_At   : constant Natural := Command_At (Buffer, Arguments, "hardware");
      All_At        : constant Natural := Command_At (Buffer, Arguments, "all");
      Options       : constant Positive :=
        (if Master_At > 0 then Master_At
         elsif Profile_At > 0 then Profile_At
         elsif Rates_At > 0 then Rates_At
         elsif Hardware_At > 0 then Hardware_At
         elsif All_At > 0 then All_At
         else Arguments);
      Show_Defaults : constant Boolean := Command_At (Buffer, Options, "defaults") > 0;
      Bare          : constant Boolean := not Show_Defaults and then Command_At (Buffer, Options, "bare") > 0;
   begin
      Known := False;
      if Profile_At > 0 or else Rates_At > 0 then
         Known := True;
         Dump_Profile
           (Into, C, (if Profile_At > 0 then PID else Rate),
            Natural (if Profile_At > 0 then C.System_Config.Pid_Profile_Index else C.System_Config.Active_Rate_Profile),
            Command, Diff, Show_Defaults, Ports);
      elsif Hardware_At = 0 and then All_At = 0 and then not Diff and then not Show_Defaults then
         Known := True;
         Dump_Master (Into, C, Env, Command, Bare, Ports);
      end if;
   end Print_Config;

   ------------------
   -- Process_Line --
   ------------------

   procedure Process_Line
     (Into : in out Sink; C : in out Configuration; Line : String; Ports : Port_List; Env : Environment;
      Known : out Boolean; Changes : out Effects)
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
              (Into, "beacon", C.Beeper_Config.Dshot_Beacon_Off_Flags, Beacon_Allowed, Text_At (Buffer, Arguments));
         when Beeper_Command_Word =>
            Known := True;
            Beeper_Command
              (Into, "beeper", C.Beeper_Config.Beeper_Off_Flags, Beeper_Allowed, Text_At (Buffer, Arguments));
         when Diff_Command =>
            Print_Config (Into, C, Env, Buffer, Arguments, "diff", True, Ports, Known);
         when Dump_Command =>
            Print_Config (Into, C, Env, Buffer, Arguments, "dump", False, Ports, Known);
         when Feature_Command_Word =>
            Known := True;
            Feature_Command (Into, C, Text_At (Buffer, Arguments));
         when Get_Command =>
            Known := True;
            Get (Into, C, "get", Text_At (Buffer, Arguments), Ports);
         when Color_Command_Word =>
            Known := True;
            Color_Command (Into, C.Led_Strip_Status_Mode_Config.Colors, Text_At (Buffer, Arguments));
         when Led_Command_Word =>
            Known := True;
            Led_Command (Into, C.Led_Strip_Status_Mode_Config.Led_Configs, Text_At (Buffer, Arguments), Changes);
         when Mode_Color_Command_Word =>
            Known := True;
            Mode_Color_Command (Into, C.Led_Strip_Status_Mode_Config, Text_At (Buffer, Arguments));
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
         when Servo_Command_Word =>
            Known := True;
            Servo_Command (Into, C.Servo_Params, Text_At (Buffer, Arguments));
         when Servo_Mix_Command_Word =>
            Known := True;
            Servo_Mix_Command (Into, C.Custom_Servo_Mixers, C.Servo_Params, Text_At (Buffer, Arguments));
         when Serial_Command_Word =>
            Known := True;
            Serial_Command (Into, C, Text_At (Buffer, Arguments), Ports);
         when Set_Command =>
            Known := True;
            Set (Into, C, Text_At (Buffer, Arguments), Ports);
         when Vtx_Command_Word =>
            Known := True;
            Vtx_Command
              (Into, C.Vtx_Config.Vtx_Channel_Activation_Conditions, C.Vtx_Table_Config, Text_At (Buffer, Arguments));
         when Vtx_Table_Command_Word =>
            Known := True;
            Vtx_Table_Command (Into, C.Vtx_Table_Config, Text_At (Buffer, Arguments));
         when Waypoint_Command_Word =>
            Known := True;
            Waypoint_Command (Into, C.Flight_Plan_Config, Env.Navigation, Text_At (Buffer, Arguments));
      end case;
   end Process_Line;

end Adaflight.Command_Line;
