package body Adaflight.MSP_Receiver with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   -------------------
   -- Frame_Receive --
   -------------------

   procedure Frame_Receive (S : in out State; Frame : Channel_Data; Count : Count_Range; Now_Ms : Time_Ms) is
   begin
      for I in Channel loop
         S.Data (I) := (if I < Count then Frame (I) else 0);
      end loop;
      S.Frame_Done := True;
      S.Override_Done := True;
      S.Last_Frame_Ms := Now_Ms;
      S.Last_Frame_Count := Count;
      S.Ever_Received := True;
   end Frame_Receive;

   ----------------------
   -- Is_Channel_Fresh --
   ----------------------

   function Is_Channel_Fresh (S : State; Ch : Channel; Now_Ms : Time_Ms) return Boolean is
   begin
      if not S.Ever_Received then
         return False;
      end if;
      if Ch >= S.Last_Frame_Count then
         return False;
      end if;
      return Now_Ms - S.Last_Frame_Ms <= Fresh_Window_Ms;
   end Is_Channel_Fresh;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Now_Us : Time_Us; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if not S.Frame_Done then
         return;
      end if;
      S.Frame_Done := False;
      S.Last_Frame_Time_Us := Now_Us;
      Status.Complete := True;
   end Frame_Status;

   ---------------------------
   -- Override_Frame_Status --
   ---------------------------

   procedure Override_Frame_Status (S : in out State; Complete : out Boolean) is
   begin
      Complete := S.Override_Done;
      S.Override_Done := False;
   end Override_Frame_Status;

end Adaflight.MSP_Receiver;
