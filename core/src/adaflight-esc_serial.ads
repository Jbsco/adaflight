--  The ESC serial port's engine: a half duplex serial line to an ESC's
--  bootloader on a motor pin, clocked by a timer's tick with the timer's
--  capture of the pin's edges. BLHeli, KISS and Castle bytes are a start
--  bit, eight bits from the low one and a stop bit, one bit per tick. A
--  SimonK byte is eight bits from the low one, each four ticks long, a one
--  as two high ticks and two low ticks and a zero as high, low, high, low,
--  after a preamble of three bytes, and comes in as the times between the
--  pin's edges. The engine keeps the port's state and its two ring buffers
--  and lists, in order, what its caller must do with pins, timers and
--  motors. It also contains the passthrough between a host port and the ESC:
--  the exit request's parser and one pass of the loop.
with Interfaces;
with Adaflight.Bytes;

package Adaflight.ESC_Serial with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   type Protocol is (SimonK, BLHeli, KISS, KISS_All, Castle);

   Max_Motors : constant := 8;
   subtype Motor_Index is Natural range 0 .. Max_Motors - 1;

   --  A pin or its timer: a motor's by its index, the separate send pin's,
   --  or none.
   subtype Target is Natural range 0 .. Max_Motors + 1;
   Send_Pin : constant Target := Max_Motors;
   Nothing  : constant Target := Max_Motors + 1;

   Buffer_Size : constant := 1024;
   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   type Buffer is array (Buffer_Index) of Unsigned_8;

   --  What the caller does, in the order listed: take a pin's timer channel,
   --  claim a pin, set a pin's mode, write a pin high or low, set a timer up
   --  at a period and a rate, reset a timer, set its time base, start it,
   --  set its counter, set its capture to a rising or a falling edge, clear
   --  its capture's flag, turn its capture's interrupt on or off, register
   --  or drop the handler of its bit ticks or of its edges, turn the motors
   --  off, wait some milliseconds, and write a byte to the host. ESC_Byte
   --  records a byte the engine queued for the ESC.
   type Op_Kind is
     (Allocate, Claim, Pin_Mode, Pin_High, Pin_Low, Configure, Reset, Time_Base, Start, Set_Counter, Polarity,
      Clear_Flag, Interrupt, Tick_Handler, Edge_Handler, Motors_Off, Wait, Host_Byte, ESC_Byte);

   --  A pin's modes, by the value an operation gives: on its timer with a
   --  pull up, a push-pull output, an input with a pull up.
   Mode_Capture : constant := 3;
   Mode_Output  : constant := 4;
   Mode_Input   : constant := 6;

   type Op is record
      Kind : Op_Kind := Wait;
      Who  : Target := Nothing;
      A    : Unsigned_32 := 0;
      B    : Unsigned_32 := 0;
   end record;

   --  A list of operations with the room its owner gives it. Each call
   --  names the room it needs. A tick and an edge, which a board runs in
   --  interrupt handlers, need little.
   Max_Ops : constant := 64;
   subtype Op_Count is Natural range 0 .. Max_Ops;
   type Op_Array is array (Positive range <>) of Op;
   type Op_List (Room : Op_Count) is record
      Count : Op_Count := 0;
      Items : Op_Array (1 .. Room) := (others => <>);
   end record;

   Open_Ops  : constant := 53;
   Start_Ops : constant := Open_Ops + 1;
   Tick_Ops  : constant := 9;
   Edge_Ops  : constant := 2;
   Close_Ops : constant := 8;

   type Edge_Kind is (Trailing, Leading);
   subtype Bit_Index is Natural range 0 .. 9;
   subtype Bit_Count is Natural range 0 .. 10;

   type Output_Pin is record
      Motor    : Motor_Index := 0;
      Inverted : Boolean := False;
   end record;
   type Output_Pins is array (Motor_Index) of Output_Pin;

   type Port is record
      Mode                : Protocol := SimonK;
      Rx_Timer            : Target := Nothing;
      Tx_Timer            : Target := Nothing;
      Tx_Period           : Unsigned_32 := 0;
      Rx_Inverted         : Boolean := False;
      Outputs             : Output_Pins;
      Output_Count        : Natural range 0 .. Max_Motors := 0;
      Searching           : Boolean := False;
      Rx_Bit              : Bit_Index := 0;
      Rx_Last_Leading     : Bit_Index := 0;
      Rx_Edge             : Edge_Kind := Trailing;
      Transmitting        : Boolean := False;
      Receiving           : Boolean := False;
      Bits_Left           : Bit_Count := 0;
      Internal_Tx         : Unsigned_16 := 0;
      Internal_Rx         : Unsigned_16 := 0;
      Receive_Timeout     : Unsigned_16 := 0;
      Transmission_Errors : Unsigned_16 := 0;
      Receive_Errors      : Unsigned_16 := 0;
      Rx_Buffer           : Buffer := (others => 0);
      Tx_Buffer           : Buffer := (others => 0);
      Rx_Head, Rx_Tail    : Buffer_Index := 0;
      Tx_Head, Tx_Tail    : Buffer_Index := 0;
      --  The SimonK coder's tick within a bit and its preamble bytes sent,
      --  and the SimonK decoder's short times seen, bits and bytes.
      Quarter             : Natural range 0 .. 3 := 0;
      Preamble            : Natural range 0 .. 3 := 0;
      Half_Zeros          : Natural range 0 .. 1 := 0;
      Bits                : Natural range 0 .. 7 := 0;
      Bytes               : Unsigned_16 := 0;
   end record;

   --  What a board has: per motor whether its pin is assigned, whether the
   --  pin's timer channel can be taken, whether that channel is a
   --  complementary or an inverted output, whether the motor is enabled and
   --  has its pin, then whether a separate send pin is set, has a timer
   --  channel to take and sits on the motor pin's timer, and the core clock.
   type Motor_Facts is record
      Assigned, Timer, Complementary, Inverted, Enabled, Has_Pin : Boolean := False;
   end record;
   type Motor_Table is array (Motor_Index) of Motor_Facts;
   type Board is record
      Motors          : Motor_Table;
      Send_Set        : Boolean := False;
      Send_Timer      : Boolean := False;
      Send_Same_Timer : Boolean := False;
      Core_Clock      : Unsigned_32 := 168_000_000;
   end record;

   --  A protocol's rate.
   function Baud_Of (Mode : Protocol) return Unsigned_32 is
     (case Mode is when KISS | KISS_All => 38_400, when Castle => 18_880, when SimonK | BLHeli => 19_200);

   --  A port opened on a motor's pin, or on every enabled motor's pin for
   --  KISS on all of them, or refused: a single motor needs its pin assigned
   --  with a timer channel that is no complementary output, and a separate
   --  send pin needs its channel too. A port without a separate send pin,
   --  or with one on the motor pin's timer, has one timer: it keeps the bit
   --  ticks' time base for its capture, and SimonK, which needs a time base
   --  for each, is refused. KISS on all motors is refused when no motor's
   --  timer channel can be taken. The operations set the pins and the
   --  timers up.
   procedure Open
     (P : out Port; Mode : Protocol; Output : Motor_Index; Baud : Unsigned_32; B : Board; Ops : in out Op_List;
      Opened : out Boolean)
     with Global => null, Pre => Baud > 0 and then Ops.Room >= Open_Ops, Post => Ops.Count <= Open_Ops;

   --  A tick of the bit timer.
   procedure Tick (P : in out Port; Ops : in out Op_List)
     with Global => null, Pre => Ops.Room >= Tick_Ops, Post => Ops.Count <= Tick_Ops;

   --  An edge on the motor pin with the capture's value. KISS has no
   --  capture.
   procedure Edge (P : in out Port; Capture : Unsigned_16; Ops : in out Op_List)
     with Global => null, Pre => Ops.Room >= Edge_Ops, Post => Ops.Count <= Edge_Ops;

   --  The port closed: the operations release its pin and timers.
   procedure Close (P : Port; Ops : in out Op_List)
     with Global => null, Pre => Ops.Room >= Close_Ops, Post => Ops.Count <= Close_Ops;

   --  The buffers: a byte to send, a byte received or zero when none waits,
   --  the bytes waiting, and whether nothing waits to be sent.
   procedure Write (P : in out Port; B : Unsigned_8)
     with Global => null;
   procedure Read (P : in out Port; B : out Unsigned_8)
     with Global => null;
   function Rx_Waiting (P : Port) return Natural
     with Global => null, Post => Rx_Waiting'Result <= Buffer_Size - 1;
   function Tx_Empty (P : Port) return Boolean is (P.Tx_Head = P.Tx_Tail);

   --  The exit request's parser: an MSP request of up to ten bytes whose
   --  command is 244 with no payload ends the passthrough. Any other
   --  command returns the parser to idle.
   type Parser_State is (Idle, Header_Start, Header_M, Header_Arrow, Header_Size, Header_Command);
   type Exit_Parser is record
      State    : Parser_State := Idle;
      Size     : Unsigned_8 := 0;
      Offset   : Unsigned_8 := 0;
      Checksum : Unsigned_8 := 0;
      Command  : Unsigned_8 := 0;
   end record;
   procedure Exit_Step (X : in out Exit_Parser; C : Unsigned_8; Leave : out Boolean)
     with Global => null;

   --  A passthrough started as the command line or MSP asks: the motors
   --  off, then the port opened for the protocol at its rate. KISS with
   --  motor 255 opens every motor. The index counts modulo 256, and one
   --  past the motors is refused.
   procedure Start
     (P : out Port; Mode : Protocol; Index : Natural; B : Board; Ops : in out Op_List; Started : out Boolean)
     with Global => null, Pre => Mode /= KISS_All and then Ops.Room >= Start_Ops, Post => Ops.Count <= Start_Ops;

   --  One pass of the passthrough has three parts, each in chunks of bytes.
   --  First every byte the ESC sent goes to the host, except in KISS for
   --  one motor: Forward takes a chunk and More asks for another call. Then
   --  every byte the host sent goes to the exit parser, back to the host
   --  for BLHeli and KISS, and on to the ESC: From_Host takes a chunk. At
   --  the exit request the host gets its reply, the port closes, Left is
   --  true and the host's later bytes stay unread. Then the pass waits.
   Chunk         : constant := 16;
   From_Host_Ops : constant := 2 * (Chunk - 1) + 6 + Close_Ops;
   procedure Forward (P : in out Port; Ops : in out Op_List; More : out Boolean)
     with Global => null, Pre => Ops.Room >= Chunk, Post => Ops.Count <= Chunk;
   procedure From_Host
     (P : in out Port; X : in out Exit_Parser; Host : Adaflight.Bytes.Byte_Array; Ops : in out Op_List;
      Left : out Boolean)
     with Global => null,
          Pre    => Host'Length <= Chunk and then Ops.Room >= From_Host_Ops,
          Post   => Ops.Count <= From_Host_Ops;
   --  The wait that ends a pass, in milliseconds.
   function Pass_Wait_Ms (P : Port) return Natural is (if P.Mode = Castle then 0 else 5);

end Adaflight.ESC_Serial;
