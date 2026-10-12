--  The DShot protocol pieces that do not touch the output hardware: the
--  frame with its telemetry request bit and nibble checksum, the throttle
--  conversions between the 1000 to 2000 command range and the 48 to 2047
--  protocol range in the one and the two direction modes, the output
--  endpoints from the idle and limit settings, the edge decoder of the
--  sampled telemetry reply with its preamble skip, the five-bit group
--  decode with its checksum, the period and extended value decode, the
--  per-motor telemetry with the revolution rates and filtered frequencies,
--  the quality counters, and the check of the motor output order.
with Interfaces;
with Adaflight.Clock;
with Adaflight.Filters;
with Adaflight.Maths;
with Adaflight.Mixer;

package Adaflight.DShot with SPARK_Mode, Pure is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_16 is Interfaces.Unsigned_16;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_16 is Interfaces.Integer_16;
   subtype Motor_Index is Adaflight.Mixer.Motor_Index;
   subtype Motor_Total is Natural range 0 .. Adaflight.Mixer.Max_Motors;
   subtype Motor_Value is Adaflight.Mixer.Motor_Value;
   subtype Unit_Interval is Adaflight.Maths.Unit_Interval;
   subtype Time_Us is Adaflight.Clock.Time_Us;
   subtype Time_Ms is Adaflight.Clock.Time_Ms;

   Min_Throttle         : constant := 48;
   Max_Throttle         : constant := 2047;
   Forward_Min_Throttle : constant := 1048;
   Throttle_Span        : constant := Max_Throttle - Min_Throttle;
   Motor_Stop           : constant := 0;

   subtype Frame_Value is Natural range 0 .. Max_Throttle;

   --  The eleven value bits, the telemetry request bit, then the checksum of
   --  the three nibbles above it, inverted when the reply shares the line.
   function Frame (Value : Frame_Value; Request_Telemetry : Boolean; Inverted_Checksum : Boolean)
                   return Unsigned_16;

   --  A 1000 to 2000 command as a protocol value: 1000 is the motor stop,
   --  and in the two direction mode 1500 is the stop with each half mapped
   --  onto its own range. Commands outside 1000 to 2000 are clamped first.
   function From_External (External : Unsigned_16; Two_Direction : Boolean) return Motor_Value;

   subtype External_Value is Natural range 999 .. 2001;

   --  The reverse map, rounded to the nearest command, with every value
   --  below the minimum throttle read as the stop.
   function To_External (Value : Motor_Value; Two_Direction : Boolean) return External_Value;

   subtype Idle_Setting is Natural range 0 .. 2000;

   --  The output range from the idle setting in hundredths of a percent and
   --  the output limit as a fraction. The deadband edges of the two
   --  direction mode are written only in that mode.
   procedure Endpoints (Idle : Idle_Setting; Output_Limit : Unit_Interval; Two_Direction : Boolean;
                        Low, High, Disarm : out Motor_Value; Deadband_High, Deadband_Low : in out Float)
     with Post => Disarm = 0.0
       and then (if Two_Direction
                 then Deadband_High in 0.0 .. 2048.0 and then Deadband_Low in 0.0 .. 2048.0
                 else Deadband_High = Deadband_High'Old and then Deadband_Low = Deadband_Low'Old);

   ---------------------------------------------------------------------------
   --  The telemetry reply
   ---------------------------------------------------------------------------

   No_Edge       : constant := 16#FFFE#;
   Invalid_Value : constant := 16#FFFF#;

   subtype Raw_Value is Unsigned_16 range 0 .. 16#FFF#;

   Max_Samples       : constant := 140;
   Min_Valid_Samples : constant := (21 - 2) * 3;
   Max_Valid_Samples : constant := (21 + 2) * 3;
   subtype Sample_Count is Natural range 0 .. Max_Samples;
   subtype Sample_Index is Natural range 0 .. Max_Samples - 1;
   subtype Sample_Bit is Natural range 0 .. 15;
   type Samples is array (Sample_Index range <>) of Unsigned_16;

   Margin_Check_Interval_Us : constant := 500_000;
   Start_Margin_Target      : constant := 5;

   --  The decoder's memory between replies: the samples skipped before the
   --  search for the first low sample, the smallest margin seen since the
   --  last check, and the time of the next check.
   type Edge_Decoder is record
      Preamble_Skip     : Unsigned_8 := 0;
      Min_Margin        : Unsigned_32 := Unsigned_32'Last;
      Next_Margin_Check : Time_Us := 0;
   end record;

   --  The reply sampled three times per bit on one line of a port: a high
   --  preamble, then runs whose lengths give the transition bits of the
   --  twenty-one bit word, the last run inferred from the bits still
   --  missing. No_Edge when the preamble never ends or the run count is off,
   --  Invalid_Value when a five-bit group or the checksum fails, else the
   --  twelve bit value.
   procedure Decode_Samples (D : in out Edge_Decoder; Buffer : Samples; Count : Sample_Count; Bit : Sample_Bit;
                             Now : Time_Us; Result : out Unsigned_32)
     with Pre  => Buffer'First = 0 and then Count <= Buffer'Length,
          Post => Result = No_Edge or else Result = Invalid_Value or else Result <= 16#FFF#;

   --  Four five-bit groups to nibbles, the nibble checksum, then the twelve
   --  bits above the checksum.
   function Decode_Groups (Word : Unsigned_32) return Unsigned_32
     with Post => Decode_Groups'Result = Invalid_Value or else Decode_Groups'Result <= 16#FFF#;

   Max_Period_Value : constant := 600_000;

   --  The period reply: three exponent bits over nine mantissa bits give the
   --  period in microseconds, returned as electrical revolutions per minute
   --  in hundreds. All ones is a stopped motor and a zero period is invalid.
   function Decode_Period (Raw : Raw_Value) return Unsigned_32
     with Post => Decode_Period'Result = Invalid_Value or else Decode_Period'Result <= Max_Period_Value;

   type Telemetry_Kind is (Erpm, Temperature, Voltage, Current, Debug_1, Debug_2, Debug_3, State_Events);

   --  With the extended kinds enabled, an even non-zero type field names the
   --  kind and the low byte is its value. Every other reply is a period.
   procedure Decode_Value (Raw : Raw_Value; Extended : Boolean; Value : out Unsigned_32; Kind : out Telemetry_Kind)
     with Post => Value = Invalid_Value or else Value <= Max_Period_Value;

   type Telemetry_Values is array (Telemetry_Kind) of Unsigned_16;

   --  Received holds one bit per kind, the period kind lowest.
   type Motor_Telemetry is record
      Raw             : Raw_Value := 0;
      Values          : Telemetry_Values := (others => 0);
      Received        : Unsigned_8 := 0;
      Max_Temperature : Unsigned_8 := 0;
   end record;
   type Motor_Telemetries is array (Motor_Index) of Motor_Telemetry;

   type Raw_State is (Invalid, Not_Processed, Processed);
   subtype Pole_Count is Positive range 1 .. 255;
   subtype Rate_Factor is Float range 0.0 .. 4.0;
   subtype Rpm_Value is Float range 0.0 .. 2.0E9;
   type Rpm_Values is array (Motor_Index) of Rpm_Value;
   type Frequencies is array (Motor_Index) of Adaflight.Maths.Signal;
   type Rate_Filters is array (Motor_Index) of Adaflight.Filters.PT1;
   subtype Cutoff_Setting is Natural range 0 .. 65535;
   subtype Looptime_Us is Positive range 1 .. 2 ** 20;

   --  The decoded replies of every motor, the processing state of the raw
   --  values, and the rates derived from them.
   type Telemetry is record
      Motors          : Motor_Telemetries;
      State           : Raw_State := Invalid;
      Count           : Motor_Total := 0;
      Erpm_To_Hz      : Rate_Factor := 0.0;
      Decode_Extended : Boolean := False;
      Filters         : Rate_Filters;
      Rpm             : Rpm_Values := (others => 0.0);
      Rpm_Average     : Rpm_Value := 0.0;
      Frequency       : Frequencies := (others => 0.0);
      Min_Frequency   : Float := 0.0;
   end record;

   --  Forgets every reply and the processing state; the rates stay.
   procedure Clean (T : in out Telemetry)
     with Post => T.State = Invalid and then T.Count = T.Count'Old;

   --  The motor count, the rate factor from the pole count, the forced
   --  extended decode, and the rate filters from the cutoff and the loop
   --  time, each filter starting from zero.
   procedure Init (T : in out Telemetry; Count : Motor_Total; Poles : Pole_Count; Extended_Forced : Boolean;
                   Cutoff_Hz : Cutoff_Setting; Looptime : Looptime_Us)
     with Post => T.Count = Count;

   --  Decodes the raw value of every motor once after the driver marks
   --  them, keeps each kind's last value and the highest temperature,
   --  then the rate per motor, the average rate over the valid replies, and
   --  the filtered frequency per motor with their minimum.
   procedure Update (T : in out Telemetry)
     with Post => T.Count = T.Count'Old;

   function Erpm_To_Rpm (T : Telemetry; Erpm_Hundreds : Unsigned_32) return Rpm_Value
     with Pre => Erpm_Hundreds <= 8 * Max_Period_Value;

   function Motor_Active (T : Telemetry; M : Motor_Index) return Boolean is
     ((T.Motors (M).Received and 1) /= 0);

   --  Every motor in the count has reported a period.
   function Active (T : Telemetry) return Boolean;

   --  The reply set of one motor as the sensor record: the period as a
   --  signed 16-bit value, the temperature and current only with the
   --  extended kinds seen.
   procedure Sensor_Data (T : Telemetry; M : Motor_Index; Present : out Boolean; Erpm_Hundreds : out Integer_16;
                          Temperature_C : out Unsigned_8; Current_A : out Unsigned_16);

   ---------------------------------------------------------------------------
   --  The reply quality over a rolling second
   ---------------------------------------------------------------------------

   Quality_Buckets   : constant := 10;
   Quality_Bucket_Ms : constant := 100;
   subtype Bucket_Index is Natural range 0 .. Quality_Buckets - 1;
   type Bucket_Counts is array (Bucket_Index) of Unsigned_32;

   type Quality is record
      Packet_Sum  : Unsigned_32 := 0;
      Invalid_Sum : Unsigned_32 := 0;
      Packets     : Bucket_Counts := (others => 0);
      Invalids    : Bucket_Counts := (others => 0);
      Last_Bucket : Bucket_Index := 0;
   end record;

   --  Counts a reply in the bucket of its time, clearing a bucket on entry.
   procedure Count_Packet (Q : in out Quality; Valid : Boolean; Now_Ms : Time_Ms);

   subtype Hundredths_Percent is Integer_16 range 0 .. 10_000;

   --  The invalid share of the counted replies in hundredths of a percent,
   --  the whole when the motor has no telemetry.
   function Invalid_Percent (Q : Quality; Active : Boolean) return Hundredths_Percent;

   ---------------------------------------------------------------------------
   --  The motor output order
   ---------------------------------------------------------------------------

   type Output_Order is array (Motor_Index range <>) of Unsigned_8;

   --  An order that is not a permutation of its indices becomes the identity.
   procedure Validate_Order (Order : in out Output_Order)
     with Pre  => Order'First = 0,
          Post => (for all I in Order'Range => Natural (Order (I)) < Order'Length);

end Adaflight.DShot;
