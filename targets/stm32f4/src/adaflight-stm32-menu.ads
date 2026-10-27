--  The menu system on the board's OSD display: the menus over the target's
--  state, the sticks read as keys, the draws and actions on the OSD chip,
--  and the requests the menus make of the runtime, which the flight carries
--  out after each pass.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.RC_Command;
package Adaflight.STM32.Menu is
   --  What the menu reads from the flight at a pass: the sticks, the arming
   --  and the modes that hold the menu off, the sensors with their
   --  calibrations, the loop rate and the running features.
   type Facts is record
      Channels                  : Adaflight.RC_Command.Channel_Values := (others => 1_500.0);
      Aux                       : Adaflight.RC_Command.Channel_Values := (others => 1_500.0);
      Armed                     : Boolean := False;
      Paralyzed                 : Boolean := False;
      Stick_Commands_Disabled   : Boolean := False;
      Acc_Present               : Boolean := False;
      Acc_Calibration_Complete  : Boolean := True;
      Acc_Calibrated            : Boolean := False;
      Gyro_Present              : Boolean := False;
      Gyro_Calibration_Complete : Boolean := False;
      PID_Frequency             : Float range 0.0 .. 65_535.0 := 0.0;
      Runtime_Features          : Interfaces.Unsigned_32 := 0;
   end record;

   --  The requests a pass made: the calibrations, the OSD's elements
   --  analyzed again, the OSD, PID and rate profiles changed to the ones
   --  asked for, the PID configuration set up again, the configuration
   --  saved and the board reset.
   type Requests is record
      Acc_Calibration  : Boolean := False;
      Gyro_Calibration : Boolean := False;
      Elements         : Boolean := False;
      OSD_Profile      : Boolean := False;
      OSD_Profile_Idx  : Interfaces.Unsigned_8 := 0;
      PID_Profile      : Boolean := False;
      PID_Profile_Idx  : Interfaces.Unsigned_8 := 0;
      Rate_Profile     : Boolean := False;
      Rate_Profile_Idx : Interfaces.Unsigned_8 := 0;
      PID_Init         : Boolean := False;
      Save             : Boolean := False;
      Reset            : Boolean := False;
   end record;

   --  The firmware's identity for the firmware menu, and the OSD display
   --  registered when the OSD has a port.
   procedure Init
     (Version, Target_Name, Board_Name, Manufacturer : String; Display_Present : Boolean;
      Columns, Rows : Interfaces.Unsigned_8);

   function Open return Boolean;
   --  Whether the menu holds arming, and whether it asked for a reboot.
   function Arming_Held return Boolean;
   function Reboot_Required return Boolean;

   --  One pass: the live configuration taken while the menu is closed and
   --  given the menu's edits while it is open, the sticks read, the menu
   --  drawn, and the requests of the pass.
   procedure Run
     (C : in out Adaflight.Config_Groups.Configuration; F : Facts; Now_Us, Now_Ms : Interfaces.Unsigned_32;
      R : out Requests);
end Adaflight.STM32.Menu;
