with Adaflight.Maths;

package body Adaflight.FrSky_Hub_Telemetry with SPARK_Mode is

   Header          : constant Byte := 16#5E#;
   Tail            : constant Byte := 16#5E#;
   Cycle_Us        : constant := 125_000;
   Boot_Delay_Us   : constant := 5_000_000;
   Degrees_Divider : constant := 10_000_000;
   Bad_Quality     : constant := 300;
   Max_Dop         : constant := 9999;
   Erpm_Per_Lsb    : constant Float := 100.0;

   Id_GPS_Altitude_BP : constant Unsigned_8 := 16#01#;
   Id_GPS_Altitude_AP : constant Unsigned_8 := 16#09#;
   Id_Temperature_1   : constant Unsigned_8 := 16#02#;
   Id_Rpm             : constant Unsigned_8 := 16#03#;
   Id_Fuel_Level      : constant Unsigned_8 := 16#04#;
   Id_Temperature_2   : constant Unsigned_8 := 16#05#;
   Id_Volt            : constant Unsigned_8 := 16#06#;
   Id_Altitude_BP     : constant Unsigned_8 := 16#10#;
   Id_Altitude_AP     : constant Unsigned_8 := 16#21#;
   Id_GPS_Speed_BP    : constant Unsigned_8 := 16#11#;
   Id_GPS_Speed_AP    : constant Unsigned_8 := 16#19#;
   Id_Longitude_BP    : constant Unsigned_8 := 16#12#;
   Id_Longitude_AP    : constant Unsigned_8 := 16#1A#;
   Id_E_W             : constant Unsigned_8 := 16#22#;
   Id_Latitude_BP     : constant Unsigned_8 := 16#13#;
   Id_Latitude_AP     : constant Unsigned_8 := 16#1B#;
   Id_N_S             : constant Unsigned_8 := 16#23#;
   Id_Course_BP       : constant Unsigned_8 := 16#14#;
   Id_Course_AP       : constant Unsigned_8 := 16#1C#;
   Id_Hour_Minute     : constant Unsigned_8 := 16#17#;
   Id_Second          : constant Unsigned_8 := 16#18#;
   Id_Acc_X           : constant Unsigned_8 := 16#24#;
   Id_Voltage_Amp     : constant Unsigned_8 := 16#39#;
   Id_Voltage_Amp_BP  : constant Unsigned_8 := 16#3A#;
   Id_Voltage_Amp_AP  : constant Unsigned_8 := 16#3B#;
   Id_Current         : constant Unsigned_8 := 16#28#;
   Id_Vert_Speed      : constant Unsigned_8 := 16#30#;

   --  The low sixteen bits of an integer, as the reference narrows its
   --  values to the frame.
   function Wrap (I : Integer) return Unsigned_16 is (Unsigned_16 (I mod 65536));

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_U32 (I : Integer_16) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Integer_32 (I) + 2 ** 16) + 16#FFFF_0000# else Unsigned_32 (I));

   function Rounded (X : Float) return Integer is
     (Integer (Adaflight.Maths.Round_Half_Even (Float'Max (-(2.0 ** 24 - 1.0), Float'Min (2.0 ** 24 - 1.0, X)))));

   procedure Put (O : in out Output; B : Byte)
     with Pre => O.Count < Max_Output, Post => O.Count = O.Count'Old + 1
   is
   begin
      O.Tx (O.Count) := B;
      O.Count := O.Count + 1;
   end Put;

   --  A value byte, the header and escape bytes stuffed.
   procedure Put_Stuffed (O : in out Output; B : Byte)
     with Pre => O.Count <= Max_Output - 2, Post => O.Count in O.Count'Old + 1 .. O.Count'Old + 2
   is
   begin
      if B = 16#5E# then
         Put (O, 16#5D#);
         Put (O, 16#3E#);
      elsif B = 16#5D# then
         Put (O, 16#5D#);
         Put (O, 16#3D#);
      else
         Put (O, B);
      end if;
   end Put_Stuffed;

   --  A frame: the header, the id and the value low byte first; a call
   --  never fills the output, so a full one drops the frame.
   procedure Frame (O : in out Output; Id : Unsigned_8; Data : Unsigned_16) is
   begin
      if O.Count <= Max_Output - 6 then
         Put (O, Header);
         Put (O, Id);
         Put_Stuffed (O, Byte (Data and 16#FF#));
         Put_Stuffed (O, Byte (Interfaces.Shift_Right (Data, 8)));
      end if;
   end Frame;

   --  An acceleration in thousandths of a g, truncated to whole g first.
   function Acc_Frame_Value (Component : Acceleration; Rec : Gravity_Scale) return Unsigned_16 is
      Whole : constant Integer := Integer (Float'Truncation (Component * Rec));
      Narrow : constant Integer := (Whole + 32768) mod 65536 - 32768;
   begin
      return Wrap (Narrow * 1000);
   end Acc_Frame_Value;

   procedure Send_Accel (C : Settings; Inp : Inputs; O : in out Output) is
   begin
      Frame (O, Id_Acc_X, Acc_Frame_Value (Inp.Acc_X, C.Acc_1G_Rec));
      Frame (O, Id_Acc_X + 1, Acc_Frame_Value (Inp.Acc_Y, C.Acc_1G_Rec));
      Frame (O, Id_Acc_X + 2, Acc_Frame_Value (Inp.Acc_Z, C.Acc_1G_Rec));
   end Send_Accel;

   --  The ESC rate in tens of revolutions per minute from the pole count.
   procedure Send_Rpm (C : Settings; Inp : Inputs; O : in out Output) is
      Data : Unsigned_16 := 0;
   begin
      if Inp.ESC_Valid then
         declare
            Pairs  : constant Float := Float (C.Pole_Count) / 2.0;
            Per_Hz : constant Float := (if Pairs > 0.0 then (Erpm_Per_Lsb / 60.0) / Pairs else 0.0);
            Raw    : constant Float := Float (To_U32 (Inp.ESC_Rpm));
         begin
            Data := Wrap (Rounded (((Raw * Per_Hz) * 60.0) / 10.0));
         end;
      end if;
      Frame (O, Id_Rpm, Data);
   end Send_Rpm;

   procedure Send_Temperature_1 (Inp : Inputs; O : in out Output) is
   begin
      Frame (O, Id_Temperature_1, (if Inp.ESC_Valid then Unsigned_16 (Inp.ESC_Temperature) else 0));
   end Send_Temperature_1;

   procedure Send_Time (Inp : Inputs; O : in out Output) is
      Seconds : constant Unsigned_32 := Inp.Now_Ms / 1000;
      Minutes : constant Unsigned_32 := (Seconds / 60) mod 60;
   begin
      Frame (O, Id_Hour_Minute, Unsigned_16 (Minutes * 256));
      Frame (O, Id_Second, Unsigned_16 (Seconds mod 60));
   end Send_Time;

   --  A coordinate as degrees and minutes, then the decimal fraction of
   --  the minutes in ten-thousandths.
   procedure Split_Coordinate (Value : Coordinate; Format : Coordinate_Format; DDDMM, MMMM : out Unsigned_16) is
      Whole : constant Integer_32 := abs Value;
      Deg   : constant Integer_32 := Whole / Degrees_Divider;
      Rest  : constant Integer_32 := (Whole - Deg * Degrees_Divider) * 60;
      Min   : constant Integer_32 := Rest / Degrees_Divider;
   begin
      DDDMM := Wrap (Integer (if Format = DMS then Deg * 100 + Min else Deg * 60 + Min));
      MMMM := Wrap (Integer ((Rest - Min * Degrees_Divider) / 1000));
   end Split_Coordinate;

   procedure Send_Lat_Long (Lat, Lon : Coordinate; C : Settings; O : in out Output) is
      DDDMM, MMMM : Unsigned_16;
   begin
      Split_Coordinate (Lat, C.Format, DDDMM, MMMM);
      Frame (O, Id_Latitude_BP, DDDMM);
      Frame (O, Id_Latitude_AP, MMMM);
      Frame (O, Id_N_S, (if Lat < 0 then Character'Pos ('S') else Character'Pos ('N')));
      Split_Coordinate (Lon, C.Format, DDDMM, MMMM);
      Frame (O, Id_Longitude_BP, DDDMM);
      Frame (O, Id_Longitude_AP, MMMM);
      Frame (O, Id_E_W, (if Lon < 0 then Character'Pos ('W') else Character'Pos ('E')));
   end Send_Lat_Long;

   --  The configured position without a fix, from hundredths of a degree.
   function No_Fix_Value (Hundredths : No_Fix_Coordinate) return Coordinate is
      Degrees : constant Float := 0.01 * Float (Hundredths);
      Scaled  : constant Float := Float'Max (-2.0e9, Float'Min (2.0e9, Degrees * 1.0e7));
   begin
      return Coordinate (Float'Truncation (Scaled));
   end No_Fix_Value;

   --  The position: the last known one once a fix was seen, else the
   --  configured one.
   procedure Send_GPS_Lat_Long (S : in out Stream; C : Settings; Inp : Inputs; O : in out Output) is
   begin
      if Inp.Fix or else S.Fix_Occurred then
         S.Fix_Occurred := True;
         Send_Lat_Long (Inp.Lat, Inp.Lon, C, O);
      else
         Send_Lat_Long (No_Fix_Value (C.No_Fix_Latitude), No_Fix_Value (C.No_Fix_Longitude), C, O);
      end if;
   end Send_GPS_Lat_Long;

   procedure Send_GPS_Altitude (Inp : Inputs; O : in out Output) is
      Alt : constant Integer_32 := (if Inp.Fix then Inp.Alt_Cm else 0);
   begin
      Frame (O, Id_GPS_Altitude_BP, Wrap (Integer (Alt / 100)));
      Frame (O, Id_GPS_Altitude_AP, Wrap (Integer (Alt rem 100)));
   end Send_GPS_Altitude;

   --  The satellite count, or the dilution while it is poor on the first
   --  half of every sixteen cycles, in the configured unit.
   procedure Send_Temperature_2 (C : Settings; Inp : Inputs; Cycle : Natural; O : in out Output) is
      Satellite : Natural := Natural (Inp.Num_Sat);
   begin
      if Inp.Pdop > Bad_Quality and then Cycle mod 16 < 8 then
         Satellite := Natural (Unsigned_16'Min (Inp.Pdop, Max_Dop));
      end if;
      if C.Unit = Imperial then
         Frame (O, Id_Temperature_2, Wrap (Rounded (Float (Satellite - 32) / 1.8)));
      else
         Frame (O, Id_Temperature_2, Wrap (Satellite));
      end if;
   end Send_Temperature_2;

   --  The ground speed in knots, with a fix.
   procedure Send_Speed (Inp : Inputs; O : in out Output) is
      Scaled : constant Integer := Integer (Inp.Ground_Speed) * 1944;
   begin
      if not Inp.Fix then
         return;
      end if;
      Frame (O, Id_GPS_Speed_BP, Wrap (Scaled / 100_000));
      Frame (O, Id_GPS_Speed_AP, Wrap ((Scaled / 100) mod 100));
   end Send_Speed;

   --  One cell's voltage in two-millivolt steps with its number, a cell
   --  per cycle.
   procedure Send_Voltage_Cells (S : in out Stream; Inp : Inputs; O : in out Output) is
      Cells        : constant Unsigned_32 := Unsigned_32 (Inp.Cell_Count);
      Cell_Voltage : Unsigned_32 := 0;
      Data         : Unsigned_16;
   begin
      if Cells > 0 then
         S.Current_Cell := S.Current_Cell mod Unsigned_16 (Cells);
         Cell_Voltage := (Unsigned_32 (Inp.Voltage_Cv) * 100 + Cells) / (Cells * 2);
      else
         S.Current_Cell := 0;
      end if;
      Data := Interfaces.Shift_Left (S.Current_Cell, 4);
      Data := Data or Unsigned_16 (Interfaces.Shift_Left (Cell_Voltage and 16#FF#, 8));
      Data := Data or Unsigned_16 (Interfaces.Shift_Right (Cell_Voltage and 16#F00#, 8));
      Frame (O, Id_Volt, Data);
      S.Current_Cell := S.Current_Cell + 1;
   end Send_Voltage_Cells;

   --  The pack voltage in tenths, or in fifths over two frames.
   procedure Send_Voltage_Amp (C : Settings; Inp : Inputs; O : in out Output) is
      Voltage : Unsigned_16 := Unsigned_16 ((Natural (Inp.Voltage_Cv) + 5) / 10);
      Cells   : constant Unsigned_16 := Unsigned_16 (Inp.Cell_Count);
   begin
      if C.Precision = High then
         if C.Report_Cell_Voltage and then Cells > 0 then
            Voltage := Voltage / Cells;
         end if;
         Frame (O, Id_Voltage_Amp, Voltage);
      else
         Voltage := Voltage * 5;
         if C.Report_Cell_Voltage and then Cells > 0 then
            Voltage := Voltage / Cells;
         end if;
         Frame (O, Id_Voltage_Amp_BP, Voltage / 100);
         Frame (O, Id_Voltage_Amp_AP, ((Voltage mod 100) + 5) / 10);
      end if;
   end Send_Voltage_Amp;

   procedure Send_Amperage (Inp : Inputs; O : in out Output) is
   begin
      Frame (O, Id_Current, Wrap (Integer (Inp.Amperage_Ca / 10)));
   end Send_Amperage;

   procedure Send_Fuel (Inp : Inputs; O : in out Output) is
   begin
      if Inp.Capacity > 0 then
         Frame (O, Id_Fuel_Level, Unsigned_16 (Inp.Percent));
      else
         Frame (O, Id_Fuel_Level, Wrap (Integer (Integer_32'Max (0, Integer_32'Min (16#FFFF#, Inp.Mah_Drawn)))));
      end if;
   end Send_Fuel;

   procedure Send_Heading (Inp : Inputs; O : in out Output) is
   begin
      Frame (O, Id_Course_BP, Wrap (Integer (Inp.Yaw / 10)));
      Frame (O, Id_Course_AP, 0);
   end Send_Heading;

   --  The altitude estimate, zero for the first five seconds after boot.
   procedure Send_Altitude (S : Stream; Inp : Inputs; O : in out Output) is
      Alt : constant Integer_32 := (if S.Last_Cycle_Us < Boot_Delay_Us then 0 else Inp.Altitude_Cm);
   begin
      Frame (O, Id_Altitude_BP, Wrap (Integer (Alt / 100)));
      Frame (O, Id_Altitude_AP, Wrap (Integer (Alt rem 100)));
   end Send_Altitude;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Stream; C : Settings; Inp : Inputs; O : out Output) is
      Cycle : Natural;
   begin
      O := (others => <>);
      if To_Signed (Inp.Now_Us - S.Last_Cycle_Us) < Cycle_Us then
         return;
      end if;
      S.Last_Cycle_Us := Inp.Now_Us;
      Cycle := S.Cycle + 1;
      if C.Acc_Present and then (C.Enabled (Acc_X) or else C.Enabled (Acc_Y) or else C.Enabled (Acc_Z)) then
         Send_Accel (C, Inp, O);
      end if;
      if C.Altitude_Present or else C.GPS_Present then
         if C.Enabled (Vario) then
            Frame (O, Id_Vert_Speed, Wrap (Integer (Inp.Vario_Cms)));
         end if;
         if Cycle mod 4 = 0 and then C.Enabled (Altitude) then
            Send_Altitude (S, Inp, O);
         end if;
      end if;
      if C.Mag_Present and then C.Enabled (Heading) and then Cycle mod 4 = 0 then
         Send_Heading (Inp, O);
      end if;
      if Cycle mod 8 = 0 then
         Send_Temperature_1 (Inp, O);
         Send_Rpm (C, Inp, O);
         if Inp.Voltage_Configured then
            if C.Enabled (Voltage) then
               Send_Voltage_Cells (S, Inp, O);
               Send_Voltage_Amp (C, Inp, O);
            end if;
            if Inp.Amperage_Configured then
               if C.Enabled (Current) then
                  Send_Amperage (Inp, O);
               end if;
               if C.Enabled (Fuel) then
                  Send_Fuel (Inp, O);
               end if;
            end if;
         end if;
         if C.GPS_Present then
            if C.Enabled (Ground_Speed) then
               Send_Speed (Inp, O);
            end if;
            if C.Enabled (Altitude) then
               Send_GPS_Altitude (Inp, O);
            end if;
            Send_Temperature_2 (C, Inp, Cycle, O);
            if C.Enabled (Lat_Long) then
               Send_GPS_Lat_Long (S, C, Inp, O);
            end if;
         elsif C.Mag_Present then
            Send_Lat_Long (Degrees_Divider, Degrees_Divider, C, O);
         end if;
      end if;
      if Cycle = 40 then
         S.Cycle := 0;
         Send_Time (Inp, O);
      else
         S.Cycle := Cycle;
      end if;
      if O.Count < Max_Output then
         Put (O, Tail);
      end if;
   end Update;

end Adaflight.FrSky_Hub_Telemetry;
