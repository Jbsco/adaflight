--  The UDP receiver: the channels a simulator sends in one packet, kept by
--  channel for the receiver's raw read, and the frame marked complete once
--  per packet, with the packet's channel count for the receiver.
with Adaflight.Receiver;
package Adaflight.UDP_Receiver with SPARK_Mode is

   Channel_Count : constant := 18;
   subtype Channel is Natural range 0 .. Channel_Count - 1;
   subtype Count_Range is Natural range 0 .. Channel_Count;
   subtype Channel_Value is Natural range 0 .. 65_535;
   type Channel_Data is array (Channel) of Channel_Value;

   type State is record
      Data     : Channel_Data := (others => 0);
      Count    : Count_Range := 0;
      Received : Boolean := False;
   end record;

   procedure Init (S : out State);

   --  A packet's channels: the first Count stored, the rest kept from the
   --  packets before, and the frame marked received.
   procedure Update_Channels (S : in out State; Frame : Channel_Data; Count : Count_Range)
     with Post => S.Received and then S.Count = Count;

   --  Complete once per packet; the count of that packet is Count.
   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report)
     with Post => Status.Complete = S.Received'Old and then not S.Received;

   function Count (S : State) return Count_Range is (S.Count);

   function Read_Raw (S : State; Ch : Channel) return Float is (Float (S.Data (Ch)));

end Adaflight.UDP_Receiver;
