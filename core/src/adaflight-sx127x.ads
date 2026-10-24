--  The SX127x radio of the ExpressLRS SPI receiver over the receiver's SPI
--  command helpers, which send a register address with the write bit set
--  for a write and clear for a read. Initialization needs the receiver's
--  interrupt pin, pulses the reset pin low for 50 ms and lets it float,
--  reads the version register up to three times 50 ms apart for the
--  chip's id, then puts the chip to sleep. The configuration sets the LoRa
--  defaults, the preamble length, the output power, the spreading factor
--  with its detection registers, the bandwidth, coding rate and CRC mode,
--  and the frequency. The interrupt handler reads and clears the interrupt
--  flags for its reason and takes the receiver's last interrupt time when
--  one is set. The frequency correction steps the offset against the sign
--  of the frequency error, back to zero at either bound, and writes it in
--  parts per million.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

generic
   type Radio_Device is limited private;
   with procedure Exti_Configured (D : in out Radio_Device; Configured : out Boolean);
   with procedure Init_Reset_Pin (D : in out Radio_Device);
   with procedure Reset_Low (D : in out Radio_Device);
   with procedure Reset_Float (D : in out Radio_Device);
   with procedure Delay_Ms (D : in out Radio_Device; Ms : Natural);
   --  The receiver's interrupt cleared, and the time of its last one.
   with procedure Reset_Exti (D : in out Radio_Device);
   with procedure Last_Exti_Time (D : in out Radio_Device; Time : out Interfaces.Unsigned_32);
   with procedure Bus_Write_Command (D : in out Radio_Device; Command : Byte; Value : Byte);
   with procedure Bus_Write_Command_Multi (D : in out Radio_Device; Command : Byte; Data : Byte_Array);
   with procedure Bus_Read_Command (D : in out Radio_Device; Command : Byte; Value : out Byte);
   with procedure Bus_Read_Command_Multi (D : in out Radio_Device; Command : Byte; Data : out Byte_Array);
package Adaflight.SX127x with SPARK_Mode is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   type Operating_Mode is
     (Sleep, Standby, FS_Transmit, Transmit, FS_Receive, Receive_Continuous, Receive_Single, CAD);

   No_Error          : constant Byte := 0;
   Invalid_Bit_Range : constant Byte := 16#40#;

   Max_Power : constant Byte := 16#0F#;

   --  The frequency correction's bounds: 100 kHz in steps of the 32 MHz
   --  crystal over 2 ** 19.
   Correction_Max : constant Interfaces.Integer_32 := 1638;
   Correction_Min : constant Interfaces.Integer_32 := -1638;

   subtype Correction is Interfaces.Integer_32 range Correction_Min .. Correction_Max;

   procedure Init (D : in out Radio_Device; Has_Reset_Pin : Boolean; OK : out Boolean);

   --  The interrupt's reason, 1 for a received packet, 2 for a sent one, 3
   --  for both and 0 otherwise; the timestamp takes the receiver's last
   --  interrupt time when that is set.
   procedure ISR (D : in out Radio_Device; Timestamp : in out Interfaces.Unsigned_32; Reason : out Byte);

   procedure Write_Register (D : in out Radio_Device; Address : Byte; Value : Byte);

   procedure Write_Register_Burst (D : in out Radio_Device; Address : Byte; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Read_Register (D : in out Radio_Device; Address : Byte; Value : out Byte);

   procedure Read_Register_Burst (D : in out Radio_Device; Address : Byte; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   --  The register's bits from Lsb to Msb in place, or the invalid range code.
   procedure Get_Register_Value (D : in out Radio_Device; Address : Byte; Msb : Byte; Lsb : Byte; Value : out Byte);

   --  The register's bits from Lsb to Msb replaced by the value's.
   procedure Set_Register_Value
     (D : in out Radio_Device; Address : Byte; Value : Byte; Msb : Byte; Lsb : Byte; Status : out Byte);

   procedure Read_FIFO (D : in out Radio_Device; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Write_FIFO (D : in out Radio_Device; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Set_Bandwidth_Coding_Rate
     (D               : in out Radio_Device;
      Bandwidth       : Byte;
      Coding          : Byte;
      Spreading       : Byte;
      Explicit_Header : Boolean;
      CRC_Enabled     : Boolean);

   --  The sync word, or the next allowed one above it.
   procedure Set_Sync_Word (D : in out Radio_Device; Sync_Word : Byte);

   procedure Set_Mode (D : in out Radio_Device; Mode : Operating_Mode);

   procedure Set_Output_Power (D : in out Radio_Device; Power : Byte);

   procedure Set_Preamble_Length (D : in out Radio_Device; Length : Byte);

   procedure Set_Spreading_Factor (D : in out Radio_Device; Spreading : Byte);

   procedure Set_Frequency_Hz (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32);

   procedure Set_Frequency_Reg (D : in out Radio_Device; Frequency : Interfaces.Unsigned_32);

   procedure Transmit_Data (D : in out Radio_Device; Data : Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Receive_Data (D : in out Radio_Device; Data : out Byte_Array)
     with Pre => Data'Length <= 255;

   procedure Start_Receiving (D : in out Radio_Device);

   procedure Config
     (D               : in out Radio_Device;
      Bandwidth       : Byte;
      Spreading       : Byte;
      Coding          : Byte;
      Frequency       : Interfaces.Unsigned_32;
      Preamble_Length : Byte;
      IQ_Inverted     : Boolean);

   --  The bandwidth in hertz, or all ones for an unknown code.
   function Current_Bandwidth (Bandwidth : Byte) return Interfaces.Unsigned_32
     with Global => null;

   --  The bandwidth's scale for the frequency error, or all ones for an
   --  unknown code.
   function Bandwidth_Normalised_Shifted (Bandwidth : Byte) return Interfaces.Unsigned_32
     with Global => null;

   procedure Set_PPM_Offset (D : in out Radio_Device; Offset : Correction; Frequency : Interfaces.Unsigned_32)
     with Pre => Frequency > 0;

   procedure Get_Frequency_Error (D : in out Radio_Device; Bandwidth : Byte; Error : out Interfaces.Integer_32);

   procedure Adjust_Frequency (D : in out Radio_Device; Offset : in out Correction; Frequency : Interfaces.Unsigned_32)
     with Pre => Frequency > 0;

   procedure Unsigned_Last_Packet_RSSI (D : in out Radio_Device; Value : out Byte);

   procedure Last_Packet_RSSI (D : in out Radio_Device; Value : out Interfaces.Integer_8);

   procedure Current_RSSI (D : in out Radio_Device; Value : out Interfaces.Integer_8);

   procedure Last_Packet_SNR_Raw (D : in out Radio_Device; Value : out Interfaces.Integer_8);

   procedure Get_Irq_Flags (D : in out Radio_Device; Flags : out Byte);

   procedure Clear_Irq_Flags (D : in out Radio_Device);

   procedure Get_Irq_Reason (D : in out Radio_Device; Reason : out Byte);

   --  The signal strength and the raw signal to noise ratio of the last
   --  packet, the strength corrected by a quarter of a negative ratio.
   procedure Get_Last_Packet_Stats
     (D : in out Radio_Device; RSSI : out Interfaces.Integer_8; SNR : out Interfaces.Integer_8);

   procedure Config_LoRa_Defaults (D : in out Radio_Device; IQ_Inverted : Boolean);

end Adaflight.SX127x;
