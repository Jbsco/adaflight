with Adaflight.Clock;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.CRSF;
with Adaflight.CRSF_Display_Port;
with Adaflight.FPort;
with Adaflight.GHST;
with Adaflight.IBUS;
with Adaflight.Jeti_Ex_Bus;
with Adaflight.MSP_Telemetry;
with Adaflight.SBUS;
with Adaflight.Spektrum;
with Adaflight.SUMD;
with Adaflight.XBUS;
with Adaflight.Stream_Buffers;
with Adaflight.Modes;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.GPIO;
package body Adaflight.STM32.Radio is
   use type Adaflight.STM32.USART.Number;
   package SFM renames Adaflight.Serial_Feature_Map;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.Modes.Box;

   --  The serial receiver provider settings the board reads, the SBUS rates,
   --  the rate IBUS, SUMD, Spektrum and XBUS mode B share, the XBUS RJ01
   --  rate, and the serial receiver feature's bit.
   Spektrum_2048_Provider : constant Interfaces.Unsigned_8 := 1;
   SBUS_Provider          : constant Interfaces.Unsigned_8 := 2;
   SUMD_Provider          : constant Interfaces.Unsigned_8 := 3;
   XBUS_B_Provider        : constant Interfaces.Unsigned_8 := 5;
   XBUS_RJ01_Provider     : constant Interfaces.Unsigned_8 := 6;
   IBUS_Provider          : constant Interfaces.Unsigned_8 := 7;
   Jeti_Provider          : constant Interfaces.Unsigned_8 := 8;
   CRSF_Provider          : constant Interfaces.Unsigned_8 := 9;
   FPort_Provider         : constant Interfaces.Unsigned_8 := 12;
   GHST_Provider          : constant Interfaces.Unsigned_8 := 14;
   Spektrum_1024_Provider : constant Interfaces.Unsigned_8 := 15;
   SBUS_Baud              : constant := 100_000;
   SBUS_Fast_Baud         : constant := 200_000;
   IBUS_SUMD_Baud         : constant := 115_200;
   XBUS_RJ01_Baud         : constant := 250_000;
   GHST_Baud              : constant := 420_000;
   Jeti_Baud              : constant := 125_000;
   Feature_RX_Serial : constant Interfaces.Unsigned_32 := 8;
   --  The serial port identifiers of the board's UARTs.
   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   type Provider is (CRSF, SBUS, IBUS, SUMD, Spektrum, XBUS, FPort, GHST, Jeti);
   Open        : Boolean := False;
   Kind        : Provider := CRSF;
   SBUS_State  : Adaflight.SBUS.State;
   IBUS_State  : Adaflight.IBUS.State;
   SUMD_State  : Adaflight.SUMD.State;
   Spek_State  : Adaflight.Spektrum.State;
   XBUS_State  : Adaflight.XBUS.State;
   FPort_State : Adaflight.FPort.State;
   --  The SmartPort telemetry an FPORT receiver answers with.
   FP_Stream   : Adaflight.SmartPort_Telemetry.Stream;
   GHST_State  : Adaflight.GHST.State;
   --  The Ghost telemetry: its schedule, whether it runs, and the frame that
   --  waits for the receiver's quiet window.
   GHST_Tlm     : Adaflight.GHST_Telemetry.Link;
   GHST_Tlm_Set : Adaflight.GHST_Telemetry.Settings;
   GHST_Tlm_On  : Boolean := False;
   GHST_Reply   : Adaflight.GHST_Telemetry.Frame := (others => 0);
   GHST_Length  : Natural range 0 .. Adaflight.GHST_Telemetry.Frame_Size := 0;
   Jeti_State  : Adaflight.Jeti_Ex_Bus.State;
   --  The EX Bus telemetry: its sensors and whether it runs.
   Jeti_Tlm     : Adaflight.Jeti_Telemetry.State;
   Jeti_Tlm_Set : Adaflight.Jeti_Telemetry.Settings;
   Jeti_Tlm_On  : Boolean := False;
   Link        : USART.Number := USART.UART3;
   --  The link's line: inverted, and on its transmit pin alone.
   Inverted    : Boolean := False;
   Line        : USART.Half_Duplex := USART.Full_Duplex;
   Rx          : Adaflight.Receiver.State;
   Rx_Settings : Adaflight.Receiver.Settings;
   Proto       : Adaflight.CRSF.State;
   FS          : Adaflight.Failsafe.State;
   FS_Settings : Adaflight.Failsafe.Settings;
   Input       : Adaflight.Bytes.Byte_Array (0 .. 63);
   Times       : USART.Time_Array (0 .. 63);
   --  The telemetry with its display port screen, which no menu draws on
   --  yet, and the frames of one run.
   Tlm         : Adaflight.CRSF_Telemetry.Telemetry;
   Screen      : Adaflight.CRSF_Display_Port.Screen;
   Out_Bytes   : Adaflight.Bytes.Byte_Array (0 .. 1_023);
   Out_Stream  : Adaflight.Stream_Buffers.Stream;
   Port        : USART.Port;
   --  The MSP requests over the CRSF link: the frames waiting, each behind
   --  its length, the origin the reply goes back to, whether a reply is due,
   --  the tunnel with whether its reply has chunks left, and the processor's
   --  reply.
   MSP_Buffer_Size : constant := 96;
   MSP_Ack         : constant := 1;
   MSP_Frames      : Adaflight.Bytes.Byte_Array (0 .. MSP_Buffer_Size - 1) := (others => 0);
   MSP_Waiting     : Natural range 0 .. MSP_Buffer_Size := 0;
   MSP_Origin      : Adaflight.Bytes.Byte := 0;
   MSP_Pending     : Boolean := False;
   MSP_Link        : Adaflight.MSP_Telemetry.Tunnel;
   MSP_Chunks_Left : Boolean := False;
   --  Whether an MSP reply is due over the Ghost link, the size of the
   --  chunks its frames take, and the response frame's address and type.
   GHST_MSP_Pending      : Boolean := False;
   GHST_MSP_Chunk        : constant := 6;
   GHST_Receiver_Address : constant Adaflight.Bytes.Byte := 16#89#;
   GHST_MSP_Response     : constant Adaflight.Bytes.Byte := 16#28#;
   MSP_Answer      : Adaflight.Bytes.Byte_Array (0 .. Adaflight.MSP_Telemetry.Response_Buffer_Size - 1) :=
     (others => 0);

   --  The port at a new rate, with the receiver's timing told.
   procedure Set_Rate (Rate : Interfaces.Unsigned_32) is
   begin
      USART.Init (Link, Positive (Interfaces.Unsigned_32'Max (1, Rate)), Line => Line, Inverted => Inverted);
      Adaflight.CRSF.Update_Baudrate (Proto, Rate);
   end Set_Rate;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms; Telemetry : Adaflight.CRSF_Telemetry.Config) is
      Conditions : constant Adaflight.Modes.Conditions :=
        Adaflight.Config_Runtime.Conditions_Of (Config.Mode_Activation_Conditions);
      R : Adaflight.Config_Groups.Rx_Config_Record renames Config.Rx_Config;
   begin
      Open := False;
      Kind := (case R.Serialrx_Provider is
                  when SBUS_Provider => SBUS,
                  when IBUS_Provider => IBUS,
                  when SUMD_Provider => SUMD,
                  when Spektrum_2048_Provider | Spektrum_1024_Provider => Spektrum,
                  when XBUS_B_Provider | XBUS_RJ01_Provider => XBUS,
                  when FPort_Provider => FPort,
                  when GHST_Provider => GHST,
                  when Jeti_Provider => Jeti,
                  when others        => CRSF);
      Rx_Settings := Adaflight.Config_Runtime.Receiver_Settings_Of
        (Config.Rx_Config, Config.Rx_Channel_Range_Configs, Config.Rx_Failsafe_Channel_Configs,
         Config.Flight3_D_Config, Config.Failsafe_Config, Runtime_Features,
         Reported_Channels => (case Kind is
                                  when CRSF => Adaflight.CRSF.Channel_Count,
                                  when SBUS => Adaflight.SBUS.Channel_Count,
                                  when IBUS => Adaflight.IBUS.Channel_Count,
                                  when SUMD => Adaflight.Receiver.Channel_Count,
                                  when Spektrum =>
                                    (if R.Serialrx_Provider = Spektrum_1024_Provider then 7
                                     else Adaflight.Spektrum.Channel_Count_Max),
                                  when XBUS => Adaflight.XBUS.Channel_Count,
                                  when FPort => Adaflight.SBUS.Channel_Count,
                                  when GHST => Adaflight.GHST.Channel_Count,
                                  when Jeti => Adaflight.Jeti_Ex_Bus.Channel_Count));
      FS_Settings := Adaflight.Config_Runtime.Failsafe_Settings_Of (Config.Failsafe_Config, Config.Autopilot_Config);
      Adaflight.Failsafe.Init (FS, FS_Settings);
      if (Runtime_Features and Feature_RX_Serial) /= 0
        and then R.Serialrx_Provider in Spektrum_2048_Provider | SBUS_Provider | SUMD_Provider | XBUS_B_Provider
                                      | XBUS_RJ01_Provider | IBUS_Provider | CRSF_Provider | FPort_Provider
                                      | GHST_Provider | Jeti_Provider | Spektrum_1024_Provider
      then
         declare
            Assigned : constant SFM.Assignments := Adaflight.Config_Fix.Serial_Assignments (Config);
         begin
            for N in USART.Number loop
               if (SFM.Function_Mask (Adaflight.Config_Fix.Serial_Options, Assigned, Port_Ids (N))
                   and SFM.Function_RX_Serial) /= 0
               then
                  Link := N;
                  Open := True;
                  exit;
               end if;
            end loop;
         end;
      end if;
      Adaflight.Receiver.Init
        (Rx, Rx_Settings, Now_Ms,
         Protocol_RSSI    =>
           (if not Open then Adaflight.Receiver.None
            elsif Kind = CRSF then Adaflight.Receiver.Protocol_CRSF
            elsif Kind in FPort | GHST then Adaflight.Receiver.Rx_Protocol
            elsif R.Rssi_Src_Frame_Errors /= 0 then Adaflight.Receiver.Frame_Errors
            else Adaflight.Receiver.None),
         Protocol_Quality =>
           (if not Open then Adaflight.Receiver.None
            elsif Kind = CRSF then Adaflight.Receiver.CRSF
            elsif Kind = GHST then Adaflight.Receiver.GHST
            else Adaflight.Receiver.None));
      for C of Conditions loop
         if C.Mode = Adaflight.Modes.Arm and then Adaflight.Modes.Usable (C.Span) then
            Adaflight.Receiver.Init_Arm_Switch (Rx, C.Aux, C.Span);
         end if;
      end loop;
      --  SBUS is inverted unless the setting says the receiver's line is not,
      --  the others only when it says so. A half-duplex line, which CRSF
      --  does not take, is push-pull with a pull-down when inverted and open
      --  drain with a pull-up otherwise.
      Inverted := (if Kind = SBUS then R.Serialrx_Inverted = 0 else R.Serialrx_Inverted /= 0);
      Line :=
        (if Kind = GHST
         then (On => True, Push_Pull => True,
               Resistor => (if Inverted then Adaflight.STM32.GPIO.Down else Adaflight.STM32.GPIO.Up))
         elsif Kind = Jeti or else (Kind /= CRSF and then R.Half_Duplex /= 0)
         then (On => True, Push_Pull => Inverted,
               Resistor => (if Inverted then Adaflight.STM32.GPIO.Down else Adaflight.STM32.GPIO.Up))
         else USART.Full_Duplex);
      if Open then
         case Kind is
            when CRSF =>
               Adaflight.CRSF.Init (Proto, Rx_Settings.Mid_RC);
               USART.Init (Link, Adaflight.CRSF.Baudrate, Line => Line, Inverted => Inverted);
            when IBUS =>
               Adaflight.IBUS.Init (IBUS_State);
               USART.Init (Link, IBUS_SUMD_Baud, Line => Line, Inverted => Inverted);
            when SUMD =>
               Adaflight.SUMD.Init (SUMD_State);
               USART.Init (Link, IBUS_SUMD_Baud, Line => Line, Inverted => Inverted);
            when Spektrum =>
               Adaflight.Spektrum.Init
                 (Spek_State,
                  (Kind         =>
                     (if R.Serialrx_Provider = Spektrum_1024_Provider then Adaflight.Spektrum.Spektrum_1024
                      else Adaflight.Spektrum.Spektrum_2048),
                   Telemetry    => False,
                   RSSI_Channel => Natural (R.Rssi_Channel)));
               USART.Init (Link, IBUS_SUMD_Baud, Line => Line, Inverted => Inverted);
            when XBUS =>
               Adaflight.XBUS.Init
                 (XBUS_State,
                  (if R.Serialrx_Provider = XBUS_RJ01_Provider then Adaflight.XBUS.Mode_B_RJ01
                   else Adaflight.XBUS.Mode_B));
               USART.Init
                 (Link, (if R.Serialrx_Provider = XBUS_RJ01_Provider then XBUS_RJ01_Baud else IBUS_SUMD_Baud),
                  Line => Line, Inverted => Inverted);
            when FPort =>
               Adaflight.FPort.Init (FPort_State, Rx_Settings.Mid_RC, Telemetry => True);
               USART.Init (Link, IBUS_SUMD_Baud, Line => Line, Inverted => Inverted);
            when GHST =>
               Adaflight.GHST.Init (GHST_State);
               USART.Init (Link, GHST_Baud, Line => Line, Inverted => Inverted);
            when Jeti =>
               Adaflight.Jeti_Ex_Bus.Init (Jeti_State);
               USART.Init (Link, Jeti_Baud, Line => Line, Inverted => Inverted);
            when SBUS =>
               Adaflight.SBUS.Init (SBUS_State, Rx_Settings.Mid_RC);
               USART.Init
                 (Link, (if R.Sbus_Baud_Fast /= 0 then SBUS_Fast_Baud else SBUS_Baud), Two_Stop_Bits => True,
                  Line => Line, Even_Parity => True, Inverted => Inverted);
         end case;
         Port.Which := Link;
      end if;
      Adaflight.CRSF_Telemetry.Init (Tlm, Telemetry, Active => Open and then Kind = CRSF);
      Adaflight.CRSF_Display_Port.Init (Screen, Now_Ms);
      MSP_Waiting := 0;
      MSP_Pending := False;
      MSP_Chunks_Left := False;
   end Init;

   --  What a received frame asked of the telemetry: a device information
   --  reply to a ping, a response slot, a speed proposal from the frame past
   --  its destination and origin, a device information frame from the same
   --  point, and the default rate after repeated errors.
   procedure Telemetry_Events (Outputs : Adaflight.CRSF.Byte_Outputs) is
      Length : constant Natural := Natural (Proto.Frame (1));
      --  The frame's bytes from First to Last as the telemetry reads them.
      function Payload (First, Last : Adaflight.CRSF.Frame_Index) return Adaflight.Bytes.Byte_Array is
         P : Adaflight.Bytes.Byte_Array (0 .. Last - First);
      begin
         for K in P'Range loop
            P (K) := Adaflight.Bytes.Byte (Proto.Frame (First + K));
         end loop;
         return P;
      end Payload;
   begin
      if Outputs.Device_Ping then
         Adaflight.CRSF_Telemetry.Schedule_Device_Info (Tlm);
      end if;
      if Outputs.Telemetry_Response then
         Adaflight.CRSF_Telemetry.Schedule_Response (Tlm);
      end if;
      if Outputs.Command and then Length >= 10 then
         Adaflight.CRSF_Telemetry.Process_Command (Tlm, Payload (5, 12));
      end if;
      if Outputs.Device_Info and then Length in 3 .. Adaflight.CRSF.Frame_Size_Max - 1 then
         Adaflight.CRSF_Telemetry.Handle_Device_Info (Tlm, Payload (3, Length));
      end if;
      if Outputs.MSP_Frame and then MSP_Waiting + 1 + (Length - 4) <= MSP_Buffer_Size then
         MSP_Frames (MSP_Waiting) := Adaflight.Bytes.Byte (Length - 4);
         for K in 0 .. Length - 5 loop
            MSP_Frames (MSP_Waiting + 1 + K) := Adaflight.Bytes.Byte (Proto.Frame (5 + K));
         end loop;
         MSP_Waiting := MSP_Waiting + 1 + (Length - 4);
         MSP_Pending := True;
         MSP_Origin := Adaflight.Bytes.Byte (Proto.Frame (4));
      end if;
      if Outputs.Default_Speed then
         Set_Rate (Adaflight.CRSF.Baudrate);
      end if;
   end Telemetry_Events;

   procedure Telemetry_Step (Now_Us : Time_Us; Src : Adaflight.CRSF_Telemetry.Sources) is
      Run      : Boolean;
      New_Baud : Interfaces.Unsigned_32;
      --  Where this run's frames start after the negotiation's, which go out
      --  at once on their own.
      First    : Natural;

      --  The reply's next chunk to the request's origin.
      procedure Send_Chunk is
         Chunk  : Adaflight.MSP_Telemetry.Chunk_Buffer;
         Length : Natural;
      begin
         Adaflight.MSP_Telemetry.Send_Reply
           (MSP_Link, Adaflight.CRSF_Telemetry.MSP_Payload_Max, Chunk, Length, MSP_Chunks_Left);
         Adaflight.CRSF_Telemetry.Write_MSP_Response (Out_Bytes, Out_Stream, MSP_Origin, Chunk (0 .. Length - 1));
      end Send_Chunk;

      --  A reply under way sends its next chunk while this run has sent no
      --  frame. Otherwise the waiting frames go through the tunnel in order,
      --  a completed request through the processor, and each reply's first
      --  chunk goes out while this run has sent no frame, or waits for the
      --  next run.
      procedure Serve_MSP_Frames is
         use type Adaflight.MSP_Telemetry.Outcome;
         Pos          : Natural := 0;
         Length       : Natural;
         Outcome      : Adaflight.MSP_Telemetry.Outcome;
         Unused_Write : Boolean;
         Count        : Natural;
         Failed       : Boolean;
      begin
         if MSP_Chunks_Left then
            if Out_Stream.Next = First then
               Send_Chunk;
            end if;
            MSP_Pending := MSP_Chunks_Left;
            return;
         end if;
         while Pos < MSP_Waiting loop
            Length := Natural (MSP_Frames (Pos));
            Adaflight.MSP_Telemetry.Handle_Frame (MSP_Link, MSP_Frames (Pos + 1 .. Pos + Length), Outcome, Unused_Write);
            if Outcome = Adaflight.MSP_Telemetry.Request_Ready then
               Answer (MSP_Link.Request_Command, Adaflight.MSP_Telemetry.Request_Data (MSP_Link), MSP_Answer, Count,
                       Failed);
               Adaflight.MSP_Telemetry.Prepare_Reply
                 (MSP_Link, (if Failed then Adaflight.MSP_Telemetry.Result_Error else MSP_Ack), MSP_Answer (0 .. Count - 1));
            end if;
            if Outcome /= Adaflight.MSP_Telemetry.Ignored then
               if Out_Stream.Next = First then
                  Send_Chunk;
               else
                  MSP_Chunks_Left := True;
               end if;
            end if;
            Pos := Pos + 1 + Length;
         end loop;
         MSP_Waiting := 0;
         MSP_Pending := MSP_Chunks_Left;
      end Serve_MSP_Frames;
   begin
      if not Open or else Kind /= CRSF then
         return;
      end if;
      Tlm.Event_Driven := Proto.Event_Telemetry;
      Adaflight.Stream_Buffers.Init (Out_Stream, 0, Out_Bytes'Length);
      Adaflight.CRSF_Telemetry.Update_Check (Tlm, Now_Us, Run);
      Adaflight.CRSF_Telemetry.Negotiate (Tlm, Now_Us, Out_Bytes, Out_Stream, New_Baud);
      First := Out_Stream.Next;
      if MSP_Pending and then Tlm.Enabled and then not Adaflight.CRSF_Telemetry.Negotiation_In_Progress (Tlm) then
         Serve_MSP_Frames;
         Tlm.Last_Cycle_Time := Now_Us;
         Tlm.Response_Pending := False;
      else
         Adaflight.CRSF_Telemetry.Update (Tlm, Now_Us, Src, Screen, Display_Ready => False, B => Out_Bytes,
                                          S => Out_Stream);
      end if;
      if Out_Stream.Next > 0 then
         USART.Put (Port, Out_Bytes (0 .. Out_Stream.Next - 1));
      end if;
      if New_Baud /= 0 then
         Set_Rate (New_Baud);
      end if;
   end Telemetry_Step;

   procedure Init_GHST_Telemetry (Settings : Adaflight.GHST_Telemetry.Settings; Feature_On : Boolean) is
   begin
      GHST_Tlm_Set := Settings;
      GHST_Tlm_On := Feature_On and then Open and then Kind = GHST;
      GHST_Length := 0;
      GHST_MSP_Pending := False;
      Adaflight.GHST_Telemetry.Init (GHST_Tlm, GHST_Tlm_Set);
   end Init_GHST_Telemetry;

   procedure GHST_Telemetry_Step (Inp : Adaflight.GHST_Telemetry.Inputs) is
      O : Adaflight.GHST_Telemetry.Output;

      --  The MSP reply's next chunk in a response frame to the receiver,
      --  zero-filled to the frame's payload, behind its type and CRC.
      procedure Queue_MSP_Chunk is
         Chunk  : Adaflight.MSP_Telemetry.Chunk_Buffer;
         Length : Natural;
         Body_Bytes : Adaflight.Bytes.Byte_Array (0 .. Adaflight.GHST_Telemetry.Frame_Size - 4) := (others => 0);
      begin
         Adaflight.MSP_Telemetry.Send_Reply (MSP_Link, GHST_MSP_Chunk, Chunk, Length, GHST_MSP_Pending);
         Body_Bytes (0) := GHST_MSP_Response;
         Body_Bytes (1 .. Length) := Chunk (0 .. Length - 1);
         GHST_Reply (0) := GHST_Receiver_Address;
         GHST_Reply (1) := Adaflight.Bytes.Byte (Body_Bytes'Length + 1);
         GHST_Reply (2 .. Body_Bytes'Length + 1) := Body_Bytes;
         GHST_Reply (Body_Bytes'Length + 2) :=
           Adaflight.Bytes.CRC8_Update (0, Body_Bytes, Adaflight.Bytes.DVB_S2_Polynomial);
         GHST_Length := Adaflight.GHST_Telemetry.Frame_Size;
         Adaflight.GHST.Queue_Telemetry (GHST_State, GHST_Length);
      end Queue_MSP_Chunk;
   begin
      if not GHST_Tlm_On or else not GHST_State.Telemetry_Enabled then
         return;
      end if;
      if GHST_MSP_Pending then
         GHST_Tlm.Last_Cycle_Us := Inp.Now_Us;
         if GHST_State.Telemetry_Length = 0 then
            Queue_MSP_Chunk;
         end if;
         return;
      end if;
      Adaflight.GHST_Telemetry.Update (GHST_Tlm, GHST_Tlm_Set, Inp, O);
      if O.Count > 0 then
         GHST_Reply := O.Tx;
         GHST_Length := O.Count;
         Adaflight.GHST.Queue_Telemetry (GHST_State, O.Count);
      end if;
   end GHST_Telemetry_Step;

   procedure Init_Jeti_Telemetry (Settings : Adaflight.Jeti_Telemetry.Settings; Feature_On : Boolean) is
   begin
      Jeti_Tlm_Set := Settings;
      Jeti_Tlm_On := Feature_On and then Open and then Kind = Jeti;
      Adaflight.Jeti_Telemetry.Init (Jeti_Tlm, Jeti_Tlm_Set);
   end Init_Jeti_Telemetry;

   procedure Jeti_Telemetry_Step (Inp : Adaflight.Jeti_Telemetry.Inputs; Now_Us : Time_Us) is
      O : Adaflight.Jeti_Telemetry.Output;
   begin
      if not Jeti_Tlm_On then
         return;
      end if;
      --  The bus hands its bytes to the protocol as they arrive, so none
      --  wait on the port.
      Adaflight.Jeti_Telemetry.Handle (Jeti_Tlm, Jeti_State, Jeti_Tlm_Set, Inp, Now_Us, Waiting => 0, O => O);
      if O.Length > 0 then
         declare
            Data : Adaflight.Bytes.Byte_Array (0 .. O.Length - 1);
         begin
            for K in Data'Range loop
               Data (K) := Adaflight.Bytes.Byte (O.Data (K + 1));
            end loop;
            USART.Put (Port, Data);
         end;
      end if;
   end Jeti_Telemetry_Step;

   function Linked return Boolean is (Open);

   function Is_CRSF return Boolean is (Open and then Kind = CRSF);

   procedure Init_FPort_Telemetry (Sensors : Adaflight.SmartPort_Telemetry.Build_Inputs) is
   begin
      FP_Stream := (others => <>);
      if Open and then Kind = FPort then
         Adaflight.SmartPort_Telemetry.Build (FP_Stream, Sensors);
      end if;
   end Init_FPort_Telemetry;

   function Is_FPort return Boolean is (Open and then Kind = FPort);

   function Holds (N : USART.Number) return Boolean is (Open and then N = Link);

   procedure Frame_Check (Now_Us : Time_Us; Delta_Us : Interfaces.Integer_32; Task_In_Progress : Boolean) is
      Count    : Natural;
      Outputs  : Adaflight.CRSF.Byte_Outputs;
      Status   : Adaflight.Receiver.Frame_Report;
      Override : Adaflight.Receiver.Override_Report;
   begin
      if Open then
         USART.Take (Link, Input, Times, Count);
         case Kind is
            when CRSF =>
               for I in 0 .. Count - 1 loop
                  Adaflight.CRSF.Receive_Byte
                    (Proto, Rx, Natural (Input (I)), Times (I),
                     Negotiating => Adaflight.CRSF_Telemetry.Negotiation_In_Progress (Tlm), Eeprom_Writing => False,
                     Result => Outputs);
                  Telemetry_Events (Outputs);
               end loop;
               if not Task_In_Progress then
                  Adaflight.CRSF.Frame_Status (Proto, Rx, Now_Us, Status);
               end if;
            when SBUS =>
               for I in 0 .. Count - 1 loop
                  Adaflight.SBUS.Receive_Byte (SBUS_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.SBUS.Frame_Status (SBUS_State, Status);
               end if;
            when IBUS =>
               for I in 0 .. Count - 1 loop
                  Adaflight.IBUS.Receive_Byte (IBUS_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  declare
                     Telemetry_Request : Boolean;
                  begin
                     Adaflight.IBUS.Frame_Status (IBUS_State, Status, Telemetry_Request);
                  end;
               end if;
            when SUMD =>
               for I in 0 .. Count - 1 loop
                  Adaflight.SUMD.Receive_Byte (SUMD_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.SUMD.Frame_Status (SUMD_State, Status);
               end if;
            when Spektrum =>
               for I in 0 .. Count - 1 loop
                  Adaflight.Spektrum.Receive_Byte (Spek_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  declare
                     VTX : Adaflight.Spektrum.VTX_Request;
                  begin
                     Adaflight.Spektrum.Frame_Status (Spek_State, Now_Us, Status, VTX);
                  end;
               end if;
            when XBUS =>
               for I in 0 .. Count - 1 loop
                  Adaflight.XBUS.Receive_Byte (XBUS_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.XBUS.Frame_Status (XBUS_State, Status);
               end if;
            when FPort =>
               for I in 0 .. Count - 1 loop
                  Adaflight.FPort.Receive_Byte (FPort_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.FPort.Frame_Status (FPort_State, Rx, Now_Us, Status);
               end if;
            when GHST =>
               for I in 0 .. Count - 1 loop
                  Adaflight.GHST.Receive_Byte (GHST_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.GHST.Frame_Status (GHST_State, Now_Us, Status);
               end if;
            when Jeti =>
               for I in 0 .. Count - 1 loop
                  Adaflight.Jeti_Ex_Bus.Receive_Byte (Jeti_State, Natural (Input (I)), Times (I));
               end loop;
               if not Task_In_Progress then
                  Adaflight.Jeti_Ex_Bus.Frame_Status (Jeti_State, Status);
               end if;
         end case;
      end if;
      Adaflight.Receiver.Frame_Check (Rx, Rx_Settings, Now_Us, Delta_Us, Task_In_Progress, Status, Override);
   end Frame_Check;

   function Update_Check (Task_In_Progress : Boolean) return Boolean is
     (Adaflight.Receiver.Update_Check (Rx, Task_In_Progress));

   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; ADC_Sample : Natural; Processed : out Boolean) is
      use type Adaflight.GHST.MSP_Kind;
      Raw             : Adaflight.Receiver.Raw_Values := (others => 0.0);
      Override        : Adaflight.Receiver.Override_Report;
      Frame_Processed : Boolean;
      Valid           : Adaflight.Receiver.Validity;

      --  A Ghost MSP frame's payload, past its address, length and type,
      --  through the tunnel, a completed request through Answer, and a reply
      --  made due for any request the tunnel answers.
      procedure Answer_GHST_MSP (Length : Natural) is
         use type Adaflight.MSP_Telemetry.Outcome;
         F            : Adaflight.GHST.Frame_Bytes renames GHST_State.Buffers (1 - GHST_State.Incoming);
         Payload      : Adaflight.Bytes.Byte_Array (0 .. Length - 1);
         Outcome      : Adaflight.MSP_Telemetry.Outcome;
         Unused_Write : Boolean;
         Count        : Natural;
         Failed       : Boolean;
      begin
         for K in Payload'Range loop
            Payload (K) := Adaflight.Bytes.Byte (F (3 + K));
         end loop;
         Adaflight.MSP_Telemetry.Handle_Frame (MSP_Link, Payload, Outcome, Unused_Write);
         if Outcome = Adaflight.MSP_Telemetry.Request_Ready then
            Answer (MSP_Link.Request_Command, Adaflight.MSP_Telemetry.Request_Data (MSP_Link), MSP_Answer, Count,
                    Failed);
            Adaflight.MSP_Telemetry.Prepare_Reply
              (MSP_Link, (if Failed then Adaflight.MSP_Telemetry.Result_Error else MSP_Ack), MSP_Answer (0 .. Count - 1));
         end if;
         if Outcome /= Adaflight.MSP_Telemetry.Ignored then
            GHST_MSP_Pending := True;
         end if;
      end Answer_GHST_MSP;

      --  The FPORT reply window: while it is open the SmartPort telemetry
      --  writes its next value as the reply, and the receiver's processing
      --  sends the empty reply when the window went unused.
      procedure Answer_FPort is
         use type Interfaces.Integer_32;
         Open_Window : constant Boolean :=
           FPort_State.Clear_To_Send
           and then Adaflight.Clock.Elapsed (Now_Us, FPort_State.Last_Telemetry_At_Us)
                    <= Adaflight.FPort.Max_Reply_Delay_Us;
         O       : Adaflight.SmartPort_Telemetry.Output;
         Empty   : Adaflight.SmartPort_Telemetry.Output;
         Handled : Boolean := False;
         Result  : Adaflight.FPort.Process_Outputs;
      begin
         if Open_Window then
            Adaflight.SmartPort_Telemetry.Process (FP_Stream, SmartPort_Values, 1, True, O, FPort => True);
            if O.Count > 0 then
               Adaflight.FPort.Begin_Reply (FPort_State);
               USART.Put (Port, O.Tx (0 .. O.Count - 1));
               Handled := True;
            end if;
         end if;
         Adaflight.FPort.Process_Frame (FPort_State, Now_Us, Handled, Result);
         if Result.Sent_Empty_Reply then
            Adaflight.SmartPort_Telemetry.Write_Frame (Empty, 0, 0, 0, FPort => True);
            USART.Put (Port, Empty.Tx (0 .. Empty.Count - 1));
         end if;
      end Answer_FPort;
   begin
      --  The processing a frame status asked for runs before the channels
      --  are read: Ghost decodes its channels and link statistics there.
      if Open and then Kind = GHST and then Rx.Aux_Required then
         declare
            Result : Adaflight.GHST.Process_Outputs;
         begin
            Adaflight.GHST.Process_Frame (GHST_State, Rx, Now_Us, Result);
            if Result.Telemetry_Sent and then GHST_Length > 0 then
               USART.Put (Port, GHST_Reply (0 .. GHST_Length - 1));
               GHST_Length := 0;
            end if;
            if Result.MSP /= Adaflight.GHST.None then
               Answer_GHST_MSP (Result.MSP_Length);
            end if;
         end;
      end if;
      if Open and then Kind = FPort and then Rx.Aux_Required then
         Answer_FPort;
      end if;
      if Open then
         case Kind is
            when CRSF =>
               for Ch in Adaflight.CRSF.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.CRSF.Read_Raw (Proto, Ch)));
               end loop;
            when SBUS =>
               for Ch in Adaflight.SBUS.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.SBUS.Read_Raw (SBUS_State, Ch)));
               end loop;
            when IBUS =>
               for Ch in Adaflight.IBUS.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.IBUS.Read_Raw (IBUS_State, Ch)));
               end loop;
            when SUMD =>
               for Ch in Adaflight.SUMD.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.SUMD.Read_Raw (SUMD_State, Ch)));
               end loop;
            when Spektrum =>
               for Ch in Adaflight.Spektrum.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.Spektrum.Read_Raw (Spek_State, Ch)));
               end loop;
            when XBUS =>
               for Ch in Adaflight.XBUS.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.XBUS.Read_Raw (XBUS_State, Ch)));
               end loop;
            when FPort =>
               for Ch in Adaflight.FPort.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.FPort.Read_Raw (FPort_State, Ch)));
               end loop;
            when GHST =>
               for Ch in Adaflight.GHST.Channel loop
                  Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.GHST.Read_Raw (GHST_State, Ch)));
               end loop;
            when Jeti =>
               for Ch in Adaflight.Jeti_Ex_Bus.Channel loop
                  Raw (Ch) :=
                    Float'Max (0.0, Float'Min (65_535.0, Adaflight.Jeti_Ex_Bus.Read_Raw (Jeti_State, Ch)));
               end loop;
         end case;
      end if;
      Adaflight.Receiver.Calculate_Channels
        (Rx, Rx_Settings, Now_Us, Now_Ms, Raw, Override, Box_Failsafe => False, Box_3D => False,
         Failsafe_Active => FS.Active, Processed => Processed, Frame_Processed => Frame_Processed, Valid => Valid);
      case Valid is
         when Adaflight.Receiver.Data_Received =>
            Adaflight.Failsafe.On_Valid_Data_Received (FS, Now_Ms);
         when Adaflight.Receiver.Data_Failed =>
            Adaflight.Failsafe.On_Valid_Data_Failed (FS, Now_Ms);
         when Adaflight.Receiver.No_Report =>
            null;
      end case;
      if not Processed then
         return;
      end if;
      Adaflight.Receiver.Update_RSSI (Rx, Rx_Settings, Now_Us, ADC_Sample);
   end Process;

   procedure Failsafe_Check
     (Now_Ms : Time_Ms; In_Flight : Adaflight.Failsafe.Inputs; Beep : out Adaflight.Failsafe.Beep;
      Disarm : out Boolean)
   is
      Stage_Rescue : Boolean;
   begin
      Adaflight.Failsafe.Check_Data_Failure_Period (FS, Now_Ms);
      Adaflight.Failsafe.Update (FS, FS_Settings, Now_Ms, In_Flight, Beep, Disarm, Stage_Rescue);
   end Failsafe_Check;

   procedure Start_Failsafe_Monitoring is
   begin
      Adaflight.Failsafe.Start_Monitoring (FS);
   end Start_Failsafe_Monitoring;

   function Failsafe_Receiving return Boolean is (Adaflight.Failsafe.Receiving_Rx_Data (FS));

   function Failsafe_Active return Boolean is (FS.Active);

   function Failsafe_Mode return Boolean is (FS.Failsafe_Mode);

   function Failsafe_Rx_Loss return Boolean is (FS.Arming_Disabled_Rx);

   function Failsafe_Blocks_Arming return Boolean is (FS.Arming_Disabled);

   function Failsafe_Monitoring return Boolean is (FS.Monitoring);

   function Last_Frame_Us return Time_Us is
     (case Kind is
         when CRSF => Proto.Last_Frame_Us,
         when SBUS => SBUS_State.Last_Frame_Time_Us,
         when IBUS => IBUS_State.Last_Frame_Time_Us,
         when SUMD => SUMD_State.Last_Frame_Us,
         when Spektrum => Spek_State.Last_Frame_Time_Us,
         when XBUS => 0,
         when FPort => FPort_State.Last_Frame_Time_Us,
         when GHST => GHST_State.Last_Frame_Time_Us,
         when Jeti => Jeti_State.Last_Frame_Time_Us);

   function RSSI_ADC return Boolean is (Rx_Settings.RSSI_ADC);

   function RSSI return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16 (Adaflight.Receiver.RSSI (Rx, Rx_Settings)));

   function RSSI_Percent return Interfaces.Unsigned_8 is
     (Interfaces.Unsigned_8 (Adaflight.Receiver.RSSI_Percent (Rx, Rx_Settings)));

   function RSSI_Dbm return Interfaces.Integer_16 is (Interfaces.Integer_16 (Rx.RSSI_Dbm));

   function RSNR return Interfaces.Integer_16 is (Interfaces.Integer_16 (Rx.RSNR));

   function Link_Quality return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16 (Rx.Link_Quality));

   function Link_Quality_Percent return Interfaces.Unsigned_16 is
     (Interfaces.Unsigned_16 (Adaflight.Receiver.Link_Quality_Percent (Rx)));

   function Link_Source return Adaflight.Receiver.Link_Quality_Source is (Rx.Quality_From);

   function RF_Mode return Natural is (Rx.RF_Mode);

   function Uplink_Power_mW return Interfaces.Unsigned_16 is (Interfaces.Unsigned_16 (Rx.Uplink_Power_mW));

   function Channel_Count return Natural is (Rx.Channels);

   function Channel (I : Adaflight.Receiver.Channel) return Float is (Rx.Data (I));

   function Receiving return Boolean is (Adaflight.Receiver.Receiving_Signal (Rx));

   function Failsafe_Phase return Adaflight.Failsafe.Phase is (FS.Current);

   function Flight_Channels_Valid return Boolean is (Adaflight.Receiver.Flight_Channels_Valid (Rx));

   function RSSI_Configured return Boolean is
     (Adaflight.Receiver."/=" (Rx.RSSI_From, Adaflight.Receiver.None));
end Adaflight.STM32.Radio;
