--  The CRSF receiver protocol: each serial byte at its arrival time into a
--  frame that restarts after the time a frame needs, the declared length
--  checked, the CRC over the type and the payload, the RC channel frames for
--  the flight controller kept for the status poll and unpacked there as the
--  sixteen packed eleven-bit channels or the subset frame's channels at
--  their resolution, the link statistics into the receiver's RSSI, dBm,
--  SNR, link quality, RF mode, and uplink power with the 250-millisecond
--  timeout, the frame errors that ask for the default speed, and the raw
--  channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.CRSF with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Delta is Interfaces.Integer_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;
   subtype Center_Us is Natural range 1200 .. 1700;
   subtype Skip_Count is Natural range 0 .. 1;

   Channel_Count : constant := 16;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 8_191;
   type Channel_Data is array (Channel) of Channel_Value;

   Frame_Size_Max : constant := 64;
   subtype Frame_Index is Natural range 0 .. Frame_Size_Max - 1;
   subtype Frame_Length is Natural range 0 .. Frame_Size_Max;
   type Frame_Bytes is array (Frame_Index) of Byte;

   Sync_Byte                 : constant := 16#C8#;
   Address_Flight_Controller : constant := 16#C8#;
   Type_Link_Statistics      : constant := 16#14#;
   Type_RC_Channels_Packed   : constant := 16#16#;
   Type_Subset_RC_Channels   : constant := 16#17#;
   Type_Link_Statistics_Tx   : constant := 16#1D#;
   Type_Command              : constant := 16#32#;

   Baudrate              : constant := 420_000;
   Time_Per_Frame_Us     : constant := 1_748;
   Statistics_Timeout_Us : constant := 250_000;
   Error_Threshold       : constant := 3;

   Legacy_Scale : constant Float := 0.62477120195241;

   type State is record
      Frame            : Frame_Bytes := (others => 0);
      Position         : Frame_Length := 0;
      Start_At_Us      : Time_Us := 0;
      Frame_Time_Us    : Time_Delta := Time_Per_Frame_Us;
      Error_Count      : Byte := 0;
      Done             : Boolean := False;
      Channel_Frame    : Frame_Bytes := (others => 0);
      Data             : Channel_Data := (others => 0);
      Scale            : Float range 0.0 .. 1.0 := Legacy_Scale;
      Last_Stats_Us    : Time_Us := 0;
      Last_Frame_Us    : Time_Us := 0;
      Event_Telemetry  : Boolean := False;
   end record;

   --  What a received byte asked of the other units: a command frame for
   --  the flight controller to process from the frame's payload, the default
   --  speed after repeated errors, and a telemetry response to schedule.
   type Byte_Outputs is record
      Command            : Boolean := False;
      Default_Speed      : Boolean := False;
      Telemetry_Response : Boolean := False;
   end record;

   --  Every channel starts at the count that reads as the configured
   --  center; the receiver takes the protocol's RSSI and link quality claims
   --  at its own init.
   procedure Init (S : out State; Mid_RC : Center_Us);

   --  One byte at its arrival time, with the baud negotiation and the
   --  EEPROM write that hold the error count.
   procedure Receive_Byte (
      S              : in out State;
      Rx             : in out Receiver.State;
      C              : Serial_Word;
      Now_Us         : Time_Us;
      Negotiating    : Boolean;
      Eeprom_Writing : Boolean;
      Result         : out Byte_Outputs
   );

   --  The frame status at the poll: the statistics timeout checked, and a
   --  received channel frame unpacked; a subset frame with no channels or a
   --  start channel past the last is dropped.
   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report
   );

   --  The channel value in microseconds through the frame type's scale.
   function Read_Raw (S : State; Ch : Channel) return Float is
     (if S.Scale = Legacy_Scale then S.Scale * Float (S.Data (Ch)) + 881.0 else S.Scale * Float (S.Data (Ch)) + 988.0);

   --  A negotiated baudrate changes the time a frame needs; above the
   --  default rate the inbound frames drive the telemetry.
   procedure Update_Baudrate (S : in out State; Rate : Unsigned_32);

end Adaflight.CRSF;
