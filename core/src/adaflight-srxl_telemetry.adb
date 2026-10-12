with Adaflight.Maths;

package body Adaflight.SRXL_Telemetry with SPARK_Mode is

   Address_First  : constant Byte := 16#A5#;
   Address_Second : constant Byte := 16#80#;
   Packet_Length  : constant Byte := 16#15#;

   Type_Qos      : constant Byte := 16#7F#;
   Type_Rpm      : constant Byte := 16#7E#;
   Type_Pack     : constant Byte := 16#34#;
   Type_GPS_Loc  : constant Byte := 16#16#;
   Type_GPS_Stat : constant Byte := 16#17#;
   Type_Text     : constant Byte := 16#0C#;
   Secondary_Id  : constant Byte := 0;

   Rpm_Unused         : constant := 16#FFFF#;
   Temperature_Unused : constant Unsigned_16 := 16#7FFF#;
   Amps_Unused        : constant Unsigned_16 := 16#7FFF#;
   Time_Unknown       : constant Unsigned_32 := 16#FFFF_FFFF#;
   Us_Per_Minute      : constant := 60_000_000;
   Min_Rpm            : constant := 999;
   Max_Rpm            : constant := 60_000_000;
   Keep_Alive_Us      : constant := 2_000_000;
   Min_Sat_Count      : constant := 4;
   Degrees_Divider    : constant := 10_000_000;

   Flag_North        : constant Byte := 16#01#;
   Flag_East         : constant Byte := 16#02#;
   Flag_Lon_Over_99  : constant Byte := 16#04#;
   Flag_Fix_Valid    : constant Byte := 16#08#;
   Flag_Received     : constant Byte := 16#10#;
   Flag_3D_Fix       : constant Byte := 16#20#;
   Flag_Negative_Alt : constant Byte := 16#80#;

   type User_Frame is (Pack, GPS_Stat, GPS_Loc, Text);

   function Wrap (I : Integer) return Unsigned_16 is (Unsigned_16 (I mod 65536));

   function To_U32 (I : Integer_16) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Integer_32 (I) + 2 ** 16) + 16#FFFF_0000# else Unsigned_32 (I));

   --  The decimal digits of a value as four bits each, low digit first.
   function Dec_To_Bcd (D : Unsigned_16) return Unsigned_32 is
      Rest   : Unsigned_16 := D;
      Result : Unsigned_32 := 0;
      Shift  : Natural := 0;
   begin
      while Rest /= 0 and then Shift <= 16 loop
         pragma Loop_Invariant (Shift <= 16);
         pragma Loop_Variant (Decreases => Rest);
         Result := Result or Interfaces.Shift_Left (Unsigned_32 (Rest mod 10), Shift);
         Shift := Shift + 4;
         Rest := Rest / 10;
      end loop;
      return Result;
   end Dec_To_Bcd;

   procedure Put_16 (F : in out Frame; At_Pos : Natural; V : Unsigned_16)
     with Pre => At_Pos <= Frame_Size - 2
   is
   begin
      F (At_Pos) := Byte (V and 16#FF#);
      F (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8));
   end Put_16;

   procedure Put_16_Big (F : in out Frame; At_Pos : Natural; V : Unsigned_16)
     with Pre => At_Pos <= Frame_Size - 2
   is
   begin
      F (At_Pos) := Byte (Interfaces.Shift_Right (V, 8));
      F (At_Pos + 1) := Byte (V and 16#FF#);
   end Put_16_Big;

   procedure Put_32 (F : in out Frame; At_Pos : Natural; V : Unsigned_32)
     with Pre => At_Pos <= Frame_Size - 4
   is
   begin
      F (At_Pos) := Byte (V and 16#FF#);
      F (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8) and 16#FF#);
      F (At_Pos + 2) := Byte (Interfaces.Shift_Right (V, 16) and 16#FF#);
      F (At_Pos + 3) := Byte (Interfaces.Shift_Right (V, 24));
   end Put_32;

   procedure Fill (F : in out Frame; From, To : Natural; V : Byte)
     with Pre => From <= To and then To <= Frame_Size - 1
   is
   begin
      for I in From .. To loop
         F (I) := V;
      end loop;
   end Fill;

   --  The link quality frame, its fields left to the receiver.
   procedure Qos_Payload (F : in out Frame) is
   begin
      F (3) := Type_Qos;
      F (4) := Secondary_Id;
      Fill (F, 5, 18, 16#FF#);
   end Qos_Payload;

   --  The period between pulses from the ESC rate, or the DShot average
   --  when the ESC gives none, bounded to the shown range.
   function Motor_Period (Inp : Inputs) return Unsigned_16 is
      Rpm : Unsigned_32 := (if Inp.ESC_Valid then To_U32 (Inp.ESC_Rpm) else 0);
   begin
      if Inp.Dshot_Telemetry and then Rpm = 0 then
         Rpm := Unsigned_32 (Integer'Max (0, Adaflight.Maths.Round_Half_Even (Inp.Dshot_Rpm)));
      end if;
      if Rpm > Min_Rpm and then Rpm < Max_Rpm then
         return Unsigned_16 (Us_Per_Minute / Rpm);
      else
         return Unsigned_16 (Us_Per_Minute / Min_Rpm);
      end if;
   end Motor_Period;

   --  The rate frame: the period, the voltage and the core temperature in
   --  Fahrenheit, big-endian.
   procedure Rpm_Payload (C : Settings; Inp : Inputs; F : in out Frame) is
      Fahrenheit : constant Integer := Integer (Inp.Core_Temperature) * 9 / 5 + 32;
   begin
      F (3) := Type_Rpm;
      F (4) := Secondary_Id;
      Put_16_Big (F, 5, Motor_Period (Inp));
      Put_16_Big (F, 7, (if C.Report_Cell_Voltage then Inp.Cell_Cv else Inp.Voltage_Cv));
      Put_16_Big (F, 9, Wrap (Fahrenheit));
      Fill (F, 11, 18, 0);
   end Rpm_Payload;

   --  The flight pack frame when the current or the charge changed or two
   --  seconds passed.
   procedure Pack_Payload (S : in out Stream; Inp : Inputs; F : in out Frame; Sent : out Boolean) is
      Amps : constant Unsigned_16 := Wrap (Integer (Inp.Amperage_Ca / 10));
      Mah  : constant Unsigned_16 := Wrap (Integer (Inp.Mah_Drawn));
   begin
      Sent := False;
      if Amps = S.Sent_Amps and then Mah = S.Sent_Mah and then Inp.Now_Us - S.Last_Pack_Us <= Keep_Alive_Us then
         return;
      end if;
      F (3) := Type_Pack;
      F (4) := Secondary_Id;
      Put_16 (F, 5, Amps);
      Put_16 (F, 7, Mah);
      Put_16 (F, 9, Temperature_Unused);
      Put_16 (F, 11, Amps_Unused);
      Put_16 (F, 13, Amps_Unused);
      Put_16 (F, 15, Temperature_Unused);
      Fill (F, 17, 18, 16#FF#);
      S.Sent_Amps := Amps;
      S.Sent_Mah := Mah;
      S.Last_Pack_Us := Inp.Now_Us;
      Sent := True;
   end Pack_Payload;

   function GPS_Usable (C : Settings; Inp : Inputs) return Boolean is
     (C.GPS_Feature and then Inp.Fix and then Inp.Num_Sat >= Min_Sat_Count);

   --  The GPS status: the speed in knots, no time, the satellites and the
   --  high part of the altitude, in binary coded decimals narrowed as the
   --  reference's conversions narrow them.
   procedure GPS_Stat_Payload (C : Settings; Inp : Inputs; F : in out Frame; Sent : out Boolean) is
      Speed    : Unsigned_16;
      Sats     : constant Unsigned_16 := Unsigned_16 (Unsigned_8'Min (Inp.Num_Sat, 99));
      Alt_High : constant Unsigned_16 := Wrap (Integer (Inp.Alt_Cm / 100_000));
   begin
      Sent := False;
      if not GPS_Usable (C, Inp) then
         return;
      end if;
      Speed := Wrap (Integer (Inp.Ground_Speed) * 1944 / 1000);
      if Speed > 9999 then
         Speed := 9999;
      end if;
      F (3) := Type_GPS_Stat;
      F (4) := Secondary_Id;
      Put_16 (F, 5, Unsigned_16 (Dec_To_Bcd (Speed) and 16#FFFF#));
      Put_32 (F, 7, Time_Unknown);
      F (11) := Byte (Dec_To_Bcd (Sats) and 16#FF#);
      F (12) := Byte (Dec_To_Bcd (Alt_High) and 16#FF#);
      Fill (F, 13, 18, 16#FF#);
      Sent := True;
   end GPS_Stat_Payload;

   --  A coordinate as degrees and minutes, then the decimal fraction of
   --  the minutes, in binary coded decimals.
   function Coordinate_Bcd (Value : Coordinate) return Unsigned_32 is
      Whole : constant Integer_32 := abs Value;
      Deg   : constant Integer_32 := Whole / Degrees_Divider;
      Rest  : constant Integer_32 := (Whole - Deg * Degrees_Divider) * 60;
      Min   : constant Integer_32 := Rest / Degrees_Divider;
      DDDMM : constant Unsigned_16 := Wrap (Integer (Deg * 100 + Min));
      MMMM  : constant Unsigned_16 := Wrap (Integer ((Rest - Min * Degrees_Divider) / 1000));
   begin
      return Interfaces.Shift_Left (Dec_To_Bcd (DDDMM), 16) or Dec_To_Bcd (MMMM);
   end Coordinate_Bcd;

   --  The GPS location: the low part of the altitude, the position, the
   --  course, the dilution and the flags.
   procedure GPS_Loc_Payload (C : Settings; Inp : Inputs; F : in out Frame; Sent : out Boolean) is
      Alt_Low : constant Unsigned_16 := Wrap (Integer ((abs Interfaces.Integer_64 (Inp.Alt_Cm) / 10) mod 100_000));
      Pdop    : constant Unsigned_16 := Unsigned_16'Min (Inp.Pdop / 10, 99);
      Flags   : Byte := Flag_Received or Flag_Fix_Valid or Flag_3D_Fix;
   begin
      Sent := False;
      if not GPS_Usable (C, Inp) then
         return;
      end if;
      if Inp.Lat > 0 then
         Flags := Flags or Flag_North;
      end if;
      if Inp.Lon > 0 then
         Flags := Flags or Flag_East;
      end if;
      if Inp.Alt_Cm < 0 then
         Flags := Flags or Flag_Negative_Alt;
      end if;
      if Inp.Lon / Degrees_Divider > 99 then
         Flags := Flags or Flag_Lon_Over_99;
      end if;
      F (3) := Type_GPS_Loc;
      F (4) := Secondary_Id;
      Put_16 (F, 5, Unsigned_16 (Dec_To_Bcd (Alt_Low) and 16#FFFF#));
      Put_32 (F, 7, Coordinate_Bcd (Inp.Lat));
      Put_32 (F, 11, Coordinate_Bcd (Inp.Lon));
      Put_16 (F, 15, Unsigned_16 (Dec_To_Bcd (Inp.Ground_Course) and 16#FFFF#));
      F (17) := Byte (Dec_To_Bcd (Pdop) and 16#FF#);
      F (18) := Flags;
      Sent := True;
   end GPS_Loc_Payload;

   --  The next text line not yet sent, or the next line in turn when all
   --  were sent.
   procedure Text_Payload (S : in out Stream; F : in out Frame) is
      Count : Natural := 0;
   begin
      while S.Line_Sent (S.Line_No) and then Count < Rows loop
         pragma Loop_Invariant (Count < Rows);
         S.Line_No := (S.Line_No + 1) mod Rows;
         Count := Count + 1;
      end loop;
      F (3) := Type_Text;
      F (4) := Secondary_Id;
      F (5) := Byte (S.Line_No);
      for Col in Column_Index loop
         F (6 + Col) := S.Text (S.Line_No, Col);
      end loop;
      S.Line_Sent (S.Line_No) := True;
      S.Line_No := (S.Line_No + 1) mod Rows;
   end Text_Payload;

   --------------
   -- Put_Char --
   --------------

   procedure Put_Char (S : in out Stream; Column, Row : Natural; C : Byte) is
   begin
      if Row < Rows and then Column < Input_Columns and then S.Text (Row, Column) /= C then
         S.Text (Row, Column) := C;
         S.Line_Sent (Row) := False;
      end if;
   end Put_Char;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Stream; C : Settings; Inp : Inputs; O : out Output) is
      Sent : Boolean := True;
      Kind : User_Frame;
   begin
      O := (others => <>);
      if not Inp.Buffer_Empty then
         return;
      end if;
      O.Tx (0) := Address_First;
      O.Tx (1) := Address_Second;
      O.Tx (2) := Packet_Length;
      if S.Index = 0 then
         Qos_Payload (O.Tx);
      elsif S.Index = 1 then
         Rpm_Payload (C, Inp, O.Tx);
      else
         Kind := User_Frame'Val (S.User_Index);
         S.User_Index := (S.User_Index + 1) mod 4;
         if Inp.Menu_On_Display then
            Kind := Text;
         end if;
         case Kind is
            when Pack => Pack_Payload (S, Inp, O.Tx, Sent);
            when GPS_Stat => GPS_Stat_Payload (C, Inp, O.Tx, Sent);
            when GPS_Loc => GPS_Loc_Payload (C, Inp, O.Tx, Sent);
            when Text => Text_Payload (S, O.Tx);
         end case;
      end if;
      S.Index := (S.Index + 1) mod 3;
      if Sent then
         declare
            Crc : constant Unsigned_16 := CRC16_CCITT_Update (0, O.Tx (3 .. 18));
         begin
            Put_16 (O.Tx, 19, Crc);
            O.Count := Frame_Size;
         end;
      else
         O.Tx := (others => 0);
      end if;
   end Update;

end Adaflight.SRXL_Telemetry;
