package body MSP.Console with SPARK_Mode is

   subtype Tail_Bytes is Byte_Array (1 .. 4);

   function Is_Prompt (Tail : Tail_Bytes) return Boolean
   is (Tail (1) = 13
       and then Tail (2) = 10
       and then Tail (3) = Character'Pos ('#')
       and then Tail (4) = Character'Pos (' '));

   --  The tail is the last four bytes of the text, zero before its start.
   function Follows (Tail : Tail_Bytes; Text : Text_Buffer; Last : Text_Length) return Boolean
   is (for all K in 1 .. 4 => Tail (K) = (if Last + K >= 5 then Text (Last + K - 4) else 0))
   with Ghost;

   procedure Exchange
     (Line     : Byte_Array;
      Quiet    : Positive;
      Patience : Positive;
      Text     : out Text_Buffer;
      Last     : out Text_Length;
      Cut      : out Boolean;
      Result   : out Status)
   is
      Sent  : Boolean;
      Chunk : Byte_Array (0 .. 255);
      Got   : Natural;
      Idle  : Natural := 0;
      Reads : Natural := 0;
      --  The last four bytes that arrived, kept in the text or not.
      Tail  : Tail_Bytes := (others => 0);
   begin
      Text := (others => 0);
      Last := 0;
      Cut := False;
      Result := No_Prompt;
      Transport.Send (Line, Sent);
      if not Sent then
         Result := Not_Sent;
         return;
      end if;
      while Reads < Max_Reads loop
         pragma Loop_Variant (Increases => Reads);
         pragma Loop_Invariant (Result = No_Prompt);
         pragma Loop_Invariant (if not Cut then Follows (Tail, Text, Last));
         Reads := Reads + 1;
         Transport.Receive (Chunk, Got);
         if Got = 0 then
            if Idle < Natural'Last then
               Idle := Idle + 1;
            end if;
            if Is_Prompt (Tail) and then Idle >= Quiet then
               Result := Prompted;
               return;
            elsif Idle >= Patience then
               return;
            end if;
         else
            Idle := 0;
            for I in 0 .. Got - 1 loop
               pragma Loop_Invariant (Result = No_Prompt);
               pragma Loop_Invariant (if not Cut then Follows (Tail, Text, Last));
               Tail := (Tail (2), Tail (3), Tail (4), Chunk (I));
               if Last < Max_Text then
                  Last := Last + 1;
                  Text (Last) := Chunk (I);
               else
                  Cut := True;
               end if;
            end loop;
         end if;
      end loop;
   end Exchange;

end MSP.Console;
