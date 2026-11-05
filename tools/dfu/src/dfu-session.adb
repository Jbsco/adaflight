package body DFU.Session with SPARK_Mode is

   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Word is Interfaces.Unsigned_16;

   Empty : constant Byte_Array (1 .. 0) := (others => 0);

   function Command (Code : Byte; A : Address) return Byte_Array is
     (Byte_Array'(Code, Byte (A and 16#FF#), Byte (Interfaces.Shift_Right (A, 8) and 16#FF#),
                  Byte (Interfaces.Shift_Right (A, 16) and 16#FF#), Byte (Interfaces.Shift_Right (A, 24))))
   with Post => Command'Result'Length = 5;

   procedure Get_Status (S : out Status; Ok : out Boolean) is
      Data : Byte_Array (0 .. 5);
      Got  : Natural;
   begin
      S := (others => <>);
      DFU.Transport.Receive (Status_Request, 0, Data, Got, Ok);
      if Ok and then Got = Data'Length then
         S := (Code  => Data (0),
               Poll  => Natural (Data (1)) + 256 * Natural (Data (2)) + 65_536 * Natural (Data (3)),
               State => Data (4));
      else
         Ok := False;
      end if;
   end Get_Status;

   --  A request without data whose result the next status read reports.
   procedure Request (Code : Byte) is
      Sent : Boolean;
      pragma Warnings (GNATprove, Off, "is set by", Reason => "the status read that follows reports the result");
   begin
      DFU.Transport.Send (Code, 0, Empty, Sent);
   end Request;

   procedure Clear_Status (Busy_Is_Stuck : Boolean; Ok : out Boolean) is
      S    : Status;
      Read : Boolean;
   begin
      Ok := False;
      for Attempt in 1 .. Max_Attempts loop
         Get_Status (S, Read);
         if Clear_Action (S, Read, Busy_Is_Stuck) = Done then
            Ok := True;
            return;
         end if;
         exit when Attempt = Max_Attempts;
         DFU.Transport.Wait (S.Poll);
         case Clear_Action (S, Read, Busy_Is_Stuck) is
            when Abort_Transfer =>
               Request (Abort_Request);
            when Clear_Error =>
               Request (Clear_Request);
            when Done | Poll_Again =>
               null;
         end case;
      end loop;
   end Clear_Status;

   --  A download the bootloader accepts with its busy state and the time to wait before the next read.
   procedure Download (Block : Word; Data : Byte_Array; Poll : out Natural; Ok : out Boolean)
   with Pre => Data'Length <= DFU.Transport.Max_Length
   is
      S : Status;
   begin
      Poll := 0;
      DFU.Transport.Send (Download_Request, Block, Data, Ok);
      if not Ok then
         return;
      end if;
      Get_Status (S, Ok);
      Ok := Ok and then S.State = Download_Busy;
      Poll := S.Poll;
   end Download;

   procedure Load_Address (A : Address; Ok : out Boolean) is
      Poll : Natural;
      S    : Status;
   begin
      Download (0, Command (Set_Address_Command, A), Poll, Ok);
      if not Ok then
         return;
      end if;
      DFU.Transport.Wait (Poll);
      Get_Status (S, Ok);
      Ok := Ok and then S.State = Download_Idle;
   end Load_Address;

   procedure Erase_Page (A : Address; Ok : out Boolean) is
      Poll : Natural;
      S    : Status;
   begin
      Download (0, Command (Erase_Command, A), Poll, Ok);
      if not Ok then
         return;
      end if;
      DFU.Transport.Wait (Poll);
      Get_Status (S, Ok);
      if not Ok then
         return;
      end if;
      if S.State = Download_Busy then
         Clear_Status (Busy_Is_Stuck => True, Ok => Ok);
         if Ok then
            Get_Status (S, Ok);
            Ok := Ok and then S.State = Idle;
         end if;
      else
         Ok := S.State = Download_Idle;
      end if;
   end Erase_Page;

   procedure Write (A : Address; Data : Byte_Array; Transfer : Transfer_Size; Ok : out Boolean) is
      Offset : Natural := 0;
      N      : Natural;
      Poll   : Natural;
      S      : Status;
   begin
      Load_Address (A, Ok);
      if not Ok then
         return;
      end if;
      for Block in 2 .. Max_Blocks + 1 loop
         pragma Loop_Invariant (Offset <= Data'Length);
         exit when Offset >= Data'Length;
         N := Natural'Min (Transfer, Data'Length - Offset);
         Download (Word (Block), Data (Data'First + Offset .. Data'First + Offset + N - 1), Poll, Ok);
         if not Ok then
            return;
         end if;
         DFU.Transport.Wait (Poll);
         Get_Status (S, Ok);
         if not Ok or else S.State /= Download_Idle then
            Ok := False;
            return;
         end if;
         Offset := Offset + N;
      end loop;
      Ok := Offset >= Data'Length;
   end Write;

   procedure Verify
     (A : Address; Data : Byte_Array; Transfer : Transfer_Size; Ok : out Boolean; Mismatch : out Data_Index)
   is
      Buffer : Byte_Array (0 .. DFU.Transport.Max_Length - 1) := (others => 0);
      Offset : Natural := 0;
      N      : Natural;
      Got    : Natural;
   begin
      Mismatch := 0;
      Clear_Status (False, Ok);
      if Ok then
         Load_Address (A, Ok);
      end if;
      if Ok then
         Clear_Status (False, Ok);
      end if;
      if not Ok then
         return;
      end if;
      for Block in 2 .. Max_Blocks + 1 loop
         pragma Loop_Invariant (Offset <= Data'Length);
         exit when Offset >= Data'Length;
         N := Natural'Min (Transfer, Data'Length - Offset);
         DFU.Transport.Receive (Upload_Request, Word (Block), Buffer (0 .. N - 1), Got, Ok);
         if not Ok or else Got /= N then
            Mismatch := Offset;
            Ok := False;
            return;
         end if;
         for J in 0 .. N - 1 loop
            if Buffer (J) /= Data (Data'First + Offset + J) then
               Mismatch := Offset + J;
               Ok := False;
               return;
            end if;
         end loop;
         Offset := Offset + N;
      end loop;
      Ok := Offset >= Data'Length;
      if not Ok then
         Mismatch := Offset;
      end if;
   end Verify;

   procedure Leave (A : Address; Ok : out Boolean) is
      Data : Byte_Array (0 .. 5);
      Got  : Natural;
      Read : Boolean;
      pragma Warnings (GNATprove, Off, "is set by", Reason => "the bootloader starts the image after this read");
   begin
      Clear_Status (False, Ok);
      if Ok then
         Load_Address (A, Ok);
      end if;
      if Ok then
         DFU.Transport.Send (Download_Request, 0, Empty, Ok);
      end if;
      if Ok then
         DFU.Transport.Receive (Status_Request, 0, Data, Got, Read);
      end if;
   end Leave;

   procedure Read_Layout (M : out DFU.Layout.Memory; Transfer : out Transfer_Size; Ok : out Boolean) is
      Config   : Byte_Array (0 .. 1023);
      Raw      : Byte_Array (0 .. 254);
      Got      : Natural;
      Info     : DFU.Layout.Interface_Info;
      Language : Word := 16#0409#;
      Text     : String (1 .. DFU.Layout.Max_Text);
      Length   : Natural;
      Region   : DFU.Layout.Memory;
      Read     : Boolean;
   begin
      M := (others => <>);
      Transfer := Default_Transfer;
      DFU.Transport.Get_Descriptor (16#0200#, 0, Config, Got, Ok);
      if not Ok then
         return;
      end if;
      DFU.Layout.Parse_Configuration (Config (0 .. Got - 1), Info);
      if Info.Transfer_Size > 0 then
         Transfer := Transfer_Size (Info.Transfer_Size);
      end if;
      DFU.Transport.Get_Descriptor (16#0300#, 0, Raw, Got, Read);
      if Read and then Got >= 4 then
         Language := Word (Raw (2)) + 256 * Word (Raw (3));
      end if;
      Ok := False;
      for K in 1 .. Info.Alternates loop
         if Info.Strings (K) /= 0 then
            DFU.Transport.Get_Descriptor (16#0300# + Word (Info.Strings (K)), Language, Raw, Got, Read);
            if Read then
               DFU.Layout.Decode_String (Raw (0 .. Got - 1), Text, Length);
               DFU.Layout.Parse (Text (1 .. Length), Region, Read);
               if Read and then DFU.Layout.Is_Internal_Flash (Region) then
                  M := Region;
                  Ok := True;
                  return;
               end if;
            end if;
         end if;
      end loop;
   end Read_Layout;

end DFU.Session;
