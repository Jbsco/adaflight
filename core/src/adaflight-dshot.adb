package body Adaflight.DShot with SPARK_Mode is
   use Interfaces;

   --  The six linear maps as a factor and an offset each, the single
   --  precision values of the span ratio and of the output start less the
   --  scaled input start.
   From_Factor     : constant Float := 2.00100112;
   From_Offset     : constant Float := -1955.00208;
   From_Neg_Factor : constant Float := -2.00200391;
   From_Neg_Offset : constant Float := 3049.00391;
   From_Pos_Factor : constant Float := 2.00200391;
   From_Pos_Offset : constant Float := -1957.00781;
   To_Factor       : constant Float := 0.499749869;
   To_Offset       : constant Float := 977.012024;
   To_Neg_Factor   : constant Float := -0.4994995;
   To_Neg_Offset   : constant Float := 1522.97595;
   To_Pos_Factor   : constant Float := 0.4994995;
   To_Pos_Offset   : constant Float := 977.524536;

   Erpm_Per_Minute_Lsb : constant Float := 100.0 / 60.0;

   Invalid_Group : constant Unsigned_32 := 16#FFFF_FFFF#;

   type Group_Table is array (Unsigned_32 range 0 .. 31) of Unsigned_32;

   Groups : constant Group_Table :=
     (9 => 9, 10 => 10, 11 => 11, 13 => 13, 14 => 14, 15 => 15, 18 => 2, 19 => 3, 21 => 5, 22 => 6, 23 => 7,
      25 => 0, 26 => 8, 27 => 1, 29 => 4, 30 => 12, others => Invalid_Group);

   -----------
   -- Frame --
   -----------

   function Frame (Value : Frame_Value; Request_Telemetry : Boolean; Inverted_Checksum : Boolean)
                   return Unsigned_16 is
      Packet : constant Unsigned_16 := Shift_Left (Unsigned_16 (Value), 1) or (if Request_Telemetry then 1 else 0);
      Data   : Unsigned_16 := Packet;
      Csum   : Unsigned_16 := 0;
   begin
      for I in 1 .. 3 loop
         Csum := Csum xor Data;
         Data := Shift_Right (Data, 4);
      end loop;
      if Inverted_Checksum then
         Csum := not Csum;
      end if;
      return Shift_Left (Packet, 4) or (Csum and 16#F#);
   end Frame;

   -------------------
   -- From_External --
   -------------------

   function From_External (External : Unsigned_16; Two_Direction : Boolean) return Motor_Value is
      Clamped : constant Unsigned_16 := Unsigned_16'Max (1000, Unsigned_16'Min (2000, External));
      E       : constant Float := Float (Clamped);
   begin
      if Two_Direction then
         if Clamped = 1500 then
            return Float (Motor_Stop);
         elsif Clamped < 1500 then
            return E * From_Neg_Factor + From_Neg_Offset;
         else
            return E * From_Pos_Factor + From_Pos_Offset;
         end if;
      elsif Clamped = 1000 then
         return Float (Motor_Stop);
      else
         return E * From_Factor + From_Offset;
      end if;
   end From_External;

   -------------------
   -- Round_To_Even --
   -------------------

   --  The whole part of a value below a million.
   function Whole_Part (X : Float) return Natural is (Natural (Float'Truncation (X)))
     with Pre => X in 0.0 .. 1.0E6;

   --  The nearest whole number with a tie going to the even one. The
   --  fraction is the exact difference from the truncated value.
   function Round_To_Even (X : Float) return Natural
     with Pre  => X in 0.0 .. 1.0E6,
          Post => Round_To_Even'Result in Whole_Part (X) .. Whole_Part (X) + 1
   is
      Base     : constant Natural := Whole_Part (X);
      Fraction : constant Float := X - Float'Truncation (X);
   begin
      if Fraction > 0.5 or else (Fraction = 0.5 and then Base mod 2 = 1) then
         return Base + 1;
      else
         return Base;
      end if;
   end Round_To_Even;

   -----------------
   -- To_External --
   -----------------

   function To_External (Value : Motor_Value; Two_Direction : Boolean) return External_Value is
      E : Float;
   begin
      if Two_Direction then
         if Value < Float (Min_Throttle) then
            E := 1500.0;
         elsif Value <= Float (Forward_Min_Throttle - 1) then
            E := Value * To_Neg_Factor + To_Neg_Offset;
         else
            E := Value * To_Pos_Factor + To_Pos_Offset;
         end if;
      elsif Value < Float (Min_Throttle) then
         E := 1000.0;
      else
         E := Value * To_Factor + To_Offset;
      end if;
      pragma Assert (E in 999.0 .. 2000.6);
      return External_Value (Round_To_Even (E));
   end To_External;

   ---------------
   -- Endpoints --
   ---------------

   procedure Endpoints (Idle : Idle_Setting; Output_Limit : Unit_Interval; Two_Direction : Boolean;
                        Low, High, Disarm : out Motor_Value; Deadband_High, Deadband_Low : in out Float) is
      Limit_Offset  : constant Float := Float (Throttle_Span) * (1.0 - Output_Limit);
      Idle_Fraction : constant Float := 0.01 * (Float (Idle) * 0.01);
   begin
      Disarm := Float (Motor_Stop);
      if Two_Direction then
         Low := Float (Min_Throttle) + Idle_Fraction * Float (Forward_Min_Throttle - 1 - Min_Throttle);
         High := Float (Max_Throttle) - Limit_Offset / 2.0;
         Deadband_High := Float (Forward_Min_Throttle) + Idle_Fraction * Float (Max_Throttle - Forward_Min_Throttle);
         Deadband_Low := Float (Forward_Min_Throttle - 1) - Limit_Offset / 2.0;
      else
         Low := Float (Min_Throttle) + Idle_Fraction * Float (Throttle_Span);
         High := Float (Max_Throttle) - Limit_Offset;
      end if;
   end Endpoints;

   --------------------
   -- Decode_Samples --
   --------------------

   procedure Decode_Samples (D : in out Edge_Decoder; Buffer : Samples; Count : Sample_Count; Bit : Sample_Bit;
                             Now : Time_Us; Result : out Unsigned_32) is
      Mask      : constant Unsigned_16 := Shift_Left (1, Bit);
      Last      : Unsigned_16 := 0;
      Level     : Unsigned_16;
      Value     : Unsigned_32 := 0;
      P         : Integer := Integer (D.Preamble_Skip);
      Limit     : Integer := Count - Min_Valid_Samples;
      Start     : Natural;
      Old_P     : Natural;
      Bits      : Natural := 0;
      Len       : Positive;
      Remaining : Positive;
      Tail      : Integer;
   begin
      --  The preamble ends at the first low sample.
      while P < Limit loop
         pragma Loop_Invariant (P in 0 .. Limit - 1);
         pragma Loop_Variant (Increases => P);
         Level := Buffer (P) and Mask;
         P := P + 1;
         exit when Level = 0;
      end loop;
      if P >= Limit then
         if D.Preamble_Skip > 0 then
            D.Preamble_Skip := D.Preamble_Skip - 1;
         end if;
         Result := No_Edge;
         return;
      end if;

      --  Each level change closes a run. The samples of a run, three per bit,
      --  give its bit count, written as a one and the zeros that follow it. A
      --  change at the last position in reach never counts, so the samples
      --  are read one at a time within the count.
      Start := P;
      Remaining := Positive'Min (Count - P, Max_Valid_Samples);
      Old_P := P;
      Limit := P + Remaining;
      while P < Limit loop
         pragma Loop_Invariant (P in Old_P .. Limit - 1);
         pragma Loop_Invariant (Old_P >= Start);
         pragma Loop_Invariant (Bits <= Old_P - Start);
         pragma Loop_Variant (Increases => P);
         Level := Buffer (P) and Mask;
         P := P + 1;
         if Level /= Last and then P < Limit then
            Len := Positive'Max ((P - Old_P + 1) / 3, 1);
            Bits := Bits + Len;
            Value := Shift_Left (Value, Len) or Shift_Left (1, Len - 1);
            Old_P := P;
            Last := Level;
         end if;
      end loop;

      if Bits < 18 then
         Result := No_Edge;
         return;
      end if;
      Tail := 21 - Bits;
      if Tail < 0 then
         Result := No_Edge;
         return;
      end if;

      --  A decodable reply refines the preamble skip: every check interval
      --  the smallest margin seen, less the target, becomes the skip.
      if Unsigned_32 (Start) < D.Min_Margin then
         D.Min_Margin := Unsigned_32 (Start);
      end if;
      if Adaflight.Clock.Elapsed (Now, D.Next_Margin_Check) >= 0 then
         D.Next_Margin_Check := D.Next_Margin_Check + Margin_Check_Interval_Us;
         if D.Next_Margin_Check < Now then
            D.Next_Margin_Check := Now + Start_Margin_Target;
         end if;
         if D.Min_Margin > Start_Margin_Target then
            D.Preamble_Skip := Unsigned_8 (D.Min_Margin - Start_Margin_Target);
         else
            D.Preamble_Skip := 0;
         end if;
         D.Min_Margin := Unsigned_32'Last;
      end if;

      if Tail > 0 then
         Value := Shift_Left (Value, Tail) or Shift_Left (1, Tail - 1);
      end if;
      Result := Decode_Groups (Value);
   end Decode_Samples;

   -------------------
   -- Decode_Groups --
   -------------------

   function Decode_Edges (Buffer : Edge_Times; Count : Edge_Count) return Unsigned_32 is
      Value     : Unsigned_32 := 0;
      Old       : Unsigned_32 := Buffer (0);
      Bits      : Natural := 0;
      Line_High : Boolean := False;
      Len       : Integer;
   begin
      for I in 1 .. Count loop
         pragma Loop_Invariant (Bits <= 21);
         if I < Count then
            exit when Bits >= 21;
            declare
               Diff : constant Unsigned_32 := Buffer (I) - Old;
               Gap  : constant Interfaces.Integer_64 :=
                 (if Diff < 2 ** 31 then Interfaces.Integer_64 (Diff) else Interfaces.Integer_64 (Diff) - 2 ** 32);
            begin
               Len := Integer ((Gap + 8) / 16);
            end;
            exit when Len <= 0;
            Line_High := not Line_High;
         else
            Len := 21 - Bits;
            exit when Len <= 0 or else not Line_High;
         end if;
         if Len > 21 - Bits then
            return Invalid_Value;
         end if;
         Value := Shift_Left (Value, Len) or Shift_Left (1, Len - 1);
         if I < Count then
            Old := Buffer (I);
         end if;
         Bits := Bits + Len;
      end loop;
      if Bits /= 21 then
         return Invalid_Value;
      end if;
      return Decode_Groups (Value);
   end Decode_Edges;

   function Decode_Groups (Word : Unsigned_32) return Unsigned_32 is
      V       : constant Unsigned_32 := Word and 16#FFFFF#;
      Decoded : constant Unsigned_32 :=
        Groups (V and 31) or Shift_Left (Groups (Shift_Right (V, 5) and 31), 4)
        or Shift_Left (Groups (Shift_Right (V, 10) and 31), 8) or Shift_Left (Groups (Shift_Right (V, 15) and 31), 12);
      Csum    : Unsigned_32 := Decoded xor Shift_Right (Decoded, 8);
   begin
      Csum := Csum xor Shift_Right (Csum, 4);
      if (Csum and 16#F#) /= 16#F# or else Decoded > 16#FFFF# then
         return Invalid_Value;
      else
         return Shift_Right (Decoded, 4);
      end if;
   end Decode_Groups;

   -------------------
   -- Decode_Period --
   -------------------

   function Decode_Period (Raw : Raw_Value) return Unsigned_32 is
      Period : Unsigned_32;
   begin
      if Raw = 16#FFF# then
         return 0;
      end if;
      Period := Shift_Left (Unsigned_32 (Raw and 16#1FF#), Natural (Shift_Right (Raw and 16#FE00#, 9)));
      if Period = 0 then
         return Invalid_Value;
      end if;
      return (1_000_000 * 60 / 100 + Period / 2) / Period;
   end Decode_Period;

   ------------------
   -- Decode_Value --
   ------------------

   procedure Decode_Value (Raw : Raw_Value; Extended : Boolean; Value : out Unsigned_32; Kind : out Telemetry_Kind) is
      Field : constant Unsigned_16 := Shift_Right (Raw and 16#F00#, 8);
   begin
      if not Extended or else (Field and 1) = 1 or else Field = 0 then
         Value := Decode_Period (Raw);
         Kind := Erpm;
      else
         Kind := Telemetry_Kind'Val (Field / 2);
         Value := Unsigned_32 (Raw and 16#FF#);
      end if;
   end Decode_Value;

   -----------
   -- Clean --
   -----------

   procedure Clean (T : in out Telemetry) is
   begin
      T.Motors := (others => <>);
      T.State := Invalid;
   end Clean;

   ----------
   -- Init --
   ----------

   procedure Init (T : in out Telemetry; Count : Motor_Total; Poles : Pole_Count; Extended_Forced : Boolean;
                   Cutoff_Hz : Cutoff_Setting; Looptime : Looptime_Us) is
      K : constant Unit_Interval := Adaflight.Filters.PT1_Gain (Float (Cutoff_Hz), Float (Looptime) * 1.0E-6);
   begin
      T.Count := Count;
      T.Erpm_To_Hz := Erpm_Per_Minute_Lsb / (Float (Poles) / 2.0);
      T.Decode_Extended := Extended_Forced;
      for M in 0 .. Count - 1 loop
         Adaflight.Filters.PT1_Init (T.Filters (M), K);
      end loop;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (T : in out Telemetry) is
      Total   : Unsigned_32 := 0;
      Samples : Natural := 0;
      Value   : Unsigned_32;
      Kind    : Telemetry_Kind;
      Output  : Adaflight.Maths.Signal;
   begin
      if T.State /= Not_Processed then
         return;
      end if;
      for M in 0 .. T.Count - 1 loop
         pragma Loop_Invariant (Total <= Unsigned_32 (M) * Max_Period_Value);
         pragma Loop_Invariant (Samples <= M);
         pragma Loop_Invariant (T.Count = T.Count'Loop_Entry);
         Decode_Value (T.Motors (M).Raw, T.Decode_Extended or else (T.Motors (M).Received and 16#FE#) /= 0,
                       Value, Kind);
         if Value /= Invalid_Value then
            T.Motors (M).Values (Kind) := Unsigned_16 (Value and 16#FFFF#);
            T.Motors (M).Received := T.Motors (M).Received or Shift_Left (1, Telemetry_Kind'Pos (Kind));
            if Kind = Temperature and then Value > Unsigned_32 (T.Motors (M).Max_Temperature) then
               T.Motors (M).Max_Temperature := Unsigned_8 (Value and 16#FF#);
            end if;
            if Kind = Erpm then
               T.Rpm (M) := Erpm_To_Rpm (T, Value);
               Total := Total + Value;
               Samples := Samples + 1;
            end if;
         end if;
      end loop;
      if Samples > 0 then
         T.Rpm_Average := Erpm_To_Rpm (T, Total) / Float (Samples);
      end if;
      T.Min_Frequency := Float'Last;
      for M in 0 .. T.Count - 1 loop
         pragma Loop_Invariant (T.Count = T.Count'Loop_Entry);
         Adaflight.Filters.PT1_Apply (T.Filters (M), T.Erpm_To_Hz * Float (T.Motors (M).Values (Erpm)), Output);
         T.Frequency (M) := Output;
         T.Min_Frequency := Float'Min (T.Min_Frequency, Output);
      end loop;
      T.State := Processed;
   end Update;

   -----------------
   -- Erpm_To_Rpm --
   -----------------

   function Erpm_To_Rpm (T : Telemetry; Erpm_Hundreds : Unsigned_32) return Rpm_Value is
      Hz : constant Float range 0.0 .. 2.0E7 := Float (Erpm_Hundreds) * T.Erpm_To_Hz;
   begin
      return Hz * 60.0;
   end Erpm_To_Rpm;

   ------------
   -- Active --
   ------------

   function Active (T : Telemetry) return Boolean is
   begin
      if T.Count = 0 then
         return False;
      end if;
      for M in 0 .. T.Count - 1 loop
         if not Motor_Active (T, M) then
            return False;
         end if;
      end loop;
      return True;
   end Active;

   -----------------
   -- Sensor_Data --
   -----------------

   procedure Sensor_Data (T : Telemetry; M : Motor_Index; Present : out Boolean; Erpm_Hundreds : out Integer_16;
                          Temperature_C : out Unsigned_8; Current_A : out Unsigned_16) is
      Extended : constant Boolean := (T.Motors (M).Received and 16#FE#) /= 0;
      E        : constant Unsigned_16 := T.Motors (M).Values (Erpm);
   begin
      Present := Motor_Active (T, M);
      Erpm_Hundreds := 0;
      Temperature_C := 0;
      Current_A := 0;
      if not Present then
         return;
      end if;
      Erpm_Hundreds := (if E >= 2 ** 15 then -Integer_16 (not E) - 1 else Integer_16 (E));
      if Extended and then (T.Motors (M).Received and 2) /= 0 then
         Temperature_C := Unsigned_8 (T.Motors (M).Values (Temperature) and 16#FF#);
      end if;
      if Extended and then (T.Motors (M).Received and 8) /= 0 then
         Current_A := T.Motors (M).Values (Current);
      end if;
   end Sensor_Data;

   ------------------
   -- Count_Packet --
   ------------------

   procedure Count_Packet (Q : in out Quality; Valid : Boolean; Now_Ms : Time_Ms) is
      B : constant Bucket_Index := Bucket_Index ((Now_Ms / Quality_Bucket_Ms) mod Quality_Buckets);
   begin
      if B /= Q.Last_Bucket then
         Q.Packet_Sum := Q.Packet_Sum - Q.Packets (B);
         Q.Invalid_Sum := Q.Invalid_Sum - Q.Invalids (B);
         Q.Packets (B) := 0;
         Q.Invalids (B) := 0;
         Q.Last_Bucket := B;
      end if;
      Q.Packet_Sum := Q.Packet_Sum + 1;
      Q.Packets (B) := Q.Packets (B) + 1;
      if not Valid then
         Q.Invalid_Sum := Q.Invalid_Sum + 1;
         Q.Invalids (B) := Q.Invalids (B) + 1;
      end if;
   end Count_Packet;

   ---------------------
   -- Invalid_Percent --
   ---------------------

   function Invalid_Percent (Q : Quality; Active : Boolean) return Hundredths_Percent is
      Share : Float;
   begin
      if not Active then
         return 10_000;
      elsif Q.Packet_Sum = 0 then
         return 0;
      end if;
      Share := Float (Q.Invalid_Sum) * 10000.0 / Float (Q.Packet_Sum);
      if Share < 9999.5 then
         return Hundredths_Percent (Round_To_Even (Share));
      else
         return 10_000;
      end if;
   end Invalid_Percent;

   procedure Read_Replies
     (T : in out Telemetry; Counts : in out Read_Counts; Q : in out Qualities; C : in out Captures;
      Count : Motor_Total; Use_Telemetry : Boolean; Commands : Command_List; Now_Us : Time_Us; Now_Ms : Time_Ms;
      Stamp_Us : in out Time_Us; Processed : out Motor_Total; Done : out Boolean)
   is
      Elapsed : constant Unsigned_32 := Now_Us - Stamp_Us;
      Since   : constant Integer_32 :=
        (if Elapsed < 2 ** 31 then Integer_32 (Elapsed) else Integer_32 (Interfaces.Integer_64 (Elapsed) - 2 ** 32));
      Raw     : Unsigned_32;
   begin
      Processed := 0;
      Done := True;
      if not Use_Telemetry then
         return;
      end if;
      for M in 0 .. Count - 1 loop
         pragma Loop_Invariant (Processed = M);
         if Since >= 0 and then Since < C (M).Deadtime then
            Done := False;
            return;
         end if;
         if C (M).Input and then C (M).Edges > Min_Edges then
            Counts.Reads := Counts.Reads + 1;
            Raw := Decode_Edges (C (M).Buffer, C (M).Edges);
            if Raw /= Invalid_Value then
               if Raw = Extended_Acknowledge and then Commands (M) = Extended_Telemetry_Enable then
                  T.Motors (M).Received := State_Events_Bit;
               else
                  T.Motors (M).Raw := Raw_Value (Raw);
               end if;
            else
               Counts.Invalids := Counts.Invalids + 1;
               if M = 0 then
                  Counts.Saved := C (M).Buffer;
               end if;
            end if;
            Count_Packet (Q (M), Raw /= Invalid_Value, Now_Ms);
         end if;
         C (M).Input := False;
         Processed := M + 1;
      end loop;
      T.State := Not_Processed;
      Stamp_Us := 0;
   end Read_Replies;

   --------------------
   -- Validate_Order --
   --------------------

   procedure Validate_Order (Order : in out Output_Order) is
      Seen    : array (Motor_Index) of Boolean := (others => False);
      Invalid : Boolean := False;
   begin
      for I in Order'Range loop
         pragma Loop_Invariant (for all J in Order'First .. I - 1 => Natural (Order (J)) < Order'Length);
         if Natural (Order (I)) >= Order'Length then
            Invalid := True;
            exit;
         end if;
      end loop;
      if not Invalid then
         for I in Order'Range loop
            pragma Loop_Invariant (for all J in Order'Range => Natural (Order (J)) < Order'Length);
            if Seen (Motor_Index (Order (I))) then
               Invalid := True;
               exit;
            end if;
            Seen (Motor_Index (Order (I))) := True;
         end loop;
      end if;
      if Invalid then
         for I in Order'Range loop
            pragma Loop_Invariant (for all J in Order'First .. I - 1 => Natural (Order (J)) < Order'Length);
            Order (I) := Unsigned_8 (I);
         end loop;
      end if;
   end Validate_Order;

end Adaflight.DShot;
