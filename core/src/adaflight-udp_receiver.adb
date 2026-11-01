package body Adaflight.UDP_Receiver with SPARK_Mode is

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   procedure Update_Channels (S : in out State; Frame : Channel_Data; Count : Count_Range) is
   begin
      for Ch in 0 .. Count - 1 loop
         S.Data (Ch) := Frame (Ch);
      end loop;
      S.Count := Count;
      S.Received := True;
   end Update_Channels;

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      Status.Complete := S.Received;
      S.Received := False;
   end Frame_Status;

end Adaflight.UDP_Receiver;
