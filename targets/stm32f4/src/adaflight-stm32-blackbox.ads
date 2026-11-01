--  The flight log on the board: the recorder over the SD card's file, the
--  flash chip's volume or a serial port, which the stored configuration names with its rate, run as the PID loop's log step
--  with what the flight gives it before each pass and what the controller
--  and the mixer hold after theirs, its bytes queued on the port, and the
--  disarm event with the log's end when the arming logic disarms.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Blackbox;
with Adaflight.Blackbox_Header;
with Adaflight.Config_Groups;
with Adaflight.STM32.USART;
package Adaflight.STM32.Blackbox is
   --  What the log reads from the flight at each pass beside the controller
   --  and the mixer: the time, the arming beep, the battery, the sensors,
   --  the attitude, the link, the modes, the GPS and the conditions of the
   --  log start.
   type Facts is record
      Now_Ms          : Interfaces.Unsigned_32 := 0;
      Arming_Beep_Us  : Interfaces.Unsigned_32 := 0;
      Battery_Voltage : Interfaces.Unsigned_16 := 0;
      VBat_Latest     : Interfaces.Unsigned_16 := 0;
      Amperage        : Interfaces.Integer_32 := 0;
      RSSI            : Interfaces.Unsigned_16 := 0;
      Surface_Raw     : Interfaces.Integer_32 := 0;
      Baro_Alt        : Interfaces.Integer_32 := 0;
      Airspeed        : Float range -1.0e6 .. 1.0e6 := 0.0;
      Diff_Pressure   : Float range -1.0e6 .. 1.0e6 := 0.0;
      Debug           : Adaflight.Blackbox.Debug_Values := (others => 0);
      Gyro_Filtered   : Adaflight.Blackbox.Axis_Floats := (others => 0.0);
      Gyro_Raw        : Adaflight.Blackbox.Axis_Floats := (others => 0.0);
      Acc             : Adaflight.Blackbox.Axis_Floats := (others => 0.0);
      Quaternion_W    : Adaflight.Blackbox.Unit_Float := 1.0;
      Quaternion_XYZ  : Adaflight.Blackbox.Unit_Floats := (others => 0.0);
      Slow            : Adaflight.Blackbox.Slow_Inputs;
      GPS             : Adaflight.Blackbox.GPS_Inputs;
      GPS_Feature     : Boolean := False;
      Conditions      : Adaflight.Blackbox_Header.Condition_Inputs;
   end record;

   --  The recorder's settings from the configuration and its port, opened
   --  at the stored rate, with two stop bits at 230400 baud; a port shared
   --  with the MSP keeps the MSP's rate and leaves the MSP while the log
   --  holds it.
   procedure Init
     (Config : Adaflight.Config_Groups.Configuration; Loop_Time : Adaflight.Blackbox.Loop_Time_Us);
   --  Whether a log device is configured.
   function Device_Set return Boolean;
   --  Whether the log holds a port the MSP would serve.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   procedure Set_Facts (F : Facts);
   --  Whether the header waits for the system information, which the flight
   --  builds from the configuration once per log.
   function Needs_Info return Boolean;
   procedure Set_Info (I : Adaflight.Blackbox_Header.Sysinfo);
   --  The PID loop's log step.
   procedure Update;
   --  A disarm: its event, then the log's end.
   procedure Disarmed (Reason : Adaflight.Arming.Disarm_Reason; Now_Us, Now_Ms : Interfaces.Unsigned_32);
   --  The recorder, which the MSP replies read.
   function Recorder return Adaflight.Blackbox.Recorder;
   --  The log device's state the OSD's log element shows: whether it works,
   --  a serial port while the log holds it open, an SD card inserted and
   --  working with its file system ready, a flash chip ready; whether it is
   --  full; and the largest log file number on an SD card, -1 on the others.
   procedure Device_State (Working, Full : out Boolean; Log_Number : out Interfaces.Integer_32);
end Adaflight.STM32.Blackbox;
