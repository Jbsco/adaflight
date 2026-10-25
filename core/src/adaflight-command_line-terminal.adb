package body Adaflight.Command_Line.Terminal with SPARK_Mode is

   Line_End : constant String := ASCII.CR & ASCII.LF;

   procedure Emit (Into : in out Output; Text : String) is
   begin
      Put (Into.Target, Text);
   end Emit;

   procedure Prompt (Into : in out Output) is
   begin
      Emit (Into, Line_End & "# ");
   end Prompt;

   procedure Clear (T : in out Session) is
   begin
      T.Length := 0;
      T.Text := (others => ' ');
   end Clear;

   --  The session closed, noted in Changes.
   procedure Close (T : in out Session; Changes : in out Effects) is
   begin
      Clear (T);
      T.Open := False;
      T.Interactive := False;
      Changes.Leave := True;
   end Close;

   procedure Enter (T : in out Session; Into : in out Output; Interactive : Boolean; Now_Ms : Interfaces.Unsigned_32) is
   begin
      T.Open := True;
      T.Interactive := Interactive;
      T.Entry_Ms := Now_Ms;
      Clear (T);
      if Interactive then
         Emit (Into, Line_End & "Entering CLI Mode, type 'exit' to reboot, or 'help'" & Line_End);
         T.Arming_Held := True;
         Prompt (Into);
         Into.Batch_Active := False;
         Into.Batch_Error := False;
      else
         Emit (Into, (1 => ASCII.STX));
      end if;
   end Enter;

   procedure Leave (T : in out Session; Changes : in out Effects) is
   begin
      Close (T, Changes);
   end Leave;

   --  A typed character: a line end runs the line and prompts, a printable
   --  character past the leading spaces joins the line and echoes.
   procedure Character_In
     (T       : in out Session;
      Into    : in out Output;
      Ch      : Character;
      C       : in out Configuration;
      Ports   : Port_List;
      Env     : Environment;
      Board   : in out Board_State;
      Sched   : in out Scheduler.State;
      Changes : in out Effects)
     with Pre => Ports'Length <= Serial_Feature_Map.Max_Ports
   is
   begin
      if T.Length > 0 and then (Ch = ASCII.LF or else Ch = ASCII.CR) then
         if T.Interactive then
            Emit (Into, Line_End);
         end if;
         if Valid (Current (C)) then
            declare
               Line_Env     : Environment := Env;
               Line_Changes : Effects;
            begin
               Line_Env.Interactive := T.Interactive;
               Process_Line (Into, C, T.Text (1 .. T.Length), Ports, Line_Env, Board, Sched, Line_Changes);
               Changes := Line_Changes;
            end;
         end if;
         if Changes.Leave then
            Clear (T);
            T.Open := False;
            T.Interactive := False;
            return;
         end if;
         Clear (T);
         if T.Interactive then
            Prompt (Into);
         end if;
      elsif T.Length < Buffer_Size - 1 and then Ch in ' ' .. '~' then
         if T.Length = 0 and then Ch = ' ' then
            return;
         end if;
         T.Length := T.Length + 1;
         T.Text (T.Length) := Ch;
         if T.Interactive then
            Emit (Into, (1 => Ch));
         end if;
      end if;
   end Character_In;

   --  Whether the line typed so far matches the start of a command name
   --  without regard to case.
   function Matches (T : Session; Name : String) return Boolean
     with Global => null
   is
   begin
      if T.Length > Name'Length then
         return False;
      end if;
      for I in 1 .. T.Length loop
         if CLI_Text.Lower (T.Text (I)) /= CLI_Text.Lower (Name (Name'First + (I - 1))) then
            return False;
         end if;
      end loop;
      return True;
   end Matches;

   --  The character of a name at a position, NUL past its end.
   function At_Position (Name : String; Position : Positive) return Character is
     (if Position <= Name'Length then Name (Name'First + (Position - 1)) else ASCII.NUL)
     with Global => null;

   --  Tab completion: the line extended as far as the first and the last
   --  matching names agree, a space after a whole name, the names between the
   --  first and the last match listed when they differ or the line is empty,
   --  and the line redrawn from where it was or from the prompt.
   procedure Complete (T : in out Session; Into : in out Output) is
      First  : Natural := 0;
      Last   : Natural := 0;
      Redraw : Natural := T.Length;
   begin
      for I in 1 .. Command_Count loop
         pragma Loop_Invariant (Last < I and then First <= Last and then Last <= Command_Count);
         if T.Length = 0 or else Matches (T, Command_Name (I)) then
            if First = 0 then
               First := I;
            end if;
            Last := I;
         end if;
      end loop;
      if First > 0 then
         loop
            pragma Loop_Invariant (T.Length <= Buffer_Size - 1);
            declare
               C1 : constant Character := At_Position (Command_Name (First), T.Length + 1);
               C2 : constant Character := At_Position (Command_Name (Last), T.Length + 1);
            begin
               exit when C1 /= C2;
               if C1 = ASCII.NUL then
                  if T.Length < Buffer_Size - 2 then
                     T.Length := T.Length + 1;
                     T.Text (T.Length) := ' ';
                  end if;
                  exit;
               end if;
               exit when T.Length >= Buffer_Size - 1;
               T.Length := T.Length + 1;
               T.Text (T.Length) := C1;
            end;
         end loop;
      end if;
      if T.Length = 0 or else First /= Last then
         Emit (Into, Line_End & ASCII.ESC & "[K");
         if First > 0 then
            for I in First .. Last loop
               Emit (Into, Command_Name (I));
               Emit (Into, (1 => ASCII.HT));
            end loop;
         end if;
         Prompt (Into);
         Redraw := 0;
      end if;
      if Redraw < T.Length then
         Emit (Into, T.Text (Redraw + 1 .. T.Length));
      end if;
   end Complete;

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
   is
   begin
      if not T.Open then
         return;
      end if;
      for I in Input'Range loop
         declare
            Ch : constant Character := Character'Val (Input (I));
         begin
            if T.Interactive then
               if Ch = ASCII.HT or else Ch = '?' then
                  Complete (T, Into);
               elsif T.Length = 0 and then Ch = ASCII.EOT then
                  Emit (Into, Line_End & "Rebooting");
                  Changes.Reboot := True;
                  Close (T, Changes);
               elsif Ch = ASCII.FF then
                  Emit (Into, ASCII.ESC & "[2J" & ASCII.ESC & "[1;1H");
                  Prompt (Into);
               elsif Ch = ASCII.DEL then
                  if T.Length > 0 then
                     T.Text (T.Length) := ' ';
                     T.Length := T.Length - 1;
                     Emit (Into, ASCII.BS & " " & ASCII.BS);
                  end if;
               else
                  Character_In (T, Into, Ch, C, Ports, Env, Board, Sched, Changes);
               end if;
            elsif Ch = ASCII.ETX
              or else (Now_Ms - T.Entry_Ms < 2 ** 31 and then Now_Ms - T.Entry_Ms > Entry_Timeout_Ms)
            then
               Emit (Into, (1 => ASCII.ETX));
               Close (T, Changes);
               return;
            else
               Character_In (T, Into, Ch, C, Ports, Env, Board, Sched, Changes);
            end if;
         end;
      end loop;
   end Process;

end Adaflight.Command_Line.Terminal;
