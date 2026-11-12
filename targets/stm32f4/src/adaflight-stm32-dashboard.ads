--  The OLED dashboard on the I2C bus the configuration names: the display
--  started and the welcome page drawn at the start, then one update of the
--  core's dashboard each pass of its task, its display operations performed
--  over the bus. A configuration that names no bus leaves the display
--  absent.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Dashboard;
package Adaflight.STM32.Dashboard is
   --  The display's bus and address taken, the display started with 200 ms
   --  before and after, and the welcome page drawn. The reading of the
   --  display's presence is this unit's own: it is present when it answered
   --  its last start.
   procedure Init
     (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32; R : Adaflight.Dashboard.Readings);
   --  One run of the dashboard task.
   procedure Update (Now_Us : Interfaces.Unsigned_32; R : Adaflight.Dashboard.Readings);
   --  The page cycle started, stopped, and sent back to its first page.
   procedure Enable_Cycling;
   procedure Disable_Cycling;
   procedure Reset_Cycling;
   --  Whether the display answered its last start.
   function Present return Boolean;
   --  The menu's draws on the display: the screen cleared, and a text or a
   --  character at a cell.
   procedure Menu_Clear;
   procedure Menu_Write (Column, Row : Interfaces.Unsigned_8; Text : String);
   procedure Menu_Write_Char (Column, Row : Interfaces.Unsigned_8; C : Character);
end Adaflight.STM32.Dashboard;
