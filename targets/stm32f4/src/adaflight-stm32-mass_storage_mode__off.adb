--  A build without mass storage mode: never ready, no button, and a start
--  of the mode is a reset.
with Adaflight.STM32.MCU;
package body Adaflight.STM32.Mass_Storage_Mode is
   function Ready (C : Adaflight.Config_Groups.Configuration) return Boolean is
      pragma Unreferenced (C);
   begin
      return False;
   end Ready;

   procedure Init_Button (C : Adaflight.Config_Groups.Configuration) is null;

   function Button_Pressed (C : Adaflight.Config_Groups.Configuration) return Boolean is
      pragma Unreferenced (C);
   begin
      return False;
   end Button_Pressed;

   procedure Run (C : Adaflight.Config_Groups.Configuration; Time_Ms : Interfaces.Unsigned_64) is
      pragma Unreferenced (C, Time_Ms);
   begin
      Adaflight.STM32.MCU.Reset;
   end Run;
end Adaflight.STM32.Mass_Storage_Mode;
