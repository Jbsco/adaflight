--  Mass storage mode: the flight log's device shown to a USB host as a disk,
--  in place of flight. A flash chip shows as a read-only disk with one file
--  per log, one file of all logs and a hidden padding file. An SD card shows
--  as its own blocks, which a host reads and writes. The mode starts after a
--  reset that asked for it, or with its button held at a start, and ends at
--  a reset: a press of that button or a loss of power.
with Interfaces;
with Adaflight.Config_Groups;
package Adaflight.STM32.Mass_Storage_Mode is
   --  Whether the mode can start: this image has the USB disk, and the
   --  flight log's device is a flash chip with a file system or an SD card
   --  that answers.
   function Ready (C : Adaflight.Config_Groups.Configuration) return Boolean;

   --  The mode's button as the stored configuration names it, and whether
   --  it is pressed. An image without the USB disk has no button.
   procedure Init_Button (C : Adaflight.Config_Groups.Configuration);
   function Button_Pressed (C : Adaflight.Config_Groups.Configuration) return Boolean;

   --  The mode, until a reset. Time_Ms is the clock's milliseconds since
   --  1970 for the dates of files without a start time, zero for none. A
   --  flash chip that is absent shows as a disk without logs, and an SD card
   --  that is absent as a disk without a medium. Any other flight log
   --  device, a card that is not configured or an image without the USB
   --  disk ends in a reset.
   procedure Run (C : Adaflight.Config_Groups.Configuration; Time_Ms : Interfaces.Unsigned_64)
     with No_Return;
end Adaflight.STM32.Mass_Storage_Mode;
