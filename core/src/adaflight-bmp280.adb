package body Adaflight.BMP280 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_64;
   use type Barometer_Task.Device_Call;

   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;
   subtype I32 is Interfaces.Integer_32;
   subtype I64 is Interfaces.Integer_64;

   Default_Address      : constant Byte := 16#76#;
   Second_Address       : constant Byte := 16#77#;
   BMP280_Id            : constant Byte := 16#58#;
   BME280_Id            : constant Byte := 16#60#;
   Chip_Id_Register     : constant Byte := 16#D0#;
   Control_Register     : constant Byte := 16#F4#;
   Data_Register        : constant Byte := 16#F7#;
   Calibration_Register : constant Byte := 16#88#;
   Max_SPI_Clock_Hz     : constant := 10_000_000;

   --  Pressure oversampling of eight, temperature oversampling of one,
   --  forced mode.
   Mode : constant Byte := 4 * 4 + 1 * 32 + 1;

   --  The datasheet's longest conversion for those settings, rounded down to
   --  sixteenths of a millisecond after a margin.
   Pressure_Delay_Us : constant := ((20 + 37 * (1 + 8) + 10 + 15) / 16) * 1000;

   function Known (Id : Byte) return Boolean is (Id = BMP280_Id or else Id = BME280_Id);

   --  The two's complement images of signed values and back.
   function Image_32 (V : I32) return U32 is
     (if V >= 0 then U32 (V) else U32'Last - U32 (-(I64 (V) + 1)));

   function Value_32 (W : U32) return I32 is
     (if W <= 16#7FFF_FFFF# then I32 (W) else I32 (-I64 (U32'Last - W) - 1));

   function Image_64 (V : I64) return U64 is
     (if V >= 0 then U64 (V) else U64'Last - U64 (-(V + 1)));

   function Value_64 (W : U64) return I64 is
     (if W <= 16#7FFF_FFFF_FFFF_FFFF# then I64 (W) else -I64 (U64'Last - W) - 1);

   function Unsigned_At (C : Calibration_Bytes; I : Natural) return I64 is
     (I64 (C (I)) + 256 * I64 (C (I + 1)))
     with Pre => I <= 22;

   function Signed_At (C : Calibration_Bytes; I : Natural) return I64 is
     (if Unsigned_At (C, I) >= 32768 then Unsigned_At (C, I) - 65536 else Unsigned_At (C, I))
     with Pre => I <= 22;

   --  A 64-bit signed division that truncates toward zero, whose one
   --  overflowing case wraps as the hardware's division does.
   function Divide (N : U64; D : U64) return U64
     with Global => null,
          Pre    => D /= 0
   is
   begin
      if Value_64 (D) = -1 then
         return 0 - N;
      end if;
      return Image_64 (Value_64 (N) / Value_64 (D));
   end Divide;

   procedure Compensate_Temperature (S : in out State; Temperature : out I32)
     with Global => null
   is
      ADC  : constant U32 := Image_32 (S.Raw_Temperature);
      T1   : constant U32 := Image_32 (I32 (Unsigned_At (S.Calibration, 0)));
      T2   : constant U32 := Image_32 (I32 (Signed_At (S.Calibration, 2)));
      T3   : constant U32 := Image_32 (I32 (Signed_At (S.Calibration, 4)));
      Var1 : U32;
      Var2 : U32;
      Diff : U32;
      Fine : U32;
   begin
      Var1 := Interfaces.Shift_Right_Arithmetic
        ((Interfaces.Shift_Right_Arithmetic (ADC, 3) - Interfaces.Shift_Left (T1, 1)) * T2, 11);
      Diff := Interfaces.Shift_Right_Arithmetic (ADC, 4) - T1;
      Var2 := Interfaces.Shift_Right_Arithmetic (Interfaces.Shift_Right_Arithmetic (Diff * Diff, 12) * T3, 14);
      Fine := Var1 + Var2;
      S.T_Fine := Value_32 (Fine);
      Temperature := Value_32 (Interfaces.Shift_Right_Arithmetic (Fine * 5 + 128, 8));
   end Compensate_Temperature;

   function Compensate_Pressure (S : State) return U32
     with Global => null
   is
      ADC  : constant U64 := Image_64 (I64 (S.Raw_Pressure));
      P1   : constant U64 := Image_64 (Unsigned_At (S.Calibration, 6));
      P2   : constant U64 := Image_64 (Signed_At (S.Calibration, 8));
      P3   : constant U64 := Image_64 (Signed_At (S.Calibration, 10));
      P4   : constant U64 := Image_64 (Signed_At (S.Calibration, 12));
      P5   : constant U64 := Image_64 (Signed_At (S.Calibration, 14));
      P6   : constant U64 := Image_64 (Signed_At (S.Calibration, 16));
      P7   : constant U64 := Image_64 (Signed_At (S.Calibration, 18));
      P8   : constant U64 := Image_64 (Signed_At (S.Calibration, 20));
      P9   : constant U64 := Image_64 (Signed_At (S.Calibration, 22));
      Var1 : U64;
      Var2 : U64;
      P    : U64;
   begin
      Var1 := Image_64 (I64 (S.T_Fine)) - 128_000;
      Var2 := Var1 * Var1 * P6;
      Var2 := Var2 + Interfaces.Shift_Left (Var1 * P5, 17);
      Var2 := Var2 + Interfaces.Shift_Left (P4, 35);
      Var1 := Interfaces.Shift_Right_Arithmetic (Var1 * Var1 * P3, 8) + Interfaces.Shift_Left (Var1 * P2, 12);
      Var1 := Interfaces.Shift_Right_Arithmetic ((Interfaces.Shift_Left (1, 47) + Var1) * P1, 33);
      if Var1 = 0 then
         return 0;
      end if;
      P := 1_048_576 - ADC;
      P := Divide ((Interfaces.Shift_Left (P, 31) - Var2) * 3125, Var1);
      Var1 := Interfaces.Shift_Right_Arithmetic
        (P9 * Interfaces.Shift_Right_Arithmetic (P, 13) * Interfaces.Shift_Right_Arithmetic (P, 13), 25);
      Var2 := Interfaces.Shift_Right_Arithmetic (P8 * P, 19);
      P := Interfaces.Shift_Right_Arithmetic (P + Var1 + Var2, 8) + Interfaces.Shift_Left (P7, 4);
      return U32 (P and 16#FFFF_FFFF#);
   end Compensate_Pressure;

   function Reading (High, Middle, Low : Byte) return Raw_Reading is
     (Raw_Reading (Interfaces.Shift_Left (U32 (High), 12) or Interfaces.Shift_Left (U32 (Middle), 4)
                   or Interfaces.Shift_Right (U32 (Low), 4)));

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Id              : Byte_Array (0 .. 0);
      Unused_OK       : Boolean;
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
      S.Chip_Id := 0;
      S.Sample_Valid := False;
      Id := (0 => S.Chip_Id);
      Read_Registers (D, Chip_Id_Register, Id, Unused_OK);
      S.Chip_Id := Id (0);
      if not Known (S.Chip_Id) and then Default_Applied and then Is_I2C (D) then
         Set_I2C_Address (D, Second_Address);
         S.Chip_Id := 0;
         Id := (0 => S.Chip_Id);
         Read_Registers (D, Chip_Id_Register, Id, Unused_OK);
         S.Chip_Id := Id (0);
      end if;
      if not Known (S.Chip_Id) then
         if Is_SPI (D) then
            Release_SPI (D);
         end if;
         if Default_Applied then
            Set_I2C_Address (D, 0);
         end if;
         return;
      end if;
      Register_Device (D);
      Read_Registers (D, Calibration_Register, S.Calibration, Unused_OK);
      Write_Register (D, Control_Register, Mode, Unused_OK);
      Device := (Combined_Read => True, Temperature_Delay_Us => 0, Pressure_Delay_Us => Pressure_Delay_Us);
      Found := True;
   end Detect;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean)
   is
      Busy         : Boolean;
      Error        : Boolean;
      Unused_Error : Boolean;
   begin
      case Call is
         when Barometer_Task.Start_Temperature | Barometer_Task.Read_Temperature
            | Barometer_Task.Get_Temperature =>
            Done := True;
         when Barometer_Task.Start_Pressure =>
            Start_Write (D, Control_Register, Mode, Done);
         when Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Start_Read (D, Data_Register, S.Sensor_Data'Length, Done);
            if Done then
               S.Sample_Valid := False;
            end if;
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Error);
            if Busy then
               Done := False;
               return;
            end if;
            Done := True;
            if Error then
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            S.Raw_Pressure := Reading (S.Sensor_Data (0), S.Sensor_Data (1), S.Sensor_Data (2));
            S.Raw_Temperature := Reading (S.Sensor_Data (3), S.Sensor_Data (4), S.Sensor_Data (5));
            S.Sample_Valid := True;
      end case;
   end Device_Call;

   procedure Calculate
     (S           : in out State;
      Pressure    : out Interfaces.Integer_32;
      Temperature : in out Interfaces.Integer_32)
   is
      T : I32;
   begin
      if not S.Sample_Valid then
         Pressure := 0;
         return;
      end if;
      Compensate_Temperature (S, T);
      Pressure := I32 (Compensate_Pressure (S) / 256);
      Temperature := T;
   end Calculate;

end Adaflight.BMP280;
