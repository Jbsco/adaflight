with Interfaces;

--  MSP frames as a client sends and receives them: a request in the first protocol version when its command
--  and its payload length fit one byte each, and in the second version otherwise; replies of either version,
--  with the first version's 16-bit length extension.
package MSP.Frames with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Max_Payload : constant := 8192;
   subtype Payload_Length is Natural range 0 .. Max_Payload;
   subtype Command is Natural range 0 .. 65_535;

   V1_Overhead : constant := 6;
   V2_Overhead : constant := 9;
   Max_Frame   : constant := V2_Overhead + Max_Payload;

   function Is_V1 (Code : Command; Length : Payload_Length) return Boolean
   is (Code < 255 and then Length < 255);

   function Frame_Length (Code : Command; Length : Payload_Length) return Positive
   is (if Is_V1 (Code, Length) then V1_Overhead + Length else V2_Overhead + Length);

   --  The second version's DVB-S2 checksum, one byte on.
   function CRC8 (CRC : Byte; Data : Byte) return Byte;

   --  A request frame at the start of Frame; Last is its last index.
   procedure Encode (Code : Command; Payload : Byte_Array; Frame : out Byte_Array; Last : out Natural)
   with
     Pre  =>
       Payload'Length <= Max_Payload
       and then Frame'First = 0
       and then Frame'Length >= Frame_Length (Code, Payload'Length),
     Post => Last = Frame_Length (Code, Payload'Length) - 1;

   type Decoder is private;

   --  What a byte did: nothing complete yet, a reply complete with a good checksum, a frame dropped for its
   --  checksum, or a frame dropped for a payload past Max_Payload.
   type Step is (Pending, Complete, Bad_Checksum, Too_Long);

   procedure Reset (D : out Decoder);

   procedure Feed (D : in out Decoder; B : Byte; Result : out Step);

   --  The last complete reply: its command, whether the flight controller refused the request, and its
   --  payload.
   function Code (D : Decoder) return Command;
   function Refused (D : Decoder) return Boolean;
   function Length (D : Decoder) return Payload_Length;
   function Payload (D : Decoder; I : Positive) return Byte
   with Pre => I <= Length (D);

private

   type State is
     (Idle,
      Proto,
      Direction,
      V1_Size,
      V1_Code,
      V1_Size_Low,
      V1_Size_High,
      V1_Payload,
      V1_Check,
      V2_Flag,
      V2_Code_Low,
      V2_Code_High,
      V2_Size_Low,
      V2_Size_High,
      V2_Payload,
      V2_Check,
      Skipping);

   subtype Data_Range is Positive range 1 .. Max_Payload;
   type Payload_Buffer is array (Data_Range) of Byte;

   type Decoder is record
      Current  : State := Idle;
      V2       : Boolean := False;
      Is_Error : Boolean := False;
      Wide     : Boolean := False;
      Low      : Byte := 0;
      Command  : Frames.Command := 0;
      Size     : Payload_Length := 0;
      Count    : Payload_Length := 0;
      Left     : Natural range 0 .. 65_536 := 0;
      Check    : Byte := 0;
      Data     : Payload_Buffer := (others => 0);
   end record;

   function Code (D : Decoder) return Command
   is (D.Command);
   function Refused (D : Decoder) return Boolean
   is (D.Is_Error);
   function Length (D : Decoder) return Payload_Length
   is (D.Size);
   function Payload (D : Decoder; I : Positive) return Byte
   is (D.Data (I));

end MSP.Frames;
