with Adaflight.Blackbox_Encoding;
with Adaflight.Maths;

package body Adaflight.Blackbox with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Header.Device_Kind;

   package Enc renames Adaflight.Blackbox_Encoding;

   Test_Mode_Hold_Ms    : constant := 5_000;
   Target_Header_Budget : constant := Header.Target_Budget_Per_Iteration;

   subtype Rounded is Adaflight.Maths.Rounded_Integer;

   ---------------------
   -- The conversions --
   ---------------------

   function Wrap_16 (V : Rounded) return Integer_16 is
     (if V >= 2 ** 15 then Integer_16 (V - 2 ** 16 * ((V + 2 ** 15) / 2 ** 16))
      elsif V < -(2 ** 15) then Integer_16 (V + 2 ** 16 * ((2 ** 15 - 1 - V) / 2 ** 16))
      else Integer_16 (V));

   function Wrap_16 (V : Unsigned_16) return Integer_16 is
     (if V >= 2 ** 15 then Integer_16 (Integer_32 (V) - 2 ** 16) else Integer_16 (V));

   function To_Int32 (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Integer_32 (U));

   --  The difference of two signed words as the target's wrapping subtraction.
   function Wrap_Difference (A, B : Integer_32) return Integer_32 is
     (To_Int32 (Unsigned_32'Mod (A) - Unsigned_32'Mod (B)));

   function Wrap_Increment (V : Integer_32) return Integer_32 is
     (if V = Integer_32'Last then Integer_32'First else V + 1);

   function Round (X : Float) return Rounded
     with Pre => abs X <= 2.0 ** 24 - 1.0
   is
   begin
      return Adaflight.Maths.Round_Half_Even (X);
   end Round;

   ----------------
   -- The writer --
   ----------------

   Scratch_Size : constant := 64;
   subtype Scratch is Byte_Array (0 .. Scratch_Size - 1);

   procedure Put (L : in out Recorder; B : in out Byte_Array; S : in out Stream; V : Byte)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Header.Put (L.Writer, B, S, V);
   end Put;

   procedure Emit (L : in out Recorder; B : in out Byte_Array; S : in out Stream; Data : Scratch; Count : Natural)
     with Pre  => Fits (S, B) and then Count <= Scratch_Size,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      for I in 0 .. Count - 1 loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
         Put (L, B, S, Data (I));
      end loop;
   end Emit;

   procedure Put_Unsigned_VB (L : in out Recorder; B : in out Byte_Array; S : in out Stream; V : Unsigned_32)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Unsigned_VB (Sc, St, V);
      Emit (L, B, S, Sc, St.Next);
   end Put_Unsigned_VB;

   procedure Put_Signed_VB (L : in out Recorder; B : in out Byte_Array; S : in out Stream; V : Integer_32)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Signed_VB (Sc, St, V);
      Emit (L, B, S, Sc, St.Next);
   end Put_Signed_VB;

   procedure Put_Signed_VB_Array (L : in out Recorder; B : in out Byte_Array; S : in out Stream;
                                  Values : Enc.Int32_Array)
     with Pre  => Fits (S, B) and then Values'Length <= 8,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Signed_VB_Array (Sc, St, Values);
      Emit (L, B, S, Sc, St.Next);
   end Put_Signed_VB_Array;

   procedure Put_Signed16_VB_Array (L : in out Recorder; B : in out Byte_Array; S : in out Stream;
                                    Values : Enc.Int16_Array)
     with Pre  => Fits (S, B) and then Values'Length <= 8,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Signed16_VB_Array (Sc, St, Values);
      Emit (L, B, S, Sc, St.Next);
   end Put_Signed16_VB_Array;

   procedure Put_Tag2_3S32 (L : in out Recorder; B : in out Byte_Array; S : in out Stream; Values : Enc.Triple)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Tag2_3S32 (Sc, St, Values);
      Emit (L, B, S, Sc, St.Next);
   end Put_Tag2_3S32;

   procedure Put_Tag8_4S16 (L : in out Recorder; B : in out Byte_Array; S : in out Stream; Values : Enc.Quad)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Tag8_4S16 (Sc, St, Values);
      Emit (L, B, S, Sc, St.Next);
   end Put_Tag8_4S16;

   procedure Put_Tag8_8SVB (L : in out Recorder; B : in out Byte_Array; S : in out Stream;
                            Values : Enc.Int32_Array; Count : Natural)
     with Pre  => Fits (S, B) and then Count <= Enc.Max_Tag8_Fields and then Count <= Values'Length,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Tag8_8SVB (Sc, St, Values, Count);
      Emit (L, B, S, Sc, St.Next);
   end Put_Tag8_8SVB;

   procedure Put_Float (L : in out Recorder; B : in out Byte_Array; S : in out Stream; V : Float)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Sc : Scratch := (others => 0);
      St : Stream;
   begin
      Init (St, 0, Scratch_Size);
      Enc.Write_Float (Sc, St, V);
      Emit (L, B, S, Sc, St.Next);
   end Put_Float;

   procedure Put_String (L : in out Recorder; B : in out Byte_Array; S : in out Stream; Text : String)
     with Pre  => Fits (S, B) and then Text'Length <= 64,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      for C of Text loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
         Put (L, B, S, Character'Pos (C));
      end loop;
   end Put_String;

   ---------------------
   -- The main frames --
   ---------------------

   function Only_Logging_Intraframes (L : Recorder) return Boolean is (L.P_Interval = 0);
   function Field_Enabled (C : Settings; F : Header.Field_Select) return Boolean is
     (Header.Field_Enabled (C.Fields_Disabled_Mask, F));

   function Nonzero_D (L : Recorder; X : Axis) return Boolean is
     (L.Cache (Header.Condition'Val (Header.Condition'Pos (Header.Nonzero_PID_D_0) + X)));
   function Nonzero_S (L : Recorder; X : Axis) return Boolean is
     (L.Cache (Header.Condition'Val (Header.Condition'Pos (Header.Nonzero_Wing_S_0) + X)));
   function Has_RPM (L : Recorder; X : Motor_Index) return Boolean is
     (L.Cache (Header.Condition'Val (Header.Condition'Pos (Header.Motor_1_Has_RPM) + X)));

   function Axis_Values (A : Axis_Ints) return Enc.Triple is (0 => A (0), 1 => A (1), 2 => A (2));
   function Axis_Values (A : Axis_Int16s) return Enc.Int16_Array is (0 => A (0), 1 => A (1), 2 => A (2));
   function Quad_Values (A : Quad_Int16s) return Enc.Int16_Array is (0 => A (0), 1 => A (1), 2 => A (2), 3 => A (3));
   function Debug_Int16s (A : Debug_Values) return Enc.Int16_Array is
     (0 => A (0), 1 => A (1), 2 => A (2), 3 => A (3), 4 => A (4), 5 => A (5), 6 => A (6), 7 => A (7));

   procedure Rotate_After_Intraframe (L : in out Recorder) is
   begin
      L.Previous := L.Current;
      L.Previous_2 := L.Current;
      L.Current := (if L.Current = 2 then 0 else L.Current + 1);
      L.Logged_Any_Frames := True;
   end Rotate_After_Intraframe;

   procedure Rotate_After_Interframe (L : in out Recorder) is
   begin
      L.Previous_2 := L.Previous;
      L.Previous := L.Current;
      L.Current := (if L.Current = 2 then 0 else L.Current + 1);
      L.Logged_Any_Frames := True;
   end Rotate_After_Interframe;

   procedure Write_Intraframe (L : in out Recorder; C : Settings; Motors : Header.Motor_Count;
                               Motor_Output_Low : Logged_Float; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Cur : constant Main_State := L.Ring (L.Current);
   begin
      Put (L, B, S, Character'Pos ('I'));
      Put_Unsigned_VB (L, B, S, L.Iteration);
      Put_Unsigned_VB (L, B, S, Cur.Time);
      if L.Cache (Header.PID) then
         Put_Signed_VB_Array (L, B, S, Axis_Values (Cur.Axis_P));
         Put_Signed_VB_Array (L, B, S, Axis_Values (Cur.Axis_I));
         for X in Axis loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Nonzero_D (L, X) then
               Put_Signed_VB (L, B, S, Cur.Axis_D (X));
            end if;
         end loop;
         Put_Signed_VB_Array (L, B, S, Axis_Values (Cur.Axis_F));
         for X in Axis loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Nonzero_S (L, X) then
               Put_Signed_VB (L, B, S, Cur.Axis_S (X));
            end if;
         end loop;
      end if;
      if L.Cache (Header.RC_Commands) then
         Put_Signed16_VB_Array (L, B, S, (0 => Cur.RC_Command (0), 1 => Cur.RC_Command (1), 2 => Cur.RC_Command (2)));
         Put_Unsigned_VB (L, B, S, Unsigned_32'Mod (Cur.RC_Command (3)));
      end if;
      if L.Cache (Header.Setpoint) then
         Put_Signed16_VB_Array (L, B, S, Quad_Values (Cur.Setpoint));
      end if;
      if L.Cache (Header.VBat) then
         Put_Unsigned_VB (L, B, S, (Unsigned_32 (L.VBat_Reference) - Unsigned_32 (Cur.VBat_Latest)) and 16#3FFF#);
      end if;
      if L.Cache (Header.Amperage_ADC) then
         Put_Signed_VB (L, B, S, Cur.Amperage_Latest);
      end if;
      if L.Cache (Header.Mag) then
         Put_Signed16_VB_Array (L, B, S, Axis_Values (Cur.Mag_ADC));
      end if;
      if L.Cache (Header.Baro) then
         Put_Signed_VB (L, B, S, Cur.Baro_Alt);
      end if;
      if L.Cache (Header.Rangefinder) then
         Put_Signed_VB (L, B, S, Cur.Surface_Raw);
      end if;
      if L.Cache (Header.RSSI) then
         Put_Unsigned_VB (L, B, S, Unsigned_32 (Cur.RSSI));
      end if;
      if L.Cache (Header.Pitot) then
         Put_Signed_VB (L, B, S, Cur.Airspeed);
         Put_Signed_VB (L, B, S, Cur.Diff_Pressure);
      end if;
      if L.Cache (Header.Gyro) then
         Put_Signed16_VB_Array (L, B, S, Axis_Values (Cur.Gyro_ADC));
      end if;
      if L.Cache (Header.Gyro_Unfilt) then
         Put_Signed16_VB_Array (L, B, S, Axis_Values (Cur.Gyro_Unfilt));
      end if;
      if L.Cache (Header.Acc) then
         Put_Signed16_VB_Array (L, B, S, Axis_Values (Cur.Acc_ADC));
      end if;
      if L.Cache (Header.Attitude) then
         Put_Signed16_VB_Array (L, B, S, Axis_Values (Cur.Quaternion3));
      end if;
      if L.Cache (Header.Debug_Log) then
         Put_Signed16_VB_Array (L, B, S, Debug_Int16s (Cur.Debug));
      end if;
      if Field_Enabled (C, Header.Select_Motor) then
         declare
            Above_Low : constant Float := Float (Cur.Motor (0)) - Motor_Output_Low;
         begin
            Put_Unsigned_VB (L, B, S, (if Above_Low <= 0.0 then 0 else Unsigned_32 (Float'Truncation (Above_Low))));
         end;
         for X in 1 .. Motors - 1 loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            Put_Signed_VB (L, B, S, Integer_32 (Cur.Motor (X)) - Integer_32 (Cur.Motor (0)));
         end loop;
      end if;
      if L.Cache (Header.Servos) then
         declare
            Out_Values : Enc.Int32_Array (0 .. Servo_Count - 1);
         begin
            for X in Servo_Index loop
               Out_Values (X) := Integer_32 (Cur.Servo (X)) - 1_500;
            end loop;
            Put_Tag8_8SVB (L, B, S, Out_Values, Servo_Count);
         end;
      end if;
      if Field_Enabled (C, Header.Select_RPM) then
         for X in 0 .. Motors - 1 loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Has_RPM (L, X) then
               Put_Unsigned_VB (L, B, S, Unsigned_32'Mod (Cur.ERPM (X)));
            end if;
         end loop;
      end if;
      Rotate_After_Intraframe (L);
   end Write_Intraframe;

   --  The delta against the average of the two previous frames.
   procedure Put_Average_Deltas (L : in out Recorder; B : in out Byte_Array; S : in out Stream;
                                 Cur, Prev_1, Prev_2 : Enc.Int16_Array)
     with Pre  => Fits (S, B) and then Cur'First = 0 and then Prev_1'First = 0 and then Prev_2'First = 0
                  and then Cur'Length = Prev_1'Length and then Cur'Length = Prev_2'Length and then Cur'Length <= 8,
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      for I in Cur'Range loop
         pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
         declare
            Predictor : constant Integer_32 := (Integer_32 (Prev_1 (I)) + Integer_32 (Prev_2 (I))) / 2;
         begin
            Put_Signed_VB (L, B, S, Integer_32 (Cur (I)) - Predictor);
         end;
      end loop;
   end Put_Average_Deltas;

   function Motor_Int16s_Of (A : Motor_Int16s; Count : Header.Motor_Count) return Enc.Int16_Array
     with Post => Motor_Int16s_Of'Result'First = 0 and then Motor_Int16s_Of'Result'Length = Count
   is
      R : Enc.Int16_Array (0 .. Count - 1);
   begin
      for I in R'Range loop
         R (I) := A (I);
      end loop;
      return R;
   end Motor_Int16s_Of;

   procedure Write_Interframe (L : in out Recorder; C : Settings; Motors : Header.Motor_Count;
                               B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Cur    : constant Main_State := L.Ring (L.Current);
      Last   : constant Main_State := L.Ring (L.Previous);
      Last_2 : constant Main_State := L.Ring (L.Previous_2);
      Deltas : Enc.Int32_Array (0 .. 7) := (others => 0);
      Setpoint_Deltas : Enc.Quad;
      Optional : Natural := 0;
   begin
      Put (L, B, S, Character'Pos ('P'));
      Put_Signed_VB (L, B, S, To_Int32 (Cur.Time - 2 * Last.Time + Last_2.Time));
      if L.Cache (Header.PID) then
         for X in Axis loop
            Deltas (X) := Cur.Axis_P (X) - Last.Axis_P (X);
         end loop;
         Put_Signed_VB_Array (L, B, S, Deltas (0 .. 2));
         for X in Axis loop
            Deltas (X) := Cur.Axis_I (X) - Last.Axis_I (X);
         end loop;
         Put_Tag2_3S32 (L, B, S, Deltas (0 .. 2));
         for X in Axis loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Nonzero_D (L, X) then
               Put_Signed_VB (L, B, S, Cur.Axis_D (X) - Last.Axis_D (X));
            end if;
         end loop;
         for X in Axis loop
            Deltas (X) := Cur.Axis_F (X) - Last.Axis_F (X);
         end loop;
         Put_Signed_VB_Array (L, B, S, Deltas (0 .. 2));
         for X in Axis loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Nonzero_S (L, X) then
               Put_Signed_VB (L, B, S, Cur.Axis_S (X) - Last.Axis_S (X));
            end if;
         end loop;
      end if;
      for X in 0 .. 3 loop
         Deltas (X) := Integer_32 (Cur.RC_Command (X)) - Integer_32 (Last.RC_Command (X));
         Setpoint_Deltas (X) := Integer_32 (Cur.Setpoint (X)) - Integer_32 (Last.Setpoint (X));
      end loop;
      if L.Cache (Header.RC_Commands) then
         Put_Tag8_4S16 (L, B, S, Deltas (0 .. 3));
      end if;
      if L.Cache (Header.Setpoint) then
         Put_Tag8_4S16 (L, B, S, Setpoint_Deltas);
      end if;
      if L.Cache (Header.VBat) then
         Deltas (Optional) := Integer_32 (Cur.VBat_Latest) - Integer_32 (Last.VBat_Latest);
         Optional := Optional + 1;
      end if;
      if L.Cache (Header.Amperage_ADC) then
         Deltas (Optional) := Wrap_Difference (Cur.Amperage_Latest, Last.Amperage_Latest);
         Optional := Optional + 1;
      end if;
      if L.Cache (Header.Mag) then
         for X in Axis loop
            Deltas (Optional + X) := Integer_32 (Cur.Mag_ADC (X)) - Integer_32 (Last.Mag_ADC (X));
         end loop;
         Optional := Optional + 3;
      end if;
      if L.Cache (Header.Baro) then
         Deltas (Optional) := Wrap_Difference (Cur.Baro_Alt, Last.Baro_Alt);
         Optional := Optional + 1;
      end if;
      if L.Cache (Header.Rangefinder) then
         Deltas (Optional) := Wrap_Difference (Cur.Surface_Raw, Last.Surface_Raw);
         Optional := Optional + 1;
      end if;
      if L.Cache (Header.RSSI) then
         Deltas (Optional) := Integer_32 (Cur.RSSI) - Integer_32 (Last.RSSI);
         Optional := Optional + 1;
      end if;
      Put_Tag8_8SVB (L, B, S, Deltas, Optional);
      if L.Cache (Header.Pitot) then
         Put_Signed_VB (L, B, S, Wrap_Difference (Cur.Airspeed, Last.Airspeed));
         Put_Signed_VB (L, B, S, Wrap_Difference (Cur.Diff_Pressure, Last.Diff_Pressure));
      end if;
      if L.Cache (Header.Gyro) then
         Put_Average_Deltas (L, B, S, Axis_Values (Cur.Gyro_ADC), Axis_Values (Last.Gyro_ADC),
                             Axis_Values (Last_2.Gyro_ADC));
      end if;
      if L.Cache (Header.Gyro_Unfilt) then
         Put_Average_Deltas (L, B, S, Axis_Values (Cur.Gyro_Unfilt), Axis_Values (Last.Gyro_Unfilt),
                             Axis_Values (Last_2.Gyro_Unfilt));
      end if;
      if L.Cache (Header.Acc) then
         Put_Average_Deltas (L, B, S, Axis_Values (Cur.Acc_ADC), Axis_Values (Last.Acc_ADC),
                             Axis_Values (Last_2.Acc_ADC));
      end if;
      if L.Cache (Header.Attitude) then
         Put_Average_Deltas (L, B, S, Axis_Values (Cur.Quaternion3), Axis_Values (Last.Quaternion3),
                             Axis_Values (Last_2.Quaternion3));
      end if;
      if L.Cache (Header.Debug_Log) then
         Put_Average_Deltas (L, B, S, Debug_Int16s (Cur.Debug), Debug_Int16s (Last.Debug), Debug_Int16s (Last_2.Debug));
      end if;
      if Field_Enabled (C, Header.Select_Motor) then
         Put_Average_Deltas (L, B, S, Motor_Int16s_Of (Cur.Motor, Motors), Motor_Int16s_Of (Last.Motor, Motors),
                             Motor_Int16s_Of (Last_2.Motor, Motors));
      end if;
      if L.Cache (Header.Servos) then
         declare
            Out_Values : Enc.Int32_Array (0 .. Servo_Count - 1);
         begin
            for X in Servo_Index loop
               Out_Values (X) := Integer_32 (Cur.Servo (X)) - Integer_32 (Last.Servo (X));
            end loop;
            Put_Tag8_8SVB (L, B, S, Out_Values, Servo_Count);
         end;
      end if;
      if Field_Enabled (C, Header.Select_RPM) then
         for X in 0 .. Motors - 1 loop
            pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry);
            if Has_RPM (L, X) then
               Put_Signed_VB (L, B, S, Integer_32 (Cur.ERPM (X)) - Integer_32 (Last.ERPM (X)));
            end if;
         end loop;
      end if;
      Rotate_After_Interframe (L);
   end Write_Interframe;

   ---------------------
   -- The slow frames --
   ---------------------

   procedure Write_Slow_Frame (L : in out Recorder; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Put (L, B, S, Character'Pos ('S'));
      Put_Unsigned_VB (L, B, S, L.Slow_Hist.Flight_Mode_Flags);
      Put_Unsigned_VB (L, B, S, Unsigned_32 (L.Slow_Hist.State_Flags));
      Put_Tag2_3S32 (L, B, S, (0 => Integer_32 (L.Slow_Hist.Failsafe_Phase),
                               1 => Boolean'Pos (L.Slow_Hist.RX_Signal_Received),
                               2 => Boolean'Pos (L.Slow_Hist.RX_Flight_Channels_Valid)));
      L.Slow_Frame_Timer := 0;
   end Write_Slow_Frame;

   function Load_Slow_State (In_Flight : Slow_Inputs) return Slow_State is
     (Flight_Mode_Flags => In_Flight.Flight_Mode_Flags, State_Flags => In_Flight.State_Flags,
      Failsafe_Phase => Adaflight.Failsafe.Phase'Pos (In_Flight.Failsafe_Phase),
      RX_Signal_Received => In_Flight.RX_Signal_Received,
      RX_Flight_Channels_Valid => In_Flight.RX_Flight_Channels_Valid);

   procedure Write_Slow_Frame_If_Needed (L : in out Recorder; In_Flight : Slow_Inputs; B : in out Byte_Array;
                                         S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Should_Write : Boolean := L.Slow_Frame_Timer >= L.S_Interval;
   begin
      if Should_Write then
         L.Slow_Hist := Load_Slow_State (In_Flight);
      else
         declare
            Fresh : constant Slow_State := Load_Slow_State (In_Flight);
         begin
            if Fresh /= L.Slow_Hist then
               L.Slow_Hist := Fresh;
               Should_Write := True;
            end if;
         end;
      end if;
      if Should_Write then
         Write_Slow_Frame (L, B, S);
      end if;
   end Write_Slow_Frame_If_Needed;

   --------------------
   -- The GPS frames --
   --------------------

   procedure Write_GPS_Home_Frame (L : in out Recorder; G : GPS_Inputs; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Put (L, B, S, Character'Pos ('H'));
      Put_Signed_VB (L, B, S, G.Home.Lat);
      Put_Signed_VB (L, B, S, G.Home.Lon);
      Put_Signed_VB (L, B, S, G.Home.Alt_Cm / 10);
      Put_Unsigned_VB (L, B, S, G.Epoch);
      L.GPS_Hist.Home := G.Home;
   end Write_GPS_Home_Frame;

   procedure Write_GPS_Frame (L : in out Recorder; G : GPS_Inputs; Now_Us : Unsigned_32; B : in out Byte_Array;
                              S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      Put (L, B, S, Character'Pos ('G'));
      if L.Cache (Header.Not_Logging_Every_Frame) then
         Put_Unsigned_VB (L, B, S, Now_Us - L.Ring (L.Previous).Time);
      end if;
      Put_Unsigned_VB (L, B, S, Unsigned_32 (G.Num_Sat));
      Put_Signed_VB (L, B, S, Wrap_Difference (G.Position.Lat, L.GPS_Hist.Home.Lat));
      Put_Signed_VB (L, B, S, Wrap_Difference (G.Position.Lon, L.GPS_Hist.Home.Lon));
      Put_Signed_VB (L, B, S, G.Position.Alt_Cm / 10);
      Put_Unsigned_VB (L, B, S, Unsigned_32 (if G.Use_3D_Speed then G.Speed_3D else G.Ground_Speed));
      Put_Unsigned_VB (L, B, S, Unsigned_32 (G.Ground_Course));
      Put_Signed_VB (L, B, S, Integer_32 (G.Vel_N));
      Put_Signed_VB (L, B, S, Integer_32 (G.Vel_E));
      Put_Signed_VB (L, B, S, Integer_32 (G.Vel_D));
      Put_Unsigned_VB (L, B, S, G.Time_Ms);
      L.GPS_Hist.Num_Sat := G.Num_Sat;
      L.GPS_Hist.Position := G.Position;
   end Write_GPS_Frame;

   function Should_Log_GPS_Home_Frame (L : Recorder; C : Settings; G : GPS_Inputs) return Boolean is
     ((G.Home.Lat /= L.GPS_Hist.Home.Lat or else G.Home.Lon /= L.GPS_Hist.Home.Lon
       or else (Integer_32 (L.P_Frame_Index) = Integer_32 (L.I_Interval) / 2 and then L.I_Frame_Index mod 128 = 0))
      and then Field_Enabled (C, Header.Select_GPS));

   --------------------
   -- The main state --
   --------------------

   procedure Load_Main_State (L : in out Recorder; M : Main_Inputs; Motors : Header.Motor_Count;
                              Now_Us : Unsigned_32) is
      Cur     : Main_State := L.Ring (L.Current);
      Scale   : constant Float := L.High_Resolution_Scale;
      Q_Scale : constant Float := (if M.Quaternion_W < 0.0 then -1.0 else 1.0) * 32_767.0;
   begin
      Cur.Time := Now_Us;
      for I in Axis loop
         Cur.Axis_P (I) := Integer_32 (Round (M.PID_P (I)));
         Cur.Axis_I (I) := Integer_32 (Round (M.PID_I (I)));
         Cur.Axis_D (I) := Integer_32 (Round (M.PID_D (I)));
         Cur.Axis_F (I) := Integer_32 (Round (M.PID_F (I)));
         Cur.Axis_S (I) := Integer_32 (Round (M.PID_S (I)));
         Cur.Gyro_ADC (I) := Wrap_16 (Round (M.Gyro_Filtered (I) * Scale));
         Cur.Gyro_Unfilt (I) := Wrap_16 (Round (M.Gyro_Raw (I) * Scale));
         Cur.Acc_ADC (I) := Wrap_16 (Round (M.Acc (I)));
         Cur.Mag_ADC (I) := Wrap_16 (Round (M.Mag (I)));
      end loop;
      for I in Axis loop
         Cur.Quaternion3 (I) := Wrap_16 (Round (M.Quaternion_XYZ (I) * Q_Scale));
      end loop;
      for I in 0 .. 3 loop
         Cur.RC_Command (I) := Wrap_16 (Round (M.RC_Command (I) * Scale));
      end loop;
      for I in Axis loop
         Cur.Setpoint (I) := Wrap_16 (Round (M.Setpoint (I) * Scale));
      end loop;
      Cur.Setpoint (3) := Wrap_16 (Round (M.Throttle * 1_000.0));
      Cur.Debug := M.Debug;
      for I in 0 .. Motors - 1 loop
         Cur.Motor (I) := Wrap_16 (Round (M.Motor (I)));
      end loop;
      for I in 0 .. Motors - 1 loop
         Cur.ERPM (I) := Wrap_16 (M.ERPM (I));
      end loop;
      Cur.VBat_Latest := M.VBat_Latest;
      Cur.Amperage_Latest := M.Amperage_Latest;
      Cur.Baro_Alt := M.Baro_Alt;
      Cur.Surface_Raw := M.Surface_Raw;
      Cur.RSSI := M.RSSI;
      Cur.Airspeed := Integer_32 (Float'Truncation (M.Airspeed));
      Cur.Diff_Pressure := Integer_32 (Float'Truncation (M.Diff_Pressure));
      Cur.Servo := M.Servo;
      L.Ring (L.Current) := Cur;
   end Load_Main_State;

   ----------------
   -- The events --
   ----------------

   procedure Log_Event (L : in out Recorder; E : Event_Kind; D : Event_Data; B : in out Byte_Array;
                        S : in out Stream) is
   begin
      if L.State not in Running | Paused then
         return;
      end if;
      Put (L, B, S, Character'Pos ('E'));
      Put (L, B, S, Event_Code (E));
      case E is
         when Sync_Beep =>
            Put_Unsigned_VB (L, B, S, D.Time_Us);
         when Flight_Mode =>
            Put_Unsigned_VB (L, B, S, D.Flags);
            Put_Unsigned_VB (L, B, S, D.Last_Flags);
         when Disarm =>
            Put_Unsigned_VB (L, B, S, D.Reason);
         when Inflight_Adjustment =>
            if D.Float_Flag then
               Put (L, B, S, Byte'Mod (Natural (D.Adjustment_Function) + 128));
               Put_Float (L, B, S, D.New_Float);
            else
               Put (L, B, S, D.Adjustment_Function);
               Put_Signed_VB (L, B, S, D.New_Value);
            end if;
         when Logging_Resume =>
            Put_Unsigned_VB (L, B, S, D.Log_Iteration);
            Put_Unsigned_VB (L, B, S, D.Current_Time);
         when Log_End =>
            Put_String (L, B, S, "End of log");
            Put (L, B, S, 0);
      end case;
   end Log_Event;

   procedure Check_And_Log_Arming_Beep (L : in out Recorder; Beep_Time_Us : Unsigned_32; B : in out Byte_Array;
                                        S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      if Beep_Time_Us /= L.Last_Arming_Beep then
         L.Last_Arming_Beep := Beep_Time_Us;
         Log_Event (L, Sync_Beep, (Time_Us => L.Last_Arming_Beep, others => <>), B, S);
      end if;
   end Check_And_Log_Arming_Beep;

   procedure Check_And_Log_Flight_Mode (L : in out Recorder; Flags : Unsigned_32; B : in out Byte_Array;
                                        S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      if Flags /= L.Last_Flight_Mode_Flags then
         declare
            D : Event_Data;
         begin
            D.Last_Flags := L.Last_Flight_Mode_Flags;
            L.Last_Flight_Mode_Flags := Flags;
            D.Flags := Flags;
            Log_Event (L, Flight_Mode, D, B, S);
         end;
      end if;
   end Check_And_Log_Flight_Mode;

   ----------------------------
   -- The iteration policy --
   ----------------------------

   function Should_Log_P_Frame (L : Recorder) return Boolean is (L.P_Frame_Index = 0 and then L.P_Interval /= 0);
   function Should_Log_I_Frame (L : Recorder) return Boolean is (L.Loop_Index = 0);

   procedure Advance_Iteration_Timers (L : in out Recorder) is
   begin
      L.Slow_Frame_Timer := Wrap_Increment (L.Slow_Frame_Timer);
      L.Iteration := L.Iteration + 1;
      L.Loop_Index := L.Loop_Index + 1;
      if Integer_32 (L.Loop_Index) >= Integer_32 (L.I_Interval) then
         L.Loop_Index := 0;
         L.I_Frame_Index := L.I_Frame_Index + 1;
         L.P_Frame_Index := 0;
      else
         L.P_Frame_Index := L.P_Frame_Index + 1;
         if Integer_32 (L.P_Frame_Index) >= Integer_32 (L.P_Interval) then
            L.P_Frame_Index := 0;
         end if;
      end if;
   end Advance_Iteration_Timers;

   procedure Device_Flush (L : in out Recorder) is
   begin
      L.Flush_Requests := L.Flush_Requests + 1;
   end Device_Flush;

   procedure Log_Iteration (L : in out Recorder; C : Settings; In_Flight : Inputs; B : in out Byte_Array;
                            S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
      Motors : constant Header.Motor_Count := In_Flight.Conditions.Motors;
   begin
      if Should_Log_I_Frame (L) then
         if Only_Logging_Intraframes (L) then
            Write_Slow_Frame_If_Needed (L, In_Flight.Slow, B, S);
         end if;
         Load_Main_State (L, In_Flight.Main, Motors, In_Flight.Now_Us);
         Write_Intraframe (L, C, Motors, In_Flight.Main.Motor_Output_Low, B, S);
      else
         Check_And_Log_Arming_Beep (L, In_Flight.Arming_Beep_Time_Us, B, S);
         Check_And_Log_Flight_Mode (L, In_Flight.Slow.Flight_Mode_Flags, B, S);
         if Should_Log_P_Frame (L) then
            Write_Slow_Frame_If_Needed (L, In_Flight.Slow, B, S);
            Load_Main_State (L, In_Flight.Main, Motors, In_Flight.Now_Us);
            Write_Interframe (L, C, Motors, B, S);
         end if;
         if In_Flight.GPS_Feature and then Field_Enabled (C, Header.Select_GPS) then
            if Should_Log_GPS_Home_Frame (L, C, In_Flight.GPS) then
               Write_GPS_Home_Frame (L, In_Flight.GPS, B, S);
               Write_GPS_Frame (L, In_Flight.GPS, In_Flight.Now_Us, B, S);
            elsif In_Flight.GPS.Num_Sat /= L.GPS_Hist.Num_Sat
              or else In_Flight.GPS.Position.Lat /= L.GPS_Hist.Position.Lat
              or else In_Flight.GPS.Position.Lon /= L.GPS_Hist.Position.Lon
            then
               Write_GPS_Frame (L, In_Flight.GPS, In_Flight.Now_Us, B, S);
            end if;
         end if;
      end if;
      Device_Flush (L);
   end Log_Iteration;

   ------------------------
   -- The log's states --
   ------------------------

   procedure Reset_Iteration_Timers (L : in out Recorder) is
   begin
      L.Iteration := 0;
      L.Loop_Index := 0;
      L.I_Frame_Index := 0;
      L.P_Frame_Index := 0;
      L.Slow_Frame_Timer := 0;
   end Reset_Iteration_Timers;

   procedure Set_State (L : in out Recorder; New_State : Log_State; Now_Ms : Unsigned_32)
     with Post => L.State = New_State and then L.Loop_Time = L.Loop_Time'Old
   is
   begin
      case New_State is
         when Prepare_Log_File =>
            L.Logged_Any_Frames := False;
         when Send_Header =>
            L.Writer.Budget := 0;
            L.Header_St.Index := 0;
            L.Header_St.Start_Time_Ms := Now_Ms;
         when Send_Main_Field_Header | Send_GPS_G_Header | Send_GPS_H_Header | Send_Slow_Header =>
            L.Header_St.Index := 0;
            L.Header_St.Field := -1;
         when Send_Sysinfo =>
            L.Header_St.Index := 0;
         when Running =>
            L.Slow_Frame_Timer := L.S_Interval;
         when Shutting_Down =>
            L.Header_St.Start_Time_Ms := Now_Ms;
         when others =>
            null;
      end case;
      L.State := New_State;
   end Set_State;

   procedure Validate_Config (C : in out Settings) is
   begin
      if C.Device not in Header.Flash | Header.SD_Card | Header.Serial then
         C.Device := Header.No_Device;
      end if;
   end Validate_Config;

   --  The device opens: a serial port with its per-iteration allowance from
   --  the loop time below a megabaud, flash when supported and not full, an
   --  SD card with a ready file system.
   procedure Device_Open (L : in out Recorder; C : Settings; D : Device_Inputs; Opened : out Boolean) is
   begin
      L.Writer.Kind := C.Device;
      L.Writer.Buffer_Size := D.Buffer_Size;
      case C.Device is
         when Header.Serial =>
            if C.Serial_Fast_Baud then
               L.Writer.Max_Per_Iteration := Target_Header_Budget;
            else
               L.Writer.Max_Per_Iteration :=
                 Natural'Max (1, Natural'Min (Target_Header_Budget, (Integer (L.Loop_Time) * 3) / 500));
            end if;
            Opened := D.Open_OK;
         when Header.Flash =>
            L.Writer.Max_Per_Iteration := Target_Header_Budget;
            Opened := not D.Full;
         when Header.SD_Card =>
            L.Writer.Max_Per_Iteration := Target_Header_Budget;
            Opened := D.Open_OK and then not D.Full;
         when Header.No_Device =>
            Opened := False;
      end case;
      if Opened then
         L.Opens := L.Opens + 1;
      end if;
   end Device_Open;

   procedure Start (L : in out Recorder; C : in out Settings; In_Flight : Inputs) is
      Opened : Boolean;
      Cond   : Header.Condition_Inputs := In_Flight.Conditions;
   begin
      Validate_Config (C);
      Device_Open (L, C, In_Flight.Device, Opened);
      if not Opened then
         Set_State (L, Disabled, In_Flight.Now_Ms);
         return;
      end if;
      L.GPS_Hist := (others => <>);
      L.Current := 0;
      L.Previous := 1;
      L.Previous_2 := 2;
      L.VBat_Reference := In_Flight.Battery_Voltage;
      Cond.Fields_Disabled_Mask := C.Fields_Disabled_Mask;
      Cond.I_Interval := Integer_32 (L.I_Interval);
      Cond.P_Interval := Integer_32 (L.P_Interval);
      Header.Build_Cache (L.Cache, Cond);
      L.Mode_Condition_Present := In_Flight.Mode_Activation_Present;
      Reset_Iteration_Timers (L);
      L.Last_Arming_Beep := In_Flight.Arming_Beep_Time_Us;
      L.Last_Flight_Mode_Flags := In_Flight.Slow.Flight_Mode_Flags;
      Set_State (L, Prepare_Log_File, In_Flight.Now_Ms);
   end Start;

   procedure Finish (L : in out Recorder; Now_Ms : Unsigned_32; B : in out Byte_Array; S : in out Stream) is
   begin
      case L.State is
         when Disabled | Stopped | Shutting_Down =>
            null;
         when Running | Paused =>
            Log_Event (L, Log_End, (others => <>), B, S);
            Set_State (L, Shutting_Down, Now_Ms);
         when others =>
            Set_State (L, Shutting_Down, Now_Ms);
      end case;
   end Finish;

   procedure Start_In_Test_Mode (L : in out Recorder; C : in out Settings; In_Flight : Inputs) is
   begin
      if not L.Started_In_Test_Mode then
         if C.Device = Header.Serial and then In_Flight.Device.Shared_MSP_Port then
            return;
         end if;
         Start (L, C, In_Flight);
         L.Started_In_Test_Mode := True;
      end if;
   end Start_In_Test_Mode;

   procedure Stop_In_Test_Mode (L : in out Recorder; Now_Ms : Unsigned_32; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old
   is
   begin
      if L.Started_In_Test_Mode then
         Finish (L, Now_Ms, B, S);
         L.Started_In_Test_Mode := False;
      end if;
   end Stop_In_Test_Mode;

   --  Motors running while disarmed start a hold of five seconds.
   procedure Motor_Test_Active (L : in out Recorder; In_Flight : Inputs; Active : out Boolean) is
   begin
      if not In_Flight.Armed and then In_Flight.Motors_Running then
         L.Test_Mode_Reset_Ms := In_Flight.Now_Ms + Test_Mode_Hold_Ms;
         Active := True;
      else
         Active := In_Flight.Now_Ms < L.Test_Mode_Reset_Ms;
      end if;
   end Motor_Test_Active;

   procedure Initialize_Counters (L : in out Recorder; C : in out Settings; Loop_Time : Loop_Time_Us)
     with Post => C.Sample_Rate <= Sample_Rate_Max and then L.Loop_Time = Loop_Time
   is
   begin
      Reset_Iteration_Timers (L);
      L.I_Interval := I_Interval_Count (32 * 1000 / Loop_Time);
      if C.Sample_Rate > Sample_Rate_Max then
         C.Sample_Rate := Sample_Rate_Max;
      end if;
      L.P_Interval := (case C.Sample_Rate is when 0 => 1, when 1 => 2, when 2 => 4, when 3 => 8, when others => 16);
      if Integer_16 (L.P_Interval) > L.I_Interval then
         L.P_Interval := 0;
      end if;
      if C.Device /= Header.No_Device then
         Set_State (L, Stopped, 0);
      else
         Set_State (L, Disabled, 0);
      end if;
      L.S_Interval := Integer_32 (L.I_Interval) * 256;
      L.High_Resolution_Scale := (if C.High_Resolution then 10.0 else 1.0);
      L.Loop_Time := Loop_Time;
   end Initialize_Counters;

   procedure Init (L : out Recorder; C : in out Settings; Loop_Time : Loop_Time_Us) is
   begin
      L := (others => <>);
      Initialize_Counters (L, C, Loop_Time);
   end Init;

   function Device_Full (C : Settings; D : Device_Inputs) return Boolean is
     (case C.Device is
        when Header.Serial | Header.No_Device => False,
        when Header.Flash | Header.SD_Card => D.Full);

   procedure Update (L : in out Recorder; C : in out Settings; In_Flight : Inputs; B : in out Byte_Array;
                     S : in out Stream) is
      Now_Ms : constant Unsigned_32 := In_Flight.Now_Ms;
      D      : constant Device_Inputs := In_Flight.Device;
      Done   : Boolean;
      More   : Boolean;
   begin
      L.Writer.Free := D.Free;
      case L.State is
         when Stopped =>
            if In_Flight.Armed then
               Start (L, C, In_Flight);
            end if;
            if In_Flight.Erase_Box then
               Set_State (L, Start_Erase, Now_Ms);
            end if;
         when Prepare_Log_File =>
            if C.Device /= Header.SD_Card or else D.Begin_Log_Done then
               Set_State (L, Send_Header, Now_Ms);
            end if;
         when Send_Header =>
            Header.Replenish (L.Writer);
            Header.Send_Header_Text (L.Header_St, L.Writer, B, S, Now_Ms, Done);
            if Done then
               Set_State (L, Send_Main_Field_Header, Now_Ms);
            end if;
         when Send_Main_Field_Header =>
            Header.Replenish (L.Writer);
            Header.Send_Field_Definition (L.Header_St, L.Writer, B, S, Header.Main_Fields, C.Wing,
                                          L.Cache, More);
            if not More then
               if In_Flight.GPS_Feature and then Field_Enabled (C, Header.Select_GPS) then
                  Set_State (L, Send_GPS_H_Header, Now_Ms);
               else
                  Set_State (L, Send_Slow_Header, Now_Ms);
               end if;
            end if;
         when Send_GPS_H_Header =>
            Header.Replenish (L.Writer);
            Header.Send_Field_Definition (L.Header_St, L.Writer, B, S, Header.GPS_Home_Fields,
                                          C.Wing, L.Cache, More);
            if not More and then Field_Enabled (C, Header.Select_GPS) then
               Set_State (L, Send_GPS_G_Header, Now_Ms);
            end if;
         when Send_GPS_G_Header =>
            Header.Replenish (L.Writer);
            Header.Send_Field_Definition (L.Header_St, L.Writer, B, S, Header.GPS_Fields, C.Wing,
                                          L.Cache, More);
            if not More and then Field_Enabled (C, Header.Select_GPS) then
               Set_State (L, Send_Slow_Header, Now_Ms);
            end if;
         when Send_Slow_Header =>
            Header.Replenish (L.Writer);
            Header.Send_Field_Definition (L.Header_St, L.Writer, B, S, Header.Slow_Fields, C.Wing,
                                          L.Cache, More);
            if not More then
               L.Cache_Flush_Next := Send_Sysinfo;
               Set_State (L, Cache_Flush, Now_Ms);
            end if;
         when Send_Sysinfo =>
            Header.Replenish (L.Writer);
            declare
               Info : Header.Sysinfo := In_Flight.Info;
            begin
               Info.Values (Header.I_Interval) := Integer_32 (L.I_Interval);
               Info.Values (Header.P_Interval) := Integer_32 (L.P_Interval);
               Info.Values (Header.VBat_Reference) := Integer_32 (L.VBat_Reference);
               Info.Values (Header.Fields_Disabled_Mask) := To_Int32 (C.Fields_Disabled_Mask);
               Info.Values (Header.High_Resolution) := Boolean'Pos (C.High_Resolution);
               Header.Send_Sysinfo (L.Header_St, L.Writer, B, S, C.Wing, Info, L.Cache,
                                    In_Flight.Conditions.Current_Meter, Done);
            end;
            if Done then
               L.Cache_Flush_Next := Running;
               Set_State (L, Cache_Flush, Now_Ms);
            end if;
         when Cache_Flush =>
            if C.Device = Header.SD_Card then
               if D.Flush_Complete then
                  Set_State (L, L.Cache_Flush_Next, Now_Ms);
               else
                  L.Flush_Forces := L.Flush_Forces + 1;
               end if;
            else
               L.Flush_Forces := L.Flush_Forces + 1;
               if D.Flush_Forced then
                  Set_State (L, L.Cache_Flush_Next, Now_Ms);
               end if;
            end if;
         when Paused =>
            if In_Flight.Blackbox_Box and then Should_Log_I_Frame (L) then
               Log_Event (L, Logging_Resume,
                          (Log_Iteration => L.Iteration, Current_Time => In_Flight.Now_Us, others => <>), B, S);
               Set_State (L, Running, Now_Ms);
               Log_Iteration (L, C, In_Flight, B, S);
            end if;
            Advance_Iteration_Timers (L);
         when Running =>
            if L.Mode_Condition_Present and then not In_Flight.Blackbox_Box and then not L.Started_In_Test_Mode then
               Set_State (L, Paused, Now_Ms);
            else
               Log_Iteration (L, C, In_Flight, B, S);
            end if;
            Advance_Iteration_Timers (L);
         when Shutting_Down =>
            if C.Device /= Header.SD_Card or else D.End_Log_Done then
               declare
                  Elapsed : constant Boolean := Now_Ms > L.Header_St.Start_Time_Ms + Shutdown_Timeout_Ms;
                  Forced  : Boolean := False;
               begin
                  if not Elapsed then
                     L.Flush_Forces := L.Flush_Forces + 1;
                     Forced := D.Flush_Forced;
                  end if;
                  if Elapsed or else Forced then
                     L.Closes := L.Closes + 1;
                     Set_State (L, Stopped, Now_Ms);
                  end if;
               end;
            end if;
         when Start_Erase =>
            if C.Device = Header.Flash then
               Initialize_Counters (L, C, L.Loop_Time);
               L.Erase_Requests := L.Erase_Requests + 1;
            end if;
            Set_State (L, Erasing, Now_Ms);
            L.Beeps := L.Beeps + 1;
         when Erasing =>
            if C.Device /= Header.Flash or else D.Erased then
               Set_State (L, Erased, Now_Ms);
               L.Beeps := L.Beeps + 1;
            end if;
         when Erased =>
            if not In_Flight.Erase_Box then
               Set_State (L, Stopped, Now_Ms);
            end if;
         when Disabled =>
            null;
      end case;

      if Device_Full (C, D) then
         if L.State not in Erasing | Start_Erase | Erased then
            Set_State (L, Stopped, Now_Ms);
            L.Started_In_Test_Mode := False;
         end if;
      else
         case C.Mode is
            when Motor_Test =>
               declare
                  Active : Boolean;
               begin
                  Motor_Test_Active (L, In_Flight, Active);
                  if Active then
                     if L.State = Stopped then
                        Start_In_Test_Mode (L, C, In_Flight);
                     end if;
                  elsif L.State /= Stopped then
                     Stop_In_Test_Mode (L, Now_Ms, B, S);
                  end if;
               end;
            when Always_On =>
               if L.State = Stopped then
                  Start_In_Test_Mode (L, C, In_Flight);
               end if;
            when Normal =>
               null;
         end case;
      end if;
   end Update;

   ----------------------
   -- The rate helpers --
   ----------------------

   function P_Denominator (L : Recorder; Rate_Num, Rate_Denom : Integer_32) return Integer_32 is
   begin
      if Rate_Num <= 0 or else Rate_Denom <= 0 then
         return 0;
      end if;
      return Integer_32 (L.I_Interval) * Rate_Num / Rate_Denom;
   end P_Denominator;

   function Log2_Floor (N : Unsigned_32) return Natural is
      V : Unsigned_32 := N or 1;
      R : Natural := 0;
   begin
      for I in 1 .. 31 loop
         pragma Loop_Invariant (R <= I - 1);
         exit when V <= 1;
         V := Interfaces.Shift_Right (V, 1);
         R := R + 1;
      end loop;
      return R;
   end Log2_Floor;

   function Sample_Rate_For (Ratio : Unsigned_16; Loop_Time : Loop_Time_Us) return Natural is
   begin
      if Ratio = 0 then
         return Sample_Rate_Max;
      end if;
      return Natural'Min (Log2_Floor (32_000 / (Unsigned_32 (Loop_Time) * Unsigned_32 (Ratio))), Sample_Rate_Max);
   end Sample_Rate_For;

end Adaflight.Blackbox;
