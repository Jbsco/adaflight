--  The software serial ports without their hardware: the two ports' engines,
--  the timer ticks and edges sent to them, and the bytes queued and taken.
--  The pins and timers come in as the formal procedures, which a board
--  fills with its registers and the host with a model of the line. A tick
--  and an edge come from interrupt handlers on a board, so its task-side
--  calls run with those held off.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.Soft_Serial;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Timers;
generic
   --  What a port's engine asks after a tick of its sending clock: the send
   --  pin turned to receiving or to sending, or a level written.
   with procedure Send_Effect (N : Positive; E : Adaflight.Soft_Serial.Tx_Effect);
   --  The capture of the next start edge.
   with procedure Rearm (N : Positive; Rising : Boolean);
   --  After an edge: the main timer's counter at half its period when
   --  Centre asks, then the capture of the next edge.
   with procedure After_Edge (N : Positive; Centre : Boolean; Rising : Boolean);
package Adaflight.STM32.Soft_Serial_Logic is
   package Engine renames Adaflight.Soft_Serial;
   Port_Count : constant := 2;
   subtype Port_Number is Positive range 1 .. Port_Count;
   type Timer is (Main, Second);

   --  The highest rate a port opens at.
   Max_Baud : constant := 19_200;

   --  The ports' pins taken from the configuration, for a build and a
   --  configuration with the ports on.
   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean);
   --  Whether the ports are on and the port has a pin.
   function Present (N : Port_Number) return Boolean;
   --  A port's pins by their tags, zero for none.
   function TX_Tag (N : Port_Number) return Interfaces.Unsigned_8;
   function RX_Tag (N : Port_Number) return Interfaces.Unsigned_8;

   --  The timer channels of a port's pins, each when its pin has one.
   type Channels is record
      TX, RX             : Adaflight.STM32.Timers.Timer_Entry;
      TX_Found, RX_Found : Boolean := False;
   end record;

   --  A port opened on its pins: each pin's timer channel taken for the
   --  port's owners, one channel when both pins are one, then the port
   --  opened as the engine plans it with what the channels allow, or left
   --  closed. A rate above the highest takes no channel. It sends when it has a send pin
   --  and receives when it has a receive pin or is half duplex. A half
   --  duplex line takes its pull from Resistor: none, down on a plain
   --  line as a SmartAudio line has it, or the line's own.
   procedure Open_On
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; C : out Channels; Plan : out Engine.Open_Plan);
   function Is_Open (N : Port_Number) return Boolean;
   --  A port closed: its ticks, edges and bytes pass it by.
   procedure Close (N : Port_Number);
   function Options (N : Port_Number) return Engine.Port_Options;
   function Timing (N : Port_Number) return Engine.Timer_Mode;

   --  A tick of a port's bit clock. A port with one timer sends and
   --  receives on its main timer's tick. A port with two receives on the
   --  main timer's, which each start edge centres in the bit, and sends on
   --  the second one's.
   procedure Tick (N : Port_Number; T : Timer);
   --  An edge on a port's receive pin.
   procedure Edge (N : Port_Number);

   --  The bytes of Data a port's send buffer has room for, and their count.
   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural);
   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural);
   --  The bytes that wait to be taken.
   function Waiting (N : Port_Number) return Natural;
   --  The send buffer's room, and whether every queued byte has left.
   function Free (N : Port_Number) return Natural;
   function Transmit_Empty (N : Port_Number) return Boolean;
end Adaflight.STM32.Soft_Serial_Logic;
