package body Adaflight.SD_Card with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;

   subtype U32 is Interfaces.Unsigned_32;

   Init_Dummy_Bytes       : constant := 10;
   Max_Reply_Delay        : constant := 8;
   Check_Pattern          : constant Byte := 16#AB#;
   Voltage_2_7_To_3_6     : constant := 16#01#;
   Init_Clock_Hz          : constant := 400_000;
   Full_Clock_Hz          : constant := 25_000_000;
   Non_DMA_Chunk          : constant := 256;
   Startup_Delay_Ms       : constant := 1000;
   Deselect_Delay_Us      : constant := 10;
   Init_Timeout_Ms        : constant := 1000;
   Read_Timeout_Ms        : constant := 100;
   Write_Timeout_Ms       : constant := 250;
   Max_Failures           : constant := 8;
   Idle_Token             : constant Byte := 16#FF#;
   Block_Start_Token      : constant Byte := 16#FE#;
   Multi_Start_Token      : constant Byte := 16#FC#;
   Multi_Stop_Token       : constant Byte := 16#FD#;
   Command_Go_Idle        : constant Byte := 0;
   Command_If_Cond        : constant Byte := 8;
   Command_Send_CSD       : constant Byte := 9;
   Command_Send_CID       : constant Byte := 10;
   Command_Set_Blocklen   : constant Byte := 16;
   Command_Read_Block     : constant Byte := 17;
   Command_Write_Block    : constant Byte := 24;
   Command_Write_Multiple : constant Byte := 25;
   Command_App            : constant Byte := 55;
   Command_Read_OCR       : constant Byte := 58;
   App_Send_Op_Cond       : constant Byte := 41;
   App_Erase_Count        : constant Byte := 23;
   Status_Idle            : constant Byte := 16#01#;
   Status_Illegal         : constant Byte := 16#04#;
   Command_CRC            : constant Byte := 16#95#;
   CSD_Version_1          : constant := 0;
   CSD_Version_2          : constant := 1;
   No_Reply               : constant Integer := -1;

   No_Data : constant Byte_Array (1 .. 0) := (1 .. 0 => 0);

   procedure Deselect (D : in out SPI_Device)
     with Global => null;

   procedure Deselect (D : in out SPI_Device) is
   begin
      Wait (D);
      Delay_Us (D, Deselect_Delay_Us);
      Release (D);
   end Deselect;

   procedure Reset_Card (D : in out SPI_Device; S : in out Card)
     with Global => null;

   procedure Reset_Card (D : in out SPI_Device; S : in out Card) is
      Inserted : Boolean;
      Divisor  : Interfaces.Unsigned_16;
   begin
      Is_Inserted (D, S, Inserted);
      if not Inserted then
         S.State := Not_Present;
         return;
      end if;
      if S.State >= Ready then
         Divider (D, Init_Clock_Hz, Divisor);
         Set_Divisor (D, Divisor);
      end if;
      S.Failure_Count := S.Failure_Count + 1;
      if S.Failure_Count >= Max_Failures then
         S.State := Not_Present;
      else
         Millis (D, S.Operation_Start);
         S.State := Resetting;
      end if;
   end Reset_Card;

   --  A segment that repeats until the card answers the idle byte, which
   --  restores the count, or the count runs out, which leaves a zero.
   procedure Idle_Segment (D : in out SPI_Device; S : in out Card; Value : out Byte; Aborted : out Boolean)
     with Global => null,
          Pre    => S.Idle_Count >= 1,
          Post   => (if not Aborted then S.Idle_Count = Max_Reply_Delay);

   procedure Idle_Segment (D : in out SPI_Device; S : in out Card; Value : out Byte; Aborted : out Boolean)
   is
      Rx : Byte_Array (0 .. 0) := (others => 0);
   begin
      Aborted := False;
      loop
         pragma Loop_Invariant (S.Idle_Count >= 1);
         Segment (D, Until_Idle, False, 1, No_Data, Rx, True);
         if Rx (0) = Idle_Token then
            S.Idle_Count := Max_Reply_Delay;
            Value := Rx (0);
            return;
         end if;
         S.Idle_Count := S.Idle_Count - 1;
         exit when S.Idle_Count <= 0;
      end loop;
      Value := 0;
      Aborted := True;
   end Idle_Segment;

   --  A segment that repeats while the card answers the idle byte, until
   --  the count runs out.
   procedure Not_Idle_Segment (D : in out SPI_Device; S : in out Card; Value : out Byte; Aborted : out Boolean)
     with Global => null,
          Pre    => S.Idle_Count >= 0;

   procedure Not_Idle_Segment (D : in out SPI_Device; S : in out Card; Value : out Byte; Aborted : out Boolean)
   is
      Rx : Byte_Array (0 .. 0) := (others => 0);
   begin
      Aborted := False;
      loop
         pragma Loop_Invariant (S.Idle_Count >= 0);
         Segment (D, Until_Not_Idle, False, 1, No_Data, Rx, True);
         Value := Rx (0);
         exit when Value /= Idle_Token;
         if S.Idle_Count <= 0 then
            S.Idle_Count := S.Idle_Count - 1;
            Aborted := True;
            return;
         end if;
         S.Idle_Count := S.Idle_Count - 1;
      end loop;
   end Not_Idle_Segment;

   procedure Wait_For_Idle (D : in out SPI_Device; S : in out Card; Max_Bytes : Idle_Counter; Idle : out Boolean)
     with Global => null,
          Pre    => Max_Bytes >= 1;

   procedure Wait_For_Idle (D : in out SPI_Device; S : in out Card; Max_Bytes : Idle_Counter; Idle : out Boolean)
   is
      Value          : Byte;
      Unused_Aborted : Boolean;
   begin
      S.Idle_Count := Max_Bytes;
      Start_Sequence (D);
      Idle_Segment (D, S, Value, Unused_Aborted);
      Wait (D);
      Idle := Value = Idle_Token;
   end Wait_For_Idle;

   procedure Wait_For_Non_Idle_Byte
     (D : in out SPI_Device; S : in out Card; Max_Delay : Idle_Counter; Value : out Byte)
     with Global => null,
          Pre    => Max_Delay >= 0;

   procedure Wait_For_Non_Idle_Byte
     (D : in out SPI_Device; S : in out Card; Max_Delay : Idle_Counter; Value : out Byte)
   is
      Unused_Aborted : Boolean;
   begin
      S.Idle_Count := Max_Delay;
      Start_Sequence (D);
      Not_Idle_Segment (D, S, Value, Unused_Aborted);
      Wait (D);
   end Wait_For_Non_Idle_Byte;

   --  The command after an idle byte and its answer, or no reply when no
   --  idle byte came, except for the reset command, which then answers 0.
   procedure Send_Command
     (D : in out SPI_Device; S : in out Card; Code : Byte; Argument : U32; Response : out Integer)
     with Global => null;

   procedure Send_Command
     (D : in out SPI_Device; S : in out Card; Code : Byte; Argument : U32; Response : out Integer)
   is
      Command : constant Byte_Array (0 .. 5) :=
        (16#40# or Code, Byte (Argument / 2 ** 24), Byte (Argument / 2 ** 16 mod 256), Byte (Argument / 256 mod 256),
         Byte (Argument mod 256), Command_CRC);
      Idle_Byte      : Byte;
      Reply          : Byte := 0;
      Aborted        : Boolean;
      Unused_Aborted : Boolean;
      Unused_Rx      : Byte_Array (0 .. 0) := (others => 0);
   begin
      S.Idle_Count := Max_Reply_Delay;
      Start_Sequence (D);
      Idle_Segment (D, S, Idle_Byte, Aborted);
      if not Aborted then
         Segment (D, Plain, False, Command'Length, Command, Unused_Rx, False);
         Not_Idle_Segment (D, S, Reply, Unused_Aborted);
      end if;
      Wait (D);
      if Idle_Byte /= Idle_Token and then Code /= Command_Go_Idle then
         Response := No_Reply;
      else
         Response := Integer (Reply);
      end if;
   end Send_Command;

   --  The application command's answer as a byte, no reply as 0xFF.
   procedure Send_App_Command
     (D : in out SPI_Device; S : in out Card; Code : Byte; Argument : U32; Response : out Byte)
     with Global => null;

   procedure Send_App_Command
     (D : in out SPI_Device; S : in out Card; Code : Byte; Argument : U32; Response : out Byte)
   is
      Unused_Reply : Integer;
      Reply        : Integer;
   begin
      Send_Command (D, S, Command_App, 0, Unused_Reply);
      Send_Command (D, S, Code, Argument, Reply);
      Response := (if Reply < 0 then 16#FF# else Byte (Reply mod 256));
   end Send_App_Command;

   procedure Validate_Interface_Condition (D : in out SPI_Device; S : in out Card; OK : out Boolean)
     with Global => null;

   procedure Validate_Interface_Condition (D : in out SPI_Device; S : in out Card; OK : out Boolean) is
      Reply : Byte_Array (0 .. 3) := (others => 0);
      Status : Integer;
   begin
      S.Version := 0;
      Send_Command (D, S, Command_If_Cond, Voltage_2_7_To_3_6 * 256 + U32 (Check_Pattern), Status);
      if Status = Integer (Status_Illegal or Status_Idle) then
         S.Version := 1;
      elsif Status = Integer (Status_Idle) then
         Start_Sequence (D);
         Segment (D, Plain, False, Reply'Length, No_Data, Reply, True);
         Wait (D);
         if Reply (3) = Check_Pattern then
            S.Version := 2;
         end if;
      end if;
      Deselect (D);
      OK := S.Version > 0;
   end Validate_Interface_Condition;

   procedure Read_OCR (D : in out SPI_Device; S : in out Card; OCR : out U32; OK : out Boolean)
     with Global => null;

   procedure Read_OCR (D : in out SPI_Device; S : in out Card; OCR : out U32; OK : out Boolean) is
      Status   : Integer;
      Response : Byte_Array (0 .. 3) := (others => 0);
   begin
      Send_Command (D, S, Command_Read_OCR, 0, Status);
      Start_Sequence (D);
      Segment (D, Plain, False, Response'Length, No_Data, Response, True);
      Wait (D);
      Deselect (D);
      OCR :=
        U32 (Response (0)) * 2 ** 24 + U32 (Response (1)) * 2 ** 16 + U32 (Response (2)) * 256 + U32 (Response (3));
      OK := Status = 0;
   end Read_OCR;

   type Receive_Status is (Received, Block_In_Progress, Receive_Error);

   --  A data block after its token, waited for over eight bytes, with its
   --  two check bytes discarded.
   procedure Receive_Data_Block
     (D : in out SPI_Device; Idle : out Idle_Counter; Data : in out Byte_Array; Status : out Receive_Status)
     with Global => null,
          Pre    => Data'Length in 1 .. Block_Bytes;

   procedure Receive_Data_Block
     (D : in out SPI_Device; Idle : out Idle_Counter; Data : in out Byte_Array; Status : out Receive_Status)
   is
      Token     : Byte_Array (0 .. 0) := (others => 0);
      Aborted   : Boolean := False;
      Unused_Rx : Byte_Array (0 .. 1) := (others => 0);
   begin
      Idle := Max_Reply_Delay;
      Start_Sequence (D);
      loop
         pragma Loop_Invariant (Idle >= 0);
         Segment (D, Until_Data_Token, False, 1, No_Data, Token, True);
         exit when Token (0) = Block_Start_Token;
         if Token (0) /= Idle_Token then
            Aborted := True;
            exit;
         end if;
         if Idle <= 0 then
            Idle := Idle - 1;
            Aborted := True;
            exit;
         end if;
         Idle := Idle - 1;
      end loop;
      if not Aborted then
         Segment (D, Plain, False, Data'Length, No_Data, Data, True);
         Segment (D, Plain, False, 2, No_Data, Unused_Rx, False);
      end if;
      Wait (D);
      Status :=
        (case Token (0) is
            when Idle_Token => Block_In_Progress,
            when Block_Start_Token => Received,
            when others => Receive_Error);
   end Receive_Data_Block;

   procedure Send_Data_Block_Finish (D : in out SPI_Device; Accepted : out Boolean)
     with Global => null;

   procedure Send_Data_Block_Finish (D : in out SPI_Device; Accepted : out Boolean) is
      Dummy_CRC : constant Byte_Array (0 .. 1) := (0, 0);
      Unused_Rx : Byte_Array (0 .. 1) := (others => 0);
      Response  : Byte_Array (0 .. 0) := (others => 0);
   begin
      Start_Sequence (D);
      Segment (D, Plain, False, 2, Dummy_CRC, Unused_Rx, False);
      Segment (D, Plain, False, 1, No_Data, Response, True);
      Wait (D);
      Accepted := (Response (0) and 16#1F#) = 16#05#;
   end Send_Data_Block_Finish;

   --  An idle byte, the token and the block, all of it with DMA, else its
   --  first chunk.
   procedure Send_Data_Block_Begin (D : in out SPI_Device; Data : Block; Multi : Boolean)
     with Global => null;

   procedure Send_Data_Block_Begin (D : in out SPI_Device; Data : Block; Multi : Boolean) is
      Token     : constant Byte_Array (0 .. 0) := (0 => (if Multi then Multi_Start_Token else Block_Start_Token));
      Unused_Rx : Byte_Array (0 .. 0) := (others => 0);
      Sent      : constant Positive := (if Uses_DMA (D) then Block_Bytes else Non_DMA_Chunk);
   begin
      Start_Sequence (D);
      Segment (D, Plain, False, 1, No_Data, Unused_Rx, False);
      Segment (D, Plain, False, 1, Token, Unused_Rx, False);
      Segment (D, Plain, False, Sent, Data (0 .. Sent - 1), Unused_Rx, False);
   end Send_Data_Block_Begin;

   procedure Receive_CID (D : in out SPI_Device; S : in out Card; OK : out Boolean)
     with Global => null;

   procedure Receive_CID (D : in out SPI_Device; S : in out Card; OK : out Boolean) is
      CID    : Byte_Array (0 .. 15) := (others => 0);
      Status : Receive_Status;
   begin
      Receive_Data_Block (D, S.Idle_Count, CID, Status);
      OK := Status = Received;
      if not OK then
         return;
      end if;
      S.Meta.Manufacturer := CID (0);
      S.Meta.OEM_Id := Interfaces.Unsigned_16 (CID (1)) * 256 + Interfaces.Unsigned_16 (CID (2));
      S.Meta.Product_Name := CID (3 .. 7);
      S.Meta.Revision_Major := CID (8) / 16;
      S.Meta.Revision_Minor := CID (8) and 16#0F#;
      S.Meta.Serial := U32 (CID (9)) * 2 ** 24 + U32 (CID (10)) * 2 ** 16 + U32 (CID (11)) * 256 + U32 (CID (12));
      S.Meta.Production_Year :=
        Interfaces.Unsigned_16 (CID (13) and 16#0F#) * 16 + Interfaces.Unsigned_16 (CID (14) / 16) + 2000;
      S.Meta.Production_Month := CID (14) and 16#0F#;
   end Receive_CID;

   --  A field of the card specific data, read most significant bit first;
   --  the reference reads a byte past a field that ends its buffer.
   function Read_Bitfield (Buffer : Byte_Array; Bit_Index : Natural; Bit_Len : Positive) return U32
     with Global => null,
          Pre    => Buffer'Length = 16 and then Bit_Index <= 127 and then Bit_Len <= 22
                    and then Bit_Len <= 128 - Bit_Index,
          Post   => Read_Bitfield'Result < 2 ** Bit_Len;

   function Read_Bitfield (Buffer : Byte_Array; Bit_Index : Natural; Bit_Len : Positive) return U32 is
      Result : U32 := 0;
   begin
      for K in Bit_Index .. Bit_Index + Bit_Len - 1 loop
         pragma Loop_Invariant (Result < 2 ** (K - Bit_Index));
         Result := Result * 2 + U32 ((Buffer (Buffer'First + K / 8) / 2 ** (7 - K mod 8)) mod 2);
      end loop;
      return Result;
   end Read_Bitfield;

   procedure Fetch_CSD (D : in out SPI_Device; S : in out Card; OK : out Boolean)
     with Global => null;

   procedure Fetch_CSD (D : in out SPI_Device; S : in out Card; OK : out Boolean) is
      Command_Status : Integer;
      Status         : Receive_Status;
   begin
      Send_Command (D, S, Command_Send_CSD, 0, Command_Status);
      OK := Command_Status = 0;
      if OK then
         Receive_Data_Block (D, S.Idle_Count, S.CSD, Status);
         OK := Status = Received and then Read_Bitfield (S.CSD, 127, 1) = 1;
      end if;
      if OK then
         case Read_Bitfield (S.CSD, 0, 2) is
            when CSD_Version_1 =>
               declare
                  Read_Block_Len : constant Interfaces.Unsigned_64 := 2 ** Natural (Read_Bitfield (S.CSD, 44, 4));
                  Count_Mult     : constant Interfaces.Unsigned_64 := 2 ** Natural (Read_Bitfield (S.CSD, 78, 3) + 2);
                  Block_Count    : constant Interfaces.Unsigned_64 :=
                    Interfaces.Unsigned_64 (Read_Bitfield (S.CSD, 54, 12) + 1) * Count_Mult;
                  Capacity       : constant Interfaces.Unsigned_64 := Block_Count * Read_Block_Len;
               begin
                  S.Meta.Num_Blocks := U32 (Capacity / Block_Bytes);
               end;
            when CSD_Version_2 =>
               S.Meta.Num_Blocks := (Read_Bitfield (S.CSD, 58, 22) + 1) * 1024;
            when others =>
               OK := False;
         end case;
      end if;
      Deselect (D);
   end Fetch_CSD;

   procedure Check_Init_Done (D : in out SPI_Device; S : in out Card; Done : out Boolean)
     with Global => null;

   procedure Check_Init_Done (D : in out SPI_Device; S : in out Card; Done : out Boolean) is
      Status : Byte;
   begin
      Send_App_Command (D, S, App_Send_Op_Cond, (if S.Version = 2 then 2 ** 30 else 0), Status);
      Deselect (D);
      Done := Status = 0;
   end Check_Init_Done;

   procedure Set_Block_Length (D : in out SPI_Device; S : in out Card; Length : U32; OK : out Boolean)
     with Global => null;

   procedure Set_Block_Length (D : in out SPI_Device; S : in out Card; Length : U32; OK : out Boolean) is
      Status : Integer;
   begin
      Send_Command (D, S, Command_Set_Blocklen, Length, Status);
      Deselect (D);
      OK := Status = 0;
   end Set_Block_Length;

   procedure End_Write_Blocks (D : in out SPI_Device; S : in out Card; Status : out Operation_Status)
     with Global => null;

   procedure End_Write_Blocks (D : in out SPI_Device; S : in out Card; Status : out Operation_Status) is
      Token     : constant Byte_Array (0 .. 0) := (0 => Multi_Stop_Token);
      Unused_Rx : Byte_Array (0 .. 0) := (others => 0);
      Value     : Byte;
   begin
      S.Multi_Remain := 0;
      Start_Sequence (D);
      Segment (D, Plain, False, 1, No_Data, Unused_Rx, False);
      Segment (D, Plain, False, 1, Token, Unused_Rx, False);
      Wait (D);
      Wait_For_Non_Idle_Byte (D, S, 1, Value);
      if Value = Idle_Token then
         S.State := Ready;
         Status := Success;
      else
         S.State := Stopping_Multiple;
         Millis (D, S.Operation_Start);
         Status := In_Progress;
      end if;
   end End_Write_Blocks;

   function Block_Address (S : Card; Index : U32) return U32 is
     (if S.High_Capacity then Index else Index * Block_Bytes)
     with Global => null;

   procedure Preinit (D : in out SPI_Device; C : Config) is
   begin
      Preinit_CS (D, C.CS_Tag);
   end Preinit;

   procedure Init (D : in out SPI_Device; S : in out Card; C : Config) is
      Divisor   : Interfaces.Unsigned_16;
      Unused_Rx : Byte_Array (0 .. 0) := (others => 0);
   begin
      S.Has_Detect_Pin := C.Detect_Tag /= 0;
      S.Detect_Inverted := S.Has_Detect_Pin and then C.Detect_Inverted;
      if S.Has_Detect_Pin then
         Init_Detect_Pin (D);
      end if;
      S.Enabled := C.Mode /= Mode_Off;
      if not S.Enabled then
         S.State := Not_Present;
         return;
      end if;
      Attach_Bus (D, C.Device);
      if C.CS_Tag /= 0 then
         Prepare_CS (D);
      end if;
      Divider (D, Init_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Delay_Ms (D, Startup_Delay_Ms);
      CS_High (D);
      Start_Sequence (D);
      Segment (D, Plain, True, Init_Dummy_Bytes, No_Data, Unused_Rx, False);
      Wait (D);
      if C.CS_Tag /= 0 then
         Configure_CS (D);
      end if;
      Millis (D, S.Operation_Start);
      S.State := Resetting;
      S.Failure_Count := 0;
   end Init;

   procedure Is_Inserted (D : in out SPI_Device; S : Card; Inserted : out Boolean) is
      High : Boolean;
   begin
      Inserted := True;
      if S.Has_Detect_Pin then
         Read_Detect_Pin (D, High);
         Inserted := High;
         if S.Detect_Inverted then
            Inserted := not Inserted;
         end if;
      end if;
   end Is_Inserted;

   procedure Poll (D : in out SPI_Device; S : in out Card; Card_Ready : out Boolean) is
      Again    : Boolean;
      Status   : Integer;
      OK       : Boolean;
      Done     : Boolean;
      OCR      : U32;
      Busy     : Boolean;
      Complete_Send : Boolean;
      Got      : Receive_Status;
      Divisor  : Interfaces.Unsigned_16;
      Now      : U32;
      Ending   : Operation_Status;
   begin
      if not S.Enabled then
         S.State := Not_Present;
         Card_Ready := False;
         return;
      end if;
      loop
         Again := False;
         case S.State is
            when Resetting =>
               Send_Command (D, S, Command_Go_Idle, 0, Status);
               Deselect (D);
               if Status = Integer (Status_Idle) then
                  Validate_Interface_Condition (D, S, OK);
                  if OK then
                     S.State := Initializing;
                     Again := True;
                  else
                     S.State := Not_Present;
                  end if;
               end if;
            when Initializing =>
               Check_Init_Done (D, S, Done);
               if Done then
                  if S.Version = 2 then
                     Read_OCR (D, S, OCR, OK);
                     if not OK then
                        Reset_Card (D, S);
                        Again := True;
                     else
                        S.High_Capacity := (OCR and 2 ** 30) /= 0;
                     end if;
                  else
                     S.High_Capacity := False;
                  end if;
                  if not Again then
                     Fetch_CSD (D, S, OK);
                     if OK then
                        Send_Command (D, S, Command_Send_CID, 0, Status);
                        if Status = 0 then
                           S.State := Receiving_CID;
                        else
                           Deselect (D);
                           Reset_Card (D, S);
                        end if;
                        Again := True;
                     end if;
                  end if;
               end if;
            when Receiving_CID =>
               Receive_CID (D, S, OK);
               if OK then
                  Deselect (D);
                  if not S.High_Capacity then
                     Set_Block_Length (D, S, Block_Bytes, OK);
                  end if;
                  if not OK then
                     Reset_Card (D, S);
                  else
                     Divider (D, Full_Clock_Hz, Divisor);
                     Set_Divisor (D, Divisor);
                     S.Multi_Remain := 0;
                     S.State := Ready;
                  end if;
                  Again := True;
               end if;
            when Sending_Write =>
               Bus_Busy (D, Busy);
               Complete_Send := not Busy;
               if not Uses_DMA (D) then
                  if S.Op.Chunk < Block_Bytes / Non_DMA_Chunk then
                     Read_Write
                       (D, S.Data (Non_DMA_Chunk * S.Op.Chunk .. Non_DMA_Chunk * S.Op.Chunk + Non_DMA_Chunk - 1));
                     S.Op.Chunk := S.Op.Chunk + 1;
                  end if;
                  Complete_Send := S.Op.Chunk = Block_Bytes / Non_DMA_Chunk;
               end if;
               if Complete_Send then
                  Send_Data_Block_Finish (D, OK);
                  if OK then
                     S.State := Waiting_For_Write;
                     Millis (D, S.Operation_Start);
                     if S.Op.Has_Callback then
                        Complete (D, True, S.Op.Index, True, S.Op.Callback_Data);
                     end if;
                  else
                     Reset_Card (D, S);
                     if S.Op.Has_Callback then
                        Complete (D, True, S.Op.Index, False, S.Op.Callback_Data);
                     end if;
                     Again := True;
                  end if;
               end if;
            when Waiting_For_Write =>
               Wait_For_Idle (D, S, Max_Reply_Delay, OK);
               if OK then
                  S.Failure_Count := 0;
                  if S.Multi_Remain > 1 then
                     S.Multi_Remain := S.Multi_Remain - 1;
                     S.Multi_Next := S.Multi_Next + 1;
                     S.State := Writing_Multiple;
                  elsif S.Multi_Remain = 1 then
                     End_Write_Blocks (D, S, Ending);
                     if Ending = Success then
                        Deselect (D);
                     end if;
                  else
                     S.State := Ready;
                     Deselect (D);
                  end if;
               else
                  Millis (D, Now);
                  if Now > S.Operation_Start + Write_Timeout_Ms then
                     Reset_Card (D, S);
                     Again := True;
                  end if;
               end if;
            when Reading =>
               Receive_Data_Block (D, S.Idle_Count, S.Data, Got);
               if Got = Block_In_Progress then
                  Millis (D, Now);
                  if Now > S.Operation_Start + Read_Timeout_Ms then
                     Got := Receive_Error;
                  end if;
               end if;
               case Got is
                  when Received =>
                     Deselect (D);
                     S.State := Ready;
                     S.Failure_Count := 0;
                     if S.Op.Has_Callback then
                        Complete (D, False, S.Op.Index, True, S.Op.Callback_Data);
                     end if;
                  when Block_In_Progress =>
                     null;
                  when Receive_Error =>
                     Deselect (D);
                     Reset_Card (D, S);
                     if S.Op.Has_Callback then
                        Complete (D, False, S.Op.Index, False, S.Op.Callback_Data);
                     end if;
                     Again := True;
               end case;
            when Stopping_Multiple =>
               Wait_For_Idle (D, S, Max_Reply_Delay, OK);
               if OK then
                  Deselect (D);
                  S.State := Ready;
               else
                  Millis (D, Now);
                  if Now > S.Operation_Start + Write_Timeout_Ms then
                     Reset_Card (D, S);
                     Again := True;
                  end if;
               end if;
            when Not_Present | Ready | Writing_Multiple =>
               null;
         end case;
         exit when not Again;
      end loop;
      if S.State in Resetting .. Receiving_CID then
         Millis (D, Now);
         if Now - S.Operation_Start > Init_Timeout_Ms then
            Reset_Card (D, S);
         end if;
      end if;
      Card_Ready := S.State in Ready | Writing_Multiple;
   end Poll;

   procedure Write_Block
     (D             : in out SPI_Device;
      S             : in out Card;
      Index         : U32;
      Data          : Block;
      Has_Callback  : Boolean;
      Callback_Data : U32;
      Status        : out Operation_Status)
   is
      Again  : Boolean;
      Reply  : Integer;
      Ending : Operation_Status;
   begin
      loop
         Again := False;
         case S.State is
            when Writing_Multiple =>
               if Index /= S.Multi_Next then
                  End_Write_Blocks (D, S, Ending);
                  if Ending = Success then
                     Again := True;
                  else
                     Status := Busy;
                     return;
                  end if;
               end if;
            when Ready =>
               Send_Command (D, S, Command_Write_Block, Block_Address (S, Index), Reply);
               if Reply /= 0 then
                  Deselect (D);
                  Reset_Card (D, S);
                  Status := Failure;
                  return;
               end if;
            when others =>
               Status := Busy;
               return;
         end case;
         exit when not Again;
      end loop;
      Send_Data_Block_Begin (D, Data, S.State = Writing_Multiple);
      S.Data := Data;
      S.Op := (Index => Index, Chunk => 1, Has_Callback => Has_Callback, Callback_Data => Callback_Data);
      S.State := Sending_Write;
      Status := In_Progress;
   end Write_Block;

   procedure Begin_Write_Blocks
     (D      : in out SPI_Device;
      S      : in out Card;
      Index  : U32;
      Count  : U32;
      Status : out Operation_Status)
   is
      Ending : Operation_Status;
      Reply  : Byte;
      Second : Integer := No_Reply;
   begin
      if S.State /= Ready then
         if S.State = Writing_Multiple then
            if Index = S.Multi_Next then
               Status := Success;
               return;
            end if;
            End_Write_Blocks (D, S, Ending);
            if Ending /= Success then
               Status := Busy;
               return;
            end if;
         else
            Status := Busy;
            return;
         end if;
      end if;
      Send_App_Command (D, S, App_Erase_Count, Count, Reply);
      if Reply = 0 then
         Send_Command (D, S, Command_Write_Multiple, Block_Address (S, Index), Second);
      end if;
      if Reply = 0 and then Second = 0 then
         S.State := Writing_Multiple;
         S.Multi_Remain := Count;
         S.Multi_Next := Index;
         Status := Success;
      else
         Deselect (D);
         Reset_Card (D, S);
         Status := Failure;
      end if;
   end Begin_Write_Blocks;

   procedure Read_Block
     (D             : in out SPI_Device;
      S             : in out Card;
      Index         : U32;
      Has_Callback  : Boolean;
      Callback_Data : U32;
      Accepted      : out Boolean)
   is
      Ending : Operation_Status;
      Reply  : Integer;
   begin
      if S.State /= Ready then
         if S.State = Writing_Multiple then
            End_Write_Blocks (D, S, Ending);
            if Ending /= Success then
               Accepted := False;
               return;
            end if;
         else
            Accepted := False;
            return;
         end if;
      end if;
      Send_Command (D, S, Command_Read_Block, Block_Address (S, Index), Reply);
      if Reply = 0 then
         S.Op := (Index => Index, Chunk => 0, Has_Callback => Has_Callback, Callback_Data => Callback_Data);
         S.State := Reading;
         Millis (D, S.Operation_Start);
         Accepted := True;
      else
         Deselect (D);
         Accepted := False;
      end if;
   end Read_Block;

end Adaflight.SD_Card;
