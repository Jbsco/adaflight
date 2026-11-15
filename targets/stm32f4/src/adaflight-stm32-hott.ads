--  The HoTT telemetry on a UART: the core's HoTT link on the telemetry port
--  of the first provider with the HoTT protocol, at 19200 baud. A receiver
--  asks with two bytes and the link answers a byte per task run. The link
--  takes the port's waiting bytes as it reads or drops them. The text
--  mode's screen is a display of the menu system, and a text mode request
--  asks the menu for what the transmitter's button means.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.HoTT_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.HoTT is
   --  The provider's port and its sharing, with the telemetry feature on.
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32);
   --  Whether a telemetry provider named a port for the link.
   function Has_Port return Boolean;
   --  The port opened or released as its sharing state asks now.
   procedure Check_State (Armed, Box_Present, Box_Active : Boolean);
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  What a text mode request asks of the menu system: the menu opened on
   --  this display, left with a save, a key from a button, and the menu
   --  opened again.
   type Menu_Asks is record
      Open    : Boolean := False;
      Leave   : Boolean := False;
      Key_Set : Boolean := False;
      Key     : Adaflight.HoTT_Telemetry.Menu_Key := Adaflight.HoTT_Telemetry.None;
      Reopen  : Boolean := False;
   end record;
   --  One run of the telemetry task: whether the link asks for a new task
   --  period, that period, and what a text mode request asks of the menu.
   procedure Run
     (Inp : Adaflight.HoTT_Telemetry.Inputs; GPS_Present : Boolean; Reschedule : out Boolean;
      Period_Us : out Interfaces.Integer_32; Asks : out Menu_Asks);
   --  The menu system's display on the text mode's screen: registered at
   --  the screen's size, grabbed, released with the screen cleared, cleared
   --  and written; and whether the text mode has stopped.
   procedure Menu_Register;
   procedure Menu_Grab;
   procedure Menu_Release;
   procedure Menu_Clear;
   procedure Menu_Write (Col, Row : Interfaces.Unsigned_8; Text : String);
   procedure Menu_Write_Char (Col, Row, C : Interfaces.Unsigned_8);
   function Text_Stopped return Boolean;
end Adaflight.STM32.HoTT;
