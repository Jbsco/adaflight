package body Adaflight.ExpressLRS_Telemetry with SPARK_Mode is

   ------------------
   -- Reset_Sender --
   ------------------

   procedure Reset_Sender (S : out Sender) is
   begin
      S := (others => <>);
   end Reset_Sender;

   --------------
   -- Set_Data --
   --------------

   procedure Set_Data (S : in out Sender; Data : Byte_Array) is
   begin
      S.Offset := 0;
      S.Length := Data'Length;
      for I in 0 .. Data'Length - 1 loop
         S.Data (I) := Data (Data'First + I);
      end loop;
      S.Current_Package := 1;
      S.Wait_Count := 0;
      S.State := (if S.State = Idle then Send_Pending else Resync_Then_Send);
   end Set_Data;

   ---------------------
   -- Current_Payload --
   ---------------------

   procedure Current_Payload (S : in out Sender; Out_Data : out Chunk; Max_Len : Chunk_Length;
                              Package_Index : out Byte) is
   begin
      Out_Data := (others => 0);
      S.Bytes_Last_Payload := 0;
      case S.State is
         when Resync | Resync_Then_Send =>
            Package_Index := Max_Packages;

         when Send_Pending | Sending =>
            --  The package can be confirmed from here on.
            S.State := Sending;
            S.Bytes_Last_Payload := Natural'Min (S.Length - S.Offset, Max_Len);
            --  The last chunk of a frame with more than one skips the blank
            --  package the confirm wait would need.
            if S.Current_Package > 1 and then S.Offset + S.Bytes_Last_Payload >= S.Length then
               Package_Index := 0;
            else
               Package_Index := S.Current_Package;
            end if;
            for I in 0 .. S.Bytes_Last_Payload - 1 loop
               Out_Data (I) := S.Data (S.Offset + I);
            end loop;

         when Idle | Wait_Until_Next_Confirm =>
            Package_Index := 0;
      end case;
   end Current_Payload;

   -------------
   -- Confirm --
   -------------

   procedure Confirm (S : in out Sender; Value : Boolean) is
      Next : Sender_State := S.State;
   begin
      case S.State is
         when Sending =>
            if Value /= S.Wait_Until_Confirm then
               S.Wait_Count := S.Wait_Count + 1;
               if S.Wait_Count > S.Max_Wait_Count then
                  S.Wait_Until_Confirm := not Value;
                  Next := Resync;
               end if;
            else
               --  The chunk handed out came from this position, so it fits
               --  the frame; a frame changed since is held at its end.
               if S.Offset + S.Bytes_Last_Payload <= S.Length then
                  S.Offset := S.Offset + S.Bytes_Last_Payload;
               else
                  S.Offset := S.Length;
               end if;
               if S.Offset >= S.Length then
                  --  A zeroth package always follows so the transmitter tells
                  --  a new frame from a resend: after a first package acked,
                  --  one more is sent, else the sender is done.
                  Next := (if S.Current_Package = 1 then Wait_Until_Next_Confirm else Idle);
               end if;
               S.Current_Package := S.Current_Package + 1;
               S.Wait_Until_Confirm := not S.Wait_Until_Confirm;
               S.Wait_Count := 0;
            end if;

         when Resync | Resync_Then_Send | Wait_Until_Next_Confirm =>
            if Value = S.Wait_Until_Confirm then
               Next := (if S.State = Resync_Then_Send then Sending else Idle);
               S.Wait_Until_Confirm := not Value;
            elsif S.State = Wait_Until_Next_Confirm then
               --  The transmitter did not confirm in time: resync.
               S.Wait_Count := S.Wait_Count + 1;
               if S.Wait_Count > S.Max_Wait_Count then
                  S.Wait_Until_Confirm := not Value;
                  Next := Resync;
               end if;
            end if;

         when Send_Pending | Idle =>
            --  Confirms are not taken before sending.
            null;
      end case;
      S.State := Next;
   end Confirm;

   -----------------
   -- Update_Rate --
   -----------------

   procedure Update_Rate (S : in out Sender; Ratio : Natural; Burst : Positive) is
      Packets_Between : constant Natural := Ratio * (1 + Burst) / Burst;
   begin
      S.Max_Wait_Count := Unsigned_16'Mod (Packets_Between * Max_Missed_Packets);
   end Update_Rate;

   --------------------
   -- Reset_Receiver --
   --------------------

   procedure Reset_Receiver (R : in out Receiver) is
   begin
      R.Offset := 0;
      R.Current_Package := 1;
      R.Confirm := False;
   end Reset_Receiver;

   ------------------------
   -- Set_Receive_Length --
   ------------------------

   procedure Set_Receive_Length (R : in out Receiver; Max_Length : MSP_Length) is
   begin
      R.Offset := 0;
      R.Length := Max_Length;
      R.Current_Package := 1;
      R.Finished := False;
   end Set_Receive_Length;

   -------------
   -- Receive --
   -------------

   procedure Receive (R : in out Receiver; Package_Index : Byte; Payload : Chunk) is
      Accept_Data : Boolean := False;
   begin
      if Package_Index = MSP_Max_Packages then
         R.Confirm := not R.Confirm;
         R.Current_Package := 1;
         R.Offset := 0;
         R.Finished := False;
         return;
      end if;
      if R.Finished then
         return;
      end if;

      if Package_Index = 0 and then R.Current_Package > 1 then
         --  The final package can carry data too.
         Accept_Data := True;
         R.Finished := True;
      elsif Package_Index = R.Current_Package then
         Accept_Data := True;
      elsif Package_Index = 1 and then R.Current_Package > 1 then
         --  A first package in mid frame: the transmitter restarted without
         --  a resync, so the frame restarts too.
         R.Current_Package := 1;
         R.Offset := 0;
         Accept_Data := True;
      end if;

      if Accept_Data then
         declare
            Len : constant Chunk_Length := Natural'Min (R.Length - R.Offset, Bytes_Per_Call);
         begin
            for I in 0 .. Len - 1 loop
               R.Data (R.Offset + I) := Payload (I);
            end loop;
            R.Current_Package := R.Current_Package + 1;
            R.Offset := R.Offset + Len;
            R.Confirm := not R.Confirm;
         end;
      end if;
   end Receive;

   ------------
   -- Unlock --
   ------------

   procedure Unlock (R : in out Receiver) is
   begin
      if R.Finished then
         R.Current_Package := 1;
         R.Offset := 0;
         R.Finished := False;
      end if;
   end Unlock;

end Adaflight.ExpressLRS_Telemetry;
