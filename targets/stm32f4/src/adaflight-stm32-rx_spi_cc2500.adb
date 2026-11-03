with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.CC2500;
with Adaflight.FrSky_SPI;
with Adaflight.MSP_Telemetry;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.SPI_Radio;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Radio;
with Adaflight.STM32.RX_SPI_Device;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RX_SPI_CC2500 is
   use type Interfaces.Unsigned_8;
   package SR renames Adaflight.SPI_Radio;
   package FS renames Adaflight.FrSky_SPI;
   use type SR.Op_Kind;
   use type FS.Received;
   use type FS.SPI_Protocol;

   type Chip is limited null record;

   procedure Write_Command (D : in out Chip; Command : Byte; Value : Byte) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Write_Command (Command, Value);
   end Write_Command;

   procedure Write_Command_Multi (D : in out Chip; Command : Byte; Data : Byte_Array) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Write_Command_Multi (Command, Data);
   end Write_Command_Multi;

   procedure Read_Command (D : in out Chip; Command : Byte; Value : out Byte) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Read_Command (Command, Value);
   end Read_Command;

   procedure Read_Command_Multi (D : in out Chip; Command : Byte; Data : out Byte_Array) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Read_Command_Multi (Command, Data);
   end Read_Command_Multi;

   procedure Write_Byte (D : in out Chip; Value : Byte) is
      pragma Unreferenced (D);
   begin
      RX_SPI_Device.Write_Byte (Value);
   end Write_Byte;

   procedure DMA_Enable (D : in out Chip; Enable : Boolean) is null;

   procedure Delay_Us (D : in out Chip; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Us (Us);
   end Delay_Us;

   package Radio_Chip is new Adaflight.CC2500
     (Radio_Device            => Chip,
      Bus_Write_Command       => Write_Command,
      Bus_Write_Command_Multi => Write_Command_Multi,
      Bus_Read_Command        => Read_Command,
      Bus_Read_Command_Multi  => Read_Command_Multi,
      Bus_Write_Byte          => Write_Byte,
      Bus_DMA_Enable          => DMA_Enable,
      Delay_Us                => Delay_Us);

   Dev : Chip;

   --  Register reads with the burst bit, which the status registers take.
   Rx_Bytes_Register : constant Byte := 16#3B# or 16#40#;
   Part_Register     : constant Byte := 16#30# or 16#40#;
   Version_Register  : constant Byte := 16#31# or 16#40#;
   Channel_Register  : constant Byte := 16#0A#;
   FSCAL3            : constant Byte := 16#23#;
   FSCAL2            : constant Byte := 16#24#;
   FSCAL1            : constant Byte := 16#25#;
   Calibration_Us    : constant := 900;

   Pin_Of_Slot : array (SR.Pin) of Pin := (others => (Port_A, 0));
   Has_Pin     : array (SR.Pin) of Boolean := (others => False);
   Bind_Pin    : Pin := (Port_A, 0);
   Has_Bind    : Boolean := False;

   Settings    : FS.Settings;
   State       : FS.State;
   Trial_State : FS.State;
   Ops         : SR.Output;
   Cal         : FS.Calibration_Table := (others => (others => 0));
   Save_Wanted : Boolean := False;
   Readings    : Adaflight.STM32.RX_SPI.Telemetry_Readings;
   --  The X telemetry's SmartPort stream, its values, the MSP tunnel over the
   --  link and the processor's reply to its request.
   Smart        : Adaflight.SmartPort_Telemetry.Stream;
   Smart_Values : Adaflight.SmartPort_Telemetry.Inputs;
   Tunnel       : Adaflight.MSP_Telemetry.Tunnel;
   Reply        : Byte_Array (0 .. Adaflight.MSP_Telemetry.Response_Buffer_Size - 1) := (others => 0);
   MSP_Wanted   : Boolean := False;
   MSP_Ack      : constant := 1;

   function Has_Tag (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   procedure Output_Pin (Slot : SR.Pin; Tag : Byte) is
   begin
      Has_Pin (Slot) := Has_Tag (Tag);
      if Has_Pin (Slot) then
         Pin_Of_Slot (Slot) := Pin_Of (Natural (Tag));
         GPIO.Enable_Port (Pin_Of_Slot (Slot).Port);
         GPIO.Set_Output (Pin_Of_Slot (Slot));
      end if;
   end Output_Pin;

   --  The calibration of Count channels from Base, Step apart: each one tuned,
   --  calibrated and its three synthesizer values read.
   procedure Calibrate (Count, Step : Interfaces.Unsigned_8; Base : Interfaces.Unsigned_16) is
      Channel : Byte;
   begin
      for C in 0 .. Natural (Count) - 1 loop
         Channel := Byte ((Natural (Base) + C * Natural (Step)) mod 256);
         Radio_Chip.Strobe (Dev, SR.SIDLE);
         Radio_Chip.Write_Register (Dev, Channel_Register, Channel);
         Radio_Chip.Strobe (Dev, SR.SCAL);
         Time.Delay_Us (Calibration_Us);
         Radio_Chip.Read_Register (Dev, FSCAL3, Cal (C) (0));
         Radio_Chip.Read_Register (Dev, FSCAL2, Cal (C) (1));
         Radio_Chip.Read_Register (Dev, FSCAL1, Cal (C) (2));
      end loop;
      FS.Set_Calibration (State, Cal);
   end Calibrate;

   --  The operations First to Last in order. A FIFO read happened before the
   --  call that asked for it.
   procedure Run (O : SR.Output; First, Last : Natural) is
   begin
      for K in First .. Last loop
         declare
            P : SR.Op renames O.Ops (K);
         begin
            case P.Kind is
               when SR.Reset =>
                  declare
                     Ok : Boolean;
                  begin
                     Radio_Chip.Reset (Dev, Ok);
                  end;
               when SR.Startup_Speed =>
                  RX_SPI_Device.Startup_Speed;
               when SR.Normal_Speed =>
                  RX_SPI_Device.Normal_Speed;
               when SR.Strobe =>
                  Radio_Chip.Strobe (Dev, P.A);
               when SR.Write_Register =>
                  Radio_Chip.Write_Register (Dev, P.A, P.B);
               when SR.Read_Fifo =>
                  null;
               when SR.Write_Fifo =>
                  declare
                     Data : Byte_Array (0 .. Natural (P.A) - 1);
                  begin
                     for I in Data'Range loop
                        Data (I) := O.Tx_Data (I);
                     end loop;
                     Radio_Chip.Write_FIFO (Dev, Data);
                  end;
               when SR.Set_Power =>
                  Radio_Chip.Set_Power (Dev, P.A);
               when SR.Delay_Ms =>
                  Time.Delay_Ms (Natural (P.Value));
               when SR.Delay_Us =>
                  Time.Delay_Us (Natural (P.Value));
               when SR.Calibrate =>
                  Calibrate (P.A, P.B, P.Value);
               when SR.Pin_High | SR.Pin_Low | SR.Pin_Toggle =>
                  if Has_Pin (P.On) then
                     case P.Kind is
                        when SR.Pin_High => GPIO.Set_High (Pin_Of_Slot (P.On));
                        when SR.Pin_Low => GPIO.Set_Low (Pin_Of_Slot (P.On));
                        when others => GPIO.Toggle (Pin_Of_Slot (P.On));
                     end case;
                  end if;
               when SR.Set_RSSI =>
                  Radio.Set_Protocol_RSSI (P.Value, Direct => False);
               when SR.Set_RSSI_Direct =>
                  Radio.Set_Protocol_RSSI (P.Value, Direct => True);
               when SR.Save_Config =>
                  Save_Wanted := True;
               when SR.Write_Block =>
                  declare
                     Data : Byte_Array (0 .. Natural (P.B) - 1);
                  begin
                     for I in Data'Range loop
                        Data (I) := O.Blocks (Natural (P.Value) + I);
                     end loop;
                     Radio_Chip.Write_Register_Multi (Dev, P.A, Data);
                  end;
               when others =>
                  null;
            end case;
         end;
      end loop;
   end Run;

   --  The first operation of a kind, zero without one.
   function First_Of (O : SR.Output; Kind : SR.Op_Kind) return Natural is
   begin
      for K in 1 .. O.Count loop
         if O.Ops (K).Kind = Kind then
            return K;
         end if;
      end loop;
      return 0;
   end First_Of;

   function Protocol_Of (Number : Byte) return FS.SPI_Protocol is
     (case Number is
         when 9      => FS.FrSky_X,
         when 15     => FS.FrSky_X_LBT,
         when 17     => FS.FrSky_X_V2,
         when 18     => FS.FrSky_X_LBT_V2,
         when others => FS.FrSky_D);

   function Settings_Of
     (Spi : Adaflight.Config_Groups.Rx_Spi_Config_Record; R : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record)
      return FS.Settings
   is
      S : FS.Settings;
   begin
      S.Protocol := Protocol_Of (Spi.Rx_Spi_Protocol);
      S.Auto_Bind := R.Auto_Bind /= 0;
      for I in S.Bind_Tx_Id'Range loop
         S.Bind_Tx_Id (I) := R.Bind_Tx_Id (I);
      end loop;
      S.Bind_Offset := R.Bind_Offset;
      for I in S.Bind_Hop_Data'Range loop
         S.Bind_Hop_Data (I) := R.Bind_Hop_Data (I);
      end loop;
      S.Rx_Num := R.Rx_Num;
      S.A1 := (if R.A1_Source <= FS.A1_Source'Pos (FS.A1_Source'Last) then FS.A1_Source'Val (R.A1_Source)
               else FS.Battery_Voltage);
      S.Pins :=
        (Chip_Detect   => R.Chip_Detect_Enabled /= 0,
         Tx_Enable     => Has_Tag (R.Tx_En_Io_Tag),
         LNA           => Has_Tag (R.Lna_En_Io_Tag),
         Antenna       => Has_Tag (R.Ant_Sel_Io_Tag),
         LED           => Has_Tag (Spi.Led_Io_Tag),
         LED_Inversion => Spi.Led_Inversion /= 0,
         Bind          => Has_Tag (Spi.Bind_Io_Tag));
      return S;
   end Settings_Of;

   function Bind_Level return Boolean is (if Has_Bind then GPIO.Is_High (Bind_Pin) else True);

   procedure FrSky_Init
     (Spi       : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500    : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      Telemetry : Boolean;
      Ok        : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      Inp   : FS.Inputs;
      Split : Natural;
   begin
      Ok := False;
      Channels := 0;
      Claim_RSSI := False;
      Settings := Settings_Of (Spi, CC2500);
      Settings.Telemetry := Telemetry;
      Output_Pin (SR.LED, Spi.Led_Io_Tag);
      Has_Bind := Has_Tag (Spi.Bind_Io_Tag);
      if Has_Bind then
         Bind_Pin := Pin_Of (Natural (Spi.Bind_Io_Tag));
         GPIO.Enable_Port (Bind_Pin.Port);
         GPIO.Set_Input (Bind_Pin, GPIO.Up);
      end if;
      if not RX_SPI_Device.Exti_Configured then
         return;
      end if;
      Output_Pin (SR.LNA_Enable, CC2500.Lna_En_Io_Tag);
      Output_Pin (SR.Tx_Enable, CC2500.Tx_En_Io_Tag);
      Output_Pin (SR.Antenna_Select, CC2500.Ant_Sel_Io_Tag);
      Inp.Now_Us := Time.Micros;
      Inp.Now_Ms := Time.Millis;
      Inp.Bind_Pin_Level := Bind_Level;
      FS.Start (Trial_State, Settings, Inp, Ops, Ok, Claim_RSSI);
      Split := First_Of (Ops, SR.Reset);
      if Split = 0 then
         State := Trial_State;
         Run (Ops, 1, Ops.Count);
      else
         Run (Ops, 1, Split - 1);
         declare
            Reset_Ok      : Boolean;
            Part, Version : Byte;
         begin
            Radio_Chip.Reset (Dev, Reset_Ok);
            Radio_Chip.Read_Register (Dev, Part_Register, Part);
            Radio_Chip.Read_Register (Dev, Version_Register, Version);
            Inp.Chip_Ok := Part = 16#80# and then Version = 16#03#;
         end;
         FS.Start (State, Settings, Inp, Ops, Ok, Claim_RSSI);
         Run (Ops, Split + 1, Ops.Count);
      end if;
      Channels := FS.Channel_Count (Settings);
   end FrSky_Init;

   procedure FrSky_Data_Received (R : out Adaflight.RX_SPI.Received) is
      Inp            : FS.Inputs;
      Trial_Settings : FS.Settings := Settings;
      Result         : FS.Received;
      Split          : Natural;
   begin
      Inp.Now_Us := Time.Micros;
      Inp.Now_Ms := Time.Millis;
      Inp.Exti := RX_SPI_Device.Exti_State;
      if Inp.Exti then
         Radio_Chip.Read_Register (Dev, Rx_Bytes_Register, Inp.Rx_Bytes);
      end if;
      Inp.Bind_Pin_Level := Bind_Level;
      Inp.ADC_External := Readings.ADC_External;
      Inp.ADC_RSSI := Readings.ADC_RSSI;
      Inp.Battery_Voltage := Readings.Centivolts;
      Inp.Legacy_Voltage := Readings.Decivolts;
      Inp.Hub := Readings.Hub;
      Trial_State := State;
      FS.Data_Received (Trial_State, Trial_Settings, Inp, Ops, Result);
      Split := First_Of (Ops, SR.Read_Fifo);
      if Split = 0 then
         State := Trial_State;
         Settings := Trial_Settings;
         Run (Ops, 1, Ops.Count);
      else
         Run (Ops, 1, Split - 1);
         declare
            Count : constant Natural := Natural'Min (Natural (Ops.Ops (Split).A), FS.Fifo_Size);
            Data  : Byte_Array (0 .. Count - 1);
         begin
            Radio_Chip.Read_FIFO (Dev, Data);
            for I in Data'Range loop
               Inp.Fifo (I) := Data (I);
            end loop;
         end;
         FS.Data_Received (State, Settings, Inp, Ops, Result);
         Run (Ops, Split + 1, Ops.Count);
      end if;
      R := (Bind => Result = FS.Bind_Done, Data => Result = FS.Data_Ready,
            Processing_Required => State.Processing_Required);
   end FrSky_Data_Received;

   procedure FrSky_Process_Frame (R : out Adaflight.RX_SPI.Received) is
   begin
      FS.Process_Frame (State, Time.Millis, Smart, Smart_Values, Tunnel, Resume => False, MSP_Request => MSP_Wanted);
      R := (others => False);
   end FrSky_Process_Frame;

   function FrSky_MSP_Pending return Boolean is (MSP_Wanted);

   procedure FrSky_Answer_MSP is
      Count          : Natural;
      Failed         : Boolean;
      Unused_Request : Boolean;
   begin
      MSP_Wanted := False;
      Answer (Tunnel.Request_Command, Adaflight.MSP_Telemetry.Request_Data (Tunnel), Reply, Count, Failed);
      Adaflight.MSP_Telemetry.Prepare_Reply
        (Tunnel, (if Failed then Adaflight.MSP_Telemetry.Result_Error else MSP_Ack), Reply (0 .. Count - 1));
      FS.Process_Frame (State, Time.Millis, Smart, Smart_Values, Tunnel, Resume => True,
                        MSP_Request => Unused_Request);
   end FrSky_Answer_MSP;

   procedure FrSky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is
      Rc : FS.Channel_Values;
   begin
      for I in Rc'Range loop
         Rc (I) := Data (I);
      end loop;
      FS.Set_Rc_Data (State, Settings, Rc);
      for I in Rc'Range loop
         Data (I) := Rc (I);
      end loop;
   end FrSky_Set_Channels;

   procedure FrSky_Request_Bind is
   begin
      FS.Request_Bind (State);
   end FrSky_Request_Bind;

   function FrSky_Hub_Taken return Boolean is (State.Telemetry_Enabled and then Settings.Protocol = FS.FrSky_D);

   function FrSky_SmartPort_Taken return Boolean is
     (State.Telemetry_Enabled and then Settings.Protocol /= FS.FrSky_D);

   procedure Set_Readings (R : Adaflight.STM32.RX_SPI.Telemetry_Readings) is
   begin
      Readings := R;
   end Set_Readings;

   procedure Set_Hub_Settings (S : Adaflight.FrSky_Hub_Telemetry.Settings) is
   begin
      Settings.Hub := S;
   end Set_Hub_Settings;

   procedure Set_SmartPort_Build (B : Adaflight.SmartPort_Telemetry.Build_Inputs) is
   begin
      Smart := (others => <>);
      Tunnel := (others => <>);
      Adaflight.SmartPort_Telemetry.Build (Smart, B);
   end Set_SmartPort_Build;

   procedure Set_SmartPort_Values (V : Adaflight.SmartPort_Telemetry.Inputs) is
   begin
      Smart_Values := V;
   end Set_SmartPort_Values;

   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean) is
      R : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record renames C.Rx_Cc2500_Spi_Config;
   begin
      Requested := Save_Wanted;
      Save_Wanted := False;
      if not Requested then
         return;
      end if;
      for I in Settings.Bind_Tx_Id'Range loop
         R.Bind_Tx_Id (I) := Settings.Bind_Tx_Id (I);
      end loop;
      R.Bind_Offset := Settings.Bind_Offset;
      for I in Settings.Bind_Hop_Data'Range loop
         R.Bind_Hop_Data (I) := Settings.Bind_Hop_Data (I);
      end loop;
      R.Rx_Num := Settings.Rx_Num;
   end Take_Save;
end Adaflight.STM32.RX_SPI_CC2500;
