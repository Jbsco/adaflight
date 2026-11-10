with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with MSP.Codes;
with MSP.Frames;
with MSP.Session;
with MSP.Transport;

--  Sends MSP requests to a flight controller on a serial port or a TCP port and prints its replies.
procedure Adaflight_MSP with SPARK_Mode => Off is

   use Ada.Command_Line;
   use Ada.Text_IO;
   use type MSP.Byte;

   Usage_Error : exception;
   Link_Error  : exception;

   Hex_Digits : constant String := "0123456789abcdef";

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

   procedure Usage is
   begin
      Put_Line (Standard_Error, "usage: adaflight_msp request <target> <code> [payload]");
      Put_Line (Standard_Error, "       adaflight_msp dump <target>");
      Put_Line (Standard_Error, "A target is a serial device, as /dev/ttyACM0, or tcp:<host>:<port>.");
      Put_Line (Standard_Error, "A payload is hexadecimal digits. request prints the reply's payload in");
      Put_Line (Standard_Error, "hexadecimal, a minus for an empty one. dump sends every read command and");
      Put_Line (Standard_Error, "prints a line per command: its name, its code and its reply.");
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
