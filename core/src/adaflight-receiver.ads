--  The receiver: the channel values the active provider delivers, mapped
--  into flight order and the flight channels scaled through their
--  calibration; the pulse validity against the configured limits, the signal
--  watched for a lost link, the flight channels held at their last good
--  value for 300 milliseconds and then at their failsafe settings, and the
--  failsafe switch's stage one values; the link quality from the frame
--  flags; and the RSSI from an aux channel, the frame errors, the analog
--  input, the protocol, or the configurator, with its smoothing.
with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;
with Adaflight.Filters;
with Adaflight.Modes;

package Adaflight.Receiver with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Ms is Unsigned_32;
   subtype Time_Delta is Integer_32;

   Channel_Count : constant := 18;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   Flight_Channel_Count : constant := 4;
   subtype Flight_Channel is Channel range 0 .. Flight_Channel_Count - 1;
   Roll     : constant Flight_Channel := 0;
   Pitch    : constant Flight_Channel := 1;
   Yaw      : constant Flight_Channel := 2;
   Throttle : constant Flight_Channel := 3;
   Mappable_Count : constant := 8;
   subtype Mappable_Channel is Channel range 0 .. Mappable_Count - 1;
   type Channel_Map is array (Mappable_Channel) of Channel;
   Averaged_Count : constant := 12;
   subtype Averaged_Channel is Channel range 0 .. Averaged_Count - 1;

   Pulse_Min : constant := 750;
   Pulse_Max : constant := 2250;
   subtype Pulse_Us is Natural range Pulse_Min .. Pulse_Max;
   subtype Raw_Value is Float range 0.0 .. 65_535.0;
   type Raw_Values is array (Channel) of Raw_Value;

   --  A calibration range inverts the channel when its low end is above its
   --  high end; equal ends would scale by an infinite factor (DESIGN.md D40).
   type Range_Config is record
      Low  : Pulse_Us := 1000;
      High : Pulse_Us := 2000;
   end record
     with Dynamic_Predicate => Range_Config.Low /= Range_Config.High;
   type Range_Configs is array (Flight_Channel) of Range_Config;

   Max_Failsafe_Step : constant := (Pulse_Max - Pulse_Min) / 25;
   subtype Failsafe_Step is Natural range 0 .. Max_Failsafe_Step;
   type Failsafe_Mode is (Auto, Hold, Set, Invalid);
   type Failsafe_Channel is record
      Mode : Failsafe_Mode := Auto;
      Step : Failsafe_Step := 0;
   end record;
   type Failsafe_Channels is array (Channel) of Failsafe_Channel;

   type Provider is (None, Parallel_PWM, PPM, Serial, MSP, SPI, UDP);
   type RSSI_Source is (None, ADC, Rx_Channel, Rx_Protocol, MSP, Frame_Errors, Protocol_CRSF, Protocol_Mavlink);
   type Link_Quality_Source is (None, CRSF, GHST, Mavlink);

   type Settings is record
      Source            : Provider := None;
      Reported_Channels : Natural range 0 .. Channel_Count := 0;
      Map               : Channel_Map := (0, 1, 3, 2, 4, 5, 6, 7);
      Ranges            : Range_Configs;
      Failsafe          : Failsafe_Channels;
      Min_Usec          : Pulse_Us := 885;
      Max_Usec          : Pulse_Us := 2115;
      Mid_RC            : Natural range 1200 .. 1700 := 1500;
      Max_Aux           : Natural range 0 .. Channel_Count - Flight_Channel_Count := 14;
      RSSI_ADC          : Boolean := False;
      RSSI_Channel      : Natural range 0 .. Channel_Count := 0;
      RSSI_Scale        : Natural range 1 .. 255 := 100;
      RSSI_Offset       : Integer range -100 .. 100 := 0;
      RSSI_Invert       : Boolean := False;
      RSSI_Smoothing    : Natural range 0 .. 255 := 125;
      Frame_LPF_Period  : Natural range 1 .. 255 := 30;
      Feature_3D        : Boolean := False;
      Switched_Mode_3D  : Boolean := False;
      Failsafe_Throttle : Natural range 1000 .. 2000 := 1000;
   end record;

   type Values is array (Channel) of Signal;
   type Timeouts is array (Channel) of Time_Ms;

   subtype Sample is Integer range -32_768 .. 32_767;
   Sample_Window : constant := 3;
   type Samples is array (0 .. Sample_Window - 1) of Sample;
   type Channel_Samples is array (Averaged_Channel) of Samples;
   type Channel_Means is array (Averaged_Channel) of Sample;

   type Scaler is record
      Scale  : Float range -1_000.0 .. 1_000.0 := 1.0;
      Offset : Float range -2.5e6 .. 2.5e6 := 0.0;
   end record;
   type Scalers is array (Flight_Channel) of Scaler;

   subtype Unsigned_16 is Natural range 0 .. 65_535;
   subtype Signed_16 is Integer range -32_768 .. 32_767;
   subtype Byte is Natural range 0 .. 255;
   subtype Antenna_Index is Integer range -128 .. 127;
   subtype ADC_Count is Natural range 0 .. 4_095;
   RSSI_Max : constant := 1_023;
   Link_Quality_Max : constant := 1_023;
   Link_Quality_Samples : constant := 16;
   type Quality_Samples is array (0 .. Link_Quality_Samples - 1) of Unsigned_16;

   type State is record
      Raw                 : Values := (others => 0.0);
      Data                : Values := (others => 1500.0);
      Valid_Until_Ms      : Timeouts := (others => 0);
      Processing_Required : Boolean := False;
      Aux_Required        : Boolean := False;
      Signal_Received     : Boolean := False;
      Flight_Valid        : Boolean := False;
      Channels            : Natural range 0 .. Channel_Count := 0;
      Need_Signal_Before  : Time_Us := 0;
      Suspend_Until       : Time_Us := 0;
      Skip_Samples        : Natural range 0 .. 255 := 0;
      Sample_Index        : Natural range 0 .. 255 := 0;
      Window              : Channel_Samples := (others => (others => 0));
      Means               : Channel_Means := (others => 0);
      Samples_Collected   : Boolean := False;
      Scales              : Scalers := (others => <>);
      RSSI                : Unsigned_16 := 0;
      RSSI_Raw            : Unsigned_16 := 0;
      RSSI_Dbm            : Signed_16 := -130;
      RSSI_Dbm_Raw        : Signed_16 := -130;
      RSNR                : Signed_16 := -30;
      RSNR_Raw            : Signed_16 := -30;
      Active_Antenna      : Integer range -128 .. 127 := 0;
      Last_Smoothing_Us   : Time_Us := 0;
      Last_MSP_RSSI_Us    : Time_Us := 0;
      Frame_Error_Filter  : Filters.PT1;
      RSSI_Filter         : Filters.PT1;
      RSSI_Dbm_Filter     : Filters.PT1;
      RSNR_Filter         : Filters.PT1;
      Link_Quality        : Unsigned_16 := 0;
      RF_Mode             : Natural range 0 .. 255 := 0;
      Uplink_Power_mW     : Unsigned_16 := 0;
      Quality_Window      : Quality_Samples := (others => 0);
      Quality_Index       : Natural range 0 .. Link_Quality_Samples - 1 := 0;
      Quality_Sum         : Unsigned_16 := 0;
      Frame_RSSI_Sum      : Unsigned_16 := 0;
      Frame_RSSI_Count    : Unsigned_16 := 0;
      Resample_Us         : Time_Delta := 0;
      ADC_Update_At_Us    : Time_Us := 0;
      RSSI_From           : RSSI_Source := None;
      Quality_From        : Link_Quality_Source := None;
   end record;

   --  The frame the provider reports: the flags of a serial-class frame, or
   --  the data-received signals of the pulse receivers.
   type Frame_Report is record
      Complete            : Boolean := False;
      Failsafe            : Boolean := False;
      Processing_Required : Boolean := False;
      Dropped             : Boolean := False;
      PPM_Received        : Boolean := False;
      PWM_Received        : Boolean := False;
   end record;

   type Validity is (No_Report, Data_Received, Data_Failed);

   --  The channels start at the center, the throttle at its minimum, the
   --  scalers come from the ranges, the RSSI source is the analog input, the
   --  channel, or else the source a protocol claimed, and the filters come
   --  from their settings.
   procedure Init (
      S                : out State;
      C                : Settings;
      Now_Ms           : Time_Ms;
      Protocol_RSSI    : RSSI_Source;
      Protocol_Quality : Link_Quality_Source
   );

   --  The arming switch's aux channel starts just outside its range.
   procedure Init_Arm_Switch (S : in out State; Aux : Modes.Aux_Channel; Span : Modes.Channel_Range)
     with Pre => Modes.Usable (Span);

   function Receiving_Signal (S : State) return Boolean is (S.Signal_Received);
   function Flight_Channels_Valid (S : State) return Boolean is (S.Flight_Valid);

   --  The receiver task's check: a packet is being processed, or data or
   --  an auxiliary frame waits.
   function Update_Check (S : State; Task_In_Progress : Boolean) return Boolean is
     (Task_In_Progress or else S.Processing_Required or else S.Aux_Required);

   --  A suspended pulse receiver skips two samples and waits 1.5 seconds; the
   --  caller tells the failsafe of the suspension and the resumption.
   procedure Suspend (S : in out State; C : Settings; Now_Us : Time_Us);
   procedure Resume (S : in out State; C : Settings; Now_Us : Time_Us);

   --  The frame check of each scheduler pass: a received frame marks the
   --  signal and the data to process; silence past the trigger interval
   --  drops the signal and asks for the loss to be processed, then rechecks
   --  every 50 milliseconds.
   procedure Frame_Check (
      S                : in out State;
      C                : Settings;
      Now_Us           : Time_Us;
      Delta_Us         : Time_Delta;
      Task_In_Progress : Boolean;
      Frame            : Frame_Report
   );

   --  The receiver task: the auxiliary frame processed first, then, when
   --  data waits and no samples are skipped, the raw channels read, mapped,
   --  and scaled, and the signal loss behaviour applied; Valid says what the
   --  caller tells the failsafe.
   procedure Calculate_Channels (
      S               : in out State;
      C               : Settings;
      Now_Us          : Time_Us;
      Now_Ms          : Time_Ms;
      Raw             : Raw_Values;
      Box_Failsafe    : Boolean;
      Box_3D          : Boolean;
      Failsafe_Active : Boolean;
      Processed       : out Boolean;
      Frame_Processed : out Boolean;
      Valid           : out Validity
   );

   procedure Set_RSSI_Direct (S : in out State; Value : Unsigned_16; Source : RSSI_Source);
   procedure Set_RSSI (S : in out State; Value : Unsigned_16; Source : RSSI_Source);
   procedure Set_RSSI_MSP (S : in out State; Value : Byte; Now_Us : Time_Us);
   procedure Set_RSSI_Dbm (S : in out State; Value : Signed_16; Source : RSSI_Source);
   procedure Set_RSSI_Dbm_Direct (S : in out State; Value : Signed_16; Source : RSSI_Source);
   procedure Set_RSNR (S : in out State; Value : Signed_16);
   procedure Set_RSNR_Direct (S : in out State; Value : Signed_16);
   procedure Set_Link_Quality_Direct (S : in out State; Value : Unsigned_16);
   procedure Set_RF_Mode (S : in out State; Value : Byte);
   procedure Set_Uplink_Power (S : in out State; Value : Unsigned_16);
   procedure Set_Active_Antenna (S : in out State; Antenna : Antenna_Index);

   --  The RSSI task: the channel, the analog input every 20 milliseconds,
   --  or the configurator's timeout, then the smoothing of the RSSI, the
   --  dBm, and the SNR toward their raw values.
   procedure Update_RSSI (S : in out State; C : Settings; Now_Us : Time_Us; ADC_Sample : ADC_Count);

   --  The RSSI as reported: inverted, scaled, and offset, held at zero where
   --  the reference's conversion of a negative value is undefined.
   function RSSI (S : State; C : Settings) return Unsigned_16;
   function RSSI_Percent (S : State; C : Settings) return Byte;
   function RSSI_Configured (S : State) return Boolean is (S.RSSI_From /= None);
   function Link_Quality_Percent (S : State) return Unsigned_16;

end Adaflight.Receiver;
