with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Interfaces;

package body Model_Board is

   use type MSP.Byte;

   Queue_Size : constant := 2 ** 17;

   Current : Settings;
   Queue   : array (0 .. Queue_Size - 1) of MSP.Byte := (others => 0);
   Head    : Natural := 0;
   Tail    : Natural := 0;

   Good     : Natural := 0;
   Bad      : Natural := 0;
   Code_Was : Natural := 0;
   Size_Was : Natural := 0;
   V2_Was   : Boolean := False;
   Empties  : Natural := 0;
   Stalled  : Natural := 0;
   Read_Count : Natural := 0;

   Max_Kept   : constant := 64;
   CR_LF      : constant String := (Ada.Characters.Latin_1.CR, Ada.Characters.Latin_1.LF);
   In_CLI     : Boolean := False;
   Kept       : array (1 .. Max_Kept) of Ada.Strings.Unbounded.Unbounded_String;
   Count      : Natural := 0;
   Saved      : Natural := 0;
   Save_Count : Natural := 0;
   Exit_Count : Natural := 0;

   function CRC8 (CRC : MSP.Byte; Data : MSP.Byte) return MSP.Byte is
      C : MSP.Byte := CRC xor Data;
   begin
      for I in 1 .. 8 loop
         C := (if (C and 16#80#) /= 0 then Interfaces.Shift_Left (C, 1) xor 16#D5# else Interfaces.Shift_Left (C, 1));
      end loop;
      return C;
   end CRC8;

   procedure Push (B : MSP.Byte) is
   begin
      Queue (Tail) := B;
      Tail := Tail + 1;
   end Push;

   procedure Push (Text : String) is
   begin
      for C of Text loop
         Push (MSP.Byte (Character'Pos (C)));
      end loop;
   end Push;

   procedure Configure (S : Settings) is
   begin
      Current := S;
      Head := 0;
      Tail := 0;
      Good := 0;
      Bad := 0;
      Code_Was := 0;
      Size_Was := 0;
      V2_Was := False;
      Empties := 0;
      Stalled := 0;
      Read_Count := 0;
      In_CLI := False;
      Count := 0;
      Saved := 0;
      Save_Count := 0;
      Exit_Count := 0;
   end Configure;

   function Reply_Byte (Code : Natural; Request : MSP.Byte_Array; I : Positive) return MSP.Byte is
      From_Request : constant MSP.Byte :=
        (if Request'Length = 0 then 0 else Request (Request'First + (I - 1) mod Request'Length));
   begin
      return MSP.Byte ((Code + 7 * I) mod 256) xor From_Request;
   end Reply_Byte;

   --  A reply frame in the request's protocol version, or the first version's long form.
   procedure Push_Reply
     (Code : Natural; Request : MSP.Byte_Array; V2 : Boolean; Refused : Boolean; Length : Natural; Spoil : Boolean)
   is
      Check : MSP.Byte;
      procedure Add (B : MSP.Byte) is
      begin
         Push (B);
         Check := (if V2 then CRC8 (Check, B) else Check xor B);
      end Add;
   begin
      Push ((if V2 then "$X" else "$M") & (if Refused then "!" else ">"));
      Check := 0;
      if V2 then
         Add (0);
         Add (MSP.Byte (Code mod 256));
         Add (MSP.Byte (Code / 256));
         Add (MSP.Byte (Length mod 256));
         Add (MSP.Byte (Length / 256));
      elsif Current.Jumbo or else Length >= 255 then
         Add (255);
         Add (MSP.Byte (Code mod 256));
         Add (MSP.Byte (Length mod 256));
         Add (MSP.Byte (Length / 256));
      else
         Add (MSP.Byte (Length));
         Add (MSP.Byte (Code mod 256));
      end if;
      for I in 1 .. Length loop
         Add (Reply_Byte (Code, Request, I));
      end loop;
      Push ((if Spoil then Check xor 16#5A# else Check));
   end Push_Reply;

   procedure Answer (Code : Natural; Request : MSP.Byte_Array; V2 : Boolean) is
   begin
      Good := Good + 1;
      Code_Was := Code;
      Size_Was := Request'Length;
      V2_Was := V2;
      if Current.Silent then
         return;
      end if;
      if Current.Noise_First then
         Push ("noise $ $M $X< $M<");
         Push (0);
         Push (255);
      end if;
      if Current.Long_First then
         --  A frame that announces a payload of 9000 bytes, past what the client keeps.
         Push ("$X>");
         Push (0);
         Push (MSP.Byte (Code mod 256));
         Push (MSP.Byte (Code / 256));
         Push (MSP.Byte (9000 mod 256));
         Push (MSP.Byte (9000 / 256));
         for I in 1 .. 9001 loop
            Push (MSP.Byte (I mod 251));
         end loop;
      end if;
      if Current.Corrupt_First then
         Push_Reply (Code, Request, V2, False, Current.Reply_Length, Spoil => True);
      end if;
      if Current.Other_First then
         Push_Reply ((Code + 1) mod 255, Request, False, False, 3, Spoil => False);
      end if;
      Push_Reply
        (Code, Request, V2, Current.Refuse, (if Current.Refuse then 0 else Current.Reply_Length), Spoil => False);
   end Answer;

   function Is_Present return Boolean
   is (Current.Present);

   function Starts_With (Line, Prefix : String) return Boolean
   is (Line'Length >= Prefix'Length and then Line (Line'First .. Line'First + Prefix'Length - 1) = Prefix);

   function Four_Digits (N : Natural) return String is
      Image : constant String := Natural'Image (10_000 + N mod 10_000);
   begin
      return Image (Image'Last - 3 .. Image'Last);
   end Four_Digits;

   --  Text for the command line: its sign enters it, and inside it a line is echoed and answered, with the
   --  prompt after every answer but a save's and an exit's.
   procedure Command_Line (Text : String) is
      Last : Natural := Text'Last;
   begin
      while Last >= Text'First and then Text (Last) in Ada.Characters.Latin_1.LF | Ada.Characters.Latin_1.CR loop
         Last := Last - 1;
      end loop;
      declare
         Line   : constant String := Text (Text'First .. Last);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, " = ");
         Leaves : Boolean := False;
      begin
         if not In_CLI then
            if Line = "#" then
               In_CLI := True;
               Push (CR_LF & "Entering CLI Mode, type 'exit' to return, or 'help'" & CR_LF);
               if not Current.No_Prompt then
                  Push (CR_LF & "# ");
               end if;
            end if;
            return;
         end if;
         Push (Line & CR_LF);
         if Line = "" or else Line (Line'First) = '#' or else Line in "batch start" | "batch end" then
            null;
         elsif Line = "diff all" then
            Push (CR_LF & "# version" & CR_LF & "# model" & CR_LF & CR_LF & "# start the command batch" & CR_LF);
            Push ("batch start" & CR_LF & CR_LF & "# reset configuration to default settings" & CR_LF);
            Push ("defaults nosave" & CR_LF & CR_LF);
            for I in 1 .. Count loop
               Push (Ada.Strings.Unbounded.To_String (Kept (I)) & CR_LF);
            end loop;
            Push (CR_LF & "# save configuration" & CR_LF & "save");
         elsif Line = "dump all" then
            for I in 1 .. Current.Dump_Lines loop
               Push ("set name_" & Four_Digits (I) & " = " & Four_Digits (I) & CR_LF);
            end loop;
         elsif Line = "defaults nosave" then
            Count := 0;
         elsif Line = "save" then
            Saved := Count;
            Save_Count := Save_Count + 1;
            In_CLI := False;
            Leaves := True;
            Push ("Saving" & CR_LF & "Rebooting");
         elsif Line = "exit" then
            Count := Saved;
            Exit_Count := Exit_Count + 1;
            In_CLI := False;
            Leaves := True;
            Push ("Rebooting");
         elsif Starts_With (Line, "set bad") then
            Push ("###ERROR IN set: INVALID NAME: " & Line (Line'First + 4 .. Line'Last) & "###");
         elsif Starts_With (Line, "set ") and then Equals > 0 and then Count < Max_Kept then
            Count := Count + 1;
            Kept (Count) := Ada.Strings.Unbounded.To_Unbounded_String (Line);
            Push (Line (Line'First + 4 .. Equals - 1) & " set to " & Line (Equals + 3 .. Line'Last));
         else
            Push ("###ERROR IN input: UNKNOWN COMMAND, TRY 'HELP'###");
         end if;
         if not Leaves and then not Current.No_Prompt then
            Push (CR_LF & "# ");
         end if;
      end;
   end Command_Line;

   procedure Take (Data : MSP.Byte_Array; Ok : out Boolean) is
      F : constant Natural := Data'First;
      N : constant Natural := Data'Length;
      Check : MSP.Byte := 0;
   begin
      Ok := Current.Accept_Sends;
      if not Ok then
         return;
      end if;
      if N >= 1 and then Data (F) /= Character'Pos ('$') then
         declare
            Text : String (1 .. N);
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (Data (F + I - 1));
            end loop;
            Command_Line (Text);
         end;
         return;
      end if;
      if N >= 6 and then Data (F) = Character'Pos ('$') and then Data (F + 1) = Character'Pos ('M')
        and then Data (F + 2) = Character'Pos ('<') and then N = 6 + Natural (Data (F + 3))
      then
         for I in F + 3 .. Data'Last - 1 loop
            Check := Check xor Data (I);
         end loop;
         if Check = Data (Data'Last) then
            Answer (Natural (Data (F + 4)), Data (F + 5 .. Data'Last - 1), V2 => False);
            return;
         end if;
      elsif N >= 9 and then Data (F) = Character'Pos ('$') and then Data (F + 1) = Character'Pos ('X')
        and then Data (F + 2) = Character'Pos ('<')
        and then N = 9 + Natural (Data (F + 6)) + 256 * Natural (Data (F + 7))
      then
         for I in F + 3 .. Data'Last - 1 loop
            Check := CRC8 (Check, Data (I));
         end loop;
         if Check = Data (Data'Last) then
            Answer (Natural (Data (F + 4)) + 256 * Natural (Data (F + 5)), Data (F + 8 .. Data'Last - 1), V2 => True);
            return;
         end if;
      end if;
      Bad := Bad + 1;
   end Take;

   procedure Give (Data : out MSP.Byte_Array; Got : out Natural) is
      Room : constant Natural := Natural'Min (Data'Length, Current.Chunk);
   begin
      Data := (others => 0);
      Read_Count := Read_Count + 1;
      if Current.Endless then
         Data := (others => Character'Pos ('x'));
         Got := Data'Length;
         return;
      end if;
      if Stalled > 0 then
         Stalled := Stalled - 1;
         Empties := Empties + 1;
         Got := 0;
         return;
      end if;
      Got := Natural'Min (Room, Tail - Head);
      if Got = 0 then
         Empties := Empties + 1;
      else
         Stalled := Current.Stall;
      end if;
      for I in 0 .. Got - 1 loop
         Data (Data'First + I) := Queue (Head + I);
      end loop;
      Head := Head + Got;
   end Give;

   function Good_Requests return Natural
   is (Good);
   function Bad_Requests return Natural
   is (Bad);
   function Last_Code return Natural
   is (Code_Was);
   function Last_Length return Natural
   is (Size_Was);
   function Last_Was_V2 return Boolean
   is (V2_Was);
   function Empty_Reads return Natural
   is (Empties);
   function Reads return Natural
   is (Read_Count);
   function Saves return Natural
   is (Save_Count);
   function Exits return Natural
   is (Exit_Count);
   function Kept_Lines return Natural
   is (Count);
   function Kept_Line (I : Positive) return String
   is (Ada.Strings.Unbounded.To_String (Kept (I)));

end Model_Board;
