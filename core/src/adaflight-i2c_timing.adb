package body Adaflight.I2C_Timing with SPARK_Mode is

   subtype Field is Natural range 0 .. 2 ** 16 - 1;

   --  The bounds of the times in nanoseconds the clock, speed and filter
   --  ranges allow, so each step's overflow check stands alone.
   subtype Period_Ns is Float range 3.0 .. 1_000.0;
   subtype Target_Ns is Float range 1_000.0 .. 100_000.0;
   subtype Scaled_Ns is Float range 3.0 .. 15_000.0;
   subtype Sync_Ns   is Float range 0.0 .. 20_000.0;
   subtype High_Ns   is Float range -20_000.0 .. 40_000.0;
   subtype Low_Ns    is Float range -100_000.0 .. 200_000.0;

   --  A conversion of a non-negative value, truncated; a negative one gives
   --  zero, which the fields' bound then refuses.
   function Whole (V : Float) return Field is
     (if V <= 0.0 then 0 elsif V >= Float (Field'Last) then Field'Last else Field (Float'Floor (V)));

   procedure Compute
     (Clock : Clock_Hz; Speed : Speed_KHz; Prescaler : Natural; Filter : Filter_Length;
      SCL_Delay, SDA_Delay, High, Low : out Field)
     with Pre => Prescaler <= 14
   is
      Fast_Plus   : constant Boolean := Speed > 400;
      Rise_Max    : constant Float := (if Fast_Plus then 120.0 else 300.0);
      Fall_Max    : constant Float := (if Fast_Plus then 120.0 else 300.0);
      Setup_Min   : constant Float := (if Fast_Plus then 50.0 else 100.0);
      Hold_Min    : constant Float := 0.0;
      High_Min    : constant Float := (if Fast_Plus then 260.0 else 600.0);
      Low_Min     : constant Float := (if Fast_Plus then 500.0 else 1300.0);
      Filter_Min  : constant Float := 50.0;
      Rise        : constant Float := 100.0;
      Fall        : constant Float := 10.0;
      Period      : constant Period_Ns := 1.0e9 / Float (Clock);
      Target      : constant Target_Ns := 1.0e6 / Float (Speed);
      Scaled      : constant Scaled_Ns := Float (Prescaler + 1) * Period;
      Sync_1      : constant Sync_Ns := Fall + Filter_Min + Float (Filter) * Period + 2.0 * Period;
      Sync_2      : constant Sync_Ns := Rise + Filter_Min + Float (Filter) * Period + 2.0 * Period;
      High_Time   : constant High_Ns := High_Min * Target / (High_Min + Low_Min) - Sync_2;
      Low_Time    : constant Low_Ns := Target - High_Time - Sync_1 - Sync_2;
   begin
      SCL_Delay := Whole ((Rise_Max + Setup_Min) / Scaled - 1.0);
      SDA_Delay := Whole ((Fall_Max + Hold_Min - Filter_Min - (Float (Filter) + 3.0) * Period) / Scaled);
      High := Whole (High_Time / Scaled - 1.0);
      Low := Whole (Low_Time / Scaled - 1.0);
      while Sync_1 + Sync_2 + Float (High + 1 + Low + 1) * Scaled < Target loop
         pragma Loop_Variant (Increases => High);
         exit when High = Field'Last;
         High := High + 1;
      end loop;
   end Compute;

   function Timing (Clock : Clock_Hz; Speed : Speed_KHz; Filter : Filter_Length) return Unsigned_32 is
      SCL_Delay, SDA_Delay, High, Low : Field;
   begin
      for Prescaler in 0 .. 14 loop
         Compute (Clock, Speed, Prescaler, Filter, SCL_Delay, SDA_Delay, High, Low);
         if SCL_Delay < 16 and then SDA_Delay < 16 and then High < 256 and then Low < 256 then
            return Shift_Left (Unsigned_32 (Prescaler), 28) or Shift_Left (Unsigned_32 (SCL_Delay), 20)
              or Shift_Left (Unsigned_32 (SDA_Delay), 16) or Shift_Left (Unsigned_32 (High), 8)
              or Unsigned_32 (Low);
         end if;
      end loop;
      return 0;
   end Timing;

end Adaflight.I2C_Timing;
