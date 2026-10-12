with Adaflight.Clock;

package body Adaflight.SBUS with SPARK_Mode is
   use type Interfaces.Integer_32;

   Time_Per_Frame_Us    : constant := 3_000;
   Time_Per_Byte_Us     : constant := Time_Per_Frame_Us / Frame_Size;
   Interbyte_Timeout_Us : constant := 5 * Time_Per_Byte_Us;
   Flag_Channel_17  : constant := 1;
   Flag_Channel_18  : constant := 2;
   Flag_Signal_Loss : constant := 4;
   Flag_Failsafe    : constant := 8;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Mid_RC : Center_Us) is
      Center : constant Channel_Value := (16 * Mid_RC) / 10 - 1_408;
   begin
      S := (Frame => <>, Data => (others => Center), Last_Frame_Time_Us => 0);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Interbyte : constant Interfaces.Integer_32 := Clock.Elapsed (Now_Us, S.Frame.Last_Byte_At_Us);
   begin
      S.Frame.Last_Byte_At_Us := Now_Us;
      if Interbyte > Interbyte_Timeout_Us then
         S.Frame.Position := 0;
      end if;
      if S.Frame.Position = 0 then
         if C /= Begin_Byte then
            return;
         end if;
         S.Frame.Start_At_Us := Now_Us;
      end if;
      if S.Frame.Position < Frame_Size then
         S.Frame.Bytes (S.Frame.Position) := C mod 256;
         S.Frame.Position := S.Frame.Position + 1;
         S.Frame.Done := S.Frame.Position = Frame_Size;
      end if;
   end Receive_Byte;

   --  The eleven bits of a channel from the little-endian bit stream of the
   --  twenty-two channel bytes.
   function Channel_Bits (Block : Channel_Block; Ch : Packed_Channel) return Channel_Value is
      Bit   : constant Natural range 0 .. 165 := 11 * Ch;
      Index : constant Natural range 0 .. 20 := Bit / 8;
      Shift : constant Natural range 0 .. 7 := Bit mod 8;
      Word  : constant Unsigned_32 :=
        Unsigned_32 (Block (Index))
        + Unsigned_32 (Block (Index + 1)) * 2 ** 8
        + Unsigned_32 (Block (Index + 2)) * 2 ** 16;
   begin
      return Channel_Value (Interfaces.Shift_Right (Word, Shift) and 16#7FF#);
   end Channel_Bits;

   ------------
   -- Decode --
   ------------

   procedure Decode (Block : Channel_Block; Data : in out Channel_Data; Status : out Receiver.Frame_Report) is
      Flags : constant Byte := Block (Block_Size - 1);
   begin
      Status := (others => False);
      for Ch in Packed_Channel loop
         Data (Ch) := Channel_Bits (Block, Ch);
      end loop;
      Data (16) := (if (Flags / Flag_Channel_17) mod 2 = 1 then Digital_Channel_Max else Digital_Channel_Min);
      Data (17) := (if (Flags / Flag_Channel_18) mod 2 = 1 then Digital_Channel_Max else Digital_Channel_Min);
      Status.Complete := True;
      if (Flags / Flag_Failsafe) mod 2 = 1 then
         Status.Failsafe := True;
      elsif (Flags / Flag_Signal_Loss) mod 2 = 1 then
         Status.Dropped := True;
      end if;
   end Decode;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Status : out Receiver.Frame_Report) is
      Block : Channel_Block;
   begin
      Status := (others => False);
      if not S.Frame.Done then
         return;
      end if;
      S.Frame.Done := False;
      for I in Block_Index loop
         Block (I) := S.Frame.Bytes (I + 1);
      end loop;
      Decode (Block, S.Data, Status);
      if not (Status.Failsafe or else Status.Dropped) then
         S.Last_Frame_Time_Us := S.Frame.Start_At_Us;
      end if;
   end Frame_Status;

end Adaflight.SBUS;
