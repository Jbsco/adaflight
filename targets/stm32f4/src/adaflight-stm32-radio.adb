with Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.CRSF;
with Adaflight.CRSF_Display_Port;
with Adaflight.SBUS;
with Adaflight.Stream_Buffers;
with Adaflight.Modes;
with Adaflight.Serial_Feature_Map;
package body Adaflight.STM32.Radio is
   use type Adaflight.STM32.USART.Number;
   package SFM renames Adaflight.Serial_Feature_Map;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.Modes.Box;

   --  The serial receiver provider settings for SBUS and CRSF, the SBUS rates,
   --  and the serial receiver feature's bit.
   SBUS_Provider     : constant Interfaces.Unsigned_8 := 2;
   CRSF_Provider     : constant Interfaces.Unsigned_8 := 9;
   SBUS_Baud         : constant := 100_000;
   SBUS_Fast_Baud    : constant := 200_000;
   Feature_RX_Serial : constant Interfaces.Unsigned_32 := 8;
   --  The serial port identifiers of the board's UARTs.
   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   type Provider is (CRSF, SBUS);
   Open        : Boolean := False;
   Kind        : Provider := CRSF;
   SBUS_State  : Adaflight.SBUS.State;
   Link        : USART.Number := USART.UART3;
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

   --  The port at a new rate, with the receiver's timing told.
   procedure Set_Rate (Rate : Interfaces.Unsigned_32) is
   begin
      USART.Init (Link, Positive (Interfaces.Unsigned_32'Max (1, Rate)));
      Adaflight.CRSF.Update_Baudrate (Proto, Rate);
   end Set_Rate;

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms; Telemetry : Adaflight.CRSF_Telemetry.Config) is
      Conditions : constant Adaflight.Modes.Conditions :=
        Adaflight.Config_Runtime.Conditions_Of (Config.Mode_Activation_Conditions);
      R : Adaflight.Config_Groups.Rx_Config_Record renames Config.Rx_Config;
   begin
      Open := False;
      Kind := (if R.Serialrx_Provider = SBUS_Provider then SBUS else CRSF);
      Rx_Settings := Adaflight.Config_Runtime.Receiver_Settings_Of
        (Config.Rx_Config, Config.Rx_Channel_Range_Configs, Config.Rx_Failsafe_Channel_Configs,
         Config.Flight3_D_Config, Config.Failsafe_Config, Runtime_Features,
         Reported_Channels => (case Kind is
                                  when CRSF => Adaflight.CRSF.Channel_Count,
                                  when SBUS => Adaflight.SBUS.Channel_Count));
      FS_Settings := Adaflight.Config_Runtime.Failsafe_Settings_Of (Config.Failsafe_Config, Config.Autopilot_Config);
      Adaflight.Failsafe.Init (FS, FS_Settings);
      if (Runtime_Features and Feature_RX_Serial) /= 0 and then R.Half_Duplex = 0
        and then ((R.Serialrx_Provider = CRSF_Provider and then R.Serialrx_Inverted = 0)
                  or else R.Serialrx_Provider = SBUS_Provider)
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
            elsif R.Rssi_Src_Frame_Errors /= 0 then Adaflight.Receiver.Frame_Errors
            else Adaflight.Receiver.None),
         Protocol_Quality => (if Open and then Kind = CRSF then Adaflight.Receiver.CRSF else Adaflight.Receiver.None));
      for C of Conditions loop
         if C.Mode = Adaflight.Modes.Arm and then Adaflight.Modes.Usable (C.Span) then
            Adaflight.Receiver.Init_Arm_Switch (Rx, C.Aux, C.Span);
         end if;
      end loop;
      if Open then
         case Kind is
            when CRSF =>
               Adaflight.CRSF.Init (Proto, Rx_Settings.Mid_RC);
               USART.Init (Link, Adaflight.CRSF.Baudrate);
            when SBUS =>
               --  Inverted unless the setting says the receiver's line is not.
               Adaflight.SBUS.Init (SBUS_State, Rx_Settings.Mid_RC);
               USART.Init
                 (Link, (if R.Sbus_Baud_Fast /= 0 then SBUS_Fast_Baud else SBUS_Baud), Two_Stop_Bits => True,
                  Even_Parity => True, Inverted => R.Serialrx_Inverted = 0);
         end case;
         Port.Which := Link;
      end if;
      Adaflight.CRSF_Telemetry.Init (Tlm, Telemetry, Active => Open and then Kind = CRSF);
      Adaflight.CRSF_Display_Port.Init (Screen, Now_Ms);
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
      if Outputs.Default_Speed then
         Set_Rate (Adaflight.CRSF.Baudrate);
      end if;
   end Telemetry_Events;

   procedure Telemetry_Step (Now_Us : Time_Us; Src : Adaflight.CRSF_Telemetry.Sources) is
      Run      : Boolean;
      New_Baud : Interfaces.Unsigned_32;
   begin
      if not Open or else Kind /= CRSF then
         return;
      end if;
      Tlm.Event_Driven := Proto.Event_Telemetry;
      Adaflight.Stream_Buffers.Init (Out_Stream, 0, Out_Bytes'Length);
      Adaflight.CRSF_Telemetry.Update_Check (Tlm, Now_Us, Run);
      Adaflight.CRSF_Telemetry.Negotiate (Tlm, Now_Us, Out_Bytes, Out_Stream, New_Baud);
      Adaflight.CRSF_Telemetry.Update (Tlm, Now_Us, Src, Screen, Display_Ready => False, B => Out_Bytes,
                                       S => Out_Stream);
      if Out_Stream.Next > 0 then
         USART.Put (Port, Out_Bytes (0 .. Out_Stream.Next - 1));
      end if;
      if New_Baud /= 0 then
         Set_Rate (New_Baud);
      end if;
   end Telemetry_Step;

   function Linked return Boolean is (Open);

   function Is_CRSF return Boolean is (Open and then Kind = CRSF);

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
         end case;
      end if;
      Adaflight.Receiver.Frame_Check (Rx, Rx_Settings, Now_Us, Delta_Us, Task_In_Progress, Status, Override);
   end Frame_Check;

   function Update_Check (Task_In_Progress : Boolean) return Boolean is
     (Adaflight.Receiver.Update_Check (Rx, Task_In_Progress));

   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; ADC_Sample : Natural; Processed : out Boolean) is
      Raw             : Adaflight.Receiver.Raw_Values := (others => 0.0);
      Override        : Adaflight.Receiver.Override_Report;
      Frame_Processed : Boolean;
      Valid           : Adaflight.Receiver.Validity;
   begin
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
         when SBUS => SBUS_State.Last_Frame_Time_Us);

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
