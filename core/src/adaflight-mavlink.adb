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
   procedure Frame_Byte (L : in out Frame_Parser; C : Byte) is
      Found : Boolean;
      E     : MAVLink_Entries.Message_Entry;
   begin
      L.Status.Msg_Received := Incomplete;
      case L.Status.State is
         when Uninit | Idle =>
            if C = Start_V2 then
               L.Status.State := Got_Start;
               L.Rx.Len := 0;
               L.Rx.Magic := C;
               L.Status.Flags := L.Status.Flags - L.Status.Flags mod 2;
               L.Rx.Checksum := CRC_Init;
            elsif C = Start_V1 then
               L.Status.State := Got_Start;
               L.Rx.Len := 0;
               L.Rx.Magic := C;
               L.Status.Flags := L.Status.Flags - L.Status.Flags mod 2 + Flag_In_V1;
               L.Rx.Checksum := CRC_Init;
            end if;
         when Got_Start =>
            L.Rx.Len := C;
            L.Status.Packet_Idx := 0;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            if In_V1 (L.Status) then
               L.Rx.Incompat_Flags := 0;
               L.Rx.Compat_Flags := 0;
               L.Status.State := Got_Compat_Flags;
            else
               L.Status.State := Got_Length;
            end if;
         when Got_Length =>
            L.Rx.Incompat_Flags := C;
            if C / 2 /= 0 then
               L.Status.State := Idle;
            else
               L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
               L.Status.State := Got_Incompat_Flags;
            end if;
         when Got_Incompat_Flags =>
            L.Rx.Compat_Flags := C;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := Got_Compat_Flags;
         when Got_Compat_Flags =>
            L.Rx.Seq := C;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := Got_Seq;
         when Got_Seq =>
            L.Rx.Sysid := C;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := Got_Sysid;
         when Got_Sysid =>
            L.Rx.Compid := C;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := Got_Compid;
         when Got_Compid =>
            L.Rx.Id := C;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            if In_V1 (L.Status) then
               L.Status.State := (if L.Rx.Len > 0 then Got_Msgid3 else Got_Payload);
            else
               L.Status.State := Got_Msgid1;
            end if;
         when Got_Msgid1 =>
            L.Rx.Id := L.Rx.Id mod 2 ** 8 + C * 2 ** 8;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := Got_Msgid2;
         when Got_Msgid2 =>
            L.Rx.Id := L.Rx.Id mod 2 ** 16 + C * 2 ** 16;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            L.Status.State := (if L.Rx.Len > 0 then Got_Msgid3 else Got_Payload);
         when Got_Msgid3 =>
            --  The index stays below the length, itself at most the payload
            --  size; the bound is stated for the array.
            if L.Status.Packet_Idx < Max_Payload then
               L.Rx.Payload (L.Status.Packet_Idx) := C;
               L.Status.Packet_Idx := L.Status.Packet_Idx + 1;
            end if;
            L.Rx.Checksum := Accumulate (L.Rx.Checksum, C);
            if L.Status.Packet_Idx = L.Rx.Len then
               L.Status.State := Got_Payload;
            end if;
         when Got_Payload =>
            MAVLink_Entries.Lookup (L.Rx.Id, Found, E);
            if not Found then
               L.Status.State := Got_Bad_CRC1;
               L.Rx.CK0 := C;
            else
               L.Rx.Checksum := Accumulate (L.Rx.Checksum, E.CRC_Extra);
               L.Status.State := (if C /= Natural (L.Rx.Checksum and 16#FF#) then Got_Bad_CRC1 else Got_CRC1);
               L.Rx.CK0 := C;
               if L.Status.Packet_Idx < E.Max_Len then
                  for I in L.Status.Packet_Idx .. E.Max_Len - 1 loop
                     L.Rx.Payload (I) := 0;
                  end loop;
               end if;
            end if;
         when Got_CRC1 | Got_Bad_CRC1 =>
            L.Status.Msg_Received :=
              (if L.Status.State = Got_Bad_CRC1 or else C /= Natural (Interfaces.Shift_Right (L.Rx.Checksum, 8))
               then Bad_CRC else OK);
            L.Rx.CK1 := C;
            if L.Rx.Incompat_Flags mod 2 = 1 then
               if L.Status.Msg_Received = Bad_CRC then
                  L.Status.State := Signature_Wait_Bad_CRC;
               else
                  L.Status.State := Signature_Wait;
                  L.Status.Msg_Received := Incomplete;
               end if;
               L.Status.Signature_Left := Signature_Length;
            else
               L.Status.State := Idle;
               L.Received := L.Rx;
            end if;
         when Signature_Wait | Signature_Wait_Bad_CRC =>
            if L.Status.Signature_Left > 0 then
               L.Status.Signature_Left := L.Status.Signature_Left - 1;
            end if;
            if L.Status.Signature_Left = 0 then
               L.Status.Msg_Received := (if L.Status.State = Signature_Wait_Bad_CRC then Bad_CRC else OK);
               L.Status.State := Idle;
               L.Received := L.Rx;
            end if;
      end case;
      if L.Status.Msg_Received = OK then
         L.Status.Current_Rx_Seq := L.Rx.Seq;
         if L.Status.Success_Count = 0 then
            L.Status.Drop_Count := 0;
         end if;
         L.Status.Success_Count := (L.Status.Success_Count + 1) mod 65_536;
      end if;
      L.Received.Len := L.Rx.Len;
      if L.Status.Msg_Received = Bad_CRC then
         L.Received.Checksum := CRC_Word (L.Rx.CK0) + CRC_Word (L.Rx.CK1) * 256;
      end if;
   end Frame_Byte;

   procedure Parse_Byte (L : in out Frame_Parser; C : Byte; Result : out Framing) is
   begin
      Frame_Byte (L, C);
      Result := L.Status.Msg_Received;
      if Result in Bad_CRC | Bad_Signature then
         L.Status.Msg_Received := Incomplete;
         L.Status.State := Idle;
         if C = Start_V2 then
            L.Status.State := Got_Start;
            L.Rx.Len := 0;
            L.Rx.Checksum := CRC_Init;
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
            W : constant Channel_Value :=
              S.Frames.Received.Payload (2 * I) + 256 * S.Frames.Received.Payload (2 * I + 1);
         begin
            if W /= 0 and then W /= 65_535 then
               S.Data (I) := W;
            end if;
         end;
      end loop;
      S.Frame_Received := True;
   end Take_Override;

   --  The radio status: the free transmitter buffer, the remote RSSI as a
   --  negative dBm held at the range minimum and scaled onto the receiver's
   --  range, the dBm itself, the noise as the SNR, and the local RSSI as the
   --  link quality.
   procedure Take_Radio_Status (S : in out State; Rx : in out Receiver.State) is
      Dbm    : constant Integer range -255 .. 0 := -S.Frames.Received.Payload (5);
      Floor  : constant Integer range RSSI_Dbm_Min .. 0 := Integer'Max (Dbm, RSSI_Dbm_Min);
      Scaled : constant Integer range 0 .. Receiver.RSSI_Max :=
        (Receiver.RSSI_Max * (Floor - RSSI_Dbm_Min)) / (-RSSI_Dbm_Min);
   begin
      S.Tx_Buffer_Valid := True;
      S.Tx_Buffer_Free := S.Frames.Received.Payload (6);
      Receiver.Set_RSSI (Rx, Scaled, Receiver.Protocol_Mavlink);
      Receiver.Set_RSSI_Dbm (Rx, Dbm, Receiver.Protocol_Mavlink);
      Receiver.Set_RSNR (Rx, S.Frames.Received.Payload (7));
      if Rx.Quality_From = Receiver.Mavlink then
         Receiver.Set_Link_Quality_Direct (Rx, (100 * S.Frames.Received.Payload (4)) / 255);
      end if;
   end Take_Radio_Status;

   procedure Enqueue (S : in out State) is
      Next : constant Queue_Index := (S.Head + 1) mod Queue_Size;
   begin
      if Next /= S.Tail then
         S.Queue (S.Head) := S.Frames.Received;
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
      Parse_Byte (S.Frames, C mod 256, Result);
      if Result = OK then
         case S.Frames.Received.Id is
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
