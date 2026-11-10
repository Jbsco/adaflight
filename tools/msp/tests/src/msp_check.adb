with Ada.Command_Line;
with Ada.Text_IO;
with Model_Board;
with MSP.Backups;
with MSP.Console;
with MSP.Frames;
with MSP.Session;
with MSP.Transport;

--  Checks of the MSP client against the model of a flight controller's port.
procedure MSP_Check is

   use Ada.Text_IO;
   use type MSP.Byte;
   use type MSP.Byte_Array;
   use type MSP.Backups.Lines;
   use type MSP.Console.Status;
   use type MSP.Frames.Step;
   use type MSP.Session.Status;

   Failures : Natural := 0;

   procedure Check (Name : String; Ok : Boolean) is
   begin
      Put_Line ((if Ok then "PASS " else "FAIL ") & Name);
      if not Ok then
         Failures := Failures + 1;
      end if;
   end Check;

   function Text (S : String) return MSP.Byte_Array is
   begin
      return Data : MSP.Byte_Array (1 .. S'Length) do
         for I in Data'Range loop
            Data (I) := Character'Pos (S (S'First + I - 1));
         end loop;
      end return;
   end Text;

   function Pattern (Length : Natural) return MSP.Byte_Array is
   begin
      return Data : MSP.Byte_Array (1 .. Length) do
         for I in Data'Range loop
            Data (I) := MSP.Byte ((3 * I + 1) mod 256);
         end loop;
      end return;
   end Pattern;

   Reply  : MSP.Session.Reply_Buffer;
   Last   : MSP.Frames.Payload_Length;
   Result : MSP.Session.Status;

   --  Whether the reply to a request is the model's answer for it.
   function Reply_Matches (Code : Natural; Request : MSP.Byte_Array; Length : Natural) return Boolean is
   begin
      if Last /= Length then
         return False;
      end if;
      for I in 1 .. Length loop
         if Reply (I) /= Model_Board.Reply_Byte (Code, Request, I) then
            return False;
         end if;
      end loop;
      return True;
   end Reply_Matches;

   --  One request against the model with the given settings, and whether its outcome is as wanted.
   procedure Exchange
     (Name    : String;
      S       : Model_Board.Settings;
      Code    : Natural;
      Request : MSP.Byte_Array;
      Want    : MSP.Session.Status;
      V2      : Boolean)
   is
   begin
      Model_Board.Configure (S);
      MSP.Session.Request (Code, Request, Reply, Last, Result);
      Check
        (Name,
         Result = Want
         and then (if Want = MSP.Session.Answered then Reply_Matches (Code, Request, S.Reply_Length) else Last = 0)
         and then (if S.Accept_Sends
                   then Model_Board.Good_Requests = 1 and then Model_Board.Bad_Requests = 0
                     and then Model_Board.Last_Code = Code and then Model_Board.Last_Length = Request'Length
                     and then Model_Board.Last_Was_V2 = V2
                   else Model_Board.Good_Requests = 0));
   end Exchange;

   LF    : constant Character := Character'Val (10);
   CR_LF : constant String := Character'Val (13) & LF;

   type Text_Access is access MSP.Console.Text_Buffer;
   Console_Text   : constant Text_Access := new MSP.Console.Text_Buffer;
   Console_Last   : MSP.Console.Text_Length;
   Console_Cut    : Boolean;
   Console_Result : MSP.Console.Status;

   --  A line to the model's command line, and the text that came back.
   procedure Say (Line : String; Quiet : Positive := 2; Patience : Positive := 6) is
   begin
      MSP.Console.Exchange
        (Text (Line), Quiet, Patience, Console_Text.all, Console_Last, Console_Cut, Console_Result);
   end Say;

   function Heard return String is
   begin
      return S : String (1 .. Console_Last) do
         for I in S'Range loop
            S (I) := Character'Val (Console_Text (I));
         end loop;
      end return;
   end Heard;

   function Prompted return Boolean
   is (Console_Result = MSP.Console.Prompted and then not Console_Cut
       and then MSP.Console.Ends_With_Prompt (Console_Text.all, Console_Last));

   function Lines_Of (Text : String) return MSP.Backups.Lines
   is (MSP.Backups.Split (Text));

   Frame      : MSP.Byte_Array (0 .. MSP.Frames.Max_Frame - 1);
   Frame_Last : Natural;
   D          : MSP.Frames.Decoder;
   Outcome    : MSP.Frames.Step;
   Completes  : Natural := 0;
   Opened     : Boolean;

begin
   MSP.Frames.Encode (1, Text (""), Frame, Frame_Last);
   Check ("request without a payload in the first version", Frame (0 .. Frame_Last) = Text ("$M<") & (0, 1, 1));
   MSP.Frames.Encode (200, (1, 2, 3, 4), Frame, Frame_Last);
   Check
     ("request with a payload in the first version",
      Frame (0 .. Frame_Last) = Text ("$M<") & (4, 200, 1, 2, 3, 4, 16#C8#));
   MSP.Frames.Encode (16#3005#, Text (""), Frame, Frame_Last);
   Check
     ("request with a two-byte command in the second version",
      Frame (0 .. Frame_Last) = Text ("$X<") & (0, 16#05#, 16#30#, 0, 0, 16#AF#));
   MSP.Frames.Encode (300, (16#AA#, 16#55#), Frame, Frame_Last);
   Check
     ("request with a payload in the second version",
      Frame (0 .. Frame_Last) = Text ("$X<") & (0, 16#2C#, 16#01#, 2, 0, 16#AA#, 16#55#, 16#51#));
   MSP.Frames.Encode (105, Pattern (254), Frame, Frame_Last);
   Check ("payload of 254 bytes stays in the first version", Frame (1) = Character'Pos ('M') and then Frame_Last = 259);
   MSP.Frames.Encode (105, Pattern (255), Frame, Frame_Last);
   Check ("payload of 255 bytes goes in the second version", Frame (1) = Character'Pos ('X') and then Frame_Last = 263);

   MSP.Frames.Reset (D);
   MSP.Frames.Encode (200, (1, 2, 3, 4), Frame, Frame_Last);
   for I in 0 .. Frame_Last loop
      MSP.Frames.Feed (D, Frame (I), Outcome);
      if Outcome /= MSP.Frames.Pending then
         Completes := Completes + 1;
      end if;
   end loop;
   Check ("decoder passes over a request frame", Completes = 0);

   Model_Board.Configure ((Present => False, others => <>));
   MSP.Transport.Open ("model", Opened);
   Check ("open reports an absent port", not Opened);
   Model_Board.Configure ((others => <>));
   MSP.Transport.Open ("model", Opened);
   Check ("open finds the port", Opened);

   Exchange ("empty reply to an empty request", (others => <>), 1, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply of three bytes", (Reply_Length => 3, others => <>), 1, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply to a request with a payload",
      (Reply_Length => 40, others => <>), 200, Pattern (12), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply of 254 bytes in the first version",
      (Reply_Length => 254, others => <>), 105, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply of 300 bytes in the first version's long form",
      (Reply_Length => 300, others => <>), 71, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("short reply in the first version's long form",
      (Reply_Length => 5, Jumbo => True, others => <>), 71, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply in the second version",
      (Reply_Length => 17, others => <>), 16#3005#, Text (""), MSP.Session.Answered, V2 => True);
   Exchange
     ("request and reply with long payloads in the second version",
      (Reply_Length => 1000, others => <>), 16#1F01#, Pattern (600), MSP.Session.Answered, V2 => True);
   Exchange
     ("reply of the largest payload",
      (Reply_Length => MSP.Frames.Max_Payload, Chunk => 256, others => <>), 16#3001#, Text (""),
      MSP.Session.Answered, V2 => True);
   Exchange
     ("reply that arrives one byte at a time",
      (Reply_Length => 33, Chunk => 1, others => <>), 112, Text (""), MSP.Session.Answered, V2 => False);
   Exchange ("refused request", (Refuse => True, others => <>), 9, Text (""), MSP.Session.Refused, V2 => False);
   Exchange
     ("refused request in the second version",
      (Refuse => True, others => <>), 16#3FFF#, Text (""), MSP.Session.Refused, V2 => True);
   Exchange
     ("reply after noise and frame starts that lead nowhere",
      (Reply_Length => 9, Noise_First => True, others => <>), 101, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply after a copy with a bad checksum",
      (Reply_Length => 9, Corrupt_First => True, others => <>), 101, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply after a frame of another command",
      (Reply_Length => 9, Other_First => True, others => <>), 101, Text (""), MSP.Session.Answered, V2 => False);
   Exchange
     ("reply after a frame with a payload too long to keep",
      (Reply_Length => 9, Long_First => True, Chunk => 200, others => <>), 16#3001#, Text (""),
      MSP.Session.Answered, V2 => True);
   Exchange
     ("silence ends as no reply", (Silent => True, others => <>), 101, Text (""), MSP.Session.No_Reply, V2 => False);
   Check ("silence is given up after the waits allowed", Model_Board.Empty_Reads = MSP.Session.Max_Waits);
   Exchange
     ("request that does not go out",
      (Accept_Sends => False, others => <>), 101, Text (""), MSP.Session.Not_Sent, V2 => False);

   Model_Board.Configure ((others => <>));
   Say ("#");
   Check
     ("command line's sign brings its prompt",
      Prompted and then Heard = CR_LF & "Entering CLI Mode, type 'exit' to return, or 'help'" & CR_LF & CR_LF & "# ");
   Say ("set a = 1" & LF);
   Check
     ("setting line is echoed and answered before the prompt",
      Prompted and then Heard = "set a = 1" & CR_LF & "a set to 1" & CR_LF & "# "
      and then Model_Board.Kept_Lines = 1 and then Model_Board.Kept_Line (1) = "set a = 1");
   Check
     ("reply's lines leave out the echo and the prompt",
      MSP.Backups.Reply_Lines (Heard) = Lines_Of ("a set to 1"));
   Say ("set bad = 1" & LF);
   Check
     ("refused line's reply has the error text",
      Prompted and then MSP.Backups.Reply_Lines (Heard) = Lines_Of ("###ERROR IN set: INVALID NAME: bad = 1###")
      and then Model_Board.Kept_Lines = 1);
   Say ("set b = 2" & LF);
   Say ("diff all" & LF);
   Check
     ("backup's lines arrive between the echo and the prompt",
      Prompted
      and then MSP.Backups.Reply_Lines (Heard)
               = Lines_Of
                   (LF & "# version" & LF & "# model" & LF & LF & "# start the command batch" & LF & "batch start"
                    & LF & LF & "# reset configuration to default settings" & LF & "defaults nosave" & LF & LF
                    & "set a = 1" & LF & "set b = 2" & LF & LF & "# save configuration" & LF & "save"));
   Say ("exit" & LF);
   Check
     ("exit ends without a prompt and drops unsaved lines",
      Console_Result = MSP.Console.No_Prompt and then Heard = "exit" & CR_LF & "Rebooting"
      and then Model_Board.Exits = 1 and then Model_Board.Saves = 0 and then Model_Board.Kept_Lines = 0);

   Model_Board.Configure ((others => <>));
   Say ("#");
   Say ("set a = 1" & LF);
   Say ("save" & LF);
   Check
     ("save ends without a prompt and keeps the lines",
      Console_Result = MSP.Console.No_Prompt and then Heard = "save" & CR_LF & "Saving" & CR_LF & "Rebooting"
      and then Model_Board.Saves = 1 and then Model_Board.Exits = 0);
   Say ("#");
   Say ("set c = 3" & LF);
   Say ("exit" & LF);
   Check ("exit keeps the lines saved before it", Model_Board.Kept_Lines = 1 and then Model_Board.Exits = 1);
   Say ("#");
   Say ("defaults nosave" & LF);
   Check ("reset to defaults drops every line", Prompted and then Model_Board.Kept_Lines = 0);

   --  A comment line of a backup starts as the prompt does. With one byte a read and an empty read after
   --  each, the text stops there unless more quiet than that is asked for.
   Model_Board.Configure ((Chunk => 1, Stall => 1, others => <>));
   Say ("#", Quiet => 2, Patience => 6);
   Say ("set a = 1" & LF, Quiet => 2, Patience => 6);
   Say ("diff all" & LF, Quiet => 2, Patience => 6);
   Check
     ("backup's comment lines do not end the text",
      Prompted and then MSP.Backups.Reply_Lines (Heard).Last_Element = "save"
      and then Natural (MSP.Backups.Reply_Lines (Heard).Length) = 14);
   Model_Board.Configure ((Chunk => 1, Stall => 1, others => <>));
   Say ("#", Quiet => 2, Patience => 6);
   Say ("diff all" & LF, Quiet => 1, Patience => 6);
   Check
     ("quiet of one read ends the text at a comment line",
      Prompted and then Heard = "diff all" & CR_LF & CR_LF & "# ");

   Model_Board.Configure ((No_Prompt => True, others => <>));
   Say ("#", Quiet => 2, Patience => 7);
   Check
     ("text without a prompt ends after the empty reads allowed",
      Console_Result = MSP.Console.No_Prompt and then not Console_Cut
      and then Heard = CR_LF & "Entering CLI Mode, type 'exit' to return, or 'help'" & CR_LF
      and then Model_Board.Empty_Reads = 7);

   Model_Board.Configure ((Dump_Lines => 2000, Chunk => 256, others => <>));
   Say ("#");
   Say ("dump all" & LF);
   Check
     ("dump of 2000 lines arrives whole",
      Prompted and then Console_Last = 10 + 2000 * 22 + 4
      and then Natural (MSP.Backups.Reply_Lines (Heard).Length) = 2001
      and then MSP.Backups.Reply_Lines (Heard).Element (2000) = "set name_2000 = 2000");
   Model_Board.Configure ((Dump_Lines => 4000, Chunk => 256, others => <>));
   Say ("#");
   Say ("dump all" & LF);
   Check
     ("dump past the text's size is cut at it",
      Console_Result = MSP.Console.Prompted and then Console_Cut and then Console_Last = MSP.Console.Max_Text
      and then Heard (1 .. 32) = "dump all" & CR_LF & "set name_0001 = 0001" & CR_LF);

   Model_Board.Configure ((Endless => True, others => <>));
   Say ("#");
   Check
     ("port that never goes quiet ends after the reads allowed",
      Console_Result = MSP.Console.No_Prompt and then Console_Cut and then Console_Last = MSP.Console.Max_Text
      and then Model_Board.Reads = MSP.Console.Max_Reads);

   Model_Board.Configure ((Accept_Sends => False, others => <>));
   Say ("#");
   Check ("line that does not go out", Console_Result = MSP.Console.Not_Sent and then Console_Last = 0);

   Check
     ("text splits at line feeds without the line ends",
      Natural (Lines_Of ("a" & CR_LF & " b " & LF & LF & "c").Length) = 4
      and then Lines_Of ("a" & CR_LF & " b " & LF & LF & "c").Element (2) = "b"
      and then Lines_Of ("a" & CR_LF & " b " & LF & LF & "c").Element (3) = ""
      and then Lines_Of ("a" & CR_LF).Last_Element = "a");
   Check
     ("restore sends commands and leaves out comments, empty lines and the save",
      MSP.Backups.Is_Command ("set a = 1") and then MSP.Backups.Is_Command ("defaults nosave")
      and then MSP.Backups.Is_Command ("batch start") and then MSP.Backups.Is_Command ("feature -GPS")
      and then not MSP.Backups.Is_Command ("") and then not MSP.Backups.Is_Command ("   ")
      and then not MSP.Backups.Is_Command ("# set a = 1") and then not MSP.Backups.Is_Command ("  # note")
      and then not MSP.Backups.Is_Command ("save") and then not MSP.Backups.Is_Command (" SAVE "));
   Check
     ("backups with equal content have no difference",
      MSP.Backups.Differences
        (Lines_Of ("# one" & LF & "batch start" & LF & "defaults nosave" & LF & "set a = 1" & LF & "feature GPS" & LF
                   & "profile 0" & LF & "set p = 4" & LF & "save"),
         Lines_Of ("feature GPS" & LF & LF & "set a = 1" & LF & "profile 0" & LF & "set p = 4" & LF & "# two"))
        .Is_Empty);
   Check
     ("differences by setting under each profile, in key order",
      MSP.Backups.Differences
        (Lines_Of ("set a = 1" & LF & "set b = 2" & LF & "set gone = 9" & LF & "feature GPS" & LF & "profile 0" & LF
                   & "set p = 40" & LF & "profile 1" & LF & "set p = 41" & LF & "rateprofile 2" & LF & "set r = 7"
                   & LF & "profile 0" & LF & "save"),
         Lines_Of ("set a = 1" & LF & "set b = 3" & LF & "feature OSD" & LF & "profile 0" & LF & "set p = 40" & LF
                   & "profile 1" & LF & "set p = 45" & LF & "set q = 5" & LF & "rateprofile 2" & LF & "set r = 7"
                   & LF & "profile 1"))
      = Lines_Of
          ("- feature GPS" & LF & "+ feature OSD" & LF & "~ profile: 0 -> 1" & LF & "~ profile 1: set p: 41 -> 45"
           & LF & "+ profile 1: set q = 5" & LF & "~ set b: 2 -> 3" & LF & "- set gone = 9"));

   if Failures = 0 then
      Put_Line ("msp checks passed");
   else
      Put_Line ("msp checks FAILED:" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end MSP_Check;
