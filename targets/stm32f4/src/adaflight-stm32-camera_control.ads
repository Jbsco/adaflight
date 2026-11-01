--  The camera control pin: a key's voltage as a hardware PWM duty on the
--  pin's timer channel, or as a software PWM toggled from the basic timers
--  TIM6 and TIM7, pressed from the sticks and from MSP while disarmed, and
--  idle again once the key delay and the hold have passed.
with Interfaces;
with Adaflight.Camera_Control;
with Adaflight.Config_Groups;
with Adaflight.Scheduler;
package Adaflight.STM32.Camera_Control is
   procedure Init (C : Adaflight.Config_Groups.Configuration);
   function Enabled return Boolean;
   --  A key by its code, held past the key delay for Hold_Ms: nothing while
   --  off or for a code past the keys; a software PWM press blocks for its
   --  wait. OSD_Reset says the OSD's refresh pause ends.
   procedure Key_Press
     (Code : Interfaces.Unsigned_8; Hold_Ms : Adaflight.Camera_Control.Hold_Time; OSD_Reset : out Boolean);
   --  The camera control task: the hardware PWM back to idle once the press
   --  has ended.
   procedure Process (Now_Us : Adaflight.Scheduler.Time_Us);
end Adaflight.STM32.Camera_Control;
