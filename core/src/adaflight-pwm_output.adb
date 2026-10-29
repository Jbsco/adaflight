package body Adaflight.PWM_Output with SPARK_Mode is

   procedure Endpoints
     (Min_Command, Max_Throttle, Idle, Limit_3D_Low, Limit_3D_High, Neutral_3D, Deadband_3D_Low,
      Deadband_3D_High : Pulse_Width; Output_Limit : Maths.Unit_Interval; Two_Direction : Boolean;
      Low, High, Disarm : out Float; Deadband_High, Deadband_Low : in out Float)
   is
   begin
      if Two_Direction then
         declare
            Offset : constant Float :=
              Float (Integer (Limit_3D_High) - Integer (Limit_3D_Low)) * (1.0 - Output_Limit) / 2.0;
         begin
            Disarm := Float (Neutral_3D);
            Low := Float (Limit_3D_Low) + Offset;
            High := Float (Limit_3D_High) - Offset;
            Deadband_High := Float (Deadband_3D_High);
            Deadband_Low := Float (Deadband_3D_Low);
         end;
      else
         declare
            Min_Throttle : constant Float := Float (Min_Command) + Float (Idle) * 0.1;
         begin
            Disarm := Float (Min_Command);
            Low := Min_Throttle;
            High := Float (Max_Throttle) - ((Float (Max_Throttle) - Min_Throttle) * (1.0 - Output_Limit));
         end;
      end if;
   end Endpoints;

   --  An unsigned division, zero for a zero divisor.
   function Div (A, B : Unsigned_32) return Unsigned_32 is (if B = 0 then 0 else A / B);

   function Motor_Timing_Of
     (P : Protocol; Rate : Unsigned_16; Continuous : Boolean; Clock : Unsigned_32; Idle : Unsigned_16)
      return Motor_Timing
   is
      S_Min      : constant Float :=
        (case P is
            when Protocol_OneShot125 => 125.0E-6,
            when Protocol_OneShot42  => 42.0E-6,
            when Protocol_MultiShot  => 5.0E-6,
            when Protocol_Brushed    => 0.0,
            when Protocol_PWM        => 1.0E-3);
      S_Len      : constant Float :=
        (case P is
            when Protocol_OneShot125 => 125.0E-6,
            when Protocol_OneShot42  => 42.0E-6,
            when Protocol_MultiShot  => 20.0E-6,
            when Protocol_Brushed    => 0.0,
            when Protocol_PWM        => 1.0E-3);
      Continuous_Update : constant Boolean := Continuous or else P in Protocol_Brushed | Protocol_PWM;
      --  The one-shot rates are the ceiling of one over four pulses of the
      --  protocol's longest width in single precision.
      Rate_Hz    : constant Unsigned_32 :=
        (if Continuous_Update then Unsigned_32 (Rate)
         else (case P is
                  when Protocol_OneShot125 => 1_000,
                  when Protocol_OneShot42  => 2_977,
                  when others              => 10_000));
      Prescale   : constant Unsigned_32 := (Div (Clock, Rate_Hz) + 16#FFFF#) / 16#1_0000#;
      Hz         : constant Unsigned_32 := Div (Clock, Prescale);
      Period     : constant Unsigned_32 := (if Continuous_Update then Div (Hz, Rate_Hz) else 16#FFFF#);
      Width      : constant Float := (if P = Protocol_Brushed then Float (Period) else S_Len * Float (Hz));
      Scale      : constant Pulse_Scale := Width / 1_000.0;
   begin
      return (Continuous => Continuous_Update,
              Hz         => Hz,
              Period     => Period,
              Scale      => Scale,
              Offset     => S_Min * Float (Hz) - Scale * 1_000.0,
              Idle       => (if P in Protocol_Brushed | Protocol_PWM then 0 else Idle));
   end Motor_Timing_Of;

   --  A value rounded to the nearest with ties to even as the 32-bit signed
   --  value a compare register stores, a value past that range at its bound.
   function Register_Value (F : Float) return Unsigned_32 is
     (if abs F <= Float (Maths.Rounding_Bound) - 1.0
      then Unsigned_32'Mod (Maths.Round_Half_Even (F))
      elsif F >= 2.0 ** 31 then 16#7FFF_FFFF#
      elsif F < -2.0 ** 31 then 16#8000_0000#
      else Unsigned_32'Mod (Integer_64 (F)));

   function Motor_Pulse (T : Motor_Timing; Value : Write_Value) return Unsigned_32 is
     (Register_Value (Value * T.Scale + T.Offset));

   function Servo_Period (Rate : Unsigned_16) return Unsigned_16 is
     (Unsigned_16'Mod (Div (1_000_000, Unsigned_32 (Rate))));

   function Servo_Pulse (Value : Write_Value) return Unsigned_32 is (Register_Value (Value));

end Adaflight.PWM_Output;
