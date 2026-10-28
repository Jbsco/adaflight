--  The receiver link of the board: the serial receiver port the stored
--  configuration assigns with the CRSF, SBUS, IBUS, SUMD, Spektrum, XBUS,
--  FPORT, Ghost or Jeti EX Bus protocol over it, the receiver's channel
--  processing, the failsafe's link state, and the CRSF telemetry sent back
--  on the port with its speed negotiation and the MSP requests answered, on
--  its two pins or, apart from CRSF, on its transmit pin alone, which Ghost
--  and EX Bus always take, the Ghost telemetry with its MSP requests
--  answered in the receiver's quiet window, the EX Bus telemetry answering
--  the receiver's requests, and the SmartPort telemetry in the FPORT reply
--  window, and the CRSF display port the menu draws on for the transmitter.
--  The other serial receiver protocols wait for their drivers.
with Interfaces;
with Adaflight.Bytes;
with Adaflight.Config_Groups;
with Adaflight.CRSF_Display_Port;
with Adaflight.CRSF_Telemetry;
with Adaflight.Failsafe;
with Adaflight.GHST_Telemetry;
with Adaflight.Jeti_Telemetry;
with Adaflight.Receiver;
with Adaflight.SmartPort_Telemetry;
with Adaflight.STM32.USART;
package Adaflight.STM32.Radio is
   subtype Time_Us is Interfaces.Unsigned_32;
   subtype Time_Ms is Interfaces.Unsigned_32;
   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms; Telemetry : Adaflight.CRSF_Telemetry.Config);
   --  One run of the telemetry task: the negotiation, then the next chunk of
   --  a reply to the link's MSP requests, whose commands go through Answer,
   --  or else the frames due from the sources, sent on the port. Answer
   --  returns the reply's payload in Reply up to Length, and Failed for an
   --  error verdict.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
   procedure Telemetry_Step (Now_Us : Time_Us; Src : Adaflight.CRSF_Telemetry.Sources);
   --  The Ghost telemetry's schedule, with the telemetry feature on and a
   --  Ghost link open, and one run of it in the telemetry task: the next
   --  chunk of an MSP reply while no frame waits, or else the next frame
   --  due, held until the receiver's quiet window.
   procedure Init_GHST_Telemetry (Settings : Adaflight.GHST_Telemetry.Settings; Feature_On : Boolean);
   procedure GHST_Telemetry_Step (Inp : Adaflight.GHST_Telemetry.Inputs);
   --  The EX Bus telemetry's sensors, with the telemetry feature on and an
   --  EX Bus link open, and one run of it in the telemetry task: the answer
   --  to a fresh telemetry request, sent on the bus.
   procedure Init_Jeti_Telemetry (Settings : Adaflight.Jeti_Telemetry.Settings; Feature_On : Boolean);
   procedure Jeti_Telemetry_Step (Inp : Adaflight.Jeti_Telemetry.Inputs; Now_Us : Time_Us);
   --  Whether a serial receiver port is open, and whether it speaks CRSF.
   function Linked return Boolean;
   function Is_CRSF return Boolean;
   --  The SmartPort tables an FPORT receiver's telemetry answers from, built
   --  when the receiver opened, and whether an FPORT receiver is open, which
   --  keeps the SmartPort telemetry off its own port.
   procedure Init_FPort_Telemetry (Sensors : Adaflight.SmartPort_Telemetry.Build_Inputs);
   function Is_FPort return Boolean;
   --  The CRSF display port's screen size and the draws the menu makes on it.
   function Display_Columns return Interfaces.Unsigned_8;
   function Display_Rows return Interfaces.Unsigned_8;
   procedure Display_Grab;
   procedure Display_Release (Now_Ms : Time_Ms);
   procedure Display_Clear (Now_Ms : Time_Ms);
   procedure Display_Write (Col, Row : Interfaces.Unsigned_8; Text : String);
   procedure Display_Write_Char (Col, Row : Interfaces.Unsigned_8; C : Interfaces.Unsigned_8);
   --  The display port command the last received frames left, run with the
   --  arming, whether the menu is open and whether the display is
   --  registered: what it asks of the menu system.
   procedure Display_Command
     (Now_Ms : Time_Ms; Armed, In_Menu, Registered : Boolean;
      Request : out Adaflight.CRSF_Display_Port.Menu_Request);
   --  The menu opened on the display, which holds the transfer back, and the
   --  menu's state the transfer waits on: open, and on this display.
   procedure Display_Opened (Now_Ms : Time_Ms);
   procedure Set_Menu_State (In_Menu, Current : Boolean);
   --  Whether the receiver link holds a UART.
   function Holds (N : Adaflight.STM32.USART.Number) return Boolean;
   --  After the realtime tasks: the bytes received through the protocol at
   --  their arrival times and the frame status when the receiver task is not
   --  past its check, while a link is open, then the receiver's frame check,
   --  which processes the signal's loss without a link.
   procedure Frame_Check (Now_Us : Time_Us; Delta_Us : Interfaces.Integer_32; Task_In_Progress : Boolean);
   --  The receiver task's check function.
   function Update_Check (Task_In_Progress : Boolean) return Boolean;
   --  The receiver task's check step: a Ghost frame's processing with its
   --  MSP request through Answer, an FPORT reply window with the SmartPort
   --  values, then the channels calculated with the failsafe told what they
   --  were worth, then the RSSI; Processed says the task moves on.
   generic
      with procedure Answer (Command : Interfaces.Unsigned_16; Request : Adaflight.Bytes.Byte_Array;
                             Reply : out Adaflight.Bytes.Byte_Array; Length : out Natural; Failed : out Boolean);
      with function SmartPort_Values return Adaflight.SmartPort_Telemetry.Inputs;
   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; ADC_Sample : Natural; Processed : out Boolean)
     with Pre => ADC_Sample <= 4_095;
   --  Whether the RSSI comes from the analog input, and the RSSI.
   function RSSI_ADC return Boolean;
   function RSSI return Interfaces.Unsigned_16;
   --  The link's quality readings: the RSSI as a percentage, the RSSI in
   --  dBm, the signal to noise ratio, the link quality raw and as a
   --  percentage, its source, the RF mode, the uplink power and the active
   --  antenna.
   function RSSI_Percent return Interfaces.Unsigned_8;
   function RSSI_Dbm return Interfaces.Integer_16;
   function RSNR return Interfaces.Integer_16;
   function Link_Quality return Interfaces.Unsigned_16;
   function Link_Quality_Percent return Interfaces.Unsigned_16;
   function Link_Source return Adaflight.Receiver.Link_Quality_Source;
   function RF_Mode return Natural;
   function Uplink_Power_mW return Interfaces.Unsigned_16;
   function Active_Antenna return Interfaces.Integer_8;
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
