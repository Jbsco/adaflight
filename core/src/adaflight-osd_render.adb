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

   procedure Battery_Severity (Inp : Inputs; O : in out Output) is
   begin
      if Inp.Battery = Adaflight.Battery.Warning then
         O.Attr := Warning;
      elsif Inp.Battery = Adaflight.Battery.Critical then
         O.Attr := Critical;
      end if;
   end Battery_Severity;

   procedure Altitude_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure Angle_Element (I : Item; Inp : Inputs; O : in out Output) is
      Angle : constant Float := Float (if I = Pitch_Angle then Inp.Pitch else Inp.Roll) / 10.0;
   begin
      Print_Float (O.Line, (if I = Pitch_Angle then Symbol_Pitch else Symbol_Roll), abs Angle,
                   (Lead => (if Angle < 0.0 then '-' else ' '), Has_Lead => True, Width => 2, Zero_Pad => True),
                   1, True, Symbol_None);
   end Angle_Element;

   procedure Cell_Voltage_Element (Inp : Inputs; O : in out Output)
     with Pre => Inp.Min_Cell /= Inp.Max_Cell
   is
   begin
      Battery_Severity (Inp, O);
      Print_Float (O.Line, Battery_Symbol (Natural (Inp.Cell_Voltage), Inp.Battery, Inp.Min_Cell, Inp.Max_Cell),
                   Float (Inp.Cell_Voltage) / 100.0, Default_Format, 2, False, Symbol_Volt);
   end Cell_Voltage_Element;

   procedure Compass_Element (Inp : Inputs; O : in out Output) is
      Sector : constant Natural := Heading_Sector (Integer (Inp.Yaw) / 10, 16);
   begin
      Append_String (O.Line, Compass (Sector + 1 .. Sector + 9));
   end Compass_Element;

   procedure Core_Temperature_Element (C : Settings; Inp : Inputs; O : in out Output) is
   begin
      Append (O.Line, 'C');
      Append (O.Line, Symbol_Temperature);
      Append_Integer (O.Line, Integer_32 (Temperature_In_Units (Integer (Inp.Core_Temperature), C.Units)), 3, False);
      Append (O.Line, Temperature_Symbol (C.Units));
   end Core_Temperature_Element;

   procedure Current_Element (Inp : Inputs; O : in out Output) is
   begin
      Print_Float (O.Line, Symbol_None, abs (Float (Inp.Amperage) / 100.0),
                   (Lead => ' ', Has_Lead => False, Width => 3, Zero_Pad => False), 2, False, Symbol_Amp);
   end Current_Element;

   procedure Debug_Element (First : Debug_Index; Label : String; Inp : Inputs; O : in out Output)
     with Pre => First <= 4 and then Label'Length <= 4
   is
   begin
      Append_String (O.Line, Label);
      for K in First .. First + 3 loop
         Append (O.Line, ' ');
         Append_Integer (O.Line, Integer_32 (Inp.Debug (K)), 5, False);
      end loop;
   end Debug_Element;

   procedure MAh_Element (C : Settings; Inp : Inputs; O : in out Output) is
   begin
      if Over_Capacity (C, Inp) then
         O.Attr := Critical;
      end if;
      Append_Integer (O.Line, Inp.MAh_Drawn, 4, False);
      Append (O.Line, Symbol_MAh);
   end MAh_Element;

   procedure Watt_Hours_Element (C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure Usage_Element (Variant : Element_Type; C : Settings; Inp : Inputs; O : in out Output) is
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
     with Pre => Inp.Min_Cell /= Inp.Max_Cell
   is
      Voltage : constant Float := Float (Inp.Pack_Voltage) / 100.0;
   begin
      Battery_Severity (Inp, O);
      Print_Float (O.Line, Battery_Symbol (Natural (Inp.Cell_Voltage), Inp.Battery, Inp.Min_Cell, Inp.Max_Cell),
                   Voltage, Default_Format, (if Voltage >= 10.0 then 1 else 2), True, Symbol_Volt);
   end Voltage_Element;

   procedure Heading_Element (Inp : Inputs; O : in out Output) is
      Heading : constant Integer := Integer (Inp.Yaw) / 10;
   begin
      Append (O.Line, Direction_Symbol (Heading));
      Append_Natural (O.Line, Heading, 3, True);
   end Heading_Element;

   procedure Vario_Element (C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure Profile_Element (Inp : Inputs; O : in out Output) is
   begin
      Append_Natural (O.Line, Natural (Inp.PID_Index) + 1, 1, False);
      Append (O.Line, '-');
      Append_Natural (O.Line, Natural (Inp.Rate_Index) + 1, 1, False);
   end Profile_Element;

   procedure PID_Element (Label : String; G : PID_Gains; O : in out Output)
     with Pre => Label'Length <= 8
   is
   begin
      PID_Line (O.Line, Label, G.P, G.I, G.D, G.D_Max, G.F);
   end PID_Element;

   procedure Power_Element (Inp : Inputs; O : in out Output) is
   begin
      Append_Integer (O.Line, (Inp.Amperage * Integer_32 (Inp.Pack_Voltage)) / 10_000, 4, False);
      Append (O.Line, 'W');
   end Power_Element;

   procedure Remaining_Time_Element (C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure RSSI_Element (C : Settings; Inp : Inputs; O : in out Output) is
   begin
      if Inp.RSSI_Percent < C.RSSI_Alarm then
         O.Attr := Critical;
      end if;
      Append (O.Line, Symbol_RSSI);
      Append_Natural (O.Line, Natural'Min (Natural (Inp.RSSI_Percent), 99), 2, False);
   end RSSI_Element;

   procedure RSSI_Dbm_Element (S : in out State; C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure Timer_Element (I : Item; C : Settings; Inp : Inputs; O : in out Output) is
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

   procedure Flip_Arrow_Element (Inp : Inputs; O : in out Output) is
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

   procedure Mode_Element (Inp : Inputs; O : in out Output) is
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
     with Pre => Inp.Date.Month in 1 .. 12
   is
      Valid : Boolean;
   begin
      RTC_Date_Time (O.Line, Variant, Inp.Has_Time, Inp.Date, Inp.Zone, Valid);
      if not Valid then
         O.Line := (others => <>);
      end if;
   end Clock_Element;

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
         when others =>
            O.Draw := False;
      end case;
   end Render;

end Adaflight.OSD_Render;
