--  The servo outputs of a build without them: no timer channels and no writes.
package body Adaflight.STM32.Servos is

   procedure Init (C : Adaflight.Config_Groups.Configuration) is null;

   procedure Write (Index : Natural; Value : Float) is null;

end Adaflight.STM32.Servos;
