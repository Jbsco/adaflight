with Adaflight.Board;
with Ada.Streams;
with GNAT.Sockets;
with Adaflight.STM32.Time;
package body Adaflight.STM32.USART is
   use type GNAT.Sockets.Socket_Type;
   use type Ada.Streams.Stream_Element_Offset;

   --  Each UART is a TCP server on port 5760 plus its number, one client at
   --  a time.
   Port_Of : constant array (Hardware) of GNAT.Sockets.Port_Type :=
     (UART1 => 5_761, UART2 => 5_762, UART3 => 5_763, UART4 => 5_764, UART5 => 5_765, UART6 => 5_766);

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

   Lines : array (Hardware) of Line;

   task type Listener is
      entry Start (N : Hardware);
   end Listener;

   task body Listener is
      use GNAT.Sockets;
      Which   : Hardware;
      Server  : Socket_Type;
      Client  : Socket_Type;
      Address : Sock_Addr_Type;
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      accept Start (N : Hardware) do
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

   Listeners : array (Hardware) of Listener;
   Started   : array (Hardware) of Boolean := (others => False);

   procedure Init_Inverters is null;

   Started_With : array (Number) of Settings;

   function Current (N : Number) return Settings is (Started_With (N));

   procedure Init
     (N : Number; Baud : Positive; Two_Stop_Bits : Boolean := False; Line : Half_Duplex := Full_Duplex;
      Even_Parity : Boolean := False; Inverted : Boolean := False)
   is
   begin
      if not Present (N) then
         return;
      end if;
      if N in Software then
         declare
            Opened : Boolean;
         begin
            if Adaflight.STM32.Soft_Serial.Is_Open (Soft_Port (N)) then
               Adaflight.STM32.Soft_Serial.Set_Baud (Soft_Port (N), Baud, Opened);
               if Opened then
                  Started_With (N).Baud := Baud;
               end if;
            else
               Adaflight.STM32.Soft_Serial.Open (Soft_Port (N), Baud, Line.On, Inverted, Line.Resistor, Opened);
               Started_With (N) :=
                 (Started => Opened, Baud => Baud, Two_Stop_Bits => False, Line => Line, Even_Parity => False,
                  Inverted => Inverted);
            end if;
         end;
         return;
      end if;
      Started_With (N) :=
        (Started => True, Baud => Baud, Two_Stop_Bits => Two_Stop_Bits, Line => Line, Even_Parity => Even_Parity,
         Inverted => Inverted);
      if not Started (N) then
         Started (N) := True;
         Listeners (N).Start (N);
      end if;
   end Init;

   procedure Send (N : Hardware; Data : Byte_Array) is
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
      Put (Into, Data);
   end Put;

   --  Every byte toward a UART's client, or queued on a software serial
   --  port as its buffer takes them.
   procedure Put (Into : in out Port; Data : Byte_Array) is
      Next  : Natural := Data'First;
      Taken : Natural;
   begin
      if Into.Which in Software then
         for Attempt in 1 .. 64 loop
            exit when Next > Data'Last;
            Adaflight.STM32.Soft_Serial.Queue (Soft_Port (Into.Which), Data (Next .. Data'Last), Taken);
            Next := Next + Taken;
         end loop;
         return;
      end if;
      Send (Into.Which, Data);
   end Put;

   procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural) is
   begin
      if N in Software then
         Adaflight.STM32.Soft_Serial.Queue (Soft_Port (N), Data, Taken);
         return;
      end if;
      Send (N, Data);
      Taken := Data'Length;
   end Queue;

   function Free (N : Number) return Natural is
     (if N in Software then Adaflight.STM32.Soft_Serial.Free (Soft_Port (N)) else 256);

   function Transmit_Empty (N : Number) return Boolean is
     (N not in Software or else Adaflight.STM32.Soft_Serial.Transmit_Empty (Soft_Port (N)));

   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural) is
      Times : Time_Array (0 .. Into'Length - 1);
   begin
      if N in Software then
         Adaflight.STM32.Soft_Serial.Take (Soft_Port (N), Into, Count);
         return;
      end if;
      Lines (N).Take (Into, Times, Count);
   end Take;

   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural) is
   begin
      if N in Software then
         Adaflight.STM32.Soft_Serial.Take (Soft_Port (N), Into, Count);
         Times := (others => Adaflight.STM32.Time.Micros);
         return;
      end if;
      Lines (N).Take (Into, Times, Count);
   end Take;

   function TX_Pin (N : Number) return Adaflight.Pins.Pin is
     (case N is
         when UART1 => Adaflight.Board.UART1_TX_Pin, when UART2 => Adaflight.Board.UART2_TX_Pin,
         when UART3 => Adaflight.Board.UART3_TX_Pin, when UART4 => Adaflight.Board.UART4_TX_Pin,
         when UART5 => Adaflight.Board.UART5_TX_Pin, when UART6 => Adaflight.Board.UART6_TX_Pin,
         when Software =>
           Adaflight.Pins.Pin_Of (Natural'Max (16, Natural (Adaflight.STM32.Soft_Serial.TX_Tag (Soft_Port (N))))));
   function RX_Pin (N : Number) return Adaflight.Pins.Pin is
     (case N is
         when UART1 => Adaflight.Board.UART1_RX_Pin, when UART2 => Adaflight.Board.UART2_RX_Pin,
         when UART3 => Adaflight.Board.UART3_RX_Pin, when UART4 => Adaflight.Board.UART4_RX_Pin,
         when UART5 => Adaflight.Board.UART5_RX_Pin, when UART6 => Adaflight.Board.UART6_RX_Pin,
         when Software =>
           Adaflight.Pins.Pin_Of (Natural'Max (16, Natural (Adaflight.STM32.Soft_Serial.RX_Tag (Soft_Port (N))))));

   function Set_Within (Last : Number) return Number_List is
      Set   : Number_List (1 .. Number'Pos (Last) + 1);
      Count : Natural := 0;
   begin
      for N in Number'First .. Last loop
         if Present (N) then
            Count := Count + 1;
            Set (Count) := N;
         end if;
      end loop;
      return Set (1 .. Count);
   end Set_Within;

   function Present_Set return Number_List is (Set_Within (Number'Last));

   function UART_Set return Number_List is (Set_Within (Hardware'Last));
end Adaflight.STM32.USART;
