--  The flight log header's system information from the stored configuration
--  and the runtime's facts: each value as the reference's line reads it from
--  the active profiles and the groups, the wing and multirotor lines of the
--  other build at zero, and the texts, with the craft name from the
--  configuration and the debug mode's name from the settings' table.
with Interfaces;
with Adaflight.Blackbox_Header;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;

package Adaflight.Blackbox_Info with SPARK_Mode is
   subtype Integer_32 is Interfaces.Integer_32;
   package Header renames Adaflight.Blackbox_Header;

   --  What the header reads outside the stored configuration: the recorder's
   --  intra and delta intervals, the motor output range rounded, the
   --  accelerometer's count for one g, the battery reference voltage, the
   --  gyro's sample loop time, the PID loop denominator, whether DShot
   --  telemetry runs, the RC smoothing filter's cutoff settings, debug axis
   --  and running cutoffs, the receiver's rate rounded, the debug mode, the
   --  device's unique identifier words, and the build's texts.
   type Facts is record
      I_Interval            : Integer_32 := 0;
      P_Interval            : Integer_32 := 0;
      Motor_Output_Low      : Integer_32 := 0;
      Motor_Output_High     : Integer_32 := 0;
      Acc_1G                : Integer_32 := 0;
      VBat_Reference        : Integer_32 := 0;
      Loop_Time             : Integer_32 := 0;
      PID_Process_Denom     : Integer_32 := 0;
      DShot_Telemetry       : Boolean := False;
      RC_Setpoint_Cutoff    : Integer_32 := 0;
      RC_Throttle_Cutoff    : Integer_32 := 0;
      RC_Debug_Axis         : Integer_32 := 0;
      RC_Setpoint_Cutoff_Hz : Integer_32 := 0;
      RC_Throttle_Cutoff_Hz : Integer_32 := 0;
      RX_Rate_Hz            : Integer_32 := 0;
      Debug_Mode            : Integer_32 := 0;
      Device_UID_0          : Integer_32 := 0;
      Device_UID_1          : Integer_32 := 0;
      Device_UID_2          : Integer_32 := 0;
      Firmware_Type         : Header.Text;
      Firmware_Name         : Header.Text;
      Firmware_Version      : Header.Text;
      Git_Revision          : Header.Text;
      Target_Name           : Header.Text;
      Build_Date            : Header.Text;
      Build_Time            : Header.Text;
      Build_Key             : Header.Text;
      Release_Name          : Header.Text;
      Manufacturer_Id       : Header.Text;
      Board_Name            : Header.Text;
      Start_Date_Time       : Header.Text;
   end record;

   function Sysinfo_Of (C : Configuration; F : Facts; Wing : Boolean) return Header.Sysinfo
     with Global => null;

end Adaflight.Blackbox_Info;
