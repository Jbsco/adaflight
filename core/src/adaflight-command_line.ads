--  Command line: the line a user types, its comment and trailing spaces cut,
--  and the commands over the configuration's settings. get lists every
--  setting whose name contains a fragment, with its value, profile, range and
--  default; set lists every setting, or reads a value for one setting by its
--  name; profile, rateprofile and battery_profile show or select a profile;
--  dump and diff list a profile's or a rate profile's settings, and the whole
--  configuration or its hardware part as commands, all of it or only what
--  differs from the defaults; version prints the firmware's version line,
--  mcu_id the MCU's unique id, and board_name, manufacturer_id and signature
--  show or set the board's information; batch brackets a command batch and
--  reports an error printed inside it; tasks lists every queued task's rate
--  and, with task statistics on, its times and loads, and resets the peaks;
--  vtx_info lists the video transmitter's power levels and rc_smoothing_info
--  the receiver's frame rate and the running RC smoothing cutoffs; motor sets
--  a motor's or every motor's disarmed value, play_sound plays a beeper sound,
--  and sensor_hardware lists the hardware each sensor type can be; bind_rx
--  starts the receiver's bind; sd_info reports the SD card and its file
--  system, and flash_info the flash chip with its partitions; bl restarts
--  the board into its ROM bootloader and msc into mass storage; help lists
--  the commands of the build with their descriptions and arguments;
--  dshotprog writes DShot commands to the ESCs and prints the information
--  they send back; options lists the build's option numbers;
--  save, exit and defaults without nosave ask for the configuration's write,
--  the board's restart or the command line's end. A line naming no command
--  gets the ERR_CMD_NA reply.
--  The text goes out through Put into a sink, inside an Output that also
--  holds the batch's state and what the tasks command remembers.
with Interfaces;
with Adaflight.Arming;
with Adaflight.Battery;
with Adaflight.Beeper;
with Adaflight.Board_Info;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.CLI_Resources;
with Adaflight.CLI_Text;
with Adaflight.DShot;
with Adaflight.ESC_Info;
with Adaflight.GPS_Frames;
with Adaflight.GPS_Link;
with Adaflight.MSP_Motor_In;
with Adaflight.Receiver;
with Adaflight.RX_Bind;
with Adaflight.RTC;
with Adaflight.Scheduler;
with Adaflight.Serial_Feature_Map;

generic
   type Sink is limited private;
   with procedure Put (Into : in out Sink; Text : String);
   --  The board's DShot programming: a command written to one ESC or to all,
   --  the motors switched off and back on around commands, an ESC information
   --  read started and its bytes taken with their count, and a wait.
   with procedure DShot_Write (Index : Natural; Motors : Natural; Command : Interfaces.Unsigned_8);
   with procedure Motors_Disable;
   with procedure Motors_Enable;
   with procedure ESC_Read_Start;
   with procedure ESC_Read_Bytes (F : out ESC_Info.Frame; Count : out Natural);
   with procedure Delay_Ms (Ms : Natural);
   --  The board's passthrough starts: an ESC's serial link by output and
   --  protocol number, and the GPS receiver's, each telling whether it
   --  started.
   with procedure ESC_Passthrough (Index : Natural; Protocol : Interfaces.Unsigned_8; Started : out Boolean);
   with procedure GPS_Passthrough (Started : out Boolean);
   --  The board's read of a gyro's register by gyro position.
   with procedure Gyro_Read_Register
     (Gyro : Natural; Register : Interfaces.Unsigned_8; Value : out Interfaces.Unsigned_8);
   --  The board's flash file system tools: whether a file system is there,
   --  the whole erase started, whether the flash is ready, a step of the
   --  erase, the verify of the whole flash, a seek, a write, a flush, and a
   --  read of up to a length of bytes at an address with the count read.
   with function Flash_Supported return Boolean;
   with procedure Flash_Erase_Completely;
   with procedure Flash_Ready (Ready : out Boolean);
   with procedure Flash_Erase_Async;
   with procedure Flash_Verify (OK : out Boolean);
   with procedure Flash_Seek (Address : Interfaces.Unsigned_32);
   with procedure Flash_Write (Data : String);
   with procedure Flash_Flush;
   with procedure Flash_Read
     (Address : Interfaces.Unsigned_32; Length : Natural; Data : out String; Count : out Natural);
   --  The board's serial ports for the passthrough, by identifier: whether a
   --  port is open, with its baud rate, mode, options and whether a receive
   --  callback is set; a port opened at a baud rate, mode and options, with
   --  whether it opened; a baud rate or a mode set on an open port and its
   --  callback removed; the USB port's line coding setting another port's
   --  baud rate; the USB port's DTR resetting the board or switching a PINIO;
   --  the motor outputs held idle for an ESC sensor passthrough; and the
   --  forwarding between two ports.
   with procedure Port_State
     (Id : Interfaces.Integer_32; Open : out Boolean; Baud : out Interfaces.Unsigned_32;
      Mode : out Interfaces.Unsigned_8; Options : out Interfaces.Unsigned_32; Callback : out Boolean);
   with procedure Port_Open
     (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32; Mode : Interfaces.Unsigned_8;
      Options : Interfaces.Unsigned_32; Opened : out Boolean);
   with procedure Port_Set_Baud (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32);
   with procedure Port_Set_Mode (Id : Interfaces.Integer_32; Mode : Interfaces.Unsigned_8);
   with procedure Port_Remove_Callback (Id : Interfaces.Integer_32);
   with procedure Port_Baud_From_USB (USB : Interfaces.Integer_32; Target : Interfaces.Integer_32);
   with procedure Port_DTR_Reset (USB : Interfaces.Integer_32);
   with procedure Port_DTR_PINIO (USB : Interfaces.Integer_32; PINIO : Natural);
   with procedure ESC_Sensor_Pins_Idle;
   with procedure Port_Forward (Left : Interfaces.Integer_32; Right : Interfaces.Integer_32);
package Adaflight.Command_Line with SPARK_Mode is

   subtype Port_List is CLI_Text.Port_List;

   --  The profiles a profile setting reads and writes.
   type Profiles is record
      PID     : Natural := 0;
      Rate    : Natural := 0;
      Battery : Natural := 0;
   end record;

   function Valid (P : Profiles) return Boolean is
     (P.PID < Pid_Profile_Record_List_4'Length and then P.Rate < Control_Rate_Config_Record_List_4'Length
      and then P.Battery < Battery_Profile_Record_List_3'Length);

   --  The profiles the configuration selects.
   function Current (C : Configuration) return Profiles is
     (PID     => Natural (C.System_Config.Pid_Profile_Index),
      Rate    => Natural (C.System_Config.Active_Rate_Profile),
      Battery => Natural (C.System_Config.Active_Battery_Profile));

   --  Where the text goes, with the command batch's state: whether a batch
   --  is open, and whether a command in it printed an error; and what the
   --  tasks command remembers from its last run: the clock, and the check
   --  functions' total execution time; and the beeper table entry play_sound
   --  played last, -1 before the first.
   type Output is limited record
      Target              : Sink;
      Batch_Active        : Boolean := False;
      Batch_Error         : Boolean := False;
      Last_Tasks_Us       : Interfaces.Unsigned_32 := 0;
      Last_Check_Total_Us : Interfaces.Unsigned_32 := 0;
      Last_Sound          : Integer range -1 .. 23 := -1;
   end record;

   --  Every setting whose name contains the fragment without regard to case,
   --  or an invalid name error; Command names the command in errors.
   procedure Get (Into : in out Output; C : Configuration; Command : String; Fragment : String; Ports : Port_List)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports;

   --  Every setting's value, with each direct setting's range for an
   --  asterisk; a value for the setting named before an equals sign; or get
   --  for arguments without one.
   procedure Set (Into : in out Output; C : in out Configuration; Arguments : String; Ports : Port_List)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports
                 and then Arguments'Last < Positive'Last;

   Line_Size : constant := 256;

   --  The runtime work a command asks for: a profile selected, the mode
   --  conditions changed, the adjustment ranges changed, or the LED strip's
   --  layout changed; the configuration written to its storage, the board
   --  restarted, or the command line left with the disarmed motors reset; a
   --  motor's disarmed value, or every motor's, set to a value; the beeper
   --  silenced and a sound requested; the flash erase's sound; a receiver
   --  bind started; a restart into the ROM bootloader, or into mass storage
   --  with its timezone offset in minutes.
   type Restart_Mode is (No_Restart, ROM_Bootloader, Mass_Storage);
   type Effects is record
      PID_Profile     : Boolean := False;
      Rate_Profile    : Boolean := False;
      Battery_Profile : Boolean := False;
      Modes           : Boolean := False;
      Adjustments     : Boolean := False;
      LEDs            : Boolean := False;
      Save            : Boolean := False;
      Reboot          : Boolean := False;
      Leave           : Boolean := False;
      Motor           : Boolean := False;
      Every_Motor     : Boolean := False;
      Motor_Index     : Natural range 0 .. MSP_Motor_In.Max_Motors - 1 := 0;
      Motor_Value     : Float := 0.0;
      Sound           : Boolean := False;
      Sound_Mode      : Beeper.Sound := Beeper.Gyro_Calibrated;
      Erase_Sound     : Boolean := False;
      Bind            : RX_Bind.Bind := RX_Bind.No_Bind;
      Restart         : Restart_Mode := No_Restart;
      Timezone_Offset : Interfaces.Integer_16 := 0;
   end record;

   --  The flight plan executor's state the waypoint status reports: whether
   --  it runs, its state, its current waypoint, the distance to that
   --  waypoint in meters, negative for none, the bearing in tenths of a
   --  degree, the time to it in seconds and the reason it aborted.
   type Navigation_Status is record
      Active        : Boolean := False;
      State         : Interfaces.Unsigned_8 := 0;
      Current_Index : Interfaces.Unsigned_8 := 0;
      Distance_M    : Float := -1.0;
      Bearing_Deci  : Interfaces.Integer_32 := 0;
      ETA_S         : Interfaces.Unsigned_16 := 0;
      Abort_Reason  : Interfaces.Unsigned_8 := 0;
   end record;

   --  A name the version line or the board's lines print: up to 32
   --  characters.
   Identity_Max : constant := Board_Info.Identity_Max;
   subtype Identity_Length is Board_Info.Identity_Length;
   subtype Identity_Text is Board_Info.Identity_Text;

   function To_Identity (Text : String) return Identity_Text renames Board_Info.To_Identity;

   type MCU_Words is array (1 .. 3) of Interfaces.Unsigned_32;
   subtype Signature_Bytes is Board_Info.Signature_Bytes;

   --  The power levels the video transmitter reports, up to eight, each a
   --  level in dBm with its power in mW.
   Max_Power_Levels : constant := 8;
   subtype Power_Level_Count is Natural range 0 .. Max_Power_Levels;
   type Power_Values is array (1 .. Max_Power_Levels) of Interfaces.Unsigned_16;
   type Power_Levels is record
      Count  : Power_Level_Count := 0;
      Levels : Power_Values := (others => 0);
      Powers : Power_Values := (others => 0);
   end record;

   --  The running RC smoothing as rc_smoothing_info reports it: whether the
   --  receiver's frame rate is valid, the rate in Hz, and each cutoff in Hz
   --  with whether its setting fixed it.
   subtype Frame_Rate_Hz is Float range 15.0 .. 1250.0;
   type Smoothing_Status is record
      Rate_Valid         : Boolean := False;
      Rate_Hz            : Frame_Rate_Hz := 1250.0;
      Setpoint_Cutoff_Hz : Interfaces.Unsigned_16 := 0;
      Setpoint_Manual    : Boolean := False;
      Throttle_Cutoff_Hz : Interfaces.Unsigned_16 := 0;
      Throttle_Manual    : Boolean := False;
   end record;

   --  The DShot telemetry as dshot_telemetry_info reports it: whether the
   --  motors run it, the driver's read and invalid reply counts, the cycle
   --  counter at the driver's last interrupt and at its completed direction
   --  change with the clock's cycles per microsecond, each motor's replies
   --  and RPM, each motor's reply counts over the last second, and the times
   --  of the decoder's last edges.
   Max_GCR_Edges : constant := 22;
   type Edge_Times is array (1 .. Max_GCR_Edges) of Interfaces.Unsigned_32;
   type Motor_Qualities is array (DShot.Motor_Index) of DShot.Quality;
   subtype Cycles_Per_Us is Interfaces.Unsigned_32 range 1 .. Interfaces.Unsigned_32'Last;
   type DShot_Status is record
      Enabled         : Boolean := False;
      Reads           : Interfaces.Unsigned_32 := 0;
      Invalid_Replies : Interfaces.Unsigned_32 := 0;
      Interrupt_Cycle : Interfaces.Unsigned_32 := 0;
      Direction_Cycle : Interfaces.Unsigned_32 := 0;
      Clock_Rate      : Cycles_Per_Us := 168;
      Telemetry       : DShot.Telemetry;
      Quality         : Motor_Qualities;
      Edges           : Edge_Times := (others => 0);
   end record;

   --  The SD card as sd_info reports it: whether the card is inserted, works
   --  and finished its start, its manufacturer, size in blocks, production
   --  month and year, revision and the five bytes of its name, and the file
   --  system's state with its last error.
   type SD_State is (Unknown, Fatal, Initializing, Ready);
   type SD_Error is (No_Error, Generic_Error, Bad_MBR, Bad_Header);
   type SD_Card_Status is record
      Inserted     : Boolean := False;
      Functional   : Boolean := False;
      Initialized  : Boolean := False;
      Manufacturer : Interfaces.Unsigned_8 := 0;
      Blocks       : Interfaces.Unsigned_32 := 0;
      Month        : Interfaces.Unsigned_8 := 0;
      Year         : Interfaces.Unsigned_16 := 0;
      Major        : Interfaces.Unsigned_8 := 0;
      Minor        : Interfaces.Unsigned_8 := 0;
      Name         : String (1 .. 5) := (others => ASCII.NUL);
      State        : SD_State := Unknown;
      Last_Error   : SD_Error := No_Error;
   end record;

   --  The flash chip as flash_info reports it: its geometry, its partition
   --  table with the count of partitions set, and the flash file system's
   --  offset. A partition's kind numbers the unknown, partition table, flash
   --  file system, bad block, firmware and configuration kinds.
   Max_Flash_Partitions : constant := 6;
   Flash_File_System    : constant := 2;
   type Flash_Partition is record
      Kind         : Natural range 0 .. 5 := 0;
      First_Sector : Interfaces.Unsigned_16 := 0;
      Last_Sector  : Interfaces.Unsigned_16 := 0;
   end record;
   type Flash_Partitions is array (0 .. Max_Flash_Partitions - 1) of Flash_Partition;
   type Flash_Status is record
      Sectors          : Interfaces.Unsigned_16 := 0;
      Sector_Size      : Interfaces.Unsigned_32 := 0;
      Pages_Per_Sector : Interfaces.Unsigned_16 := 0;
      Page_Size        : Interfaces.Unsigned_16 := 0;
      Total_Size       : Interfaces.Unsigned_32 := 0;
      JEDEC_Id         : Interfaces.Unsigned_32 := 0;
      Count            : Natural range 0 .. Max_Flash_Partitions := 0;
      Partitions       : Flash_Partitions;
      Used             : Interfaces.Unsigned_32 := 0;
   end record;

   --  The build's option numbers, as the build information message sends
   --  them, up to 64.
   Max_Build_Options : constant := 64;
   type Build_Option_List is array (1 .. Max_Build_Options) of Interfaces.Unsigned_16;

   --  A device's bus as the peripherals command names it: none, an SPI bus
   --  by number, or an I2C bus by number with the device's address.
   type Bus_Kind is (No_Bus, SPI_Bus, I2C_Bus);
   type Device_Bus is record
      Kind    : Bus_Kind := No_Bus;
      Number  : Natural range 0 .. 15 := 0;
      Address : Interfaces.Unsigned_8 := 0;
   end record;

   --  A serial port of the target's list: whether the board has it, and the
   --  functions it opened with, none when it did not open.
   type Serial_Port_Status is record
      Available     : Boolean := False;
      Open_Function : Interfaces.Unsigned_32 := 0;
   end record;
   type Serial_Port_Statuses is array (1 .. Serial_Feature_Map.Max_Ports) of Serial_Port_Status;

   --  The motor's ordinal each DMA stream drives, zero for a free stream, from
   --  the first controller's stream 0 to the second's stream 7.
   type DMA_Motor_List is array (1 .. 16) of Natural range 0 .. 8;

   subtype Timer_Owner is CLI_Resources.Timer_Owner;
   subtype Timer_Owner_List is CLI_Resources.Timer_Owner_List;

   --  A gyro's interrupt mode as its SPI driver sets it.
   type Gyro_Mode is (Interrupt_Init, Interrupt_DMA, Interrupt, No_Interrupt);

   --  A detected gyro by position: its hardware by gyro hardware code, its
   --  bus, its interrupt mode, and the device count of its bus, zero without
   --  one.
   Max_Gyro_Positions  : constant := 4;
   Gyro_Hardware_Count : constant := 30;
   type Gyro_Device is record
      Hardware    : Natural range 0 .. Gyro_Hardware_Count - 1 := 0;
      Bus         : Device_Bus;
      Mode        : Gyro_Mode := Interrupt_Init;
      Bus_Devices : Interfaces.Unsigned_8 := 0;
   end record;
   type Gyro_Devices is array (0 .. Max_Gyro_Positions - 1) of Gyro_Device;

   --  A sensor's detection, the hardware detected by the code of its
   --  hardware setting, and its bus.
   type Sensor_Device is record
      Detected : Boolean := False;
      Hardware : Interfaces.Unsigned_8 := 0;
      Bus      : Device_Bus;
   end record;

   --  The GPS receiver as the status command reports it: the link's state,
   --  the u-blox platform, the baud rate index its port runs at, and the
   --  solution with the signal of each satellite channel.
   Max_GPS_Channels : constant := 32;
   type Signal_Levels is array (1 .. Max_GPS_Channels) of Interfaces.Unsigned_8;
   type GPS_Status is record
      State       : GPS_Link.Link_State := GPS_Link.Unknown;
      Platform    : GPS_Frames.Platform := GPS_Frames.Undefined;
      Port_Baud   : Serial_Feature_Map.Baud_Index := Serial_Feature_Map.Baud_Auto;
      Satellites  : Interfaces.Unsigned_8 := 0;
      HDOP        : Interfaces.Unsigned_16 := 0;
      VDOP        : Interfaces.Unsigned_16 := 0;
      Fix         : Boolean := False;
      Latitude    : Interfaces.Integer_32 := 0;
      Longitude   : Interfaces.Integer_32 := 0;
      Altitude_Cm : Interfaces.Integer_32 := 0;
      Time_Valid  : Boolean := False;
      Year        : Interfaces.Unsigned_16 := 0;
      Month       : Interfaces.Unsigned_8 := 0;
      Day         : Interfaces.Unsigned_8 := 0;
      Hour        : Interfaces.Unsigned_8 := 0;
      Minute      : Interfaces.Unsigned_8 := 0;
      Second      : Interfaces.Unsigned_8 := 0;
      Channels    : Natural range 0 .. Max_GPS_Channels := 0;
      Signals     : Signal_Levels := (others => 0);
   end record;

   --  The board as the status command reports it: the MCU's name and clock,
   --  whether the platform reports its clock sources with the system clock's
   --  source and the PLL's, whether it reads the internal ADC with the
   --  reference voltage in millivolts and the core temperature, whether it
   --  checks its stack with the stack's size, top and use, the stored
   --  configuration's size and the storage's, the SPI and I2C devices with
   --  the I2C errors, the OSD's display port device, whether it has a port
   --  with its columns and rows, the build key and the release name where
   --  the build has them, the millisecond clock, the real-time clock, the
   --  battery's voltage in hundredths of a volt with its cells and state, and
   --  the reasons arming is disabled.
   type System_Status is record
      MCU_Name         : Identity_Text;
      Core_Clock_Hz    : Interfaces.Unsigned_32 := 0;
      Clock_Sources    : Boolean := False;
      System_Source    : Natural range 0 .. 3 := 0;
      PLL_Source       : Natural range 0 .. 1 := 0;
      Internal_ADC     : Boolean := False;
      Vref_Mv          : Interfaces.Unsigned_16 := 0;
      Core_Temp_C      : Interfaces.Integer_16 := 0;
      Stack_Check      : Boolean := False;
      Stack_Total      : Interfaces.Unsigned_32 := 0;
      Stack_High       : Interfaces.Unsigned_32 := 0;
      Stack_Used       : Interfaces.Unsigned_32 := 0;
      Config_Size      : Interfaces.Unsigned_16 := 0;
      Storage_Size     : Interfaces.Unsigned_32 := 0;
      SPI_Devices      : Interfaces.Unsigned_8 := 0;
      I2C_Devices      : Interfaces.Unsigned_8 := 0;
      I2C_Errors       : Interfaces.Unsigned_16 := 0;
      OSD_Device       : Natural range 0 .. 5 := 0;
      OSD_Port         : Boolean := False;
      OSD_Columns      : Interfaces.Unsigned_8 := 0;
      OSD_Rows         : Interfaces.Unsigned_8 := 0;
      Has_Build_Key    : Boolean := False;
      Build_Key        : Identity_Text;
      Has_Release_Name : Boolean := False;
      Release_Name     : Identity_Text;
      Uptime_Ms        : Interfaces.Unsigned_32 := 0;
      Clock            : RTC.Clock;
      Battery_Voltage  : Interfaces.Unsigned_16 := 0;
      Battery_Cells    : Interfaces.Unsigned_8 := 0;
      Battery_State    : Battery.Battery_State := Battery.OK;
      Arming_Disabled  : Arming.Disable_Set := (others => False);
   end record;

   --  What the commands report from outside the configuration: the flight
   --  plan executor's state, the firmware's name, the target's name, the
   --  version, the build's date, time and revision, the MCU's unique id, the
   --  clock in microseconds as the command runs, the running debug mode,
   --  whether a video transmitter is present with the power levels it
   --  reports, the running RC smoothing, the mixer's motors with their output
   --  and whether the 3D feature runs, the receiver and serial protocol the
   --  board took at its start, the motors' DShot telemetry, the SD card, the
   --  flash chip, whether the mass storage is ready, whether the motors run
   --  DShot, whether the ESC sensor feature runs, the build's option numbers,
   --  whether the soft serial feature runs, the serial ports in the order of
   --  the target's list, the command line's own port, the build's gyro
   --  positions with the gyros enabled and the hardware and bus of each, and
   --  the accelerometer, the barometer and the compass as the board detected
   --  them, the rangefinder, the optical flow sensor and the pitot with the
   --  accelerometer's revision, whether the GPS feature runs with the
   --  receiver's state, the board's status, whether the raw gyro's detected
   --  sensor is an ICM-45605 or an ICM-45686, whose registers sit elsewhere,
   --  and whether a terminal drives the session, where an unknown command
   --  gets the interactive error line.
   type Environment is record
      Navigation      : Navigation_Status;
      Firmware        : Identity_Text;
      Target          : Identity_Text;
      Version         : Identity_Text;
      Build_Date      : Identity_Text;
      Build_Time      : Identity_Text;
      Revision        : Identity_Text;
      MCU_Id          : MCU_Words := (others => 0);
      Now_Us          : Interfaces.Unsigned_32 := 0;
      Debug_Mode      : Interfaces.Unsigned_8 := 0;
      VTX_Present     : Boolean := False;
      VTX_Power       : Power_Levels;
      Smoothing       : Smoothing_Status;
      Motors          : MSP_Motor_In.Motor_Count := 0;
      Motor_Device    : MSP_Motor_In.Device_Kind := MSP_Motor_In.No_Device;
      Three_D         : Boolean := False;
      Receiver_Source : Receiver.Provider := Receiver.None;
      Serial_Protocol : Natural := 0;
      DShot_Telemetry : DShot_Status;
      SD_Card         : SD_Card_Status;
      Flash           : Flash_Status;
      MSC_Ready       : Boolean := False;
      DShot_Protocol  : Boolean := False;
      ESC_Sensor      : Boolean := False;
      Build_Options   : Build_Option_List := (others => 0);
      Option_Count    : Natural range 0 .. Max_Build_Options := 0;
      Soft_Serial     : Boolean := False;
      Serial_Ports    : Serial_Port_Statuses;
      CLI_Port        : Interfaces.Integer_32 := 20;
      Gyro_Positions  : Positive range 1 .. Max_Gyro_Positions := 1;
      Gyros_Enabled   : Interfaces.Unsigned_8 := 0;
      Gyros           : Gyro_Devices;
      Acc             : Sensor_Device;
      Baro            : Sensor_Device;
      Mag             : Sensor_Device;
      Rangefinder     : Sensor_Device;
      Optical_Flow    : Sensor_Device;
      Pitot           : Sensor_Device;
      Acc_Revision    : Interfaces.Unsigned_8 := 0;
      GPS_Enabled     : Boolean := False;
      GPS             : GPS_Status;
      Status          : System_Status;
      Raw_Gyro_ICM456 : Boolean := False;
      Interactive     : Boolean := False;
      DMA_Motors      : DMA_Motor_List := (others => 0);
      Timer_Owners    : Timer_Owner_List := (others => <>);
   end record;

   --  The board's information as the commands see it: its name and
   --  manufacturer and whether the stored configuration set them, whether a
   --  command changed them, and the same for its signature.
   subtype Board_State is Board_Info.State;

   --  The stored board information taken in as the board starts: the name
   --  and the manufacturer when they are set, the signature when it is set.
   procedure Init_Board (Board : in out Board_State; C : Configuration) renames Board_Info.Init;

   --  A typed line without its line end: printable characters past the
   --  leading spaces, up to 255 of them, a comment from the first number sign
   --  and trailing spaces cut, then its command run, or the ERR_CMD_NA reply
   --  for a line naming no command. Sched is the scheduler's state, which the
   --  tasks command reads and whose peak times it resets.
   procedure Process_Line
     (Into : in out Output; C : in out Configuration; Line : String; Ports : Port_List; Env : Environment;
      Board : in out Board_State; Sched : in out Scheduler.State; Changes : out Effects)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports;

   --  The command names in the order of the reference's table, which the
   --  terminal's completion walks.
   function Command_Count return Positive;

   function Command_Name (Position : Positive) return String
     with Pre  => Position <= Command_Count,
          Post => Command_Name'Result'Length in 1 .. 20;

end Adaflight.Command_Line;
