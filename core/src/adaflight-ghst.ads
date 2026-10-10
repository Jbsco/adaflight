--  The Ghost receiver protocol: the fourteen-byte frames assembled from the
--  serial bytes into a pair of buffers swapped at each frame for the flight
--  controller, a new frame after the frame time, the CRC checked at the
--  status poll, the channels and link statistics decoded at the processing
--  the poll asks for, the primary four channels in twelve bits and four more
--  in eight sent in turn, the legacy frames rescaled, the RF protocol that
--  enables the telemetry, the telemetry reply sent in the quiet window after
--  a frame, the MSP frames for the MSP layer, and the raw channel value the
--  receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.GHST with SPARK_Mode is
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count : constant := 16;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;

   Frame_Size : constant := 14;
   subtype Frame_Index is Natural range 0 .. Frame_Size - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;
   subtype Buffer_Choice is Natural range 0 .. 1;
   type Buffer_Pair is array (Buffer_Choice) of Frame_Bytes;
   subtype Full_Length is Natural range 4 .. Frame_Size;

   Max_Frame_Time_Us     : constant := 500;
   Telemetry_Min_Us      : constant := 1_000;
   Telemetry_Max_Us      : constant := 2_000;
   RSSI_Dbm_Min          : constant := -117;
   RSSI_Dbm_Max          : constant := -60;
   Address_FC            : constant := 16#82#;
   Center_Primary_12_Bit : constant := 2_048;
   Center_Aux_12_Bit     : constant := 128 * 4;

   --  The uplink frame types: the ten-bit and twelve-bit RC frames with the
   --  aux channels they carry or the link statistics, and the MSP frames.
   RC_Legacy_First : constant := 16#10#;
   RC_Legacy_Last  : constant := 16#1F#;
   RC_12_Bit_First : constant := 16#30#;
   RC_12_Bit_Last  : constant := 16#3F#;
   RC_5_To_8       : constant := 16#00#;
   RC_9_To_12      : constant := 16#01#;
   RC_13_To_16     : constant := 16#02#;
   RC_RSSI         : constant := 16#03#;
   MSP_Request     : constant := 16#21#;
   MSP_Write       : constant := 16#22#;

   --  The RF protocols: undefined until the first statistics frame, and
   --  those with telemetry.
   RF_Undefined  : constant := 16#00#;
   RF_Normal     : constant := 16#05#;
   RF_Race       : constant := 16#06#;
   RF_Long_Range : constant := 16#08#;
   RF_Race_250   : constant := 16#0A#;

   type MSP_Kind is (None, Request, Write);

   --  What the processing produced for the other units: a telemetry reply
   --  sent on the port, and an MSP frame with its payload length for the
   --  MSP layer.
   type Process_Outputs is record
      Telemetry_Sent : Boolean := False;
      MSP            : MSP_Kind := None;
      MSP_Length     : Natural range 0 .. Frame_Size - 4 := 0;
   end record;

   type State is record
      Buffers                : Buffer_Pair := (others => (others => 0));
      Incoming               : Buffer_Choice := 0;
      Index                  : Natural range 0 .. Frame_Size := 0;
      Validated_Full         : Full_Length := Full_Length'Last;
      Frame_Available        : Boolean := False;
      Validated_Available    : Boolean := False;
      Transmitting_Telemetry : Boolean := False;
      Telemetry_Enabled      : Boolean := False;
      RF_Protocol            : Byte := RF_Undefined;
      Frame_Start_At_Us      : Time_Us := 0;
      Frame_End_At_Us        : Time_Us := 0;
      Last_Frame_Time_Us     : Time_Us := 0;
      Telemetry_Length       : Natural range 0 .. Frame_Size := 0;
      Data                   : Channel_Data := (0 .. 3 => Center_Primary_12_Bit, others => Center_Aux_12_Bit);
   end record;

   --  Every channel starts at its center; the receiver takes the protocol's
   --  RSSI and link quality claims at its own init.
   procedure Init (S : out State);

   --  One byte from the serial port at its arrival time: a byte after the
   --  frame time starts a new frame at that time, the length is five until
   --  the length byte is in and that byte plus two after, and the last byte
   --  of a frame for the flight controller swaps the buffers and marks the
   --  frame available with its end time.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The frame's status: complete with processing to do when the CRC over
   --  the type and payload matches, dropped otherwise, and processing alone
   --  when a telemetry reply waits in its window after the last frame.
   procedure Frame_Status (S : in out State; Now_Us : Time_Us; Status : out Receiver.Frame_Report);

   --  The processing the status asked for: the telemetry reply out in its
   --  window, then the validated frame decoded into the receiver's RSSI,
   --  dBm, and link quality from a statistics frame, the RF protocol with
   --  the telemetry it allows, and the channels once the protocol is known.
   procedure Process_Frame (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Result : out Process_Outputs
   );

   --  A telemetry reply queued by the Ghost telemetry, cut to a frame.
   procedure Queue_Telemetry (S : in out State; Length : Natural);

   --  The port's idle between packets ends a transmission.
   procedure Idle (S : in out State);

   --  The channel value in microseconds: a quarter of the primary counts and
   --  the aux counts as they are, plus 988.
   function Read_Raw (S : State; Ch : Channel) return Float is
     (if Ch < 4 then 0.25 * Float (S.Data (Ch)) + 988.0 else Float (S.Data (Ch)) + 988.0);

end Adaflight.GHST;
