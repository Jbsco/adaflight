with Adaflight.Settings_Table; use Adaflight.Settings_Table;
with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;
with Adaflight.Mixer_Init;

package body Adaflight.MSP_Hardware_In with SPARK_Mode is
   use type Interfaces.Integer_64;

   Mixer_Count : constant := Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1;

   --  The mixer type among the command line's mixer names, then the yaw
   --  motor reversal when a byte remains.
   procedure Set_Mixer_Config (C : in out Configuration; Request : Byte_Array; R : out Result)
     with Pre  => Request'Length <= Max_Request,
          Post => (if R = Error then C = C'Old)
   is
      P : Plan;
   begin
      if U8 (Request, 0) not in 1 .. Mixer_Count then
         R := Error;
         return;
      end if;
      if Request'Length - 1 >= 1 then
         Add (P, Yaw_Motors_Reversed, S8 (Request, 1), 0);
      end if;
      if not Valid (P) then
         R := Error;
         return;
      end if;
      C.Mixer_Config.Mixer_Mode := Byte (U8 (Request, 0));
      Apply (C, P);
      R := Ack;
   end Set_Mixer_Config;

   --  A plan of writes, checked together.
   procedure Set_Fields (C : in out Configuration; Fields : Plan; R : out Result)
     with Pre  => Fits (Fields),
          Post => (if R = Error then C = C'Old)
   is
   begin
      if not Valid (Fields) then
         R := Error;
         return;
      end if;
      Apply (C, Fields);
      R := Ack;
   end Set_Fields;

   procedure Process
     (C : in out Configuration; Command : Interfaces.Unsigned_16; Request : Byte_Array; R : out Result)
   is
      Length : constant Natural := Request'Length;
      Offset : Offset_Range;
      P      : Plan;
   begin
      case Command is
         when Set_Mixer_Config_Command =>
            Set_Mixer_Config (C, Request, R);
         when Set_Sensor_Config_Command =>
            Add (P, Acc_Hardware, U8 (Request, 0), 0);
            Add (P, Baro_Hardware, U8 (Request, 1), 0);
            Add (P, Mag_Hardware, U8 (Request, 2), 0);
            Offset := 3;
            if Length - Offset >= 1 then
               Add (P, Rangefinder_Hardware, U8 (Request, Offset), 0);
               Offset := Offset + 1;
            end if;
            if Length - Offset >= 1 then
               Add (P, Opticalflow_Hardware, U8 (Request, Offset), 0);
               Offset := Offset + 1;
            end if;
            if Length - Offset >= 1 then
               Add (P, Pitot_Hardware, U8 (Request, Offset), 0);
            end if;
            Set_Fields (C, P, R);
         when Set_Motor_Config_Command =>
            Add (P, Max_Throttle, U16 (Request, 2), 0);
            Add (P, Min_Command, U16 (Request, 4), 0);
            Offset := 6;
            if Length - Offset >= 2 then
               Add (P, Motor_Poles, U8 (Request, Offset), 0);
               Add (P, Dshot_Bidir, U8 (Request, Offset + 1), 0);
               Offset := Offset + 2;
            end if;
            if Length - Offset >= 2 then
               Add (P, Motor_Kv, U16 (Request, Offset), 0);
            end if;
            Set_Fields (C, P, R);
         when Set_GPS_Config_Command =>
            Add (P, Gps_Provider, U8 (Request, 0), 0);
            Add (P, Gps_Sbas_Mode, U8 (Request, 1), 0);
            Add (P, Gps_Auto_Config, U8 (Request, 2), 0);
            Add (P, Gps_Auto_Baud, U8 (Request, 3), 0);
            if Length - 4 >= 2 then
               Add (P, Gps_Set_Home_Point_Once, U8 (Request, 4), 0);
               Add (P, Gps_Ublox_Use_Galileo, U8 (Request, 5), 0);
            end if;
            Set_Fields (C, P, R);
         when Set_Compass_Config_Command =>
            Add (P, Mag_Declination, S16 (Request, 0), 0);
            Set_Fields (C, P, R);
         when Set_GPS_Rescue_Command =>
            Add (P, Ap_Max_Angle, U16 (Request, 0), 0);
            Add (P, Gps_Rescue_Return_Alt, U16 (Request, 2), 0);
            Add (P, Gps_Rescue_Descent_Dist, U16 (Request, 4), 0);
            Add (P, Gps_Rescue_Ground_Speed, U16 (Request, 6), 0);
            Add (P, Ap_Throttle_Min, U16 (Request, 8), 0);
            Add (P, Ap_Throttle_Max, U16 (Request, 10), 0);
            Add (P, Ap_Hover_Throttle, U16 (Request, 12), 0);
            Add (P, Gps_Rescue_Sanity_Checks, U8 (Request, 14), 0);
            Add (P, Gps_Rescue_Min_Sats, U8 (Request, 15), 0);
            Offset := 16;
            if Length - Offset >= 6 then
               Add (P, Gps_Rescue_Ascend_Rate, U16 (Request, Offset), 0);
               Add (P, Gps_Rescue_Descend_Rate, U16 (Request, Offset + 2), 0);
               Add (P, Gps_Rescue_Allow_Arming_Without_Fix, U8 (Request, Offset + 4), 0);
               Add (P, Gps_Rescue_Alt_Mode, U8 (Request, Offset + 5), 0);
               Offset := Offset + 6;
            end if;
            if Length - Offset >= 2 then
               Add (P, Gps_Rescue_Min_Start_Dist, U16 (Request, Offset), 0);
               Offset := Offset + 2;
            end if;
            if Length - Offset >= 2 then
               Add (P, Gps_Rescue_Initial_Climb, U16 (Request, Offset), 0);
            end if;
            Set_Fields (C, P, R);
         when Set_GPS_Rescue_PIDs_Command =>
            Add (P, Ap_Altitude_P, U16 (Request, 0), 0);
            Add (P, Ap_Altitude_I, U16 (Request, 2), 0);
            Add (P, Ap_Altitude_D, U16 (Request, 4), 0);
            Add (P, Ap_Position_P, U16 (Request, 6), 0);
            Add (P, Ap_Position_I, U16 (Request, 8), 0);
            Add (P, Ap_Position_D, U16 (Request, 10), 0);
            Add (P, Gps_Rescue_Yaw_P, U16 (Request, 12), 0);
            Set_Fields (C, P, R);
         when others =>
            R := Error;
      end case;
   end Process;

end Adaflight.MSP_Hardware_In;
