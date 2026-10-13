package body Adaflight.MSP_Telemetry with SPARK_Mode is

   Sequence_Mask : constant Byte := 16#0F#;
   Start_Mask    : constant Byte := 16#10#;
   Version_Mask  : constant Byte := 16#60#;
   Error_Mask    : constant Byte := 16#80#;
   Version_Shift : constant := 5;

   Min_Length_Chunk         : constant := 2;
   Min_Length_Request_V1    : constant := 3;
   Min_Length_Request_Jumbo : constant := 5;
   Min_Length_Request_V2    : constant := 6;

   function Low (V : Unsigned_16) return Byte is (Byte (V and 16#FF#));
   function High (V : Unsigned_16) return Byte is (Byte (Interfaces.Shift_Right (V, 8)));
   function Word (Lo, Hi : Byte) return Unsigned_16 is (Unsigned_16 (Lo) + 256 * Unsigned_16 (Hi));

   --  A one-byte reply with the error code, marked as an error response.
   procedure Error_Reply (T : in out Tunnel; Error : Byte; Command : Unsigned_16) is
   begin
      T.Response_Command := Command;
      T.Response_Buffer (0) := Error;
      T.Response_Read := 0;
      T.Response_Length := 1;
      T.Response_Result := Result_Error_Response;
      T.Header_Sent := False;
   end Error_Reply;

   procedure Handle_Frame (T : in out Tunnel; Payload : Byte_Array; Result : out Outcome; EEPROM_Write : out Boolean) is
      Length      : constant Natural := Payload'Length;
      Status      : Byte;
      Seq_Number  : Sequence;
      Data_Offset : Natural;
      Expecting   : Natural;
      Incoming    : Natural;
   begin
      Result := Ignored;
      EEPROM_Write := False;
      if Length < Min_Length_Chunk then
         return;
      end if;
      Status := Payload (Payload'First);
      Seq_Number := Natural (Status and Sequence_Mask);
      T.Last_Version := Natural (Interfaces.Shift_Right (Status and Version_Mask, Version_Shift));
      if T.Last_Version > Protocol_Version then
         Error_Reply (T, Error_Version_Mismatch, 0);
         Result := Error_Reply_Ready;
         return;
      end if;
      if (Status and Start_Mask) /= 0 then
         declare
            Size : Unsigned_16;
         begin
            if T.Last_Version = 1 then
               if Length < Min_Length_Request_V1 then
                  return;
               end if;
               Size := Unsigned_16 (Payload (Payload'First + 1));
               T.Request_Command := Unsigned_16 (Payload (Payload'First + 2));
               if Size = 16#FF# then
                  if Length < Min_Length_Request_Jumbo then
                     return;
                  end if;
                  Size := Word (Payload (Payload'First + 3), Payload (Payload'First + 4));
                  Data_Offset := Min_Length_Request_Jumbo;
               else
                  Data_Offset := Min_Length_Request_V1;
               end if;
            else
               if Length < Min_Length_Request_V2 then
                  return;
               end if;
               T.Request_Flags := Payload (Payload'First + 1);
               T.Request_Command := Word (Payload (Payload'First + 2), Payload (Payload'First + 3));
               Size := Word (Payload (Payload'First + 4), Payload (Payload'First + 5));
               Data_Offset := Min_Length_Request_V2;
            end if;
            if Size <= Request_Buffer_Size then
               T.Request_Filled := 0;
               T.Request_Expected := Natural (Size);
               T.Started := True;
            else
               Error_Reply (T, Error_Request_Too_Big, T.Request_Command);
               Result := Error_Reply_Ready;
               return;
            end if;
         end;
      else
         if not T.Started then
            return;
         end if;
         if (T.Last_Seq + 1) mod 16 /= Seq_Number then
            T.Started := False;
            return;
         end if;
         Data_Offset := 1;
      end if;
      T.Last_Seq := Seq_Number;
      Expecting := T.Request_Expected - T.Request_Filled;
      Incoming := Length - Data_Offset;
      if Expecting > Incoming then
         for K in 0 .. Incoming - 1 loop
            pragma Loop_Invariant (T.Request_Filled = T.Request_Filled'Loop_Entry);
            T.Request_Buffer (T.Request_Filled + K) := Payload (Payload'First + Data_Offset + K);
         end loop;
         T.Request_Filled := T.Request_Filled + Incoming;
         return;
      end if;
      for K in 0 .. Expecting - 1 loop
         pragma Loop_Invariant (T.Request_Filled = T.Request_Filled'Loop_Entry);
         T.Request_Buffer (T.Request_Filled + K) := Payload (Payload'First + Data_Offset + K);
      end loop;
      T.Request_Filled := 0;
      if T.Request_Command = EEPROM_Write_Command then
         EEPROM_Write := True;
      end if;
      T.Started := False;
      Result := Request_Ready;
   end Handle_Frame;

   procedure Prepare_Reply (T : in out Tunnel; Result : Result_Code; Payload : Byte_Array) is
      N : constant Natural := Payload'Length;
   begin
      T.Response_Command := T.Request_Command;
      T.Response_Result := Result;
      T.Response_Read := 0;
      T.Response_Length := N;
      for K in 0 .. N - 1 loop
         T.Response_Buffer (K) := Payload (Payload'First + K);
      end loop;
      if Result = Result_Error then
         T.Response_Buffer (N) := Error_Processor;
         T.Response_Length := N + 1;
      end if;
      T.Header_Sent := False;
   end Prepare_Reply;

   procedure Send_Reply (T : in out Tunnel; Chunk_Max : Chunk_Size; Chunk : out Chunk_Buffer; Length : out Natural;
                         More : out Boolean) is
      Pos             : Natural;
      Status          : Byte;
      Input_Remainder : Natural;
      Chunk_Remainder : Natural;
   begin
      Chunk := (others => 0);
      if not T.Header_Sent then
         Status := Start_Mask or Byte (T.Seq) or Interfaces.Shift_Left (Byte (T.Last_Version), Version_Shift);
         T.Seq := (T.Seq + 1) mod 16;
         if T.Response_Result < 0 then
            Status := Status or Error_Mask;
         end if;
         Chunk (0) := Status;
         declare
            Size : constant Unsigned_16 := Unsigned_16 (T.Response_Length - T.Response_Read);
         begin
            if T.Last_Version = 1 then
               if Size >= 16#FF# then
                  Chunk (1) := 16#FF#;
                  Chunk (2) := Low (T.Response_Command);
                  Chunk (3) := Low (Size);
                  Chunk (4) := High (Size);
                  Pos := 5;
               else
                  Chunk (1) := Low (Size);
                  Chunk (2) := Low (T.Response_Command);
                  Pos := 3;
               end if;
            else
               Chunk (1) := 0;
               Chunk (2) := Low (T.Response_Command);
               Chunk (3) := High (T.Response_Command);
               Chunk (4) := Low (Size);
               Chunk (5) := High (Size);
               Pos := 6;
            end if;
         end;
         T.Header_Sent := True;
      else
         Chunk (0) := Byte (T.Seq) or Interfaces.Shift_Left (Byte (T.Last_Version), Version_Shift);
         T.Seq := (T.Seq + 1) mod 16;
         Pos := 1;
      end if;
      Input_Remainder := T.Response_Length - T.Response_Read;
      Chunk_Remainder := Chunk_Max - Pos;
      if Input_Remainder >= Chunk_Remainder then
         for K in 0 .. Chunk_Remainder - 1 loop
            pragma Loop_Invariant (T.Response_Read = T.Response_Read'Loop_Entry);
            Chunk (Pos + K) := T.Response_Buffer (T.Response_Read + K);
         end loop;
         T.Response_Read := T.Response_Read + Chunk_Remainder;
         Length := Chunk_Max;
         More := True;
         return;
      end if;
      for K in 0 .. Input_Remainder - 1 loop
         pragma Loop_Invariant (T.Response_Read = T.Response_Read'Loop_Entry);
         Chunk (Pos + K) := T.Response_Buffer (T.Response_Read + K);
      end loop;
      T.Response_Read := 0;
      Length := Pos + Input_Remainder;
      More := False;
      T.Header_Sent := False;
   end Send_Reply;

end Adaflight.MSP_Telemetry;
