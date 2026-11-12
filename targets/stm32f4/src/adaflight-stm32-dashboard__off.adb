--  The dashboard of a build without it: no display and no drawing.
package body Adaflight.STM32.Dashboard is

   procedure Init
     (C : Adaflight.Config_Groups.Configuration; Now_Us : Interfaces.Unsigned_32; R : Adaflight.Dashboard.Readings)
   is null;

   procedure Update (Now_Us : Interfaces.Unsigned_32; R : Adaflight.Dashboard.Readings) is null;

   procedure Enable_Cycling is null;

   procedure Disable_Cycling is null;

   procedure Reset_Cycling is null;

   function Present return Boolean is (False);

   procedure Menu_Clear is null;

   procedure Menu_Write (Column, Row : Interfaces.Unsigned_8; Text : String) is null;

   procedure Menu_Write_Char (Column, Row : Interfaces.Unsigned_8; C : Character) is null;

end Adaflight.STM32.Dashboard;
