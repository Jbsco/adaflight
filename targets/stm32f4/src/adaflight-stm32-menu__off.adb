--  The menu system of a build without it: no state and nothing to draw.
package body Adaflight.STM32.Menu is

   procedure Init
     (Version, Target_Name, Board_Name, Manufacturer : String; Display_Present : Boolean;
      Columns, Rows : Interfaces.Unsigned_8) is null;

   function Open return Boolean is (False);

   function Arming_Held return Boolean is (False);

   function Reboot_Required return Boolean is (False);

   procedure Run
     (C : in out Adaflight.Config_Groups.Configuration; F : Facts; Now_Us, Now_Ms : Interfaces.Unsigned_32;
      R : out Requests)
   is
      pragma Unreferenced (C, F, Now_Us, Now_Ms);
   begin
      R := (others => <>);
   end Run;

   procedure Set_Gate (Lat, Lon : Interfaces.Integer_32) is null;

   procedure Register_CRSF (Columns, Rows : Interfaces.Unsigned_8) is null;

   procedure Resize_CRSF (Columns, Rows : Interfaces.Unsigned_8) is null;

   function CRSF_Registered return Boolean is (False);

   function On_CRSF return Boolean is (False);

   procedure Open_On_CRSF (C : Adaflight.Config_Groups.Configuration; Opened : out Boolean) is
      pragma Unreferenced (C);
   begin
      Opened := False;
   end Open_On_CRSF;

   procedure Leave is null;

   procedure Register_SRXL is null;

   function SRXL_Registered return Boolean is (False);

   function On_SRXL return Boolean is (False);

   procedure Register_OLED is null;

   function OLED_Grabbed return Boolean is (False);

end Adaflight.STM32.Menu;
