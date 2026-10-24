package body Adaflight.QMP6988 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Default_Address  : constant Byte := 16#70#;
   Chip_Id_Register : constant Byte := 16#D1#;
   Chip_Identity    : constant Byte := 16#5C#;
   IIR_Register     : constant Byte := 16#F1#;
   IIR_Setting      : constant Byte := 16#05#;
   Measure_Register : constant Byte := 16#F4#;
   Power_Sampling   : constant Byte := 16#7B#;
   Calibration_Base : constant Byte := 16#A0#;
   Pressure_MSB     : constant Byte := 16#F7#;
   Max_SPI_Clock_Hz : constant := 10_000_000;
   Pressure_Delay   : constant := 23_000;
   Midpoint         : constant := 2 ** 23;

   subtype Calibration_Bytes is Byte_Array (0 .. 24);
   subtype Word_Value is Float range 0.0 .. 65_535.0;

   function Word (High : Byte; Low : Byte) return Word_Value is
     (Float (Interfaces.Integer_32 (High) * 256 + Interfaces.Integer_32 (Low)))
     with Global => null;

   function Signed_20 (Value : Interfaces.Integer_32) return Interfaces.Integer_32 is
     (if Value >= 16#8_0000# then Value - 16#10_0000# else Value)
     with Global => null,
          Pre    => Value in 0 .. 16#F_FFFF#,
          Post   => Signed_20'Result in -16#8_0000# .. 16#7_FFFF#;

   --  The whole part toward zero, from the whole part of the magnitude.
   function Cut (X : Float) return Interfaces.Integer_32 is
     (if X >= 0.0 then Interfaces.Integer_32 (Float'Truncation (X))
      else -Interfaces.Integer_32 (Float'Truncation (-X)))
     with Global => null,
          Pre    => X in -2.0E6 .. 2.0E6;

   procedure Parse (OTP : Calibration_Bytes; C : out Coefficients)
     with Global => null
   is
      Temp_1 : constant Interfaces.Integer_32 :=
        Interfaces.Integer_32 (OTP (0)) * 4096 + Interfaces.Integer_32 (OTP (1)) * 16
        + Interfaces.Integer_32 (OTP (24) / 16);
      Temp_2 : constant Interfaces.Integer_32 :=
        Interfaces.Integer_32 (OTP (18)) * 4096 + Interfaces.Integer_32 (OTP (19)) * 16
        + Interfaces.Integer_32 (OTP (24) and 16#0F#);
   begin
      C.A0 := Float (Signed_20 (Temp_2)) / 16.0;
      C.A1 := (-6.30E-03) + 4.30E-04 * Word (OTP (20), OTP (21)) / 32_767.0;
      C.A2 := (-1.9E-11) + 1.2E-10 * Word (OTP (22), OTP (23)) / 32_767.0;
      C.B00 := Float (Signed_20 (Temp_1)) / 16.0;
      C.Bt1 := 1.00E-01 + 9.10E-02 * Word (OTP (2), OTP (3)) / 32_767.0;
      C.Bt2 := 1.20E-08 + 1.20E-06 * Word (OTP (4), OTP (5)) / 32_767.0;
      C.Bp1 := 3.30E-02 + 1.90E-02 * Word (OTP (6), OTP (7)) / 32_767.0;
      C.B11 := 2.10E-07 + 1.40E-07 * Word (OTP (8), OTP (9)) / 32_767.0;
      C.Bp2 := (-6.30E-10) + 3.50E-10 * Word (OTP (10), OTP (11)) / 32_767.0;
      C.B12 := 2.90E-13 + 7.60E-13 * Word (OTP (12), OTP (13)) / 32_767.0;
      C.B21 := 2.10E-15 + 1.20E-14 * Word (OTP (14), OTP (15)) / 32_767.0;
      C.Bp3 := 1.30E-16 + 7.90E-17 * Word (OTP (16), OTP (17)) / 32_767.0;
   end Parse;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Id              : Byte_Array (0 .. 0) := (0 => S.Chip_Id);
      OTP             : Calibration_Bytes := (others => 0);
      Ignored         : Boolean;
   begin
      Device := (others => <>);
      Found := False;
      Delay_Ms (D, 20);
      if Is_SPI (D) then
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      end if;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Default_Address);
         Default_Applied := True;
      end if;
      Read_Registers (D, Chip_Id_Register, Id, Ignored);
      S.Chip_Id := Id (0);
      if S.Chip_Id /= Chip_Identity then
         if Is_SPI (D) then
            Return_CS (D);
         end if;
         if Default_Applied then
            Set_I2C_Address (D, 0);
         end if;
         return;
      end if;
      Register_Device (D);
      Write_Register (D, IIR_Register, IIR_Setting, Ignored);
      Read_Registers (D, Calibration_Base, OTP, Ignored);
      Parse (OTP, S.Calibration);
      Write_Register (D, Measure_Register, Power_Sampling, Ignored);
      Device := (Combined_Read => True, Temperature_Delay_Us => 0, Pressure_Delay_Us => Pressure_Delay);
      Found := True;
   end Detect;

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
            Write_Register (D, Measure_Register, Power_Sampling, Done);
         when Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Start_Read (D, Pressure_MSB, S.Sensor_Data'Length, Done);
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            S.Raw_Pressure :=
              Interfaces.Integer_32 (S.Sensor_Data (0)) * 2 ** 16 + Interfaces.Integer_32 (S.Sensor_Data (1)) * 2 ** 8
              + Interfaces.Integer_32 (S.Sensor_Data (2));
            S.Raw_Temperature :=
              Interfaces.Integer_32 (S.Sensor_Data (3)) * 2 ** 16 + Interfaces.Integer_32 (S.Sensor_Data (4)) * 2 ** 8
              + Interfaces.Integer_32 (S.Sensor_Data (5));
            Done := True;
      end case;
   end Device_Call;

   procedure Calculate
     (S : State; Pressure : in out Interfaces.Integer_32; Temperature : in out Interfaces.Integer_32)
   is
      C    : Coefficients renames S.Calibration;
      Var1 : constant Float := Float (S.Raw_Temperature - Midpoint);
      Dp   : constant Float := Float (S.Raw_Pressure - Midpoint);
      T_A1 : constant Float := C.A1 * Var1;
      T_A2 : constant Float := C.A2 * Var1 * Var1;
      Tr   : Float;
   begin
      pragma Assert (abs T_A1 <= 5.3E4);
      pragma Assert (abs T_A2 <= 1.6E4);
      Tr := C.A0 + T_A1 + T_A2;
      pragma Assert (abs Tr <= 1.1E5);
      declare
         T1 : constant Float := C.Bt1 * Tr;
         T2 : constant Float := C.Bp1 * Dp;
         T3 : constant Float := C.B11 * Tr * Dp;
         T4 : constant Float := C.Bt2 * Tr * Tr;
         T5 : constant Float := C.Bp2 * Dp * Dp;
         T6 : constant Float := C.B12 * Dp * Tr * Tr;
         T7 : constant Float := C.B21 * Dp * Dp * Tr;
         T8 : constant Float := C.Bp3 * Dp * Dp * Dp;
         Pr : Float;
      begin
         pragma Assert (abs T1 <= 3.2E4);
         pragma Assert (abs T2 <= 6.1E5);
         pragma Assert (abs T3 <= 4.6E5);
         pragma Assert (abs T4 <= 3.0E4);
         pragma Assert (abs T5 <= 4.5E4);
         pragma Assert (abs T6 <= 1.9E5);
         pragma Assert (abs T7 <= 2.1E5);
         pragma Assert (abs T8 <= 1.8E5);
         Pr := C.B00 + T1 + T2 + T3 + T4 + T5 + T6 + T7 + T8;
         pragma Assert (abs Pr <= 1.8E6);
         if Pr /= 0.0 then
            Pressure := Cut (Pr);
         end if;
      end;
      if Tr /= 0.0 then
         Temperature := Cut (Tr) / 256;
      end if;
   end Calculate;

end Adaflight.QMP6988;
