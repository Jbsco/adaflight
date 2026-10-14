package body Adaflight.Task_Init with SPARK_Mode is
   use Adaflight.Scheduler;

   Fast_Voltage_Hz : constant := 200;
   Fast_Telemetry_Hz : constant := 500;

   function Period_Of (Hz : Rate_Hz) return Time_Delta is (Time_Delta (1_000_000 / Hz));

   -------------------------------
   -- Update_Mode_Gated_Enables --
   -------------------------------

   procedure Update_Mode_Gated_Enables
     (S : in out Adaflight.Scheduler.State; O : Options; Mag_Detected, Mag_Mode_Present : Boolean)
   is
   begin
      if O.Mag then
         Set_Task_Enabled (S, Mag_Hold, Mag_Detected and then Mag_Mode_Present);
      end if;
   end Update_Mode_Gated_Enables;

   ----------
   -- Init --
   ----------

   procedure Init
     (S : out Adaflight.Scheduler.State; C : Adaflight.Scheduler.Settings; Now_Cycles : Adaflight.Scheduler.Cycles;
      O : Options; I : Inputs)
   is
      Use_Voltage : constant Boolean := I.Voltage_Meter;
      Use_Current : constant Boolean := I.Current_Meter;
      Use_Alerts  : constant Boolean := I.Voltage_Alerts or else I.Consumption_Alerts or else I.Feature_OSD;
   begin
      Adaflight.Scheduler.Init (S, C, Now_Cycles);
      Set_Task_Enabled (S, Main, True);
      Set_Task_Enabled (S, Serial, True);
      Reschedule (S, C, Serial, Period_Of (I.Serial_Update_Rate_Hz));
      Set_Task_Enabled (S, Battery_Voltage, Use_Voltage);
      if O.Sag_Compensation and then I.Sag_Compensation then
         Reschedule (S, C, Battery_Voltage, Period_Of (Fast_Voltage_Hz));
      end if;
      Set_Task_Enabled (S, Battery_Current, Use_Current);
      Set_Task_Enabled (S, Battery_Alerts, (Use_Voltage or else Use_Current) and then Use_Alerts);
      if O.Stack_Check then
         Set_Task_Enabled (S, Stack_Check, True);
      end if;
      if I.Gyro_Detected then
         Reschedule (S, C, Gyro, I.Gyro_Sample_Looptime_Us);
         Reschedule (S, C, Filter, I.Gyro_Target_Looptime_Us);
         Reschedule (S, C, PID, I.Gyro_Target_Looptime_Us);
         Set_Task_Enabled (S, Gyro, True);
         Set_Task_Enabled (S, Filter, True);
         Set_Task_Enabled (S, PID, True);
         Enable_Gyro (S);
      end if;
      if O.Accel and then I.Acc_Detected and then I.Acc_Sample_Rate_Hz /= 0 then
         Set_Task_Enabled (S, Accel, True);
         Reschedule (S, C, Accel, Period_Of (I.Acc_Sample_Rate_Hz));
         Set_Task_Enabled (S, Attitude, True);
      end if;
      if O.Rangefinder and then I.Rangefinder_Detected then
         Set_Task_Enabled (S, Rangefinder, I.Feature_Rangefinder);
      end if;
      if O.Optical_Flow and then I.Optical_Flow_Detected then
         Set_Task_Enabled (S, Optical_Flow, I.Feature_Optical_Flow);
      end if;
      Set_Task_Enabled (S, Rx, True);
      Set_Task_Enabled (S, Dispatch, I.Dispatch_Enabled);
      if O.Beeper then
         Set_Task_Enabled (S, Beeper, True);
      end if;
      if O.GPS then
         Set_Task_Enabled (S, GPS, I.Feature_GPS);
      end if;
      if O.GPS_Rescue then
         Set_Task_Enabled (S, GPS_Rescue, I.Feature_GPS);
      end if;
      if O.Alt_Hold then
         Set_Task_Enabled (S, Alt_Hold, I.Baro_Detected or else I.Feature_Rangefinder or else I.Feature_GPS);
      end if;
      if O.Pos_Hold then
         Set_Task_Enabled (S, Pos_Hold, I.Feature_GPS or else I.Feature_Optical_Flow);
      end if;
      Update_Mode_Gated_Enables (S, O, I.Mag_Detected, I.Mag_Mode_Present);
      if O.Mag then
         Set_Task_Enabled (S, Compass, I.Mag_Detected);
      end if;
      if O.Baro then
         Set_Task_Enabled (S, Baro, I.Baro_Detected);
      end if;
      if O.Pitot then
         Set_Task_Enabled (S, Pitot, I.Pitot_Configured);
      end if;
      if O.Baro or else O.GPS or else O.Rangefinder or else O.Optical_Flow then
         Set_Task_Enabled
           (S, Position,
            I.Baro_Detected or else I.Feature_GPS or else I.Feature_Rangefinder or else I.Feature_Optical_Flow);
      end if;
      if O.Dashboard then
         Set_Task_Enabled (S, Dashboard, I.Feature_Dashboard);
      end if;
      if O.Telemetry and then I.Feature_Telemetry then
         Set_Task_Enabled (S, Telemetry, True);
         if I.Receiver in Jeti_ExBus | CRSF then
            Reschedule (S, C, Telemetry, Period_Of (Fast_Telemetry_Hz));
         end if;
      end if;
      if O.LED_Strip then
         Set_Task_Enabled (S, LED_Strip, I.Feature_LED_Strip);
      end if;
      if O.Transponder then
         Set_Task_Enabled (S, Transponder, I.Feature_Transponder);
      end if;
      if O.OSD then
         Reschedule (S, C, OSD, Period_Of (I.OSD_Framerate_Hz));
         Set_Task_Enabled (S, OSD, I.Feature_OSD and then I.OSD_Display_Port);
      end if;
      if O.BST then
         Set_Task_Enabled (S, BST_Master, True);
      end if;
      if O.ESC_Sensor then
         Set_Task_Enabled (S, ESC_Sensor, I.Feature_ESC_Sensor);
      end if;
      if O.ADC_Internal then
         Set_Task_Enabled (S, ADC_Internal, True);
      end if;
      if O.PINIO_Box then
         Set_Task_Enabled (S, PINIO_Box, I.PINIO_Box_Enabled);
      end if;
      if O.CMS then
         Set_Task_Enabled (S, CMS, O.MSP_Display_Port or else I.Feature_OSD or else I.Feature_Dashboard);
      end if;
      if O.VTX_Control and then O.VTX_Driver then
         Set_Task_Enabled (S, VTX_Control, True);
      end if;
      if O.Camera_Control then
         Set_Task_Enabled (S, Camera_Control, True);
      end if;
      if O.RC_Device then
         Set_Task_Enabled (S, RC_Device, I.RC_Device_Enabled);
      end if;
      if O.CRSF_V3 then
         Set_Task_Enabled (S, Speed_Negotiation, I.Receiver = CRSF);
      end if;
      if O.RC_Stats then
         Set_Task_Enabled (S, RC_Stats, True);
      end if;
      if O.Gimbal then
         Set_Task_Enabled (S, Gimbal, True);
      end if;
      if O.OSD_Custom_Text then
         Set_Task_Enabled (S, OSD_Custom_Text, True);
      end if;
      if O.DroneCAN then
         Set_Task_Enabled (S, DroneCAN, I.DroneCAN_Initialised);
      end if;
   end Init;

end Adaflight.Task_Init;
