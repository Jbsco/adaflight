--  The BLHeli 4-way interface on the board: the enabled motor outputs' pins
--  as the ESCs' signal lines, both bootloader protocols timed from the
--  board's clock on those pins, and the interface's loop on the port its
--  passthrough request came in on, until the host's exit command.
with Adaflight.STM32.Serial;
package Adaflight.STM32.Four_Way is

   --  The enabled motor outputs with a pin, which a passthrough request's
   --  reply counts and the interface takes as its ESCs.
   function ESC_Count return Natural;

   --  The interface on the host's port: the motors stop and their pins go
   --  to the interface, each of the host's frames is answered, and the exit
   --  command hands the pins back and restarts the motors.
   procedure Run (Host : Adaflight.STM32.Serial.Line; Silence_Beeper : not null access procedure);

end Adaflight.STM32.Four_Way;
