with Interfaces;
with Adaflight.Bytes;

--  The simulator link's flight dynamics packets: the decode of one packet and
--  the state update the simulator target runs for it, which turns the
--  simulator's IMU, attitude, pressure and position into the virtual sensors'
--  counts, the attitude quaternion and a GPS solution, and keeps the
--  simulation's rate against the host clock.
package Adaflight.Sim_FDM with SPARK_Mode is
   use Interfaces;

   Packet_Size : constant := 144;

   --  The largest magnitude a packet field may hold; a packet with a larger,
   --  infinite or NaN field is dropped.
   Field_Bound : constant := 1.0E6;
   subtype Field is Long_Float range -Field_Bound .. Field_Bound;

   --  The largest magnitude of an attitude quaternion's component, about
   --  twice that of a unit quaternion's; a packet with a larger one is dropped.
   Orientation_Bound : constant := 2.0;
   subtype Component is Field range -Orientation_Bound .. Orientation_Bound;

   type Vector3 is array (1 .. 3) of Field;
   type Vector4 is array (1 .. 4) of Component;

   type Packet is record
      Timestamp    : Field := 0.0;
      Rates        : Vector3 := (others => 0.0);
      Acceleration : Vector3 := (others => 0.0);
      Orientation  : Vector4 := (others => 0.0);
      Velocity     : Vector3 := (others => 0.0);
      Position     : Vector3 := (others => 0.0);
      Pressure     : Field := 0.0;
   end record;

   procedure Decode (Bytes : Adaflight.Bytes.Byte_Array; P : out Packet; Valid : out Boolean)
     with Pre => Bytes'Length = Packet_Size;

   --  Gazebo's plugin sends its IMU in the sensor frame and its attitude
   --  conjugated, with no pressure; the older bridges send yaw rate of the
   --  other sign, the attitude as it is and the pressure.
   type Bridge is (Legacy, Gazebo);

   type Time_Spec is record
      Sec  : Integer_64 range 0 .. 2 ** 40 := 0;
      Nsec : Integer_64 range 0 .. 999_999_999 := 0;
   end record;

   subtype Rate is Long_Float range 0.0 .. 2.1E7;

   type State is record
      Last_Timestamp : Field := 0.0;
      Last_Realtime  : Unsigned_64 := 0;
      Last_Time      : Time_Spec;
      Origin_Lat     : Field := 0.0;
      Origin_Lon     : Field := 0.0;
      Origin_Set     : Boolean := False;
      Sim_Rate       : Rate := 1.0;
   end record;

   type Outcome is (Timeout, Stale, Update);
   type Axes is array (1 .. 3) of Integer_16;
   type Quaternion is array (1 .. 4) of Float;

   type GPS_Fix is record
      Lat, Lon, Alt_Cm               : Integer_32 := 0;
      Ground_Speed, Speed_3D, Course : Unsigned_16 := 0;
      Vel_North, Vel_East, Vel_Down  : Integer_16 := 0;
   end record;

   --  The virtual GPS's fixed solution fields.
   Satellites      : constant := 12;
   H_Accuracy      : constant := 500;
   V_Accuracy      : constant := 500;
   Speed_Accuracy  : constant := 400;
   Position_DOP    : constant := 10;
   Temperature     : constant := 2500;

   type Feed is record
      Kind     : Outcome := Stale;
      Acc      : Axes := (others => 0);
      Gyro     : Axes := (others => 0);
      Mag      : Axes := (others => 0);
      Pressure : Integer_32 := 0;
      Attitude : Quaternion := (others => 0.0);
      GPS_Set  : Boolean := False;
      GPS      : GPS_Fix;
   end record;

   --  One packet: a packet more than 500 ms of host time after the last
   --  restarts the timing and asks for a motor update, an older one than the
   --  last is stale, and any other feeds the sensors, the attitude and the
   --  GPS. Now_Us is the host clock at the packet, End_Us after its update and
   --  Now the monotonic time the rate is measured with.
   procedure Step (S : in out State; P : Packet; B : Bridge; Now_Us, End_Us : Unsigned_64; Now : Time_Spec;
                   F : out Feed);

end Adaflight.Sim_FDM;
