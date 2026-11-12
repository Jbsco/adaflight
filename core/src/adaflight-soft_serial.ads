--  The software serial port's engine: a serial port made of a timer's bit
--  clock and its capture of the receive pin's edges. A byte goes out as a
--  start bit, its eight bits from the low one and a stop bit, one bit per
--  tick of the bit clock. A byte comes in from the edges: the start edge
--  centres the bit clock in the bit, each later edge marks where a run of
--  high bits began or ended, and the tenth tick stores the byte when its
--  stop bit was high. A half duplex port turns its one pin round between
--  the two. The engine keeps the port's state and its two ring buffers and
--  tells its caller what to do with the pins and the timer.
with Interfaces;

package Adaflight.Soft_Serial with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;

   Buffer_Size : constant := 256;
   subtype Buffer_Index is Natural range 0 .. Buffer_Size - 1;
   type Buffer is array (Buffer_Index) of Unsigned_8;

   Total_Bits : constant := 10;

   type Port_Mode is record
      Rx, Tx : Boolean := False;
   end record;

   --  The port's options: the line inverted, one pin for both directions,
   --  no pull on the receive pin, and the pull down a SmartAudio line takes.
   type Port_Options is record
      Inverted, Bidirectional, No_Pull, SmartAudio_Pull : Boolean := False;
   end record;

   type Pull is (None, Down, Up);
   function Pull_Of (O : Port_Options) return Pull is
     (if O.SmartAudio_Pull then Down elsif O.No_Pull then None elsif O.Inverted then Down else Up);

   --  A timer's time base for a rate: the timer's clock halved until the
   --  bit's period fits sixteen bits.
   type Time_Base is record
      Period : Unsigned_16 := 0;
      Clock  : Unsigned_32 := 0;
   end record;
   function Time_Base_Of (Clock : Unsigned_32; Baud : Unsigned_32) return Time_Base
     with Global => null, Pre => Baud > 0;

   type Timer_Mode is (Single, Dual);
   type Edge_Kind is (Trailing, Leading);
   subtype Bit_Index is Natural range 0 .. Total_Bits - 1;
   subtype Bit_Count is Natural range 0 .. Total_Bits;

   type Port is record
      Mode                : Port_Mode;
      Options             : Port_Options;
      Timing              : Timer_Mode := Single;
      Rx_Active           : Boolean := False;
      Searching           : Boolean := False;
      Rx_Bit              : Bit_Index := 0;
      Rx_Last_Leading     : Bit_Index := 0;
      Rx_Edge             : Edge_Kind := Trailing;
      Transmitting        : Boolean := False;
      Bits_Left           : Bit_Count := 0;
      Internal_Tx         : Unsigned_16 := 0;
      Internal_Rx         : Unsigned_16 := 0;
      Transmission_Errors : Unsigned_16 := 0;
      Receive_Errors      : Unsigned_16 := 0;
      Rx_Buffer           : Buffer := (others => 0);
      Tx_Buffer           : Buffer := (others => 0);
      Rx_Head, Rx_Tail    : Buffer_Index := 0;
      Tx_Head, Tx_Tail    : Buffer_Index := 0;
   end record;

   --  What an open is asked: the mode, the options and the rate, whether
   --  each pin is assigned and whether both are one pin, whether each pin
   --  has a timer channel, an inverted-output channel among them, whether
   --  both channels are one timer's, and each timer's clock.
   type Open_Request is record
      Mode         : Port_Mode;
      Options      : Port_Options;
      Baud         : Unsigned_32 := 9600;
      Tx_Assigned  : Boolean := False;
      Rx_Assigned  : Boolean := False;
      Same_Pin     : Boolean := False;
      Tx_Timer     : Boolean := False;
      Rx_Timer     : Boolean := False;
      Tx_N         : Boolean := False;
      Rx_N         : Boolean := False;
      Same_Timer   : Boolean := False;
      Tx_Clock     : Unsigned_32 := 0;
      Rx_Clock     : Unsigned_32 := 0;
   end record;

   --  What an open answers: whether the port opened, the pin whose timer is
   --  the port's main timer, the pins it receives and sends on, the pins it
   --  claims, whether the send pin's timer is kept beside the main one and
   --  runs the port's second bit clock, and the time bases.
   type Pin is (No_Pin, Tx_Pin, Rx_Pin);
   type Open_Plan is record
      Opened      : Boolean := False;
      Main        : Pin := No_Pin;
      Receive_On  : Pin := No_Pin;
      Send_On     : Pin := No_Pin;
      Claim_Rx    : Boolean := False;
      Claim_Tx    : Boolean := False;
      Extra_Timer : Boolean := False;
      Timing      : Timer_Mode := Single;
      Main_Base   : Time_Base;
      Second_Base : Time_Base;
   end record;

   --  A port opened, or refused: a half duplex port needs a timer channel
   --  on its send pin, a receiving port one on its receive pin, neither an
   --  inverted-output channel, and a sending port a send pin, with a timer
   --  channel when it does not receive. An opened port listens.
   procedure Open (P : out Port; R : Open_Request; Plan : out Open_Plan)
     with Global => null, Pre => R.Baud > 0;

   --  What a tick of the bit clock asks of the send pin: nothing, the pin
   --  turned to receiving or to sending, or a level written.
   type Tx_Effect is (Nothing, To_Receive, To_Transmit, Level_Low, Level_High);

   --  A tick of the sending bit clock.
   procedure Clock_Tx (P : in out Port; E : out Tx_Effect)
     with Global => null;
   --  A tick of the receiving bit clock. Rearm asks for the capture of the
   --  next start edge, falling on a plain line and rising on an inverted
   --  one.
   procedure Clock_Rx (P : in out Port; Rearm : out Boolean)
     with Global => null;
   --  A tick of a single timer's bit clock: sending, then receiving, each
   --  when the port's mode has it.
   procedure Clock (P : in out Port; E : out Tx_Effect; Rearm : out Boolean)
     with Global => null;

   --  An edge on the receive pin. Acted is false when the port does not
   --  receive. Centre asks for the bit clock's counter at half its period,
   --  and Rising names the next edge to capture.
   procedure Edge (P : in out Port; Acted : out Boolean; Centre : out Boolean; Rising : out Boolean)
     with Global => null;

   --  The buffers: a byte to send, a byte received or zero when none waits,
   --  the bytes waiting, the room to send, and whether nothing waits to be
   --  sent. A port that does not send takes no byte and has no room, and one
   --  that does not receive gives none.
   procedure Write (P : in out Port; B : Unsigned_8)
     with Global => null;
   procedure Read (P : in out Port; B : out Unsigned_8)
     with Global => null;
   function Rx_Waiting (P : Port) return Natural
     with Global => null, Post => Rx_Waiting'Result <= Buffer_Size - 1;
   function Tx_Free (P : Port) return Natural
     with Global => null, Post => Tx_Free'Result <= Buffer_Size - 1;
   function Tx_Empty (P : Port) return Boolean is (P.Tx_Head = P.Tx_Tail);

   procedure Set_Mode (P : in out Port; M : Port_Mode)
     with Global => null;

end Adaflight.Soft_Serial;
