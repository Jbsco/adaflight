--  The flight log recorder: the log states from stopped through the header
--  to running, paused and shutting down, the intra and delta main frames
--  with their three-deep history, the slow frames on change or interval,
--  the GPS and GPS home frames, the events, and the iteration policy that
--  places them. The device, the sensors, the settings and the clock stay
--  with the target: each update brings the device's answers and the state
--  to log, and the recorder appends the bytes to a caller owned array.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers; use Adaflight.Stream_Buffers;
with Adaflight.Blackbox_Header;
with Adaflight.Failsafe;
with Adaflight.GPS_Frames;

package Adaflight.Blackbox with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   package Header renames Adaflight.Blackbox_Header;

   type Log_State is
     (Disabled, Stopped, Prepare_Log_File, Send_Header, Send_Main_Field_Header, Send_GPS_H_Header,
      Send_GPS_G_Header, Send_Slow_Header, Send_Sysinfo, Cache_Flush, Paused, Running, Shutting_Down,
      Start_Erase, Erasing, Erased);
   type Log_Mode is (Normal, Motor_Test, Always_On);

   Sample_Rate_Max : constant := 4;

   --  The settings: the field groups disabled, the sample rate as a power of
   --  two divisor, the device, the mode, the tenfold resolution, and whether
   --  a serial device runs at a megabaud or more.
   type Settings is record
      Fields_Disabled_Mask : Unsigned_32 := 0;
      Sample_Rate          : Natural range 0 .. 255 := 2;
      Device               : Header.Device_Kind := Header.No_Device;
      Mode                 : Log_Mode := Normal;
      High_Resolution      : Boolean := False;
      Serial_Fast_Baud     : Boolean := False;
      Wing                 : Boolean := False;
   end record;

   subtype Loop_Time_Us is Positive range 1 .. 65_535;

   Axis_Count   : constant := 3;
   Motor_Count  : constant := 8;
   Servo_Count  : constant := 8;
   Debug_Count  : constant := 8;
   subtype Axis is Natural range 0 .. Axis_Count - 1;
   subtype Motor_Index is Natural range 0 .. Motor_Count - 1;
   subtype Servo_Index is Natural range 0 .. Servo_Count - 1;
   subtype Debug_Index is Natural range 0 .. Debug_Count - 1;

   --  A value the log rounds to an integer, within the rounding bound after
   --  the tenfold resolution scale.
   subtype Logged_Float is Float range -1_000_000.0 .. 1_000_000.0;
   subtype Unit_Float is Float range -2.0 .. 2.0;
   subtype Throttle_Float is Float range -1_000.0 .. 1_000.0;
   type Axis_Floats is array (Axis) of Logged_Float;
   type Unit_Floats is array (Axis) of Unit_Float;
   type Quad_Floats is array (0 .. 3) of Logged_Float;
   type Motor_Floats is array (Motor_Index) of Logged_Float;
   type Debug_Values is array (Debug_Index) of Integer_16;
   type Motor_RPMs is array (Motor_Index) of Unsigned_16;
   type Servo_Values is array (Servo_Index) of Integer_16;

   --  What the main frame reads from the flight controller each iteration.
   type Main_Inputs is record
      PID_P, PID_I, PID_D, PID_F, PID_S  : Axis_Floats := (others => 0.0);
      Gyro_Filtered, Gyro_Raw            : Axis_Floats := (others => 0.0);
      Acc, Mag                           : Axis_Floats := (others => 0.0);
      Quaternion_W                       : Unit_Float := 1.0;
      Quaternion_XYZ                     : Unit_Floats := (others => 0.0);
      RC_Command                         : Quad_Floats := (others => 0.0);
      Setpoint                           : Axis_Floats := (others => 0.0);
      Throttle                           : Throttle_Float := 0.0;
      Debug                              : Debug_Values := (others => 0);
      Motor                              : Motor_Floats := (others => 0.0);
      ERPM                               : Motor_RPMs := (others => 0);
      VBat_Latest                        : Unsigned_16 := 0;
      Amperage_Latest                    : Integer_32 := 0;
      Baro_Alt                           : Integer_32 := 0;
      Surface_Raw                        : Integer_32 := 0;
      RSSI                               : Unsigned_16 := 0;
      Airspeed, Diff_Pressure            : Logged_Float := 0.0;
      Servo                              : Servo_Values := (others => 0);
      Motor_Output_Low                   : Logged_Float := 1_000.0;
   end record;

   --  What the slow frame reads: the first thirty-two mode flags, the state
   --  flags, the failsafe phase and the receiver's signal and channel state.
   type Slow_Inputs is record
      Flight_Mode_Flags        : Unsigned_32 := 0;
      State_Flags              : Byte := 0;
      Failsafe_Phase           : Adaflight.Failsafe.Phase := Adaflight.Failsafe.Idle;
      RX_Signal_Received       : Boolean := False;
      RX_Flight_Channels_Valid : Boolean := False;
   end record;

   --  The GPS solution and home, with the date and time already converted
   --  to seconds since the epoch.
   type GPS_Inputs is record
      Home                         : Adaflight.GPS_Frames.Location;
      Position                     : Adaflight.GPS_Frames.Location;
      Num_Sat                      : Byte := 0;
      Speed_3D, Ground_Speed       : Unsigned_16 := 0;
      Ground_Course                : Unsigned_16 := 0;
      Vel_N, Vel_E, Vel_D          : Integer_16 := 0;
      Time_Ms                      : Unsigned_32 := 0;
      Epoch                        : Unsigned_32 := 0;
      Use_3D_Speed                 : Boolean := False;
   end record;

   --  The device's answers this iteration: its free space, whether it
   --  opened with its buffer size, whether the log file is ready and closed,
   --  whether its buffers are flushed, whether it is full or erased, and
   --  whether the serial port is shared with the MSP.
   type Device_Inputs is record
      Free            : Header.Device_Space := 0;
      Open_OK         : Boolean := False;
      Buffer_Size     : Header.Device_Space := 0;
      Begin_Log_Done  : Boolean := True;
      End_Log_Done    : Boolean := True;
      Flush_Complete  : Boolean := True;
      Flush_Forced    : Boolean := True;
      Full            : Boolean := False;
      Erased          : Boolean := True;
      Shared_MSP_Port : Boolean := False;
   end record;

   type Inputs is record
      Now_Us                   : Unsigned_32 := 0;
      Now_Ms                   : Unsigned_32 := 0;
      Armed                    : Boolean := False;
      Blackbox_Box             : Boolean := False;
      Erase_Box                : Boolean := False;
      Motors_Running           : Boolean := False;
      GPS_Feature              : Boolean := False;
      Mode_Activation_Present  : Boolean := False;
      Arming_Beep_Time_Us      : Unsigned_32 := 0;
      Battery_Voltage          : Unsigned_16 := 0;
      Device                   : Device_Inputs;
      Main                     : Main_Inputs;
      Slow                     : Slow_Inputs;
      GPS                      : GPS_Inputs;
      Conditions               : Header.Condition_Inputs;
      Info                     : Header.Sysinfo;
   end record;

   subtype Logged_Int is Integer_32 range -(2 ** 24) .. 2 ** 24;
   type Axis_Ints is array (Axis) of Logged_Int;
   type Axis_Int16s is array (Axis) of Integer_16;
   type Quad_Int16s is array (0 .. 3) of Integer_16;
   type Motor_Int16s is array (Motor_Index) of Integer_16;

   --  A main frame's values as the log stores them.
   type Main_State is record
      Time                               : Unsigned_32 := 0;
      Axis_P, Axis_I, Axis_D, Axis_F     : Axis_Ints := (others => 0);
      Axis_S                             : Axis_Ints := (others => 0);
      RC_Command, Setpoint               : Quad_Int16s := (others => 0);
      Gyro_ADC, Gyro_Unfilt              : Axis_Int16s := (others => 0);
      Acc_ADC, Quaternion3               : Axis_Int16s := (others => 0);
      Debug                              : Debug_Values := (others => 0);
      Motor                              : Motor_Int16s := (others => 0);
      Servo                              : Servo_Values := (others => 0);
      ERPM                               : Motor_Int16s := (others => 0);
      VBat_Latest                        : Unsigned_16 := 0;
      Amperage_Latest                    : Integer_32 := 0;
      Baro_Alt                           : Integer_32 := 0;
      Mag_ADC                            : Axis_Int16s := (others => 0);
      Surface_Raw                        : Integer_32 := 0;
      RSSI                               : Unsigned_16 := 0;
      Airspeed, Diff_Pressure            : Integer_32 := 0;
   end record;

   type Ring_Index is range 0 .. 2;
   type History_Ring is array (Ring_Index) of Main_State;

   type GPS_History is record
      Home     : Adaflight.GPS_Frames.Location;
      Position : Adaflight.GPS_Frames.Location;
      Num_Sat  : Byte := 0;
   end record;

   type Slow_State is record
      Flight_Mode_Flags        : Unsigned_32 := 0;
      State_Flags              : Byte := 0;
      Failsafe_Phase           : Byte := 0;
      RX_Signal_Received       : Boolean := False;
      RX_Flight_Channels_Valid : Boolean := False;
   end record;

   subtype I_Interval_Count is Integer_16 range 0 .. 32_000;
   subtype P_Interval_Count is Integer_8 range 0 .. 16;

   --  The recorder's state: the log state and the one a cache flush returns
   --  to, the header transmission, the writer and condition cache, the
   --  iteration counters and intervals, the frame histories, the test mode
   --  flags, and the counts of the requests the target carries out.
   type Recorder is record
      State                   : Log_State := Disabled;
      Cache_Flush_Next        : Log_State := Running;
      Last_Arming_Beep        : Unsigned_32 := 0;
      Last_Flight_Mode_Flags  : Unsigned_32 := 0;
      Header_St               : Header.Header_State;
      Writer                  : Header.Writer;
      Cache                   : Header.Condition_Set := (others => False);
      Iteration               : Unsigned_32 := 0;
      Loop_Index              : Unsigned_16 := 0;
      P_Frame_Index           : Unsigned_16 := 0;
      I_Frame_Index           : Unsigned_16 := 0;
      I_Interval              : I_Interval_Count := 0;
      P_Interval              : P_Interval_Count := 0;
      S_Interval              : Integer_32 := 0;
      Slow_Frame_Timer        : Integer_32 := 0;
      Logged_Any_Frames       : Boolean := False;
      High_Resolution_Scale   : Float range 1.0 .. 10.0 := 1.0;
      VBat_Reference          : Unsigned_16 := 0;
      GPS_Hist                : GPS_History;
      Slow_Hist               : Slow_State;
      Ring                    : History_Ring;
      Current                 : Ring_Index := 0;
      Previous                : Ring_Index := 1;
      Previous_2              : Ring_Index := 2;
      Mode_Condition_Present  : Boolean := False;
      Started_In_Test_Mode    : Boolean := False;
      Test_Mode_Reset_Ms      : Unsigned_32 := 0;
      Loop_Time               : Loop_Time_Us := 125;
      Flush_Requests          : Unsigned_32 := 0;
      Flush_Forces            : Unsigned_32 := 0;
      Erase_Requests          : Unsigned_32 := 0;
      Beeps                   : Unsigned_32 := 0;
      Opens                   : Unsigned_32 := 0;
      Closes                  : Unsigned_32 := 0;
   end record;

   --  The event kinds the log carries, by their codes.
   type Event_Kind is (Sync_Beep, Inflight_Adjustment, Logging_Resume, Disarm, Flight_Mode, Log_End);
   function Event_Code (E : Event_Kind) return Byte is
     (case E is
        when Sync_Beep => 0, when Inflight_Adjustment => 13, when Logging_Resume => 14, when Disarm => 15,
        when Flight_Mode => 30, when Log_End => 255);

   type Event_Data is record
      Time_Us             : Unsigned_32 := 0;
      Flags, Last_Flags   : Unsigned_32 := 0;
      Reason              : Unsigned_32 := 0;
      Adjustment_Function : Byte := 0;
      Float_Flag          : Boolean := False;
      New_Value           : Integer_32 := 0;
      New_Float           : Float := 0.0;
      Log_Iteration       : Unsigned_32 := 0;
      Current_Time        : Unsigned_32 := 0;
   end record;

   --  The recorder at startup: the intervals from the loop time and the
   --  sample rate, which is held at its maximum, and stopped when a device
   --  is set.
   procedure Init (L : out Recorder; C : in out Settings; Loop_Time : Loop_Time_Us)
     with Post => C.Sample_Rate <= Sample_Rate_Max;

   --  One flight loop iteration of logging.
   procedure Update (L : in out Recorder; C : in out Settings; In_Flight : Inputs; B : in out Byte_Array;
                     S : in out Stream)
     with Pre  => Fits (S, B) and then C.Sample_Rate <= Sample_Rate_Max,
          Post => Fits (S, B) and then S.Last = S.Last'Old;

   --  The log's shutdown begins: the end event while running or paused.
   procedure Finish (L : in out Recorder; Now_Ms : Unsigned_32; B : in out Byte_Array; S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old;

   --  An event while running or paused.
   procedure Log_Event (L : in out Recorder; E : Event_Kind; D : Event_Data; B : in out Byte_Array;
                        S : in out Stream)
     with Pre  => Fits (S, B),
          Post => Fits (S, B) and then S.Last = S.Last'Old;

   --  Whether the settings may change: before the log starts.
   function May_Edit_Config (L : Recorder) return Boolean is (L.State <= Stopped);

   --  The delta frame interval for a rate given as a fraction of the loop.
   function P_Denominator (L : Recorder; Rate_Num, Rate_Denom : Integer_32) return Integer_32
     with Pre => Rate_Num in -2 ** 15 .. 2 ** 15 and then Rate_Denom in -2 ** 15 .. 2 ** 15;

   function Rate_Denominator (L : Recorder) return Byte is (Byte (L.P_Interval));

   --  Intra frames per delta frame, zero without delta frames.
   function P_Ratio (L : Recorder) return Unsigned_16 is
     (if L.P_Interval = 0 then 0 else Unsigned_16 (L.I_Interval / Integer_16 (L.P_Interval)));

   --  The sample rate setting that gives a ratio at the loop time.
   function Sample_Rate_For (Ratio : Unsigned_16; Loop_Time : Loop_Time_Us) return Natural
     with Post => Sample_Rate_For'Result <= Sample_Rate_Max;

end Adaflight.Blackbox;
