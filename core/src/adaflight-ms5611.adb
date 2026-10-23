package body Adaflight.MS5611 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_64;
   use type Barometer_Task.Device_Call;

   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype I32 is Interfaces.Integer_32;
   subtype I64 is Interfaces.Integer_64;

   Default_Address  : constant Byte := 16#77#;
   Max_SPI_Clock_Hz : constant := 10_000_000;
   Command_Reset    : constant Byte := 16#1E#;
   Command_ADC_Read : constant Byte := 16#00#;
   Command_PROM     : constant Byte := 16#A0#;
   Convert_D1       : constant Byte := 16#40#;
   Convert_D2       : constant Byte := 16#50#;
   Oversampling     : constant Byte := 16#08#;
   Conversion_Us    : constant := 10_000;

   --  The check of the PROM words as the application note computes it, with
   --  the low byte of the last word cleared: 0 when it matches the word's
   --  low four bits and the PROM is not blank. The last word keeps only its
   --  check bits in its low byte afterwards, as the reference leaves it.
   procedure Check_PROM (Words : in out PROM_Words; OK : out Boolean)
     with Global => null
   is
      Check : constant U16 := Words (7) and 16#F#;
      Blank : Boolean := True;
      Res   : U32 := 0;
   begin
      Words (7) := Words (7) and 16#FF00#;
      for I in 0 .. 15 loop
         if Words (I / 2) /= 0 then
            Blank := False;
         end if;
         if I mod 2 = 1 then
            Res := Res xor U32 (Words (I / 2) and 16#00FF#);
         else
            Res := Res xor U32 (Interfaces.Shift_Right (Words (I / 2), 8));
         end if;
         for J in 1 .. 8 loop
            if (Res and 16#8000#) /= 0 then
               Res := Res xor 16#1800#;
            end if;
            Res := Interfaces.Shift_Left (Res, 1);
         end loop;
      end loop;
      Words (7) := Words (7) or Check;
      OK := not Blank and then U32 (Check) = (Interfaces.Shift_Right (Res, 12) and 16#F#);
   end Check_PROM;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Signature       : Byte_Array (0 .. 0) := (0 => 0);
      OK              : Boolean;
      Unused_OK       : Boolean;
   begin
      Device := (others => <>);
      Found := False;
      Delay_Ms (D, 10);
      if Is_SPI (D) then
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      end if;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Default_Address);
         Default_Applied := True;
      end if;
      Raw_Read (D, Command_PROM, Signature, OK);
      if OK and then Signature (0) /= 16#FF# then
         Raw_Write (D, Command_Reset, 1, Unused_OK);
         Delay_Us (D, 2800);
         for I in PROM_Words'Range loop
            declare
               Word : Byte_Array (0 .. 1) := (0, 0);
            begin
               Raw_Read (D, Command_PROM + Byte (I) * 2, Word, Unused_OK);
               S.PROM (I) := Interfaces.Shift_Left (U16 (Word (0)), 8) or U16 (Word (1));
            end;
         end loop;
         Check_PROM (S.PROM, OK);
         if OK then
            Register_Device (D);
            Device :=
              (Combined_Read => False, Temperature_Delay_Us => Conversion_Us, Pressure_Delay_Us => Conversion_Us);
            Found := True;
            return;
         end if;
      end if;
      if Is_SPI (D) then
         Release_SPI (D);
      end if;
      if Default_Applied then
         Set_I2C_Address (D, 0);
      end if;
   end Detect;

   function Reading (Data : Data_Bytes) return Raw_Reading is
     (Interfaces.Shift_Left (U32 (Data (0)), 16) or Interfaces.Shift_Left (U32 (Data (1)), 8) or U32 (Data (2)));

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean)
   is
      Busy           : Boolean;
      Unused_Error   : Boolean;
      Unused_Started : Boolean;
   begin
      case Call is
         when Barometer_Task.Start_Temperature =>
            Raw_Start_Write (D, Convert_D2 + Oversampling, 1, Done);
         when Barometer_Task.Start_Pressure =>
            Raw_Start_Write (D, Convert_D1 + Oversampling, 1, Done);
         when Barometer_Task.Read_Temperature | Barometer_Task.Read_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Raw_Start_Read (D, Command_ADC_Read, S.Sensor_Data'Length, Unused_Started);
            Done := True;
         when Barometer_Task.Get_Temperature | Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            if Call = Barometer_Task.Get_Temperature then
               S.Raw_Temperature := Reading (S.Sensor_Data);
            else
               S.Raw_Pressure := Reading (S.Sensor_Data);
            end if;
            Done := True;
      end case;
   end Device_Call;

   --  The quotient by a power of two rounded down, as an arithmetic shift
   --  right gives it.
   function Floor_Div (X : I64; D : I64) return I64 is
     (if X >= 0 then X / D else (X + 1) / D - 1)
     with Pre => D in 2 .. 2 ** 31;

   subtype Delta_T is I64 range -16_776_960 .. 16_777_215;
   subtype Delta_Product is I64 range -1_100_000_000_000 .. 1_100_000_000_000;
   subtype Delta_Square is I64 range 0 .. 281_474_943_156_225;
   subtype First_Order_Temperature is I64 range -129_131 .. 133_130;
   subtype Temperature_Term is I64 range -270_000 .. 140_000;
   subtype Second_Order is I64 range -500_000_000_000 .. 500_000_000_000;

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
      C          : PROM_Words renames S.PROM;
      DT         : constant Delta_T := I64 (S.Raw_Temperature) - I64 (C (5)) * 256;
      Off_Delta  : constant Delta_Product := I64 (C (4)) * DT;
      Sens_Delta : constant Delta_Product := I64 (C (3)) * DT;
      Temp_Delta : constant Delta_Product := DT * I64 (C (6));
      First_Temp : constant First_Order_Temperature := 2000 + Floor_Div (Temp_Delta, 2 ** 23);
      Off        : Second_Order := I64 (C (2)) * 2 ** 16 + Floor_Div (Off_Delta, 2 ** 7);
      Sens       : Second_Order := I64 (C (1)) * 2 ** 15 + Floor_Div (Sens_Delta, 2 ** 8);
      Temp       : Temperature_Term := First_Temp;
   begin
      if Temp < 2000 then
         declare
            Below : constant I64 range -131_131 .. -1 := Temp - 2000;
            Delt  : constant I64 range 5 .. 86_000_000_000 := 5 * Below * Below;
         begin
            Off := Off - Floor_Div (Delt, 2);
            Sens := Sens - Floor_Div (Delt, 4);
         end;
         if Temp < -1500 then
            declare
               Below : constant I64 range -127_631 .. -1 := Temp + 1500;
               Delt  : constant I64 range 1 .. 16_300_000_000 := Below * Below;
            begin
               Off := Off - 7 * Delt;
               Sens := Sens - Floor_Div (11 * Delt, 2);
            end;
         end if;
         declare
            DT_Square : constant Delta_Square := DT * DT;
         begin
            Temp := Temp - Floor_Div (DT_Square, 2 ** 31);
         end;
      end if;
      declare
         Product : constant I64 := I64 (S.Raw_Pressure) * Sens;
      begin
         Pressure := I32 (Floor_Div (Floor_Div (Product, 2 ** 21) - Off, 2 ** 15));
      end;
      Temperature := I32 (Temp);
   end Calculate;

end Adaflight.MS5611;
