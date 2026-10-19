package body Adaflight.BMP085 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;

   subtype I32 is Interfaces.Integer_32;
   subtype U32 is Interfaces.Unsigned_32;

   Default_Address     : constant Byte := 16#77#;
   Chip_Identity       : constant Byte := 16#55#;
   Chip_Id_Register    : constant Byte := 16#D0#;
   Version_Register    : constant Byte := 16#D1#;
   Calibration_Start   : constant Byte := 16#AA#;
   Control_Register    : constant Byte := 16#F4#;
   Data_Register       : constant Byte := 16#F6#;
   Temperature_Measure : constant Byte := 16#2E#;
   Pressure_Measure    : constant Byte := 16#34#;
   Oversampling        : constant := 3;
   Temperature_Delay   : constant := 6_000;
   Pressure_Delay      : constant := 27_000;
   Param_MG            : constant := 3_038;
   Param_MH            : constant := -7_357;
   Param_MI            : constant := 3_791;

   function To_U32 (X : I32) return U32 is
     (if X >= 0 then U32 (X) else U32 (X + 2_147_483_647 + 1) + 2 ** 31)
     with Global => null;

   function To_I32 (U : U32) return I32 is
     (if U < 2 ** 31 then I32 (U) else I32 (U - 2 ** 31) - 2_147_483_647 - 1)
     with Global => null;

   --  Sums and products that wrap at 32 bits, as the processor computes them.
   function Wrap_Add (A : I32; B : I32) return I32 is (To_I32 (To_U32 (A) + To_U32 (B)))
     with Global => null;

   function Wrap_Mul (A : I32; B : I32) return I32 is (To_I32 (To_U32 (A) * To_U32 (B)))
     with Global => null;

   --  The arithmetic right shift, the floor of the division by the power of
   --  two, through the division of a non-negative value.
   function Shift (X : I32; Divisor : I32) return I32 is
     (if X >= 0 then X / Divisor else -((-(X + 1)) / Divisor) - 1)
     with Global => null,
          Pre    => Divisor >= 1;

   --  The quotient of the ARM processor's division, zero for a zero divisor.
   function Divide (A : I32; B : I32) return I32 is
     (if B = 0 then 0 elsif A = I32'First and then B = -1 then I32'First else A / B)
     with Global => null;

   function Divide (A : U32; B : U32) return U32 is (if B = 0 then 0 else A / B)
     with Global => null;

   subtype Calibration_Bytes is Byte_Array (0 .. 21);

   procedure Parse (Data : Calibration_Bytes; C : out Calibration)
     with Global => null
   is
      function Signed (I : Natural) return Interfaces.Integer_16 is
        (if Data (I) >= 128 then Interfaces.Integer_16 (Integer (Data (I)) * 256 + Integer (Data (I + 1)) - 65_536)
         else Interfaces.Integer_16 (Integer (Data (I)) * 256 + Integer (Data (I + 1))))
        with Pre => I <= 20;
      function Unsigned (I : Natural) return Interfaces.Unsigned_16 is
        (Interfaces.Unsigned_16 (Data (I)) * 256 + Interfaces.Unsigned_16 (Data (I + 1)))
        with Pre => I <= 20;
   begin
      C := (AC1 => Signed (0), AC2 => Signed (2), AC3 => Signed (4), AC4 => Unsigned (6), AC5 => Unsigned (8),
            AC6 => Unsigned (10), B1 => Signed (12), B2 => Signed (14), MB => Signed (16), MC => Signed (18),
            MD => Signed (20));
   end Parse;

   procedure Start_Temperature (D : in out Bus_Device; S : in out State; Started : out Boolean) is
   begin
      S.Conversion_Complete := False;
      Start_Write (D, Control_Register, Temperature_Measure, Started);
   end Start_Temperature;

   procedure Test_EOC (D : in out Bus_Device; C : Config; S : in out State; Connected : out Boolean) is
      High    : Boolean;
      Ignored : Boolean;
   begin
      Connected := False;
      if S.Init_Done or else C.EOC_Tag = 0 then
         return;
      end if;
      Read_Pin (D, C.EOC_Tag, High);
      if High then
         return;
      end if;
      Start_Temperature (D, S, Ignored);
      Delay_Us (D, Temperature_Delay * 2);
      Read_Pin (D, C.EOC_Tag, High);
      Connected := High;
   end Test_EOC;

   procedure Detect
     (D      : in out Bus_Device;
      C      : Config;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Id              : Byte_Array (0 .. 0) := (0 => 0);
      Cal_Data        : Calibration_Bytes := (others => 0);
      Connected       : Boolean;
      OK              : Boolean;
      Ignored         : Boolean;
   begin
      Device := (others => <>);
      if S.Init_Done then
         Found := True;
         return;
      end if;
      Init_Pin (D, C.XCLR_Tag, XCLR_Owner);
      Config_Pin (D, C.XCLR_Tag);
      Pin_High (D, C.XCLR_Tag);
      Init_Pin (D, C.EOC_Tag, EOC_Owner);
      Interrupt_Init (D);
      Interrupt_Config (D, C.EOC_Tag);
      Interrupt_Enable (D, C.EOC_Tag);
      Delay_Ms (D, 20);
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Default_Address);
         Default_Applied := True;
      end if;
      Read_Registers (D, Chip_Id_Register, Id, OK);
      if OK then
         S.Chip_Id := Id (0);
         if S.Chip_Id = Chip_Identity then
            Register_Device (D);
            Read_Registers (D, Version_Register, Id, Ignored);
            S.Version := Id (0);
            Read_Registers (D, Calibration_Start, Cal_Data, Ignored);
            Parse (Cal_Data, S.Cal);
            Device :=
              (Combined_Read => False, Temperature_Delay_Us => Temperature_Delay, Pressure_Delay_Us => Pressure_Delay);
            Test_EOC (D, C, S, Connected);
            S.EOC_Connected := Connected;
            S.Init_Done := True;
            Found := True;
            return;
         end if;
      end if;
      if C.EOC_Tag /= 0 then
         Release_Pin (D, C.EOC_Tag);
         Interrupt_Release (D, C.EOC_Tag);
      end if;
      Pin_Low (D, C.XCLR_Tag);
      if Default_Applied then
         Set_I2C_Address (D, 0);
      end if;
      Found := False;
   end Detect;

   procedure Conversion_Ended (S : in out State) is
   begin
      S.Conversion_Complete := True;
   end Conversion_Ended;

   procedure Read_Data (D : in out Bus_Device; S : State; Length : Positive; Done : out Boolean) is
      Busy         : Boolean;
      Unused_Error : Boolean;
   begin
      Check_Busy (D, Busy, Unused_Error);
      if Busy or else (S.EOC_Connected and then not S.Conversion_Complete) then
         Done := False;
         return;
      end if;
      Start_Read (D, Data_Register, Length, Done);
   end Read_Data;

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
         when Barometer_Task.Start_Temperature =>
            Start_Temperature (D, S, Done);
         when Barometer_Task.Read_Temperature =>
            Read_Data (D, S, 2, Done);
         when Barometer_Task.Get_Temperature =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data (0 .. 1));
            S.UT := Interfaces.Unsigned_16 (S.Sensor_Data (0)) * 256 + Interfaces.Unsigned_16 (S.Sensor_Data (1));
            Done := True;
         when Barometer_Task.Start_Pressure =>
            S.Conversion_Complete := False;
            Start_Write (D, Control_Register, Pressure_Measure + Oversampling * 64, Done);
         when Barometer_Task.Read_Pressure =>
            Read_Data (D, S, 3, Done);
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            S.UP :=
              (U32 (S.Sensor_Data (0)) * 2 ** 16 + U32 (S.Sensor_Data (1)) * 2 ** 8 + U32 (S.Sensor_Data (2)))
              / 2 ** (8 - Oversampling);
            Done := True;
      end case;
   end Device_Call;

   procedure Calculate
     (S : in out State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32)
   is
      X1, X2, X3, B3, B6, P : I32;
      B4, B7                : U32;
   begin
      X1 := Shift (Wrap_Mul (I32 (S.UT) - I32 (S.Cal.AC6), I32 (S.Cal.AC5)), 2 ** 15);
      X2 := Divide (I32 (S.Cal.MC) * 2 ** 11, Wrap_Add (X1, I32 (S.Cal.MD)));
      S.B5 := Wrap_Add (X1, X2);
      Temperature := Shift (Wrap_Add (Wrap_Mul (S.B5, 10), 8), 2 ** 4);
      B6 := Wrap_Add (S.B5, -4_000);
      X1 := Shift (Wrap_Mul (B6, B6), 2 ** 12);
      X1 := Wrap_Mul (X1, I32 (S.Cal.B2));
      X1 := Shift (X1, 2 ** 11);
      X2 := Shift (Wrap_Mul (I32 (S.Cal.AC2), B6), 2 ** 11);
      X3 := Wrap_Add (X1, X2);
      B3 := Shift (Wrap_Add (Wrap_Mul (Wrap_Add (I32 (S.Cal.AC1) * 4, X3), 2 ** Oversampling), 2), 2 ** 2);
      X1 := Shift (Wrap_Mul (I32 (S.Cal.AC3), B6), 2 ** 13);
      X2 := Shift (Wrap_Mul (I32 (S.Cal.B1), Shift (Wrap_Mul (B6, B6), 2 ** 12)), 2 ** 16);
      X3 := Shift (Wrap_Add (Wrap_Add (X1, X2), 2), 2 ** 2);
      B4 := (U32 (S.Cal.AC4) * To_U32 (Wrap_Add (X3, 32_768))) / 2 ** 15;
      B7 := (U32 (S.UP) - To_U32 (B3)) * (50_000 / 2 ** Oversampling);
      if B7 < 2 ** 31 then
         P := To_I32 (Divide (B7 * 2, B4));
      else
         P := To_I32 (Divide (B7, B4) * 2);
      end if;
      X1 := Shift (P, 2 ** 8);
      X1 := Wrap_Mul (X1, X1);
      X1 := Shift (Wrap_Mul (X1, Param_MG), 2 ** 16);
      X2 := Shift (Wrap_Mul (P, Param_MH), 2 ** 16);
      Pressure := Wrap_Add (P, Shift (Wrap_Add (Wrap_Add (X1, X2), Param_MI), 2 ** 4));
   end Calculate;

end Adaflight.BMP085;
