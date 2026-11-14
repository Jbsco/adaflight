package body Adaflight.Mass_Storage.Engine with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Command_Signature : constant := 16#4342_5355#;

   --  A status wrapper's results.
   Passed : constant := 0;
   Failed : constant := 1;

   --  Sense keys.
   Not_Ready       : constant := 16#02#;
   Hardware_Error  : constant := 16#04#;
   Illegal_Request : constant := 16#05#;
   Data_Protect    : constant := 16#07#;

   --  Sense codes.
   Write_Fault        : constant := 16#03#;
   Read_Error         : constant := 16#11#;
   Invalid_Command    : constant := 16#20#;
   Out_Of_Range       : constant := 16#21#;
   Invalid_Field      : constant := 16#24#;
   Protected_Medium   : constant := 16#27#;
   Medium_Not_Present : constant := 16#3A#;

   --  Where a command wrapper's command block starts.
   Block_At : constant := 15;

   --  A little endian word of the command wrapper.
   function Word (S : Session; From : Natural) return Unsigned_32 is
     (Unsigned_32 (S.Command (From)) or Interfaces.Shift_Left (Unsigned_32 (S.Command (From + 1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (S.Command (From + 2)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (S.Command (From + 3)), 24))
     with Pre => From <= Command_Length - 4;

   function Transfer_Length (S : Session) return Unsigned_32 is (Word (S, 8));
   function Flags (S : Session) return Unsigned_8 is (S.Command (12));
   function To_Host (S : Session) return Boolean is ((Flags (S) and 16#80#) = 16#80#);

   --  A byte of the command block.
   function Parameter (S : Session; Index : Natural) return Unsigned_8 is (S.Command (Block_At + Index))
     with Pre => Index <= 15;

   --  The block address and block count of a read, write or verify.
   function Address (S : Session) return Unsigned_32 is
     (Interfaces.Shift_Left (Unsigned_32 (Parameter (S, 2)), 24)
      or Interfaces.Shift_Left (Unsigned_32 (Parameter (S, 3)), 16)
      or Interfaces.Shift_Left (Unsigned_32 (Parameter (S, 4)), 8) or Unsigned_32 (Parameter (S, 5)));

   function Count (S : Session) return Natural is (Natural (Parameter (S, 7)) * 256 + Natural (Parameter (S, 8)));

   function In_Range (S : Session) return Boolean is
     (Unsigned_64 (Address (S)) + Unsigned_64 (Count (S)) <= Unsigned_64 (S.Block_Count));

   --  A failure kept for a host's sense request. A list that fills drops
   --  its oldest one.
   procedure Keep_Sense (S : in out Session; Key : Unsigned_8; Code : Unsigned_8) is
   begin
      S.Senses (S.Tail) := (Key => Key, Code => Code);
      S.Tail := (S.Tail + 1) mod 4;
      if S.Tail = S.Head then
         S.Head := (S.Head + 1) mod 4;
      end if;
   end Keep_Sense;

   procedure Ask_For (S : in out Session; Next : in out Actions; Kind : Receive_Kind; Length : Natural) is
   begin
      Next.Receive := Kind;
      Next.Receive_Length := Length;
      S.Receiving := Kind;
      S.Receive_Length := Length;
   end Ask_For;

   --  The status wrapper goes out and the next command wrapper is asked for.
   procedure Send_Status (S : in out Session; Next : in out Actions; Result : Unsigned_8) is
   begin
      S.Result := Result;
      S.State := Idle;
      Next.Send := Status;
      Next.Send_Length := Status_Length;
      Ask_For (S, Next, Command, Command_Length);
   end Send_Status;

   --  A short reply goes out from the data buffer, cut to what a host asked for.
   procedure Send_Reply (S : in out Session; Next : in out Actions; Length : Natural) is
      Sent : constant Natural :=
        (if Transfer_Length (S) < Unsigned_32 (Length) then Natural (Transfer_Length (S)) else Length);
   begin
      S.Residue := S.Residue - Unsigned_32 (Sent);
      S.Result := Passed;
      S.State := Send_Data;
      Next.Send := Data;
      Next.Send_Length := Sent;
   end Send_Reply;

   --  A command that cannot go on: the endpoints a host still expects to use halt.
   procedure Give_Up (S : in out Session; Next : in out Actions) is
   begin
      if Flags (S) = 0 and then Transfer_Length (S) /= 0 and then S.Status = Normal then
         Next.Halt_Out := True;
      end if;
      Next.Halt_In := True;
      if S.Status = Error then
         Ask_For (S, Next, Command, Command_Length);
      end if;
   end Give_Up;

   --  A big endian word into the data buffer.
   procedure Put_Word (Data : in out Data_Buffer; From : Natural; Value : Unsigned_32)
     with Pre => From <= 8
   is
   begin
      Data (From) := Unsigned_8 (Interfaces.Shift_Right (Value, 24));
      Data (From + 1) := Unsigned_8 (Interfaces.Shift_Right (Value, 16) and 16#FF#);
      Data (From + 2) := Unsigned_8 (Interfaces.Shift_Right (Value, 8) and 16#FF#);
      Data (From + 3) := Unsigned_8 (Value and 16#FF#);
   end Put_Word;

   --  The first bytes of a packet into the start of a buffer.
   procedure Take (Target : in out Adaflight.Bytes.Byte_Array; Packet : Adaflight.Bytes.Byte_Array; Count : Natural)
     with Pre => Target'First = 0 and then Count <= Target'Length and then Count <= Packet'Length
   is
   begin
      for I in 0 .. Count - 1 loop
         Target (I) := Packet (Packet'First + I);
      end loop;
   end Take;

   procedure Test_Unit_Ready (S : in out Session; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      OK : Boolean;
   begin
      Refused := True;
      if Transfer_Length (S) /= 0 then
         Keep_Sense (S, Illegal_Request, Invalid_Command);
         return;
      end if;
      Ready (OK);
      if not OK then
         Keep_Sense (S, Not_Ready, Medium_Not_Present);
         return;
      end if;
      Refused := False;
   end Test_Unit_Ready;

   procedure Request_Sense (S : in out Session)
     with Post => S.Status = S.Status'Old
   is
   begin
      S.Data (0 .. 17) := (others => 0);
      S.Data (0) := 16#70#;
      S.Data (7) := 12;
      if S.Head /= S.Tail then
         S.Data (2) := S.Senses (S.Head).Key;
         S.Data (12) := S.Senses (S.Head).Code;
         S.Head := (S.Head + 1) mod 4;
      end if;
      S.Reply := (if Parameter (S, 4) <= 18 then Natural (Parameter (S, 4)) else 18);
   end Request_Sense;

   procedure Inquire (S : in out Session)
     with Post => S.Status = S.Status'Old
   is
      Pages : constant Adaflight.Bytes.Byte_Array (0 .. 6) := (0, 0, 0, 3, 0, 16#80#, 16#83#);
   begin
      if (Parameter (S, 1) and 1) /= 0 then
         S.Data (0 .. 6) := Pages;
         S.Reply := 7;
      else
         S.Reply := (if Parameter (S, 4) <= Inquiry_Length then Natural (Parameter (S, 4)) else Inquiry_Length);
         Take (S.Data, Inquiry, S.Reply);
      end if;
   end Inquire;

   --  A mode reply of eight bytes whose byte at Flag has its top bit set
   --  for a storage that takes no writes.
   procedure Mode_Sense (S : in out Session; Flag : Natural)
     with Pre => Flag <= 7, Post => S.Status = S.Status'Old
   is
      Yes : Boolean;
   begin
      S.Data (0 .. 7) := (others => 0);
      Write_Protected (Yes);
      if Yes then
         S.Data (Flag) := 16#80#;
      end if;
      S.Reply := 8;
   end Mode_Sense;

   procedure Read_Format_Capacities (S : in out Session; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      Blocks : Unsigned_32;
      OK     : Boolean;
   begin
      S.Data (0 .. 11) := (others => 0);
      Capacity (Blocks, OK);
      Refused := not OK;
      if not OK then
         Keep_Sense (S, Not_Ready, Medium_Not_Present);
         return;
      end if;
      S.Data (3) := 8;
      Put_Word (S.Data, 4, Blocks - 1);
      S.Data (8) := 2;
      S.Data (10) := 2;
      S.Reply := 12;
   end Read_Format_Capacities;

   procedure Read_Capacity (S : in out Session; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      Blocks : Unsigned_32;
      OK     : Boolean;
   begin
      Capacity (Blocks, OK);
      Refused := not OK;
      if not OK then
         Keep_Sense (S, Not_Ready, Medium_Not_Present);
         return;
      end if;
      S.Block_Count := Blocks;
      Put_Word (S.Data, 0, Blocks - 1);
      Put_Word (S.Data, 4, Block_Size);
      S.Reply := 8;
   end Read_Capacity;

   --  The next blocks of a read go out.
   procedure Read_Next (S : in out Session; Next : in out Actions; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      Left   : constant Natural := S.Blocks_Left;
      Blocks : constant Natural := Natural'Min (Left, Buffer_Blocks);
      OK     : Boolean;
   begin
      Read_Blocks (S.Block, Blocks, S.Data, OK);
      Refused := not OK;
      if not OK then
         Keep_Sense (S, Hardware_Error, Read_Error);
         return;
      end if;
      Next.Send := Data;
      Next.Send_Length := Blocks * Block_Size;
      S.Block := S.Block + Unsigned_32 (Blocks);
      S.Blocks_Left := Left - Blocks;
      S.Residue := S.Residue - Unsigned_32 (Blocks * Block_Size);
      if Left = Blocks then
         S.State := Last_Data_In;
      end if;
   end Read_Next;

   --  The blocks that arrived are written, then more are asked for or the
   --  status goes out.
   procedure Write_Next (S : in out Session; Next : in out Actions; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      Left   : constant Natural := S.Blocks_Left;
      Blocks : constant Natural := Natural'Min (Left, Buffer_Blocks);
      OK     : Boolean;
   begin
      Write_Blocks (S.Block, Blocks, S.Data, OK);
      Refused := not OK;
      if not OK then
         Keep_Sense (S, Hardware_Error, Write_Fault);
         return;
      end if;
      S.Block := S.Block + Unsigned_32 (Blocks);
      S.Blocks_Left := Left - Blocks;
      S.Residue := S.Residue - Unsigned_32 (Blocks * Block_Size);
      if Left = Blocks then
         Send_Status (S, Next, Passed);
      else
         Ask_For (S, Next, Data, Natural'Min (Left - Blocks, Buffer_Blocks) * Block_Size);
      end if;
   end Write_Next;

   procedure Read (S : in out Session; Next : in out Actions; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      OK : Boolean;
   begin
      Refused := True;
      if S.State = Idle then
         if not To_Host (S) then
            Keep_Sense (S, Illegal_Request, Invalid_Command);
            return;
         end if;
         Ready (OK);
         if not OK then
            Keep_Sense (S, Not_Ready, Medium_Not_Present);
            return;
         end if;
         S.Block := Address (S);
         S.Blocks_Left := Count (S);
         if not In_Range (S) then
            Keep_Sense (S, Illegal_Request, Out_Of_Range);
            return;
         end if;
         S.State := Data_In;
         if Transfer_Length (S) /= Unsigned_32 (Count (S)) * Block_Size then
            Keep_Sense (S, Illegal_Request, Invalid_Command);
            return;
         end if;
      end if;
      Read_Next (S, Next, Refused);
   end Read;

   procedure Write (S : in out Session; Next : in out Actions; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
      OK  : Boolean;
      Yes : Boolean;
   begin
      Refused := True;
      if S.State /= Idle then
         Write_Next (S, Next, Refused);
         return;
      end if;
      if To_Host (S) then
         Keep_Sense (S, Illegal_Request, Invalid_Command);
         return;
      end if;
      Ready (OK);
      if not OK then
         Keep_Sense (S, Not_Ready, Medium_Not_Present);
         return;
      end if;
      Write_Protected (Yes);
      if Yes then
         Keep_Sense (S, Data_Protect, Protected_Medium);
         return;
      end if;
      S.Block := Address (S);
      S.Blocks_Left := Count (S);
      if not In_Range (S) then
         Keep_Sense (S, Illegal_Request, Out_Of_Range);
         return;
      end if;
      if Transfer_Length (S) /= Unsigned_32 (Count (S)) * Block_Size then
         Keep_Sense (S, Illegal_Request, Invalid_Command);
         return;
      end if;
      Refused := False;
      if Count (S) /= 0 then
         S.State := Data_Out;
         Ask_For (S, Next, Data, Natural'Min (Count (S), Buffer_Blocks) * Block_Size);
      end if;
   end Write;

   procedure Verify (S : in out Session; Refused : out Boolean)
     with Post => S.Status = S.Status'Old
   is
   begin
      Refused := True;
      if (Parameter (S, 1) and 2) = 2 then
         Keep_Sense (S, Illegal_Request, Invalid_Field);
         return;
      end if;
      S.Block := Address (S);
      S.Blocks_Left := Count (S);
      if not In_Range (S) then
         Keep_Sense (S, Illegal_Request, Out_Of_Range);
         return;
      end if;
      Refused := False;
   end Verify;

   --  The stored command runs or goes on.
   procedure Run_Command (S : in out Session; Next : in out Actions; Refused : out Boolean) is
   begin
      S.Reply := 0;
      Refused := False;
      case Parameter (S, 0) is
         when 16#00# =>
            Test_Unit_Ready (S, Refused);
         when 16#03# =>
            Request_Sense (S);
         when 16#12# =>
            Inquire (S);
         when 16#1B# | 16#1E# =>
            null;
         when 16#1A# =>
            Mode_Sense (S, Flag => 2);
         when 16#5A# =>
            Mode_Sense (S, Flag => 3);
            S.Data (1) := 6;
         when 16#23# =>
            Read_Format_Capacities (S, Refused);
         when 16#25# =>
            Read_Capacity (S, Refused);
         when 16#28# =>
            Read (S, Next, Refused);
         when 16#2A# =>
            Write (S, Next, Refused);
         when 16#2F# =>
            Verify (S, Refused);
         when others =>
            Keep_Sense (S, Illegal_Request, Invalid_Command);
            Refused := True;
      end case;
   end Run_Command;

   --  A command wrapper arrived with a count of bytes.
   procedure Decode (S : in out Session; Received : Natural; Next : in out Actions) is
      Refused : Boolean;
   begin
      if S.Status = Recovery then
         S.Status := Normal;
      end if;
      S.Tag := Word (S, 4);
      S.Residue := Transfer_Length (S);
      if Received /= Command_Length or else Word (S, 0) /= Command_Signature or else S.Command (13) /= 0
        or else S.Command (14) not in 1 .. 16
      then
         Keep_Sense (S, Illegal_Request, Invalid_Command);
         S.Status := Error;
         Give_Up (S, Next);
         return;
      end if;
      Run_Command (S, Next, Refused);
      if Refused then
         Give_Up (S, Next);
      elsif S.State not in Data_In | Data_Out | Last_Data_In then
         if S.Reply > 0 then
            Send_Reply (S, Next, S.Reply);
         else
            Send_Status (S, Next, Passed);
         end if;
      end if;
   end Decode;

   procedure Start (S : in out Session; Next : out Actions) is
   begin
      Next := (others => <>);
      S.State := Idle;
      S.Status := Normal;
      Start_Storage;
      Next.Flush := True;
      Ask_For (S, Next, Command, Command_Length);
   end Start;

   procedure Reset (S : in out Session; Next : out Actions) is
   begin
      Next := (others => <>);
      S.State := Idle;
      S.Status := Recovery;
      Ask_For (S, Next, Command, Command_Length);
   end Reset;

   procedure Stop (S : in out Session) is
   begin
      S.State := Idle;
   end Stop;

   procedure Packet_Out (S : in out Session; Packet : Adaflight.Bytes.Byte_Array; Next : out Actions) is
      Length  : constant Natural := Packet'Length;
      Asked   : constant Natural := S.Receive_Length;
      Taken   : constant Natural := (if Length < Asked then Length else Asked);
      Refused : Boolean;
   begin
      Next := (others => <>);
      if S.Receiving = Command then
         Take (S.Command, Packet, (if Taken < Command_Length then Taken else Command_Length));
      else
         Take (S.Data, Packet, (if Taken < Buffer_Size then Taken else Buffer_Size));
      end if;
      S.Receiving := Nothing;
      case S.State is
         when Idle =>
            Decode (S, Packet'Length, Next);
         when Data_Out =>
            Run_Command (S, Next, Refused);
            if Refused then
               Send_Status (S, Next, Failed);
            end if;
         when others =>
            null;
      end case;
   end Packet_Out;

   procedure Packet_In (S : in out Session; Next : out Actions) is
      Refused : Boolean;
   begin
      Next := (others => <>);
      case S.State is
         when Data_In =>
            Run_Command (S, Next, Refused);
            if Refused then
               Send_Status (S, Next, Failed);
            end if;
         when Send_Data | Last_Data_In =>
            Send_Status (S, Next, Passed);
         when others =>
            null;
      end case;
   end Packet_In;

   procedure Halt_Cleared (S : in out Session; In_Endpoint : Boolean; Next : out Actions) is
   begin
      Next := (others => <>);
      if S.Status = Error then
         Next.Halt_In := True;
         S.Status := Normal;
      elsif In_Endpoint and then S.Status /= Recovery then
         Send_Status (S, Next, Failed);
      end if;
   end Halt_Cleared;

   function Status_Wrapper (S : Session) return Status_Bytes is
      function Byte (Value : Unsigned_32; Shift : Natural) return Unsigned_8 is
        (Unsigned_8 (Interfaces.Shift_Right (Value, Shift) and 16#FF#));
   begin
      return
        (16#55#, 16#53#, 16#42#, 16#53#, Byte (S.Tag, 0), Byte (S.Tag, 8), Byte (S.Tag, 16), Byte (S.Tag, 24),
         Byte (S.Residue, 0), Byte (S.Residue, 8), Byte (S.Residue, 16), Byte (S.Residue, 24), S.Result);
   end Status_Wrapper;

end Adaflight.Mass_Storage.Engine;
