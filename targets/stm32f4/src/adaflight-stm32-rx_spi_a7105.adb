with Adaflight.A7105;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Runtime;
with Adaflight.FlySky;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.SPI_Radio;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.MCU;
with Adaflight.STM32.Radio;
with Adaflight.STM32.Receiver_Storage;
with Adaflight.STM32.RX_SPI_Device;
with Adaflight.STM32.Time;
package body Adaflight.STM32.RX_SPI_A7105 is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   package SR renames Adaflight.SPI_Radio;
   package FS renames Adaflight.FlySky;
   use type SR.Op_Kind;
   use type SR.Pin;
   use type FS.Received;

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

   package Radio_Chip is new Adaflight.A7105
     (Radio_Device            => Chip,
      Bus_Write_Command       => Write_Command,
      Bus_Write_Command_Multi => Write_Command_Multi,
      Bus_Read_Command        => Read_Command,
      Bus_Read_Command_Multi  => Read_Command_Multi,
      Bus_Write_Byte          => Write_Byte);

   Dev : Chip;

   Mode_Register : constant Radio_Chip.Register := 16#00#;
   RSSI_Register : constant Radio_Chip.Register := 16#1D#;
   Register_Mask : constant Byte := 16#3F#;
   --  The reads a calibration is given to clear its register.
   Clear_Reads   : constant := 1_001;

   LED_Pin  : Pin := (Port_A, 0);
   Has_LED  : Boolean := False;
   Bind_Pin : Pin := (Port_A, 0);
   Has_Bind : Boolean := False;

   --  The settings, the state and its trial copy lie in the storage the
   --  receivers share; the start sets them.
   Settings    : FS.Settings
     with Import, Address => Adaflight.STM32.Receiver_Storage.Shared.FlySky_State.Settings'Address;
   State       : FS.State
     with Import, Address => Adaflight.STM32.Receiver_Storage.Shared.FlySky_State.State'Address;
   Trial_State : FS.State
     with Import, Address => Adaflight.STM32.Receiver_Storage.Shared.FlySky_State.Trial'Address;
   Ops         : SR.Output;
   Save_Wanted : Boolean := False;
   Battery     : Interfaces.Unsigned_16 := 0;

   function Has_Tag (Tag : Byte) return Boolean is (Tag / 16 in 1 .. Port_Name'Pos (Port_Name'Last) + 1);

   function Bind_Level return Boolean is (if Has_Bind then GPIO.Is_High (Bind_Pin) else True);

   procedure Pins_Init (Spi : Adaflight.Config_Groups.Rx_Spi_Config_Record) is
   begin
      Has_LED := Has_Tag (Spi.Led_Io_Tag);
      if Has_LED then
         LED_Pin := Pin_Of (Natural (Spi.Led_Io_Tag));
         GPIO.Enable_Port (LED_Pin.Port);
         GPIO.Set_Output (LED_Pin);
      end if;
      Has_Bind := Has_Tag (Spi.Bind_Io_Tag);
      if Has_Bind then
         Bind_Pin := Pin_Of (Natural (Spi.Bind_Io_Tag));
         GPIO.Enable_Port (Bind_Pin.Port);
         GPIO.Set_Input (Bind_Pin, GPIO.Up);
      end if;
   end Pins_Init;

   --  The operations First to Last in order. A FIFO read happened before the
   --  call that asked for it.
   procedure Run (O : SR.Output; First, Last : Natural) is
   begin
      for K in First .. Last loop
         declare
            P : SR.Op renames O.Ops (K);
         begin
            case P.Kind is
               when SR.Strobe =>
                  Radio_Chip.Strobe (Dev, P.A);
               when SR.Write_Register =>
                  Radio_Chip.Write_Register (Dev, P.A and Register_Mask, P.B);
               when SR.Read_Register =>
                  declare
                     Unused : Byte;
                  begin
                     Radio_Chip.Read_Register (Dev, P.A and Register_Mask, Unused);
                  end;
               when SR.Await_Clear =>
                  declare
                     Value : Byte;
                  begin
                     for Read in 1 .. Clear_Reads loop
                        Radio_Chip.Read_Register (Dev, P.A and Register_Mask, Value);
                        exit when Value = 0;
                     end loop;
                  end;
               when SR.Write_Id =>
                  Radio_Chip.Write_ID (Dev, P.Word);
               when SR.Read_Fifo =>
                  null;
               when SR.Write_Fifo =>
                  declare
                     Data : Byte_Array (0 .. Natural'Min (Natural (P.A), Radio_Chip.FIFO_Size) - 1);
                  begin
                     for I in Data'Range loop
                        Data (I) := O.Tx_Data (I);
                     end loop;
                     Radio_Chip.Write_FIFO (Dev, Data);
                  end;
               when SR.Reset_Exti =>
                  RX_SPI_Device.Reset_Exti;
               when SR.Delay_Ms =>
                  Time.Delay_Ms (Natural (P.Value));
               when SR.Delay_Us =>
                  Time.Delay_Us (Natural (P.Value));
               when SR.Pin_High | SR.Pin_Low | SR.Pin_Toggle =>
                  if P.On = SR.LED and then Has_LED then
                     case P.Kind is
                        when SR.Pin_High => GPIO.Set_High (LED_Pin);
                        when SR.Pin_Low => GPIO.Set_Low (LED_Pin);
                        when others => GPIO.Toggle (LED_Pin);
                     end case;
                  end if;
               when SR.Set_RSSI =>
                  Radio.Set_Protocol_RSSI (P.Value, Direct => False);
               when SR.Set_RSSI_Direct =>
                  Radio.Set_Protocol_RSSI (P.Value, Direct => True);
               when SR.Save_Config =>
                  Save_Wanted := True;
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

   procedure FlySky_Init
     (Spi    : Adaflight.Config_Groups.Rx_Spi_Config_Record;
      CC2500 : Adaflight.Config_Groups.Rx_Cc2500_Spi_Config_Record;
      FlySky : Adaflight.Config_Groups.Fly_Sky_Config_Record;
      Ok     : out Boolean; Channels : out Natural; Claim_RSSI : out Boolean)
   is
      Inp : FS.Inputs;
      Id  : constant Adaflight.STM32.MCU.Identifier := Adaflight.STM32.MCU.UID;
   begin
      State := (others => <>);
      Settings := Adaflight.Config_Runtime.FlySky_Settings_Of (Spi, CC2500, FlySky);
      --  An AFHDS 2A receiver names itself by the microcontroller's
      --  identifier words.
      Settings.Receiver_Id := Id (1) xor Id (2) xor Id (3);
      Channels := FS.Channel_Count (Settings);
      Save_Wanted := False;
      if not RX_SPI_Device.Exti_Configured then
         Ok := False;
         Claim_RSSI := False;
         return;
      end if;
      Pins_Init (Spi);
      Inp.Now_Us := Time.Micros;
      Inp.Now_Ms := Time.Millis;
      Inp.Bind_Pin_Level := Bind_Level;
      FS.Start (State, Settings, Inp, Ops, Ok, Claim_RSSI);
      Run (Ops, 1, Ops.Count);
   end FlySky_Init;

   procedure FlySky_Data_Received (R : out Adaflight.RX_SPI.Received) is
      Inp            : FS.Inputs;
      Trial_Settings : FS.Settings := Settings;
      Result         : FS.Received;
      Split          : Natural;
      First          : Positive := 1;
   begin
      Inp.Now_Us := Time.Micros;
      Inp.Now_Ms := Time.Millis;
      Inp.Exti_Flag := RX_SPI_Device.Poll_Exti;
      Inp.Exti_Time_Us := RX_SPI_Device.Last_Exti_Time;
      Inp.Bind_Pin_Level := Bind_Level;
      Inp.Battery_Voltage := Battery;
      --  A raised line the receiver consumes is reset before the mode
      --  register is read; the receiver's own reset, its first operation
      --  then, is left out.
      if State.Consume_Exti and then Inp.Exti_Flag then
         RX_SPI_Device.Reset_Exti;
         Radio_Chip.Read_Register (Dev, Mode_Register, Inp.Mode_Register);
         First := 2;
      end if;
      Trial_State := State;
      FS.Data_Received (Trial_State, Trial_Settings, Inp, Ops, Result);
      if First = 2 and then (Ops.Count = 0 or else Ops.Ops (1).Kind /= SR.Reset_Exti) then
         First := 1;
      end if;
      Split := First_Of (Ops, SR.Read_Fifo);
      if Split = 0 then
         State := Trial_State;
         Settings := Trial_Settings;
         Run (Ops, First, Ops.Count);
      else
         Run (Ops, First, Split - 1);
         declare
            Count : constant Natural := Natural'Min (Natural (Ops.Ops (Split).A), FS.Fifo_Size);
            Data  : Byte_Array (0 .. Count - 1);
         begin
            Radio_Chip.Read_FIFO (Dev, Data);
            for I in Data'Range loop
               Inp.Fifo (I) := Data (I);
            end loop;
         end;
         Radio_Chip.Read_Register (Dev, RSSI_Register, Inp.RSSI_Register);
         FS.Data_Received (State, Settings, Inp, Ops, Result);
         Run (Ops, Split + 1, Ops.Count);
      end if;
      R := (Bind => Result = FS.Bind_Done, Data => Result = FS.Data_Ready, Processing_Required => False);
   end FlySky_Data_Received;

   procedure FlySky_Set_Channels (Data : in out Adaflight.RX_SPI.Channel_Data) is
      Rc : FS.Channel_Values;
   begin
      for I in Rc'Range loop
         Rc (I) := Data (I);
      end loop;
      FS.Set_Rc_Data (State, Settings, Rc);
      for I in Rc'Range loop
         Data (I) := Rc (I);
      end loop;
   end FlySky_Set_Channels;

   procedure FlySky_Request_Bind is
   begin
      FS.Request_Bind (State);
   end FlySky_Request_Bind;

   procedure Set_Battery_Voltage (Centivolts : Interfaces.Unsigned_16) is
   begin
      Battery := Centivolts;
   end Set_Battery_Voltage;

   procedure Take_Save (C : in out Adaflight.Config_Groups.Configuration; Requested : out Boolean) is
   begin
      Requested := Save_Wanted;
      if Save_Wanted then
         Save_Wanted := False;
         C.Fly_Sky_Config.Tx_Id := Settings.Tx_Id;
         for I in Settings.Rf_Map'Range loop
            C.Fly_Sky_Config.Rf_Channel_Map (I) := Settings.Rf_Map (I);
         end loop;
      end if;
   end Take_Save;

end Adaflight.STM32.RX_SPI_A7105;
