--  The simulator link of the host image: a simulator's flight dynamics
--  packets over UDP, turned into the virtual gyro and accelerometer counts
--  and the attitude quaternion the flight software takes, its stick packets
--  for the UDP receiver, and the motor packets sent back, one pair per
--  flight dynamics packet. ADAFLIGHT_SIMULATOR names the bridge, gazebo or
--  legacy, with the simulator's address after a comma; unset, the link is
--  off and the virtual sensors read a craft at rest.
with Interfaces;
with Adaflight.Attitude;
with Adaflight.Sim_FDM;
with Adaflight.STM32.MCU;
package Adaflight.Host_Simulator is
   function Enabled return Boolean;
   function Legacy_Bridge return Boolean;
   --  The sockets opened on the first call, then the packets that arrived
   --  since the last call, each decoded and stepped.
   procedure Poll;
   function Gyro return Adaflight.Sim_FDM.Axes;
   function Acc return Adaflight.Sim_FDM.Axes;
   --  The quaternion of the latest packet since the last take, once.
   procedure Take_Attitude (Fresh : out Boolean; Q : out Adaflight.Attitude.Quaternion);
   --  The GPS solution of the latest packet since the last take, once, and
   --  the pressure of the latest update, sea level before any.
   procedure Take_GPS (Fresh : out Boolean; Fix : out Adaflight.Sim_FDM.GPS_Fix);
   function Pressure return Interfaces.Integer_32;
   --  The sixteen pulses of the latest stick packet since the last take, once.
   procedure Take_RC (Fresh : out Boolean; Pulses : out Adaflight.STM32.MCU.RC_Pulses);
   --  The motor outputs for the packets: the driven count, each pulse with
   --  its idle pulse, and the write's end, which sends the pair when a
   --  flight dynamics packet arrived since the last pair.
   procedure Set_Motor_Count (N : Natural);
   procedure Set_Motor (Index : Natural; Pulse, Idle : Float);
   procedure Complete_Motors (Three_D : Boolean);
end Adaflight.Host_Simulator;
