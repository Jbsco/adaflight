with Adaflight.Clock;

package body Adaflight.Spektrum with SPARK_Mode is
   use type Interfaces.Integer_32;

   subtype Dbm is Integer range RSSI_Min_Dbm .. RSSI_Max_Dbm;
   subtype Report is Natural range 0 .. 101;

   --  The range table from dBm to a percentage that follows the distance
   --  about linearly, interpolated between its points.
   type Table_Entry is record
      At_Dbm    : Dbm;
      Report_As : Report;
   end record;
   type Range_Table is array (Natural range 0 .. 12) of Table_Entry;
   Table : constant Range_Table :=
     ((-42, 101), (-49, 100), (-56, 98), (-61, 95), (-66, 89), (-69, 83), (-71, 78),
      (-73, 72), (-74, 69), (-75, 66), (-76, 63), (-77, 60), (-92, 0));

   function To_Signed_8 (B : Byte) return Integer is (if B >= 128 then B - 256 else B)
     with Post => To_Signed_8'Result in -128 .. 127;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
      R : constant Byte := (C.RSSI_Channel + 255) mod 256;
   begin
      S := (others => <>);
      case C.Kind is
         when SRXL | Spektrum_2048 =>
            S.SRXL_Enabled := C.Kind = SRXL and then C.Telemetry;
            S.Shift := 3;
            S.Mask := 7;
            S.Hi_Res := True;
            S.Resolution := 2_048;
            S.Channel_Count := Channel_Count_Max;
         when Spektrum_1024 =>
            S.Shift := 2;
            S.Mask := 3;
            S.Hi_Res := False;
            S.Resolution := 1_024;
            S.Channel_Count := 7;
      end case;
      S.RSSI_Channel := (if R >= S.Channel_Count then 0 else R);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Interval : constant Unsigned_32 := Now_Us - S.Time_Last_Us;
   begin
      S.Time_Last_Us := Now_Us;
      if Interval > Needed_Frame_Interval_Us then
         S.Position := 0;
      end if;
      if S.Position < Frame_Size then
         S.Frame (S.Position) := C mod 256;
         S.Position := S.Position + 1;
         if S.Position < Frame_Size then
            S.Frame_Complete := False;
         else
            S.Last_Frame_Time_Us := Now_Us;
            S.Frame_Complete := True;
         end if;
      end if;
   end Receive_Byte;

   --  The percentage of the range for a dBm report, held within the range
   --  and interpolated between the table's points.
   function Range_Percent (Report_Dbm : Integer) return Natural
     with Pre  => Report_Dbm in -128 .. 127,
          Post => Range_Percent'Result <= 100
   is
      Level  : constant Dbm := Integer'Max (RSSI_Min_Dbm, Integer'Min (RSSI_Max_Dbm, Report_Dbm));
      Result : Integer range -3_200 .. 3_200 := Table (0).Report_As;
   begin
      for I in 1 .. Table'Last loop
         if Level >= Table (I).At_Dbm then
            declare
               Span   : constant Integer range -50 .. 50 := Level - Table (I - 1).At_Dbm;
               Rise   : constant Integer range -101 .. 101 := Table (I).Report_As - Table (I - 1).Report_As;
               Width  : constant Integer range -50 .. -1 := Table (I).At_Dbm - Table (I - 1).At_Dbm;
               Scaled : constant Integer range -5_050 .. 5_050 := Span * Rise;
            begin
               Result := Scaled / Width + Table (I - 1).Report_As;
            end;
            exit;
         end if;
      end loop;
      return Integer'Max (0, Integer'Min (100, Result));
   end Range_Percent;

   --  The RSSI channel count for a fade difference over the half second,
   --  mapped from the fade limit per half second down to zero, as the
   --  reference converts it to sixteen bits.
   function Fade_To_Count (Fades : Integer; Resolution : Natural) return Channel_Value
     with Pre => Fades in -65_535 .. 65_535 and then Resolution in 1_024 .. 2_048
   is
      Limit  : constant := Max_Fade_Per_Sec / Fade_Reports_Per_Sec;
      Scaled : constant Integer range -135_000_000 .. 135_000_000 := (Fades - Limit) * Resolution;
   begin
      return (Scaled / (0 - Limit)) mod 65_536;
   end Fade_To_Count;

   --  The RSSI channel from the frame's first bytes: the SRXL receiver's dBm
   --  report held through up to four fades and dropped to the minimum after
   --  the fifth, through the range table onto the resolution; or a satellite
   --  receiver's fade count, one byte with the system type when bound by the
   --  flight controller and two bytes otherwise, differenced over the half
   --  second when the frames come every half second.
   procedure Handle_RSSI (S : in out State; Now_Us : Time_Us) is
   begin
      if S.SRXL_Enabled then
         declare
            RSSI : Integer range -128 .. 127 := To_Signed_8 (S.Frame (0));
         begin
            if RSSI <= RSSI_Fade_Limit_Dbm then
               S.Fade_Count := (S.Fade_Count + 1) mod 256;
               if S.Fade_Count < Link_Loss_Fades then
                  RSSI := S.Last_RSSI_Dbm;
               else
                  RSSI := RSSI_Min_Dbm;
               end if;
            else
               S.Fade_Count := 0;
            end if;
            if S.RSSI_Channel /= 0 then
               S.Data (S.RSSI_Channel) := Range_Percent (RSSI) * S.Resolution / 100;
            end if;
            S.Last_RSSI_Dbm := RSSI;
         end;
      else
         declare
            Current_Secs : constant Unsigned_32 := Now_Us / 1_000 / (1_000 / Fade_Reports_Per_Sec);
            Fade         : Natural range 0 .. 65_535;
         begin
            if S.Sat_Internal then
               Fade := S.Frame (0);
               if S.Frame (1) not in DSM2_22 | DSM2_11 | DSMX_22 | DSMX_11 then
                  S.Sat_Internal := False;
               end if;
            else
               Fade := S.Frame (0) * 256 + S.Frame (1);
            end if;
            if S.Fade_Last_Sec = 0 then
               S.Fade_Last_Sec_Count := Fade;
               S.Fade_Last_Sec := Current_Secs;
            elsif S.Fade_Last_Sec /= Current_Secs then
               if Current_Secs - S.Fade_Last_Sec = 1 then
                  if S.RSSI_Channel /= 0 then
                     S.Data (S.RSSI_Channel) := Fade_To_Count (Fade - S.Fade_Last_Sec_Count, S.Resolution);
                  end if;
               end if;
               S.Fade_Last_Sec_Count := Fade;
               S.Fade_Last_Sec := Current_Secs;
            end if;
         end;
      end if;
   end Handle_RSSI;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (
      S      : in out State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report;
      VTX    : out VTX_Request
   ) is
   begin
      Status := (others => False);
      VTX := (others => <>);
      if S.Frame_Complete then
         S.Frame_Complete := False;
         Handle_RSSI (S, Now_Us);
         declare
            Word  : constant Unsigned_32 :=
              Interfaces.Shift_Left (Unsigned_32 (S.Frame (Frame_Size - 4)), 24)
              or Interfaces.Shift_Left (Unsigned_32 (S.Frame (Frame_Size - 3)), 16)
              or Interfaces.Shift_Left (Unsigned_32 (S.Frame (Frame_Size - 2)), 8)
              or Unsigned_32 (S.Frame (Frame_Size - 1));
            Pairs : Natural range 5 .. 7 := (Frame_Size - 2) / 2;
         begin
            if (Word and VTX_Frame_Mask) = VTX_Frame and then S.Frame (2) < 128 then
               VTX := (Present => True, Word => Word);
               Pairs := (Frame_Size - VTX_Control_Size - 2) / 2;
            end if;
            for Pair in 1 .. Pairs loop
               declare
                  B  : constant Natural range 3 .. 15 := 2 * Pair + 1;
                  Ch : constant Natural range 0 .. 15 := (S.Frame (B - 1) / 2 ** S.Shift) mod 16;
               begin
                  if Ch < S.Channel_Count and then Ch < Channel_Count_Max then
                     if S.RSSI_Channel = 0 or else Ch /= S.RSSI_Channel then
                        S.Data (Ch) := (S.Frame (B - 1) mod (S.Mask + 1)) * 256 + S.Frame (B);
                     end if;
                  end if;
               end;
            end loop;
         end;
         if S.SRXL_Enabled and then S.Frame (2) < 128 then
            S.Telemetry_Requested_Us := Now_Us;
         end if;
         Status.Complete := True;
      end if;
      if S.Telemetry_Length > 0 and then S.Telemetry_Requested_Us /= 0
        and then Clock.Elapsed (Now_Us, S.Telemetry_Requested_Us) >= Telemetry_Frame_Delay_Us
      then
         S.Telemetry_Requested_Us := 0;
         Status.Processing_Required := True;
      end if;
   end Frame_Status;

   ---------------------
   -- Queue_Telemetry --
   ---------------------

   procedure Queue_Telemetry (S : in out State; Length : Natural) is
   begin
      S.Telemetry_Length := Natural'Min (Length, Telemetry_Max);
   end Queue_Telemetry;

   -------------------
   -- Process_Frame --
   -------------------

   procedure Process_Frame (S : in out State; Written : out Boolean) is
   begin
      Written := S.Telemetry_Length > 0;
      S.Telemetry_Length := 0;
   end Process_Frame;

end Adaflight.Spektrum;
