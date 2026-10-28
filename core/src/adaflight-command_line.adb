with Interfaces; use Interfaces;
with Adaflight.Adjustments;
with Adaflight.CLI_Resources;
with Adaflight.Config_Codec;
with Adaflight.Config_Fix;
with Adaflight.Config_Reset;
with Adaflight.LED_Strip;
with Adaflight.Maths;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.MSP_Box;
with Adaflight.MSP_Common_Out;
with Adaflight.Servo_Rules;
with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.Simplified_Tuning.Stored;
with Adaflight.VTX_Table_Store;

package body Adaflight.Command_Line with SPARK_Mode is

   CRLF : constant String := (ASCII.CR, ASCII.LF);

   function Decimal (V : Integer_64) return String renames CLI_Text.Decimal;

   function Text_Of (T : Identity_Text) return String is (T.Data (1 .. T.Length));

   procedure Put (Into : in out Output; Text : String)
     with Global => null
   is
   begin
      Put (Into.Target, Text);
   end Put;

   --  An error's text after "###ERROR IN ", noted for an open batch.
   procedure Put_Error (Into : in out Output; Text : String)
     with Global => null
   is
   begin
      Put (Into, "###ERROR IN ");
      Put (Into, Text);
      if Into.Batch_Active then
         Into.Batch_Error := True;
      end if;
   end Put_Error;

   --  A heading after an empty line, after a number sign.
   procedure Put_Hash_Line (Into : in out Output; Heading : String) is
   begin
      Put (Into, CRLF & "# ");
      Put (Into, Heading);
      Put (Into, CRLF);
   end Put_Hash_Line;

   --  How a dump prints a section: every line, or for a diff only the lines
   --  off their defaults; with Show_Defaults a changed line's default comes
   --  first after a number sign.
   type Dump_Mode is record
      Diff          : Boolean := False;
      Show_Defaults : Boolean := False;
   end record;

   Listing : constant Dump_Mode := (Diff => False, Show_Defaults => False);

   function Shows_Default (Mode : Dump_Mode; Equal : Boolean) return Boolean is
     (Mode.Show_Defaults and then not Equal);

   function Shows_Line (Mode : Dump_Mode; Equal : Boolean) return Boolean is
     (not Mode.Diff or else not Equal);

   --  A pending heading: printed outside a diff, or in a diff before a
   --  changed line, then no longer pending.
   procedure Put_Heading
     (Into : in out Output; Mode : Dump_Mode; Changed : Boolean; Heading : String; Pending : in out Boolean)
   is
   begin
      if Pending and then (not Mode.Diff or else Changed) then
         Put_Hash_Line (Into, Heading);
         Pending := False;
      end if;
   end Put_Heading;

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
     (Into : in out Output; C : Configuration; S : Setting; Profile : Natural; Command : String; Full : Boolean;
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
                     Put (Into, " 0 ");
                     Put (Into, Decimal (I.Max));
                  end if;
               when I32 =>
                  Corrupted := V > I.Max or else V < -I.Max;
                  if Full and then not Corrupted then
                     Put (Into, " 0 ");
                     Put (Into, Decimal (I.Max));
                  end if;
               when U8 | I8 | U16 | I16 =>
                  Corrupted := V < I.Min or else V > I.Max;
                  if Full and then not Corrupted then
                     Put (Into, " ");
                     Put (Into, Decimal (I.Min));
                     Put (Into, " ");
                     Put (Into, Decimal (I.Max));
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
         Put_Error (Into, Command);
         Put (Into, ": CORRUPTED CONFIG: ");
         Put (Into, Name (S));
         Put (Into, " = ");
         Put (Into, Decimal (if I.Kind = U32 and then V > 2 ** 31 - 1 then V - 2 ** 32 else V));
         Put (Into, "###");
      end if;
   end Put_Value;

   --  The values a setting takes, on a line; nothing for a port.
   procedure Put_Range (Into : in out Output; S : Setting) is
      I     : constant Info := Describe (S);
      First : Boolean := True;
   begin
      case I.How is
         when Direct =>
            case I.Kind is
               when U32 =>
                  Put (Into, "Allowed range: 0 - ");
                  Put (Into, Decimal (I.Max));
                  Put (Into, CRLF);
               when I32 =>
                  Put (Into, "Allowed range: ");
                  Put (Into, Decimal (-I.Max));
                  Put (Into, " - ");
                  Put (Into, Decimal (I.Max));
                  Put (Into, CRLF);
               when U8 | I8 | U16 | I16 =>
                  Put (Into, "Allowed range: ");
                  Put (Into, Decimal (I.Min));
                  Put (Into, " - ");
                  Put (Into, Decimal (I.Max));
                  Put (Into, CRLF);
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
            Put (Into, "Array length: ");
            Put (Into, Decimal (Integer_64 (I.Count)));
            Put (Into, CRLF);
         when Text =>
            Put (Into, "String length: ");
            Put (Into, Decimal (Integer_64 (I.Min_Length)));
            Put (Into, " - ");
            Put (Into, Decimal (Integer_64 (I.Count)));
            Put (Into, CRLF);
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

   procedure Get (Into : in out Output; C : Configuration; Command : String; Fragment : String; Ports : Port_List)
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
                  Put (Into, "profile ");
                  Put (Into, Decimal (Integer_64 (P.PID)));
                  Put (Into, CRLF);
               when Rate_Profile =>
                  Put (Into, "rateprofile ");
                  Put (Into, Decimal (Integer_64 (P.Rate)));
                  Put (Into, CRLF);
               when Battery_Profile =>
                  Put (Into, "battery_profile ");
                  Put (Into, Decimal (Integer_64 (P.Battery)));
                  Put (Into, CRLF);
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
         Put_Error (Into, Command);
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

   procedure Set (Into : in out Output; C : in out Configuration; Arguments : String; Ports : Port_List) is
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
            Put_Error (Into, "set: INVALID NAME: ");
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
                        Put_Error (Into, "set: STRING MUST BE 1-");
                        Put (Into, Decimal (Integer_64 (I.Count)));
                        Put (Into, " CHARACTERS OR '-' FOR EMPTY###" & CRLF);
                     end if;
                  end;
            end case;
            if Changed then
               Put (Into, Name (Target));
               Put (Into, " set to ");
               Put_Value (Into, C, Target, Profile, "set", False, Ports);
            else
               Put_Error (Into, "set: INVALID VALUE###" & CRLF);
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
     (Into : in out Output; C : in out Configuration; Kind : Profile_Kind; Arguments : String;
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
            Put_Error (Into, Profile_Word (Kind));
            Put (Into, ": ");
            Put (Into, (case Kind is when PID => "PROFILE", when Rate => "RATE PROFILE",
                        when Battery => "BATTERY PROFILE"));
            Put (Into, " OUTSIDE OF [0..");
            Put (Into, Decimal (Integer_64 (Count - 1)));
            Put (Into, "]###" & CRLF);
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
      Put (Into, Profile_Word (Kind));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (case Kind is when PID => C.System_Config.Pid_Profile_Index,
                                      when Rate => C.System_Config.Active_Rate_Profile,
                                      when Battery => C.System_Config.Active_Battery_Profile)));
      Put (Into, CRLF);
   end Profile_Command;

   --  A scope's settings in the given profiles as set lines under a heading,
   --  the hardware settings with the master settings; for a diff only those
   --  off their default, under a heading printed with the first of them, each
   --  after its default for Show_Defaults.
   procedure Dump_Values
     (Into : in out Output; C : Configuration; Where : Value_Scope; P : Profiles; Heading : String; Command : String;
      Mode : Dump_Mode; Ports : Port_List)
     with Pre => Valid (P) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Pending : Boolean := True;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for S in Setting loop
         if Describe (S).Where = Where or else (Where = Master and then Describe (S).Where = Hardware) then
            declare
               Profile : constant Natural := Profile_Of (S, P);
               Equal   : constant Boolean := Equals_Default (C, S, Profile);
            begin
               Put_Heading (Into, Mode, not Equal, Heading, Pending);
               if Shows_Line (Mode, Equal) then
                  if Shows_Default (Mode, Equal) then
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
     (Into : in out Output; C : Configuration; Kind : Profile_Kind; Index : Natural; Command : String; Mode : Dump_Mode;
      Ports : Port_List)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
   begin
      if Index >= (if Kind = Battery then 3 else 4) then
         return;
      end if;
      Put (Into, CRLF);
      Put (Into, Profile_Word (Kind));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, CRLF);
      Dump_Values
        (Into, C,
         (case Kind is
             when PID => PID_Profile,
             when Rate => Rate_Profile,
             when Battery => Battery_Profile),
         (PID     => (if Kind = PID then Index else 0),
          Rate    => (if Kind = Rate then Index else 0),
          Battery => (if Kind = Battery then Index else 0)),
         Profile_Word (Kind) & " " & Decimal (Integer_64 (Index)), Command, Mode, Ports);
   end Dump_Profile;

   --  Whether a text starts a word, without regard to case.
   function Starts (Text, Word : String) return Boolean is
     (Text'Length <= Word'Length
      and then CLI_Text.Same_Ignoring_Case (Text, Word (Word'First .. Word'First + (Text'Length - 1))));

   subtype Feature_Bit is Natural range 0 .. 28;

   --  The feature names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Feature_Name_Pool_Length : constant := 215;
   Feature_Name_Text : constant String (1 .. Feature_Name_Pool_Length + 18) :=
     "RX_PPMRX_UDPINFLIGHT_ACC_CALRX_SERIALMOTOR_STOPSERVO_TILTSOFTSERIALGPSOPTICALFLOWRANGEFINDERTELEMETRY3DR"
     & "X_PARALLEL_PWMRX_MSPRSSI_ADCLED_STRIPDISPLAYOSDCHANNEL_FORWARDINGTRANSPONDERAIRMODERX_SPIESC_SENSORANTI_"
     & "GRAVITY                  ";
   type Feature_Name_Start is range 0 .. Feature_Name_Pool_Length;
   type Feature_Name_Length is range 0 .. 18;
   Feature_Name_Starts : constant array (Feature_Bit) of Feature_Name_Start :=
     (0 => 0, 1 => 6, 2 => 12, 3 => 28, 4 => 37, 5 => 47, 6 => 57, 7 => 67, 8 => 70, 9 => 81, 10 => 92, 12 => 101,
      13 => 103, 14 => 118, 15 => 124, 16 => 132, 17 => 141, 18 => 148, 20 => 151, 21 => 169, 22 => 180, 25 => 187,
      27 => 193, 28 => 203, 11 | 19 | 23 | 24 | 26 => 0);
   Feature_Name_Lengths : constant array (Feature_Bit) of Feature_Name_Length :=
     (0 => 6, 1 => 6, 2 => 16, 3 => 9, 4 => 10, 5 => 10, 6 => 10, 7 => 3, 8 => 11, 9 => 11, 10 => 9, 12 => 2,
      13 => 15, 14 => 6, 15 => 8, 16 => 9, 17 => 7, 18 => 3, 20 => 18, 21 => 11, 22 => 7, 25 => 6, 27 => 10,
      28 => 12, 11 | 19 | 23 | 24 | 26 => 0);

   function Feature_Name (Bit : Feature_Bit) return String is
     (Feature_Name_Text (Natural (Feature_Name_Starts (Bit)) + 1
                         .. Natural (Feature_Name_Starts (Bit)) + Natural (Feature_Name_Lengths (Bit))))
     with Post => Feature_Name'Result'Length <= 18;

   --  A header, then the names of a mask's features, each after a space but
   --  the first feature's.
   procedure Put_Features (Into : in out Output; Header : String; Mask : Unsigned_32) is
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
   --  the one whose name the text starts, enabled or, after a minus,
   --  disabled in the configuration. A text that starts two or more names
   --  is the multiple match error, which the reference's first-match loop
   --  can never print (finding F154).
   procedure Feature_Command (Into : in out Output; C : in out Configuration; Arguments : String)
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
         Found  : Natural := 0;
         Match  : Feature_Bit := Feature_Bit'First;
      begin
         for Bit in Feature_Bit loop
            pragma Loop_Invariant (Found <= Bit - Feature_Bit'First);
            if Feature_Name (Bit)'Length > 0 and then Starts (Text, Feature_Name (Bit)) then
               Found := Found + 1;
               Match := Bit;
            end if;
         end loop;
         if Found = 1 then
            declare
               Feature : constant Unsigned_32 := Shift_Left (1, Match);
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
               Put (Into, " ");
               Put (Into, Feature_Name (Match));
               Put (Into, CRLF);
            end;
         elsif Found > 1 then
            Put_Error (Into, "feature: Multiple features match ");
            Put (Into, Text);
            Put (Into, "###" & CRLF);
         else
            Put_Error (Into, "feature: INVALID NAME: ");
            Put (Into, Text);
            Put (Into, "###" & CRLF);
         end if;
      end;
   end Feature_Command;

   --  The features as commands: every feature disabled, then each enabled one
   --  enabled. A diff keeps a feature's disabled line when it was enabled by
   --  default and its enabled line when it was disabled; the default lines
   --  print for the opposite changes, and the heading precedes the first line
   --  printed either way (finding F172).
   procedure Put_Feature_Dump
     (Into : in out Output; Mask : Unsigned_32; Default : Unsigned_32 := Defaults.Feature_Config.Enabled_Features;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for Bit in Feature_Bit loop
         if Feature_Name (Bit)'Length > 0 then
            declare
               B     : constant Unsigned_32 := Shift_Left (1, Bit);
               Equal : constant Boolean := (((not Default) or Mask) and B) /= 0;
            begin
               Put_Heading (Into, Mode, ((Mask xor Default) and B) /= 0, Heading, Pending);
               if Shows_Default (Mode, ((Default or not Mask) and B) /= 0) then
                  Put (Into, "#feature -");
                  Put (Into, Feature_Name (Bit));
                  Put (Into, CRLF);
               end if;
               if Shows_Line (Mode, Equal) then
                  Put (Into, "feature -");
                  Put (Into, Feature_Name (Bit));
                  Put (Into, CRLF);
               end if;
            end;
         end if;
      end loop;
      for Bit in Feature_Bit loop
         if Feature_Name (Bit)'Length > 0 then
            declare
               B : constant Unsigned_32 := Shift_Left (1, Bit);
            begin
               Put_Heading (Into, Mode, ((Mask xor Default) and B) /= 0, Heading, Pending);
               if (Default and B) /= 0 and then Shows_Default (Mode, (((not Default) or Mask) and B) /= 0) then
                  Put (Into, "#feature ");
                  Put (Into, Feature_Name (Bit));
                  Put (Into, CRLF);
               end if;
               if (Mask and B) /= 0 then
                  Put_Heading (Into, Mode, ((Default or not Mask) and B) = 0, Heading, Pending);
                  if Shows_Line (Mode, ((Default or not Mask) and B) /= 0) then
                     Put (Into, "feature ");
                     Put (Into, Feature_Name (Bit));
                     Put (Into, CRLF);
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Put_Feature_Dump;

   subtype Beeper_Index is Natural range 0 .. 23;
   All_Beepers : constant Beeper_Index := 23;

   --  The beeper names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Beeper_Name_Pool_Length : constant := 268;
   Beeper_Name_Text : constant String (1 .. Beeper_Name_Pool_Length + 20) :=
     "GYRO_CALIBRATEDRX_LOSTRX_LOST_LANDINGDISARMINGARMING_GPS_FIXARMING_GPS_NO_FIXBAT_CRIT_LOWBAT_LOWGPS_STAT"
     & "USRX_SETACC_CALIBRATIONACC_CALIBRATION_FAILREADY_BEEPMULTI_BEEPSDISARM_REPEATARMEDSYSTEM_INITON_USBBLACK"
     & "BOX_ERASECRASHFLIPCAM_CONNECTION_OPENCAM_CONNECTION_CLOSEALL                    ";
   type Beeper_Name_Start is range 0 .. Beeper_Name_Pool_Length;
   type Beeper_Name_Length is range 3 .. 20;
   Beeper_Name_Starts : constant array (Beeper_Index) of Beeper_Name_Start :=
     (0 => 0, 1 => 15, 2 => 22, 3 => 37, 4 => 40, 5 => 46, 6 => 60, 7 => 77, 8 => 89, 9 => 96, 10 => 106, 11 => 112,
      12 => 127, 13 => 147, 14 => 157, 15 => 168, 16 => 181, 17 => 186, 18 => 197, 19 => 203, 20 => 217, 21 => 226,
      22 => 245, 23 => 265);
   Beeper_Name_Lengths : constant array (Beeper_Index) of Beeper_Name_Length :=
     (0 => 15, 1 => 7, 2 => 15, 3 => 9, 4 => 6, 5 => 14, 6 => 17, 7 => 12, 8 => 7, 9 => 10, 10 => 6, 11 => 15,
      12 => 20, 13 => 10, 14 => 11, 15 => 13, 16 => 5, 17 => 11, 18 => 6, 19 => 14, 20 => 9, 21 => 19, 22 => 20,
      23 => 3);

   function Beeper_Name (I : Beeper_Index) return String is
     (Beeper_Name_Text (Natural (Beeper_Name_Starts (I)) + 1
                        .. Natural (Beeper_Name_Starts (I)) + Natural (Beeper_Name_Lengths (I))))
     with Post => Beeper_Name'Result'Length in 1 .. 20;

   --  The flag of a beeper table entry's mode.
   function Beeper_Mask (I : Beeper_Index) return Unsigned_32 is
     (Shift_Left (1, (case I is
                         when 6 => 22,
                         when 7 .. 22 => I - 1,
                         when 23 => 23,
                         when 0 .. 5 => I)));

   --  The beeper mode of a beeper table entry.
   function Beeper_Mode (I : Beeper_Index) return Beeper.Sound is
     (case I is
         when 0 .. 5 => Beeper.Mode'Val (I + 1),
         when 6 => Beeper.Arming_GPS_No_Fix,
         when 7 .. 22 => Beeper.Mode'Val (I),
         when 23 => Beeper.All_Sounds);

   --  beeper and beacon: the disabled conditions, the available ones, or a
   --  condition, the first allowed one whose name the text starts, enabled
   --  or, after a minus, disabled; ALL sets every allowed one.
   procedure Beeper_Command
     (Into : in out Output; Command : String; Flags : in out Unsigned_32; Allowed : Unsigned_32; Arguments : String)
     with Pre => Arguments'Last < Positive'Last
   is
   begin
      if Arguments'Length = 0 then
         Put (Into, "Disabled:");
         for I in 0 .. All_Beepers - 1 loop
            if (Beeper_Mask (I) and Flags) /= 0 then
               Put (Into, "  ");
               Put (Into, Beeper_Name (I));
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
               Put (Into, " ");
               Put (Into, Beeper_Name (I));
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
               Put (Into, " ");
               Put (Into, Beeper_Name (I));
               Put (Into, CRLF);
               return;
            end if;
         end loop;
         Put_Error (Into, Command);
         Put (Into, ": INVALID NAME: ");
         Put (Into, Text);
         Put (Into, "###" & CRLF);
      end;
   end Beeper_Command;

   Beeper_Allowed : constant Unsigned_32 := 16#7F_FFFF#;
   Beacon_Allowed : constant Unsigned_32 := 16#202#;

   --  The beeper or beacon conditions as commands: each allowed one but ALL
   --  enabled or, after a minus, disabled. The heading precedes a changed
   --  condition's default line (finding F171).
   procedure Put_Beeper_Dump
     (Into : in out Output; Command : String; Flags : Unsigned_32; Default : Unsigned_32; Allowed : Unsigned_32;
      Mode : Dump_Mode; Heading : String)
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in 0 .. All_Beepers - 1 loop
         pragma Loop_Invariant (I in 0 .. All_Beepers - 1);
         if (Beeper_Mask (I) and Allowed) /= 0 then
            declare
               Off   : constant Boolean := (Flags and Beeper_Mask (I)) /= 0;
               Equal : constant Boolean := ((not (Flags xor Default)) and Beeper_Mask (I)) /= 0;
            begin
               Put_Heading (Into, Mode, not Equal, Heading, Pending);
               if Shows_Default (Mode, Equal) then
                  Put (Into, "#");
                  Put (Into, Command);
                  Put (Into, (if Off then " " else " -"));
                  Put (Into, Beeper_Name (I));
                  Put (Into, CRLF);
               end if;
               if Shows_Line (Mode, Equal) then
                  Put (Into, Command);
                  Put (Into, (if Off then " -" else " "));
                  Put (Into, Beeper_Name (I));
                  Put (Into, CRLF);
               end if;
            end;
         end if;
      end loop;
   end Put_Beeper_Dump;

   Condition_Count : constant := Mode_Activation_Condition_Record_List_20'Length;

   --  A box's permanent id by its box id; 0 for an id outside the box table.
   function Permanent_Of (Box_Id : Unsigned_8) return Unsigned_8 is
     (if Box_Id <= Modes.Box'Pos (Modes.Box'Last) then MSP_Box.Permanent_Id (Modes.Box'Val (Box_Id)) else 0);

   --  A mode condition as an aux line: index, mode's permanent id, aux channel,
   --  range ends as channel values, logic, and the linked mode's permanent id.
   procedure Put_Condition (Into : in out Output; Index : Natural; M : Mode_Activation_Condition_Record) is
   begin
      Put (Into, "aux ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Permanent_Of (M.Mode_Id))));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (M.Aux_Channel_Index)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (M.Range_Value.Start_Step)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (M.Range_Value.End_Step)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (M.Mode_Logic)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Permanent_Of (M.Linked_To))));
      Put (Into, CRLF);
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

   --  Every mode condition whose mode is in the box table, a changed one's
   --  default first for Show_Defaults when its mode is in the table.
   procedure Put_Conditions
     (Into : in out Output; Conditions : Mode_Activation_Condition_Record_List_20;
      Default : Mode_Activation_Condition_Record_List_20 := Defaults.Mode_Activation_Conditions;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Conditions'Range loop
         pragma Loop_Invariant (I in Conditions'Range);
         declare
            Equal : constant Boolean := Conditions (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) and then Default (I).Mode_Id <= Modes.Box'Pos (Modes.Box'Last) then
               Put (Into, "#");
               Put_Condition (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) and then Conditions (I).Mode_Id <= Modes.Box'Pos (Modes.Box'Last) then
               Put_Condition (Into, I, Conditions (I));
            end if;
         end;
      end loop;
   end Put_Conditions;

   --  aux: every mode condition, or one condition's mode, aux channel, range,
   --  logic and link from its arguments, the valid ones counted; four valid
   --  take the default logic and no link, five no link, and any other count
   --  clears the condition. A negative index gets the index range error.
   procedure Aux_Command (Into : in out Output; C : in out Configuration; Arguments : String; Changes : in out Effects)
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
         Put_Error (Into, "aux: INDEX NOT BETWEEN 0 AND ");
         Put (Into, Decimal (Condition_Count - 1));
         Put (Into, "###" & CRLF);
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
   procedure Put_Adjustment_Range (Into : in out Output; Index : Natural; A : Adjustment_Range_Record)
     with Pre => Index <= 29
   is
   begin
      Put (Into, "adjrange ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " 0 ");
      Put (Into, Decimal (Integer_64 (A.Aux_Channel_Index)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (A.Range_Value.Start_Step)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (A.Range_Value.End_Step)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (A.Adjustment_Config)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (A.Aux_Switch_Channel_Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (A.Adjustment_Center)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (A.Adjustment_Scale)));
      Put (Into, CRLF);
   end Put_Adjustment_Range;

   --  Every adjustment range's line, a changed one's default first for
   --  Show_Defaults.
   procedure Put_Adjustment_Ranges
     (Into : in out Output; Ranges : Adjustment_Range_Record_List_30;
      Default : Adjustment_Range_Record_List_30 := Defaults.Adjustment_Ranges; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Ranges'Range loop
         pragma Loop_Invariant (I in Ranges'Range);
         declare
            Equal : constant Boolean := Ranges (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Adjustment_Range (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Adjustment_Range (Into, I, Ranges (I));
            end if;
         end;
      end loop;
   end Put_Adjustment_Ranges;

   --  adjrange: every adjustment range, or one range's aux channel, range ends,
   --  function and switch channel from the arguments after a slot argument,
   --  each valid one counted, then its optional center and scale. Any other
   --  count than six clears the range. A negative index gets the index range
   --  error.
   procedure Adjustment_Range_Command
     (Into : in out Output; C : in out Configuration; Arguments : String; Changes : in out Effects)
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
         Put_Error (Into, "adjrange: INDEX NOT BETWEEN 0 AND ");
         Put (Into, Decimal (Range_Count - 1));
         Put (Into, "###" & CRLF);
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
            Put_Error (Into, "adjrange: INVALID ARGUMENT COUNT###" & CRLF);
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
   procedure Serial_Command (Into : in out Output; C : in out Configuration; Arguments : String; Ports : Port_List)
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
         Put_Error (Into, "serial: PARSING FAILED###" & CRLF);
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
         Put_Error (Into, "serial: INVALID ARGUMENT COUNT###" & CRLF);
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
            Put_Error (Into, "serial: PARSING FAILED###" & CRLF);
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

   --  The mixer names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Mixer_Name_Pool_Length : constant := 197;
   Mixer_Name_Text : constant String (1 .. Mixer_Name_Pool_Length + 14) :=
     "TRIQUADPQUADXBIGIMBALY6HEX6FLYING_WINGY4HEX6XOCTOX8OCTOFLATPOCTOFLATXAIRPLANEHELI_120_CCPMHELI_90_DEGVTA"
     & "IL4HEX6HPPM_TO_SERVODUALCOPTERSINGLECOPTERATAIL4CUSTOMCUSTOMAIRPLANECUSTOMTRIQUADX1234OCTOX8P           "
     & "   ";
   type Mixer_Name_Start is range 0 .. Mixer_Name_Pool_Length;
   type Mixer_Name_Length is range 2 .. 14;
   Mixer_Name_Starts : constant array (Mixer_Init.Mixer_Mode) of Mixer_Name_Start :=
     (Mixer_Init.Tri => 0, Mixer_Init.Quad_P => 3, Mixer_Init.Quad_X => 8, Mixer_Init.Bicopter => 13,
      Mixer_Init.Gimbal => 15, Mixer_Init.Y6 => 21, Mixer_Init.Hex6 => 23, Mixer_Init.Flying_Wing => 27,
      Mixer_Init.Y4 => 38, Mixer_Init.Hex6X => 40, Mixer_Init.Octo_X8 => 45, Mixer_Init.Octo_Flat_P => 51,
      Mixer_Init.Octo_Flat_X => 60, Mixer_Init.Airplane => 69, Mixer_Init.Heli_120_CCPM => 77,
      Mixer_Init.Heli_90_Deg => 90, Mixer_Init.Vtail4 => 101, Mixer_Init.Hex6H => 107,
      Mixer_Init.PPM_To_Servo => 112, Mixer_Init.Dualcopter => 124, Mixer_Init.Singlecopter => 134,
      Mixer_Init.Atail4 => 146, Mixer_Init.Custom => 152, Mixer_Init.Custom_Airplane => 158,
      Mixer_Init.Custom_Tri => 172, Mixer_Init.Quad_X_1234 => 181, Mixer_Init.Octo_X8P => 190);
   Mixer_Name_Lengths : constant array (Mixer_Init.Mixer_Mode) of Mixer_Name_Length :=
     (Mixer_Init.Tri => 3, Mixer_Init.Quad_P => 5, Mixer_Init.Quad_X => 5, Mixer_Init.Bicopter => 2,
      Mixer_Init.Gimbal => 6, Mixer_Init.Y6 => 2, Mixer_Init.Hex6 => 4, Mixer_Init.Flying_Wing => 11,
      Mixer_Init.Y4 => 2, Mixer_Init.Hex6X => 5, Mixer_Init.Octo_X8 => 6, Mixer_Init.Octo_Flat_P => 9,
      Mixer_Init.Octo_Flat_X => 9, Mixer_Init.Airplane => 8, Mixer_Init.Heli_120_CCPM => 13,
      Mixer_Init.Heli_90_Deg => 11, Mixer_Init.Vtail4 => 6, Mixer_Init.Hex6H => 5, Mixer_Init.PPM_To_Servo => 12,
      Mixer_Init.Dualcopter => 10, Mixer_Init.Singlecopter => 12, Mixer_Init.Atail4 => 6, Mixer_Init.Custom => 6,
      Mixer_Init.Custom_Airplane => 14, Mixer_Init.Custom_Tri => 9, Mixer_Init.Quad_X_1234 => 9,
      Mixer_Init.Octo_X8P => 7);

   function Mixer_Name (M : Mixer_Init.Mixer_Mode) return String is
     (Mixer_Name_Text (Natural (Mixer_Name_Starts (M)) + 1
                       .. Natural (Mixer_Name_Starts (M)) + Natural (Mixer_Name_Lengths (M))))
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
   procedure Mixer_Command (Into : in out Output; Mode : in out Unsigned_8; Arguments : String) is
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
            Put_Error (Into, "mixer: INVALID NAME: ");
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

   --  One motor's mix line.
   procedure Put_Motor (Into : in out Output; Index : Natural; M : Motor_Mixer_Record) is
   begin
      Put (Into, "mmix ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, CLI_Text.Float_Text (M.Throttle));
      Put (Into, " ");
      Put (Into, CLI_Text.Float_Text (M.Roll));
      Put (Into, " ");
      Put (Into, CLI_Text.Float_Text (M.Pitch));
      Put (Into, " ");
      Put (Into, CLI_Text.Float_Text (M.Yaw));
      Put (Into, CRLF);
   end Put_Motor;

   --  The custom motor mix up to its first motor without throttle, every
   --  motor's line in a diff too, a changed one's default first for
   --  Show_Defaults; a changed motor prints the heading.
   procedure Put_Motor_Mix
     (Into : in out Output; Mix : Motor_Mixer_Record_List_8;
      Default : Motor_Mixer_Record_List_8 := Defaults.Custom_Motor_Mixer; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      for I in Mix'Range loop
         pragma Loop_Invariant (I in Mix'Range);
         exit when Mix (I).Throttle = 0.0;
         declare
            Equal : constant Boolean := Mix (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Motor (Into, I, Default (I));
            end if;
            Put_Motor (Into, I, Mix (I));
         end;
      end loop;
   end Put_Motor_Mix;

   --  mmix: the custom motor mix, every motor's throttle cleared, a mode's
   --  table loaded by the first name the text starts, or one motor's
   --  throttle, roll, pitch and yaw, each argument read as a float and kept
   --  even when fewer than four are given.
   procedure Motor_Mix_Command (Into : in out Output; Mix : in out Motor_Mixer_Record_List_8; Arguments : String)
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
               Put_Error (Into, "mmix: INVALID NAME: ");
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
               Put_Error (Into, "mmix: INDEX NOT BETWEEN 0 AND 7###" & CRLF);
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
               Put_Error (Into, "mmix: INVALID ARGUMENT COUNT###" & CRLF);
            else
               Put_Motor_Mix (Into, Mix);
            end if;
         end;
      end if;
   end Motor_Mix_Command;

   Input_Source_Count : constant := 14;

   --  One servo's parameter line.
   procedure Put_Servo (Into : in out Output; Index : Natural; P : Servo_Param_Record) is
   begin
      Put (Into, "servo ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (P.Min)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (P.Max)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (P.Middle)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (P.Rate)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (P.Forward_From_Channel)));
      Put (Into, CRLF);
   end Put_Servo;

   --  Each servo's line, then a reverse line for each input source it
   --  reverses. A changed servo's default line, and a reverse line the
   --  defaults have and the servo no longer has, come first for
   --  Show_Defaults; only a changed servo prints the heading.
   procedure Put_Servos
     (Into : in out Output; Params : Servo_Param_Record_List_8;
      Default : Servo_Param_Record_List_8 := Defaults.Servo_Params; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         declare
            Equal : constant Boolean := Params (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Servo (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Servo (Into, I, Params (I));
            end if;
         end;
      end loop;
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         for Input in 0 .. Input_Source_Count - 1 loop
            pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
            declare
               Bit   : constant Unsigned_32 := Shift_Left (1, Input);
               Equal : constant Boolean :=
                 ((not (Params (I).Reversed_Sources xor Default (I).Reversed_Sources)) and Bit) /= 0;
               Line  : constant String :=
                 "smix reverse " & Decimal (Integer_64 (I)) & " " & Decimal (Integer_64 (Input)) & " r" & CRLF;
            begin
               if (Default (I).Reversed_Sources and Bit) /= 0 and then Shows_Default (Mode, Equal) then
                  Put (Into, "#");
                  Put (Into, Line);
               end if;
               if (Params (I).Reversed_Sources and Bit) /= 0 and then Shows_Line (Mode, Equal) then
                  Put (Into, Line);
               end if;
            end;
         end loop;
      end loop;
   end Put_Servos;

   --  servo: every servo's parameters, or one servo's minimum, maximum,
   --  middle, rate and forwarded channel from six numbers, each wrapped to
   --  16 bits; anything but numbers and spaces is the parse error.
   procedure Servo_Command (Into : in out Output; Params : in out Servo_Param_Record_List_8; Arguments : String)
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
               Put_Error (Into, "servo: INVALID ARGUMENT COUNT###" & CRLF);
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
            Put_Error (Into, "servo: PARSING FAILED###" & CRLF);
            return;
         end if;
      end loop;
      if Count /= 6 or else Values (0) not in 0 .. 7 then
         Put_Error (Into, "servo: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      if Values (1) not in 500 .. 2500 or else Values (2) not in 500 .. 2500 or else Values (3) < Values (1)
        or else Values (3) > Values (2) or else Values (1) > Values (2) or else Values (4) not in -100 .. 100
        or else Values (5) >= 18
      then
         Put_Error (Into, "servo: ARGUMENT OUT OF RANGE###" & CRLF);
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
         Put (Into, "servo ");
         Put (Into, Decimal (Integer_64 (Index)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (S.Min)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (S.Max)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (S.Middle)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (S.Rate)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (S.Forward_From_Channel)));
         Put (Into, CRLF);
      end;
   end Servo_Command;

   --  One servo rule's line.
   procedure Put_Rule (Into : in out Output; Index : Natural; R : Servo_Mixer_Record) is
   begin
      Put (Into, "smix ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Target_Channel)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Input_Source)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Rate)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Speed)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Min)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Max)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Box)));
      Put (Into, CRLF);
   end Put_Rule;

   --  The servo rules up to the first without a rate, a changed one's default
   --  first for Show_Defaults.
   procedure Put_Servo_Rules
     (Into : in out Output; Rules : Servo_Mixer_Record_List_16;
      Default : Servo_Mixer_Record_List_16 := Defaults.Custom_Servo_Mixers; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Rules'Range loop
         pragma Loop_Invariant (I in Rules'Range);
         exit when Rules (I).Rate = 0;
         declare
            Equal : constant Boolean := Rules (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Rule (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Rule (Into, I, Rules (I));
            end if;
         end;
      end loop;
   end Put_Servo_Rules;

   --  Each servo's reversed input sources as a table.
   procedure Put_Reversed (Into : in out Output; Params : Servo_Param_Record_List_8) is
   begin
      Put (Into, "s");
      for Input in 0 .. Input_Source_Count - 1 loop
         pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
         Put (Into, ASCII.HT & "i");
         Put (Into, Decimal (Integer_64 (Input)));
      end loop;
      Put (Into, CRLF);
      for I in Params'Range loop
         pragma Loop_Invariant (I in Params'Range);
         Put (Into, Decimal (Integer_64 (I)));
         for Input in 0 .. Input_Source_Count - 1 loop
            pragma Loop_Invariant (Input in 0 .. Input_Source_Count - 1);
            Put (Into, "" & ASCII.HT);
            Put (Into, "" & (if (Params (I).Reversed_Sources and Shift_Left (1, Input)) /= 0 then 'r' else 'n'));
            Put (Into, "  ");
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
     (Into : in out Output; Rules : in out Servo_Mixer_Record_List_16; Params : in out Servo_Param_Record_List_8;
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
               Put_Error (Into, "smix: INVALID NAME: ");
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
                  Put_Error (Into, "smix: INVALID ARGUMENT COUNT###" & CRLF);
                  return;
               end if;
               if Servo not in 0 .. 7 or else Input not in 0 .. Input_Source_Count - 1
                 or else Arguments (First) not in 'r' | 'n'
               then
                  Put_Error (Into, "smix: servo NOT BETWEEN 0 AND 8###" & CRLF);
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
               Put_Error (Into, "smix: INVALID ARGUMENT COUNT###" & CRLF);
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
               Put_Error (Into, "smix: ARGUMENT OUT OF RANGE###" & CRLF);
            end if;
         end;
      end if;
   end Servo_Mix_Command;

   --  A LED's configuration as text: position, direction letters, function
   --  letter with overlay letters, and color. A function past the function
   --  letters has no letter.
   procedure Put_Led_Text (Into : in out Output; Config : Unsigned_32) is
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
      Put (Into, ":");
      Put (Into, Dir_Text (1 .. Dir_Last));
      Put (Into, ":");
      Put (Into, Fn_Text (1 .. Fn_Last));
      Put (Into, ":");
      Put (Into, Decimal (Integer_64 (Shift_Right (Config, 22) and 16#F#)));
   end Put_Led_Text;

   --  Every LED's configuration line, a changed one's default first for
   --  Show_Defaults.
   procedure Put_Leds
     (Into : in out Output; Configs : Unsigned_32_List_32;
      Default : Unsigned_32_List_32 := Defaults.Led_Strip_Status_Mode_Config.Led_Configs; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Configs'Range loop
         pragma Loop_Invariant (I in Configs'Range);
         Put_Heading (Into, Mode, Configs (I) /= Default (I), Heading, Pending);
         if Shows_Default (Mode, Configs (I) = Default (I)) then
            Put (Into, "#led ");
            Put (Into, Decimal (Integer_64 (I)));
            Put (Into, " ");
            Put_Led_Text (Into, Default (I));
            Put (Into, CRLF);
         end if;
         if Shows_Line (Mode, Configs (I) = Default (I)) then
            Put (Into, "led ");
            Put (Into, Decimal (Integer_64 (I)));
            Put (Into, " ");
            Put_Led_Text (Into, Configs (I));
            Put (Into, CRLF);
         end if;
      end loop;
   end Put_Leds;

   --  led: every LED's configuration, or one LED's configuration cleared and
   --  then read from its text; a reading LED asks for the strip's layout.
   procedure Led_Command
     (Into : in out Output; Configs : in out Unsigned_32_List_32; Arguments : String; Changes : in out Effects)
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
         Put_Error (Into, "led: INDEX NOT BETWEEN 0 AND 31###" & CRLF);
         return;
      end if;
      P := Next_Argument (Arguments, Arguments'First);
      if P = 0 then
         Put_Error (Into, "led: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      Configs (Natural (Index)) := 0;
      if Arguments'Last - P + 1 > LED_Strip.Max_Text then
         Put_Error (Into, "led: PARSING FAILED###" & CRLF);
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
            Put_Error (Into, "led: PARSING FAILED###" & CRLF);
            return;
         end if;
         Configs (Natural (Index)) := Config;
         Changes.LEDs := True;
         Put (Into, "led ");
         Put (Into, Decimal (Integer_64 (Index)));
         Put (Into, " ");
         Put_Led_Text (Into, Config);
         Put (Into, CRLF);
      end;
   end Led_Command;

   --  One color's line.
   procedure Put_Color (Into : in out Output; Index : Natural; Color : Hsv_Color_Record) is
   begin
      Put (Into, "color ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Color.H)));
      Put (Into, ",");
      Put (Into, Decimal (Integer_64 (Color.S)));
      Put (Into, ",");
      Put (Into, Decimal (Integer_64 (Color.V)));
      Put (Into, CRLF);
   end Put_Color;

   --  Every color's line, a changed one's default first for Show_Defaults.
   procedure Put_Colors
     (Into : in out Output; Colors : Hsv_Color_Record_List_16;
      Default : Hsv_Color_Record_List_16 := Defaults.Led_Strip_Status_Mode_Config.Colors; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Colors'Range loop
         pragma Loop_Invariant (I in Colors'Range);
         declare
            Equal : constant Boolean := Colors (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Color (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Color (Into, I, Colors (I));
            end if;
         end;
      end loop;
   end Put_Colors;

   --  color: every color, or one color's hue, saturation and value read in
   --  turn, each stored as it is read and the color cleared when one is past
   --  its limit or a comma is missing.
   procedure Color_Command (Into : in out Output; Colors : in out Hsv_Color_Record_List_16; Arguments : String)
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
         Put_Error (Into, "color: INDEX NOT BETWEEN 0 AND 15###" & CRLF);
         return;
      end if;
      P := Next_Argument (Arguments, Arguments'First);
      if P = 0 then
         Put_Error (Into, "color: INVALID ARGUMENT COUNT###" & CRLF);
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
            Put_Error (Into, "color: PARSING FAILED###" & CRLF);
            return;
         end if;
         Put (Into, "color ");
         Put (Into, Decimal (Integer_64 (Slot)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (Colors (Slot).H)));
         Put (Into, ",");
         Put (Into, Decimal (Integer_64 (Colors (Slot).S)));
         Put (Into, ",");
         Put (Into, Decimal (Integer_64 (Colors (Slot).V)));
         Put (Into, CRLF);
      end;
   end Color_Command;

   --  One mode color's line, its default first for Show_Defaults when they
   --  differ; a difference prints the heading.
   procedure Put_Mode_Color
     (Into : in out Output; Mode : Dump_Mode; M, D : Natural; Color, Default : Unsigned_8; Heading : String;
      Pending : in out Boolean)
   is
      Text : constant String := "mode_color " & Decimal (Integer_64 (M)) & " " & Decimal (Integer_64 (D)) & " ";
   begin
      Put_Heading (Into, Mode, Color /= Default, Heading, Pending);
      if Shows_Default (Mode, Color = Default) then
         Put (Into, "#");
         Put (Into, Text);
         Put (Into, Decimal (Integer_64 (Default)));
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, Color = Default) then
         Put (Into, Text);
         Put (Into, Decimal (Integer_64 (Color)));
         Put (Into, CRLF);
      end if;
   end Put_Mode_Color;

   --  Every mode's direction colors, the special colors and the aux channel.
   procedure Put_Mode_Colors
     (Into : in out Output; L : Led_Strip_Status_Mode_Config_Record;
      Default : Led_Strip_Status_Mode_Config_Record := Defaults.Led_Strip_Status_Mode_Config;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for M in L.Mode_Colors'Range loop
         pragma Loop_Invariant (M in L.Mode_Colors'Range);
         for D in L.Mode_Colors (M).Color'Range loop
            pragma Loop_Invariant (D in L.Mode_Colors (M).Color'Range);
            Put_Mode_Color
              (Into, Mode, M, D, L.Mode_Colors (M).Color (D), Default.Mode_Colors (M).Color (D), Heading, Pending);
         end loop;
      end loop;
      for D in L.Special_Colors.Color'Range loop
         pragma Loop_Invariant (D in L.Special_Colors.Color'Range);
         Put_Mode_Color
           (Into, Mode, 6, D, L.Special_Colors.Color (D), Default.Special_Colors.Color (D), Heading, Pending);
      end loop;
      if Pending and then Shows_Line (Mode, L.Ledstrip_Aux_Channel = Default.Ledstrip_Aux_Channel) then
         Put_Hash_Line (Into, Heading);
      end if;
      if Shows_Default (Mode, L.Ledstrip_Aux_Channel = Default.Ledstrip_Aux_Channel) then
         Put (Into, "#mode_color 7 0 ");
         Put (Into, Decimal (Integer_64 (Default.Ledstrip_Aux_Channel)));
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, L.Ledstrip_Aux_Channel = Default.Ledstrip_Aux_Channel) then
         Put (Into, "mode_color 7 0 ");
         Put (Into, Decimal (Integer_64 (L.Ledstrip_Aux_Channel)));
         Put (Into, CRLF);
      end if;
   end Put_Mode_Colors;

   --  mode_color: every mode's direction colors, the special colors and the
   --  strip's aux channel, or one of them set from three numbers.
   procedure Mode_Color_Command
     (Into : in out Output; L : in out Led_Strip_Status_Mode_Config_Record; Arguments : String)
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
         Put_Error (Into, "mode_color: INVALID ARGUMENT COUNT###" & CRLF);
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
         Put_Error (Into, "mode_color: PARSING FAILED###" & CRLF);
         return;
      end if;
      Put (Into, "mode_color ");
      Put (Into, Decimal (Integer_64 (Values (0))));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Values (1))));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (Values (2))));
      Put (Into, CRLF);
   end Mode_Color_Command;

   --  One VTX channel condition's line.
   procedure Put_Vtx_Condition (Into : in out Output; Index : Natural; V : Vtx_Channel_Activation_Condition_Record)
     with Pre => Index <= 9
   is
   begin
      Put (Into, "vtx ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (V.Aux_Channel_Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (V.Band)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (V.Channel)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (V.Power)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (V.Range_Value.Start_Step)));
      Put (Into, " ");
      Put (Into, Decimal (900 + 25 * Integer_64 (V.Range_Value.End_Step)));
      Put (Into, CRLF);
   end Put_Vtx_Condition;

   --  Every VTX channel condition's line, a changed one's default first for
   --  Show_Defaults.
   procedure Put_Vtx_Conditions
     (Into : in out Output; Conditions : Vtx_Channel_Activation_Condition_Record_List_10;
      Default : Vtx_Channel_Activation_Condition_Record_List_10 :=
        Defaults.Vtx_Config.Vtx_Channel_Activation_Conditions;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Conditions'Range loop
         pragma Loop_Invariant (I in Conditions'Range);
         declare
            Equal : constant Boolean := Conditions (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Vtx_Condition (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Vtx_Condition (Into, I, Conditions (I));
            end if;
         end;
      end loop;
   end Put_Vtx_Conditions;

   --  vtx: every VTX channel condition, or one condition's aux channel, band,
   --  channel, power and range ends from its arguments, each valid one
   --  counted against the VTX table's counts; any other count than six
   --  clears the condition. A negative index gets the index range error.
   procedure Vtx_Command
     (Into : in out Output; Conditions : in out Vtx_Channel_Activation_Condition_Record_List_10;
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
         Put_Error (Into, "vtx: INDEX NOT BETWEEN 0 AND 9###" & CRLF);
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
            Put_Error (Into, "vtx: INVALID ARGUMENT COUNT###" & CRLF);
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

   --  A band's line: its number, name, letter, factory flag and the
   --  frequencies of a channel count.
   procedure Put_Band (Into : in out Output; T : Vtx_Table_Config_Record; Band : Natural; Channels : Unsigned_8)
     with Pre => Band < Table_Bands
   is
   begin
      Put (Into, "vtxtable band ");
      Put (Into, Decimal (Integer_64 (Band + 1)));
      Put (Into, " ");
      Put (Into, Stored_Text (T.Band_Names (Band)));
      Put (Into, " ");
      Put (Into, "" & Character'Val (T.Band_Letters (Band)));
      Put (Into, (if T.Is_Factory_Band (Band) then " FACTORY" else " CUSTOM "));
      for C in 0 .. Natural'Min (Natural (Channels), Table_Channels) - 1 loop
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
   end Put_Band;

   --  The power values of a level count.
   procedure Put_Power_Values (Into : in out Output; T : Vtx_Table_Config_Record; Levels : Natural) is
   begin
      Put (Into, "vtxtable powervalues");
      for L in 0 .. Natural'Min (Levels, Table_Powers) - 1 loop
         pragma Loop_Invariant (L < Table_Powers);
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (T.Power_Values (L))));
      end loop;
      Put (Into, CRLF);
   end Put_Power_Values;

   --  The power labels of a level count, each up to its first space.
   procedure Put_Power_Labels (Into : in out Output; T : Vtx_Table_Config_Record; Levels : Natural) is
   begin
      Put (Into, "vtxtable powerlabels");
      for L in 0 .. Natural'Min (Levels, Table_Powers) - 1 loop
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
   end Put_Power_Labels;

   --  The table's bands, channels, each band's line, power levels, power
   --  values and power labels, a changed part's default first for
   --  Show_Defaults. A band compares its name without regard to case, its
   --  letter, its factory flag and its frequencies, and its default line has
   --  the default channel count. The power values and labels compare all
   --  eight entries and print the default level count.
   procedure Put_Vtx_Table
     (Into : in out Output; T : Vtx_Table_Config_Record; Default : Vtx_Table_Config_Record := Defaults.Vtx_Table_Config;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      Put_Heading (Into, Mode, T.Bands /= Default.Bands, Heading, Pending);
      if Shows_Default (Mode, T.Bands = Default.Bands) then
         Put (Into, "#vtxtable bands ");
         Put (Into, Decimal (Integer_64 (Default.Bands)));
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, T.Bands = Default.Bands) then
         Put (Into, "vtxtable bands ");
         Put (Into, Decimal (Integer_64 (T.Bands)));
         Put (Into, CRLF);
      end if;
      Put_Heading (Into, Mode, T.Channels /= Default.Channels, Heading, Pending);
      if Shows_Default (Mode, T.Channels = Default.Channels) then
         Put (Into, "#vtxtable channels ");
         Put (Into, Decimal (Integer_64 (Default.Channels)));
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, T.Channels = Default.Channels) then
         Put (Into, "vtxtable channels ");
         Put (Into, Decimal (Integer_64 (T.Channels)));
         Put (Into, CRLF);
      end if;
      for Band in 0 .. Natural'Min (Natural (T.Bands), Table_Bands) - 1 loop
         pragma Loop_Invariant (Band < Table_Bands);
         declare
            Equal : constant Boolean :=
              CLI_Text.Same_Ignoring_Case (Stored_Text (T.Band_Names (Band)), Stored_Text (Default.Band_Names (Band)))
              and then T.Band_Letters (Band) = Default.Band_Letters (Band)
              and then T.Is_Factory_Band (Band) = Default.Is_Factory_Band (Band)
              and then T.Frequency (Band) = Default.Frequency (Band);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Band (Into, Default, Band, Default.Channels);
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Band (Into, T, Band, T.Channels);
            end if;
         end;
      end loop;
      Put_Heading (Into, Mode, T.Power_Levels /= Default.Power_Levels, Heading, Pending);
      if Shows_Default (Mode, T.Power_Levels = Default.Power_Levels) then
         Put (Into, "#vtxtable powerlevels ");
         Put (Into, Decimal (Integer_64 (Default.Power_Levels)));
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, T.Power_Levels = Default.Power_Levels) then
         Put (Into, "vtxtable powerlevels ");
         Put (Into, Decimal (Integer_64 (T.Power_Levels)));
         Put (Into, CRLF);
      end if;
      Put_Heading (Into, Mode, T.Power_Values /= Default.Power_Values, Heading, Pending);
      if Shows_Default (Mode, T.Power_Values = Default.Power_Values) then
         Put (Into, "#");
         Put_Power_Values (Into, Default, Natural (Default.Power_Levels));
      end if;
      if Shows_Line (Mode, T.Power_Values = Default.Power_Values) then
         Put_Power_Values (Into, T, Natural (T.Power_Levels));
      end if;
      declare
         Equal : Boolean := True;
      begin
         for L in 0 .. Table_Powers - 1 loop
            if not CLI_Text.Same_Ignoring_Case
              (Stored_Text (T.Power_Labels (L)), Stored_Text (Default.Power_Labels (L)))
            then
               Equal := False;
            end if;
         end loop;
         if Pending and then Shows_Line (Mode, Equal) then
            Put_Hash_Line (Into, Heading);
         end if;
         if Shows_Default (Mode, Equal) then
            Put (Into, "#");
            Put_Power_Labels (Into, Default, Natural (Default.Power_Levels));
         end if;
         if Shows_Line (Mode, Equal) then
            Put_Power_Labels (Into, T, Natural (T.Power_Levels));
         end if;
      end;
   end Put_Vtx_Table;

   --  vtxtable: the table, or one of its parts set: the band count, the
   --  channel count, the power level count, the power values, the power
   --  labels, or one band's name, letter, factory flag and frequencies.
   procedure Vtx_Table_Command (Into : in out Output; T : in out Vtx_Table_Config_Record; Arguments : String)
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
               Put_Error (Into, "vtxtable: INVALID ARGUMENT COUNT###" & CRLF);
            elsif Value not in 0 .. Table_Bands then
               Put_Error (Into, "vtxtable: BAND COUNT NOT BETWEEN 0 AND 8###" & CRLF);
            else
               for Band in Natural (Value) .. Natural'Min (Natural (T.Bands), Table_Bands) - 1 loop
                  VTX_Table_Store.Clear_Band (T, Band);
               end loop;
               T.Bands := Unsigned_8 (Value);
            end if;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "channels") then
            Read_Number (From, Found, Value);
            if not Found then
               Put_Error (Into, "vtxtable: INVALID ARGUMENT COUNT###" & CRLF);
            elsif Value not in 0 .. Table_Channels then
               Put_Error (Into, "vtxtable: CHANNEL COUNT NOT BETWEEN 0 AND 8###" & CRLF);
            else
               if Unsigned_8 (Value) < T.Channels then
                  for Band in 0 .. Table_Bands - 1 loop
                     VTX_Table_Store.Clear_Channels (T, Band, Natural (Value));
                  end loop;
               end if;
               T.Channels := Unsigned_8 (Value);
            end if;
         elsif CLI_Text.Same_Ignoring_Case (Sub, "powerlevels") then
            Read_Number (From, Found, Value);
            if Found then
               if Value not in 0 .. Table_Powers then
                  Put_Error (Into, "vtxtable: POWER LEVEL COUNT NOT BETWEEN 0 AND 8###" & CRLF);
               else
                  if Unsigned_8 (Value) < T.Power_Levels then
                     VTX_Table_Store.Clear_Power_Values (T, Natural (Value));
                     VTX_Table_Store.Clear_Power_Labels (T, Natural (Value));
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
                  Put_Error (Into, "vtxtable: NOT ENOUGH VALUES (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Power_Levels)));
                  Put (Into, ")###" & CRLF);
               elsif Has_Word (From) then
                  Put_Error (Into, "vtxtable: TOO MANY VALUES (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Power_Levels)));
                  Put (Into, ")###" & CRLF);
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
                  Put_Error (Into, "vtxtable: NOT ENOUGH LABELS (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Power_Levels)));
                  Put (Into, ")###" & CRLF);
               elsif Has_Word (From) then
                  Put_Error (Into, "vtxtable: TOO MANY LABELS (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Power_Levels)));
                  Put (Into, ")###" & CRLF);
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
                  Put_Error (Into, "vtxtable: BAND NUMBER NOT BETWEEN 1 AND ");
                  Put (Into, Decimal (Integer_64 (T.Bands)));
                  Put (Into, "###" & CRLF);
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
                        Put_Error (Into, "vtxtable: INVALID FACTORY FLAG ");
                        Put (Into, Arguments (First .. Last));
                        Put (Into, " (EXPECTED FACTORY OR CUSTOM)###" & CRLF);
                        return;
                     end if;
                  else
                     Value := CLI_Text.To_Integer (Arguments (First .. Last));
                     if Value < 0 then
                        Put_Error (Into, "vtxtable: INVALID FREQUENCY ");
                        Put (Into, Arguments (First .. Last));
                        Put (Into, "###" & CRLF);
                        return;
                     end if;
                     Freqs (Channel) := Unsigned_16'Mod (Value);
                     Channel := Channel + 1;
                  end if;
               end loop;
               if Channel < Natural (T.Channels) then
                  Put_Error (Into, "vtxtable: NOT ENOUGH FREQUENCIES (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Channels)));
                  Put (Into, ")###" & CRLF);
               elsif Has_Word (From) then
                  Put_Error (Into, "vtxtable: TOO MANY FREQUENCIES (EXPECTED ");
                  Put (Into, Decimal (Integer_64 (T.Channels)));
                  Put (Into, ")###" & CRLF);
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
            Put_Error (Into, "vtxtable: INVALID SUBCOMMAND ");
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
   procedure Put_Meters (Into : in out Output; Length_Cm : Integer_64)
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
      Put (Into, ".");
      Put (Into, Hundredths);
      Put (Into, "m");
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

   --  One waypoint's insert line.
   procedure Put_Waypoint (Into : in out Output; Index : Natural; W : Waypoint) is
   begin
      Put (Into, "waypoint insert ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, CLI_Text.Coordinate_Text (W.Latitude));
      Put (Into, " ");
      Put (Into, CLI_Text.Coordinate_Text (W.Longitude));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (W.Altitude)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (W.Speed)));
      Put (Into, " ");
      Put (Into, Type_Name (W.Type_Value));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (W.Duration)));
      Put (Into, " ");
      Put (Into, Pattern_Name (W.Pattern));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (W.Vert_Rate)));
      Put (Into, " ");
      Put (Into, Yaw_Name (W.Yaw_Behaviour));
      Put (Into, CRLF);
   end Put_Waypoint;

   --  The plan as a clear line and an insert line for each waypoint. A diff
   --  keeps the clear line when the plan differs from the default plan, the
   --  heading precedes the first line printed (finding F170), and a changed
   --  waypoint within the default plan's count prints its default first for
   --  Show_Defaults.
   procedure Put_Waypoints
     (Into : in out Output; Count : Unsigned_8; Points : Waypoint_List;
      Default_Count : Unsigned_8 := Defaults.Flight_Plan_Config.Waypoint_Count;
      Default : Waypoint_List := Defaults.Flight_Plan_Config.Waypoints; Mode : Dump_Mode := Listing;
      Heading : String := "")
     with Global => null
   is
      Last      : constant Natural := Natural'Min (Natural (Count), Max_Waypoints);
      All_Equal : Boolean := Count = Default_Count;
      Pending   : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      if All_Equal then
         for I in 0 .. Last - 1 loop
            if Points (I) /= Default (I) then
               All_Equal := False;
            end if;
         end loop;
      end if;
      Put_Heading (Into, Mode, not All_Equal, Heading, Pending);
      if Shows_Line (Mode, All_Equal) then
         Put (Into, "waypoint clear" & CRLF);
      end if;
      for I in 0 .. Last - 1 loop
         pragma Loop_Invariant (I < Max_Waypoints);
         declare
            Equal : constant Boolean := I < Natural (Default_Count) and then Points (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if I < Natural (Default_Count) then
               if Shows_Default (Mode, Equal) then
                  Put (Into, "#");
                  Put_Waypoint (Into, I, Default (I));
               end if;
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Waypoint (Into, I, Points (I));
            end if;
         end;
      end loop;
   end Put_Waypoints;

   --  waypoint: the plan, cleared, its status with the executor's, one
   --  waypoint removed, or one inserted or updated from its index,
   --  coordinates, altitude, speed, type, duration and pattern, with an
   --  optional vertical rate and yaw behaviour. A stored count past the plan
   --  is cleared first.
   procedure Waypoint_Command
     (Into : in out Output; Plan : in out Flight_Plan_Config_Record; Navigation : Navigation_Status;
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
         Put_Error (Into, "waypoint: ");
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
         Put (Into, "Waypoint count: ");
         Put (Into, Decimal (Integer_64 (Plan.Waypoint_Count)));
         Put (Into, CRLF);
         if Plan.Waypoint_Count > 0 then
            Put (Into, ASCII.LF & "Configured waypoints:" & CRLF);
            for I in 0 .. Natural (Plan.Waypoint_Count) - 1 loop
               pragma Loop_Invariant (I < Max_Waypoints);
               declare
                  W : constant Waypoint := Plan.Waypoints (I);
               begin
                  Put (Into, "  [");
                  Put (Into, Decimal (Integer_64 (I)));
                  Put (Into, "] ");
                  Put (Into, CLI_Text.Coordinate_Text (W.Latitude));
                  Put (Into, " ");
                  Put (Into, CLI_Text.Coordinate_Text (W.Longitude));
                  Put (Into, " ");
                  Put_Meters (Into, Integer_64 (W.Altitude));
                  Put (Into, " ");
                  Put (Into, Type_Name (W.Type_Value));
                  Put (Into, CRLF);
               end;
            end loop;
         end if;
         Put (Into, ASCII.LF & "Runtime status:" & CRLF);
         if not Navigation.Active then
            Put (Into, "  inactive" & CRLF);
            return;
         end if;
         Put (Into, "  state: ");
         Put (Into, (case Navigation.State is when 0 => "IDLE", when 1 => "TARGETING", when 2 => "HOLDING",
                     when 3 => "COMPLETE", when 4 => "LANDING", when 5 => "ABORTED", when others => "UNKNOWN"));
         Put (Into, CRLF);
         Put (Into, "  current waypoint: ");
         Put (Into, Decimal (if Plan.Waypoint_Count = 0 then 0 else Integer_64 (Navigation.Current_Index + 1)));
         Put (Into, "/");
         Put (Into, Decimal (Integer_64 (Plan.Waypoint_Count)));
         Put (Into, CRLF);
         if Navigation.Distance_M >= 0.0 then
            Put (Into, "  distance: ");
            Put_Meters (Into, Centimeters (Navigation.Distance_M));
            Put (Into, "  bearing: ");
            Put (Into, Decimal (Integer_64 (Navigation.Bearing_Deci / 10)));
            Put (Into, " deg  eta: ");
            Put (Into, Decimal (Integer_64 (Navigation.ETA_S)));
            Put (Into, "s" & CRLF);
         end if;
         if Navigation.State = 5 then
            Put (Into, "  abort reason: ");
            Put (Into, (case Navigation.Abort_Reason is when 0 => "NONE", when 1 => "GPS LOST", when 2 => "STALLED",
                        when 3 => "FLYAWAY", when 4 => "HEADING", when 5 => "MAG FAULT", when others => "UNKNOWN"));
            Put (Into, CRLF);
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
            Put (Into, "Waypoint ");
            Put (Into, Decimal (Index));
            Put (Into, " removed, ");
            Put (Into, Decimal (Integer_64 (Plan.Waypoint_Count)));
            Put (Into, " waypoints remaining" & CRLF);
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
            Put (Into, "waypoint ");
            Put (Into, (if Insert then "insert" else "update"));
            Put (Into, " ");
            Put (Into, Decimal (Index));
            Put (Into, " ");
            Put (Into, CLI_Text.Coordinate_Text (Latitude));
            Put (Into, " ");
            Put (Into, CLI_Text.Coordinate_Text (Longitude));
            Put (Into, " ");
            Put_Meters (Into, Altitude);
            Put (Into, " ");
            Put (Into, Decimal (Speed));
            Put (Into, " ");
            Put (Into, Type_Name (Kind));
            Put (Into, " ");
            Put (Into, Decimal (Duration));
            Put (Into, " ");
            Put (Into, Pattern_Name (Pattern));
            Put (Into, " ");
            Put (Into, Decimal (Rate));
            Put (Into, " ");
            Put (Into, Yaw_Name (Yaw));
            Put (Into, CRLF);
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
   procedure Put_Map_Line (Into : in out Output; Start : Map_Text; Rcmap : Bytes_8) is
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
      Put (Into, "map ");
      Put (Into, Buffer (1 .. Last));
      Put (Into, CRLF);
   end Put_Map_Line;

   --  The map line from a cleared buffer, a changed map's default first for
   --  Show_Defaults.
   procedure Put_Map (Into : in out Output; Rcmap : Bytes_8; Default : Bytes_8; Mode : Dump_Mode; Heading : String)
     with Global => null
   is
   begin
      if Heading'Length > 0 and then Shows_Line (Mode, Rcmap = Default) then
         Put_Hash_Line (Into, Heading);
      end if;
      if Shows_Default (Mode, Rcmap = Default) then
         Put (Into, "#");
         Put_Map_Line (Into, (others => ASCII.NUL), Default);
      end if;
      if Shows_Line (Mode, Rcmap = Default) then
         Put_Map_Line (Into, (others => ASCII.NUL), Rcmap);
      end if;
   end Put_Map;

   --  map: a new channel order of the eight mappable channels, each letter
   --  once, then the order as a map line, each channel's letter at its
   --  position over the typed text, or over a cleared buffer for a query.
   procedure Map_Command (Into : in out Output; C : in out Configuration; Arguments : String) is
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
               Put_Error (Into, "map: PARSING FAILED###" & CRLF);
               return;
            end if;
         end loop;
         for I in 1 .. Mappable loop
            if Letter_Position (Buffer (I)) in 1 .. Mappable then
               C.Rx_Config.Rcmap (Letter_Position (Buffer (I)) - 1) := Unsigned_8 (I - 1);
            end if;
         end loop;
      elsif Arguments'Length > 0 then
         Put_Error (Into, "map: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      Put_Map_Line (Into, Buffer, C.Rx_Config.Rcmap);
   end Map_Command;

   --  One stick's channel range line.
   procedure Put_Range_Line (Into : in out Output; Index : Natural; R : Rx_Channel_Range_Config_Record) is
   begin
      Put (Into, "rxrange ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Min)));
      Put (Into, " ");
      Put (Into, Decimal (Integer_64 (R.Max)));
      Put (Into, CRLF);
   end Put_Range_Line;

   --  The four sticks' channel range lines, a changed one's default first for
   --  Show_Defaults.
   procedure Put_Ranges
     (Into : in out Output; Ranges : Rx_Channel_Range_Config_Record_List_4;
      Default : Rx_Channel_Range_Config_Record_List_4 := Defaults.Rx_Channel_Range_Configs;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Ranges'Range loop
         pragma Loop_Invariant (I in Ranges'Range);
         declare
            Equal : constant Boolean := Ranges (I) = Default (I);
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Range_Line (Into, I, Default (I));
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Range_Line (Into, I, Ranges (I));
            end if;
         end;
      end loop;
   end Put_Ranges;

   --  rxrange: the four sticks' channel ranges, all reset to 1000 to 2000, or
   --  one stick's range of two values within 750 to 2250.
   procedure Range_Command (Into : in out Output; C : in out Configuration; Arguments : String)
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
         Put_Error (Into, "rxrange: CHANNEL NOT BETWEEN 0 AND 3###" & CRLF);
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
         Put_Error (Into, "rxrange: INVALID ARGUMENT COUNT###" & CRLF);
      elsif Low not in 750 .. 2250 or else High not in 750 .. 2250 then
         Put_Error (Into, "rxrange: range min/max NOT BETWEEN 750 AND 2250###" & CRLF);
      else
         C.Rx_Channel_Range_Configs (Natural (Index)) := (Min => Unsigned_16 (Low), Max => Unsigned_16 (High));
         Put (Into, "rxrange ");
         Put (Into, Decimal (Integer_64 (Index)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (Low)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (High)));
         Put (Into, CRLF);
      end if;
   end Range_Command;

   Failsafe_Characters : constant String := "ahs";

   --  A channel's failsafe line: its mode's letter and, with a value, its
   --  value.
   procedure Put_Failsafe
     (Into : in out Output; Channel : Natural; F : Rx_Failsafe_Channel_Config_Record; With_Value : Boolean)
   is
   begin
      Put (Into, "rxfail ");
      Put (Into, Decimal (Integer_64 (Channel)));
      Put (Into, " ");
      Put (Into, (if F.Mode <= 2 then (1 => Failsafe_Characters (Natural (F.Mode) + 1)) else ""));
      if With_Value then
         Put (Into, " ");
         Put (Into, Decimal (750 + 25 * Integer_64 (F.Step)));
      end if;
      Put (Into, CRLF);
   end Put_Failsafe;

   --  Every channel's failsafe line, with its value for the set mode, and a
   --  changed one's default first for Show_Defaults, with a value when the
   --  default's mode is the set mode.
   procedure Put_Failsafes
     (Into : in out Output; Configs : Rx_Failsafe_Channel_Config_Record_List_18;
      Default : Rx_Failsafe_Channel_Config_Record_List_18 := Defaults.Rx_Failsafe_Channel_Configs;
      Mode : Dump_Mode := Listing; Heading : String := "")
     with Global => null
   is
      Pending : Boolean := Heading'Length > 0;
   begin
      Put_Heading (Into, Mode, False, Heading, Pending);
      for I in Configs'Range loop
         pragma Loop_Invariant (I in Configs'Range);
         declare
            Equal      : constant Boolean := Configs (I) = Default (I);
            With_Value : constant Boolean := Configs (I).Mode = 2;
         begin
            Put_Heading (Into, Mode, not Equal, Heading, Pending);
            if Shows_Default (Mode, Equal) then
               Put (Into, "#");
               Put_Failsafe (Into, I, Default (I), Default (I).Mode = 2);
            end if;
            if Shows_Line (Mode, Equal) then
               Put_Failsafe (Into, I, Configs (I), With_Value);
            end if;
         end;
      end loop;
   end Put_Failsafes;

   --  rxfail: every channel's failsafe line, or one channel's mode and, for
   --  the set mode, its value; the channel number is taken modulo 256.
   procedure Failsafe_Command (Into : in out Output; C : in out Configuration; Arguments : String)
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
         Put_Error (Into, "rxfail: CHANNEL NOT BETWEEN 0 AND 17###" & CRLF);
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
               Put_Error (Into, "rxfail: PARSING FAILED###" & CRLF);
               return;
            end if;
            Mode := Unsigned_8 (Requested - 1);
            Require_Value := Mode = 2;
            P := Next_Argument (Arguments, P);
            if P > 0 then
               if not Require_Value then
                  Put_Error (Into, "rxfail: PARSING FAILED###" & CRLF);
                  return;
               end if;
               Value := Unsigned_16'Mod (Argument (Arguments, P));
               Value := (Unsigned_16'Max (750, Unsigned_16'Min (2250, Value)) - 750) / 25;
               C.Rx_Failsafe_Channel_Configs (Index).Step := Unsigned_8 (Value);
            elsif Require_Value then
               Put_Error (Into, "rxfail: INVALID ARGUMENT COUNT###" & CRLF);
               return;
            end if;
            C.Rx_Failsafe_Channel_Configs (Index).Mode := Mode;
         end if;
         Put_Failsafe
           (Into, Index, C.Rx_Failsafe_Channel_Configs (Index), C.Rx_Failsafe_Channel_Configs (Index).Mode = 2);
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
     with Pre  => Word'Length in 1 .. 20,
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
     (No_Command, Adjustment_Range_Command_Word, Aux_Command_Word, Batch_Command_Word, Battery_Profile_Command,
      Beacon_Command, Bootloader_Command_Word, Exit_Command_Word, Save_Command_Word,
      Beeper_Command_Word, Bind_Rx_Command_Word, Board_Name_Command_Word, Defaults_Command_Word,
      Manufacturer_Id_Command_Word, Signature_Command_Word, Color_Command_Word, Diff_Command, Dma_Command_Word,
      Dshot_Telemetry_Info_Command_Word, Dshotprog_Command_Word, Dump_Command, Env_Command_Word, Escprog_Command_Word,
      Feature_Command_Word, Flash_Erase_Command_Word, Flash_Info_Command_Word, Flash_Read_Command_Word,
      Flash_Scan_Command_Word, Flash_Write_Command_Word, Get_Command, Gpspassthrough_Command_Word,
      Gyroregisters_Command_Word, Help_Command_Word, Led_Command_Word,
      Map_Command_Word,
      Mode_Color_Command_Word,
      Mixer_Command_Word, Motor_Mix_Command_Word, Options_Command_Word, Peripherals_Command_Word,
      Profile_Command, Rate_Profile_Command,
      Rc_Smoothing_Info_Command_Word, Resource_Command_Word, Rx_Failsafe_Command, MCU_Id_Command_Word,
      Motor_Command_Word,
      MSC_Command_Word,
      Play_Sound_Command_Word, Rx_Range_Command, Sd_Info_Command_Word, Sensor_Hardware_Command_Word,
      Serial_Command_Word,
      Servo_Command_Word, Servo_Mix_Command_Word, Set_Command, Simplified_Tuning_Command_Word, Status_Command_Word,
      Tasks_Command_Word,
      Version_Command_Word, Vtx_Command_Word, Vtx_Info_Command_Word, Vtx_Table_Command_Word, Waypoint_Command_Word);
   subtype Known_Command is Command_Kind range Adjustment_Range_Command_Word .. Waypoint_Command_Word;

   --  The command words in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Command_Word_Pool_Length : constant := 485;
   Command_Word_Text : constant String (1 .. Command_Word_Pool_Length + 20) :=
     "adjrangeauxbatchbattery_profilebeaconblexitsavebeeperbind_rxboard_namemanufacturer_idsignaturedefaultsdi"
     & "ffdmadshot_telemetry_infodshotprogdumpenvescprogfeatureflash_eraseflash_infoflash_readflash_scanflash_wr"
     & "itegetgpspassthroughgyroregistershelpcolorledmode_colormapmcu_idmotormscplay_soundsd_infosensor_hardware"
     & "mixermmixoptionsperipheralsstatusrateprofilerc_smoothing_inforesourcerxfailrxrangeserialservosmixsetsimp"
     & "lified_tuningtasksversionvtxvtx_infovtxtablewaypointserialpassthrough                    ";
   type Command_Word_Start is range 0 .. Command_Word_Pool_Length;
   type Command_Word_Length is range 2 .. 20;
   Command_Word_Starts : constant array (Known_Command) of Command_Word_Start :=
     (Adjustment_Range_Command_Word => 0, Aux_Command_Word => 8, Batch_Command_Word => 11,
      Battery_Profile_Command => 16, Beacon_Command => 31, Bootloader_Command_Word => 37, Exit_Command_Word => 39,
      Save_Command_Word => 43, Beeper_Command_Word => 47, Bind_Rx_Command_Word => 53, Board_Name_Command_Word => 60,
      Manufacturer_Id_Command_Word => 70, Signature_Command_Word => 85, Defaults_Command_Word => 94,
      Diff_Command => 102, Dma_Command_Word => 106, Dshot_Telemetry_Info_Command_Word => 109,
      Dshotprog_Command_Word => 129, Dump_Command => 138, Env_Command_Word => 142, Escprog_Command_Word => 145,
      Feature_Command_Word => 152, Flash_Erase_Command_Word => 159, Flash_Info_Command_Word => 170,
      Flash_Read_Command_Word => 180, Flash_Scan_Command_Word => 190, Flash_Write_Command_Word => 200,
      Get_Command => 211, Gpspassthrough_Command_Word => 214, Gyroregisters_Command_Word => 228,
      Help_Command_Word => 241, Color_Command_Word => 245, Led_Command_Word => 250, Mode_Color_Command_Word => 253,
      Map_Command_Word => 263, MCU_Id_Command_Word => 266, Motor_Command_Word => 272, MSC_Command_Word => 277,
      Play_Sound_Command_Word => 280, Sd_Info_Command_Word => 290, Sensor_Hardware_Command_Word => 297,
      Mixer_Command_Word => 312, Motor_Mix_Command_Word => 317, Options_Command_Word => 321,
      Peripherals_Command_Word => 328, Status_Command_Word => 339, Profile_Command => 24,
      Rate_Profile_Command => 345, Rc_Smoothing_Info_Command_Word => 356, Resource_Command_Word => 373,
      Rx_Failsafe_Command => 381, Rx_Range_Command => 387, Serial_Command_Word => 394, Servo_Command_Word => 400,
      Servo_Mix_Command_Word => 405, Set_Command => 409, Simplified_Tuning_Command_Word => 412,
      Tasks_Command_Word => 429, Version_Command_Word => 434, Vtx_Command_Word => 441, Vtx_Info_Command_Word => 444,
      Vtx_Table_Command_Word => 452, Waypoint_Command_Word => 460);
   Command_Word_Lengths : constant array (Known_Command) of Command_Word_Length :=
     (Adjustment_Range_Command_Word => 8, Aux_Command_Word => 3, Batch_Command_Word => 5,
      Battery_Profile_Command => 15, Beacon_Command => 6, Bootloader_Command_Word => 2, Exit_Command_Word => 4,
      Save_Command_Word => 4, Beeper_Command_Word => 6, Bind_Rx_Command_Word => 7, Board_Name_Command_Word => 10,
      Manufacturer_Id_Command_Word => 15, Signature_Command_Word => 9, Defaults_Command_Word => 8,
      Diff_Command => 4, Dma_Command_Word => 3, Dshot_Telemetry_Info_Command_Word => 20,
      Dshotprog_Command_Word => 9, Dump_Command => 4, Env_Command_Word => 3, Escprog_Command_Word => 7,
      Feature_Command_Word => 7, Flash_Erase_Command_Word => 11, Flash_Info_Command_Word => 10,
      Flash_Read_Command_Word => 10, Flash_Scan_Command_Word => 10, Flash_Write_Command_Word => 11,
      Get_Command => 3, Gpspassthrough_Command_Word => 14, Gyroregisters_Command_Word => 13, Help_Command_Word => 4,
      Color_Command_Word => 5, Led_Command_Word => 3, Mode_Color_Command_Word => 10, Map_Command_Word => 3,
      MCU_Id_Command_Word => 6, Motor_Command_Word => 5, MSC_Command_Word => 3, Play_Sound_Command_Word => 10,
      Sd_Info_Command_Word => 7, Sensor_Hardware_Command_Word => 15, Mixer_Command_Word => 5,
      Motor_Mix_Command_Word => 4, Options_Command_Word => 7, Peripherals_Command_Word => 11,
      Status_Command_Word => 6, Profile_Command => 7, Rate_Profile_Command => 11,
      Rc_Smoothing_Info_Command_Word => 17, Resource_Command_Word => 8, Rx_Failsafe_Command => 6,
      Rx_Range_Command => 7, Serial_Command_Word => 6, Servo_Command_Word => 5, Servo_Mix_Command_Word => 4,
      Set_Command => 3, Simplified_Tuning_Command_Word => 17, Tasks_Command_Word => 5, Version_Command_Word => 7,
      Vtx_Command_Word => 3, Vtx_Info_Command_Word => 8, Vtx_Table_Command_Word => 8, Waypoint_Command_Word => 8);

   function Command_Word (K : Known_Command) return String is
     (Command_Word_Text (Natural (Command_Word_Starts (K)) + 1
                         .. Natural (Command_Word_Starts (K)) + Natural (Command_Word_Lengths (K))))
     with Post => Command_Word'Result'Length in 1 .. 20;

   function Command_Count return Positive is (64);

   subtype Command_Position is Positive range 1 .. 64;

   --  The command names, each at its start in the command word text for its length.
   type Command_Name_Start is range 0 .. Command_Word_Pool_Length;
   type Command_Name_Length is range 2 .. 20;
   Command_Name_Starts : constant array (Command_Position) of Command_Name_Start :=
     (1 => 0, 2 => 8, 3 => 11, 4 => 31, 5 => 47, 6 => 53, 7 => 37, 8 => 60, 9 => 245, 10 => 94, 11 => 102,
      12 => 106, 13 => 109, 14 => 129, 15 => 138, 16 => 142, 17 => 145, 18 => 39, 19 => 152, 20 => 159, 21 => 170,
      22 => 180, 23 => 190, 24 => 200, 25 => 211, 26 => 214, 27 => 228, 28 => 241, 29 => 250, 30 => 70, 31 => 263,
      32 => 266, 33 => 312, 34 => 317, 35 => 253, 36 => 272, 37 => 277, 38 => 321, 39 => 328, 40 => 280, 41 => 16,
      42 => 24, 43 => 345, 44 => 356, 45 => 373, 46 => 381, 47 => 387, 48 => 43, 49 => 290, 50 => 297, 51 => 394,
      52 => 468, 53 => 400, 54 => 409, 55 => 85, 56 => 412, 57 => 405, 58 => 339, 59 => 429, 60 => 434, 61 => 441,
      62 => 444, 63 => 452, 64 => 460);
   Command_Name_Lengths : constant array (Command_Position) of Command_Name_Length :=
     (1 => 8, 2 => 3, 3 => 5, 4 => 6, 5 => 6, 6 => 7, 7 => 2, 8 => 10, 9 => 5, 10 => 8, 11 => 4, 12 => 3, 13 => 20,
      14 => 9, 15 => 4, 16 => 3, 17 => 7, 18 => 4, 19 => 7, 20 => 11, 21 => 10, 22 => 10, 23 => 10, 24 => 11,
      25 => 3, 26 => 14, 27 => 13, 28 => 4, 29 => 3, 30 => 15, 31 => 3, 32 => 6, 33 => 5, 34 => 4, 35 => 10,
      36 => 5, 37 => 3, 38 => 7, 39 => 11, 40 => 10, 41 => 15, 42 => 7, 43 => 11, 44 => 17, 45 => 8, 46 => 6,
      47 => 7, 48 => 4, 49 => 7, 50 => 15, 51 => 6, 52 => 17, 53 => 5, 54 => 3, 55 => 9, 56 => 17, 57 => 4, 58 => 6,
      59 => 5, 60 => 7, 61 => 3, 62 => 8, 63 => 8, 64 => 8);

   function Command_Name (Position : Positive) return String is
     (Command_Word_Text (Natural (Command_Name_Starts (Position)) + 1
                         .. Natural (Command_Name_Starts (Position)) + Natural (Command_Name_Lengths (Position))));

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

   --  simplified_tuning: the simplified tuning of every PID profile with the
   --  gyro settings applied, or every slider turned off.
   procedure Simplified_Tuning_Command (Into : in out Output; C : in out Configuration; Arguments : String) is
   begin
      if CLI_Text.Same_Ignoring_Case (Arguments, "apply") then
         Config_Reset.Apply_Tuning (C);
         Put (Into, "Applied simplified tuning." & CRLF);
      elsif CLI_Text.Same_Ignoring_Case (Arguments, "disable") then
         for I in C.Pid_Profiles'Range loop
            Simplified_Tuning.Stored.Disable (C.Pid_Profiles (I), C.Gyro_Config);
         end loop;
         Put (Into, "Disabled simplified tuning." & CRLF);
      else
         Put_Error (Into, "simplified_tuning: PARSING FAILED###" & CRLF);
      end if;
   end Simplified_Tuning_Command;

   --  batch: start opens a batch, or starts an open one again, clearing its
   --  error; end closes it, with the error line when a command in it
   --  printed an error; any other option is the error. An option is its
   --  whole word, in any case (finding F180).
   procedure Batch_Command (Into : in out Output; Arguments : String) is
      function Is_Word (Word : String) return Boolean is (CLI_Text.Same_Ignoring_Case (Arguments, Word));
   begin
      if Is_Word ("start") then
         Into.Batch_Active := True;
         Into.Batch_Error := False;
         Put (Into, "Command batch started" & CRLF);
      elsif Is_Word ("end") then
         if Into.Batch_Active and then Into.Batch_Error then
            Put_Error (Into, "batch: ERRORS WERE DETECTED - PLEASE REVIEW BEFORE CONTINUING###" & CRLF);
         else
            Put (Into, "Command batch ended" & CRLF);
         end if;
         Into.Batch_Active := False;
         Into.Batch_Error := False;
      else
         Put_Error (Into, "batch: Invalid option###" & CRLF);
      end if;
   end Batch_Command;

   --  The version line: the firmware's name, the target's name, a board
   --  identifier, the version, the build's date, time and revision, and the
   --  MSP API version.
   procedure Put_Version (Into : in out Output; Env : Environment; Identifier : Bytes_6) is
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
      Put (Into, ") MSP API: ");
      Put (Into, Decimal (MSP_Common_Out.API_Version_Major));
      Put (Into, ".");
      Put (Into, Decimal (MSP_Common_Out.API_Version_Minor));
      Put (Into, CRLF);
   end Put_Version;

   --  version: the version line with the configuration's board identifier,
   --  then the board's manufacturer and name when both are known.
   procedure Version_Command (Into : in out Output; C : Configuration; Env : Environment; Board : Board_State) is
   begin
      Put_Version (Into, Env, C.System_Config.Board_Identifier);
      if Board.Manufacturer.Length > 0 and then Board.Name.Length > 0 then
         Put (Into, "# board: manufacturer_id: ");
         Put (Into, Text_Of (Board.Manufacturer));
         Put (Into, ", board_name: ");
         Put (Into, Text_Of (Board.Name));
         Put (Into, CRLF);
      end if;
   end Version_Command;

   --  The restart: the Rebooting line after an empty one, and the restart
   --  requested.
   procedure Reboot_Board (Into : in out Output; Changes : in out Effects) is
   begin
      Put (Into, CRLF);
      Put (Into, "Rebooting");
      Changes.Reboot := True;
   end Reboot_Board;

   --  The save's preparation: inside a batch that printed an error, the
   --  batch warning, the batch closed and no save; else the board's updated
   --  information stored, and its updated signature while none is stored.
   procedure Prepare_Save
     (Into : in out Output; C : in out Configuration; Board : in out Board_State; Command : String; OK : out Boolean)
   is
   begin
      if Into.Batch_Active and then Into.Batch_Error then
         Put_Error (Into, Command);
         Put (Into, ": ERRORS WERE DETECTED - PLEASE REVIEW BEFORE CONTINUING###" & CRLF);
         Put_Error (Into, Command);
         Put (Into, ": PLEASE FIX ERRORS THEN 'SAVE'###" & CRLF);
         Into.Batch_Active := False;
         Into.Batch_Error := False;
         OK := False;
         return;
      end if;
      if Board.Information_Updated then
         Board_Info.Persist_Information (C, Board);
      end if;
      if Board.Signature_Updated and then not Board.Signature_Set then
         Board_Info.Persist_Signature (C, Board);
      end if;
      OK := True;
   end Prepare_Save;

   --  save: after the save's preparation, the configuration marked
   --  configured and its write requested, the saving line, and the restart
   --  unless noreboot follows.
   procedure Save_Command
     (Into : in out Output; C : in out Configuration; Board : in out Board_State; Arguments : String;
      Changes : in out Effects)
   is
      OK : Boolean;
   begin
      Prepare_Save (Into, C, Board, "save", OK);
      if not OK then
         return;
      end if;
      C.System_Config.Configuration_State := 1;
      Changes.Save := True;
      Put_Hash_Line (Into, "saving");
      if CLI_Text.Same_Ignoring_Case (Arguments, "noreboot") then
         return;
      end if;
      Reboot_Board (Into, Changes);
   end Save_Command;

   --  exit: the leaving line, the command line left, and the restart unless
   --  noreboot follows.
   procedure Exit_Command (Into : in out Output; Arguments : String; Changes : in out Effects) is
      Reboot : constant Boolean := not CLI_Text.Same_Ignoring_Case (Arguments, "noreboot");
   begin
      Put_Hash_Line
        (Into, (if Reboot then "leaving CLI mode, unsaved changes lost" else "leaving CLI mode, no reboot"));
      Changes.Leave := True;
      if Reboot then
         Reboot_Board (Into, Changes);
      end if;
   end Exit_Command;

   --  defaults with nosave: the configuration reset to its defaults, or one
   --  parameter group's after group_id and its number, with the simplified
   --  tuning applied to every PID profile of the reset configuration first
   --  and the board's information kept in it. A word other than group_id or
   --  nosave, in any case, a group number outside 1 to 65535 or a missing
   --  one is the parse error (finding F178). A reset clears an open batch's
   --  error. Without nosave, the save's preparation follows, then the
   --  configuration's write and the board's restart.
   procedure Defaults_Command
     (Into : in out Output; C : in out Configuration; Board : in out Board_State; Arguments : String;
      Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      Save   : Boolean := True;
      Group  : Unsigned_16 := 0;
      Expect : Boolean := False;
      P      : Positive := Arguments'First;
      First  : Natural;
      Last   : Natural;
      OK     : Boolean;
   begin
      loop
         pragma Loop_Invariant (P >= Arguments'First);
         pragma Loop_Variant (Increases => P);
         Next_Word (Arguments, P, First, Last);
         exit when First = 0;
         if Expect then
            declare
               Number : constant Integer_32 := CLI_Text.To_Integer (Arguments (First .. Last));
            begin
               Expect := False;
               if Number not in 1 .. 65_535 then
                  Put_Error (Into, "defaults: PARSING FAILED###" & CRLF);
                  return;
               end if;
               Group := Unsigned_16 (Number);
            end;
         elsif CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "group_id") then
            Expect := True;
         elsif CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "nosave") then
            Save := False;
         else
            Put_Error (Into, "defaults: PARSING FAILED###" & CRLF);
            return;
         end if;
         exit when Last >= Arguments'Last;
         P := Last + 1;
      end loop;
      if Expect then
         Put_Error (Into, "defaults: PARSING FAILED###" & CRLF);
         return;
      end if;
      if Group = 0 then
         Put_Hash_Line (Into, "resetting to defaults");
         C := Config_Reset.Reset (Board);
      else
         Put (Into, CRLF & "# resetting group ");
         Put (Into, Decimal (Integer_64 (Group)));
         Put (Into, " to defaults" & CRLF);
         declare
            Reset : constant Configuration := Config_Reset.Reset (Board);
            Kept  : Config_Codec.Data;
            Fresh : Config_Codec.Data;
         begin
            Config_Codec.Encode (C, Kept);
            Config_Codec.Encode (Reset, Fresh);
            pragma Assert (Config_Codec.Groups_Within);
            for G of Config_Codec.Registry loop
               if G.Number = Group then
                  Kept (G.Offset .. G.Offset + G.Size - 1) := Fresh (G.Offset .. G.Offset + G.Size - 1);
               end if;
            end loop;
            Config_Codec.Decode (Kept, C);
         end;
      end if;
      Into.Batch_Error := False;
      if Save then
         Prepare_Save (Into, C, Board, "defaults", OK);
         if OK then
            Changes.Save := True;
            Reboot_Board (Into, Changes);
         end if;
      end if;
   end Defaults_Command;

   --  board_name and manufacturer_id: the value, after a new one up to its
   --  length is taken while the stored information is not set or the value
   --  is empty; a different value for a set one is the error, the new one
   --  cut to the length as it would be stored (finding F176).
   procedure Board_Text_Command
     (Into : in out Output; Command : String; Label : String; Value : in out Identity_Text; Limit : Natural;
      Information_Set : Boolean; Updated : in out Boolean; Arguments : String)
     with Pre => Limit <= Identity_Max and then Arguments'Last < Positive'Last
   is
   begin
      if Arguments'Length > 0 and then Value.Length /= 0 and then Information_Set
        and then Arguments (Arguments'First .. Arguments'First + (Natural'Min (Arguments'Length, Limit) - 1))
                 /= Text_Of (Value)
      then
         Put_Error (Into, Command);
         Put (Into, ": ");
         Put (Into, Label);
         Put (Into, " CANNOT BE CHANGED. CURRENT VALUE: '");
         Put (Into, Text_Of (Value));
         Put (Into, "'###" & CRLF);
         return;
      end if;
      if Arguments'Length > 0 and then (not Information_Set or else Value.Length = 0) then
         Value :=
           To_Identity (Arguments (Arguments'First .. Arguments'First + (Natural'Min (Arguments'Length, Limit) - 1)));
         Updated := True;
         Put (Into, CRLF & "# Set ");
         Put (Into, Command);
         Put (Into, "." & CRLF);
      end if;
      Put (Into, Command);
      Put (Into, " ");
      Put (Into, Text_Of (Value));
      Put (Into, CRLF);
   end Board_Text_Command;

   --  A mixer mode's name; none outside the names.
   procedure Put_Mixer_Name (Into : in out Output; Mode : Unsigned_8) is
   begin
      if Mode in 1 .. Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1 then
         Put (Into, Mixer_Name (Mixer_Init.Mixer_Mode'Val (Mode - 1)));
      end if;
   end Put_Mixer_Name;

   --  The dump's sections from the mixer on, each under its heading: the
   --  mixer with its custom motor mix, the servos, the servo rules, the
   --  beepers, the beacons, the channel map, the LEDs, the colors, the mode
   --  colors, the mode conditions, the adjustment ranges, the channel ranges,
   --  the VTX table, the VTX conditions, the channel failsafe and the flight
   --  plan. The motor mix's and the servo rules' reset lines follow the
   --  default configuration's first motor and first rule, and without the
   --  servo rules' reset line the rules print their heading.
   procedure Put_Sections (Into : in out Output; C : Configuration; Mode : Dump_Mode)
     with Global => null
   is
      Mixer   : constant Unsigned_8 := C.Mixer_Config.Mixer_Mode;
      Default : constant Unsigned_8 := Defaults.Mixer_Config.Mixer_Mode;
      Pending : Boolean := True;
   begin
      Put_Heading (Into, Mode, Mixer /= Default, "mixer", Pending);
      if Shows_Default (Mode, Mixer = Default) then
         Put (Into, "#mixer ");
         Put_Mixer_Name (Into, Default);
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, Mixer = Default) then
         Put (Into, "mixer ");
         Put_Mixer_Name (Into, Mixer);
         Put (Into, CRLF);
      end if;
      if Shows_Line (Mode, C.Custom_Motor_Mixer (0).Throttle = 0.0) then
         Put (Into, CRLF & "mmix reset" & CRLF & CRLF);
      end if;
      Put_Motor_Mix (Into, C.Custom_Motor_Mixer, Mode => Mode, Heading => (if Pending then "mixer" else ""));
      Put_Servos (Into, C.Servo_Params, Mode => Mode, Heading => "servo");
      if not Mode.Diff or else C.Custom_Servo_Mixers (0).Rate /= 0 then
         Put_Hash_Line (Into, "servo mixer");
         Put (Into, "smix reset" & CRLF & CRLF);
         Put_Servo_Rules (Into, C.Custom_Servo_Mixers, Mode => Mode);
      else
         Put_Servo_Rules (Into, C.Custom_Servo_Mixers, Mode => Mode, Heading => "servo mixer");
      end if;
      Put_Beeper_Dump
        (Into, "beeper", C.Beeper_Config.Beeper_Off_Flags, Defaults.Beeper_Config.Beeper_Off_Flags, Beeper_Allowed,
         Mode, "beeper");
      Put_Beeper_Dump
        (Into, "beacon", C.Beeper_Config.Dshot_Beacon_Off_Flags, Defaults.Beeper_Config.Dshot_Beacon_Off_Flags,
         Beacon_Allowed, Mode, "beacon");
      Put_Map (Into, C.Rx_Config.Rcmap, Defaults.Rx_Config.Rcmap, Mode, "map");
      Put_Leds (Into, C.Led_Strip_Status_Mode_Config.Led_Configs, Mode => Mode, Heading => "led");
      Put_Colors (Into, C.Led_Strip_Status_Mode_Config.Colors, Mode => Mode, Heading => "color");
      Put_Mode_Colors (Into, C.Led_Strip_Status_Mode_Config, Mode => Mode, Heading => "mode_color");
      Put_Conditions (Into, C.Mode_Activation_Conditions, Mode => Mode, Heading => "aux");
      Put_Adjustment_Ranges (Into, C.Adjustment_Ranges, Mode => Mode, Heading => "adjrange");
      Put_Ranges (Into, C.Rx_Channel_Range_Configs, Mode => Mode, Heading => "rxrange");
      Put_Vtx_Table (Into, C.Vtx_Table_Config, Mode => Mode, Heading => "vtxtable");
      Put_Vtx_Conditions (Into, C.Vtx_Config.Vtx_Channel_Activation_Conditions, Mode => Mode, Heading => "vtx");
      Put_Failsafes (Into, C.Rx_Failsafe_Channel_Configs, Mode => Mode, Heading => "rxfail");
      Put_Waypoints
        (Into, C.Flight_Plan_Config.Waypoint_Count, C.Flight_Plan_Config.Waypoints, Mode => Mode,
         Heading => "waypoint");
   end Put_Sections;

   Hex_Digits : constant String (1 .. 16) := "0123456789abcdef";

   --  A number's low hexadecimal digits in lower case.
   function Hex_Text (V : Unsigned_32; Width : Positive) return String
     with Pre => Width <= 8, Post => Hex_Text'Result'Length = Width
   is
      Text : String (1 .. Width);
   begin
      for K in 1 .. Width loop
         Text (K) := Hex_Digits (Natural (Shift_Right (V, 4 * (Width - K)) and 16#F#) + 1);
      end loop;
      return Text;
   end Hex_Text;

   --  sd_info: why the SD card cannot report, or its identity with its
   --  name's five bytes after an opening quote, then the file system's state.
   procedure SD_Info_Command (Into : in out Output; Mode : Unsigned_8; S : SD_Card_Status)
     with Global => null
   is
      --  A number with zeros before it up to the width, as %0Nd prints it.
      function Zero_Padded (V : Integer_64; Width : Natural) return String is
        (if Decimal (V)'Length >= Width then Decimal (V)
         else String'(1 .. Width - Decimal (V)'Length => '0') & Decimal (V))
        with Pre => V >= 0 and then Width <= 8;

      Maker : constant Unsigned_32 := Unsigned_32 (S.Manufacturer);
   begin
      Put (Into, "SD-CARD: ");
      if Mode = 0 then
         Put (Into, "Not configured" & CRLF);
         return;
      end if;
      if not S.Inserted then
         Put (Into, "None inserted" & CRLF);
         return;
      end if;
      if not S.Functional or else not S.Initialized then
         Put (Into, "Startup failed" & CRLF);
         return;
      end if;
      Put (Into, "Manufacturer 0x");
      Put (Into, Hex_Text (Maker, (if Maker < 16 then 1 else 2)));
      Put (Into, ", ");
      Put (Into, Decimal (Integer_64 (S.Blocks / 2)));
      Put (Into, "kB, ");
      Put (Into, Zero_Padded (Integer_64 (S.Month), 2));
      Put (Into, "/");
      Put (Into, Zero_Padded (Integer_64 (S.Year), 4));
      Put (Into, ", v");
      Put (Into, Decimal (Integer_64 (S.Major)));
      Put (Into, ".");
      Put (Into, Decimal (Integer_64 (S.Minor)));
      Put (Into, ", '");
      Put (Into, S.Name);
      Put (Into, " FS: ");
      case S.State is
         when Ready =>
            Put (Into, "Ready");
         when Initializing =>
            Put (Into, "Initializing");
         when Unknown | Fatal =>
            Put (Into, "Fatal");
            case S.Last_Error is
               when Bad_MBR =>
                  Put (Into, " - no FAT MBR partitions");
               when Bad_Header =>
                  Put (Into, " - bad FAT header");
               when No_Error | Generic_Error =>
                  null;
            end case;
      end case;
      Put (Into, CRLF);
   end SD_Info_Command;

   --  flash_info: the flash chip's geometry, its partitions, and the size of
   --  the first flash file system partition in the whole table with the
   --  file system's use; without such a partition the size reads 0 (F241).
   procedure Flash_Info_Command (Into : in out Output; F : Flash_Status)
     with Global => null
   is
      type Kind_Names is array (0 .. 5) of String (1 .. 9);
      Names : constant Kind_Names := ("UNKNOWN  ", "PARTITION", "FLASHFS  ", "BBMGMT   ", "FIRMWARE ", "CONFIG   ");
      Size  : Unsigned_32 := 0;
   begin
      Put (Into, "Flash sectors=");
      Put (Into, Decimal (Integer_64 (F.Sectors)));
      Put (Into, ", sectorSize=");
      Put (Into, Decimal (Integer_64 (F.Sector_Size)));
      Put (Into, ", pagesPerSector=");
      Put (Into, Decimal (Integer_64 (F.Pages_Per_Sector)));
      Put (Into, ", pageSize=");
      Put (Into, Decimal (Integer_64 (F.Page_Size)));
      Put (Into, ", totalSize=");
      Put (Into, Decimal (Integer_64 (F.Total_Size)));
      Put (Into, " JEDEC ID=0x");
      Put (Into, Hex_Text (F.JEDEC_Id, 8));
      Put (Into, CRLF);
      for Index in 0 .. Max_Flash_Partitions - 1 loop
         pragma Loop_Invariant (Index in 0 .. Max_Flash_Partitions - 1);
         if Index = 0 then
            Put (Into, "Partitions:" & CRLF);
         end if;
         exit when Index >= F.Count;
         Put (Into, "  ");
         Put (Into, Decimal (Integer_64 (Index)));
         Put (Into, ": ");
         Put (Into, Names (F.Partitions (Index).Kind));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (F.Partitions (Index).First_Sector)));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (F.Partitions (Index).Last_Sector)));
         Put (Into, CRLF);
      end loop;
      for P of F.Partitions loop
         if P.Kind = Flash_File_System then
            Size := Unsigned_32'Mod (Integer_64 (P.Last_Sector) + 1 - Integer_64 (P.First_Sector)) * F.Sector_Size;
            exit;
         end if;
      end loop;
      Put (Into, "FlashFS size=");
      Put (Into, Decimal (Integer_64 (Size)));
      Put (Into, ", usedSize=");
      Put (Into, Decimal (Integer_64 (F.Used)));
      Put (Into, CRLF);
   end Flash_Info_Command;

   --  The number at a text's start as C's atoi reads it: blanks, a sign and
   --  the digits up to the first other character, held at a million
   --  millions.
   function Leading_Whole (Text : String) return Integer_64
     with Global => null,
          Pre    => Text'First >= 1 and then Text'Last < Positive'Last,
          Post   => Leading_Whole'Result in -10 ** 12 .. 10 ** 12
   is
      K        : Positive := Text'First;
      Negative : Boolean := False;
      Value    : Integer_64 := 0;
   begin
      while K <= Text'Last and then Text (K) in ' ' | ASCII.HT .. ASCII.CR loop
         pragma Loop_Invariant (K in Text'Range);
         pragma Loop_Variant (Increases => K);
         K := K + 1;
      end loop;
      if K <= Text'Last and then Text (K) in '+' | '-' then
         Negative := Text (K) = '-';
         K := K + 1;
      end if;
      while K <= Text'Last and then Text (K) in '0' .. '9' loop
         pragma Loop_Invariant (K in Text'Range and then Value in 0 .. 10 ** 12);
         pragma Loop_Variant (Increases => K);
         Value := Integer_64'Min (Value * 10 + Character'Pos (Text (K)) - Character'Pos ('0'), 10 ** 12);
         K := K + 1;
      end loop;
      return (if Negative then -Value else Value);
   end Leading_Whole;

   --  A number from 0 to 255 with a zero before it up to two digits, as %02d
   --  prints it.
   function Byte_Two_Digits (V : Interfaces.Unsigned_8) return String is
     (if V < 10 then "0" & Decimal (Integer_64 (V)) else Decimal (Integer_64 (V)))
     with Global => null;

   --  The details of an ESC information frame of a kind whose checksum holds:
   --  the ESC type, the MCU serial number, the firmware version, and for the
   --  later kinds the rotation direction and 3D, with the voltage and current
   --  limits and the LEDs of BLHeli_32.
   procedure Put_ESC_Details (Into : in out Output; F : ESC_Info.Frame; K : ESC_Info.Kind)
     with Global => null
   is
      use type ESC_Info.Kind;
      Version : constant ESC_Info.Byte := ESC_Info.Firmware (F, K);
      Sub     : constant ESC_Info.Byte := ESC_Info.Subversion (F, K);
      Number  : constant ESC_Info.Byte := ESC_Info.ESC_Type (F, K);
   begin
      Put (Into, "ESC Type: ");
      if K = ESC_Info.BLHeli_32 then
         declare
            Length : constant Natural := ESC_Info.Type_Text_Length (F);
            Text   : String (1 .. Length);
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (F (30 + I));
            end loop;
            Put (Into, Text);
            Put (Into, CRLF);
         end;
      else
         Put (Into, (case Number is when 1 => "KISS8A", when 2 => "KISS16A", when 3 => "KISS24A",
                     when 5 => "KISS Ultralite", when others => "unknown"));
         Put (Into, CRLF);
      end if;
      Put (Into, "MCU Serial No: 0x");
      for I in 0 .. 11 loop
         pragma Loop_Invariant (I in 0 .. 11);
         if I > 0 and then I mod 3 = 0 then
            Put (Into, "-");
         end if;
         Put (Into, Hex_Text (Unsigned_32 (F (I)), 2));
      end loop;
      Put (Into, CRLF);
      if K = ESC_Info.BLHeli_32 then
         Put (Into, "Firmware Version: ");
         Put (Into, Decimal (Integer_64 (Version)));
         Put (Into, ".");
         Put (Into, Byte_Two_Digits (Sub));
         Put (Into, CRLF);
      else
         Put (Into, "Firmware Version: ");
         Put (Into, Decimal (Integer_64 (Version / 100)));
         Put (Into, ".");
         Put (Into, Byte_Two_Digits (Version mod 100));
         Put (Into, "" & Character'Val (Sub));
         Put (Into, CRLF);
      end if;
      if K = ESC_Info.KISS_V1 then
         return;
      end if;
      Put (Into, "Rotation Direction: ");
      Put (Into, (if F (16) /= 0 then "reversed" else "normal"));
      Put (Into, CRLF);
      Put (Into, "3D: ");
      Put (Into, (if F (17) /= 0 then "on" else "off"));
      Put (Into, CRLF);
      if K /= ESC_Info.BLHeli_32 then
         return;
      end if;
      Put (Into, "Low voltage Limit: ");
      case F (18) is
         when 0 =>
            Put (Into, "off" & CRLF);
         when 255 =>
            Put (Into, "unsupported" & CRLF);
         when others =>
            Put (Into, Decimal (Integer_64 (F (18) / 10)));
            Put (Into, ".");
            Put (Into, Decimal (Integer_64 (F (18) mod 10)));
            Put (Into, CRLF);
      end case;
      Put (Into, "Current Limit: ");
      case F (19) is
         when 0 =>
            Put (Into, "off" & CRLF);
         when 255 =>
            Put (Into, "unsupported" & CRLF);
         when others =>
            Put (Into, Decimal (Integer_64 (F (19))));
            Put (Into, CRLF);
      end case;
      for I in 0 .. 3 loop
         pragma Loop_Invariant (I in 0 .. 3);
         Put (Into, "LED ");
         Put (Into, Decimal (Integer_64 (I)));
         Put (Into, ": ");
         Put (Into, (if F (20 + I) = 0 then "off" elsif F (20 + I) = 255 then "unsupported" else "on"));
         Put (Into, CRLF);
      end loop;
   end Put_ESC_Details;

   --  An ESC's information: its heading, the read started, the information
   --  command written, a wait of 10 ms, and the frame that came back, or that
   --  none did.
   procedure ESC_Info_Command (Into : in out Output; Index : Natural; Motors : Natural)
     with Global => null
   is
      F     : ESC_Info.Frame;
      Count : Natural;
   begin
      Put (Into, "Info for ESC ");
      Put (Into, Decimal (Integer_64 (Index)));
      Put (Into, ":" & CRLF);
      ESC_Read_Start;
      DShot_Write (Index, Motors, 6);
      Delay_Ms (10);
      ESC_Read_Bytes (F, Count);
      if Count > ESC_Info.Version_Position and then Count = ESC_Info.Length_Of (ESC_Info.Kind_Of (F)) then
         if ESC_Info.Checksum_Holds (F, ESC_Info.Kind_Of (F)) then
            Put_ESC_Details (Into, F, ESC_Info.Kind_Of (F));
         else
            Put_Error (Into, "dshotprog: CHECKSUM ERROR.###" & CRLF);
         end if;
      else
         Put (Into, "No Info." & CRLF);
      end if;
   end ESC_Info_Command;

   --  dshotprog: the output's line, then for each command up to 47 the motors
   --  switched off before the first one, the command written, or with the ESC
   --  sensor the information of the ESC or of each one for the information
   --  command, and the sent line; any other command is an error. The motors
   --  switch back on at the end unless the output was wrong.
   procedure Dshotprog_Command (Into : in out Output; Env : Environment; Arguments : String)
     with Global => null,
          Pre    => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      All_Motors : constant := 255;
      Motors     : constant Natural := Natural (Env.Motors);
      Index      : Integer_64 := 0;
      Position   : Natural := 0;
      First      : Boolean := True;
      K          : Positive := Arguments'First;
   begin
      if Arguments'Length = 0 or else not Env.DShot_Protocol then
         Put_Error (Into, "dshotprog: PARSING FAILED###" & CRLF);
         return;
      end if;
      loop
         pragma Loop_Invariant (K in Arguments'First .. Arguments'Last + 1);
         pragma Loop_Invariant
           (Position = 0 or else Index in 0 .. Integer_64 (Motors) - 1 or else Index = All_Motors);
         while K <= Arguments'Last and then Arguments (K) = ' ' loop
            pragma Loop_Invariant (K in Arguments'Range);
            pragma Loop_Variant (Increases => K);
            K := K + 1;
         end loop;
         exit when K > Arguments'Last;
         declare
            Start : constant Positive := K;
         begin
            while K <= Arguments'Last and then Arguments (K) /= ' ' loop
               pragma Loop_Invariant (K in Start .. Arguments'Last);
               pragma Loop_Variant (Increases => K);
               K := K + 1;
            end loop;
            declare
               Value : constant Integer_64 := Leading_Whole (Arguments (Start .. K - 1));
            begin
               if Position = 0 then
                  Index := Value;
                  if Index in 0 .. Integer_64 (Motors) - 1 then
                     Put (Into, "Using output ");
                     Put (Into, Decimal (Index));
                     Put (Into, "." & CRLF);
                  elsif Index = All_Motors then
                     Put (Into, "Using all outputs." & CRLF);
                  else
                     Put_Error (Into, "dshotprog: INVALID OUTPUT NUMBER. RANGE: 0 - ");
                     Put (Into, Decimal (Integer_64 (Motors) - 1));
                     Put (Into, ".###" & CRLF);
                     return;
                  end if;
               elsif Value in 0 .. 47 then
                  if First then
                     Motors_Disable;
                     First := False;
                  end if;
                  if Value /= 6 then
                     DShot_Write (Natural (Index), Motors, Interfaces.Unsigned_8 (Value));
                  elsif Env.ESC_Sensor then
                     if Index /= All_Motors then
                        ESC_Info_Command (Into, Natural (Index), Motors);
                     else
                        for M in 0 .. Motors - 1 loop
                           pragma Loop_Invariant (M in 0 .. Motors - 1);
                           ESC_Info_Command (Into, M, Motors);
                        end loop;
                     end if;
                  else
                     Put (Into, "Not supported." & CRLF);
                  end if;
                  Put (Into, "Command Sent: ");
                  Put (Into, Decimal (Value));
                  Put (Into, CRLF);
               else
                  Put_Error (Into, "dshotprog: INVALID COMMAND. RANGE: 1 - 47.###" & CRLF);
               end if;
            end;
         end;
         if Position < Natural'Last then
            Position := Position + 1;
         end if;
      end loop;
      Motors_Enable;
   end Dshotprog_Command;

   --  escprog: the board's ESC passthrough of a protocol, chosen by a word
   --  that starts sk, bl, ki or cc without regard to case, to an output, or
   --  to all outputs for KISS. Another protocol is the parse error, another
   --  output the output error, a third word or no words the argument count
   --  error, each ending the command; a start that fails is the start error.
   procedure Escprog_Command (Into : in out Output; Env : Environment; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      SimonK     : constant := 0;
      BLHeli     : constant := 1;
      KISS       : constant := 2;
      Castle     : constant := 4;
      All_Motors : constant := 255;
      Motors     : constant Natural := Natural (Env.Motors);
      Protocol   : Interfaces.Unsigned_8 := SimonK;
      Index      : Natural := 0;
      Position   : Natural := 0;
      K          : Positive := Arguments'First;
      Started    : Boolean;

      --  Whether a word is the start of a protocol's two letters, as
      --  strncasecmp over the word's length compares them.
      function Starts (Word : String; Name : String) return Boolean is
        (Word'Length in 1 .. Name'Length
         and then CLI_Text.Same_Ignoring_Case (Word, Name (Name'First .. Name'First + Word'Length - 1)))
        with Pre => Name'Length = 2 and then Name'First = 1;
   begin
      if Arguments'Length = 0 then
         Put_Error (Into, "escprog: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      loop
         pragma Loop_Invariant (K in Arguments'First .. Arguments'Last + 1);
         while K <= Arguments'Last and then Arguments (K) = ' ' loop
            pragma Loop_Invariant (K in Arguments'Range);
            pragma Loop_Variant (Increases => K);
            K := K + 1;
         end loop;
         exit when K > Arguments'Last;
         declare
            Start : constant Positive := K;
         begin
            while K <= Arguments'Last and then Arguments (K) /= ' ' loop
               pragma Loop_Invariant (K in Start .. Arguments'Last);
               pragma Loop_Variant (Increases => K);
               K := K + 1;
            end loop;
            if Position = 0 then
               if Starts (Arguments (Start .. K - 1), "sk") then
                  Protocol := SimonK;
               elsif Starts (Arguments (Start .. K - 1), "bl") then
                  Protocol := BLHeli;
               elsif Starts (Arguments (Start .. K - 1), "ki") then
                  Protocol := KISS;
               elsif Starts (Arguments (Start .. K - 1), "cc") then
                  Protocol := Castle;
               else
                  Put_Error (Into, "escprog: PARSING FAILED###" & CRLF);
                  return;
               end if;
            elsif Position = 1 then
               declare
                  Value : constant Integer_64 := Leading_Whole (Arguments (Start .. K - 1));
               begin
                  if Value in 0 .. Integer_64 (Motors) - 1 then
                     Index := Natural (Value);
                     Put (Into, "Using output ");
                     Put (Into, Decimal (Value));
                     Put (Into, "." & CRLF);
                  elsif Protocol = KISS and then Value = All_Motors then
                     Index := All_Motors;
                     Put (Into, "Using all outputs." & CRLF);
                  else
                     Put_Error (Into, "escprog: INVALID OUTPUT NUMBER. RANGE: 0 - ");
                     Put (Into, Decimal (Integer_64 (Motors) - 1));
                     Put (Into, ".###" & CRLF);
                     return;
                  end if;
               end;
            else
               Put_Error (Into, "escprog: INVALID ARGUMENT COUNT###" & CRLF);
               return;
            end if;
         end;
         Position := Position + 1;
      end loop;
      ESC_Passthrough (Index, Protocol, Started);
      if not Started then
         Put_Error (Into, "escprog: Error starting ESC connection###" & CRLF);
      end if;
   end Escprog_Command;

   --  gpspassthrough: the board's GPS passthrough, with an error when it
   --  does not start.
   procedure Gpspassthrough_Command (Into : in out Output) is
      Started : Boolean;
   begin
      GPS_Passthrough (Started);
      if not Started then
         Put_Error (Into, "gpspassthrough: GPS forwarding failed###" & CRLF);
      end if;
   end Gpspassthrough_Command;

   --  options: each of the build's option numbers on its own line.
   procedure Options_Command (Into : in out Output; Env : Environment)
     with Global => null
   is
   begin
      for I in 1 .. Env.Option_Count loop
         pragma Loop_Invariant (I in 1 .. Env.Option_Count);
         Put (Into, Decimal (Integer_64 (Env.Build_Options (I))));
         Put (Into, CRLF);
      end loop;
   end Options_Command;

   --  bl: a restart into the ROM bootloader without an option or with one
   --  that starts with rom in any case, else the option's error.
   procedure Bootloader_Command (Into : in out Output; Arguments : String; Changes : in out Effects)
     with Global => null
   is
   begin
      if Arguments'Length = 0
        or else (Arguments'Length >= 3
                 and then CLI_Text.Same_Ignoring_Case (Arguments (Arguments'First .. Arguments'First + 2), "rom"))
      then
         Put_Hash_Line (Into, "restarting in ROM bootloader mode");
         Put (Into, CRLF & "Rebooting");
         Changes.Restart := ROM_Bootloader;
      else
         Put_Error (Into, "bl: Invalid option###" & CRLF);
      end if;
   end Bootloader_Command;

   --  msc: with the mass storage ready, a restart into it with the stored
   --  timezone offset, or with one read from the arguments as C's atoi reads
   --  it, which must lie within 13 hours; else that the storage is missing.
   procedure MSC_Command
     (Into          : in out Output;
      Ready         : Boolean;
      Stored_Offset : Interfaces.Integer_16;
      Arguments     : String;
      Changes       : in out Effects)
     with Global => null,
          Pre    => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      Offset : Integer_64 := Integer_64 (Stored_Offset);
   begin
      if not Ready then
         Put_Hash_Line (Into, "Storage not present or failed to initialize!");
         return;
      end if;
      if Arguments'Length > 0 then
         Offset := Leading_Whole (Arguments);
         if Offset not in -780 .. 780 then
            Put_Error (Into, "msc: INVALID TIMEZONE OFFSET###" & CRLF);
            return;
         end if;
      end if;
      Put_Hash_Line (Into, "Restarting in mass storage mode");
      Put (Into, CRLF & "Rebooting");
      Changes.Restart := Mass_Storage;
      Changes.Timezone_Offset := Interfaces.Integer_16 (Offset);
   end MSC_Command;

   --  Whether a text holds a pattern without regard to case.
   function Contains_Ignoring_Case (Text : String; Pattern : String) return Boolean
     with Global => null,
          Pre    => Pattern'Length >= 1 and then Text'Last < Positive'Last
   is
   begin
      if Pattern'Length > Text'Length then
         return False;
      end if;
      for Start in Text'First .. Text'Last - Pattern'Length + 1 loop
         if CLI_Text.Same_Ignoring_Case (Text (Start .. Start + Pattern'Length - 1), Pattern) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Ignoring_Case;

   --  A help entry when the search is empty or found in its name or in its
   --  description without regard to case: the name, the description after
   --  a dash, and the arguments on the next line after a tab.
   procedure Help_Entry
     (Into        : in out Output;
      Search      : String;
      Name        : String;
      Description : String;
      Arguments   : String;
      Any         : in out Boolean)
     with Global => null,
          Pre    => Search'Last < Positive'Last and then Name'Last < Positive'Last
                    and then Description'Last < Positive'Last and then Description'Length <= 128
                    and then Arguments'Length <= 512
   is
   begin
      if Search'Length = 0 or else Contains_Ignoring_Case (Name, Search)
        or else Contains_Ignoring_Case (Description, Search)
      then
         Any := True;
         Put (Into, Name);
         if Description'Length > 0 then
            Put (Into, " - ");
            Put (Into, Description);
         end if;
         if Arguments'Length > 0 then
            Put (Into, CRLF & ASCII.HT);
            Put (Into, Arguments);
         end if;
         Put (Into, CRLF);
      end if;
   end Help_Entry;

   --  The help descriptions and argument lists in one text, each at its start for its length. The text
   --  ends with room for a longest one, so every slice stays within it by its types.
   Help_Pool_Length : constant := 2784;
   Help_Text : constant String (1 .. Help_Pool_Length + 216) :=
     "configure adjustment rangesconfigure modesstart or end a batch of commandsenable/disable Dshot beaco"
     & "n for a conditionenable/disable beeper for a conditioninitiate binding for RX SPI, SRXL2 or CRSFrebo"
     & "ot into bootloaderget / set the name of the board modelconfigure colorsreset to defaults and rebootl"
     & "ist configuration changes from defaultshow DMA assignmentsdisplay dshot telemetry info and statsprog"
     & "ram DShot ESC(s)dump configurationshow environment (version + status as NAME=VALUE)passthrough esc t"
     & "o serialexit command line interface and reboot (default)configure featureserase flash chipshow flash"
     & " chip infoscan flash device for errorsget variable valuepassthrough gps to serialdump gyro config re"
     & "gisters contentsdisplay command helpconfigure ledsget / set the id of the board manufacturerconfigur"
     & "e rc channel orderid of the microcontrollerconfigure mixercustom motor mixerconfigure mode and speci"
     & "al colorsget/set motorswitch into msc modeshow build optionsshow attached peripheralschange battery "
     & "profilechange profilechange rate profileshow rc_smoothing operational settingsshow/set resourcesshow"
     & "/set rx failsafe settingsconfigure rx channel rangessave and reboot (default)sdcard infolist support"
     & "ed sensor hardwareshow port assignments as set commandspassthrough serial data data from port 1 to V"
     & "CP / port 2configure servoschange settingget / set the board type signatureapplies or disables simpl"
     & "ified tuningservo mixershow statusshow task statsshow versionvtx channels on switchvtx power config "
     & "dumpvtx frequency tableconfigure waypoints<index> <unused> <range channel> <start> <end> <function> "
     & "<select channel> [<center> <scale>]<index> <mode> <aux> <start> <end> <logic>start | endlist" & ASCII.CR
     & ASCII.LF & ASCII.HT
     & "<->[name][rom][board name]{nosave}[master|profile|rates|hardware|all] {defaults|bare}<index> <comman"
     & "d>+[prefix]<mode [sk/bl/ki/cc]> <index>[noreboot]<address> <length><address> <message>[search string"
     & "][manufacturer id][<map>]list" & ASCII.CR & ASCII.LF & ASCII.HT
     & "<name><index> [<value>][<timezone offset minutes>][<index>]<> | <resource name> <index> [<pin>|none]"
     & " | show [all][gyro|acc|baro|mag|rangefinder|opticalflow|pitot][<identifier> <function mask> <msp bau"
     & "d> <gps baud> <telemetry baud> <blackbox baud> (deprecated)]<id1> [<baud1>] [<mode1>] [none|<dtr pin"
     & "io>|reset] [<id2>] [<baud2>] [<mode2>][<name>=<value>][signature]apply | disable<rule> <servo> <sour"
     & "ce> <rate> <speed> <min> <max> <box>" & ASCII.CR & ASCII.LF & ASCII.HT & "reset" & ASCII.CR & ASCII.LF
     & ASCII.HT & "load <mixer>" & ASCII.CR & ASCII.LF & ASCII.HT
     & "reverse <servo> <source> r|n<index> <aux_channel> <vtx_band> <vtx_channel> <vtx_power> <start_range>"
     & " <end_range><band> <bandname> <bandletter> [FACTORY|CUSTOM] <freq> ... <freq>" & ASCII.CR & ASCII.LF
     & "list | status | insert <idx> <lat.ddddddd> <lon.ddddddd> <alt> <spd> <type> <dur> <pat> [<vrate> <ya"
     & "w>] | update <idx> <lat.ddddddd> <lon.ddddddd> <alt> <spd> <type> <dur> <pat> [<vrate> <yaw>] | remo"
     & "ve <idx> | clear                                                                                    "
     & "                                                                                                    "
     & "                                ";
   type Help_Start is range 0 .. Help_Pool_Length;
   type Description_Length is range 0 .. 56;
   type Arguments_Length is range 0 .. 216;
   Description_Starts : constant array (Command_Position) of Help_Start :=
     (1 => 0, 2 => 27, 3 => 42, 4 => 74, 5 => 117, 6 => 154, 7 => 196, 8 => 218, 9 => 255, 10 => 271, 11 => 299,
      12 => 338, 13 => 358, 14 => 396, 15 => 416, 16 => 434, 17 => 483, 18 => 508, 19 => 556, 20 => 574, 21 => 590,
      22 => 0, 23 => 610, 24 => 0, 25 => 638, 26 => 656, 27 => 681, 28 => 716, 29 => 736, 30 => 750, 31 => 792,
      32 => 818, 33 => 843, 34 => 858, 35 => 876, 36 => 909, 37 => 922, 38 => 942, 39 => 960, 40 => 0, 41 => 985,
      42 => 1007, 43 => 1021, 44 => 1040, 45 => 1078, 46 => 1096, 47 => 1125, 48 => 1152, 49 => 1177, 50 => 1188,
      51 => 1218, 52 => 1255, 53 => 1311, 54 => 1327, 55 => 1341, 56 => 1375, 57 => 1412, 58 => 1423, 59 => 1434,
      60 => 1449, 61 => 1461, 62 => 1483, 63 => 1504, 64 => 1523);
   Description_Lengths : constant array (Command_Position) of Description_Length :=
     (1 => 27, 2 => 15, 3 => 32, 4 => 43, 5 => 37, 6 => 42, 7 => 22, 8 => 37, 9 => 16, 10 => 28, 11 => 39, 12 => 20,
      13 => 38, 14 => 20, 15 => 18, 16 => 49, 17 => 25, 18 => 48, 19 => 18, 20 => 16, 21 => 20, 22 => 0, 23 => 28,
      24 => 0, 25 => 18, 26 => 25, 27 => 35, 28 => 20, 29 => 14, 30 => 42, 31 => 26, 32 => 25, 33 => 15, 34 => 18,
      35 => 33, 36 => 13, 37 => 20, 38 => 18, 39 => 25, 40 => 0, 41 => 22, 42 => 14, 43 => 19, 44 => 38, 45 => 18,
      46 => 29, 47 => 27, 48 => 25, 49 => 11, 50 => 30, 51 => 37, 52 => 56, 53 => 16, 54 => 14, 55 => 34, 56 => 37,
      57 => 11, 58 => 11, 59 => 15, 60 => 12, 61 => 22, 62 => 21, 63 => 19, 64 => 19);
   Arguments_Starts : constant array (Command_Position) of Help_Start :=
     (1 => 1542, 2 => 1635, 3 => 1677, 4 => 1688, 5 => 1688, 6 => 0, 7 => 1704, 8 => 1709, 9 => 0, 10 => 1721,
      11 => 1729, 12 => 338, 13 => 0, 14 => 1780, 15 => 1729, 16 => 1798, 17 => 1806, 18 => 1834, 19 => 1688,
      20 => 0, 21 => 0, 22 => 1844, 23 => 0, 24 => 1862, 25 => 1698, 26 => 0, 27 => 0, 28 => 1881, 29 => 0,
      30 => 1896, 31 => 1913, 32 => 0, 33 => 1920, 34 => 0, 35 => 0, 36 => 1933, 37 => 1950, 38 => 0, 39 => 0,
      40 => 1977, 41 => 1977, 42 => 1977, 43 => 1977, 44 => 0, 45 => 1986, 46 => 0, 47 => 0, 48 => 1834, 49 => 0,
      50 => 2040, 51 => 2089, 52 => 2187, 53 => 0, 54 => 2265, 55 => 2281, 56 => 2292, 57 => 2307, 58 => 0, 59 => 0,
      60 => 0, 61 => 2417, 62 => 0, 63 => 2501, 64 => 2568);
   Arguments_Lengths : constant array (Command_Position) of Arguments_Length :=
     (1 => 93, 2 => 42, 3 => 11, 4 => 16, 5 => 16, 6 => 0, 7 => 5, 8 => 12, 9 => 0, 10 => 8, 11 => 51, 12 => 4,
      13 => 0, 14 => 18, 15 => 51, 16 => 8, 17 => 28, 18 => 10, 19 => 16, 20 => 0, 21 => 0, 22 => 18, 23 => 0,
      24 => 19, 25 => 6, 26 => 0, 27 => 0, 28 => 15, 29 => 0, 30 => 17, 31 => 7, 32 => 0, 33 => 13, 34 => 0,
      35 => 0, 36 => 17, 37 => 27, 38 => 0, 39 => 0, 40 => 9, 41 => 9, 42 => 9, 43 => 9, 44 => 0, 45 => 54, 46 => 0,
      47 => 0, 48 => 10, 49 => 0, 50 => 49, 51 => 98, 52 => 78, 53 => 0, 54 => 16, 55 => 11, 56 => 15, 57 => 110,
      58 => 0, 59 => 0, 60 => 0, 61 => 84, 62 => 0, 63 => 67, 64 => 216);

   --  help: the entry of every command the build has, or of those whose
   --  name or description holds the search, else the no-match error.
   procedure Help_Command (Into : in out Output; Search : String)
     with Global => null,
          Pre    => Search'First >= 1 and then Search'Last <= Line_Size
   is
      Any : Boolean := False;
   begin
      for P in Command_Position loop
         Help_Entry
           (Into, Search, Command_Name (P),
            Help_Text (Natural (Description_Starts (P)) + 1
                       .. Natural (Description_Starts (P)) + Natural (Description_Lengths (P))),
            Help_Text (Natural (Arguments_Starts (P)) + 1
                       .. Natural (Arguments_Starts (P)) + Natural (Arguments_Lengths (P))),
            Any);
      end loop;
      if Search'Length > 0 and then not Any then
         Put_Error (Into, "help: NO MATCHES FOR '");
         Put (Into, Search);
         Put (Into, "'###" & CRLF);
      end if;
   end Help_Command;

   --  The MCU's unique id as 24 hexadecimal digits.
   procedure Put_MCU_Id (Into : in out Output; Id : MCU_Words) is
   begin
      Put (Into, "mcu_id ");
      Put (Into, Hex_Text (Id (1), 8));
      Put (Into, Hex_Text (Id (2), 8));
      Put (Into, Hex_Text (Id (3), 8));
      Put (Into, CRLF);
   end Put_MCU_Id;

   --  vtx_info: each power level the transmitter reports with its power, or
   --  an error without a transmitter or without levels.
   procedure Vtx_Info_Command (Into : in out Output; Present : Boolean; Report : Power_Levels)
     with Global => null
   is
   begin
      if not Present then
         Put_Error (Into, "vtx_info: NO VTX###" & CRLF);
      elsif Report.Count = 0 then
         Put_Error (Into, "vtx_info: NO POWER VALUES DEFINED###" & CRLF);
      else
         for I in 1 .. Report.Count loop
            Put (Into, "level ");
            Put (Into, Decimal (Integer_64 (Report.Levels (I))));
            Put (Into, " dBm, power ");
            Put (Into, Decimal (Integer_64 (Report.Powers (I))));
            Put (Into, " mW" & CRLF);
         end loop;
      end if;
   end Vtx_Info_Command;

   --  rc_smoothing_info: the receiver's frame rate rounded to the nearest
   --  whole Hz, whether RC smoothing is on, and when it is, each running
   --  cutoff with whether its setting fixed it.
   procedure Rc_Smoothing_Info_Command (Into : in out Output; Smoothing_On : Boolean; Status : Smoothing_Status)
     with Global => null
   is
      function Origin (Manual : Boolean) return String is (if Manual then "(manual)" else "(auto)");
   begin
      if Status.Rate_Valid then
         Put (Into, "# Detected Rx frequency: ");
         Put (Into, Decimal (Integer_64 (Maths.Round_Half_Even (Status.Rate_Hz))));
         Put (Into, "Hz" & CRLF);
      else
         Put (Into, "# Detected Rx frequency: NO SIGNAL" & CRLF);
      end if;
      Put (Into, "# RC Smoothing: ");
      Put (Into, (if Smoothing_On then "ON" else "OFF"));
      Put (Into, CRLF);
      if Smoothing_On then
         Put (Into, "# Active setpoint and FF cutoff: ");
         Put (Into, Decimal (Integer_64 (Status.Setpoint_Cutoff_Hz)));
         Put (Into, "Hz ");
         Put (Into, Origin (Status.Setpoint_Manual));
         Put (Into, CRLF);
         Put (Into, "# Active throttle cutoff: ");
         Put (Into, Decimal (Integer_64 (Status.Throttle_Cutoff_Hz)));
         Put (Into, "Hz ");
         Put (Into, Origin (Status.Throttle_Manual));
         Put (Into, CRLF);
      end if;
   end Rc_Smoothing_Info_Command;

   --  dshot_telemetry_info: the driver's read and invalid reply counts and
   --  the cycles and microseconds of its direction change, a line per motor
   --  with its reply kinds, eRPM, RPM and Hz, invalid share, temperature,
   --  voltage, current, state events and debug values, then the decoder's
   --  edge times and the steps between them; or that the motors do not run
   --  DShot telemetry.
   procedure Dshot_Telemetry_Info_Command (Into : in out Output; Count : MSP_Motor_In.Motor_Count; S : DShot_Status)
     with Global => null
   is
      function Field (V : Integer_64; Width : Natural) return String is
        (CLI_Text.Right_Justified (Decimal (V), Width))
        with Pre => Width <= 64;

      function Two_Digits (N : Integer_64) return String is
        (String'(Character'Val (Character'Pos ('0') + Natural (N / 10)),
                 Character'Val (Character'Pos ('0') + Natural (N mod 10))))
        with Pre => N in 0 .. 99;

      function Kind (Received : Unsigned_8; Bit : Natural; Letter : Character) return Character is
        (if (Shift_Right (Received, Bit) and 1) /= 0 then Letter else '-');

      --  An RPM rounded as lrintf rounds it: ties to even below 2 ** 23,
      --  where every float above is whole.
      function Whole (X : DShot.Rpm_Value) return Integer_64 is
        (if X < 2.0 ** 23 then Integer_64 (Maths.Round_Half_Even (X)) else Integer_64 (X));

      Cycles : constant Unsigned_32 := S.Direction_Cycle - S.Interrupt_Cycle;
   begin
      if not S.Enabled then
         Put (Into, "Dshot telemetry not enabled" & CRLF);
         return;
      end if;
      Put (Into, "Dshot reads: ");
      Put (Into, Decimal (Integer_64 (S.Reads)));
      Put (Into, CRLF);
      Put (Into, "Dshot invalid pkts: ");
      Put (Into, Decimal (Integer_64 (S.Invalid_Replies)));
      Put (Into, CRLF);
      Put (Into, "Dshot directionChange cycles: ");
      Put (Into, Decimal (Integer_64 (Cycles)));
      Put (Into, ", micros: ");
      Put (Into, Decimal (Integer_64 (Cycles / S.Clock_Rate)));
      Put (Into, CRLF & CRLF);
      Put (Into, "Motor    Type   eRPM    RPM     Hz Invalid   TEMP    VCC   CURR  ST/EV   DBG1   DBG2   DBG3" & CRLF);
      Put (Into, "=====  ====== ====== ====== ====== ======= ====== ====== ====== ====== ====== ====== ======" & CRLF);
      for M in 0 .. Count - 1 loop
         declare
            T     : constant DShot.Motor_Telemetry := S.Telemetry.Motors (M);
            Rpm   : constant Integer_64 := Whole (S.Telemetry.Rpm (M)) mod 2 ** 16;
            Volts : constant Integer_64 := Integer_64 (T.Values (DShot.Voltage));
         begin
            Put (Into, Field (Integer_64 (M) + 1, 5));
            Put (Into, "   ");
            Put (Into, "" & Kind (T.Received, 0, 'R'));
            Put (Into, "" & Kind (T.Received, 1, 'T'));
            Put (Into, "" & Kind (T.Received, 2, 'V'));
            Put (Into, "" & Kind (T.Received, 3, 'C'));
            Put (Into, "" & Kind (T.Received, 7, 'S'));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Erpm)) * 100, 6));
            Put (Into, " ");
            Put (Into, Field (Rpm, 6));
            Put (Into, " ");
            Put (Into, Field (Rpm / 60, 6));
            if (T.Received and 1) /= 0 then
               declare
                  Share : constant Integer_64 := Integer_64 (DShot.Invalid_Percent (S.Quality (M), True));
               begin
                  Put (Into, " ");
                  Put (Into, Field (Share / 100, 3));
                  Put (Into, ".");
                  Put (Into, Two_Digits (Share mod 100));
                  Put (Into, "%");
               end;
            else
               Put (Into, " NO DATA");
            end if;
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Temperature)), 6));
            Put (Into, " ");
            Put (Into, Field (Volts / 4, 3));
            Put (Into, ".");
            Put (Into, Two_Digits (25 * (Volts mod 4)));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Current)), 6));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.State_Events)), 6));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Debug_1)), 6));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Debug_2)), 6));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (T.Values (DShot.Debug_3)), 6));
            Put (Into, CRLF);
         end;
      end loop;
      Put (Into, CRLF);
      for E of S.Edges loop
         Put (Into, Field (Integer_64 (E), 0));
         Put (Into, " ");
      end loop;
      Put (Into, CRLF);
      for K in 2 .. Max_GCR_Edges loop
         Put (Into, Field (Integer_64 (S.Edges (K) - S.Edges (K - 1)), 0));
         Put (Into, " ");
      end loop;
      Put (Into, CRLF);
   end Dshot_Telemetry_Info_Command;

   --  motor: after the output in use, a motor's or, at output 255, every
   --  motor's disarmed value from the 1000 to 2000 range, converted for the
   --  motor protocol and truncated to a whole number; or the error for an
   --  output past the motors, a value out of range or other than two
   --  arguments. Arguments are the words between spaces, each read as the C
   --  library's atoi reads it.
   procedure Motor_Command (Into : in out Output; Env : Environment; Arguments : String; Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      All_Motors : constant := 255;
      Index      : Integer_32 := 0;
      Value      : Integer_32 := 0;
      Words      : Natural range 0 .. 3 := 0;
      P          : Positive := Arguments'First;
      Last       : Natural;
   begin
      if Arguments'Length = 0 then
         Put_Error (Into, "motor: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      loop
         pragma Loop_Invariant (P in Arguments'Range);
         pragma Loop_Invariant
           (if Words >= 1 then Index in 0 .. Integer_32 (Env.Motors) - 1 or else Index = All_Motors);
         pragma Loop_Variant (Increases => P);
         if Arguments (P) /= ' ' then
            Last := P;
            while Last < Arguments'Last and then Arguments (Last + 1) /= ' ' loop
               pragma Loop_Invariant (Last in P .. Arguments'Last - 1);
               pragma Loop_Variant (Increases => Last);
               Last := Last + 1;
            end loop;
            if Words = 0 then
               Index := CLI_Text.To_Integer (Arguments (P .. Last));
               if Index >= 0 and then Index < Integer_32 (Env.Motors) then
                  Put (Into, "Using output ");
                  Put (Into, Decimal (Integer_64 (Index)));
                  Put (Into, "." & CRLF);
               elsif Index = All_Motors then
                  Put (Into, "Using all outputs." & CRLF);
               else
                  Put_Error
                    (Into, "motor: INVALID OUTPUT NUMBER. RANGE: 0 - " & Decimal (Integer_64 (Env.Motors) - 1) & ".###"
                           & CRLF);
                  return;
               end if;
            elsif Words = 1 then
               Value := CLI_Text.To_Integer (Arguments (P .. Last));
            end if;
            Words := Natural'Min (Words + 1, 3);
            P := Last;
         end if;
         exit when P = Arguments'Last;
         P := P + 1;
      end loop;
      if Words /= 2 then
         Put_Error (Into, "motor: INVALID ARGUMENT COUNT###" & CRLF);
      elsif Value < 1_000 or else Value > 2_000 then
         Put_Error (Into, "motor: VALUE NOT BETWEEN 1000 AND 2000###" & CRLF);
      else
         declare
            Converted : constant Float :=
              MSP_Motor_In.From_External (Unsigned_16 (Value), Env.Motor_Device, Env.Three_D);
            Output_Value : constant Unsigned_32 := Unsigned_32 (Float'Truncation (Converted));
         begin
            Changes.Motor := True;
            Changes.Every_Motor := Index = All_Motors;
            Changes.Motor_Value := Float (Output_Value);
            if Index /= All_Motors then
               Changes.Motor_Index := Natural (Index);
               Put (Into, "motor ");
               Put (Into, Decimal (Integer_64 (Index)));
               Put (Into, ": ");
               Put (Into, Decimal (Integer_64 (Output_Value)));
               Put (Into, CRLF);
            else
               Put (Into, "all motors: ");
               Put (Into, Decimal (Integer_64 (Output_Value)));
               Put (Into, CRLF);
            end if;
         end;
      end if;
   end Motor_Command;

   --  play_sound: the beeper table's entry at the given index, or without
   --  one the entry after the one played last, the first after the last
   --  entry, with the beeper silenced before its sound; or the line for an
   --  index without an entry. Every entry has a name, so the search for a
   --  named entry stops at the first it tries.
   procedure Play_Sound_Command (Into : in out Output; Arguments : String; Changes : in out Effects)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
                 and then Arguments'First <= Arguments'Last + 1
   is
      I : Integer_32;
   begin
      if Arguments'Length = 0 then
         I := (if Into.Last_Sound < Beeper_Index'Last then Integer_32 (Into.Last_Sound) + 1 else 0);
      else
         I := CLI_Text.To_Integer (Arguments);
         if I not in 0 .. Integer_32 (Beeper_Index'Last) then
            Put (Into, "No sound for index ");
            Put (Into, Decimal (Integer_64 (I)));
            Put (Into, CRLF);
            return;
         end if;
      end if;
      Into.Last_Sound := Integer (I);
      Changes.Sound := True;
      Changes.Sound_Mode := Beeper_Mode (Beeper_Index (I));
      Put (Into, "Playing sound ");
      Put (Into, Decimal (Integer_64 (I)));
      Put (Into, ": ");
      Put (Into, Beeper_Name (Beeper_Index (I)));
      Put (Into, CRLF);
   end Play_Sound_Command;

   --  bind_rx: the receiver's bind started, or the error for a receiver
   --  without one.
   procedure Bind_Rx_Command (Into : in out Output; C : Configuration; Env : Environment; Changes : in out Effects)
     with Global => null
   is
      use type RX_Bind.Bind;
      B : constant RX_Bind.Bind :=
        RX_Bind.Bind_For (Env.Receiver_Source, Env.Serial_Protocol, Natural (C.Rx_Spi_Config.Rx_Spi_Protocol));
   begin
      if B = RX_Bind.No_Bind then
         Put_Error (Into, "bind_rx: Not supported.###" & CRLF);
      else
         Put (Into, "Binding..." & CRLF);
         Changes.Bind := B;
      end if;
   end Bind_Rx_Command;

   --  The hardware a gyro can be, in the order of the gyro hardware codes.
   subtype Gyro_Hardware_Index is Natural range 0 .. Gyro_Hardware_Count - 1;

   --  The gyro names in one text, each at its start for its length. The text ends with room for a
   --  longest one, so every slice stays within it by its types.
   Gyro_Name_Pool_Length : constant := 230;
   Gyro_Name_Text : constant String (1 .. Gyro_Name_Pool_Length + 11) :=
     "NONEAUTOMPU6050L3GD20MPU6000MPU6500MPU9250ICM20601ICM20602ICM20608GICM20649ICM20689ICM42605ICM42688PBMI1"
     & "60BMI270LSM6DSOLSM6DSV16XIIM42653ICM45605ICM45686ICM40609DIIM42652LSM6DSK320XICM42622PICM42686PICM56686B"
     & "MI423VIRTUALLSM6DSV32X           ";
   type Gyro_Name_Start is range 0 .. Gyro_Name_Pool_Length;
   type Gyro_Name_Length is range 4 .. 11;
   Gyro_Name_Starts : constant array (Gyro_Hardware_Index) of Gyro_Name_Start :=
     (0 => 0, 1 => 4, 2 => 8, 3 => 15, 4 => 21, 5 => 28, 6 => 35, 7 => 42, 8 => 50, 9 => 58, 10 => 67, 11 => 75,
      12 => 83, 13 => 91, 14 => 100, 15 => 106, 16 => 112, 17 => 119, 18 => 129, 19 => 137, 20 => 145, 21 => 153,
      22 => 162, 23 => 170, 24 => 181, 25 => 190, 26 => 199, 27 => 207, 28 => 213, 29 => 220);
   Gyro_Name_Lengths : constant array (Gyro_Hardware_Index) of Gyro_Name_Length :=
     (0 => 4, 1 => 4, 2 => 7, 3 => 6, 4 => 7, 5 => 7, 6 => 7, 7 => 8, 8 => 8, 9 => 9, 10 => 8, 11 => 8, 12 => 8,
      13 => 9, 14 => 6, 15 => 6, 16 => 7, 17 => 10, 18 => 8, 19 => 8, 20 => 8, 21 => 9, 22 => 8, 23 => 11, 24 => 9,
      25 => 9, 26 => 8, 27 => 6, 28 => 7, 29 => 10);

   function Gyro_Hardware_Name (I : Gyro_Hardware_Index) return String is
     (Gyro_Name_Text (Natural (Gyro_Name_Starts (I)) + 1
                      .. Natural (Gyro_Name_Starts (I)) + Natural (Gyro_Name_Lengths (I))));

   --  The sensor types sensor_hardware lists, with their names and the
   --  hardware each knows: the gyro's from its own list, the others' from
   --  their hardware settings' values, empty where the build has no such
   --  hardware.
   type Sensor_Type is
     (Gyro_Sensor, Acc_Sensor, Baro_Sensor, Mag_Sensor, Rangefinder_Sensor, Opticalflow_Sensor, Pitot_Sensor);

   function Sensor_Name (S : Sensor_Type) return String is
     (case S is
         when Gyro_Sensor => "gyro",
         when Acc_Sensor => "acc",
         when Baro_Sensor => "baro",
         when Mag_Sensor => "mag",
         when Rangefinder_Sensor => "rangefinder",
         when Opticalflow_Sensor => "opticalflow",
         when Pitot_Sensor => "pitot");

   function Hardware_Count (S : Sensor_Type) return Natural is
     (case S is
         when Gyro_Sensor => Gyro_Hardware_Count,
         when Acc_Sensor => Value_Count (Table_Acc_Hardware),
         when Baro_Sensor => Value_Count (Table_Baro_Hardware),
         when Mag_Sensor => Value_Count (Table_Mag_Hardware),
         when Rangefinder_Sensor => Value_Count (Table_Rangefinder_Hardware),
         when Opticalflow_Sensor => Value_Count (Table_Opticalflow_Hardware),
         when Pitot_Sensor => Value_Count (Table_Pitot_Hardware));

   function Hardware_Name (S : Sensor_Type; I : Natural) return String is
     (case S is
         when Gyro_Sensor => Gyro_Hardware_Name (I),
         when Acc_Sensor => Value_Name (Table_Acc_Hardware, I),
         when Baro_Sensor => Value_Name (Table_Baro_Hardware, I),
         when Mag_Sensor => Value_Name (Table_Mag_Hardware, I),
         when Rangefinder_Sensor => Value_Name (Table_Rangefinder_Hardware, I),
         when Opticalflow_Sensor => Value_Name (Table_Opticalflow_Hardware, I),
         when Pitot_Sensor => Value_Name (Table_Pitot_Hardware, I))
     with Pre => I < Hardware_Count (S);

   --  sensor_hardware: every sensor type with the hardware it knows, past
   --  the hardware the build lacks; or one type's hardware, a lacking one as
   --  an empty name between commas, for a type named without regard to case;
   --  or the error for any other argument.
   procedure Sensor_Hardware_Command (Into : in out Output; Arguments : String)
     with Global => null,
          Pre    => Arguments'First >= 1 and then Arguments'Last <= Line_Size
   is
   begin
      if Arguments'Length = 0 then
         for S in Sensor_Type loop
            pragma Loop_Invariant (S in Gyro_Sensor .. Pitot_Sensor);
            Put (Into, Sensor_Name (S));
            Put (Into, ": ");
            declare
               First : Boolean := True;
            begin
               for J in 0 .. Hardware_Count (S) - 1 loop
                  pragma Loop_Invariant (J in 0 .. Hardware_Count (S) - 1);
                  if Hardware_Name (S, J)'Length > 0 then
                     if not First then
                        Put (Into, ",");
                     end if;
                     Put (Into, Hardware_Name (S, J));
                     First := False;
                  end if;
               end loop;
            end;
            Put (Into, CRLF);
         end loop;
         return;
      end if;
      for S in Sensor_Type loop
         pragma Loop_Invariant (S in Gyro_Sensor .. Pitot_Sensor);
         if CLI_Text.Same_Ignoring_Case (Arguments, Sensor_Name (S)) then
            for J in 0 .. Hardware_Count (S) - 1 loop
               pragma Loop_Invariant (J in 0 .. Hardware_Count (S) - 1);
               if J > 0 then
                  Put (Into, ",");
               end if;
               Put (Into, Hardware_Name (S, J));
            end loop;
            Put (Into, CRLF);
            return;
         end if;
      end loop;
      Put_Error (Into, "sensor_hardware: INVALID SENSOR TYPE: ");
      Put (Into, Arguments);
      Put (Into, "###" & CRLF);
   end Sensor_Hardware_Command;

   Upper_Hex_Digits : constant String (1 .. 16) := "0123456789ABCDEF";

   --  A device's bus: the SPI bus by number, or the I2C bus by number with
   --  the device's address in two upper case hexadecimal digits.
   procedure Put_Device_Bus (Into : in out Output; Bus : Device_Bus)
     with Global => null
   is
   begin
      case Bus.Kind is
         when No_Bus =>
            null;
         when SPI_Bus =>
            Put (Into, " on SPI");
            Put (Into, Decimal (Integer_64 (Bus.Number)));
         when I2C_Bus =>
            Put (Into, " on I2C");
            Put (Into, Decimal (Integer_64 (Bus.Number)));
            Put (Into, " @0x");
            Put (Into, "" & Upper_Hex_Digits (Natural (Bus.Address / 16) + 1));
            Put (Into, "" & Upper_Hex_Digits (Natural (Bus.Address mod 16) + 1));
      end case;
   end Put_Device_Bus;

   --  A sensor's line: the detected hardware with its bus, unless the code
   --  is the automatic or the none choice or names no hardware of the
   --  build; or, for a sensor not detected, the configured hardware past
   --  those two choices, by name or, without one, by code.
   procedure Put_Sensor_Peripheral
     (Into : in out Output; Stem : String; S : Sensor_Type; Configured : Unsigned_8; Device : Sensor_Device)
     with Global => null
   is
      Count : constant Natural := Hardware_Count (S);
   begin
      if Device.Detected then
         if Natural (Device.Hardware) in 2 .. Count - 1
           and then Hardware_Name (S, Natural (Device.Hardware))'Length > 0
         then
            Put (Into, Stem);
            Put (Into, ": ");
            Put (Into, Hardware_Name (S, Natural (Device.Hardware)));
            Put_Device_Bus (Into, Device.Bus);
            Put (Into, CRLF);
         end if;
      elsif Natural (Configured) in 2 .. Count - 1 then
         Put (Into, Stem);
         Put (Into, ": ");
         if Hardware_Name (S, Natural (Configured))'Length > 0 then
            Put (Into, Hardware_Name (S, Natural (Configured)));
         else
            Put (Into, Decimal (Integer_64 (Configured)));
         end if;
         Put (Into, " configured, not detected" & CRLF);
      end if;
   end Put_Sensor_Peripheral;

   --  peripherals: each of the target's serial ports the board has, or one
   --  it lacks that a feature claims or that is a soft serial port, with
   --  why it lacks it, then the claims on it, those of the functions it
   --  opened with first and starred; each gyro of the build's positions
   --  that the configuration lists as detected, with its hardware, starred
   --  when enabled, and its bus; then the accelerometer, the barometer and
   --  the compass.
   procedure Peripherals_Command (Into : in out Output; C : Configuration; Ports : Port_List; Env : Environment)
     with Global => null,
          Pre    => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      package Map renames Serial_Feature_Map;
      Soft_Count : constant Natural := Config_Fix.Serial_Options.Soft_Serial_Ports;
   begin
      for I in Ports'Range loop
         declare
            Port   : constant Map.Port_Id := Ports (I);
            Status : constant Serial_Port_Status := Env.Serial_Ports (I - Ports'First + 1);
            Soft   : constant Boolean := Port >= Map.Soft_Serial_1 and then Port < Map.Soft_Serial_1 + Soft_Count;
            Claims : Map.Claim_Array;
            Count  : Map.Claim_Count;
            Open   : Unsigned_32 := 0;
            First  : Boolean := True;
         begin
            Map.Port_Claims
              (Config_Fix.Serial_Options, Config_Fix.Serial_Assignments (C), Port, Map.Max_Claims, Claims, Count);
            if Status.Available or else Count > 0 or else Soft then
               Put (Into, "serial ");
               Put (Into, CLI_Text.Port_Name (Integer_64 (Port), Ports));
               if Status.Available then
                  Open := Status.Open_Function;
                  Put (Into, ":");
               elsif Soft and then not Env.Soft_Serial then
                  Put (Into, " (feature SOFTSERIAL off):");
               else
                  Put (Into, " (no pins):");
               end if;
               for Active in reverse Boolean loop
                  for K in 1 .. Count loop
                     pragma Loop_Invariant (K in 1 .. Count);
                     if ((Claims (K).Mask and Open) /= 0) = Active then
                        Put (Into, (if First then " " else ", "));
                        Put (Into, Map.Claim_Name (Claims (K).Kind));
                        if Active then
                           Put (Into, "*");
                        end if;
                        First := False;
                     end if;
                  end loop;
               end loop;
               Put (Into, CRLF);
            end if;
         end;
      end loop;
      for Position in 0 .. Env.Gyro_Positions - 1 loop
         pragma Loop_Invariant (Position in 0 .. Max_Gyro_Positions - 1);
         if (C.Gyro_Config.Gyros_Detected and 2 ** Position) /= 0 then
            Put (Into, "gyro ");
            Put (Into, Decimal (Integer_64 (Position + 1)));
            Put (Into, ": ");
            Put (Into, Gyro_Hardware_Name (Env.Gyros (Position).Hardware));
            if (Env.Gyros_Enabled and 2 ** Position) /= 0 then
               Put (Into, "*");
            end if;
            Put_Device_Bus (Into, Env.Gyros (Position).Bus);
            Put (Into, CRLF);
         end if;
      end loop;
      Put_Sensor_Peripheral (Into, "acc", Acc_Sensor, C.Accelerometer_Config.Acc_Hardware, Env.Acc);
      Put_Sensor_Peripheral (Into, "baro", Baro_Sensor, C.Barometer_Config.Baro_Hardware, Env.Baro);
      Put_Sensor_Peripheral (Into, "mag", Mag_Sensor, C.Compass_Config.Mag_Hardware, Env.Mag);
   end Peripherals_Command;

   --  flash_erase: when the board has a flash file system, the whole erase,
   --  a dot for each poll before the flash is ready with a line end after
   --  every 122 dots, then the erase sound and the done line.
   procedure Flash_Erase_Command (Into : in out Output; Changes : in out Effects) is
      Ready : Boolean;
      Dots  : Natural := 0;
   begin
      if not Flash_Supported then
         return;
      end if;
      Put (Into, "Erasing, please wait ... " & CRLF);
      Flash_Erase_Completely;
      loop
         pragma Loop_Invariant (Dots <= 121);
         Flash_Ready (Ready);
         exit when Ready;
         Flash_Erase_Async;
         Put (Into, ".");
         if Dots > 120 then
            Dots := 0;
            Put (Into, CRLF);
         else
            Dots := Dots + 1;
         end if;
         Delay_Ms (100);
      end loop;
      Changes.Erase_Sound := True;
      Put (Into, CRLF);
      Put (Into, "Done." & CRLF);
   end Flash_Erase_Command;

   --  flash_scan: the board's verify of the whole flash, success or the
   --  failure error.
   procedure Flash_Scan_Command (Into : in out Output) is
      OK : Boolean;
   begin
      Put (Into, "Verifying" & CRLF);
      Flash_Verify (OK);
      if OK then
         Put (Into, "Success" & CRLF);
      else
         Put_Error (Into, "flash_scan: Failed###" & CRLF);
      end if;
   end Flash_Scan_Command;

   --  The position of the first space in a text, zero without one.
   function First_Space (Text : String) return Natural
     with Global => null,
          Post   => First_Space'Result = 0 or else First_Space'Result in Text'Range
   is
   begin
      for K in Text'Range loop
         if Text (K) = ' ' then
            return K;
         end if;
      end loop;
      return 0;
   end First_Space;

   --  flash_write: the text after the address and its spaces written at the
   --  address read as C's atoi reads it, or the argument count error without
   --  a space.
   procedure Flash_Write_Command (Into : in out Output; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      Address : constant Unsigned_32 := Unsigned_32 (Leading_Whole (Arguments) mod 2 ** 32);
      Space   : constant Natural := First_Space (Arguments);
      First   : Positive;
   begin
      if Space = 0 then
         Put_Error (Into, "flash_write: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      First := Space + 1;
      while First <= Arguments'Last and then Arguments (First) = ' ' loop
         pragma Loop_Invariant (First in Arguments'Range);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      Flash_Seek (Address);
      Flash_Write (Arguments (First .. Arguments'Last));
      Flash_Flush;
      Put (Into, "Wrote ");
      Put (Into, Decimal (Integer_64 (Arguments'Last - First + 1)));
      Put (Into, " bytes at ");
      Put (Into, Decimal (Integer_64 (Address)));
      Put (Into, "." & CRLF);
   end Flash_Write_Command;

   --  flash_read: the given count of bytes from the address, each number read
   --  as C's atoi reads it, in reads of up to 32 bytes until the count is
   --  done or a read takes none, or the argument count error without a
   --  space.
   procedure Flash_Read_Command (Into : in out Output; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last < Positive'Last
   is
      Address : Unsigned_32 := Unsigned_32 (Leading_Whole (Arguments) mod 2 ** 32);
      Space   : constant Natural := First_Space (Arguments);
      Length  : Unsigned_32;
      Data    : String (1 .. 32);
      Count   : Natural;
   begin
      if Space = 0 then
         Put_Error (Into, "flash_read: INVALID ARGUMENT COUNT###" & CRLF);
         return;
      end if;
      Length := Unsigned_32 (Leading_Whole (Arguments (Space .. Arguments'Last)) mod 2 ** 32);
      Put (Into, "Reading ");
      Put (Into, Decimal (Integer_64 (Length)));
      Put (Into, " bytes at ");
      Put (Into, Decimal (Integer_64 (Address)));
      Put (Into, ":" & CRLF);
      while Length > 0 loop
         pragma Loop_Invariant (Length > 0);
         Flash_Read (Address, Natural (Unsigned_32'Min (Length, 32)), Data, Count);
         Count := Natural'Min (Count, Natural (Unsigned_32'Min (Length, 32)));
         Put (Into, Data (1 .. Count));
         Length := Length - Unsigned_32 (Count);
         Address := Address + Unsigned_32 (Count);
         exit when Count = 0;
      end loop;
      Put (Into, CRLF);
   end Flash_Read_Command;

   --  gyroregisters: for each gyro position the configuration enables, an
   --  empty line and the gyro's heading, then its identity and configuration
   --  registers in upper case hexadecimal, the ICM-456xx registers with their
   --  addresses when the raw gyro is such a part.
   procedure Gyroregisters_Command (Into : in out Output; C : Configuration; Env : Environment) is

      procedure Put_Register (Label : String; Gyro : Natural; Register : Unsigned_8; Address : String) is
         Value : Unsigned_8;
      begin
         Gyro_Read_Register (Gyro, Register, Value);
         Put (Into, Label);
         if Value >= 16 then
            Put (Into, Upper_Hex_Digits (Natural (Value / 16) + 1 .. Natural (Value / 16) + 1));
         end if;
         Put (Into, Upper_Hex_Digits (Natural (Value mod 16) + 1 .. Natural (Value mod 16) + 1));
         Put (Into, Address);
         Put (Into, CRLF);
      end Put_Register;

   begin
      for Position in 0 .. Env.Gyro_Positions - 1 loop
         pragma Loop_Invariant (Position in 0 .. Max_Gyro_Positions - 1);
         if (C.Gyro_Config.Gyro_Enabled_Bitmask and 2 ** Position) /= 0 then
            Put (Into, CRLF & "# Gyro ");
            Put (Into, Decimal (Integer_64 (Position + 1)));
            Put (Into, CRLF);
            if Env.Raw_Gyro_ICM456 then
               Put_Register ("# WHO_AM_I      0x", Position, 16#72#, " (0x72)");
               Put_Register ("# PWR_MGMT0     0x", Position, 16#10#, " (0x10)");
               Put_Register ("# GYRO_CONFIG0  0x", Position, 16#1C#, " (0x1C)");
               Put_Register ("# ACCEL_CONFIG0 0x", Position, 16#1B#, " (0x1B)");
               Put_Register ("# INT1_STATUS0  0x", Position, 16#19#, " (0x19)");
            else
               Put_Register ("# WHO_AM_I    0x", Position, 16#75#, "");
               Put_Register ("# CONFIG      0x", Position, 16#1A#, "");
               Put_Register ("# GYRO_CONFIG 0x", Position, 16#1B#, "");
            end if;
         end if;
      end loop;
   end Gyroregisters_Command;

   --  The rates the baud rate indices name.
   Baud_Values : constant array (Serial_Feature_Map.Baud_Index) of Unsigned_32 :=
     (0, 9600, 19200, 38400, 57600, 115200, 230400, 250000, 400000, 460800, 500000, 921600, 1000000, 1500000,
      2000000, 2470000);

   --  A word as %d prints it, past 2147483647 as a negative number.
   function Signed_Text (V : Unsigned_32) return String is
     (Decimal (if V >= 2 ** 31 then Integer_64 (V) - 2 ** 32 else Integer_64 (V)))
     with Global => null,
          Post   => Signed_Text'Result'Length in 1 .. 21;

   --  A number with zeros before it up to a width, as %0Nd prints it.
   function Zero_Padded (V : Natural; Width : Positive) return String
     with Global => null,
          Pre    => Width <= 7,
          Post   => Zero_Padded'Result'Length in 1 .. 21
   is
      Text : constant String := Decimal (Integer_64 (V));
   begin
      if Text'Length >= Width then
         return Text;
      end if;
      return (1 .. Width - Text'Length => '0') & Text;
   end Zero_Padded;

   --  A word in lower case hexadecimal digits without leading zeros, as %x
   --  prints it.
   function Hex_Minimal (V : Unsigned_32) return String
     with Global => null,
          Post   => Hex_Minimal'Result'Length in 1 .. 8
   is
      Width : Positive := 1;
   begin
      while Width < 8 and then Shift_Right (V, 4 * Width) /= 0 loop
         pragma Loop_Invariant (Width in 1 .. 7);
         pragma Loop_Variant (Increases => Width);
         Width := Width + 1;
      end loop;
      return Hex_Text (V, Width);
   end Hex_Minimal;

   --  The system clock's sources by number, the PLL's two first.
   function Clock_Source_Name (I : Natural) return String is
     (case I is when 0 => "HSI", when 1 => "HSE", when 2 => "PLLP", when others => "PLLR");

   --  The u-blox platform's name, unknown before the receiver reports it.
   function GPS_Platform_Name (P : GPS_Frames.Platform) return String is
     (case P is
         when GPS_Frames.Undefined => "unknown", when GPS_Frames.M5 => "M5", when GPS_Frames.M6 => "M6",
         when GPS_Frames.M7 => "M7", when GPS_Frames.M8 => "M8", when GPS_Frames.M9 => "M9",
         when GPS_Frames.M10 => "M10");

   function Battery_State_Name (B : Adaflight.Battery.Battery_State) return String is
     (case B is
         when Adaflight.Battery.OK => "OK", when Adaflight.Battery.Warning => "WARNING",
         when Adaflight.Battery.Critical => "CRITICAL", when Adaflight.Battery.Not_Present => "NOT PRESENT",
         when Adaflight.Battery.Init => "INIT");

   --  The status lines of the MCU with its clock, the internal ADC's
   --  readings, the stack, the stored configuration and the bus devices.
   procedure Put_Status_Board (Into : in out Output; C : Configuration; S : System_Status)
     with Global => null
   is
   begin
      Put (Into, "MCU: ");
      Put (Into, Text_Of (S.MCU_Name));
      Put (Into, " CLK=");
      Put (Into, Decimal (Integer_64 (S.Core_Clock_Hz / 1_000_000)));
      Put (Into, "MHz");
      if S.Clock_Sources then
         Put (Into, " (");
         Put (Into, Clock_Source_Name (S.System_Source));
         Put (Into, (if S.System_Source < 2 then "" elsif S.PLL_Source = 0 then "-HSI" else "-HSE"));
         Put (Into, ")");
      end if;
      if S.Internal_ADC then
         Put (Into, ", Vref=");
         Put (Into, Decimal (Integer_64 (S.Vref_Mv / 1000)));
         Put (Into, ".");
         Put (Into, Zero_Padded (Natural ((S.Vref_Mv mod 1000) / 10), 2));
         Put (Into, "V, Core temp=");
         Put (Into, Decimal (Integer_64 (S.Core_Temp_C)));
         Put (Into, "degC");
      end if;
      Put (Into, CRLF);
      Put (Into, "STACK: ");
      Put (Into, Signed_Text (S.Stack_Total));
      Put (Into, "b (0x");
      Put (Into, Hex_Minimal (S.Stack_High));
      Put (Into, ")");
      if S.Stack_Check then
         Put (Into, " / ");
         Put (Into, Signed_Text (S.Stack_Used));
         Put (Into, "b");
      end if;
      Put (Into, CRLF);
      Put (Into, "CONFIG: ");
      Put (Into, (if C.System_Config.Configuration_State = 0 then "UNCONFIGURED" else "CONFIGURED"));
      Put (Into, " (");
      Put (Into, Decimal (Integer_64 (S.Config_Size)));
      Put (Into, "b / ");
      Put (Into, Signed_Text (S.Storage_Size));
      Put (Into, "b)" & CRLF);
      Put (Into, CRLF);
      Put (Into, "DEVICES DETECTED: SPI=");
      Put (Into, Decimal (Integer_64 (S.SPI_Devices)));
      Put (Into, ", I2C=");
      Put (Into, Decimal (Integer_64 (S.I2C_Devices)));
      Put (Into, " (");
      Put (Into, Decimal (Integer_64 (S.I2C_Errors)));
      Put (Into, " errors)" & CRLF);
   end Put_Status_Board;

   subtype Detected_Sensor is Sensor_Type range Acc_Sensor .. Pitot_Sensor;

   function Status_Sensor_Name (S : Detected_Sensor) return String is
     (case S is
         when Acc_Sensor => "ACC", when Baro_Sensor => "BARO", when Mag_Sensor => "MAG",
         when Rangefinder_Sensor => "RANGEFINDER", when Opticalflow_Sensor => "OPTICAL-FLOW",
         when Pitot_Sensor => "PITOT");

   function Device_Of (Env : Environment; S : Detected_Sensor) return Sensor_Device is
     (case S is
         when Acc_Sensor => Env.Acc, when Baro_Sensor => Env.Baro, when Mag_Sensor => Env.Mag,
         when Rangefinder_Sensor => Env.Rangefinder, when Opticalflow_Sensor => Env.Optical_Flow,
         when Pitot_Sensor => Env.Pitot);

   --  The status lines of the gyros the configuration lists as detected,
   --  with their hardware, whether they are enabled, locked to an interrupt,
   --  served by DMA or sharing their bus, and of the detected sensors with
   --  their hardware and the accelerometer's revision.
   procedure Put_Status_Sensors (Into : in out Output; C : Configuration; Env : Environment)
     with Global => null
   is
      Found : Boolean := False;
   begin
      Put (Into, "GYRO: ");
      for Position in 0 .. Env.Gyro_Positions - 1 loop
         pragma Loop_Invariant (Position in 0 .. Max_Gyro_Positions - 1);
         if (C.Gyro_Config.Gyros_Detected and 2 ** Position) /= 0 then
            if Found then
               Put (Into, ", ");
            end if;
            Found := True;
            Put (Into, "(");
            Put (Into, Decimal (Integer_64 (Position + 1)));
            Put (Into, ") ");
            Put (Into, Gyro_Hardware_Name (Env.Gyros (Position).Hardware));
            if (Env.Gyros_Enabled and 2 ** Position) /= 0 then
               Put (Into, " enabled");
            end if;
            if Env.Gyros (Position).Mode /= No_Interrupt then
               Put (Into, " locked");
            end if;
            if Env.Gyros (Position).Mode = Interrupt_DMA then
               Put (Into, " dma");
            end if;
            if Env.Gyros (Position).Bus_Devices > 1 then
               Put (Into, " shared");
            end if;
         end if;
      end loop;
      if not Found then
         Put (Into, "None");
      end if;
      Put (Into, CRLF);
      for S in Detected_Sensor loop
         pragma Loop_Invariant (S in Acc_Sensor .. Pitot_Sensor);
         declare
            D : constant Sensor_Device := Device_Of (Env, S);
         begin
            if D.Detected and then Natural (D.Hardware) < Hardware_Count (S) then
               Put (Into, Status_Sensor_Name (S));
               Put (Into, ": ");
               Put (Into, Hardware_Name (S, Natural (D.Hardware)));
               if S = Acc_Sensor and then Env.Acc_Revision /= 0 then
                  Put (Into, ".");
                  Put (Into, "" & Character'Val (Env.Acc_Revision));
               end if;
               Put (Into, CRLF);
            end if;
         end;
      end loop;
   end Put_Status_Sensors;

   --  The status line of the GPS receiver: whether it is connected, the
   --  provider without a port or the port with its actual and set baud
   --  rates and whether it is configured, the u-blox platform, and while it
   --  delivers data the satellites, their mean signal, the dilutions, the
   --  position and the time.
   procedure Put_Status_GPS
     (Into : in out Output; C : Configuration; Ports : Port_List; Enabled : Boolean; G : GPS_Status)
     with Global => null,
          Pre    => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      use type GPS_Link.Link_State;
      Provider : constant Natural := Natural (C.Gps_Config.Provider);
   begin
      Put (Into, "GPS: ");
      if not Enabled then
         Put (Into, "NOT ENABLED" & CRLF);
         return;
      end if;
      Put (Into, (if G.State >= GPS_Link.Configure then "connected, " else "NOT CONNECTED, "));
      if Provider in 2 .. 4 then
         if Provider < Value_Count (Table_Gps_Provider) then
            Put (Into, Value_Name (Table_Gps_Provider, Provider));
         end if;
      else
         if C.Gps_Config.Gps_Uart = -1 then
            Put (Into, "NO PORT, ");
         else
            if CLI_Text.Port_Name (Integer_64 (C.Gps_Config.Gps_Uart), Ports)'Length > 0 then
               Put (Into, CLI_Text.Port_Name (Integer_64 (C.Gps_Config.Gps_Uart), Ports));
            else
               Put (Into, "INVALID");
            end if;
            Put (Into, " ");
            Put (Into, Decimal (Integer_64 (Baud_Values (G.Port_Baud))));
            Put (Into, " (set to ");
            if C.Gps_Config.Auto_Baud /= 0 then
               Put (Into, "AUTO");
            elsif Natural (C.Gps_Config.Gps_Baud) <= Serial_Feature_Map.Baud_Index'Last then
               Put (Into, Decimal (Integer_64 (Baud_Values (Natural (C.Gps_Config.Gps_Baud)))));
            end if;
            Put (Into, "), ");
         end if;
         if G.State <= GPS_Link.Configure then
            Put (Into, "NOT CONFIGURED");
         elsif C.Gps_Config.Auto_Config = 0 then
            Put (Into, "auto config OFF");
         else
            Put (Into, "configured");
         end if;
         if Provider = 1 then
            Put (Into, ", version =  ");
            Put (Into, GPS_Platform_Name (G.Platform));
         end if;
      end if;
      if G.State = GPS_Link.Receiving_Data then
         Put (Into, CRLF);
         Put (Into, "  sats: ");
         Put (Into, Decimal (Integer_64 (G.Satellites)));
         declare
            Sum   : Natural := 0;
            Count : Natural := 0;
         begin
            for I in 1 .. G.Channels loop
               pragma Loop_Invariant (Sum <= (I - 1) * 255 and then Count <= I - 1);
               if G.Signals (I) > 0 then
                  Sum := Sum + Natural (G.Signals (I));
                  Count := Count + 1;
               end if;
            end loop;
            if Count > 0 then
               Put (Into, ", signal: ");
               Put (Into, Decimal (Integer_64 (Sum / Count)));
               Put (Into, " dBHz");
            end if;
         end;
         if G.HDOP > 0 then
            Put (Into, ", hdop: ");
            Put (Into, Decimal (Integer_64 (G.HDOP / 100)));
            Put (Into, ".");
            Put (Into, Zero_Padded (Natural (G.HDOP mod 100), 2));
         end if;
         if G.VDOP > 0 then
            Put (Into, ", vdop: ");
            Put (Into, Decimal (Integer_64 (G.VDOP / 100)));
            Put (Into, ".");
            Put (Into, Zero_Padded (Natural (G.VDOP mod 100), 2));
         end if;
         if G.Fix then
            declare
               Lat : constant Integer_64 := Integer_64 (G.Latitude);
               Lon : constant Integer_64 := Integer_64 (G.Longitude);
               Alt : constant Integer_64 := Integer_64 (G.Altitude_Cm);
            begin
               Put (Into, ", pos: ");
               Put (Into, (if Lat < 0 then "-" else ""));
               Put (Into, Decimal (abs Lat / 10_000_000));
               Put (Into, ".");
               Put (Into, Zero_Padded (Natural (abs Lat mod 10_000_000), 7));
               Put (Into, " ");
               Put (Into, (if Lon < 0 then "-" else ""));
               Put (Into, Decimal (abs Lon / 10_000_000));
               Put (Into, ".");
               Put (Into, Zero_Padded (Natural (abs Lon mod 10_000_000), 7));
               Put (Into, ", alt: ");
               Put (Into, (if Alt < 0 then "-" else ""));
               Put (Into, Decimal (abs Alt / 100));
               Put (Into, ".");
               Put (Into, Zero_Padded (Natural (abs Alt mod 100), 2));
               Put (Into, "m");
            end;
         else
            Put (Into, ", pos: no fix");
         end if;
         if G.Time_Valid then
            Put (Into, ", ");
            Put (Into, Zero_Padded (Natural (G.Year), 4));
            Put (Into, "-");
            Put (Into, Zero_Padded (Natural (G.Month), 2));
            Put (Into, "-");
            Put (Into, Zero_Padded (Natural (G.Day), 2));
            Put (Into, "T");
            Put (Into, Zero_Padded (Natural (G.Hour), 2));
            Put (Into, ":");
            Put (Into, Zero_Padded (Natural (G.Minute), 2));
            Put (Into, ":");
            Put (Into, Zero_Padded (Natural (G.Second), 2));
            Put (Into, "Z");
         end if;
      end if;
      Put (Into, CRLF);
   end Put_Status_GPS;

   --  A task's average rate in hertz from its average period in tenths of a
   --  microsecond, zero without one.
   function Task_Rate (T : Scheduler.Task_Info) return Integer_64 is
     (if T.Average_Delta_10th = 0 then 0
      else Integer_64 (Maths.Round_Half_Even (1.0e7 / Float (T.Average_Delta_10th))))
     with Global => null;

   --  The status lines of the OSD, the SD card, the flash chip, the build
   --  key, the uptime with the local time, the load with the gyro, receiver
   --  and system rates, the battery and the reasons arming is disabled.
   procedure Put_Status_Run (Into : in out Output; C : Configuration; Env : Environment; Sched : Scheduler.State)
     with Global => null
   is
      S      : constant System_Status := Env.Status;
      Gyro   : constant Scheduler.Task_Info := Scheduler.Info (Sched, Scheduler.Gyro);
      System : constant Scheduler.Task_Info := Scheduler.Info (Sched, Scheduler.System);
   begin
      Put (Into, "OSD: ");
      if S.OSD_Device < Value_Count (Table_Osd_Displayport_Device) then
         Put (Into, Value_Name (Table_Osd_Displayport_Device, S.OSD_Device));
      end if;
      Put (Into, " ");
      if S.OSD_Port then
         Put (Into, "(");
         Put (Into, Decimal (Integer_64 (S.OSD_Columns)));
         Put (Into, " x ");
         Put (Into, Decimal (Integer_64 (S.OSD_Rows)));
         Put (Into, ")");
      end if;
      Put (Into, CRLF);
      SD_Info_Command (Into, C.Sdcard_Config.Mode, Env.SD_Card);
      if Env.Flash.JEDEC_Id /= 0 then
         Put (Into, "FLASH: JEDEC ID=0x");
         Put (Into, Hex_Text (Env.Flash.JEDEC_Id, 8));
         Put (Into, " ");
         Put (Into, Decimal (Integer_64 (Shift_Right (Env.Flash.Total_Size, 20))));
         Put (Into, "M" & CRLF);
      end if;
      if S.Has_Build_Key then
         Put (Into, CRLF);
         Put (Into, "BUILD KEY: ");
         Put (Into, Text_Of (S.Build_Key));
         if S.Has_Release_Name then
            Put (Into, " (");
            Put (Into, Text_Of (S.Release_Name));
            Put (Into, ")");
         end if;
         Put (Into, CRLF);
      end if;
      Put (Into, CRLF);
      Put (Into, "System Uptime: ");
      Put (Into, Decimal (Integer_64 (S.Uptime_Ms / 1000)));
      Put (Into, " seconds");
      if RTC.Has_Time (S.Clock) then
         declare
            Zone   : constant Integer_16 := C.Time_Config.Tz_Offset_Minutes;
            Text   : RTC.Formatted;
            Length : Natural;
            Valid  : Boolean;
         begin
            RTC.Format_Local
              (RTC.Time_To_Date (RTC.Get (S.Clock, S.Uptime_Ms)), (Zone => (if Zone in RTC.Zone_Minutes then Zone
                                                                              else 0)),
               Text, Length, Valid);
            pragma Unreferenced (Valid);
            Put (Into, ", Current Time: ");
            Put (Into, Text (1 .. Length));
         end;
      end if;
      Put (Into, CRLF);
      Put (Into, "CPU:");
      Put (Into, Decimal (Integer_64'Min (Integer_64 (Sched.Average_Load_Percent), 100)));
      Put (Into, "%, cycle time: ");
      Put (Into, Signed_Text ((Gyro.Average_Delta_10th + 5) / 10));
      Put (Into, ", GYRO rate: ");
      Put (Into, Decimal (Task_Rate (Gyro)));
      Put (Into, ", RX rate: ");
      Put (Into, Decimal (if Env.Smoothing.Rate_Valid then Integer_64 (Maths.Round_Half_Even (Env.Smoothing.Rate_Hz))
                          else 0));
      Put (Into, ", System rate: ");
      Put (Into, Decimal (Task_Rate (System)));
      Put (Into, CRLF);
      Put (Into, "Voltage: ");
      Put (Into, Decimal (Integer_64 (S.Battery_Voltage / 100)));
      Put (Into, ".");
      Put (Into, Zero_Padded (Natural (S.Battery_Voltage mod 100), 2));
      Put (Into, "V (");
      Put (Into, Decimal (Integer_64 (S.Battery_Cells)));
      Put (Into, "S battery - ");
      Put (Into, Battery_State_Name (S.Battery_State));
      Put (Into, ")" & CRLF);
      Put (Into, "Arming disable flags:");
      for R in Arming.Disable_Reason loop
         pragma Loop_Invariant (R in Arming.No_Gyro .. Arming.Arm_Switch);
         if S.Arming_Disabled (R) then
            Put (Into, " ");
            Put (Into, Arming.Disable_Name (R));
         end if;
      end loop;
      Put (Into, CRLF);
   end Put_Status_Run;

   --  status: the board, its sensors, the GPS receiver, and how it runs.
   procedure Status_Command
     (Into : in out Output; C : Configuration; Ports : Port_List; Env : Environment; Sched : Scheduler.State)
     with Global => null,
          Pre    => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
   begin
      Put_Status_Board (Into, C, Env.Status);
      Put_Status_Sensors (Into, C, Env);
      Put_Status_GPS (Into, C, Ports, Env.GPS_Enabled, Env.GPS);
      Put_Status_Run (Into, C, Env, Sched);
   end Status_Command;

   --  Whether a name starts with the filter, as strncmp over the filter's
   --  length compares them; an empty filter matches every name.
   function Name_Matches (Name : String; Filter : String) return Boolean is
     (Filter'Length = 0
      or else (Filter'Length <= Name'Length
               and then Name (Name'First .. Name'First + (Filter'Length - 1)) = Filter))
     with Global => null;

   --  A NAME=value line, the value in two parts, when the name matches the
   --  filter.
   procedure Put_Name_Value (Into : in out Output; Filter : String; Name : String; Value : String; Tail : String := "")
     with Global => null
   is
   begin
      if Name_Matches (Name, Filter) then
         Put (Into, Name);
         Put (Into, "=");
         Put (Into, Value);
         Put (Into, Tail);
         Put (Into, CRLF);
      end if;
   end Put_Name_Value;

   --  The board identifier's characters up to its first zero byte.
   function Identifier_Text (B : Config_Groups.Bytes_6) return String
     with Global => null,
          Post   => Identifier_Text'Result'Length <= 6
   is
      Text   : String (1 .. 6) := (others => ' ');
      Length : Natural := 0;
   begin
      for I in B'Range loop
         pragma Loop_Invariant (Length = I - B'First);
         exit when B (I) = 0;
         Length := Length + 1;
         Text (Length) := Character'Val (B (I));
      end loop;
      return Text (1 .. Length);
   end Identifier_Text;

   --  The env lines of the firmware, the build, the board's information,
   --  the build key and the release name.
   procedure Put_Env_Version
     (Into : in out Output; C : Configuration; Board : Board_State; Env : Environment; Filter : String)
     with Global => null
   is
   begin
      Put_Name_Value (Into, Filter, "FIRMWARE_NAME", Text_Of (Env.Firmware));
      Put_Name_Value (Into, Filter, "FIRMWARE_VERSION", Text_Of (Env.Version));
      Put_Name_Value (Into, Filter, "TARGET", Text_Of (Env.Target));
      Put_Name_Value (Into, Filter, "BOARD_IDENTIFIER", Identifier_Text (C.System_Config.Board_Identifier));
      Put_Name_Value (Into, Filter, "BUILD_DATE", Text_Of (Env.Build_Date));
      Put_Name_Value (Into, Filter, "BUILD_TIME", Text_Of (Env.Build_Time));
      Put_Name_Value (Into, Filter, "GIT_REVISION", Text_Of (Env.Revision));
      Put_Name_Value (Into, Filter, "MSP_API_VERSION", Decimal (MSP_Common_Out.API_Version_Major),
                      "." & Decimal (MSP_Common_Out.API_Version_Minor));
      if Board.Manufacturer.Length > 0 then
         Put_Name_Value (Into, Filter, "MANUFACTURER_ID", Text_Of (Board.Manufacturer));
      end if;
      if Board.Name.Length > 0 then
         Put_Name_Value (Into, Filter, "BOARD_NAME", Text_Of (Board.Name));
      end if;
      if Env.Status.Has_Build_Key then
         Put_Name_Value (Into, Filter, "BUILD_KEY", Text_Of (Env.Status.Build_Key));
      end if;
      if Env.Status.Has_Release_Name then
         Put_Name_Value (Into, Filter, "RELEASE_NAME", Text_Of (Env.Status.Release_Name));
      end if;
   end Put_Env_Version;

   --  The env lines of the MCU with its clock, the internal ADC's readings,
   --  the stack, the stored configuration and the bus devices.
   procedure Put_Env_Board (Into : in out Output; C : Configuration; S : System_Status; Filter : String)
     with Global => null
   is
   begin
      Put_Name_Value (Into, Filter, "MCU", Text_Of (S.MCU_Name));
      Put_Name_Value (Into, Filter, "CLK_MHZ", Decimal (Integer_64 (S.Core_Clock_Hz / 1_000_000)));
      if S.Clock_Sources then
         Put_Name_Value (Into, Filter, "SYSCLK_SOURCE", Clock_Source_Name (S.System_Source),
                         (if S.System_Source < 2 then "" elsif S.PLL_Source = 0 then "-HSI" else "-HSE"));
      end if;
      if S.Internal_ADC then
         Put_Name_Value (Into, Filter, "VREF_MV", Decimal (Integer_64 (S.Vref_Mv)));
         Put_Name_Value (Into, Filter, "CORE_TEMP_C", Decimal (Integer_64 (S.Core_Temp_C)));
      end if;
      Put_Name_Value (Into, Filter, "STACK_SIZE", Signed_Text (S.Stack_Total));
      Put_Name_Value (Into, Filter, "STACK_HIGH", "0x" & Hex_Minimal (S.Stack_High));
      if S.Stack_Check then
         Put_Name_Value (Into, Filter, "STACK_USED", Signed_Text (S.Stack_Used));
      end if;
      Put_Name_Value (Into, Filter, "CONFIG_STATE",
                      (if C.System_Config.Configuration_State = 0 then "UNCONFIGURED" else "CONFIGURED"));
      Put_Name_Value (Into, Filter, "CONFIG_SIZE", Decimal (Integer_64 (S.Config_Size)));
      Put_Name_Value (Into, Filter, "CONFIG_MAX_SIZE", Signed_Text (S.Storage_Size));
      Put_Name_Value (Into, Filter, "SPI_COUNT", Decimal (Integer_64 (S.SPI_Devices)));
      Put_Name_Value (Into, Filter, "I2C_COUNT", Decimal (Integer_64 (S.I2C_Devices)));
      Put_Name_Value (Into, Filter, "I2C_ERRORS", Decimal (Integer_64 (S.I2C_Errors)));
   end Put_Env_Board;

   function Env_Sensor_Name (S : Detected_Sensor) return String is
     (case S is
         when Acc_Sensor => "ACC_HW", when Baro_Sensor => "BARO_HW", when Mag_Sensor => "MAG_HW",
         when Rangefinder_Sensor => "RANGEFINDER_HW", when Opticalflow_Sensor => "OPTICAL_FLOW_HW",
         when Pitot_Sensor => "PITOT_HW");

   --  The env lines of the gyros the configuration lists as detected, their
   --  count, the detected sensors and the GPS receiver.
   procedure Put_Env_Sensors (Into : in out Output; C : Configuration; Env : Environment; Filter : String)
     with Global => null
   is
      use type GPS_Link.Link_State;
      Count : Natural := 0;
   begin
      for Position in 0 .. Env.Gyro_Positions - 1 loop
         pragma Loop_Invariant (Position in 0 .. Max_Gyro_Positions - 1 and then Count <= Position);
         if (C.Gyro_Config.Gyros_Detected and 2 ** Position) /= 0 then
            Count := Count + 1;
            Put_Name_Value (Into, Filter, "GYRO_" & Decimal (Integer_64 (Position + 1)) & "_HW",
                            Gyro_Hardware_Name (Env.Gyros (Position).Hardware));
         end if;
      end loop;
      Put_Name_Value (Into, Filter, "GYRO_COUNT", Decimal (Integer_64 (Count)));
      for S in Detected_Sensor loop
         pragma Loop_Invariant (S in Acc_Sensor .. Pitot_Sensor);
         declare
            D : constant Sensor_Device := Device_Of (Env, S);
         begin
            if D.Detected and then Natural (D.Hardware) < Hardware_Count (S) then
               Put_Name_Value (Into, Filter, Env_Sensor_Name (S), Hardware_Name (S, Natural (D.Hardware)));
            end if;
         end;
      end loop;
      Put_Name_Value (Into, Filter, "GPS_ENABLED", (if Env.GPS_Enabled then "ON" else "OFF"));
      if Env.GPS_Enabled then
         Put_Name_Value (Into, Filter, "GPS_CONNECTED", (if Env.GPS.State >= GPS_Link.Configure then "ON" else "OFF"));
         Put_Name_Value (Into, Filter, "GPS_CONFIGURED", (if Env.GPS.State > GPS_Link.Configure then "ON" else "OFF"));
         Put_Name_Value (Into, Filter, "GPS_VERSION", GPS_Platform_Name (Env.GPS.Platform));
      end if;
   end Put_Env_Sensors;

   --  The env lines of the OSD, the flash chip, the uptime with the local
   --  time, the load with the gyro, receiver and system rates, the battery
   --  and the reasons arming is disabled.
   procedure Put_Env_Run
     (Into : in out Output; C : Configuration; Env : Environment; Sched : Scheduler.State; Filter : String)
     with Global => null
   is
      S      : constant System_Status := Env.Status;
      Gyro   : constant Scheduler.Task_Info := Scheduler.Info (Sched, Scheduler.Gyro);
      System : constant Scheduler.Task_Info := Scheduler.Info (Sched, Scheduler.System);
      First  : Boolean := True;
   begin
      Put_Name_Value (Into, Filter, "OSD_DEVICE",
                      (if S.OSD_Device < Value_Count (Table_Osd_Displayport_Device)
                       then Value_Name (Table_Osd_Displayport_Device, S.OSD_Device) else ""));
      if S.OSD_Port then
         Put_Name_Value (Into, Filter, "OSD_COLS", Decimal (Integer_64 (S.OSD_Columns)));
         Put_Name_Value (Into, Filter, "OSD_ROWS", Decimal (Integer_64 (S.OSD_Rows)));
      end if;
      if Env.Flash.JEDEC_Id /= 0 then
         Put_Name_Value (Into, Filter, "FLASH_JEDEC_ID", "0x" & Hex_Text (Env.Flash.JEDEC_Id, 8));
         Put_Name_Value (Into, Filter, "FLASH_SIZE_MB", Decimal (Integer_64 (Shift_Right (Env.Flash.Total_Size, 20))));
      end if;
      Put_Name_Value (Into, Filter, "UPTIME_S", Decimal (Integer_64 (S.Uptime_Ms / 1000)));
      if RTC.Has_Time (S.Clock) then
         declare
            Zone   : constant Integer_16 := C.Time_Config.Tz_Offset_Minutes;
            Text   : RTC.Formatted;
            Length : Natural;
            Valid  : Boolean;
         begin
            RTC.Format_Local
              (RTC.Time_To_Date (RTC.Get (S.Clock, S.Uptime_Ms)), (Zone => (if Zone in RTC.Zone_Minutes then Zone
                                                                              else 0)),
               Text, Length, Valid);
            pragma Unreferenced (Valid);
            Put_Name_Value (Into, Filter, "CURRENT_TIME", Text (1 .. Length));
         end;
      end if;
      Put_Name_Value
        (Into, Filter, "CPU_LOAD_PCT", Decimal (Integer_64'Min (Integer_64 (Sched.Average_Load_Percent), 100)));
      Put_Name_Value (Into, Filter, "CYCLE_TIME_US", Signed_Text ((Gyro.Average_Delta_10th + 5) / 10));
      Put_Name_Value (Into, Filter, "GYRO_RATE_HZ", Decimal (Task_Rate (Gyro)));
      Put_Name_Value (Into, Filter, "RX_RATE_HZ",
                      Decimal (if Env.Smoothing.Rate_Valid
                               then Integer_64 (Maths.Round_Half_Even (Env.Smoothing.Rate_Hz)) else 0));
      Put_Name_Value (Into, Filter, "SYSTEM_RATE_HZ", Decimal (Task_Rate (System)));
      Put_Name_Value (Into, Filter, "VOLTAGE_V", Decimal (Integer_64 (S.Battery_Voltage / 100)),
                      "." & Zero_Padded (Natural (S.Battery_Voltage mod 100), 2));
      Put_Name_Value (Into, Filter, "BATTERY_CELLS", Decimal (Integer_64 (S.Battery_Cells)));
      Put_Name_Value (Into, Filter, "BATTERY_STATE", Battery_State_Name (S.Battery_State));
      if Name_Matches ("ARMING_DISABLE_FLAGS", Filter) then
         Put (Into, "ARMING_DISABLE_FLAGS=");
         for R in Arming.Disable_Reason loop
            pragma Loop_Invariant (R in Arming.No_Gyro .. Arming.Arm_Switch);
            if S.Arming_Disabled (R) then
               if not First then
                  Put (Into, " ");
               end if;
               Put (Into, Arming.Disable_Name (R));
               First := False;
            end if;
         end loop;
         Put (Into, CRLF);
      end if;
   end Put_Env_Run;

   --  env: the build, the board, its sensors and how it runs, one NAME=value
   --  line each, only the names that start with the text after the command
   --  when there is one.
   procedure Env_Command
     (Into  : in out Output;
      C     : Configuration;
      Board : Board_State;
      Env   : Environment;
      Sched : Scheduler.State;
      Text  : String)
     with Global => null,
          Pre    => Text'First >= 1 and then Text'Last < Positive'Last
   is
      First : Positive := Text'First;
   begin
      while First <= Text'Last and then Text (First) = ' ' loop
         pragma Loop_Invariant (First in Text'Range);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      Put_Env_Version (Into, C, Board, Env, Text (First .. Text'Last));
      Put_Env_Board (Into, C, Env.Status, Text (First .. Text'Last));
      Put_Env_Sensors (Into, C, Env, Text (First .. Text'Last));
      Put_Env_Run (Into, C, Env, Sched, Text (First .. Text'Last));
   end Env_Command;

   --  A signature as 64 hexadecimal digits.
   procedure Put_Signature_Digits (Into : in out Output; Signature : Signature_Bytes) is
   begin
      for B of Signature loop
         Put (Into, Hex_Text (Unsigned_32 (B), 2));
      end loop;
   end Put_Signature_Digits;

   --  The board's signature line: its 64 hexadecimal digits when it is set
   --  or a command changed it, nothing otherwise.
   procedure Put_Signature (Into : in out Output; Board : Board_State) is
   begin
      Put (Into, "signature ");
      if Board.Signature_Updated or else Board.Signature_Set then
         Put_Signature_Digits (Into, Board.Signature);
      end if;
      Put (Into, CRLF);
   end Put_Signature;

   --  Two hexadecimal digits as a byte: Stop is 3 when both characters are
   --  digits, else the position of the first character that is not one.
   --  The reference reads the pair as the C library reads a number, with
   --  spaces and a sign allowed before the digits (finding F175).
   procedure Read_Hex_Pair (Pair : String; Value : out Unsigned_8; Stop : out Positive)
     with Pre => Pair'First = 1 and then Pair'Last = 2, Post => Stop in 1 .. 3
   is
      function Digit (C : Character) return Unsigned_8 is
        (case C is
            when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
            when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
            when others => Character'Pos (C) - Character'Pos ('A') + 10)
        with Pre => C in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F';
   begin
      Value := 0;
      Stop := 3;
      for K in 1 .. 2 loop
         if Pair (K) not in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' then
            Stop := K;
            return;
         end if;
      end loop;
      Value := Digit (Pair (1)) * 16 + Digit (Pair (2));
   end Read_Hex_Pair;

   --  signature: the board's signature, after a new one of 64 hexadecimal
   --  digits is taken while no signature is stored; a different signature
   --  for a stored one is the error.
   procedure Signature_Command (Into : in out Output; Board : in out Board_State; Arguments : String)
     with Pre => Arguments'Last < Positive'Last
   is
      use type Board_Info.Signature_Bytes;
      New_Signature : Signature_Bytes := (others => 0);
   begin
      if Arguments'Length > 0 then
         if Arguments'Length /= 2 * Signature_Bytes'Length then
            Put_Error (Into, "signature: INVALID LENGTH: ");
            Put (Into, Decimal (Integer_64 (Arguments'Length)));
            Put (Into, " (EXPECTED: 64)###" & CRLF);
            return;
         end if;
         for I in New_Signature'Range loop
            pragma Loop_Invariant (Arguments'Length = 2 * Signature_Bytes'Length);
            declare
               Pair  : constant String (1 .. 2) :=
                 (Arguments (Arguments'First + 2 * I), Arguments (Arguments'First + 2 * I + 1));
               Value : Unsigned_8;
               Stop  : Positive;
            begin
               Read_Hex_Pair (Pair, Value, Stop);
               if Stop /= 3 then
                  Put_Error (Into, "signature: INVALID CHARACTER FOUND: ");
                  Put (Into, "" & Pair (Stop));
                  Put (Into, "###" & CRLF);
                  return;
               end if;
               New_Signature (I) := Value;
            end;
         end loop;
         if Board.Signature_Set and then New_Signature /= Board.Signature then
            Put_Error (Into, "signature: SIGNATURE CANNOT BE CHANGED. CURRENT VALUE: '");
            Put_Signature_Digits (Into, Board.Signature);
            Put (Into, "'###" & CRLF);
            return;
         end if;
         if not Board.Signature_Set then
            Board.Signature := New_Signature;
            Board.Signature_Updated := True;
            Put_Hash_Line (Into, "Set signature.");
         end if;
      end if;
      Put_Signature (Into, Board);
   end Signature_Command;

   --  Every PID profile, the selected PID profile, every rate profile and
   --  every battery profile; unless bare, the selected profiles restored and
   --  a save without its line end.
   procedure Dump_Every_Profile
     (Into : in out Output; C : Configuration; Command : String; Mode : Dump_Mode; Bare : Boolean; Ports : Port_List)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
   begin
      for Index in 0 .. Pid_Profile_Record_List_4'Length - 1 loop
         Dump_Profile (Into, C, PID, Index, Command, Mode, Ports);
      end loop;
      if not Bare then
         Put_Hash_Line (Into, "restore original profile selection");
         Put (Into, "profile ");
         Put (Into, Decimal (Integer_64 (C.System_Config.Pid_Profile_Index)));
         Put (Into, CRLF);
      end if;
      for Index in 0 .. Control_Rate_Config_Record_List_4'Length - 1 loop
         Dump_Profile (Into, C, Rate, Index, Command, Mode, Ports);
      end loop;
      for Index in 0 .. Battery_Profile_Record_List_3'Length - 1 loop
         Dump_Profile (Into, C, Battery, Index, Command, Mode, Ports);
      end loop;
      if not Bare then
         Put_Hash_Line (Into, "restore original rateprofile selection");
         Put (Into, "rateprofile ");
         Put (Into, Decimal (Integer_64 (C.System_Config.Active_Rate_Profile)));
         Put (Into, CRLF);
         Put_Hash_Line (Into, "restore original battery_profile selection");
         Put (Into, "battery_profile ");
         Put (Into, Decimal (Integer_64 (C.System_Config.Active_Battery_Profile)));
         Put (Into, CRLF);
         Put_Hash_Line (Into, "save configuration");
         Put (Into, "save");
      end if;
   end Dump_Every_Profile;

   --  The DMA streams, each with the motor it drives or free.
   procedure Put_DMA (Into : in out Output; Env : Environment)
     with Global => null
   is
   begin
      Put (Into, CRLF & "Currently active DMA:" & CRLF & "--------------------" & CRLF);
      for K in Env.DMA_Motors'Range loop
         pragma Loop_Invariant (True);
         Put (Into, "DMA");
         Put (Into, Decimal (Integer_64 ((K - 1) / 8 + 1)));
         Put (Into, " Stream ");
         Put (Into, Decimal (Integer_64 ((K - 1) mod 8)));
         Put (Into, ":");
         if Env.DMA_Motors (K) > 0 then
            Put (Into, " MOTOR ");
            Put (Into, Decimal (Integer_64 (Env.DMA_Motors (K))));
            Put (Into, CRLF);
         else
            Put (Into, " FREE" & CRLF);
         end if;
      end loop;
   end Put_DMA;

   --  A pin as its port's letter and its number in two digits.
   function Pin_Text (T : Unsigned_8) return String is
     ((Character'Val (Character'Pos ('A') + Natural (T / 16) - 1),
       Character'Val (Character'Pos ('0') + Natural (T mod 16 / 10)),
       Character'Val (Character'Pos ('0') + Natural (T mod 16 mod 10))))
     with Post => Pin_Text'Result'First = 1 and then Pin_Text'Result'Length = 3;

   --  The resources, each pin a line: for a dump against the default
   --  configuration under the section's heading, with a changed pin's default
   --  first after a number sign, and for the resource command only the pins
   --  set.
   procedure Put_Resources (Into : in out Output; C : Configuration; Mode : Dump_Mode; Dump : Boolean)
     with Global => null
   is
      package R renames CLI_Resources;
      Pending : Boolean := Dump;
   begin
      if Dump then
         Put_Heading (Into, Mode, False, "resources", Pending);
      end if;
      for O in R.Owner loop
         pragma Loop_Invariant (True);
         for I in 0 .. R.Count (O) - 1 loop
            pragma Loop_Invariant (True);
            declare
               Tag     : constant Unsigned_8 := R.Tag (C, O, I);
               Default : constant Unsigned_8 := (if Dump then R.Tag (Defaults, O, I) else 0);
               Equal   : constant Boolean := Tag = Default;
               Start   : constant String := "resource " & R.Name (O) & " " & Decimal (Integer_64 (I + 1)) & " ";
            begin
               if Dump then
                  Put_Heading (Into, Mode, not Equal, "resources", Pending);
                  if Shows_Default (Mode, Equal) then
                     Put (Into, "#");
                     Put (Into, Start);
                     Put (Into, (if Default /= 0 then Pin_Text (Default) else "NONE"));
                     Put (Into, CRLF);
                  end if;
               end if;
               if (Tag /= 0 or else Dump) and then Shows_Line (Mode, Equal) then
                  Put (Into, Start);
                  Put (Into, (if Tag /= 0 then Pin_Text (Tag) else "NONE"));
                  Put (Into, CRLF);
               end if;
            end;
         end loop;
      end loop;
   end Put_Resources;

   --  An owner's name, with its ordinal where it has more than one pin.
   function Owner_Text (O : CLI_Resources.Owner; I : Natural) return String is
     (CLI_Resources.Name (O) & (if CLI_Resources.Max_Index (O) > 0 then " " & Decimal (Integer_64 (I + 1)) else ""))
     with Pre  => I < CLI_Resources.Count (O),
          Post => Owner_Text'Result'First = 1 and then Owner_Text'Result'Length <= 45;

   --  Each other pin the new tag is set to noted, and cleared when it belongs
   --  to the same owner.
   procedure Resource_Check
     (Into : in out Output; C : in out Configuration; Set_Owner : CLI_Resources.Owner; Set_Index : Natural;
      New_Tag : Unsigned_8)
     with Global => null
   is
      package R renames CLI_Resources;
      use type R.Owner;
   begin
      for O in R.Owner loop
         pragma Loop_Invariant (True);
         for I in 0 .. R.Count (O) - 1 loop
            pragma Loop_Invariant (True);
            if R.Tag (C, O, I) = New_Tag and then not (O = Set_Owner and then I = Set_Index) then
               Put (Into, CRLF & "NOTE: ");
               Put (Into, Pin_Text (New_Tag));
               Put (Into, " already assigned to ");
               Put (Into, Owner_Text (O, I));
               if O = Set_Owner then
                  R.Set_Tag (C, O, I, 0);
                  Put (Into, ". ");
                  Put (Into, Owner_Text (O, I));
                  Put (Into, " disabled");
               end if;
               Put (Into, "." & CRLF);
            end if;
         end loop;
      end loop;
   end Resource_Check;

   --  resource: the pins set without arguments; the active assignments for
   --  show, no pin known, with the DMA streams after all; an owner's pin by
   --  name and ordinal, the ordinal left out for a single pin, as a port
   --  letter and number, or none to free it; the owner's pin without one.
   procedure Resource_Command (Into : in out Output; C : in out Configuration; Env : Environment; Arguments : String)
     with Pre => Arguments'First >= 1 and then Arguments'Last <= Line_Size
                 and then Arguments'First <= Arguments'Last + 1
   is
      package R renames CLI_Resources;
      Owner : R.Owner := R.Owner'First;
      Found : Boolean := False;
      Index : Natural := 0;

      --  The first position from From past the spaces.
      function Skip_Spaces (From : Positive) return Positive
        with Pre  => Arguments'First >= 1 and then Arguments'Last <= Line_Size
                     and then From in Arguments'First .. Arguments'Last + 1,
             Post => Skip_Spaces'Result in From .. Arguments'Last + 1
      is
         P : Positive := From;
      begin
         while P <= Arguments'Last and then Arguments (P) = ' ' loop
            pragma Loop_Invariant (P in From .. Arguments'Last);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         return P;
      end Skip_Spaces;

      --  The first position from From that is a space or past the end.
      function Word_End (From : Positive) return Positive
        with Pre  => Arguments'First >= 1 and then Arguments'Last <= Line_Size
                     and then From in Arguments'First .. Arguments'Last + 1,
             Post => Word_End'Result in From .. Arguments'Last + 1
      is
         P : Positive := From;
      begin
         while P <= Arguments'Last and then Arguments (P) /= ' ' loop
            pragma Loop_Invariant (P in From .. Arguments'Last);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
         return P;
      end Word_End;

      First : Positive := Skip_Spaces (Arguments'First);
      Last  : Natural := Word_End (First) - 1;
   begin
      if Last < First then
         Put_Resources (Into, C, Listing, Dump => False);
         return;
      end if;
      if CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "show") then
         Put (Into, "Currently active IO resource assignments:" & CRLF & "(reboot to update)" & CRLF);
         Put (Into, "--------------------" & CRLF);
         First := Skip_Spaces (Last + 1);
         Last := Word_End (First) - 1;
         if CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "all") then
            Put_DMA (Into, Env);
         end if;
         return;
      end if;
      for O in R.Owner loop
         if CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), R.Name (O)) then
            Owner := O;
            Found := True;
            exit;
         end if;
      end loop;
      if not Found then
         Put_Error (Into, "resource: INVALID RESOURCE NAME: '");
         Put (Into, Arguments (First .. Last));
         Put (Into, "'###" & CRLF);
         return;
      end if;
      First := Skip_Spaces (Last + 1);
      Last := Word_End (First) - 1;
      declare
         Have_Index : constant Boolean := Last >= First and then Arguments (First) in '0' .. '9';
      begin
         if R.Max_Index (Owner) > 0 or else Have_Index then
            declare
               Candidate : constant Integer_64 :=
                 (if Have_Index then Integer_64 (CLI_Text.To_Integer (Arguments (First .. Last))) - 1 else -1);
            begin
               if not Have_Index or else Candidate < 0 or else Candidate >= Integer_64 (R.Count (Owner)) then
                  Put_Error (Into, "resource: INDEX NOT BETWEEN 1 AND ");
                  Put (Into, Decimal (Integer_64 (R.Count (Owner))));
                  Put (Into, "###" & CRLF);
                  return;
               end if;
               Index := Natural (Candidate);
            end;
            First := Skip_Spaces (Last + 1);
            Last := Word_End (First) - 1;
         end if;
      end;
      if Last < First then
         declare
            Tag : constant Unsigned_8 := R.Tag (C, Owner, Index);
         begin
            Put (Into, "# resource ");
            Put (Into, R.Name (Owner));
            Put (Into, " ");
            Put (Into, Decimal (Integer_64 (Index + 1)));
            Put (Into, " ");
            Put (Into, (if Tag /= 0 then Pin_Text (Tag) else "NONE"));
            Put (Into, CRLF);
         end;
         return;
      end if;
      if CLI_Text.Same_Ignoring_Case (Arguments (First .. Last), "NONE") then
         R.Set_Tag (C, Owner, Index, 0);
         Put (Into, "Resource is freed" & CRLF);
         return;
      end if;
      declare
         Letter : constant Character := Arguments (First);
         Port   : constant Integer :=
           (if Letter >= 'a' then Character'Pos (Letter) - Character'Pos ('a')
            else Character'Pos (Letter) - Character'Pos ('A'));
         Pin    : Integer_32 := 0;
         Next   : Positive := First + 1;
      begin
         if Port in 0 .. 8 then
            CLI_Text.Parse_Signed (Arguments (First + 1 .. Last), Pin, Next);
         end if;
         if Port not in 0 .. 8 or else Next = First + 1 or else Pin not in 0 .. 15 then
            Put_Error (Into, "resource: Failed to parse '");
            Put (Into, Arguments (First .. Last));
            Put (Into, "' as pin###" & CRLF);
         elsif Port > 5 then
            Put_Error (Into, "resource: PARSING FAILED###" & CRLF);
         else
            declare
               Tag : constant Unsigned_8 := Unsigned_8 ((Port + 1) * 16) + Unsigned_8 (Pin);
            begin
               R.Set_Tag (C, Owner, Index, Tag);
               Resource_Check (Into, C, Owner, Index, Tag);
               Put (Into, CRLF & "Resource is set to ");
               Put (Into, Pin_Text (Tag));
               Put (Into, CRLF);
            end;
         end if;
      end;
   end Resource_Command;

   --  The master dump: the version line with the default board identifier,
   --  the command batch's start, the board's name and manufacturer, the craft
   --  name, the resources, the features, the sections from the mixer on, and
   --  the master settings, then the selected profiles and the batch's end. A
   --  bare dump leaves out the batch; a diff leaves out an empty board name,
   --  manufacturer and craft name. The hardware dump keeps the board's lines,
   --  the resources, the features and the hardware settings. The dump of every
   --  profile adds the MCU's id and the board's signature unless bare, and
   --  ends with every profile, for a diff after a reset to the defaults at the
   --  batch's start.
   procedure Dump_Master
     (Into : in out Output; C : Configuration; Env : Environment; Board : Board_State; Command : String;
      Mode : Dump_Mode; Bare : Boolean; Hardware_Only : Boolean; Every_Profile : Boolean; Ports : Port_List)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      Craft : constant String := Stored_Text (C.Pilot_Config.Craft_Name);
   begin
      Put_Hash_Line (Into, "version");
      Put_Version (Into, Env, Defaults.System_Config.Board_Identifier);
      if not Bare then
         Put_Hash_Line (Into, "start the command batch");
         Put (Into, "batch start" & CRLF);
         if Every_Profile and then Mode.Diff then
            Put_Hash_Line (Into, "reset configuration to default settings");
            Put (Into, "defaults nosave" & CRLF);
         end if;
      end if;
      Put (Into, CRLF);
      if not Mode.Diff or else Board.Name.Length > 0 then
         Put (Into, "board_name ");
         Put (Into, Text_Of (Board.Name));
         Put (Into, CRLF);
      end if;
      if not Mode.Diff or else Board.Manufacturer.Length > 0 then
         Put (Into, "manufacturer_id ");
         Put (Into, Text_Of (Board.Manufacturer));
         Put (Into, CRLF);
      end if;
      if Every_Profile and then not Bare then
         Put_MCU_Id (Into, Env.MCU_Id);
         Put_Signature (Into, Board);
      end if;
      if not Hardware_Only and then Shows_Line (Mode, Craft'Length = 0) then
         Put (Into, CRLF & "# name: ");
         Put (Into, (if Craft'Length = 0 then "-" else Craft));
         Put (Into, CRLF);
      end if;
      Put_Resources (Into, C, Mode, Dump => True);
      Put_Feature_Dump (Into, C.Feature_Config.Enabled_Features, Mode => Mode, Heading => "feature");
      if Hardware_Only then
         Dump_Values (Into, C, Hardware, Current (C), "master", Command, Mode, Ports);
      else
         Put_Sections (Into, C, Mode);
         Dump_Values (Into, C, Master, Current (C), "master", Command, Mode, Ports);
         if Every_Profile then
            Dump_Every_Profile (Into, C, Command, Mode, Bare, Ports);
         else
            Dump_Profile (Into, C, PID, Natural (C.System_Config.Pid_Profile_Index), Command, Mode, Ports);
            Dump_Profile (Into, C, Rate, Natural (C.System_Config.Active_Rate_Profile), Command, Mode, Ports);
            Dump_Profile (Into, C, Battery, Natural (C.System_Config.Active_Battery_Profile), Command, Mode, Ports);
         end if;
      end if;
      if not Bare and then not Every_Profile then
         Put_Hash_Line (Into, "end the command batch");
         Put (Into, "batch end" & CRLF);
      end if;
   end Dump_Master;

   --  dump or diff: a profile's or a rate profile's settings, or the master
   --  dump, the hardware dump or the dump of every profile, each with defaults
   --  after the option defaults, and the last three without the command batch
   --  after the option bare.
   procedure Print_Config
     (Into : in out Output; C : Configuration; Env : Environment; Board : Board_State; Buffer : Line_Buffer;
      Arguments : Positive; Command : String; Diff : Boolean; Ports : Port_List)
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
      Mode          : constant Dump_Mode := (Diff => Diff, Show_Defaults => Show_Defaults);
   begin
      if Profile_At > 0 or else Rates_At > 0 then
         Dump_Profile
           (Into, C, (if Profile_At > 0 then PID else Rate),
            Natural (if Profile_At > 0 then C.System_Config.Pid_Profile_Index else C.System_Config.Active_Rate_Profile),
            Command, Mode, Ports);
      else
         Dump_Master (Into, C, Env, Board, Command, Mode, Bare, Hardware_At > 0, All_At > 0, Ports);
      end if;
   end Print_Config;

   --  The scheduler determinism debug mode's number in the reference's table.
   Scheduler_Determinism : constant := 67;

   --  tasks: every queued task's number, name and rate, and with task
   --  statistics its peak and average execution times, peak and average
   --  loads, total time, late and run counts and anticipated time, then the
   --  check functions' line with their load
   --  over the time since the last run, the total load, and in the scheduler
   --  determinism debug mode the loop start and guard cycles. Each queued
   --  task's peak times reset after its line, the check functions' after
   --  theirs. Counts print as the C library's %d prints their 32-bit
   --  pattern.
   procedure Tasks_Command
     (Into : in out Output; Sys : System_Config_Record; Env : Environment; Sched : in out Scheduler.State)
     with Global => null
   is
      function As_Signed (U : Unsigned_32) return Integer_64 is
        (if U >= 2 ** 31 then Integer_64 (U) - 2 ** 32 else Integer_64 (U))
        with Post => As_Signed'Result in -2 ** 31 .. 2 ** 31 - 1;

      function Wrapped (X : Integer_64) return Integer_64 is
        ((X + 2 ** 31) mod 2 ** 32 - 2 ** 31)
        with Pre  => X in -2 ** 40 .. 2 ** 40,
             Post => Wrapped'Result in -2 ** 31 .. 2 ** 31 - 1;

      --  A load in tenths of a percent as the reference's float arithmetic
      --  and its conversion of the result to a count give it: the truncated
      --  value's low 32 bits.
      function Load_Tenths (Total_Since : Integer_64; Time_Since : Integer_64) return Unsigned_32
        with Pre => Total_Since in -2 ** 31 .. 2 ** 31 - 1 and then Time_Since in -2 ** 31 .. 2 ** 31 - 1
                    and then Time_Since /= 0
      is
         Ratio : constant Float := Float (Total_Since) * 1000.0 / Float (Time_Since);
      begin
         pragma Assert (abs Ratio <= 2.2e12);
         return Unsigned_32 (Integer_64 (Float'Truncation (Ratio)) mod 2 ** 32);
      end Load_Tenths;

      function Two_Digits (N : Natural) return String is
        (String'(Character'Val (Character'Pos ('0') + N / 10), Character'Val (Character'Pos ('0') + N mod 10)))
        with Pre  => N < 100,
             Post => Two_Digits'Result'First = 1 and then Two_Digits'Result'Length = 2;

      function Field (V : Integer_64; Width : Natural) return String is
        (CLI_Text.Right_Justified (Decimal (V), Width))
        with Pre => Width <= 64;

      Statistics : constant Boolean := Sys.Task_Statistics /= 0;
      Time_Since : constant Integer_64 := As_Signed (Env.Now_Us - Into.Last_Tasks_Us);
      Load_Sum   : Integer_64 := 0;
   begin
      if Statistics then
         Put (Into, "Task list             rate/hz  max/us  avg/us maxload avgload  total/ms   late    run reqd/us");
         Put (Into, CRLF);
      else
         Put (Into, "Task list" & CRLF);
      end if;
      for Id in Scheduler.Task_Id loop
         pragma Loop_Invariant (abs Load_Sum <= Integer_64 (Scheduler.Task_Id'Pos (Id)) * 2 ** 31);
         declare
            T : constant Scheduler.Task_Info := Scheduler.Info (Sched, Id);
         begin
            if T.Enabled then
               declare
                  Average_Load : constant Integer_64 := As_Signed (T.Average_Load_10th);
                  Max_Load     : constant Integer_64 := As_Signed (T.Max_Load_10th);
                  Frequency    : Integer_64 := 0;
               begin
                  if T.Average_Delta_10th /= 0 then
                     pragma Assert (Float (T.Average_Delta_10th) >= 1.0);
                     Frequency := Integer_64 (Maths.Round_Half_Even (1.0e7 / Float (T.Average_Delta_10th)));
                  end if;
                  Load_Sum := Load_Sum + Average_Load;
                  Put (Into, Two_Digits (Scheduler.Task_Id'Pos (Id)));
                  Put (Into, " - (");
                  Put (Into, CLI_Text.Right_Justified (Scheduler.Name (Id), 15));
                  Put (Into, ") ");
                  if Statistics then
                     Put (Into, Field (Frequency, 6));
                     Put (Into, " ");
                     Put (Into, Field (As_Signed (T.Max_Exec_Us), 7));
                     Put (Into, " ");
                     Put (Into, Field (Integer_64 (T.Average_Exec_10th / 10), 7));
                     Put (Into, " ");
                     Put (Into, Field (Max_Load / 10, 4));
                     Put (Into, ".");
                     Put (Into, Decimal (Max_Load rem 10));
                     Put (Into, "% ");
                     Put (Into, Field (Average_Load / 10, 4));
                     Put (Into, ".");
                     Put (Into, Decimal (Average_Load rem 10));
                     Put (Into, "% ");
                     Put (Into, Field (Integer_64 (T.Total_Exec_Us / 1000), 9));
                     Put (Into, " ");
                     Put (Into, Field (As_Signed (T.Late_Count), 6));
                     Put (Into, " ");
                     Put (Into, Field (As_Signed (T.Run_Count), 6));
                     Put (Into, " ");
                     Put (Into, Field (As_Signed (T.Exec_Time_Us), 7));
                     Put (Into, CRLF);
                  else
                     Put (Into, Field (Frequency, 6));
                     Put (Into, CRLF);
                  end if;
               end;
               Scheduler.Reset_Task_Max_Execution_Time (Sched, Id);
            end if;
         end;
      end loop;
      if Statistics then
         declare
            Checks      : constant Scheduler.Check_Info := Scheduler.Check_Functions (Sched);
            Total_Since : constant Integer_64 := As_Signed (Checks.Total_Exec_Us - Into.Last_Check_Total_Us);
            Load        : constant Unsigned_32 := (if Time_Since = 0 then 0 else Load_Tenths (Total_Since, Time_Since));
            Total       : constant Integer_64 := Wrapped (Load_Sum);
         begin
            Into.Last_Check_Total_Us := Checks.Total_Exec_Us;
            Put (Into, "Check Functions (RX, ...) ");
            Put (Into, Field (As_Signed (Checks.Max_Exec_Us), 11));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (Checks.Average_Exec_Us), 7));
            Put (Into, " ");
            Put (Into, Field (Integer_64 (Load / 10), 12));
            Put (Into, ".");
            Put (Into, Decimal (Integer_64 (Load mod 10)));
            Put (Into, "% ");
            Put (Into, Field (Integer_64 (Checks.Total_Exec_Us / 1000), 9));
            Put (Into, CRLF);
            Put (Into, "Total ");
            Put (Into, Field (Total / 10, 52));
            Put (Into, ".");
            Put (Into, Decimal (Total rem 10));
            Put (Into, "%" & CRLF);
            if Env.Debug_Mode = Scheduler_Determinism then
               Put (Into, "Scheduler start cycles ");
               Put (Into, Decimal (Integer_64 (Sched.Loop_Start_Cycles)));
               Put (Into, " guard cycles ");
               Put (Into, Decimal (Integer_64 (Sched.Guard_Cycles)));
               Put (Into, CRLF);
            end if;
            Scheduler.Reset_Check_Max_Execution_Time (Sched);
         end;
      end if;
      Into.Last_Tasks_Us := Env.Now_Us;
   end Tasks_Command;

   ------------------
   -- Process_Line --
   ------------------

   procedure Process_Line
     (Into : in out Output; C : in out Configuration; Line : String; Ports : Port_List; Env : Environment;
      Board : in out Board_State; Sched : in out Scheduler.State; Changes : out Effects)
   is
      Buffer    : Line_Buffer := (others => ASCII.NUL);
      Length    : Natural := 0;
      Kind      : Command_Kind;
      Arguments : Natural;
   begin
      Changes := (others => <>);
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
            Buffer (K .. Line_Size) := (others => ASCII.NUL);
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
            if Env.Interactive then
               Put_Error (Into, "input: UNKNOWN COMMAND, TRY 'HELP'###");
            else
               Put (Into, "ERR_CMD_NA: ");
               Put (Into, Buffer (1 .. Length));
               Put (Into, CRLF);
            end if;
         when Adjustment_Range_Command_Word =>
            Adjustment_Range_Command (Into, C, Text_At (Buffer, Arguments), Changes);
         when Aux_Command_Word =>
            Aux_Command (Into, C, Text_At (Buffer, Arguments), Changes);
         when Batch_Command_Word =>
            Batch_Command (Into, Text_At (Buffer, Arguments));
         when Battery_Profile_Command =>
            Profile_Command (Into, C, Battery, Text_At (Buffer, Arguments), Changes);
         when Beacon_Command =>
            Beeper_Command
              (Into, "beacon", C.Beeper_Config.Dshot_Beacon_Off_Flags, Beacon_Allowed, Text_At (Buffer, Arguments));
         when Board_Name_Command_Word =>
            Board_Text_Command
              (Into, "board_name", "BOARD_NAME", Board.Name, Board_Info.Board_Name_Length, Board.Information_Set,
               Board.Information_Updated, Text_At (Buffer, Arguments));
         when Manufacturer_Id_Command_Word =>
            Board_Text_Command
              (Into, "manufacturer_id", "MANUFACTURER_ID", Board.Manufacturer, Board_Info.Manufacturer_Length,
               Board.Information_Set, Board.Information_Updated, Text_At (Buffer, Arguments));
         when Signature_Command_Word =>
            Signature_Command (Into, Board, Text_At (Buffer, Arguments));
         when Bind_Rx_Command_Word =>
            Bind_Rx_Command (Into, C, Env, Changes);
         when Beeper_Command_Word =>
            Beeper_Command
              (Into, "beeper", C.Beeper_Config.Beeper_Off_Flags, Beeper_Allowed, Text_At (Buffer, Arguments));
         when Defaults_Command_Word =>
            Defaults_Command (Into, C, Board, Text_At (Buffer, Arguments), Changes);
         when Diff_Command =>
            Print_Config (Into, C, Env, Board, Buffer, Arguments, "diff", True, Ports);
         when Dma_Command_Word =>
            Put_DMA (Into, Env);
         when Exit_Command_Word =>
            Exit_Command (Into, Text_At (Buffer, Arguments), Changes);
         when Dump_Command =>
            Print_Config (Into, C, Env, Board, Buffer, Arguments, "dump", False, Ports);
         when Feature_Command_Word =>
            Feature_Command (Into, C, Text_At (Buffer, Arguments));
         when Get_Command =>
            Get (Into, C, "get", Text_At (Buffer, Arguments), Ports);
         when Help_Command_Word =>
            Help_Command (Into, Text_At (Buffer, Arguments));
         when Color_Command_Word =>
            Color_Command (Into, C.Led_Strip_Status_Mode_Config.Colors, Text_At (Buffer, Arguments));
         when Led_Command_Word =>
            Led_Command (Into, C.Led_Strip_Status_Mode_Config.Led_Configs, Text_At (Buffer, Arguments), Changes);
         when Mode_Color_Command_Word =>
            Mode_Color_Command (Into, C.Led_Strip_Status_Mode_Config, Text_At (Buffer, Arguments));
         when Map_Command_Word =>
            Map_Command (Into, C, Text_At (Buffer, Arguments));
         when MCU_Id_Command_Word =>
            Put_MCU_Id (Into, Env.MCU_Id);
         when Motor_Command_Word =>
            Motor_Command (Into, Env, Text_At (Buffer, Arguments), Changes);
         when Play_Sound_Command_Word =>
            Play_Sound_Command (Into, Text_At (Buffer, Arguments), Changes);
         when Sensor_Hardware_Command_Word =>
            Sensor_Hardware_Command (Into, Text_At (Buffer, Arguments));
         when Mixer_Command_Word =>
            Mixer_Command (Into, C.Mixer_Config.Mixer_Mode, Text_At (Buffer, Arguments));
         when Motor_Mix_Command_Word =>
            Motor_Mix_Command (Into, C.Custom_Motor_Mixer, Text_At (Buffer, Arguments));
         when Profile_Command =>
            Profile_Command (Into, C, PID, Text_At (Buffer, Arguments), Changes);
         when Rate_Profile_Command =>
            Profile_Command (Into, C, Rate, Text_At (Buffer, Arguments), Changes);
         when Rc_Smoothing_Info_Command_Word =>
            Rc_Smoothing_Info_Command (Into, C.Rx_Config.Rc_Smoothing /= 0, Env.Smoothing);
         when Resource_Command_Word =>
            Resource_Command (Into, C, Env, Text_At (Buffer, Arguments));
         when Dshot_Telemetry_Info_Command_Word =>
            Dshot_Telemetry_Info_Command (Into, Env.Motors, Env.DShot_Telemetry);
         when Dshotprog_Command_Word =>
            Dshotprog_Command (Into, Env, Text_At (Buffer, Arguments));
         when Escprog_Command_Word =>
            Escprog_Command (Into, Env, Text_At (Buffer, Arguments));
         when Gpspassthrough_Command_Word =>
            Gpspassthrough_Command (Into);
         when Gyroregisters_Command_Word =>
            Gyroregisters_Command (Into, C, Env);
         when Options_Command_Word =>
            Options_Command (Into, Env);
         when Peripherals_Command_Word =>
            Peripherals_Command (Into, C, Ports, Env);
         when Status_Command_Word =>
            Status_Command (Into, C, Ports, Env, Sched);
         when Env_Command_Word =>
            Env_Command (Into, C, Board, Env, Sched, Text_At (Buffer, Arguments));
         when Sd_Info_Command_Word =>
            SD_Info_Command (Into, C.Sdcard_Config.Mode, Env.SD_Card);
         when Bootloader_Command_Word =>
            Bootloader_Command (Into, Text_At (Buffer, Arguments), Changes);
         when MSC_Command_Word =>
            MSC_Command (Into, Env.MSC_Ready, C.Time_Config.Tz_Offset_Minutes, Text_At (Buffer, Arguments), Changes);
         when Flash_Info_Command_Word =>
            Flash_Info_Command (Into, Env.Flash);
         when Flash_Erase_Command_Word =>
            Flash_Erase_Command (Into, Changes);
         when Flash_Scan_Command_Word =>
            Flash_Scan_Command (Into);
         when Flash_Write_Command_Word =>
            Flash_Write_Command (Into, Text_At (Buffer, Arguments));
         when Flash_Read_Command_Word =>
            Flash_Read_Command (Into, Text_At (Buffer, Arguments));
         when Rx_Failsafe_Command =>
            Failsafe_Command (Into, C, Text_At (Buffer, Arguments));
         when Rx_Range_Command =>
            Range_Command (Into, C, Text_At (Buffer, Arguments));
         when Servo_Command_Word =>
            Servo_Command (Into, C.Servo_Params, Text_At (Buffer, Arguments));
         when Servo_Mix_Command_Word =>
            Servo_Mix_Command (Into, C.Custom_Servo_Mixers, C.Servo_Params, Text_At (Buffer, Arguments));
         when Save_Command_Word =>
            Save_Command (Into, C, Board, Text_At (Buffer, Arguments), Changes);
         when Serial_Command_Word =>
            Serial_Command (Into, C, Text_At (Buffer, Arguments), Ports);
         when Set_Command =>
            Set (Into, C, Text_At (Buffer, Arguments), Ports);
         when Simplified_Tuning_Command_Word =>
            Simplified_Tuning_Command (Into, C, Text_At (Buffer, Arguments));
         when Tasks_Command_Word =>
            Tasks_Command (Into, C.System_Config, Env, Sched);
         when Version_Command_Word =>
            Version_Command (Into, C, Env, Board);
         when Vtx_Command_Word =>
            Vtx_Command
              (Into, C.Vtx_Config.Vtx_Channel_Activation_Conditions, C.Vtx_Table_Config, Text_At (Buffer, Arguments));
         when Vtx_Info_Command_Word =>
            Vtx_Info_Command (Into, Env.VTX_Present, Env.VTX_Power);
         when Vtx_Table_Command_Word =>
            Vtx_Table_Command (Into, C.Vtx_Table_Config, Text_At (Buffer, Arguments));
         when Waypoint_Command_Word =>
            Waypoint_Command (Into, C.Flight_Plan_Config, Env.Navigation, Text_At (Buffer, Arguments));
      end case;
   end Process_Line;

end Adaflight.Command_Line;
