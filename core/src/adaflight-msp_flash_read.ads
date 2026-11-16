--  The reply to an MSP flash read. A request names an address, and in its
--  newer form a size and whether its reply may be compressed; a shorter one
--  is the legacy form of 128 bytes. The reply starts with that address. The
--  newer form follows with its byte count and a compression method, then
--  the volume's bytes, or with Huffman coding a count of the bytes coded
--  and their code. The legacy form follows with 128 bytes, zeros past the
--  volume's end. A read is cut to the reply's room less 16 bytes and to the
--  volume's end. The caller supplies the volume's bytes: it asks for the
--  next read, feeds its bytes, and finishes the reply once no read is left.
--  A read may bring fewer bytes than asked, as a NAND chip's does at its
--  page's end: a plain reply then has those bytes alone, and a coded one
--  reads on from where they end. A read that brings none ends the reply.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Huffman;

package Adaflight.MSP_Flash_Read with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Info_Size   : constant := 16;
   Chunk_Size  : constant := 256;
   Legacy_Size : constant := 128;

   --  A reply's room: the legacy form's bytes fit in the least.
   Min_Room : constant := Legacy_Size + Info_Size;
   Max_Room : constant := 4112;
   subtype Room_Size is Natural range Min_Room .. Max_Room;
   subtype Read_Size is Natural range 0 .. Max_Room - Info_Size;

   --  Where a reply's parts start.
   Count_At  : constant := 4;
   Method_At : constant := 6;
   Plain_At  : constant := 7;
   Coded_At  : constant := 9;

   type Request is record
      Address  : Unsigned_32 := 0;
      Size     : Unsigned_16 := Legacy_Size;
      Legacy   : Boolean := True;
      Compress : Boolean := False;
   end record;

   --  A request from its payload, bytes it lacks read as zero.
   function Parse (Payload : Byte_Array) return Request
     with Pre => Payload'Length <= 65_535;

   --  A read's length: the size asked for, cut to the room less the bytes
   --  kept free and to what the volume has from the address.
   function Read_Length (R : Request; Room : Room_Size; Flash_Size : Unsigned_32) return Read_Size
     with Post => Read_Length'Result <= Room - Info_Size;

   type Coding is (Plain, Huffman_Coded);

   type State is record
      Req      : Request;
      Room     : Room_Size := Min_Room;
      Length   : Read_Size := 0;
      Method   : Coding := Plain;
      --  The next read's address and the volume's bytes from it.
      Offset   : Unsigned_32 := 0;
      Left     : Unsigned_32 := 0;
      --  The bytes placed or coded so far, the coded count wrapping at
      --  sixteen bits.
      Got      : Read_Size := 0;
      Total    : Unsigned_16 := 0;
      Encoder  : Adaflight.Huffman.Encoder;
      Coding_On : Boolean := False;
      Stopped  : Boolean := False;
   end record;

   --  Whether a state belongs to a reply buffer: the encoder's region lies
   --  within the room, and a plain read fits it.
   function Fits (S : State; Reply : Byte_Array) return Boolean is
     (Reply'First = 0 and then Reply'Length >= S.Room and then S.Length <= S.Room - Info_Size
      and then S.Got <= S.Length
      and then (if S.Coding_On
                then S.Encoder.Base = Coded_At and then S.Encoder.Out_Buf_Len = S.Length and then S.Length >= 1));

   --  The count of bytes the next read takes: none once the reply has all
   --  it needs.
   function Next_Count (S : State) return Natural is
     (if S.Stopped then 0
      elsif S.Method = Plain then Natural'Max (S.Length, S.Got) - S.Got
      elsif S.Coding_On and then S.Encoder.Bytes_Written < S.Length and then S.Left > 0
      then Natural (Unsigned_32'Min (Chunk_Size, S.Left))
      else 0);

   function Next_Address (S : State) return Unsigned_32 is (S.Offset);

   --  A reply begun: its address written, its read length set.
   procedure Start
     (S : out State; R : Request; Room : Room_Size; Flash_Size : Unsigned_32; Reply : in out Byte_Array)
     with Pre  => Reply'First = 0 and then Reply'Length >= Room,
          Post => Fits (S, Reply) and then S.Room = Room;

   --  The bytes the read that was asked for brought, from its start.
   procedure Feed (S : in out State; Data : Byte_Array; Reply : in out Byte_Array)
     with Pre  => Fits (S, Reply) and then Data'Length in 1 .. Next_Count (S),
          Post => Fits (S, Reply) and then S.Room = S.Room'Old;

   --  A read that brought no bytes: no read is left.
   procedure Stop (S : in out State)
     with Post => Next_Count (S) = 0;

   --  The reply's counts and method written, and its length.
   procedure Finish (S : State; Reply : in out Byte_Array; Length : out Natural)
     with Pre  => Fits (S, Reply),
          Post => Length <= S.Room;

end Adaflight.MSP_Flash_Read;
