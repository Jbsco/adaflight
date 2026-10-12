with Adaflight.Maths;
with Adaflight.Exponentials;

package body Adaflight.CRSF_Telemetry with SPARK_Mode is
   use Interfaces;

   --  Radians times ten thousand per decidegree, the single precision value
   --  of pi over 180 times 1000, and sixteen gravities in meters per second
   --  squared, the single precision value of 16 times 9.80665.
   Scaled_Radians : constant Float := 17.4532928;
   Sixteen_G      : constant Float := 156.906403;
   Gravity        : constant Float := 9.80665;
   Climb_Linear   : constant Float := 100.0;
   Climb_Range    : constant Float := 0.026;

   function U16 (V : Integer_16) return Unsigned_16 is (Unsigned_16'Mod (V));
   function U16 (V : Integer_32) return Unsigned_16 is (Unsigned_16'Mod (V));
   function U32 (V : Integer_32) return Unsigned_32 is (Unsigned_32'Mod (V));

   --  The sync byte, the length and the type open every frame; the checksum
   --  runs from the type to the end.
   procedure Open_Frame (B : in out Byte_Array; S : in out Stream; Length : Byte; Kind : Byte; Start : out Position)
     with Pre  => Fits (S, B) and then Remaining (S) >= 3,
          Post => S.Last = S.Last'Old and then S.Next = S.Next'Old + 3 and then Start = S.Next'Old
   is
   begin
      Start := S.Next;
      Write_U8 (B, S, Sync_Byte);
      Write_U8 (B, S, Length);
      Write_U8 (B, S, Kind);
   end Open_Frame;

   procedure Close_Frame (B : in out Byte_Array; S : in out Stream; Start : Position)
     with Pre  => Fits (S, B) and then Remaining (S) >= 1 and then Start + 2 <= S.Next and then Start >= B'First,
          Post => S.Last = S.Last'Old and then S.Next = S.Next'Old + 1
   is
   begin
      Append_CRC8 (B, S, Start + 2, DVB_S2_Polynomial);
   end Close_Frame;

   ---------------
   -- Write_GPS --
   ---------------

   procedure Write_GPS (B : in out Byte_Array; S : in out Stream; G : GPS_Solution) is
      Start : Position;
      Speed : constant Integer := (Integer (G.Ground_Speed) * 36 + 50) / 100;
      Alt   : constant Integer_32 := Adaflight.Maths.Constrain (G.Altitude_Cm / 100 + 1000, 0, 5000);
   begin
      Open_Frame (B, S, 15 + 2, Type_GPS, Start);
      Write_U32_Big_Endian (B, S, U32 (G.Latitude));
      Write_U32_Big_Endian (B, S, U32 (G.Longitude));
      Write_U16_Big_Endian (B, S, Unsigned_16 (Speed));
      Write_U16_Big_Endian (B, S, Unsigned_16'Mod (Integer (G.Ground_Course) * 10));
      Write_U16_Big_Endian (B, S, Unsigned_16 (Alt));
      Write_U8 (B, S, Byte (G.Satellites));
      Close_Frame (B, S, Start);
   end Write_GPS;

   --------------------
   -- Write_GPS_Time --
   --------------------

   procedure Write_GPS_Time (B : in out Byte_Array; S : in out Stream; G : GPS_Solution) is
      Start : Position;
   begin
      Open_Frame (B, S, 9 + 2, Type_GPS_Time, Start);
      Write_U16_Big_Endian (B, S, G.Year);
      Write_U8 (B, S, Byte (G.Month));
      Write_U8 (B, S, Byte (G.Day));
      Write_U8 (B, S, Byte (G.Hour));
      Write_U8 (B, S, Byte (G.Minute));
      Write_U8 (B, S, Byte (G.Second));
      Write_U16_Big_Endian (B, S, G.Millisecond);
      Close_Frame (B, S, Start);
   end Write_GPS_Time;

   ------------------------
   -- Write_GPS_Extended --
   ------------------------

   procedure Write_GPS_Extended (B : in out Byte_Array; S : in out Stream; G : GPS_Solution) is
      Start    : Position;
      Fix_Type : constant Byte := (if not G.Fix then 1 elsif G.Satellites < 4 then 2 else 3);
      Up       : constant Integer_16 :=
        (if G.Velocity_Down = Integer_16'First then Integer_16'Last else -G.Velocity_Down);
   begin
      Open_Frame (B, S, 20 + 2, Type_GPS_Extended, Start);
      Write_U8 (B, S, Fix_Type);
      Write_U16_Big_Endian (B, S, U16 (G.Velocity_North));
      Write_U16_Big_Endian (B, S, U16 (G.Velocity_East));
      Write_U16_Big_Endian (B, S, U16 (Up));
      Write_U16_Big_Endian (B, S, Unsigned_16'Mod (G.Speed_Accuracy / 10));
      Write_U16_Big_Endian (B, S, Unsigned_16'Mod (G.Heading_Accuracy / 10_000));
      Write_U16_Big_Endian (B, S, U16 (G.Altitude_Cm / 100));
      Write_U16_Big_Endian (B, S, Unsigned_16'Mod (G.Horizontal_Accuracy / 10));
      Write_U16_Big_Endian (B, S, Unsigned_16'Mod (G.Vertical_Accuracy / 10));
      Write_U8 (B, S, 0);
      Write_U8 (B, S, Byte (Unsigned_16'Min (G.HDOP / 10, 255)));
      Write_U8 (B, S, Byte (Unsigned_16'Min (G.VDOP / 10, 255)));
      Close_Frame (B, S, Start);
   end Write_GPS_Extended;

   -----------------
   -- Write_Vario --
   -----------------

   procedure Write_Vario (B : in out Byte_Array; S : in out Stream; Vario : Integer_16) is
      Start : Position;
   begin
      Open_Frame (B, S, 2 + 2, Type_Vario, Start);
      Write_U16_Big_Endian (B, S, U16 (Vario));
      Close_Frame (B, S, Start);
   end Write_Vario;

   ----------------
   -- Write_Baro --
   ----------------

   procedure Write_Baro (B : in out Byte_Array; S : in out Stream; Baro : Barometer_Readings) is
      Start : Position;
   begin
      Open_Frame (B, S, 8 + 2, Type_Baro, Start);
      Write_U32_Big_Endian (B, S, U32 (Baro.Pressure));
      Write_U32_Big_Endian (B, S, U32 (Baro.Temperature));
      Close_Frame (B, S, Start);
   end Write_Baro;

   ---------------
   -- Write_Mag --
   ---------------

   procedure Write_Mag (B : in out Byte_Array; S : in out Stream; Mag : Mag_Readings) is
      Start : Position;
   begin
      Open_Frame (B, S, 6 + 2, Type_Mag, Start);
      Write_U16_Big_Endian (B, S, U16 (Integer_16 (Float'Truncation (Mag.X * 3.0))));
      Write_U16_Big_Endian (B, S, U16 (Integer_16 (Float'Truncation (Mag.Y * 3.0))));
      Write_U16_Big_Endian (B, S, U16 (Integer_16 (Float'Truncation (Mag.Z * 3.0))));
      Close_Frame (B, S, Start);
   end Write_Mag;

   -------------------
   -- Write_Battery --
   -------------------

   procedure Write_Battery (B : in out Byte_Array; S : in out Stream; Bat : Battery_Readings) is
      Start   : Position;
      Voltage : constant Unsigned_16 :=
        (if Bat.Report_Cell_Voltage then Unsigned_16'Mod ((Integer (Bat.Cell_Voltage) + 5) / 10)
         else Bat.Legacy_Voltage);
      Drawn   : constant Unsigned_32 := U32 (Bat.Drawn_Mah);
   begin
      Open_Frame (B, S, 8 + 2, Type_Battery, Start);
      Write_U16_Big_Endian (B, S, Voltage);
      Write_U16_Big_Endian (B, S, U16 (Bat.Amperage / 10));
      Write_U8 (B, S, Byte (Shift_Right (Drawn, 16) and 255));
      Write_U8 (B, S, Byte (Shift_Right (Drawn, 8) and 255));
      Write_U8 (B, S, Byte (Drawn and 255));
      Write_U8 (B, S, Byte (Bat.Remaining_Percent));
      Close_Frame (B, S, Start);
   end Write_Battery;

   ---------------------
   -- Packed_Altitude --
   ---------------------

   function Packed_Altitude (Altitude_Dm : Integer_32) return Unsigned_16 is
      Val_Dm : constant Integer_32 := Altitude_Dm + 10_000;
   begin
      if Val_Dm < 0 then
         return 0;
      elsif Val_Dm < 16#8000# then
         return Unsigned_16 (Val_Dm);
      else
         return Unsigned_16'Mod (Unsigned_32 (Integer_32'Min ((Altitude_Dm + 5) / 10, 16#7FFFE#)) or 16#8000#);
      end if;
   end Packed_Altitude;

   ------------------
   -- Packed_Climb --
   ------------------

   function Packed_Climb (Vertical_Speed : Integer_16) return Integer_8 is
      Sign      : constant Integer := (if Vertical_Speed < 0 then -1 else 1);
      Magnitude : constant Integer := Integer (Vertical_Speed) * Sign;
      X         : constant Float := Float (Magnitude) / Climb_Linear + 1.0;
      L         : constant Float := Adaflight.Exponentials.Log_Approx (X) / Climb_Range;
      R         : constant Integer := Adaflight.Maths.Round_Half_Even (L) * Sign;
   begin
      return Integer_8 (Integer'Max (-128, Integer'Min (127, R)));
   end Packed_Climb;

   --------------------
   -- Write_Altitude --
   --------------------

   procedure Write_Altitude (B : in out Byte_Array; S : in out Stream; Baro : Barometer_Readings; Vario : Integer_16) is
      Start : Position;
      Dm    : constant Integer_32 := Integer_32 (Float'Truncation ((Baro.Altitude_Cm + 5.0) / 10.0));
   begin
      Open_Frame (B, S, 3 + 2, Type_Baro_Altitude, Start);
      Write_U16_Big_Endian (B, S, Packed_Altitude (Dm));
      Write_U8 (B, S, Byte (Unsigned_8'Mod (Packed_Climb (Vario))));
      Close_Frame (B, S, Start);
   end Write_Altitude;

   ---------------------
   -- Write_Heartbeat --
   ---------------------

   procedure Write_Heartbeat (B : in out Byte_Array; S : in out Stream) is
      Start : Position;
   begin
      Open_Frame (B, S, 2 + 2, Type_Heartbeat, Start);
      Write_U16_Big_Endian (B, S, Unsigned_16 (Address_Flight_Controller));
      Close_Frame (B, S, Start);
   end Write_Heartbeat;

   ----------------
   -- Write_Ping --
   ----------------

   procedure Write_Ping (B : in out Byte_Array; S : in out Stream) is
      Start : Position;
   begin
      Open_Frame (B, S, 2 + 2, Type_Ping, Start);
      Write_U8 (B, S, Address_Receiver);
      Write_U8 (B, S, Address_Flight_Controller);
      Close_Frame (B, S, Start);
   end Write_Ping;

   -------------------
   -- Radians_10000 --
   -------------------

   function Radians_10000 (Angle : Integer_16) return Integer_16 is
      A : Integer := Integer (Angle);
   begin
      while A > 1800 loop
         A := A - 3600;
         pragma Loop_Invariant (A in -1799 .. Integer (Integer_16'Last) - 3600);
         pragma Loop_Variant (Decreases => A);
      end loop;
      while A < -1800 loop
         A := A + 3600;
         pragma Loop_Invariant (A in Integer (Integer_16'First) + 3600 .. 1799);
         pragma Loop_Variant (Increases => A);
      end loop;
      pragma Assert (A in -1800 .. 1800);
      declare
         subtype Half_Turn is Float range -1800.0 .. 1800.0;
         subtype Scaled is Float range -31_416.0 .. 31_416.0;
         X : constant Half_Turn := Float (A);
         P : constant Scaled := Scaled_Radians * X;
      begin
         return Integer_16 (Float'Truncation (P));
      end;
   end Radians_10000;

   --------------------
   -- Write_Attitude --
   --------------------

   procedure Write_Attitude (B : in out Byte_Array; S : in out Stream; A : Attitude_Angles) is
      Start : Position;
   begin
      Open_Frame (B, S, 6 + 2, Type_Attitude, Start);
      Write_U16_Big_Endian (B, S, U16 (Radians_10000 (A.Pitch)));
      Write_U16_Big_Endian (B, S, U16 (Radians_10000 (A.Roll)));
      Write_U16_Big_Endian (B, S, U16 (Radians_10000 (A.Yaw)));
      Close_Frame (B, S, Start);
   end Write_Attitude;

   -----------------------
   -- Write_Flight_Mode --
   -----------------------

   procedure Write_Flight_Mode (B : in out Byte_Array; S : in out Stream; F : Flight_State;
                                Satellites : Unsigned_8; Fix : Boolean) is
      Start  : Position;
      Mode   : String (1 .. 4) := "ACRO";
      Last   : Natural range 3 .. 4 := 4;
      Suffix : constant Boolean := not F.Armed and then (F.Mode_Flags and Mode_Failsafe) = 0;
      Rescue_Off : constant Boolean :=
        F.GPS_Feature and then F.Rescue_Configured and then Satellites < F.Rescue_Min_Satellites and then not Fix;
      Length : Byte;
   begin
      if (F.Mode_Flags and Mode_Failsafe) /= 0 or else F.Failsafe_Switch then
         Mode := "!FS!";
      elsif (F.Mode_Flags and Mode_GPS_Rescue) /= 0 or else F.Rescue_Switch or else F.Rescue_Plan then
         Mode := "RTH ";
         Last := 3;
      elsif (F.Mode_Flags and Mode_Passthru) /= 0 then
         Mode := "PASS";
      elsif (F.Mode_Flags and Mode_Pos_Hold) /= 0 then
         Mode := (if F.Position_Hold_Failure then "PHFL" else "POSH");
      elsif (F.Mode_Flags and Mode_Alt_Hold) /= 0 then
         Mode := "ALTH";
      elsif (F.Mode_Flags and Mode_Angle) /= 0 then
         Mode := "ANGL";
      elsif (F.Mode_Flags and Mode_Horizon) /= 0 then
         Mode := "HOR ";
         Last := 3;
      elsif (F.Mode_Flags and Mode_Chirp) /= 0 then
         Mode := "CHIR";
      elsif F.Airmode then
         Mode := "AIR ";
         Last := 3;
      end if;
      Length := Byte (Last + (if Suffix then 1 else 0) + 1 + 2);
      Open_Frame (B, S, Length, Type_Flight_Mode, Start);
      Write_String (B, S, Mode (1 .. Last));
      if Suffix then
         Write_U8 (B, S, (if F.Arming_Disabled then Character'Pos ('!')
                          elsif Rescue_Off then Character'Pos ('?') else Character'Pos ('*')));
      end if;
      Write_U8 (B, S, 0);
      Close_Frame (B, S, Start);
   end Write_Flight_Mode;

   -----------------------
   -- Write_Device_Info --
   -----------------------

   procedure Write_Device_Info (B : in out Byte_Array; S : in out Stream; Name : String) is
      Start : Position;
   begin
      Open_Frame (B, S, Byte (Name'Length + 19), Type_Device_Info, Start);
      Write_U8 (B, S, Address_Radio_Transmitter);
      Write_U8 (B, S, Address_Flight_Controller);
      Write_String_With_Terminator (B, S, Name);
      Fill (B, S, 0, 12);
      Write_U8 (B, S, 0);
      Write_U8 (B, S, 1);
      Close_Frame (B, S, Start);
   end Write_Device_Info;

   --------------------
   -- Write_Inertial --
   --------------------

   procedure Write_Inertial (B : in out Byte_Array; S : in out Stream; Now : Time_Us; IMU : IMU_Sample) is
      use Adaflight.Maths;

      function Rate_Word (X : Rate_Dps) return Unsigned_16 is
        (U16 (Constrain (Integer_32 (Float'Truncation ((Constrain_F (X, -2000.0, 2000.0) * 32767.0) / 2000.0)),
                         -32767, 32767)));

      function Acc_Word (X : Float) return Unsigned_16 is
        (U16 (Constrain (Integer_32 (Float'Truncation ((Constrain_F (X, -Sixteen_G, Sixteen_G) * 32767.0) / Sixteen_G)),
                         -32767, 32767)))
        with Pre => X in -1.0E8 .. 1.0E8;

      function Acc_Mss (Axis : Natural) return Float is
        ((IMU.Acc (Axis) * IMU.Acc_1G_Reciprocal) * Gravity)
        with Pre => Axis <= 2, Post => Acc_Mss'Result in -1.0E8 .. 1.0E8;

      Start : Position;
      Temp  : constant Integer_32 := Constrain (Integer_32 (IMU.Temperature) * 100, -32768, 32767);
   begin
      if not IMU.Fresh then
         return;
      end if;
      Open_Frame (B, S, 18 + 2, Type_Inertial, Start);
      Write_U32_Big_Endian (B, S, Now);
      Write_U16_Big_Endian (B, S, Rate_Word (IMU.Gyro (0)));
      Write_U16_Big_Endian (B, S, Rate_Word (-IMU.Gyro (1)));
      Write_U16_Big_Endian (B, S, Rate_Word (-IMU.Gyro (2)));
      Write_U16_Big_Endian (B, S, Acc_Word (Acc_Mss (0)));
      Write_U16_Big_Endian (B, S, Acc_Word (-Acc_Mss (1)));
      Write_U16_Big_Endian (B, S, Acc_Word (-Acc_Mss (2)));
      Write_U16_Big_Endian (B, S, U16 (Temp));
      Close_Frame (B, S, Start);
   end Write_Inertial;

   ------------------------
   -- Write_MSP_Response --
   ------------------------

   procedure Write_MSP_Response (B : in out Byte_Array; S : in out Stream; Origin : Byte; Payload : Byte_Array) is
      Start : Position;
   begin
      Open_Frame (B, S, Byte (Payload'Length + 4), Type_MSP_Response, Start);
      Write_U8 (B, S, Origin);
      Write_U8 (B, S, Address_Flight_Controller);
      Write_Data (B, S, Payload);
      Close_Frame (B, S, Start);
   end Write_MSP_Response;

   --------------------------
   -- Write_Speed_Response --
   --------------------------

   procedure Write_Speed_Response (B : in out Byte_Array; S : in out Stream; Port : Unsigned_8; Reply : Boolean) is
      Start : Position;
   begin
      Open_Frame (B, S, 9, Type_Command, Start);
      Write_U8 (B, S, Address_Receiver);
      Write_U8 (B, S, Address_Flight_Controller);
      Write_U8 (B, S, Command_General);
      Write_U8 (B, S, Command_Speed_Response);
      Write_U8 (B, S, Byte (Port));
      Write_U8 (B, S, (if Reply then 1 else 0));
      Append_CRC8 (B, S, Start + 2, Command_Polynomial);
      Close_Frame (B, S, Start);
   end Write_Speed_Response;

   ----------
   -- Init --
   ----------

   procedure Init (T : in out Telemetry; Cfg : Config; Active : Boolean) is
      function Enabled (Kinds : Unsigned_32) return Boolean is (((not Cfg.Disabled_Kinds) and Kinds) /= 0);
      Idx   : Natural range 0 .. Schedule_Max := 0;
      Sched : Slots := T.Schedule;
      procedure Add (Slot : Unsigned_16)
        with Pre => Idx < Schedule_Max, Post => Idx = Idx'Old + 1
      is
      begin
         Sched (Idx) := Slot;
         Idx := Idx + 1;
      end Add;
   begin
      T.Enabled := Active;
      if not Active then
         return;
      end if;
      T.Inertial_Frames := Cfg.Inertial_Frames;
      T.Event_Driven := Cfg.Event_Driven;
      T.Use_Negotiated_Baud := Cfg.Use_Negotiated_Baud;
      T.Telemetry_Feature := Cfg.Telemetry_Feature;
      T.Device_Info_Pending := False;
      T.Response_Pending := False;
      T.Timed := 0;
      if Cfg.Acc_Present and then Enabled (Kind_Pitch or Kind_Roll or Kind_Heading) then
         Add (Slot_Attitude);
      end if;
      if Enabled (Kind_Altitude) then
         Add (Slot_Baro_Altitude);
      end if;
      if (Cfg.Voltage_Configured and then Enabled (Kind_Voltage))
        or else (Cfg.Amperage_Configured and then Enabled (Kind_Current or Kind_Fuel))
      then
         Add (Slot_Battery);
      end if;
      if Enabled (Kind_Mode) then
         Add (Slot_Flight_Mode);
      end if;
      if Cfg.Baro_Present then
         T.Timed := T.Timed or Timed_Baro;
      end if;
      if Cfg.Mag_Present then
         Add (Slot_Mag);
      end if;
      if Cfg.GPS_Feature and then Enabled (Kind_Altitude or Kind_Lat_Long or Kind_Ground_Speed or Kind_Heading) then
         T.Timed := T.Timed or Timed_GPS or Timed_GPS_Time or Timed_GPS_Extended;
      end if;
      if Cfg.Inertial_Frames and then (Cfg.Acc_Present or else Cfg.Gyro_Present) then
         T.Timed := T.Timed or Timed_Inertial;
      end if;
      if (Cfg.Baro_Present or else Cfg.GPS_Feature) and then Enabled (Kind_Vario) then
         Add (Slot_Vario);
      end if;
      if (T.Timed and Timed_Inertial) = 0 then
         while Idx < Cycle_Time_Us / Frame_Interval_Max_Us loop
            Add (Slot_Heartbeat);
            pragma Loop_Invariant (Idx <= Cycle_Time_Us / Frame_Interval_Max_Us);
            pragma Loop_Variant (Increases => Idx);
         end loop;
      end if;
      T.Schedule := Sched;
      T.Count := Idx;
   end Init;

   ------------------
   -- Update_Check --
   ------------------

   procedure Update_Check (T : in out Telemetry; Now : Time_Us; Run : out Boolean) is
   begin
      if T.Device_Info_Pending then
         Run := True;
      elsif not T.Response_Pending then
         Run := False;
      elsif Adaflight.Clock.Elapsed (Now, T.Last_Check_Time) < Frame_Interval_Max_Us then
         Run := False;
      else
         T.Last_Check_Time := Now;
         Run := True;
      end if;
   end Update_Check;

   -----------------------
   -- Schedule_Response --
   -----------------------

   procedure Schedule_Response (T : in out Telemetry) is
   begin
      T.Response_Pending := True;
   end Schedule_Response;

   --------------------------
   -- Schedule_Device_Info --
   --------------------------

   procedure Schedule_Device_Info (T : in out Telemetry) is
   begin
      T.Device_Info_Pending := True;
   end Schedule_Device_Info;

   ---------------------
   -- Process_Command --
   ---------------------

   procedure Process_Command (T : in out Telemetry; Payload : Byte_Array) is
      F    : constant Natural := Payload'First;
      Baud : Unsigned_32;
   begin
      if Payload (F) /= Command_General or else Payload (F + 1) /= Command_Speed_Proposal then
         return;
      end if;
      Baud := Shift_Left (Unsigned_32 (Payload (F + 3)), 24) or Shift_Left (Unsigned_32 (Payload (F + 4)), 16)
        or Shift_Left (Unsigned_32 (Payload (F + 5)), 8) or Unsigned_32 (Payload (F + 6));
      T.Speed.Index := Baud_Count;
      for I in Baud_Table'Range loop
         if Baud_Rates (I) = Baud then
            T.Speed.Index := I;
            exit;
         end if;
      end loop;
      T.Speed.Port_Id := Unsigned_8 (Payload (F + 2) and 7);
      T.Speed.Pending_Reply := True;
      T.Speed.New_Speed_Valid := False;
   end Process_Command;

   ---------------
   -- Negotiate --
   ---------------

   procedure Negotiate (T : in out Telemetry; Now : Time_Us; B : in out Byte_Array; S : in out Stream;
                        New_Baud : out Unsigned_32) is
      Found : Boolean;
   begin
      New_Baud := 0;
      if T.Speed.Pending_Reply then
         Found := T.Speed.Index < Baud_Count and then T.Use_Negotiated_Baud;
         Write_Speed_Response (B, S, T.Speed.Port_Id, Found);
         T.Speed.Pending_Reply := False;
         T.Speed.New_Speed_Valid := Found;
         T.Speed.Confirmation_Time := Now;
      elsif T.Speed.New_Speed_Valid then
         if Adaflight.Clock.Elapsed (Now, T.Speed.Confirmation_Time) >= Speed_Confirm_Us then
            New_Baud := Desired_Speed (T);
            T.Speed.New_Speed_Valid := False;
            T.V3_Running := True;
         end if;
      elsif not T.Telemetry_Feature and then T.Use_Negotiated_Baud then
         Write_Heartbeat (B, S);
      end if;
   end Negotiate;

   -------------
   -- Process --
   -------------

   --  The timed frames first, one per pass, then the next slot once the
   --  cycle time divided by the slot count has passed.
   procedure Process (T : in out Telemetry; Now : Time_Us; Src : Sources; B : in out Byte_Array; S : in out Stream;
                      Sent : out Boolean)
     with Pre  => Fits (S, B) and then Remaining (S) >= Update_Room,
          Post => S.Last = S.Last'Old and then S.Next in S.Next'Old .. S.Next'Old + Update_Room
                  and then (if not Sent then S.Next = S.Next'Old)
   is
      Current : Unsigned_16;
   begin
      Sent := True;
      if (T.Timed and Timed_GPS_Time) /= 0 and then not Src.Flight.Armed and then Src.GPS.Date_Valid
        and then Src.GPS.Time /= T.Last_GPS_Time_Solution_Time
        and then Adaflight.Clock.Elapsed (Now, T.Last_GPS_Time_Frame_Time) > GPS_Time_Interval_Us
      then
         Write_GPS_Time (B, S, Src.GPS);
         T.Last_GPS_Time_Solution_Time := Src.GPS.Time;
         T.Last_GPS_Time_Frame_Time := Now;
         return;
      end if;
      if T.V3_Running and then (T.Timed and Timed_GPS_Extended) /= 0
        and then Src.GPS.Time /= T.Last_GPS_Solution_Time
      then
         Write_GPS_Extended (B, S, Src.GPS);
         T.Timed := T.Timed and not Timed_GPS_Extended;
         return;
      end if;
      if (T.Timed and Timed_GPS) /= 0 and then Src.GPS.Time /= T.Last_GPS_Solution_Time then
         Write_GPS (B, S, Src.GPS);
         if T.V3_Running then
            T.Timed := T.Timed or Timed_GPS_Extended or Timed_GPS_Time;
         end if;
         T.Last_GPS_Solution_Time := Src.GPS.Time;
         return;
      end if;
      if (T.Timed and Timed_Baro) /= 0 and then Adaflight.Clock.Elapsed (Now, T.Last_Baro_Time) > Baro_Interval_Us then
         Write_Baro (B, S, Src.Baro);
         T.Last_Baro_Time := Now;
         return;
      end if;
      Sent := False;
      if T.Count = 0 then
         return;
      end if;
      if Now < T.Last_Cycle_Time + Unsigned_32 (Cycle_Time_Us / T.Count) then
         return;
      end if;
      Current := T.Schedule (T.Index);
      if (Current and Slot_Attitude) /= 0 then
         Write_Attitude (B, S, Src.Attitude);
      end if;
      if (Current and Slot_Baro_Altitude) /= 0 then
         Write_Altitude (B, S, Src.Baro, Src.Vario);
      end if;
      if (Current and Slot_Battery) /= 0 then
         Write_Battery (B, S, Src.Battery);
      end if;
      if (Current and Slot_Flight_Mode) /= 0 then
         Write_Flight_Mode (B, S, Src.Flight, Src.GPS.Satellites, Src.GPS.Fix);
      end if;
      if (Current and Slot_Mag) /= 0 then
         Write_Mag (B, S, Src.Mag);
      end if;
      if (Current and Slot_GPS) /= 0 then
         Write_GPS (B, S, Src.GPS);
      end if;
      if (Current and Slot_Vario) /= 0 then
         Write_Vario (B, S, Src.Vario);
      end if;
      if (Current and Slot_Heartbeat) /= 0 then
         Write_Heartbeat (B, S);
      end if;
      T.Index := (T.Index + 1) mod T.Count;
      Sent := True;
   end Process;

   ------------
   -- Update --
   ------------

   procedure Update (T : in out Telemetry; Now : Time_Us; Src : Sources; B : in out Byte_Array; S : in out Stream) is
      Sent : Boolean;
   begin
      if not T.Enabled or else Negotiation_In_Progress (T) then
         return;
      end if;
      if T.Device_Info_Pending then
         Write_Device_Info (B, S, Src.Name (1 .. Src.Name_Last));
         T.Device_Info_Pending := False;
         T.Response_Pending := False;
         T.Last_Cycle_Time := Now;
         return;
      end if;
      if T.Event_Driven and then not T.Response_Pending then
         return;
      end if;
      Process (T, Now, Src, B, S, Sent);
      if Sent then
         T.Last_Cycle_Time := Now;
      elsif T.Inertial_Frames and then T.Event_Driven then
         Write_Inertial (B, S, Now, Src.IMU);
      end if;
      T.Response_Pending := False;
   end Update;

end Adaflight.CRSF_Telemetry;
