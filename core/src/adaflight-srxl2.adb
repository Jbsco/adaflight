with Adaflight.Bytes;
with Adaflight.Clock;

package body Adaflight.SRXL2 with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Receiver.RSSI_Source;

   function Own_Id (S : State) return Byte is
     (Natural (Interfaces.Unsigned_8 (Flight_Controller * 16) or Interfaces.Unsigned_8 (S.Unit_Id)));

   function Process_Buffer (S : State) return Buffer_Choice is (1 - S.Read_Buffer);

   function To_Signed_8 (B : Byte) return Integer is (if B >= 128 then B - 256 else B)
     with Post => To_Signed_8'Result in -128 .. 127;

   --  The CRC-16 over the first bytes of a packet.
   function Packet_CRC (P : Packet_Bytes; Length : Packet_Length) return Unsigned_16 is
      CRC : Unsigned_16 := 0;
   begin
      for I in 0 .. Length - 1 loop
         CRC := Bytes.CRC16_CCITT (CRC, Bytes.Byte (P (I)));
      end loop;
      return CRC;
   end Packet_CRC;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Now_Us : Time_Us) is
   begin
      S := (Unit_Id => C.Unit_Id, Baud_Fast => C.Baud_Fast, Link => Listen_For_Activity,
            Timeout_Us => Now_Us + Listen_For_Activity_Timeout_Us, others => <>);
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
   begin
      S.Last_Receive_Us := Now_Us;
      if S.Buffers (S.Read_Buffer).Len > 0 or else S.Read_Index = Max_Packet_Length then
         S.Read_Index := 0;
         S.Result := (Dropped => True, others => False);
      else
         S.Buffers (S.Read_Buffer).Raw (S.Read_Index) := C mod 256;
         S.Read_Index := S.Read_Index + 1;
      end if;
   end Receive_Byte;

   ----------
   -- Idle --
   ----------

   procedure Idle (S : in out State; Now_Us : Time_Us) is
   begin
      if S.Transmitting then
         S.Transmitting := False;
      elsif S.Read_Index = 0 then
         S.Buffers (S.Read_Buffer).Len := 0;
      else
         S.Last_Idle_Us := Now_Us;
         S.Read_Buffer := 1 - S.Read_Buffer;
         S.Buffers (Process_Buffer (S)).Len := S.Read_Index;
      end if;
      S.Read_Index := 0;
   end Idle;

   ----------------
   -- Write_Data --
   ----------------

   procedure Write_Data (S : in out State; Data : Packet_Bytes; Length : Natural) is
      CRC : constant Unsigned_16 := Packet_CRC (Data, Length - 2);
   begin
      S.Write_Buffer := Data;
      S.Write_Buffer (Length - 2) := Natural (Interfaces.Shift_Right (CRC, 8));
      S.Write_Buffer (Length - 1) := Natural (CRC and 16#FF#);
      S.Write_Length := Length;
   end Write_Data;

   --  A handshake: a broadcast names the bus master, takes the fast rate when
   --  the master supports it, and runs the link; one to this unit gets the
   --  reply with the ids swapped, the priority, and the rate offered.
   procedure Process_Handshake (S : in out State; P : Packet_Bytes) is
      Source      : constant Byte := P (3);
      Destination : constant Byte := P (4);
   begin
      if Destination = Broadcast_Id then
         S.Bus_Master := Source;
         if P (6) = 1 then
            S.Baud := High_Rate;
         end if;
         S.Link := Running;
         return;
      end if;
      if Destination /= Own_Id (S) then
         return;
      end if;
      declare
         Response : Packet_Bytes := (others => 0);
      begin
         Response (0 .. 2) := P (0 .. 2);
         Response (3) := Destination;
         Response (4) := Source;
         Response (5) := 10;
         Response (6) := S.Baud_Fast;
         Write_Data (S, Response, Handshake_Length);
      end;
   end Process_Handshake;

   --  Channel data: the RSSI percent onto the receiver's range when it is
   --  not negative, a dropped frame when the mask is empty, and each channel
   --  under the mask from the next word.
   procedure Process_Channel_Data (
      S  : in out State;
      Rx : in out Receiver.State;
      P  : Packet_Bytes
   ) is
      RSSI : constant Integer := To_Signed_8 (P (5));
      Mask : constant Unsigned_32 :=
        Unsigned_32 (P (8)) + Unsigned_32 (P (9)) * 2 ** 8
        + Unsigned_32 (P (10)) * 2 ** 16 + Unsigned_32 (P (11)) * 2 ** 24;
      Word : Natural range 12 .. 12 + 2 * Channel_Count := 12;
   begin
      S.Result := (Complete => True, others => False);
      if RSSI >= 0 then
         Receiver.Set_RSSI (Rx, Receiver.RSSI_Max * RSSI / 100, Receiver.Rx_Protocol);
      end if;
      if Mask = 0 then
         S.Result.Dropped := True;
         return;
      end if;
      for Ch in Channel loop
         pragma Loop_Invariant (Word <= 12 + 2 * Ch);
         if (Interfaces.Shift_Right (Mask, Ch) and 1) = 1 then
            S.Data (Ch) := P (Word) + P (Word + 1) * 256;
            Word := Word + 2;
         end if;
      end loop;
   end Process_Channel_Data;

   --  Control data: a reply asked of this unit requests telemetry; the
   --  command is channel data, the failsafe with the RSSI set to zero, or
   --  the VTX data packed into the Spektrum control word.
   procedure Process_Control_Data (
      S   : in out State;
      Rx  : in out Receiver.State;
      P   : Packet_Bytes;
      VTX : out VTX_Request
   ) is
      Command : constant Byte := P (3);
   begin
      VTX := (others => <>);
      if P (4) = Own_Id (S) then
         S.Telemetry_Requested := True;
      end if;
      case Command is
         when Channel_Data_Command =>
            Process_Channel_Data (S, Rx, P);
         when Failsafe_Command =>
            S.Result.Failsafe := True;
            Receiver.Set_RSSI_Direct (Rx, 0, Receiver.Rx_Protocol);
         when VTX_Command =>
            VTX := (Present => True,
                    Word    => Interfaces.Shift_Left (16#E0#, 24) or Interfaces.Shift_Left (16#E0#, 8)
                               or Interfaces.Shift_Left (Unsigned_32 (P (5) mod 8), 21)
                               or Interfaces.Shift_Left (Unsigned_32 (P (6) mod 16), 16)
                               or Interfaces.Shift_Left (Unsigned_32 (P (7) mod 2), 4)
                               or Interfaces.Shift_Left (Unsigned_32 (P (11) mod 2), 3)
                               or Unsigned_32 (P (8) mod 8));
         when others =>
            null;
      end case;
   end Process_Control_Data;

   --  The handed-over packet: dropped unless its id, its length byte, and its
   --  CRC check, then valid at this time and processed by its type, dropped
   --  when the type is unknown.
   procedure Process (S : in out State; Rx : in out Receiver.State; Now_Us : Time_Us; VTX : out VTX_Request) is
      P : constant Packet := S.Buffers (Process_Buffer (S));
   begin
      VTX := (others => <>);
      if P.Raw (0) /= Packet_Id or else P.Len /= P.Raw (2) then
         S.Result := (Dropped => True, others => False);
         return;
      end if;
      if Packet_CRC (P.Raw, P.Len) /= 0 then
         S.Result := (Dropped => True, others => False);
         return;
      end if;
      S.Last_Valid_Us := Now_Us;
      case P.Raw (1) is
         when Handshake_Type =>
            Process_Handshake (S, P.Raw);
         when Control_Data_Type =>
            Process_Control_Data (S, Rx, P.Raw, VTX);
         when others =>
            S.Result := (Dropped => True, others => False);
      end case;
   end Process;

   --  The link falls back to listening for activity at the default rate
   --  with a new timeout and a failsafe result.
   procedure Fall_Back (S : in out State; R : in out Receiver.Frame_Report; Now_Us : Time_Us) is
   begin
      S.Baud := Default_Rate;
      S.Timeout_Us := Now_Us + Listen_For_Activity_Timeout_Us;
      R.Failsafe := True;
      S.Link := Listen_For_Activity;
      S.Last_Receive_Us := 0;
   end Fall_Back;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report;
      VTX    : out VTX_Request
   ) is
      R : Receiver.Frame_Report;
   begin
      S.Result := (others => False);
      VTX := (others => <>);
      if S.Buffers (Process_Buffer (S)).Len > 0 then
         Process (S, Rx, Now_Us, VTX);
         S.Buffers (Process_Buffer (S)).Len := 0;
      end if;
      R := S.Result;
      case S.Link is
         when Disabled =>
            null;
         when Listen_For_Activity =>
            if S.Last_Valid_Us /= 0 then
               S.Link := Running;
            elsif Clock.Elapsed (S.Last_Idle_Us, S.Last_Receive_Us) > 0 then
               if S.Baud_Fast /= 0 then
                  S.Baud := (if S.Baud = Default_Rate then High_Rate else Default_Rate);
               end if;
            elsif Clock.Elapsed (Now_Us, S.Timeout_Us) >= 0 then
               if S.Unit_Id = 0 then
                  S.Link := Send_Handshake;
                  S.Timeout_Us := Now_Us + Send_Handshake_Timeout_Us;
                  S.Full_Timeout_Us := Now_Us + Listen_For_Handshake_Timeout_Us;
               else
                  S.Link := Listen_For_Handshake;
                  S.Timeout_Us := Now_Us + Listen_For_Handshake_Timeout_Us;
               end if;
            end if;
         when Send_Handshake =>
            if Clock.Elapsed (Now_Us, S.Timeout_Us) >= 0 then
               R.Processing_Required := True;
            end if;
            if Clock.Elapsed (Now_Us, S.Full_Timeout_Us) >= 0 then
               Fall_Back (S, R, Now_Us);
            end if;
         when Listen_For_Handshake =>
            if Clock.Elapsed (Now_Us, S.Timeout_Us) >= 0 then
               Fall_Back (S, R, Now_Us);
            end if;
         when Running =>
            if Clock.Elapsed (Now_Us, S.Last_Valid_Us) >= Frame_Timeout_Us then
               Fall_Back (S, R, Now_Us);
               S.Last_Valid_Us := 0;
            end if;
      end case;
      if S.Write_Length > 0 then
         R.Processing_Required := True;
      end if;
      if not (R.Failsafe or else R.Dropped) then
         S.Last_Frame_Time_Us := S.Last_Idle_Us;
      end if;
      Status := R;
   end Frame_Status;

   -------------------
   -- Process_Frame --
   -------------------

   procedure Process_Frame (S : in out State; Now_Us : Time_Us; Written : out Boolean) is
   begin
      Written := False;
      if S.Write_Length = 0 then
         return;
      end if;
      if Clock.Elapsed (S.Last_Idle_Us, S.Last_Receive_Us) > 0
        and then Clock.Elapsed (Now_Us, S.Last_Receive_Us) > Reply_Quiescence_Us
      then
         S.Transmitting := True;
         Written := True;
         S.Write_Length := 0;
      end if;
   end Process_Frame;

   ----------
   -- Bind --
   ----------

   procedure Bind (S : in out State) is
      Frame : Packet_Bytes := (others => 0);
   begin
      Frame (0) := Packet_Id;
      Frame (1) := Bind_Info_Type;
      Frame (2) := Bind_Info_Length;
      Frame (3) := Enter_Bind_Mode;
      Frame (4) := S.Bus_Master;
      Frame (5) := Bind_DSMX_11ms;
      Frame (6) := Bind_Options;
      Write_Data (S, Frame, Bind_Info_Length);
   end Bind;

   ---------------------------
   -- Begin_Telemetry_Frame --
   ---------------------------

   procedure Begin_Telemetry_Frame (S : in out State) is
   begin
      S.Telemetry_Frame (0) := Packet_Id;
      S.Telemetry_Frame (1) := Telemetry_Sensor_Type;
      S.Telemetry_Frame (2) := Telemetry_Frame_Length;
      S.Telemetry_Frame (3) := S.Bus_Master;
      S.Telemetry_Fill := 4;
   end Begin_Telemetry_Frame;

   ------------------------
   -- Add_Telemetry_Byte --
   ------------------------

   procedure Add_Telemetry_Byte (S : in out State; B : Byte) is
   begin
      S.Telemetry_Frame (S.Telemetry_Fill) := B;
      S.Telemetry_Fill := S.Telemetry_Fill + 1;
   end Add_Telemetry_Byte;

   ----------------------------
   -- Finish_Telemetry_Frame --
   ----------------------------

   procedure Finish_Telemetry_Frame (S : in out State) is
      Data : Packet_Bytes := (others => 0);
   begin
      for I in Telemetry_Index loop
         Data (I) := S.Telemetry_Frame (I);
      end loop;
      Write_Data (S, Data, S.Telemetry_Fill + 2);
      S.Telemetry_Requested := False;
   end Finish_Telemetry_Frame;

end Adaflight.SRXL2;
