--  The host's ESC serial port: the ESC's line is a TCP server on port 5769,
--  one client at a time. The levels the engine writes to the motor's pin are
--  put back into bytes for the client, and a byte from the client becomes
--  the edges and bit ticks its frame makes on the pin. KISS on every motor
--  gives the client a level only when every motor's pin has it. The line
--  has no rate: each of the passthrough's calls runs the frames that wait.
--  When the environment variable ADAFLIGHT_ESC_SERIAL_LOG names a file, each
--  timer setup, reset, time base, start and handler change on a pin with a
--  channel is a line in it: the operation, the pin's target and the
--  operation's two values.
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Text_IO;
with GNAT.Sockets;
package body Adaflight.STM32.ESC_Serial_Port is
   use Interfaces;
   subtype Byte is Adaflight.Bytes.Byte;
   subtype Byte_Array is Adaflight.Bytes.Byte_Array;
   use type GNAT.Sockets.Socket_Type;
   use type Ada.Streams.Stream_Element_Offset;
   use type Engine.Protocol;
   use type Engine.Op_Kind;

   Line_Port : constant GNAT.Sockets.Port_Type := 5_769;

   Ring_Size : constant := 4_096;
   subtype Ring_Index is Natural range 0 .. Ring_Size - 1;

   --  The line's bytes from its client, and the client.
   protected Line is
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
      select
         accept Start;
      or
         terminate;
      end select;
      Create_Socket (Server);
      Set_Socket_Option (Server, Socket_Level, (Reuse_Address, True));
      Bind_Socket (Server, (Family => Family_Inet, Addr => Any_Inet_Addr, Port => Line_Port));
      Listen_Socket (Server);
      loop
         Accept_Socket (Server, Client, Address);
         Set_Socket_Option (Client, IP_Protocol_For_TCP_Level, (No_Delay, True));
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

   Listening : Boolean := False;

   procedure Send (B : Byte) is
      use Ada.Streams;
      Buffer : constant Stream_Element_Array (1 .. 1) := (1 => Stream_Element (B));
      Last   : Stream_Element_Offset;
   begin
      if Line.Connected then
         GNAT.Sockets.Send_Socket (Line.Client, Buffer, Last);
      end if;
   exception
      when GNAT.Sockets.Socket_Error =>
         null;
   end Send;

   P      : Engine.Port;
   Parser : Engine.Exit_Parser;
   Open   : Boolean := False;
   Taken  : array (Pin_Target) of Boolean := (others => False);

   --  The pin's levels put back into bytes. A BLHeli, KISS or Castle byte: a
   --  low level while idle is a start bit, the eight levels after it the
   --  byte from its low bit, and the level after those the stop bit. A
   --  SimonK byte, while the pin is an output: four levels a bit, high,
   --  high, low, low a one and high, low, high, low a zero, eight bits from
   --  the low one, after three bytes of preamble.
   type Decoder is record
      Bits    : Natural range 0 .. 9 := 0;
      Value   : Unsigned_16 := 0;
      Framed  : Boolean := False;
      Quarter : Natural range 0 .. 3 := 0;
      Levels  : Unsigned_8 := 0;
      Count   : Natural range 0 .. 7 := 0;
      Bytes   : Natural := 0;
   end record;
   Sent : Decoder;

   --  Each pin's last level, and the receive line's, high while idle.
   Last_Level : array (Pin_Target) of Boolean := (others => True);
   In_Level   : Boolean := True;

   procedure Level (High : Boolean) is
   begin
      if P.Mode = Engine.SimonK then
         if not Sent.Framed then
            return;
         end if;
         Sent.Levels := Sent.Levels * 2 + Boolean'Pos (High);
         if Sent.Quarter < 3 then
            Sent.Quarter := Sent.Quarter + 1;
            return;
         end if;
         if Sent.Levels = 2#1100# then
            Sent.Value := Sent.Value or Shift_Left (1, Sent.Count);
         end if;
         Sent.Quarter := 0;
         Sent.Levels := 0;
         if Sent.Count < 7 then
            Sent.Count := Sent.Count + 1;
         else
            Sent.Bytes := Sent.Bytes + 1;
            if Sent.Bytes > 3 then
               Send (Byte (Sent.Value and 16#FF#));
            end if;
            Sent.Count := 0;
            Sent.Value := 0;
         end if;
      elsif Sent.Bits = 0 then
         if not High then
            Sent.Bits := 1;
            Sent.Value := 0;
         end if;
      elsif Sent.Bits < 9 then
         if High then
            Sent.Value := Sent.Value or Shift_Left (1, Sent.Bits - 1);
         end if;
         Sent.Bits := Sent.Bits + 1;
      else
         if High then
            Send (Byte (Sent.Value and 16#FF#));
         end if;
         Sent.Bits := 0;
      end if;
   end Level;

   function Image (N : Unsigned_32) return String is (Unsigned_32'Image (N) (2 .. Unsigned_32'Image (N)'Last));

   procedure Log (O : Engine.Op) is
      Variable : constant String := "ADAFLIGHT_ESC_SERIAL_LOG";
      File     : Ada.Text_IO.File_Type;
   begin
      if not Ada.Environment_Variables.Exists (Variable) then
         return;
      end if;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Ada.Environment_Variables.Value (Variable));
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Environment_Variables.Value (Variable));
      end;
      Ada.Text_IO.Put_Line
        (File,
         (case O.Kind is
             when Engine.Configure => "setup", when Engine.Reset => "reset", when Engine.Time_Base => "base",
             when Engine.Start => "start", when Engine.Tick_Handler => "tick", when others => "edge")
         & "," & Image (Unsigned_32 (O.Who)) & "," & Image (O.A) & "," & Image (O.B));
      Ada.Text_IO.Close (File);
   end Log;

   --  One operation on the model: a level on a pin with a channel reaches
   --  the client's decoder, and the motor pin's turn to an output and back
   --  frames a SimonK message.
   procedure Apply (O : Engine.Op) is
      High : constant Boolean := O.Kind = Engine.Pin_High;
   begin
      if O.Who not in Pin_Target or else not Taken (O.Who) then
         return;
      end if;
      if O.Kind in Engine.Configure | Engine.Reset | Engine.Time_Base | Engine.Start | Engine.Tick_Handler
                 | Engine.Edge_Handler
      then
         Log (O);
      elsif O.Kind = Engine.Pin_Mode and then O.Who = P.Rx_Timer then
         if O.A = Engine.Mode_Output and then not Sent.Framed then
            Sent := (Framed => True, others => <>);
         elsif O.A /= Engine.Mode_Output then
            Sent.Framed := False;
         end if;
      elsif O.Kind in Engine.Pin_High | Engine.Pin_Low then
         Last_Level (O.Who) := High;
         if P.Mode /= Engine.KISS_All then
            if O.Who = P.Rx_Timer then
               Level (High);
            end if;
         elsif P.Output_Count > 0 and then O.Who = P.Outputs (P.Output_Count - 1).Motor
           and then (for all I in 0 .. P.Output_Count - 1 => Last_Level (P.Outputs (I).Motor) = High)
         then
            Level (High);
         end if;
      end if;
   end Apply;

   procedure Tick is
      Ops : Engine.Op_List (Engine.Tick_Ops);
   begin
      Engine.Tick (P, Ops);
      for I in 1 .. Ops.Count loop
         Apply (Ops.Items (I));
      end loop;
   end Tick;

   procedure Edge (Capture : Unsigned_16) is
      Ops : Engine.Op_List (Engine.Edge_Ops);
   begin
      Engine.Edge (P, Capture, Ops);
      for I in 1 .. Ops.Count loop
         Apply (Ops.Items (I));
      end loop;
   end Edge;

   --  A SimonK bit from the ESC: a one is one time between edges of four
   --  ticks, a zero two times of two ticks.
   procedure SimonK_Bit (One : Boolean) is
   begin
      if One then
         Edge (136);
      else
         Edge (68);
         Edge (68);
      end if;
   end SimonK_Bit;

   --  The frames that wait run: the queued bytes clocked out up to the tick
   --  that turns the pin back, then the client's bytes. A BLHeli or Castle
   --  byte is its start bit, its eight bits from the low one and its stop
   --  bit, an edge where the level changes and a tick in each bit. SimonK
   --  bytes come as one message: its first edge, which counts as a one,
   --  the rest of the three preamble bytes, the bytes' bits, and the ticks
   --  without an edge that end it. KISS has no receiver.
   procedure Poll is
      B     : Byte;
      Got   : Boolean;
      High  : Boolean;
      First : Boolean := True;
   begin
      if not Open then
         return;
      end if;
      for Guard in 1 .. 48 * Engine.Buffer_Size loop
         exit when Engine.Tx_Empty (P) and then not P.Transmitting;
         Tick;
      end loop;
      loop
         exit when Engine.Rx_Waiting (P) >= Engine.Buffer_Size - 2;
         Line.Pop (B, Got);
         exit when not Got;
         case P.Mode is
            when Engine.KISS | Engine.KISS_All =>
               null;
            when Engine.BLHeli | Engine.Castle =>
               for Bit in 0 .. 9 loop
                  High := (if Bit = 0 then False elsif Bit = 9 then True else (Shift_Right (B, Bit - 1) and 1) /= 0);
                  if High /= In_Level then
                     In_Level := High;
                     Edge (0);
                  end if;
                  Tick;
               end loop;
            when Engine.SimonK =>
               if First then
                  First := False;
                  Edge (1_000);
                  for Bit in 1 .. 23 loop
                     SimonK_Bit (One => Bit /= 23);
                  end loop;
               end if;
               for Bit in 0 .. 7 loop
                  SimonK_Bit (One => (Shift_Right (B, Bit) and 1) /= 0);
               end loop;
         end case;
      end loop;
      if P.Mode = Engine.SimonK and then not First then
         for T in 1 .. 9 loop
            Tick;
         end loop;
      end if;
   end Poll;

   procedure Opened (Started : Boolean) is
   begin
      Open := Started;
      Sent := (others => <>);
      Last_Level := (others => True);
      In_Level := True;
      if Started and then not Listening then
         Listening := True;
         Listener.Start;
      end if;
   end Opened;

   procedure Start
     (Mode : Engine.Protocol; Index : Natural; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean)
   is
   begin
      Taken := (others => False);
      Parser := (others => <>);
      Engine.Start (P, Mode, Index, B, Ops, Started);
      Opened (Started);
   end Start;

   procedure Open_All (Baud : Unsigned_32; B : Engine.Board; Ops : in out Engine.Op_List; Started : out Boolean) is
   begin
      Taken := (others => False);
      Parser := (others => <>);
      Engine.Open (P, Engine.KISS_All, 0, Baud, B, Ops, Started);
      Opened (Started);
   end Open_All;

   procedure Forward (Ops : in out Engine.Op_List; More : out Boolean) is
   begin
      Poll;
      Engine.Forward (P, Ops, More);
   end Forward;

   procedure From_Host (Host : Byte_Array; Ops : in out Engine.Op_List; Left : out Boolean) is
   begin
      Engine.From_Host (P, Parser, Host, Ops, Left);
      if Left then
         for I in 1 .. Ops.Count loop
            Apply (Ops.Items (I));
         end loop;
         Open := False;
         Taken := (others => False);
      else
         Poll;
      end if;
   end From_Host;

   function Pass_Wait_Ms return Natural is (Engine.Pass_Wait_Ms (P));

   procedure Assign (Who : Pin_Target; E : Adaflight.STM32.Timers.Timer_Entry; Found : Boolean) is
      pragma Unreferenced (E);
   begin
      Taken (Who) := Found;
   end Assign;

   procedure Perform (Ops : Engine.Op_List; First, Last : Positive) is
   begin
      for I in First .. Natural'Min (Last, Ops.Count) loop
         Apply (Ops.Items (I));
      end loop;
   end Perform;

   procedure Release is
   begin
      Open := False;
      Taken := (others => False);
   end Release;

end Adaflight.STM32.ESC_Serial_Port;
