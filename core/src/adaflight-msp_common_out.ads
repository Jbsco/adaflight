--  The MSP out messages every MSP host answers: the protocol and API
--  versions, the firmware variant and version, the MCU, board and build
--  information, the unique id, the feature and beeper configuration, the
--  voltage and current meters with their sensors' configuration, the battery
--  and transponder configuration, and the OSD canvas. The caller gathers the
--  firmware's identity, the target's options, the configuration and the
--  meter readings into a snapshot; the meters come in the target's meter
--  order. Each reply narrows its values to the field widths of the protocol:
--  voltages round to tenths, consumption and current saturate, and the year
--  and the cell voltages in tenths wrap to a byte.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;

package Adaflight.MSP_Common_Out with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_16;

   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   API_Version_Command          : constant := 1;
   FC_Variant_Command           : constant := 2;
   FC_Version_Command           : constant := 3;
   Board_Info_Command           : constant := 4;
   Build_Info_Command           : constant := 5;
   Battery_Config_Command       : constant := 32;
   Feature_Config_Command       : constant := 36;
   Current_Meter_Config_Command : constant := 40;
   Voltage_Meter_Config_Command : constant := 56;
   Transponder_Config_Command   : constant := 82;
   Voltage_Meters_Command       : constant := 128;
   Current_Meters_Command       : constant := 129;
   UID_Command                  : constant := 160;
   Beeper_Config_Command        : constant := 184;
   OSD_Canvas_Command           : constant := 189;
   MCU_Info_Command             : constant := 16#300C#;

   Protocol_Version   : constant := 0;
   API_Version_Major  : constant := 1;
   API_Version_Minor  : constant := 49;
   Calendar_Base_Year : constant := 2000;
   MCU_Type_By_Name   : constant := 254;

   Max_Text          : constant := 32;
   Signature_Length  : constant := 32;
   Max_Build_Options : constant := 64;
   Max_Meters        : constant := 16;
   Max_Voltage_ADC   : constant := 4;
   ESC_Meter_Count   : constant := 12;
   Max_Motors        : constant := 8;
   Max_Reply_Length  : constant := 26 + 2 * Max_Build_Options;

   subtype Text_Length is Natural range 0 .. Max_Text;
   type Text is record
      Length : Text_Length := 0;
      Data   : String (1 .. Max_Text) := (others => ' ');
   end record;

   subtype Four_Letters is String (1 .. 4);
   type Build_Options is array (1 .. Max_Build_Options) of Unsigned_16;
   type UID_Words is array (1 .. 3) of Unsigned_32;

   --  The firmware: its four letter variant, its calendar version and the
   --  version text, the MCU's name, the build date, time and revision with
   --  the option codes it was built with, and the MCU's unique id.
   type Firmware_Values is record
      Variant        : Four_Letters := "    ";
      Year           : Natural range Calendar_Base_Year .. Calendar_Base_Year + 255 := Calendar_Base_Year;
      Month          : Unsigned_8 := 0;
      Patch          : Unsigned_8 := 0;
      Version        : Text;
      MCU_Name       : Text;
      Build_Date     : String (1 .. 11) := (others => ' ');
      Build_Time     : String (1 .. 8) := (others => ' ');
      Revision       : String (1 .. 7) := (others => ' ');
      Options        : Build_Options := (others => 0);
      Option_Count   : Natural range 0 .. Max_Build_Options := 0;
      UID            : UID_Words := (others => 0);
   end record;

   --  The board: its identifier and hardware revision, the OSD chip, the
   --  target's capabilities (USB serial, soft serial, flash boot loader,
   --  receiver bind), the target, board and manufacturer names when the
   --  board information is built in, the signature, the configuration
   --  state, the gyro's sample rate in hertz, the configuration problems,
   --  and the SPI and I2C device counts.
   type Board_Values is record
      Identifier              : Four_Letters := "    ";
      Hardware_Revision       : Unsigned_16 := 0;
      MAX7456                 : Boolean := False;
      VCP                     : Boolean := False;
      Soft_Serial             : Boolean := False;
      Flash_Boot_Loader       : Boolean := False;
      RX_Bind                 : Boolean := False;
      Target_Name             : Text;
      Board_Info              : Boolean := False;
      Board_Name              : Text;
      Manufacturer            : Text;
      Signature               : Byte_Array (1 .. Signature_Length) := (others => 0);
      Configuration_State     : Unsigned_8 := 0;
      Gyro_Rate_Hz            : Unsigned_32 := 0;
      Acc_Needs_Calibration   : Boolean := False;
      Motor_Protocol_Disabled : Boolean := False;
      SPI_Devices             : Unsigned_8 := 0;
      I2C_Devices             : Unsigned_8 := 0;
   end record;

   --  A meter's reading by its id: the displayed voltage in hundredths of a
   --  volt, the consumption in milliampere hours and the current in
   --  hundredths of an ampere.
   subtype Centiamps is Integer_32 range -2 ** 24 .. 2 ** 24;
   subtype Charge_mAh is Integer_32 range -2 ** 30 .. 2 ** 30;
   type Voltage_Reading is record
      Id               : Unsigned_8 := 0;
      Display_Filtered : Unsigned_16 := 0;
   end record;
   type Current_Reading is record
      Id        : Unsigned_8 := 0;
      mAh_Drawn : Charge_mAh := 0;
      Amperage  : Centiamps := 0;
   end record;
   type Voltage_Readings is array (1 .. Max_Meters) of Voltage_Reading;
   type Current_Readings is array (1 .. Max_Meters) of Current_Reading;

   --  An analog voltage sensor's configuration, with the id of its meter.
   type Voltage_Sensor is record
      Id         : Unsigned_8 := 0;
      Scale      : Unsigned_8 := 0;
      Divider    : Unsigned_8 := 0;
      Multiplier : Unsigned_8 := 0;
   end record;
   type Voltage_Sensors is array (1 .. Max_Voltage_ADC) of Voltage_Sensor;

   --  The meters the target supports and their readings, with the ESC
   --  sensor's per-motor meters past the motor count left out of the
   --  readings; the analog voltage sensors; the analog and, when built in,
   --  the virtual current sensors' scale and offset.
   type Meter_Values is record
      Voltage_Count  : Natural range 0 .. Max_Meters := 0;
      Voltages       : Voltage_Readings;
      Current_Count  : Natural range 0 .. Max_Meters := 0;
      Currents       : Current_Readings;
      ESC_Sensor     : Boolean := False;
      Motor_Count    : Natural range 0 .. Max_Motors := 0;
      Sensor_Count   : Natural range 1 .. Max_Voltage_ADC := 1;
      Sensors        : Voltage_Sensors;
      Current_Scale  : Integer_16 := 0;
      Current_Offset : Integer_16 := 0;
      Virtual        : Boolean := False;
      Virtual_Scale  : Integer_16 := 0;
      Virtual_Offset : Integer_16 := 0;
   end record;

   --  The meters a reply lists: all the target supports, less the ESC
   --  sensor's per-motor slots past the motor count.
   function Listed (Count : Natural; V : Meter_Values) return Integer is
     (if V.ESC_Sensor then Count - (ESC_Meter_Count - V.Motor_Count) else Count);

   --  The battery profile's cell voltages in hundredths of a volt and its
   --  capacity, and the meter sources by their protocol codes.
   type Battery_Values is record
      Min_Cell       : Unsigned_16 := 0;
      Max_Cell       : Unsigned_16 := 0;
      Warning_Cell   : Unsigned_16 := 0;
      Capacity       : Unsigned_16 := 0;
      Voltage_Source : Unsigned_8 := 0;
      Current_Source : Unsigned_8 := 0;
   end record;

   Transponder_Data_Length : constant := 9;
   subtype Transponder_Provider is Natural range 0 .. 3;
   type Transponder_Values is record
      Built_In : Boolean := False;
      Provider : Transponder_Provider := 0;
      Data     : Byte_Array (1 .. Transponder_Data_Length) := (others => 0);
   end record;

   type Snapshot is record
      Firmware         : Firmware_Values;
      Board            : Board_Values;
      VTX_Port         : Boolean := False;
      Features         : Unsigned_32 := 0;
      Beeper           : Boolean := False;
      Beeper_Off_Flags : Unsigned_32 := 0;
      Beacon_Tone      : Unsigned_8 := 0;
      Beacon_Off_Flags : Unsigned_32 := 0;
      Meters           : Meter_Values;
      Battery          : Battery_Values;
      Transponder      : Transponder_Values;
      OSD              : Boolean := False;
      Canvas_Columns   : Unsigned_8 := 0;
      Canvas_Rows      : Unsigned_8 := 0;
   end record;

   --  The ESC sensor's meters are all in the target's list.
   function Consistent (V : Snapshot) return Boolean is
     (Listed (V.Meters.Voltage_Count, V.Meters) in 0 .. Max_Meters
      and then Listed (V.Meters.Current_Count, V.Meters) in 0 .. Max_Meters);

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in API_Version_Command | FC_Variant_Command | FC_Version_Command | Board_Info_Command
               | Build_Info_Command | Battery_Config_Command | Feature_Config_Command
               | Current_Meter_Config_Command | Voltage_Meter_Config_Command | Transponder_Config_Command
               | Voltage_Meters_Command | Current_Meters_Command | UID_Command | Beeper_Config_Command
               | OSD_Canvas_Command | MCU_Info_Command);

   --  Whether the reply exists for this build: the beeper configuration
   --  needs the beeper. An unsupported reply is an error.
   function Supported (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Handles (Command) and then (Command /= Beeper_Config_Command or else V.Beeper));

   --  The reply to one of these out messages; any other command, or one not
   --  supported, writes nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length
                  and then Consistent (V),
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Supported (Command, V) then S.Next = S.Next'Old);

end Adaflight.MSP_Common_Out;
