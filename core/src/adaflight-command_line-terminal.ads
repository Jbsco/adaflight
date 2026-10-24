--  The command line's character layer: the session a port enters, the typed
--  characters gathered into a line, and the line handed to the commands. An
--  interactive session prints its banner and prompt, holds arming, echoes
--  each printable character past the leading spaces and keeps up to 255 of
--  them; a line end runs a non-empty line and prompts again; a tab or a
--  question mark completes the line over the command names as far as the
--  matching names agree and lists them when more than one matches; control-D
--  on an empty line leaves with a restart, control-L clears
--  the screen and prompts, and delete takes the last character back. A session
--  a configurator drives answers a start of text, takes the lines without
--  echo, and closes with an end of text at an end of text or at any byte two
--  seconds after its entry. A command that leaves the command line closes the
--  session. The completion lists only the names that match the typed text;
--  the reference lists every name between its first and last match (finding
--  F286).
with Adaflight.Bytes; use Adaflight.Bytes;

generic
package Adaflight.Command_Line.Terminal with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   Buffer_Size      : constant := 256;
   Entry_Timeout_Ms : constant := 2000;

   subtype Line_Length is Natural range 0 .. Buffer_Size - 1;
   subtype Line_Text is String (1 .. Buffer_Size - 1);

   --  Whether the session is open and interactive, the millisecond it was
   --  entered, the line typed so far, and whether an interactive entry has
   --  held arming, which stays held after the session.
   type Session is record
      Open        : Boolean := False;
      Interactive : Boolean := False;
      Entry_Ms    : Interfaces.Unsigned_32 := 0;
      Length      : Line_Length := 0;
      Text        : Line_Text := (others => ' ');
      Arming_Held : Boolean := False;
   end record;

   procedure Enter (T : in out Session; Into : in out Output; Interactive : Boolean; Now_Ms : Interfaces.Unsigned_32);

   --  The session closed without a restart; Changes notes the leave.
   procedure Leave (T : in out Session; Changes : in out Effects);

   --  The bytes waiting on the port, each taken as the reference's poll takes
   --  it, until a configurator session closes; the last line's effects stay in
   --  Changes, with the leave and the restart the session itself asks for.
   procedure Process
     (T      : in out Session;
      Into   : in out Output;
      Input  : Byte_Array;
      Now_Ms : Interfaces.Unsigned_32;
      C      : in out Configuration;
      Ports  : Port_List;
      Env    : Environment;
      Board  : in out Board_State;
      Sched  : in out Scheduler.State;
      Changes : in out Effects)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports;

end Adaflight.Command_Line.Terminal;
