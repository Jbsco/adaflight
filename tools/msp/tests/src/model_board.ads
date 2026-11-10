with MSP;

--  A model of a flight controller's port for the checks: it takes MSP request frames of either protocol
--  version, checks them, and queues a reply the way its settings say; and it has a small command line that
--  keeps the settings it is given, lists them as a backup, and saves or leaves.
package Model_Board is

   type Settings is record
      Present       : Boolean := True;
      Accept_Sends  : Boolean := True;
      Silent        : Boolean := False;
      Refuse        : Boolean := False;
      Jumbo         : Boolean := False;
      Chunk         : Positive := 64;
      Noise_First   : Boolean := False;
      Corrupt_First : Boolean := False;
      Other_First   : Boolean := False;
      Long_First    : Boolean := False;
      Reply_Length  : Natural := 0;
      No_Prompt     : Boolean := False;
      Stall         : Natural := 0;
      Dump_Lines    : Natural := 0;
      Endless       : Boolean := False;
   end record;

   --  The settings for the requests that follow, with the counts and the queue cleared.
   procedure Configure (S : Settings);

   --  The reply payload the model gives a command: Reply_Length bytes that follow from the command and the
   --  request's payload.
   function Reply_Byte (Code : Natural; Request : MSP.Byte_Array; I : Positive) return MSP.Byte;

   function Is_Present return Boolean;
   procedure Take (Data : MSP.Byte_Array; Ok : out Boolean);
   procedure Give (Data : out MSP.Byte_Array; Got : out Natural);

   --  What the model saw: requests with a good checksum, requests it could not read, the last request's
   --  command, payload length and protocol version, the reads it answered with no byte, and all its reads.
   function Good_Requests return Natural;
   function Bad_Requests return Natural;
   function Last_Code return Natural;
   function Last_Length return Natural;
   function Last_Was_V2 return Boolean;
   function Empty_Reads return Natural;
   function Reads return Natural;

   --  The command line's side: No_Prompt leaves its prompt out, Stall puts that many empty reads after each
   --  read with bytes, Dump_Lines is the length of its whole dump, and Endless fills every read with bytes.
   --  It counts its saves and its exits, and keeps the setting lines it took; an exit drops those taken
   --  since the last save, and a reset to defaults drops them all.
   function Saves return Natural;
   function Exits return Natural;
   function Kept_Lines return Natural;
   function Kept_Line (I : Positive) return String;

end Model_Board;
