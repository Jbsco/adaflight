--  The ExpressLRS link's common tables and counters: the air rate and
--  performance tables of the two bands, the frequency domains with the
--  hopping sequence generated from the bind seed, the 14-bit CRC of the
--  over-the-air packets, the link quality counter over a hundred periods,
--  and the switch, ratio, rate, power, and rate index conversions. The
--  over-the-air protocol is version 3.
with Interfaces;
with Adaflight.Bytes; use Adaflight.Bytes;

package Adaflight.ExpressLRS with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   OTA_Version : constant := 3;

   type Frequency_Domain is (AU433, AU915, EU433, EU868, IN866, FCC915, ISM2400, CE2400);
   type Band is (Band_900, Band_2400);
   type Switch_Mode is (Wide, Hybrid);
   type Telemetry_Ratio is
     (Ratio_Standard, No_Telemetry, Ratio_1_128, Ratio_1_64, Ratio_1_32, Ratio_1_16,
      Ratio_1_8, Ratio_1_4, Ratio_1_2, Ratio_Disarmed);
   type RF_Rate is
     (LoRa_4Hz, LoRa_25Hz, LoRa_50Hz, LoRa_100Hz, LoRa_100Hz_8Ch, LoRa_150Hz, LoRa_200Hz,
      LoRa_250Hz, LoRa_333Hz_8Ch, LoRa_500Hz, DVDA_250Hz, DVDA_500Hz, FLRC_500Hz, FLRC_1000Hz);
   type Radio_Type is (SX127x_LoRa, SX128x_LoRa, SX128x_FLRC);

   function Band_Of (D : Frequency_Domain) return Band is
     (if D in ISM2400 | CE2400 then Band_2400 else Band_900);

   --  One air rate: the radio's modulation registers, the packet interval,
   --  the telemetry ratio, the hop interval in packets, and the preamble.
   subtype Rate_Index is Natural range 0 .. 5;
   type Mod_Settings is record
      Index        : Rate_Index;
      Radio        : Radio_Type;
      Rate         : RF_Rate;
      V4_Rate      : Natural range 0 .. 255;
      Bandwidth    : Byte;
      Spreading    : Byte;
      Coding       : Byte;
      Interval_Us  : Natural;
      Ratio        : Telemetry_Ratio;
      Hop_Interval : Natural range 1 .. 16;
      Preamble     : Natural range 1 .. 32;
   end record;

   --  The link's timing at one air rate: the sensitivity, the time on air,
   --  the disconnect and lock timeouts, and the sync packet intervals.
   type Perf_Params is record
      Index                         : Rate_Index;
      Rate                          : RF_Rate;
      Sensitivity_Dbm               : Integer;
      Time_On_Air_Us                : Natural;
      Disconnect_Timeout_Ms         : Natural;
      Lock_Timeout_Ms               : Natural;
      Sync_Interval_Disconnected_Ms : Natural;
      Sync_Interval_Connected_Ms    : Natural;
   end record;

   type Mod_Table is array (Rate_Index range <>) of Mod_Settings;
   type Perf_Table is array (Rate_Index range <>) of Perf_Params;

   Rates_900 : constant Mod_Table (0 .. 3) :=
     ((0, SX127x_LoRa, LoRa_200Hz, 5, 16#90#, 16#60#, 16#06#, 5_000, Ratio_1_64, 4, 8),
      (1, SX127x_LoRa, LoRa_100Hz, 2, 16#90#, 16#70#, 16#06#, 10_000, Ratio_1_64, 4, 8),
      (2, SX127x_LoRa, LoRa_50Hz, 1, 16#90#, 16#80#, 16#06#, 20_000, Ratio_1_16, 4, 10),
      (3, SX127x_LoRa, LoRa_25Hz, 0, 16#90#, 16#90#, 16#06#, 40_000, Ratio_1_8, 2, 10));

   Rates_2400 : constant Mod_Table (0 .. 5) :=
     ((0, SX128x_FLRC, FLRC_1000Hz, 33, 16#86#, 16#10#, 16#00#, 1_000, Ratio_1_128, 2, 32),
      (1, SX128x_FLRC, FLRC_500Hz, 32, 16#86#, 16#10#, 16#00#, 2_000, Ratio_1_128, 2, 32),
      (2, SX128x_LoRa, LoRa_500Hz, 29, 16#18#, 16#50#, 16#06#, 2_000, Ratio_1_128, 4, 12),
      (3, SX128x_LoRa, LoRa_250Hz, 27, 16#18#, 16#60#, 16#07#, 4_000, Ratio_1_64, 4, 14),
      (4, SX128x_LoRa, LoRa_150Hz, 24, 16#18#, 16#70#, 16#07#, 6_666, Ratio_1_32, 4, 12),
      (5, SX128x_LoRa, LoRa_50Hz, 21, 16#18#, 16#80#, 16#07#, 20_000, Ratio_1_16, 2, 12));

   Perf_900 : constant Perf_Table (0 .. 3) :=
     ((0, LoRa_200Hz, -112, 4_380, 3_000, 2_500, 600, 5_000),
      (1, LoRa_100Hz, -117, 8_770, 3_500, 2_500, 600, 5_000),
      (2, LoRa_50Hz, -120, 17_540, 4_000, 2_500, 600, 5_000),
      (3, LoRa_25Hz, -123, 17_540, 6_000, 4_000, 0, 5_000));

   Perf_2400 : constant Perf_Table (0 .. 5) :=
     ((0, FLRC_1000Hz, -104, 389, 2_500, 2_500, 0, 5_000),
      (1, FLRC_500Hz, -104, 389, 2_500, 2_500, 0, 5_000),
      (2, LoRa_500Hz, -105, 1_665, 2_500, 2_500, 3, 5_000),
      (3, LoRa_250Hz, -108, 3_300, 3_000, 2_500, 6, 5_000),
      (4, LoRa_150Hz, -112, 5_871, 3_500, 2_500, 10, 5_000),
      (5, LoRa_50Hz, -115, 10_798, 4_000, 2_500, 0, 5_000));

   --  A domain's first and last channel as the radio's frequency register
   --  values (the frequency over the synthesizer step of 61.03515625 Hz for
   --  the 900 MHz radio and of 52 MHz over 2 to the 18 for the 2.4 GHz
   --  radio, truncated) and its channel count.
   subtype Channel_Count is Natural range 3 .. 80;
   type Domain_Config is record
      Start_Reg : Unsigned_32;
      Stop_Reg  : Unsigned_32;
      Channels  : Channel_Count;
   end record;

   Domains : constant array (Frequency_Domain) of Domain_Config :=
     (AU433   => (7_101_153, 7_117_537, 3),
      AU915   => (14_999_552, 15_186_329, 20),
      EU433   => (7_095_910, 7_118_028, 3),
      EU868   => (14_176_665, 14_247_116, 13),
      IN866   => (14_178_304, 14_204_108, 4),
      FCC915  => (14_802_944, 15_186_329, 40),
      ISM2400 => (12_100_970, 12_499_227, 80),
      CE2400  => (12_100_970, 12_499_227, 80));

   --  The hopping sequence: the sync channel every channel count entries and
   --  the other channels shuffled within each block by the seeded generator,
   --  over as many whole blocks as fit 256 entries.
   Sequence_Length : constant := 256;
   Spread_Scale    : constant := 256;
   subtype Sequence_Index is Natural range 0 .. Sequence_Length - 1;
   subtype Sequence_Count is Natural range 1 .. Sequence_Length;
   subtype Channel_Number is Natural range 0 .. Channel_Count'Last - 1;
   type Hop_Sequence is array (Sequence_Index) of Channel_Number;

   type Hopping is record
      Domain       : Frequency_Domain := ISM2400;
      Sequence     : Hop_Sequence := (others => 0);
      Count        : Sequence_Count := 1;
      Index        : Sequence_Index := 0;
      Sync_Channel : Channel_Number := 0;
      Spread       : Unsigned_32 := 0;
      Seed         : Unsigned_32 := 0;
   end record
     with Dynamic_Predicate => Hopping.Index < Hopping.Count;

   --  The bind seed from the unique id: its third to sixth bytes, the last
   --  marked with the protocol version.
   function UID_Seed (UID : Byte_Array) return Unsigned_32
     with Pre => UID'Length = 6;

   procedure Generate (H : in out Hopping; Seed : Unsigned_32; Domain : Frequency_Domain);

   function Entry_Count (H : Hopping) return Channel_Count is (Domains (H.Domain).Channels);

   procedure Set_Index (H : in out Hopping; Value : Byte);

   --  The register value of the sync channel, less the frequency correction.
   function Initial_Frequency (H : Hopping; Correction : Interfaces.Integer_32) return Unsigned_32 is
     (Domains (H.Domain).Start_Reg + Unsigned_32 (H.Sync_Channel) * H.Spread / Spread_Scale
      - Unsigned_32'Mod (Correction));

   --  The register value of the next channel in the sequence, less the
   --  frequency correction.
   procedure Next_Frequency (H : in out Hopping; Correction : Interfaces.Integer_32; Freq : out Unsigned_32);

   --  The 14-bit CRC of the over-the-air packet, polynomial 16#2E57#, from a
   --  starting value whose low fourteen bits count.
   CRC14_Polynomial : constant := 16#2E57#;
   subtype CRC14_Value is Unsigned_16 range 0 .. 16#3FFF#;

   function CRC14 (Data : Byte_Array; Init : Unsigned_16) return CRC14_Value;

   --  The link quality: a hundred-period window of hit bits over four words,
   --  and the count of hits in it. The window position is a word index and a
   --  bit position, and wraps from the fourth bit of the last word to the
   --  first bit of the first.
   LQ_Depth    : constant := 4;
   LQ_Periods  : constant := 100;
   LQ_Last_Bit : constant := LQ_Periods - 32 * (LQ_Depth - 1);
   type LQ_Words is array (0 .. LQ_Depth - 1) of Unsigned_32;

   type Link_Quality is record
      Bits  : LQ_Words := (others => 0);
      Value : Byte := 0;
      Index : Natural range 0 .. LQ_Depth - 1 := 0;
      Bit   : Natural range 0 .. 31 := 0;
   end record
     with Dynamic_Predicate => (if Link_Quality.Index = LQ_Depth - 1 then Link_Quality.Bit < LQ_Last_Bit);

   procedure Reset (L : out Link_Quality);

   function Mask (L : Link_Quality) return Unsigned_32 is (Interfaces.Shift_Left (1, L.Bit));

   function Period_Is_Set (L : Link_Quality) return Boolean is ((L.Bits (L.Index) and Mask (L)) /= 0);

   --  A packet in the current period counts once.
   procedure Increase (L : in out Link_Quality);

   --  The window advances one period and drops the hit it leaves.
   procedure New_Period (L : in out Link_Quality);

   --  The switch conversions to channel values in microseconds.
   function Switch_1b (V : Natural) return Natural is (if V /= 0 then 2_000 else 1_000);

   function Switch_3b (V : Natural) return Natural is
     (case V is
        when 0 => 1_000, when 1 => 1_275, when 2 => 1_425, when 3 => 1_575,
        when 4 => 1_725, when 5 => 2_000, when others => 1_500);

   function Switch_Nb (V, Max : Natural) return Natural is
     (if V > Max then 1_500 else V * 1_000 / Max + 1_000)
     with Pre => Max in 1 .. 65_535 and then V <= 65_535;

   --  The wide hybrid switch sent with a nonce: eight switches in turn, the
   --  second round rotated by one, so each is sent within sixteen packets at
   --  any telemetry ratio.
   function Hybrid_Wide_Switch_Index (Nonce : Byte) return Natural is
     ((Natural (Nonce and 7) + Natural (Interfaces.Shift_Right (Nonce, 3) and 1)) mod 8);

   --  The telemetry ratio as packets per telemetry packet, in a byte: one for
   --  no telemetry, 128 down to 2 for the ratios, and the standard and
   --  disarmed markers fall outside the byte or read one.
   function Ratio_Value (R : Telemetry_Ratio) return Byte is
     (if R = No_Telemetry then 1
      else Byte'Mod (2 ** (8 + Telemetry_Ratio'Pos (No_Telemetry) - Telemetry_Ratio'Pos (R))));

   function Rate_Hz (R : RF_Rate) return Natural is
     (case R is
        when FLRC_1000Hz => 1_000, when FLRC_500Hz | LoRa_500Hz => 500, when LoRa_250Hz => 250,
        when LoRa_200Hz => 200, when LoRa_150Hz => 150, when LoRa_100Hz => 100, when LoRa_50Hz => 50,
        when LoRa_25Hz => 25, when LoRa_4Hz => 4, when others => 1);

   function Power_Mw (Index : Natural) return Natural is
     (case Index is
        when 0 => 0, when 1 => 10, when 2 => 25, when 3 => 100, when 4 => 500, when 5 => 1_000,
        when 6 => 2_000, when 7 => 250, when 8 => 50, when others => 0);

   --  The air rate index of a sync packet mapped onto the band's table; an
   --  index the table lacks keeps the current one.
   function Rate_Index_900 (Air_Rate : Natural; Current : Rate_Index) return Rate_Index is
     (case Air_Rate is
        when 0 => 0, when 1 => Current, when 2 => 1, when 3 => 2, when 4 => 3, when others => Current);

   function Rate_Index_2400 (Air_Rate : Natural; Current : Rate_Index) return Rate_Index is
     (case Air_Rate is
        when 0 => 0, when 1 => 1, when 2 | 3 => Current, when 4 => 2, when 5 => Current,
        when 6 => 3, when 7 => 4, when 8 => Current, when 9 => 5, when others => Current);

end Adaflight.ExpressLRS;
