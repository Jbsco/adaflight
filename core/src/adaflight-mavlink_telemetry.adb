with Adaflight.Float_Bits;
with Adaflight.MAVLink;

package body Adaflight.MAVLink_Telemetry with SPARK_Mode is
   use type Interfaces.Unsigned_64;
   use type Adaflight.Battery.Battery_State;

   Max_Payload : constant := 60;
   subtype Payload_Index is Natural range 0 .. Max_Payload - 1;
   type Payload is array (Payload_Index) of Unsigned_8;

   System_Id    : constant := 1;
   Component_Id : constant := 1;

   function Bits_16 (V : Integer_32) return Unsigned_16 is
     (Unsigned_16 (Interfaces.Integer_64 (V) mod 65_536));

   function Bits_32 (V : Integer_32) return Unsigned_32 is
     (Unsigned_32 (Interfaces.Integer_64 (V) mod 2 ** 32));

   procedure Put_U8 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_8)
     with Global => null
   is
   begin
      P (At_Byte) := V;
   end Put_U8;

   procedure Put_U16 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_16)
     with Global => null, Pre => At_Byte <= Max_Payload - 2
   is
   begin
      P (At_Byte) := Unsigned_8 (V and 16#FF#);
      P (At_Byte + 1) := Unsigned_8 (Interfaces.Shift_Right (V, 8));
   end Put_U16;

   procedure Put_U32 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_32)
     with Global => null, Pre => At_Byte <= Max_Payload - 4
   is
   begin
      for K in 0 .. 3 loop
         P (At_Byte + K) := Unsigned_8 (Interfaces.Shift_Right (V, 8 * K) and 16#FF#);
      end loop;
   end Put_U32;

   procedure Put_U64 (P : in out Payload; At_Byte : Payload_Index; V : Interfaces.Unsigned_64)
     with Global => null, Pre => At_Byte <= Max_Payload - 8
   is
   begin
      for K in 0 .. 7 loop
         P (At_Byte + K) := Unsigned_8 (Interfaces.Shift_Right (V, 8 * K) and 16#FF#);
      end loop;
   end Put_U64;

   procedure Put_F32 (P : in out Payload; At_Byte : Payload_Index; V : Float)
     with Global => null, Pre => At_Byte <= Max_Payload - 4
   is
   begin
      Put_U32 (P, At_Byte, Adaflight.Float_Bits.Float_Bits (V));
   end Put_F32;

   procedure Frame
     (S : in out State; O : in out Output; Id : Natural; CRC_Extra : Unsigned_8; P : Payload; Max_Len : Positive)
     with Global => null, Pre => Id <= 255 and then Max_Len <= Max_Payload
   is
      Len    : Natural := Max_Len;
      Header : constant array (1 .. 9) of Unsigned_8 :=
        (0, 0, 0, S.Tx_Seq, System_Id, Component_Id, Unsigned_8 (Id), 0, 0);
      CRC    : Adaflight.MAVLink.CRC_Word := Adaflight.MAVLink.CRC_Init;
   begin
      while Len > 1 and then P (Len - 1) = 0 loop
         pragma Loop_Invariant (Len in 2 .. Max_Len);
         Len := Len - 1;
      end loop;
      if O.Length > Max_Output - (12 + Len) then
         return;
      end if;
      CRC := Adaflight.MAVLink.Accumulate (CRC, Len);
      for K in 2 .. Header'Last loop
         CRC := Adaflight.MAVLink.Accumulate (CRC, Natural (Header (K)));
      end loop;
      for K in 0 .. Len - 1 loop
         CRC := Adaflight.MAVLink.Accumulate (CRC, Natural (P (K)));
      end loop;
      CRC := Adaflight.MAVLink.Accumulate (CRC, Natural (CRC_Extra));
      O.Data (O.Length + 1) := 16#FD#;
      O.Data (O.Length + 2) := Unsigned_8 (Len);
      for K in 2 .. Header'Last loop
         O.Data (O.Length + 1 + K) := Header (K);
      end loop;
      for K in 0 .. Len - 1 loop
         O.Data (O.Length + 11 + K) := P (K);
      end loop;
      O.Data (O.Length + 11 + Len) := Unsigned_8 (CRC and 16#FF#);
      O.Data (O.Length + 12 + Len) := Unsigned_8 (Interfaces.Shift_Right (CRC, 8));
      O.Length := O.Length + 12 + Len;
      S.Tx_Seq := S.Tx_Seq + 1;
   end Frame;

   procedure Send_System_Time (S : in out State; Inp : Inputs; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null
   is
      P    : Payload := (others => 0);
      Unix : Interfaces.Unsigned_64 := 0;
   begin
      if Inp.Has_Time and then Inp.RTC_Ms > 0 then
         Unix := Interfaces.Unsigned_64 (Inp.RTC_Ms) * 1000;
      end if;
      Put_U64 (P, 0, Unix);
      Put_U32 (P, 8, Now_Ms);
      Frame (S, O, 2, 137, P, 12);
   end Send_System_Time;

   procedure Send_Sys_Status (S : in out State; Inp : Inputs; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null
   is
      P         : Payload := (others => 0);
      Present   : Unsigned_32 := 35_843;
      Voltage   : Unsigned_16 := 0;
      Current   : Unsigned_16 := 16#FFFF#;
      Remaining : Unsigned_8 := 100;
   begin
      if Inp.Mag_Present then
         Present := Present or 4_100;
      end if;
      if Inp.Baro_Present then
         Present := Present or 8_200;
      end if;
      if Inp.GPS_Present then
         Present := Present or 16_416;
      end if;
      if Inp.Battery in Adaflight.Battery.OK | Adaflight.Battery.Warning | Adaflight.Battery.Critical then
         if Inp.Voltage_Configured then
            Voltage := Unsigned_16 ((Unsigned_32 (Inp.Pack_Voltage) * 10) mod 65_536);
         end if;
         if Inp.Amperage_Configured then
            Current := Bits_16 (Inp.Amperage);
         end if;
         if Inp.Voltage_Configured then
            Remaining := Inp.Battery_Percent;
         end if;
      end if;
      Put_U32 (P, 0, Present);
      Put_U32 (P, 4, Present);
      Put_U32 (P, 8, Present and 1_023);
      Put_U16 (P, 14, Voltage);
      Put_U16 (P, 16, Current);
      Put_U8 (P, 30, Remaining);
      Frame (S, O, 1, 124, P, 43);
      Send_System_Time (S, Inp, Now_Ms, O);
   end Send_Sys_Status;

   procedure Send_RC_Channels (S : in out State; Inp : Inputs; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U32 (P, 0, Now_Ms);
      for K in 0 .. 7 loop
         if Inp.Channel_Count >= K + 1 then
            Put_U16 (P, 4 + 2 * K, Unsigned_16 (Float'Truncation (Inp.RC (K))));
         end if;
      end loop;
      Put_U8 (P, 21, Unsigned_8 (((254 * Unsigned_32 (Inp.RSSI)) / 1023) mod 256));
      Frame (S, O, 35, 244, P, 22);
   end Send_RC_Channels;

   procedure Send_GPS_Raw (S : in out State; Inp : Inputs; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
      P   : Payload := (others => 0);
      Fix : Unsigned_8;
   begin
      if not Inp.GPS_Present then
         return;
      end if;
      Fix := (if not Inp.GPS_Fix then 1 elsif Inp.Satellites < 4 then 2 else 3);
      Put_U64 (P, 0, Interfaces.Unsigned_64 (Now_Us));
      Put_U32 (P, 8, Bits_32 (Inp.Latitude));
      Put_U32 (P, 12, Bits_32 (Inp.Longitude));
      Put_U32 (P, 16, Bits_32 (Inp.Altitude_Cm * 10));
      Put_U16 (P, 20, Inp.HDOP);
      Put_U16 (P, 22, Inp.VDOP);
      Put_U16 (P, 24, Inp.Ground_Speed);
      Put_U16 (P, 26, Unsigned_16 ((Unsigned_32 (Inp.Ground_Course) * 10) mod 65_536));
      Put_U8 (P, 28, Fix);
      Put_U8 (P, 29, Inp.Satellites);
      Put_U32 (P, 30, Bits_32 (Inp.Altitude_Cm * 10));
      Put_U32 (P, 34, Inp.H_Acc);
      Put_U32 (P, 38, Inp.V_Acc);
      Put_U32 (P, 42, Inp.S_Acc);
      Put_U32 (P, 46, Unsigned_32'Last);
      Frame (S, O, 24, 24, P, 52);
   end Send_GPS_Raw;

   procedure Send_Global_Position (S : in out State; Inp : Inputs; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      if not Inp.GPS_Present then
         return;
      end if;
      Put_U32 (P, 0, Now_Us);
      Put_U32 (P, 4, Bits_32 (Inp.Latitude));
      Put_U32 (P, 8, Bits_32 (Inp.Longitude));
      Put_U32 (P, 12, Bits_32 (Inp.Altitude_Cm * 10));
      Put_U32 (P, 16, Bits_32 (Inp.Estimated_Alt_Cm * 10));
      Put_U16 (P, 20, Bits_16 (Integer_32 (Inp.Vel_N)));
      Put_U16 (P, 22, Bits_16 (Integer_32 (Inp.Vel_E)));
      Put_U16 (P, 24, Bits_16 (Integer_32 (Inp.Vel_D)));
      Put_U16 (P, 26, Bits_16 (Integer_32 (Inp.Yaw) * 10));
      Frame (S, O, 33, 104, P, 28);
   end Send_Global_Position;

   procedure Send_Global_Origin (S : in out State; Inp : Inputs; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      if not Inp.GPS_Present or else not Inp.GPS_Fix_Home then
         return;
      end if;
      Put_U32 (P, 0, Bits_32 (Inp.Home_Latitude));
      Put_U32 (P, 4, Bits_32 (Inp.Home_Longitude));
      Put_U32 (P, 8, Bits_32 (Inp.Home_Altitude_Cm * 10));
      Put_U64 (P, 12, Interfaces.Unsigned_64 (Now_Us));
      Frame (S, O, 49, 39, P, 20);
   end Send_Global_Origin;

   procedure Send_Home_Position (S : in out State; Inp : Inputs; Now_Us : Unsigned_32; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      if not Inp.GPS_Fix_Home then
         return;
      end if;
      Put_U32 (P, 0, Bits_32 (Inp.Home_Latitude));
      Put_U32 (P, 4, Bits_32 (Inp.Home_Longitude));
      Put_U32 (P, 8, Bits_32 (Inp.Home_Altitude_Cm * 10));
      Put_F32 (P, 24, 1.0);
      Put_U64 (P, 52, Interfaces.Unsigned_64 (Now_Us));
      Frame (S, O, 242, 104, P, 60);
   end Send_Home_Position;

   Decidegree_Radians : constant Float := 0.0174532925;

   procedure Send_Attitude (S : in out State; Inp : Inputs; Now_Ms : Unsigned_32; O : in out Output)
     with Global => null
   is
      P : Payload := (others => 0);
   begin
      Put_U32 (P, 0, Now_Ms);
      Put_F32 (P, 4, Float (Inp.Roll) / 10.0 * Decidegree_Radians);
      Put_F32 (P, 8, Float (-Integer_32 (Inp.Pitch)) / 10.0 * Decidegree_Radians);
      Put_F32 (P, 12, Float (Inp.Yaw) / 10.0 * Decidegree_Radians);
      Frame (S, O, 30, 39, P, 28);
   end Send_Attitude;

   function Custom_Mode (Inp : Inputs) return Unsigned_32 is
     (if (Inp.Modes and 16#0400#) /= 0 or else Inp.Failsafe_Active then 7
      elsif (Inp.Modes and 16#0800#) /= 0 then 6
      elsif (Inp.Modes and 16#1000#) /= 0 then 5
      elsif (Inp.Modes and 16#0020#) /= 0 then 4
      elsif (Inp.Modes and 16#0008#) /= 0 then 3
      elsif (Inp.Modes and 16#0002#) /= 0 then 2
      elsif (Inp.Modes and 16#0001#) /= 0 then 1
      else 0);

   function System_Type (Mixer_Mode : Unsigned_8) return Unsigned_8 is
     (case Mixer_Mode is
        when 1 => 15,
        when 2 | 3 | 9 | 17 => 2,
        when 6 | 7 | 10 => 13,
        when 11 | 27 | 12 | 13 => 14,
        when 8 | 14 | 24 => 1,
        when 15 | 16 => 4,
        when others => 0);

   procedure Send_Heartbeat (S : in out State; Inp : Inputs; O : in out Output)
     with Global => null
   is
      P    : Payload := (others => 0);
      Base : Unsigned_8 := 64;
      Mode : constant Unsigned_32 := Custom_Mode (Inp);
   begin
      if Inp.Armed then
         Base := Base or 192;
      end if;
      if Mode /= 0 then
         Base := Base or 16;
      end if;
      Put_U32 (P, 0, Mode);
      Put_U8 (P, 4, System_Type (Inp.Mixer_Mode));
      Put_U8 (P, 6, Base);
      Put_U8 (P, 7, (if Inp.Armed then (if Inp.Failsafe_Active then 5 else 4) else 3));
      Put_U8 (P, 8, 3);
      Frame (S, O, 0, 50, P, 9);
   end Send_Heartbeat;

   procedure Send_HUD (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      P        : Payload := (others => 0);
      Ground   : constant Float := (if Inp.GPS_Present then Float (Inp.Ground_Speed) / 100.0 else 0.0);
      Throttle : constant Integer_32 :=
        Integer_32'Max (1_000, Integer_32'Min (2_000, Integer_32 (Float'Truncation (Inp.RC (3)))));
      Heading  : constant Integer_32 :=
        (if Inp.Amperage_Configured and then C.MAh_Heading_Divisor > 0
         then Inp.MAh_Drawn / Integer_32 (C.MAh_Heading_Divisor) else Integer_32 (Inp.Yaw) / 10);
   begin
      Put_F32 (P, 4, Ground);
      Put_F32 (P, 8, Float (Inp.Estimated_Alt_Cm) / 100.0);
      Put_U16 (P, 16, Bits_16 (Heading));
      Put_U16 (P, 18, Unsigned_16 ((100 * (Throttle - 1_000)) / 1_000));
      Frame (S, O, 74, 20, P, 20);
   end Send_HUD;

   procedure Send_Battery (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      P    : Payload := (others => 0);
      Cell : constant Unsigned_16 := Unsigned_16 ((Unsigned_32 (Inp.Cell_Voltage) * 10) mod 65_536);
   begin
      Put_U32 (P, 0, (if Inp.Amperage_Configured then Bits_32 (Inp.MAh_Drawn) else Unsigned_32'Last));
      Put_U32 (P, 4, Unsigned_32'Last);
      Put_U16 (P, 8, 32_767);
      for K in 0 .. 9 loop
         Put_U16 (P, 10 + 2 * K, 16#FFFF#);
      end loop;
      if Inp.Voltage_Configured then
         if Inp.Cell_Count > 0 and then C.Report_Cell_Voltage then
            for K in 0 .. Natural'Min (Natural (Inp.Cell_Count), 14) - 1 loop
               if K < 10 then
                  Put_U16 (P, 10 + 2 * K, Cell);
               else
                  Put_U16 (P, 41 + 2 * (K - 10), Cell);
               end if;
            end loop;
         else
            Put_U16 (P, 10, Unsigned_16 ((Unsigned_32 (Inp.Pack_Voltage) * 10) mod 65_536));
         end if;
      end if;
      Put_U16 (P, 30, (if Inp.Amperage_Configured then Bits_16 (Inp.Amperage) else 16#FFFF#));
      Put_U8 (P, 35, (if Inp.Voltage_Configured then Inp.Battery_Percent else 16#FF#));
      Frame (S, O, 147, 154, P, 54);
   end Send_Battery;

   procedure Send_Arming_Text (S : in out State; Inp : Inputs; O : in out Output)
     with Global => null
   is
      use Adaflight.Arming;
      Prefix : constant String := "Arming disabled:";
      Text   : array (0 .. 49) of Unsigned_8 := (others => 0);
      Pos    : Natural range 0 .. 49 := Prefix'Length;
      P      : Payload := (others => 0);
   begin
      if Inp.Disable_Flags = S.Last_Flags then
         return;
      end if;
      S.Last_Flags := Inp.Disable_Flags;
      if Inp.Disable_Flags = Disable_Set'(others => False) then
         return;
      end if;
      for K in Prefix'Range loop
         Text (K - Prefix'First) := Character'Pos (Prefix (K));
      end loop;
      for R in Disable_Reason loop
         exit when Pos = 49;
         if Inp.Disable_Flags (R) then
            exit when 49 - Pos < 2;
            Text (Pos) := Character'Pos (' ');
            Pos := Pos + 1;
            declare
               Name : constant String := Disable_Name (R);
               Copy : constant Natural := Natural'Min (Name'Length, 49 - Pos);
            begin
               for J in 0 .. Copy - 1 loop
                  Text (Pos + J) := Character'Pos (Name (Name'First + J));
               end loop;
               Pos := Pos + Copy;
            end;
         end if;
      end loop;
      Put_U8 (P, 0, 5);
      for K in Text'Range loop
         P (1 + K) := Text (K);
      end loop;
      Frame (S, O, 253, 83, P, 54);
   end Send_Arming_Text;

   function Config_Interval (C : Settings; St : Stream) return Unsigned_32 is
     (if C.Rates (St) /= 0 then Unsigned_32'Max (Min_Interval_Ms, 1_000 / Unsigned_32 (C.Rates (St))) else Disabled);

   procedure Configure_Intervals (S : in out State; C : Settings; Now_Ms : Unsigned_32) is
   begin
      for M in Output_Message loop
         S.Streams (M).Interval_Ms := Config_Interval (C, Stream_Of (M));
         if S.Streams (M).Interval_Ms /= Disabled then
            S.Streams (M).Due_Ms := Now_Ms + S.Streams (M).Interval_Ms + 3 * Unsigned_32 (Output_Message'Pos (M));
         end if;
      end loop;
   end Configure_Intervals;

   function Message_Interval_Us (S : State; Id : Natural) return Integer_32 is
   begin
      for M in Output_Message loop
         if Id_Of (M) = Id then
            if S.Streams (M).Interval_Ms = Disabled then
               return -1;
            end if;
            declare
               Us : constant Unsigned_32 := S.Streams (M).Interval_Ms * 1_000;
            begin
               return (if Us <= Unsigned_32 (Integer_32'Last) then Integer_32 (Us) else Integer_32'Last);
            end;
         end if;
      end loop;
      return 0;
   end Message_Interval_Us;

   procedure Set_Message_Interval
     (S : in out State; C : Settings; Id : Natural; Interval_Ms : Unsigned_32; Found : out Boolean)
   is
      Ms : Unsigned_32 := Interval_Ms;
   begin
      Found := False;
      for M in Output_Message loop
         if Id_Of (M) = Id then
            if Ms = 0 then
               Ms := Config_Interval (C, Stream_Of (M));
            end if;
            S.Streams (M).Interval_Ms := Unsigned_32'Max (Ms, Min_Interval_Ms);
            Found := True;
            return;
         end if;
      end loop;
   end Set_Message_Interval;

   procedure Handle
     (S : in out State; C : Settings; Inp : Inputs; Now_Us, Now_Ms : Unsigned_32; Tx_Valid, Tx_Should_Send : Boolean;
      O : out Output)
   is
      Should : constant Boolean := (if Tx_Valid then Tx_Should_Send else Now_Us - S.Last_Message_Us >= Delay_Us);
   begin
      O := (others => <>);
      if not Should then
         return;
      end if;
      for M in Output_Message loop
         if S.Streams (M).Interval_Ms /= Disabled and then Now_Ms >= S.Streams (M).Due_Ms then
            case M is
               when Sys_Status => Send_Sys_Status (S, Inp, Now_Ms, O);
               when RC_Channels_Raw => Send_RC_Channels (S, Inp, Now_Ms, O);
               when GPS_Raw_Int => Send_GPS_Raw (S, Inp, Now_Us, O);
               when Global_Position_Int => Send_Global_Position (S, Inp, Now_Us, O);
               when GPS_Global_Origin => Send_Global_Origin (S, Inp, Now_Us, O);
               when Home_Position => Send_Home_Position (S, Inp, Now_Us, O);
               when Attitude => Send_Attitude (S, Inp, Now_Ms, O);
               when Heartbeat => Send_Heartbeat (S, Inp, O);
               when VFR_HUD => Send_HUD (S, C, Inp, O);
               when Battery_Status => Send_Battery (S, C, Inp, O);
            end case;
            S.Streams (M).Due_Ms := Now_Ms + S.Streams (M).Interval_Ms;
         end if;
      end loop;
      Send_Arming_Text (S, Inp, O);
      S.Last_Message_Us := Now_Us;
   end Handle;

end Adaflight.MAVLink_Telemetry;
