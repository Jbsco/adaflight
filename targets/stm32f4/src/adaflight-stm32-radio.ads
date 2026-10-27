--  The receiver link of the board: the serial receiver port the stored
--  configuration assigns with the CRSF, SBUS, IBUS, SUMD, Spektrum, XBUS or
--  FPORT protocol over it, the receiver's channel processing, the
--  failsafe's link state, and the CRSF telemetry sent back on the port with
--  its speed negotiation, on its two pins or, apart from CRSF, on its
--  transmit pin alone. The other serial receiver protocols and the FPORT
--  telemetry wait for their drivers.
with Interfaces;
with Adaflight.Config_Groups;
with Adaflight.CRSF_Telemetry;
with Adaflight.Failsafe;
with Adaflight.Receiver;
with Adaflight.STM32.USART;
package Adaflight.STM32.Radio is
   subtype Time_Us is Interfaces.Unsigned_32;
   subtype Time_Ms is Interfaces.Unsigned_32;
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms; Telemetry : Adaflight.CRSF_Telemetry.Config);
   --  One run of the telemetry task: the negotiation, then the frames due
   --  from the sources, sent on the port.
   procedure Telemetry_Step (Now_Us : Time_Us; Src : Adaflight.CRSF_Telemetry.Sources);
   --  Whether a serial receiver port is open, and whether it speaks CRSF.
   function Linked return Boolean;
   function Is_CRSF return Boolean;
   --  Whether the receiver link holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  After the realtime tasks: the bytes received through the protocol at
   --  their arrival times and the frame status when the receiver task is not
   --  past its check, while a link is open, then the receiver's frame check,
   --  which processes the signal's loss without a link.
   procedure Frame_Check (Now_Us : Time_Us; Delta_Us : Interfaces.Integer_32; Task_In_Progress : Boolean);
   --  The receiver task's check function.
   function Update_Check (Task_In_Progress : Boolean) return Boolean;
   --  The receiver task's check step: the channels calculated with the
   --  failsafe told what they were worth, then the RSSI; Processed says the
   --  task moves on.
   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; ADC_Sample : Natural; Processed : out Boolean)
     with Pre => ADC_Sample <= 4_095;
   --  Whether the RSSI comes from the analog input, and the RSSI.
   function RSSI_ADC return Boolean;
   function RSSI return Interfaces.Unsigned_16;
   --  The link's quality readings: the RSSI as a percentage, the RSSI in
   --  dBm, the signal to noise ratio, the link quality raw and as a
   --  percentage, its source, the RF mode and the uplink power.
   function RSSI_Percent return Interfaces.Unsigned_8;
   function RSSI_Dbm return Interfaces.Integer_16;
   function RSNR return Interfaces.Integer_16;
   function Link_Quality return Interfaces.Unsigned_16;
   function Link_Quality_Percent return Interfaces.Unsigned_16;
   function Link_Source return Adaflight.Receiver.Link_Quality_Source;
   function RF_Mode return Natural;
   function Uplink_Power_mW return Interfaces.Unsigned_16;
   --  The failsafe's check every ten milliseconds of the realtime block.
   --  The failsafe's check over what it reads in flight; Disarm says its
   --  landed stage asks for a disarm.
   procedure Failsafe_Check
     (Now_Ms : Time_Ms; In_Flight : Adaflight.Failsafe.Inputs; Beep : out Adaflight.Failsafe.Beep;
      Disarm : out Boolean);
   --  The failsafe's own flight mode.
   function Failsafe_Mode return Boolean;
   --  The failsafe's arming disable reasons: the link lost and the failsafe
   --  active.
   function Failsafe_Rx_Loss return Boolean;
   function Failsafe_Blocks_Arming return Boolean;
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
   --  What the flight log reads: the failsafe's phase, whether the flight
   --  channels are valid, and whether an RSSI source is set.
   function Failsafe_Phase return Adaflight.Failsafe.Phase;
   function Flight_Channels_Valid return Boolean;
   function RSSI_Configured return Boolean;
end Adaflight.STM32.Radio;
