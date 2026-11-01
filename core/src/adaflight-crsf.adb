with Adaflight.Bytes;
with Adaflight.Clock;

package body Adaflight.CRSF with SPARK_Mode is
   use type Interfaces.Integer_64;
   use type Receiver.RSSI_Source;
   use type Receiver.Link_Quality_Source;

   Length_Type_CRC   : constant := 2;
   Origin_Dest_Size  : constant := 2;
   Statistics_Size   : constant := 10;
   Statistics_Tx_Size : constant := 6;
   Poly_DVB_S2       : constant := 16#D5#;
   Poly_Command      : constant := 16#BA#;
   RSSI_Min_Dbm      : constant := -130;
   SNR_Min           : constant := -30;

   type Power_Table is array (0 .. 8) of Receiver.Unsigned_16;
   Uplink_Power_mW : constant Power_Table := (0, 10, 25, 100, 500, 1000, 2000, 250, 50);

   function Signed_8 (B : Byte) return Integer is (if B >= 128 then B - 256 else B);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Mid_RC : Center_Us) is
      Center : constant Channel_Value := (16 * Mid_RC) / 10 - 1_408;
   begin
      S := (Data => (others => Center), others => <>);
   end Init;

   --  The CRC over the type and the payload with the DVB-S2 polynomial, and
   --  the command CRC over all but the last with the command polynomial.
   function Frame_CRC (F : Frame_Bytes; Length : Frame_Length; Poly : Byte; Skip : Skip_Count) return Byte
     with Pre => Length >= Length_Type_CRC + Skip and then Length <= Frame_Size_Max - 2
   is
      CRC : Bytes.Byte := Bytes.CRC8 (0, Bytes.Byte (F (2)), Bytes.Byte (Poly));
   begin
      for I in 0 .. Length - Length_Type_CRC - Skip - 1 loop
         CRC := Bytes.CRC8 (CRC, Bytes.Byte (F (3 + I)), Bytes.Byte (Poly));
      end loop;
      return Byte (CRC);
   end Frame_CRC;

   function Length_Valid (Length : Byte) return Boolean is
     (Length >= Length_Type_CRC and then Length <= Frame_Size_Max - 2);

   --  The link statistics into the receiver: the RSSI of the active antenna
   --  in dBm scaled onto the RSSI range, the SNR, the link quality and RF
   --  mode when the protocol owns them, and the uplink power from its table.
   procedure Handle_Statistics (S : in out State; Rx : in out Receiver.State; Now_Us : Time_Us) is
      RSSI_1   : constant Byte := S.Frame (3);
      RSSI_2   : constant Byte := S.Frame (4);
      Quality  : constant Byte := S.Frame (5);
      SNR      : constant Integer := Signed_8 (S.Frame (6));
      Antenna  : constant Byte := S.Frame (7);
      RF_Mode  : constant Byte := S.Frame (8);
      Power    : constant Byte := S.Frame (9);
      Dbm      : constant Integer range -255 .. 0 := -(if Antenna /= 0 then RSSI_2 else RSSI_1);
      Factor   : constant Float := Float (Receiver.RSSI_Max - 0) / Float (0 - RSSI_Min_Dbm);
      Offset   : constant Float := Float (0) - Factor * Float (RSSI_Min_Dbm);
   begin
      S.Last_Stats_Us := Now_Us;
      if Rx.RSSI_From = Receiver.Protocol_CRSF then
         declare
            Scaled : constant Float range 0.0 .. 3_000.0 := Float'Max (0.0, Float (Dbm) * Factor + Offset);
            Whole  : constant Integer range 0 .. 3_000 := Integer (Float'Truncation (Scaled));
         begin
            Receiver.Set_RSSI (Rx, Whole, Receiver.Protocol_CRSF);
         end;
      end if;
      Receiver.Set_RSSI_Dbm (Rx, Dbm, Receiver.Protocol_CRSF);
      Receiver.Set_Active_Antenna (Rx, Antenna mod 128 - (if Antenna >= 128 then 128 else 0));
      Receiver.Set_RSNR (Rx, SNR);
      if Rx.Quality_From = Receiver.CRSF then
         Receiver.Set_Link_Quality_Direct (Rx, Quality);
         Receiver.Set_RF_Mode (Rx, RF_Mode);
      end if;
      Receiver.Set_Uplink_Power (Rx, Uplink_Power_mW (if Power < 9 then Power else 0));
      S.Taps.Stats_Set := True;
      S.Taps.Uplink_RSSI_1 := RSSI_1;
      S.Taps.Uplink_RSSI_2 := RSSI_2;
      S.Taps.Uplink_Quality := Quality;
      S.Taps.Uplink_SNR := SNR;
      S.Taps.Active_Antenna := Antenna;
      S.Taps.RF_Mode := RF_Mode;
      S.Taps.Uplink_Power := Power;
      S.Taps.Downlink_RSSI := S.Frame (10);
      S.Taps.Downlink_Quality := S.Frame (11);
      S.Taps.Downlink_SNR := Signed_8 (S.Frame (12));
   end Handle_Statistics;

   --  The transmitter's statistics of the third protocol version: the
   --  percentage onto the RSSI range, the dBm, the SNR, and the link quality.
   procedure Handle_Statistics_Tx (S : in out State; Rx : in out Receiver.State; Now_Us : Time_Us) is
      RSSI     : constant Byte := S.Frame (3);
      Percent  : constant Byte := S.Frame (4);
      Quality  : constant Byte := S.Frame (5);
      SNR      : constant Integer := Signed_8 (S.Frame (6));
      Factor   : constant Float := Float (Receiver.RSSI_Max - 0) / Float (100 - 0);
   begin
      S.Last_Stats_Us := Now_Us;
      if Rx.RSSI_From = Receiver.Protocol_CRSF then
         declare
            Scaled : constant Float range 0.0 .. 3_000.0 := Float (Percent) * Factor + 0.0;
            Whole  : constant Integer range 0 .. 3_000 := Integer (Float'Truncation (Scaled));
         begin
            Receiver.Set_RSSI (Rx, Whole, Receiver.Protocol_CRSF);
         end;
      end if;
      Receiver.Set_RSSI_Dbm (Rx, -RSSI, Receiver.Protocol_CRSF);
      Receiver.Set_RSNR (Rx, SNR);
      if Rx.Quality_From = Receiver.CRSF then
         Receiver.Set_Link_Quality_Direct (Rx, Quality);
      end if;
      S.Taps.Tx_Set := True;
      S.Taps.Tx_RSSI := RSSI;
      S.Taps.Tx_SNR := SNR;
      S.Taps.Tx_Quality := Quality;
      S.Taps.Tx_Percent := Percent;
   end Handle_Statistics_Tx;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (
      S              : in out State;
      Rx             : in out Receiver.State;
      C              : Serial_Word;
      Now_Us         : Time_Us;
      Negotiating    : Boolean;
      Eeprom_Writing : Boolean;
      Result         : out Byte_Outputs
   ) is
      Full_Length : Frame_Length;
   begin
      Result := (others => False);
      if Clock.Elapsed (Now_Us, S.Start_At_Us) > S.Frame_Time_Us then
         if S.Position > 0 then
            S.Error_Count := (S.Error_Count + 1) mod 256;
         end if;
         S.Position := 0;
      end if;
      if S.Position = 0 then
         S.Start_At_Us := Now_Us;
      end if;
      if S.Position = 2 and then not Length_Valid (S.Frame (1)) then
         S.Position := 0;
         return;
      end if;
      Full_Length := (if S.Position < 3 then 5 else Natural'Min (S.Frame (1) + 2, Frame_Size_Max));
      if S.Position < Full_Length then
         S.Frame (S.Position) := C mod 256;
         S.Position := S.Position + 1;
         if S.Position >= Full_Length then
            S.Position := 0;
            if Length_Valid (S.Frame (1))
              and then Frame_CRC (S.Frame, S.Frame (1), Poly_DVB_S2, 0) = S.Frame (Full_Length - 1)
            then
               S.Error_Count := 0;
               Result.Telemetry_Response := True;
               case S.Frame (2) is
                  when Type_RC_Channels_Packed | Type_Subset_RC_Channels =>
                     if S.Frame (0) = Address_Flight_Controller then
                        S.Last_Frame_Us := Now_Us;
                        S.Channel_Frame := S.Frame;
                        S.Done := True;
                     end if;
                  when Type_Link_Statistics =>
                     if Rx.RSSI_From = Receiver.Protocol_CRSF and then S.Frame (0) = Address_Flight_Controller
                       and then S.Frame (1) = Origin_Dest_Size + Statistics_Size
                     then
                        Handle_Statistics (S, Rx, Now_Us);
                     end if;
                  when Type_Link_Statistics_Tx =>
                     if Rx.RSSI_From = Receiver.Protocol_CRSF and then S.Frame (0) = Address_Flight_Controller
                       and then S.Frame (1) = Origin_Dest_Size + Statistics_Tx_Size
                     then
                        Handle_Statistics_Tx (S, Rx, Now_Us);
                     end if;
                  when Type_MSP_Request | Type_MSP_Write =>
                     Result.MSP_Frame := S.Frame (1) >= 4;
                  when Type_Device_Ping =>
                     Result.Device_Ping := True;
                  when Type_Device_Info =>
                     Result.Device_Info := True;
                  when Type_Display_Port =>
                     Result.Display_Port := True;
                  when Type_Command =>
                     if Full_Length >= 5 and then S.Frame (1) >= Length_Type_CRC + 1
                       and then S.Frame (Full_Length - 2) = Frame_CRC (S.Frame, S.Frame (1), Poly_Command, 1)
                       and then S.Frame (3) = Address_Flight_Controller
                     then
                        Result.Command := True;
                     end if;
                  when others =>
                     null;
               end case;
            elsif S.Error_Count < Error_Threshold then
               S.Error_Count := S.Error_Count + 1;
            end if;
         end if;
         if Negotiating or else Eeprom_Writing then
            S.Error_Count := 0;
         elsif S.Error_Count >= Error_Threshold then
            Result.Default_Speed := True;
            S.Error_Count := 0;
         end if;
      end if;
   end Receive_Byte;

   --  The sixteen packed eleven-bit channels of the legacy frame.
   function Packed_Channel (F : Frame_Bytes; Ch : Channel) return Channel_Value is
      Bit   : constant Natural range 0 .. 165 := 11 * Ch;
      Index : constant Natural range 3 .. 23 := 3 + Bit / 8;
      Shift : constant Natural range 0 .. 7 := Bit mod 8;
      Word  : constant Unsigned_32 :=
        Unsigned_32 (F (Index)) + Unsigned_32 (F (Index + 1)) * 2 ** 8
        + Unsigned_32 (F (Index + 2)) * 2 ** 16;
   begin
      return Channel_Value (Interfaces.Shift_Right (Word, Shift) and 16#7FF#);
   end Packed_Channel;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report
   ) is
   begin
      Status := (others => False);
      if Clock.Elapsed (Now_Us, S.Last_Stats_Us) > Statistics_Timeout_Us then
         if Rx.RSSI_From = Receiver.Protocol_CRSF then
            Receiver.Set_RSSI_Direct (Rx, 0, Receiver.Protocol_CRSF);
            Receiver.Set_RSSI_Dbm_Direct (Rx, RSSI_Min_Dbm, Receiver.Protocol_CRSF);
            Receiver.Set_RSNR_Direct (Rx, SNR_Min);
         end if;
         if Rx.Quality_From = Receiver.CRSF then
            Receiver.Set_Link_Quality_Direct (Rx, 0);
         end if;
      end if;
      if not S.Done then
         return;
      end if;
      S.Done := False;
      if S.Channel_Frame (2) = Type_RC_Channels_Packed then
         S.Scale := Legacy_Scale;
         for Ch in Channel loop
            S.Data (Ch) := Packed_Channel (S.Channel_Frame, Ch);
         end loop;
      else
         declare
            Config        : constant Byte := S.Channel_Frame (3);
            Start_Channel : constant Natural range 0 .. 31 := Config mod 32;
            Resolution    : constant Natural range 0 .. 3 := (Config / 32) mod 4;
            Channel_Bits  : constant Natural range 10 .. 13 := 10 + Resolution;
            Mask          : constant Unsigned_32 := 2 ** Channel_Bits - 1;
            Packed_Length : constant Integer range -3 .. 252 := Integer (S.Channel_Frame (1)) - Length_Type_CRC - 1;
            Count         : constant Natural range 0 .. 255 :=
              (if Packed_Length > 0 then (Packed_Length * 8) / Channel_Bits else 0);
            Index         : Natural range 4 .. Frame_Size_Max := 4;
            Merged        : Natural range 0 .. 31 := 0;
            Value         : Unsigned_32 := 0;
         begin
            if Count = 0 or else Start_Channel >= Channel_Count then
               Status.Dropped := True;
               return;
            end if;
            S.Scale := (case Resolution is when 0 => 1.0, when 1 => 0.5, when 2 => 0.25, when 3 => 0.125);
            for N in 0 .. Natural'Min (Count, Channel_Count - Start_Channel) - 1 loop
               pragma Loop_Invariant (Merged < Channel_Bits);
               while Merged < Channel_Bits loop
                  pragma Loop_Invariant (Merged < Channel_Bits);
                  exit when Index = Frame_Size_Max;
                  Value := Value or Interfaces.Shift_Left (Unsigned_32 (S.Channel_Frame (Index)), Merged);
                  Index := Index + 1;
                  Merged := Merged + 8;
               end loop;
               exit when Merged < Channel_Bits;
               S.Data (Start_Channel + N) := Channel_Value (Value and Mask);
               Value := Interfaces.Shift_Right (Value, Channel_Bits);
               Merged := Merged - Channel_Bits;
            end loop;
         end;
      end if;
      Status.Complete := True;
   end Frame_Status;

   ---------------------
   -- Update_Baudrate --
   ---------------------

   procedure Update_Baudrate (S : in out State; Rate : Unsigned_32) is
   begin
      if Rate > 0 then
         S.Frame_Time_Us := Time_Delta (Interfaces.Integer_64'Min (
           (Interfaces.Integer_64 (Time_Per_Frame_Us) * Interfaces.Integer_64 (Baudrate)
              + Interfaces.Integer_64 (Rate) - 1) / Interfaces.Integer_64 (Rate),
           Interfaces.Integer_64 (Time_Delta'Last)));
      else
         S.Frame_Time_Us := Time_Per_Frame_Us;
      end if;
      S.Event_Telemetry := Rate > Baudrate;
   end Update_Baudrate;

end Adaflight.CRSF;
