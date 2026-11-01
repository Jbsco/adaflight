--  The debug values: eight sixteen-bit values the modules record for the
--  mode the configuration selects, which the blackbox logs, the MSP debug
--  reply and the OSD elements show, and the telemetry carries. The selected
--  number is compared to a mode's position, so a number past the list
--  selects nothing. A value stored from a rounded float wraps into sixteen
--  bits as the reference's conversion does.
with Interfaces;

package Adaflight.Debug with SPARK_Mode is
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   subtype Integer_16 is Interfaces.Integer_16;

   Value_Count : constant := 8;
   subtype Index is Natural range 0 .. Value_Count - 1;
   type Values is array (Index) of Integer_16;

   --  The modes in the reference's order.
   type Mode is
     (None, Cycle_Time, Battery, Gyro_Filtered, Accelerometer, PID_Loop, RC_Interpolation,
      Angle_Rate, ESC_Sensor, Scheduler, Stack, ESC_Sensor_RPM, ESC_Sensor_Tmp, Altitude, FFT, FFT_Time,
      FFT_Freq, RX_FrSky_SPI, RX_SFHSS_SPI, Gyro_Raw, Multi_Gyro_Raw, Multi_Gyro_Diff, MAX7456_Signal,
      MAX7456_SPI_Clock, SBUS, FPORT, Rangefinder, Rangefinder_Quality, Optical_Flow, Lidar_TF, ADC_Internal,
      Runaway_Takeoff, SDIO, Current_Sensor, USB, Smartaudio, RTH, ITerm_Relax, Acro_Trainer, RC_Smoothing,
      RX_Signal_Loss, RC_Smoothing_Rate, Anti_Gravity, Dyn_LPF, RX_Spektrum_SPI, DShot_RPM_Telemetry,
      RPM_Filter, D_Max, AC_Correction, AC_Error, Multi_Gyro_Scaled, DShot_RPM_Errors,
      CRSF_Link_Statistics_Uplink, CRSF_Link_Statistics_Pwr, CRSF_Link_Statistics_Down, Baro,
      Autopilot_Altitude, Dyn_Idle, Feedforward_Limit, Feedforward, Blackbox_Output, Gyro_Sample, RX_Timing,
      D_LPF, VTX_Tramp, GHST, GHST_MSP, Scheduler_Determinism, Timing_Accuracy, RX_ExpressLRS_SPI,
      RX_ExpressLRS_Phaselock, RX_State_Time, GPS_Rescue_Velocity, GPS_Rescue_Heading, GPS_Rescue_Tracking,
      GPS_Connection, Attitude, VTX_MSP, GPS_DOP, Failsafe, Gyro_Calibration, Angle_Mode, Angle_Target,
      Current_Angle, DShot_Telemetry_Counts, RPM_Limit, RC_Stats, Mag_Calib, Mag_Task_Rate, EZ_Landing, TPA,
      S_Term, SPA, Tasks, Gimbal, Wing_Setpoint, Chirp, Flash_Test_PRBS, Mavlink_Telemetry, Autopilot_PID,
      Position_Nav, Autopilot_Stop, Pitot, Position_Est, Autopilot_Heading, RX_Redpine_SPI, Launch,
      Velocity_Est, Sag_Compensation, UPT1, Flight_Plan);

   type State is record
      Selected : Natural range 0 .. 255 := 0;
      Data     : Values := (others => 0);
   end record;

   function Selected (S : State; M : Mode) return Boolean is (S.Selected = Mode'Pos (M));

   --  The configuration's debug mode number.
   procedure Select_Mode (S : in out State; Number : Interfaces.Unsigned_8)
     with Post => S.Selected = Natural (Number) and then S.Data = S.Data'Old;

   --  One value for one mode, kept only while that mode is selected.
   procedure Set (S : in out State; M : Mode; I : Index; V : Integer_16)
     with Post => S.Selected = S.Selected'Old
                  and then (if Selected (S, M) then S.Data (I) = V else S.Data = S.Data'Old)
                  and then (for all J in Index => (if J /= I then S.Data (J) = S.Data'Old (J)));

   --  An integer wrapped into sixteen bits, and a float rounded half to even
   --  then wrapped, as the reference stores lrintf results.
   function Wrapped (V : Interfaces.Integer_32) return Integer_16;
   function Rounded (X : Float) return Integer_16
     with Pre => abs X <= 2.0 ** 24 - 1.0;
   --  A float truncated toward zero then wrapped, as the reference stores a
   --  float without rounding.
   function Truncated (X : Float) return Integer_16
     with Pre => abs X <= 2.0 ** 24 - 1.0;

end Adaflight.Debug;
