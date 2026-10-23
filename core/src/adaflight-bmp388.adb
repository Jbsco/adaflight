package body Adaflight.BMP388 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_64;

   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;
   subtype I32 is Interfaces.Integer_32;
   subtype I64 is Interfaces.Integer_64;

   Default_Address       : constant Byte := 16#76#;
   BMP388_Id             : constant Byte := 16#50#;
   BMP390_Id             : constant Byte := 16#60#;
   Chip_Id_Register      : constant Byte := 16#00#;
   Data_Register         : constant Byte := 16#04#;
   Status_Register       : constant Byte := 16#11#;
   Interrupt_Register    : constant Byte := 16#19#;
   Power_Register        : constant Byte := 16#1B#;
   Oversampling_Register : constant Byte := 16#1C#;
   Calibration_Register  : constant Byte := 16#31#;
   Max_SPI_Clock_Hz      : constant := 10_000_000;
   Frame_Length          : constant := 6;

   --  Pressure oversampling of eight and temperature oversampling of one.
   Pressure_Oversampling    : constant := 3;
   Temperature_Oversampling : constant := 0;
   Oversampling : constant Byte := (Pressure_Oversampling and 16#03#) or (Temperature_Oversampling * 8 and 16#38#);

   --  The data ready interrupt, active high.
   Interrupt_Setting : constant Byte := 2 ** 6 + 2 ** 1;

   --  Forced mode with the pressure and temperature measurements enabled.
   Forced_Measurement : constant Byte := 1 * 16 + 2 + 1;

   --  The datasheet's measurement time for those settings.
   Pressure_Delay_Us : constant :=
     234 + (392 + 2 ** (Pressure_Oversampling + 1) * 2000) + (313 + 2 ** (Temperature_Oversampling + 1) * 2000);

   function Known (Id : Byte) return Boolean is (Id = BMP388_Id or else Id = BMP390_Id);

   --  A register read. A chip on SPI sends a dummy byte first, which the
   --  read takes and drops.
   procedure Read (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Pre => Data'Length in 1 .. Calibration_Bytes'Length
   is
   begin
      if Is_SPI (D) then
         declare
            Buffer : Byte_Array (0 .. Data'Length) := (others => 0);
         begin
            Read_Registers (D, Register, Buffer, OK);
            if OK then
               Data := Buffer (1 .. Buffer'Last);
            end if;
         end;
      else
         Read_Registers (D, Register, Data, OK);
      end if;
   end Read;

   procedure Detect
     (D       : in out Bus_Device;
      S       : in out State;
      EOC_Pin : Boolean;
      Found   : out Boolean;
      Device  : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Id              : Byte_Array (0 .. 0);
      Busy            : Boolean;
      Unused_OK       : Boolean;
      Unused_Started  : Boolean;
      Unused_Error    : Boolean;
   begin
      Device := (others => <>);
      Found := False;
      Delay_Ms (D, 20);
      if EOC_Pin then
         Enable_EOC_Interrupt (D);
      end if;
      if Is_SPI (D) then
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      end if;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Default_Address);
         Default_Applied := True;
      end if;
      if Is_SPI (D) then
         S.Dummy_Byte := True;
      end if;
      Id := (0 => S.Chip_Id);
      Read (D, Chip_Id_Register, Id, Unused_OK);
      S.Chip_Id := Id (0);
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
      if EOC_Pin then
         Write_Register (D, Interrupt_Register, Interrupt_Setting, Unused_OK);
      end if;
      Read (D, Calibration_Register, S.Calibration, Unused_OK);
      Write_Register (D, Oversampling_Register, Oversampling, Unused_OK);
      Start_Write (D, Power_Register, Forced_Measurement, Unused_Started);
      Device := (Combined_Read => False, Temperature_Delay_Us => 0, Pressure_Delay_Us => Pressure_Delay_Us);
      loop
         Check_Busy (D, Busy, Unused_Error);
         exit when not Busy;
      end loop;
      Found := True;
   end Detect;

   function Reading (Data : Frame_Bytes; First : Natural) return Raw_Reading is
     (Raw_Reading (U32 (Data (First)) + 256 * U32 (Data (First + 1)) + 65_536 * U32 (Data (First + 2))))
     with Pre => First <= 4;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean)
   is
      First        : constant Natural := (if S.Dummy_Byte then 1 else 0);
      Busy         : Boolean;
      Unused_Error : Boolean;
   begin
      case Call is
         when Barometer_Task.Start_Temperature | Barometer_Task.Read_Temperature
            | Barometer_Task.Get_Temperature =>
            Done := True;
         when Barometer_Task.Start_Pressure =>
            Start_Write (D, Power_Register, Forced_Measurement, Done);
         when Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Start_Read (D, Data_Register, Frame_Length + First, Done);
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            S.Raw_Pressure := Reading (S.Sensor_Data, First);
            S.Raw_Temperature := Reading (S.Sensor_Data, First + 3);
            Done := True;
      end case;
   end Device_Call;

   procedure Interrupt (D : in out Bus_Device) is
      Unused_Status : Byte_Array (0 .. 0) := (0 => 0);
      Unused_OK     : Boolean;
   begin
      Read (D, Status_Register, Unused_Status, Unused_OK);
   end Interrupt;

   --  The two's complement images of signed values and back.
   function Image_64 (V : I64) return U64 is
     (if V >= 0 then U64 (V) else U64'Last - U64 (-(V + 1)));
   function Value_64 (W : U64) return I64 is
     (if W <= 16#7FFF_FFFF_FFFF_FFFF# then I64 (W) else -I64 (U64'Last - W) - 1);

   --  A signed quotient by a positive constant, truncated toward zero.
   function Quotient (N : U64; D : I64) return U64 is
     (Image_64 (Value_64 (N) / D))
     with Pre => D > 0;

   function Unsigned_16_At (C : Calibration_Bytes; I : Natural) return I64 is
     (I64 (C (I)) + 256 * I64 (C (I + 1)))
     with Pre => I <= 19;
   function Signed_16_At (C : Calibration_Bytes; I : Natural) return I64 is
     (if Unsigned_16_At (C, I) >= 32_768 then Unsigned_16_At (C, I) - 65_536 else Unsigned_16_At (C, I))
     with Pre => I <= 19;
   function Signed_8_At (C : Calibration_Bytes; I : Natural) return I64 is
     (if C (I) >= 128 then I64 (C (I)) - 256 else I64 (C (I)))
     with Pre => I <= 20;

   subtype Linear_Temperature is I64 range -2 ** 31 .. 2 ** 31 - 1;
   subtype Temperature_Range is I64 range -3_276_800 .. 3_276_799;

   procedure Compensate_Temperature
     (Raw         : Raw_Reading;
      C           : Calibration_Bytes;
      T_Lin       : out Linear_Temperature;
      Temperature : out Temperature_Range)
     with Global => null
   is
      T1  : constant U32 := U32 (Unsigned_16_At (C, 0));
      T2  : constant U64 := U64 (Unsigned_16_At (C, 2));
      T3  : constant U64 := Image_64 (Signed_8_At (C, 4));
      PD1 : constant U64 := U64 (Raw - 256 * T1);
      PD2 : constant U64 := T2 * PD1;
      PD3 : constant U64 := PD1 * PD1;
      PD4 : constant U64 := PD3 * T3;
      PD5 : constant U64 := PD2 * 262_144 + PD4;
   begin
      T_Lin := Value_64 (PD5) / 4_294_967_296;
      Temperature := T_Lin * 25 / 16_384;
   end Compensate_Temperature;

   function Compensate_Pressure (Raw : Raw_Reading; C : Calibration_Bytes; T_Lin : Linear_Temperature) return U64
     with Global => null,
          Post   => Compensate_Pressure'Result < 2 ** 24
   is
      T           : constant U64 := Image_64 (T_Lin);
      UP          : constant U64 := U64 (Raw);
      P1          : constant U64 := Image_64 (Signed_16_At (C, 5));
      P2          : constant U64 := Image_64 (Signed_16_At (C, 7));
      P3          : constant U64 := Image_64 (Signed_8_At (C, 9));
      P4          : constant U64 := Image_64 (Signed_8_At (C, 10));
      P5          : constant U64 := U64 (Unsigned_16_At (C, 11));
      P6          : constant U64 := U64 (Unsigned_16_At (C, 13));
      P7          : constant U64 := Image_64 (Signed_8_At (C, 15));
      P8          : constant U64 := Image_64 (Signed_8_At (C, 16));
      P9          : constant U64 := Image_64 (Signed_16_At (C, 17));
      P10         : constant U64 := Image_64 (Signed_8_At (C, 19));
      P11         : constant U64 := Image_64 (Signed_8_At (C, 20));
      PD1         : U64;
      PD2         : U64;
      PD3         : U64;
      PD4         : U64;
      PD5         : U64;
      PD6         : U64;
      Offset      : U64;
      Sensitivity : U64;
   begin
      PD1 := T * T;
      PD2 := Quotient (PD1, 64);
      PD3 := Quotient (PD2 * T, 256);
      PD4 := Quotient (P8 * PD3, 32);
      PD5 := P7 * PD1 * 16;
      PD6 := P6 * T * 4_194_304;
      Offset := P5 * 140_737_488_355_328 + PD4 + PD5 + PD6;
      PD2 := Quotient (P4 * PD3, 32);
      PD4 := P3 * PD1 * 4;
      PD5 := (P2 - 16_384) * T * 2_097_152;
      Sensitivity := (P1 - 16_384) * 70_368_744_177_664 + PD2 + PD4 + PD5;
      PD1 := Quotient (Sensitivity, 16_777_216) * UP;
      PD2 := P10 * T;
      PD3 := PD2 + 65_536 * P9;
      PD4 := Quotient (PD3 * UP, 8_192);
      PD5 := Quotient (PD4 * UP, 512);
      PD6 := UP * UP;
      PD2 := Quotient (P11 * PD6, 65_536);
      PD3 := Quotient (PD2 * UP, 128);
      PD4 := Quotient (Offset, 4) + PD1 + PD5 + PD3;
      return PD4 * 25 / 1_099_511_627_776;
   end Compensate_Pressure;

   procedure Calculate
     (S           : State;
      Pressure    : out Interfaces.Integer_32;
      Temperature : out Interfaces.Integer_32)
   is
      T_Lin : Linear_Temperature;
      Temp  : Temperature_Range;
   begin
      Compensate_Temperature (S.Raw_Temperature, S.Calibration, T_Lin, Temp);
      Pressure := I32 (I64 (Compensate_Pressure (S.Raw_Pressure, S.Calibration, T_Lin)) / 256);
      Temperature := I32 (Temp);
   end Calculate;

end Adaflight.BMP388;
