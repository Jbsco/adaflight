--  The runtime records built from the stored configuration. Each field is
--  held to its runtime range, which a stored value leaves only through a
--  foreign image, and each code to its names. The order rules the runtime
--  predicates need come from the configuration fix.
with Interfaces; use Interfaces;
with Adaflight.Accelerometer;
with Adaflight.Adjustments;
with Adaflight.Altitude_Control;
with Adaflight.Altitude_Hold;
with Adaflight.Arming;
with Adaflight.Attitude;
with Adaflight.Axes; use Adaflight.Axes;
with Adaflight.Barometer;
with Adaflight.Battery;
with Adaflight.Beeper;
with Adaflight.Blackbox;
with Adaflight.Blackbox_Header;
with Adaflight.Compass;
with Adaflight.Config_Fix;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.CRSF_Telemetry;
with Adaflight.Dyn_Notch;
with Adaflight.ExpressLRS;
with Adaflight.ExpressLRS_Receiver;
with Adaflight.Failsafe;
with Adaflight.Flight_Plan_Nav;
with Adaflight.Flight_Stats;
with Adaflight.Float_Bits;
with Adaflight.FlySky;
with Adaflight.GPS_Lap_Timer;
with Adaflight.GPS_Link;
with Adaflight.FrSky_Hub_Telemetry;
with Adaflight.FrSky_SPI;
with Adaflight.GHST_Telemetry;
with Adaflight.Gimbal_Control;
with Adaflight.GPS_Rescue;
with Adaflight.HoTT_Telemetry;
with Adaflight.IBus_Telemetry;
with Adaflight.Jeti_Telemetry;
with Adaflight.LED_Strip;
with Adaflight.MAVLink_Telemetry;
with Adaflight.Gyro_Filters;
with Adaflight.Mixer;
with Adaflight.Mixer_Init;
with Adaflight.Modes;
with Adaflight.Optical_Flow;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Page;
with Adaflight.OSD_Render;
with Adaflight.OSD_Spec;
with Adaflight.OSD_Stats;
with Adaflight.OSD_Warnings;
with Adaflight.PID_Config;
with Adaflight.PID_Profile; use Adaflight.PID_Profile;
with Adaflight.Pitot;
with Adaflight.Position_Control;
with Adaflight.Position_Estimator;
with Adaflight.Position_Hold;
with Adaflight.Rangefinder;
with Adaflight.Rates;
with Adaflight.RC_Command;
with Adaflight.Receiver;
with Adaflight.Redpine;
with Adaflight.RPM_Filter;
with Adaflight.RTC;
with Adaflight.Scheduler;
with Adaflight.Sensor_Alignment;
with Adaflight.SFHSS;
with Adaflight.Spektrum;
with Adaflight.Spektrum_SPI;
with Adaflight.SPI_Radio;
with Adaflight.SRXL2;
with Adaflight.SRXL_Telemetry;
with Adaflight.UBX_Config;
with Adaflight.Vectors;
with Adaflight.VTX;

package Adaflight.Config_Runtime with SPARK_Mode is

   function PID_Profile_Of (P : Pid_Profile_Record) return PID_Profile.Profile
     with Pre => Config_Fix.Fixed_PID_Profile (P);

   --  The rate profile from a stored rate profile; the rates have no order
   --  rule, so nothing is asked of the fix.
   function Rate_Profile_Of (R : Control_Rate_Config_Record) return Rates.Profile;

   --  The arming settings from the stored arming, system, receiver, 3D,
   --  mixer, PID loop and scheduler groups, the current PID profile, the
   --  features in use and the sensors found at boot.
   function Arming_Settings_Of
     (A : Arming_Config_Record; Sys : System_Config_Record; R : Rx_Config_Record;
      Flight_3D : Flight3_D_Config_Record; Mixer_Mode : Unsigned_8; Loop_Rate : Pid_Config_Record;
      Sch : Scheduler_Config_Record; P : Pid_Profile_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return Arming.Settings;

   --  The mode conditions from the stored ones. A mode outside the box
   --  table makes a condition that is never active, and a link outside it
   --  no link (D6).
   function Conditions_Of (C : Mode_Activation_Condition_Record_List_20) return Modes.Conditions;

   --  The failsafe settings from the stored failsafe group and the
   --  autopilot's loss policy.
   function Failsafe_Settings_Of (F : Failsafe_Config_Record; A : Autopilot_Config_Record) return Failsafe.Settings;

   --  The receiver settings from the stored receiver, channel range,
   --  channel failsafe, 3D and failsafe groups, the features in use, which
   --  name the source as the reference's receiver setup does, and the
   --  channel count the protocol reports. An equal channel range is widened
   --  by one step and a zero frame period reads as one (D6).
   function Receiver_Settings_Of
     (R : Rx_Config_Record; Ranges : Rx_Channel_Range_Config_Record_List_4;
      Failsafes : Rx_Failsafe_Channel_Config_Record_List_18; Flight_3D : Flight3_D_Config_Record;
      F : Failsafe_Config_Record; Features : Unsigned_32; Reported_Channels : Natural)
      return Receiver.Settings
     with Pre => Reported_Channels <= Receiver.Channel_Count;

   --  The gyro settings from the stored gyro, dynamic notch, RPM filter,
   --  gyro device, board alignment, motor and PID loop groups, with what the
   --  hardware gives: the sample time, whose product with the loop ratio is
   --  the loop time, the gyro's scale, the motors in use, and whether the
   --  gyro protects against overflow.
   function Gyro_Settings_Of
     (G : Gyro_Config_Record; N : Dyn_Notch_Config_Record; R : Rpm_Filter_Config_Record;
      Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record; Motor : Motor_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us; Scale : Float;
      Motors : Mixer.Motor_Count; Overflow_Protected : Boolean) return Gyro_Filters.Settings
     with Pre => Config_Fix.Fixed_Gyro_Filters (G) and then Loop_Rate.Pid_Process_Denom >= 1
                 and then Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom) <= PID_Config.Loop_Time_Us'Last
                 and then Scale in 2.0 ** (-10) .. 1.0;

   --  The RC command settings from the stored receiver, RC controls and
   --  PID loop groups and the current rate profile, with the sample time
   --  whose product with the loop ratio is the loop time.
   function RC_Config_Of
     (R : Rx_Config_Record; Controls : Rc_Controls_Config_Record; Rate : Control_Rate_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us) return RC_Command.Config
     with Pre => Loop_Rate.Pid_Process_Denom >= 1
                 and then Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom) <= PID_Config.Loop_Time_Us'Last;

   --  The adjustment settings from the stored receiver and system groups.
   function Adjustment_Settings_Of (R : Rx_Config_Record; Sys : System_Config_Record) return Adjustments.Settings;

   --  The mixer configuration from the stored mixer, motor, 3D and receiver
   --  groups, the current rate and PID profiles, the custom motor mix, the
   --  features in use and the build's mixers. The output range comes from
   --  the protocol family's endpoints, with a range the motor values do not
   --  hold, or an inverted one, held to a range at least one step wide; a
   --  disabled protocol's range is zero to one. A mode outside the table
   --  reads as quad X, a weight that is not a number as zero, and a custom
   --  mix without motors as one motor with a zero mix (D6).
   function Mixer_Config_Of
     (M : Mixer_Config_Record; Motor : Motor_Config_Record; Flight_3D : Flight3_D_Config_Record;
      R : Rx_Config_Record; Rate : Control_Rate_Config_Record; P : Pid_Profile_Record;
      Custom : Motor_Mixer_Record_List_8; Features : Unsigned_32; O : Mixer_Init.Options) return Mixer.Config;

   --  The accelerometer settings from the stored accelerometer, gyro device
   --  and board alignment groups, with the hardware's sample rate and counts
   --  per g; the alignment is the first gyro's, since the boards use one
   --  chip for both.
   function Accelerometer_Settings_Of
     (A : Accelerometer_Config_Record; Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record;
      Sample_Rate_Hz : Accelerometer.Sample_Rate; One_G : Accelerometer.Counts_Per_G)
      return Accelerometer.Settings;

   --  The attitude settings from the stored IMU and throttle correction
   --  groups.
   function Attitude_Settings_Of (I : Imu_Config_Record; T : Throttle_Correction_Config_Record)
      return Attitude.Settings;

   --  The barometer settings from the stored barometer group; the virtual
   --  device is hardware code 13.
   function Barometer_Settings_Of (B : Barometer_Config_Record) return Barometer.Settings;

   --  The compass settings from the stored compass and board alignment
   --  groups.
   function Compass_Settings_Of (C : Compass_Config_Record; Board : Board_Alignment_Record) return Compass.Settings;

   --  The battery settings from the stored battery, voltage meter, current
   --  meter, virtual meter and ESC sensor groups and the current battery
   --  profile.
   function Battery_Settings_Of
     (B : Battery_Config_Record; P : Battery_Profile_Record; V : Voltage_Sensor_Adc_Config_Record;
      I : Current_Sensor_Adc_Config_Record; Virtual : Current_Sensor_Virtual_Config_Record;
      ESC : Esc_Sensor_Config_Record) return Battery.Settings;

   --  The beeper settings from the stored beeper group; each sound's flag
   --  is the bit below its code.
   function Beeper_Settings_Of (B : Beeper_Config_Record) return Beeper.Settings;

   --  The GPS link settings from the stored GPS and GPS rescue groups, with
   --  whether a serial port has the GPS function. The baud is the user's
   --  from the module's table, 230400 for a rate the table lacks; the
   --  custom NMEA commands are the stored text up to its first NUL.
   function GPS_Link_Settings_Of
     (G : Gps_Config_Record; R : Gps_Rescue_Record; Port_Assigned : Boolean) return GPS_Link.Settings;

   --  The GPS rescue settings from the stored GPS rescue, autopilot and GPS
   --  groups.
   function GPS_Rescue_Settings_Of
     (R : Gps_Rescue_Record; A : Autopilot_Config_Record; G : Gps_Config_Record) return GPS_Rescue.Settings;

   --  The autopilot's position control settings from the stored autopilot
   --  and RC controls groups, with whether the build flies a rescue as a
   --  flight plan.
   function Position_Control_Settings_Of
     (A : Autopilot_Config_Record; Controls : Rc_Controls_Config_Record; Rescue_Plan : Boolean)
      return Position_Control.Settings;

   --  The position estimator settings from the stored position and
   --  position hold groups, and the position hold settings from the latter.
   function Position_Estimator_Settings_Of
     (P : Position_Config_Record; H : Pos_Hold_Config_Record) return Position_Estimator.Settings;
   function Position_Hold_Settings_Of (H : Pos_Hold_Config_Record) return Position_Hold.Settings;

   --  The altitude control settings from the stored autopilot and receiver
   --  groups, and the altitude hold settings with the stored altitude hold
   --  group.
   function Altitude_Control_Settings_Of
     (A : Autopilot_Config_Record; R : Rx_Config_Record) return Altitude_Control.Settings;
   function Altitude_Hold_Settings_Of
     (A : Autopilot_Config_Record; H : Alt_Hold_Config_Record; R : Rx_Config_Record) return Altitude_Hold.Settings;

   --  The flight plan executor's settings from the stored autopilot, GPS
   --  rescue and altitude hold groups; a wing flies without a climb rate.
   function Flight_Plan_Settings_Of
     (A : Autopilot_Config_Record; Rescue : Gps_Rescue_Record; H : Alt_Hold_Config_Record; Wing : Boolean)
      return Flight_Plan_Nav.Settings;

   --  The flight log settings from the stored blackbox group, with whether
   --  the build is a wing; a serial device runs fast from a megabaud up.
   function Blackbox_Settings_Of (B : Blackbox_Config_Record; Wing : Boolean) return Blackbox.Settings;

   --  The scheduler settings from the stored scheduler group, with the
   --  platform's clock in cycles per microsecond, its floor on a
   --  rescheduled period and the gyro's period.
   function Scheduler_Settings_Of
     (S : Scheduler_Config_Record; Cycles_Per_Us : Positive; Delay_Limit_Us : Scheduler.Delay_Limit;
      Gyro_Period_Us : Scheduler.Period_Us) return Scheduler.Settings
     with Pre => Cycles_Per_Us <= 1_000;

   --  The LED strip settings from the stored LED strip and status mode
   --  groups; the first eight special colors are the strip's.
   function LED_Strip_Settings_Of
     (L : Led_Strip_Config_Record; M : Led_Strip_Status_Mode_Config_Record) return LED_Strip.Settings;

   --  The video transmitter settings from the stored VTX settings group.
   function VTX_Settings_Of (V : Vtx_Settings_Config_Record) return VTX.Settings;

   --  The flight statistics settings from the stored statistics group, and
   --  the lap timer settings from the stored lap timer group.
   function Flight_Stats_Settings_Of (S : Stats_Config_Record) return Flight_Stats.Settings;
   function Lap_Timer_Settings_Of (G : Gps_Lap_Timer_Config_Record) return GPS_Lap_Timer.Settings;

   --  The rangefinder settings from the stored position group, with the
   --  cone the detected sensor reports; the optical flow settings from the
   --  stored optical flow group; and the pitot settings from the stored
   --  pitot group.
   function Rangefinder_Settings_Of
     (P : Position_Config_Record; Cone_Extended_Decidegrees : Rangefinder.Decidegrees) return Rangefinder.Settings;
   function Optical_Flow_Settings_Of (O : Opticalflow_Config_Record) return Optical_Flow.Settings;
   function Pitot_Settings_Of (P : Pitot_Config_Record) return Pitot.Settings;

   --  The gimbal settings from the stored gimbal tracking and receiver
   --  groups, with whether a serial port has the gimbal function.
   function Gimbal_Settings_Of
     (G : Gimbal_Track_Config_Record; R : Rx_Config_Record; Port_Configured : Boolean) return Gimbal_Control.Settings;

   --  The clock settings from the stored time group.
   function RTC_Settings_Of (T : Time_Config_Record) return RTC.Settings;

   --  The OSD page settings from the stored OSD and OSD element groups,
   --  with whether the display supports a logo; an element is visible when
   --  its position shows it in the stored profile.
   function OSD_Page_Settings_Of
     (O : Osd_Config_Record; E : Osd_Element_Config_Record; Logo_Supported : Boolean) return OSD_Page.Settings;

   --  The OSD render settings from the stored OSD and VTX settings groups;
   --  a profile name is the stored text up to its first NUL.
   function OSD_Render_Settings_Of
     (O : Osd_Config_Record; V : Vtx_Settings_Config_Record; N : Osd_Nav_Map_Config_Record) return OSD_Render.Settings;

   --  The OSD specification settings from the stored mixer and motor
   --  groups, the current rate, PID and battery profiles.
   function OSD_Spec_Settings_Of
     (M : Mixer_Config_Record; Motor : Motor_Config_Record; Rate : Control_Rate_Config_Record;
      P : Pid_Profile_Record; B : Battery_Profile_Record) return OSD_Spec.Settings;

   --  The OSD warning settings from the stored OSD group; each warning's
   --  flag is its bit.
   function OSD_Warnings_Settings_Of (O : Osd_Config_Record) return OSD_Warnings.Settings;

   --  The OSD element alarm settings from the stored OSD and GPS rescue
   --  groups.
   function OSD_Alarm_Settings_Of (O : Osd_Config_Record; R : Gps_Rescue_Record) return OSD_Elements.Alarm_Settings;

   --  The telemetry settings from the stored telemetry group, with what the
   --  protocols read from outside it: the sensors found at boot, the
   --  features in use, the battery meters configured, and the
   --  accelerometer's scale. The FrSky hub takes the motor group's pole
   --  count and the altitude's presence; the CRSF configuration takes the
   --  receiver group's negotiated baud and whether the build sends event
   --  driven frames; Jeti takes the system group's debug mode.
   function FrSky_Hub_Settings_Of
     (T : Telemetry_Config_Record; Motor : Motor_Config_Record; Sensors : Arming.Sensor_Set;
      Altitude_Present : Boolean; GPS_Present : Boolean; Acc_1G_Rec : FrSky_Hub_Telemetry.Gravity_Scale)
      return FrSky_Hub_Telemetry.Settings;
   function GHST_Settings_Of
     (T : Telemetry_Config_Record; B : Battery_Config_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return GHST_Telemetry.Settings;
   function CRSF_Config_Of
     (T : Telemetry_Config_Record; R : Rx_Config_Record; B : Battery_Config_Record; Features : Unsigned_32;
      Sensors : Arming.Sensor_Set; Event_Driven : Boolean) return CRSF_Telemetry.Config;
   function HoTT_Settings_Of (T : Telemetry_Config_Record; GPS_Present : Boolean) return HoTT_Telemetry.Settings;
   function IBus_Settings_Of
     (T : Telemetry_Config_Record; Acc_1G_Rec : IBus_Telemetry.Gravity_Scale) return IBus_Telemetry.Settings;
   function Jeti_Settings_Of
     (B : Battery_Config_Record; Sys : System_Config_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return Jeti_Telemetry.Settings;
   function MAVLink_Settings_Of (T : Telemetry_Config_Record) return MAVLink_Telemetry.Settings;
   function SRXL_Settings_Of (T : Telemetry_Config_Record; Features : Unsigned_32) return SRXL_Telemetry.Settings;

   --  The receiver link settings from the stored SPI receiver, CC2500,
   --  ExpressLRS, FlySky, Spektrum and receiver groups and the features in
   --  use. A radio's pins come from the stored pin tags; the FrSky SPI
   --  protocol comes from the SPI protocol code, FrSky D for a code outside
   --  the family, and the FlySky variant is AFHDS 2A for its code and AFHDS
   --  otherwise; the Spektrum kind comes from the serial provider,
   --  Spektrum 2048 for a code outside the three.
   function Radio_Pins_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return SPI_Radio.Pins;
   function ExpressLRS_Settings_Of (E : Rx_Express_Lrs_Spi_Config_Record) return ExpressLRS_Receiver.Settings;
   function FrSky_SPI_Settings_Of
     (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; Features : Unsigned_32;
      Hub : FrSky_Hub_Telemetry.Settings) return FrSky_SPI.Settings;
   function Redpine_Settings_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return Redpine.Settings;
   function SFHSS_Settings_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return SFHSS.Settings;
   function FlySky_Settings_Of
     (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; F : Fly_Sky_Config_Record) return FlySky.Settings;
   function Spektrum_Settings_Of
     (R : Rx_Config_Record; Features : Unsigned_32; Telemetry_Port : Boolean) return Spektrum.Settings;
   function Spektrum_SPI_Settings_Of
     (K : Spektrum_Config_Record; S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; Features : Unsigned_32)
      return Spektrum_SPI.Settings;
   function SRXL2_Settings_Of (R : Rx_Config_Record) return SRXL2.Settings;

private

   function Held (V : Integer; Low : Integer; High : Integer) return Integer is
     (Integer'Min (High, Integer'Max (Low, V)))
     with Pre  => Low <= High,
          Post => Held'Result in Low .. High;

   --  A code held to the last of its names.
   function Code (V : Unsigned_8; Last : Natural) return Natural is (Natural'Min (Natural (V), Last))
     with Post => Code'Result <= Last;

   function Held_F (V : Float; Low : Float; High : Float) return Float is
     (Float'Min (High, Float'Max (Low, V)))
     with Pre  => Low <= High,
          Post => Held_F'Result in Low .. High;

   --  Whether a stored float is a number: its exponent bits are not all set.
   function Is_Number (X : Float) return Boolean is
     ((Float_Bits.Float_Bits (X) and 16#7F80_0000#) /= 16#7F80_0000#);

   function Weight_Of (X : Float) return Mixer.Weight is
     (if Is_Number (X) then Held_F (X, Mixer.Weight'First, Mixer.Weight'Last) else 0.0);

   --  The motor protocol families: PWM, OneShot, MultiShot and brushed are
   --  analog, codes 0 to 4; the DShot speeds and ProShot are DShot, codes 5
   --  to 8; 9 is disabled.
   function Is_Analog (Protocol : Unsigned_8) return Boolean is (Protocol <= 4);
   function Is_DShot (Protocol : Unsigned_8) return Boolean is (Protocol in 5 .. 8);

   function Axis_Gains_Of (G : Pidf_Record) return Axis_Gains is
     (P => Held (Integer (G.P), 0, Gain_Max),
      I => Held (Integer (G.I), 0, Gain_Max),
      D => Held (Integer (G.D), 0, Gain_Max),
      F => Held (Integer (G.F), 0, F_Gain_Max),
      S => Held (Integer (G.S), 0, Gain_Max));

   --  The level gains are the fourth PID entry, with the angle feedforward
   --  in the low byte of its feedforward gain.
   function Level_Gains_Of (G : Pidf_Record) return Level_Gains is
     (P => Held (Integer (G.P), 0, 200),
      I => Held (Integer (G.I), 0, 100),
      D => Held (Integer (G.D), 10, 200),
      F => Held (Integer (G.F and 16#FF#), 0, 200));

   function PID_Profile_Of (P : Pid_Profile_Record) return PID_Profile.Profile is
     (Gains                    => (Roll => Axis_Gains_Of (P.Pid (0)), Pitch => Axis_Gains_Of (P.Pid (1)),
                                   Yaw => Axis_Gains_Of (P.Pid (2))),
      D_Max                    => (Roll  => Held (Integer (P.D_Max (0)), 0, Gain_Max),
                                   Pitch => Held (Integer (P.D_Max (1)), 0, Gain_Max),
                                   Yaw   => Held (Integer (P.D_Max (2)), 0, Gain_Max)),
      Level                    => Level_Gains_Of (P.Pid (3)),
      Angle_Earth_Ref          => Held (Integer (P.Angle_Earth_Ref), 0, 100),
      Horizon_Ignore_Sticks    => P.Horizon_Ignore_Sticks /= 0,
      Horizon_Limit_Degrees    => Held (Integer (P.Horizon_Limit_Degrees), 10, 250),
      Horizon_Delay_Ms         => Held (Integer (P.Horizon_Delay_Ms), 10, 5000),
      Rate_Accel_Limit         => Held (Integer (P.Rate_Accel_Limit), 0, 500),
      Yaw_Rate_Accel_Limit     => Held (Integer (P.Yaw_Rate_Accel_Limit), 0, 500),
      Anti_Gravity_Gain        => Held (Integer (P.Anti_Gravity_Gain), 0, Gain_Max),
      Anti_Gravity_P_Gain      => Held (Integer (P.Anti_Gravity_P_Gain), 0, Gain_Max),
      Crash_Time               => Held (Integer (P.Crash_Time), 100, 5000),
      Crash_Delay              => Held (Integer (P.Crash_Delay), 0, 500),
      Crash_Recovery_Angle     => Held (Integer (P.Crash_Recovery_Angle), 5, 30),
      Crash_Recovery_Rate      => Held (Integer (P.Crash_Recovery_Rate), 50, 255),
      Crash_Gyro_Threshold     => Held (Integer (P.Crash_Gthreshold), 100, 2000),
      Crash_Dterm_Threshold    => Held (Integer (P.Crash_Dthreshold), 10, 2000),
      Crash_Setpoint_Threshold => Held (Integer (P.Crash_Setpoint_Threshold), 50, 2000),
      Crash_Limit_Yaw          => Held (Integer (P.Crash_Limit_Yaw), 0, 1000),
      Crash_Recovery           =>
        Crash_Recovery_Mode'Val (Code (P.Crash_Recovery, Crash_Recovery_Mode'Pos (Crash_Recovery_Mode'Last))),
      Iterm_Windup             => Held (Integer (P.Iterm_Windup), 20, 100),
      PID_Sum_Limit            => Held (Integer (P.Pid_Sum_Limit), 100, 1000),
      PID_Sum_Limit_Yaw        => Held (Integer (P.Pid_Sum_Limit_Yaw), 100, 1000),
      Iterm_Rotation           => P.Iterm_Rotation /= 0,
      Iterm_Relax              =>
        Iterm_Relax_Mode'Val (Code (P.Iterm_Relax, Iterm_Relax_Mode'Pos (Iterm_Relax_Mode'Last))),
      Iterm_Relax_Type         =>
        Iterm_Relax_Source'Val (Code (P.Iterm_Relax_Type, Iterm_Relax_Source'Pos (Iterm_Relax_Source'Last))),
      Iterm_Relax_Cutoff       => Held (Integer (P.Iterm_Relax_Cutoff), 1, 50),
      Acro_Trainer_Angle_Limit => Held (Integer (P.Acro_Trainer_Angle_Limit), 10, 80),
      Acro_Trainer_Lookahead_Ms => Held (Integer (P.Acro_Trainer_Lookahead_Ms), 10, 200),
      Acro_Trainer_Debug_Axis  => Held (Integer (P.Acro_Trainer_Debug_Axis), 0, 1),
      Acro_Trainer_Gain        => Held (Integer (P.Acro_Trainer_Gain), 25, 255),
      Dterm_LPF1_Dyn_Min_Hz    => Held (Integer (P.Dterm_Lpf1_Dyn_Min_Hz), 0, 1000),
      Dterm_LPF1_Dyn_Max_Hz    => Held (Integer (P.Dterm_Lpf1_Dyn_Max_Hz), 0, 1000),
      Dterm_LPF1_Dyn_Expo      => Held (Integer (P.Dterm_Lpf1_Dyn_Expo), 0, 10),
      Dterm_LPF1_Type          => Lowpass_Kind'Val (Code (P.Dterm_Lpf1_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      Dterm_LPF1_Static_Hz     => Held (Integer (P.Dterm_Lpf1_Static_Hz), 0, 1000),
      Dterm_LPF2_Static_Hz     => Held (Integer (P.Dterm_Lpf2_Static_Hz), 0, 1000),
      Dterm_LPF2_Type          => Lowpass_Kind'Val (Code (P.Dterm_Lpf2_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      Dterm_Notch_Hz           => Held (Integer (P.Dterm_Notch_Hz), 0, 1000),
      Dterm_Notch_Cutoff       => Held (Integer (P.Dterm_Notch_Cutoff), 0, 1000),
      Yaw_Lowpass_Hz           => Held (Integer (P.Yaw_Lowpass_Hz), 0, 500),
      Anti_Gravity_Cutoff_Hz   => Held (Integer (P.Anti_Gravity_Cutoff_Hz), 2, 50),
      Throttle_Boost_Cutoff    => Held (Integer (P.Throttle_Boost_Cutoff), 5, 50),
      Angle_Feedforward_Smoothing_Ms => Held (Integer (P.Angle_Feedforward_Smoothing_Ms), 10, 250),
      Launch_Control           =>
        Launch_Control_Mode'Val (Code (P.Launch_Control_Mode, Launch_Control_Mode'Pos (Launch_Control_Mode'Last))),
      Launch_Control_Angle_Limit => Held (Integer (P.Launch_Control_Angle_Limit), 0, 80),
      Launch_Control_Gain      => Held (Integer (P.Launch_Control_Gain), 0, 200),
      Thrust_Linearization     => Held (Integer (P.Thrust_Linearization), 0, 150),
      D_Max_Gain               => Held (Integer (P.D_Max_Gain), 0, 100),
      D_Max_Advance            => Held (Integer (P.D_Max_Advance), 0, 200),
      Feedforward_Transition   => Held (Integer (P.Feedforward_Transition), 0, 100),
      Feedforward_Average      =>
        Feedforward_Averaging'Val
          (Code (P.Feedforward_Averaging, Feedforward_Averaging'Pos (Feedforward_Averaging'Last))),
      Feedforward_Smooth_Factor => Held (Integer (P.Feedforward_Smooth_Factor), 0, 95),
      Feedforward_Jitter_Factor => Held (Integer (P.Feedforward_Jitter_Factor), 0, 20),
      Feedforward_Boost        => Held (Integer (P.Feedforward_Boost), 0, 50),
      Feedforward_Max_Rate_Limit => Held (Integer (P.Feedforward_Max_Rate_Limit), 0, 200),
      Feedforward_Yaw_Hold_Gain => Held (Integer (P.Feedforward_Yaw_Hold_Gain), 0, 100),
      Feedforward_Yaw_Hold_Time => Held (Integer (P.Feedforward_Yaw_Hold_Time), 10, 250),
      Level_Race_Mode          => P.Level_Race_Mode /= 0,
      TPA_Rate                 => Held (Integer (P.Tpa_Rate), 0, 100),
      TPA_Breakpoint           => Held (Integer (P.Tpa_Breakpoint), 1000, 2000),
      TPA_Low_Rate             => Held (Integer (P.Tpa_Low_Rate), -100, 100),
      TPA_Low_Breakpoint       => Held (Integer (P.Tpa_Low_Breakpoint), 1000, 2000),
      TPA_Low_Always           => P.Tpa_Low_Always /= 0,
      TPA_Terms                => TPA_Mode'Val (Code (P.Tpa_Mode, TPA_Mode'Pos (TPA_Mode'Last))),
      TPA_Curve_Type           =>
        TPA_Curve_Kind'Val (Code (P.Tpa_Curve_Type, TPA_Curve_Kind'Pos (TPA_Curve_Kind'Last))),
      TPA_Curve_Stall_Throttle => Held (Integer (P.Tpa_Curve_Stall_Throttle), 0, 100),
      TPA_Curve_PID_Thr0       => Held (Integer (P.Tpa_Curve_Pid_Thr0), 1, 1000),
      TPA_Curve_PID_Thr100     => Held (Integer (P.Tpa_Curve_Pid_Thr100), 1, 1000),
      TPA_Curve_Expo           => Held (Integer (P.Tpa_Curve_Expo), -100, 100),
      Throttle_Boost           => Held (Integer (P.Throttle_Boost), 0, 100),
      Ez_Landing_Threshold     => Held (Integer (P.Ez_Landing_Threshold), 0, 200),
      Ez_Landing_Limit         => Held (Integer (P.Ez_Landing_Limit), 0, 75),
      Ez_Landing_Speed         => Held (Integer (P.Ez_Landing_Speed), 0, 250),
      Landing_Disarm_Threshold => Held (Integer (P.Landing_Disarm_Threshold), 0, 250),
      Angle_Limit              => Held (Integer (P.Angle_Limit), 10, 90),
      Simplified_PIDs_Mode     =>
        Simplified_Mode'Val (Code (P.Simplified_Pids_Mode, Simplified_Mode'Pos (Simplified_Mode'Last))),
      Simplified_Master_Multiplier => Held (Integer (P.Simplified_Master_Multiplier), 0, 200),
      Simplified_Roll_Pitch_Ratio => Held (Integer (P.Simplified_Roll_Pitch_Ratio), 0, 200),
      Simplified_I_Gain        => Held (Integer (P.Simplified_I_Gain), 0, 200),
      Simplified_D_Gain        => Held (Integer (P.Simplified_D_Gain), 0, 200),
      Simplified_PI_Gain       => Held (Integer (P.Simplified_Pi_Gain), 0, 200),
      Simplified_D_Max_Gain    => Held (Integer (P.Simplified_D_Max_Gain), 0, 200),
      Simplified_Feedforward_Gain => Held (Integer (P.Simplified_Feedforward_Gain), 0, 200),
      Simplified_Pitch_PI_Gain => Held (Integer (P.Simplified_Pitch_Pi_Gain), 0, 200),
      Simplified_Dterm_Filter  => P.Simplified_Dterm_Filter /= 0,
      Simplified_Dterm_Filter_Multiplier => Held (Integer (P.Simplified_Dterm_Filter_Multiplier), 10, 200));

   function Rate_Profile_Of (R : Control_Rate_Config_Record) return Rates.Profile is
     (Kind           => Rates.Curve_Kind'Val (Code (R.Rates_Type, Rates.Curve_Kind'Pos (Rates.Curve_Kind'Last))),
      RC_Rates       => (Roll  => Held (Integer (R.Rc_Rates (0)), 1, 255),
                         Pitch => Held (Integer (R.Rc_Rates (1)), 1, 255),
                         Yaw   => Held (Integer (R.Rc_Rates (2)), 1, 255)),
      RC_Expo        => (Roll  => Held (Integer (R.Rc_Expo (0)), 0, 100),
                         Pitch => Held (Integer (R.Rc_Expo (1)), 0, 100),
                         Yaw   => Held (Integer (R.Rc_Expo (2)), 0, 100)),
      Super_Rates    => (Roll => Integer (R.Rates (0)), Pitch => Integer (R.Rates (1)), Yaw => Integer (R.Rates (2))),
      Limits         => (Roll  => Held (Integer (R.Rate_Limit (0)), 0, Rates.Max_Rate_Limit),
                         Pitch => Held (Integer (R.Rate_Limit (1)), 0, Rates.Max_Rate_Limit),
                         Yaw   => Held (Integer (R.Rate_Limit (2)), 0, Rates.Max_Rate_Limit)),
      Quick_Expo     => R.Quick_Rates_Rc_Expo /= 0,
      Throttle_Mid   => Held (Integer (R.Thr_Mid8), 0, 100),
      Throttle_Expo  => Held (Integer (R.Thr_Expo8), 0, 100),
      Throttle_Hover => Held (Integer (R.Thr_Hover8), 0, 100));

   function Arming_Settings_Of
     (A : Arming_Config_Record; Sys : System_Config_Record; R : Rx_Config_Record;
      Flight_3D : Flight3_D_Config_Record; Mixer_Mode : Unsigned_8; Loop_Rate : Pid_Config_Record;
      Sch : Scheduler_Config_Record; P : Pid_Profile_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return Arming.Settings is
     (Gyro_Cal_On_First_Arm      => A.Gyro_Cal_On_First_Arm /= 0,
      Auto_Disarm_Delay          => Integer (A.Auto_Disarm_Delay),
      Prearm_Allow_Rearm         => A.Prearm_Allow_Rearm /= 0,
      Boot_Grace_Time            => Integer (Sys.Power_On_Arming_Grace_Time),
      Stick_Arming               => Sys.Enable_Stick_Arming /= 0,
      Mid_RC                     => Held (Integer (R.Midrc), 1_200, 1_700),
      Min_Check                  => Held (Integer (R.Mincheck), 750, 2_250),
      Max_Check                  => Held (Integer (R.Maxcheck), 750, 2_250),
      Airmode_Threshold          => Held (Integer (R.Air_Mode_Activate_Threshold), 0, 100),
      Three_D                    => (Features and Config_Fix.Feature_3D) /= 0,
      Switched_Mode_3D           => Flight_3D.Switched_Mode3d /= 0,
      Deadband_3D_Throttle       => Held (Integer (Flight_3D.Deadband3d_Throttle), 0, 1_000),
      Motor_Stop                 => (Features and Config_Fix.Feature_Motor_Stop) /= 0,
      Airmode_Feature            => (Features and Config_Fix.Feature_Airmode) /= 0,
      Anti_Gravity_Feature       => (Features and Config_Fix.Feature_Anti_Gravity) /= 0,
      Fixed_Wing                 =>
        Mixer_Mode in 1 .. Mixer_Init.Mixer_Mode'Pos (Mixer_Init.Mixer_Mode'Last) + 1
        and then Mixer_Init.Is_Fixed_Wing (Mixer_Init.Mixer_Mode'Val (Mixer_Mode - 1)),
      PID_At_Min_Throttle        => P.Pid_At_Min_Throttle /= 0,
      Launch_Control_Angle_Limit => Held (Integer (P.Launch_Control_Angle_Limit), 0, 90),
      Launch_Trigger_Throttle    => Held (Integer (P.Launch_Control_Throttle_Percent), 0, 100),
      Launch_Trigger_Reset       => P.Launch_Control_Allow_Trigger_Reset /= 0,
      Runaway_Prevention         => Loop_Rate.Runaway_Takeoff_Prevention /= 0,
      Runaway_Deactivate_Delay   => Held (Integer (Loop_Rate.Runaway_Takeoff_Deactivate_Delay), 100, 1_000),
      Runaway_Deactivate_Throttle => Held (Integer (Loop_Rate.Runaway_Takeoff_Deactivate_Throttle), 0, 100),
      CPU_Late_Limit             => Natural (Sch.Cpu_Late_Percentage_Limit),
      Sensors                    => Sensors);

   function Failsafe_Settings_Of (F : Failsafe_Config_Record; A : Autopilot_Config_Record) return Failsafe.Settings is
     (Throttle_Low_Delay => Held (Integer (F.Failsafe_Throttle_Low_Delay), 0, 300),
      Signal_Delay       => Held (Integer (F.Failsafe_Delay), 1, 200),
      Landing_Time       => Held (Integer (F.Failsafe_Landing_Time), 0, 250),
      Switch             => Failsafe.Switch_Mode'Val (Code (F.Failsafe_Switch_Mode, 2)),
      Action             => Failsafe.Procedure_Kind'Val (Code (F.Failsafe_Procedure, 2)),
      Recovery_Delay     => Held (Integer (F.Failsafe_Recovery_Delay), 1, 200),
      Policy             => Failsafe.Loss_Policy'Val (Code (A.Rx_Loss_Policy, 2)));

   --  The receiver source the features name, in the setup's order of
   --  precedence; the UDP source needs a build the boards do not have.
   function Source_Of (Features : Unsigned_32) return Receiver.Provider is
     (if (Features and Config_Fix.Feature_RX_Parallel_PWM) /= 0 then Receiver.Parallel_PWM
      elsif (Features and Config_Fix.Feature_RX_PPM) /= 0 then Receiver.PPM
      elsif (Features and Config_Fix.Feature_RX_Serial) /= 0 then Receiver.Serial
      elsif (Features and Config_Fix.Feature_RX_MSP) /= 0 then Receiver.MSP
      elsif (Features and Config_Fix.Feature_RX_SPI) /= 0 then Receiver.SPI
      else Receiver.None);

   function Map_Of (Rcmap : Bytes_8) return Receiver.Channel_Map;
   function Ranges_Of (Ranges : Rx_Channel_Range_Config_Record_List_4) return Receiver.Range_Configs;
   function Failsafes_Of (Failsafes : Rx_Failsafe_Channel_Config_Record_List_18) return Receiver.Failsafe_Channels;
   function Channels_Of (Mask : Unsigned_32) return Receiver.Channel_Set;

   function Receiver_Settings_Of
     (R : Rx_Config_Record; Ranges : Rx_Channel_Range_Config_Record_List_4;
      Failsafes : Rx_Failsafe_Channel_Config_Record_List_18; Flight_3D : Flight3_D_Config_Record;
      F : Failsafe_Config_Record; Features : Unsigned_32; Reported_Channels : Natural)
      return Receiver.Settings is
     (Source            => Source_Of (Features),
      Reported_Channels => Reported_Channels,
      Map               => Map_Of (R.Rcmap),
      Ranges            => Ranges_Of (Ranges),
      Failsafe          => Failsafes_Of (Failsafes),
      Min_Usec          => Held (Integer (R.Rx_Min_Usec), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Max_Usec          => Held (Integer (R.Rx_Max_Usec), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Mid_RC            => Held (Integer (R.Midrc), 1200, 1700),
      Max_Aux           =>
        Held (Integer (R.Max_Aux_Channel), 0, Receiver.Channel_Count - Receiver.Flight_Channel_Count),
      RSSI_ADC          => (Features and Config_Fix.Feature_RSSI_ADC) /= 0,
      RSSI_Channel      => Held (Integer (R.Rssi_Channel), 0, Receiver.Channel_Count),
      RSSI_Scale        => Held (Integer (R.Rssi_Scale), 1, 255),
      RSSI_Offset       => Held (Integer (R.Rssi_Offset), -100, 100),
      RSSI_Invert       => R.Rssi_Invert /= 0,
      RSSI_Smoothing    => Integer (R.Rssi_Smoothing),
      Frame_LPF_Period  => Held (Integer (R.Rssi_Src_Frame_Lpf_Period), 1, 255),
      Feature_3D        => (Features and Config_Fix.Feature_3D) /= 0,
      Switched_Mode_3D  => Flight_3D.Switched_Mode3d /= 0,
      Failsafe_Throttle => Held (Integer (F.Failsafe_Throttle), Receiver.Pulse_Min, Receiver.Pulse_Max),
      Override_Channels => Channels_Of (R.Msp_Override_Channels_Mask),
      Override_Failsafe => R.Msp_Override_Failsafe /= 0);

   function RC_Config_Of
     (R : Rx_Config_Record; Controls : Rc_Controls_Config_Record; Rate : Control_Rate_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us) return RC_Command.Config is
     (Rates     => Rate_Profile_Of (Rate),
      Receiver  => (Mid_RC               => Held (Integer (R.Midrc), 1200, 1700),
                    Min_Check            => Held (Integer (R.Mincheck), 750, 1999),
                    Smoothing            => R.Rc_Smoothing /= 0,
                    Auto_Factor_Setpoint => Held (Integer (R.Rc_Smoothing_Auto_Factor_Rpy), 0, 250),
                    Auto_Factor_Throttle => Held (Integer (R.Rc_Smoothing_Auto_Factor_Throttle), 0, 250),
                    Setpoint_Cutoff      => Integer (R.Rc_Smoothing_Setpoint_Cutoff),
                    Throttle_Cutoff      => Integer (R.Rc_Smoothing_Throttle_Cutoff)),
      Controls  => (Deadband     => Held (Integer (Controls.Deadband), 0, 32),
                    Yaw_Deadband => Held (Integer (Controls.Yaw_Deadband), 0, 100),
                    Yaw_Reversed => Controls.Yaw_Control_Reversed),
      Loop_Time => Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom));

   function Adjustment_Settings_Of (R : Rx_Config_Record; Sys : System_Config_Record) return Adjustments.Settings is
     (Mid_RC                  => Held (Integer (R.Midrc), 1200, 1700),
      Rate_Profile_6_Position => Sys.Rate_Profile6_Pos_Switch /= 0);

   function Standard_Alignment_Of (Code_Value : Unsigned_8) return Sensor_Alignment.Standard_Alignment is
     (Sensor_Alignment.Standard_Alignment'Val
        (Code (Code_Value, Sensor_Alignment.Standard_Alignment'Pos (Sensor_Alignment.Standard_Alignment'Last))));

   function Custom_Angles_Of (Angles : Integer_16_List_3) return Sensor_Alignment.Alignment_Angles is
     (Roll  => Sensor_Alignment.Decidegrees (Held (Integer (Angles (0)), -3600, 3600)),
      Pitch => Sensor_Alignment.Decidegrees (Held (Integer (Angles (1)), -3600, 3600)),
      Yaw   => Sensor_Alignment.Decidegrees (Held (Integer (Angles (2)), -3600, 3600)));

   function Board_Angles_Of (Board : Board_Alignment_Record) return Sensor_Alignment.Board_Angles is
     (Roll  => Held (Integer (Board.Roll_Degrees), -180, 360),
      Pitch => Held (Integer (Board.Pitch_Degrees), -180, 360),
      Yaw   => Held (Integer (Board.Yaw_Degrees), -180, 360));

   function Accelerometer_Settings_Of
     (A : Accelerometer_Config_Record; Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record;
      Sample_Rate_Hz : Accelerometer.Sample_Rate; One_G : Accelerometer.Counts_Per_G)
      return Accelerometer.Settings is
     (Sample_Rate_Hz => Sample_Rate_Hz,
      Lowpass_Hz     => Held (Integer (A.Acc_Lpf_Hz), 0, Accelerometer.Cutoff'Last),
      Alignment      => Standard_Alignment_Of (Device.Alignment),
      Custom_Angles  => Custom_Angles_Of (Device.Custom_Alignment),
      Board          => Board_Angles_Of (Board),
      One_G          => One_G,
      Roll_Trim      => A.Accelerometer_Trims (0),
      Pitch_Trim     => A.Accelerometer_Trims (1));

   function Attitude_Settings_Of (I : Imu_Config_Record; T : Throttle_Correction_Config_Record)
      return Attitude.Settings is
     (DCM_Kp                    => Held (Integer (I.Imu_Dcm_Kp), 0, 32_000),
      DCM_Ki                    => Held (Integer (I.Imu_Dcm_Ki), 0, 32_000),
      Small_Angle               => Held (Integer (I.Small_Angle), 0, 180),
      Throttle_Correction_Angle => Held (Integer (T.Throttle_Correction_Angle), 1, 900),
      Throttle_Correction_Value => Held (Integer (T.Throttle_Correction_Value), 0, 150),
      Mag_Declination           => Held (Integer (I.Mag_Declination), -300, 300));

   function Barometer_Settings_Of (B : Barometer_Config_Record) return Barometer.Settings is
     (Temperature_Drift_Cm_Per_10C => Held (Integer (B.Baro_Temp_Drift_Cm_Per10_C), -500, 500),
      Virtual_Device               => B.Baro_Hardware = 13);

   function Compass_Settings_Of (C : Compass_Config_Record; Board : Board_Alignment_Record) return Compass.Settings is
     (Alignment     => Standard_Alignment_Of (C.Mag_Alignment),
      Custom_Angles => Custom_Angles_Of (C.Mag_Custom_Alignment),
      Board         => Board_Angles_Of (Board),
      Zero          => (Vectors.X => Integer (C.Mag_Zero (0)), Vectors.Y => Integer (C.Mag_Zero (1)),
                        Vectors.Z => Integer (C.Mag_Zero (2))));

   function Battery_Settings_Of
     (B : Battery_Config_Record; P : Battery_Profile_Record; V : Voltage_Sensor_Adc_Config_Record;
      I : Current_Sensor_Adc_Config_Record; Virtual : Current_Sensor_Virtual_Config_Record;
      ESC : Esc_Sensor_Config_Record) return Battery.Settings is
     (Voltage_Meter                  =>
        Battery.Voltage_Source'Val
          (Code (B.Voltage_Meter_Source, Battery.Voltage_Source'Pos (Battery.Voltage_Source'Last))),
      Current_Meter                  =>
        Battery.Current_Source'Val
          (Code (B.Current_Meter_Source, Battery.Current_Source'Pos (Battery.Current_Source'Last))),
      Not_Present_Cell_Voltage       => Integer (B.Vbatnotpresentcellvoltage),
      LVC_Percentage                 => Held (Integer (B.Lvc_Percentage), 0, 100),
      Voltage_Alerts                 => B.Use_V_Bat_Alerts,
      Consumption_Alerts             => B.Use_Consumption_Alerts,
      Hysteresis                     => Integer (B.Vbathysteresis),
      Display_Filter_Period          => Held (Integer (B.Vbat_Display_Lpf_Period), 1, 255),
      Current_Filter_Period          => Held (Integer (B.Ibat_Lpf_Period), 1, 255),
      Duration_For_Warning           => Integer (B.Vbat_Duration_For_Warning),
      Duration_For_Critical          => Integer (B.Vbat_Duration_For_Critical),
      Max_Cell_Voltage               => Held (Integer (P.Vbatmaxcellvoltage), 1, 65_535),
      Min_Cell_Voltage               => Integer (P.Vbatmincellvoltage),
      Warning_Cell_Voltage           => Integer (P.Vbatwarningcellvoltage),
      Full_Cell_Voltage              => Integer (P.Vbatfullcellvoltage),
      Capacity_mAh                   => Integer (P.Battery_Capacity),
      Force_Cell_Count               => Integer (P.Force_Battery_Cell_Count),
      Consumption_Warning_Percentage => Held (Integer (P.Consumption_Warning_Percentage), 0, 100),
      Voltage_Scale                  => Integer (V.Vbatscale),
      Voltage_Divider                => Held (Integer (V.Vbatresdivval), 1, 255),
      Voltage_Multiplier             => Held (Integer (V.Vbatresdivmultiplier), 1, 255),
      Current_Scale                  => Integer (I.Scale),
      Current_Offset                 => Integer (I.Offset),
      Virtual_Scale                  => Held (Integer (Virtual.Scale), -16_000, 16_000),
      Virtual_Offset                 => Held (Integer (Virtual.Offset), 0, 16_000),
      ESC_Current_Offset             => Held (Integer (ESC.Offset), 0, 16_000));

   function Flags_Of (Mask : Unsigned_32) return Beeper.Mode_Flags;

   function Beeper_Settings_Of (B : Beeper_Config_Record) return Beeper.Settings is
     (Off_Flags        => Flags_Of (B.Beeper_Off_Flags),
      Beacon_Off_Flags => Flags_Of (B.Dshot_Beacon_Off_Flags),
      Beacon_Tone      => Held (Integer (B.Dshot_Beacon_Tone), 1, 5));

   --  The module's baud table: the stored code names the rate, the first
   --  entry stands for a code outside it.
   function Baud_Of (Code_Value : Unsigned_8) return GPS_Link.Baud_Rate is
     (case Code_Value is
         when 1 => GPS_Link.B_9600,
         when 2 => GPS_Link.B_19200,
         when 3 => GPS_Link.B_38400,
         when 4 => GPS_Link.B_57600,
         when 5 => GPS_Link.B_115200,
         when others => GPS_Link.B_230400);

   function Command_Text_Of (B : Bytes_65) return GPS_Link.Command_Text;
   function Command_Length_Of (B : Bytes_65) return GPS_Link.Command_Length;

   function GPS_Link_Settings_Of
     (G : Gps_Config_Record; R : Gps_Rescue_Record; Port_Assigned : Boolean) return GPS_Link.Settings is
     (Source            => GPS_Link.Provider'Val (Code (G.Provider, GPS_Link.Provider'Pos (GPS_Link.Provider'Last))),
      Port_Assigned     => Port_Assigned,
      Baud              => Baud_Of (G.Gps_Baud),
      Auto_Config       => G.Auto_Config /= 0,
      Sbas              =>
        UBX_Config.Sbas_Mode'Val (Code (G.Sbas_Mode, UBX_Config.Sbas_Mode'Pos (UBX_Config.Sbas_Mode'Last))),
      Sbas_Integrity    => G.Sbas_Integrity,
      Use_Galileo       => G.Gps_Ublox_Use_Galileo,
      Acquire_Model     =>
        UBX_Config.Dynamic_Model'Val
          (Code (G.Gps_Ublox_Acquire_Model, UBX_Config.Dynamic_Model'Pos (UBX_Config.Dynamic_Model'Last))),
      Flight_Model      =>
        UBX_Config.Dynamic_Model'Val
          (Code (G.Gps_Ublox_Flight_Model, UBX_Config.Dynamic_Model'Pos (UBX_Config.Dynamic_Model'Last))),
      Update_Rate       => Unsigned_8 (Held (Integer (G.Gps_Update_Rate_Hz), 1, 20)),
      UTC               =>
        UBX_Config.UTC_Standard'Val
          (Code (G.Gps_Ublox_Utc_Standard, UBX_Config.UTC_Standard'Pos (UBX_Config.UTC_Standard'Last))),
      Enable_Assistance => G.Gps_Ublox_Enable_Ana,
      Set_Home_Once     => G.Gps_Set_Home_Point_Once,
      Use_3D_Speed      => G.Gps_Use_3d_Speed,
      Commands          => Command_Text_Of (G.Nmea_Custom_Commands),
      Commands_Length   => Command_Length_Of (G.Nmea_Custom_Commands),
      Min_Sats          => Unsigned_8 (Held (Integer (R.Min_Sats), 5, 50)));

   function GPS_Rescue_Settings_Of
     (R : Gps_Rescue_Record; A : Autopilot_Config_Record; G : Gps_Config_Record) return GPS_Rescue.Settings is
     (Min_Start_Distance_M => Held (Integer (R.Min_Start_Dist_M), 5, 30),
      Mode                 => GPS_Rescue.Altitude_Mode'Val (Code (R.Altitude_Mode, 2)),
      Initial_Climb_M      => Held (Integer (R.Initial_Climb_M), 0, 100),
      Ascend_Rate          => Held (Integer (R.Ascend_Rate), 50, 2_500),
      Return_Altitude_M    => Held (Integer (R.Return_Altitude_M), 5, 1_000),
      Ground_Speed_Cms     => Held (Integer (R.Ground_Speed_Cm_S), 0, 3_000),
      Descent_Distance_M   => Held (Integer (R.Descent_Distance_M), 5, 500),
      Descend_Rate         => Held (Integer (R.Descend_Rate), 25, 500),
      Sanity               => GPS_Rescue.Sanity_Checks'Val (Code (R.Sanity_Checks, 2)),
      Min_Sats             => Held (Integer (R.Min_Sats), 5, 50),
      Landing_Altitude_M   => Integer (A.Landing_Altitude_M),
      Set_Home_Once        => G.Gps_Set_Home_Point_Once);

   function Position_Control_Settings_Of
     (A : Autopilot_Config_Record; Controls : Rc_Controls_Config_Record; Rescue_Plan : Boolean)
      return Position_Control.Settings is
     (Position_P           => Held (Integer (A.Position_P), 0, 200),
      Position_I           => Held (Integer (A.Position_I), 0, 200),
      Position_D           => Held (Integer (A.Position_D), 0, 200),
      Position_A           => Held (Integer (A.Position_A), 0, 200),
      Position_F           => Held (Integer (A.Position_F), 0, 200),
      Position_Cutoff      => Held (Integer (A.Position_Cutoff), 10, 50),
      Stop_Threshold       => Held (Integer (A.Stop_Threshold), 5, 50),
      Max_Angle            => Held (Integer (A.Max_Angle), 10, 70),
      Drag_Coefficient     => Held (Integer (A.Velocity_Drag_Coeff), 0, 100),
      Max_Velocity         => Held (Integer (A.Max_Velocity), 100, 5_000),
      Stick_Deadband       => Held (Integer (A.Stick_Deadband), 0, 500),
      Yaw_P                => Held (Integer (A.Yaw_P), 0, 200),
      Max_Yaw_Rate         => Held (Integer (A.Max_Yaw_Rate), 10, 250),
      Yaw_Reversed         => Controls.Yaw_Control_Reversed,
      Nav_Yaw_Mode         =>
        Position_Control.Yaw_Mode'Val
          (Code (A.Yaw_Mode, Position_Control.Yaw_Mode'Pos (Position_Control.Yaw_Mode'Last))),
      Min_Forward_Velocity => Held (Integer (A.Min_Forward_Velocity), 10, 500),
      Buildup_Max_Pitch    => Held (Integer (A.Velocity_Buildup_Max_Pitch), 0, 20),
      Rescue_Plan          => Rescue_Plan);

   function Position_Estimator_Settings_Of
     (P : Position_Config_Record; H : Pos_Hold_Config_Record) return Position_Estimator.Settings is
     (Source         =>
        Position_Estimator.Altitude_Source'Val
          (Code (P.Altitude_Source,
                 Position_Estimator.Altitude_Source'Pos (Position_Estimator.Altitude_Source'Last))),
      Prefer_Baro    => Held (Integer (P.Altitude_Prefer_Baro), 0, 100),
      Altitude_LPF   => Held (Integer (P.Altitude_Lpf), 10, 5_000),
      Derivative_LPF => Held (Integer (P.Altitude_D_Lpf), 10, 5_000),
      Horizontal     =>
        Position_Estimator.Horizontal_Source'Val
          (Code (H.Position_Source,
                 Position_Estimator.Horizontal_Source'Pos (Position_Estimator.Horizontal_Source'Last))));

   function Position_Hold_Settings_Of (H : Pos_Hold_Config_Record) return Position_Hold.Settings is
     (Deadband => Held (Integer (H.Deadband), 0, 50));

   function Altitude_Control_Settings_Of
     (A : Autopilot_Config_Record; R : Rx_Config_Record) return Altitude_Control.Settings is
     (Hover_Throttle => Held (Integer (A.Hover_Throttle), 0, 1_700),
      Throttle_Min   => Held (Integer (A.Throttle_Min), 1_050, 1_400),
      Throttle_Max   => Held (Integer (A.Throttle_Max), 1_400, 2_000),
      Altitude_P     => Held (Integer (A.Altitude_P), 0, 200),
      Altitude_I     => Held (Integer (A.Altitude_I), 0, 200),
      Altitude_D     => Held (Integer (A.Altitude_D), 0, 200),
      Altitude_A     => Held (Integer (A.Altitude_A), 0, 200),
      Altitude_F     => Held (Integer (A.Altitude_F), 0, 200),
      Min_Check      => Held (Integer (R.Mincheck), 750, 1_999));

   function Altitude_Hold_Settings_Of
     (A : Autopilot_Config_Record; H : Alt_Hold_Config_Record; R : Rx_Config_Record) return Altitude_Hold.Settings is
     (Hover_Throttle => Held (Integer (A.Hover_Throttle), 0, 1_700),
      Throttle_Min   => Held (Integer (A.Throttle_Min), 1_050, 1_400),
      Throttle_Max   => Held (Integer (A.Throttle_Max), 1_400, 2_000),
      Altitude_P     => Held (Integer (A.Altitude_P), 0, 200),
      Altitude_I     => Held (Integer (A.Altitude_I), 0, 200),
      Altitude_D     => Held (Integer (A.Altitude_D), 0, 200),
      Altitude_A     => Held (Integer (A.Altitude_A), 0, 200),
      Altitude_F     => Held (Integer (A.Altitude_F), 0, 200),
      Climb_Rate     => Held (Integer (H.Climb_Rate), 0, 200),
      Deadband       => Held (Integer (H.Deadband), 0, 70),
      Min_Check      => Held (Integer (R.Mincheck), 750, 1_999));

   function Flight_Plan_Settings_Of
     (A : Autopilot_Config_Record; Rescue : Gps_Rescue_Record; H : Alt_Hold_Config_Record; Wing : Boolean)
      return Flight_Plan_Nav.Settings is
     (Max_Angle       => Unsigned_8 (Held (Integer (A.Max_Angle), 10, 70)),
      Arrival_Radius  => Unsigned_16 (Held (Integer (A.Waypoint_Arrival_Radius), 100, 5_000)),
      Radius          => Unsigned_16 (Held (Integer (A.Waypoint_Hold_Radius), 50, 1_000)),
      Max_Speed       => Unsigned_16 (Held (Integer (A.Max_Velocity), 100, 5_000)),
      Nav_Accel       => Unsigned_16 (Held (Integer (A.Nav_Accel), 20, 1_000)),
      Landing_Rate    => Unsigned_8 (Held (Integer (A.Landing_Descent_Rate), 10, 200)),
      Climb_Rate      => (if Wing then 0.0 else Float (H.Climb_Rate) * 10.0),
      Corner_Speed    => Unsigned_16 (Held (Integer (A.Nav_Corner_Speed), 50, 2_000)),
      Corner_Delta_V  => Unsigned_16 (Held (Integer (A.Nav_Corner_Delta_V), 100, 4_000)),
      Nav_Decel       => Unsigned_16 (Held (Integer (A.Nav_Decel), 20, 1_000)),
      Lead_Time       => Unsigned_8 (Held (Integer (A.Nav_Carrot_Lead_Time), 2, 40)),
      Lead_Max        => Unsigned_16 (Held (Integer (A.Nav_Carrot_Lead_Max), 600, 6_000)),
      Preturn_Dist    => Unsigned_16 (Held (Integer (A.Nav_Preturn_Dist), 500, 5_000)),
      Yaw_Mode        => Unsigned_8 (Code (A.Yaw_Mode, 4)),
      Touchdown_Cms   => Unsigned_8 (Held (Integer (A.Landing_Velocity_Threshold), 10, 200)),
      Touchdown_Ds    => Unsigned_8 (Held (Integer (A.Landing_Detection_Time), 5, 50)),
      Descent_Dist_M  => Unsigned_16 (Held (Integer (Rescue.Descent_Distance_M), 5, 500)),
      Fence_M         => Unsigned_16 (Held (Integer (A.Max_Distance_From_Home_M), 0, 10_000)),
      Fence_Return    => A.Geofence_Action /= 0,
      Return_Alt_M    => Unsigned_16 (Held (Integer (Rescue.Return_Altitude_M), 5, 1_000)),
      Return_Cms      => Unsigned_16 (Held (Integer (Rescue.Ground_Speed_Cm_S), 0, 3_000)),
      Min_Start_M     => Unsigned_16 (Held (Integer (Rescue.Min_Start_Dist_M), 5, 30)),
      Initial_Climb_M => Unsigned_16 (Held (Integer (Rescue.Initial_Climb_M), 0, 100)),
      Ascend_Cms      => Unsigned_16 (Held (Integer (Rescue.Ascend_Rate), 50, 2_500)),
      Descend_Cms     => Unsigned_16 (Held (Integer (Rescue.Descend_Rate), 25, 500)),
      Rescue_Alt_Mode => Unsigned_8 (Code (Rescue.Altitude_Mode, 2)));

   function Blackbox_Settings_Of (B : Blackbox_Config_Record; Wing : Boolean) return Blackbox.Settings is
     (Fields_Disabled_Mask => B.Fields_Disabled_Mask,
      Sample_Rate          => Integer (B.Sample_Rate),
      Device               =>
        Blackbox_Header.Device_Kind'Val
          (Code (B.Device, Blackbox_Header.Device_Kind'Pos (Blackbox_Header.Device_Kind'Last))),
      Mode                 => Blackbox.Log_Mode'Val (Code (B.Mode, Blackbox.Log_Mode'Pos (Blackbox.Log_Mode'Last))),
      High_Resolution      => B.High_Resolution /= 0,
      Serial_Fast_Baud     => B.Blackbox_Baud in 12 .. 15,
      Wing                 => Wing);

   function Scheduler_Settings_Of
     (S : Scheduler_Config_Record; Cycles_Per_Us : Positive; Delay_Limit_Us : Scheduler.Delay_Limit;
      Gyro_Period_Us : Scheduler.Period_Us) return Scheduler.Settings is
     (Cycles_Per_Us  => Cycles_Per_Us,
      Rx_Relax       => Integer (S.Rx_Relax_Determinism),
      OSD_Relax      => Integer (S.Osd_Relax_Determinism),
      Delay_Limit_Us => Delay_Limit_Us,
      Gyro_Period_Us => Gyro_Period_Us);

   function Palette_Of (Colors : Hsv_Color_Record_List_16) return LED_Strip.Palette;
   function Mode_Colors_Of (Modes : Mode_Color_Indexes_Record_List_6) return LED_Strip.Mode_Colors;
   function Special_Colors_Of (Specials : Special_Color_Indexes_Record) return LED_Strip.Special_Colors;

   function LED_Strip_Settings_Of
     (L : Led_Strip_Config_Record; M : Led_Strip_Status_Mode_Config_Record) return LED_Strip.Settings is
     (Visual_Beeper       => L.Ledstrip_Visual_Beeper /= 0,
      Prof                =>
        LED_Strip.Profile'Val (Code (L.Ledstrip_Profile, LED_Strip.Profile'Pos (LED_Strip.Profile'Last))),
      Race_Color          => Held (Integer (L.Ledstrip_Race_Color), 0, LED_Strip.Named_Color'Last),
      Beacon_Color        => Held (Integer (L.Ledstrip_Beacon_Color), 0, LED_Strip.Named_Color'Last),
      Beacon_Period       => Unsigned_16 (Held (Integer (L.Ledstrip_Beacon_Period_Ms), 1, 65_535)),
      Beacon_Percent      => L.Ledstrip_Beacon_Percent,
      Visual_Beeper_Color => Held (Integer (L.Ledstrip_Visual_Beeper_Color), 0, LED_Strip.Named_Color'Last),
      Brightness          => Unsigned_8 (Held (Integer (L.Ledstrip_Brightness), 0, 100)),
      Rainbow_Delta       => L.Ledstrip_Rainbow_Delta,
      Rainbow_Freq        => L.Ledstrip_Rainbow_Freq,
      Leds                => LED_Strip.Led_Configs (M.Led_Configs),
      Colors              => Palette_Of (M.Colors),
      Modes               => Mode_Colors_Of (M.Mode_Colors),
      Specials            => Special_Colors_Of (M.Special_Colors),
      Aux_Channel         => Held (Integer (M.Ledstrip_Aux_Channel), 0, LED_Strip.Channel_Index'Last));

   function VTX_Settings_Of (V : Vtx_Settings_Config_Record) return VTX.Settings is
     (Band           => V.Band,
      Channel        => V.Channel,
      Power          => V.Power,
      Freq           => V.Freq,
      Pit_Mode_Freq  => V.Pit_Mode_Freq,
      Low_Power      =>
        VTX.Low_Power_Disarm'Val (Code (V.Low_Power_Disarm, VTX.Low_Power_Disarm'Pos (VTX.Low_Power_Disarm'Last))),
      Softserial_Alt => V.Softserial_Alt /= 0);

   function Flight_Stats_Settings_Of (S : Stats_Config_Record) return Flight_Stats.Settings is
     (Min_Armed_Time_S => S.Stats_Min_Armed_Time_S, Save_Move_Limit => S.Stats_Save_Move_Limit);

   function Lap_Timer_Settings_Of (G : Gps_Lap_Timer_Config_Record) return GPS_Lap_Timer.Settings is
     (Gate_Lat           => G.Gate_Lat,
      Gate_Lon           => G.Gate_Lon,
      Minimum_Lap_Time_S => G.Minimum_Lap_Time_Seconds,
      Gate_Tolerance_M   => G.Gate_Tolerance_M);

   function Rangefinder_Settings_Of
     (P : Position_Config_Record; Cone_Extended_Decidegrees : Rangefinder.Decidegrees) return Rangefinder.Settings is
     (Max_Range_Cm              =>
        Integer_16 (Held (Integer (P.Rangefinder_Max_Range_Cm), 0, Integer (Integer_16'Last))),
      Cone_Extended_Decidegrees => Cone_Extended_Decidegrees);

   function Optical_Flow_Settings_Of (O : Opticalflow_Config_Record) return Optical_Flow.Settings is
     (Rotation_Degrees => O.Rotation, Flip_X => O.Flip_X /= 0);

   function Pitot_Settings_Of (P : Pitot_Config_Record) return Pitot.Settings is
     (Hardware => Pitot.Source'Val (Code (P.Pitot_Hardware, Pitot.Source'Pos (Pitot.Source'Last))));

   function Gimbal_Gain (V : Integer_8) return Gimbal_Control.Gain is (Held (Integer (V), -100, 100));
   function Gimbal_Limit (V : Integer_8) return Gimbal_Control.Limit is (Held (Integer (V), 0, 100));

   function Gimbal_Settings_Of
     (G : Gimbal_Track_Config_Record; R : Rx_Config_Record; Port_Configured : Boolean) return Gimbal_Control.Settings is
     (Port_Configured        => Port_Configured,
      Roll_RC_Gain           => Gimbal_Gain (G.Gimbal_Roll_Rc_Gain),
      Pitch_RC_Throttle_Gain => Gimbal_Gain (G.Gimbal_Pitch_Rc_Thr_Gain),
      Pitch_RC_Low_Gain      => Gimbal_Gain (G.Gimbal_Pitch_Rc_Low_Gain),
      Pitch_RC_High_Gain     => Gimbal_Gain (G.Gimbal_Pitch_Rc_High_Gain),
      Yaw_RC_Gain            => Gimbal_Gain (G.Gimbal_Yaw_Rc_Gain),
      Roll_Gain              => Gimbal_Gain (G.Gimbal_Roll_Gain),
      Roll_Offset            => Gimbal_Gain (G.Gimbal_Roll_Offset),
      Roll_Limit             => Gimbal_Limit (G.Gimbal_Roll_Limit),
      Pitch_Gain             => Gimbal_Gain (G.Gimbal_Pitch_Gain),
      Pitch_Offset           => Gimbal_Gain (G.Gimbal_Pitch_Offset),
      Pitch_Low_Limit        => Gimbal_Limit (G.Gimbal_Pitch_Low_Limit),
      Pitch_High_Limit       => Gimbal_Limit (G.Gimbal_Pitch_High_Limit),
      Yaw_Gain               => Gimbal_Gain (G.Gimbal_Yaw_Gain),
      Yaw_Offset             => Gimbal_Gain (G.Gimbal_Yaw_Offset),
      Yaw_Limit              => Gimbal_Limit (G.Gimbal_Yaw_Limit),
      Stabilisation          => Held (Integer (G.Gimbal_Stabilisation), 0, 7),
      Sensitivity            => Held (Integer (G.Gimbal_Sensitivity), -16, 15),
      Mid_RC                 => Held (Integer (R.Midrc), 1200, 1700));

   function RTC_Settings_Of (T : Time_Config_Record) return RTC.Settings is
     (Zone => Integer_16 (Held (Integer (T.Tz_Offset_Minutes), -780, 780)));

   function Stat_Set_Of (Mask : Unsigned_32) return OSD_Stats.Stat_Set;
   function Warning_Set_Of (Mask : Unsigned_32) return OSD_Warnings.Warning_Set;
   function Names_Of (P : Bytes_17_List_3) return OSD_Render.Profile_Names;
   function RC_Channels_Of (R : Integer_8_List_4) return OSD_Render.RC_Channel_Settings;

   function Unit_System_Of (Code_Value : Unsigned_8) return OSD_Format.Unit_System is
     (OSD_Format.Unit_System'Val (Code (Code_Value, OSD_Format.Unit_System'Pos (OSD_Format.Unit_System'Last))));

   function Timers_Of (T : Unsigned_16_List_2) return OSD_Elements.Timer_Settings is (0 => T (0), 1 => T (1));

   function Item_Visible (E : Osd_Element_Config_Record; I : OSD_Elements.Item; Profile_Code : Unsigned_8)
     return Boolean is
     (OSD_Elements.Visible_In_Profile (E.Item_Pos (OSD_Elements.Item'Pos (I)), Held (Integer (Profile_Code), 1, 3)));

   function OSD_Page_Settings_Of
     (O : Osd_Config_Record; E : Osd_Element_Config_Record; Logo_Supported : Boolean) return OSD_Page.Settings is
     (Rows                 => O.Canvas_Rows,
      Cols                 => O.Canvas_Cols,
      Enabled              => Stat_Set_Of (O.Enabled_Stats),
      Logo_On_Arming       => Held (Integer (O.Logo_On_Arming), 0, 2),
      Logo_Duration_Tenths => O.Logo_On_Arming_Duration,
      Arming_Logo          => Held (Integer (O.Arming_Logo), 0, OSD_Page.Font'Last),
      Logo_Supported       => Logo_Supported,
      Aux_Scale            => O.Aux_Scale,
      Aux_Visible          => Item_Visible (E, OSD_Elements.Aux_Value, O.Osd_Profile_Index),
      G_Force_Visible      => Item_Visible (E, OSD_Elements.G_Force, O.Osd_Profile_Index),
      Warnings_Visible     => Item_Visible (E, OSD_Elements.Warnings, O.Osd_Profile_Index));

   function OSD_Render_Settings_Of
     (O : Osd_Config_Record; V : Vtx_Settings_Config_Record; N : Osd_Nav_Map_Config_Record)
      return OSD_Render.Settings is
     (Units                => Unit_System_Of (O.Units),
      Alt_Alarm            => O.Alt_Alarm,
      Cap_Alarm            => O.Cap_Alarm,
      RSSI_Alarm           => O.Rssi_Alarm,
      RSSI_Dbm_Alarm       => O.Rssi_Dbm_Alarm,
      Timers               => Timers_Of (O.Timers),
      Aux_Symbol           => O.Aux_Symbol,
      Link_Quality_Alarm   => O.Link_Quality_Alarm,
      Show_PDOP            => O.Gps_Sats_Show_Pdop /= 0,
      OSD_Profile_Index    => Held (Integer (O.Osd_Profile_Index), 1, 3),
      OSD_Profile_Names    => Names_Of (O.Profile),
      Framerate_Hz         => Unsigned_16 (Held (Integer (O.Framerate_Hz), 1, 60)),
      AH_Max_Pitch         => O.Ah_Max_Pitch,
      AH_Max_Roll          => O.Ah_Max_Roll,
      AH_Invert            => O.Ah_Invert /= 0,
      Overlay_Radio_Mode   => Held (Integer (O.Overlay_Radio_Mode), 1, 4),
      RC_Channels          => RC_Channels_Of (O.Rc_Channels),
      Camera_Frame_Width   => O.Camera_Frame_Width,
      Camera_Frame_Height  => O.Camera_Frame_Height,
      VTX_Band             => V.Band,
      VTX_Channel          => V.Channel,
      VTX_Frequency        => V.Freq,
      VTX_Power            => V.Power,
      VTX_Low_Power_Disarm => V.Low_Power_Disarm,
      Nav_Map              =>
        (Heading_Up => N.Mode = 1, Centre_Craft => N.Centre = 1, Min_Scale_M => N.Min_Scale_M,
         Units      => Unit_System_Of (O.Units)));

   function OSD_Spec_Settings_Of
     (M : Mixer_Config_Record; Motor : Motor_Config_Record; Rate : Control_Rate_Config_Record;
      P : Pid_Profile_Record; B : Battery_Profile_Record) return OSD_Spec.Settings is
     (RPM_Limit              => M.Rpm_Limit,
      RPM_Limit_Value        => M.Rpm_Limit_Value,
      RPM_Limit_P            => M.Rpm_Limit_P,
      RPM_Limit_I            => M.Rpm_Limit_I,
      RPM_Limit_D            => M.Rpm_Limit_D,
      KV                     => Motor.Kv,
      Pole_Count             => Motor.Motor_Pole_Count,
      Throttle_Limit         => Code (Rate.Throttle_Limit_Type, OSD_Spec.Throttle_Limit_Kind'Last),
      Throttle_Limit_Percent => Rate.Throttle_Limit_Percent,
      Motor_Output_Limit     => P.Motor_Output_Limit,
      Min_Cell               => B.Vbatmincellvoltage,
      Max_Cell               => B.Vbatmaxcellvoltage);

   function OSD_Warnings_Settings_Of (O : Osd_Config_Record) return OSD_Warnings.Settings is
     (Enabled            => Warning_Set_Of (O.Enabled_Warnings),
      Units              => Unit_System_Of (O.Units),
      RSSI_Alarm         => Held (Integer (O.Rssi_Alarm), 0, 100),
      RSSI_Dbm_Alarm     => Held (Integer (O.Rssi_Dbm_Alarm), -130, 0),
      RSNR_Alarm         => Held (Integer (O.Rsnr_Alarm), -30, 20),
      Link_Quality_Alarm => Held (Integer (O.Link_Quality_Alarm), 0, 100),
      Core_Temp_Alarm    => Integer (O.Core_Temp_Alarm),
      Cap_Alarm          => Held (Integer (O.Cap_Alarm), 0, 20_000),
      ESC_RPM_Alarm      => Held (Integer (O.Esc_Rpm_Alarm), OSD_Warnings.Alarm_Off, 32_767),
      ESC_Current_Alarm  => Held (Integer (O.Esc_Current_Alarm), OSD_Warnings.Alarm_Off, 32_767),
      ESC_Temp_Alarm     => Integer (O.Esc_Temp_Alarm));

   function OSD_Alarm_Settings_Of (O : Osd_Config_Record; R : Gps_Rescue_Record) return OSD_Elements.Alarm_Settings is
     (Units              => Unit_System_Of (O.Units),
      RSSI_Alarm         => O.Rssi_Alarm,
      RSSI_Dbm_Alarm     => O.Rssi_Dbm_Alarm,
      Link_Quality_Alarm => O.Link_Quality_Alarm,
      Timers             => Timers_Of (O.Timers),
      Cap_Alarm          => O.Cap_Alarm,
      Alt_Alarm          => O.Alt_Alarm,
      Distance_Alarm     => O.Distance_Alarm,
      ESC_Temp_Alarm     => O.Esc_Temp_Alarm,
      Rescue_Min_Sats    => R.Min_Sats);

   function Hub_Sensors_Of (Disabled : Unsigned_32) return FrSky_Hub_Telemetry.Sensor_Set;

   --  Whether a sensor's telemetry is on: its bit in the disabled mask is
   --  clear.
   function Sensor_On (Disabled : Unsigned_32; Bit : Natural) return Boolean is
     ((Disabled and Shift_Left (1, Bit)) = 0)
     with Pre => Bit < 32;

   function FrSky_Hub_Settings_Of
     (T : Telemetry_Config_Record; Motor : Motor_Config_Record; Sensors : Arming.Sensor_Set;
      Altitude_Present : Boolean; GPS_Present : Boolean; Acc_1G_Rec : FrSky_Hub_Telemetry.Gravity_Scale)
      return FrSky_Hub_Telemetry.Settings is
     (Enabled             => Hub_Sensors_Of (T.Disabled_Sensors),
      Format              =>
        FrSky_Hub_Telemetry.Coordinate_Format'Val
          (Code (T.Frsky_Coordinate_Format,
                 FrSky_Hub_Telemetry.Coordinate_Format'Pos (FrSky_Hub_Telemetry.Coordinate_Format'Last))),
      Unit                =>
        FrSky_Hub_Telemetry.Units'Val
          (Code (T.Frsky_Unit, FrSky_Hub_Telemetry.Units'Pos (FrSky_Hub_Telemetry.Units'Last))),
      Precision           =>
        FrSky_Hub_Telemetry.VFAS_Precision'Val
          (Code (T.Frsky_Vfas_Precision,
                 FrSky_Hub_Telemetry.VFAS_Precision'Pos (FrSky_Hub_Telemetry.VFAS_Precision'Last))),
      Report_Cell_Voltage => T.Report_Cell_Voltage /= 0,
      No_Fix_Latitude     => Integer_16 (Held (Integer (T.Gps_No_Fix_Latitude), -18_000, 18_000)),
      No_Fix_Longitude    => Integer_16 (Held (Integer (T.Gps_No_Fix_Longitude), -18_000, 18_000)),
      Acc_Present         => Sensors.Acc,
      Altitude_Present    => Altitude_Present,
      GPS_Present         => GPS_Present,
      Mag_Present         => Sensors.Mag,
      Pole_Count          => Motor.Motor_Pole_Count,
      Acc_1G_Rec          => Acc_1G_Rec);

   function GHST_Settings_Of
     (T : Telemetry_Config_Record; B : Battery_Config_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return GHST_Telemetry.Settings is
     (Voltage_Enabled      => Sensor_On (T.Disabled_Sensors, 0),
      Current_Enabled      => Sensor_On (T.Disabled_Sensors, 1),
      Fuel_Enabled         => Sensor_On (T.Disabled_Sensors, 2),
      Altitude_Enabled     => Sensor_On (T.Disabled_Sensors, 10),
      Lat_Long_Enabled     => Sensor_On (T.Disabled_Sensors, 12),
      Ground_Speed_Enabled => Sensor_On (T.Disabled_Sensors, 13),
      Heading_Enabled      => Sensor_On (T.Disabled_Sensors, 9),
      Report_Cell_Voltage  => T.Report_Cell_Voltage /= 0,
      Voltage_Configured   => B.Voltage_Meter_Source /= 0,
      Amperage_Configured  => B.Current_Meter_Source /= 0,
      GPS_Feature          => (Features and Config_Fix.Feature_GPS) /= 0,
      Baro_Present         => Sensors.Baro,
      Mag_Present          => Sensors.Mag);

   function CRSF_Config_Of
     (T : Telemetry_Config_Record; R : Rx_Config_Record; B : Battery_Config_Record; Features : Unsigned_32;
      Sensors : Arming.Sensor_Set; Event_Driven : Boolean) return CRSF_Telemetry.Config is
     (Acc_Present         => Sensors.Acc,
      Baro_Present        => Sensors.Baro,
      Mag_Present         => Sensors.Mag,
      Gyro_Present        => Sensors.Gyro,
      Disabled_Kinds      => T.Disabled_Sensors,
      Voltage_Configured  => B.Voltage_Meter_Source /= 0,
      Amperage_Configured => B.Current_Meter_Source /= 0,
      GPS_Feature         => (Features and Config_Fix.Feature_GPS) /= 0,
      Telemetry_Feature   => (Features and Config_Fix.Feature_Telemetry) /= 0,
      Inertial_Frames     => T.Crsf_Tlm_Accgyro /= 0,
      Event_Driven        => Event_Driven,
      Use_Negotiated_Baud => R.Crsf_Use_Negotiated_Baud /= 0);

   function HoTT_Settings_Of (T : Telemetry_Config_Record; GPS_Present : Boolean) return HoTT_Telemetry.Settings is
     (Alarm_Interval_S => T.Hott_Alarm_Sound_Interval, GPS_Present => GPS_Present);

   function IBus_Settings_Of
     (T : Telemetry_Config_Record; Acc_1G_Rec : IBus_Telemetry.Gravity_Scale) return IBus_Telemetry.Settings is
     (Sensors             => IBus_Telemetry.Sensor_Table (T.Flysky_Sensors),
      Report_Cell_Voltage => T.Report_Cell_Voltage /= 0,
      Acc_1G_Rec          => Acc_1G_Rec);

   function Jeti_Settings_Of
     (B : Battery_Config_Record; Sys : System_Config_Record; Features : Unsigned_32; Sensors : Arming.Sensor_Set)
      return Jeti_Telemetry.Settings is
     (Voltage_Meter => B.Voltage_Meter_Source /= 0,
      Current_Meter => B.Current_Meter_Source /= 0,
      Baro          => Sensors.Baro,
      Acc           => Sensors.Acc,
      Mag           => Sensors.Mag,
      GPS_Feature   => (Features and Config_Fix.Feature_GPS) /= 0,
      ESC_Feature   => (Features and Config_Fix.Feature_ESC_Sensor) /= 0,
      Debug_Mode    => Sys.Debug_Mode /= 0);

   function MAVLink_Settings_Of (T : Telemetry_Config_Record) return MAVLink_Telemetry.Settings is
     (Rates               => (MAVLink_Telemetry.Extended_Status => T.Mavlink_Extended_Status_Rate,
                              MAVLink_Telemetry.RC_Channels     => T.Mavlink_Rc_Channels_Rate,
                              MAVLink_Telemetry.Position        => T.Mavlink_Position_Rate,
                              MAVLink_Telemetry.Extra1          => T.Mavlink_Extra1_Rate,
                              MAVLink_Telemetry.Extra2          => T.Mavlink_Extra2_Rate,
                              MAVLink_Telemetry.Extra3          => T.Mavlink_Extra3_Rate),
      MAh_Heading_Divisor => T.Mavlink_Mah_As_Heading_Divisor,
      Report_Cell_Voltage => T.Report_Cell_Voltage /= 0);

   function SRXL_Settings_Of (T : Telemetry_Config_Record; Features : Unsigned_32) return SRXL_Telemetry.Settings is
     (Report_Cell_Voltage => T.Report_Cell_Voltage /= 0, GPS_Feature => (Features and Config_Fix.Feature_GPS) /= 0);

   function Radio_Pins_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return SPI_Radio.Pins is
     (Chip_Detect   => C.Chip_Detect_Enabled /= 0,
      Tx_Enable     => C.Tx_En_Io_Tag /= 0,
      LNA           => C.Lna_En_Io_Tag /= 0,
      Antenna       => C.Ant_Sel_Io_Tag /= 0,
      LED           => S.Led_Io_Tag /= 0,
      LED_Inversion => S.Led_Inversion /= 0,
      Bind          => S.Bind_Io_Tag /= 0);

   function ExpressLRS_Settings_Of (E : Rx_Express_Lrs_Spi_Config_Record) return ExpressLRS_Receiver.Settings is
     (Domain   =>
        ExpressLRS.Frequency_Domain'Val
          (Code (E.Domain, ExpressLRS.Frequency_Domain'Pos (ExpressLRS.Frequency_Domain'Last))),
      Rate     => Held (Integer (E.Rate_Index), 0, ExpressLRS.Rate_Index'Last),
      UID      => ExpressLRS_Receiver.UID_Bytes (E.Uid),
      Model_Id => E.Model_Id);

   --  The FrSky SPI protocols by their SPI protocol codes.
   function FrSky_Protocol_Of (Code_Value : Unsigned_8) return FrSky_SPI.SPI_Protocol is
     (case Code_Value is
         when 9 => FrSky_SPI.FrSky_X,
         when 15 => FrSky_SPI.FrSky_X_LBT,
         when 17 => FrSky_SPI.FrSky_X_V2,
         when 18 => FrSky_SPI.FrSky_X_LBT_V2,
         when others => FrSky_SPI.FrSky_D);

   function FrSky_SPI_Settings_Of
     (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; Features : Unsigned_32;
      Hub : FrSky_Hub_Telemetry.Settings) return FrSky_SPI.Settings is
     (Protocol      => FrSky_Protocol_Of (S.Rx_Spi_Protocol),
      Auto_Bind     => C.Auto_Bind /= 0,
      Bind_Tx_Id    => (0 => C.Bind_Tx_Id (0), 1 => C.Bind_Tx_Id (1), 2 => C.Bind_Tx_Id (2)),
      Bind_Offset   => C.Bind_Offset,
      Bind_Hop_Data => FrSky_SPI.Hop_Table (C.Bind_Hop_Data),
      Rx_Num        => C.Rx_Num,
      A1            =>
        FrSky_SPI.A1_Source'Val (Code (C.A1_Source, FrSky_SPI.A1_Source'Pos (FrSky_SPI.A1_Source'Last))),
      Pins          => Radio_Pins_Of (S, C),
      Telemetry     => (Features and Config_Fix.Feature_Telemetry) /= 0,
      Hub           => Hub);

   function Redpine_Settings_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return Redpine.Settings is
     (Auto_Bind     => C.Auto_Bind /= 0,
      Bind_Tx_Id    => (0 => C.Bind_Tx_Id (0), 1 => C.Bind_Tx_Id (1)),
      Bind_Offset   => C.Bind_Offset,
      Bind_Hop_Data => Redpine.Hop_Table (C.Bind_Hop_Data),
      Pins          => Radio_Pins_Of (S, C));

   function SFHSS_Settings_Of (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record) return SFHSS.Settings is
     (Bind_Tx_Id  => (0 => C.Bind_Tx_Id (0), 1 => C.Bind_Tx_Id (1)),
      Bind_Offset => C.Bind_Offset,
      Pins        => Radio_Pins_Of (S, C));

   function FlySky_Settings_Of
     (S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; F : Fly_Sky_Config_Record) return FlySky.Settings is
     (Protocol    => (if S.Rx_Spi_Protocol = 11 then FlySky.AFHDS_2A else FlySky.AFHDS),
      Tx_Id       => F.Tx_Id,
      Rf_Map      => FlySky.Channel_Map (F.Rf_Channel_Map),
      Receiver_Id => S.Rx_Spi_Id,
      Pins        => Radio_Pins_Of (S, C));

   function Spektrum_Settings_Of
     (R : Rx_Config_Record; Features : Unsigned_32; Telemetry_Port : Boolean) return Spektrum.Settings is
     (Kind         =>
        (case R.Serialrx_Provider is
            when 15 => Spektrum.Spektrum_1024,
            when 10 => Spektrum.SRXL,
            when others => Spektrum.Spektrum_2048),
      Telemetry    => (Features and Config_Fix.Feature_Telemetry) /= 0 and then Telemetry_Port,
      RSSI_Channel => Spektrum.Byte (R.Rssi_Channel));

   function Spektrum_SPI_Settings_Of
     (K : Spektrum_Config_Record; S : Rx_Spi_Config_Record; C : Rx_Cc2500_Spi_Config_Record; Features : Unsigned_32)
      return Spektrum_SPI.Settings is
     (Protocol     => K.Protocol,
      Mfg_Id       => Spektrum_SPI.Manufacturer_Id (K.Mfg_Id),
      Num_Channels => K.Num_Channels,
      Telemetry    => (Features and Config_Fix.Feature_Telemetry) /= 0,
      Pins         => Radio_Pins_Of (S, C));

   function SRXL2_Settings_Of (R : Rx_Config_Record) return SRXL2.Settings is
     (Unit_Id => Natural (R.Srxl2_Unit_Id), Baud_Fast => Natural (R.Srxl2_Baud_Fast));

   function Gyro_Settings_Of
     (G : Gyro_Config_Record; N : Dyn_Notch_Config_Record; R : Rpm_Filter_Config_Record;
      Device : Gyro_Device_Config_Record; Board : Board_Alignment_Record; Motor : Motor_Config_Record;
      Loop_Rate : Pid_Config_Record; Sample_Time_Us : PID_Config.Loop_Time_Us; Scale : Float;
      Motors : Mixer.Motor_Count; Overflow_Protected : Boolean) return Gyro_Filters.Settings is
     (LPF1_Type          => Lowpass_Kind'Val (Code (G.Gyro_Lpf1_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      LPF1_Static_Hz     => Held (Integer (G.Gyro_Lpf1_Static_Hz), 0, 1000),
      LPF1_Dyn_Min_Hz    => Held (Integer (G.Gyro_Lpf1_Dyn_Min_Hz), 0, 1000),
      LPF1_Dyn_Max_Hz    => Held (Integer (G.Gyro_Lpf1_Dyn_Max_Hz), 0, 1000),
      LPF1_Dyn_Expo      => Held (Integer (G.Gyro_Lpf1_Dyn_Expo), 0, 10),
      LPF2_Type          => Lowpass_Kind'Val (Code (G.Gyro_Lpf2_Type, Lowpass_Kind'Pos (Lowpass_Kind'Last))),
      LPF2_Static_Hz     => Held (Integer (G.Gyro_Lpf2_Static_Hz), 0, 1000),
      Notch1_Hz          => Held (Integer (G.Gyro_Soft_Notch_Hz_1), 0, 1000),
      Notch1_Cutoff      => Held (Integer (G.Gyro_Soft_Notch_Cutoff_1), 0, 1000),
      Notch2_Hz          => Held (Integer (G.Gyro_Soft_Notch_Hz_2), 0, 1000),
      Notch2_Cutoff      => Held (Integer (G.Gyro_Soft_Notch_Cutoff_2), 0, 1000),
      Sample_Time_Us     => Sample_Time_Us,
      Loop_Time_Us       => Sample_Time_Us * Integer (Loop_Rate.Pid_Process_Denom),
      Scale              => Scale,
      Alignment          =>
        Sensor_Alignment.Standard_Alignment'Val
          (Code (Device.Alignment, Sensor_Alignment.Standard_Alignment'Pos (Sensor_Alignment.Standard_Alignment'Last))),
      Custom_Angles      =>
        (Roll  => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (0)), -3600, 3600)),
         Pitch => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (1)), -3600, 3600)),
         Yaw   => Sensor_Alignment.Decidegrees (Held (Integer (Device.Custom_Alignment (2)), -3600, 3600))),
      Board              =>
        (Roll  => Held (Integer (Board.Roll_Degrees), -180, 360),
         Pitch => Held (Integer (Board.Pitch_Degrees), -180, 360),
         Yaw   => Held (Integer (Board.Yaw_Degrees), -180, 360)),
      Calibration_Duration => Held (Integer (G.Gyro_Calibration_Duration), 1, 3_000),
      Movement_Threshold => Held (Integer (G.Gyro_Movement_Calibration_Threshold), 0, 200),
      Offset_Yaw         => Held (Integer (G.Gyro_Offset_Yaw), -1_000, 1_000),
      Check_Overflow     =>
        Gyro_Filters.Overflow_Check'Val
          (Code (G.Check_Overflow, Gyro_Filters.Overflow_Check'Pos (Gyro_Filters.Overflow_Check'Last))),
      Overflow_Protected => Overflow_Protected,
      Yaw_Spin           =>
        Gyro_Filters.Spin_Recovery'Val
          (Code (G.Yaw_Spin_Recovery, Gyro_Filters.Spin_Recovery'Pos (Gyro_Filters.Spin_Recovery'Last))),
      Yaw_Spin_Threshold => Held (Integer (G.Yaw_Spin_Threshold), 500, 1_950),
      Dynamic_Notch      =>
        (Count  => Held (Integer (N.Dyn_Notch_Count), 0, Dyn_Notch.Max_Notches),
         Q      => Held (Integer (N.Dyn_Notch_Q), 1, 1_000),
         Min_Hz => Held (Integer (N.Dyn_Notch_Min_Hz), 20, 250),
         Max_Hz => Held (Integer (N.Dyn_Notch_Max_Hz), 200, 1_000)),
      RPM                =>
        (Harmonics     => Held (Integer (R.Rpm_Filter_Harmonics), 0, RPM_Filter.Max_Harmonics),
         Weights       => (0 => Integer (R.Rpm_Filter_Weights (0)), 1 => Integer (R.Rpm_Filter_Weights (1)),
                           2 => Integer (R.Rpm_Filter_Weights (2))),
         Min_Hz        => Held (Integer (R.Rpm_Filter_Min_Hz), 30, 200),
         Fade_Range_Hz => Held (Integer (R.Rpm_Filter_Fade_Range_Hz), 0, 1_000),
         Q             => Held (Integer (R.Rpm_Filter_Q), 250, 3_000)),
      Motors             => Motors,
      Motor_Telemetry    => Motor.Dev.Use_Dshot_Telemetry /= 0,
      Simplified_Filter  => G.Simplified_Gyro_Filter /= 0,
      Simplified_Filter_Multiplier => Held (Integer (G.Simplified_Gyro_Filter_Multiplier), 10, 200));

end Adaflight.Config_Runtime;
