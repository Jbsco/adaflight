with Interfaces;

--  USB access to interface 0 of the first device in ST's bootloader mode (0483:df11).
package DFU.Transport with SPARK_Mode, Abstract_State => Device, Initializes => Device is

   Max_Length : constant := 65_535;

   procedure Open (Ok : out Boolean)
   with Global => (In_Out => Device);

   procedure Close
   with Global => (In_Out => Device);

   --  A standard GET_DESCRIPTOR request to the device.
   procedure Get_Descriptor
     (Value, Index : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean)
   with Global => (In_Out => Device), Pre => Data'Length <= Max_Length, Post => Got <= Data'Length;

   --  A DFU class request to interface 0 with its data out.
   procedure Send (Request : Byte; Value : Interfaces.Unsigned_16; Data : Byte_Array; Ok : out Boolean)
   with Global => (In_Out => Device), Pre => Data'Length <= Max_Length;

   --  A DFU class request to interface 0 with its data in.
   procedure Receive
     (Request : Byte; Value : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean)
   with Global => (In_Out => Device), Pre => Data'Length <= Max_Length, Post => Got <= Data'Length;

   procedure Wait (Milliseconds : Natural)
   with Global => (In_Out => Device);

end DFU.Transport;
