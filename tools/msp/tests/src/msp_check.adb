with Ada.Command_Line;
with Ada.Text_IO;
with Model_Board;
with MSP.Frames;
with MSP.Session;
with MSP.Transport;

--  Checks of the MSP client against the model of a flight controller's port.
procedure MSP_Check is

   use Ada.Text_IO;
   use type MSP.Byte;
   use type MSP.Byte_Array;
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

   if Failures = 0 then
      Put_Line ("msp checks passed");
   else
      Put_Line ("msp checks FAILED:" & Natural'Image (Failures));
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end MSP_Check;
