with Adaflight.Bytes;
with Adaflight.Clock;

package body Adaflight.SUMD with SPARK_Mode is
   use type Interfaces.Integer_32;

   Header_Length : constant := 3;
   CRC_Length    : constant := 2;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
   begin
      if Clock.Elapsed (Now_Us, S.Time_Last_Us) > Time_Per_Frame_Us then
         S.Index := 0;
      end if;
      S.Time_Last_Us := Now_Us;
      if S.Index = 0 then
         if C /= Sync_Byte then
            return;
         end if;
         S.Done := False;
         S.CRC := 0;
      elsif S.Index = 2 then
         S.Channel_Count := C mod 256;
      end if;
      if S.Index < Buffer_Size then
         S.Bytes (S.Index) := C mod 256;
      end if;
      S.Index := (S.Index + 1) mod 256;
      if S.Index <= S.Channel_Count * 2 + Header_Length then
         S.CRC := Bytes.CRC16_CCITT (S.CRC, Bytes.Byte (C mod 256));
      elsif S.Index = S.Channel_Count * 2 + Header_Length + CRC_Length then
         S.Last_Frame_Us := Now_Us;
         S.Index := 0;
         S.Done := True;
      end if;
   end Receive_Byte;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
      Base : constant Natural := 2 * S.Channel_Count + Header_Length;
   begin
      Status := (others => False);
      if not S.Done then
         return;
      end if;
      S.Done := False;
      if S.Channel_Count > Max_Channels then
         return;
      end if;
      if S.CRC = Unsigned_16 (S.Bytes (Base)) * 256 + Unsigned_16 (S.Bytes (Base + 1)) then
         case S.Bytes (1) is
            when State_Failsafe =>
               Status.Complete := True;
               Status.Failsafe := True;
            when State_V1_OK | State_V3_OK =>
               Status.Complete := True;
            when others =>
               null;
         end case;
         if Status.Complete then
            for Ch in 0 .. Natural'Min (S.Channel_Count, Receiver.Channel_Count) - 1 loop
               S.Data (Ch) := S.Bytes (2 * Ch + Header_Length) * 256 + S.Bytes (2 * Ch + Header_Length + 1);
            end loop;
         end if;
      end if;
   end Frame_Status;

end Adaflight.SUMD;
