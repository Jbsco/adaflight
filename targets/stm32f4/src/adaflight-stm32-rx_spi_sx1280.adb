with Interfaces;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.ExpressLRS;
with Adaflight.ExpressLRS_Receiver;
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
package body Adaflight.STM32.RX_SPI_SX1280 is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.ExpressLRS.Frequency_Domain;
   package ER renames Adaflight.ExpressLRS_Receiver;
   package SR renames Adaflight.SPI_Radio;
   use type ER.Packet_Status;
   use type ER.Tick_Tock;
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

   procedure Do_Telemetry (D : in out Chip) is
      pragma Unreferenced (D);
      None : constant Byte_Array (1 .. 0) := (others => 0);
   begin
      ER.Do_Telemetry (Receiver, None, Has_Next => False);
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
