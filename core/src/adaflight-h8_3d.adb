with Adaflight.XN297;

package body Adaflight.H8_3D with SPARK_Mode is
   use Adaflight.NRF24L01;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   package Radio renames Adaflight.SPI_Radio;

   Address : constant Adaflight.XN297.Address := (16#41#, 16#BD#, 16#42#, 16#D4#, 16#C2#);
   Bind_Channel_Start : constant := 16#06#;
   Bind_Channel_End   : constant := 16#26#;
   Data_Hop_Timeout_Us : constant := 5_000;
   PWM_Min : constant := 1_000;
   PWM_Mid : constant := 1_500;
   PWM_Max : constant := 2_000;

   procedure Hop (S : in out State; O : in out Radio.Output) is
   begin
      S.Channel_Index := S.Channel_Index + 1;
      if S.Phase = Bind then
         if S.Channel_Index > Bind_Channel_End then
            S.Channel_Index := Bind_Channel_Start;
         end if;
         Set_Channel (O, S.Channel_Index);
      else
         if S.Channel_Index >= 4 then
            S.Channel_Index := 0;
         end if;
         Set_Channel (O, S.Channels (Natural (S.Channel_Index)));
      end if;
   end Hop;

   procedure Set_Bound (S : in out State; Id : Transmitter_Id; Now_Us : Unsigned_32; O : in out Radio.Output) is
   begin
      S.Phase := Data;
      for I in 0 .. 3 loop
         S.Channels (I) := Unsigned_8 (16#06# + 16#0F# * I
                                       + (Natural (Interfaces.Shift_Right (Id (I), 4)) + Natural (Id (I) and 16#0F#))
                                         mod 16#0F#);
      end loop;
      S.Hop_Timeout_Us := Data_Hop_Timeout_Us;
      S.Time_Of_Last_Hop := Now_Us;
      S.Channel_Index := 0;
      Set_Channel (O, S.Channels (0));
   end Set_Bound;

   function Id_Of (Word : Unsigned_32) return Transmitter_Id is
     (Unsigned_8 (Word and 16#FF#), Unsigned_8 (Interfaces.Shift_Right (Word, 8) and 16#FF#),
      Unsigned_8 (Interfaces.Shift_Right (Word, 16) and 16#FF#), Unsigned_8 (Interfaces.Shift_Right (Word, 24)));

   function Word_Of (Id : Transmitter_Id) return Unsigned_32 is
     (Unsigned_32 (Id (0)) or Interfaces.Shift_Left (Unsigned_32 (Id (1)), 8)
      or Interfaces.Shift_Left (Unsigned_32 (Id (2)), 16) or Interfaces.Shift_Left (Unsigned_32 (Id (3)), 24));

   --  A pulse from a byte between two ends with the truncating division of
   --  C, in sixteen bits.
   function Pulse (Value : Unsigned_8; Low, High : Integer) return Unsigned_16 is
     (Unsigned_16'Mod (PWM_Min + ((Integer (Value) - Low) * 1000) / (High - Low)))
     with Pre => Low in -256 .. 256 and then High in -256 .. 256 and then High /= Low;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Stored_Id : Unsigned_32; Now_Us : Unsigned_32; O : out Radio.Output) is
   begin
      S := (others => <>);
      O := (others => <>);
      S.Stored_Id := Stored_Id;
      S.Phase := Bind;
      Initialize (S.Radio, O, 0, Now_Us);
      Setup_Basic (O);
      Write_Reg (O, RF_SETUP, RF_DR_1M or RF_PWR_N12);
      Write_Register_Multi (O, RX_ADDR_P0, (Address (0), Address (1), Address (2), Address (3), Address (4)));
      if Stored_Id = 0 then
         S.Channel_Index := Bind_Channel_Start;
         Set_Channel (O, Bind_Channel_Start);
      else
         Set_Bound (S, Id_Of (Stored_Id), Now_Us, O);
      end if;
      Write_Reg (O, RX_PW_P0, Payload_Size + CRC_Length);
      Set_Rx_Mode (S.Radio, O);
   end Init;

   -------------------
   -- Data_Received --
   -------------------

   procedure Data_Received (S : in out State; Now_Us : Unsigned_32; Fifo_Status : Unsigned_8;
                            Buffer : in out Payload_Buffer; O : out Radio.Output; R : out Result)
   is
      Available : Boolean;
      Received  : Boolean := False;
      Check     : Unsigned_16;
   begin
      O := (others => <>);
      R := None;
      Read_Payload_If_Available (O, Fifo_Status, Payload_Size + CRC_Length, Available);
      if Available then
         Adaflight.XN297.Unscramble (Buffer, Payload_Size, Address, Check);
         Received := Buffer (Payload_Size) = Unsigned_8 (Interfaces.Shift_Right (Check, 8))
           and then Buffer (Payload_Size + 1) = Unsigned_8 (Check and 16#FF#);
      end if;
      case S.Phase is
         when Bind =>
            if Received
              and then Buffer (5) = 0 and then Buffer (6) = 0 and then Buffer (7) = 1
              and then Buffer (1) + Buffer (2) + Buffer (3) + Buffer (4) = Buffer (8)
            then
               declare
                  Id : constant Transmitter_Id := (Buffer (1), Buffer (2), Buffer (3), Buffer (4));
               begin
                  S.Tx_Id := Id;
                  if S.Stored_Id = 0 then
                     S.Stored_Id := Word_Of (Id);
                  end if;
                  R := Bind_Received;
                  Set_Bound (S, Id, Now_Us, O);
               end;
            end if;
         when Data =>
            if Received then
               R := Data_Received_Result;
            end if;
      end case;
      if R = Data_Received_Result or else Now_Us > S.Time_Of_Last_Hop + S.Hop_Timeout_Us then
         Hop (S, O);
         S.Time_Of_Last_Hop := Now_Us;
      end if;
   end Data_Received;

   -----------------
   -- Set_RC_Data --
   -----------------

   procedure Set_RC_Data (Buffer : Payload_Buffer; RC : in out RC_Channels) is
      function Switch (On : Boolean) return Unsigned_16 is (if On then PWM_Max else PWM_Min);
      Flags  : constant Unsigned_8 := Buffer (17);
      Flags2 : constant Unsigned_8 := Buffer (18);
   begin
      RC (0) := Pulse (Buffer (12), 16#BB#, 16#43#);
      RC (1) := Pulse (Buffer (11), 16#43#, 16#BB#);
      RC (2) := Pulse (Buffer (9), 0, 16#FF#);
      RC (3) := (if Buffer (10) < 16#80# then Pulse (Buffer (10), -16#3C#, 16#3C#)
                 else Pulse (Buffer (10), 16#BC#, 16#44#));
      RC (4) := (if (Flags and 16#04#) /= 0 then PWM_Max elsif (Flags and 16#02#) /= 0 then PWM_Mid else PWM_Min);
      RC (5) := Switch ((Flags and 16#01#) /= 0);
      RC (6) := Switch ((Flags2 and 16#40#) /= 0);
      RC (7) := Switch ((Flags2 and 16#80#) /= 0);
      RC (8) := Switch ((Flags and 16#10#) /= 0);
      RC (9) := Switch ((Flags and 16#20#) /= 0);
      RC (10) := (if (Flags2 and 16#04#) /= 0 then PWM_Max elsif (Flags2 and 16#08#) /= 0 then PWM_Min else PWM_Mid);
      RC (11) := Pulse (Buffer (14), 16#10#, 16#30#);
      RC (12) := Pulse (Buffer (15), 16#30#, 16#10#);
      RC (13) := Pulse (Buffer (16), 16#10#, 16#30#);
   end Set_RC_Data;

end Adaflight.H8_3D;
