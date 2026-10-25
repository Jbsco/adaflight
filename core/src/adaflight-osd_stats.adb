with Adaflight.Maths;

package body Adaflight.OSD_Stats with SPARK_Mode is
   use Adaflight.OSD_Format;
   use type Interfaces.Integer_64;

   function Wrap16 (V : Integer_32) return Integer_16 is
     (if V mod 65_536 >= 32_768 then Integer_16 (V mod 65_536 - 65_536) else Integer_16 (V mod 65_536));

   function Wrap32 (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then Integer_32 (Interfaces.Integer_64 (U) - 2 ** 32) else Integer_32 (U));

   procedure Set (T : out Text; S : String)
     with Pre => S'Length <= Max_Length
   is
   begin
      T := (others => <>);
      Append_String (T, S);
   end Set;

   procedure Reset (S : out Statistics; Has_Link_Quality_Source : Boolean) is
   begin
      S := (Max_Current => 0, Max_Speed => 0, Min_Voltage => 5_000, End_Voltage => 0, Min_RSSI => 99,
            Max_Altitude => 0, Max_Distance => 0, Armed_Time_Us => 0, Max_G_Force => 0.0, Max_ESC_Temp_Ix => 0,
            Max_ESC_Temp => 0, Max_ESC_RPM => 0, Min_Link_Quality => (if Has_Link_Quality_Source then 100 else 99),
            Min_RSSI_Dbm => 0, Min_RSNR => 20);
   end Reset;

   function Average_ESC_RPM (R : Readings) return Integer_32 is
     (if R.ESC_Sensor_Feature then
         Integer_32 (Adaflight.Maths.Round_Half_Even (Float (R.ESC_Erpm) * R.Erpm_To_Hz * 60.0))
      elsif R.DShot_Telemetry then Integer_32 (Adaflight.Maths.Round_Half_Even (R.DShot_RPM_Average))
      else 0);

   procedure Update (S : in out Statistics; R : Readings) is
      Value : Integer_16;
      Rpm   : Integer_32;
   begin
      Value := Wrap16 (Integer_32 (if R.Use_3D_Speed then R.Speed_3D else R.Ground_Speed));
      if S.Max_Speed < Value then
         S.Max_Speed := Value;
      end if;
      Value := Wrap16 (Integer_32 (Stats_Voltage (R)));
      if S.Min_Voltage > Value then
         S.Min_Voltage := Value;
      end if;
      Value := Wrap16 (R.Amperage);
      if S.Max_Current < Value then
         S.Max_Current := Value;
      end if;
      Value := Integer_16 (R.RSSI_Percent);
      if Integer_16 (S.Min_RSSI) > Value then
         S.Min_RSSI := R.RSSI_Percent;
      end if;
      if S.Max_Altitude < R.Altitude_Cm then
         S.Max_Altitude := R.Altitude_Cm;
      end if;
      if S.Max_G_Force < R.Acceleration then
         S.Max_G_Force := R.Acceleration;
      end if;
      Value := Wrap16 (Integer_32 (R.Link_Quality_Percent));
      if Integer (S.Min_Link_Quality) > Integer (Value) then
         S.Min_Link_Quality := Unsigned_16'Mod (Value);
      end if;
      if S.Min_RSSI_Dbm > R.RSSI_Dbm then
         S.Min_RSSI_Dbm := R.RSSI_Dbm;
      end if;
      if S.Min_RSNR > R.RSNR then
         S.Min_RSNR := R.RSNR;
      end if;
      if R.GPS_Fix and then R.GPS_Fix_Home then
         if S.Max_Distance < R.Distance_To_Home then
            S.Max_Distance := R.Distance_To_Home;
         end if;
      end if;
      if R.ESC_Sensor_Feature then
         Value := Integer_16 (R.ESC_Temperature);
         if S.Max_ESC_Temp < Value then
            S.Max_ESC_Temp := Value;
         end if;
      else
         for K in 0 .. R.Motors - 1 loop
            if Integer (R.DShot_Max_Temp (K)) > Integer (S.Max_ESC_Temp) then
               S.Max_ESC_Temp_Ix := Integer_16 (K + 1);
               S.Max_ESC_Temp := Integer_16 (R.DShot_Max_Temp (K));
            end if;
         end loop;
      end if;
      Rpm := Average_ESC_RPM (R);
      if S.Max_ESC_RPM < Rpm then
         S.Max_ESC_RPM := Rpm;
      end if;
   end Update;

   procedure Lap_Time (Ms : Unsigned_32; T : out Text) is
   begin
      T := (others => <>);
      if Ms /= 0 then
         declare
            Rounded : constant Unsigned_32 := Ms + 5;
         begin
            Append_Natural (T, Natural (Rounded / 1_000), 3, False);
            Append (T, '.');
            Append_Natural (T, Natural ((Rounded mod 1_000) / 10), 2, True);
         end;
      else
         Append_String (T, "  -.--");
      end if;
   end Lap_Time;

   procedure Blackbox_Status (P : Page; T : out Text) is
   begin
      T := (others => <>);
      if P.Blackbox_Working then
         declare
            Total : constant Unsigned_32 := Storage_Total (P);
            Used  : constant Unsigned_32 :=
              (if P.Blackbox_Device = Device_SDCard then Total - P.SD_Free_Bytes / 1_024_000
               elsif P.Blackbox_Device = Device_Flash then P.Flash_Offset / 1_024
               else 0);
         begin
            Append_Natural (T, Natural (Unsigned_16'Mod ((Used * 100) / Total)), 0, False);
            Append (T, '%');
         end;
      else
         Append_String (T, "FAULT");
      end if;
   end Blackbox_Status;

   function Source_Name (Source : Timer_Source) return String is
     (case Source is
        when Source_On => "ON TIME  ",
        when Source_Total_Armed => "TOTAL ARM",
        when Source_Last_Armed => "LAST ARM ",
        when Source_On_Or_Armed => "ON/ARM   ",
        when Source_Launch_Time => "LAUNCH TIME",
        when others => "");

   procedure Stat_Text (Which : Stat; S : Statistics; P : Page; Line : out Stat_Line) is
   begin
      Line := (others => <>);
      case Which is
         when RTC_Date_Time =>
            declare
               Valid : Boolean;
            begin
               RTC_Date_Time (Line.Value, P.RTC_Variant, P.Has_Time, P.Date, P.Zone, Valid);
               if not Valid then
                  Set (Line.Value, "NO RTC");
               end if;
            end;
            Line.Labeled := False;
            Line.Shown := True;
         when Timer_1 | Timer_2 =>
            declare
               Timer  : constant Unsigned_16 := (if Which = Timer_1 then P.Timer_1 else P.Timer_2);
               Source : constant Timer_Source := Timer_Source_Of (Timer);
            begin
               Timer_String (Line.Value, False, Source /= Source_On, Timer, P.Clocks);
               Set (Line.Label, Source_Name (Source));
            end;
            Line.Shown := True;
         when Max_Altitude =>
            Print_Float (Line.Value, Symbol_None, Meters_To_Unit (S.Max_Altitude, P.Units) / 100.0, Default_Format, 1,
                         True, Meters_Symbol (P.Units));
            Set (Line.Label, "MAX ALTITUDE");
            Line.Shown := True;
         when Max_Speed =>
            if P.GPS_Feature then
               Append_Integer (Line.Value, Speed_To_Unit (Integer_32 (S.Max_Speed), P.Units), 0, False);
               Append (Line.Value, Speed_Symbol (P.Units));
               Set (Line.Label, "MAX SPEED");
               Line.Shown := True;
            end if;
         when Max_Distance =>
            if P.GPS_Feature then
               Distance_String (Line.Value, Integer_32 (S.Max_Distance), Symbol_None, P.Units);
               Set (Line.Label, "MAX DISTANCE");
               Line.Shown := True;
            end if;
         when Flight_Distance =>
            if P.GPS_Feature then
               Distance_String (Line.Value, Integer_32 (P.Flight_Distance_Cm / 100), Symbol_None, P.Units);
               Set (Line.Label, "FLIGHT DISTANCE");
               Line.Shown := True;
            end if;
         when Min_Battery =>
            Print_Float (Line.Value, Symbol_None, Float (S.Min_Voltage) / 100.0, Default_Format, 2, True, Symbol_Volt);
            Set (Line.Label, (if P.Show_Cell_Value then "MIN AVG CELL" else "MIN BATTERY"));
            Line.Shown := True;
         when End_Battery =>
            Print_Float (Line.Value, Symbol_None, Float (S.End_Voltage) / 100.0, Default_Format, 2, True, Symbol_Volt);
            Set (Line.Label, (if P.Show_Cell_Value then "END AVG CELL" else "END BATTERY"));
            Line.Shown := True;
         when Battery =>
            Print_Float (Line.Value, Symbol_None,
                         Float (if P.Show_Cell_Value then P.Cell_Voltage else P.Pack_Voltage) / 100.0, Default_Format,
                         2, True, Symbol_Volt);
            Set (Line.Label, (if P.Show_Cell_Value then "AVG BATT CELL" else "BATTERY"));
            Line.Shown := True;
         when Min_RSSI =>
            Append_Natural (Line.Value, Natural (S.Min_RSSI), 0, False);
            Append (Line.Value, '%');
            Set (Line.Label, "MIN RSSI");
            Line.Shown := True;
         when Max_Current =>
            if P.Current_Meter then
               Print_Float (Line.Value, Symbol_None, Float (S.Max_Current) / 100.0, Default_Format, 2, False,
                            Symbol_Amp);
               Set (Line.Label, "MAX CURRENT");
               Line.Shown := True;
            end if;
         when Used_MAh =>
            if P.Current_Meter then
               Append_Integer (Line.Value, P.MAh_Drawn, 0, False);
               Append (Line.Value, Symbol_MAh);
               Set (Line.Label, "USED MAH");
               Line.Shown := True;
            end if;
         when Watt_Hours_Drawn =>
            if P.Current_Meter then
               Print_Float (Line.Value, Symbol_None, P.Wh_Drawn, Default_Format, 2, True, Symbol_None);
               Set (Line.Label, "USED WATT HOURS");
               Line.Shown := True;
            end if;
         when Blackbox =>
            if P.Blackbox_Device in Device_Flash | Device_SDCard then
               Blackbox_Status (P, Line.Value);
               Set (Line.Label, "BLACKBOX");
               Line.Shown := True;
            end if;
         when Blackbox_Number =>
            if P.Log_Number >= 0 then
               Append_Integer (Line.Value, P.Log_Number, 0, False);
               Set (Line.Label, "BB LOG NUM");
               Line.Shown := True;
            end if;
         when Max_G_Force =>
            if P.Acc_Present then
               Print_Float (Line.Value, Symbol_None, S.Max_G_Force, Default_Format, 1, True, 'G');
               Set (Line.Label, "MAX G-FORCE");
               Line.Shown := True;
            end if;
         when Max_ESC_Temp =>
            if S.Max_ESC_Temp_Ix > 0 then
               Append_Integer (Line.Value, Integer_32 (S.Max_ESC_Temp_Ix), 0, False);
               Append (Line.Value, ' ');
            end if;
            Append_Integer (Line.Value, Integer_32 (Temperature_In_Units (Integer (S.Max_ESC_Temp), P.Units)), 0,
                            False);
            Append (Line.Value, Temperature_Symbol (P.Units));
            Set (Line.Label, "MAX ESC TEMP");
            Line.Shown := True;
         when Max_ESC_RPM =>
            Append_Integer (Line.Value, S.Max_ESC_RPM, 0, False);
            Set (Line.Label, "MAX ESC RPM");
            Line.Shown := True;
         when Min_Link_Quality =>
            Append_Natural (Line.Value, Natural (S.Min_Link_Quality), 0, False);
            Append (Line.Value, '%');
            Set (Line.Label, "MIN LINK");
            Line.Shown := True;
         when Max_FFT =>
            if P.Dyn_Notch_Active then
               if P.Max_FFT > 0 then
                  Append_Integer (Line.Value, P.Max_FFT, 0, False);
                  Append_String (Line.Value, "HZ");
               else
                  Set (Line.Value, "THRT<20%");
               end if;
               Set (Line.Label, "PEAK FFT");
               Line.Shown := True;
            end if;
         when Min_RSSI_Dbm =>
            Append_Integer (Line.Value, Integer_32 (S.Min_RSSI_Dbm), 3, False);
            Set (Line.Label, "MIN RSSI DBM");
            Line.Shown := True;
         when Min_RSNR =>
            Append_Integer (Line.Value, Integer_32 (S.Min_RSNR), 3, False);
            Set (Line.Label, "MIN RSNR");
            Line.Shown := True;
         when Best_3_Consec_Laps =>
            Lap_Time (P.Best_3_Consec_Ms, Line.Value);
            Set (Line.Label, "BEST 3 CON");
            Line.Shown := True;
         when Best_Lap =>
            Lap_Time (P.Best_Lap_Ms, Line.Value);
            Set (Line.Label, "BEST LAP");
            Line.Shown := True;
         when Total_Flights =>
            Append_Integer (Line.Value, Wrap32 (P.Total_Flights), 0, False);
            Set (Line.Label, "TOTAL FLIGHTS");
            Line.Shown := True;
         when Total_Time =>
            declare
               Minutes : constant Unsigned_32 := P.Total_Time_S / 60;
            begin
               Append_Integer (Line.Value, Wrap32 (Minutes / 60), 0, False);
               Append (Line.Value, ':');
               Append_Natural (Line.Value, Natural (Minutes mod 60), 2, True);
               Append (Line.Value, 'H');
            end;
            Set (Line.Label, "TOTAL FLIGHT TIME");
            Line.Shown := True;
         when Total_Dist =>
            if P.Units = Imperial then
               Append_Integer (Line.Value, Wrap32 (P.Total_Dist_M / 1_609), 0, False);
               Append (Line.Value, Symbol_Miles);
            else
               Append_Integer (Line.Value, Wrap32 (P.Total_Dist_M / 1_000), 0, False);
               Append (Line.Value, Symbol_Kilometres);
            end if;
            Set (Line.Label, "TOTAL DISTANCE");
            Line.Shown := True;
         when Full_Throttle_Time =>
            declare
               Seconds : constant Natural := Natural (P.Full_Throttle_Time_Us / 1_000_000);
            begin
               Append_Natural (Line.Value, Seconds / 60, 2, True);
               Append (Line.Value, ':');
               Append_Natural (Line.Value, Seconds mod 60, 2, True);
            end;
            Set (Line.Label, "100% THRT TIME");
            Line.Shown := True;
         when Full_Throttle_Counter =>
            Append_Integer (Line.Value, Wrap32 (P.Full_Throttle_Count), 0, False);
            Set (Line.Label, "100% THRT COUNT");
            Line.Shown := True;
         when Avg_Throttle =>
            Append_Integer (Line.Value, Integer_32 (P.Average_Throttle), 0, False);
            Set (Line.Label, "AVG THROTTLE");
            Line.Shown := True;
      end case;
   end Stat_Text;

end Adaflight.OSD_Stats;
