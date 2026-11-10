package body MSP.Session with SPARK_Mode is

   use type Frames.Step;

   procedure Request
     (Code    : Frames.Command;
      Payload : Byte_Array;
      Reply   : out Reply_Buffer;
      Last    : out Frames.Payload_Length;
      Result  : out Status)
   is
      Frame      : Byte_Array (0 .. Frames.Max_Frame - 1);
      Frame_Last : Natural;
      Sent       : Boolean;
      D          : Frames.Decoder;
      Chunk      : Byte_Array (0 .. 255);
      Got        : Natural;
      Outcome    : Frames.Step;
      Waits      : Natural := 0;
      Reads      : Natural := 0;
   begin
      Reply := (others => 0);
      Last := 0;
      Result := No_Reply;
      Frames.Encode (Code, Payload, Frame, Frame_Last);
      Transport.Send (Frame (0 .. Frame_Last), Sent);
      if not Sent then
         Result := Not_Sent;
         return;
      end if;
      Frames.Reset (D);
      while Waits < Max_Waits and then Reads < Max_Reads loop
         pragma Loop_Variant (Increases => Reads);
         pragma Loop_Invariant (Last = 0 and then Result = No_Reply);
         Reads := Reads + 1;
         Transport.Receive (Chunk, Got);
         if Got = 0 then
            Waits := Waits + 1;
         end if;
         for I in 0 .. Got - 1 loop
            pragma Loop_Invariant (Last = 0 and then Result = No_Reply);
            Frames.Feed (D, Chunk (I), Outcome);
            if Outcome = Frames.Complete and then Frames.Code (D) = Code then
               for J in 1 .. Frames.Length (D) loop
                  Reply (J) := Frames.Payload (D, J);
               end loop;
               Last := Frames.Length (D);
               Result := (if Frames.Refused (D) then Refused else Answered);
               return;
            end if;
         end loop;
      end loop;
   end Request;

end MSP.Session;
