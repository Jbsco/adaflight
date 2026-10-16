--  The task functions with a unit or two behind them: the main task's
--  flash erase, the serial task's MSP pass that evaluates other data only
--  while disarmed, the battery alerts with the presence check while
--  disarmed, the accelerometer, the GPS rescue when configured, the
--  barometer, pitot and compass whose updates name the next period, the
--  position estimator, the rangefinder and optical flow when detected,
--  telemetry outside the command line with the feature, and the camera
--  control while disarmed. The units come in as the instantiation's
--  procedures.
with Adaflight.Scheduler;

generic
   with procedure Flash_Erase;
   with procedure MSP_Serial (Evaluate_Other_Data : Boolean);
   with procedure Battery_Presence;
   with procedure Battery_States (Now_Us : Adaflight.Scheduler.Time_Us);
   with procedure Battery_Alarms;
   with procedure Acc_Update (Now_Us : Adaflight.Scheduler.Time_Us);
   with procedure GPS_Rescue_Update;
   with procedure Baro_Update
     (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   with procedure Pitot_Update
     (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   with procedure Compass_Update
     (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta);
   with procedure Position_Update;
   with procedure Rangefinder_Update;
   with procedure Rangefinder_Process (Now_Us : Adaflight.Scheduler.Time_Us; Cos_Tilt : Float);
   with procedure Optical_Flow_Update;
   with procedure Optical_Flow_Process;
   with procedure Telemetry_Poll_Sensors (Now_Us : Adaflight.Scheduler.Time_Us);
   with procedure Telemetry_Process (Now_Us : Adaflight.Scheduler.Time_Us);
   with procedure Camera_Control_Process (Now_Us : Adaflight.Scheduler.Time_Us);
package Adaflight.Task_Functions with SPARK_Mode is

   --  What the functions read: the arming flag, the command line, the
   --  telemetry feature, the sensors detected, the pitot and rescue
   --  configuration, and the cosine of the tilt.
   type Inputs is record
      Armed                 : Boolean := False;
      CLI_Open              : Boolean := False;
      Feature_Telemetry     : Boolean := False;
      Baro_Detected         : Boolean := False;
      Mag_Detected          : Boolean := False;
      Rangefinder_Detected  : Boolean := False;
      Optical_Flow_Detected : Boolean := False;
      Pitot_Configured      : Boolean := False;
      Rescue_Configured     : Boolean := False;
      Cos_Tilt              : Float := 1.0;
   end record;

   procedure Main;
   procedure Serial (I : Inputs);
   procedure Battery_Alerts (I : Inputs; Now_Us : Scheduler.Time_Us);
   procedure Accelerometer (Now_Us : Scheduler.Time_Us);
   procedure GPS_Rescue (I : Inputs);

   --  The sensor tasks run as the scheduler's current task, which their
   --  updates reschedule by naming a period other than zero.
   procedure Baro (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us)
     with Pre => S.Has_Current;
   procedure Pitot (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us)
     with Pre => S.Has_Current;
   procedure Compass (S : in out Scheduler.State; C : Scheduler.Settings; I : Inputs; Now_Us : Scheduler.Time_Us)
     with Pre => S.Has_Current;

   procedure Position;
   procedure Rangefinder (I : Inputs; Now_Us : Scheduler.Time_Us);
   procedure Optical_Flow (I : Inputs);
   procedure Telemetry (I : Inputs; Now_Us : Scheduler.Time_Us);
   procedure Camera_Control (I : Inputs; Now_Us : Scheduler.Time_Us);

end Adaflight.Task_Functions;
