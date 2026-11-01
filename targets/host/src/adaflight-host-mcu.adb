with GNAT.OS_Lib;
with Adaflight.Host_Simulator;
with Adaflight.Sim_FDM;
package body Adaflight.STM32.MCU is
   --  A fixed identifier for the host image.
   function UID return Identifier is ((16#00AD_A000#, 16#4F57_4E00#, 16#0000_0001#));

   --  A reset ends the process, which the caller starts again.
   procedure Reset is
   begin
      GNAT.OS_Lib.OS_Exit (0);
   end Reset;

   --  The host has no backup registers and no bootloader: the request ends
   --  the process with status 2 so the caller can tell it from a reset.
   procedure Init_Persistent is null;

   function Software_Reset return Boolean is (False);

   procedure Reset_To_Bootloader is
   begin
      GNAT.OS_Lib.OS_Exit (2);
   end Reset_To_Bootloader;

   procedure Check_Bootloader_Request is null;

   function Simulated return Boolean is (Adaflight.Host_Simulator.Enabled);

   procedure Simulator_Poll renames Adaflight.Host_Simulator.Poll;

   procedure Simulator_Attitude
     (Fresh : out Boolean; Q : out Adaflight.Attitude.Quaternion; Legacy_Bridge : out Boolean) is
   begin
      Adaflight.Host_Simulator.Take_Attitude (Fresh, Q);
      Legacy_Bridge := Adaflight.Host_Simulator.Legacy_Bridge;
   end Simulator_Attitude;

   procedure Simulator_GPS (Fresh : out Boolean; Fix : out Simulator_Fix) is
      G : Adaflight.Sim_FDM.GPS_Fix;
   begin
      Adaflight.Host_Simulator.Take_GPS (Fresh, G);
      Fix := (Lat => G.Lat, Lon => G.Lon, Alt_Cm => G.Alt_Cm, Ground_Speed => G.Ground_Speed, Speed_3D => G.Speed_3D,
              Course => G.Course, Vel_North => G.Vel_North, Vel_East => G.Vel_East, Vel_Down => G.Vel_Down);
   end Simulator_GPS;

   procedure Simulator_Pressure (Pascals : out Interfaces.Integer_32) is
   begin
      Pascals := Adaflight.Host_Simulator.Pressure;
   end Simulator_Pressure;
end Adaflight.STM32.MCU;
