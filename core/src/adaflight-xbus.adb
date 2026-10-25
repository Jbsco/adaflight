with Adaflight.Bytes;

package body Adaflight.XBUS with SPARK_Mode is
   use type Bytes.Byte;

   --  The Dallas one-wire CRC-8 over one byte, bit by bit from the low end.
   function RJ01_CRC8 (Data : Byte; Seed : Byte) return Byte is
      In_Data : Byte := Data;
      Result  : Byte := Seed;
   begin
      for Bits_Left in reverse 1 .. 8 loop
         if (Result + In_Data) mod 2 = 0 then
            Result := Result / 2;
         else
            Result := (Natural (Bytes.Byte (Result) xor 16#18#) / 2) + 16#80#;
         end if;
         In_Data := In_Data / 2;
      end loop;
      return Result;
   end RJ01_CRC8;

   --  A Mode B frame at an offset: the channels from its words through the
   --  pulse conversion, 800 plus the word's 1400 fraction of 4096, once its
   --  CRC-16 over all but the last two bytes matches them, high byte first.
   subtype Mode_B_Offset is Natural range 0 .. RJ01_Offset_Bytes;

   procedure Unpack_Mode_B (S : in out State; Offset : Mode_B_Offset; Length : Frame_Length)
     with Pre => Offset + Length <= Frame_Size_A2 and then Length in Frame_Size_A1 | Frame_Size_A2
   is
      CRC : Interfaces.Unsigned_16 := 0;
   begin
      for I in Offset .. Offset + Length - 3 loop
         CRC := Bytes.CRC16_CCITT (CRC, Bytes.Byte (S.Frame (I)));
      end loop;
      if Natural (CRC) = S.Frame (Offset + Length - 2) * 256 + S.Frame (Offset + Length - 1) then
         for I in Channel loop
            declare
               Address : constant Natural range 1 .. 26 := Offset + 1 + I * 2;
               Value   : constant Channel_Value := S.Frame (Address) * 256 + S.Frame (Address + 1);
            begin
               S.Data (I) := 800 + (Value * 1_400) / 4_096;
            end;
         end loop;
         S.Frame_Received := True;
      end if;
   end Unpack_Mode_B;

   --  The RJ01 outer frame: its length byte, the CRC-8 over all but its last
   --  byte against that byte, and then the Mode B frame three bytes in.
   procedure Unpack_RJ01 (S : in out State) is
      Outer_CRC : Byte := 0;
   begin
      if S.Frame (1) /= RJ01_Message_Length then
         return;
      end if;
      for I in 0 .. S.Length - 2 loop
         Outer_CRC := RJ01_CRC8 (Outer_CRC, S.Frame (I));
      end loop;
      if Outer_CRC /= S.Frame (S.Length - 1) then
         return;
      end if;
      Unpack_Mode_B (S, RJ01_Offset_Bytes, Frame_Size_A1);
   end Unpack_RJ01;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Kind : Provider) is
   begin
      S := (Kind => Kind, Length => (case Kind is when Mode_B => Frame_Size_A1, when Mode_B_RJ01 => RJ01_Frame_Size),
            others => <>);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Interval : constant Unsigned_32 := Now_Us - S.Time_Last_Us;
   begin
      S.Time_Last_Us := Now_Us;
      if Interval > Max_Frame_Time_Us then
         S.Position := 0;
         S.Data_Incoming := False;
      end if;
      if S.Position = 0 then
         if C = Start_Of_Frame_A1 then
            S.Data_Incoming := True;
            S.Length := (case S.Kind is when Mode_B_RJ01 => RJ01_Frame_Size, when Mode_B => Frame_Size_A1);
         elsif C = Start_Of_Frame_A2 and then S.Kind = Mode_B then
            S.Data_Incoming := True;
            S.Length := Frame_Size_A2;
         end if;
      end if;
      if S.Data_Incoming then
         S.Frame (S.Position) := C mod 256;
         if S.Position + 1 = S.Length then
            case S.Kind is
               when Mode_B =>
                  Unpack_Mode_B (S, 0, S.Length);
               when Mode_B_RJ01 =>
                  Unpack_RJ01 (S);
            end case;
            S.Position := 0;
            S.Data_Incoming := False;
         else
            S.Position := S.Position + 1;
         end if;
      end if;
   end Receive_Byte;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if not S.Frame_Received then
         return;
      end if;
      S.Frame_Received := False;
      Status.Complete := True;
   end Frame_Status;

end Adaflight.XBUS;
