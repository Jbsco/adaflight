--  The byte link to a flight controller: a serial device by its path, or a TCP port as "tcp:host:port".
package MSP.Transport with SPARK_Mode, Abstract_State => Link, Initializes => Link is

   procedure Open (Target : String; Ok : out Boolean)
   with Global => (In_Out => Link);

   procedure Close
   with Global => (In_Out => Link);

   procedure Send (Data : Byte_Array; Ok : out Boolean)
   with Global => (In_Out => Link);

   --  The bytes that arrive within a short wait, up to the room in Data; Got is zero when none do.
   procedure Receive (Data : out Byte_Array; Got : out Natural)
   with Global => (In_Out => Link), Post => Got <= Data'Length;

end MSP.Transport;
