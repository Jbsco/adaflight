--  PWM motor output: the output range of the analog protocols, PWM,
--  OneShot, MultiShot and brushed, from the motor and 3D groups' pulse
--  widths, and their timing on the timers with the servos': each protocol's
--  update rate, the prescaled counting rate, the period, the scale and
--  offset that turn a motor value into a pulse, the servos' 1 MHz period,
--  and the compare values a write sets, rounded to the nearest with ties to
--  even. A division by zero gives zero, as the processor's divider does.
with Interfaces; use Interfaces;
with Adaflight.Maths;

package Adaflight.PWM_Output with SPARK_Mode is

   subtype Pulse_Width is Natural range 0 .. 65_535;

   --  The minimum command raised by a tenth of the idle setting, up to the
   --  maximum throttle brought down by what the output limit leaves of the
   --  span, with the disarm output at the minimum command; in the two
   --  direction mode the 3D limits brought in by half the limited span, the
   --  disarm output at the neutral pulse, and the deadband edges, written
   --  only in that mode.
   procedure Endpoints
     (Min_Command, Max_Throttle, Idle, Limit_3D_Low, Limit_3D_High, Neutral_3D, Deadband_3D_Low,
      Deadband_3D_High : Pulse_Width; Output_Limit : Maths.Unit_Interval; Two_Direction : Boolean;
      Low, High, Disarm : out Float; Deadband_High, Deadband_Low : in out Float)
     with Post => (if not Two_Direction
                   then Deadband_High = Deadband_High'Old and then Deadband_Low = Deadband_Low'Old);

   --  The analog protocols' numbers in the motor configuration.
   Protocol_PWM        : constant := 0;
   Protocol_OneShot125 : constant := 1;
   Protocol_OneShot42  : constant := 2;
   Protocol_MultiShot  : constant := 3;
   Protocol_Brushed    : constant := 4;
   subtype Protocol is Unsigned_8 range Protocol_PWM .. Protocol_Brushed;

   subtype Pulse_Scale is Float range 0.0 .. 5.0E6;
   subtype Pulse_Offset is Float range -5.0E9 .. 5.0E9;

   --  A motor output's timing: whether it updates without a forced timer
   --  overflow, the timer's counting rate and its period in counts, the
   --  scale and offset of a motor value's pulse, and the pulse its channel
   --  starts with.
   type Motor_Timing is record
      Continuous : Boolean := True;
      Hz         : Unsigned_32 := 0;
      Period     : Unsigned_32 := 0;
      Scale      : Pulse_Scale := 0.0;
      Offset     : Pulse_Offset := 0.0;
      Idle       : Unsigned_16 := 0;
   end record;

   --  The timing of a motor on a timer counting at Clock: the configured
   --  rate with continuous updates, which PWM and brushed motors always
   --  take, or the protocol's rate with a margin of four pulses, the
   --  smallest prescaler that keeps the period within sixteen bits, and no
   --  starting pulse for PWM and brushed motors.
   function Motor_Timing_Of
     (P : Protocol; Rate : Unsigned_16; Continuous : Boolean; Clock : Unsigned_32; Idle : Unsigned_16)
      return Motor_Timing
     with Global => null;

   --  The period a timer takes in sixteen bits, its auto-reload value, and
   --  the prescaler of a counting rate.
   function Period_Of (T : Motor_Timing) return Unsigned_16 is (Unsigned_16'Mod (T.Period));
   function Auto_Reload (Period : Unsigned_16) return Unsigned_32 is (Unsigned_32 (Period - 1));
   function Prescaler (Clock : Unsigned_32; Hz : Unsigned_32) return Unsigned_32 is
     ((if Hz = 0 then 0 else Clock / Hz) - 1);

   --  The values a motor or servo write takes: the mix's motor values, the
   --  servo mixer's values and its forwarded channels.
   subtype Write_Value is Float range -4.0E4 .. 4.0E4;

   --  A motor value's compare value.
   function Motor_Pulse (T : Motor_Timing; Value : Write_Value) return Unsigned_32
     with Global => null;

   --  The servos' period at 1 MHz for a rate in hertz, in sixteen bits.
   function Servo_Period (Rate : Unsigned_16) return Unsigned_16
     with Global => null;

   --  A servo value's compare value.
   function Servo_Pulse (Value : Write_Value) return Unsigned_32
     with Global => null;

end Adaflight.PWM_Output;
