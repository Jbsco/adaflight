--  The rangefinder on a UART: a Benewake TF lidar on the port the
--  rangefinder setting names, found at the start, and the rangefinder task,
--  which reads its frames and turns the distance into an altitude with the
--  craft's tilt.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.STM32.USART;
package Adaflight.STM32.Rangefinder is
   --  The lidar the rangefinder hardware setting names, on its UART at
   --  115200 baud, and the filter on the range and cone it reports.
   procedure Init (Config : Adaflight.Config_Groups.Configuration);
   --  Whether a rangefinder was found, the task period it asks for, and
   --  whether it holds a UART.
   function Detected return Boolean;
   function Period_Ms return Natural;
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  The task's two steps: the frames read, then the reading filtered and
   --  tilted into an altitude with the cosine of the craft's tilt.
   procedure Update;
   procedure Process (Now_Us : Interfaces.Unsigned_32; Cos_Tilt : Float);
   --  The last altitude in centimetres, or the out of range or failure code.
   function Altitude_Cm return Interfaces.Integer_32;
end Adaflight.STM32.Rangefinder;
