--  The receiver link of the board: the serial receiver port the stored
--  configuration assigns with the CRSF protocol over it, the receiver's
--  channel processing and the failsafe's link state, in the reference's
--  order. The other serial receiver protocols, inverted ports and
--  half-duplex ports wait for their drivers.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.Receiver;
package Adaflight.STM32.Radio is
   subtype Time_Us is Interfaces.Unsigned_32;
   subtype Time_Ms is Interfaces.Unsigned_32;
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms);
   --  Whether a serial receiver port is open.
   function Linked return Boolean;
   --  After the realtime tasks: the bytes received through the protocol at
   --  their arrival times, the frame status when the receiver task is not
   --  past its check, and the receiver's frame check.
   procedure Frame_Check (Now_Us : Time_Us; Delta_Us : Interfaces.Integer_32; Task_In_Progress : Boolean);
   --  The receiver task's check function.
   function Update_Check (Task_In_Progress : Boolean) return Boolean;
   --  The receiver task's check step: the channels calculated with the
   --  failsafe told what they were worth, then the RSSI; Processed says the
   --  task moves on.
   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; Processed : out Boolean);
   --  The failsafe's check every ten milliseconds of the realtime block.
   procedure Failsafe_Check (Now_Ms : Time_Ms);
   --  The failsafe's monitoring, which the arming logic starts.
   procedure Start_Failsafe_Monitoring;
   function Failsafe_Receiving return Boolean;
   function Failsafe_Active return Boolean;
   function Failsafe_Monitoring return Boolean;
   --  The arrival time of the last channel frame.
   function Last_Frame_Us return Time_Us;
   function Channel_Count return Natural;
   function Channel (I : Adaflight.Receiver.Channel) return Float;
   function Receiving return Boolean;
end Adaflight.STM32.Radio;
