package body Adaflight.DPS310 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype I32 is Interfaces.Integer_32;
   subtype U32 is Interfaces.Unsigned_32;

   Default_Address      : constant Byte := 16#76#;
   DPS310_Id            : constant Byte := 16#10#;
   SPL07_Id             : constant Byte := 16#11#;
   Data_Register        : constant Byte := 16#00#;
   Pressure_Config      : constant Byte := 16#06#;
   Temperature_Config   : constant Byte := 16#07#;
   Measure_Config       : constant Byte := 16#08#;
   Config_Register      : constant Byte := 16#09#;
   Reset_Register       : constant Byte := 16#0C#;
   Id_Register          : constant Byte := 16#0D#;
   Coefficient_Register : constant Byte := 16#10#;
   Coefficient_Source   : constant Byte := 16#28#;
   Max_SPI_Clock_Hz     : constant := 10_000_000;

   Soft_Reset          : constant Byte := 16#09#;
   Coefficients_Ready  : constant Byte := 16#80#;
   Sensor_Ready        : constant Byte := 16#40#;
   Continuous          : constant Byte := 16#07#;
   Rate_32_Hz_16_Times : constant Byte := 16#50# or 16#04#;
   External_Sensor     : constant Byte := 16#80#;
   Shifts              : constant Byte := 16#08# or 16#04#;

   Detection_Tries : constant := 5;
   Chunk_Length    : constant := 9;

   --  The raw readings over the scale factor for sixteen times
   --  oversampling.
   Scale : constant Float := 253_952.0;
   subtype Scaled is Float range -34.0 .. 34.0;

   subtype Coefficient_Bytes is Byte_Array (0 .. 21);

   function Is_SPL07 (S : State) return Boolean is (S.Chip_Id = SPL07_Id);

   --  Fields of 12, 16, 20 and 24 bits read as two's complement.
   function Signed_12 (Raw : U32) return I32 is
     (if Raw >= 2 ** 11 then I32 (Raw) - 2 ** 12 else I32 (Raw))
     with Pre  => Raw < 2 ** 12,
          Post => Signed_12'Result in -2 ** 11 .. 2 ** 11 - 1;

   function Signed_16 (Raw : U32) return I32 is
     (if Raw >= 2 ** 15 then I32 (Raw) - 2 ** 16 else I32 (Raw))
     with Pre  => Raw < 2 ** 16,
          Post => Signed_16'Result in -2 ** 15 .. 2 ** 15 - 1;

   function Signed_20 (Raw : U32) return I32 is
     (if Raw >= 2 ** 19 then I32 (Raw) - 2 ** 20 else I32 (Raw))
     with Pre  => Raw < 2 ** 20,
          Post => Signed_20'Result in -2 ** 19 .. 2 ** 19 - 1;

   subtype Reading_Value is I32 range -2 ** 23 .. 2 ** 23 - 1;

   function Signed_24 (Raw : U32) return Reading_Value is
     (if Raw >= 2 ** 23 then I32 (Raw) - 2 ** 24 else I32 (Raw))
     with Pre => Raw < 2 ** 24;

   procedure Read_Register (D : in out Bus_Device; Register : Byte; Value : out Byte)
     with Global => null
   is
      Data      : Byte_Array (0 .. 0) := (0 => 0);
      Unused_OK : Boolean;
   begin
      Read_Registers (D, Register, Data, Unused_OK);
      Value := Data (0);
   end Read_Register;

   --  Sets bits of a register with a read and, where any is clear, a write.
   procedure Set_Bits (D : in out Bus_Device; Register : Byte; Bits : Byte)
     with Global => null
   is
      Value     : Byte;
      Unused_OK : Boolean;
   begin
      Read_Register (D, Register, Value);
      if (Value and Bits) /= Bits then
         Write_Register (D, Register, Value or Bits, Unused_OK);
      end if;
   end Set_Bits;

   procedure Identify (D : in out Bus_Device; S : in out State; Found : out Boolean)
     with Global => null
   is
      Id  : Byte_Array (0 .. 0);
      Ack : Boolean;
   begin
      for Try in 1 .. Detection_Tries loop
         Delay_Ms (D, 100);
         Id := (0 => S.Chip_Id);
         Read_Registers (D, Id_Register, Id, Ack);
         S.Chip_Id := Id (0);
         if Ack and then (S.Chip_Id = DPS310_Id or else S.Chip_Id = SPL07_Id) then
            Found := True;
            return;
         end if;
      end loop;
      Found := False;
   end Identify;

   procedure Parse (C : Coefficient_Bytes; SPL07 : Boolean; K : out Coefficients)
     with Global => null
   is
      function B (I : Natural) return U32 is (U32 (C (I)))
        with Pre => I <= 21;
   begin
      K.C0 := Signed_12 (Interfaces.Shift_Left (B (0), 4) or (Interfaces.Shift_Right (B (1), 4) and 16#0F#));
      K.C1 := Signed_12 (Interfaces.Shift_Left (B (1) and 16#0F#, 8) or B (2));
      K.C00 := Signed_20
        (Interfaces.Shift_Left (B (3), 12) or Interfaces.Shift_Left (B (4), 4)
         or (Interfaces.Shift_Right (B (5), 4) and 16#0F#));
      K.C10 := Signed_20
        (Interfaces.Shift_Left (B (5) and 16#0F#, 16) or Interfaces.Shift_Left (B (6), 8) or B (7));
      K.C01 := Signed_16 (Interfaces.Shift_Left (B (8), 8) or B (9));
      K.C11 := Signed_16 (Interfaces.Shift_Left (B (10), 8) or B (11));
      K.C20 := Signed_16 (Interfaces.Shift_Left (B (12), 8) or B (13));
      K.C21 := Signed_16 (Interfaces.Shift_Left (B (14), 8) or B (15));
      K.C30 := Signed_16 (Interfaces.Shift_Left (B (16), 8) or B (17));
      if SPL07 then
         K.C31 := Signed_12 (Interfaces.Shift_Left (B (18), 4) or (Interfaces.Shift_Right (B (19), 4) and 16#0F#));
         K.C40 := Signed_12 (Interfaces.Shift_Left (B (19) and 16#0F#, 8) or B (20));
      else
         K.C31 := 0;
         K.C40 := 0;
      end if;
   end Parse;

   procedure Configure (D : in out Bus_Device; S : in out State; OK : out Boolean)
     with Global => null
   is
      Status     : Byte;
      Source     : Byte;
      Length     : constant Natural := (if Is_SPL07 (S) then 22 else 18);
      Coef       : Coefficient_Bytes := (others => 0);
      First      : Natural := 0;
      Chunk      : Natural;
      Ack        : Boolean;
   begin
      Set_Bits (D, Reset_Register, Soft_Reset);
      Delay_Ms (D, 40);
      Read_Register (D, Measure_Config, Status);
      if (Status and Coefficients_Ready) = 0 or else (Status and Sensor_Ready) = 0 then
         OK := False;
         return;
      end if;
      while First < Length loop
         pragma Loop_Invariant (First < Length);
         Chunk := Natural'Min (Chunk_Length, Length - First);
         Read_Registers (D, Coefficient_Register + Byte (First), Coef (First .. First + Chunk - 1), Ack);
         if not Ack then
            OK := False;
            return;
         end if;
         First := First + Chunk;
      end loop;
      Parse (Coef, Is_SPL07 (S), S.Calibration);
      Set_Bits (D, Pressure_Config, Rate_32_Hz_16_Times);
      if Is_SPL07 (S) then
         Set_Bits (D, Temperature_Config, Rate_32_Hz_16_Times);
      else
         Read_Register (D, Coefficient_Source, Source);
         Set_Bits (D, Temperature_Config, Rate_32_Hz_16_Times or (Source and External_Sensor));
      end if;
      Set_Bits (D, Config_Register, Shifts);
      Set_Bits (D, Measure_Config, Continuous);
      OK := True;
   end Configure;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      OK              : Boolean;
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
      Identify (D, S, OK);
      if not OK then
         if Is_SPI (D) then
            Release_SPI (D);
         end if;
         if Default_Applied then
            Set_I2C_Address (D, 0);
         end if;
         return;
      end if;
      Configure (D, S, OK);
      if not OK then
         if Is_SPI (D) then
            Release_SPI (D);
         end if;
         return;
      end if;
      Register_Device (D);
      Device := (Combined_Read => False, Temperature_Delay_Us => 0, Pressure_Delay_Us => 45_000);
      Found := True;
   end Detect;

   function Reading (High, Middle, Low : Byte) return Reading_Value is
     (Signed_24 (Interfaces.Shift_Left (U32 (High), 16) + Interfaces.Shift_Left (U32 (Middle), 8) + U32 (Low)));

   --  Bounds of the compensation's steps, from the coefficients' widths and
   --  the scaled readings' range, with room for rounding.
   subtype Cubic_Term is Float range -1.2E5 .. 1.2E5;
   subtype Square_Term is Float range -4.2E6 .. 4.2E6;
   subtype Linear_Term is Float range -1.5E8 .. 1.5E8;
   subtype Base_Sum is Float range -5.2E9 .. 5.2E9;
   subtype Temperature_Sum is Float range -5.21E9 .. 5.21E9;
   subtype Scaled_Product is Float range -1160.0 .. 1160.0;
   subtype Cross_Sum is Float range -4.9E9 .. 4.9E9;

   procedure Compensate (S : in out State)
     with Global => null
   is
      K       : Coefficients renames S.Calibration;
      Praw_Sc : constant Scaled := Float (Reading (S.Sensor_Data (0), S.Sensor_Data (1), S.Sensor_Data (2))) / Scale;
      Traw_Sc : constant Scaled := Float (Reading (S.Sensor_Data (3), S.Sensor_Data (4), S.Sensor_Data (5))) / Scale;
      C30     : Cubic_Term := Float (K.C30);
      C21     : Cubic_Term := Float (K.C21);
      Square  : Square_Term;
      Linear  : Linear_Term;
      Base    : Base_Sum;
      With_T  : Temperature_Sum;
      Inner   : Square_Term;
      Product : Scaled_Product;
      Cross   : Cross_Sum;
   begin
      if Is_SPL07 (S) then
         C30 := Float (K.C30) + Praw_Sc * Float (K.C40);
         C21 := Float (K.C21) + Praw_Sc * Float (K.C31);
      end if;
      Square := Float (K.C20) + Praw_Sc * C30;
      Linear := Float (K.C10) + Praw_Sc * Square;
      Base := Float (K.C00) + Praw_Sc * Linear;
      With_T := Base + Traw_Sc * Float (K.C01);
      Inner := Float (K.C11) + Praw_Sc * C21;
      Product := Traw_Sc * Praw_Sc;
      Cross := Product * Inner;
      S.Pressure := With_T + Cross;
      S.Temperature := Float (K.C0) * 0.5 + Float (K.C1) * Traw_Sc;
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
            | Barometer_Task.Get_Temperature | Barometer_Task.Start_Pressure =>
            Done := True;
         when Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Start_Read (D, Data_Register, S.Sensor_Data'Length, Done);
         when Barometer_Task.Get_Pressure =>
            Fetch (D, S.Sensor_Data);
            Compensate (S);
            Done := True;
      end case;
   end Device_Call;

   function Whole (V : Float) return I32 is
     (if V >= 2_147_483_647.0 then I32'Last
      elsif V <= -2_147_483_648.0 then I32'First
      else I32 (Float'Truncation (V)));

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
   begin
      Pressure := Whole (S.Pressure);
      Temperature := Whole (S.Temperature * 100.0);
   end Calculate;

end Adaflight.DPS310;
