package body Adaflight.MSP_Port with SPARK_Mode is

   Dollar        : constant Byte := Character'Pos ('$');
   Hash          : constant Byte := Character'Pos ('#');
   Start_Of_Text : constant Byte := 2;

   ----------
   -- Init --
   ----------

   procedure Init (P : out Port) is
   begin
      P := (others => <>);
   end Init;

   --------------------
   -- Take_V2_Header --
   --------------------

   --  The version 2 header at First in the buffer, read on its last byte: a
   --  size past the buffer rejects the frame, else the payload or its
   --  checksum follows from the start of the buffer.
   procedure Take_V2_Header (P : in out Port; First : In_Index;
                             Payload_Phase, Checksum_Phase : Decoder_Phase)
     with Pre  => First <= In_Buffer_Size - V2_Header_Size
                  and then P.Decoder in Header_V2_Over_V1 | Header_V2_Native
                  and then Payload_Phase in Payload_V2_Over_V1 | Payload_V2_Native
                  and then Checksum_Phase in Checksum_V2_Over_V1 | Checksum_V2_Native,
          Post => P.Phase = P.Phase'Old and then P.Pending = P.Pending'Old
                  and then P.Last_Activity_Ms = P.Last_Activity_Ms'Old
   is
      Hdr_Size : constant Natural := Natural (P.Data (First + 3)) + 256 * Natural (P.Data (First + 4));
   begin
      if Hdr_Size > In_Buffer_Size then
         P.Decoder := Idle;
         P.Offset := P.Offset + 1;
      else
         P.Data_Size := Hdr_Size;
         P.Command_Id := Natural (P.Data (First + 1)) + 256 * Natural (P.Data (First + 2));
         P.Flags := P.Data (First);
         P.Offset := 0;
         P.Decoder := (if P.Data_Size > 0 then Payload_Phase else Checksum_Phase);
      end if;
   end Take_V2_Header;

   -------------
   -- Receive --
   -------------

   --  One byte through the decoder. A header or payload byte lands at the
   --  position, and the position advances unless the byte completes the
   --  header or the payload, when the next phase starts with the position
   --  the frame needs.
   procedure Receive (P : in out Port; C : Byte)
     with Post => P.Phase = P.Phase'Old and then P.Pending = P.Pending'Old
                  and then P.Last_Activity_Ms = P.Last_Activity_Ms'Old
   is
   begin
      case P.Decoder is
         when Idle | Header_Start | Command_Received =>
            P.Offset := 0;
            P.Checksum_1 := 0;
            P.Checksum_2 := 0;
            if C = Character'Pos ('M') then
               P.Decoder := Header_M;
               P.Version := V1;
            elsif C = Character'Pos ('X') then
               P.Decoder := Header_X;
               P.Version := V2_Native;
            else
               P.Decoder := Idle;
            end if;

         when Header_M | Header_X =>
            if C = Character'Pos ('<') then
               P.Kind := Command;
               P.Decoder := (if P.Decoder = Header_M then Header_V1 else Header_V2_Native);
            elsif C = Character'Pos ('>') then
               P.Kind := Reply;
               P.Decoder := (if P.Decoder = Header_M then Header_V1 else Header_V2_Native);
            else
               P.Decoder := Idle;
            end if;

         when Header_V1 =>
            P.Data (P.Offset) := C;
            P.Checksum_1 := P.Checksum_1 xor C;
            if P.Offset + 1 < V1_Header_Size then
               P.Offset := P.Offset + 1;
            else
               declare
                  Hdr_Size : constant Natural := Natural (P.Data (0));
                  Hdr_Cmd  : constant Byte := P.Data (1);
               begin
                  if Hdr_Size > In_Buffer_Size then
                     P.Decoder := Idle;
                     P.Offset := V1_Header_Size;
                  elsif Hdr_Cmd = V2_Frame_Id then
                     --  The version 1 payload must hold the version 2 header and its checksum.
                     if Hdr_Size >= V2_Header_Size + 1 then
                        P.Version := V2_Over_V1;
                        P.Decoder := Header_V2_Over_V1;
                     else
                        P.Decoder := Idle;
                     end if;
                     P.Offset := V1_Header_Size;
                  else
                     P.Data_Size := Hdr_Size;
                     P.Command_Id := Natural (Hdr_Cmd);
                     P.Flags := 0;
                     P.Offset := 0;
                     P.Decoder := (if P.Data_Size > 0 then Payload_V1 else Checksum_V1);
                  end if;
               end;
            end if;

         when Payload_V1 =>
            P.Data (P.Offset) := C;
            P.Checksum_1 := P.Checksum_1 xor C;
            if P.Offset + 1 < P.Data_Size then
               P.Offset := P.Offset + 1;
            else
               P.Decoder := Checksum_V1;
               P.Offset := P.Offset + 1;
            end if;

         when Checksum_V1 =>
            P.Decoder := (if P.Checksum_1 = C then Command_Received else Idle);

         when Header_V2_Over_V1 =>
            P.Data (P.Offset) := C;
            P.Checksum_1 := P.Checksum_1 xor C;
            P.Checksum_2 := CRC8 (P.Checksum_2, C, DVB_S2_Polynomial);
            if P.Offset + 1 < V1_Header_Size + V2_Header_Size then
               P.Offset := P.Offset + 1;
            else
               Take_V2_Header (P, V1_Header_Size, Payload_V2_Over_V1, Checksum_V2_Over_V1);
            end if;

         when Payload_V2_Over_V1 =>
            P.Checksum_2 := CRC8 (P.Checksum_2, C, DVB_S2_Polynomial);
            P.Checksum_1 := P.Checksum_1 xor C;
            P.Data (P.Offset) := C;
            if P.Offset + 1 < P.Data_Size then
               P.Offset := P.Offset + 1;
            else
               P.Decoder := Checksum_V2_Over_V1;
               P.Offset := P.Offset + 1;
            end if;

         when Checksum_V2_Over_V1 =>
            P.Checksum_1 := P.Checksum_1 xor C;
            P.Decoder := (if P.Checksum_2 = C then Checksum_V1 else Idle);

         when Header_V2_Native =>
            P.Data (P.Offset) := C;
            P.Checksum_2 := CRC8 (P.Checksum_2, C, DVB_S2_Polynomial);
            if P.Offset + 1 < V2_Header_Size then
               P.Offset := P.Offset + 1;
            else
               Take_V2_Header (P, 0, Payload_V2_Native, Checksum_V2_Native);
            end if;

         when Payload_V2_Native =>
            P.Checksum_2 := CRC8 (P.Checksum_2, C, DVB_S2_Polynomial);
            P.Data (P.Offset) := C;
            if P.Offset + 1 < P.Data_Size then
               P.Offset := P.Offset + 1;
            else
               P.Decoder := Checksum_V2_Native;
               P.Offset := P.Offset + 1;
            end if;

         when Checksum_V2_Native =>
            P.Decoder := (if P.Checksum_2 = C then Command_Received else Idle);
      end case;
   end Receive;

   -------------
   -- Process --
   -------------

   procedure Process (P : in out Port; Input : Byte_Array; Consumed : out Natural;
                      Now_Ms : Unsigned_32; Opt : Options; Ev : out Event) is
   begin
      Ev := Nothing;
      Consumed := 0;

      while P.Phase = Idle and then Consumed < Input'Length loop
         pragma Loop_Invariant (Consumed < Input'Length);
         declare
            C : constant Byte := Input (Input'First + Consumed);
         begin
            Consumed := Consumed + 1;
            P.Last_Activity_Ms := Now_Ms;
            if C = Dollar then
               P.Pending := None;
               P.Phase := Packet;
               P.Decoder := Header_Start;
            elsif Opt.Evaluate_Non_MSP and then not Opt.Peripheral then
               if C = Opt.Reboot_Character then
                  P.Pending := Bootloader;
               elsif C = Hash then
                  P.Pending := Command_Line;
               elsif C = Start_Of_Text then
                  P.Phase := CLI_Command;
                  Ev := CLI_Command_Entered;
               elsif P.Pending = Bootloader then
                  P.Pending := None;
               end if;
            end if;
         end;
      end loop;

      case P.Phase is
         when Idle =>
            if P.Pending /= None and then Clock.Elapsed (Now_Ms, P.Last_Activity_Ms) >= Pending_Guard_Ms then
               case P.Pending is
                  when Bootloader =>
                     Ev := Reset_Requested;
                  when Command_Line =>
                     P.Pending := None;
                     P.Phase := CLI_Active;
                     Ev := CLI_Opened;
                  when None =>
                     null;
               end case;
            end if;

         when Packet =>
            while Consumed < Input'Length loop
               pragma Loop_Invariant (Consumed < Input'Length);
               Receive (P, Input (Input'First + Consumed));
               Consumed := Consumed + 1;
               if P.Decoder = Command_Received then
                  Ev := (if P.Kind = Command then Command_Frame else Reply_Frame);
                  P.Decoder := Idle;
               end if;
               if P.Decoder = Idle then
                  P.Phase := Idle;
                  exit;
               end if;
            end loop;

         when CLI_Active | CLI_Command =>
            if not Opt.CLI_Running then
               P.Phase := Idle;
            end if;
      end case;
   end Process;

   ------------
   -- Encode --
   ------------

   procedure Encode (Version : Framing; Command : Command_Code; Flags : Byte; Error : Boolean;
                     Payload : Byte_Array; Frame : out Frame_Buffer; Length : out Positive) is
      N : constant Payload_Size := Payload'Length;
      H : constant Positive := Header_Length (Version, N);

      --  The version 2 header: the flags, the command, and the size, low byte first.
      procedure Put_V2_Header (First : Frame_Index)
        with Pre => First <= Max_Header - V2_Header_Size
      is
      begin
         Frame (First) := Flags;
         Frame (First + 1) := Byte (Command mod 256);
         Frame (First + 2) := Byte (Command / 256);
         Frame (First + 3) := Byte (N mod 256);
         Frame (First + 4) := Byte (N / 256);
      end Put_V2_Header;

   begin
      Frame := (others => 0);
      Frame (0) := Dollar;
      Frame (1) := (if Version = V2_Native then Character'Pos ('X') else Character'Pos ('M'));
      Frame (2) := (if Error then Character'Pos ('!') else Character'Pos ('>'));

      case Version is
         when V1 =>
            Frame (4) := Byte (Command);
            if N >= Jumbo_Limit then
               Frame (3) := Jumbo_Limit;
               Frame (5) := Byte (N mod 256);
               Frame (6) := Byte (N / 256);
            else
               Frame (3) := Byte (N);
            end if;

         when V2_Over_V1 =>
            --  The jumbo size follows the version 1 header and the version 2
            --  header follows it, as in the version 1 framing.
            declare
               V1_Size : constant Natural := V2_Header_Size + N + 1;
            begin
               Frame (4) := V2_Frame_Id;
               if V1_Size >= Jumbo_Limit then
                  Frame (3) := Jumbo_Limit;
                  Frame (5) := Byte (V1_Size mod 256);
                  Frame (6) := Byte (V1_Size / 256);
                  Put_V2_Header (3 + V1_Header_Size + Jumbo_Header_Size);
               else
                  Frame (3) := Byte (V1_Size);
                  Put_V2_Header (3 + V1_Header_Size);
               end if;
            end;

         when V2_Native =>
            Put_V2_Header (3);
      end case;

      for I in 0 .. N - 1 loop
         Frame (H + I) := Payload (Payload'First + I);
      end loop;

      case Version is
         when V1 =>
            Frame (H + N) := CRC8_Xor_Update (CRC8_Xor_Update (0, Frame (3 .. H - 1)), Payload);

         when V2_Over_V1 =>
            declare
               CRC : constant Byte :=
                 CRC8_Update (CRC8_Update (0, Frame (H - V2_Header_Size .. H - 1), DVB_S2_Polynomial),
                              Payload, DVB_S2_Polynomial);
            begin
               Frame (H + N) := CRC;
               Frame (H + N + 1) := CRC8_Xor_Update (CRC8_Xor_Update (0, Frame (3 .. H - 1)), Payload) xor CRC;
            end;

         when V2_Native =>
            Frame (H + N) := CRC8_Update (CRC8_Update (0, Frame (3 .. H - 1), DVB_S2_Polynomial),
                                          Payload, DVB_S2_Polynomial);
      end case;

      Length := H + N + Trailer_Length (Version);
   end Encode;

end Adaflight.MSP_Port;
