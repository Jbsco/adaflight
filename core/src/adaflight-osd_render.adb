with Adaflight.Maths;

package body Adaflight.OSD_Render with SPARK_Mode is
   use type Interfaces.Integer_64;
   use Adaflight.OSD_Format;
   use all type Adaflight.OSD_Warnings.Severity;
   use all type Adaflight.Battery.Battery_State;

   Symbol_Roll              : constant Character := Character'Val (16#14#);
   Symbol_Pitch             : constant Character := Character'Val (16#15#);
   Symbol_Temperature       : constant Character := Character'Val (16#7A#);
   Symbol_Centre_Line       : constant Character := Character'Val (16#72#);
   Symbol_Centre            : constant Character := Character'Val (16#73#);
   Symbol_Centre_Line_Right : constant Character := Character'Val (16#74#);
   Symbol_RSSI              : constant Character := Character'Val (16#01#);
   Symbol_Throttle          : constant Character := Character'Val (16#04#);
   Symbol_Arrow_Small_Up    : constant Character := Character'Val (16#75#);
   Symbol_Arrow_Small_Down  : constant Character := Character'Val (16#76#);
   Symbol_Arrow_North       : constant Character := Character'Val (16#68#);
   Symbol_Arrow_East        : constant Character := Character'Val (16#64#);
   Symbol_Arrow_West        : constant Character := Character'Val (16#6C#);
   Symbol_Bar_Start         : constant Character := Character'Val (16#8A#);
   Symbol_Bar_Full          : constant Character := Character'Val (16#8B#);
   Symbol_Bar_Half          : constant Character := Character'Val (16#8C#);
   Symbol_Bar_Empty         : constant Character := Character'Val (16#8D#);
   Symbol_Bar_End           : constant Character := Character'Val (16#8E#);
   Symbol_Bar_Close         : constant Character := Character'Val (16#8F#);
   Heading_N                : constant Character := Character'Val (16#18#);
   Heading_S                : constant Character := Character'Val (16#19#);
   Heading_E                : constant Character := Character'Val (16#1A#);
   Heading_W                : constant Character := Character'Val (16#1B#);
   Heading_Divided          : constant Character := Character'Val (16#1C#);
   Heading_Line             : constant Character := Character'Val (16#1D#);

   Compass : constant String (1 .. 24) :=
     (Heading_W, Heading_Line, Heading_Divided, Heading_Line, Heading_N, Heading_Line, Heading_Divided, Heading_Line,
      Heading_E, Heading_Line, Heading_Divided, Heading_Line, Heading_S, Heading_Line, Heading_Divided, Heading_Line,
      Heading_W, Heading_Line, Heading_Divided, Heading_Line, Heading_N, Heading_Line, Heading_Divided, Heading_Line);

   Usage_Steps : constant := 11;

   function Capacity_Alarm (C : Settings; Inp : Inputs) return Unsigned_16 is
     (if Inp.Profile_Capacity > 0 then Inp.Profile_Capacity else C.Cap_Alarm);

   function Over_Capacity (C : Settings; Inp : Inputs) return Boolean is
     (Capacity_Alarm (C, Inp) > 0 and then Inp.MAh_Drawn >= Integer_32 (Capacity_Alarm (C, Inp)));

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Integer_32 (U));

   procedure Battery_Severity (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Battery = Adaflight.Battery.Warning then
         O.Attr := Warning;
      elsif Inp.Battery = Adaflight.Battery.Critical then
         O.Attr := Critical;
      end if;
   end Battery_Severity;

   procedure Altitude_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Adaflight.OSD_Elements.Alarm_Altitude (Inp.Altitude_Cm, C.Units) >= Integer_32 (C.Alt_Alarm)
        and then Inp.Clocks.Armed
      then
         O.Attr := Critical;
      end if;
      if Inp.Baro_Present or else (Inp.GPS_Present and then Inp.GPS_Fix) then
         Altitude_String (O.Line, Inp.Altitude_Cm, Variant, Inp.Altitude_Asl_Cm, C.Units);
      else
         Append (O.Line, Symbol_Altitude);
         Append (O.Line, Symbol_Hyphen);
      end if;
   end Altitude_Element;

   procedure Angle_Element (I : Item; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Angle : constant Float := Float (if I = Pitch_Angle then Inp.Pitch else Inp.Roll) / 10.0;
   begin
      Print_Float (O.Line, (if I = Pitch_Angle then Symbol_Pitch else Symbol_Roll), abs Angle,
                   (Lead => (if Angle < 0.0 then '-' else ' '), Has_Lead => True, Width => 2, Zero_Pad => True),
                   1, True, Symbol_None);
   end Angle_Element;

   procedure Cell_Voltage_Element (Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => Inp.Min_Cell /= Inp.Max_Cell
   is
   begin
      Battery_Severity (Inp, O);
      Print_Float (O.Line, Battery_Symbol (Natural (Inp.Cell_Voltage), Inp.Battery, Inp.Min_Cell, Inp.Max_Cell),
                   Float (Inp.Cell_Voltage) / 100.0, Default_Format, 2, False, Symbol_Volt);
   end Cell_Voltage_Element;

   procedure Compass_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Sector : constant Natural := Heading_Sector (Integer (Inp.Yaw) / 10, 16);
   begin
      Append_String (O.Line, Compass (Sector + 1 .. Sector + 9));
   end Compass_Element;

   procedure Core_Temperature_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append (O.Line, 'C');
      Append (O.Line, Symbol_Temperature);
      Append_Integer (O.Line, Integer_32 (Temperature_In_Units (Integer (Inp.Core_Temperature), C.Units)), 3, False);
      Append (O.Line, Temperature_Symbol (C.Units));
   end Core_Temperature_Element;

   procedure Current_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Print_Float (O.Line, Symbol_None, abs (Float (Inp.Amperage) / 100.0),
                   (Lead => ' ', Has_Lead => False, Width => 3, Zero_Pad => False), 2, False, Symbol_Amp);
   end Current_Element;

   procedure Debug_Element (First : Debug_Index; Label : String; Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => First <= 4 and then Label'Length <= 4
   is
   begin
      Append_String (O.Line, Label);
      for K in First .. First + 3 loop
         Append (O.Line, ' ');
         Append_Integer (O.Line, Integer_32 (Inp.Debug (K)), 5, False);
      end loop;
   end Debug_Element;

   procedure MAh_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Over_Capacity (C, Inp) then
         O.Attr := Critical;
      end if;
      Append_Integer (O.Line, Inp.MAh_Drawn, 4, False);
      Append (O.Line, Symbol_MAh);
   end MAh_Element;

   procedure Watt_Hours_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Whole, Decimal : Integer;
   begin
      if Over_Capacity (C, Inp) then
         O.Attr := Critical;
      end if;
      if Inp.Wh_Drawn < 1.0 then
         Append_Integer (O.Line, Integer_32 (Adaflight.Maths.Round_Half_Even (Inp.Wh_Drawn * 1000.0)), 3, False);
         Append_String (O.Line, "MWH");
      else
         declare
            subtype Whole_Hours is Float range 0.0 .. Wh_Bound;
            Whole_F  : constant Whole_Hours := Float'Truncation (Inp.Wh_Drawn);
            Fraction : constant Float := Inp.Wh_Drawn - Whole_F;
            Scaled   : constant Float := Fraction * 100.0;
         begin
            Whole := Integer (Whole_F);
            Decimal := Integer (Float'Truncation (Scaled));
         end;
         Append_Integer (O.Line, Integer_32 (Whole), 3, False);
         if Decimal >= 10 then
            Append (O.Line, '.');
            Append_Integer (O.Line, Integer_32 (Decimal), 2, False);
         else
            Append_String (O.Line, ".0");
            Append_Integer (O.Line, Integer_32 (Decimal), 1, False);
         end if;
         Append_String (O.Line, "WH");
      end if;
   end Watt_Hours_Element;

   procedure Usage_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Capacity     : constant Integer_32 := Integer_32 (Inp.Profile_Capacity);
      Alarm        : constant Unsigned_16 := Capacity_Alarm (C, Inp);
      Used         : constant Integer_32 := Inp.MAh_Drawn;
      Basis        : Integer_32 := Used;
      Percent      : Integer_32 := 0;
      Half_Steps   : Integer_32 := 0;
      Full         : Integer_32;
      Volt_Percent : Unsigned_8;
   begin
      if Alarm > 0 then
         if Used >= Integer_32 (Alarm) then
            O.Attr := Critical;
         end if;
      elsif Inp.Battery = Adaflight.Battery.Critical then
         O.Attr := Critical;
      elsif Inp.Battery = Adaflight.Battery.Warning then
         O.Attr := Warning;
      end if;
      case Variant is
         when Type_3 | Type_4 =>
            if Variant = Type_3 then
               Basis := Adaflight.Maths.Constrain (Capacity - Used, 0, Capacity);
            end if;
            if Capacity /= 0 then
               declare
                  Quotient : constant Float := 100.0 * Float (Basis) / Float (Capacity);
               begin
                  Percent := (if Quotient >= 100.0 then 100
                              elsif Quotient <= 0.0 then 0
                              else Integer_32 (Adaflight.Maths.Round_Half_Even (Quotient)));
               end;
            elsif Inp.Battery /= Not_Present then
               Volt_Percent := Inp.Battery_Percent;
               if Variant = Type_4 then
                  Volt_Percent := 100 - Volt_Percent;
               end if;
               Percent := Integer_32 (Volt_Percent);
            end if;
            Append (O.Line, Symbol_MAh);
            Append_Integer (O.Line, Percent, 1, False);
            Append (O.Line, '%');
         when Type_1 | Type_2 =>
            if Variant = Type_2 then
               Basis := Adaflight.Maths.Constrain (Capacity - Used, 0, Capacity);
            end if;
            if Capacity > 0 then
               declare
                  Remaining : constant Integer_32 := Adaflight.Maths.Constrain (Capacity - Basis, 0, Capacity);
               begin
                  Half_Steps := (Remaining * Usage_Steps * 2 + Capacity - 1) / Capacity;
               end;
            elsif Inp.Battery /= Not_Present then
               Volt_Percent := Inp.Battery_Percent;
               if Variant = Type_2 then
                  Volt_Percent := 100 - Volt_Percent;
               end if;
               Half_Steps := (Integer_32 (Volt_Percent) * Usage_Steps * 2 + 99) / 100;
            end if;
            Half_Steps := Integer_32'Min (Half_Steps, Usage_Steps * 2);
            Full := Half_Steps / 2;
            Append (O.Line, Symbol_Bar_Start);
            for K in 1 .. Usage_Steps loop
               Append (O.Line, (if Integer_32 (K) <= Full then Symbol_Bar_Full else Symbol_Bar_Empty));
            end loop;
            Append (O.Line, Symbol_Bar_Close);
            if Half_Steps mod 2 = 1 then
               O.Line.Data (Integer (Full) + 2) := Symbol_Bar_Half;
            elsif Full in 1 .. Usage_Steps - 1 then
               O.Line.Data (Integer (Full) + 2) := Symbol_Bar_End;
            end if;
      end case;
   end Usage_Element;

   procedure Voltage_Element (Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => Inp.Min_Cell /= Inp.Max_Cell
   is
      Voltage : constant Float := Float (Inp.Pack_Voltage) / 100.0;
   begin
      Battery_Severity (Inp, O);
      Print_Float (O.Line, Battery_Symbol (Natural (Inp.Cell_Voltage), Inp.Battery, Inp.Min_Cell, Inp.Max_Cell),
                   Voltage, Default_Format, (if Voltage >= 10.0 then 1 else 2), True, Symbol_Volt);
   end Voltage_Element;

   procedure Heading_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Heading : constant Integer := Integer (Inp.Yaw) / 10;
   begin
      Append (O.Line, Direction_Symbol (Heading));
      Append_Natural (O.Line, Heading, 3, True);
   end Heading_Element;

   procedure Vario_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Baro_Present or else (Inp.GPS_Present and then Inp.GPS_Fix) then
         declare
            Speed : constant Float := Meters_To_Unit (Integer_32 (Inp.Vario_Cm_S), C.Units) / 100.0;
         begin
            Print_Float (O.Line, (if Speed < 0.0 then Symbol_Arrow_Small_Down else Symbol_Arrow_Small_Up), abs Speed,
                         Default_Format, 1, True, Vario_Symbol (C.Units));
         end;
      else
         Append (O.Line, Symbol_Hyphen);
      end if;
   end Vario_Element;

   procedure Profile_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append_Natural (O.Line, Natural (Inp.PID_Index) + 1, 1, False);
      Append (O.Line, '-');
      Append_Natural (O.Line, Natural (Inp.Rate_Index) + 1, 1, False);
   end Profile_Element;

   procedure PID_Element (Label : String; G : PID_Gains; O : in out Output)
     with Global => null,
          Pre => Label'Length <= 8
   is
   begin
      PID_Line (O.Line, Label, G.P, G.I, G.D, G.D_Max, G.F);
   end PID_Element;

   procedure Power_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append_Integer (O.Line, (Inp.Amperage * Integer_32 (Inp.Pack_Voltage)) / 10_000, 4, False);
      Append (O.Line, 'W');
   end Power_Element;

   procedure Remaining_Time_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Alarm : constant Unsigned_16 := Capacity_Alarm (C, Inp);
      MAh   : constant Integer_32 := Inp.MAh_Drawn;
   begin
      if Alarm > 0 and then MAh >= Integer_32 (Alarm) then
         O.Attr := Critical;
      end if;
      if Alarm = 0 or else Float (MAh) <= 0.1 * Float (Alarm) then
         Append_String (O.Line, "--:--");
      elsif MAh > Integer_32 (Alarm) then
         Append_String (O.Line, "00:00");
      else
         declare
            Remaining : constant Float :=
              Float (Integer_32 (Alarm) - MAh) * Float (Inp.Clocks.Fly_Time_Us) / Float (MAh);
         begin
            pragma Assert (Remaining >= 0.0);
            Time_String (O.Line, Precision_Second,
                         (if Remaining >= 2_147_483_648.0 then Unsigned_32 (Integer_32'Last)
                          else Unsigned_32 (Float'Truncation (Remaining))));
         end;
      end if;
   end Remaining_Time_Element;

   procedure RSSI_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.RSSI_Percent < C.RSSI_Alarm then
         O.Attr := Critical;
      end if;
      Append (O.Line, Symbol_RSSI);
      Append_Natural (O.Line, Natural'Min (Natural (Inp.RSSI_Percent), 99), 2, False);
   end RSSI_Element;

   procedure RSSI_Dbm_Element (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.RSSI_Dbm < C.RSSI_Dbm_Alarm then
         O.Attr := Critical;
      end if;
      Append (O.Line, Symbol_RSSI);
      Append_Integer (O.Line, Integer_32 (Inp.RSSI_Dbm), 3, False);
      if Inp.Antenna /= 0 or else S.Diversity then
         S.Diversity := True;
         Append (O.Line, ':');
         Append_Integer (O.Line, Integer_32 (Inp.Antenna) + 1, 1, False);
      end if;
   end RSSI_Dbm_Element;

   procedure Timer_Element (I : Item; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      for T in Adaflight.OSD_Elements.Timer_Index loop
         declare
            Timer      : constant Unsigned_16 := C.Timers (T);
            Time       : constant Unsigned_32 := Timer_Value (Timer_Source_Of (Timer), Inp.Clocks);
            Alarm_Time : constant Unsigned_32 := Unsigned_32 (Timer_Alarm_Of (Timer)) * 60_000_000;
         begin
            if Alarm_Time /= 0 and then Time >= Alarm_Time then
               O.Attr := Critical;
            end if;
         end;
      end loop;
      Timer_String (O.Line, True, True, C.Timers (if I = Timer_1 then 0 else 1), Inp.Clocks);
   end Timer_Element;

   procedure Flip_Arrow_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Roll_Angle  : Integer := Integer (Inp.Roll) / 10;
      Pitch_Angle : constant Integer := Integer (Inp.Pitch) / 10;
   begin
      if abs Roll_Angle > 90 then
         Roll_Angle := (if Roll_Angle < 0 then -180 else 180) - Roll_Angle;
      end if;
      if (Inp.Crash_Flip or else (not Inp.Clocks.Armed and then not Inp.Upright))
        and then not ((Inp.Small_Angle < 180 and then Inp.Upright) or else (Roll_Angle = 0 and then Pitch_Angle = 0))
      then
         O.Attr := Info;
         if abs Pitch_Angle < 2 * abs Roll_Angle and then abs Roll_Angle < 2 * abs Pitch_Angle then
            if Pitch_Angle > 0 then
               Append (O.Line, (if Roll_Angle > 0 then Character'Val (16#6E#) else Character'Val (16#62#)));
            else
               Append (O.Line, (if Roll_Angle > 0 then Character'Val (16#6A#) else Character'Val (16#66#)));
            end if;
         elsif abs Pitch_Angle > abs Roll_Angle then
            Append (O.Line, (if Pitch_Angle > 0 then Symbol_Arrow_South else Symbol_Arrow_North));
         else
            Append (O.Line, (if Roll_Angle > 0 then Symbol_Arrow_West else Symbol_Arrow_East));
         end if;
      end if;
   end Flip_Arrow_Element;

   Axis_Chars : constant String := "RPY";

   procedure Mode_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Axis_Char : constant Character := Axis_Chars (Inp.Chirp_Axis + 1);
   begin
      if Inp.Modes.Failsafe then
         Append_String (O.Line, "!FS!");
      elsif Inp.Modes.GPS_Rescue then
         Append_String (O.Line, "RESC");
      elsif Inp.Modes.Headfree then
         Append_String (O.Line, "HEAD");
      elsif Inp.Modes.Passthru then
         Append_String (O.Line, "PASS");
      elsif Inp.Modes.Pos_Hold then
         Append_String (O.Line, "POSH");
      elsif Inp.Modes.Alt_Hold then
         Append_String (O.Line, "ALTH");
      elsif Inp.Modes.Chirp then
         if Inp.Chirp_Total <= 1 then
            if not Inp.Chirp_Finished then
               Append_String (O.Line, "CHIR");
            else
               Append (O.Line, Axis_Char);
               Append_String (O.Line, "FIN");
            end if;
         elsif Inp.Chirp_Series_Finished then
            Append (O.Line, Axis_Char);
            Append_String (O.Line, "FIN");
         else
            Append (O.Line, Axis_Char);
            Append_Natural (O.Line, Natural (Inp.Chirp_Current), 1, False);
            Append (O.Line, '/');
            Append_Natural (O.Line, Natural (Inp.Chirp_Total), 1, False);
         end if;
      elsif Inp.Modes.Angle then
         Append_String (O.Line, "ANGL");
      elsif Inp.Modes.Horizon then
         Append_String (O.Line, "HOR ");
      elsif Inp.Acro_Trainer_Box then
         Append_String (O.Line, "ATRN");
      elsif Inp.Airmode then
         Append_String (O.Line, "AIR ");
      else
         Append_String (O.Line, "ACRO");
      end if;
   end Mode_Element;

   procedure Clock_Element (Variant : Element_Type; Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => Inp.Date.Month in 1 .. 12
   is
      Valid : Boolean;
   begin
      RTC_Date_Time (O.Line, Variant, Inp.Has_Time, Inp.Date, Inp.Zone, Valid);
      if not Valid then
         O.Line := (others => <>);
      end if;
   end Clock_Element;

   Symbol_Total_Distance : constant Character := Character'Val (16#71#);
   Symbol_Over_Home      : constant Character := Character'Val (16#05#);
   Symbol_Home_Flag      : constant Character := Character'Val (16#11#);
   Symbol_Speed          : constant Character := Character'Val (16#70#);
   Symbol_Previous_Lap   : constant Character := Character'Val (16#79#);
   Symbol_Checkered_Flag : constant Character := Character'Val (16#24#);
   Symbol_Link_Quality   : constant Character := Character'Val (16#7B#);
   Symbol_Blackbox_Log   : constant Character := Character'Val (16#10#);
   Motor_Bar_Top         : constant := 16#88#;
   Motor_Stopped_RPM     : constant := 1000;

   function To_Upper (C : Character) return Character is
     (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);

   procedure Append_Name (O : in out Output; N : Name; Upper : Boolean)
     with Global => null
   is
   begin
      for K in 1 .. N.Length loop
         Append (O.Line, (if Upper then To_Upper (N.Data (K)) else N.Data (K)));
      end loop;
   end Append_Name;

   --  The motor's rotation count a minute from DShot telemetry or the ESC
   --  sensor, zero without either.
   function ESC_RPM_Of (Inp : Inputs; K : Motor_Index) return Integer_32 is
     (if Inp.DShot_Telemetry then Integer_32 (Adaflight.Maths.Round_Half_Even (Inp.DShot_RPM (K)))
      elsif Inp.ESC_Sensor_Feature
      then Integer_32 (Adaflight.Maths.Round_Half_Even (Float (Inp.ESC_RPM (K)) * Inp.ERPM_To_Hz * 60.0))
      else 0);

   function Wrap_16 (V : Integer_32) return Integer_16 is
     (Integer_16 ((Interfaces.Integer_64 (V) + 32_768) mod 65_536 - 32_768));

   procedure Flight_Distance_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.GPS_Fix and then Inp.GPS_Fix_Home then
         Distance_String (O.Line, Integer_32 (Inp.Flown_Cm / 100), Symbol_Total_Distance, C.Units);
      else
         Append (O.Line, Symbol_Total_Distance);
         Append (O.Line, Symbol_Hyphen);
      end if;
   end Flight_Distance_Element;

   procedure Home_Direction_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Direction : Integer := Integer (Inp.Home_Direction);
   begin
      if Inp.GPS_Fix and then Inp.GPS_Fix_Home then
         if Inp.Home_Distance_M > 0 then
            if Inp.Lap_Running then
               Direction := Integer'Min
                 (3600, Integer'Max (0, Adaflight.Maths.Round_Half_Even (Float (Inp.Lap_Direction_Cdeg) * 0.1)));
            end if;
            Append (O.Line, Direction_Symbol ((Direction - Integer (Inp.Yaw)) / 10));
         else
            Append (O.Line, Symbol_Over_Home);
         end if;
      else
         Append (O.Line, Symbol_Hyphen);
      end if;
   end Home_Direction_Element;

   procedure Home_Distance_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Distance : Integer_32 := Integer_32 (Inp.Home_Distance_M);
   begin
      if Inp.GPS_Fix and then Inp.GPS_Fix_Home then
         if Inp.Lap_Running then
            Distance :=
              Integer_32 (Integer'Max (0, Adaflight.Maths.Round_Half_Even (Float (Inp.Lap_Distance_Cm) * 0.01)));
         end if;
         Distance_String (O.Line, Distance, Symbol_Home_Flag, C.Units);
      else
         Append (O.Line, Symbol_Home_Flag);
         Append (O.Line, Symbol_Hyphen);
      end if;
   end Home_Distance_Element;

   procedure Coordinate_Element (I : Item; Variant : Element_Type; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Coordinate (O.Line, I = GPS_Longitude, Variant, Inp.GPS_Fix_Ever, Inp.Latitude, Inp.Longitude);
      O.Blink := (if Inp.GPS_Fix_Ever and then not Inp.GPS_Fix then Set else Clear);
   end Coordinate_Element;

   procedure Satellites_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      PDOP : Text;
   begin
      if not Inp.GPS_Fix or else Inp.Satellites < 4 then
         O.Attr := Critical;
      elsif Inp.Satellites < Inp.Rescue_Min_Sats and then Inp.Rescue_Configured then
         O.Attr := Warning;
      end if;
      Append (O.Line, Symbol_Sat_Left);
      Append (O.Line, Symbol_Sat_Right);
      if not Inp.GPS_Healthy then
         Append_String (O.Line, "NC");
      else
         Append_Natural (O.Line, Natural (Inp.Satellites), 2, False);
         if C.Show_PDOP then
            Append (O.Line, ' ');
            Print_Float (PDOP, Symbol_None, Float (Inp.PDOP) / 100.0, Default_Format, 1, True, Symbol_None);
            Append_String (O.Line, PDOP.Data (1 .. PDOP.Length));
         end if;
      end if;
   end Satellites_Element;

   procedure Speed_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append (O.Line, Symbol_Speed);
      if Inp.GPS_Fix then
         Append_Integer
           (O.Line, Speed_To_Unit (Integer_32 (if Inp.Use_3D_Speed then Inp.Speed_3D else Inp.Ground_Speed), C.Units),
            3, False);
      else
         Append (O.Line, Symbol_Hyphen);
      end if;
      Append (O.Line, Speed_Symbol (C.Units));
   end Speed_Element;

   procedure Efficiency_Element (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Efficiency : Integer := 0;
   begin
      if Inp.GPS_Present and then Inp.Clocks.Armed and then Inp.GPS_Fix and then Inp.Ground_Speed >= 100 then
         declare
            Speed    : constant Float := Float (Speed_To_Unit (Integer_32 (Inp.Ground_Speed), C.Units));
            Current  : constant Float := Float (Inp.Amperage) * 10.0;
            Filtered : Adaflight.Maths.Signal;
         begin
            pragma Assert (Speed >= 2.0);
            Adaflight.Filters.PT1_Apply (S.Efficiency, Current / Speed, Filtered);
            Efficiency :=
              (if abs Filtered < 2.0 ** 24 - 1.0 then Adaflight.Maths.Round_Half_Even (Filtered) else 10_000);
         end;
      end if;
      if Efficiency in 1 .. 9999 then
         Append_Integer (O.Line, Integer_32 (Efficiency), 4, False);
      else
         Append_String (O.Line, "----");
      end if;
      Append (O.Line, Symbol_MAh);
      Append (O.Line, '/');
      Append (O.Line, (if C.Units = Adaflight.OSD_Format.Imperial then Symbol_Miles else Symbol_Kilometres));
   end Efficiency_Element;

   procedure Lap_Time (O : in out Output; Time_Ms : Unsigned_32; Symbol : Character)
     with Global => null
   is
      T : constant Unsigned_32 := Time_Ms + 5;
   begin
      Append (O.Line, Symbol);
      Append_Natural (O.Line, Natural (T / 1000), 3, False);
      Append (O.Line, '.');
      Append_Natural (O.Line, Natural ((T mod 1000) / 10), 2, True);
   end Lap_Time;

   procedure Link_Quality_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Quality : Natural;
   begin
      if Inp.Link_Quality_Percent < C.Link_Quality_Alarm then
         O.Attr := Critical;
      end if;
      Append (O.Line, Symbol_Link_Quality);
      case Inp.Link_Source is
         when CRSF =>
            if Variant /= Type_2 then
               Append_Natural (O.Line, Natural (Inp.RF_Mode), 1, False);
               Append (O.Line, ':');
            end if;
            Append_Natural (O.Line, Natural (Inp.Link_Quality), 2, False);
         when GHST | MAVLink =>
            Append_Natural (O.Line, Natural (Inp.Link_Quality), 2, False);
         when None =>
            Quality := Natural'Min (Natural (Inp.Link_Quality) * 10 / 1023, 9);
            Append_Natural (O.Line, Quality, 1, False);
      end case;
   end Link_Quality_Element;

   procedure Uplink_Power_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Uplink_Mw < 1000 then
         Append (O.Line, Symbol_RSSI);
         Append_Natural (O.Line, Natural (Inp.Uplink_Mw), 3, False);
         Append_String (O.Line, "MW");
      else
         Print_Float (O.Line, Symbol_RSSI, Float (Inp.Uplink_Mw) / 1000.0, Default_Format, 1, False, 'W');
      end if;
   end Uplink_Power_Element;

   procedure Log_Status_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Blackbox_Box then
         Append (O.Line, Symbol_Blackbox_Log);
         if not Inp.Blackbox_Working then
            Append (O.Line, '!');
         elsif Inp.Blackbox_Full then
            Append (O.Line, '>');
         elsif Inp.Log_Number >= 0 then
            Append_Integer (O.Line, Inp.Log_Number, 1, False);
         end if;
      end if;
   end Log_Status_Element;

   procedure ESC_Temperature_Element (C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append (O.Line, 'E');
      Append (O.Line, Symbol_Temperature);
      if Inp.ESC_Sensor_Feature then
         Append_Integer (O.Line, Integer_32 (Temperature_In_Units (Integer (Inp.ESC_Temperature), C.Units)), 3, False);
         Append (O.Line, Temperature_Symbol (C.Units));
      else
         for K in 0 .. Inp.Motors - 1 loop
            if Inp.DShot (K).Has_Temperature then
               Append_Integer (O.Line, Integer_32 (Temperature_In_Units (Integer (Inp.DShot (K).Temperature), C.Units)),
                               3, False);
            else
               Append_String (O.Line, "  0");
            end if;
            Append (O.Line, Temperature_Symbol (C.Units));
         end loop;
      end if;
   end ESC_Temperature_Element;

   procedure ESC_RPM_Element (I : Item; S : in out State; Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => S.ESC_Motor < Unsigned_8 (Inp.Motors)
   is
      RPM : Integer_32 := ESC_RPM_Of (Inp, Motor_Index (S.ESC_Motor));
   begin
      if I = ESC_RPM_Frequency then
         RPM := RPM / 60;
      end if;
      Append_Integer (O.Line, Integer_32'Min (RPM, 99_999), 1, False);
      O.Offset_Y := S.ESC_Motor;
      S.ESC_Motor := S.ESC_Motor + 1;
      if S.ESC_Motor = Unsigned_8 (Inp.Motors) then
         S.ESC_Motor := 0;
      else
         O.Rendered := False;
      end if;
   end ESC_RPM_Element;

   procedure Motor_Diagnostics_Element (Inp : Inputs; O : in out Output)
     with Global => null,
          Pre => Integer_32 (Float'Truncation (Inp.Output_High)) > Integer_32 (Float'Truncation (Inp.Output_Low))
   is
      Low   : constant Integer_32 := Integer_32 (Float'Truncation (Inp.Output_Low));
      High  : constant Integer_32 := Integer_32 (Float'Truncation (Inp.Output_High));
      Level : Integer_32;
   begin
      for K in 0 .. Inp.Motors - 1 loop
         if Inp.Motors_Running then
            Level :=
              Adaflight.Maths.Scale_Range (Integer_32 (Float'Truncation (Inp.Motor_Output (K))), Low, High, 0, 8);
            if ESC_RPM_Of (Inp, K) < Motor_Stopped_RPM then
               Append (O.Line, 'S');
            else
               Append (O.Line, Character'Val ((Motor_Bar_Top - Interfaces.Integer_64 (Level)) mod 256));
            end if;
         else
            Append (O.Line, Character'Val (Motor_Bar_Top));
         end if;
      end loop;
   end Motor_Diagnostics_Element;

   procedure Profile_Name_Element (Label : String; Index : Unsigned_8; N : Name; O : in out Output)
     with Global => null,
          Pre => Label'Length <= 8
   is
   begin
      if N.Length = 0 then
         Append_String (O.Line, Label);
         Append_Natural (O.Line, Natural (Index) + 1, 1, False);
      else
         Append_Name (O, N, True);
      end if;
   end Profile_Name_Element;

   procedure Message_Element (I : Item; Inp : Inputs; O : in out Output)
     with Global => null,
          Pre    => I in Custom_Message_0 .. Custom_Message_3
   is
      Index : constant Message_Index := Item'Pos (I) - Item'Pos (Custom_Message_0);
   begin
      if Inp.Messages (Index).Length = 0 then
         Append_String (O.Line, "CUSTOM_MSG");
         Append_Natural (O.Line, Index + 1, 1, False);
      else
         Append_Name (O, Inp.Messages (Index), False);
      end if;
   end Message_Element;

   procedure Custom_Text_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Custom_Text_Present and then Inp.Custom.Length > 0 then
         for K in 1 .. Natural'Min (Inp.Custom.Length, Max_Length) loop
            Append (O.Line, Inp.Custom.Data (K));
         end loop;
      else
         Append_String (O.Line, "---");
      end if;
   end Custom_Text_Element;

   procedure Adjustment_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      if Inp.Adjustment_Present then
         Append_Name (O, Inp.Adjustment_Name, False);
         Append_String (O.Line, ": ");
         Append_Integer (O.Line, Inp.Adjustment_Value, 3, False);
      end if;
   end Adjustment_Element;

   procedure Lidar_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Distance : constant Integer_16 := Wrap_16 (Inp.Rangefinder_Cm);
   begin
      Append_String (O.Line, "RF:");
      if Distance > 0 then
         Append_Integer (O.Line, Integer_32 (Distance), 3, False);
      else
         Append_String (O.Line, "---");
      end if;
   end Lidar_Element;

   Sine_25_Degrees           : constant Float := 0.422618261740699;
   Quarter_Pi                : constant Float := Adaflight.Maths.Pi / 4.0;
   Symbol_AH_Bar             : constant := 16#80#;
   Symbol_AH_Left            : constant Character := Character'Val (16#03#);
   Symbol_AH_Right           : constant Character := Character'Val (16#02#);
   Symbol_AH_Decoration      : constant Character := Character'Val (16#13#);
   Symbol_Overlay_Vertical   : constant Character := Character'Val (16#16#);
   Symbol_Overlay_Horizontal : constant Character := Character'Val (16#17#);
   Symbol_Overlay_Centre     : constant Character := Character'Val (16#0B#);
   Symbol_Sprite_High        : constant := 16#08#;
   Blink_Attribute           : constant Unsigned_8 := 16#80#;
   Sidebar_Width             : constant := 7;
   Sidebar_Height            : constant := 3;
   Overlay_Width             : constant := 7;
   Overlay_Height            : constant := 5;
   Overlay_Sprite_Height     : constant := 3;
   Frame_Min_Width           : constant := 2;
   Frame_Max_Width           : constant := 30;
   Frame_Min_Height          : constant := 2;
   Frame_Max_Height          : constant := 16;
   Roll_Channel              : constant RC_Channel_Index := 0;
   Pitch_Channel             : constant RC_Channel_Index := 1;
   Yaw_Channel               : constant RC_Channel_Index := 2;
   Throttle_Channel          : constant RC_Channel_Index := 3;

   --  The sticks each radio mode puts on the left and right overlays.
   type Radio_Channels is record
      Left_Vertical, Left_Horizontal, Right_Vertical, Right_Horizontal : RC_Channel_Index;
   end record;
   Radio_Modes : constant array (Radio_Mode) of Radio_Channels :=
     (1 => (Pitch_Channel, Yaw_Channel, Throttle_Channel, Roll_Channel),
      2 => (Throttle_Channel, Yaw_Channel, Pitch_Channel, Roll_Channel),
      3 => (Pitch_Channel, Roll_Channel, Throttle_Channel, Yaw_Channel),
      4 => (Throttle_Channel, Roll_Channel, Pitch_Channel, Yaw_Channel));

   procedure Write_Char (O : in out Output; Inp : Inputs; X, Y : Integer; Char : Character)
     with Global => null,
          Pre    => O.Written < Max_Writes,
          Post   => O.Written = O.Written'Old + 1
   is
   begin
      O.Written := O.Written + 1;
      O.Writes (O.Written) := (X => Unsigned_8 (X mod 256), Y => Unsigned_8 (Y mod 256),
                               Attr => (if Inp.Item_Blinks then Blink_Attribute else 0), Char => Char);
   end Write_Char;

   procedure Horizon_Element (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Max_Pitch   : constant Integer_32 := Integer_32 (C.AH_Max_Pitch) * 10;
      Max_Roll    : constant Integer_32 := Integer_32 (C.AH_Max_Roll) * 10;
      Sign        : constant Integer_32 := (if C.AH_Invert then -1 else 1);
      Roll_Angle  : constant Integer_32 :=
        Adaflight.Maths.Constrain (Integer_32 (Inp.Roll) * Sign, -Max_Roll, Max_Roll);
      Pitch_Angle : Integer_32 := Adaflight.Maths.Constrain (Integer_32 (Inp.Pitch) * Sign, -Max_Pitch, Max_Pitch);
      Y           : Integer_32;
   begin
      if Max_Pitch > 0 then
         Pitch_Angle := (Pitch_Angle * 25) / Max_Pitch;
      end if;
      Pitch_Angle := Pitch_Angle - 41;
      Y := (((-Roll_Angle) * Integer_32 (S.Horizon_X)) / 64) - Pitch_Angle;
      if Y in 0 .. 81 then
         O.Offset_X := Unsigned_8 (S.Horizon_X mod 256);
         O.Offset_Y := Unsigned_8 (Y / 9);
         Append (O.Line, Character'Val (Symbol_AH_Bar + Integer (Y mod 9)));
      else
         O.Draw := False;
      end if;
      if S.Horizon_X = 4 then
         S.Horizon_X := -4;
      else
         O.Rendered := False;
         S.Horizon_X := S.Horizon_X + 1;
      end if;
   end Horizon_Element;

   function Round_Offset (X : Float) return Integer is
     (if abs X <= 1_000.0 then Adaflight.Maths.Round_Half_Even (X) else 0);

   function Stick_Position (Value : Float; Positions : Integer_32) return Integer_32 is
     ((Positions * (Adaflight.Maths.Constrain (Integer_32 (Float'Truncation (Value)), 1000, 1999) - 1000)) / 1000)
     with Pre  => Value in RC_Low .. RC_High and then Positions in 1 .. 15,
          Post => Stick_Position'Result in 0 .. Positions - 1;

   procedure Up_Down_Element (Inp : Inputs; O : in out Output)
     with Global => null
   is
      Up    : constant Axis_Vector := (-Inp.Earth_Up (0), -Inp.Earth_Up (1), -Inp.Earth_Up (2));
      Theta : Float range -1.0 .. 1.0;
      Psi   : Float range -1.0 .. 1.0;
   begin
      if abs Up (2) < Sine_25_Degrees and then abs Up (1) < Sine_25_Degrees then
         if Inp.Pitch > 0 then
            Theta := -Up (2);
            Psi := -Up (1);
         else
            Theta := Up (2);
            Psi := Up (1);
         end if;
         O.Offset_X := Unsigned_8
           (Round_Offset (Adaflight.Maths.Scale_Range_F (Psi, -Quarter_Pi, Quarter_Pi, -14.0, 14.0)) mod 256);
         O.Offset_Y := Unsigned_8
           (Round_Offset (Adaflight.Maths.Scale_Range_F (Theta, -Quarter_Pi, Quarter_Pi, -8.0, 8.0)) mod 256);
         Append (O.Line, (if Inp.Pitch > 0 then 'D' else 'U'));
      end if;
   end Up_Down_Element;

   procedure Overlay_Element (I : Item; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      M        : constant Radio_Channels := Radio_Modes (C.Overlay_Radio_Mode);
      V        : constant RC_Channel_Index := (if I = Stick_Overlay_Left then M.Left_Vertical else M.Right_Vertical);
      H        : constant RC_Channel_Index :=
        (if I = Stick_Overlay_Left then M.Left_Horizontal else M.Right_Horizontal);
      Cursor_X : constant Integer_32 := Stick_Position (Inp.RC_Data (H), Overlay_Width);
      Cursor_Y : constant Integer_32 :=
        Overlay_Height * Overlay_Sprite_Height - 1
        - Stick_Position (Inp.RC_Data (V), Overlay_Height * Overlay_Sprite_Height);
   begin
      Append (O.Line, Character'Val ((Symbol_Sprite_High + Integer (Cursor_Y mod Overlay_Sprite_Height)) mod 256));
      O.Offset_X := Unsigned_8 (Cursor_X mod 256);
      O.Offset_Y := Unsigned_8 ((Cursor_Y / Overlay_Sprite_Height) mod 256);
   end Overlay_Element;

   procedure RC_Channels_Element (S : in out State; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      Ch : constant RC_Channel_Setting := C.RC_Channels (S.RC_Channel);
   begin
      if Ch >= 0 then
         Append_Integer
           (O.Line,
            Adaflight.Maths.Scale_Range
              (Integer_32 (Float'Truncation (Inp.RC_Data (RC_Channel_Index (Ch)))), 1000, 2000, -1000, 1000),
            5, False);
         O.Offset_Y := Unsigned_8 (S.RC_Channel);
      end if;
      if S.RC_Channel = 3 then
         S.RC_Channel := 0;
      else
         S.RC_Channel := S.RC_Channel + 1;
         O.Rendered := False;
      end if;
   end RC_Channels_Element;

   procedure VTX_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output)
     with Global => null
   is
      use Adaflight.VTX_Table;
      Band      : Natural := Natural (C.VTX_Band);
      Channel   : Natural := Natural (C.VTX_Channel);
      Power     : Unsigned_8 := C.VTX_Power;
      Status    : Unsigned_8 := 0;
      Indicator : Character := Character'Val (0);
      B         : Band_Count;
      Ch        : Channel_Count;
   begin
      if Band = 0 then
         if Inp.VTX_Present then
            Band_Channel_Of (Inp.VTX, C.VTX_Frequency, B, Ch);
            Band := B;
            Channel := Ch;
         else
            Channel := 0;
         end if;
      end if;
      if Inp.VTX_Present then
         if Inp.VTX_Status_OK then
            Status := Inp.VTX_Status;
         end if;
         if C.VTX_Low_Power_Disarm /= 0 and then Inp.VTX_Power_OK then
            Power := Inp.VTX_Power_Index;
         end if;
      end if;
      if Inp.VTX_Control_Disable_Box then
         Indicator := 'D';
      elsif (Status and 1) /= 0 then
         Indicator := 'P';
      end if;
      declare
         Letter : constant Character := (if Inp.VTX_Present then Band_Letter_Of (Inp.VTX, Band) else '?');
         Name   : constant Character := (if Inp.VTX_Present then Channel_Name_Of (Inp.VTX, Channel) else '?');
         Label  : constant String := (if Inp.VTX_Present then Power_Label_Of (Inp.VTX, Natural (Power)) else "?");
      begin
         if Variant = Type_2 then
            Append_String (O.Line, Label);
         elsif (Status and 2) /= 0 then
            Append_String (O.Line, "-:-:-:L");
         else
            Append (O.Line, Letter);
            Append (O.Line, ':');
            Append (O.Line, Name);
            Append (O.Line, ':');
            Append_String (O.Line, Label);
            if Indicator /= Character'Val (0) then
               Append (O.Line, ':');
               Append (O.Line, Indicator);
            end if;
         end if;
      end;
   end VTX_Element;

   procedure Sidebars_Background (S : in out State; Inp : Inputs; Pos_X, Pos_Y : Unsigned_8; O : in out Output)
     with Global => null,
          Pre    => O.Written = 0
   is
      X : constant Integer := Integer (Pos_X);
      Y : constant Integer := Integer (Pos_Y);
   begin
      if S.Sidebar_Level then
         Write_Char (O, Inp, X - Sidebar_Width + 1, Y, Symbol_AH_Left);
         Write_Char (O, Inp, X + Sidebar_Width - 1, Y, Symbol_AH_Right);
         S.Sidebar_Level := False;
      else
         Write_Char (O, Inp, X - Sidebar_Width, Y + S.Sidebar_Y, Symbol_AH_Decoration);
         Write_Char (O, Inp, X + Sidebar_Width, Y + S.Sidebar_Y, Symbol_AH_Decoration);
         if S.Sidebar_Y = Sidebar_Height then
            S.Sidebar_Y := -Sidebar_Height;
            S.Sidebar_Level := True;
         else
            S.Sidebar_Y := S.Sidebar_Y + 1;
         end if;
         O.Rendered := False;
      end if;
      O.Draw := False;
   end Sidebars_Background;

   procedure Frame_Background
     (S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Unsigned_8; O : in out Output)
     with Global => null,
          Pre    => O.Written = 0
   is
      Width  : constant Integer_32 :=
        Adaflight.Maths.Constrain (Integer_32 (C.Camera_Frame_Width), Frame_Min_Width, Frame_Max_Width);
      Height : constant Integer_32 :=
        Adaflight.Maths.Constrain (Integer_32 (C.Camera_Frame_Height), Frame_Min_Height, Frame_Max_Height);
      X      : constant Integer := Integer (Pos_X);
      Y      : constant Integer := Integer (Pos_Y);
   begin
      if S.Frame_Phase /= Bottom then
         O.Rendered := False;
      end if;
      if S.Frame_Phase = Middle then
         Write_Char (O, Inp, X, Y + Integer (S.Frame_Row), Symbol_Overlay_Vertical);
         Write_Char (O, Inp, X + Integer (Width) - 1, Y + Integer (S.Frame_Row), Symbol_Overlay_Vertical);
         O.Draw := False;
         S.Frame_Row := S.Frame_Row + 1;
         if S.Frame_Row = Unsigned_8 (Height) then
            S.Frame_Row := 1;
            S.Frame_Phase := Bottom;
         end if;
      else
         Append (O.Line, Symbol_Overlay_Centre);
         for K in 2 .. Width - 1 loop
            Append (O.Line, Symbol_Overlay_Horizontal);
         end loop;
         Append (O.Line, Symbol_Overlay_Centre);
         if S.Frame_Phase = Top then
            S.Frame_Phase := Middle;
         else
            O.Offset_Y := Unsigned_8 (Height - 1);
            S.Frame_Phase := Top;
         end if;
      end if;
   end Frame_Background;

   procedure Overlay_Background (S : in out State; O : in out Output)
     with Global => null
   is
   begin
      if S.Overlay_Vertical then
         Append (O.Line, Symbol_Overlay_Vertical);
         O.Offset_X := (Overlay_Width - 1) / 2;
         O.Offset_Y := S.Overlay_Y;
         S.Overlay_Y := S.Overlay_Y + 1;
         if S.Overlay_Y = (Overlay_Height - 1) / 2 then
            S.Overlay_Y := S.Overlay_Y + 1;
         end if;
         if S.Overlay_Y = Overlay_Height then
            S.Overlay_Y := 0;
            S.Overlay_Vertical := False;
         end if;
         O.Rendered := False;
      else
         for K in 1 .. Overlay_Width loop
            Append (O.Line, Symbol_Overlay_Horizontal);
         end loop;
         O.Line.Data ((Overlay_Width - 1) / 2 + 1) := Symbol_Overlay_Centre;
         O.Offset_Y := (Overlay_Height - 1) / 2;
         S.Overlay_Vertical := True;
      end if;
   end Overlay_Background;

   procedure Init (S : out State; C : Settings) is
   begin
      S := (others => <>);
      Adaflight.Filters.PT1_Init (S.Efficiency, Adaflight.Filters.PT1_Gain (0.5, 1.0 / Float (C.Framerate_Hz)));
   end Init;

   procedure Render (I : Item; Variant : Adaflight.OSD_Format.Element_Type; S : in out State; C : Settings;
                     Inp : Inputs; O : out Output) is
   begin
      O := (others => <>);
      case I is
         when Altitude =>
            Altitude_Element (Variant, C, Inp, O);
         when Pitch_Angle | Roll_Angle =>
            Angle_Element (I, Inp, O);
         when Anti_Gravity =>
            if Inp.Anti_Gravity then
               Append_String (O.Line, "AG");
            end if;
         when Average_Cell_Voltage =>
            Cell_Voltage_Element (Inp, O);
         when Compass_Bar =>
            Compass_Element (Inp, O);
         when Core_Temperature =>
            Core_Temperature_Element (C, Inp, O);
         when Crosshairs =>
            Append (O.Line, Symbol_Centre_Line);
            Append (O.Line, Symbol_Centre);
            Append (O.Line, Symbol_Centre_Line_Right);
         when Current_Draw =>
            Current_Element (Inp, O);
         when Debug =>
            Debug_Element (0, "DBG", Inp, O);
         when Debug2 =>
            Debug_Element (4, "D2 ", Inp, O);
         when Disarmed =>
            if not Inp.Clocks.Armed then
               Append_String (O.Line, "DISARMED");
            end if;
         when G_Force =>
            Print_Float (O.Line, Symbol_None, Inp.G_Force, Default_Format, 1, True, 'G');
         when MAh_Drawn =>
            MAh_Element (C, Inp, O);
         when Watt_Hours_Drawn =>
            Watt_Hours_Element (C, Inp, O);
         when Main_Battery_Usage =>
            Usage_Element (Variant, C, Inp, O);
         when Main_Battery_Voltage =>
            Voltage_Element (Inp, O);
         when Numerical_Heading =>
            Heading_Element (Inp, O);
         when Numerical_Vario =>
            Vario_Element (C, Inp, O);
         when PID_Rate_Profile =>
            Profile_Element (Inp, O);
         when Roll_PIDs =>
            PID_Element ("ROL", Inp.PIDs (0), O);
         when Pitch_PIDs =>
            PID_Element ("PIT", Inp.PIDs (1), O);
         when Yaw_PIDs =>
            PID_Element ("YAW", Inp.PIDs (2), O);
         when Power =>
            Power_Element (Inp, O);
         when Remaining_Time_Estimate =>
            Remaining_Time_Element (C, Inp, O);
         when RSSI_Value =>
            RSSI_Element (C, Inp, O);
         when RSSI_Dbm_Value =>
            RSSI_Dbm_Element (S, C, Inp, O);
         when RSNR_Value =>
            Append (O.Line, Symbol_RSSI);
            Append_Integer (O.Line, Integer_32 (Inp.RSNR), 3, False);
         when Throttle_Position =>
            Append (O.Line, Symbol_Throttle);
            Append_Integer (O.Line, Integer_32 (Inp.Throttle_Percent), 3, False);
         when Timer_1 | Timer_2 =>
            Timer_Element (I, C, Inp, O);
         when Aux_Value =>
            if C.Aux_Symbol /= 0 then
               Append (O.Line, Character'Val (C.Aux_Symbol));
               Append_Natural (O.Line, Natural (Inp.Aux_Value), 1, False);
            end if;
         when Ready_Mode =>
            if Inp.Ready_Box and then not Inp.Clocks.Armed then
               Append_String (O.Line, "READY");
            end if;
         when Position_Hold_Ready =>
            if Inp.Pos_Hold_Ready then
               Append_String (O.Line, "POSH RDY");
            end if;
         when Total_Flights =>
            Append (O.Line, '#');
            Append_Integer (O.Line, To_Signed (Inp.Total_Flights), 1, False);
         when Flip_Arrow =>
            Flip_Arrow_Element (Inp, O);
         when Fly_Mode =>
            Mode_Element (Inp, O);
         when RTC_Date_Time =>
            Clock_Element (Variant, Inp, O);
         when Flight_Distance =>
            Flight_Distance_Element (C, Inp, O);
         when Home_Direction =>
            Home_Direction_Element (Inp, O);
         when Home_Distance =>
            Home_Distance_Element (C, Inp, O);
         when GPS_Longitude | GPS_Latitude =>
            Coordinate_Element (I, Variant, Inp, O);
         when GPS_Sats =>
            Satellites_Element (C, Inp, O);
         when GPS_Speed =>
            Speed_Element (C, Inp, O);
         when Efficiency =>
            Efficiency_Element (S, C, Inp, O);
         when GPS_Lap_Time_Current =>
            Lap_Time (O, (if Inp.Lap_Running then Inp.GPS_Time_Ms - Inp.Lap_Last_Ms else 0), Symbol_Total_Distance);
         when GPS_Lap_Time_Previous =>
            Lap_Time (O, Inp.Lap_Previous_Ms, Symbol_Previous_Lap);
         when GPS_Lap_Time_Best3 =>
            Lap_Time (O, Inp.Lap_Best3_Ms, Symbol_Checkered_Flag);
         when Link_Quality =>
            Link_Quality_Element (Variant, C, Inp, O);
         when TX_Uplink_Power =>
            Uplink_Power_Element (Inp, O);
         when Log_Status =>
            Log_Status_Element (Inp, O);
         when ESC_Temperature =>
            ESC_Temperature_Element (C, Inp, O);
         when ESC_RPM | ESC_RPM_Frequency =>
            ESC_RPM_Element (I, S, Inp, O);
         when Motor_Diagnostics =>
            Motor_Diagnostics_Element (Inp, O);
         when Rate_Profile_Name =>
            Profile_Name_Element ("RATE_", Inp.Rate_Index, Inp.Rate_Profile_Name, O);
         when PID_Profile_Name =>
            Profile_Name_Element ("PID_", Inp.PID_Index, Inp.PID_Profile_Name, O);
         when Profile_Name =>
            Profile_Name_Element
              ("OSD_", Unsigned_8 (C.OSD_Profile_Index) - 1, C.OSD_Profile_Names (C.OSD_Profile_Index), O);
         when Battery_Profile_Name =>
            Profile_Name_Element ("BAT", Inp.Battery_Index, Inp.Battery_Profile_Name, O);
         when Custom_Message_0 | Custom_Message_1 | Custom_Message_2 | Custom_Message_3 =>
            Message_Element (I, Inp, O);
         when Custom_Serial_Text =>
            Custom_Text_Element (Inp, O);
         when Adjustment_Range =>
            Adjustment_Element (Inp, O);
         when Lidar_Distance =>
            Lidar_Element (Inp, O);
         when Artificial_Horizon =>
            Horizon_Element (S, C, Inp, O);
         when Up_Down_Reference =>
            Up_Down_Element (Inp, O);
         when Stick_Overlay_Left | Stick_Overlay_Right =>
            Overlay_Element (I, C, Inp, O);
         when RC_Channels =>
            RC_Channels_Element (S, C, Inp, O);
         when VTX_Channel =>
            VTX_Element (Variant, C, Inp, O);
         when others =>
            O.Draw := False;
      end case;
   end Render;

   procedure Render_Background (I : Item; S : in out State; C : Settings; Inp : Inputs; Pos_X, Pos_Y : Unsigned_8;
                                O : out Output) is
   begin
      O := (others => <>);
      case I is
         when Craft_Name =>
            if Inp.Craft_Name.Length = 0 then
               Append_String (O.Line, "CRAFT_NAME");
            else
               Append_Name (O, Inp.Craft_Name, True);
            end if;
         when Pilot_Name =>
            if Inp.Pilot_Name.Length = 0 then
               Append_String (O.Line, "PILOT_NAME");
            else
               Append_Name (O, Inp.Pilot_Name, True);
            end if;
         when Horizon_Sidebars =>
            Sidebars_Background (S, Inp, Pos_X, Pos_Y, O);
         when Camera_Frame =>
            Frame_Background (S, C, Inp, Pos_X, Pos_Y, O);
         when Stick_Overlay_Left | Stick_Overlay_Right =>
            Overlay_Background (S, O);
         when others =>
            O.Draw := False;
      end case;
   end Render_Background;

   procedure Link_Quality_Message (Inp : Inputs; O : in out Output)
     with Global => null
   is
   begin
      Append_String (O.Line, "LQ ");
      case Inp.Link_Source is
         when CRSF =>
            Append_Natural (O.Line, Natural (Inp.RF_Mode), 2, False);
            Append (O.Line, ':');
            Append_Natural (O.Line, Natural (Inp.Link_Quality), 3, True);
            Append (O.Line, ' ');
            Append_Integer (O.Line, Integer_32 (Inp.RSSI_Dbm), 3, False);
         when GHST =>
            Append_Natural (O.Line, Natural (Inp.Link_Quality), 3, True);
            Append (O.Line, ' ');
            Append_Integer (O.Line, Integer_32 (Inp.RSSI_Dbm), 3, False);
         when None | MAVLink =>
            Append_Natural (O.Line, Natural'Min (Natural (Inp.Link_Quality) * 10 / 1023, 9), 1, False);
      end case;
   end Link_Quality_Message;

   procedure Render_Warnings
     (WS : in out Adaflight.OSD_Warnings.State; WC : Adaflight.OSD_Warnings.Settings;
      WI : Adaflight.OSD_Warnings.Inputs; Craft_Name_Messages, Blink_State : Boolean; Inp : Inputs;
      Craft : in out Craft_Name_Buffer; O : out Output; Beeper_Shown : out Boolean)
   is
      Line     : Adaflight.OSD_Warnings.Text;
      Blinking : Boolean;
      Attr     : Severity;
   begin
      O := (others => <>);
      Adaflight.OSD_Warnings.Render (WS, WC, WI, Line, Blinking, Attr, Beeper_Shown);
      O.Attr := Attr;
      O.Blink := (if Blinking then Set else Clear);
      Append_String (O.Line, Line.Data (1 .. Line.Length));
      if Craft_Name_Messages then
         if Blink_State or else Line.Length = 0 then
            O.Line := (others => <>);
            Link_Quality_Message (Inp, O);
         end if;
         for K in 1 .. Max_Name - 1 loop
            Craft (K) := (if K <= O.Line.Length then O.Line.Data (K) else Character'Val (0));
         end loop;
      end if;
   end Render_Warnings;

end Adaflight.OSD_Render;
