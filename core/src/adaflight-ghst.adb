with Adaflight.Bytes;
with Adaflight.Clock;

package body Adaflight.GHST with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Receiver.RSSI_Source;
   use type Receiver.Link_Quality_Source;

   DVB_S2 : constant := 16#D5#;

   function Validated (S : State) return Buffer_Choice is (1 - S.Incoming);

   --  The CRC over the type and the payload, the length's bytes less the
   --  type and the CRC itself.
   function Frame_CRC (F : Frame_Bytes; Full : Full_Length) return Byte is
      CRC : Bytes.Byte := Bytes.CRC8 (0, Bytes.Byte (F (2)), DVB_S2);
   begin
      for I in 3 .. Full - 2 loop
         CRC := Bytes.CRC8 (CRC, Bytes.Byte (F (I)), DVB_S2);
      end loop;
      return Natural (CRC);
   end Frame_CRC;

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
      if Clock.Elapsed (Now_Us, S.Frame_Start_At_Us) > Max_Frame_Time_Us then
         S.Index := 0;
      end if;
      if S.Index = 0 then
         S.Frame_Start_At_Us := Now_Us;
      end if;
      declare
         Full : constant Natural range 2 .. 257 := (if S.Index < 3 then 5 else S.Buffers (S.Incoming) (1) + 2);
      begin
         if S.Index < Full and then S.Index < Frame_Size then
            S.Buffers (S.Incoming) (S.Index) := C mod 256;
            S.Index := S.Index + 1;
            if S.Index >= Full then
               S.Index := 0;
               if S.Buffers (S.Incoming) (0) = Address_FC then
                  S.Validated_Full := Full;
                  S.Incoming := 1 - S.Incoming;
                  S.Frame_Available := True;
                  S.Frame_End_At_Us := Now_Us;
               end if;
            end if;
         end if;
      end;
   end Receive_Byte;

   --  A reply waits and the bus has been quiet for more than a millisecond
   --  and less than two since the last frame ended.
   function Should_Send_Telemetry (S : State; Now_Us : Time_Us) return Boolean is
      Since_End : constant Interfaces.Integer_32 := Clock.Elapsed (Now_Us, S.Frame_End_At_Us);
   begin
      return S.Telemetry_Length > 0 and then Since_End > Telemetry_Min_Us and then Since_End < Telemetry_Max_Us;
   end Should_Send_Telemetry;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (S : in out State; Now_Us : Time_Us; Status : out Receiver.Frame_Report) is
   begin
      Status := (others => False);
      if S.Frame_Available then
         S.Frame_Available := False;
         declare
            F : constant Frame_Bytes := S.Buffers (Validated (S));
         begin
            if Frame_CRC (F, S.Validated_Full) = F (S.Validated_Full - 1) then
               S.Validated_Available := True;
               S.Last_Frame_Time_Us := S.Frame_End_At_Us;
               Status.Complete := True;
               Status.Processing_Required := True;
            else
               Status.Dropped := True;
            end if;
         end;
      elsif S.Telemetry_Enabled and then Should_Send_Telemetry (S, Now_Us) then
         Status.Processing_Required := True;
      end if;
   end Frame_Status;

   --  The link statistics: the RF protocol with the telemetry it allows,
   --  the RSSI sent sign-inverted and scaled onto the receiver's range as
   --  the reference converts it, the dBm, and the link quality.
   procedure Take_Statistics (S : in out State; Rx : in out Receiver.State; F : Frame_Bytes) is
      LQ   : constant Byte := F (9);
      RSSI : constant Byte := F (10);
      RF   : constant Byte := F (11);
   begin
      S.RF_Protocol := RF;
      S.Telemetry_Enabled := RF in RF_Normal | RF_Race | RF_Long_Range | RF_Race_250;
      if Rx.RSSI_From = Receiver.Rx_Protocol then
         declare
            Scaled  : constant Integer range -2_500 .. 2_100 :=
              Receiver.RSSI_Max * (-RSSI - RSSI_Dbm_Min) / (RSSI_Dbm_Max - RSSI_Dbm_Min);
            Wrapped : constant Natural range 0 .. 65_535 := Scaled mod 65_536;
         begin
            Receiver.Set_RSSI (Rx, Natural'Min (Wrapped, Receiver.RSSI_Max), Receiver.Rx_Protocol);
         end;
      end if;
      Receiver.Set_RSSI_Dbm (Rx, -RSSI, Receiver.Rx_Protocol);
      if Rx.Quality_From = Receiver.GHST then
         Receiver.Set_Link_Quality_Direct (Rx, LQ);
      end if;
   end Take_Statistics;

   --  The four primary channels from their packed twelve bits, the four aux
   --  channels of the frame's turn widened from eight bits, and the legacy
   --  frames rescaled to the twelve-bit range as the reference does, its
   --  sixteen-bit wrap included.
   procedure Take_Channels (S : in out State; F : Frame_Bytes; Start : Natural; Legacy : Boolean)
     with Pre => Start in 0 | 4 | 8 | 12
   is
      Next : Natural range 0 .. 16 := Start;
   begin
      S.Data (0) := F (3) + (F (4) mod 16) * 256;
      S.Data (1) := F (4) / 16 + F (5) * 16;
      S.Data (2) := F (6) + (F (7) mod 16) * 256;
      S.Data (3) := F (7) / 16 + F (8) * 16;
      if Next > 0 then
         S.Data (Next) := F (9) * 4;
         S.Data (Next + 1) := F (10) * 4;
         S.Data (Next + 2) := F (11) * 4;
         S.Data (Next + 3) := F (12) * 4;
         Next := Next + 4;
      end if;
      if Legacy then
         for I in 0 .. 3 loop
            S.Data (I) := ((5 * S.Data (I)) / 4 - 430) mod 65_536;
            if Next > 4 then
               Next := Next - 1;
               S.Data (Next) := (5 * (S.Data (Next) / 4) - 108) mod 65_536;
            end if;
         end loop;
      end if;
   end Take_Channels;

   -------------------
   -- Process_Frame --
   -------------------

   procedure Process_Frame (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Result : out Process_Outputs
   ) is
   begin
      Result := (others => <>);
      if S.Telemetry_Enabled and then Should_Send_Telemetry (S, Now_Us) then
         S.Transmitting_Telemetry := True;
         if S.Telemetry_Length > 0 then
            Result.Telemetry_Sent := True;
            S.Telemetry_Length := 0;
         end if;
      end if;
      if S.Validated_Available then
         S.Validated_Available := False;
         declare
            F      : constant Frame_Bytes := S.Buffers (Validated (S));
            Kind   : constant Byte := F (2);
            Legacy : constant Boolean := Kind in RC_Legacy_First .. RC_Legacy_Last;
            Twelve : constant Boolean := Kind in RC_12_Bit_First .. RC_12_Bit_Last;
         begin
            if Twelve or else Legacy then
               declare
                  Start : Natural range 0 .. 12 := 0;
               begin
                  case Kind mod 16 is
                     when RC_RSSI =>
                        if Kind in RC_Legacy_First + RC_RSSI | RC_12_Bit_First + RC_RSSI then
                           Take_Statistics (S, Rx, F);
                        end if;
                     when RC_5_To_8 =>
                        if Kind in RC_Legacy_First | RC_12_Bit_First then
                           Start := 4;
                        end if;
                     when RC_9_To_12 =>
                        if Kind in RC_Legacy_First + RC_9_To_12 | RC_12_Bit_First + RC_9_To_12 then
                           Start := 8;
                        end if;
                     when RC_13_To_16 =>
                        if Kind in RC_Legacy_First + RC_13_To_16 | RC_12_Bit_First + RC_13_To_16 then
                           Start := 12;
                        end if;
                     when others =>
                        null;
                  end case;
                  if S.RF_Protocol /= RF_Undefined then
                     Take_Channels (S, F, Start, Legacy);
                  end if;
               end;
            else
               case Kind is
                  when MSP_Request =>
                     Result.MSP := Request;
                  when MSP_Write =>
                     Result.MSP := Write;
                  when others =>
                     null;
               end case;
               if Result.MSP /= None then
                  Result.MSP_Length := S.Validated_Full - 4;
               end if;
            end if;
         end;
      end if;
   end Process_Frame;

   ---------------------
   -- Queue_Telemetry --
   ---------------------

   procedure Queue_Telemetry (S : in out State; Length : Natural) is
   begin
      S.Telemetry_Length := Natural'Min (Length, Frame_Size);
   end Queue_Telemetry;

   ----------
   -- Idle --
   ----------

   procedure Idle (S : in out State) is
   begin
      if S.Transmitting_Telemetry then
         S.Transmitting_Telemetry := False;
      end if;
   end Idle;

end Adaflight.GHST;
