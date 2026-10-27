with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Config_Runtime;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.GPS;
with Adaflight.STM32.Pilot;
with Adaflight.STM32.Radio;
with Adaflight.Tramp;
with Adaflight.VTX;
with Adaflight.VTX_Table_Store;
package body Adaflight.STM32.VTX is
   use type Interfaces.Integer_8;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Adaflight.STM32.USART.Number;
   use type Adaflight.VTX.Device_Kind;
   use type Adaflight.VTX.Settings;
   package Core renames Adaflight.VTX;
   package USART renames Adaflight.STM32.USART;

   --  The serial port identifiers of the board's UARTs.
   Port_Ids : constant array (USART.Number) of Interfaces.Integer_8 :=
     (USART.UART1 => 51, USART.UART3 => 53, USART.UART4 => 54, USART.UART6 => 56);

   SmartAudio_Code : constant := 3;
   Tramp_Code      : constant := 4;
   Unknown_Code    : constant := 16#FF#;

   SmartAudio_Line : constant USART.Half_Duplex :=
     (On => True, Push_Pull => True, Resistor => Adaflight.STM32.GPIO.Down);
   Tramp_Line      : constant USART.Half_Duplex :=
     (On => True, Push_Pull => False, Resistor => Adaflight.STM32.GPIO.Up);

   V       : Core.State;
   T       : Adaflight.VTX_Table.Table;
   Open    : Boolean := False;
   Which   : USART.Number := USART.UART1;
   Port    : USART.Port;
   Pending : Byte_Array (0 .. 255) := (others => 0);
   Waiting : Natural range 0 .. 256 := 0;

   --  The settings the control layer changed, written back to the stored
   --  ones.
   procedure Store (C : in out Adaflight.Config_Groups.Configuration; S : Core.Settings) is
   begin
      C.Vtx_Settings_Config.Band := S.Band;
      C.Vtx_Settings_Config.Channel := S.Channel;
      C.Vtx_Settings_Config.Power := S.Power;
      C.Vtx_Settings_Config.Freq := S.Freq;
      C.Vtx_Settings_Config.Pit_Mode_Freq := S.Pit_Mode_Freq;
   end Store;

   function Kind_Of (Code : Interfaces.Unsigned_8) return Core.Device_Kind is
     (case Code is
         when SmartAudio_Code => Core.SmartAudio_Device,
         when Tramp_Code      => Core.Tramp_Device,
         when others          => Core.No_Device);

   --  The table, then SmartAudio's start and Tramp's on the configured port,
   --  each opening the port for its kind, then the common start with the
   --  device registered when its port opened.
   procedure Init (C : in out Adaflight.Config_Groups.Configuration; Save : out Boolean) is
      Kind : Core.Device_Kind := Kind_Of (C.Vtx_Settings_Config.Vtx_Type);
      S    : Core.Settings := Adaflight.Config_Runtime.VTX_Settings_Of (C.Vtx_Settings_Config);
   begin
      T := (if Adaflight.VTX_Table_Store.Counts_Valid (C.Vtx_Table_Config)
            then Adaflight.VTX_Table_Store.Running (C.Vtx_Table_Config) else Adaflight.VTX_Table.Default);
      Open := False;
      if Kind /= Core.No_Device then
         for N in USART.Number loop
            if Port_Ids (N) = C.Vtx_Settings_Config.Vtx_Uart then
               if not Adaflight.STM32.Radio.Holds (N) and then not Adaflight.STM32.GPS.Holds (N) then
                  Which := N;
                  Open := True;
               end if;
               exit;
            end if;
         end loop;
      end if;
      if Open then
         Port.Which := Which;
         case Kind is
            when Core.SmartAudio_Device =>
               USART.Init (Which, 4_800, Two_Stop_Bits => True, Line => SmartAudio_Line);
            when Core.Tramp_Device =>
               USART.Init
                 (Which, 9_600, Line => (if C.Vtx_Config.Half_Duplex /= 0 then Tramp_Line else USART.Full_Duplex));
            when others =>
               null;
         end case;
      else
         Kind := Core.No_Device;
      end if;
      Core.Init (V, S, T, Kind, Port_Opened => Open, Softserial => False, Save => Save);
      if Save then
         Store (C, S);
      end if;
   end Init;

   function Holds (N : USART.Number) return Boolean is (Open and then N = Which);

   procedure Run
     (C        : in out Adaflight.Config_Groups.Configuration;
      Now_Ms   : Interfaces.Unsigned_32;
      Now_Us   : Interfaces.Unsigned_32;
      Cli_Mode : Boolean;
      Save     : out Boolean)
   is
      S      : Core.Settings := Adaflight.Config_Runtime.VTX_Settings_Of (C.Vtx_Settings_Config);
      Before : constant Core.Settings := S;
      Fresh  : Byte_Array (0 .. 255);
      Count  : Natural := 0;
      E      : Core.Events;
      Inp    : constant Core.Inputs :=
        (Now_Ms           => Now_Ms,
         Now_Us           => Now_Us,
         Armed            => Adaflight.STM32.Pilot.Armed,
         Was_Ever_Armed   => Adaflight.STM32.Pilot.Was_Ever_Armed,
         Failsafe         => Adaflight.STM32.Radio.Failsafe_Active,
         Cli_Mode         => Cli_Mode,
         Pit_Switch       => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.VTX_Pit_Mode),
         Control_Disabled => Adaflight.STM32.Pilot.Box_Active (Adaflight.Modes.VTX_Control_Disable));
   begin
      if Open then
         USART.Take (Which, Fresh (0 .. Pending'Length - Waiting - 1), Count);
         Pending (Waiting .. Waiting + Count - 1) := Fresh (0 .. Count - 1);
         Waiting := Waiting + Count;
      end if;
      Core.Update (V, S, T, Inp, Pending (0 .. Waiting - 1), E);
      if E.Consumed > 0 then
         Pending (0 .. Waiting - E.Consumed - 1) := Pending (E.Consumed .. Waiting - 1);
         Waiting := Waiting - E.Consumed;
      end if;
      if Open then
         case V.Kind is
            when Core.SmartAudio_Device =>
               if E.Device.Tx_Count > 0 then
                  USART.Put (Port, Byte_Array (E.Device.Tx (0 .. E.Device.Tx_Count - 1)));
               end if;
               if E.Device.Baud_Changed then
                  USART.Init (Which, Positive (Adaflight.SmartAudio.Rate_Of (E.Device.New_Baud)), Two_Stop_Bits => True,
                              Line => SmartAudio_Line);
               end if;
            when Core.Tramp_Device =>
               if E.Tramp_Tx.Tx_Count > 0 then
                  USART.Put (Port, Byte_Array (E.Tramp_Tx.Tx (0 .. E.Tramp_Tx.Tx_Count - 1)));
               end if;
            when others =>
               null;
         end case;
      end if;
      if S /= Before then
         Store (C, S);
      end if;
      Save := E.Save;
   end Run;

   procedure Switches
     (C : in out Adaflight.Config_Groups.Configuration; Aux : Adaflight.Modes.Aux_Values; Armed : Boolean)
   is
      S     : Core.Settings := Adaflight.Config_Runtime.VTX_Settings_Of (C.Vtx_Settings_Config);
      Conds : Core.Conditions;
   begin
      for I in Core.Condition_Index loop
         declare
            R : constant Adaflight.Config_Groups.Vtx_Channel_Activation_Condition_Record :=
              C.Vtx_Config.Vtx_Channel_Activation_Conditions (I - 1);
         begin
            Conds (I) :=
              (Aux     => Natural'Min (Adaflight.Modes.Aux_Channel'Last, Natural (R.Aux_Channel_Index)),
               Band    => R.Band,
               Channel => R.Channel,
               Power   => R.Power,
               Span    => (Start_Step => Natural'Min (Adaflight.Modes.Max_Range_Step, Natural (R.Range_Value.Start_Step)),
                           End_Step   => Natural'Min (Adaflight.Modes.Max_Range_Step, Natural (R.Range_Value.End_Step))));
         end;
      end loop;
      Core.Update_Activated_Channel (V, S, Conds, Aux, Armed);
      Store (C, S);
   end Switches;

   procedure Set_Pit_Mode (Value : Interfaces.Unsigned_8) is
   begin
      Core.Common_Set_Pit_Mode (V, T, Value);
   end Set_Pit_Mode;

   function Device return Adaflight.MSP_VTX_In.Device is
      Pit   : Boolean;
      Known : Boolean;
   begin
      Core.Common_Get_Status (V, Pit, Known);
      return (Present => V.Device_Present, Known_Type => V.Device_Present and then V.Kind /= Core.No_Device,
              Pit_Mode => Known and then Pit);
   end Device;

   function Table return Adaflight.VTX_Table.Table is (T);

   function Status return Adaflight.MSP_VTX_Status_Out.Snapshot is
     (VTX_Common => True,
      Kind       =>
        (if not V.Device_Present then Adaflight.MSP_VTX_Status_Out.No_Device
         else (case V.Kind is
                  when Core.SmartAudio_Device => Adaflight.MSP_VTX_Status_Out.SmartAudio_Device,
                  when Core.Tramp_Device      => Adaflight.MSP_VTX_Status_Out.Tramp_Device,
                  when others                 => Adaflight.MSP_VTX_Status_Out.No_Device)),
      SA         => V.SA,
      TR         => V.TR,
      MD         => V.MD,
      Table      => T);

   procedure Peripheral (Present, Pit_Mode, Ready : out Boolean; Type_Code : out Interfaces.Unsigned_8) is
      Known : Boolean;
   begin
      Present := V.Device_Present;
      Core.Common_Get_Status (V, Pit_Mode, Known);
      Pit_Mode := Present and then Known and then Pit_Mode;
      Ready := Present
        and then (case V.Kind is
                     when Core.SmartAudio_Device => Adaflight.SmartAudio.Ready (V.SA),
                     when Core.Tramp_Device      => Adaflight.Tramp.Ready (V.TR),
                     when others                 => False);
      Type_Code :=
        (if not Present then Unknown_Code
         else (case V.Kind is
                  when Core.SmartAudio_Device => SmartAudio_Code,
                  when Core.Tramp_Device      => Tramp_Code,
                  when others                 => Unknown_Code));
   end Peripheral;

   procedure Power_Levels (Count : out Natural; Levels, Powers : out Adaflight.SmartAudio.Level_Values) is
      N : Adaflight.SmartAudio.Level_Count := 0;
   begin
      Levels := (others => 0);
      Powers := (others => 0);
      if V.Device_Present and then V.Kind = Core.SmartAudio_Device then
         Adaflight.SmartAudio.Get_Power_Levels (V.SA, N, Levels, Powers);
      end if;
      Count := N;
   end Power_Levels;
end Adaflight.STM32.VTX;
