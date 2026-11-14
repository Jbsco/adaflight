--  The mass storage class's state machine over a storage of 512 byte
--  blocks. A host's command wrapper arrives, data moves in one direction
--  through a buffer of whole blocks, and a status wrapper ends the command.
--  The caller owns the endpoints: it reports each packet that arrived, each
--  transmission that ended and each halt a host cleared, and does the work
--  an event leaves. The storage answers through the formal subprograms.
--  Read_Blocks fills and Write_Blocks takes Count blocks from the start of
--  Data.
generic
   Buffer_Blocks : Buffer_Block_Count;
   Inquiry : Inquiry_Bytes;
   with procedure Start_Storage;
   with procedure Capacity (Blocks : out Unsigned_32; OK : out Boolean);
   with procedure Ready (OK : out Boolean);
   with procedure Write_Protected (Yes : out Boolean);
   with procedure Read_Blocks
     (First : Unsigned_32; Count : Natural; Data : in out Adaflight.Bytes.Byte_Array; OK : out Boolean);
   with procedure Write_Blocks
     (First : Unsigned_32; Count : Natural; Data : Adaflight.Bytes.Byte_Array; OK : out Boolean);
package Adaflight.Mass_Storage.Engine with SPARK_Mode is

   Buffer_Size : constant Positive := Buffer_Blocks * Block_Size;
   subtype Data_Buffer is Adaflight.Bytes.Byte_Array (0 .. Buffer_Size - 1);

   --  Where a command stands: none in progress, data arriving, data
   --  leaving, the last data leaving, a short reply leaving.
   type Transport_State is (Idle, Data_Out, Data_In, Last_Data_In, Send_Data);
   --  Recovery lasts from a transport reset to the next command wrapper.
   --  Error lasts from a wrapper that is not valid until a halt is cleared.
   type Transport_Status is (Normal, Recovery, Error);

   type Sense is record
      Key  : Unsigned_8 := 0;
      Code : Unsigned_8 := 0;
   end record;
   subtype Sense_Index is Natural range 0 .. 3;
   type Sense_List is array (Sense_Index) of Sense;

   --  The last command wrapper as it arrived, the status wrapper's tag,
   --  residue and result, the length of a short reply left in the data
   --  buffer, the failures a host has not asked for yet, the
   --  block count the last capacity request gave, the next block and the
   --  blocks left of a read or write, what the out endpoint was asked to
   --  take, and the data buffer.
   type Session is record
      State          : Transport_State := Idle;
      Status         : Transport_Status := Normal;
      Command        : Command_Bytes := (others => 0);
      Tag            : Unsigned_32 := 0;
      Residue        : Unsigned_32 := 0;
      Result         : Unsigned_8 := 0;
      Reply          : Natural range 0 .. Inquiry_Length := 0;
      Senses         : Sense_List;
      Head           : Sense_Index := 0;
      Tail           : Sense_Index := 0;
      Block_Count    : Unsigned_32 := 0;
      Block          : Unsigned_32 := 0;
      Blocks_Left    : Natural range 0 .. 65_535 := 0;
      Receiving      : Receive_Kind := Nothing;
      Receive_Length : Natural range 0 .. 65_535 := 0;
      Data           : Data_Buffer := (others => 0);
   end record;

   --  The class starts: the storage starts, both endpoints are flushed and
   --  a command wrapper is asked for.
   procedure Start (S : in out Session; Next : out Actions);

   --  The transport's reset request.
   procedure Reset (S : in out Session; Next : out Actions);

   --  The class stops.
   procedure Stop (S : in out Session);

   --  A packet arrived on the out endpoint. Its bytes go where the last
   --  receive pointed, as many as that receive asked for.
   procedure Packet_Out (S : in out Session; Packet : Adaflight.Bytes.Byte_Array; Next : out Actions)
     with Pre => S.Receiving /= Nothing;

   --  A transmission on the in endpoint ended.
   procedure Packet_In (S : in out Session; Next : out Actions);

   --  A host cleared an endpoint's halt.
   procedure Halt_Cleared (S : in out Session; In_Endpoint : Boolean; Next : out Actions);

   --  The status wrapper to send.
   function Status_Wrapper (S : Session) return Status_Bytes;

end Adaflight.Mass_Storage.Engine;
