with Adaflight.Maths;

package body Adaflight.MSP_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   --  A reading rounded to the nearest integer with ties to even, in the
   --  sixteen bits of its field.
   function Rounded_16 (X : Float) return Unsigned_16 is
     (Unsigned_16'Mod (Adaflight.Maths.Round_Half_Even (X)))
     with Pre => abs X <= Float (Adaflight.Maths.Rounding_Bound) - 1.0;

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
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Out;
