--  The serial passthrough on the board: the board's serial ports by their
--  identifiers as the command line's serialpassthrough sees them, a port
--  opened or changed for it, the USB port's line coding and DTR actions,
--  the motor outputs held idle for an ESC sensor passthrough, and the
--  forwarding between two ports until a reset, which the command line's
--  gpspassthrough also runs between the GPS port and the command line's.
with Interfaces;
with Adaflight.STM32.Serial;
package Adaflight.STM32.Passthrough is

   --  The port the command line runs on, the other end of a GPS passthrough.
   procedure Set_Command_Line_Port (Which : Adaflight.STM32.Serial.Line);

   --  Whether a port is open with its baud rate, mode, options and whether
   --  a function takes its bytes as they arrive.
   procedure Port_State
     (Id : Interfaces.Integer_32; Open : out Boolean; Baud : out Interfaces.Unsigned_32;
      Mode : out Interfaces.Unsigned_8; Options : out Interfaces.Unsigned_32; Callback : out Boolean);

   --  A port started at a baud rate with options, the USB port as it is.
   procedure Port_Open
     (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32; Mode : Interfaces.Unsigned_8;
      Options : Interfaces.Unsigned_32; Opened : out Boolean);

   --  A UART started again at a baud rate with its other settings.
   procedure Port_Set_Baud (Id : Interfaces.Integer_32; Baud : Interfaces.Unsigned_32);

   --  The UARTs run both ways, so a mode change and a callback removal leave
   --  the port as it is.
   procedure Port_Set_Mode (Id : Interfaces.Integer_32; Mode : Interfaces.Unsigned_8) is null;
   procedure Port_Remove_Callback (Id : Interfaces.Integer_32) is null;

   --  The forwarding's setup: the host's line coding setting a port's baud
   --  rate, and the USB port's DTR resetting the board when it drops or
   --  switching a PINIO on while it is down.
   procedure Port_Baud_From_USB (USB : Interfaces.Integer_32; Target : Interfaces.Integer_32);
   procedure Port_DTR_Reset (USB : Interfaces.Integer_32);
   procedure Port_DTR_PINIO (USB : Interfaces.Integer_32; PINIO : Natural);

   --  The motor outputs held at the level an ESC's serial link idles at.
   procedure ESC_Sensor_Pins_Idle;

   --  The bytes of each port written to the other until a reset, with the
   --  setup's line coding and DTR actions, and the escape when the right
   --  port, the host's, is not the USB port.
   procedure Port_Forward (Left : Interfaces.Integer_32; Right : Interfaces.Integer_32);

   --  The forwarding between the GPS port and the command line's, with its
   --  transmit side on, or no start when no GPS port is open.
   procedure GPS_Passthrough (Started : out Boolean);

end Adaflight.STM32.Passthrough;
