with Adaflight.Bytes;
with Adaflight.Config_Fix;
with Adaflight.Config_Runtime;
with Adaflight.CRSF;
with Adaflight.Failsafe;
with Adaflight.Modes;
with Adaflight.Serial_Feature_Map;
with Adaflight.STM32.USART;
package body Adaflight.STM32.Radio is
   package SFM renames Adaflight.Serial_Feature_Map;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Adaflight.Modes.Box;

   --  The serial receiver provider setting for CRSF, the serial receiver
   --  feature's bit, and the delay before the failsafe monitors the link.
   CRSF_Provider     : constant Interfaces.Unsigned_8 := 9;
   Feature_RX_Serial : constant Interfaces.Unsigned_32 := 8;
   Power_On_Delay_Us : constant := 5_000_000;
   --  The serial port identifiers of the board's UARTs.
   Port_Ids : constant array (USART.Number) of SFM.Port_Id :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   Open        : Boolean := False;
   Link        : USART.Number := USART.UART3;
   Rx          : Adaflight.Receiver.State;
   Rx_Settings : Adaflight.Receiver.Settings;
   Proto       : Adaflight.CRSF.State;
   FS          : Adaflight.Failsafe.State;
   FS_Settings : Adaflight.Failsafe.Settings;
   Input       : Adaflight.Bytes.Byte_Array (0 .. 63);
   Times       : USART.Time_Array (0 .. 63);

   procedure Init (Config : Adaflight.Config_Groups.Configuration; Runtime_Features : Interfaces.Unsigned_32;
                   Now_Ms : Time_Ms) is
      Conditions : constant Adaflight.Modes.Conditions :=
        Adaflight.Config_Runtime.Conditions_Of (Config.Mode_Activation_Conditions);
   begin
      Open := False;
      Rx_Settings := Adaflight.Config_Runtime.Receiver_Settings_Of
        (Config.Rx_Config, Config.Rx_Channel_Range_Configs, Config.Rx_Failsafe_Channel_Configs,
         Config.Flight3_D_Config, Config.Failsafe_Config, Runtime_Features,
         Reported_Channels => Adaflight.CRSF.Channel_Count);
      FS_Settings := Adaflight.Config_Runtime.Failsafe_Settings_Of (Config.Failsafe_Config, Config.Autopilot_Config);
      Adaflight.Failsafe.Init (FS, FS_Settings);
      if (Runtime_Features and Feature_RX_Serial) /= 0 and then Config.Rx_Config.Serialrx_Provider = CRSF_Provider
        and then Config.Rx_Config.Serialrx_Inverted = 0 and then Config.Rx_Config.Half_Duplex = 0
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
         Protocol_RSSI    => (if Open then Adaflight.Receiver.Protocol_CRSF else Adaflight.Receiver.None),
         Protocol_Quality => (if Open then Adaflight.Receiver.CRSF else Adaflight.Receiver.None));
      for C of Conditions loop
         if C.Mode = Adaflight.Modes.Arm and then Adaflight.Modes.Usable (C.Span) then
            Adaflight.Receiver.Init_Arm_Switch (Rx, C.Aux, C.Span);
         end if;
      end loop;
      if Open then
         Adaflight.CRSF.Init (Proto, Rx_Settings.Mid_RC);
         USART.Init (Link, Adaflight.CRSF.Baudrate);
      end if;
   end Init;

   function Linked return Boolean is (Open);

   procedure Frame_Check (Now_Us : Time_Us; Delta_Us : Interfaces.Integer_32; Task_In_Progress : Boolean) is
      Count    : Natural;
      Outputs  : Adaflight.CRSF.Byte_Outputs;
      Status   : Adaflight.Receiver.Frame_Report;
      Override : Adaflight.Receiver.Override_Report;
   begin
      if not Open then
         return;
      end if;
      USART.Take (Link, Input, Times, Count);
      for I in 0 .. Count - 1 loop
         Adaflight.CRSF.Receive_Byte
           (Proto, Rx, Natural (Input (I)), Times (I), Negotiating => False, Eeprom_Writing => False,
            Result => Outputs);
      end loop;
      if not Task_In_Progress then
         Adaflight.CRSF.Frame_Status (Proto, Rx, Now_Us, Status);
      end if;
      Adaflight.Receiver.Frame_Check (Rx, Rx_Settings, Now_Us, Delta_Us, Task_In_Progress, Status, Override);
   end Frame_Check;

   function Update_Check (Task_In_Progress : Boolean) return Boolean is
     (Adaflight.Receiver.Update_Check (Rx, Task_In_Progress));

   procedure Process (Now_Us : Time_Us; Now_Ms : Time_Ms; Processed : out Boolean) is
      Raw             : Adaflight.Receiver.Raw_Values := (others => 0.0);
      Override        : Adaflight.Receiver.Override_Report;
      Frame_Processed : Boolean;
      Valid           : Adaflight.Receiver.Validity;
   begin
      if Open then
         for Ch in Adaflight.CRSF.Channel loop
            Raw (Ch) := Float'Max (0.0, Float'Min (65_535.0, Adaflight.CRSF.Read_Raw (Proto, Ch)));
         end loop;
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
      Adaflight.Receiver.Update_RSSI (Rx, Rx_Settings, Now_Us, ADC_Sample => 0);
      if Now_Us > Power_On_Delay_Us and then not FS.Monitoring then
         Adaflight.Failsafe.Start_Monitoring (FS);
      end if;
   end Process;

   procedure Failsafe_Check (Now_Ms : Time_Ms) is
      In_Flight    : Adaflight.Failsafe.Inputs;
      Beeper       : Adaflight.Failsafe.Beep;
      Disarm       : Boolean;
      Stage_Rescue : Boolean;
   begin
      Adaflight.Failsafe.Check_Data_Failure_Period (FS, Now_Ms);
      Adaflight.Failsafe.Update (FS, FS_Settings, Now_Ms, In_Flight, Beeper, Disarm, Stage_Rescue);
   end Failsafe_Check;

   function Channel_Count return Natural is (Rx.Channels);

   function Channel (I : Adaflight.Receiver.Channel) return Float is (Rx.Data (I));

   function Receiving return Boolean is (Adaflight.Receiver.Receiving_Signal (Rx));
end Adaflight.STM32.Radio;
