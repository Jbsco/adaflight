package body Adaflight.Task_Functions with SPARK_Mode is

   procedure Main is
   begin
      SD_Card_Poll;
      Flash_Erase;
   end Main;

   procedure Serial (I : Inputs) is
   begin
      MSP_Serial (Evaluate_Other_Data => not I.Armed);
   end Serial;

   procedure Battery_Alerts (I : Inputs; Now_Us : Scheduler.Time_Us) is
   begin
      if not I.Armed then
         Battery_Presence;
      end if;
      Battery_States (Now_Us);
      Battery_Alarms;
   end Battery_Alerts;

   procedure Accelerometer (Now_Us : Scheduler.Time_Us) is
   begin
      Acc_Update (Now_Us);
   end Accelerometer;

   procedure GPS_Rescue (I : Inputs) is
   begin
      if I.Rescue_Configured then
         GPS_Rescue_Update;
      end if;
   end GPS_Rescue;

   procedure Reschedule_Self
     (S : in out Scheduler.State; C : Scheduler.Settings; Next_Period_Us : Scheduler.Time_Delta)
     with Pre => S.Has_Current
   is
      use type Scheduler.Time_Delta;
   begin
      if Next_Period_Us /= 0 then
         Scheduler.Reschedule (S, C, Scheduler.Current_Task (S), Next_Period_Us);
      end if;
   end Reschedule_Self;

   procedure Baro (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us) is
      Next_Period_Us : Scheduler.Time_Delta;
   begin
      if I.Baro_Detected then
         Baro_Update (Now_Us, Next_Period_Us);
         Reschedule_Self (S, C, Next_Period_Us);
      end if;
   end Baro;

   procedure Pitot (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us) is
      Next_Period_Us : Scheduler.Time_Delta;
   begin
      if I.Pitot_Configured then
         Pitot_Update (Now_Us, Next_Period_Us);
         Reschedule_Self (S, C, Next_Period_Us);
      end if;
   end Pitot;

   procedure Compass (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us) is
      Next_Period_Us : Scheduler.Time_Delta;
   begin
      if I.Mag_Detected then
         Compass_Update (Now_Us, Next_Period_Us);
         Reschedule_Self (S, C, Next_Period_Us);
      end if;
   end Compass;

   procedure Position is
   begin
      Position_Update;
   end Position;

   procedure Rangefinder (I : Inputs; Now_Us : Scheduler.Time_Us) is
   begin
      if I.Rangefinder_Detected then
         Rangefinder_Update;
         Rangefinder_Process (Now_Us, I.Cos_Tilt);
      end if;
   end Rangefinder;

   procedure Optical_Flow (I : Inputs) is
   begin
      if I.Optical_Flow_Detected then
         Optical_Flow_Update;
         Optical_Flow_Process;
      end if;
   end Optical_Flow;

   procedure Telemetry (I : Inputs; Now_Us : Scheduler.Time_Us) is
   begin
      if not I.CLI_Open and then I.Feature_Telemetry then
         Telemetry_Poll_Sensors (Now_Us);
         Telemetry_Process (Now_Us);
      end if;
   end Telemetry;

   procedure Camera_Control (I : Inputs; Now_Us : Scheduler.Time_Us) is
   begin
      if not I.Armed then
         Camera_Control_Process (Now_Us);
      end if;
   end Camera_Control;

end Adaflight.Task_Functions;
