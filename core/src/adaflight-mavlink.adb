package body Adaflight.MAVLink with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Receiver.Link_Quality_Source;

   --  One byte folded into the X.25 checksum.
   function Accumulate (CRC : CRC_Word; Data : Byte) return CRC_Word is
      Tmp0 : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8 (Data) xor Interfaces.Unsigned_8 (CRC and 16#FF#);
      Tmp  : constant Interfaces.Unsigned_8 := Tmp0 xor Interfaces.Shift_Left (Tmp0, 4);
   begin
      return Interfaces.Shift_Right (CRC, 8) xor Interfaces.Shift_Left (CRC_Word (Tmp), 8)
        xor Interfaces.Shift_Left (CRC_Word (Tmp), 3) xor CRC_Word (Interfaces.Shift_Right (Tmp, 4));
   end Accumulate;

   function In_V1 (St : Parser) return Boolean is (St.Flags mod 2 = 1);

   --  The frame parser on one byte: the library's state machine, with the
   --  complete frame copied out and its checksum replaced by the wire's
   --  when the two disagree.
   procedure Frame_Byte (S : in out State; C : Byte) is
      Found : Boolean;
      E     : MAVLink_Entries.Message_Entry;
   begin
      S.Status.Msg_Received := Incomplete;
      case S.Status.State is
         when Uninit | Idle =>
            if C = Start_V2 then
               S.Status.State := Got_Start;
               S.Rx.Len := 0;
               S.Rx.Magic := C;
               S.Status.Flags := S.Status.Flags - S.Status.Flags mod 2;
               S.Rx.Checksum := CRC_Init;
            elsif C = Start_V1 then
               S.Status.State := Got_Start;
               S.Rx.Len := 0;
               S.Rx.Magic := C;
               S.Status.Flags := S.Status.Flags - S.Status.Flags mod 2 + Flag_In_V1;
               S.Rx.Checksum := CRC_Init;
            end if;
         when Got_Start =>
            S.Rx.Len := C;
            S.Status.Packet_Idx := 0;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            if In_V1 (S.Status) then
               S.Rx.Incompat_Flags := 0;
               S.Rx.Compat_Flags := 0;
               S.Status.State := Got_Compat_Flags;
            else
               S.Status.State := Got_Length;
            end if;
         when Got_Length =>
            S.Rx.Incompat_Flags := C;
            if C / 2 /= 0 then
               S.Status.State := Idle;
            else
               S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
               S.Status.State := Got_Incompat_Flags;
            end if;
         when Got_Incompat_Flags =>
            S.Rx.Compat_Flags := C;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := Got_Compat_Flags;
         when Got_Compat_Flags =>
            S.Rx.Seq := C;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := Got_Seq;
         when Got_Seq =>
            S.Rx.Sysid := C;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := Got_Sysid;
         when Got_Sysid =>
            S.Rx.Compid := C;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := Got_Compid;
         when Got_Compid =>
            S.Rx.Id := C;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            if In_V1 (S.Status) then
               S.Status.State := (if S.Rx.Len > 0 then Got_Msgid3 else Got_Payload);
            else
               S.Status.State := Got_Msgid1;
            end if;
         when Got_Msgid1 =>
            S.Rx.Id := S.Rx.Id mod 2 ** 8 + C * 2 ** 8;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := Got_Msgid2;
         when Got_Msgid2 =>
            S.Rx.Id := S.Rx.Id mod 2 ** 16 + C * 2 ** 16;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            S.Status.State := (if S.Rx.Len > 0 then Got_Msgid3 else Got_Payload);
         when Got_Msgid3 =>
            --  The index stays below the length, itself at most the payload
            --  size; the bound is stated for the array.
            if S.Status.Packet_Idx < Max_Payload then
               S.Rx.Payload (S.Status.Packet_Idx) := C;
               S.Status.Packet_Idx := S.Status.Packet_Idx + 1;
            end if;
            S.Rx.Checksum := Accumulate (S.Rx.Checksum, C);
            if S.Status.Packet_Idx = S.Rx.Len then
               S.Status.State := Got_Payload;
            end if;
         when Got_Payload =>
            MAVLink_Entries.Lookup (S.Rx.Id, Found, E);
            if not Found then
               S.Status.State := Got_Bad_CRC1;
               S.Rx.CK0 := C;
            else
               S.Rx.Checksum := Accumulate (S.Rx.Checksum, E.CRC_Extra);
               S.Status.State := (if C /= Natural (S.Rx.Checksum and 16#FF#) then Got_Bad_CRC1 else Got_CRC1);
               S.Rx.CK0 := C;
               if S.Status.Packet_Idx < E.Max_Len then
                  for I in S.Status.Packet_Idx .. E.Max_Len - 1 loop
                     S.Rx.Payload (I) := 0;
                  end loop;
               end if;
            end if;
         when Got_CRC1 | Got_Bad_CRC1 =>
            S.Status.Msg_Received :=
              (if S.Status.State = Got_Bad_CRC1 or else C /= Natural (Interfaces.Shift_Right (S.Rx.Checksum, 8))
               then Bad_CRC else OK);
            S.Rx.CK1 := C;
            if S.Rx.Incompat_Flags mod 2 = 1 then
               if S.Status.Msg_Received = Bad_CRC then
                  S.Status.State := Signature_Wait_Bad_CRC;
               else
                  S.Status.State := Signature_Wait;
                  S.Status.Msg_Received := Incomplete;
               end if;
               S.Status.Signature_Left := Signature_Length;
            else
               S.Status.State := Idle;
               S.Received := S.Rx;
            end if;
         when Signature_Wait | Signature_Wait_Bad_CRC =>
            if S.Status.Signature_Left > 0 then
               S.Status.Signature_Left := S.Status.Signature_Left - 1;
            end if;
            if S.Status.Signature_Left = 0 then
               S.Status.Msg_Received := (if S.Status.State = Signature_Wait_Bad_CRC then Bad_CRC else OK);
               S.Status.State := Idle;
               S.Received := S.Rx;
            end if;
      end case;
      if S.Status.Msg_Received = OK then
         S.Status.Current_Rx_Seq := S.Rx.Seq;
         if S.Status.Success_Count = 0 then
            S.Status.Drop_Count := 0;
         end if;
         S.Status.Success_Count := (S.Status.Success_Count + 1) mod 65_536;
      end if;
      S.Received.Len := S.Rx.Len;
      if S.Status.Msg_Received = Bad_CRC then
         S.Received.Checksum := CRC_Word (S.Rx.CK0) + CRC_Word (S.Rx.CK1) * 256;
      end if;
   end Frame_Byte;

   --  A bad checksum or signature restarts the parser, on the start byte
   --  when the byte is one.
   procedure Parse_Byte (S : in out State; C : Byte; Result : out Framing) is
   begin
      Frame_Byte (S, C);
      Result := S.Status.Msg_Received;
      if Result in Bad_CRC | Bad_Signature then
         S.Status.Msg_Received := Incomplete;
         S.Status.State := Idle;
         if C = Start_V2 then
            S.Status.State := Got_Start;
            S.Rx.Len := 0;
            S.Rx.Checksum := CRC_Init;
         end if;
         Result := Incomplete;
      end if;
   end Parse_Byte;

   --  The override's eighteen channels as consecutive words from its first
   --  channel, so the ninth word is the two target ids and the following
   --  words are each a channel early (finding F41); zero and all ones leave
   --  a channel as it was.
   procedure Take_Override (S : in out State) is
   begin
      for I in Channel loop
         declare
            W : constant Channel_Value := S.Received.Payload (2 * I) + 256 * S.Received.Payload (2 * I + 1);
         begin
            if W /= 0 and then W /= 65_535 then
               S.Data (I) := W;
            end if;
         end;
      end loop;
      S.Frame_Received := True;
   end Take_Override;

   --  The radio status: the free transmitter buffer, the remote RSSI as a
   --  negative dBm scaled onto the receiver's range, wrapping below the
   --  range minimum (finding F42), the dBm itself, the noise as the SNR, and
   --  the local RSSI as the link quality.
   procedure Take_Radio_Status (S : in out State; Rx : in out Receiver.State) is
      Dbm    : constant Integer range -255 .. 0 := -S.Received.Payload (5);
      Scaled : constant Integer range -1_000 .. 1_023 := (Receiver.RSSI_Max * (Dbm - RSSI_Dbm_Min)) / (-RSSI_Dbm_Min);
   begin
      S.Tx_Buffer_Valid := True;
      S.Tx_Buffer_Free := S.Received.Payload (6);
      Receiver.Set_RSSI (Rx, Scaled mod 65_536, Receiver.Protocol_Mavlink);
      Receiver.Set_RSSI_Dbm (Rx, Dbm, Receiver.Protocol_Mavlink);
      Receiver.Set_RSNR (Rx, S.Received.Payload (7));
      if Rx.Quality_From = Receiver.Mavlink then
         Receiver.Set_Link_Quality_Direct (Rx, (100 * S.Received.Payload (4)) / 255);
      end if;
   end Take_Radio_Status;

   procedure Enqueue (S : in out State) is
      Next : constant Queue_Index := (S.Head + 1) mod Queue_Size;
   begin
      if Next /= S.Tail then
         S.Queue (S.Head) := S.Received;
         S.Head := Next;
      end if;
   end Enqueue;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Mid_RC : Channel_Value) is
   begin
      S := (others => <>);
      S.Data := (others => Mid_RC);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; Rx : in out Receiver.State; C : Serial_Word; Now_Us : Time_Us) is
      Result : Framing;
   begin
      Parse_Byte (S, C mod 256, Result);
      if Result = OK then
         case S.Received.Id is
            when RC_Override_Id =>
               Take_Override (S);
               S.Last_Frame_Time_Us := Now_Us;
            when Radio_Status_Id =>
               Take_Radio_Status (S, Rx);
            when others =>
               Enqueue (S);
         end case;
      end if;
   end Receive_Byte;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if S.Frame_Received then
         S.Frame_Received := False;
         Status.Complete := True;
      end if;
   end Frame_Status;

   ---------------
   -- Pop_Queue --
   ---------------

   procedure Pop_Queue (S : in out State; Msg : out Message; Got : out Boolean) is
   begin
      Got := S.Tail /= S.Head;
      Msg := S.Queue (S.Tail);
      if Got then
         S.Tail := (S.Tail + 1) mod Queue_Size;
      end if;
   end Pop_Queue;

end Adaflight.MAVLink;
