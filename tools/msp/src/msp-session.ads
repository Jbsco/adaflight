with MSP.Frames;
with MSP.Transport;

--  One request and its reply over the link.
package MSP.Session with SPARK_Mode is

   --  The reply came, the flight controller refused the request, no reply came in time, or the request did
   --  not go out.
   type Status is (Answered, Refused, No_Reply, Not_Sent);

   --  Empty waits and reads in all before a request gives up on its reply.
   Max_Waits : constant := 40;
   Max_Reads : constant := 4000;

   subtype Reply_Buffer is Byte_Array (1 .. Frames.Max_Payload);

   --  The request sent, then the link read until a reply to this command is complete. Frames of other
   --  commands and frames with a bad checksum are passed over. Last is the reply's length.
   procedure Request
     (Code    : Frames.Command;
      Payload : Byte_Array;
      Reply   : out Reply_Buffer;
      Last    : out Frames.Payload_Length;
      Result  : out Status)
   with
     Global => (In_Out => Transport.Link),
     Pre    => Payload'Length <= Frames.Max_Payload,
     Post   => (if Result in No_Reply | Not_Sent then Last = 0);

end MSP.Session;
