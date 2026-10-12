--  The MSP receiver: the channels a configurator or companion sends over
--  MSP, the channels it leaves out reset to zero, the frame marked done for
--  the receiver and for the override path, the freshness of a channel within
--  the window since the last frame, and the raw channel value the receiver
--  reads.
with Interfaces;
with Adaflight.Receiver;

package Adaflight.MSP_Receiver with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Time_Us is Unsigned_32;
   subtype Time_Ms is Unsigned_32;

   Channel_Count : constant := 18;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Count_Range is Natural range 0 .. Channel_Count;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;

   --  A channel is fresh while a frame that carried it arrived within this
   --  window.
   Fresh_Window_Ms : constant := 300;

   type State is record
      Data               : Channel_Data := (others => 0);
      Frame_Done         : Boolean := False;
      Override_Done      : Boolean := False;
      Ever_Received      : Boolean := False;
      Last_Frame_Ms      : Time_Ms := 0;
      Last_Frame_Count   : Count_Range := 0;
      Last_Frame_Time_Us : Time_Us := 0;
   end record;

   procedure Init (S : out State);

   --  A frame from the MSP command handler: its channels, zero for the rest,
   --  both frames marked done, and the time and count kept for freshness.
   procedure Frame_Receive (S : in out State; Frame : Channel_Data; Count : Count_Range; Now_Ms : Time_Ms);

   --  A channel is fresh when a frame has ever arrived, the last frame
   --  carried the channel, and it arrived within the window.
   function Is_Channel_Fresh (S : State; Ch : Channel; Now_Ms : Time_Ms) return Boolean;

   --  Complete once per frame, stamped at the poll.
   procedure Frame_Status (S : in out State; Now_Us : Time_Us; Status : out Receiver.Frame_Report);

   --  Complete once per frame for the override path.
   procedure Override_Frame_Status (S : in out State; Complete : out Boolean);

   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.MSP_Receiver;
