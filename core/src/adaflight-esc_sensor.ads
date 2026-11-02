--  The ESC telemetry over one serial line: a ten byte frame per motor on
--  request with its checksum, the readings it fills, the polling that asks
--  each motor in turn after a boot delay and gives up on a reply after a
--  timeout, the data age that grows on a failed or missing reply, and the
--  combined reading over every motor.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Clock;
with Adaflight.Mixer;

package Adaflight.ESC_Sensor with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Motor_Index is Adaflight.Mixer.Motor_Index;
   subtype Motor_Count is Adaflight.Mixer.Motor_Count;
   subtype Time_Us is Adaflight.Clock.Time_Us;

   Data_Invalid       : constant Unsigned_8 := 255;
   Boot_Time_Ms       : constant := 5_000;
   Request_Timeout_Ms : constant := 100;
   Frame_Size         : constant := 10;
   Frame_Polynomial   : constant Byte := 16#07#;

   --  Temperature in degrees, voltage in hundredths of a volt, current in
   --  hundredths of an ampere, consumption in milliampere hours, and the
   --  electrical rate in hundreds of revolutions per minute. The age counts
   --  the replies missed since the reading, 255 for none yet.
   --  The serial frames carry sixteen bit values; an outside source may give
   --  more, within a range whose sum over every motor still fits.
   subtype Summed_Value is Integer_32 range -2 ** 27 .. 2 ** 27;

   type Reading is record
      Data_Age    : Unsigned_8 := 0;
      Temperature : Unsigned_8 := 0;
      Voltage     : Unsigned_16 := 0;
      Current     : Integer_32 := 0;
      Consumption : Integer_32 := 0;
      Rpm         : Integer_16 := 0;
   end record;

   function Summable (R : Reading) return Boolean is
     (R.Current in Summed_Value and then R.Consumption in Summed_Value);

   type Readings is array (Motor_Index) of Reading;

   type Trigger_State is (Startup, Ready, Pending);

   subtype Frame_Fill is Natural range 0 .. Frame_Size;
   subtype Frame_Index is Natural range 0 .. Frame_Size - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;

   --  What a polling pass wrote where upstream records a debug value: a
   --  frame decoded and its motor, a reply timed out, a checksum failed.
   type Debug_Taps is record
      Frame_Decoded   : Boolean := False;
      Frame_Motor     : Motor_Index := 0;
      Timed_Out       : Boolean := False;
      Checksum_Failed : Boolean := False;
   end record;

   type Sensor is record
      Data            : Readings;
      Frame           : Frame_Bytes := (others => 0);
      Position        : Frame_Fill := 0;
      Size            : Frame_Fill := 0;
      State           : Trigger_State := Startup;
      Trigger_Time_Ms : Unsigned_32 := 0;
      Motor           : Motor_Index := 0;
      Combined        : Reading;
      Combined_Stale  : Boolean := True;
      --  Replies timed out and checksums failed, counted by the recorder
      --  while its mode is selected, as upstream counts inside its write.
      Timeouts        : Unsigned_16 := 0;
      Checksum_Errors : Unsigned_16 := 0;
      Taps            : Debug_Taps;
   end record
     with Dynamic_Predicate => Sensor.Position <= Sensor.Size
       and then (for all M in Motor_Index => Summable (Sensor.Data (M)));

   --  Marks every reading as not yet received.
   procedure Init (E : in out Sensor)
     with Post => (for all M in Motor_Index => E.Data (M).Data_Age = Data_Invalid);

   --  One byte from the line, kept until the frame in flight is complete.
   procedure Receive (E : in out Sensor; C : Byte);

   function Frame_Complete (E : Sensor) return Boolean is (E.Position = E.Size);

   --  The frame checksum over the first nine bytes.
   function Checksum (F : Frame_Bytes) return Byte;

   --  One pass of the polling: the boot delay, then a request for the
   --  motor in turn (Request set, the motor in E.Motor), then the reply
   --  decoded when complete, aged on a bad checksum or on the timeout.
   procedure Process (E : in out Sensor; Now : Time_Us; Count : Motor_Count; Motors_Enabled : Boolean;
                      Request : out Boolean);

   --  The reading over every motor in the count: the oldest age, the
   --  highest temperature, the average voltage and rate, the summed current
   --  and consumption, cached until a reading changes.
   procedure Combined_Reading (E : in out Sensor; Count : Motor_Count; R : out Reading);

   --  A reading from another source replaces the motor's reading at age zero.
   procedure Set_External (E : in out Sensor; M : Motor_Index; R : Reading)
     with Pre  => Summable (R),
          Post => E.Data (M).Data_Age = 0;

   procedure External_Age (E : in out Sensor; M : Motor_Index);

end Adaflight.ESC_Sensor;
