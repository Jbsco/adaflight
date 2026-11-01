--  The MT rangefinder and optical flow bridge on this board: the device the
--  rangefinder hardware setting names, the distance and flow messages MSP
--  brings, and their reads by the rangefinder and optical flow tasks.
with Interfaces;
with Adaflight.Optical_Flow;
with Adaflight.Rangefinder;
package Adaflight.STM32.MT is
   procedure Init (Rangefinder_Hardware : Interfaces.Unsigned_8);
   function Present return Boolean;
   function Delay_Ms return Natural;
   function Max_Range_Cm return Natural;
   procedure Receive_Range (Distance_Mm : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32);
   procedure Receive_Flow
     (Quality : Interfaces.Unsigned_8; Motion_X, Motion_Y : Interfaces.Integer_32; Now_Us : Interfaces.Unsigned_32);
   procedure Read_Range (Distance : out Adaflight.Rangefinder.Reading);
   function Flow_Sample return Adaflight.Optical_Flow.Sample;
end Adaflight.STM32.MT;
