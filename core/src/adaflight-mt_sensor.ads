--  The MT rangefinder and optical flow bridge: an MT device sends its
--  distance and its flow over MSP, and the rangefinder and optical flow
--  readings read them from here. The configured rangefinder hardware picks
--  the device's delay and range. A read hands on a distance within the
--  rangefinder readings' bound, and a flow sample holds its rates within
--  the optical flow readings' bound.
with Interfaces;
with Adaflight.Optical_Flow;
with Adaflight.Rangefinder;

package Adaflight.MT_Sensor with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Optical_Flow.Sample;

   --  The rangefinder hardware values of the MT devices.
   MTF01  : constant := 4;
   MTF02  : constant := 5;
   MTF01P : constant := 6;
   MTF02P : constant := 7;

   Detection_Cone_Decidegrees : constant := 900;
   Flow_Gyro_Delay_Us         : constant := 65_000;
   Flow_Min_Range_Mm          : constant := 80;

   type Device is record
      Present      : Boolean := False;
      Delay_Ms     : Interfaces.Unsigned_8 := 0;
      Max_Range_Cm : Interfaces.Unsigned_16 := 0;
   end record;

   --  The device for a rangefinder hardware value, absent past the MT ones.
   function Detect (Hardware : Interfaces.Unsigned_8) return Device;

   --  The device, the last distance with its time and whether a read took
   --  it yet, and the last flow sample with its validity. The distance's
   --  time starts at the no new data code.
   type State is record
      Conf          : Device;
      Range_New     : Boolean := False;
      Distance_Mm   : Interfaces.Integer_32 := 0;
      Range_Time_Us : Interfaces.Unsigned_32 := 16#FFFF_FFFD#;
      Flow          : Optical_Flow.Sample := (Time_Stamp_Us => 0, Quality => 0, Flow_X => 0.0, Flow_Y => 0.0);
      Range_Valid   : Boolean := False;
      Flow_Valid    : Boolean := False;
      Dt_Valid      : Boolean := False;
   end record;

   --  A rangefinder message: the distance in millimeters, negative out of
   --  range, new as of the time it came.
   procedure Range_Receive (S : in out State; Distance_Mm : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32)
     with Post => S.Range_New and then S.Distance_Mm = Distance_Mm and then S.Range_Time_Us = Now_Us
                  and then S.Conf = S'Old.Conf and then S.Flow = S'Old.Flow;

   --  The rangefinder read: a new distance in centimeters or out of range
   --  for a negative one, then no new data until the next message.
   procedure Range_Read (S : in out State; Distance : out Rangefinder.Reading)
     with Post => not S.Range_New
                  and then (if not S'Old.Range_New then Distance = Rangefinder.No_New_Data
                            elsif S.Distance_Mm < 0 then Distance = Rangefinder.Out_Of_Range
                            else Distance >= 0);

   --  An optical flow message with an MT device detected: the time since
   --  the last sample, valid within a second, gives the rates from the
   --  motion and the quality in percent; the rangefinder's distance and its
   --  age give the range validity, and an invalid range or a stale distance
   --  replaces the quality with its code. Without a device it changes
   --  nothing.
   procedure Flow_Receive
     (S : in out State; Quality : Interfaces.Unsigned_8; Motion_X, Motion_Y : Interfaces.Integer_32;
      Now_Us : Interfaces.Unsigned_32)
     with Post => (if not S'Old.Conf.Present then S = S'Old else S.Flow.Time_Stamp_Us = Now_Us);

end Adaflight.MT_Sensor;
