with Model_Board;

package body MSP.Transport with SPARK_Mode => Off is

   procedure Open (Target : String; Ok : out Boolean) is
   begin
      Ok := Target'Length > 0 and then Model_Board.Is_Present;
   end Open;

   procedure Close is null;

   procedure Send (Data : Byte_Array; Ok : out Boolean) is
   begin
      Model_Board.Take (Data, Ok);
   end Send;

   procedure Receive (Data : out Byte_Array; Got : out Natural) is
   begin
      Model_Board.Give (Data, Got);
   end Receive;

end MSP.Transport;
