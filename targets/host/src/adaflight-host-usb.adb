with Ada.Streams;
with GNAT.Sockets;
package body Adaflight.STM32.USB is
   use type Ada.Streams.Stream_Element_Offset;

   --  The virtual serial port is a TCP server on port 5780, the port's
   --  identifier 20 past 5760, one client at a time; a connected client is a
   --  configured port with DTR set, and each connect or disconnect counts as
   --  a control line request.
   VCP_Port : constant GNAT.Sockets.Port_Type := 5_780;

   Ring_Size : constant := 4_096;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   protected Line is
      procedure Push (Data : Byte_Array);
      procedure Take (Into : out Byte_Array; Count : out Natural);
      procedure Connect (Client : GNAT.Sockets.Socket_Type);
      procedure Disconnect;
      function Client return GNAT.Sockets.Socket_Type;
      function Connected return Boolean;
      function Changes return Interfaces.Unsigned_32;
   private
      Bytes   : Byte_Array (Ring_Index) := (others => 0);
      Head    : Ring_Index := 0;
      Fill    : Natural range 0 .. Ring_Size := 0;
      Socket  : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Present : Boolean := False;
      Changed : Interfaces.Unsigned_32 := 0;
   end Line;

   protected body Line is
      procedure Push (Data : Byte_Array) is
      begin
         for B of Data loop
            exit when Fill = Ring_Size;
            Bytes ((Head + Fill) mod Ring_Size) := B;
            Fill := Fill + 1;
         end loop;
      end Push;

      procedure Take (Into : out Byte_Array; Count : out Natural) is
      begin
         Count := Natural'Min (Into'Length, Fill);
         Into := (others => 0);
         for K in 0 .. Count - 1 loop
            Into (Into'First + K) := Bytes ((Head + K) mod Ring_Size);
         end loop;
         Head := (Head + Count) mod Ring_Size;
         Fill := Fill - Count;
      end Take;

      procedure Connect (Client : GNAT.Sockets.Socket_Type) is
      begin
         Socket := Client;
         Present := True;
         Changed := Interfaces."+" (Changed, 1);
      end Connect;

      procedure Disconnect is
      begin
         Present := False;
         Socket := GNAT.Sockets.No_Socket;
         Changed := Interfaces."+" (Changed, 1);
      end Disconnect;

      function Client return GNAT.Sockets.Socket_Type is (Socket);

      function Connected return Boolean is (Present);

      function Changes return Interfaces.Unsigned_32 is (Changed);
   end Line;

   task Listener is
      entry Start;
   end Listener;

   task body Listener is
      use GNAT.Sockets;
      Server  : Socket_Type;
      Client  : Socket_Type;
      Address : Sock_Addr_Type;
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      accept Start;
      Create_Socket (Server);
      Set_Socket_Option (Server, Socket_Level, (Reuse_Address, True));
      Bind_Socket (Server, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => VCP_Port));
      Listen_Socket (Server);
      loop
         Accept_Socket (Server, Client, Address);
         Line.Connect (Client);
         loop
            begin
               Receive_Socket (Client, Buffer, Last);
            exception
               when Socket_Error =>
                  Last := 0;
            end;
            exit when Last < Buffer'First;
            declare
               Data : Byte_Array (0 .. Natural (Last - Buffer'First));
            begin
               for I in Data'Range loop
                  Data (I) := Byte (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I)));
               end loop;
               Line.Push (Data);
            end;
         end loop;
         Line.Disconnect;
         Close_Socket (Client);
      end loop;
   end Listener;

   procedure Init (Product : String) is
      pragma Unreferenced (Product);
   begin
      Listener.Start;
   end Init;

   function Configured return Boolean is (Line.Connected);

   function Line_Rate return Interfaces.Unsigned_32 is (0);

   procedure Control_Line (State : out Interfaces.Unsigned_16; Count : out Interfaces.Unsigned_32) is
   begin
      State := (if Line.Connected then 1 else 0);
      Count := Line.Changes;
   end Control_Line;

   procedure Send (Data : Byte_Array; Accepted : out Natural) is
      use Ada.Streams;
      Buffer : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Last   : Stream_Element_Offset;
   begin
      Accepted := Data'Length;
      if not Line.Connected or else Data'Length = 0 then
         return;
      end if;
      for I in Buffer'Range loop
         Buffer (I) := Stream_Element (Data (Data'First + Natural (I) - 1));
      end loop;
      GNAT.Sockets.Send_Socket (Line.Client, Buffer, Last);
   exception
      when GNAT.Sockets.Socket_Error =>
         null;
   end Send;

   procedure Take (Into : out Byte_Array; Count : out Natural) is
   begin
      Line.Take (Into, Count);
   end Take;
end Adaflight.STM32.USB;
