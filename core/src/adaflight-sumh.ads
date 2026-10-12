--  The SUMH receiver protocol: the 21-byte frame assembled from the serial
--  bytes, restarted after a gap of five milliseconds, its eight channels
--  taken once the sync byte and the zero before the last byte check, and the
--  raw channel value the receiver reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.SUMH with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Byte is Natural range 0 .. 255;
   subtype Serial_Word is Natural range 0 .. 65_535;

   Channel_Count : constant := 8;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   type Channel_Data is array (Channel) of Unsigned_32;

   Frame_Size : constant := 21;
   subtype Frame_Index is Natural range 0 .. Frame_Size - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;

   Sync_Byte : constant := 16#A8#;
   Gap_Us    : constant := 5_000;

   type State is record
      Done         : Boolean := False;
      Frame        : Frame_Bytes := (others => 0);
      Data         : Channel_Data := (others => 0);
      Time_Last_Us : Time_Us := 0;
      Position     : Frame_Index := 0;
   end record;

   procedure Init (S : out State);

   --  One byte at its arrival time: a gap over five milliseconds restarts
   --  the frame, and the twenty-first byte completes it.
   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us);

   --  The status of a complete frame: pending unless the sync byte and the
   --  zero before the last byte check, then the eight channels taken from
   --  their two bytes through the reference's scale, held at zero where the
   --  reference's conversion of a negative value is undefined.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report);

   function Read_Raw (S : State; Ch : Natural) return Float is
     (if Ch >= Channel_Count then 0.0 else Float (S.Data (Ch)));

end Adaflight.SUMH;
