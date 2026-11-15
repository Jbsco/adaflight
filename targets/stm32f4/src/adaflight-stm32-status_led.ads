--  The status LEDs on the pins the stored configuration names. An LED
--  without a pin, or a number outside the three, takes no call.
with Adaflight.Config_Groups;
with Adaflight.Warning_LED;
package Adaflight.STM32.Status_LED is
   --  Each pin there is claimed as an output, its LED off.
   procedure Init (C : Adaflight.Config_Groups.Status_Led_Config_Record);
   procedure Set (LED : Integer; On : Boolean);
   procedure Toggle (LED : Integer);
   --  The warning LED's call on the first LED.
   procedure Warn (Call : Adaflight.Warning_LED.LED_Call);
end Adaflight.STM32.Status_LED;
