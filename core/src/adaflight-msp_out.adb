with Adaflight.Maths;

package body Adaflight.MSP_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   --  A reading rounded to the nearest integer with ties to even, in the
   --  sixteen bits of its field.
   function Rounded_16 (X : Float) return Unsigned_16 is
     (Unsigned_16'Mod (Adaflight.Maths.Round_Half_Even (X)))
     with Pre => abs X <= Float (Adaflight.Maths.Rounding_Bound) - 1.0;

   --  A rate rounded to the nearest integer with ties to even; past 2 ** 24
   --  every float is whole.
   function Rounded_Rpm (X : Rpm_Value) return Integer_32 is
     (if X < 16_777_215.0 then Integer_32 (Adaflight.Maths.Round_Half_Even (X)) else Integer_32 (X));

   function Truncated (X : Pitot_Reading) return Interfaces.Unsigned_32 is
     (Interfaces.Unsigned_32'Mod (Integer_32 (Float'Truncation (X))));

   function Saturated_8 (V : Unsigned_16) return Byte is (Byte (Unsigned_16'Min (V, 255)));

   function Saturated_MAh (V : Integer_32) return Unsigned_16 is
     (Unsigned_16 (Integer_32'Max (0, Integer_32'Min (65_535, V))));

   function Saturated_Amperage (V : Integer_32) return Unsigned_16 is
     (Unsigned_16'Mod (Integer_32'Max (-32_768, Integer_32'Min (32_767, V))));

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      case Command is
         when Status_Command | Status_Ex_Command =>
            declare
               Sensor_Bits : Unsigned_16 := 0;
               Arming_Bits : Interfaces.Unsigned_32 := 0;
               Extra       : constant Natural := Integer'Max (0, Integer'Min (15, (V.Status.Mode_Flag_Count - 25) / 8));
            begin
               for K in Sensor loop
                  if V.Status.Sensors (K) then
                     Sensor_Bits := Sensor_Bits or Interfaces.Shift_Left (1, Sensor'Pos (K));
                  end if;
               end loop;
               for R in Adaflight.Arming.Disable_Reason loop
                  if V.Status.Arming_Disabled (R) then
                     Arming_Bits := Arming_Bits or Interfaces.Shift_Left (1, Adaflight.Arming.Disable_Reason'Pos (R));
                  end if;
               end loop;
               Write_U16 (B, S, Unsigned_16'Mod (V.Status.PID_Delta_Us));
               Write_U16 (B, S, V.Status.I2C_Errors);
               Write_U16 (B, S, Sensor_Bits);
               Write_U32 (B, S, V.Status.Mode_Flags (0));
               Write_U8 (B, S, Byte (V.Status.PID_Profile));
               Write_U16 (B, S, Unsigned_16'Min (V.Status.Load_Percent, 100));
               if Command = Status_Ex_Command then
                  Write_U8 (B, S, PID_Profile_Count);
                  Write_U8 (B, S, Byte (V.Status.Rate_Profile));
               else
                  Write_U16 (B, S, 0);
               end if;
               Write_U8 (B, S, Byte (Extra));
               for I in 0 .. Extra - 1 loop
                  pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                         and then S.Next = S.Next'Loop_Entry + I);
                  Write_U8 (B, S, Byte (Interfaces.Shift_Right (V.Status.Mode_Flags (1), 8 * I) and 16#FF#));
               end loop;
               Write_U8 (B, S, Arming_Flag_Count);
               Write_U32 (B, S, Arming_Bits);
               Write_U8 (B, S, Boolean'Pos (V.Status.Reboot_Required));
               Write_U16 (B, S, Unsigned_16'Mod (V.Status.Core_Temperature));
               Write_U8 (B, S, Control_Rate_Profile_Count);
               Write_U8 (B, S, Battery_Profile_Count);
               Write_U8 (B, S, Byte (V.Status.Battery_Profile));
            end;
         when Raw_IMU_Command =>
            for I in Axis loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               Write_U16 (B, S, Rounded_16 (V.IMU.Acc (I)));
            end loop;
            for I in Axis loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               Write_U16 (B, S, Unsigned_16'Mod (V.IMU.Gyro_Dps (I)));
            end loop;
            for I in Axis loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               Write_U16 (B, S, Rounded_16 (V.IMU.Mag (I)));
            end loop;
         when Motor_Command =>
            for I in Motor_Index loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               if V.Motors.Enabled and then V.Motors.Motor_Enabled (I) then
                  Write_U16 (B, S, V.Motors.External (I));
               else
                  Write_U16 (B, S, 0);
               end if;
            end loop;
         when RC_Command =>
            for I in 0 .. V.RC.Count - 1 loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               Write_U16 (B, S, Unsigned_16 (Float'Truncation (V.RC.Channels (I))));
            end loop;
         when Attitude_Command =>
            Write_U16 (B, S, Unsigned_16'Mod (V.Attitude.Roll));
            Write_U16 (B, S, Unsigned_16'Mod (V.Attitude.Pitch));
            Write_U16 (B, S, Unsigned_16'Mod (V.Attitude.Yaw / 10));
         when Attitude_Quaternion_Command =>
            Write_U16 (B, S, Rounded_16 (V.Attitude.W * 32_767.0));
            Write_U16 (B, S, Rounded_16 (V.Attitude.X * 32_767.0));
            Write_U16 (B, S, Rounded_16 (V.Attitude.Y * 32_767.0));
            Write_U16 (B, S, Rounded_16 (V.Attitude.Z * 32_767.0));
         when Altitude_Command =>
            Write_U32 (B, S, Interfaces.Unsigned_32'Mod (V.Altitude.Estimate_Cm));
            Write_U16 (B, S, Unsigned_16'Mod (V.Altitude.Vario));
         when Sonar_Altitude_Command =>
            Write_U32 (B, S, Interfaces.Unsigned_32'Mod (V.Altitude.Rangefinder_Cm));
         when Analog_Command =>
            Write_U8 (B, S, Saturated_8 (V.Battery.Legacy_Voltage));
            Write_U16 (B, S, Saturated_MAh (V.Battery.MAh_Drawn));
            Write_U16 (B, S, V.Battery.RSSI);
            Write_U16 (B, S, Saturated_Amperage (V.Battery.Amperage));
            Write_U16 (B, S, V.Battery.Voltage);
         when Debug_Command =>
            for I in Debug_Index loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 2 * I);
               Write_U16 (B, S, Unsigned_16'Mod (V.Debug (I)));
            end loop;
         when Battery_State_Command =>
            Write_U8 (B, S, V.Battery.Cell_Count);
            Write_U16 (B, S, V.Battery.Capacity_MAh);
            Write_U8 (B, S, Saturated_8 (V.Battery.Legacy_Voltage));
            Write_U16 (B, S, Saturated_MAh (V.Battery.MAh_Drawn));
            Write_U16 (B, S, Saturated_Amperage (V.Battery.Amperage));
            Write_U8 (B, S, Adaflight.Battery.Battery_State'Pos (V.Battery.State));
            Write_U16 (B, S, V.Battery.Voltage);
         when Raw_GPS_Command =>
            Write_U8 (B, S, (if V.GPS.Fix then GPS_Fix_Flag else 0));
            Write_U8 (B, S, V.GPS.Satellite_Count);
            Write_U32 (B, S, Interfaces.Unsigned_32'Mod (V.GPS.Latitude));
            Write_U32 (B, S, Interfaces.Unsigned_32'Mod (V.GPS.Longitude));
            Write_U16 (B, S, Unsigned_16 (Integer_32'Max (0, Integer_32'Min (65_535, V.GPS.Altitude_Cm / 100))));
            Write_U16 (B, S, V.GPS.Ground_Speed);
            Write_U16 (B, S, V.GPS.Ground_Course);
            Write_U16 (B, S, V.GPS.PDOP);
            Write_U16 (B, S, V.GPS.HDOP);
            Write_U16 (B, S, V.GPS.VDOP);
            Write_U8 (B, S, V.GPS.In_View);
         when Comp_GPS_Command =>
            Write_U16 (B, S, V.GPS.Distance_To_Home);
            Write_U16 (B, S, Unsigned_16'Mod (V.GPS.Direction_To_Home / 10));
            Write_U8 (B, S, V.GPS.Update and 1);
         when GPS_SV_Info_Command =>
            Write_U8 (B, S, Byte (V.GPS.Channels));
            for I in 0 .. V.GPS.Channels - 1 loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 4 * I);
               Write_U8 (B, S, V.GPS.Satellites (I).Channel);
               Write_U8 (B, S, V.GPS.Satellites (I).Id);
               Write_U8 (B, S, V.GPS.Satellites (I).Quality);
               Write_U8 (B, S, V.GPS.Satellites (I).Signal);
            end loop;
         when ESC_Sensor_Data_Command =>
            if V.ESC.ESC_Sensor then
               Write_U8 (B, S, Byte (V.ESC.Count));
               for I in 0 .. V.ESC.Count - 1 loop
                  pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                         and then S.Next = S.Next'Loop_Entry + 3 * I);
                  Write_U8 (B, S, V.ESC.Motors (I).ESC_Temperature);
                  Write_U16 (B, S, Unsigned_16'Mod (V.ESC.Motors (I).ESC_Erpm));
               end loop;
            elsif V.ESC.DShot_Telemetry then
               Write_U8 (B, S, Byte (V.ESC.Count));
               for I in 0 .. V.ESC.Count - 1 loop
                  pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                         and then S.Next = S.Next'Loop_Entry + 3 * I);
                  Write_U8 (B, S, Byte'Mod (V.ESC.Motors (I).Temperature));
                  Write_U16 (B, S, Unsigned_16'Mod (Rounded_Rpm (V.ESC.Motors (I).DShot_Rpm)));
               end loop;
            end if;
         when Motor_Telemetry_Command =>
            Write_U8 (B, S, Byte (V.ESC.Count));
            for I in 0 .. V.ESC.Count - 1 loop
               pragma Loop_Invariant (Fits (S, B) and then S.Last = S.Last'Loop_Entry
                                      and then S.Next = S.Next'Loop_Entry + 13 * I);
               declare
                  M           : Motor_Telemetry renames V.ESC.Motors (I);
                  Rpm         : Integer_32 := 0;
                  Have_Rpm    : Boolean := False;
                  Invalid     : Integer_16 := 0;
                  Temperature : Byte := 0;
                  Voltage     : Unsigned_16 := 0;
                  Current     : Unsigned_16 := 0;
                  Consumption : Unsigned_16 := 0;
               begin
                  if V.ESC.DShot_Telemetry then
                     Rpm := Rounded_Rpm (M.DShot_Rpm);
                     Have_Rpm := True;
                     Invalid := (if M.DShot_Active then M.Invalid_Percent else 10_000);
                     if (M.Kinds and 16#FE#) /= 0 then
                        if (M.Kinds and 2) /= 0 then
                           Temperature := Byte'Mod (M.Temperature);
                        end if;
                        if (M.Kinds and 8) /= 0 then
                           Current := M.Current;
                        end if;
                        if (M.Kinds and 4) /= 0 then
                           Voltage := M.Voltage / 4;
                        end if;
                     end if;
                  end if;
                  if V.ESC.ESC_Sensor then
                     if not Have_Rpm then
                        Rpm := Rounded_Rpm (M.ESC_Rpm);
                        Have_Rpm := True;
                     end if;
                     Temperature := M.ESC_Temperature;
                     Voltage := M.ESC_Voltage;
                     Current := Unsigned_16'Mod (M.ESC_Current);
                     Consumption := Unsigned_16'Mod (M.ESC_Consumption);
                  end if;
                  Write_U32 (B, S, (if Have_Rpm then Interfaces.Unsigned_32'Mod (Rpm) else 0));
                  Write_U16 (B, S, Unsigned_16'Mod (Invalid));
                  Write_U8 (B, S, Temperature);
                  Write_U16 (B, S, Voltage);
                  Write_U16 (B, S, Current);
                  Write_U16 (B, S, Consumption);
               end;
            end loop;
         when Pitot_Command =>
            Write_U32 (B, S, Truncated (V.Pitot.Airspeed));
            Write_U32 (B, S, Truncated (V.Pitot.Diff_Pressure));
         when TX_Info_Command =>
            Write_U8 (B, S, Adaflight.Receiver.RSSI_Source'Pos (V.RSSI_Source));
            Write_U8 (B, S, Boolean'Pos (V.Clock.Valid));
         when RTC_Command =>
            if V.Clock.Valid then
               Write_U16 (B, S, V.Clock.Year);
               Write_U8 (B, S, V.Clock.Month);
               Write_U8 (B, S, V.Clock.Day);
               Write_U8 (B, S, V.Clock.Hours);
               Write_U8 (B, S, V.Clock.Minutes);
               Write_U8 (B, S, V.Clock.Seconds);
               Write_U16 (B, S, V.Clock.Millis);
            end if;
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Out;
