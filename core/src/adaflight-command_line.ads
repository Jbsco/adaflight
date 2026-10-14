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
--  reports an error printed inside it.
--  The text goes out through Put into a sink, inside an Output that also
--  holds the batch's state.
with Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.CLI_Text;
with Adaflight.Serial_Feature_Map;

generic
   type Sink is limited private;
   with procedure Put (Into : in out Sink; Text : String);
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
   --  is open, and whether a command in it printed an error.
   type Output is limited record
      Target       : Sink;
      Batch_Active : Boolean := False;
      Batch_Error  : Boolean := False;
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
   --  layout changed.
   type Effects is record
      PID_Profile     : Boolean := False;
      Rate_Profile    : Boolean := False;
      Battery_Profile : Boolean := False;
      Modes           : Boolean := False;
      Adjustments     : Boolean := False;
      LEDs            : Boolean := False;
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
   Identity_Max : constant := 32;
   subtype Identity_Length is Natural range 0 .. Identity_Max;
   type Identity_Text is record
      Data   : String (1 .. Identity_Max) := (others => ' ');
      Length : Identity_Length := 0;
   end record;

   function To_Identity (Text : String) return Identity_Text
     with Pre  => Text'Length <= Identity_Max,
          Post => To_Identity'Result.Length = Text'Length;

   type MCU_Words is array (1 .. 3) of Interfaces.Unsigned_32;
   type Signature_Bytes is array (0 .. 31) of Interfaces.Unsigned_8;

   --  What the commands report from outside the configuration: the flight
   --  plan executor's state, the firmware's name, the target's name, the
   --  version, the build's date, time and revision, and the MCU's unique id.
   type Environment is record
      Navigation      : Navigation_Status;
      Firmware        : Identity_Text;
      Target          : Identity_Text;
      Version         : Identity_Text;
      Build_Date      : Identity_Text;
      Build_Time      : Identity_Text;
      Revision        : Identity_Text;
      MCU_Id          : MCU_Words := (others => 0);
   end record;

   --  The board's information as the commands see it: its name and
   --  manufacturer and whether the stored configuration set them, whether a
   --  command changed them, and the same for its signature.
   type Board_State is record
      Name                : Identity_Text;
      Manufacturer        : Identity_Text;
      Information_Set     : Boolean := False;
      Information_Updated : Boolean := False;
      Signature           : Signature_Bytes := (others => 0);
      Signature_Set       : Boolean := False;
      Signature_Updated   : Boolean := False;
   end record;

   --  The stored board information taken in as the board starts: the name
   --  and the manufacturer when they are set, the signature when it is set.
   procedure Init_Board (Board : in out Board_State; C : Configuration);

   --  A typed line without its line end: printable characters past the
   --  leading spaces, up to 255 of them, a comment from the first number sign
   --  and trailing spaces cut, then its command run. Known is false for a
   --  line naming no command, and for defaults without nosave, whose save and
   --  restart wait for the save command.
   procedure Process_Line
     (Into : in out Output; C : in out Configuration; Line : String; Ports : Port_List; Env : Environment;
      Board : in out Board_State; Known : out Boolean; Changes : out Effects)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports;

end Adaflight.Command_Line;
