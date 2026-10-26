--  The OSD display of the board: the MAX7456 chip's select pin held from the
--  start, the chip and its display port started over the chip's SPI bus when
--  the OSD feature is on and the display device setting allows it, the
--  stored canvas fitted to the display, the readiness the OSD replies report
--  and the font characters a configurator writes.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.MSP_Font_In;
with Adaflight.OSD_Task;
package Adaflight.STM32.OSD is
   --  The select pin as the stored configuration names it, before the SPI
   --  buses start: driven high when the configuration asks for it, else an
   --  input with its pull up.
   procedure Preinit (C : Adaflight.Config_Groups.Configuration);

   --  The display device the configuration selects, started with the OSD
   --  feature on. Disable_Feature says no display started, which turns the
   --  feature off until the next start.
   procedure Init
     (C : in out Adaflight.Config_Groups.Configuration; Feature_OSD : Boolean; Disable_Feature : out Boolean);

   function Device return Adaflight.OSD_Task.Device_Kind;
   function Port_Present return Boolean;
   --  The display's columns and rows, zero before the chip answers.
   procedure Dimensions (Columns, Rows : out Interfaces.Unsigned_8);

   --  The display's readiness for the OSD replies: a chip that did not
   --  answer is started again first, with a redraw while disarmed.
   procedure Check_Ready (C : Adaflight.Config_Groups.Configuration; Armed : Boolean; Ready : out Boolean);

   --  Whether a font character write goes to the chip, which needs it found.
   function Font_Write_Taken return Boolean;
   procedure Write_Font (Address : Interfaces.Unsigned_16; Data : Adaflight.MSP_Font_In.Character_Data);
end Adaflight.STM32.OSD;
