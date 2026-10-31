--  The simulator link of the host image: a simulator's flight dynamics
--  packets over UDP, turned into the virtual gyro and accelerometer counts
--  and the attitude quaternion the flight software takes, and the motor
--  packets sent back. ADAFLIGHT_SIMULATOR names the bridge, gazebo or
--  legacy, with the simulator's address after a comma; unset, the link is
--  off and the virtual sensors read a craft at rest.
with Adaflight.Attitude;
with Adaflight.Sim_FDM;
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
end Adaflight.Host_Simulator;
