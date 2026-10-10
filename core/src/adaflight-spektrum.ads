--  The Spektrum receiver protocols: the sixteen-byte DSM frame assembled from
--  the serial bytes with a restart after a five-millisecond gap, the channels
--  decoded at the status poll from the frame's seven pairs by the
--  resolution's shift and mask, the RSSI channel filled from the SRXL
--  receiver's dBm report through the fade count and the range table or from
--  a satellite receiver's fade count per half second, the VTX control frame
--  handed to the VTX layer, the SRXL telemetry request a frame opens and the
--  processing it asks for once the reply delay has passed, and the raw
--  channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.Spektrum with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Frame_Size        : constant := 16;
   Channel_Count_Max : constant := 12;
   subtype Channel is Natural range 0 .. Channel_Count_Max - 1;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;
   subtype Frame_Index is Natural range 0 .. Frame_Size - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;

   Needed_Frame_Interval_Us : constant := 5_000;
   Telemetry_Frame_Delay_Us : constant := 1_000;
   Telemetry_Max            : constant := Frame_Size + 5;
   RSSI_Max_Dbm             : constant := -42;
   RSSI_Min_Dbm             : constant := -92;
   RSSI_Fade_Limit_Dbm      : constant := -100;
   Link_Loss_Fades          : constant := 5;
   Max_Fade_Per_Sec         : constant := 40;
   Fade_Reports_Per_Sec     : constant := 2;
   VTX_Control_Size         : constant := 4;
   VTX_Frame_Mask           : constant Unsigned_32 := 16#F000_F000#;
   VTX_Frame                : constant Unsigned_32 := 16#E000_E000#;

   --  The system types a receiver bound by the flight controller reports.
   DSM2_22 : constant := 16#01#;
   DSM2_11 : constant := 16#12#;
   DSMX_22 : constant := 16#A2#;
   DSMX_11 : constant := 16#B2#;

   type Provider is (Spektrum_1024, Spektrum_2048, SRXL);

   --  The serial receiver provider, whether the telemetry feature is on with
   --  a port of its own, and the one-based RSSI channel, zero for none.
   type Settings is record
      Kind         : Provider := Spektrum_2048;
      Telemetry    : Boolean := False;
      RSSI_Channel : Byte := 0;
   end record;

   --  A VTX control frame's word for the VTX layer.
   type VTX_Request is record
      Present : Boolean := False;
      Word    : Unsigned_32 := 0;
   end record;

   type State is record
      SRXL_Enabled           : Boolean := False;
      Hi_Res                 : Boolean := True;
      Resolution             : Natural range 1_024 .. 2_048 := 2_048;
      Channel_Count          : Natural range 7 .. Channel_Count_Max := Channel_Count_Max;
      RSSI_Channel           : Channel := 0;
      Shift                  : Natural range 2 .. 3 := 3;
      Mask                   : Natural range 3 .. 7 := 7;
      Frame                  : Frame_Bytes := (others => 0);
      Position               : Natural range 0 .. Frame_Size := 0;
      Time_Last_Us           : Time_Us := 0;
      Frame_Complete         : Boolean := False;
      Last_Frame_Time_Us     : Time_Us := 0;
      Data                   : Channel_Data := (others => 0);
      Last_RSSI_Dbm          : Integer range -128 .. 127 := RSSI_Max_Dbm;
      Fade_Count             : Byte := 0;
      Sat_Internal           : Boolean := True;
      Fade_Last_Sec          : Unsigned_32 := 0;
      Fade_Last_Sec_Count    : Natural range 0 .. 65_535 := 0;
      Telemetry_Length       : Natural range 0 .. Telemetry_Max := 0;
      Telemetry_Requested_Us : Time_Us := 0;
   end record;

   --  The resolution's shift, mask, and channel count, SRXL telemetry when
   --  the provider is SRXL with the feature on, and the RSSI channel made
   --  zero-based and dropped when it is past the channel count.
   procedure Init (S : out State; C : Settings);

   --  One byte from the serial port at its arrival time: a gap over five
   --  milliseconds starts a new frame, and the sixteenth byte completes it
   --  at its own time.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The frame's status when one is complete: the RSSI channel from the
   --  frame's first bytes, the VTX control word when the last four bytes
   --  carry one in a first-phase frame, the channels from the pairs that
   --  remain, the telemetry request for SRXL, and the processing request
   --  once a queued reply has waited its delay after the request.
   procedure Frame_Status (
      S      : in out State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report;
      VTX    : out VTX_Request
   );

   --  A telemetry reply queued by the SRXL telemetry, cut to the buffer.
   procedure Queue_Telemetry (S : in out State; Length : Natural);

   --  The processing the status asked for: the queued reply goes out on the
   --  port and the buffer empties.
   procedure Process_Frame (S : in out State; Written : out Boolean);

   function Telemetry_Buffer_Empty (S : State) return Boolean is (S.Telemetry_Length = 0);

   --  The channel value in microseconds: zero past the channel count, half
   --  the count plus 988 at the high resolution, the count plus 988 otherwise.
   function Read_Raw (S : State; Ch : Channel) return Float is
     (if Ch >= S.Channel_Count then 0.0
      elsif S.Hi_Res then 0.5 * Float (S.Data (Ch)) + 988.0
      else Float (S.Data (Ch) + 988));

end Adaflight.Spektrum;
