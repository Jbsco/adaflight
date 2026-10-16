with Adaflight.Settings_Table; use Adaflight.Settings_Table;

package body Adaflight.MSP_CLI_Setting with SPARK_Mode is
   use Interfaces;

   No_Reply : constant Reply_Text := (Length => 0, Text => (others => ' '));

   --  The profile a setting reads: its scope's, none outside the profiles.
   function Profile_Of (C : Configuration; S : Setting) return Natural is
     (case Profile_Count (S) is
         when 3 => Natural (C.System_Config.Active_Battery_Profile),
         when 4 =>
           (if Describe (S).Where = Rate_Profile then Natural (C.System_Config.Active_Rate_Profile)
            else Natural (C.System_Config.Pid_Profile_Index)),
         when others => 0)
     with Pre  => Valid_Profiles (C),
          Post => Profile_Of'Result < Profile_Count (S);

   --  The text after the reply's, as much of it as fits.
   procedure Append (Reply : in out Reply_Text; Text : String)
     with Global => null
   is
   begin
      for Ch of Text loop
         exit when Reply.Length = Max_Reply;
         Reply.Length := Reply.Length + 1;
         Reply.Text (Reply.Length) := Ch;
      end loop;
   end Append;

   --  The setting a name names, without regard to case.
   procedure Find (Text : String; Found : out Boolean; S : out Setting)
     with Global => null
   is
   begin
      for T in Setting loop
         if CLI_Text.Same_Ignoring_Case (Settings_Table.Name (T), Text) then
            Found := True;
            S := T;
            return;
         end if;
      end loop;
      Found := False;
      S := Setting'First;
   end Find;

   --  A setting's value as the command line prints it; OK is false for a
   --  lookup or port value without a name.
   procedure Append_Value
     (Reply : in out Reply_Text; C : Configuration; S : Setting; Profile : Natural; Ports : Port_List;
      OK : out Boolean)
     with Global => null,
          Pre    => Profile < Profile_Count (S) and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      I : constant Info := Describe (S);
      V : Integer_64;
   begin
      OK := True;
      if I.How = List then
         for K in 0 .. Element_Count (S) - 1 loop
            pragma Loop_Invariant (K in 0 .. Element_Count (S) - 1);
            if K > 0 then
               Append (Reply, ",");
            end if;
            Append (Reply, CLI_Text.Decimal (Get (C, S, Profile, K)));
         end loop;
         return;
      end if;
      V := Get (C, S, Profile);
      case I.How is
         when Direct =>
            Append (Reply, CLI_Text.Decimal (V));
         when Lookup =>
            if V >= 0 and then V < Integer_64 (Value_Count (I.Table))
              and then Value_Name (I.Table, Natural (V))'Length > 0
            then
               Append (Reply, Value_Name (I.Table, Natural (V)));
            else
               OK := False;
            end if;
         when Identifier =>
            if CLI_Text.Port_Name (V, Ports)'Length > 0 then
               Append (Reply, CLI_Text.Port_Name (V, Ports));
            else
               OK := False;
            end if;
         when Bitset =>
            Append (Reply, (if V /= 0 then "ON" else "OFF"));
         when Text =>
            declare
               T : constant String := Get_Text (C, S, Profile);
            begin
               if T'Length = 0 then
                  Append (Reply, "-");
               else
                  Append (Reply, T (T'First .. T'First + (Natural'Min (T'Length, I.Count) - 1)));
               end if;
            end;
         when List =>
            null;
      end case;
   end Append_Value;

   --  A named setting's reply, "name = value"; OK is false for no such
   --  setting or a value without text, and the reply is then empty.
   procedure Get_Reply
     (C : Configuration; Text : String; Ports : Port_List; Reply : out Reply_Text; OK : out Boolean)
     with Global => null,
          Pre    => Ports'Length <= Serial_Feature_Map.Max_Ports and then Valid_Profiles (C),
          Post   => (if not OK then Reply.Length = 0)
   is
      Found : Boolean;
      S     : Setting;
   begin
      Reply := No_Reply;
      Find (Text, Found, S);
      OK := Found;
      if not Found then
         return;
      end if;
      Append (Reply, Settings_Table.Name (S));
      Append (Reply, " = ");
      Append_Value (Reply, C, S, Profile_Of (C, S), Ports, OK);
      if not OK then
         Reply := No_Reply;
      end if;
   end Get_Reply;

   --  The characters the C library's strtol family skips before a number.
   function Is_Space (Ch : Character) return Boolean is
     (Ch in ' ' | ASCII.HT | ASCII.LF | ASCII.VT | ASCII.FF | ASCII.CR);

   --  The number at the start of a text as the strtol family reads it: white
   --  space, a sign, then decimal digits, held at a million millions; Next
   --  is past the digits, and Seen says there were any.
   procedure Read_Number (Text : String; Value : out Integer_64; Next : out Positive; Seen : out Boolean)
     with Global => null,
          Pre    => Text'First >= 1 and then Text'Last < Positive'Last and then Text'First <= Text'Last + 1,
          Post   => Value in -10 ** 12 .. 10 ** 12 and then Next in Text'First .. Text'Last + 1
                    and then (if Seen then Next > Text'First)
   is
      Negative : Boolean := False;
   begin
      Value := 0;
      Seen := False;
      Next := Text'First;
      while Next <= Text'Last and then Is_Space (Text (Next)) loop
         pragma Loop_Invariant (Next in Text'Range);
         pragma Loop_Variant (Increases => Next);
         Next := Next + 1;
      end loop;
      if Next <= Text'Last and then Text (Next) in '+' | '-' then
         Negative := Text (Next) = '-';
         Next := Next + 1;
      end if;
      while Next <= Text'Last and then Text (Next) in '0' .. '9' loop
         pragma Loop_Invariant (Next in Text'Range and then Value in 0 .. 10 ** 12);
         pragma Loop_Variant (Increases => Next);
         Value :=
           Integer_64'Min (10 ** 12, Value * 10 + Integer_64 (Character'Pos (Text (Next)) - Character'Pos ('0')));
         Seen := True;
         Next := Next + 1;
      end loop;
      if not Seen then
         Next := Text'First;
      end if;
      if Negative then
         Value := -Value;
      end if;
   end Read_Number;

   --  An array setting's elements from a text of numbers between commas,
   --  exactly as many as the array holds, each a number of the C library's
   --  strtoul for an unsigned element type and strtol otherwise, then each
   --  within its element type; OK is false, and nothing written, otherwise.
   procedure Write_Array
     (C : in out Configuration; S : Setting; Profile : Natural; Kind : Value_Type; Value : String; OK : out Boolean)
     with Global => null,
          Pre    => Profile < Profile_Count (S) and then Value'First >= 1 and then Value'Last < Positive'Last
                    and then Value'Length > 0
   is
      Max_Elements : constant := 50;
      Length       : constant Positive := Element_Count (S);
      Elements     : array (0 .. Max_Elements - 1) of Integer_64 := (others => 0);
      Count        : Natural range 0 .. Max_Elements := 0;
      P            : Positive := Value'First;
      N            : Integer_64;
      Next         : Positive;
      Seen         : Boolean;
      Unsigned     : constant Boolean := Kind in U8 | U16 | U32;
   begin
      OK := False;
      if Length > Max_Elements then
         return;
      end if;
      loop
         pragma Loop_Invariant (P in Value'First .. Value'Last + 1 and then Count <= Length);
         pragma Loop_Variant (Increases => P);
         declare
            Q : Positive := P;
         begin
            while Q <= Value'Last and then Value (Q) = ' ' loop
               pragma Loop_Invariant (Q in P .. Value'Last);
               pragma Loop_Variant (Increases => Q);
               Q := Q + 1;
            end loop;
            exit when Q > Value'Last;
            if Value (Q) = ',' or else Count >= Length or else (Unsigned and then Value (Q) = '-') then
               return;
            end if;
            Read_Number (Value (Q .. Value'Last), N, Next, Seen);
            if not Seen then
               return;
            end if;
            if (Unsigned and then N not in 0 .. 4_294_967_295)
              or else (not Unsigned and then N not in -2_147_483_648 .. 2_147_483_647)
            then
               return;
            end if;
            Elements (Count) := N;
            Count := Count + 1;
            while Next <= Value'Last and then Value (Next) = ' ' loop
               pragma Loop_Invariant (Next in Value'Range and then Next > Q);
               pragma Loop_Variant (Increases => Next);
               Next := Next + 1;
            end loop;
            if Next <= Value'Last and then Value (Next) /= ',' then
               return;
            end if;
            exit when Next > Value'Last;
            P := Next + 1;
         end;
      end loop;
      if Count /= Length or else Value (Value'Last) = ',' then
         return;
      end if;
      for K in 0 .. Length - 1 loop
         case Kind is
            when U8 =>
               if Elements (K) > 255 then
                  return;
               end if;
            when I8 =>
               if Elements (K) not in -128 .. 127 then
                  return;
               end if;
            when U16 =>
               if Elements (K) > 65_535 then
                  return;
               end if;
            when I16 =>
               if Elements (K) not in -32_768 .. 32_767 then
                  return;
               end if;
            when U32 | I32 =>
               null;
         end case;
      end loop;
      for K in 0 .. Length - 1 loop
         Config_Groups.Set (C, S, Elements (K), Profile, K);
      end loop;
      OK := True;
   end Write_Array;

   --  A setting's value from its text as the setting writer parses it; OK
   --  is false, and nothing written, for a text that does not parse.
   procedure Write_Value
     (C : in out Configuration; S : Setting; Profile : Natural; Value : String; Ports : Port_List; OK : out Boolean)
     with Global => null,
          Pre    => Profile < Profile_Count (S) and then Value'First >= 1 and then Value'Last < Positive'Last
                    and then Value'Length > 0 and then Ports'Length <= Serial_Feature_Map.Max_Ports
   is
      I      : constant Info := Describe (S);
      N      : Integer_64;
      Next   : Positive;
      Seen   : Boolean;
   begin
      OK := False;
      case I.How is
         when Direct =>
            if I.Kind = U32 and then Value (Value'First) = '-' then
               return;
            end if;
            Read_Number (Value, N, Next, Seen);
            if not Seen or else Next <= Value'Last then
               return;
            end if;
            case I.Kind is
               when U32 =>
                  if N < 0 or else N > I.Max then
                     return;
                  end if;
               when I32 =>
                  if N > I.Max or else N < -I.Max then
                     return;
                  end if;
               when U8 | I8 | U16 | I16 =>
                  if N < I.Min or else N > I.Max then
                     return;
                  end if;
            end case;
            Config_Groups.Set (C, S, N, Profile);
            OK := True;
         when Lookup | Bitset =>
            declare
               Table : constant Lookup_Table := (if I.How = Bitset then Table_Off_On else I.Table);
            begin
               for K in 0 .. Value_Count (Table) - 1 loop
                  pragma Loop_Invariant (K in 0 .. Value_Count (Table) - 1 and then not OK);
                  if Value_Name (Table, K)'Length > 0
                    and then CLI_Text.Same_Ignoring_Case (Value_Name (Table, K), Value)
                  then
                     Config_Groups.Set (C, S, Integer_64 (K), Profile);
                     OK := True;
                     return;
                  end if;
               end loop;
            end;
         when Identifier =>
            declare
               Found : Boolean;
               Id    : Integer_64;
            begin
               CLI_Text.Port_From_Name (Value, Ports, Found, Id);
               if Found then
                  Config_Groups.Set (C, S, Id, Profile);
                  OK := True;
               end if;
            end;
         when List =>
            Write_Array (C, S, Profile, I.Kind, Value, OK);
         when Text =>
            declare
               Stored    : constant String := Get_Text (C, S, Profile);
               Kept      : constant String :=
                 Stored (Stored'First .. Stored'First + (Natural'Min (Stored'Length, I.Count) - 1));
               Updatable : constant Boolean := not I.Write_Once or else Kept'Length = 0 or else Value = Kept;
            begin
               if Updatable and then Value'Length <= I.Count then
                  Config_Groups.Set_Text
                    (C, S, (if Value'Length >= I.Min_Length and then Value /= "-" then Value else ""), Profile);
                  OK := True;
               end if;
            end;
      end case;
   end Write_Value;

   --  "name = value": the name before the equals sign with its spaces cut
   --  after it, the value after it with spaces cut on both sides, neither
   --  empty, then the value written; OK is false, and nothing written,
   --  otherwise.
   procedure Set_By_Name
     (C : in out Configuration; Text : String; Eq : Positive; Ports : Port_List; OK : out Boolean)
     with Global => null,
          Pre    => Text'First = 1 and then Text'Last <= Max_Request and then Eq in Text'Range
                    and then Ports'Length <= Serial_Feature_Map.Max_Ports and then Valid_Profiles (C)
   is
      Name_Last : Natural := Eq - 1;
      First     : Positive := Eq + 1;
      Last      : Natural := Text'Last;
      Found     : Boolean;
      S         : Setting;
   begin
      OK := False;
      while Name_Last >= Text'First and then Text (Name_Last) = ' ' loop
         pragma Loop_Invariant (Name_Last in Text'First .. Eq - 1);
         pragma Loop_Variant (Decreases => Name_Last);
         Name_Last := Name_Last - 1;
      end loop;
      if Name_Last < Text'First then
         return;
      end if;
      while First <= Last and then Text (First) = ' ' loop
         pragma Loop_Invariant (First in Eq + 1 .. Last);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      while Last >= First and then Text (Last) = ' ' loop
         pragma Loop_Invariant (Last in First .. Text'Last);
         pragma Loop_Variant (Decreases => Last);
         Last := Last - 1;
      end loop;
      if Last < First then
         return;
      end if;
      Find (Text (Text'First .. Name_Last), Found, S);
      if Found then
         Write_Value (C, S, Profile_Of (C, S), Text (First .. Last), Ports, OK);
      end if;
   end Set_By_Name;

   -------------
   -- Process --
   -------------

   procedure Process (C : in out Configuration; Request : Byte_Array; Ports : Port_List; R : out Result;
                      Reply : out Reply_Text)
   is
      Text      : String (1 .. Max_Request) := (others => ' ');
      Length    : Natural := 0;
      Eq        : Natural := 0;
      OK          : Boolean;
      Ignore_Echo : Boolean;
      Name_Last   : Natural;
   begin
      Reply := No_Reply;
      R := Error;
      if Request'Length = 0 then
         return;
      end if;
      for K in Request'Range loop
         exit when Request (K) = 0;
         pragma Loop_Invariant (Length = K - Request'First);
         Length := Length + 1;
         Text (Length) := Character'Val (Request (K));
      end loop;
      for K in 1 .. Length loop
         if Text (K) = '=' then
            Eq := K;
            exit;
         end if;
      end loop;
      if Eq = 0 then
         Get_Reply (C, Text (1 .. Length), Ports, Reply, OK);
         if OK then
            R := Ack;
         end if;
         return;
      end if;
      Set_By_Name (C, Text (1 .. Length), Eq, Ports, OK);
      if not OK then
         return;
      end if;
      Name_Last := Eq - 1;
      while Name_Last >= 1 and then Text (Name_Last) = ' ' loop
         pragma Loop_Invariant (Name_Last in 1 .. Eq - 1);
         pragma Loop_Variant (Decreases => Name_Last);
         Name_Last := Name_Last - 1;
      end loop;
      if Valid_Profiles (C) then
         Get_Reply (C, Text (1 .. Name_Last), Ports, Reply, Ignore_Echo);
      end if;
      R := Ack;
   end Process;

   --  A setting's description, as much of it as fits.
   type Description is record
      Length : Info_Length := 0;
      Text   : String (1 .. Max_Info) := (others => ' ');
   end record;

   procedure Add (D : in out Description; Text : String)
     with Global => null
   is
   begin
      for Ch of Text loop
         exit when D.Length = Max_Info;
         D.Length := D.Length + 1;
         D.Text (D.Length) := Ch;
      end loop;
   end Add;

   --  The description: the parameter group, the type with its range, its
   --  values or its lengths, each on a line, then the default without a line
   --  end, at most 255 characters of it.
   procedure Describe_Setting (C : Configuration; S : Setting; Ports : Port_List; D : out Description)
     with Global => null,
          Pre    => Ports'Length <= Serial_Feature_Map.Max_Ports and then Valid_Profiles (C)
   is
      I            : constant Info := Describe (S);
      LF           : constant String := (1 => ASCII.LF);
      Default      : Reply_Text := No_Reply;
      Ignore_Named : Boolean;

      procedure Add_Range (Type_Name : String; Min, Max : Integer_64)
        with Global => (In_Out => D)
      is
      begin
         Add (D, "type=");
         Add (D, Type_Name);
         Add (D, LF & "min=");
         Add (D, CLI_Text.Decimal (Min));
         Add (D, LF & "max=");
         Add (D, CLI_Text.Decimal (Max));
         Add (D, LF);
      end Add_Range;
   begin
      D := (Length => 0, Text => (others => ' '));
      Add (D, "pgn=");
      Add (D, CLI_Text.Decimal (Integer_64 (I.Group)));
      Add (D, LF);
      case I.How is
         when Direct =>
            case I.Kind is
               when U32 =>
                  Add_Range ("uint32", 0, I.Max);
               when I32 =>
                  Add_Range ("int32", -I.Max, I.Max);
               when U8 =>
                  Add_Range ("uint8", I.Min, I.Max);
               when I8 =>
                  Add_Range ("int8", I.Min, I.Max);
               when U16 =>
                  Add_Range ("uint16", I.Min, I.Max);
               when I16 =>
                  Add_Range ("int16", I.Min, I.Max);
            end case;
         when Lookup =>
            Add (D, "type=lookup" & LF & "values=");
            declare
               First : Boolean := True;
            begin
               for K in 0 .. Value_Count (I.Table) - 1 loop
                  pragma Loop_Invariant (K in 0 .. Value_Count (I.Table) - 1);
                  if Value_Name (I.Table, K)'Length > 0 then
                     if not First then
                        Add (D, ",");
                     end if;
                     Add (D, Value_Name (I.Table, K));
                     First := False;
                  end if;
               end loop;
            end;
            Add (D, LF);
         when Identifier =>
            Add (D, "type=lookup" & LF & "values=NONE");
            for K in Ports'Range loop
               Add (D, ",");
               Add (D, CLI_Text.Port_Name (Integer_64 (Ports (K)), Ports));
            end loop;
            Add (D, LF);
         when Bitset =>
            Add (D, "type=bitset" & LF & "values=OFF,ON" & LF);
         when List =>
            Add (D, "type=");
            Add (D, (case I.Kind is
                        when U8 => "uint8[]", when I8 => "int8[]", when U16 => "uint16[]", when I16 => "int16[]",
                        when U32 => "uint32[]", when I32 => "int32[]"));
            Add (D, LF & "length=");
            Add (D, CLI_Text.Decimal (Integer_64 (Element_Count (S))));
            Add (D, LF);
         when Text =>
            Add (D, "type=string" & LF & "minlength=");
            Add (D, CLI_Text.Decimal (Integer_64 (I.Min_Length)));
            Add (D, LF & "maxlength=");
            Add (D, CLI_Text.Decimal (Integer_64 (I.Count)));
            Add (D, LF);
      end case;
      Add (D, "default=");
      Append_Value (Default, Config_Groups.Defaults, S, Profile_Of (C, S), Ports, Ignore_Named);
      Add (D, Default.Text (1 .. Natural'Min (Default.Length, 255)));
   end Describe_Setting;

   ------------------
   -- Setting_Info --
   ------------------

   procedure Setting_Info
     (C : Configuration; Request : Byte_Array; Ports : Port_List; R : out Result; Reply : out Info_Reply)
   is
      Max_Info_Request : constant := 128;
      Name             : String (1 .. Max_Info_Request) := (others => ' ');
      Length           : Natural := 0;
      Offset           : Natural := 0;
      Found            : Boolean;
      S                : Setting;
      D                : Description;
   begin
      Reply := (Length => 0, Data => (others => 0));
      R := Error;
      if Request'Length = 0 or else Request'Length > Max_Info_Request then
         return;
      end if;
      for K in Request'Range loop
         exit when Request (K) = 0;
         pragma Loop_Invariant (Length = K - Request'First);
         Length := Length + 1;
         Name (Length) := Character'Val (Request (K));
      end loop;
      if Request'Length - Length - 1 >= 2 then
         Offset :=
           Natural (Request (Request'First + Length + 1)) + 256 * Natural (Request (Request'First + Length + 2));
      end if;
      Reply.Length := 2;
      Find (Name (1 .. Length), Found, S);
      if not Found then
         return;
      end if;
      Describe_Setting (C, S, Ports, D);
      Reply.Data (0) := Byte (D.Length mod 256);
      Reply.Data (1) := Byte (D.Length / 256);
      for K in 1 .. D.Length loop
         pragma Loop_Invariant (Reply.Length in 2 .. Max_Info);
         if K > Offset and then Reply.Length < Max_Info then
            Reply.Data (Reply.Length) := Byte (Character'Pos (D.Text (K)));
            Reply.Length := Reply.Length + 1;
         end if;
      end loop;
      R := Ack;
   end Setting_Info;

end Adaflight.MSP_CLI_Setting;
