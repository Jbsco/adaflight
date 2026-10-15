with Adaflight.Color;
with Adaflight.DShot;
with Adaflight.Maths;
with Adaflight.PWM_Output;

package body Adaflight.Config_Runtime with SPARK_Mode is

   type Output_Range is record
      Low           : Float := 0.0;
      High          : Float := 0.0;
      Disarm        : Float := 0.0;
      Deadband_High : Float := 0.0;
      Deadband_Low  : Float := 0.0;
   end record;

   --  The output range of the motor protocol's family; nothing for a
   --  disabled protocol.
   function Range_Of
     (Motor : Motor_Config_Record; Flight_3D : Flight3_D_Config_Record; Limit : Maths.Unit_Interval;
      Three_D : Boolean) return Output_Range
     with Global => null
   is
      E : Output_Range;
   begin
      if Is_DShot (Motor.Dev.Motor_Protocol) then
         DShot.Endpoints
           (Held (Integer (Motor.Motor_Idle), 0, DShot.Idle_Setting'Last), Limit, Three_D, E.Low, E.High, E.Disarm,
            E.Deadband_High, E.Deadband_Low);
      elsif Is_Analog (Motor.Dev.Motor_Protocol) then
         PWM_Output.Endpoints
           (Natural (Motor.Mincommand), Natural (Motor.Maxthrottle), Natural (Motor.Motor_Idle),
            Natural (Flight_3D.Limit3d_Low), Natural (Flight_3D.Limit3d_High), Natural (Flight_3D.Neutral3d),
            Natural (Flight_3D.Deadband3d_Low), Natural (Flight_3D.Deadband3d_High), Limit, Three_D, E.Low, E.High,
            E.Disarm, E.Deadband_High, E.Deadband_Low);
      end if;
      return E;
   end Range_Of;

   --  What the mixer setup gives: the mix and its motor count, which the
   --  configuration takes, the launch mix and the disarmed outputs.
   type Mixer_Setup is record
      Current  : Mixer.Mix_Table := (others => <>);
      Count    : Natural := 0;
      Launch   : Mixer.Mix_Table := (others => <>);
      Disarmed : Mixer.Motor_Outputs := (others => 0.0);
   end record;

   function Setup_Of
     (O : Mixer_Init.Options; Mode : Mixer_Init.Mixer_Mode; Custom_Mix : Mixer.Mix_Table;
      Disarm : Mixer.Motor_Value) return Mixer_Setup
     with Global => null, Post => Setup_Of'Result.Count <= O.Max_Motors
   is
      S : Mixer_Setup;
   begin
      Mixer_Init.Configure_Output (O, Mode, Custom_Mix, Disarm, S.Current, S.Count, S.Launch, S.Disarmed);
      return S;
   end Setup_Of;

   function Mixer_Config_Of
     (M : Mixer_Config_Record; Motor : Motor_Config_Record; Flight_3D : Flight3_D_Config_Record;
      R : Rx_Config_Record; Rate : Control_Rate_Config_Record; P : Pid_Profile_Record;
      Custom : Motor_Mixer_Record_List_8; Features : Unsigned_32; O : Mixer_Init.Options) return Mixer.Config
   is
      Mode       : constant Mixer_Init.Mixer_Mode :=
        (if M.Mixer_Mode in 1 .. Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1
         then Mixer_Init.Mixer_Mode'Val (M.Mixer_Mode - 1) else Mixer_Init.Quad_X);
      Limit      : constant Maths.Unit_Interval :=
        (if P.Motor_Output_Limit < 100 then Float (P.Motor_Output_Limit) / 100.0 else 1.0);
      E          : constant Output_Range :=
        Range_Of (Motor, Flight_3D, Limit, (Features and Config_Fix.Feature_3D) /= 0);
      High       : constant Mixer.Motor_Value := Held_F (E.High, 1.0, Mixer.Motor_Value'Last);
      Low        : constant Mixer.Motor_Value := Held_F (E.Low, 0.0, High - 1.0);
      Disarm     : constant Mixer.Motor_Value := Held_F (E.Disarm, 0.0, High);
      Custom_Mix : Mixer.Mix_Table;
   begin
      for I in Custom_Mix'Range loop
         Custom_Mix (I) :=
           (Throttle => Weight_Of (Custom (I).Throttle), Roll => Weight_Of (Custom (I).Roll),
            Pitch => Weight_Of (Custom (I).Pitch), Yaw => Weight_Of (Custom (I).Yaw));
      end loop;
      declare
         S : constant Mixer_Setup := Setup_Of (O, Mode, Custom_Mix, Disarm);
      begin
         return
           (Count                  => Natural'Max (1, S.Count),
            Table                  => S.Current,
            Kind                   =>
              Mixer.Mixer_Kind'Val (Code (M.Mixer_Type, Mixer.Mixer_Kind'Pos (Mixer.Mixer_Kind'Last))),
            Yaw_Reversed           => M.Yaw_Motors_Reversed,
            Throttle_Limit         =>
              Mixer.Throttle_Limit_Kind'Val
                (Code (Rate.Throttle_Limit_Type, Mixer.Throttle_Limit_Kind'Pos (Mixer.Throttle_Limit_Kind'Last))),
            Throttle_Limit_Percent => Held (Integer (Rate.Throttle_Limit_Percent), 25, 100),
            Output_Low             => Low,
            Output_High            => High,
            Disarm_Output          => Disarm,
            Motor_Stop             => (Features and Config_Fix.Feature_Motor_Stop) /= 0,
            Min_Check              => Held (Integer (R.Mincheck), 1000, 2000));
      end;
   end Mixer_Config_Of;

   Last_Box : constant Natural := Modes.Box'Pos (Modes.Box'Last);

   --  A stored condition: its range held to the steps, its aux channel to
   --  the channels, its logic to the two, its link to a box or none.
   function Condition_Of (M : Mode_Activation_Condition_Record) return Modes.Condition is
     (if Natural (M.Mode_Id) > Last_Box then Modes.Empty
      else
        (Mode      => Modes.Box'Val (M.Mode_Id),
         Aux       => Held (Integer (M.Aux_Channel_Index), 0, Modes.Aux_Channel_Count - 1),
         Span      => (Start_Step => Held (Integer (M.Range_Value.Start_Step), 0, Modes.Max_Range_Step),
                       End_Step   => Held (Integer (M.Range_Value.End_Step), 0, Modes.Max_Range_Step)),
         Combine   => Modes.Logic'Val (Code (M.Mode_Logic, 1)),
         Linked_To => (if Natural (M.Linked_To) > Last_Box then Modes.Arm else Modes.Box'Val (M.Linked_To))));

   function Conditions_Of (C : Mode_Activation_Condition_Record_List_20) return Modes.Conditions is
      R : Modes.Conditions;
   begin
      for I in R'Range loop
         R (I) := Condition_Of (C (I));
      end loop;
      return R;
   end Conditions_Of;

   function Flags_Of (Mask : Unsigned_32) return Beeper.Mode_Flags is
      F : Beeper.Mode_Flags;
   begin
      for S in Beeper.Sound loop
         F (S) := (Mask and Shift_Left (1, Beeper.Mode'Pos (S) - 1)) /= 0;
      end loop;
      return F;
   end Flags_Of;

   --  The stored command text: its bytes as characters, a NUL and what
   --  follows it as spaces.
   function Command_Text_Of (B : Bytes_65) return GPS_Link.Command_Text is
      T     : GPS_Link.Command_Text := (others => ' ');
      Ended : Boolean := False;
   begin
      for I in T'Range loop
         Ended := Ended or else B (I - 1) = 0;
         if not Ended then
            T (I) := Character'Val (B (I - 1));
         end if;
      end loop;
      return T;
   end Command_Text_Of;

   function Command_Length_Of (B : Bytes_65) return GPS_Link.Command_Length is
   begin
      for I in 0 .. GPS_Link.Max_Command - 1 loop
         if B (I) = 0 then
            return I;
         end if;
      end loop;
      return GPS_Link.Max_Command;
   end Command_Length_Of;

   --  The stored palette, each hue held to the circle.
   function Palette_Of (Colors : Hsv_Color_Record_List_16) return LED_Strip.Palette is
      P : LED_Strip.Palette;
   begin
      for I in P'Range loop
         P (I) := (H => Held (Integer (Colors (I).H), 0, Color.Hue'Last), S => Colors (I).S, V => Colors (I).V);
      end loop;
      return P;
   end Palette_Of;

   --  The stored mode colors, each index held to the palette.
   function Mode_Colors_Of (Modes : Mode_Color_Indexes_Record_List_6) return LED_Strip.Mode_Colors is
      M : LED_Strip.Mode_Colors := (others => (others => 0));
   begin
      for I in LED_Strip.Mode_Id loop
         for D in LED_Strip.Direction_Id loop
            M (I) (D) :=
              Held (Integer (Modes (LED_Strip.Mode_Id'Pos (I)).Color (LED_Strip.Direction_Id'Pos (D))), 0,
                    LED_Strip.Color_Index'Last);
         end loop;
      end loop;
      return M;
   end Mode_Colors_Of;

   --  The first eight stored special colors, each index held to the palette.
   function Special_Colors_Of (Specials : Special_Color_Indexes_Record) return LED_Strip.Special_Colors is
      S : LED_Strip.Special_Colors;
   begin
      for I in LED_Strip.Special_Id loop
         S (I) := Held (Integer (Specials.Color (LED_Strip.Special_Id'Pos (I))), 0, LED_Strip.Color_Index'Last);
      end loop;
      return S;
   end Special_Colors_Of;

   --  The stored statistics flags, each statistic's bit.
   function Stat_Set_Of (Mask : Unsigned_32) return OSD_Stats.Stat_Set is
      S : OSD_Stats.Stat_Set;
   begin
      for I in OSD_Stats.Stat loop
         S (I) := (Mask and Shift_Left (1, OSD_Stats.Stat'Pos (I))) /= 0;
      end loop;
      return S;
   end Stat_Set_Of;

   --  The stored warning flags, each warning's bit.
   function Warning_Set_Of (Mask : Unsigned_32) return OSD_Warnings.Warning_Set is
      W : OSD_Warnings.Warning_Set;
   begin
      for I in OSD_Warnings.Warning_Kind loop
         W (I) := (Mask and Shift_Left (1, OSD_Warnings.Warning_Kind'Pos (I))) /= 0;
      end loop;
      return W;
   end Warning_Set_Of;

   --  A stored name: its bytes as characters up to the first NUL.
   function Name_Of (B : Bytes_17) return OSD_Render.Name is
      N : OSD_Render.Name;
   begin
      for I in 1 .. OSD_Render.Max_Name loop
         exit when B (I - 1) = 0;
         N.Data (I) := Character'Val (B (I - 1));
         N.Length := I;
      end loop;
      return N;
   end Name_Of;

   function Names_Of (P : Bytes_17_List_3) return OSD_Render.Profile_Names is
      Names : OSD_Render.Profile_Names;
   begin
      for I in Names'Range loop
         Names (I) := Name_Of (P (I - 1));
      end loop;
      return Names;
   end Names_Of;

   function RC_Channels_Of (R : Integer_8_List_4) return OSD_Render.RC_Channel_Settings is
      C : OSD_Render.RC_Channel_Settings;
   begin
      for I in C'Range loop
         C (I) := Integer_8 (Held (Integer (R (I)), -1, 17));
      end loop;
      return C;
   end RC_Channels_Of;

   --  The hub's sensors, each on when its bit in the disabled mask is clear.
   function Hub_Sensors_Of (Disabled : Unsigned_32) return FrSky_Hub_Telemetry.Sensor_Set is
      S : FrSky_Hub_Telemetry.Sensor_Set;
   begin
      for I in FrSky_Hub_Telemetry.Sensor loop
         S (I) := Sensor_On (Disabled, FrSky_Hub_Telemetry.Sensor'Pos (I));
      end loop;
      return S;
   end Hub_Sensors_Of;

   function Map_Of (Rcmap : Bytes_8) return Receiver.Channel_Map is
      M : Receiver.Channel_Map;
   begin
      for I in M'Range loop
         M (I) := Held (Integer (Rcmap (I)), 0, Receiver.Channel_Count - 1);
      end loop;
      return M;
   end Map_Of;

   --  A channel range, its ends held to the pulse range, an equal pair
   --  widened by one step so that the scaling has a span.
   function Range_Of (R : Rx_Channel_Range_Config_Record) return Receiver.Range_Config is
      Low  : constant Receiver.Pulse_Us := Held (Integer (R.Min), Receiver.Pulse_Min, Receiver.Pulse_Max);
      High : constant Receiver.Pulse_Us := Held (Integer (R.Max), Receiver.Pulse_Min, Receiver.Pulse_Max);
   begin
      if Low /= High then
         return (Low => Low, High => High);
      elsif High <= Receiver.Pulse_Max - 25 then
         return (Low => Low, High => High + 25);
      else
         return (Low => Low - 25, High => High);
      end if;
   end Range_Of;

   function Ranges_Of (Ranges : Rx_Channel_Range_Config_Record_List_4) return Receiver.Range_Configs is
      C : Receiver.Range_Configs;
   begin
      for I in C'Range loop
         C (I) := Range_Of (Ranges (I));
      end loop;
      return C;
   end Ranges_Of;

   function Failsafes_Of (Failsafes : Rx_Failsafe_Channel_Config_Record_List_18) return Receiver.Failsafe_Channels is
      C : Receiver.Failsafe_Channels;
   begin
      for I in C'Range loop
         C (I) := (Mode => Receiver.Failsafe_Mode'Val (Code (Failsafes (I).Mode, 3)),
                   Step => Held (Integer (Failsafes (I).Step), 0, Receiver.Max_Failsafe_Step));
      end loop;
      return C;
   end Failsafes_Of;

   function Channels_Of (Mask : Unsigned_32) return Receiver.Channel_Set is
      C : Receiver.Channel_Set;
   begin
      for I in C'Range loop
         C (I) := (Mask and Shift_Left (1, I)) /= 0;
      end loop;
      return C;
   end Channels_Of;

end Adaflight.Config_Runtime;
