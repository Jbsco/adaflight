--  The ExpressLRS receiver: the over-the-air packets validated by their
--  14-bit CRC and decoded into channels, sync and bind data and MSP chunks,
--  the telemetry response assembled from the link statistics or the sender's
--  chunk, the hop and telemetry slot requests, the phase lock on the timer
--  with its tick and tock periods, the connection states with the rate
--  cycling, and the link statistics and configuration updates. The radio,
--  the timer hardware, the bind button and the LEDs stay with the target,
--  which carries out the requests the receiver records.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Filters;
with Adaflight.ExpressLRS;
with Adaflight.ExpressLRS_Telemetry;

package Adaflight.ExpressLRS_Receiver with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Adaflight.ExpressLRS.Band;
   use type Adaflight.ExpressLRS.Frequency_Domain;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Integer_32 is Interfaces.Integer_32;
   subtype Rate_Index is Adaflight.ExpressLRS.Rate_Index;

   Packet_Size   : constant := 8;
   Channel_Count : constant := 16;
   subtype Packet is Byte_Array (0 .. Packet_Size - 1);
   subtype Channel_Index is Natural range 0 .. Channel_Count - 1;
   type Channels is array (Channel_Index) of Unsigned_16;
   subtype UID_Bytes is Byte_Array (0 .. 5);

   --  The frequency domain, the air rate, the unique id (all zero to bind)
   --  and the model id of the configuration, which the receiver writes back
   --  on a connection, a bind and a model id from the transmitter.
   type Settings is record
      Domain   : Adaflight.ExpressLRS.Frequency_Domain := Adaflight.ExpressLRS.ISM2400;
      Rate     : Rate_Index := 0;
      UID      : UID_Bytes := (others => 0);
      Model_Id : Byte := 255;
   end record;

   --  A rate is within its band's table.
   function Rate_Valid (D : Adaflight.ExpressLRS.Frequency_Domain; R : Rate_Index) return Boolean is
     (Adaflight.ExpressLRS.Band_Of (D) = Adaflight.ExpressLRS.Band_2400 or else R <= 3);

   type Connection_State is (Connected, Tentative, Disconnected, Disconnect_Pending);
   type Timer_State is (Timer_Disconnected, Timer_Tentative, Timer_Locked);
   type Packet_Status is (None, Bind, Data);
   type Telemetry_Type is (Link, Data);

   --  The radio configuration the receiver asks for.
   type Radio_Config is record
      Bandwidth      : Byte := 0;
      Spreading      : Byte := 0;
      Coding         : Byte := 0;
      Frequency      : Unsigned_32 := 0;
      Preamble       : Byte := 0;
      IQ_Inverted    : Boolean := False;
      FLRC_Sync_Word : Unsigned_32 := 0;
      FLRC_CRC_Seed  : Unsigned_16 := 0;
      Is_FLRC        : Boolean := False;
   end record;

   --  The timer the receiver drives: its half-period alternates between the
   --  tick and the tock, with the frequency offset in ticks and the phase
   --  shift the lock asks for; the period and the time base it last
   --  programmed are what the target applies.
   type Tick_Tock is (Tick, Tock);
   subtype Interval_Us is Natural range 1 .. 65_535;
   type Timer is record
      Running                : Boolean := False;
      Phase                  : Tick_Tock := Tock;
      Interval               : Interval_Us := 20_000;
      Frequency_Offset_Ticks : Integer_32 := 0;
      Phase_Shift_Us         : Integer_32 := 0;
      Period                 : Unsigned_32 := 0;
      Max_Period             : Natural := 0;
      Period_Count           : Unsigned_32 := 0;
      Counter_Resets         : Unsigned_32 := 0;
   end record;

   --  The two timestamps the phase lock compares: the timer's tock and the
   --  packet's arrival.
   type Event_Pair is record
      Internal_Us   : Unsigned_32 := 0;
      External_Us   : Unsigned_32 := 0;
      Internal_Seen : Boolean := False;
      External_Seen : Boolean := False;
   end record;

   subtype Offset_Us is Integer_32 range -16_384 .. 16_384;
   type Phase_Lock is record
      Offset_Filter          : Adaflight.Filters.Simple_Lowpass;
      Offset_Dx_Filter       : Adaflight.Filters.Simple_Lowpass;
      Raw_Offset_Us          : Offset_Us := 0;
      Previous_Raw_Offset_Us : Offset_Us := 0;
      Offset_Us              : Integer_32 := 0;
      Offset_Delta_Us        : Adaflight.Filters.Simple_Input := 0;
   end record;

   --  The mean of the signal to noise samples between telemetry responses,
   --  held at its bounds the reference overruns after 2 ** 24 packets.
   Mean_Samples_Max : constant := 2 ** 24 - 1;
   subtype Mean_Count is Natural range 0 .. Mean_Samples_Max;
   type Mean_Accumulator is record
      Sum   : Integer_32 := 0;
      Count : Mean_Count := 0;
   end record
     with Dynamic_Predicate =>
       Mean_Accumulator.Sum in -(128 * Integer_32 (Mean_Accumulator.Count))
                            .. 127 * Integer_32 (Mean_Accumulator.Count);

   subtype MSP_Buffer is Adaflight.ExpressLRS_Telemetry.MSP_Buffer;

   --  Packets per telemetry packet: one for no telemetry, 128 down to 2.
   subtype Telemetry_Denominator is Byte range 1 .. 128;

   --  The receiver's state as the reference keeps it, with the file-level
   --  state beside it and the requests and reports the target reads.
   type Receiver is record
      Domain                   : Adaflight.ExpressLRS.Frequency_Domain := Adaflight.ExpressLRS.ISM2400;
      Freq_Offset              : Integer_32 := 0;
      Current_Freq             : Unsigned_32 := 0;
      Nonce                    : Byte := 0;
      Rate                     : Rate_Index := 0;
      Next_Rate                : Rate_Index := 0;
      Binding_Rate             : Rate_Index := 0;
      UID                      : UID_Bytes := (others => 0);
      RSSI                     : Integer_8 := 0;
      SNR                      : Integer_8 := 0;
      RSSI_Filtered            : Integer_8 := 0;
      RSNR_Filtered            : Integer_8 := 0;
      Uplink_LQ                : Byte := 0;
      Already_FHSS             : Boolean := False;
      Already_Telem_Resp       : Boolean := False;
      Lock_RF_Mode             : Boolean := False;
      Started                  : Boolean := False;
      Timer_St                 : Timer_State := Timer_Disconnected;
      Connection               : Connection_State := Disconnected;
      RF_Mode_Cycle_Multiplier : Byte := 0;
      Cycle_Interval_Ms        : Unsigned_16 := 0;
      RF_Mode_Cycled_At_Ms     : Unsigned_32 := 0;
      Switch_Mode              : Byte := 0;
      Got_Connection_Ms        : Unsigned_32 := 0;
      Last_Sync_Packet_Ms      : Unsigned_32 := 0;
      Last_Valid_Packet_Ms     : Unsigned_32 := 0;
      Config_Checked_At_Ms     : Unsigned_32 := 0;
      Stats_Updated_At_Ms      : Unsigned_32 := 0;
      Config_Changed           : Boolean := False;
      In_Binding_Mode          : Boolean := False;
      Initialize_Pending       : Boolean := False;
      CRC_Initializer          : Unsigned_16 := 0;
      Model_Match              : Boolean := False;
      Tx_Power                 : Byte := 0;
      Wide_Switch_Index        : Natural range 0 .. 7 := 0;
      Tlm_Denom                : Telemetry_Denominator := 1;
      RSSI_Filter              : Adaflight.Filters.Simple_Lowpass;
      RSNR_Filter              : Adaflight.Filters.Simple_Lowpass;
      SNR_Mean                 : Mean_Accumulator;
      Telemetry_Packet         : Packet := (others => 0);
      Packet_St                : Packet_Status := None;
      Events                   : Event_Pair;
      Lock                     : Phase_Lock;
      Next_Telemetry           : Telemetry_Type := Link;
      Burst_Count              : Byte := 1;
      Burst_Max                : Byte := 1;
      Burst_Valid              : Boolean := False;
      Lost_Connections         : Unsigned_16 := 0;
      Hops                     : Adaflight.ExpressLRS.Hopping;
      LQ                       : Adaflight.ExpressLRS.Link_Quality;
      Sender                   : Adaflight.ExpressLRS_Telemetry.Sender;
      MSP                      : Adaflight.ExpressLRS_Telemetry.Receiver;
      Timing                   : Timer;
      Config                   : Radio_Config;
      Config_Count             : Unsigned_32 := 0;
      Start_Count              : Unsigned_32 := 0;
      Power_Count              : Unsigned_32 := 0;
      RF_Mode_Report           : Byte := 0;
      RSSI_Report              : Unsigned_16 := 0;
      RSSI_Direct              : Boolean := False;
      RSSI_Dbm_Report          : Integer_16 := 0;
      RSNR_Report              : Integer_16 := 0;
      LQ_Report                : Byte := 0;
      Uplink_Power_Report      : Unsigned_16 := 0;
      Report_Count             : Unsigned_32 := 0;
      Save_Count               : Unsigned_32 := 0;
      MSP_Ready_Count          : Unsigned_32 := 0;
      MSP_Frame                : MSP_Buffer := (others => 0);
   end record
     with Dynamic_Predicate =>
       Rate_Valid (Receiver.Domain, Receiver.Rate) and then Rate_Valid (Receiver.Domain, Receiver.Next_Rate)
       and then Rate_Valid (Receiver.Domain, Receiver.Binding_Rate);

   --  The receiver set up from the settings at the time given: binding when
   --  the unique id is all zero, the timer stopped, the radio configured for
   --  the rate.
   procedure Init (R : out Receiver; C : Settings; Now_Ms : Unsigned_32)
     with Pre => Rate_Valid (C.Domain, C.Rate);

   --  A packet from the radio with its arrival time and the radio's signal
   --  readings: validated, decoded by its type, copied to the payload when it
   --  carries channels, and counted in the link quality.
   procedure Process_Packet (R : in out Receiver; C : in out Settings; P : Packet; Time_Stamp_Us : Unsigned_32;
                             Now_Ms : Unsigned_32; RSSI, SNR : Integer_8; Payload : in out Packet;
                             Status : out Packet_Status)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain;

   --  Whether the next packet is on a new channel, with the channel taken.
   procedure Hop_Required (R : in out Receiver; Required : out Boolean);

   --  Whether this slot carries a telemetry response.
   function Telemetry_Response_Required (R : Receiver) return Boolean;

   --  The telemetry slot: the next frame the target offers starts in the
   --  sender when it is idle, and the response packet is built.
   procedure Do_Telemetry (R : in out Receiver; Next_Frame : Byte_Array; Has_Next : Boolean)
     with Pre => Next_Frame'Length <= Adaflight.ExpressLRS_Telemetry.Frame_Max;

   --  The timer's overflow: the tick advances the nonce and the link quality
   --  window after the phase lock update, the tock records its time; each
   --  programs the next half-period.
   procedure Timer_Update (R : in out Receiver; C : in out Settings; Now_Us : Unsigned_32)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain;

   --  The receiver task: the delayed start, a pending initialization, a bind
   --  request, the connection, configuration and link statistics updates,
   --  and the packet status since the last call.
   procedure Data_Received (R : in out Receiver; C : in out Settings; Now_Ms : Unsigned_32; System_Ready : Boolean;
                            Bind_Requested : Boolean; Status : out Packet_Status)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain;

   --  The channels from a payload in the current switch mode.
   procedure Set_RC_Data (R : in out Receiver; Payload : Packet; RC : in out Channels);

   --  A started receiver loses its connection.
   procedure Stop (R : in out Receiver; C : in out Settings)
     with Pre => Rate_Valid (C.Domain, C.Rate) and then C.Domain = R.Domain;

end Adaflight.ExpressLRS_Receiver;
