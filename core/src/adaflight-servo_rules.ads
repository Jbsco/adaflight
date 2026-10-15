--  Servo rules: the rules the servo mixer starts from for each mixer mode,
--  each naming a servo, an input source, a rate, a speed, a range and a
--  box. The uncommon frames have rules only in builds with the uncommon
--  mixers, and the modes past the rule table have none.
with Interfaces; use Interfaces;
with Adaflight.Mixer_Init;

package Adaflight.Servo_Rules with SPARK_Mode is

   type Rule is record
      Target : Unsigned_8 := 0;
      Input  : Unsigned_8 := 0;
      Rate   : Integer_8 := 0;
      Speed  : Unsigned_8 := 0;
      Min    : Integer_8 := 0;
      Max    : Integer_8 := 0;
      Box    : Unsigned_8 := 0;
   end record;

   Max_Mode_Rules : constant := 9;
   subtype Rule_Count is Natural range 0 .. Max_Mode_Rules;
   type Rule_List is array (1 .. Max_Mode_Rules) of Rule;

   --  The mode's rules, the first Count of the list.
   procedure Mode_Rules
     (O : Mixer_Init.Options; Mode : Mixer_Init.Mixer_Mode; Rules : out Rule_List; Count : out Rule_Count);

end Adaflight.Servo_Rules;
