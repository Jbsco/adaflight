--  Configuration fix: the checks a configuration passes after every load
--  and before every save. An unsupported mixer mode becomes a custom mode,
--  a repeated telemetry protocol is dropped, conflicting serial ports lose
--  their claims, filter cutoffs past their limits are reset, receiver
--  features that exclude each other are reduced to one, linked mode chains
--  are cut, motor settings the protocol or timers cannot run are reset,
--  profile selections past their counts return to the first, rates are held
--  to their type's limits, and battery voltages out of order return to their
--  defaults. The fix also names the serial port the MSP display port draws
--  over.
with Interfaces; use Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Serial_Feature_Map;

package Adaflight.Config_Fix with SPARK_Mode is

   Feature_RX_PPM          : constant Unsigned_32 := 16#0000_0001#;
   Feature_RX_UDP          : constant Unsigned_32 := 16#0000_0002#;
   Feature_RX_Serial       : constant Unsigned_32 := 16#0000_0008#;
   Feature_Soft_Serial     : constant Unsigned_32 := 16#0000_0040#;
   Feature_GPS             : constant Unsigned_32 := 16#0000_0080#;
   Feature_Telemetry       : constant Unsigned_32 := 16#0000_0400#;
   Feature_3D              : constant Unsigned_32 := 16#0000_1000#;
   Feature_RX_Parallel_PWM : constant Unsigned_32 := 16#0000_2000#;
   Feature_RX_MSP          : constant Unsigned_32 := 16#0000_4000#;
   Feature_RSSI_ADC        : constant Unsigned_32 := 16#0000_8000#;
   Feature_LED_Strip       : constant Unsigned_32 := 16#0001_0000#;
   Feature_OSD             : constant Unsigned_32 := 16#0004_0000#;
   Feature_RX_SPI          : constant Unsigned_32 := 16#0200_0000#;
   Feature_ESC_Sensor      : constant Unsigned_32 := 16#0800_0000#;

   --  The features of the settings oracle's build.
   Supported_Features : constant Unsigned_32 := 16#1A77_D7FD#;

   type Timer_Kind is (No_Timer, Normal_Channel, N_Channel);
   type Pin_Timers is array (Unsigned_8) of Timer_Kind;

   Max_Motors : constant := 8;
   subtype Motor_Count is Natural range 0 .. Max_Motors;
   subtype Gyro_Rate is Unsigned_32 range 0 .. 32_000;

   --  The hardware the fix reads: the gyro's sample rate, zero before the
   --  gyro starts, the motors in use, and the timer behind each pin.
   type Hardware is record
      Gyro_Sample_Rate_Hz : Gyro_Rate := 0;
      Motors              : Motor_Count := 0;
      Timers              : Pin_Timers := (others => No_Timer);
   end record;

   --  A port setting outside the serial map's identifiers stands for this
   --  port, which no board has.
   Absent_Port : constant Serial_Feature_Map.Port_Id := Serial_Feature_Map.Port_Id'Last;

   --  The serial port the MSP display port draws over, and the GPS port the
   --  fix takes out of use; -1 for none.
   type Results is record
      MSP_Display_Port : Integer_8 := -1;
      Removed_GPS_Port : Integer_8 := -1;
   end record;

   --  The serial options of the settings oracle's build.
   Serial_Options : constant Serial_Feature_Map.Options := (others => <>);

   --  The serial assignments the configuration's port settings make.
   function Serial_Assignments (C : Configuration) return Serial_Feature_Map.Assignments;

   --  The ports, baud rates, VTX device, display device and telemetry
   --  providers that differ between two assignments, written from the second
   --  into the configuration.
   procedure Store_Serial_Assignments (C : in out Configuration; Before, After : Serial_Feature_Map.Assignments);

   LPF_Max_Hz : constant := 1_000;

   --  What the PID profile checks leave: the D term cutoffs within the
   --  limit, the notch and the dynamic lowpass in order, and the motor
   --  output limit and the automatic profile cell count within their ranges.
   function Fixed_PID_Profile (P : Pid_Profile_Record) return Boolean is
     (P.Dterm_Lpf1_Static_Hz <= LPF_Max_Hz and then P.Dterm_Lpf2_Static_Hz <= LPF_Max_Hz
      and then P.Dterm_Notch_Hz <= LPF_Max_Hz
      and then (P.Dterm_Notch_Hz = 0 or else P.Dterm_Notch_Cutoff < P.Dterm_Notch_Hz)
      and then (P.Dterm_Lpf1_Dyn_Min_Hz = 0 or else P.Dterm_Lpf1_Dyn_Min_Hz <= P.Dterm_Lpf1_Dyn_Max_Hz)
      and then P.Motor_Output_Limit in 1 .. 100 and then P.Auto_Profile_Cell_Count in -1 .. 8);

   --  What the gyro filter checks leave: the lowpass and notch cutoffs within
   --  the limit, the notches and the dynamic lowpass in order.
   function Fixed_Gyro_Filters (G : Gyro_Config_Record) return Boolean is
     (G.Gyro_Lpf1_Static_Hz <= LPF_Max_Hz and then G.Gyro_Lpf2_Static_Hz <= LPF_Max_Hz
      and then G.Gyro_Soft_Notch_Hz_1 <= LPF_Max_Hz and then G.Gyro_Soft_Notch_Hz_2 <= LPF_Max_Hz
      and then (G.Gyro_Soft_Notch_Hz_1 = 0 or else G.Gyro_Soft_Notch_Cutoff_1 < G.Gyro_Soft_Notch_Hz_1)
      and then (G.Gyro_Soft_Notch_Hz_2 = 0 or else G.Gyro_Soft_Notch_Cutoff_2 < G.Gyro_Soft_Notch_Hz_2)
      and then G.Gyro_Lpf1_Dyn_Min_Hz <= G.Gyro_Lpf1_Dyn_Max_Hz);

   --  The gyro's checks: filter cutoffs past their limits, the PID loop or
   --  the motor update rate held to what the motor protocol runs, and the
   --  profile selections and waypoint count past their counts.
   procedure Fix_Gyro (C : in out Configuration; Gyro_Sample_Rate_Hz : Gyro_Rate);

   --  Every check in order. The runtime feature mask starts as the
   --  configuration's on a load and follows every feature change.
   procedure Fix
     (C : in out Configuration; H : Hardware; Ports : Serial_Feature_Map.Port_List;
      Runtime_Features : in out Unsigned_32; R : out Results)
     with Pre => Ports'Length in 1 .. Serial_Feature_Map.Max_Ports
                 and then (for all P of Ports => P /= Absent_Port);

end Adaflight.Config_Fix;
