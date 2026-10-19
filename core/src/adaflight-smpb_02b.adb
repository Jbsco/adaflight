with Adaflight.Maths;

package body Adaflight.SMPB_02B with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Chip_Identity     : constant Byte := 16#5C#;
   Default_Address   : constant Byte := 16#70#;
   Identity_Register : constant Byte := 16#D1#;
   IIR_Register      : constant Byte := 16#F1#;
   Control_Register  : constant Byte := 16#F4#;
   Data_Register     : constant Byte := 16#F7#;
   IIR_8_Samples     : constant Byte := 16#03#;
   Forced_4x_32x     : constant Byte := 16#75#;
   Max_SPI_Clock_Hz  : constant := 10_000_000;
   Attempts          : constant := 5;
   Pressure_Delay_Us : constant := 35_000;

   Coe_PR11   : constant Byte := 16#A0#;
   Coe_PR21   : constant Byte := 16#A3#;
   Coe_PR31   : constant Byte := 16#A5#;
   Coe_TEMP11 : constant Byte := 16#A7#;
   Coe_TEMP21 : constant Byte := 16#A9#;
   Coe_TEMP31 : constant Byte := 16#AB#;
   Coe_PTAT11 : constant Byte := 16#AD#;
   Coe_PTAT21 : constant Byte := 16#B1#;
   Coe_PTAT31 : constant Byte := 16#B3#;

   subtype I32 is Interfaces.Integer_32;
   subtype Signed_16_Value is I32 range -32_768 .. 32_767;

   Not_A_Number_Value : constant Real := (Not_A_Number, 0.0);

   procedure Read_16 (D : in out Bus_Device; Register : Byte; V : out Signed_16_Value) is
      Data      : Byte_Array (0 .. 1) := (others => 0);
      Unused_OK : Boolean;
   begin
      Read_Registers (D, Register, Data, Unused_OK);
      V := I32 (Data (0)) * 256 + I32 (Data (1)) - (if Data (0) >= 128 then 65_536 else 0);
   end Read_16;

   procedure Read_24 (D : in out Bus_Device; Register : Byte; V : out Raw_Delta) is
      Data      : Byte_Array (0 .. 2) := (others => 0);
      Unused_OK : Boolean;
   begin
      Read_Registers (D, Register, Data, Unused_OK);
      V := I32 (Data (0)) * 65_536 + I32 (Data (1)) * 256 + I32 (Data (2))
        - (if Data (0) >= 128 then 2 ** 24 else 0);
   end Read_24;

   --  The nine coefficients in the order the reference reads them.
   procedure Configure (D : in out Bus_Device; C : out Coefficients) is
      V  : Signed_16_Value;
      Ca : Raw_Delta;
      Cp : Raw_Delta;
      Aa : Float;
      Ba : Float;
      Ap : Float;
      Bp : Float;
      A_T : Float;
      B_T : Float;
      C_T : Float;
   begin
      Read_16 (D, Coe_PTAT31, V);
      Aa := (4.2E-04 * Float (V)) / 32_767.0;
      pragma Assert (abs Aa <= 4.21E-04);
      pragma Assert (if V = 0 then Aa = 0.0 else abs Aa >= 1.28E-08);
      Read_16 (D, Coe_PTAT21, V);
      Ba := (8.0 * Float (V)) / 32_767.0 - 160.0;
      pragma Assert (Ba in -168.01 .. -151.99);
      Read_24 (D, Coe_PTAT11, Ca);
      Read_16 (D, Coe_PR31, V);
      Ap := (3.0E-05 * Float (V)) / 32_767.0;
      pragma Assert (abs Ap <= 3.01E-05);
      pragma Assert (if V = 0 then Ap = 0.0 else abs Ap >= 9.15E-10);
      Read_16 (D, Coe_PR21, V);
      Bp := Float ((10 * V) / 32_767) + 30.0;
      pragma Assert (Bp in 20.0 .. 40.0);
      Read_24 (D, Coe_PR11, Cp);
      Read_16 (D, Coe_TEMP31, V);
      A_T := (8.0E-11 * Float (V)) / 32_767.0;
      pragma Assert (abs A_T <= 8.01E-11);
      Read_16 (D, Coe_TEMP21, V);
      B_T := (1.6E-06 * Float (V)) / 32_767.0 - 6.6E-06;
      pragma Assert (B_T in -8.21E-06 .. -4.99E-06);
      Read_16 (D, Coe_TEMP11, V);
      C_T := (8.5E-03 * Float (V)) / 32_767.0 + 4.0E-02;
      pragma Assert (C_T in 0.031 .. 0.049);
      C := (Aa => Aa, Ba => Ba, Ca => Ca, Ap => Ap, Bp => Bp, Cp => Cp, A_T => A_T, B_T => B_T, C_T => C_T);
   end Configure;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Detected        : Boolean := False;
      Unused_OK       : Boolean;
   begin
      Device := (others => <>);
      Found := False;
      if Is_SPI (D) then
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      end if;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Default_Address);
         Default_Applied := True;
      end if;
      for Attempt in 1 .. Attempts loop
         Read_Byte (D, Identity_Register, S.Chip_Id);
         if S.Chip_Id = Chip_Identity then
            Detected := True;
            exit;
         end if;
         Delay_Ms (D, 50);
      end loop;
      if not Detected then
         if Is_SPI (D) then
            Preinit_CS (D);
         end if;
         if Default_Applied then
            Set_I2C_Address (D, 0);
         end if;
         return;
      end if;
      Configure (D, S.Calibration);
      Write_Register (D, IIR_Register, IIR_8_Samples, Unused_OK);
      Device.Combined_Read := False;
      Device.Temperature_Delay_Us := 0;
      Device.Pressure_Delay_Us := Pressure_Delay_Us;
      Found := True;
   end Detect;

   --  The 24-bit count of three bytes past the midpoint.
   function Mid_24 (B : Byte_Array) return Raw_Delta is
     (I32 (B (B'First)) * 65_536 + I32 (B (B'First + 1)) * 256 + I32 (B (B'First + 2)) - 2 ** 23)
     with Global => null,
          Pre    => B'Length = 3 and then B'First <= Natural'Last - 2;

   --  A finite value over a finite divisor as the reference's single
   --  precision division gives it, with its kinds past the finite range.
   function Divide (Numerator : Float; Denominator : Float) return Real
     with Global => null;

   function Divide (Numerator : Float; Denominator : Float) return Real is
      Q : Long_Float;
   begin
      if Denominator = 0.0 then
         if Numerator = 0.0 then
            return Not_A_Number_Value;
         elsif Numerator > 0.0 then
            return (Plus_Infinity, 0.0);
         else
            return (Minus_Infinity, 0.0);
         end if;
      end if;
      Q := Long_Float (Numerator) / Long_Float (Denominator);
      if Q > Long_Float (Float'Last) then
         return (Plus_Infinity, 0.0);
      elsif Q < -Long_Float (Float'Last) then
         return (Minus_Infinity, 0.0);
      end if;
      return (Finite, Float (Q));
   end Divide;

   --  A finite value over an infinite or undefined divisor.
   function Divide_By_Kind (Numerator : Real; Divisor : Value_Kind) return Real is
     (if Numerator.Kind /= Finite or else Divisor = Not_A_Number then Not_A_Number_Value
      else (Finite, Float'Copy_Sign (0.0, Numerator.Value) * (if Divisor = Minus_Infinity then -1.0 else 1.0)))
     with Global => null,
          Pre    => Divisor /= Finite;

   --  An infinite value over a finite divisor.
   function Infinity_Over (Numerator : Value_Kind; Denominator : Float) return Real is
     (if (Numerator = Plus_Infinity) = (Denominator >= 0.0) then (Plus_Infinity, 0.0) else (Minus_Infinity, 0.0))
     with Global => null,
          Pre    => Numerator in Plus_Infinity | Minus_Infinity;

   --  The root of a discriminant over twice the quadratic coefficient, as
   --  the reference computes the temperature and the raw pressure.
   procedure Solve (Linear : Float; Quadratic : Float; Discriminant : Float; Negated : Boolean; R : out Real)
     with Global => null,
          Pre    => abs Linear <= 170.0 and then abs Quadratic <= 4.21E-04
                    and then (Quadratic = 0.0 or else abs Quadratic >= 9.15E-10)
                    and then Discriminant <= 60_000.0,
          Post   => (if R.Kind = Finite then abs R.Value <= 7.2E+13);

   procedure Solve (Linear : Float; Quadratic : Float; Discriminant : Float; Negated : Boolean; R : out Real) is
   begin
      if Discriminant < 0.0 then
         R := Not_A_Number_Value;
         return;
      end if;
      declare
         Root    : constant Float := Adaflight.Maths.Sqrt_Bounded (Discriminant);
         Num     : constant Float := (if Negated then (-Linear) - Root else Root - Linear);
         Twice   : constant Float := 2.0 * Quadratic;
      begin
         pragma Assert (abs Num <= 66_000.0);
         if Twice = 0.0 then
            if Num = 0.0 then
               R := Not_A_Number_Value;
            elsif Num > 0.0 then
               R := (Plus_Infinity, 0.0);
            else
               R := (Minus_Infinity, 0.0);
            end if;
         else
            pragma Assert (abs Twice >= 1.83E-09);
            R := (Finite, Num / Twice);
         end if;
      end;
   end Solve;

   procedure Compensate (S : in out State)
     with Global => null;

   procedure Compensate (S : in out State) is
      C  : Coefficients renames S.Calibration;
      Dt : constant Raw_Delta := Mid_24 (S.Sensor_Data (3 .. 5));
      Dp : constant Raw_Delta := Mid_24 (S.Sensor_Data (0 .. 2));
      Tr : Real;
      Pl : Real;
   begin
      declare
         Tmp : constant Float := C.Ba * C.Ba;
         Dd  : constant Float := Float (C.Ca - Dt);
      begin
         pragma Assert (abs Dd <= 16_777_216.0);
         pragma Assert (abs (4.0 * C.Aa * Dd) <= 28_300.0);
         Solve (C.Ba, C.Aa, Tmp - 4.0 * C.Aa * Dd, True, Tr);
      end;
      S.Temperature := (if Tr.Kind = Finite then (Finite, Tr.Value / 256.0) else Tr);
      declare
         Tmp : constant Float := C.Bp * C.Bp;
         Dd  : constant Float := Float (C.Cp - Dp);
      begin
         pragma Assert (abs Dd <= 16_777_216.0);
         pragma Assert (abs (4.0 * C.Ap * Dd) <= 2_100.0);
         Solve (C.Bp, C.Ap, Tmp - 4.0 * C.Ap * Dd, False, Pl);
      end;
      case Tr.Kind is
         when Finite =>
            declare
               Tr2   : constant Float := Tr.Value * Tr.Value;
               Denom : constant Float := C.A_T * Tr2 + C.B_T * Tr.Value + C.C_T + 1.0;
            begin
               case Pl.Kind is
                  when Finite =>
                     S.Pressure := Divide (Pl.Value, Denom);
                  when Plus_Infinity | Minus_Infinity =>
                     S.Pressure := Infinity_Over (Pl.Kind, Denom);
                  when Not_A_Number =>
                     S.Pressure := Not_A_Number_Value;
               end case;
            end;
         when Plus_Infinity | Minus_Infinity =>
            --  The polynomial's quadratic term takes the sign of its
            --  coefficient and its linear term, whose coefficient is
            --  negative, the opposite sign of the temperature.
            declare
               Quadratic_Term : constant Value_Kind :=
                 (if C.A_T > 0.0 then Plus_Infinity elsif C.A_T < 0.0 then Minus_Infinity else Not_A_Number);
               Linear_Term    : constant Value_Kind :=
                 (if Tr.Kind = Plus_Infinity then Minus_Infinity else Plus_Infinity);
               Denom          : constant Value_Kind :=
                 (if Quadratic_Term = Linear_Term then Quadratic_Term else Not_A_Number);
            begin
               S.Pressure := Divide_By_Kind (Pl, Denom);
            end;
         when Not_A_Number =>
            S.Pressure := Not_A_Number_Value;
      end case;
   end Compensate;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean)
   is
      Busy         : Boolean;
      Unused_Error : Boolean;
   begin
      case Call is
         when Barometer_Task.Start_Temperature | Barometer_Task.Read_Temperature
            | Barometer_Task.Get_Temperature =>
            Done := True;
         when Barometer_Task.Start_Pressure =>
            Write_Register (D, Control_Register, Forced_4x_32x, Done);
         when Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Start_Read (D, Data_Register, S.Sensor_Data'Length, Done);
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            Compensate (S);
            Done := True;
      end case;
   end Device_Call;

   function Convert (R : Real) return I32 is
     (case R.Kind is
         when Not_A_Number => 0,
         when Plus_Infinity => I32'Last,
         when Minus_Infinity => I32'First,
         when Finite =>
           (if R.Value >= 2_147_483_648.0 then I32'Last
            elsif R.Value <= -2_147_483_648.0 then I32'First
            else I32 (Float'Truncation (R.Value))))
     with Global => null;

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
      T : constant Real := S.Temperature;
   begin
      Pressure := Convert (S.Pressure);
      if T.Kind = Finite and then abs T.Value < 1.0E+36 then
         Temperature := Convert ((Finite, T.Value * 100.0));
      elsif T.Kind = Finite then
         Temperature := (if T.Value > 0.0 then I32'Last else I32'First);
      else
         Temperature := Convert (T);
      end if;
   end Calculate;

end Adaflight.SMPB_02B;
