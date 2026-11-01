with Adaflight.Maths;

package body Adaflight.SmartPort_Telemetry with SPARK_Mode is

   Id_Speed     : constant Unsigned_16 := 16#0830#;
   Id_Vfas      : constant Unsigned_16 := 16#0210#;
   Id_Current   : constant Unsigned_16 := 16#0200#;
   Id_Rpm       : constant Unsigned_16 := 16#0500#;
   Id_Altitude  : constant Unsigned_16 := 16#0100#;
   Id_Fuel      : constant Unsigned_16 := 16#0600#;
   Id_Lat_Long  : constant Unsigned_16 := 16#0800#;
   Id_Vario     : constant Unsigned_16 := 16#0110#;
   Id_Heading   : constant Unsigned_16 := 16#0840#;
   Id_Cap_Used  : constant Unsigned_16 := 16#5250#;
   Id_Pitch     : constant Unsigned_16 := 16#5230#;
   Id_Roll      : constant Unsigned_16 := 16#5240#;
   Id_Acc_X     : constant Unsigned_16 := 16#0700#;
   Id_Acc_Y     : constant Unsigned_16 := 16#0710#;
   Id_Acc_Z     : constant Unsigned_16 := 16#0720#;
   Id_T1        : constant Unsigned_16 := 16#0400#;
   Id_T11       : constant Unsigned_16 := 16#0401#;
   Id_T2        : constant Unsigned_16 := 16#0410#;
   Id_Home_Dist : constant Unsigned_16 := 16#0420#;
   Id_GPS_Alt   : constant Unsigned_16 := 16#0820#;
   Id_Temp      : constant Unsigned_16 := 16#0B70#;
   Id_A4        : constant Unsigned_16 := 16#0910#;

   ESC_Period : constant := 7;

   Erpm_Per_Lsb : constant Float := 100.0;

   function To_U32 (I : Integer_32) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Interfaces.Integer_64 (I) + 2 ** 32) else Unsigned_32 (I));

   function To_U32 (I : Integer_16) return Unsigned_32 is (To_U32 (Integer_32 (I)));

   --  The nearest integer of a value held within the rounding bound.
   function Rounded (X : Float) return Unsigned_32 is
     (To_U32 (Integer_32 (Adaflight.Maths.Round_Half_Even
        (Float'Max (-(2.0 ** 24 - 1.0), Float'Min (2.0 ** 24 - 1.0, X))))));

   -----------
   -- Build --
   -----------

   procedure Build (S : in out Stream; B : Build_Inputs) is
      procedure Add (Id : Unsigned_16) is
      begin
         if S.Size < Max_Values then
            S.Size := S.Size + 1;
            S.Table (S.Size) := Id;
         end if;
      end Add;

      procedure Add_ESC (Id : Unsigned_16) is
      begin
         if S.ESC_Size < Max_ESC_Values then
            S.ESC_Size := S.ESC_Size + 1;
            S.ESC_Table (S.ESC_Size) := Id;
         end if;
      end Add_ESC;
   begin
      S.Size := 0;
      S.Index := 0;
      if B.Enabled (Mode) then
         Add (Id_T1);
         Add (Id_T2);
      end if;
      if B.Enabled (Temperature) then
         Add (Id_T11);
      end if;
      if B.Voltage_Configured and then B.Enabled (Voltage) then
         if not B.Enabled (ESC_Voltage) then
            Add (Id_Vfas);
         end if;
         Add (Id_A4);
      end if;
      if B.Amperage_Configured and then B.Enabled (Current) then
         if not B.Enabled (ESC_Current) then
            Add (Id_Current);
         end if;
         if B.Enabled (Fuel) then
            Add (Id_Fuel);
         end if;
         if B.Enabled (Cap_Used) then
            Add (Id_Cap_Used);
         end if;
      end if;
      if B.Enabled (Heading) then
         Add (Id_Heading);
      end if;
      if B.Acc_Present then
         if B.Enabled (Pitch) then
            Add (Id_Pitch);
         end if;
         if B.Enabled (Roll) then
            Add (Id_Roll);
         end if;
         if B.Enabled (Acc_X) then
            Add (Id_Acc_X);
         end if;
         if B.Enabled (Acc_Y) then
            Add (Id_Acc_Y);
         end if;
         if B.Enabled (Acc_Z) then
            Add (Id_Acc_Z);
         end if;
      end if;
      if B.Baro_Present then
         if B.Enabled (Altitude) then
            Add (Id_Altitude);
         end if;
         if B.Enabled (Vario) then
            Add (Id_Vario);
         end if;
      end if;
      if B.GPS_Feature then
         if B.Enabled (Ground_Speed) then
            Add (Id_Speed);
         end if;
         if B.Enabled (Lat_Long) then
            Add (Id_Lat_Long);
            Add (Id_Lat_Long);
         end if;
         if B.Enabled (Distance) then
            Add (Id_Home_Dist);
         end if;
         if B.Enabled (Altitude) then
            Add (Id_GPS_Alt);
         end if;
      end if;
      S.ESC_Size := 0;
      S.ESC_Index := 0;
      if B.Enabled (ESC_Voltage) then
         Add_ESC (Id_Vfas);
      end if;
      if B.Enabled (ESC_Current) then
         Add_ESC (Id_Current);
      end if;
      if B.Enabled (ESC_Rpm) then
         Add_ESC (Id_Rpm);
      end if;
      if B.Enabled (ESC_Temperature) then
         Add_ESC (Id_Temp);
      end if;
   end Build;

   -------------
   -- Receive --
   -------------

   procedure Receive (S : in out Stream; C : Byte; Last : Boolean; Clear_To_Send : in out Boolean;
                      Received : out Payload) is
      R : Receive_State renames S.Receiver;
      V : Byte := C;
   begin
      Received := (others => <>);
      if C = Start_Stop then
         Clear_To_Send := False;
         R.Rx_Count := 0;
         R.Await_Id := True;
         R.Skip := False;
         return;
      elsif R.Skip then
         return;
      end if;
      if R.Await_Id then
         R.Await_Id := False;
         if C = Sensor_Id_1 and then Last then
            Clear_To_Send := True;
            R.Skip := True;
         elsif C = Sensor_Id_2 then
            R.Checksum := 0;
         else
            R.Skip := True;
         end if;
      else
         if C = Escape then
            R.Stuffing := True;
            return;
         elsif R.Stuffing then
            V := C xor Escape_Xor;
            R.Stuffing := False;
         end if;
         if R.Rx_Count < 7 then
            R.Rx (R.Rx_Count) := V;
            R.Rx_Count := R.Rx_Count + 1;
            R.Checksum := R.Checksum + Unsigned_16 (V);
         else
            R.Skip := True;
            R.Checksum := R.Checksum + Unsigned_16 (V);
            R.Checksum := (R.Checksum and 16#FF#) + Interfaces.Shift_Right (R.Checksum, 8);
            if R.Checksum = 16#FF# then
               Received := (Valid    => True,
                            Frame_Id => R.Rx (0),
                            Value_Id => Unsigned_16 (R.Rx (1)) or Interfaces.Shift_Left (Unsigned_16 (R.Rx (2)), 8),
                            Data     => Unsigned_32 (R.Rx (3)) or Interfaces.Shift_Left (Unsigned_32 (R.Rx (4)), 8)
                                        or Interfaces.Shift_Left (Unsigned_32 (R.Rx (5)), 16)
                                        or Interfaces.Shift_Left (Unsigned_32 (R.Rx (6)), 24));
            end if;
         end if;
      end if;
   end Receive;

   --  A byte onto the line, escaped when it is one of the two reserved
   --  bytes.
   procedure Send_Raw (O : in out Output; C : Byte)
     with Pre  => O.Count <= Max_Tx - 2,
          Post => O.Count <= O.Count'Old + 2
                  and then (if C /= Escape and then C /= Start_Stop then O.Count = O.Count'Old + 1)
   is
   begin
      if C = Escape or else C = Start_Stop then
         O.Tx (O.Count) := Escape;
         O.Tx (O.Count + 1) := C xor Escape_Xor;
         O.Count := O.Count + 2;
      else
         O.Tx (O.Count) := C;
         O.Count := O.Count + 1;
      end if;
   end Send_Raw;

   --  The same, into the running checksum.
   procedure Send_Byte (O : in out Output; C : Byte; Checksum : in out Unsigned_16)
     with Pre  => O.Count <= Max_Tx - 2,
          Post => O.Count <= O.Count'Old + 2
                  and then (if C /= Escape and then C /= Start_Stop then O.Count = O.Count'Old + 1)
   is
   begin
      Send_Raw (O, C);
      Checksum := Checksum + Unsigned_16 (C);
   end Send_Byte;

   -----------------
   -- Write_Frame --
   -----------------

   --  The FPORT reply's length and type first when asked for, then the
   --  frame id, the value id and the value, and the checksum folded to a byte
   --  and inverted.
   procedure Write_Frame (O : in out Output; Frame_Id : Unsigned_8; Value_Id : Unsigned_16; Value : Unsigned_32;
                          FPort : Boolean)
   is
      Checksum : Unsigned_16 := 0;
      Bytes    : constant Byte_Array (0 .. 6) :=
        (Frame_Id,
         Byte (Value_Id and 16#FF#), Byte (Interfaces.Shift_Right (Value_Id, 8)),
         Byte (Value and 16#FF#), Byte (Interfaces.Shift_Right (Value, 8) and 16#FF#),
         Byte (Interfaces.Shift_Right (Value, 16) and 16#FF#), Byte (Interfaces.Shift_Right (Value, 24)));
      Start    : constant Natural := (if FPort then 2 else 0);
   begin
      if FPort then
         Send_Byte (O, FPort_Reply_Length, Checksum);
         Send_Byte (O, FPort_Reply_Type, Checksum);
      end if;
      pragma Assert (O.Count = Start);
      for I in Bytes'Range loop
         pragma Loop_Invariant (O.Count <= Start + 2 * I);
         Send_Byte (O, Bytes (I), Checksum);
      end loop;
      while Checksum > 16#FF# loop
         Checksum := (Checksum and 16#FF#) + Interfaces.Shift_Right (Checksum, 8);
      end loop;
      Checksum := 16#FF# - Checksum;
      Send_Raw (O, Byte (Checksum));
   end Write_Frame;

   --  The ESC reading of a motor number, the combined one past them.
   function ESC_Of (Inp : Inputs; Number : Natural) return ESC_Reading is
     (if Number < Inp.Motors then Inp.ESC (Number) else (others => <>));

   function Combined (Inp : Inputs) return ESC_Reading is (Inp.ESC_Combined);

   --  The electrical rate in revolutions per minute from the pole count.
   function Rpm_Of (Inp : Inputs; Erpm : Integer_16) return Unsigned_32 is
      Pairs  : constant Float := Float (Inp.Pole_Count) / 2.0;
      Per_Hz : constant Float := (if Pairs > 0.0 then (Erpm_Per_Lsb / 60.0) / Pairs else 0.0);
      Raw    : constant Float := Float (To_U32 (Erpm));
   begin
      return Rounded ((Raw * Per_Hz) * 60.0);
   end Rpm_Of;

   function Acc_Hundredths (Component : Acceleration; Rec : Gravity_Scale) return Unsigned_32 is
     (Rounded ((100.0 * Component) * Rec));

   --  The mode digits: the counter in the ten thousands, then the arming,
   --  the armed state and the modes.
   function Mode_Digits (Inp : Inputs; Count : Unsigned_8) return Unsigned_32 is
      V : Integer_32 := Integer_32 (Count) * 10_000;
   begin
      V := V + (if Inp.Arming_Disabled then 2 else 1);
      if Inp.Armed then
         V := V + 4;
      end if;
      if Inp.Angle_Like then
         V := V + 10;
      end if;
      if Inp.Horizon then
         V := V + 20;
      end if;
      if Inp.Passthru then
         V := V + 40;
      end if;
      if Inp.Mag then
         V := V + 100;
      end if;
      if Inp.Headfree then
         V := V + 4000;
      end if;
      return To_U32 (V);
   end Mode_Digits;

   --  The GPS word: the fix and home fix thousands, the dilution scaled
   --  from its 1.00 to 5.50 range onto nine steps, and the satellites.
   function GPS_Word (Inp : Inputs) return Unsigned_32 is
      Scaled : constant Integer_32 :=
        Adaflight.Maths.Scale_Range (Integer_32 (Inp.Pdop), 100, 550, 9, 0);
      Pdop   : constant Unsigned_32 := Unsigned_32 (Integer_32'Max (0, Integer_32'Min (9, Scaled))) * 100;
   begin
      return (if Inp.Fix then 1000 else 0) + (if Inp.Fix_Home then 2000 else 0) + Pdop + Unsigned_32 (Inp.Num_Sat);
   end GPS_Word;

   --  A coordinate as the receiver takes it: the magnitude in sixths of a
   --  ten-thousandth of a minute, the longitude flag and the sign flag.
   function Coordinate_Word (Value : Integer_32; Longitude : Boolean) return Unsigned_32 is
      Mag : constant Unsigned_32 :=
        (if Value < 0 then Unsigned_32 (-Interfaces.Integer_64 (Value)) else Unsigned_32 (Value));
   begin
      return ((Mag + Mag / 2) / 25) or (if Longitude then 16#8000_0000# else 0)
        or (if Value < 0 then 16#4000_0000# else 0);
   end Coordinate_Word;

   --  The gains or rates word of the cycle step.
   function Tuning_Word (Inp : Inputs; Step : Unsigned_8) return Unsigned_32 is
      G : constant Gains := (case Step is
                                when 0 => Inp.P,
                                when 1 => Inp.I,
                                when 2 => Inp.D,
                                when others => Inp.Rates);
   begin
      return Unsigned_32 (G.Roll) + Interfaces.Shift_Left (Unsigned_32 (G.Pitch), 8)
        + Interfaces.Shift_Left (Unsigned_32 (G.Yaw), 16) + Interfaces.Shift_Left (Unsigned_32 (Step), 24);
   end Tuning_Word;

   -------------
   -- Process --
   -------------

   procedure Process (S : in out Stream; Inp : Inputs; Attempts : Positive; Clear_To_Send : Boolean;
                      O : in out Output; T : in out MSP_Telemetry.Tunnel; FPort : Boolean := False;
                      Resume : Boolean := False) is
      Clear : Boolean := Clear_To_Send;
      Id    : Unsigned_16;
      Sent  : Boolean;

      --  One reply chunk as a server frame, zero past its length.
      procedure Send_MSP_Chunk with Pre => O.Count = 0 is
         Chunk  : MSP_Telemetry.Chunk_Buffer;
         Length : Natural;
         More   : Boolean;
         Value  : Unsigned_32 := 0;
      begin
         MSP_Telemetry.Send_Reply (T, MSP_Chunk, Chunk, Length, More);
         for I in Length .. MSP_Chunk - 1 loop
            Chunk (I) := 0;
         end loop;
         for I in reverse 2 .. MSP_Chunk - 1 loop
            Value := Interfaces.Shift_Left (Value, 8) or Unsigned_32 (Chunk (I));
         end loop;
         Write_Frame (O, MSP_Server_Frame,
                      Unsigned_16 (Chunk (0)) or Interfaces.Shift_Left (Unsigned_16 (Chunk (1)), 8), Value, FPort);
         S.MSP_Pending := More;
      end Send_MSP_Chunk;

      procedure Send (Id : Unsigned_16; Value : Unsigned_32) with Pre => O.Count = 0 is
      begin
         Write_Frame (O, Data_Frame, Id, Value, FPort);
         Sent := True;
      end Send;

      procedure Send_ESC_Value (Id : Unsigned_16; R : ESC_Reading; Field : Natural) with Pre => O.Count = 0 is
      begin
         if R.Present then
            case Field is
               when 0 => Send (Id, Unsigned_32 (R.Voltage));
               when 1 => Send (Id, To_U32 (R.Current));
               when 2 => Send (Id, Rpm_Of (Inp, R.Rpm));
               when others => Send (Id, Unsigned_32 (R.Temperature));
            end case;
         end if;
      end Send_ESC_Value;
   begin
      if Resume then
         S.MSP_Pending := True;
      elsif S.Skip_Requests > 0 then
         S.Skip_Requests := S.Skip_Requests - 1;
      elsif O.Received.Valid
        and then O.Received.Frame_Id in MSP_Client_Frame | MSP_Client_FPort_Frame
      then
         declare
            use type MSP_Telemetry.Outcome;
            R       : constant Payload := O.Received;
            Bytes   : constant Byte_Array (0 .. MSP_Chunk - 1) :=
              (Byte (R.Value_Id and 16#FF#), Byte (Interfaces.Shift_Right (R.Value_Id, 8)),
               Byte (R.Data and 16#FF#), Byte (Interfaces.Shift_Right (R.Data, 8) and 16#FF#),
               Byte (Interfaces.Shift_Right (R.Data, 16) and 16#FF#), Byte (Interfaces.Shift_Right (R.Data, 24)));
            Outcome : MSP_Telemetry.Outcome;
            EEPROM  : Boolean;
         begin
            MSP_Telemetry.Handle_Frame (T, Bytes, Outcome, EEPROM);
            if EEPROM then
               S.Skip_Requests := MSP_Telemetry.Skips_After_EEPROM_Write;
            end if;
            S.MSP_Pending := Outcome = MSP_Telemetry.Error_Reply_Ready;
            if S.Skip_Requests > 0 then
               Clear := False;
            end if;
            if Outcome = MSP_Telemetry.Request_Ready then
               O.MSP_Request := True;
               O.Clear_To_Send := Clear;
               return;
            end if;
         end;
      end if;
      for Attempt in 1 .. Attempts loop
         exit when not Clear or else O.Count /= 0 or else S.Skip_Requests > 0;
         if S.MSP_Pending then
            Send_MSP_Chunk;
            Clear := False;
            exit;
         end if;
         Sent := False;
         if S.Cycle >= ESC_Period then
            if Natural (S.ESC_Index) = S.ESC_Size then
               S.ESC_Index := 0;
               S.Cycle := 0;
               S.Motor := S.Motor + 1;
               if Natural (S.Motor) = Inp.Motors + 1 then
                  S.Motor := 0;
               end if;
            end if;
         end if;
         if S.Cycle < ESC_Period then
            if Natural (S.Index) = S.Size then
               S.Index := 0;
            end if;
            Id := (if Natural (S.Index) < S.Size then S.Table (Natural (S.Index) + 1) else 0);
            S.Index := S.Index + 1;
         else
            Id := (if Natural (S.ESC_Index) < S.ESC_Size then S.ESC_Table (Natural (S.ESC_Index) + 1) else 0)
              + Unsigned_16 (S.Motor);
            S.ESC_Index := S.ESC_Index + 1;
         end if;
         S.Cycle := S.Cycle + 1;
         case Id is
            when Id_Vfas =>
               Send (Id, Unsigned_32 (if Inp.Report_Cell_Voltage then Inp.Cell_Voltage_Cv else Inp.Voltage_Cv));
            when Id_Vfas + 1 .. Id_Vfas + 8 =>
               Send_ESC_Value (Id, ESC_Of (Inp, Natural (Id - Id_Vfas - 1)), 0);
            when Id_Current =>
               Send (Id, To_U32 (Inp.Amperage_Ca / 10));
            when Id_Current + 1 .. Id_Current + 8 =>
               Send_ESC_Value (Id, ESC_Of (Inp, Natural (Id - Id_Current - 1)), 1);
            when Id_Rpm =>
               Send_ESC_Value (Id, Combined (Inp), 2);
            when Id_Rpm + 1 .. Id_Rpm + 8 =>
               Send_ESC_Value (Id, ESC_Of (Inp, Natural (Id - Id_Rpm - 1)), 2);
            when Id_Temp =>
               Send_ESC_Value (Id, Combined (Inp), 3);
            when Id_Temp + 1 .. Id_Temp + 8 =>
               Send_ESC_Value (Id, ESC_Of (Inp, Natural (Id - Id_Temp - 1)), 3);
            when Id_Altitude =>
               Send (Id, To_U32 (Inp.Altitude_Cm));
            when Id_Fuel =>
               Send (Id, (if Inp.Capacity_Set then Unsigned_32 (Inp.Percent_Remaining) else To_U32 (Inp.Mah_Drawn)));
            when Id_Cap_Used =>
               Send (Id, To_U32 (Inp.Mah_Drawn));
            when Id_Vario =>
               Send (Id, To_U32 (Inp.Vario_Cms));
            when Id_Heading =>
               Send (Id, To_U32 (Integer_32 (Inp.Yaw) * 10));
            when Id_Pitch =>
               Send (Id, To_U32 (Inp.Pitch));
            when Id_Roll =>
               Send (Id, To_U32 (Inp.Roll));
            when Id_Acc_X =>
               Send (Id, Acc_Hundredths (Inp.Acc_X, Inp.Acc_1G_Rec));
            when Id_Acc_Y =>
               Send (Id, Acc_Hundredths (Inp.Acc_Y, Inp.Acc_1G_Rec));
            when Id_Acc_Z =>
               Send (Id, Acc_Hundredths (Inp.Acc_Z, Inp.Acc_1G_Rec));
            when Id_T1 =>
               S.T1_Count := S.T1_Count + 1;
               if S.T1_Count = 4 then
                  S.T1_Count := 1;
               end if;
               Send (Id, Mode_Digits (Inp, S.T1_Count));
            when Id_T2 =>
               if Inp.GPS_Present then
                  Send (Id, GPS_Word (Inp));
               elsif Inp.GPS_Feature then
                  Send (Id, 0);
               elsif Inp.Pid_Values then
                  Send (Id, Tuning_Word (Inp, S.T2_Count));
                  S.T2_Count := S.T2_Count + 1;
                  if S.T2_Count = 4 then
                     S.T2_Count := 0;
                  end if;
               end if;
            when Id_T11 =>
               Send (Id, To_U32 (Inp.Core_Temperature));
            when Id_Speed =>
               if Inp.Fix then
                  Send (Id, (Unsigned_32 (Inp.Ground_Speed) * 1944) / 100);
               end if;
            when Id_Lat_Long =>
               if Inp.Fix then
                  if S.Index mod 2 /= 0 then
                     Send (Id, Coordinate_Word (Inp.Lon, True));
                  else
                     Send (Id, Coordinate_Word (Inp.Lat, False));
                  end if;
               end if;
            when Id_Home_Dist =>
               if Inp.Fix then
                  Send (Id, Unsigned_32 (Inp.Home_Distance_M));
               end if;
            when Id_GPS_Alt =>
               if Inp.Fix then
                  Send (Id, To_U32 (Inp.GPS_Altitude_Cm));
               end if;
            when Id_A4 =>
               Send (Id, Unsigned_32 (Inp.Cell_Voltage_Cv));
            when others =>
               null;
         end case;
         if Sent then
            Clear := False;
         end if;
      end loop;
      O.Clear_To_Send := Clear;
   end Process;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Stream; Inp : Inputs; Rx : Byte_Array; Attempts : Positive; O : out Output;
                     Consumed : out Natural; T : in out MSP_Telemetry.Tunnel) is
      Clear : Boolean := False;
      P     : Payload;
   begin
      O := (others => <>);
      Consumed := 0;
      for I in Rx'Range loop
         pragma Loop_Invariant (Consumed = I - Rx'First);
         Receive (S, Rx (I), I = Rx'Last, Clear, P);
         Consumed := Consumed + 1;
         if P.Valid then
            O.Received := P;
            exit;
         end if;
      end loop;
      O.Clear_To_Send := Clear;
      Process (S, Inp, Attempts, Clear, O, T);
   end Update;

end Adaflight.SmartPort_Telemetry;
