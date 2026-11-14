--  The ESC serial link on the board: a host's port joined to an ESC's
--  bootloader over a motor pin in the SimonK, BLHeli, KISS or Castle framing,
--  or to every motor's ESC for KISS. The link runs until the host's exit
--  request and leaves the motors stopped.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.STM32.Serial;
package Adaflight.STM32.ESC_Serial is

   --  The motors' pins and the separate send pin from the configuration.
   procedure Configure (C : Adaflight.Config_Groups.Configuration);

   --  The link on a host's port to a motor's ESC, in a protocol by its
   --  number: 0 SimonK, 1 BLHeli, 2 KISS, 3 KISS on every motor, 4 Castle.
   --  KISS with motor 255 also takes every motor. Started is false when the
   --  link does not open: a pin without a timer channel the port can take,
   --  a complementary channel, or SimonK without a second timer.
   procedure Run
     (Host : Adaflight.STM32.Serial.Line; Protocol : Interfaces.Unsigned_8; Index : Natural; Started : out Boolean);

   --  The link on the command line's port.
   procedure Run_On_Command_Line (Index : Natural; Protocol : Interfaces.Unsigned_8; Started : out Boolean);

end Adaflight.STM32.ESC_Serial;
