--  The SmartAudio video transmitter driver over one half-duplex serial
--  line at 4800 baud. Frames go out from a queue, one per task call, and
--  the outstanding one is resent after a timeout; the device's responses
--  are reassembled through the preamble, code, length and checksum, and
--  the settings response gives the version, the channel, the power, the
--  mode and the frequency. The line rate is adjusted when fewer than seven
--  of ten frames are answered. The band and channel, the power index, the
--  pit mode and the frequency are set and read through the table, and the
--  status is serialized for the ground link.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.VTX_Table;

package Adaflight.SmartAudio with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_8;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_8 is Interfaces.Integer_8;

   Cmd_None         : constant Unsigned_8 := 0;
   Cmd_Get_Settings : constant Unsigned_8 := 1;
   Cmd_Set_Power    : constant Unsigned_8 := 2;
   Cmd_Set_Channel  : constant Unsigned_8 := 3;
   Cmd_Set_Freq     : constant Unsigned_8 := 4;
   Cmd_Set_Mode     : constant Unsigned_8 := 5;
   Rsp_Settings_V2  : constant Unsigned_8 := 16#09#;
   Rsp_Settings_V21 : constant Unsigned_8 := 16#11#;

   --  The mode flags as the device reports them.
   Mode_Freq_By_Freq  : constant Unsigned_8 := 1;
   Mode_Pit           : constant Unsigned_8 := 2;
   Mode_In_Range_Pit  : constant Unsigned_8 := 4;
   Mode_Out_Range_Pit : constant Unsigned_8 := 8;
   Mode_Unlocked      : constant Unsigned_8 := 16;
   Mode_Deferred_Freq : constant Unsigned_8 := 32;

   --  The mode flags as they are set.
   Set_In_Range_Pit  : constant Unsigned_8 := 1;
   Set_Out_Range_Pit : constant Unsigned_8 := 2;
   Set_Clear_Pit     : constant Unsigned_8 := 4;
   Set_Unlock        : constant Unsigned_8 := 8;
   Set_Deferred_Freq : constant Unsigned_8 := 16;

   --  The frequency word flags for the pit mode frequency.
   Freq_Get_Pit : constant Unsigned_16 := 2 ** 14;
   Freq_Set_Pit : constant Unsigned_16 := 2 ** 15;
   Freq_Mask    : constant Unsigned_16 := 16#3FFF#;

   Min_Frequency : constant := 5000;
   Max_Frequency : constant := 5999;

   type Version is (Unknown, V1, V2, V21);

   --  The device as last reported: the channel and the power as the
   --  device numbers them, the mode flags, the frequency and the pit mode
   --  frequency.
   type Report is record
      Version_Seen           : Version := Unknown;
      Channel                : Integer_8 := -1;
      Power                  : Integer_8 := 0;
      Mode                   : Unsigned_8 := 0;
      Freq                   : Unsigned_16 := 0;
      Pit_Freq               : Unsigned_16 := 0;
      Will_Boot_Into_Pit_Mode : Boolean := False;
   end record;

   --  The report the first response is compared with.
   No_Report : constant Report := (Version_Seen => Unknown, Channel => 0, Power => 0, Mode => 0, Freq => 0,
                                   Pit_Freq => 0, Will_Boot_Into_Pit_Mode => False);

   type Stats is record
      Sent, Received, Bad_Preamble, Bad_Length, Crc_Errors, Out_Of_Order, Bad_Code : Unsigned_16 := 0;
   end record;

   --  The frame each queued command is sent from; a later request of the
   --  same kind replaces the bytes before they go out.
   type Frame_Kind is (Get_Settings, Set_Freq, Set_Freq_Switch, Set_Mode, Set_Channel, Set_Power, Set_Power_Pit);

   Max_Frame : constant := 7;
   subtype Frame_Length is Natural range 0 .. Max_Frame;
   subtype Frame_Bytes is Byte_Array (0 .. Max_Frame - 1);

   type Frame is record
      Data   : Frame_Bytes := (others => 0);
      Length : Frame_Length := 0;
   end record;

   type Frame_Buffers is array (Frame_Kind) of Frame;

   Queue_Size : constant := 6;
   subtype Queue_Index is Natural range 0 .. Queue_Size - 1;
   type Queue is array (Queue_Index) of Frame_Kind;

   type Receive_Phase is (Wait_Preamble_1, Wait_Preamble_2, Wait_Code, Wait_Length, Payload, Wait_Crc);

   Max_Receive : constant := 21;
   subtype Receive_Length is Natural range 0 .. Max_Receive - 2;
   subtype Receive_Bytes is Byte_Array (0 .. Max_Receive - 1);

   type Init_Phase is (Start, Wait_Settings, Wait_Pit_Freq, Done);

   --  The line rates the adjustment steps through.
   type Baud is (B_4800, B_4850, B_4900, B_4950);

   function Rate_Of (B : Baud) return Unsigned_16 is
     (case B is
         when B_4800 => 4800,
         when B_4850 => 4850,
         when B_4900 => 4900,
         when B_4950 => 4950);

   type Direction is (Down, Up);

   Max_Levels : constant := 8;
   subtype Level_Count is Natural range 0 .. Max_Levels;
   type Level_Values is array (0 .. Max_Levels - 1) of Unsigned_16;

   type Driver is record
      Device           : Report;
      Stat             : Stats;
      Lock_Mode        : Unsigned_8 := Set_Unlock;
      Levels           : Level_Count := Max_Levels;
      Level_Value      : Level_Values := (others => 0);
      Smart_Baud       : Baud := B_4800;
      Adjust           : Direction := Up;
      Last_Tx_Ms       : Unsigned_32 := 0;
      Outstanding      : Unsigned_8 := Cmd_None;
      Outstanding_Frame : Frame;
      Buffers          : Frame_Buffers;
      Pending          : Queue := (others => Get_Settings);
      Head, Tail       : Queue_Index := 0;
      Phase            : Receive_Phase := Wait_Preamble_1;
      Rx_Length        : Receive_Length := 0;
      Rx_Fill          : Receive_Length := 0;
      Rx               : Receive_Bytes := (others => 0);
      Init_State       : Init_Phase := Start;
      Last_Command_Ms  : Unsigned_32 := 0;
      Port_Open        : Boolean := False;
      Prev_Device      : Report := No_Report;
   end record;

   --  The bytes a call sends, a zero ahead of them when the line needs
   --  one, and the line rate to set.
   Max_Tx : constant := Max_Frame + 1;
   subtype Tx_Length is Natural range 0 .. Max_Tx;
   subtype Tx_Bytes is Byte_Array (0 .. Max_Tx - 1);

   type Events is record
      Tx           : Tx_Bytes := (others => 0);
      Tx_Count     : Tx_Length := 0;
      Baud_Changed : Boolean := False;
      New_Baud     : Baud := B_4800;
   end record;

   --  The start, with the port open or not; every power level is one
   --  until the device reports.
   procedure Init (D : out Driver; Port_Opened : Boolean);

   --  One byte of the line received. Processed reports a response taken in,
   --  and Changed that it changed the device's report.
   procedure Receive_Byte (D : in out Driver; T : VTX_Table.Table; C : Byte; Control_Disabled : Boolean;
                           Processed, Changed : out Boolean);

   --  A task call after its bytes are received: the line rate, the start-up
   --  queries, and the resend or the next frame.
   procedure Process_Line (D : in out Driver; Now_Ms : Unsigned_32; Control_Disabled, Prepend_Zero : Boolean;
                           E : out Events);

   --  One task call at the millisecond clock with the bytes received since
   --  the last one; a disabled control drops the frames instead of sending
   --  and the zero prefix serves a line that needs it.
   procedure Process (D : in out Driver; T : VTX_Table.Table; Now_Ms : Unsigned_32; Rx : Byte_Array;
                      Control_Disabled, Prepend_Zero : Boolean; E : out Events);

   function Ready (D : Driver) return Boolean is (D.Port_Open and then D.Device.Version_Seen /= Unknown);

   --  The mode flags as set, under the lock mode.
   procedure Set_Mode (D : in out Driver; Mode : Unsigned_8);

   --  A frequency word with its flags; a set of the frequency the device
   --  already holds in channel mode goes through a neighbouring frequency.
   procedure Set_Frequency_Word (D : in out Driver; Freq : Unsigned_16);

   procedure Set_Pit_Frequency (D : in out Driver; Freq : Unsigned_16);

   procedure Set_Band_Channel (D : in out Driver; T : VTX_Table.Table; Band, Channel : Unsigned_8);

   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8);

   procedure Set_Pit_Mode (D : in out Driver; On : Boolean);

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16);

   --  Band and channel from the device's channel number, zero in frequency
   --  mode; the table channel count divides, a zero count giving band one.
   procedure Get_Band_Channel (D : Driver; T : VTX_Table.Table; Band, Channel : out Unsigned_8; Known : out Boolean);

   procedure Get_Power_Index (D : Driver; Index : out Unsigned_8; Known : out Boolean);

   procedure Get_Frequency (D : Driver; T : VTX_Table.Table; Freq : out Unsigned_16; Known : out Boolean);

   procedure Get_Status (D : Driver; Pit_Mode : out Boolean; Known : out Boolean);

   --  The power levels in dBm and in milliwatts, rounded to fifties above
   --  14 dBm.
   procedure Get_Power_Levels (D : Driver; Count : out Level_Count; Levels, Powers : out Level_Values);

   --  The device status for the ground link: a size of five, the version,
   --  the mode, the pit mode frequency and the boot flag.
   Status_Size : constant := 6;
   subtype Status_Bytes is Byte_Array (0 .. Status_Size - 1);
   function Custom_Status (D : Driver) return Status_Bytes;

end Adaflight.SmartAudio;
