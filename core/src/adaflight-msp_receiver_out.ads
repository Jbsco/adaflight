--  The MSP out messages that report the receiver and the switches: the mode
--  ranges with their logic and links by the boxes' permanent ids, the
--  adjustment ranges, the receiver configuration, the failsafe
--  configuration, each channel's failsafe and the RSSI channel and channel
--  map. The caller gathers the configuration, the runtime channel count and
--  the build's options into a snapshot. A value its option leaves out of the
--  build goes out as zero.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.Modes;
with Adaflight.Adjustments;
with Adaflight.Receiver;

package Adaflight.MSP_Receiver_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Mode_Ranges_Command       : constant := 34;
   RX_Config_Command         : constant := 44;
   RSSI_Config_Command       : constant := 50;
   Adjustment_Ranges_Command : constant := 52;
   RX_Map_Command            : constant := 64;
   Failsafe_Config_Command   : constant := 75;
   RXFail_Config_Command     : constant := 77;
   Mode_Ranges_Extra_Command : constant := 238;

   Max_Reply_Length : constant := 10 * Adaflight.Adjustments.Max_Ranges;

   subtype ELRS_UID is Byte_Array (1 .. 6);

   --  The receiver configuration: the serial provider, the stick checks and
   --  the pulse limits in microseconds, the satellite bind, the airmode
   --  threshold in tens of microseconds above 1000, the SPI receiver's
   --  protocol, id and channel count when it is built in, the camera angle,
   --  the RC smoothing settings when it is built in, the USB device type
   --  when the HID class is built in, the ExpressLRS binding and model when
   --  it is built in, and the RSSI channel.
   type RX_Values is record
      Provider             : Unsigned_8 := 0;
      Max_Check            : Unsigned_16 := 0;
      Mid_RC               : Unsigned_16 := 0;
      Min_Check            : Unsigned_16 := 0;
      Spektrum_Sat_Bind    : Unsigned_8 := 0;
      Min_Usec             : Unsigned_16 := 0;
      Max_Usec             : Unsigned_16 := 0;
      Airmode_Threshold    : Unsigned_8 := 0;
      RX_SPI               : Boolean := False;
      SPI_Protocol         : Unsigned_8 := 0;
      SPI_Id               : Unsigned_32 := 0;
      SPI_Channel_Count    : Unsigned_8 := 0;
      FPV_Cam_Angle        : Unsigned_8 := 0;
      RC_Smoothing         : Boolean := False;
      Setpoint_Cutoff      : Unsigned_8 := 0;
      Throttle_Cutoff      : Unsigned_8 := 0;
      Auto_Factor_Throttle : Unsigned_8 := 0;
      Auto_Factor_RPY      : Unsigned_8 := 0;
      Smoothing            : Unsigned_8 := 0;
      USB_HID              : Boolean := False;
      USB_Type             : Unsigned_8 := 0;
      ExpressLRS           : Boolean := False;
      UID                  : ELRS_UID := (others => 0);
      Model_Id             : Unsigned_8 := 0;
      RSSI_Channel         : Unsigned_8 := 0;
   end record;

   type Failsafe_Values is record
      Failsafe_Delay     : Unsigned_8 := 0;
      Landing_Time       : Unsigned_8 := 0;
      Throttle           : Unsigned_16 := 0;
      Switch_Mode        : Unsigned_8 := 0;
      Throttle_Low_Delay : Unsigned_16 := 0;
      Procedure_Kind     : Unsigned_8 := 0;
   end record;

   type Snapshot is record
      Conditions    : Adaflight.Modes.Conditions := (others => Adaflight.Modes.Empty);
      Adjustments   : Adaflight.Adjustments.Ranges := (others => Adaflight.Adjustments.Unset);
      RX            : RX_Values;
      Map           : Adaflight.Receiver.Channel_Map := (0, 1, 3, 2, 4, 5, 6, 7);
      Failsafe      : Failsafe_Values;
      Channels      : Adaflight.Receiver.Failsafe_Channels;
      Channel_Count : Natural range 0 .. Adaflight.Receiver.Channel_Count := 0;
   end record;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in Mode_Ranges_Command | RX_Config_Command | RSSI_Config_Command | Adjustment_Ranges_Command
               | RX_Map_Command | Failsafe_Config_Command | RXFail_Config_Command | Mode_Ranges_Extra_Command);

   --  The reply to one of these out messages; any other command writes
   --  nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command) then S.Next = S.Next'Old);

end Adaflight.MSP_Receiver_Out;
