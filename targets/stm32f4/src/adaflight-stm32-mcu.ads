--  The microcontroller itself: its unique identifier, the system reset, and
--  the reset into the ROM bootloader through a request kept in the RTC
--  backup registers, which a system reset leaves alone.
with Interfaces;
with Adaflight.Attitude;
package Adaflight.STM32.MCU is
   type Identifier is array (1 .. 3) of Interfaces.Unsigned_32;
   --  The device's unique identifier, the three words the status prints.
   function UID return Identifier;
   --  The core's reset through its application interrupt and reset control
   --  register.
   procedure Reset
     with No_Return;
   --  The persistent words in the backup registers: kept over a software
   --  reset with their magic word, cleared after any other reset.
   procedure Init_Persistent;
   --  Whether this start follows a software reset, read at the persistent
   --  words' start.
   function Software_Reset return Boolean;
   --  A reset that the next start turns into the ROM bootloader.
   procedure Reset_To_Bootloader
     with No_Return;
   --  At the start, before the board's devices: a pending bootloader request
   --  cleared, and the jump into the system memory's bootloader with the
   --  clocks and interrupts back as a reset leaves them.
   procedure Check_Bootloader_Request;
   --  The host image's simulator link: whether the image runs against a
   --  simulator, its packets read once a pass, and the attitude quaternion
   --  of the latest packet, once. Board images have no link.
   function Simulated return Boolean;
   procedure Simulator_Poll;
   procedure Simulator_Attitude
     (Fresh : out Boolean; Q : out Adaflight.Attitude.Quaternion; Legacy_Bridge : out Boolean);
   --  The simulator's GPS solution as the virtual provider offers it, once
   --  per packet, and its pressure in pascals for the virtual barometer.
   type Simulator_Fix is record
      Lat, Lon, Alt_Cm               : Interfaces.Integer_32 := 0;
      Ground_Speed, Speed_3D, Course : Interfaces.Unsigned_16 := 0;
      Vel_North, Vel_East, Vel_Down  : Interfaces.Integer_16 := 0;
   end record;
   procedure Simulator_GPS (Fresh : out Boolean; Fix : out Simulator_Fix);
   procedure Simulator_Pressure (Pascals : out Interfaces.Integer_32);
   --  Whether this image has the UDP receiver: the host image alone.
   function UDP_Receiver_Available return Boolean;
   type RC_Pulses is array (0 .. 15) of Interfaces.Unsigned_16;
   procedure Simulator_RC (Fresh : out Boolean; Pulses : out RC_Pulses);
end Adaflight.STM32.MCU;
