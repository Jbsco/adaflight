with Adaflight.Clock;

package body Adaflight.Gimbal_Control with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;

   Opcode_Low_Byte  : constant := 16#A5#;
   Opcode_High_Byte : constant := 16#5A#;
   Timeout_Us       : constant := 250_000;

   RC_Min       : constant := -500;
   RC_Max       : constant := 500;
   Set_Min      : constant := -2047;
   Set_Max      : constant := 2047;
   Set_Roll_Min : constant := -900;
   Set_Roll_Max : constant := 900;
   Roll_Min     : constant := -500;
   Roll_Max     : constant := 500;
   Pitch_Min    : constant := -1150;
   Pitch_Max    : constant := 1750;
   Yaw_Min      : constant := -2047;
   Yaw_Max      : constant := 2047;

   subtype Angle is Integer range -2048 .. 2047;
   subtype Bound is Integer range -2047 .. 2047;
   subtype Scaled is Integer range -100_000 .. 100_000;

   --  The integer range scale with the truncating division of C.
   function Scale_Range (X : Angle; Src_From, Src_To, Dest_From, Dest_To : Bound) return Scaled is
     ((Dest_To - Dest_From) * (X - Src_From) / (Src_To - Src_From) + Dest_From)
     with Pre => Src_To - Src_From >= 500;

   --  A stick's deviation from the centre, truncated to whole microseconds.
   function Deviation (P : Pulse; C : Settings) return Angle is
     (Integer (Float'Truncation (P - Float (C.Mid_RC))));

   function Field (Raw : Natural) return Angle is (if Raw >= 2048 then Raw - 4096 else Raw)
     with Pre => Raw < 4096;

   function Raw (A : Angle) return Natural is (if A < 0 then A + 4096 else A);

   function Roll_Of (F : Frame) return Angle is (Field (Natural (F (3)) / 16 + Natural (F (4)) * 16));
   function Pitch_Of (F : Frame) return Angle is (Field (Natural (F (5)) + Natural (F (6)) mod 16 * 256));
   function Yaw_Of (F : Frame) return Angle is (Field (Natural (F (6)) / 16 + Natural (F (7)) * 16));

   function Constrain (V, Low, High : Integer) return Integer is
     (if V < Low then Low elsif V > High then High else V);

   function Check_Of (F : Frame) return Unsigned_16 is
     (Adaflight.Bytes.CRC16_CCITT_Update (0, F (0 .. 7)));

   function Valid (F : Frame) return Boolean is
     (F (8) = Byte (Check_Of (F) / 256) and then F (9) = Byte (Check_Of (F) mod 256));

   --  The gimbal frame from the head tracker's angles and the sticks: each
   --  axis scaled by its gain, the sticks added by theirs, the offsets added
   --  and the limits applied, then the mode, the sensitivity and the check.
   procedure Set (T : in out State; C : Settings; S : Sticks; Roll_In, Pitch_In, Yaw_In : Angle) is
      Roll  : Integer := Scale_Range (Roll_In, Set_Roll_Min, Set_Roll_Max,
                                      Roll_Min * C.Roll_Gain / 100, Roll_Max * C.Roll_Gain / 100);
      Pitch : Integer := Scale_Range (Pitch_In, Set_Min, Set_Max,
                                      Pitch_Min * C.Pitch_Gain / 100, Pitch_Max * C.Pitch_Gain / 100);
      Yaw   : Integer := Scale_Range (Yaw_In, Set_Min, Set_Max,
                                      Yaw_Min * C.Yaw_Gain / 100, Yaw_Max * C.Yaw_Gain / 100);
      Sensitivity : constant Natural := (if C.Sensitivity < 0 then C.Sensitivity + 32 else C.Sensitivity);
      Check : Unsigned_16;
   begin
      Roll := Roll + Scale_Range (Deviation (S.Roll, C), RC_Min, RC_Max,
                                  Roll_Min * C.Roll_RC_Gain / 100, Roll_Max * C.Roll_RC_Gain / 100);
      if S.Pitch < Float (C.Mid_RC) then
         Pitch := Pitch + Scale_Range (Deviation (S.Pitch, C), RC_Min, 0, Pitch_Max * C.Pitch_RC_Low_Gain / 100, 0);
      else
         Pitch := Pitch + Scale_Range (Deviation (S.Pitch, C), 0, RC_Max, 0, Pitch_Min * C.Pitch_RC_High_Gain / 100);
      end if;
      Yaw := Yaw + Scale_Range (Deviation (S.Yaw, C), RC_Min, RC_Max,
                                Yaw_Min * C.Yaw_RC_Gain / 100, Yaw_Max * C.Yaw_RC_Gain / 100);
      Pitch := Pitch + Scale_Range (Deviation (S.Throttle, C), RC_Min, RC_Max,
                                    Pitch_Min * C.Pitch_RC_Throttle_Gain / 100,
                                    Pitch_Max * C.Pitch_RC_Throttle_Gain / 100);
      Roll := Roll + Roll_Max * C.Roll_Offset / 100;
      Pitch := Pitch + Pitch_Max * C.Pitch_Offset / 100;
      Yaw := Yaw + Yaw_Max * C.Yaw_Offset / 100;
      Roll := Constrain (Roll, Roll_Min * C.Roll_Limit / 100, Roll_Max * C.Roll_Limit / 100);
      Pitch := Constrain (Pitch, Pitch_Min * C.Pitch_Low_Limit / 100, Pitch_Max * C.Pitch_High_Limit / 100);
      Yaw := Constrain (Yaw, Yaw_Min * C.Yaw_Limit / 100, Yaw_Max * C.Yaw_Limit / 100);
      T.Sent (2) := Byte (C.Stabilisation + 8 * Sensitivity);
      T.Sent (3) := (T.Sent (3) and 16#0F#) or Byte (Raw (Roll) mod 16 * 16);
      T.Sent (4) := Byte (Raw (Roll) / 16);
      T.Sent (5) := Byte (Raw (Pitch) mod 256);
      T.Sent (6) := Byte (Raw (Pitch) / 256 + Raw (Yaw) mod 16 * 16);
      T.Sent (7) := Byte (Raw (Yaw) / 16);
      Check := Check_Of (T.Sent);
      T.Sent (8) := Byte (Check / 256);
      T.Sent (9) := Byte (Check mod 256);
   end Set;

   ----------
   -- Init --
   ----------

   procedure Init (T : out State; C : Settings; S : Sticks) is
   begin
      T := (others => <>);
      if C.Port_Configured then
         T.Open := True;
         T.Received (0) := Opcode_Low_Byte;
         T.Received (1) := Opcode_High_Byte;
         T.Sent (0) := Opcode_Low_Byte;
         T.Sent (1) := Opcode_High_Byte;
         Set (T, C, S, 0, 0, 0);
      end if;
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (T : in out State; C : Settings; S : Sticks; Now_Us : Unsigned_32; Input : Byte_Array;
                     O : out Output)
   is
      --  The output holds twice the input and one frame, which the
      --  passthrough and a frame begun in an earlier update cannot exceed.
      procedure Write (B : Byte) is
      begin
         if O.Length < Max_Output then
            O.Bytes (O.Length) := B;
            O.Length := O.Length + 1;
         end if;
      end Write;
   begin
      O := (others => <>);
      if not T.Open then
         O.Disable_Task := True;
         return;
      end if;
      if Input'Length > 0 then
         T.Last_Rx_Us := Now_Us;
         for K in Input'Range loop
            case T.Phase is
               when Opcode_Low =>
                  if Input (K) = Opcode_Low_Byte then
                     T.Phase := Opcode_High;
                  else
                     Write (Input (K));
                  end if;
               when Opcode_High =>
                  if Input (K) = Opcode_High_Byte then
                     T.Phase := Command;
                     T.Count := 2;
                  else
                     Write (1);
                     Write (Input (K));
                     T.Phase := Opcode_Low;
                  end if;
               when Command =>
                  if T.Count < Frame_Length then
                     T.Received (T.Count) := Input (K);
                     T.Count := T.Count + 1;
                  end if;
                  if T.Count = Frame_Length then
                     if Valid (T.Received) then
                        T.Sent := T.Received;
                        Set (T, C, S, Roll_Of (T.Received), Pitch_Of (T.Received), Yaw_Of (T.Received));
                        for I in Frame_Index loop
                           Write (T.Sent (I));
                        end loop;
                     end if;
                     T.Phase := Opcode_Low;
                  end if;
            end case;
         end loop;
      elsif Adaflight.Clock.Elapsed (Now_Us, T.Last_Rx_Us) > Timeout_Us then
         Set (T, C, S, 0, 0, 0);
         for I in Frame_Index loop
            Write (T.Sent (I));
         end loop;
      end if;
   end Update;

end Adaflight.Gimbal_Control;
