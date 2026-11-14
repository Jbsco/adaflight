with Ada.Streams;
with GNAT.Sockets;
package body Adaflight.STM32.USB_Storage is
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.Sockets.Selector_Status;
   use type GNAT.Sockets.Socket_Type;
   use type Byte;

   --  The disk is a TCP server on port 5781, one client at a time. A message
   --  is a letter, a length in two bytes with the high one first, then that
   --  many bytes. A client sends O with a transfer for the out endpoint, C
   --  with an endpoint number for a cleared halt and R for a transport
   --  reset. The image sends D with a transfer from the in endpoint, H with
   --  an endpoint number for a halt, A with a length in two bytes when the
   --  out endpoint is ready for a transfer, and F for a flush. A client's
   --  connection configures the device and its end takes that away. A
   --  transfer for the out endpoint waits until the endpoint is ready.
   Disk_Port : constant GNAT.Sockets.Port_Type := 5_781;

   Server    : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
   Client    : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
   Listening : Boolean := False;
   Sent      : Boolean := False;
   Ready     : Boolean := False;

   --  A message held until its event can be given.
   Held        : Boolean := False;
   Held_Kind   : Character := ' ';
   Held_Bytes  : Byte_Array (0 .. 65_535) := (others => 0);
   Held_Length : Natural := 0;

   function Available return Boolean is (True);

   procedure Start (Product : String) is
      pragma Unreferenced (Product);
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
      Held := False;
      Sent := False;
      Ready := False;
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

   procedure Next (What : out Event; Data : in out Byte_Array; Count : out Natural) is
      Head : Byte_Array (0 .. 2);
      OK   : Boolean;
   begin
      What := Nothing;
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
               What := Started;
            end;
         end if;
         return;
      end if;
      if Sent then
         Sent := False;
         What := Packet_In;
         return;
      end if;
      if not Held then
         if not Readable (Client, 0.001) then
            return;
         end if;
         Get (Head, OK);
         if OK then
            Held_Kind := Character'Val (Head (0));
            Held_Length := Natural (Head (1)) * 256 + Natural (Head (2));
            Get (Held_Bytes (0 .. Held_Length - 1), OK);
         end if;
         if not OK then
            Drop;
            What := Stopped;
            return;
         end if;
         Held := True;
      end if;
      case Held_Kind is
         when 'O' =>
            if Ready then
               Ready := False;
               Held := False;
               Count := Natural'Min (Held_Length, Data'Length);
               Data (Data'First .. Data'First + Count - 1) := Held_Bytes (0 .. Count - 1);
               Count := Held_Length;
               What := Packet_Out;
            end if;
         when 'C' =>
            Held := False;
            What := (if Held_Length = 1 and then Held_Bytes (0) >= 16#80# then Cleared_In else Cleared_Out);
         when 'R' =>
            Held := False;
            What := Transport_Reset;
         when others =>
            Held := False;
      end case;
   exception
      when others =>
         Drop;
         What := Stopped;
   end Next;

   procedure Flush is
      None : constant Byte_Array (1 .. 0) := (others => 0);
   begin
      Put ('F', None);
   end Flush;

   procedure Halt_In is
   begin
      Put ('H', (0 => 16#81#));
   end Halt_In;

   procedure Halt_Out is
   begin
      Put ('H', (0 => 16#01#));
   end Halt_Out;

   procedure Send (Data : Byte_Array) is
   begin
      Put ('D', Data);
      Sent := True;
   end Send;

   procedure Receive (Length : Natural) is
   begin
      Ready := True;
      Put ('A', (0 => Byte (Length / 256 mod 256), 1 => Byte (Length mod 256)));
   end Receive;
end Adaflight.STM32.USB_Storage;
