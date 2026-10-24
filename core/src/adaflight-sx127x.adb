package body Adaflight.SX127x with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_8;
   use type Interfaces.Integer_64;

   Reg_FIFO             : constant Byte := 16#00#;
   Reg_Op_Mode          : constant Byte := 16#01#;
   Reg_FRF_MSB          : constant Byte := 16#06#;
   Reg_PA_Config        : constant Byte := 16#09#;
   Reg_OCP              : constant Byte := 16#0B#;
   Reg_LNA              : constant Byte := 16#0C#;
   Reg_FIFO_Addr_Ptr    : constant Byte := 16#0D#;
   Reg_FIFO_TX_Base     : constant Byte := 16#0E#;
   Reg_FIFO_RX_Base     : constant Byte := 16#0F#;
   Reg_Irq_Flags        : constant Byte := 16#12#;
   Reg_Packet_SNR       : constant Byte := 16#19#;
   Reg_Packet_RSSI      : constant Byte := 16#1A#;
   Reg_RSSI             : constant Byte := 16#1B#;
   Reg_Modem_Config_1   : constant Byte := 16#1D#;
   Reg_Modem_Config_2   : constant Byte := 16#1E#;
   Reg_Preamble_LSB     : constant Byte := 16#21#;
   Reg_Payload_Length   : constant Byte := 16#22#;
   Reg_Modem_Config_3   : constant Byte := 16#26#;
   Reg_PPM_Offset       : constant Byte := 16#27#;
   Reg_FEI_MSB          : constant Byte := 16#28#;
   Reg_Detect_Optimize  : constant Byte := 16#31#;
   Reg_Invert_IQ        : constant Byte := 16#33#;
   Reg_Errata_36        : constant Byte := 16#36#;
   Reg_Detection_Thresh : constant Byte := 16#37#;
   Reg_Sync_Word        : constant Byte := 16#39#;
   Reg_Errata_3A        : constant Byte := 16#3A#;
   Reg_DIO_Mapping_1    : constant Byte := 16#40#;
   Reg_Version          : constant Byte := 16#42#;

   Write_Bit                : constant Byte := 16#80#;
   LoRa_Mode                : constant Byte := 16#80#;
   Op_Mode_Sleep            : constant Byte := 16#00#;
   Chip_Version             : constant Byte := 16#12#;
   PA_Select_Boost          : constant Byte := 16#80#;
   Max_Output_Power         : constant Byte := 16#70#;
   TX_Mode_Single           : constant Byte := 16#00#;
   Detect_Optimize_SF6      : constant Byte := 16#05#;
   Detect_Optimize_SF7_12   : constant Byte := 16#03#;
   Detection_Thresh_SF6     : constant Byte := 16#0C#;
   Detection_Thresh_SF7_12  : constant Byte := 16#0A#;
   Header_Explicit          : constant Byte := 16#00#;
   Header_Implicit          : constant Byte := 16#01#;
   CRC_Mode_Off             : constant Byte := 16#00#;
   CRC_Mode_On              : constant Byte := 16#04#;
   Spreading_Factor_6       : constant Byte := 16#60#;
   Bandwidth_500            : constant Byte := 16#90#;
   LNA_Boost_On             : constant Byte := 16#03#;
   AGC_Auto_On              : constant Byte := 16#04#;
   Low_Data_Rate_Opt_Off    : constant Byte := 16#00#;
   OCP_On                   : constant Byte := 16#20#;
   OCP_150mA                : constant Byte := 16#12#;
   Preamble_Length_Default  : constant Byte := 16#08#;
   Default_Sync_Word        : constant Byte := 16#12#;
   DIO0_Both_Done           : constant Byte := 16#C0#;
   Irq_RX_Done              : constant Byte := 16#40#;
   Irq_TX_Done              : constant Byte := 16#08#;
   Payload_Bytes            : constant Byte := 8;
   Reset_Low_Ms             : constant := 50;
   Detect_Retry_Ms          : constant := 50;
   Detect_Attempts          : constant := 3;
   RSSI_Offset              : constant := 157;
   --  The frequency step of 61.03515625 Hz as 15625 over 256.
   Step_Numerator           : constant := 15625;
   Step_Denominator         : constant := 256;

   Allowed_Sync_Words : constant Byte_Array (0 .. 104) :=
     (0, 5, 6, 7, 11, 12, 13, 15, 18, 21, 23, 26, 29, 30, 31, 33, 34, 37, 38, 39, 40, 42, 44, 50, 51, 54, 55, 57, 58,
      59, 61, 63, 65, 67, 68, 71, 77, 78, 79, 80, 82, 84, 86, 89, 92, 94, 96, 97, 99, 101, 102, 105, 106, 109, 111,
      113, 115, 117, 118, 119, 121, 122, 124, 126, 127, 129, 130, 138, 143, 161, 170, 172, 173, 175, 180, 181, 182,
      187, 190, 191, 192, 193, 196, 199, 201, 204, 205, 208, 209, 212, 213, 219, 220, 221, 223, 227, 229, 235, 239,
      240, 242, 243, 246, 247, 255);

   function To_Signed (V : Byte) return Interfaces.Integer_8 is
     (if V < 128 then Interfaces.Integer_8 (V) else Interfaces.Integer_8 (Integer (V) - 256));

   function To_Signed_32 (V : Interfaces.Unsigned_32) return Interfaces.Integer_32 is
     (if V < 2 ** 31 then Interfaces.Integer_32 (V)
      else Interfaces.Integer_32 (Interfaces.Integer_64 (V) - 2 ** 32));

   function To_Unsigned_32 (V : Interfaces.Integer_32) return Interfaces.Unsigned_32 is
     (if V >= 0 then Interfaces.Unsigned_32 (V)
      else Interfaces.Unsigned_32 (Interfaces.Integer_64 (V) + 2 ** 32));

   function Sync_Word_Allowed (Word : Byte) return Boolean is
     (for some I in Allowed_Sync_Words'Range => Allowed_Sync_Words (I) = Word);

   function Bit_Range_Invalid (Msb : Byte; Lsb : Byte) return Boolean is (Msb > 7 or else Lsb > 7 or else Lsb > Msb);

   procedure Write_Register (D : in out Radio_Device; Address : Byte; Value : Byte) is
   begin
      Bus_Write_Command (D, Address or Write_Bit, Value);
   end Write_Register;

   procedure Write_Register_Burst (D : in out Radio_Device; Address : Byte; Data : Byte_Array) is
   begin
      Bus_Write_Command_Multi (D, Address or Write_Bit, Data);
   end Write_Register_Burst;

   procedure Read_Register (D : in out Radio_Device; Address : Byte; Value : out Byte) is
   begin
      Bus_Read_Command (D, Address, Value);
   end Read_Register;

   procedure Read_Register_Burst (D : in out Radio_Device; Address : Byte; Data : out Byte_Array) is
   begin
      Bus_Read_Command_Multi (D, Address, Data);
   end Read_Register_Burst;

   procedure Get_Register_Value (D : in out Radio_Device; Address : Byte; Msb : Byte; Lsb : Byte; Value : out Byte) is
      Raw : Byte;
   begin
      if Bit_Range_Invalid (Msb, Lsb) then
         Value := Invalid_Bit_Range;
         return;
      end if;
      Read_Register (D, Address, Raw);
      Value :=
        Raw and Byte'Mod (Interfaces.Shift_Left (Interfaces.Unsigned_32'(16#FF#), Natural (Lsb))
                          and Interfaces.Shift_Right (Interfaces.Unsigned_32'(16#FF#), 7 - Natural (Msb)));
   end Get_Register_Value;

   procedure Set_Register_Value
     (D : in out Radio_Device; Address : Byte; Value : Byte; Msb : Byte; Lsb : Byte; Status : out Byte)
   is
      Current : Byte;
      Mask    : Byte;
   begin
      if Bit_Range_Invalid (Msb, Lsb) then
         Status := Invalid_Bit_Range;
         return;
      end if;
      Read_Register (D, Address, Current);
      Mask :=
        Byte'Mod (not (Interfaces.Shift_Left (Interfaces.Unsigned_32'(16#FF#), Natural (Msb) + 1)
                       or Interfaces.Shift_Right (Interfaces.Unsigned_32'(16#FF#), 8 - Natural (Lsb))));
      Write_Register (D, Address, (Current and not Mask) or (Value and Mask));
      Status := No_Error;
   end Set_Register_Value;

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array) is
   begin
      Read_Register_Burst (D, Reg_FIFO, Data);
   end Read_FIFO;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array) is
   begin
      Write_Register_Burst (D, Reg_FIFO, Data);
   end Write_FIFO;

   procedure Set_Bandwidth_Coding_Rate
     (D               : in out Radio_Device;
      Bandwidth       : Byte;
      Coding          : Byte;
      Spreading       : Byte;
      Explicit_Header : Boolean;
      CRC_Enabled     : Boolean)
   is
      Header        : constant Byte := (if Explicit_Header then Header_Explicit else Header_Implicit);
      Unused_Status : Byte;
   begin
      if Spreading = Spreading_Factor_6 then
         Write_Register (D, Reg_Modem_Config_1, Bandwidth or Coding or Header_Implicit);
         Set_Register_Value (D, Reg_Modem_Config_2, CRC_Mode_Off, 2, 2, Unused_Status);
      else
         Write_Register (D, Reg_Modem_Config_1, Bandwidth or Coding or Header);
         Set_Register_Value
           (D, Reg_Modem_Config_2, (if CRC_Enabled then CRC_Mode_On else CRC_Mode_Off), 2, 2, Unused_Status);
      end if;
      if Bandwidth = Bandwidth_500 then
         Write_Register (D, Reg_Errata_36, 16#02#);
         Write_Register (D, Reg_Errata_3A, 16#64#);
      else
         Write_Register (D, Reg_Errata_36, 16#03#);
      end if;
   end Set_Bandwidth_Coding_Rate;

   procedure Set_Sync_Word (D : in out Radio_Device; Sync_Word : Byte) is
      Word : Byte := Sync_Word;
   begin
      for Attempt in 1 .. 256 loop
         exit when Sync_Word_Allowed (Word);
         Word := Word + 1;
      end loop;
      Write_Register (D, Reg_Sync_Word, Word);
   end Set_Sync_Word;

   procedure Set_Mode (D : in out Radio_Device; Mode : Operating_Mode) is
   begin
      Write_Register (D, LoRa_Mode or Reg_Op_Mode, Byte (Operating_Mode'Pos (Mode)));
   end Set_Mode;

   procedure Set_Output_Power (D : in out Radio_Device; Power : Byte) is
   begin
      Set_Mode (D, Standby);
      Write_Register (D, Reg_PA_Config, PA_Select_Boost or Max_Output_Power or Power);
   end Set_Output_Power;

   procedure Set_Preamble_Length (D : in out Radio_Device; Length : Byte) is
   begin
      Write_Register (D, Reg_Preamble_LSB, Length);
   end Set_Preamble_Length;

   procedure Set_Spreading_Factor (D : in out Radio_Device; Spreading : Byte) is
      Unused_Status : Byte;
   begin
      Set_Register_Value (D, Reg_Modem_Config_2, Spreading or TX_Mode_Single, 7, 3, Unused_Status);
      if Spreading = Spreading_Factor_6 then
         Set_Register_Value (D, Reg_Detect_Optimize, Detect_Optimize_SF6, 2, 0, Unused_Status);
         Write_Register (D, Reg_Detection_Thresh, Detection_Thresh_SF6);
      else
         Set_Register_Value (D, Reg_Detect_Optimize, Detect_Optimize_SF7_12, 2, 0, Unused_Status);
         Write_Register (D, Reg_Detection_Thresh, Detection_Thresh_SF7_12);
      end if;
   end Set_Spreading_Factor;

   procedure Set_Frequency_Hz (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_64;
      Steps : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Interfaces.Unsigned_64 (Frequency) * Step_Denominator / Step_Numerator);
   begin
      Set_Mode (D, Standby);
      Write_Register_Burst
        (D, Reg_FRF_MSB, (Byte (Steps / 2 ** 16 mod 256), Byte (Steps / 256 mod 256), Byte (Steps mod 256)));
   end Set_Frequency_Hz;

   procedure Set_Frequency_Reg (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32) is
   begin
      Set_Mode (D, Standby);
      Write_Register_Burst
        (D, Reg_FRF_MSB,
         (Byte (Frequency / 2 ** 16 mod 256), Byte (Frequency / 256 mod 256), Byte (Frequency mod 256)));
   end Set_Frequency_Reg;

   procedure Transmit_Data (D : in out Radio_Device; Data : Byte_Array) is
   begin
      Set_Mode (D, Standby);
      Write_Register (D, Reg_FIFO_Addr_Ptr, 0);
      Write_FIFO (D, Data);
      Set_Mode (D, Transmit);
   end Transmit_Data;

   procedure Receive_Data (D : in out Radio_Device; Data : out Byte_Array) is
   begin
      Read_FIFO (D, Data);
   end Receive_Data;

   procedure Start_Receiving (D : in out Radio_Device) is
   begin
      Set_Mode (D, Standby);
      Write_Register (D, Reg_FIFO_Addr_Ptr, 0);
      Set_Mode (D, Receive_Continuous);
   end Start_Receiving;

   procedure Config
     (D               : in out Radio_Device;
      Bandwidth       : Byte;
      Spreading       : Byte;
      Coding          : Byte;
      Frequency       : Interfaces.Unsigned_32;
      Preamble_Length : Byte;
      IQ_Inverted     : Boolean) is
   begin
      Config_LoRa_Defaults (D, IQ_Inverted);
      Set_Preamble_Length (D, Preamble_Length);
      Set_Output_Power (D, Max_Power);
      Set_Spreading_Factor (D, Spreading);
      Set_Bandwidth_Coding_Rate (D, Bandwidth, Coding, Spreading, False, False);
      Set_Frequency_Reg (D, Frequency);
   end Config;

   function Current_Bandwidth (Bandwidth : Byte) return Interfaces.Unsigned_32 is
     (case Bandwidth is
         when 16#00# => 7_800,
         when 16#10# => 10_400,
         when 16#20# => 15_600,
         when 16#30# => 20_800,
         when 16#40# => 31_250,
         when 16#50# => 41_700,
         when 16#60# => 62_500,
         when 16#70# => 125_000,
         when 16#80# => 250_000,
         when 16#90# => 500_000,
         when others => Interfaces.Unsigned_32'Last);

   function Bandwidth_Normalised_Shifted (Bandwidth : Byte) return Interfaces.Unsigned_32 is
     (case Bandwidth is
         when 16#00# => 1026,
         when 16#10# => 769,
         when 16#20# => 513,
         when 16#30# => 385,
         when 16#40# => 256,
         when 16#50# => 192,
         when 16#60# => 128,
         when 16#70# => 64,
         when 16#80# => 32,
         when 16#90# => 16,
         when others => Interfaces.Unsigned_32'Last);

   --  The offset register's byte: the scaled offset truncated and wrapped.
   function PPM_Register (PPM : Long_Float) return Byte
     with Global => null, Pre => PPM >= -1.6e9 and then PPM <= 1.6e9;

   function PPM_Register (PPM : Long_Float) return Byte is (Byte'Mod (Integer (Long_Float'Truncation (PPM))));

   procedure Set_PPM_Offset (D : in out Radio_Device; Offset : Correction; Frequency : Interfaces.Unsigned_32) is
      Scale  : constant Long_Float := Long_Float (Frequency);
      Scaled : constant Long_Float := Long_Float (Offset) * 1.0e6;
      Ratio  : constant Long_Float := Scaled / Scale;
      PPM    : constant Long_Float := Ratio * 95.0 / 100.0;
   begin
      pragma Assert (Scale >= 1.0);
      pragma Assert (Scaled >= -1.638e9 and then Scaled <= 1.638e9);
      pragma Assert (Ratio >= -1.638e9 and then Ratio <= 1.638e9);
      pragma Assert (PPM >= -1.6e9 and then PPM <= 1.6e9);
      Write_Register (D, Reg_PPM_Offset, PPM_Register (PPM));
   end Set_PPM_Offset;

   procedure Get_Frequency_Error (D : in out Radio_Device; Bandwidth : Byte; Error : out Interfaces.Integer_32) is
      Regs    : Byte_Array (0 .. 2);
      Reg_FEI : Interfaces.Unsigned_32;
      Raw     : Interfaces.Integer_32;
      Product : Interfaces.Unsigned_32;
   begin
      Read_Register_Burst (D, Reg_FEI_MSB, Regs);
      Reg_FEI :=
        Interfaces.Unsigned_32 (Regs (0) and 16#07#) * 2 ** 16 + Interfaces.Unsigned_32 (Regs (1)) * 256
        + Interfaces.Unsigned_32 (Regs (2));
      Raw := Interfaces.Integer_32 (Reg_FEI);
      if (Regs (0) and 16#08#) /= 0 then
         Raw := Raw - 524_288;
      end if;
      Product :=
        Interfaces.Shift_Right_Arithmetic (To_Unsigned_32 (Raw), 3) * Bandwidth_Normalised_Shifted (Bandwidth);
      Error := To_Signed_32 (Interfaces.Shift_Right_Arithmetic (Product, 4));
   end Get_Frequency_Error;

   procedure Adjust_Frequency
     (D : in out Radio_Device; Offset : in out Correction; Frequency : Interfaces.Unsigned_32)
   is
      MSB : Byte;
   begin
      Read_Register (D, Reg_FEI_MSB, MSB);
      if (MSB and 16#08#) /= 0 then
         if Offset > Correction_Min then
            Offset := Offset - 1;
         else
            Offset := 0;
         end if;
      else
         if Offset < Correction_Max then
            Offset := Offset + 1;
         else
            Offset := 0;
         end if;
      end if;
      Set_PPM_Offset (D, Offset, Frequency);
   end Adjust_Frequency;

   procedure Unsigned_Last_Packet_RSSI (D : in out Radio_Device; Value : out Byte) is
   begin
      Get_Register_Value (D, Reg_Packet_RSSI, 7, 0, Value);
   end Unsigned_Last_Packet_RSSI;

   procedure Last_Packet_RSSI (D : in out Radio_Device; Value : out Interfaces.Integer_8) is
      Raw : Byte;
   begin
      Get_Register_Value (D, Reg_Packet_RSSI, 7, 0, Raw);
      Value := To_Signed (Byte'Mod (Integer (Raw) - RSSI_Offset));
   end Last_Packet_RSSI;

   procedure Current_RSSI (D : in out Radio_Device; Value : out Interfaces.Integer_8) is
      Raw : Byte;
   begin
      Get_Register_Value (D, Reg_RSSI, 7, 0, Raw);
      Value := To_Signed (Byte'Mod (Integer (Raw) - RSSI_Offset));
   end Current_RSSI;

   procedure Last_Packet_SNR_Raw (D : in out Radio_Device; Value : out Interfaces.Integer_8) is
      Raw : Byte;
   begin
      Get_Register_Value (D, Reg_Packet_SNR, 7, 0, Raw);
      Value := To_Signed (Raw);
   end Last_Packet_SNR_Raw;

   procedure Get_Irq_Flags (D : in out Radio_Device; Flags : out Byte) is
   begin
      Get_Register_Value (D, Reg_Irq_Flags, 7, 0, Flags);
   end Get_Irq_Flags;

   procedure Clear_Irq_Flags (D : in out Radio_Device) is
   begin
      Write_Register (D, Reg_Irq_Flags, 16#FF#);
   end Clear_Irq_Flags;

   procedure Get_Irq_Reason (D : in out Radio_Device; Reason : out Byte) is
      Flags : Byte;
   begin
      Get_Irq_Flags (D, Flags);
      Clear_Irq_Flags (D);
      if (Flags and Irq_TX_Done) /= 0 and then (Flags and Irq_RX_Done) /= 0 then
         Reason := 3;
      elsif (Flags and Irq_TX_Done) /= 0 then
         Reason := 2;
      elsif (Flags and Irq_RX_Done) /= 0 then
         Reason := 1;
      else
         Reason := 0;
      end if;
   end Get_Irq_Reason;

   procedure Get_Last_Packet_Stats
     (D : in out Radio_Device; RSSI : out Interfaces.Integer_8; SNR : out Interfaces.Integer_8) is
   begin
      Last_Packet_RSSI (D, RSSI);
      Last_Packet_SNR_Raw (D, SNR);
      if SNR < 0 then
         RSSI := To_Signed (Byte'Mod (Integer (RSSI) + Integer (SNR / 4)));
      end if;
   end Get_Last_Packet_Stats;

   procedure Config_LoRa_Defaults (D : in out Radio_Device; IQ_Inverted : Boolean) is
      Unused_Status : Byte;
   begin
      Write_Register (D, Reg_Op_Mode, Op_Mode_Sleep);
      Write_Register (D, Reg_Op_Mode, LoRa_Mode);
      Set_Mode (D, Standby);
      Clear_Irq_Flags (D);
      Write_Register (D, Reg_Payload_Length, Payload_Bytes);
      Set_Sync_Word (D, Default_Sync_Word);
      Write_Register (D, Reg_FIFO_TX_Base, 0);
      Write_Register (D, Reg_FIFO_RX_Base, 0);
      Set_Register_Value (D, Reg_DIO_Mapping_1, DIO0_Both_Done, 7, 6, Unused_Status);
      Write_Register (D, Reg_LNA, LNA_Boost_On);
      Write_Register (D, Reg_Modem_Config_3, AGC_Auto_On or Low_Data_Rate_Opt_Off);
      Set_Register_Value (D, Reg_OCP, OCP_On or OCP_150mA, 5, 0, Unused_Status);
      Set_Preamble_Length (D, Preamble_Length_Default);
      Set_Register_Value (D, Reg_Invert_IQ, (if IQ_Inverted then 1 else 0), 6, 6, Unused_Status);
   end Config_LoRa_Defaults;

   procedure Init (D : in out Radio_Device; Has_Reset_Pin : Boolean; OK : out Boolean) is
      Configured    : Boolean;
      Version       : Byte;
      Unused_Status : Byte;
   begin
      Exti_Configured (D, Configured);
      if not Configured then
         OK := False;
         return;
      end if;
      if Has_Reset_Pin then
         Init_Reset_Pin (D);
         Reset_Low (D);
      end if;
      Delay_Ms (D, Reset_Low_Ms);
      if Has_Reset_Pin then
         Reset_Float (D);
      end if;
      OK := False;
      for Attempt in 1 .. Detect_Attempts loop
         Read_Register (D, Reg_Version, Version);
         if Version = Chip_Version then
            OK := True;
            exit;
         end if;
         Delay_Ms (D, Detect_Retry_Ms);
      end loop;
      Set_Register_Value (D, Reg_Op_Mode, Op_Mode_Sleep, 2, 0, Unused_Status);
   end Init;

   procedure ISR (D : in out Radio_Device; Timestamp : in out Interfaces.Unsigned_32; Reason : out Byte) is
      Exti_Time : Interfaces.Unsigned_32;
   begin
      Last_Exti_Time (D, Exti_Time);
      Reset_Exti (D);
      Get_Irq_Reason (D, Reason);
      if Exti_Time /= 0 then
         Timestamp := Exti_Time;
      end if;
   end ISR;

end Adaflight.SX127x;
