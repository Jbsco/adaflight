--  The board's two software serial ports: each on the pins the configuration
--  assigns it, a timer's overflow as its bit clock and the timer's capture
--  of the receive pin's edges. A port sends when it has a send pin and
--  receives when it has a receive pin; a half duplex port does both on its
--  send pin. A port whose pins sit on two timers sends on the send pin's
--  timer and receives on the receive pin's.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.STM32.GPIO;
package Adaflight.STM32.Soft_Serial is
   Port_Count : constant := 2;
   subtype Port_Number is Positive range 1 .. Port_Count;
   --  The ports' pins taken from the configuration, for a build and a
   --  configuration with the ports on.
   procedure Configure (C : Adaflight.Config_Groups.Configuration; Feature_On : Boolean);
   --  Whether the ports are on and the port has a pin.
   function Present (N : Port_Number) return Boolean;
   --  A port's pins by their tags, zero for none.
   function TX_Tag (N : Port_Number) return Interfaces.Unsigned_8;
   function RX_Tag (N : Port_Number) return Interfaces.Unsigned_8;
   --  A port opened at a rate, half duplex on its send pin or on both pins,
   --  inverted or not, with a half duplex line's pull. Opened is false when
   --  a pin it needs has no free timer channel.
   procedure Open
     (N : Port_Number; Baud : Positive; Half_Duplex : Boolean; Inverted : Boolean;
      Resistor : Adaflight.STM32.GPIO.Pull; Opened : out Boolean);
   function Is_Open (N : Port_Number) return Boolean;
   --  An open port's rate changed on each of its timers. A closed port and
   --  a rate above the highest a port opens at change nothing.
   procedure Set_Baud (N : Port_Number; Baud : Positive; Changed : out Boolean);
   --  The bytes of Data the port's send buffer has room for, and their
   --  count.
   procedure Queue (N : Port_Number; Data : Byte_Array; Taken : out Natural);
   --  The send buffer's room, and whether every queued byte has left.
   function Free (N : Port_Number) return Natural;
   function Transmit_Empty (N : Port_Number) return Boolean;
   --  The bytes received since the last take, up to Into's length, and
   --  their count; the rest of Into is zero.
   procedure Take (N : Port_Number; Into : out Byte_Array; Count : out Natural);
end Adaflight.STM32.Soft_Serial;
