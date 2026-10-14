--  Command line: the line a user types, its comment and trailing spaces cut,
--  and the commands over the configuration's settings. get lists every
--  setting whose name contains a fragment, with its value, profile, range and
--  default; set lists every setting, or reads a value for one setting by its
--  name; profile, rateprofile and battery_profile show or select a profile;
--  dump and diff list a profile's or a rate profile's settings. The text goes
--  out through Put into a sink.
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

   --  Every setting whose name contains the fragment without regard to case,
   --  or an invalid name error; Command names the command in errors.
   procedure Get (Into : in out Sink; C : Configuration; Command : String; Fragment : String; Ports : Port_List)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports;

   --  Every setting's value, with each direct setting's range for an
   --  asterisk; a value for the setting named before an equals sign; or get
   --  for arguments without one.
   procedure Set (Into : in out Sink; C : in out Configuration; Arguments : String; Ports : Port_List)
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

   --  A typed line without its line end: printable characters past the
   --  leading spaces, up to 255 of them, a comment from the first number sign
   --  and trailing spaces cut, then its command run. Known is false for a
   --  line naming no command, and for dump and diff of other sections than a
   --  profile's and a rate profile's.
   procedure Process_Line
     (Into : in out Sink; C : in out Configuration; Line : String; Ports : Port_List; Known : out Boolean;
      Changes : out Effects)
     with Pre => Valid (Current (C)) and then Ports'Length <= Serial_Feature_Map.Max_Ports;

end Adaflight.Command_Line;
