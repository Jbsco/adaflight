--  The OSD custom text on a UART: the port the custom text setting names,
--  opened for its messages at the custom text rate when the rangefinder,
--  the receiver and the GPS leave it free, and the custom text task, which
--  turns the messages received into the text the OSD element shows.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.OSD_Render;
with Adaflight.STM32.USART;
package Adaflight.STM32.OSD_Custom_Text is
   --  The port at the rate the custom text rate setting names, or at 115200
   --  baud when that setting is automatic or past the rate table.
   procedure Init (Config : Adaflight.Config_Groups.Configuration);
   --  Whether the port holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  One run of the custom text task over every byte received since the
   --  last, each message ended by a null when the terminator setting is
   --  zero and by a line feed otherwise.
   procedure Update (Terminator : Interfaces.Unsigned_8);
   --  The text the OSD element shows.
   function Text return Adaflight.OSD_Render.Custom_Text;
end Adaflight.STM32.OSD_Custom_Text;
