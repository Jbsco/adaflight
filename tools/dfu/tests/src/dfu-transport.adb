with Model_Device;

package body DFU.Transport with SPARK_Mode => Off is

   procedure Open (Ok : out Boolean) is
   begin
      Ok := Model_Device.Is_Present;
   end Open;

   procedure Close is null;

   procedure Get_Descriptor
     (Value, Index : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean) is
   begin
      Model_Device.Descriptor (Value, Index, Data, Got, Ok);
   end Get_Descriptor;

   procedure Send (Request : Byte; Value : Interfaces.Unsigned_16; Data : Byte_Array; Ok : out Boolean) is
   begin
      Model_Device.Out_Request (Request, Value, Data, Ok);
   end Send;

   procedure Receive
     (Request : Byte; Value : Interfaces.Unsigned_16; Data : out Byte_Array; Got : out Natural; Ok : out Boolean) is
   begin
      Model_Device.In_Request (Request, Value, Data, Got, Ok);
   end Receive;

   procedure Wait (Milliseconds : Natural) is null;

end DFU.Transport;
