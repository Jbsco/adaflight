package body Adaflight.MSP_Hardware_Out with SPARK_Mode is
   use Adaflight.Stream_Buffers;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   function Word (V : Integer_16) return Unsigned_16 is (Unsigned_16 (Interfaces.Integer_32 (V) mod 65_536));

   function Flag (V : Boolean) return Unsigned_8 is (Boolean'Pos (V));

   procedure GPS_Rescue (B : in out Byte_Array; S : in out Stream; R : Rescue_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 26 and then S.Last = S.Last'Old
   is
   begin
      Write_U16 (B, S, Unsigned_16 (R.Max_Angle));
      Write_U16 (B, S, R.Return_Altitude_M);
      Write_U16 (B, S, R.Descent_Distance_M);
      Write_U16 (B, S, R.Ground_Speed_Cm_S);
      Write_U16 (B, S, R.Throttle_Min);
      Write_U16 (B, S, R.Throttle_Max);
      Write_U16 (B, S, R.Hover_Throttle);
      Write_U8 (B, S, R.Sanity_Checks);
      Write_U8 (B, S, R.Min_Sats);
      Write_U16 (B, S, R.Ascend_Rate);
      Write_U16 (B, S, R.Descend_Rate);
      Write_U8 (B, S, R.Allow_Arming_Without_Fix);
      Write_U8 (B, S, R.Altitude_Mode);
      Write_U16 (B, S, R.Min_Start_Dist_M);
      Write_U16 (B, S, R.Initial_Climb_M);
   end GPS_Rescue;

   procedure SD_Card_Summary (B : in out Byte_Array; S : in out Stream; C : SD_Card_Values)
     with Pre  => Fits (S, B) and then Remaining (S) >= Max_Reply_Length,
          Post => S.Next = S.Next'Old + 11 and then S.Last = S.Last'Old
   is
      Not_Present : constant := 0;
      Fatal_State : constant := 1;
      Card_Init   : constant := 2;
      FS_Init     : constant := 3;
      Ready_State : constant := 4;
      Flags       : Unsigned_8 := 0;
      State       : Unsigned_8 := 0;
      Last_Error  : Unsigned_8 := 0;
      Free_Space  : Unsigned_32 := 0;
      Total_Space : Unsigned_32 := 0;
   begin
      if C.Built and then C.Configured then
         Flags := 1;
         if not C.Inserted then
            State := Not_Present;
         elsif not C.Functional then
            State := Fatal_State;
         else
            case C.State is
               when Ready =>
                  State := Ready_State;
               when Initialization =>
                  State := (if C.Initialized then FS_Init else Card_Init);
               when Fatal | Unknown =>
                  State := Fatal_State;
            end case;
         end if;
         Last_Error := C.Last_Error;
         if State = Ready_State then
            Free_Space := C.Free_Bytes / 1_024;
            Total_Space := C.Block_Count / 2;
         end if;
      end if;
      Write_U8 (B, S, Flags);
      Write_U8 (B, S, State);
      Write_U8 (B, S, Last_Error);
      Write_U32 (B, S, Free_Space);
      Write_U32 (B, S, Total_Space);
   end SD_Card_Summary;

   -----------
   -- Reply --
   -----------

   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot) is
   begin
      if not Supported (Command, V) then
         return;
      end if;
      case Command is
         when Mixer_Config_Command =>
            Write_U8 (B, S, V.Mixer_Mode);
            Write_U8 (B, S, Flag (V.Yaw_Reversed));
         when Motor_Config_Command =>
            Write_U16 (B, S, 0);
            Write_U16 (B, S, V.Motor.Max_Throttle);
            Write_U16 (B, S, V.Motor.Min_Command);
            Write_U8 (B, S, V.Motor.Motor_Count);
            Write_U8 (B, S, V.Motor.Pole_Count);
            Write_U8 (B, S, Flag (V.Motor.DShot_Telemetry and then V.Motor.Use_DShot_Telemetry));
            Write_U8 (B, S, Flag (V.Motor.ESC_Sensor and then V.Motor.ESC_Sensor_Feature));
            Write_U16 (B, S, V.Motor.KV);
         when Compass_Config_Command =>
            Write_U16 (B, S, Word (V.Mag_Declination));
         when GPS_Config_Command =>
            Write_U8 (B, S, V.GPS_Provider);
            Write_U8 (B, S, V.SBAS_Mode);
            Write_U8 (B, S, V.Auto_Config);
            Write_U8 (B, S, V.Auto_Baud);
            Write_U8 (B, S, Flag (V.Set_Home_Once));
            Write_U8 (B, S, Flag (V.Use_Galileo));
         when GPS_Rescue_Command =>
            GPS_Rescue (B, S, V.Rescue_Settings);
         when GPS_Rescue_PIDs_Command =>
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Altitude_P));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Altitude_I));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Altitude_D));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Position_P));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Position_I));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Position_D));
            Write_U16 (B, S, Unsigned_16 (V.Rescue_Settings.Yaw_P));
         when Acc_Trim_Command =>
            Write_U16 (B, S, Word (V.Trim_Pitch));
            Write_U16 (B, S, Word (V.Trim_Roll));
         when Blackbox_Config_Command =>
            if V.Blackbox.Built then
               Write_U8 (B, S, 1);
               Write_U8 (B, S, V.Blackbox.Device);
               Write_U8 (B, S, 1);
               Write_U8 (B, S, V.Blackbox.Rate_Denom);
               Write_U16 (B, S, V.Blackbox.P_Ratio);
               Write_U8 (B, S, V.Blackbox.Sample_Rate);
               Write_U32 (B, S, V.Blackbox.Fields_Disabled);
            else
               Fill (B, S, 0, 11);
            end if;
         when Sensor_Config_Command =>
            for Which in Acc .. Pitot loop
               Write_U8 (B, S, (if V.Built (Which) then V.Selected (Which) else None_Selection (Which)));
            end loop;
         when Sensor_Config_Active_Command =>
            for Which in Sensor loop
               Write_U8 (B, S, (if V.Built (Which) then V.Detected (Which) else 16#FF#));
            end loop;
         when Gyro_Sensor_Active_Command =>
            if V.Built (Gyro) then
               Write_U8 (B, S, Unsigned_8 (V.Gyro_Count));
               for I in 1 .. V.Gyro_Count loop
                  Write_U8 (B, S, V.Detected_Gyros (I));
               end loop;
            end if;
         when Dataflash_Summary_Command =>
            if V.Flash.Built and then V.Flash.Supported then
               Write_U8 (B, S, 2 + Flag (V.Flash.Ready));
               Write_U32 (B, S, Unsigned_32 ((Interfaces.Integer_64 (V.Flash.End_Sector) + 1
                                              - Interfaces.Integer_64 (V.Flash.Start_Sector)) mod 2 ** 32));
               Write_U32 (B, S, V.Flash.Size);
               Write_U32 (B, S, V.Flash.Offset);
            else
               Fill (B, S, 0, 13);
            end if;
         when SD_Card_Summary_Command =>
            SD_Card_Summary (B, S, V.SD_Card);
         when others =>
            null;
      end case;
   end Reply;

end Adaflight.MSP_Hardware_Out;
