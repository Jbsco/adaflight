with Adaflight.Clock;

package body Adaflight.Jeti_Ex_Bus with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_8;

   -----------------
   -- Frame_CRC16 --
   -----------------

   function Frame_CRC16 (F : Frame_Bytes; Length : Natural) return Unsigned_16 is
      CRC : Unsigned_16 := 0;
   begin
      for M in 0 .. Length - 1 loop
         declare
            Mixed : constant Interfaces.Unsigned_8 :=
              Interfaces.Unsigned_8 (F (M)) xor Interfaces.Unsigned_8 (CRC and 16#FF#);
            D     : constant Interfaces.Unsigned_8 := Mixed xor Interfaces.Shift_Left (Mixed, 4);
         begin
            CRC := (Interfaces.Shift_Left (Unsigned_16 (D), 8) or Interfaces.Shift_Right (CRC and 16#FF00#, 8))
              xor Unsigned_16 (Interfaces.Shift_Right (D, 4))
              xor Interfaces.Shift_Left (Unsigned_16 (D), 3);
         end;
      end loop;
      return CRC;
   end Frame_CRC16;

   --  The channels from a received channel frame: as many words as the data
   --  length holds, up to the channel count, each word's eighth, when the
   --  header names channel data with or without a request.
   procedure Decode_Channel_Frame (S : in out State) is
      Received : constant Natural range 0 .. Channel_Count :=
        Natural'Min (S.Channel_Frame (Header_Sub_Len) / 2, Channel_Count);
      Header   : constant Natural := S.Channel_Frame (Header_Sync) * 256 + S.Channel_Frame (Header_Req);
   begin
      if Header in Channel_Data_Request | Channel_Data_Id then
         for I in 0 .. Received - 1 loop
            declare
               Address : constant Natural range Header_Len .. Header_Len + 30 := Header_Len + I * 2;
               Value   : constant Natural range 0 .. 65_535 :=
                 S.Channel_Frame (Address + 1) * 256 + S.Channel_Frame (Address);
            begin
               S.Data (I) := Value / 8;
            end;
         end loop;
      end if;
   end Decode_Channel_Frame;

   procedure Reset_Frame (S : in out State) is
   begin
      S.Position := 0;
      S.Length := Max_Channel_Frame;
   end Reset_Frame;

   procedure Drop_Frame (S : in out State) is
   begin
      Reset_Frame (S);
      S.Frame_State := Zero;
      S.Request_State := Zero;
   end Drop_Frame;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
   begin
      if Clock.Elapsed (Now_Us, S.Time_Last_Us) > Min_Frame_Gap_Us then
         Drop_Frame (S);
      end if;
      S.Time_Last_Us := Now_Us;
      if S.Position = 0 then
         case C is
            when Start_Channel_Frame =>
               S.Frame_State := In_Progress;
               S.Target := Channel_Buffer;
            when Start_Request_Frame =>
               S.Request_State := In_Progress;
               S.Target := Request_Buffer;
            when others =>
               return;
         end case;
      end if;
      if S.Position = Header_Req then
         S.Can_Tx := C = 1;
      end if;
      if S.Position = Max_Size (S.Target) then
         Drop_Frame (S);
         return;
      end if;
      case S.Target is
         when Channel_Buffer =>
            S.Channel_Frame (S.Position) := C mod 256;
         when Request_Buffer =>
            S.Request_Frame (S.Position) := C mod 256;
      end case;
      S.Position := S.Position + 1;
      if S.Position = Header_Len then
         declare
            Msg_Len : constant Byte :=
              (case S.Target is
                  when Channel_Buffer => S.Channel_Frame (Header_Msg_Len),
                  when Request_Buffer => S.Request_Frame (Header_Msg_Len));
         begin
            if S.Frame_State = In_Progress and then Msg_Len in Header_Len + CRC_Len .. Max_Channel_Frame then
               S.Length := Msg_Len;
               return;
            end if;
            if S.Request_State = In_Progress and then Msg_Len in Header_Len + CRC_Len .. Max_Request_Frame then
               S.Length := Msg_Len;
               return;
            end if;
            Drop_Frame (S);
            return;
         end;
      end if;
      if S.Position >= S.Length then
         if S.Frame_State = In_Progress then
            S.Frame_State := Received;
            S.Request_State := Zero;
            S.Channel_Stamp_Us := Now_Us;
            S.Received_Length := S.Length;
         end if;
         if S.Request_State = In_Progress then
            S.Frame_State := Zero;
            S.Request_State := Received;
            S.Request_Stamp_Us := Now_Us;
         end if;
         Reset_Frame (S);
      end if;
   end Receive_Byte;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if S.Frame_State = Received then
         if Frame_CRC16 (S.Channel_Frame, S.Received_Length) = 0 then
            Decode_Channel_Frame (S);
            Status.Complete := True;
            S.Last_Frame_Time_Us := S.Channel_Stamp_Us;
         end if;
         S.Frame_State := Zero;
      end if;
   end Frame_Status;

end Adaflight.Jeti_Ex_Bus;
