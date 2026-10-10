with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Clock;

package body Adaflight.Battery with SPARK_Mode is

   Reference_Millivolts     : constant := 3_300;
   Full_Scale               : constant := 4_095;
   Voltage_Task_Hz          : constant Float := 50.0;
   Current_Task_Hz          : constant Float := 50.0;
   Stable_Tick_Ms           : constant := 100;
   Stable_Max_Delta         : constant := 10;
   Stable_Bits_Total        : constant := 11;
   Stable_Bits_Threshold    : constant := 10;
   Max_Auto_Detect_Cells    : constant := 8;
   LVC_Affect_Time_Us       : constant := 10_000_000;

   --  The cutoff of a battery filter from its period in tenths of a second.
   function Period_Cutoff (Period : Positive) return Float is
     (1.0 / (Float (Period) / 10.0));

   --  A filtered analog sample back to a count, as the reference truncates it.
   function To_Count (Filtered : Signal) return ADC_Count is
     (Natural (Float'Truncation (Float'Max (0.0, Float'Min (Float (Full_Scale), Filtered)))));

   --  A count through the divider to hundredths of a volt, in the reference's
   --  32-bit unsigned arithmetic, kept to the 16-bit field it stores into.
   function Count_To_Centivolts (Count : ADC_Count; C : Settings) return Centivolts is
      Scaled : constant Unsigned_32 :=
        Unsigned_32 (Count) * Unsigned_32 (C.Voltage_Scale) * Reference_Millivolts / 10 + Full_Scale * 5;
      Divided : constant Unsigned_32 :=
        Scaled / (Full_Scale * Unsigned_32 (C.Voltage_Divider)) / Unsigned_32 (C.Voltage_Multiplier);
   begin
      return Centivolts (Divided mod 65_536);
   end Count_To_Centivolts;

   --  A count through the current sensor's scale and offset to hundredths of
   --  an ampere, in the reference's 32-bit arithmetic.
   function Count_To_Centiamps (Count : ADC_Count; C : Settings) return Centiamps is
      Millivolts : constant Integer_32 := Integer_32 (Count) * Reference_Millivolts / 4_096;
   begin
      if C.Current_Scale = 0 then
         return 0;
      end if;
      return (Millivolts * 10_000 / Integer_32 (C.Current_Scale) + Integer_32 (C.Current_Offset)) / 10;
   end Count_To_Centiamps;

   function Voltage_Is_Stable (S : State) return Boolean is
      Window : constant Unsigned_16 := S.Voltage.Stable_Bits and (2 ** (Stable_Bits_Total + 1) - 1);
      Count  : Natural := 0;
   begin
      for Bit in 0 .. Stable_Bits_Total loop
         pragma Loop_Invariant (Count <= Bit);
         if (Window and 2 ** Bit) /= 0 then
            Count := Count + 1;
         end if;
      end loop;
      return Count >= Stable_Bits_Threshold;
   end Voltage_Is_Stable;

   function Voltage_From_Battery (S : State; C : Settings) return Boolean is
     ((S.Voltage.Display_Filtered >= C.Not_Present_Cell_Voltage
       and then S.Voltage.Display_Filtered <= C.Max_Cell_Voltage)
      or else S.Voltage.Display_Filtered > C.Not_Present_Cell_Voltage * 2);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings) is
   begin
      S := (others => <>);
      if C.Voltage_Meter = Analog then
         Filters.PT1_Init (S.Display_Filter,
                           Filters.PT1_Gain (Period_Cutoff (C.Display_Filter_Period), 1.0 / Voltage_Task_Hz));
      end if;
      if C.Current_Meter = Analog then
         Filters.PT1_Init (S.Current_Filter,
                           Filters.PT1_Gain (Period_Cutoff (C.Current_Filter_Period), 1.0 / Current_Task_Hz));
      end if;
   end Init;

   --------------------
   -- Update_Voltage --
   --------------------

   procedure Update_Voltage (S : in out State; C : Settings; Raw : ADC_Count; Now_Ms : Time_Ms) is
   begin
      case C.Voltage_Meter is
         when Analog =>
            declare
               Filtered : Signal;
            begin
               Filters.PT1_Apply (S.Display_Filter, Float (Raw), Filtered);
               S.Voltage.Display_Filtered := Count_To_Centivolts (To_Count (Filtered), C);
               S.Voltage.Unfiltered := Count_To_Centivolts (Raw, C);
            end;
         when None | ESC =>
            S.Voltage := (others => <>);
      end case;
      --  The stability record: a jump beyond the delta clears the current
      --  period's bit and resets the reference, and each period shifts in a
      --  stable bit.
      if abs (Integer (S.Voltage.Stable_Prev_Filtered) - Integer (S.Voltage.Display_Filtered)) > Stable_Max_Delta then
         S.Voltage.Stable_Prev_Filtered := S.Voltage.Display_Filtered;
         S.Voltage.Stable_Bits := S.Voltage.Stable_Bits and not 1;
      end if;
      if Clock.Elapsed (Now_Ms, S.Voltage.Stable_Last_Update) >= Stable_Tick_Ms then
         S.Voltage.Stable_Bits := Interfaces.Shift_Left (S.Voltage.Stable_Bits, 1) or 1;
         S.Voltage.Stable_Last_Update := Now_Ms;
      end if;
   end Update_Voltage;

   --------------------
   -- Update_Current --
   --------------------

   procedure Update_Current (S : in out State; C : Settings; Raw : ADC_Count; Now_Us : Time_Us) is
   begin
      if S.Cells = 0 then
         S.Current := (Amperage => 0, Amperage_Latest => 0, mAh_Drawn => 0, mAh_Drawn_F => S.Current.mAh_Drawn_F);
         return;
      end if;
      declare
         Since_Last : constant Integer_32 := Clock.Elapsed (Now_Us, S.Current_Serviced_Us);
      begin
         S.Current_Serviced_Us := Now_Us;
         case C.Current_Meter is
            when Analog =>
               declare
                  Filtered : Signal;
                  Latest   : constant Centiamps := Count_To_Centiamps (Raw, C);
                  Product  : constant Interfaces.Integer_64 :=
                    Interfaces.Integer_64 (Latest) * Interfaces.Integer_64 (Since_Last);
                  Drawn    : constant Float :=
                    S.Current.mAh_Drawn_F + Float (Product) / (100.0 * 1_000.0 * 3_600.0);
               begin
                  Filters.PT1_Apply (S.Current_Filter, Float (Raw), Filtered);
                  S.Current.Amperage_Latest := Latest;
                  S.Current.Amperage := Count_To_Centiamps (To_Count (Filtered), C);
                  S.Current.mAh_Drawn_F := Float'Max (-2.0 ** 30, Float'Min (2.0 ** 30, Drawn));
                  S.Current.mAh_Drawn := Charge_mAh (Float'Truncation (S.Current.mAh_Drawn_F));
               end;
            when None | Virtual | ESC | MSP =>
               S.Current := (Amperage => 0, Amperage_Latest => 0, mAh_Drawn => 0, mAh_Drawn_F => S.Current.mAh_Drawn_F);
         end case;
      end;
   end Update_Current;

   ---------------------
   -- Update_Presence --
   ---------------------

   procedure Update_Presence (S : in out State; C : Settings) is
      Stable : constant Boolean := Voltage_Is_Stable (S);
   begin
      if (S.Voltage_State = Not_Present or else S.Voltage_State = Init)
        and then Voltage_From_Battery (S, C) and then Stable
      then
         S.Voltage_State := OK;
         S.Consumption_State := OK;
         if C.Force_Cell_Count /= 0 then
            S.Cells := C.Force_Cell_Count;
         else
            S.Cells := Natural'Min (S.Voltage.Display_Filtered / C.Max_Cell_Voltage + 1, Max_Auto_Detect_Cells);
         end if;
         declare
            Warning_V  : constant Unsigned_16 := Unsigned_16 (S.Cells) * Unsigned_16 (C.Warning_Cell_Voltage);
            Critical_V : constant Unsigned_16 := Unsigned_16 (S.Cells) * Unsigned_16 (C.Min_Cell_Voltage);
            Hysteresis : constant Unsigned_16 := Unsigned_16 (C.Hysteresis);
         begin
            S.Warning_Voltage := Centivolts (Warning_V);
            S.Critical_Voltage := Centivolts (Critical_V);
            S.Warning_Hysteresis := (if Warning_V > Hysteresis then Centivolts (Warning_V - Hysteresis) else 0);
            S.Critical_Hysteresis := (if Critical_V > Hysteresis then Centivolts (Critical_V - Hysteresis) else 0);
         end;
         S.LVC_Percentage := 100;
         S.LVC_Start_Us := 0;
      elsif S.Voltage_State /= Not_Present and then Stable and then not Voltage_From_Battery (S, C) then
         S.Voltage_State := Not_Present;
         S.Consumption_State := Not_Present;
         S.Cells := 0;
         S.Warning_Voltage := 0;
         S.Critical_Voltage := 0;
         S.Warning_Hysteresis := 0;
         S.Critical_Hysteresis := 0;
         S.Watt_Hours := 0.0;
      end if;
   end Update_Presence;

   --------------------------
   -- Percentage_Remaining --
   --------------------------

   function Percentage_Remaining (S : State; C : Settings) return Percent is
   begin
      if S.Cells = 0 then
         return 0;
      end if;
      if C.Capacity_mAh > 0 then
         declare
            Fraction : constant Float :=
              (Float (C.Capacity_mAh) - Float (S.Current.mAh_Drawn)) * 100.0 / Float (C.Capacity_mAh);
            Whole    : constant Float := Float'Truncation (Float'Max (-1.0e9, Float'Min (1.0e9, Fraction)));
            Counted  : constant Integer := Integer (Whole);
         begin
            return Percent (Integer'Max (0, Integer'Min (100, Counted)));
         end;
      end if;
      declare
         Voltage : constant Natural := S.Voltage.Display_Filtered;
         Low     : constant Natural := C.Min_Cell_Voltage * S.Cells;
         High    : constant Natural := C.Max_Cell_Voltage * S.Cells;
      begin
         if Voltage <= Low then
            return 0;
         elsif Voltage >= High then
            return 100;
         elsif High > Low then
            return (Voltage - Low) * 100 / (High - Low);
         else
            return 0;
         end if;
      end;
   end Percentage_Remaining;

   -------------------
   -- Update_States --
   -------------------

   procedure Update_States (S : in out State; C : Settings; Now_Us : Time_Us; Now_Ms : Time_Ms) is
   begin
      --  The voltage state with its hysteresis and durations.
      case S.Voltage_State is
         when OK =>
            if S.Voltage.Display_Filtered <= S.Warning_Hysteresis then
               if Clock.Elapsed (Now_Ms, S.Last_Voltage_Change_Ms) >= Integer_32 (C.Duration_For_Warning) * 100 then
                  S.Voltage_State := Warning;
               end if;
            else
               S.Last_Voltage_Change_Ms := Now_Ms;
            end if;
         when Warning =>
            if S.Voltage.Display_Filtered <= S.Critical_Hysteresis then
               if Clock.Elapsed (Now_Ms, S.Last_Voltage_Change_Ms) >= Integer_32 (C.Duration_For_Critical) * 100 then
                  S.Voltage_State := Critical;
               end if;
            else
               if S.Voltage.Display_Filtered > S.Warning_Voltage then
                  S.Voltage_State := OK;
               end if;
               S.Last_Voltage_Change_Ms := Now_Ms;
            end if;
         when Critical =>
            if S.Voltage.Display_Filtered > S.Critical_Voltage then
               S.Voltage_State := Warning;
               S.Last_Voltage_Change_Ms := Now_Ms;
            end if;
         when Not_Present | Init =>
            null;
      end case;
      --  The consumption state from the remaining percentage.
      if C.Consumption_Alerts and then C.Capacity_mAh > 0 and then S.Cells > 0 then
         declare
            Remaining : constant Percent := Percentage_Remaining (S, C);
         begin
            if Remaining = 0 then
               S.Consumption_State := Critical;
            elsif Remaining <= C.Consumption_Warning_Percentage then
               S.Consumption_State := Warning;
            else
               S.Consumption_State := OK;
            end if;
         end;
      end if;
      --  The low voltage cutoff ramps the throttle limit over ten seconds.
      if C.LVC_Percentage < 100 then
         if S.Voltage_State = Critical and then not S.LVC_Enabled then
            S.LVC_Enabled := True;
            S.LVC_Start_Us := Now_Us;
            S.LVC_Percentage := 100;
         end if;
         if S.LVC_Enabled then
            declare
               Since : constant Integer_32 := Clock.Elapsed (Now_Us, S.LVC_Start_Us);
            begin
               if Since < LVC_Affect_Time_Us then
                  --  Held to the percent range, which the reference's byte leaves
                  --  only when the clock wraps during the ramp.
                  S.LVC_Percentage :=
                    Percent (Interfaces.Integer_64'Max (0, Interfaces.Integer_64'Min (100,
                      100 - Interfaces.Integer_64 (Since) * Interfaces.Integer_64 (100 - C.LVC_Percentage)
                            / LVC_Affect_Time_Us)));
               else
                  S.LVC_Percentage := C.LVC_Percentage;
               end if;
            end;
         end if;
      end if;
      S.Overall := Battery_State'Max (S.Voltage_State, S.Consumption_State);
      --  The energy drawn since the last call, from the filtered voltage.
      declare
         Delta_mAh : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (S.Current.mAh_Drawn) - Interfaces.Integer_64 (S.mAh_Previous);
         Product   : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (S.Voltage.Display_Filtered) * Delta_mAh;
         Energy    : constant Float := S.Watt_Hours + Float (Product) / 100_000.0;
      begin
         S.Watt_Hours := Float'Max (-1.0e9, Float'Min (1.0e9, Energy));
         S.mAh_Previous := S.Current.mAh_Drawn;
      end;
   end Update_States;

   -----------
   -- Alarm --
   -----------

   function Alarm (S : State; C : Settings) return Alert is
   begin
      if not C.Voltage_Alerts then
         return Silence;
      end if;
      case S.Overall is
         when Warning => return Low;
         when Critical => return Critical_Low;
         when OK | Not_Present | Init => return Silence;
      end case;
   end Alarm;

end Adaflight.Battery;
