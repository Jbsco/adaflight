with Adaflight.CLI_Text;
with Adaflight.Maths;

package body Adaflight.Dashboard with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_8;
   use type Scheduler.Task_Id;
   subtype Integer_64 is Interfaces.Integer_64;

   Display_Update_Us : constant := 200_000;
   Page_Cycle_Us     : constant := 5_000_000;
   Half_Columns      : constant := Columns / 2;

   --  The column of the satellite graph: the 32 satellite slots taken from
   --  the 21 columns in unsigned arithmetic and halved, then cut to a byte.
   Satellite_Graph_Column : constant := 250;

   --  The pages in the order they cycle, the welcome and armed pages left
   --  out of the cycle.
   Pages : constant array (Page_Index) of Page_Id :=
     (Welcome, Armed, Profile, Rate_Profile, GPS, Receiver, Battery, Sensors, Tasks, Blackbox, Debug);

   function Skips (P : Page_Id) return Boolean is (P in Welcome | Armed);

   Channel_Letters : constant String (1 .. 20) := "AERT12345678abcdefgh";

   --  The ticker's characters with the zero that ends their string, all five
   --  in the cycle.
   Ticker_Characters : constant String (1 .. Ticker_Count) := "|/-\" & ASCII.NUL;

   --  A word as %d prints it.
   function As_Signed (V : Unsigned_32) return Integer_64 is
     (if V >= 2 ** 31 then Integer_64 (V) - 2 ** 32 else Integer_64 (V));

   function Decimal (V : Integer_64) return String renames CLI_Text.Decimal;

   type Line_Text is record
      Data   : String (1 .. Max_Text) := (others => ' ');
      Length : Natural range 0 .. Max_Text := 0;
   end record;

   procedure Append (L : in out Line_Text; S : String)
     with Global => null
   is
   begin
      for C of S loop
         exit when L.Length = Max_Text;
         L.Length := L.Length + 1;
         L.Data (L.Length) := C;
      end loop;
   end Append;

   --  A number right-justified in a field, as %Nd prints it.
   procedure Append_Field (L : in out Line_Text; V : Integer_64; Width : Natural)
     with Global => null,
          Pre    => Width <= 8
   is
   begin
      Append (L, CLI_Text.Right_Justified (Decimal (V), Width));
   end Append_Field;

   procedure Pad (L : in out Line_Text; Width : Natural)
     with Global => null,
          Pre    => Width <= Max_Text
   is
   begin
      while L.Length < Width loop
         pragma Loop_Variant (Increases => L.Length);
         L.Length := L.Length + 1;
         L.Data (L.Length) := ' ';
      end loop;
   end Pad;

   procedure Emit (O : in out Output; Op : Operation)
     with Global => null
   is
   begin
      if O.Count < Max_Operations then
         O.Count := O.Count + 1;
         O.Operations (O.Count) := Op;
      end if;
   end Emit;

   procedure Emit_Position (O : in out Output; Column : Natural; Row : Natural)
     with Global => null,
          Pre    => Column <= 255 and then Row <= 255
   is
   begin
      Emit (O, (Kind => Position, Column => Unsigned_8 (Column), Row => Unsigned_8 (Row), others => <>));
   end Emit_Position;

   procedure Emit_Line (O : in out Output; Row : Natural)
     with Global => null,
          Pre    => Row <= 255
   is
   begin
      Emit (O, (Kind => Line, Row => Unsigned_8 (Row), others => <>));
   end Emit_Line;

   procedure Emit_Char (O : in out Output; Ch : Character)
     with Global => null
   is
   begin
      Emit (O, (Kind => Char, Glyph => Ch, others => <>));
   end Emit_Char;

   procedure Emit_Text (O : in out Output; L : Line_Text)
     with Global => null
   is
   begin
      Emit (O, (Kind => Text, Data => L.Data, Length => L.Length, others => <>));
   end Emit_Text;

   --  A line's text at the start of a row.
   procedure Put_Row (O : in out Output; Row : Natural; L : Line_Text)
     with Global => null,
          Pre    => Row <= 255
   is
   begin
      Emit_Line (O, Row);
      Emit_Text (O, L);
   end Put_Row;

   procedure Put_Row (O : in out Output; Row : Natural; S : String)
     with Global => null,
          Pre    => Row <= 255
   is
      L : Line_Text;
   begin
      Append (L, S);
      Put_Row (O, Row, L);
   end Put_Row;

   --  A bar of a width filled to a percentage, a partial cell after the full
   --  ones.
   procedure Put_Bar (O : in out Output; Width : Natural; Percent_In : Unsigned_8)
     with Global => null,
          Pre    => Width <= Columns
   is
      Percent : constant Natural := Natural'Min (Natural (Percent_In), 100);
      Full    : constant Natural := (Width * Percent) / 100;
   begin
      for I in 1 .. Full loop
         Emit_Char (O, Character'Val (159));
      end loop;
      if Full < Width then
         Emit_Char (O, Character'Val (154 + (Percent * Width * 5 / 100 - 5 * Full)));
      end if;
      for I in Full + 2 .. Width loop
         Emit_Char (O, Character'Val (154));
      end loop;
   end Put_Bar;

   function Rounded (X : Float) return Integer_64 is
     (Integer_64 (Maths.Round_Half_Even
        (Float'Max (Float'Min (X, Float (Maths.Rounding_Bound) - 1.0), 1.0 - Float (Maths.Rounding_Bound)))))
     with Global => null;

   procedure Put_Title (O : in out Output; P : Page_Id; R : Readings)
     with Global => null
   is
   begin
      case P is
         when Welcome => Put_Row (O, 0, R.Firmware.Data (1 .. R.Firmware.Length));
         when Armed => Put_Row (O, 0, "ARMED");
         when Profile => Put_Row (O, 0, "PROFILE");
         when Rate_Profile => Put_Row (O, 0, "RATE PROFILE");
         when GPS => Put_Row (O, 0, "GPS");
         when Receiver => Put_Row (O, 0, "RX");
         when Battery => Put_Row (O, 0, "BATTERY");
         when Sensors => Put_Row (O, 0, "SENSORS");
         when Tasks => Put_Row (O, 0, "TASKS");
         when Blackbox => Put_Row (O, 0, "BLACK BOX");
         when Debug => Put_Row (O, 0, "DEBUG");
      end case;
   end Put_Title;

   procedure Put_Welcome (O : in out Output; R : Readings)
     with Global => null
   is
      L : Line_Text;
   begin
      Append (L, "v");
      Append (L, R.Version.Data (1 .. R.Version.Length));
      Put_Row (O, 1, L);
      L := (others => <>);
      Append (L, "(");
      Append (L, R.Revision.Data (1 .. R.Revision.Length));
      Append (L, ")");
      Put_Row (O, 2, L);
      Put_Row (O, 3, R.Target.Data (1 .. R.Target.Length));
   end Put_Welcome;

   procedure Put_Profile (O : in out Output; R : Readings)
     with Global => null
   is
      L : Line_Text;
   begin
      Append (L, "Profile: ");
      Append (L, Decimal (Integer_64 (R.PID_Index)));
      Put_Row (O, 1, L);
      for Axis in 0 .. 2 loop
         L := (others => <>);
         Append (L, (case Axis is when 0 => "ROL", when 1 => "PIT", when others => "YAW"));
         Append (L, " P:");
         Append_Field (L, Integer_64 (R.P_Gains (Axis)), 3);
         Append (L, " I:");
         Append_Field (L, Integer_64 (R.I_Gains (Axis)), 3);
         Append (L, " D:");
         Append_Field (L, Integer_64 (R.D_Gains (Axis)), 3);
         Pad (L, Columns);
         Put_Row (O, 2 + Axis, L);
      end loop;
   end Put_Profile;

   procedure Put_Rate_Profile (O : in out Output; R : Readings)
     with Global => null
   is
      type Rate_Kind is (RC_Rate, Super, Expo);
      L : Line_Text;
   begin
      Append (L, "Rate profile: ");
      Append (L, Decimal (Integer_64 (R.Rate_Index)));
      Put_Row (O, 1, L);
      L := (others => <>);
      Append (L, "         R   P   Y");
      Pad (L, Columns);
      Put_Row (O, 2, L);
      for K in Rate_Kind loop
         L := (others => <>);
         Append (L, (case K is when RC_Rate => "RcRate", when Super => "Super ", when Expo => "Expo  "));
         for Axis in 0 .. 2 loop
            Append (L, " ");
            Append_Field
              (L, Integer_64 (case K is
                                 when RC_Rate => R.RC_Rates (Axis), when Super => R.Super_Rates (Axis),
                                 when Expo => R.Expos (Axis)), 3);
         end loop;
         Pad (L, Columns);
         Put_Row (O, 3 + Rate_Kind'Pos (K), L);
      end loop;
   end Put_Rate_Profile;

   procedure Put_GPS (S : in out State; O : in out Output; R : Readings)
     with Global => null
   is
      L : Line_Text;
   begin
      if not R.GPS_Enabled then
         S.Force_Change := True;
         return;
      end if;
      if R.Sat_Info_Count /= S.Last_Sat_Info then
         S.Last_Sat_Info := R.Sat_Info_Count;
         S.GPS_Ticker := (S.GPS_Ticker + 1) mod Ticker_Count;
      end if;
      Emit_Position (O, 0, 1);
      Emit_Char (O, Ticker_Characters (S.GPS_Ticker + 1));
      Emit_Position (O, Satellite_Graph_Column, 1);
      for Index in 0 .. Columns - 1 loop
         Emit_Char (O, Character'Val (160 + Natural'Min ((Natural (R.Signals (Index)) * 7) / 54, 6)));
      end loop;
      Append (L, "Sats: ");
      Append (L, Decimal (Integer_64 (R.Satellites)));
      Append (L, " Fix: ");
      Append (L, (if R.Fix then "Y" else "N"));
      Pad (L, Columns);
      Put_Row (O, 2, L);
      L := (others => <>);
      Append (L, "La/Lo: ");
      Append (L, Decimal (Integer_64 (R.Latitude) / 10_000_000));
      Append (L, "/");
      Append (L, Decimal (Integer_64 (R.Longitude) / 10_000_000));
      Pad (L, Columns);
      Put_Row (O, 3, L);
      L := (others => <>);
      Append (L, "Spd: ");
      Append (L, Decimal (Integer_64 (R.Ground_Speed)));
      Pad (L, Half_Columns);
      Put_Row (O, 4, L);
      L := (others => <>);
      Append (L, "GC: ");
      Append (L, Decimal (Integer_64 (R.Ground_Course)));
      Pad (L, Half_Columns);
      Emit_Position (O, Half_Columns, 4);
      Emit_Text (O, L);
      L := (others => <>);
      Append (L, "RX: ");
      Append (L, Decimal (As_Signed (R.Packets)));
      Pad (L, Half_Columns);
      Put_Row (O, 5, L);
      L := (others => <>);
      Append (L, "ERRs: ");
      Append (L, Decimal (As_Signed (R.Errors)));
      Pad (L, Half_Columns);
      Emit_Position (O, Half_Columns, 5);
      Emit_Text (O, L);
      L := (others => <>);
      Append (L, "Dt: ");
      Append (L, Decimal (As_Signed (R.Nav_Interval_Ms)));
      Pad (L, Half_Columns);
      Put_Row (O, 6, L);
      L := (others => <>);
      Append (L, "TOs: ");
      Append (L, Decimal (As_Signed (R.Timeouts)));
      Pad (L, Half_Columns);
      Emit_Position (O, Half_Columns, 6);
      Emit_Text (O, L);
      L := (others => <>);
      for C of R.Log loop
         exit when C = ASCII.NUL;
         Append (L, (1 => C));
      end loop;
      Pad (L, Half_Columns);
      Put_Row (O, 7, L);
   end Put_GPS;

   --  A channel's letter and its bar over 1000 to 2000.
   procedure Put_Channel (O : in out Output; R : Readings; Index : Natural; Width : Natural)
     with Global => null,
          Pre    => Index < Max_Channels and then Width in 1 .. Columns
   is
      V       : constant Float := R.Channels (Index);
      Clamped : constant Float := (if V < 1000.0 then 1000.0 elsif V > 2000.0 then 2000.0 else V);
      Percent : constant Float := (Clamped - 1000.0) * 100.0 / 1000.0;
   begin
      Emit_Char (O, Channel_Letters (Index + 1));
      Put_Bar (O, Width - 1, Unsigned_8 (Natural (Float'Truncation (Float'Min (Float'Max (Percent, 0.0), 100.0)))));
   end Put_Channel;

   procedure Put_Receiver (O : in out Output; R : Readings)
     with Global => null
   is
      Index : Natural := 0;
   begin
      while Index < R.Channel_Count and then Index < 14 loop
         pragma Loop_Invariant (Index mod 2 = 0 and then Index < 14);
         pragma Loop_Variant (Increases => Index);
         Emit_Line (O, Index / 2 + 1);
         Put_Channel (O, R, Index, Half_Columns);
         Emit_Char (O, ' ');
         Put_Channel (O, R, Index + 1, Half_Columns);
         Index := Index + 2;
      end loop;
   end Put_Receiver;

   procedure Put_Battery (O : in out Output; R : Readings)
     with Global => null
   is
      Row : Natural := 1;
      L   : Line_Text;
   begin
      if R.Voltage_Meter then
         Append (L, "Volts:");
         Append (L, Decimal (Integer_64 (R.Voltage / 100)));
         Append (L, ".");
         Append (L, (if R.Voltage mod 100 < 10 then "0" else ""));
         Append (L, Decimal (Integer_64 (R.Voltage mod 100)));
         Append (L, " Cells:");
         Append (L, Decimal (Integer_64 (R.Cells)));
         Pad (L, Columns);
         Put_Row (O, Row, L);
         Emit_Line (O, Row + 1);
         Put_Bar (O, Columns, R.Percentage);
         Row := Row + 2;
      end if;
      if R.Current_Meter then
         L := (others => <>);
         Append (L, "Amp: ");
         Append (L, Decimal (Integer_64 (R.Amperage) / 100));
         Append (L, ".");
         Append (L, Decimal ((Integer_64 (R.Amperage) rem 100) / 10));
         Append (L, " mAh: ");
         Append (L, Decimal (Integer_64 (R.MAh_Drawn)));
         Pad (L, Columns);
         Put_Row (O, Row, L);
         Emit_Line (O, Row + 1);
         Put_Bar (O, Columns, R.Percentage);
      end if;
   end Put_Battery;

   procedure Put_Sensor_Row (O : in out Output; Row : Natural; Name : String; X, Y, Z : Integer_64)
     with Global => null,
          Pre    => Row <= 255
   is
      L : Line_Text;
   begin
      Append (L, Name);
      Append_Field (L, X, 6);
      Append_Field (L, Y, 6);
      Append_Field (L, Z, 6);
      Pad (L, Columns);
      Put_Row (O, Row, L);
   end Put_Sensor_Row;

   procedure Put_Sensors (O : in out Output; R : Readings)
     with Global => null
   is
      Row : Natural := 1;
   begin
      Put_Row (O, Row, "        X     Y     Z");
      Row := Row + 1;
      if R.Acc_On then
         Put_Sensor_Row (O, Row, "ACC", Rounded (R.Acc (0)), Rounded (R.Acc (1)), Rounded (R.Acc (2)));
         Row := Row + 1;
      end if;
      if R.Gyro_On then
         Put_Sensor_Row (O, Row, "GYR", Rounded (R.Gyro (0)), Rounded (R.Gyro (1)), Rounded (R.Gyro (2)));
         Row := Row + 1;
      end if;
      if R.Mag_On then
         Put_Sensor_Row (O, Row, "MAG", Rounded (R.Mag (0)), Rounded (R.Mag (1)), Rounded (R.Mag (2)));
         Row := Row + 1;
      end if;
      Put_Sensor_Row
        (O, Row, "I&H", Integer_64 (R.Roll), Integer_64 (R.Pitch), Integer_64 (R.Yaw) / 10);
   end Put_Sensors;

   procedure Put_Tasks (O : in out Output; R : Readings)
     with Global => null
   is
      Row : Natural := 1;
      L   : Line_Text;
   begin
      Put_Row (O, Row, "Task max  avg mx% av%");
      Row := Row + 1;
      for Id in Scheduler.Task_Id loop
         pragma Loop_Invariant (Row in 2 .. Rows);
         if R.Tasks (Id).Enabled and then Id /= Scheduler.Serial then
            L := (others => <>);
            Append_Field (L, Integer_64 (Scheduler.Task_Id'Pos (Id)), 2);
            Append_Field (L, As_Signed (R.Tasks (Id).Max_Exec_Us), 6);
            Append_Field (L, As_Signed (R.Tasks (Id).Average_Exec_10th / 10), 5);
            Append_Field (L, As_Signed (R.Tasks (Id).Max_Load_10th / 10), 4);
            Append_Field (L, As_Signed (R.Tasks (Id).Average_Load_10th / 10), 4);
            Pad (L, Columns);
            Put_Row (O, Row, L);
            exit when Row = Rows;
            Row := Row + 1;
         end if;
      end loop;
   end Put_Tasks;

   procedure Put_Blackbox (O : in out Output; R : Readings)
     with Global => null
   is
      SD_Card : constant := 2;
      L       : Line_Text;
   begin
      if R.Blackbox_Working then
         if R.Blackbox_Device = SD_Card then
            if R.Log_File > 0 then
               Append (L, "File no: ");
               Append (L, Decimal (Integer_64 (R.Log_File)));
            else
               Append (L, "Not ready yet");
            end if;
         else
            Append (L, "Not supp. dev.");
         end if;
      else
         Append (L, "BB not working");
      end if;
      Pad (L, Columns);
      Put_Row (O, 1, L);
   end Put_Blackbox;

   procedure Put_Debug (O : in out Output; R : Readings)
     with Global => null
   is
      L : Line_Text;
   begin
      for Index in 0 .. 3 loop
         L := (others => <>);
         Append (L, Decimal (Integer_64 (Index)));
         Append (L, " = ");
         Append_Field (L, Integer_64 (R.Debug_Values_In (Index)), 5);
         Pad (L, Columns);
         Put_Row (O, Index + 1, L);
      end loop;
   end Put_Debug;

   procedure Draw_Page (S : in out State; O : in out Output; R : Readings)
     with Global => null
   is
   begin
      case Pages (S.Page) is
         when Welcome => Put_Welcome (O, R);
         when Armed => null;
         when Profile => Put_Profile (O, R);
         when Rate_Profile => Put_Rate_Profile (O, R);
         when GPS => Put_GPS (S, O, R);
         when Receiver => Put_Receiver (O, R);
         when Battery => Put_Battery (O, R);
         when Sensors => Put_Sensors (O, R);
         when Tasks => Put_Tasks (O, R);
         when Blackbox => Put_Blackbox (O, R);
         when Debug => Put_Debug (O, R);
      end case;
   end Draw_Page;

   --  The corner: the failsafe phase, the receiver's state and the ticker.
   procedure Put_Corner (S : in out State; O : in out Output; R : Readings)
     with Global => null
   is
   begin
      Emit_Position (O, Columns - 3, 0);
      Emit_Char (O, (case R.Phase is
                        when Failsafe.Idle => '-', when Failsafe.Rx_Loss_Detected => 'R',
                        when Failsafe.Landing => 'l', when Failsafe.Landed => 'L',
                        when Failsafe.Rx_Loss_Monitoring => 'M', when Failsafe.Rx_Loss_Recovered => 'r',
                        when Failsafe.GPS_Rescue => 'G', when Failsafe.Autopilot => 'A'));
      Emit_Position (O, Columns - 2, 0);
      Emit_Char (O, (if R.Rx_Valid then 'R' elsif R.Rx_Signal then 'r' else '!'));
      Emit_Position (O, Columns - 1, 0);
      Emit_Char (O, Ticker_Characters (S.Ticker + 1));
      S.Ticker := (S.Ticker + 1) mod Ticker_Count;
   end Put_Corner;

   procedure Set_Page (S : in out State; Page : Page_Id)
     with Global => null
   is
   begin
      for I in Page_Index loop
         if Pages (I) = Page then
            S.Page := I;
         end if;
      end loop;
      S.Force_Change := True;
   end Set_Page;

   --  Whether a time is at or past another in the wrapping microsecond
   --  clock.
   function Reached (Now_Us : Unsigned_32; At_Us : Unsigned_32) return Boolean is
     (Now_Us - At_Us < 2 ** 31);

   procedure Update (S : in out State; Now_Us : Unsigned_32; R : Readings; O : in out Output) is
      Armed_Changed : Boolean;
   begin
      if R.Grabbed or else not Reached (Now_Us, S.Next_Update_At) then
         return;
      end if;
      S.Next_Update_At := Now_Us + Display_Update_Us;
      Armed_Changed := R.Armed /= S.Previous_Armed;
      S.Previous_Armed := R.Armed;
      if R.Armed then
         if not Armed_Changed then
            return;
         end if;
         Set_Page (S, Armed);
         S.Changing := True;
      else
         if Armed_Changed then
            S.Force_Change := True;
         end if;
         S.Changing := S.Force_Change or else (Reached (Now_Us, S.Next_Page_At) and then S.Cycle_Enabled);
         if S.Changing and then S.Cycle_Enabled then
            loop
               S.Cycle_Index := (S.Cycle_Index + 1) mod Page_Count;
               S.Page := S.Cycle_Index;
               exit when not Skips (Pages (S.Page));
            end loop;
         end if;
      end if;
      if S.Changing then
         S.Force_Change := False;
         S.Next_Page_At := Now_Us + Page_Cycle_Us;
         Emit (O, (Kind => Start, others => <>));
         S.Present := R.Present;
         if not S.Present then
            return;
         end if;
         Emit (O, (Kind => Clear, others => <>));
         Put_Title (O, Pages (S.Page), R);
      end if;
      if not S.Present then
         return;
      end if;
      Draw_Page (S, O, R);
      if not R.Armed then
         Put_Corner (S, O, R);
      end if;
   end Update;

   procedure Init (S : in out State; Now_Us : Unsigned_32; R : Readings; O : out Output) is
   begin
      O := (Operations => (others => <>), Count => 0);
      Emit (O, (Kind => Start, others => <>));
      S.Present := R.Present;
      S.Page := 0;
      S.Changing := False;
      S.Cycle_Enabled := False;
      S.Force_Change := False;
      S.Cycle_Index := 0;
      S.Next_Page_At := 0;
      Set_Page (S, Welcome);
      Update (S, Now_Us, R, O);
      S.Next_Page_At := Now_Us + Page_Cycle_Us;
   end Init;

   procedure Show_Fixed_Page (S : in out State; Page : Page_Id) is
   begin
      Set_Page (S, Page);
      S.Cycle_Enabled := False;
   end Show_Fixed_Page;

   procedure Enable_Cycling (S : in out State) is
   begin
      S.Cycle_Enabled := True;
   end Enable_Cycling;

   procedure Disable_Cycling (S : in out State) is
   begin
      S.Cycle_Enabled := False;
   end Disable_Cycling;

   procedure Reset_Cycling (S : in out State) is
   begin
      S.Cycle_Index := Page_Count - 1;
   end Reset_Cycling;

end Adaflight.Dashboard;
