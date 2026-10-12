package body Adaflight.GHST_Telemetry with SPARK_Mode is

   Cycle_Us          : constant := 100_000;
   Receiver_Address  : constant Byte := 16#89#;
   Frame_Length      : constant Byte := 12;
   Polynomial        : constant Byte := 16#D5#;
   Type_Pack         : constant Byte := 16#23#;
   Type_GPS_Primary  : constant Byte := 16#25#;
   Type_GPS_Second   : constant Byte := 16#26#;
   Type_Mag_Baro     : constant Byte := 16#27#;
   Flag_Disarmed     : constant Byte := 1;
   Flag_Fix          : constant Byte := 1;
   Flag_Fix_Home     : constant Byte := 2;
   Flag_Mag_Heading  : constant Byte := 1;
   Flag_Baro_Alt     : constant Byte := 2;
   Altitude_Limit_Cm : constant := 3_200_000;

   function To_U32 (I : Integer_32) return Unsigned_32 is
     (if I < 0 then Unsigned_32 (Interfaces.Integer_64 (I) + 2 ** 32) else Unsigned_32 (I));

   function Wrap (I : Integer) return Unsigned_16 is (Unsigned_16 (I mod 65536));

   procedure Put_16 (F : in out Frame; At_Pos : Natural; V : Unsigned_16)
     with Pre => At_Pos <= Frame_Size - 2
   is
   begin
      F (At_Pos) := Byte (V and 16#FF#);
      F (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8));
   end Put_16;

   procedure Put_32 (F : in out Frame; At_Pos : Natural; V : Unsigned_32)
     with Pre => At_Pos <= Frame_Size - 4
   is
   begin
      F (At_Pos) := Byte (V and 16#FF#);
      F (At_Pos + 1) := Byte (Interfaces.Shift_Right (V, 8) and 16#FF#);
      F (At_Pos + 2) := Byte (Interfaces.Shift_Right (V, 16) and 16#FF#);
      F (At_Pos + 3) := Byte (Interfaces.Shift_Right (V, 24));
   end Put_32;

   --  The battery: the pack or cell voltage, the current and the charge
   --  used in tens, and the disarmed flag.
   procedure Pack_Payload (C : Settings; Inp : Inputs; F : in out Frame) is
   begin
      Put_16 (F, 3, (if C.Report_Cell_Voltage then Inp.Cell_Cv else Inp.Voltage_Cv));
      Put_16 (F, 5, Unsigned_16 (To_U32 (Inp.Amperage_Ca) and 16#FFFF#));
      Put_16 (F, 7, Wrap (Integer (Inp.Mah_Drawn / 10)));
      F (9) := 0;
      F (10) := (if Inp.Armed then 0 else Flag_Disarmed);
      F (11) := 0;
      F (12) := 0;
   end Pack_Payload;

   --  The position and the GPS altitude in metres, zero without a fix.
   procedure GPS_Primary_Payload (Inp : Inputs; F : in out Frame) is
      Alt : constant Integer_32 := (if Inp.Fix then Inp.Alt_Cm else 0);
   begin
      Put_32 (F, 3, To_U32 (Inp.Lat));
      Put_32 (F, 7, To_U32 (Inp.Lon));
      Put_16 (F, 11, Wrap (Integer (Alt / 100)));
   end GPS_Primary_Payload;

   --  The speed, course, satellites, the home distance and direction in
   --  tens, and the fix flags.
   procedure GPS_Secondary_Payload (Inp : Inputs; F : in out Frame) is
   begin
      Put_16 (F, 3, Inp.Ground_Speed);
      Put_16 (F, 5, Inp.Ground_Course);
      F (7) := Inp.Num_Sat;
      Put_16 (F, 8, Inp.Distance_Home / 10);
      Put_16 (F, 10, Wrap (Integer (Inp.Direction_Home / 10)));
      F (12) := (if Inp.Fix then Flag_Fix else 0) or (if Inp.Fix_Home then Flag_Fix_Home else 0);
   end GPS_Secondary_Payload;

   --  The heading and the altitude in metres with their flags; the climb
   --  rate stays zero, as the reference tests a sensor bit no sensor sets
   --  (finding F82).
   procedure Mag_Baro_Payload (C : Settings; Inp : Inputs; F : in out Frame) is
      Yaw      : Unsigned_16 := 0;
      Altitude : Unsigned_16 := 0;
      Flags    : Byte := 0;
   begin
      if C.Baro_Present and then C.Altitude_Enabled then
         Flags := Flags or Flag_Baro_Alt;
         Altitude := Wrap (Integer (Integer_32'Max (-Altitude_Limit_Cm,
                                                   Integer_32'Min (Altitude_Limit_Cm, Inp.Altitude_Cm)) / 100));
      end if;
      if C.Mag_Present and then C.Heading_Enabled then
         Flags := Flags or Flag_Mag_Heading;
         Yaw := Wrap (Integer (Inp.Yaw));
      end if;
      Put_16 (F, 3, Yaw);
      Put_16 (F, 5, Altitude);
      F (7) := 0;
      Put_16 (F, 8, 0);
      Put_16 (F, 10, 0);
      F (12) := Flags;
   end Mag_Baro_Payload;

   procedure Build (K : Frame_Kind; C : Settings; Inp : Inputs; O : out Output) is
   begin
      O := (others => <>);
      O.Tx (0) := Receiver_Address;
      O.Tx (1) := Frame_Length;
      O.Tx (2) := (case K is
                     when Pack => Type_Pack,
                     when GPS_Primary => Type_GPS_Primary,
                     when GPS_Secondary => Type_GPS_Second,
                     when Mag_Baro => Type_Mag_Baro);
      case K is
         when Pack => Pack_Payload (C, Inp, O.Tx);
         when GPS_Primary => GPS_Primary_Payload (Inp, O.Tx);
         when GPS_Secondary => GPS_Secondary_Payload (Inp, O.Tx);
         when Mag_Baro => Mag_Baro_Payload (C, Inp, O.Tx);
      end case;
      O.Tx (13) := CRC8_Update (0, O.Tx (2 .. 12), Polynomial);
      O.Count := Frame_Size;
   end Build;

   ----------
   -- Init --
   ----------

   procedure Init (L : out Link; C : Settings) is
      procedure Add (K : Frame_Kind)
        with Pre => L.Count < Max_Schedule, Post => L.Count = L.Count'Old + 1
      is
      begin
         L.Table (L.Count) := K;
         L.Count := L.Count + 1;
      end Add;
   begin
      L := (others => <>);
      if (C.Voltage_Configured and then C.Voltage_Enabled)
        or else (C.Amperage_Configured and then (C.Current_Enabled or else C.Fuel_Enabled))
      then
         Add (Pack);
      end if;
      if C.GPS_Feature and then (C.Altitude_Enabled or else C.Lat_Long_Enabled) then
         Add (GPS_Primary);
      end if;
      if C.GPS_Feature and then (C.Ground_Speed_Enabled or else C.Heading_Enabled) then
         Add (GPS_Secondary);
      end if;
      if (C.Baro_Present and then C.Altitude_Enabled) or else (C.Mag_Present and then C.Heading_Enabled) then
         Add (Mag_Baro);
      end if;
   end Init;

   ------------
   -- Update --
   ------------

   --  The empty schedule sends nothing, where the reference divides by
   --  its length (finding F83).
   procedure Update (L : in out Link; C : Settings; Inp : Inputs; O : out Output) is
   begin
      O := (others => <>);
      if L.Count = 0 then
         return;
      end if;
      if Inp.Now_Us >= L.Last_Cycle_Us + Unsigned_32 (Cycle_Us / L.Count) then
         L.Last_Cycle_Us := Inp.Now_Us;
         Build (L.Table (L.Index), C, Inp, O);
         L.Index := (L.Index + 1) mod L.Count;
      end if;
   end Update;

end Adaflight.GHST_Telemetry;
