with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with MSP.Backups;
with MSP.Codes;
with MSP.Console;
with MSP.Frames;
with MSP.Session;
with MSP.Transport;

--  Sends MSP requests to a flight controller on a serial port or a TCP port and prints its replies, and backs
--  up, restores and compares its configuration through its command line.
procedure Adaflight_MSP with SPARK_Mode => Off is

   use Ada.Command_Line;
   use Ada.Text_IO;
   use type MSP.Byte;
   use type MSP.Console.Status;

   Usage_Error : exception;
   Link_Error  : exception;

   Hex_Digits : constant String := "0123456789abcdef";
   Line_Feed  : constant Character := Ada.Characters.Latin_1.LF;

   function Decimal (N : Natural) return String
   is (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   function Hex (Data : MSP.Byte_Array) return String is
      Text : String (1 .. 2 * Data'Length);
   begin
      for I in Data'Range loop
         Text (2 * (I - Data'First) + 1) := Hex_Digits (Natural (Data (I) / 16) + 1);
         Text (2 * (I - Data'First) + 2) := Hex_Digits (Natural (Data (I) mod 16) + 1);
      end loop;
      return (if Text'Length = 0 then "-" else Text);
   end Hex;

   function Nibble (C : Character) return MSP.Byte is
   begin
      case C is
         when '0' .. '9' =>
            return Character'Pos (C) - Character'Pos ('0');
         when 'a' .. 'f' =>
            return Character'Pos (C) - Character'Pos ('a') + 10;
         when 'A' .. 'F' =>
            return Character'Pos (C) - Character'Pos ('A') + 10;
         when others =>
            raise Usage_Error with "'" & C & "' is not a hexadecimal digit";
      end case;
   end Nibble;

   function Bytes (Text : String) return MSP.Byte_Array is
   begin
      if Text = "-" then
         return (1 .. 0 => 0);
      elsif Text'Length mod 2 /= 0 or else Text'Length / 2 > MSP.Frames.Max_Payload then
         raise Usage_Error with "a payload is an even count of hexadecimal digits, at most"
           & Natural'Image (MSP.Frames.Max_Payload) & " bytes";
      end if;
      return Data : MSP.Byte_Array (1 .. Text'Length / 2) do
         for I in Data'Range loop
            Data (I) := Nibble (Text (Text'First + 2 * (I - 1))) * 16 + Nibble (Text (Text'First + 2 * I - 1));
         end loop;
      end return;
   end Bytes;

   function Command (Text : String) return MSP.Frames.Command is
   begin
      if Text'Length > 2 and then Text (Text'First .. Text'First + 1) in "0x" | "0X" then
         return MSP.Frames.Command'Value ("16#" & Text (Text'First + 2 .. Text'Last) & "#");
      end if;
      return MSP.Frames.Command'Value (Text);
   exception
      when Constraint_Error =>
         raise Usage_Error with "'" & Text & "' is not a command code from 0 to 65535";
   end Command;

   procedure Open (Target : String) is
      Ok : Boolean;
   begin
      MSP.Transport.Open (Target, Ok);
      if not Ok then
         raise Link_Error with "cannot open " & Target;
      end if;
   end Open;

   --  One request; its reply's payload in hexadecimal, or why none came.
   function Answer (Code : MSP.Frames.Command; Payload : MSP.Byte_Array) return String is
      Reply  : MSP.Session.Reply_Buffer;
      Last   : MSP.Frames.Payload_Length;
      Result : MSP.Session.Status;
   begin
      MSP.Session.Request (Code, Payload, Reply, Last, Result);
      case Result is
         when MSP.Session.Answered =>
            return Hex (Reply (1 .. Last));
         when MSP.Session.Refused =>
            return "refused";
         when MSP.Session.No_Reply =>
            return "no reply";
         when MSP.Session.Not_Sent =>
            raise Link_Error with "the request did not go out";
      end case;
   end Answer;

   --  The command line's waits in empty reads of the link, a twentieth of a second each: the quiet after a
   --  prompt that ends a short reply or a long one, and the silence that gives up on a prompt.
   Quiet_After_Prompt : constant := 4;
   Quiet_After_Output : constant := 8;
   Short_Patience     : constant := 40;
   Long_Patience      : constant := 400;

   --  Text sent to the command line, and the lines that came back before the prompt.
   procedure Console
     (Text     : String;
      Quiet    : Positive;
      Patience : Positive;
      Reply    : out MSP.Backups.Lines;
      Prompted : out Boolean)
   is
      type Buffer_Access is access MSP.Console.Text_Buffer;
      Line   : MSP.Byte_Array (1 .. Text'Length);
      Buffer : constant Buffer_Access := new MSP.Console.Text_Buffer;
      Last   : MSP.Console.Text_Length;
      Cut    : Boolean;
      Result : MSP.Console.Status;
   begin
      if Text'Length > MSP.Console.Max_Line then
         raise Usage_Error with "a line of" & Natural'Image (Text'Length) & " characters is too long to send";
      end if;
      for I in Line'Range loop
         Line (I) := Character'Pos (Text (Text'First + I - 1));
      end loop;
      MSP.Console.Exchange (Line, Quiet, Patience, Buffer.all, Last, Cut, Result);
      if Result = MSP.Console.Not_Sent then
         raise Link_Error with "the line did not go out";
      elsif Cut then
         raise Link_Error with "the reply is longer than" & Natural'Image (MSP.Console.Max_Text) & " bytes";
      end if;
      declare
         Received : String (1 .. Last);
      begin
         for I in Received'Range loop
            Received (I) := Character'Val (Buffer (I));
         end loop;
         Reply := MSP.Backups.Reply_Lines (Received);
      end;
      Prompted := Result = MSP.Console.Prompted;
   end Console;

   --  The command line entered: its sign sent, and a line end after it for a board already there, where the
   --  sign starts a comment.
   procedure Enter_Command_Line is
      Reply    : MSP.Backups.Lines;
      Prompted : Boolean;
   begin
      Console ("#", Quiet_After_Prompt, Short_Patience, Reply, Prompted);
      if not Prompted then
         Console ((1 => Line_Feed), Quiet_After_Prompt, Short_Patience, Reply, Prompted);
      end if;
      if not Prompted then
         raise Link_Error with "the board gave no command line prompt";
      end if;
   end Enter_Command_Line;

   --  The command line left without a save, which restarts the board.
   procedure Leave_Command_Line is
      Reply    : MSP.Backups.Lines;
      Prompted : Boolean;
   begin
      Console ("exit" & Line_Feed, Quiet_After_Prompt, Quiet_After_Output, Reply, Prompted);
   end Leave_Command_Line;

   procedure Backup (Target : String; Whole : Boolean) is
      Reply    : MSP.Backups.Lines;
      Prompted : Boolean;
   begin
      Open (Target);
      Enter_Command_Line;
      Console
        ((if Whole then "dump all" else "diff all") & Line_Feed, Quiet_After_Output, Long_Patience, Reply, Prompted);
      Leave_Command_Line;
      MSP.Transport.Close;
      if not Prompted then
         raise Link_Error with "the backup did not end with a prompt";
      end if;
      for Line of Reply loop
         Put_Line (Line);
      end loop;
   end Backup;

   function File_Lines (Path : String) return MSP.Backups.Lines is
      File   : File_Type;
      Result : MSP.Backups.Lines;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Result.Append (Get_Line (File));
      end loop;
      Close (File);
      return Result;
   exception
      when Name_Error | Use_Error =>
         raise Usage_Error with "cannot read " & Path;
   end File_Lines;

   --  A backup's lines sent in order as the file has them, each waited on for its prompt, so a backup that
   --  starts with the reset to defaults replaces the board's configuration and a file of a few lines changes
   --  those alone. Without an error line in any reply the configuration is saved, which restarts the board.
   --  With one, the command line is left without a save.
   procedure Restore (Target : String; Path : String) is
      Backup_Lines : constant MSP.Backups.Lines := File_Lines (Path);
      Reply        : MSP.Backups.Lines;
      Prompted     : Boolean;
      Sent         : Natural := 0;
      Errors       : Natural := 0;
   begin
      Open (Target);
      Enter_Command_Line;
      for Line of Backup_Lines loop
         if MSP.Backups.Is_Command (Line) then
            Console (Line & Line_Feed, Quiet_After_Prompt, Long_Patience, Reply, Prompted);
            Sent := Sent + 1;
            if not Prompted then
               Leave_Command_Line;
               raise Link_Error with "no prompt after: " & Line;
            end if;
            for Answer_Line of Reply loop
               if Ada.Strings.Fixed.Index (Answer_Line, "###ERROR") > 0 then
                  Errors := Errors + 1;
                  Put_Line (Standard_Error, Line);
                  Put_Line (Standard_Error, "  " & Answer_Line);
               end if;
            end loop;
         end if;
      end loop;
      if Errors > 0 then
         Leave_Command_Line;
         raise Link_Error with Decimal (Errors) & " of " & Decimal (Sent) & " lines failed; nothing saved";
      end if;
      Console ("save" & Line_Feed, Quiet_After_Prompt, Quiet_After_Output, Reply, Prompted);
      MSP.Transport.Close;
      Put_Line ("restored " & Decimal (Sent) & " lines and saved");
   end Restore;

   procedure Compare (First, Second : String) is
      Found : constant MSP.Backups.Lines := MSP.Backups.Differences (File_Lines (First), File_Lines (Second));
   begin
      for Line of Found loop
         Put_Line (Line);
      end loop;
      if not Found.Is_Empty then
         Set_Exit_Status (1);
      end if;
   end Compare;

   procedure Usage is
   begin
      Put_Line (Standard_Error, "usage: adaflight_msp request <target> <code> [payload]");
      Put_Line (Standard_Error, "       adaflight_msp dump <target>");
      Put_Line (Standard_Error, "       adaflight_msp backup <target> [all]");
      Put_Line (Standard_Error, "       adaflight_msp restore <target> <file>");
      Put_Line (Standard_Error, "       adaflight_msp diff <file> <file>");
      Put_Line (Standard_Error, "A target is a serial device, as /dev/ttyACM0, or tcp:<host>:<port>.");
      Put_Line (Standard_Error, "request prints the reply's payload in hexadecimal, a minus for an empty one;");
      Put_Line (Standard_Error, "a payload is hexadecimal digits. dump sends every read command and prints a");
      Put_Line (Standard_Error, "line per command: its name, its code and its reply. backup prints the");
      Put_Line (Standard_Error, "command line's 'diff all', or with 'all' its 'dump all', and restarts the");
      Put_Line (Standard_Error, "board. restore sends a backup's lines, saves when none fails, and restarts");
      Put_Line (Standard_Error, "the board. diff compares two backups setting by setting and exits with 1");
      Put_Line (Standard_Error, "when they differ.");
   end Usage;

begin
   if Argument_Count in 3 | 4 and then Argument (1) = "request" then
      Open (Argument (2));
      Put_Line (Answer (Command (Argument (3)), (if Argument_Count = 4 then Bytes (Argument (4)) else Bytes ("-"))));
      MSP.Transport.Close;
   elsif Argument_Count = 2 and then Argument (1) = "dump" then
      Open (Argument (2));
      for R of MSP.Codes.Reads loop
         Put_Line
           (Ada.Strings.Fixed.Trim (R.Name, Ada.Strings.Right) & " " & Decimal (R.Code) & " "
            & Answer (R.Code, Bytes ("-")));
      end loop;
      MSP.Transport.Close;
   elsif Argument_Count = 2 and then Argument (1) = "backup" then
      Backup (Argument (2), Whole => False);
   elsif Argument_Count = 3 and then Argument (1) = "backup" and then Argument (3) = "all" then
      Backup (Argument (2), Whole => True);
   elsif Argument_Count = 3 and then Argument (1) = "restore" then
      Restore (Argument (2), Argument (3));
   elsif Argument_Count = 3 and then Argument (1) = "diff" then
      Compare (Argument (2), Argument (3));
   else
      Usage;
      Set_Exit_Status (2);
   end if;
exception
   when E : Usage_Error =>
      Put_Line (Standard_Error, "adaflight_msp: " & Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (2);
   when E : Link_Error =>
      MSP.Transport.Close;
      Put_Line (Standard_Error, "adaflight_msp: " & Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (1);
end Adaflight_MSP;
