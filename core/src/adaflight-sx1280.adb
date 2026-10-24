package body Adaflight.SX1280 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_8;

   Cmd_Get_Status            : constant Byte := 16#C0#;
   Cmd_Write_Register        : constant Byte := 16#18#;
   Cmd_Read_Register         : constant Byte := 16#19#;
   Cmd_Write_Buffer          : constant Byte := 16#1A#;
   Cmd_Read_Buffer           : constant Byte := 16#1B#;
   Cmd_Set_Sleep             : constant Byte := 16#84#;
   Cmd_Set_Standby           : constant Byte := 16#80#;
   Cmd_Set_FS                : constant Byte := 16#C1#;
   Cmd_Set_TX                : constant Byte := 16#83#;
   Cmd_Set_RX                : constant Byte := 16#82#;
   Cmd_Set_Packet_Type       : constant Byte := 16#8A#;
   Cmd_Set_RF_Frequency      : constant Byte := 16#86#;
   Cmd_Set_TX_Params         : constant Byte := 16#8E#;
   Cmd_Set_Buffer_Base       : constant Byte := 16#8F#;
   Cmd_Set_Modulation_Params : constant Byte := 16#8B#;
   Cmd_Set_Packet_Params     : constant Byte := 16#8C#;
   Cmd_Get_RX_Buffer_Status  : constant Byte := 16#17#;
   Cmd_Get_Packet_Status     : constant Byte := 16#1D#;
   Cmd_Set_DIO_IRQ_Params    : constant Byte := 16#8D#;
   Cmd_Get_IRQ_Status        : constant Byte := 16#15#;
   Cmd_Clear_IRQ_Status      : constant Byte := 16#97#;
   Cmd_Set_Auto_FS           : constant Byte := 16#9E#;

   Reg_Firmware_Version    : constant Interfaces.Unsigned_16 := 16#0153#;
   Reg_RX_Gain_Regime      : constant Interfaces.Unsigned_16 := 16#0891#;
   Reg_SF_Additional       : constant Interfaces.Unsigned_16 := 16#0925#;
   Reg_FLRC_CRC_Seed       : constant Interfaces.Unsigned_16 := 16#09C8#;
   Reg_FLRC_Sync_Word      : constant Interfaces.Unsigned_16 := 16#09CF#;
   Reg_FLRC_Sync_Addr_Ctrl : constant Interfaces.Unsigned_16 := 16#09CD#;

   Irq_TX_Done        : constant Interfaces.Unsigned_16 := 16#0001#;
   Irq_RX_Done        : constant Interfaces.Unsigned_16 := 16#0002#;
   Irq_Syncword_Valid : constant Interfaces.Unsigned_16 := 16#0004#;
   Irq_Syncword_Error : constant Interfaces.Unsigned_16 := 16#0008#;
   Irq_CRC_Error      : constant Interfaces.Unsigned_16 := 16#0040#;

   Packet_Type_LoRa     : constant Byte := 1;
   Packet_Type_FLRC     : constant Byte := 3;
   Standby_RC_Value     : constant Byte := 0;
   Standby_XOSC_Value   : constant Byte := 1;
   Ramp_04_Us           : constant Byte := 16#20#;
   LoRa_IQ_Normal       : constant Byte := 16#40#;
   LoRa_IQ_Inverted     : constant Byte := 16#00#;
   LoRa_Packet_Fixed    : constant Byte := 16#80#;
   LoRa_CRC_Off         : constant Byte := 16#00#;
   FLRC_Sync_Word_P32S  : constant Byte := 16#04#;
   FLRC_Match_Sync_1    : constant Byte := 16#10#;
   FLRC_Packet_Fixed    : constant Byte := 16#00#;
   FLRC_CRC_3_Byte      : constant Byte := 16#20#;
   FLRC_Whitening_Off   : constant Byte := 16#08#;
   FLRC_CR_1_2          : constant Byte := 16#00#;
   FLRC_CR_3_4          : constant Byte := 16#02#;
   LoRa_SF5             : constant Byte := 16#50#;
   LoRa_SF6             : constant Byte := 16#60#;
   LoRa_SF7             : constant Byte := 16#70#;
   LoRa_SF8             : constant Byte := 16#80#;
   Default_Power        : constant Interfaces.Integer_8 := 13;
   Normal_Speed_Hz      : constant := 18_000_000;
   Busy_Timeout_Us      : constant := 1000;
   Reset_Low_Ms         : constant := 50;
   Reset_Settle_Ms      : constant := 20;
   Max_Chain            : constant := 12;

   procedure Poll_Busy (D : in out Radio_Device) is
      Start : Interfaces.Unsigned_32;
      Now   : Interfaces.Unsigned_32;
      Busy  : Boolean;
   begin
      Micros (D, Start);
      loop
         Read_Busy (D, Busy);
         exit when not Busy;
         Micros (D, Now);
         exit when Now - Start > Busy_Timeout_Us;
      end loop;
   end Poll_Busy;

   procedure Mark_Busy (D : in out Radio_Device; S : in out Radio; Claimed : out Boolean) is
      Now : Interfaces.Unsigned_32;
   begin
      if S.Processing /= 0 then
         Claimed := False;
         return;
      end if;
      Micros (D, Now);
      S.Processing := Now;
      Claimed := True;
   end Mark_Busy;

   procedure Clear_Busy_Fn (D : in out Radio_Device; S : in out Radio) is
   begin
      Busy_Exti_Disable (D);
      S.Waiting := No_Step;
   end Clear_Busy_Fn;

   procedure Enable_Busy (D : in out Radio_Device; S : in out Radio; Claimed : out Boolean) is
   begin
      Mark_Busy (D, S, Claimed);
      if Claimed then
         Busy_Exti_Config (D);
      end if;
   end Enable_Busy;

   procedure Enable_Exti (D : in out Radio_Device; S : in out Radio) is
   begin
      S.Processing := 0;
      Enable_Receiver_Exti (D);
   end Enable_Exti;

   procedure Is_Busy (D : in out Radio_Device; Busy : out Boolean) is
   begin
      Read_Busy (D, Busy);
   end Is_Busy;

   procedure Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte) is
   begin
      Poll_Busy (D);
      Bus_Write_Command (D, Command, Value);
   end Write_Command;

   procedure Write_Command_Burst (D : in out Radio_Device; Command : Byte; Data : Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length) := (others => 0);
   begin
      Buffer (0) := Command;
      Buffer (1 .. Data'Length) := Data;
      Poll_Busy (D);
      Bus_Write (D, Buffer);
   end Write_Command_Burst;

   procedure Read_Command_Burst (D : in out Radio_Device; Command : Byte; Data : in out Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length + 1) := (others => 0);
   begin
      Buffer (0) := Command;
      Buffer (2 .. Data'Length + 1) := Data;
      Poll_Busy (D);
      Bus_Transfer (D, Buffer);
      Data := Buffer (2 .. Data'Length + 1);
   end Read_Command_Burst;

   procedure Write_Register_Burst (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Data : Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length + 2) := (others => 0);
   begin
      Buffer (0) := Cmd_Write_Register;
      Buffer (1) := Byte (Address / 256);
      Buffer (2) := Byte (Address mod 256);
      Buffer (3 .. Data'Length + 2) := Data;
      Poll_Busy (D);
      Bus_Write (D, Buffer);
   end Write_Register_Burst;

   procedure Write_Register (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Value : Byte) is
   begin
      Write_Register_Burst (D, Address, (0 => Value));
   end Write_Register;

   procedure Read_Register_Burst (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Data : out Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length + 3) := (others => 0);
   begin
      Buffer (0) := Cmd_Read_Register;
      Buffer (1) := Byte (Address / 256);
      Buffer (2) := Byte (Address mod 256);
      Poll_Busy (D);
      Bus_Transfer (D, Buffer);
      Data := Buffer (4 .. Data'Length + 3);
   end Read_Register_Burst;

   procedure Read_Register (D : in out Radio_Device; Address : Interfaces.Unsigned_16; Value : out Byte) is
      Rx : Byte_Array (0 .. 0);
   begin
      Read_Register_Burst (D, Address, Rx);
      Value := Rx (0);
   end Read_Register;

   procedure Write_Buffer (D : in out Radio_Device; Offset : Byte; Data : Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length + 1) := (others => 0);
   begin
      Buffer (0) := Cmd_Write_Buffer;
      Buffer (1) := Offset;
      Buffer (2 .. Data'Length + 1) := Data;
      Poll_Busy (D);
      Bus_Write (D, Buffer);
   end Write_Buffer;

   procedure Read_Buffer (D : in out Radio_Device; Offset : Byte; Data : out Byte_Array) is
      Buffer : Byte_Array (0 .. Data'Length + 2) := (others => 0);
   begin
      Buffer (0) := Cmd_Read_Buffer;
      Buffer (1) := Offset;
      Poll_Busy (D);
      Bus_Transfer (D, Buffer);
      Data := Buffer (3 .. Data'Length + 2);
   end Read_Buffer;

   procedure Get_Status (D : in out Radio_Device; Status : out Byte) is
      Buffer : Byte_Array (0 .. 2) := (Cmd_Get_Status, 0, 0);
   begin
      Poll_Busy (D);
      Bus_Transfer (D, Buffer);
      Status := Buffer (0);
   end Get_Status;

   procedure Config_Mod_Params_LoRa (D : in out Radio_Device; Bandwidth : Byte; Spreading : Byte; Coding : Byte) is
   begin
      Write_Command_Burst (D, Cmd_Set_Modulation_Params, (Spreading, Bandwidth, Coding));
      case Spreading is
         when LoRa_SF5 | LoRa_SF6 =>
            Write_Register (D, Reg_SF_Additional, 16#1E#);
         when LoRa_SF7 | LoRa_SF8 =>
            Write_Register (D, Reg_SF_Additional, 16#37#);
         when others =>
            Write_Register (D, Reg_SF_Additional, 16#32#);
      end case;
   end Config_Mod_Params_LoRa;

   procedure Set_Packet_Params_LoRa
     (D : in out Radio_Device; Preamble_Length : Byte; Header_Type : Byte; Payload_Length : Byte; CRC : Byte;
      Invert_IQ : Boolean)
   is
   begin
      Write_Command_Burst
        (D, Cmd_Set_Packet_Params,
         (Preamble_Length, Header_Type, Payload_Length, CRC, (if Invert_IQ then LoRa_IQ_Inverted else LoRa_IQ_Normal),
          0, 0));
   end Set_Packet_Params_LoRa;

   procedure Config_Mod_Params_FLRC (D : in out Radio_Device; Bandwidth : Byte; Coding : Byte; Filter : Byte) is
   begin
      Write_Command_Burst (D, Cmd_Set_Modulation_Params, (Bandwidth, Coding, Filter));
   end Config_Mod_Params_FLRC;

   procedure Set_Packet_Params_FLRC
     (D : in out Radio_Device; Preamble_Length : Byte; Header_Type : Byte; Payload_Length : Byte;
      Sync_Word : Interfaces.Unsigned_32; CRC_Seed : Interfaces.Unsigned_16; Coding : Byte)
   is
      Preamble : constant Byte := (if Preamble_Length < 8 then 8 else Preamble_Length);
      Sync     : Byte_Array (0 .. 3) :=
        (Byte (Sync_Word / 2 ** 24), Byte (Sync_Word / 2 ** 16 mod 256), Byte (Sync_Word / 2 ** 8 mod 256),
         Byte (Sync_Word mod 256));
      Swap     : Byte;
      Control  : Byte;
   begin
      Write_Command_Burst
        (D, Cmd_Set_Packet_Params,
         ((Preamble / 4 - 1) * 16, FLRC_Sync_Word_P32S, FLRC_Match_Sync_1, Header_Type, Payload_Length,
          FLRC_CRC_3_Byte, FLRC_Whitening_Off));
      Write_Register_Burst (D, Reg_FLRC_CRC_Seed, (Byte (CRC_Seed / 256), Byte (CRC_Seed mod 256)));
      if (Coding = FLRC_CR_1_2 or else Coding = FLRC_CR_3_4)
        and then ((Sync (0) = 16#8C# and then Sync (1) = 16#38#) or else (Sync (0) = 16#63# and then Sync (1) = 16#0E#))
      then
         Swap := Sync (0);
         Sync (0) := Sync (1);
         Sync (1) := Swap;
         if Coding = FLRC_CR_3_4 and then Sync (3) <= 16#3E# then
            Sync (3) := Sync (3) or 16#80#;
         end if;
      end if;
      Write_Register_Burst (D, Reg_FLRC_Sync_Word, Sync);
      Read_Register (D, Reg_FLRC_Sync_Addr_Ctrl, Control);
      Write_Register (D, Reg_FLRC_Sync_Addr_Ctrl, Control and 16#F0#);
   end Set_Packet_Params_FLRC;

   procedure Set_Output_Power (D : in out Radio_Device; Power : Interfaces.Integer_8) is
   begin
      Write_Command_Burst (D, Cmd_Set_TX_Params, (Byte'Mod (Integer (Power) + 18), Ramp_04_Us));
   end Set_Output_Power;

   procedure Set_Mode (D : in out Radio_Device; Mode : Operating_Mode) is
   begin
      case Mode is
         when Sleep =>
            Write_Command (D, Cmd_Set_Sleep, 1);
         when Calibration | CAD =>
            null;
         when Standby_RC =>
            Write_Command (D, Cmd_Set_Standby, Standby_RC_Value);
         when Standby_XOSC =>
            Write_Command (D, Cmd_Set_Standby, Standby_XOSC_Value);
         when Frequency_Synthesis =>
            Write_Command (D, Cmd_Set_FS, 0);
         when Receive =>
            Write_Command_Burst (D, Cmd_Set_RX, (0, 16#FF#, 16#FF#));
         when Transmit =>
            Write_Command_Burst (D, Cmd_Set_TX, (0, 16#FF#, 16#FF#));
      end case;
   end Set_Mode;

   procedure Set_Frequency_Reg (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32) is
   begin
      Write_Command_Burst
        (D, Cmd_Set_RF_Frequency,
         (Byte (Frequency / 2 ** 16 mod 256), Byte (Frequency / 2 ** 8 mod 256), Byte (Frequency mod 256)));
   end Set_Frequency_Reg;

   procedure Set_FIFO_Addr (D : in out Radio_Device; TX_Base : Byte; RX_Base : Byte) is
   begin
      Write_Command_Burst (D, Cmd_Set_Buffer_Base, (TX_Base, RX_Base));
   end Set_FIFO_Addr;

   procedure Set_DIO_IRQ_Params
     (D         : in out Radio_Device;
      Irq_Mask  : Interfaces.Unsigned_16;
      DIO1_Mask : Interfaces.Unsigned_16;
      DIO2_Mask : Interfaces.Unsigned_16;
      DIO3_Mask : Interfaces.Unsigned_16)
   is
   begin
      Write_Command_Burst
        (D, Cmd_Set_DIO_IRQ_Params,
         (Byte (Irq_Mask / 256), Byte (Irq_Mask mod 256), Byte (DIO1_Mask / 256), Byte (DIO1_Mask mod 256),
          Byte (DIO2_Mask / 256), Byte (DIO2_Mask mod 256), Byte (DIO3_Mask / 256), Byte (DIO3_Mask mod 256)));
   end Set_DIO_IRQ_Params;

   procedure Config
     (D               : in out Radio_Device;
      S               : in out Radio;
      Bandwidth       : Byte;
      Spreading       : Byte;
      Coding          : Byte;
      Frequency       : Interfaces.Unsigned_32;
      Preamble_Length : Byte;
      IQ_Inverted     : Boolean;
      FLRC_Sync_Word  : Interfaces.Unsigned_32;
      FLRC_CRC_Seed   : Interfaces.Unsigned_16;
      Is_FLRC         : Boolean)
   is
   begin
      Set_Mode (D, Standby_RC);
      S.FLRC := Is_FLRC;
      Write_Command (D, Cmd_Set_Packet_Type, (if Is_FLRC then Packet_Type_FLRC else Packet_Type_LoRa));
      if Is_FLRC then
         Config_Mod_Params_FLRC (D, Bandwidth, Coding, Spreading);
         Set_Packet_Params_FLRC
           (D, Preamble_Length, FLRC_Packet_Fixed, Packet_Bytes, FLRC_Sync_Word, FLRC_CRC_Seed, Coding);
      else
         Config_Mod_Params_LoRa (D, Bandwidth, Spreading, Coding);
         Set_Packet_Params_LoRa (D, Preamble_Length, LoRa_Packet_Fixed, Packet_Bytes, LoRa_CRC_Off, IQ_Inverted);
      end if;
      Set_DIO_IRQ_Params
        (D, Irq_TX_Done or Irq_RX_Done or Irq_Syncword_Valid or Irq_Syncword_Error or Irq_CRC_Error,
         Irq_TX_Done or Irq_RX_Done, 0, 0);
      Set_Output_Power (D, Default_Power);
      Set_Frequency_Reg (D, Frequency);
   end Config;

   procedure Transmit_Data (D : in out Radio_Device; Data : Byte_Array) is
   begin
      Write_Buffer (D, 0, Data);
      Set_Mode (D, Transmit);
   end Transmit_Data;

   procedure Receive_Data (D : in out Radio_Device; Data : out Byte_Array) is
      Status : Byte_Array (0 .. 1) := (0, 0);
   begin
      Read_Command_Burst (D, Cmd_Get_RX_Buffer_Status, Status);
      Read_Buffer (D, Status (1), Data);
   end Receive_Data;

   procedure Start_Receiving (D : in out Radio_Device; S : in out Radio) is
      Claimed : Boolean;
   begin
      Mark_Busy (D, S, Claimed);
      if Claimed then
         Set_Mode (D, Receive);
         S.Processing := 0;
      end if;
   end Start_Receiving;

   function To_Signed (V : Byte) return Interfaces.Integer_8 is
     (if V >= 128 then Interfaces.Integer_8 (Integer (V) - 256) else Interfaces.Integer_8 (V));

   procedure Get_Last_Packet_Stats (S : Radio; RSSI : out Interfaces.Integer_8; SNR : out Interfaces.Integer_8) is
      Sum : Integer;
   begin
      if S.FLRC then
         RSSI := -Interfaces.Integer_8 (S.Packet_Stats (1) / 2);
         SNR := 0;
      else
         RSSI := -Interfaces.Integer_8 (S.Packet_Stats (0) / 2);
         SNR := To_Signed (S.Packet_Stats (1));
         Sum := Integer (RSSI) + (if SNR < 0 then Integer (SNR / 4) else 0);
         if Sum < -128 then
            Sum := Sum + 256;
         end if;
         RSSI := Interfaces.Integer_8 (Sum);
      end if;
   end Get_Last_Packet_Stats;

   procedure Clear_Irq_Status (D : in out Radio_Device; Irq_Mask : Interfaces.Unsigned_16) is
   begin
      Write_Command_Burst (D, Cmd_Clear_IRQ_Status, (Byte (Irq_Mask / 256), Byte (Irq_Mask mod 256)));
   end Clear_Irq_Status;

   procedure Enable_IRQs (D : in out Radio_Device; S : in out Radio; Next : out Step) is
   begin
      if S.Pending_Hop then
         Next := Set_Frequency;
      else
         Enable_Exti (D, S);
         Next := No_Step;
      end if;
   end Enable_IRQs;

   procedure Set_Freq_Complete (D : in out Radio_Device; Next : out Step) is
      Requested : Boolean;
   begin
      Telemetry_Requested (D, Requested);
      if Requested then
         Do_Telemetry (D);
         Next := Send_Telemetry;
      else
         Next := Start_Receiving_DMA;
      end if;
   end Set_Freq_Complete;

   procedure Run_Step (D : in out Radio_Device; S : in out Radio; Current : Step; Next : out Step) is
      Four      : Byte_Array (0 .. 3);
      Telemetry : Packet;
      Status    : Interfaces.Unsigned_16;
      Result    : Byte;
      Time      : Interfaces.Unsigned_32;
      Frequency : Interfaces.Unsigned_32;
      Requested : Boolean;
   begin
      case Current is
         when Irq_Get_Status =>
            Clear_Busy_Fn (D, S);
            Four := (Cmd_Get_IRQ_Status, 0, 0, 0);
            Run_Transfer (D, Step'Pos (Current), Four);
            Status := Interfaces.Unsigned_16 (Four (2)) * 256 + Interfaces.Unsigned_16 (Four (3));
            if (Status and Irq_TX_Done) /= 0 then
               S.Irq_Reason := Reason_TX_Done;
            elsif (Status and Irq_RX_Done) /= 0 then
               S.Irq_Reason := Reason_RX_Done;
               if S.FLRC
                 and then ((Status and (Irq_CRC_Error or Irq_Syncword_Error)) /= 0
                           or else (Status and Irq_Syncword_Valid) = 0)
               then
                  S.Irq_Reason := S.Irq_Reason or Reason_HW_Error;
               end if;
            else
               S.Irq_Reason := Reason_Unknown;
            end if;
            Next := Irq_Clear_Status;
         when Irq_Clear_Status =>
            Clear_Busy_Fn (D, S);
            Run_Write (D, Step'Pos (Current), (Cmd_Clear_IRQ_Status, 16#FF#, 16#FF#));
            Next := (if (S.Irq_Reason and Reason_HW_Error) = 0 then Process_Irq else No_Step);
         when Process_Irq =>
            Clear_Busy_Fn (D, S);
            if (S.Irq_Reason and Reason_RX_Done) /= 0 then
               Four := (Cmd_Get_RX_Buffer_Status, 0, 0, 0);
               Run_Transfer (D, Step'Pos (Current), Four);
               S.FIFO_Addr := Four (3);
               Next := Do_Read_Buffer;
            else
               Run_Write (D, Step'Pos (Current), (Cmd_Set_RX, 0, 16#FF#, 16#FF#));
               Enable_IRQs (D, S, Next);
            end if;
         when Do_Read_Buffer =>
            Clear_Busy_Fn (D, S);
            Run_Pair (D, Step'Pos (Current), (Cmd_Read_Buffer, S.FIFO_Addr, 0), S.Rx_Buffer);
            Next := Get_Packet_Stats;
         when Get_Packet_Stats =>
            Clear_Busy_Fn (D, S);
            Four := (Cmd_Get_Packet_Status, 0, 0, 0);
            Run_Transfer (D, Step'Pos (Current), Four);
            S.Packet_Stats := (Four (2), Four (3));
            Last_Exti_Time (D, Time);
            Process_Packet (D, S.Rx_Buffer, Time, Result);
            Set_Packet_Status (D, Result);
            Hop_Requested (D, Requested);
            if Requested then
               S.Pending_Hop := True;
               Next := Set_Frequency;
            else
               Set_Freq_Complete (D, Next);
            end if;
         when Set_Frequency =>
            Current_Frequency (D, Frequency);
            Clear_Busy_Fn (D, S);
            Run_Write
              (D, Step'Pos (Current),
               (Cmd_Set_RF_Frequency, Byte (Frequency / 2 ** 16 mod 256), Byte (Frequency / 2 ** 8 mod 256),
                Byte (Frequency mod 256)));
            S.Pending_Hop := False;
            Set_Freq_Complete (D, Next);
         when Start_Receiving_DMA =>
            Clear_Busy_Fn (D, S);
            Run_Write (D, Step'Pos (Current), (Cmd_Set_RX, 0, 16#FF#, 16#FF#));
            Enable_IRQs (D, S, Next);
         when Send_Telemetry =>
            Clear_Busy_Fn (D, S);
            Telemetry_Buffer (D, Telemetry);
            Run_Pair_Write (D, Step'Pos (Current), (Cmd_Write_Buffer, 0), Telemetry);
            Next := Start_Transmitting_DMA;
         when Start_Transmitting_DMA =>
            Clear_Busy_Fn (D, S);
            Run_Write (D, Step'Pos (Current), (Cmd_Set_TX, 0, 16#FF#, 16#FF#));
            Enable_IRQs (D, S, Next);
         when No_Step =>
            Next := No_Step;
      end case;
   end Run_Step;

   --  The chain from First: each step waits for the busy pin, low now or
   --  falling later, when Gated.
   procedure Run_Chain (D : in out Radio_Device; S : in out Radio; First : Step; Gated : Boolean) is
      Current : Step := First;
      Next    : Step;
      Busy    : Boolean;
      Gate    : Boolean := Gated;
   begin
      for Pass in 1 .. Max_Chain loop
         if Gate then
            Read_Busy (D, Busy);
            if Busy then
               Busy_Exti_Arm (D);
               S.Waiting := Current;
               exit;
            end if;
            Busy_Exti_Disable (D);
         end if;
         Gate := True;
         Run_Step (D, S, Current, Next);
         exit when Next = No_Step;
         Current := Next;
      end loop;
   end Run_Chain;

   procedure Init (D : in out Radio_Device; Has_Reset_Pin : Boolean; Has_Busy_Pin : Boolean; OK : out Boolean) is
      Configured : Boolean;
      High       : Byte;
      Low        : Byte;
      Gain       : Byte;
      Revision   : Interfaces.Unsigned_16;
   begin
      Exti_Configured (D, Configured);
      if not Configured then
         OK := False;
         return;
      end if;
      Set_Normal_Speed (D, Normal_Speed_Hz);
      if Has_Reset_Pin then
         Init_Reset_Pin (D);
      end if;
      if Has_Busy_Pin then
         Init_Busy_Pin (D);
      end if;
      if Has_Reset_Pin then
         Reset_Low (D);
      end if;
      Delay_Ms (D, Reset_Low_Ms);
      if Has_Reset_Pin then
         Reset_Float (D);
      end if;
      Delay_Ms (D, Reset_Settle_Ms);
      Read_Register (D, Reg_Firmware_Version, High);
      Read_Register (D, Reg_Firmware_Version + 1, Low);
      Revision := Interfaces.Unsigned_16 (High) * 256 + Interfaces.Unsigned_16 (Low);
      if Revision = 0 or else Revision = 65535 then
         OK := False;
         return;
      end if;
      Set_Mode (D, Standby_RC);
      Write_Command (D, Cmd_Set_Auto_FS, 1);
      Read_Register (D, Reg_RX_Gain_Regime, Gain);
      Write_Register (D, Reg_RX_Gain_Regime, Gain or 16#C0#);
      OK := True;
   end Init;

   procedure ISR (D : in out Radio_Device; S : in out Radio) is
      Claimed : Boolean;
   begin
      Enable_Busy (D, S, Claimed);
      if Claimed then
         Run_Chain (D, S, Irq_Get_Status, True);
      end if;
   end ISR;

   procedure Busy_Fell (D : in out Radio_Device; S : in out Radio) is
      Waiting : constant Step := S.Waiting;
   begin
      if Waiting /= No_Step then
         S.Waiting := No_Step;
         Run_Chain (D, S, Waiting, False);
      end if;
   end Busy_Fell;

   procedure Handle_From_Tick (D : in out Radio_Device; S : in out Radio; Handled : out Boolean) is
      Now : Interfaces.Unsigned_32;
   begin
      Handled := False;
      if S.Processing /= 0 then
         Micros (D, Now);
         if Now - S.Processing in Busy_Timeout_Us + 1 .. 2 ** 31 - 1 then
            Clear_Busy_Fn (D, S);
            Enable_Exti (D, S);
            Handled := True;
         end if;
      end if;
   end Handle_From_Tick;

   procedure Handle_From_Tock (D : in out Radio_Device; S : in out Radio) is
      Due     : Boolean;
      Claimed : Boolean;
   begin
      Hop_Requested (D, Due);
      if Due or else S.Pending_Hop then
         S.Pending_Hop := True;
         Enable_Busy (D, S, Claimed);
         if Claimed then
            Run_Chain (D, S, Set_Frequency, True);
         end if;
      end if;
   end Handle_From_Tock;

end Adaflight.SX1280;
