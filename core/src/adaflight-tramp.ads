--  The Tramp video transmitter driver over one half-duplex serial line at
--  9600 baud. Frames are sixteen bytes: a start byte, a command, twelve
--  payload bytes, a checksum over the command and the payload, and a zero.
--  The driver queries the device's limits until it answers, then its
--  settings, then watches the frequency, power and pit mode against the
--  configuration and sends one change at a time with a bounded retry,
--  polling the settings every second and the temperature after each
--  settings reply. A reply that echoes a request carries zeros and is
--  passed over.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.VTX_Table;

package Adaflight.Tramp with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_16;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;

   Min_Frequency : constant := 5000;
   Max_Frequency : constant := 5999;
   Max_Retries   : constant := 20;

   type Status is (Offline, Init, Monitor_Settings, Monitor_Temperature, Config);
   type Receive_Phase is (Wait_Start, Wait_Code, Data);

   Frame_Length : constant := 16;
   subtype Frame_Bytes is Byte_Array (0 .. Frame_Length - 1);
   subtype Frame_Fill is Natural range 0 .. Frame_Length;

   type Driver is record
      Port_Open          : Boolean := False;
      Current            : Status := Offline;
      Freq_Min           : Unsigned_32 := 0;
      Freq_Max           : Unsigned_32 := 0;
      Power_Max          : Unsigned_32 := 0;
      Cur_Freq           : Unsigned_32 := 0;
      Cur_Conf_Power     : Unsigned_16 := 0;
      Cur_Act_Power      : Unsigned_16 := 0;
      Cur_Pit_Mode       : Unsigned_8 := 0;
      Cur_Temp           : Integer_16 := 0;
      Cur_Control_Mode   : Unsigned_8 := 0;
      Conf_Freq          : Unsigned_32 := 0;
      Conf_Power         : Unsigned_16 := 0;
      Conf_Pit_Mode      : Unsigned_8 := 0;
      Last_Conf_Freq     : Unsigned_32 := 0;
      Last_Conf_Power    : Unsigned_16 := 0;
      Last_Conf_Pit_Mode : Unsigned_8 := 0;
      Retry_Count        : Unsigned_8 := Max_Retries;
      Phase              : Receive_Phase := Wait_Start;
      Rx_Pos             : Frame_Fill := 0;
      Rx                 : Frame_Bytes := (others => 0);
      Last_Time_Us       : Unsigned_32 := 0;
   end record;

   type Events is record
      Tx       : Frame_Bytes := (others => 0);
      Tx_Count : Frame_Fill := 0;
   end record;

   procedure Init (D : out Driver; Port_Opened : Boolean);

   --  One task call at the microsecond clock with the bytes received. The
   --  bytes are read up to the first complete reply, and Consumed says how
   --  many were taken; the caller keeps the rest for the next call.
   procedure Process (D : in out Driver; Now_Us : Unsigned_32; Rx : Byte_Array; Control_Disabled : Boolean;
                      E : out Events; Consumed : out Natural)
     with Post => Consumed <= Rx'Length;

   function Ready (D : Driver) return Boolean is (D.Port_Open and then D.Current >= Monitor_Settings);

   --  The configured power from the table value of the index.
   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8);

   procedure Set_Pit_Mode (D : in out Driver; Value : Unsigned_8);

   --  A frequency within the device's limits, or the user range while the
   --  limits are unknown.
   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16);

   --  The device has no bands: zero and zero when ready.
   procedure Get_Band_Channel (D : Driver; Band, Channel : out Unsigned_8; Known : out Boolean);

   --  The table index of the configured power, zero for none; the index
   --  keeps its value for a power outside the table or a device not ready.
   procedure Read_Power_Index (D : Driver; T : VTX_Table.Table; Index : in out Unsigned_8);

   --  The same with Known false for a power outside the table.
   procedure Get_Power_Index (D : Driver; T : VTX_Table.Table; Index : in out Unsigned_8; Known : out Boolean);

   procedure Get_Frequency (D : Driver; Freq : out Unsigned_16; Known : out Boolean);

   --  The configured pit mode and the device's race lock.
   procedure Get_Status (D : Driver; Pit_Mode, Locked : out Boolean; Known : out Boolean);

   procedure Get_Pit_Mode (D : Driver; Pit_Mode : out Boolean; Known : out Boolean);

   function Actual_Power (D : Driver) return Unsigned_16 is (D.Cur_Act_Power);
   function Temperature (D : Driver) return Integer_16 is (D.Cur_Temp);

end Adaflight.Tramp;
