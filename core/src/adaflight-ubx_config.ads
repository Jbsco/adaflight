--  The configuration messages for a u-blox receiver. A frame wraps a class,
--  an id and a payload in the preamble, the little-endian length and the two
--  running checksum bytes. The polls, the message rates, the navigation rate,
--  the dynamic model, the autonomous assistance, the power mode, the SBAS
--  selection and the NMEA output disable each have the legacy form and, from
--  the ninth generation, the keyed value form. A frame carries the id its
--  acknowledgement names and whether the sender counts it acknowledged at
--  once.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.UBX_Config with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_64 is Interfaces.Unsigned_64;

   Preamble_1 : constant Byte := 16#B5#;
   Preamble_2 : constant Byte := 16#62#;

   Class_Nav      : constant Unsigned_8 := 16#01#;
   Class_Ack      : constant Unsigned_8 := 16#05#;
   Class_Cfg      : constant Unsigned_8 := 16#06#;
   Class_Mon      : constant Unsigned_8 := 16#0A#;
   Class_NMEA_Std : constant Unsigned_8 := 16#F0#;

   Msg_Nav_Posllh : constant Unsigned_8 := 16#02#;
   Msg_Nav_Status : constant Unsigned_8 := 16#03#;
   Msg_Nav_Dop    : constant Unsigned_8 := 16#04#;
   Msg_Nav_Sol    : constant Unsigned_8 := 16#06#;
   Msg_Nav_Pvt    : constant Unsigned_8 := 16#07#;
   Msg_Nav_Velned : constant Unsigned_8 := 16#12#;
   Msg_Nav_Svinfo : constant Unsigned_8 := 16#30#;
   Msg_Nav_Sat    : constant Unsigned_8 := 16#35#;
   Msg_Cfg_Msg    : constant Unsigned_8 := 16#01#;
   Msg_Cfg_Rate   : constant Unsigned_8 := 16#08#;
   Msg_Cfg_Sbas   : constant Unsigned_8 := 16#16#;
   Msg_Cfg_Navx5  : constant Unsigned_8 := 16#23#;
   Msg_Cfg_Nav5   : constant Unsigned_8 := 16#24#;
   Msg_Cfg_Gnss   : constant Unsigned_8 := 16#3E#;
   Msg_Cfg_Pms    : constant Unsigned_8 := 16#86#;
   Msg_Cfg_Valset : constant Unsigned_8 := 16#8A#;
   Msg_Mon_Ver    : constant Unsigned_8 := 16#04#;
   Msg_NMEA_GGA   : constant Unsigned_8 := 16#00#;
   Msg_NMEA_GLL   : constant Unsigned_8 := 16#01#;
   Msg_NMEA_GSA   : constant Unsigned_8 := 16#02#;
   Msg_NMEA_GSV   : constant Unsigned_8 := 16#03#;
   Msg_NMEA_RMC   : constant Unsigned_8 := 16#04#;
   Msg_NMEA_VTG   : constant Unsigned_8 := 16#05#;

   --  The keys of the value form. The top byte of a key gives the size of
   --  its value: one byte for 16#10# and 16#20#, two for 16#30#, four for
   --  16#40#, eight for 16#50#.
   subtype Key is Unsigned_32;

   Key_Rate_Meas          : constant Key := 16#3021_0001#;
   Key_Rate_Nav           : constant Key := 16#3021_0002#;
   Key_Rate_Timeref       : constant Key := 16#2021_0003#;
   Key_Dynamic_Model      : constant Key := 16#2011_0021#;
   Key_UTC_Standard       : constant Key := 16#2011_001C#;
   Key_Use_Assistance     : constant Key := 16#1023_0001#;
   Key_NMEA_VTG_UART1     : constant Key := 16#2091_00B1#;
   Key_NMEA_GSV_UART1     : constant Key := 16#2091_00C5#;
   Key_NMEA_GLL_UART1     : constant Key := 16#2091_00CA#;
   Key_NMEA_GGA_UART1     : constant Key := 16#2091_00BB#;
   Key_NMEA_GSA_UART1     : constant Key := 16#2091_00C0#;
   Key_NMEA_RMC_UART1     : constant Key := 16#2091_00AC#;
   Key_Nav_Pvt_UART1      : constant Key := 16#2091_0007#;
   Key_Nav_Sat_UART1      : constant Key := 16#2091_0016#;
   Key_Nav_Dop_UART1      : constant Key := 16#2091_0039#;
   Key_Sbas_Test_Mode     : constant Key := 16#1036_0002#;
   Key_Sbas_Ranging       : constant Key := 16#1036_0003#;
   Key_Sbas_Corrections   : constant Key := 16#1036_0004#;
   Key_Sbas_Integrity     : constant Key := 16#1036_0005#;
   Key_Sbas_Scan_Mask     : constant Key := 16#5036_0006#;
   Key_Power_Operate_Mode : constant Key := 16#20D0_0001#;

   function Value_Size (K : Key) return Natural is
     (case Interfaces.Shift_Right (K, 24) is
         when 16#10# | 16#20# => 1,
         when 16#30#          => 2,
         when 16#40#          => 4,
         when 16#50#          => 8,
         when others          => 0);

   Max_Values  : constant := 128;
   Max_Payload : constant := 4 + Max_Values;
   Max_Frame   : constant := 8 + Max_Payload;
   subtype Payload_Length is Natural range 0 .. Max_Payload;
   subtype Frame_Length is Natural range 0 .. Max_Frame;
   subtype Frame_Index is Natural range 0 .. Max_Frame - 1;
   type Frame_Bytes is array (Frame_Index) of Byte;

   type Frame is record
      Data     : Frame_Bytes := (others => 0);
      Length   : Frame_Length := 0;
      Id       : Unsigned_8 := 0;
      Skip_Ack : Boolean := False;
   end record;

   type Dynamic_Model is (Portable, Stationary, Pedestrian, Automotive, At_Sea,
                          Airborne_1G, Airborne_2G, Airborne_4G);
   type UTC_Standard is (Auto, USNO, EU, SU, NTSC);
   type Sbas_Mode is (Auto, EGNOS, WAAS, MSAS, GAGAN, None);

   subtype Measurement_Rate_Hz is Unsigned_16 range 1 .. 1000;

   --  A message with an empty payload, answered by the receiver.
   function Poll (Class, Id : Unsigned_8) return Frame
     with Post => Poll'Result.Length = 8;

   --  The output rate of one message, legacy form.
   function Message_Rate (Class, Id, Rate : Unsigned_8) return Frame
     with Post => Message_Rate'Result.Length = 11;

   --  The output rate of one message, keyed form.
   function Message_Rate_Key (K : Key; Rate : Unsigned_8) return Frame
     with Pre  => Value_Size (K) = 1,
          Post => Message_Rate_Key'Result.Length = 17;

   --  The measurement rate from the rate in hertz, the solutions per
   --  measurement and the time reference.
   function Nav_Rate (Rate : Measurement_Rate_Hz; Solutions : Unsigned_16; Time_Ref : Unsigned_8;
                      Keyed : Boolean) return Frame;

   --  The dynamic model with the UTC standard and the fixed defaults of the
   --  remaining navigation settings.
   function Model_Message (Model : Dynamic_Model; UTC : UTC_Standard; Keyed : Boolean) return Frame;

   --  The autonomous assistance enable.
   function Assistance_Message (Keyed : Boolean) return Frame;

   --  Full power, in the eighth generation's form or keyed.
   function Power_Mode_Message (Keyed : Boolean) return Frame;

   --  The SBAS enable, the usage flags and the satellite scan mask of the
   --  selected system.
   function Sbas_Message (Mode : Sbas_Mode; Integrity : Boolean; Keyed : Boolean) return Frame;

   --  The six NMEA sentences off on the first UART, keyed form.
   function Disable_NMEA_Message return Frame;

   --  The satellite information message of the generation at the divisor
   --  of the navigation rate.
   function Satellite_Info_Rate (Divisor : Unsigned_8; M8, M9 : Boolean) return Frame;

   --  The GNSS configuration sent back from the module's reply: the same
   --  blocks, SBAS disabled when none is selected and Galileo set as
   --  selected. The message holds at most seven blocks (finding F61).
   Max_Gnss_Blocks : constant := 7;
   Gnss_Reply_Size : constant := 4 + 8 * Max_Gnss_Blocks;
   subtype Gnss_Reply is Byte_Array (0 .. Gnss_Reply_Size - 1);

   function Gnss_Message (Reply : Gnss_Reply; Disable_Sbas, Enable_Galileo : Boolean) return Frame;

end Adaflight.UBX_Config;
