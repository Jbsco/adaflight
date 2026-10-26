--  The configuration's views for the MSP out replies. Each out unit reads a
--  snapshot the caller gathers; these functions fill a snapshot's stored part
--  from the configuration, and take what the board detects, measures or
--  builds in from the caller. The mode conditions, adjustment ranges, channel
--  map and failsafe channels come out in the runtime types the flight tasks
--  read, so a target loads them from here as well. A stored value past its
--  runtime type (a mode past the boxes, a function past the adjustments, a
--  channel past the eighteen, a step past the range) leaves that entry empty.
with Interfaces;
with Adaflight.Adjustments;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.Modes;
with Adaflight.MSP_Box;
with Adaflight.MSP_Common_Out;
with Adaflight.MSP_Hardware_Out;
with Adaflight.MSP_OSD_Out;
with Adaflight.MSP_Peripheral_Out;
with Adaflight.MSP_Receiver_Out;
with Adaflight.MSP_Serial_Out;
with Adaflight.MSP_Text_Out;
with Adaflight.MSP_Tuning_Out;
with Adaflight.OSD_Task;
with Adaflight.OSD_Warnings;
with Adaflight.Receiver;

package Adaflight.MSP_Views with SPARK_Mode is
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;

   --  The profiles the configuration selects are among its profiles.
   function Profiles_Valid (C : Configuration) return Boolean is
     (Natural (C.System_Config.Pid_Profile_Index) < C.Pid_Profiles'Length
      and then Natural (C.System_Config.Active_Rate_Profile) < C.Control_Rate_Profiles'Length
      and then Natural (C.System_Config.Active_Battery_Profile) < C.Battery_Profiles'Length);

   function Mode_Conditions (C : Configuration) return Modes.Conditions;

   --  The user box names, each up to its first zero byte.
   function Box_Names (C : Configuration) return MSP_Box.User_Names;

   function Adjustment_Ranges (C : Configuration) return Adjustments.Ranges;

   --  A map entry past the channels keeps its own position.
   function Channel_Map (C : Configuration) return Receiver.Channel_Map;

   --  A mode past the three reads as invalid and a step past the range as the
   --  last step.
   function Failsafe_Channels (C : Configuration) return Receiver.Failsafe_Channels;

   --  Build names the options built in and Detected_Flags the gyros detected.
   function Tuning_View
     (C : Configuration; Build : MSP_Tuning_Out.Build_Options; Detected_Flags : Unsigned_8)
      return MSP_Tuning_Out.Snapshot
     with Pre => Profiles_Valid (C);

   --  The receiver options built in and the running channel count.
   type Receiver_Options is record
      RX_SPI        : Boolean := True;
      RC_Smoothing  : Boolean := True;
      USB_HID       : Boolean := True;
      ExpressLRS    : Boolean := True;
      Channel_Count : Natural range 0 .. Receiver.Channel_Count := 0;
   end record;

   function Receiver_View (C : Configuration; O : Receiver_Options) return MSP_Receiver_Out.Snapshot;

   --  What the board reports to the hardware replies: the sensors, GPS,
   --  rescue, flight log, DShot telemetry and ESC sensor built in, the
   --  sensors and gyros detected, the motors in use with their telemetry,
   --  the log's rate values, and the flash and SD card state.
   type Hardware_Runtime is record
      Built               : MSP_Hardware_Out.Sensor_Flags := (others => True);
      GPS                 : Boolean := True;
      Rescue              : Boolean := True;
      Blackbox            : Boolean := True;
      DShot_Telemetry     : Boolean := True;
      ESC_Sensor          : Boolean := True;
      Detected            : MSP_Hardware_Out.Sensor_Bytes := (others => 0);
      Gyro_Count          : Natural range 0 .. MSP_Hardware_Out.Max_Gyros := 0;
      Detected_Gyros      : MSP_Hardware_Out.Gyro_Bytes := (others => 0);
      Motor_Count         : Unsigned_8 := 0;
      Use_DShot_Telemetry : Boolean := False;
      Rate_Denom          : Unsigned_8 := 0;
      P_Ratio             : Unsigned_16 := 0;
      Flash               : MSP_Hardware_Out.Flash_Values;
      SD_Card             : MSP_Hardware_Out.SD_Card_Values;
   end record;

   function Hardware_View (C : Configuration; R : Hardware_Runtime) return MSP_Hardware_Out.Snapshot;

   --  What the board reports to the peripheral replies: the servos with their
   --  outputs, the LED strip and its status mode, and the video transmitter.
   type Peripheral_Runtime is record
      Servos       : Boolean := True;
      Servo_Count  : Positive range 1 .. MSP_Peripheral_Out.Max_Servos := MSP_Peripheral_Out.Max_Servos;
      Outputs      : MSP_Peripheral_Out.Servo_Outputs := (others => 0);
      LED_Strip    : Boolean := True;
      Status_Mode  : Boolean := True;
      VTX_Built    : Boolean := True;
      VTX_Device   : Boolean := False;
      VTX_Type     : Unsigned_8 := 16#FF#;
      VTX_Pit_Mode : Boolean := False;
      VTX_Ready    : Boolean := False;
      VTX_Table    : Boolean := True;
   end record;

   function Peripheral_View (C : Configuration; R : Peripheral_Runtime) return MSP_Peripheral_Out.Snapshot
     with Pre => Profiles_Valid (C);

   --  The target's ports with their availability.
   function Serial_View
     (C : Configuration; Ports : MSP_Serial_Out.Port_Entries; Count : Natural) return MSP_Serial_Out.Snapshot
     with Pre => Count <= MSP_Serial_Out.Max_Ports;

   --  The build's key and release name, and the LED strip and VTX table built in.
   type Text_Runtime is record
      Build_Key    : MSP_Text_Out.Optional_Text;
      Release_Name : MSP_Text_Out.Optional_Text;
      LED_Strip    : Boolean := True;
      Table        : Boolean := True;
   end record;

   function Text_View (C : Configuration; R : Text_Runtime) return MSP_Text_Out.Snapshot
     with Pre => Profiles_Valid (C);

   --  What the board reports to the OSD replies: the OSD options built in,
   --  the request's port, the display device and its readiness, and the
   --  warning line shown.
   type OSD_Runtime is record
      OSD                 : Boolean := True;
      Video_System_Option : Boolean := True;
      Profiles            : Boolean := True;
      Stick_Overlay       : Boolean := True;
      Display_Port_Font   : Boolean := True;
      Frame_Buffer_OSD    : Boolean := True;
      VTX_Port            : Boolean := False;
      Device              : OSD_Task.Device_Kind := OSD_Task.None;
      Device_Ready        : Boolean := False;
      Warning_Line        : OSD_Warnings.Text;
      Warning_Blinking    : Boolean := False;
      Warning_Severity    : OSD_Warnings.Severity := OSD_Warnings.Normal;
   end record;

   function OSD_View (C : Configuration; R : OSD_Runtime) return MSP_OSD_Out.Snapshot;

   --  The stored part of the common replies: the features, the beeper flags,
   --  the battery settings with the meter sources, the voltage sensor and
   --  current meter settings, the transponder and the OSD canvas. The
   --  firmware identity, the board and the meter readings stay the caller's.
   procedure Common_View (C : Configuration; V : in out MSP_Common_Out.Snapshot)
     with Pre  => Profiles_Valid (C),
          Post => V.Meters.Voltage_Count = V.Meters.Voltage_Count'Old
                  and then V.Meters.Current_Count = V.Meters.Current_Count'Old
                  and then V.Meters.ESC_Sensor = V.Meters.ESC_Sensor'Old
                  and then V.Meters.Motor_Count = V.Meters.Motor_Count'Old;

end Adaflight.MSP_Views;
