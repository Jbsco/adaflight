--  MAVLink commands: the messages a ground station sends, drained from the
--  telemetry's own port or popped from the receiver's queue and dispatched.
--  Ping and time sync requests are answered. Command messages addressed to
--  this system are executed and acknowledged: autopilot version, protocol
--  version, component information, available modes and message interval
--  requests, message intervals, disarming, mode overrides, return to launch,
--  the home position and reboots. Arming over the link, an option the
--  default build leaves out, answers unsupported. Disarming, the mode
--  overrides and the home position go out as requests in call order; a
--  reboot waits for the end of the port's drain.
with Interfaces;
with Adaflight.MAVLink;
with Adaflight.MAVLink_Frames;
with Adaflight.MAVLink_Telemetry;
with Adaflight.Modes;

package Adaflight.MAVLink_Commands with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;

   type UID_Words is array (0 .. 2) of Unsigned_32;

   --  The firmware version the autopilot version reports, and the board's
   --  unique id.
   type Settings is record
      Version_Year  : Natural range 2000 .. 2255 := 2026;
      Version_Month : Unsigned_8 := 12;
      Version_Patch : Unsigned_8 := 0;
      UID           : UID_Words := (others => 0);
   end record;

   --  What the handlers read: arming, the GPS fix and the clock.
   type Inputs is record
      Armed   : Boolean := False;
      GPS_Fix : Boolean := False;
      Now_Us  : Unsigned_32 := 0;
      Now_Ms  : Unsigned_32 := 0;
   end record;

   type Request_Kind is (Disarm, Clear_Overrides, Set_Override, Reset_Home, Set_Home);

   --  One request: the box an override forces on, the home a set-home sets.
   type Request is record
      Kind        : Request_Kind := Disarm;
      Box         : Adaflight.Modes.Box := Adaflight.Modes.Angle;
      Latitude    : Integer_32 := 0;
      Longitude   : Integer_32 := 0;
      Altitude_Cm : Integer_32 := 0;
   end record;

   Max_Requests : constant := 32;
   type Request_List is array (1 .. Max_Requests) of Request;

   type Reboot_Kind is (None, Reset, Bootloader);

   --  The requests in call order, and the reboot a drain ends with.
   type Requests is record
      List   : Request_List;
      Count  : Natural range 0 .. Max_Requests := 0;
      Reboot : Reboot_Kind := None;
   end record;

   --  Sixteen dispatches of the longest reply pair, an autopilot version and
   --  its acknowledgement.
   Max_Output : constant := 1_792;
   subtype Output_Bytes is Adaflight.MAVLink_Frames.Byte_Buffer (1 .. Max_Output);
   type Output is record
      Data   : Output_Bytes := (others => 0);
      Length : Natural range 0 .. Max_Output := 0;
   end record;

   --  The owned port's frame parser and the reboot waiting for the drain's
   --  end.
   type State is record
      Port           : Adaflight.MAVLink.Frame_Parser;
      Reboot_Pending : Boolean := False;
      To_Bootloader  : Boolean := False;
   end record;

   Port_Budget  : constant := 64;
   Queue_Budget : constant := 16;

   --  One message: answered, or executed and acknowledged.
   procedure Dispatch
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      TC  : Adaflight.MAVLink_Telemetry.Settings;
      C   : Settings;
      Inp : Inputs;
      Msg : Adaflight.MAVLink.Message;
      O   : in out Output;
      R   : in out Requests);

   --  The owned port: up to sixty-four of the waiting bytes through the
   --  parser, each complete frame dispatched, then a pending reboot.
   procedure Process_Port
     (S        : in out State;
      T        : in out Adaflight.MAVLink_Telemetry.State;
      TC       : Adaflight.MAVLink_Telemetry.Settings;
      C        : Settings;
      Inp      : Inputs;
      Waiting  : Adaflight.MAVLink_Frames.Byte_Buffer;
      Consumed : out Natural;
      O        : out Output;
      R        : out Requests)
     with Post => Consumed = Natural'Min (Port_Budget, Waiting'Length);

   --  The receiver's queue: up to sixteen messages popped and dispatched; a
   --  reboot they accept stays pending.
   procedure Process_Queue
     (S   : in out State;
      T   : in out Adaflight.MAVLink_Telemetry.State;
      TC  : Adaflight.MAVLink_Telemetry.Settings;
      C   : Settings;
      Inp : Inputs;
      Rx  : in out Adaflight.MAVLink.State;
      O   : out Output;
      R   : out Requests);

end Adaflight.MAVLink_Commands;
