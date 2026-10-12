with Adaflight.Clock;

package body Adaflight.FPORT with SPARK_Mode is
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;

   Frame_Timeout_Us : constant := Frame_Time_Us + 500;

   --  The FrSky checksum over the frame's bytes: the sum folded into a byte
   --  reads all ones when the frame is intact.
   function Checksum_Good (Data : Buffer_Bytes; Length : Buffer_Length) return Boolean is
      Sum : Natural range 0 .. 255 * Buffer_Size := 0;
   begin
      for I in 0 .. Length - 1 loop
         pragma Loop_Invariant (Sum <= 255 * I);
         Sum := Sum + Data (I);
      end loop;
      while Sum > 16#FF# loop
         pragma Loop_Variant (Decreases => Sum);
         Sum := (Sum mod 256) + Sum / 256;
      end loop;
      return Sum = 16#FF#;
   end Checksum_Good;

   function Carries_MSP (P : Payload) return Boolean is (P.Frame_Id in Frame_Id_Read | Frame_Id_Write);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; Mid_RC : SBUS.Center_Us; Telemetry : Boolean) is
      Center : constant SBUS.Channel_Value := (16 * Mid_RC) / 10 - 1_408;
   begin
      S := (others => <>);
      S.Data := (others => Center);
      S.Telemetry_Enabled := Telemetry;
   end Init;

   ------------------
   -- Receive_Byte --
   ------------------

   procedure Receive_Byte (S : in out State; C : Serial_Word; Now_Us : Time_Us) is
      Val : Byte := C mod 256;
   begin
      S.Clear_To_Send := False;
      if S.Position > 1 and then Clock.Elapsed (Now_Us, S.Frame_Start_At_Us) > Frame_Timeout_Us then
         S.Position := 0;
      end if;
      if Val = Frame_Marker then
         if S.Position > 1 then
            declare
               Next : constant Ring_Index := (S.Write_Index + 1) mod Ring_Size;
            begin
               if Next /= S.Read_Index then
                  S.Buffers (S.Write_Index).Length := S.Position - 1;
                  S.Write_Index := Next;
               end if;
            end;
            if S.Telemetry_Frame then
               S.Clear_To_Send := True;
               S.Last_Telemetry_At_Us := Now_Us;
               S.Telemetry_Frame := False;
            end if;
            S.Escaped := False;
         end if;
         S.Frame_Start_At_Us := Now_Us;
         S.Position := 1;
         S.Buffers (S.Write_Index).Start_At_Us := Now_Us;
      elsif S.Position > 0 then
         if S.Position > Buffer_Size then
            S.Position := 0;
         else
            if S.Escaped then
               Val := (if (Val / 32) mod 2 = 1 then Val - 32 else Val + 32);
               S.Escaped := False;
            elsif Val = Escape_Char then
               S.Escaped := True;
               return;
            end if;
            if S.Position = 2 and then Val = Type_Telemetry_Request then
               S.Telemetry_Frame := True;
            end if;
            S.Buffers (S.Write_Index).Data (S.Position - 1) := Val;
            S.Position := S.Position + 1;
         end if;
      end if;
   end Receive_Byte;

   --  A control frame: the channels and flags through the SBUS block, the
   --  RSSI scaled from a percentage onto the receiver's range, and the
   --  frame's start as the frame time unless the receiver flags it.
   procedure Take_Control (S : in out State; Rx : in out Receiver.State; B : Frame_Buffer; Now_Ms : Time_Ms;
                           Status : out Receiver.Frame_Report) is
      Block : SBUS.Channel_Block;
   begin
      for I in SBUS.Block_Index loop
         Block (I) := B.Data (I + 2);
      end loop;
      SBUS.Decode (Block, S.Data, Status);
      Receiver.Set_RSSI (Rx, (Receiver.RSSI_Max * B.Data (25)) / 100, Receiver.Rx_Protocol);
      S.Last_Control_At_Ms := Now_Ms;
      if not (Status.Failsafe or else Status.Dropped) then
         S.Last_Frame_Time_Us := B.Start_At_Us;
      end if;
   end Take_Control;

   --  A telemetry request: a data frame hands the frame rate to the
   --  receiver and asks for a reply, a null frame asks for one until two
   --  have gone unanswered while the receiver does not drive the rate, and
   --  a read or write frame keeps its payload for the telemetry layer.
   procedure Take_Request (S : in out State; B : Frame_Buffer) is
   begin
      case B.Data (2) is
         when Frame_Id_Data =>
            S.Rx_Driven_Rate := True;
            S.Has_Request := True;
         when Frame_Id_Null =>
            if not S.Rx_Driven_Rate then
               if S.Consecutive >= Max_Consecutive_Telemetry and then not (S.Has_MSP and then Carries_MSP (S.MSP)) then
                  S.Consecutive := 0;
               else
                  S.Has_Request := True;
                  S.Consecutive := (S.Consecutive + 1) mod 256;
               end if;
            end if;
         when Frame_Id_Read | Frame_Id_Write =>
            S.MSP := (Frame_Id => B.Data (2),
                      Value_Id => B.Data (3) + 256 * B.Data (4),
                      Data     => Unsigned_32 (B.Data (5)) + Unsigned_32 (B.Data (6)) * 2 ** 8
                                  + Unsigned_32 (B.Data (7)) * 2 ** 16 + Unsigned_32 (B.Data (8)) * 2 ** 24);
            S.Has_MSP := True;
         when others =>
            null;
      end case;
   end Take_Request;

   ------------------
   -- Frame_Status --
   ------------------

   procedure Frame_Status (
      S      : in out State;
      Rx     : in out Receiver.State;
      Now_Us : Time_Us;
      Status : out Receiver.Frame_Report
   ) is
      Now_Ms : constant Time_Ms := Now_Us / 1_000;
   begin
      Status := (others => False);
      if S.Read_Index /= S.Write_Index then
         declare
            B            : constant Frame_Buffer := S.Buffers (S.Read_Index);
            Frame_Length : constant Byte := B.Data (0);
         begin
            if Integer (B.Length) - 2 = Frame_Length and then Checksum_Good (B.Data, B.Length) then
               case B.Data (1) is
                  when Type_Control =>
                     if Frame_Length = Control_Payload_Length then
                        Take_Control (S, Rx, B, Now_Ms, Status);
                     end if;
                  when Type_Telemetry_Request =>
                     if Frame_Length = Telemetry_Payload_Length and then S.Telemetry_Enabled then
                        Take_Request (S, B);
                     end if;
                  when others =>
                     null;
               end case;
            end if;
         end;
         S.Read_Index := (S.Read_Index + 1) mod Ring_Size;
      end if;
      if (S.Has_MSP or else S.Has_Request)
        and then Clock.Elapsed (Now_Us, S.Last_Telemetry_At_Us) >= Min_Reply_Delay_Us
      then
         S.Has_Request := False;
         Status.Processing_Required := True;
      end if;
      if S.Last_Control_At_Ms /= 0 and then Now_Ms - S.Last_Control_At_Ms > Max_Control_Age_Ms then
         Receiver.Set_RSSI_Direct (Rx, 0, Receiver.Rx_Protocol);
         S.Last_Control_At_Ms := 0;
      end if;
   end Frame_Status;

   -------------------
   -- Process_Frame --
   -------------------

   procedure Process_Frame (
      S                 : in out State;
      Now_Us            : Time_Us;
      Telemetry_Handled : Boolean;
      Result            : out Process_Outputs
   ) is
   begin
      Result := (others => False);
      if Clock.Elapsed (Now_Us, S.Last_Telemetry_At_Us) > Max_Reply_Delay_Us then
         S.Clear_To_Send := False;
      end if;
      if S.Clear_To_Send then
         Result.Consulted := True;
         Result.Consulted_With_Payload := S.Has_MSP;
         if Telemetry_Handled then
            S.Clear_To_Send := False;
         end if;
         if S.Clear_To_Send then
            Begin_Reply (S);
            Result.Sent_Empty_Reply := True;
            S.Clear_To_Send := False;
         end if;
      end if;
      S.Has_MSP := False;
   end Process_Frame;

   -----------------
   -- Begin_Reply --
   -----------------

   procedure Begin_Reply (S : in out State) is
   begin
      S.Position := 0;
   end Begin_Reply;

end Adaflight.FPORT;
