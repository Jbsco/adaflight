with Adaflight.MT_Sensor;
package body Adaflight.STM32.MT is
   State : Adaflight.MT_Sensor.State;

   procedure Init (Rangefinder_Hardware : Interfaces.Unsigned_8) is
   begin
      State := (others => <>);
      State.Conf := Adaflight.MT_Sensor.Detect (Rangefinder_Hardware);
   end Init;

   function Present return Boolean is (State.Conf.Present);
   function Delay_Ms return Natural is (Natural (State.Conf.Delay_Ms));
   function Max_Range_Cm return Natural is (Natural (State.Conf.Max_Range_Cm));

   procedure Receive_Range (Distance_Mm : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32) is
   begin
      Adaflight.MT_Sensor.Range_Receive (State, Distance_Mm, Now_Us);
   end Receive_Range;

   procedure Receive_Flow
     (Quality : Interfaces.Unsigned_8; Motion_X, Motion_Y : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32) is
   begin
      Adaflight.MT_Sensor.Flow_Receive (State, Quality, Motion_X, Motion_Y, Now_Us);
   end Receive_Flow;

   procedure Read_Range (Distance : out Adaflight.Rangefinder.Reading) is
   begin
      Adaflight.MT_Sensor.Range_Read (State, Distance);
   end Read_Range;

   function Flow_Sample return Adaflight.Optical_Flow.Sample is (State.Flow);

end Adaflight.STM32.MT;
