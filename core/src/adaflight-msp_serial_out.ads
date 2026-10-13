--  The MSP out messages of the serial ports: each available port with an
--  empty function mask and its baud rate of each class, in the legacy layout
--  and in the common layout with a port count and a 32-bit mask. The caller
--  gives the target's ports with their availability, the build's options and
--  the feature assignments in a snapshot.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Stream_Buffers;
with Adaflight.Serial_Feature_Map;

package Adaflight.MSP_Serial_Out with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Stream is Adaflight.Stream_Buffers.Stream;

   CF_Serial_Config_Command     : constant := 54;
   Common_Serial_Config_Command : constant := 16#1009#;

   Max_Ports : constant := Adaflight.Serial_Feature_Map.Max_Ports;
   subtype Target_Port is Adaflight.Serial_Feature_Map.Port_Id range 0 .. Adaflight.Serial_Feature_Map.Port_Id'Last;

   type Port_Entry is record
      Port      : Target_Port := 0;
      Available : Boolean := False;
   end record;
   type Port_Entries is array (1 .. Max_Ports) of Port_Entry;

   type Snapshot is record
      Options     : Adaflight.Serial_Feature_Map.Options;
      Assignments : Adaflight.Serial_Feature_Map.Assignments;
      Port_Count  : Natural range 0 .. Max_Ports := 0;
      Ports       : Port_Entries;
   end record;

   Max_Reply_Length : constant := 1 + 9 * Max_Ports;

   function Handles (Command : Unsigned_16) return Boolean is
     (Command in CF_Serial_Config_Command | Common_Serial_Config_Command);

   --  The reply to one of these out messages; a command not handled writes
   --  nothing.
   procedure Reply (B : in out Byte_Array; S : in out Stream; Command : Unsigned_16; V : Snapshot)
     with Pre  => Adaflight.Stream_Buffers.Fits (S, B)
                  and then Adaflight.Stream_Buffers.Remaining (S) >= Max_Reply_Length,
          Post => Adaflight.Stream_Buffers.Fits (S, B) and then S.Last = S.Last'Old
                  and then S.Next - S.Next'Old in 0 .. Max_Reply_Length
                  and then (if not Handles (Command) then S.Next = S.Next'Old);

end Adaflight.MSP_Serial_Out;
