--  The UARTs of the STM32F405 the board family brings out, USART1 and USART6
--  on the 84 MHz bus and USART3 and UART4 on the 42 MHz bus, each at eight
--  data bits, no parity or even parity and one or two stop bits over its two
--  pins, or half duplex over its transmit pin alone, inverted through the
--  board's inverter where it has one: a transmitter whose interrupt sends
--  the bytes queued in a ring of 256, and a receiver whose interrupt keeps
--  the bytes with their arrival times in a ring of 256 until a task takes
--  them.
with Interfaces;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins;
with Adaflight.STM32.GPIO;
package Adaflight.STM32.USART is
   type Number is (UART1, UART2, UART3, UART4, UART5, UART6);
   type Port is limited record
      Which : Number := UART1;
   end record;
   type Time_Array is array (Natural range <>) of Interfaces.Unsigned_32;
   --  A half duplex line: the transmit pin alone, push-pull or open drain,
   --  with its pull resistor.
   type Half_Duplex is record
      On        : Boolean := False;
      Push_Pull : Boolean := False;
      Resistor  : Adaflight.STM32.GPIO.Pull := Adaflight.STM32.GPIO.Up;
   end record;
   Full_Duplex : constant Half_Duplex := (others => <>);
   --  The board's UART inverters, off.
   procedure Init_Inverters;
   --  A port's transmit and receive pins on the board.
   function TX_Pin (N : Number) return Adaflight.Pins.Pin;
   function RX_Pin (N : Number) return Adaflight.Pins.Pin;
   --  Whether the board has the port, its identifier as the configuration
   --  names the ports, and the ports the board has in order. A port the
   --  board lacks does not start.
   function Present (N : Number) return Boolean is
     (case N is
         when UART1 => Adaflight.Board.Has_UART1, when UART2 => Adaflight.Board.Has_UART2,
         when UART3 => Adaflight.Board.Has_UART3, when UART4 => Adaflight.Board.Has_UART4,
         when UART5 => Adaflight.Board.Has_UART5, when UART6 => Adaflight.Board.Has_UART6);
   function Identifier (N : Number) return Integer is (51 + Number'Pos (N));
   type Number_List is array (Positive range <>) of Number;
   function Present_Set return Number_List;
   --  The port at the rate, the stop bits and the line, with a parity bit on
   --  each word when Even_Parity asks for one, and the board's inverter on
   --  the port's lines set as Inverted asks where the board has one.
   procedure Init
     (N : Number; Baud : Positive; Two_Stop_Bits : Boolean := False; Line : Half_Duplex := Full_Duplex;
      Even_Parity : Boolean := False; Inverted : Boolean := False);
   --  A port's settings at its last start, and whether it started.
   type Settings is record
      Started       : Boolean := False;
      Baud          : Natural := 0;
      Two_Stop_Bits : Boolean := False;
      Line          : Half_Duplex := Full_Duplex;
      Even_Parity   : Boolean := False;
      Inverted      : Boolean := False;
   end record;
   function Current (N : Number) return Settings;
   --  Every character of Text, queued as the ring has room.
   procedure Put (Into : in out Port; Text : String);
   --  Every byte of Data, queued as the ring has room.
   procedure Put (Into : in out Port; Data : Byte_Array);
   --  The bytes of Data the ring has room for, and their count.
   procedure Queue (N : Number; Data : Byte_Array; Taken : out Natural);
   --  The ring's room, and whether every queued byte has left.
   function Free (N : Number) return Natural;
   function Transmit_Empty (N : Number) return Boolean;
   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (N : Number; Into : out Byte_Array; Count : out Natural);
   --  The same with each byte's arrival time in microseconds.
   procedure Take (N : Number; Into : out Byte_Array; Times : out Time_Array; Count : out Natural)
     with Pre => Times'Length >= Into'Length;
end Adaflight.STM32.USART;
