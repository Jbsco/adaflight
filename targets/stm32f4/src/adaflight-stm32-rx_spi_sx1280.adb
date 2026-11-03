with Interfaces;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.ExpressLRS;
with Adaflight.ExpressLRS_Receiver;
with Adaflight.MSP_Telemetry;
with Adaflight.Stream_Buffers;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.SPI_Radio;
with Adaflight.SX1280;
with Adaflight.STM32.ELRS_Timer;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Radio;
with Adaflight.STM32.RX_SPI_Device;
with Adaflight.STM32.Time;
with System;
package body Adaflight.STM32.RX_SPI_SX1280 is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.ExpressLRS.Frequency_Domain;
   package ER renames Adaflight.ExpressLRS_Receiver;
   package SR renames Adaflight.SPI_Radio;
   package Tlm renames Adaflight.ExpressLRS_Telemetry;
   package CT renames Adaflight.CRSF_Telemetry;
   use type ER.Packet_Status;
   use type ER.Tick_Tock;
   use type Adaflight.ExpressLRS_Telemetry.Next_Payload;
   use type SR.Pin;

   type Chip is limited null record;

   Reset_Pin : Pin := (Port_A, 0);
   Busy_Pin  : Pin := (Port_A, 0);
   Has_Reset : Boolean := False;
   Has_Busy  : Boolean := False;

   procedure Read_Busy (D : in out Chip; Busy : out Boolean) is
      pragma Unreferenced (D);
   begin
      Busy := Has_Busy and then GPIO.Is_High (Busy_Pin);
   end Read_Busy;

   procedure Micros (D : in out Chip; Now : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Micros;
   end Micros;

   procedure Exti_Configured (D : in out Chip; Configured : out Boolean) is
      pragma Unreferenced (D);
   begin
      Configured := RX_SPI_Device.Exti_Configured;
   end Exti_Configured;

   procedure Set_Normal_Speed (D : in out Chip; Hz : Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Set_Normal_Speed (Hz);
   end Set_Normal_Speed;

   procedure Init_Reset_Pin (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      GPIO.Enable_Port (Reset_Pin.Port);
      GPIO.Set_Output (Reset_Pin);
   end Init_Reset_Pin;

   procedure Init_Busy_Pin (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      GPIO.Enable_Port (Busy_Pin.Port);
      GPIO.Set_Input (Busy_Pin);
   end Init_Busy_Pin;

   procedure Reset_Low (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      GPIO.Set_Output (Reset_Pin);
      GPIO.Set_Low (Reset_Pin);
   end Reset_Low;

   procedure Reset_Float (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      GPIO.Set_Input (Reset_Pin);
   end Reset_Float;

   procedure Delay_Ms (D : in out Chip; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Ms (Ms);
   end Delay_Ms;

   procedure Busy_Edge;

   procedure Busy_Exti_Config (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      EXTI_Dispatch.Register (Busy_Pin.Number, Busy_Edge'Access);
      EXTI.Configure_Falling (Busy_Pin);
   end Busy_Exti_Config;

   procedure Busy_Exti_Arm (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      EXTI.Unmask (Busy_Pin);
   end Busy_Exti_Arm;

   procedure Busy_Exti_Disable (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      EXTI.Mask (Busy_Pin);
   end Busy_Exti_Disable;

   procedure Enable_Receiver_Exti (D : in out Chip) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Exti_Init (Pull_Down => True);
   end Enable_Receiver_Exti;

   procedure Last_Exti_Time (D : in out Chip; Time : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Time := RX_SPI_Device.Last_Exti_Time;
   end Last_Exti_Time;

   procedure Bus_Write_Command (D : in out Chip; Command : Byte; Value : Byte) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Write_Command (Command, Value);
   end Bus_Write_Command;

   procedure Bus_Transfer (D : in out Chip; Data : in out Byte_Array) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Exchange (Data);
   end Bus_Transfer;

   procedure Bus_Write (D : in out Chip; Data : Byte_Array) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Send (Data);
   end Bus_Write;

   procedure Run_Transfer (D : in out Chip; Step : Byte; Data : in out Byte_Array) is
      pragma Unreferenced (D, Step);
   begin
      RX_SPI_Device.Exchange (Data);
   end Run_Transfer;

   procedure Run_Write (D : in out Chip; Step : Byte; Data : Byte_Array) is
      pragma Unreferenced (D, Step);
   begin
      RX_SPI_Device.Send (Data);
   end Run_Write;

   procedure Run_Pair (D : in out Chip; Step : Byte; Head : Byte_Array; Tail : in out Byte_Array) is
      pragma Unreferenced (D, Step);
   begin
      RX_SPI_Device.Exchange_Pair (Head, Tail);
   end Run_Pair;

   procedure Run_Pair_Write (D : in out Chip; Step : Byte; Head : Byte_Array; Tail : Byte_Array) is
      pragma Unreferenced (D, Step);
   begin
      RX_SPI_Device.Send_Pair (Head, Tail);
   end Run_Pair_Write;

   --  The receiver, its settings and the last channel payload, shared by the
   --  radio's interrupt chain, the timer and the receiver task as the
   --  reference shares them.
   Receiver : ER.Receiver;
   Settings : ER.Settings;
   Payload  : ER.Packet := (others => 0);
   --  The telemetry's payload schedule and the readings its frames send.
   Schedule : Tlm.Payload_Schedule;
   Readings : CT.Sources;
   MSP_Seen : Interfaces.Unsigned_32 := 0;

   --  The MSP frames from the transmitter the telemetry task has yet to
   --  serve, each after its length as the reference buffers them, whether
   --  one arrived since the task last looked, and the reply frame the next
   --  MSP reply payload sends; shared by the radio's interrupt and the task.
   MSP_Buffer_Size : constant := 96;
   MSP_Frame_Size  : constant := 8;
   MSP_Offset      : constant := 5;

   protected MSP_Box with Priority => System.Interrupt_Priority'First is
      procedure Put (Frame : Tlm.MSP_Buffer);
      procedure Arrived (Any : out Boolean);
      procedure Take (Frames : out Byte_Array; Count : out Natural);
      procedure Set_Reply (Frame : Byte_Array);
      procedure Reply (Frame : out Byte_Array; Length : out Natural);
   private
      Frames      : Byte_Array (0 .. MSP_Buffer_Size - 1) := (others => 0);
      Waiting     : Natural range 0 .. MSP_Buffer_Size := 0;
      New_Frame   : Boolean := False;
      Reply_Frame : Byte_Array (0 .. CT.Frame_Size_Max - 1) := (others => 0);
      Reply_Last  : Natural range 0 .. CT.Frame_Size_Max := 0;
   end MSP_Box;

   protected body MSP_Box is
      procedure Put (Frame : Tlm.MSP_Buffer) is
      begin
         if Waiting + 1 + MSP_Frame_Size <= MSP_Buffer_Size then
            Frames (Waiting) := MSP_Frame_Size;
            Frames (Waiting + 1 .. Waiting + MSP_Frame_Size) := Frame (MSP_Offset .. MSP_Offset + MSP_Frame_Size - 1);
            Waiting := Waiting + 1 + MSP_Frame_Size;
            New_Frame := True;
         end if;
      end Put;

      procedure Arrived (Any : out Boolean) is
      begin
         Any := New_Frame;
         New_Frame := False;
      end Arrived;

      procedure Take (Frames : out Byte_Array; Count : out Natural) is
      begin
         Count := Waiting;
         Frames (Frames'First .. Frames'First + Waiting - 1) := MSP_Box.Frames (0 .. Waiting - 1);
         Waiting := 0;
      end Take;

      --  The reply's frame, and the schedule told a reply waits.
      procedure Set_Reply (Frame : Byte_Array) is
      begin
         Reply_Last := Frame'Length;
         Reply_Frame (0 .. Frame'Length - 1) := Frame;
         Tlm.Process_MSP (Schedule, Tlm.MSP_Frame, Buffered => True);
      end Set_Reply;

      procedure Reply (Frame : out Byte_Array; Length : out Natural) is
      begin
         Length := Reply_Last;
         Frame (Frame'First .. Frame'First + Reply_Last - 1) := Reply_Frame (0 .. Reply_Last - 1);
      end Reply;
   end MSP_Box;

   procedure Apply_Timer;

   procedure Hop_Requested (D : in out Chip; Requested : out Boolean) is
      pragma Unreferenced (D);
   begin
      ER.Hop_Required (Receiver, Requested);
   end Hop_Requested;

   procedure Current_Frequency (D : in out Chip; Frequency : out Interfaces.Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Frequency := Receiver.Current_Freq;
   end Current_Frequency;

   procedure Telemetry_Requested (D : in out Chip; Requested : out Boolean) is
      pragma Unreferenced (D);
   begin
      Requested := ER.Telemetry_Response_Required (Receiver);
   end Telemetry_Requested;

   --  The next payload when the link offers one: connected, with telemetry
   --  at its rate, and the sender idle.
   procedure Do_Telemetry (D : in out Chip) is
      pragma Unreferenced (D);
      use type Adaflight.ExpressLRS.Telemetry_Ratio;
      use type ER.Connection_State;
      Frame  : Byte_Array (0 .. CT.Frame_Size_Max - 1) := (others => 0);
      S      : Adaflight.Stream_Buffers.Stream;
      Kind   : Tlm.Next_Payload := Tlm.None;
      Length : Natural := 0;
   begin
      Adaflight.Stream_Buffers.Init (S, 0, CT.Frame_Size_Max);
      if Receiver.Connection = ER.Connected
        and then Adaflight.ExpressLRS.Rates_2400 (Receiver.Rate).Ratio /= Adaflight.ExpressLRS.No_Telemetry
        and then not Tlm.Is_Active (Receiver.Sender)
      then
         Tlm.Next (Schedule, Kind);
         case Kind is
            when Tlm.Device_Info =>
               CT.Write_Device_Info (Frame, S, Readings.Name (1 .. Readings.Name_Last));
            when Tlm.GPS_Frame =>
               CT.Write_GPS (Frame, S, Readings.GPS);
            when Tlm.Battery_Frame =>
               CT.Write_Battery (Frame, S, Readings.Battery);
            when Tlm.Attitude_Frame =>
               CT.Write_Attitude (Frame, S, Readings.Attitude);
            when Tlm.Flight_Mode_Frame =>
               CT.Write_Flight_Mode (Frame, S, Readings.Flight, Readings.GPS.Satellites, Readings.GPS.Fix);
            when Tlm.MSP_Reply =>
               MSP_Box.Reply (Frame, Length);
            when Tlm.None =>
               null;
         end case;
      end if;
      if Kind /= Tlm.MSP_Reply then
         Length := S.Next;
      end if;
      ER.Do_Telemetry (Receiver, Frame (0 .. Length - 1), Has_Next => Kind /= Tlm.None);
   end Do_Telemetry;

   procedure Telemetry_Buffer (D : in out Chip; Data : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      Data := Receiver.Telemetry_Packet;
   end Telemetry_Buffer;

   procedure Process_Packet
     (D : in out Chip; Packet : Byte_Array; Timestamp : Interfaces.Unsigned_32; Status : out Byte);

   procedure Set_Packet_Status (D : in out Chip; Status : Byte) is null;

   package SX is new Adaflight.SX1280
     (Radio_Device         => Chip,
      Read_Busy            => Read_Busy,
      Micros               => Micros,
      Exti_Configured      => Exti_Configured,
      Set_Normal_Speed     => Set_Normal_Speed,
      Init_Reset_Pin       => Init_Reset_Pin,
      Init_Busy_Pin        => Init_Busy_Pin,
      Reset_Low            => Reset_Low,
      Reset_Float          => Reset_Float,
      Delay_Ms             => Delay_Ms,
      Busy_Exti_Config     => Busy_Exti_Config,
      Busy_Exti_Arm        => Busy_Exti_Arm,
      Busy_Exti_Disable    => Busy_Exti_Disable,
      Enable_Receiver_Exti => Enable_Receiver_Exti,
      Last_Exti_Time       => Last_Exti_Time,
      Bus_Write_Command    => Bus_Write_Command,
      Bus_Transfer         => Bus_Transfer,
      Bus_Write            => Bus_Write,
      Run_Transfer         => Run_Transfer,
      Run_Write            => Run_Write,
      Run_Pair             => Run_Pair,
      Run_Pair_Write       => Run_Pair_Write,
      Hop_Requested        => Hop_Requested,
      Current_Frequency    => Current_Frequency,
      Telemetry_Requested  => Telemetry_Requested,
      Do_Telemetry         => Do_Telemetry,
      Telemetry_Buffer     => Telemetry_Buffer,
      Process_Packet       => Process_Packet,
      Set_Packet_Status    => Set_Packet_Status);

   Dev         : Chip;
   Radio_State : SX.Radio;

   procedure Process_Packet
     (D : in out Chip; Packet : Byte_Array; Timestamp : Interfaces.Unsigned_32; Status : out Byte)
   is
      pragma Unreferenced (D);
      P         : ER.Packet := (others => 0);
      RSSI, SNR : Interfaces.Integer_8;
      Result    : ER.Packet_Status;
   begin
      for K in P'Range loop
         exit when Packet'First + K > Packet'Last;
         P (K) := Packet (Packet'First + K);
      end loop;
      SX.Get_Last_Packet_Stats (Radio_State, RSSI, SNR);
      ER.Process_Packet (Receiver, Settings, P, Timestamp, Time.Millis, RSSI, SNR, Payload, Result);
      Apply_Timer;
      if Receiver.MSP_Ready_Count /= MSP_Seen then
         MSP_Seen := Receiver.MSP_Ready_Count;
         case Tlm.Kind_Of (Receiver.MSP_Frame) is
            when Tlm.Ping =>
               Tlm.Process_MSP (Schedule, Tlm.Ping, Buffered => False);
            when Tlm.MSP_Frame =>
               MSP_Box.Put (Receiver.MSP_Frame);
            when Tlm.Other =>
               null;
         end case;
      end if;
      Status := Byte (ER.Packet_Status'Pos (Result));
   end Process_Packet;

   --  The requests the receiver recorded since the last look, each carried
   --  out once in the order the reference makes them.
   type Seen_Requests is record
      Config  : Interfaces.Unsigned_32 := 0;
      Power   : Interfaces.Unsigned_32 := 0;
      Start   : Interfaces.Unsigned_32 := 0;
      Save    : Interfaces.Unsigned_32 := 0;
      Report  : Interfaces.Unsigned_32 := 0;
      Period  : Interfaces.Unsigned_32 := 0;
      Resets  : Interfaces.Unsigned_32 := 0;
      Running : Boolean := False;
   end record;
   Seen        : Seen_Requests;
   Save_Wanted : Boolean := False;

   procedure Apply_Timer is
      T : ER.Timer renames Receiver.Timing;
   begin
      if T.Period_Count /= Seen.Period then
         Seen.Period := T.Period_Count;
         ELRS_Timer.Set_Period (T.Period);
      end if;
      if T.Counter_Resets /= Seen.Resets then
         Seen.Resets := T.Counter_Resets;
         ELRS_Timer.Reset_Counter;
      end if;
      if T.Running /= Seen.Running then
         Seen.Running := T.Running;
         ELRS_Timer.Set_Running (T.Running);
      end if;
   end Apply_Timer;

   procedure Apply is
      G : ER.Radio_Config renames Receiver.Config;
   begin
      if Receiver.Config_Count /= Seen.Config then
         Seen.Config := Receiver.Config_Count;
         SX.Config (Dev, Radio_State, G.Bandwidth, G.Spreading, G.Coding, G.Frequency, G.Preamble, G.IQ_Inverted,
                    G.FLRC_Sync_Word, G.FLRC_CRC_Seed, G.Is_FLRC);
         if Receiver.Power_Count /= Seen.Power then
            Seen.Power := Receiver.Power_Count;
            SX.Set_Output_Power (Dev, 10);
         end if;
         if Receiver.Timing.Max_Period > 0 then
            ELRS_Timer.Set_Time_Base (Receiver.Timing.Max_Period);
         end if;
         Radio.Set_Protocol_RF_Mode (Receiver.RF_Mode_Report);
      end if;
      Apply_Timer;
      if Receiver.Start_Count /= Seen.Start then
         Seen.Start := Receiver.Start_Count;
         SX.Start_Receiving (Dev, Radio_State);
      end if;
      if Receiver.Save_Count /= Seen.Save then
         Seen.Save := Receiver.Save_Count;
         Save_Wanted := True;
      end if;
      if Receiver.Report_Count /= Seen.Report then
         Seen.Report := Receiver.Report_Count;
         Radio.Set_Protocol_Link
           (Receiver.RSSI_Report, Receiver.RSSI_Dbm_Report, Receiver.RSNR_Report,
            Interfaces.Unsigned_16 (Receiver.LQ_Report), Receiver.Uplink_Power_Report,
            Connected => not Receiver.RSSI_Direct);
      end if;
   end Apply;

   --  The interrupt chain runs once at a time: an edge the chain's own
   --  re-arming of the receiver line takes waits for the chain to end.
   In_Radio     : Boolean := False;
   Edge_Pending : Boolean := False;

   procedure Finish_Edges is
   begin
      while Edge_Pending loop
         Edge_Pending := False;
         SX.ISR (Dev, Radio_State);
      end loop;
      In_Radio := False;
   end Finish_Edges;

   procedure Receiver_Edge is
   begin
      if In_Radio then
         Edge_Pending := True;
         return;
      end if;
      In_Radio := True;
      SX.ISR (Dev, Radio_State);
      Finish_Edges;
   end Receiver_Edge;

   procedure Busy_Edge is
   begin
      if In_Radio then
         return;
      end if;
      In_Radio := True;
      SX.Busy_Fell (Dev, Radio_State);
      Finish_Edges;
   end Busy_Edge;

   procedure Timer_Edge is
      Was_Tick : constant Boolean := Receiver.Timing.Phase = ER.Tick;
      Handled  : Boolean;
   begin
      ER.Timer_Update (Receiver, Settings, Time.Micros);
      In_Radio := True;
      if Was_Tick then
         SX.Handle_From_Tick (Dev, Radio_State, Handled);
      else
         SX.Handle_From_Tock (Dev, Radio_State);
      end if;
      Finish_Edges;
      Apply_Timer;
   end Timer_Edge;

   --  The LED and bind pins, and the radio state that blinks the one and
   --  watches the other.
   LED_Pin    : Pin := (Port_A, 0);
   Bind_Pin   : Pin := (Port_A, 0);
   Pins       : SR.Pins;
   Pin_Radio  : SR.Radio;
   Pin_Ops    : SR.Output;
   Channels_N : constant := ER.Channel_Count;

   function Has_Tag (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Bind_Level return Boolean is (if Pins.Bind then GPIO.Is_High (Bind_Pin) else True);

   procedure Run_Pin_Ops is
   begin
      for K in 1 .. Pin_Ops.Count loop
         if Pins.LED and then Pin_Ops.Ops (K).On = SR.LED then
            case Pin_Ops.Ops (K).Kind is
               when SR.Pin_High => GPIO.Set_High (LED_Pin);
               when SR.Pin_Low => GPIO.Set_Low (LED_Pin);
               when SR.Pin_Toggle => GPIO.Toggle (LED_Pin);
               when others => null;
            end case;
         end if;
      end loop;
      Pin_Ops := (others => <>);
   end Run_Pin_Ops;

   procedure ExpressLRS_Init
     (Spi  : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      ELRS : Adaflight.Config_Groups.Rx_Express_Lrs_Spi_Config_Record;
      Ok   : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      Timer_Ok : Boolean;
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
      if not RX_SPI_Device.Exti_Configured then
         return;
      end if;
      Pins := (Chip_Detect => False, Tx_Enable => False, LNA => False, Antenna => False,
               LED => Has_Tag (Spi.Led_Io_Tag), LED_Inversion => Spi.Led_Inversion /= 0,
               Bind => Has_Tag (Spi.Bind_Io_Tag));
      if Pins.LED then
         LED_Pin := Pin_Of (Natural (Spi.Led_Io_Tag));
         GPIO.Enable_Port (LED_Pin.Port);
         GPIO.Set_Output (LED_Pin);
      end if;
      if Pins.Bind then
         Bind_Pin := Pin_Of (Natural (Spi.Bind_Io_Tag));
         GPIO.Enable_Port (Bind_Pin.Port);
         GPIO.Set_Input (Bind_Pin, GPIO.Up);
      end if;
      SR.Start_Common (Pin_Radio, Pins, Bind_Level, Pin_Ops);
      Run_Pin_Ops;
      Channels := Channels_N;
      Has_Reset := Has_Tag (ELRS.Reset_Io_Tag);
      if Has_Reset then
         Reset_Pin := Pin_Of (Natural (ELRS.Reset_Io_Tag));
      end if;
      Has_Busy := Has_Tag (ELRS.Busy_Io_Tag);
      if Has_Busy then
         Busy_Pin := Pin_Of (Natural (ELRS.Busy_Io_Tag));
      end if;
      if Natural (ELRS.Domain) > Adaflight.ExpressLRS.Frequency_Domain'Pos (Adaflight.ExpressLRS.Frequency_Domain'Last)
      then
         return;
      end if;
      Settings.Domain := Adaflight.ExpressLRS.Frequency_Domain'Val (ELRS.Domain);
      if Settings.Domain not in Adaflight.ExpressLRS.ISM2400 | Adaflight.ExpressLRS.CE2400 then
         return;
      end if;
      SX.Init (Dev, Has_Reset, Has_Busy, Ok);
      if not Ok then
         return;
      end if;
      ELRS_Timer.Init (Adaflight.Board.ELRS_Timer, Timer_Edge'Access, Timer_Ok);
      if not Timer_Ok then
         Ok := False;
         return;
      end if;
      Claim_RSSI := True;
      Settings.Rate := (if Natural (ELRS.Rate_Index) <= ER.Rate_Index'Last
                          and then ER.Rate_Valid (Settings.Domain, ER.Rate_Index (ELRS.Rate_Index))
                        then ER.Rate_Index (ELRS.Rate_Index) else 0);
      for I in Settings.UID'Range loop
         Settings.UID (I) := ELRS.Uid (I);
      end loop;
      Settings.Model_Id := ELRS.Model_Id;
      ER.Init (Receiver, Settings, Time.Millis);
      Seen := (others => <>);
      MSP_Seen := 0;
      Apply;
      RX_SPI_Device.Set_Edge_Handler (Receiver_Edge'Access);
      ELRS_Timer.Enable_Interrupt;
   end ExpressLRS_Init;

   procedure ExpressLRS_Data_Received (R : out Adaflight.RX_SPI.Received) is
      Now_Ms    : constant Interfaces.Unsigned_32 := Time.Millis;
      Requested : Boolean;
      Status    : ER.Packet_Status;
   begin
      SR.Check_Bind_Requested (Pin_Radio, Pins, Bind_Level, True, Requested);
      ER.Data_Received (Receiver, Settings, Now_Ms, System_Ready => True, Bind_Requested => Requested,
                        Status => Status);
      Apply;
      if Receiver.In_Binding_Mode then
         SR.LED_Blink (Pin_Radio, Pins, Pin_Ops, Now_Ms, 250);
      else
         SR.LED_Blink_Rx_Loss (Pin_Radio, Pins, Pin_Ops, Now_Ms, Status = ER.Data);
      end if;
      Run_Pin_Ops;
      R := (Bind => Status = ER.Bind, Data => Status = ER.Data, Processing_Required => False);
   end ExpressLRS_Data_Received;

   procedure ExpressLRS_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is
      RC : ER.Channels;
   begin
      for I in RC'Range loop
         RC (I) := Data (I);
      end loop;
      ER.Set_RC_Data (Receiver, Payload, RC);
      for I in RC'Range loop
         Data (I) := RC (I);
      end loop;
   end ExpressLRS_Set_Channels;

   procedure ExpressLRS_Request_Bind is
   begin
      Pin_Radio.Bind_Requested := True;
   end ExpressLRS_Request_Bind;

   procedure ExpressLRS_Stop is
   begin
      ER.Stop (Receiver, Settings);
      Apply;
   end ExpressLRS_Stop;

   --  The MSP over the link: the tunnel, the processor's answer, and whether
   --  a reply has chunks left to send.
   Tunnel      : Adaflight.MSP_Telemetry.Tunnel;
   MSP_Answer  : Byte_Array (0 .. Adaflight.MSP_Telemetry.Response_Buffer_Size - 1) := (others => 0);
   Chunks_Left : Boolean := False;
   MSP_Ack     : constant := 1;

   procedure Serve_MSP is
      use type Adaflight.MSP_Telemetry.Outcome;
      Any    : Boolean;
      Frames : Byte_Array (0 .. MSP_Buffer_Size - 1) := (others => 0);
      Count  : Natural;

      --  The reply's next chunk as the reply frame.
      procedure Send_Chunk is
         Chunk  : Adaflight.MSP_Telemetry.Chunk_Buffer;
         Length : Natural;
         Frame  : Byte_Array (0 .. CT.Frame_Size_Max - 1) := (others => 0);
         S      : Adaflight.Stream_Buffers.Stream;
      begin
         Adaflight.MSP_Telemetry.Send_Reply (Tunnel, CT.MSP_Payload_Max, Chunk, Length, Chunks_Left);
         Adaflight.Stream_Buffers.Init (S, 0, CT.Frame_Size_Max);
         CT.Write_MSP_Response (Frame, S, CT.Address_Radio_Transmitter, Chunk (0 .. Length - 1));
         MSP_Box.Set_Reply (Frame (0 .. S.Next - 1));
      end Send_Chunk;
   begin
      MSP_Box.Arrived (Any);
      if not Any then
         return;
      end if;
      if Chunks_Left then
         Send_Chunk;
         return;
      end if;
      MSP_Box.Take (Frames, Count);
      declare
         Pos          : Natural := 0;
         Length       : Natural;
         Outcome      : Adaflight.MSP_Telemetry.Outcome;
         Unused_Write : Boolean;
         Reply_Count  : Natural;
         Failed       : Boolean;
         Replied      : Boolean := False;
      begin
         while Pos < Count loop
            Length := Natural (Frames (Pos));
            Adaflight.MSP_Telemetry.Handle_Frame (Tunnel, Frames (Pos + 1 .. Pos + Length), Outcome, Unused_Write);
            if Outcome = Adaflight.MSP_Telemetry.Request_Ready then
               Answer (Tunnel.Request_Command, Adaflight.MSP_Telemetry.Request_Data (Tunnel), MSP_Answer, Reply_Count,
                       Failed);
               Adaflight.MSP_Telemetry.Prepare_Reply
                 (Tunnel, (if Failed then Adaflight.MSP_Telemetry.Result_Error else MSP_Ack),
                  MSP_Answer (0 .. Reply_Count - 1));
            end if;
            if Outcome /= Adaflight.MSP_Telemetry.Ignored then
               Send_Chunk;
               Replied := True;
            end if;
            Pos := Pos + 1 + Length;
         end loop;
         if not Replied then
            Tlm.Process_MSP (Schedule, Tlm.MSP_Frame, Buffered => True);
         end if;
      end;
   end Serve_MSP;

   procedure Start_Telemetry (Inp : Tlm.Start_Inputs) is
   begin
      Tlm.Start (Schedule, Receiver.MSP, Inp);
   end Start_Telemetry;

   procedure Set_Telemetry_Sources (Src : CT.Sources) is
   begin
      Readings := Src;
   end Set_Telemetry_Sources;

   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean) is
      E : Adaflight.Config_Groups.Rx_Express_Lrs_Spi_Config_Record renames C.Rx_Express_Lrs_Spi_Config;
   begin
      Requested := Save_Wanted;
      Save_Wanted := False;
      if not Requested then
         return;
      end if;
      for I in Settings.UID'Range loop
         E.Uid (I) := Settings.UID (I);
      end loop;
      E.Rate_Index := Interfaces.Unsigned_8 (Settings.Rate);
      E.Model_Id := Settings.Model_Id;
   end Take_Save;
end Adaflight.STM32.RX_SPI_SX1280;
