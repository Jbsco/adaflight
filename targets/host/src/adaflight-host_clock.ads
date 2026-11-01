--  The host image's clock: the real monotonic time scaled by the simulator's
--  rate, as the reference's simulator build scales its microseconds. The
--  rate is one until a simulator link sets it from its packets.
with Interfaces;
package Adaflight.Host_Clock is
   procedure Set_Rate (Rate : Float);
   function Rate return Float;
   --  The scaled nanoseconds since the image started.
   function Elapsed_Ns return Interfaces.Unsigned_64;
end Adaflight.Host_Clock;
