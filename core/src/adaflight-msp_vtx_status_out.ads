--  The MSP out message of the video transmitter's device status: the device
--  type and readiness, the band and channel, power index, frequency and
--  status, each with whether the device knows it, the power levels, and the
--  device's own status block. Nothing is written without a device. The
--  caller gives the device in use with its driver and the frequency table
--  in a snapshot.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.SmartAudio;
with Adaflight.Tramp;
with Adaflight.VTX_MSP;
with Adaflight.VTX_Table;

package Adaflight.MSP_VTX_Status_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   Device_Status_Command : constant := 16#3004#;

   --  Device type codes on the wire.
   SmartAudio_Type : constant := 3;
   Tramp_Type      : constant := 4;
   MSP_Type        : constant := 5;

   Pit_Mode_Status : constant := 1;
   Locked_Status   : constant := 2;

   Max_Levels       : constant := Adaflight.VTX_Table.Max_Power_Levels;
   Max_Reply_Length : constant := 16 + 4 * Max_Levels + Adaflight.SmartAudio.Status_Size;

   type Device is (No_Device, SmartAudio_Device, Tramp_Device, MSP_Device);

   type Snapshot is record
      VTX_Common : Boolean := False;
      Kind       : Device := No_Device;
      SA         : Adaflight.SmartAudio.Driver;
      TR         : Adaflight.Tramp.Driver;
      MD         : Adaflight.VTX_MSP.Driver;
      Table      : Adaflight.VTX_Table.Table;
   end record;

   --  The message needs the transmitter's common layer built.
   function Handles (Command : Unsigned_16; V : Snapshot) return Boolean is
     (Command = Device_Status_Command and then V.VTX_Common);

   --  The reply to the device status message; a command not handled writes
   --  nothing, and neither does the message without a device.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command, V) or else V.Kind = No_Device then S.Next = S.Next'Old);

end Adaflight.MSP_VTX_Status_Out;
