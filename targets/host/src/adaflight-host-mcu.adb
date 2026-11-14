with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adaflight.Host_Arming_Log;
with Adaflight.Host_OLED;
with Adaflight.Host_Screen;
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

   --  A mass storage request ends the process with status 3, after its time
   --  is written to the file ADAFLIGHT_MASS_STORAGE_REQUEST names. A start
   --  with ADAFLIGHT_MASS_STORAGE set to a time is a start with that request.
   procedure Reset_To_Mass_Storage (Time_Ms : Interfaces.Unsigned_64) is
      Name : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_MASS_STORAGE_REQUEST", "");
      File : Ada.Text_IO.File_Type;
      Text : constant String := Interfaces.Unsigned_64'Image (Time_Ms);
   begin
      if Name'Length > 0 then
         begin
            Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
            Ada.Text_IO.Put_Line (File, Text (Text'First + 1 .. Text'Last));
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
      GNAT.OS_Lib.OS_Exit (3);
   end Reset_To_Mass_Storage;

   procedure Take_Mass_Storage_Request (Asked : out Boolean; Time_Ms : out Interfaces.Unsigned_64) is
      Text : constant String := Ada.Environment_Variables.Value ("ADAFLIGHT_MASS_STORAGE", "");
   begin
      Asked := Text'Length in 1 .. 18 and then (for all C of Text => C in '0' .. '9');
      Time_Ms := (if Asked then Interfaces.Unsigned_64'Value (Text) else 0);
   end Take_Mass_Storage_Request;

   procedure Check_Bootloader_Exit is null;

   function Simulated return Boolean is (Adaflight.Host_Simulator.Enabled);

   --  The host's work once per scheduler pass: the simulator's packets, the
   --  screen files and the log of arming events.
   procedure Simulator_Poll is
   begin
      Adaflight.Host_Simulator.Poll;
      Adaflight.Host_Screen.Poll;
      Adaflight.Host_OLED.Poll;
      Adaflight.Host_Arming_Log.Poll;
   end Simulator_Poll;

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

   function UDP_Receiver_Available return Boolean is (True);

   procedure Simulator_RC (Fresh : out Boolean; Pulses : out RC_Pulses) is
   begin
      Adaflight.Host_Simulator.Take_RC (Fresh, Pulses);
   end Simulator_RC;

   procedure Simulator_Mag (Field : out Mag_Field) is
      M : constant Adaflight.Sim_FDM.Axes := Adaflight.Host_Simulator.Mag;
   begin
      Field := (M (1), M (2), M (3));
   end Simulator_Mag;
end Adaflight.STM32.MCU;
