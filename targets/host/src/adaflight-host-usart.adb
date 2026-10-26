with Ada.Streams;
with GNAT.Sockets;
with Adaflight.STM32.Time;
package body Adaflight.STM32.USART is
   use type GNAT.Sockets.Socket_Type;
   use type Ada.Streams.Stream_Element_Offset;

   --  Each UART is a TCP server on port 5760 plus its number, one client at
   --  a time.
   Port_Of : constant array (Number) of GNAT.Sockets.Port_Type :=
     (UART1 => 5_761, UART3 => 5_763, UART4 => 5_764, UART6 => 5_766);

   Ring_Size : constant := 4_096;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   --  A UART's received bytes with their times, and its client.
   protected type Line is
      procedure Push (Data : Byte_Array);
      procedure Take (Into : out Byte_Array; Times : out Time_Array; Count : out Natural);
      procedure Connect (Client : GNAT.Sockets.Socket_Type);
      procedure Disconnect;
      function Client return GNAT.Sockets.Socket_Type;
      function Connected return Boolean;
   private
      Bytes   : Byte_Array (Ring_Index) := (others => 0);
      Stamps  : Time_Array (Ring_Index) := (others => 0);
      Head    : Ring_Index := 0;
      Fill    : Natural range 0 .. Ring_Size := 0;
      Socket  : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Present : Boolean := False;
   end Line;

   protected body Line is
      procedure Push (Data : Byte_Array) is
         Now : constant Interfaces.Unsigned_32 := Adaflight.STM32.Time.Micros;
      begin
         for B of Data loop
            exit when Fill = Ring_Size;
            Bytes ((Head + Fill) mod Ring_Size) := B;
            Stamps ((Head + Fill) mod Ring_Size) := Now;
            Fill := Fill + 1;
         end loop;
      end Push;

      procedure Take (Into : out Byte_Array; Times : out Time_Array; Count : out Natural) is
      begin
         Count := Natural'Min (Into'Length, Fill);
         Into := (others => 0);
         Times := (others => 0);
         for K in 0 .. Count - 1 loop
            Into (Into'First + K) := Bytes ((Head + K) mod Ring_Size);
            Times (Times'First + K) := Stamps ((Head + K) mod Ring_Size);
         end loop;
         Head := (Head + Count) mod Ring_Size;
         Fill := Fill - Count;
      end Take;

      procedure Connect (Client : GNAT.Sockets.Socket_Type) is
      begin
         Socket := Client;
         Present := True;
      end Connect;

      procedure Disconnect is
      begin
         Present := False;
         Socket := GNAT.Sockets.No_Socket;
      end Disconnect;

      function Client return GNAT.Sockets.Socket_Type is (Socket);

      function Connected return Boolean is (Present);
   end Line;

   Lines : array (Number) of Line;

   task type Listener is
      entry Start (N : Number);
   end Listener;

   task body Listener is
      use GNAT.Sockets;
      Which   : Number;
      Server  : Socket_Type;
      Client  : Socket_Type;
      Address : Sock_Addr_Type;
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      accept Start (N : Number) do
         Which := N;
      end Start;
      Create_Socket (Server);
      Set_Socket_Option (Server, Socket_Level, (Reuse_Address, True));
      Bind_Socket (Server, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => Port_Of (Which)));
      Listen_Socket (Server);
      loop
         Accept_Socket (Server, Client, Address);
         Lines (Which).Connect (Client);
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
               Lines (Which).Push (Data);
            end;
         end loop;
         Lines (Which).Disconnect;
         Close_Socket (Client);
      end loop;
   end Listener;

   Listeners : array (Number) of Listener;
   Started   : array (Number) of Boolean := (others => False);

   procedure Init (N : Number; Baud : Positive) is
      pragma Unreferenced (Baud);
   begin
      if not Started (N) then
         Started (N) := True;
         Listeners (N).Start (N);
      end if;
   end Init;

   procedure Send (N : Number; Data : Byte_Array) is
      use Ada.Streams;
      Buffer : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Last   : Stream_Element_Offset;
   begin
      if not Lines (N).Connected or else Data'Length = 0 then
         return;
      end if;
      for I in Buffer'Range loop
         Buffer (I) := Stream_Element (Data (Data'First + Natural (I) - 1));
      end loop;
      GNAT.Sockets.Send_Socket (Lines (N).Client, Buffer, Last);
   exception
      when GNAT.Sockets.Socket_Error =>
         null;
   end Send;

   procedure Put (Into : in out Port; Text : String) is
      Data : Byte_Array (0 .. Text'Length - 1);
   begin
      for I in Data'Range loop
         Data (I) := Byte (Character'Pos (Text (Text'First + I)));
      end loop;
      Send (Into.Which, Data);
   end Put;

   procedure Put (Into : in out Port; Data : Byte_Array) is
   begin
      Send (Into.Which, Data);
   end Put;

   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural) is
      Times : Time_Array (0 .. Into'Length - 1);
   begin
      Lines (N).Take (Into, Times, Count);
   end Take;

   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural) is
   begin
      Lines (N).Take (Into, Times, Count);
   end Take;
end Adaflight.STM32.USART;
