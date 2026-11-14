with Ada.Streams;
with GNAT.Sockets;
package body Adaflight.STM32.USB_Storage is
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.Sockets.Selector_Status;
   use type GNAT.Sockets.Socket_Type;

   package U renames Adaflight.USB_Device;

   --  The controller is a TCP server on port 5781, one client at a time,
   --  which plays a host and the bus. A message is a letter, a length in two
   --  bytes with the high one first, then that many bytes. A client sends B
   --  for a bus reset, S with a setup packet, O with an endpoint number and
   --  a packet for it, I with an endpoint number whose transmission ended, U
   --  for a suspend and W for a resume. The image answers each of these with
   --  X once per endpoint operation, with its kind, its address, its length
   --  in two bytes, its endpoint type, its count and that many bytes, and
   --  then E. A client's end is a suspend.
   Disk_Port : constant GNAT.Sockets.Port_Type := 5_781;

   Server    : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
   Client    : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
   Listening : Boolean := False;

   function Available return Boolean is (True);

   procedure Start is
      Address : GNAT.Sockets.Sock_Addr_Type;
   begin
      Address.Addr := GNAT.Sockets.Inet_Addr ("127.0.0.1");
      Address.Port := Disk_Port;
      GNAT.Sockets.Create_Socket (Server);
      GNAT.Sockets.Set_Socket_Option (Server, GNAT.Sockets.Socket_Level, (GNAT.Sockets.Reuse_Address, True));
      GNAT.Sockets.Bind_Socket (Server, Address);
      GNAT.Sockets.Listen_Socket (Server, 1);
      Listening := True;
   exception
      when others =>
         Listening := False;
   end Start;

   --  Whether a socket has something to read within a wait.
   function Readable (Socket : GNAT.Sockets.Socket_Type; Wait : Duration) return Boolean is
      Read_Set  : GNAT.Sockets.Socket_Set_Type;
      Write_Set : GNAT.Sockets.Socket_Set_Type;
      Selector  : GNAT.Sockets.Selector_Type;
      Status    : GNAT.Sockets.Selector_Status;
   begin
      GNAT.Sockets.Create_Selector (Selector);
      GNAT.Sockets.Set (Read_Set, Socket);
      GNAT.Sockets.Check_Selector (Selector, Read_Set, Write_Set, Status, Wait);
      GNAT.Sockets.Close_Selector (Selector);
      return Status = GNAT.Sockets.Completed;
   end Readable;

   procedure Drop is
   begin
      GNAT.Sockets.Close_Socket (Client);
      Client := GNAT.Sockets.No_Socket;
   exception
      when others =>
         Client := GNAT.Sockets.No_Socket;
   end Drop;

   --  Exactly Into'Length bytes from the client, or a closed connection.
   procedure Get (Into : out Byte_Array; OK : out Boolean) is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Into'Length));
      Last   : Ada.Streams.Stream_Element_Offset;
      Have   : Ada.Streams.Stream_Element_Offset := 0;
   begin
      Into := (others => 0);
      OK := True;
      while Have < Buffer'Last loop
         GNAT.Sockets.Receive_Socket (Client, Buffer (Have + 1 .. Buffer'Last), Last);
         if Last <= Have then
            OK := False;
            return;
         end if;
         Have := Last;
      end loop;
      for I in Buffer'Range loop
         Into (Into'First + Natural (I - 1)) := Byte (Buffer (I));
      end loop;
   exception
      when others =>
         OK := False;
   end Get;

   procedure Put (Kind : Character; Data : Byte_Array) is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length + 3));
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      if Client = GNAT.Sockets.No_Socket then
         return;
      end if;
      Buffer (1) := Character'Pos (Kind);
      Buffer (2) := Ada.Streams.Stream_Element (Data'Length / 256);
      Buffer (3) := Ada.Streams.Stream_Element (Data'Length mod 256);
      for I in 0 .. Data'Length - 1 loop
         Buffer (Ada.Streams.Stream_Element_Offset (I + 4)) := Ada.Streams.Stream_Element (Data (Data'First + I));
      end loop;
      GNAT.Sockets.Send_Socket (Client, Buffer, Last);
   exception
      when others =>
         null;
   end Put;

   procedure Next
     (What : out Event; EP : out U.Endpoint_Number; Data : in out Byte_Array; Count : out Natural)
   is
      Head    : Byte_Array (0 .. 2);
      Payload : Byte_Array (0 .. 255);
      Length  : Natural;
      OK      : Boolean;
   begin
      What := Nothing;
      EP := 0;
      Count := 0;
      if not Listening then
         delay 0.01;
         return;
      end if;
      if Client = GNAT.Sockets.No_Socket then
         if Readable (Server, 0.01) then
            declare
               From : GNAT.Sockets.Sock_Addr_Type;
            begin
               GNAT.Sockets.Accept_Socket (Server, Client, From);
               GNAT.Sockets.Set_Socket_Option
                 (Client, GNAT.Sockets.IP_Protocol_For_TCP_Level, (GNAT.Sockets.No_Delay, True));
            end;
         end if;
         return;
      end if;
      if not Readable (Client, 0.001) then
         return;
      end if;
      Get (Head, OK);
      Length := Natural (Head (1)) * 256 + Natural (Head (2));
      if OK and then Length <= Payload'Length then
         Get (Payload (0 .. Length - 1), OK);
      else
         OK := False;
      end if;
      if not OK then
         Drop;
         What := Suspend;
         return;
      end if;
      case Character'Val (Head (0)) is
         when 'B' =>
            What := Bus_Reset;
         when 'S' =>
            if Length = 8 then
               What := Setup;
               Count := 8;
               Data (Data'First .. Data'First + 7) := Payload (0 .. 7);
            end if;
         when 'O' =>
            if Length in 1 .. U.Packet_Size + 1 and then Natural (Payload (0)) < U.Endpoint_Count then
               What := Packet_Out;
               EP := Natural (Payload (0));
               Count := Length - 1;
               Data (Data'First .. Data'First + Count - 1) := Payload (1 .. Count);
            end if;
         when 'I' =>
            if Length = 1 and then Natural (Payload (0)) < U.Endpoint_Count then
               What := Packet_In;
               EP := Natural (Payload (0));
            end if;
         when 'U' =>
            What := Suspend;
         when 'W' =>
            What := Resume;
         when others =>
            null;
      end case;
      if What = Nothing then
         Put ('E', Payload (1 .. 0));
      end if;
   exception
      when others =>
         Drop;
         What := Suspend;
   end Next;

   procedure Execute (A : U.Actions) is
      None : constant Byte_Array (1 .. 0) := (others => 0);
   begin
      for K in 1 .. A.Count loop
         declare
            X       : U.Action renames A.List (K);
            Message : Byte_Array (0 .. 5 + X.Count);
         begin
            Message (0) := Byte (U.Action_Kind'Pos (X.Kind));
            Message (1) := X.Address;
            Message (2) := Byte (X.Length / 256);
            Message (3) := Byte (X.Length mod 256);
            Message (4) := Byte (U.Endpoint_Kind'Pos (X.EP_Kind));
            Message (5) := Byte (X.Count);
            Message (6 .. 5 + X.Count) := X.Data (0 .. X.Count - 1);
            Put ('X', Message (0 .. 5 + X.Count));
         end;
      end loop;
      Put ('E', None);
   end Execute;
end Adaflight.STM32.USB_Storage;
