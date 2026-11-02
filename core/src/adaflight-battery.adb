with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Clock;

package body Adaflight.Battery with SPARK_Mode is

   Full_Scale               : constant := 4_095;
   Voltage_Task_Hz          : constant Float := 50.0;
   Fast_Voltage_Task_Hz     : constant Float := 200.0;
   Current_Task_Hz          : constant Float := 50.0;
   Stable_Tick_Ms           : constant := 100;
   Stable_Max_Delta         : constant := 10;
   Stable_Bits_Total        : constant := 11;
   Stable_Bits_Threshold    : constant := 10;
   Max_Auto_Detect_Cells    : constant := 8;
   LVC_Affect_Time_Us       : constant := 10_000_000;
   ESC_Age_Max              : constant := 10;
   MSP_Request_Period_Us    : constant := 100_000;

   --  The whole part of a throttle in thousandths, shared by the rounding
   --  below and its postcondition.
   function Whole_Part (X : Float) return Natural is (Natural (Float'Truncation (X)))
     with Pre => X in 0.0 .. 1_000.0;

   --  The nearest whole number with a tie going to the even one, as the C
   --  library rounds in its default mode.
   function Round_To_Even (X : Float) return Natural
     with Pre  => X in 0.0 .. 1_000.0,
          Post => Round_To_Even'Result in Whole_Part (X) .. Whole_Part (X) + 1
   is
      Base     : constant Natural := Whole_Part (X);
      Fraction : constant Float := X - Float'Truncation (X);
   begin
      if Fraction > 0.5 or else (Fraction = 0.5 and then Base mod 2 = 1) then
         return Base + 1;
      else
         return Base;
      end if;
   end Round_To_Even;

   --  The cutoff of a battery filter from its period in tenths of a second.
   function Period_Cutoff (Period : Positive) return Float is
     (1.0 / (Float (Period) / 10.0));

   --  A filtered analog sample back to a count, as the reference truncates it.
   function To_Count (Filtered : Signal) return ADC_Count is
     (Natural (Float'Truncation (Float'Max (0.0, Float'Min (Float (Full_Scale), Filtered)))));

   --  A count at the supply through the divider to hundredths of a volt, in
   --  the reference's 32-bit unsigned arithmetic, kept to the 16-bit field
   --  it stores into.
   function Count_To_Centivolts (Count : ADC_Count; C : Settings; Supply_Mv : Supply_Millivolts) return Centivolts is
      Scaled : constant Unsigned_32 :=
        Unsigned_32 (Count) * Unsigned_32 (C.Voltage_Scale) * Unsigned_32 (Supply_Mv) / 10 + Full_Scale * 5;
      Divided : constant Unsigned_32 :=
        Scaled / (Full_Scale * Unsigned_32 (C.Voltage_Divider)) / Unsigned_32 (C.Voltage_Multiplier);
   begin
      return Centivolts (Divided mod 65_536);
   end Count_To_Centivolts;

   --  A count at the supply through the current sensor's scale and offset to
   --  hundredths of an ampere, in the reference's 32-bit arithmetic.
   function Count_To_Millivolts (Count : ADC_Count; Supply_Mv : Supply_Millivolts) return Sensor_Millivolts is
     (Integer_32 (Unsigned_32 (Count) * Unsigned_32 (Supply_Mv) / 4_096));

   function Count_To_Centiamps (Count : ADC_Count; C : Settings; Supply_Mv : Supply_Millivolts) return Centiamps is
      Millivolts : constant Sensor_Millivolts := Count_To_Millivolts (Count, Supply_Mv);
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
      if C.Voltage_Meter in Analog | ESC then
         Filters.PT1_Init
           (S.Display_Filter,
            Filters.PT1_Gain
              (Period_Cutoff (C.Display_Filter_Period),
               1.0 / (if C.Sag_Compensation then Fast_Voltage_Task_Hz else Voltage_Task_Hz)));
      end if;
      if C.Voltage_Meter = Analog and then C.Sag_Compensation then
         Filters.PT1_Init
           (S.Sag_Filter, Filters.PT1_Gain (Period_Cutoff (C.Sag_Filter_Period), 1.0 / Fast_Voltage_Task_Hz));
      end if;
      if C.Current_Meter = Analog then
         Filters.PT1_Init (S.Current_Filter,
                           Filters.PT1_Gain (Period_Cutoff (C.Current_Filter_Period), 1.0 / Current_Task_Hz));
      end if;
   end Init;

   --------------------
   -- Update_Voltage --
   --------------------

   procedure Update_Voltage (S : in out State; C : Settings; Raw : ADC_Count; Now_Ms : Time_Ms;
                             Meters : Meter_Inputs := No_Meters)
   is
   begin
      case C.Voltage_Meter is
         when Analog =>
            declare
               Filtered : Signal;
               Sag      : Signal;
            begin
               Filters.PT1_Apply (S.Display_Filter, Float (Raw), Filtered);
               S.Voltage.Display_Filtered := Count_To_Centivolts (To_Count (Filtered), C, Meters.Supply_Mv);
               S.Voltage.Unfiltered := Count_To_Centivolts (Raw, C, Meters.Supply_Mv);
               if C.Sag_Compensation then
                  Filters.PT1_Apply (S.Sag_Filter, Float (Raw), Sag);
                  S.Voltage.Sag_Filtered := Count_To_Centivolts (To_Count (Sag), C, Meters.Supply_Mv);
               end if;
            end;
         when ESC =>
            if Meters.ESC_Sensor then
               declare
                  Unfiltered : constant Centivolts :=
                    (if Meters.ESC.Data_Age <= ESC_Age_Max then Meters.ESC.Voltage else 0);
                  Filtered   : Signal;
               begin
                  Filters.PT1_Apply (S.Display_Filter, Float (Unfiltered), Filtered);
                  S.Voltage.Display_Filtered :=
                    Centivolts (Float'Truncation (Float'Max (0.0, Float'Min (Float (Centivolts'Last), Filtered))));
                  S.Voltage.Unfiltered := Unfiltered;
               end;
            end if;
         when None =>
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
      S.Taps.Voltage_Updated := True;
      S.Taps.Voltage_State_Seen := S.Voltage_State;
   end Update_Voltage;

   --------------------
   -- Update_Current --
   --------------------

   procedure Update_Current (S : in out State; C : Settings; Raw : ADC_Count; Now_Us : Time_Us;
                             Meters : Meter_Inputs := No_Meters)
   is
      --  The charge of the latest current over the time since the last call,
      --  in a 64-bit product (DESIGN.md D6).
      procedure Accumulate (Latest : Centiamps; Since_Last : Integer_32) is
         Product : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (Latest) * Interfaces.Integer_64 (Since_Last);
         Drawn   : constant Float := S.Current.mAh_Drawn_F + Float (Product) / (100.0 * 1_000.0 * 3_600.0);
      begin
         S.Current.mAh_Drawn_F := Float'Max (-2.0 ** 30, Float'Min (2.0 ** 30, Drawn));
         S.Current.mAh_Drawn := Charge_mAh (Float'Truncation (S.Current.mAh_Drawn_F));
      end Accumulate;
   begin
      S.MSP_Request := False;
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
                  Latest   : constant Centiamps := Count_To_Centiamps (Raw, C, Meters.Supply_Mv);
               begin
                  Filters.PT1_Apply (S.Current_Filter, Float (Raw), Filtered);
                  S.Current.Amperage_Latest := Latest;
                  S.Current.Amperage := Count_To_Centiamps (To_Count (Filtered), C, Meters.Supply_Mv);
                  S.Taps.ADC_Current := True;
                  S.Taps.Sensor_Millivolts := Count_To_Millivolts (To_Count (Filtered), Meters.Supply_Mv);
                  S.Taps.Sensor_Centiamps := S.Current.Amperage;
                  Accumulate (Latest, Since_Last);
                  S.Taps.Sensor_Latest := Latest;
                  S.Taps.Sensor_Drawn := S.Current.mAh_Drawn;
               end;
            when Virtual =>
               declare
                  Amperage : Centiamps := Integer_32 (C.Virtual_Offset);
               begin
                  if Meters.Armed then
                     declare
                        subtype Throttle_Offset is Natural range 0 .. 1_001;
                        subtype Throttle_Factor is Integer_32 range 0 .. 21_041;
                        Offset : constant Throttle_Offset :=
                          (if Meters.Throttle_Low and then Meters.Motor_Stop then 0
                           else Round_To_Even (Meters.Throttle * 1_000.0));
                        Factor : constant Throttle_Factor := Integer_32 (Offset + Offset * Offset / 50);
                     begin
                        Amperage := Amperage + Factor * Integer_32 (C.Virtual_Scale) / 1_000;
                     end;
                  end if;
                  S.Current.Amperage_Latest := Amperage;
                  S.Current.Amperage := Amperage;
                  Accumulate (Amperage, Since_Last);
               end;
            when ESC =>
               if Meters.ESC_Sensor then
                  if Meters.ESC.Data_Age <= ESC_Age_Max then
                     declare
                        --  The offset's charge from the 32-bit unsigned product
                        --  of the offset and the clock (DESIGN.md D136).
                        Product  : constant Unsigned_32 := Unsigned_32 (C.ESC_Current_Offset) * Meters.Now_Ms;
                        Share    : constant Float range 0.0 .. 1_200.0 := Float (Product) / (1_000.0 * 3_600.0);
                        Consumed : constant Float range -2.0 ** 23 .. 2.0 ** 23 := Float (Meters.ESC.Consumption);
                        Drawn    : constant Float range -2.0 ** 24 .. 2.0 ** 24 := Consumed + Share;
                     begin
                        S.Current.Amperage := Meters.ESC.Current + Integer_32 (C.ESC_Current_Offset / 10);
                        S.Current.Amperage_Latest := S.Current.Amperage;
                        S.Current.mAh_Drawn := Charge_mAh (Float'Truncation (Drawn));
                     end;
                  else
                     S.Current.Amperage := 0;
                     S.Current.Amperage_Latest := 0;
                     S.Current.mAh_Drawn := 0;
                  end if;
               end if;
            when MSP =>
               if Clock.Elapsed (Now_Us, S.MSP_Request_At) > 0 then
                  S.MSP_Request_At := Now_Us + MSP_Request_Period_Us;
                  S.MSP_Request := True;
               end if;
               S.Current.Amperage_Latest := Integer_32 (S.MSP_Amperage);
               S.Current.Amperage := Integer_32 (S.MSP_Amperage);
               S.Current.mAh_Drawn := Integer_32 (S.MSP_mAh);
            when None =>
               S.Current := (Amperage => 0, Amperage_Latest => 0, mAh_Drawn => 0, mAh_Drawn_F => S.Current.mAh_Drawn_F);
         end case;
      end;
   end Update_Current;

   ---------------------
   -- Set_MSP_Current --
   ---------------------

   procedure Set_MSP_Current (S : in out State; Amperage : Unsigned_16; mAh : Unsigned_16) is
   begin
      S.MSP_Amperage := Amperage;
      S.MSP_mAh := mAh;
   end Set_MSP_Current;

   ---------------------
   -- Update_Presence --
   ---------------------

   procedure Update_Presence (S : in out State; C : Settings; Events : out Presence_Events) is
      Stable : constant Boolean := Voltage_Is_Stable (S);
   begin
      Events := (others => <>);
      if (S.Voltage_State = Not_Present or else S.Voltage_State = Init)
        and then Voltage_From_Battery (S, C) and then Stable
      then
         S.Voltage_State := OK;
         S.Consumption_State := OK;
         if C.Force_Cell_Count /= 0 then
            S.Cells := C.Force_Cell_Count;
         else
            S.Cells := Natural'Min (S.Voltage.Display_Filtered / C.Max_Cell_Voltage + 1, Max_Auto_Detect_Cells);
            Events.Detected_Cells := S.Cells;
         end if;
         Events.Connected := True;
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
