--  The host's software serial ports: each port's line is a TCP server on
--  port 5767 or 5768, one client at a time. A byte from the client becomes
--  the edges and bit clock ticks its frame makes on the receive pin, and the
--  levels the engine writes to the send pin are put back into bytes for the
--  client. The pins take their timer channels as on a board. The line has
--  no rate: a call that queues, takes or asks for room first runs the
--  frames that wait.
with Ada.Streams;
with GNAT.Sockets;
with Adaflight.Soft_Serial;
with Adaflight.STM32.Soft_Serial_Logic;
package body Adaflight.STM32.Soft_Serial is
   use Interfaces;
   use type GNAT.Sockets.Socket_Type;
   use type Ada.Streams.Stream_Element_Offset;
   package Engine renames Adaflight.Soft_Serial;
   use type Engine.Tx_Effect;
   use type Engine.Timer_Mode;

   Port_Of : constant array (Port_Number) of GNAT.Sockets.Port_Type := (5_767, 5_768);

   Ring_Size : constant := 4_096;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   --  A line's bytes from its client, and the client.
   protected type Line is
      procedure Push (Data : Byte_Array);
      procedure Pop (B : out Byte; Got : out Boolean);
      procedure Connect (Client : GNAT.Sockets.Socket_Type);
      procedure Disconnect;
      function Client return GNAT.Sockets.Socket_Type;
      function Connected return Boolean;
   private
      Bytes   : Byte_Array (Ring_Index) := (others => 0);
      Head    : Ring_Index := 0;
      Fill    : Natural range 0 .. Ring_Size := 0;
      Socket  : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Present : Boolean := False;
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

      procedure Pop (B : out Byte; Got : out Boolean) is
      begin
         B := 0;
         Got := Fill > 0;
         if Got then
            B := Bytes (Head);
            Head := (Head + 1) mod Ring_Size;
            Fill := Fill - 1;
         end if;
      end Pop;

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

   Lines : array (Port_Number) of Line;

   task type Listener is
      entry Start (N : Port_Number);
   end Listener;

   task body Listener is
      use GNAT.Sockets;
      Which   : Port_Number;
      Server  : Socket_Type;
      Client  : Socket_Type;
      Address : Sock_Addr_Type;
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      accept Start (N : Port_Number) do
         Which := N;
      end Start;
      Create_Socket (Server);
      Set_Socket_Option (Server, Socket_Level, (Reuse_Address, True));
      Bind_Socket (Server, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => Port_Of (Which)));
      Listen_Socket (Server);
      loop
         Accept_Socket (Server, Client, Address);
         Set_Socket_Option (Client, IP_Protocol_For_TCP_Level, (No_Delay, True));
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

   Listeners : array (Port_Number) of Listener;
   Listening : array (Port_Number) of Boolean := (others => False);

   procedure Send (N : Port_Number; B : Byte) is
      use Ada.Streams;
      Buffer : constant Stream_Element_Array (1 .. 1) := (1 => Stream_Element (B));
      Last   : Stream_Element_Offset;
   begin
      if Lines (N).Connected then
         GNAT.Sockets.Send_Socket (Lines (N).Client, Buffer, Last);
      end if;
   exception
      when GNAT.Sockets.Socket_Error =>
         null;
   end Send;

   Inverted_Line : array (Port_Number) of Boolean := (others => False);

   --  The send pin's levels put back into bytes: a low level while idle is
   --  a start bit, the eight levels after it the byte from its low bit, and
   --  the level after those the stop bit.
   type Receiver is record
      Bits  : Natural range 0 .. 9 := 0;
      Value : Interfaces.Unsigned_16 := 0;
   end record;
   Sent : array (Port_Number) of Receiver;

   procedure Send_Effect (N : Positive; E : Engine.Tx_Effect) is
      High : Boolean;
   begin
      if E not in Engine.Level_Low | Engine.Level_High then
         return;
      end if;
      High := (E = Engine.Level_High) /= Inverted_Line (N);
      if Sent (N).Bits = 0 then
         if not High then
            Sent (N) := (Bits => 1, Value => 0);
         end if;
      elsif Sent (N).Bits < 9 then
         if High then
            Sent (N).Value := Sent (N).Value or Shift_Left (1, Sent (N).Bits - 1);
         end if;
         Sent (N).Bits := Sent (N).Bits + 1;
      else
         if High then
            Send (N, Byte (Sent (N).Value and 16#FF#));
         end if;
         Sent (N) := (others => <>);
      end if;
   end Send_Effect;

   procedure Rearm (N : Positive; Rising : Boolean) is null;

   procedure After_Edge (N : Positive; Centre : Boolean; Rising : Boolean) is null;

   package Logic is new Adaflight.STM32.Soft_Serial_Logic
     (Send_Effect => Send_Effect, Rearm => Rearm, After_Edge => After_Edge);

   --  The receive line's level, high while idle.
   Level : array (Port_Number) of Boolean := (others => True);

   --  The frames that wait run: the queued bytes clocked out with the tick
   --  that turns a half duplex pin back, then each byte from the client as
   --  its start bit, its eight bits from the low one and its stop bit, an
   --  edge where the level changes and a tick in each bit.
   procedure Poll (N : Port_Number) is
      Sending : constant Logic.Timer :=
        (if Logic.Timing (N) = Engine.Dual then Logic.Second else Logic.Main);
      B       : Byte;
      Got     : Boolean;
      High    : Boolean;
   begin
      if not Logic.Is_Open (N) then
         return;
      end if;
      for Guard in 1 .. 16 * Engine.Buffer_Size loop
         exit when Logic.Transmit_Empty (N);
         Logic.Tick (N, Sending);
      end loop;
      Logic.Tick (N, Sending);
      loop
         exit when Logic.Waiting (N) >= Engine.Buffer_Size - 2;
         Lines (N).Pop (B, Got);
         exit when not Got;
         for Bit in 0 .. Engine.Total_Bits - 1 loop
            High := (if Bit = 0 then False elsif Bit = 9 then True else (Shift_Right (B, Bit - 1) and 1) /= 0);
            if High /= Level (N) then
               Level (N) := High;
               Logic.Edge (N);
            end if;
            Logic.Tick (N, Logic.Main);
         end loop;
      end loop;
   end Poll;

   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean) is
   begin
      Logic.Configure (C, Feature_On);
   end Configure;

   function Present (N : Port_Number) return Boolean is (Logic.Present (N));

   function TX_Tag (N : Port_Number) return Unsigned_8 is (Logic.TX_Tag (N));
   function RX_Tag (N : Port_Number) return Unsigned_8 is (Logic.RX_Tag (N));

   procedure Open
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; Opened : out Boolean)
   is
      Unused : Logic.Channels;
      Plan   : Engine.Open_Plan;
   begin
      if Logic.Is_Open (N) then
         Opened := True;
         return;
      end if;
      Logic.Open_On (N, Baud, Half_Duplex, Inverted, Resistor, Unused, Plan);
      Opened := Plan.Opened;
      if Opened then
         Inverted_Line (N) := Inverted;
         Sent (N) := (others => <>);
         Level (N) := True;
         if not Listening (N) then
            Listening (N) := True;
            Listeners (N).Start (N);
         end if;
      end if;
   end Open;

   function Is_Open (N : Port_Number) return Boolean is (Logic.Is_Open (N));

   procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean) is
   begin
      Changed := Logic.Is_Open (N) and then Baud <= Logic.Max_Baud;
   end Set_Baud;

   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural) is
   begin
      Poll (N);
      Logic.Queue (N, Data, Taken);
      Poll (N);
   end Queue;

   function Free (N : Port_Number) return Natural is
   begin
      Poll (N);
      return Logic.Free (N);
   end Free;

   function Transmit_Empty (N : Port_Number) return Boolean is
   begin
      Poll (N);
      return Logic.Transmit_Empty (N);
   end Transmit_Empty;

   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural) is
   begin
      Poll (N);
      Logic.Take (N, Into, Count);
   end Take;

end Adaflight.STM32.Soft_Serial;
