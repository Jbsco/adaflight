--  Task setup: which tasks run from boot and at what period, from the build,
--  the features, the sensors detected and the settings, in the reference's
--  order; and the heading hold task, which follows the compass and a heading
--  mode on a switch and so is set again whenever the modes change.
with Adaflight.Scheduler;

package Adaflight.Task_Init with SPARK_Mode is

   subtype Rate_Hz is Positive range 1 .. 1_000_000;

   --  The tasks the build has, and the sag compensation, MSP display port
   --  and transmitter driver options their setup reads.
   type Options is record
      Accel              : Boolean := True;
      Beeper             : Boolean := True;
      GPS                : Boolean := True;
      GPS_Rescue         : Boolean := True;
      Alt_Hold           : Boolean := True;
      Pos_Hold           : Boolean := True;
      Mag                : Boolean := True;
      Baro               : Boolean := True;
      Rangefinder        : Boolean := True;
      Optical_Flow       : Boolean := True;
      Pitot              : Boolean := True;
      Dashboard          : Boolean := True;
      Telemetry          : Boolean := True;
      LED_Strip          : Boolean := True;
      Transponder        : Boolean := True;
      Stack_Check        : Boolean := True;
      OSD                : Boolean := True;
      BST                : Boolean := True;
      ESC_Sensor         : Boolean := True;
      CMS                : Boolean := True;
      VTX_Control        : Boolean := True;
      Camera_Control     : Boolean := True;
      RC_Device          : Boolean := True;
      ADC_Internal       : Boolean := True;
      PINIO_Box          : Boolean := True;
      CRSF_V3            : Boolean := True;
      RC_Stats           : Boolean := True;
      Gimbal             : Boolean := True;
      OSD_Custom_Text    : Boolean := True;
      DroneCAN           : Boolean := True;
      Sag_Compensation   : Boolean := True;
      MSP_Display_Port   : Boolean := True;
      VTX_Driver         : Boolean := True;
   end record;

   type Serial_Receiver is (Other_Receiver, Jeti_ExBus, CRSF);

   --  What the setup reads at boot: settings, features, sensors detected,
   --  and the states other units decide.
   type Inputs is record
      Serial_Update_Rate_Hz     : Rate_Hz := 100;
      Voltage_Meter             : Boolean := False;
      Current_Meter             : Boolean := False;
      Voltage_Alerts            : Boolean := False;
      Consumption_Alerts        : Boolean := False;
      Sag_Compensation          : Boolean := False;
      Gyro_Detected             : Boolean := False;
      Gyro_Sample_Looptime_Us   : Adaflight.Scheduler.Time_Delta := 125;
      Gyro_Target_Looptime_Us   : Adaflight.Scheduler.Time_Delta := 125;
      Acc_Detected              : Boolean := False;
      Acc_Sample_Rate_Hz        : Natural range 0 .. 1_000_000 := 0;
      Rangefinder_Detected      : Boolean := False;
      Optical_Flow_Detected     : Boolean := False;
      Baro_Detected             : Boolean := False;
      Mag_Detected              : Boolean := False;
      Mag_Mode_Present          : Boolean := False;
      Pitot_Configured          : Boolean := False;
      Dispatch_Enabled          : Boolean := False;
      Feature_OSD               : Boolean := False;
      Feature_Rangefinder       : Boolean := False;
      Feature_Optical_Flow      : Boolean := False;
      Feature_GPS               : Boolean := False;
      Feature_Dashboard         : Boolean := False;
      Feature_Telemetry         : Boolean := False;
      Feature_LED_Strip         : Boolean := False;
      Feature_Transponder       : Boolean := False;
      Feature_ESC_Sensor        : Boolean := False;
      Receiver                  : Serial_Receiver := Other_Receiver;
      OSD_Framerate_Hz          : Rate_Hz := 12;
      OSD_Display_Port          : Boolean := False;
      RC_Device_Enabled         : Boolean := False;
      PINIO_Box_Enabled         : Boolean := False;
      DroneCAN_Initialised      : Boolean := False;
   end record;

   --  The heading hold task runs with the compass and a heading mode on a
   --  switch.
   procedure Update_Mode_Gated_Enables
     (S : in out Adaflight.Scheduler.State; O : Options; Mag_Detected, Mag_Mode_Present : Boolean);

   --  The scheduler started, then each task enabled and its period set as
   --  the build, the features, the sensors and the settings call for.
   procedure Init
     (S : out Adaflight.Scheduler.State; C : Adaflight.Scheduler.Settings; Now_Cycles : Adaflight.Scheduler.Cycles;
      O : Options; I : Inputs);

end Adaflight.Task_Init;
