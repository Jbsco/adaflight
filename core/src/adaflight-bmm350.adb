with Adaflight.Maths;

package body Adaflight.BMM350 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   Address_ADSEL_GND   : constant Byte := 16#14#;
   Address_ADSEL_VDDIO : constant Byte := 16#15#;

   Chip_Id_Register     : constant Byte := 16#00#;
   Aggr_Set_Register    : constant Byte := 16#04#;
   Axis_En_Register     : constant Byte := 16#05#;
   PMU_Cmd_Register     : constant Byte := 16#06#;
   PMU_Status_Register  : constant Byte := 16#07#;
   Int_Ctrl_Register    : constant Byte := 16#2E#;
   Mag_Data_Register    : constant Byte := 16#31#;
   OTP_Cmd_Register     : constant Byte := 16#50#;
   OTP_Data_Register    : constant Byte := 16#52#;
   OTP_Status_Register  : constant Byte := 16#55#;
   Cmd_Register         : constant Byte := 16#7E#;

   Chip_Id             : constant Byte := 16#33#;
   Soft_Reset          : constant Byte := 16#B6#;
   OTP_Dir_Read        : constant Byte := 16#20#;
   OTP_Power_Off       : constant Byte := 16#80#;
   OTP_Error_Mask      : constant Byte := 16#E0#;
   OTP_Cmd_Done        : constant Byte := 16#01#;
   PMU_Suspend         : constant Byte := 0;
   PMU_Normal          : constant Byte := 1;
   PMU_Update_Offsets  : constant Byte := 2;
   PMU_Flux_Guide      : constant Byte := 5;
   PMU_Bit_Reset       : constant Byte := 7;
   PMU_Busy            : constant Byte := 16#01#;
   PMU_Normal_Mode     : constant Byte := 16#08#;
   PMU_Cmd_Mask        : constant Byte := 16#E0#;
   Averaging_4_100Hz   : constant Byte := 16#20# or 16#04#;
   Axes_XYZ            : constant Byte := 16#07#;
   Int_Ctrl_Value      : constant Byte := 16#02# or 16#04# or 16#80#;
   Data_Bytes          : constant := 12;
   Dummy_Bytes         : constant := 2;
   Boot_Retries        : constant := 3;
   OTP_Poll_Tries      : constant := 10;
   Suspend_Timeout_Ms  : constant := 6;
   Normal_Timeout_Ms   : constant := 38;
   Bit_Reset_Timeout   : constant := 19;
   Flux_Guide_Timeout  : constant := 23;
   Offsets_Timeout_Ms  : constant := 20;
   Reset_Delay_Ms      : constant := 24;
   Detect_Delay_Ms     : constant := 3;
   OTP_Poll_Us         : constant := 300;

   --  The scales of the 24-bit readings, in single precision as the
   --  reference folds them.
   XY_Scale   : constant Float := 0.0070699784;
   Z_Scale    : constant Float := 0.00717496406;
   Temp_Scale : constant Float := 0.000981281861;
   Temp_Base  : constant Float := 25.49;
   Sens_Corr_Y : constant Float := 0.01;
   TCS_Corr_Z  : constant Float := 0.0001;
   To_Tenths   : constant Float := 10.0;
   --  A nonzero single precision sum of one and a product is at least this,
   --  so a smaller divisor is zero.
   Den_Min     : constant Float := 2.0 ** (-24);

   subtype Raw_Value is Integer range -2 ** 23 .. 2 ** 23 - 1;
   subtype Scaled_Field is Float range -61_000.0 .. 61_000.0;
   subtype Temperature_Value is Float range -10_500.0 .. 10_500.0;
   subtype Temperature_Delta is Float range -10_600.0 .. 10_600.0;
   subtype Axis_Sum is Float range -140_000.0 .. 140_000.0;
   subtype Denominator is Float range -86.0 .. 88.0;
   subtype Compensated_Field is Float range -2.4E12 .. 2.4E12;
   subtype Cross_Denominator is Float range 0.97 .. 1.03;
   subtype Cross_Coefficient is Float range -0.19 .. 0.19;
   subtype Cross_Field is Float range -3.5E12 .. 3.5E12;

   procedure Read_Bytes (D : in out Bus_Device; Register : Byte; Data : out Byte_Array; OK : out Boolean)
     with Global => null,
          Pre    => Data'Length in 1 .. Data_Bytes and then Data'First = 0;

   procedure Read_Bytes (D : in out Bus_Device; Register : Byte; Data : out Byte_Array; OK : out Boolean) is
      Buffer : Byte_Array (0 .. Data'Length + Dummy_Bytes - 1) := (others => 0);
   begin
      Data := (others => 0);
      Read_Registers (D, Register, Buffer, OK);
      if OK then
         Data := Buffer (Dummy_Bytes .. Data'Length + Dummy_Bytes - 1);
      end if;
   end Read_Bytes;

   procedure Wait_PMU_Cmd (D : in out Bus_Device; Cmd : Byte; Timeout_Ms : Positive; Done : out Boolean)
     with Global => null;

   procedure Wait_PMU_Cmd (D : in out Bus_Device; Cmd : Byte; Timeout_Ms : Positive; Done : out Boolean) is
      Status : Byte_Array (0 .. 0);
      OK     : Boolean;
   begin
      Done := False;
      for Remaining in 1 .. Timeout_Ms loop
         Delay_Ms (D, 1);
         Read_Bytes (D, PMU_Status_Register, Status, OK);
         if not OK then
            return;
         end if;
         if (Status (0) and PMU_Busy) = 0 and then (Status (0) and PMU_Cmd_Mask) / 32 = Cmd then
            Done := True;
            return;
         end if;
      end loop;
   end Wait_PMU_Cmd;

   procedure Set_Power_Mode (D : in out Bus_Device; Mode : Byte; OK : out Boolean)
     with Global => null;

   procedure Set_Power_Mode (D : in out Bus_Device; Mode : Byte; OK : out Boolean) is
      Current     : Byte_Array (0 .. 0);
      Unused_Done : Boolean;
   begin
      Read_Bytes (D, PMU_Cmd_Register, Current, OK);
      if not OK then
         return;
      end if;
      if Current (0) = PMU_Normal or else Current (0) = PMU_Update_Offsets then
         Write_Register (D, PMU_Cmd_Register, PMU_Suspend, OK);
         if not OK then
            return;
         end if;
         Wait_PMU_Cmd (D, PMU_Suspend, Suspend_Timeout_Ms, Unused_Done);
      end if;
      Write_Register (D, PMU_Cmd_Register, Mode, OK);
      if not OK then
         return;
      end if;
      Wait_PMU_Cmd (D, Mode, Normal_Timeout_Ms, OK);
   end Set_Power_Mode;

   procedure Read_OTP (D : in out Bus_Device; Words : out Trim_Words; OK : out Boolean)
     with Global => null;

   procedure Read_OTP (D : in out Bus_Device; Words : out Trim_Words; OK : out Boolean) is
      Status : Byte_Array (0 .. 0);
      Pair   : Byte_Array (0 .. 1);
      Done   : Boolean;
   begin
      Words := (others => 0);
      for Index in Words'Range loop
         Write_Register (D, OTP_Cmd_Register, OTP_Dir_Read or Byte (Index), OK);
         if not OK then
            return;
         end if;
         Done := False;
         for Poll in 1 .. OTP_Poll_Tries loop
            Delay_Us (D, OTP_Poll_Us);
            Read_Bytes (D, OTP_Status_Register, Status, OK);
            if not OK or else (Status (0) and OTP_Error_Mask) /= 0 then
               OK := False;
               return;
            end if;
            if (Status (0) and OTP_Cmd_Done) /= 0 then
               Done := True;
               exit;
            end if;
         end loop;
         if not Done then
            OK := False;
            return;
         end if;
         Read_Bytes (D, OTP_Data_Register, Pair, OK);
         if not OK then
            return;
         end if;
         Words (Index) := Interfaces.Unsigned_16 (Pair (0)) * 256 + Interfaces.Unsigned_16 (Pair (1));
      end loop;
      OK := True;
   end Read_OTP;

   --  A 12-bit field as a signed value.
   function Sign_Extend_12 (Value : Interfaces.Unsigned_16) return Float is
     (if (Value and 16#0FFF#) >= 2048 then Float (Integer (Value and 16#0FFF#) - 4096)
      else Float (Value and 16#0FFF#))
     with Global => null,
          Post   => Sign_Extend_12'Result in -2048.0 .. 2047.0;

   --  The low or high byte of a word as a signed value.
   function Low_Signed (Value : Interfaces.Unsigned_16) return Float is
     (if (Value and 16#FF#) >= 128 then Float (Integer (Value and 16#FF#) - 256) else Float (Value and 16#FF#))
     with Global => null,
          Post   => Low_Signed'Result in -128.0 .. 127.0;

   function High_Signed (Value : Interfaces.Unsigned_16) return Float is
     (if Value / 256 >= 128 then Float (Integer (Value / 256) - 256) else Float (Value / 256))
     with Global => null,
          Post   => High_Signed'Result in -128.0 .. 127.0;

   function Word_Signed (Value : Interfaces.Unsigned_16) return Float is
     (if Value >= 32_768 then Float (Integer (Value) - 65_536) else Float (Value))
     with Global => null,
          Post   => Word_Signed'Result in -32_768.0 .. 32_767.0;

   procedure Parse_OTP (Words : Trim_Words; Trim : out Compensation)
     with Global => null;

   procedure Parse_OTP (Words : Trim_Words; Trim : out Compensation) is
      Temp_Off_Sens : constant Interfaces.Unsigned_16 := Words (16#0D#);
      Offset_X_Word : constant Interfaces.Unsigned_16 := Words (16#0E#);
      Offset_Y_Word : constant Interfaces.Unsigned_16 := Words (16#0F#);
      Offset_Z_Word : constant Interfaces.Unsigned_16 := Words (16#10#);
      Sens_Y_Word   : constant Interfaces.Unsigned_16 := Words (16#11#);
      TC_X_Word     : constant Interfaces.Unsigned_16 := Words (16#12#);
      TC_Y_Word     : constant Interfaces.Unsigned_16 := Words (16#13#);
      TC_Z_Word     : constant Interfaces.Unsigned_16 := Words (16#14#);
      Cross_XY_Word : constant Interfaces.Unsigned_16 := Words (16#15#);
      Cross_Z_Word  : constant Interfaces.Unsigned_16 := Words (16#16#);
      T0_Word       : constant Interfaces.Unsigned_16 := Words (16#18#);
   begin
      Trim :=
        (Offset_X    => Sign_Extend_12 (Offset_X_Word),
         Offset_Y    => Sign_Extend_12 ((Offset_X_Word and 16#F000#) / 16 + (Offset_Y_Word and 16#00FF#)),
         Offset_Z    => Sign_Extend_12 ((Offset_Y_Word and 16#0F00#) + (Offset_Z_Word and 16#00FF#)),
         Offset_Temp => Low_Signed (Temp_Off_Sens) * (1.0 / 5.0),
         Sensit_X    => High_Signed (Offset_Z_Word) * (1.0 / 256.0),
         Sensit_Y    => Low_Signed (Sens_Y_Word) * (1.0 / 256.0) + Sens_Corr_Y,
         Sensit_Z    => High_Signed (Sens_Y_Word) * (1.0 / 256.0),
         Sensit_Temp => High_Signed (Temp_Off_Sens) * (1.0 / 512.0),
         TCO_X       => Low_Signed (TC_X_Word) * (1.0 / 32.0),
         TCO_Y       => Low_Signed (TC_Y_Word) * (1.0 / 32.0),
         TCO_Z       => Low_Signed (TC_Z_Word) * (1.0 / 32.0),
         TCS_X       => High_Signed (TC_X_Word) * (1.0 / 16384.0),
         TCS_Y       => High_Signed (TC_Y_Word) * (1.0 / 16384.0),
         TCS_Z       => High_Signed (TC_Z_Word) * (1.0 / 16384.0) - TCS_Corr_Z,
         T0          => Word_Signed (T0_Word) * (1.0 / 512.0) + 23.0,
         Cross_XY    => Low_Signed (Cross_XY_Word) * (1.0 / 800.0),
         Cross_YX    => High_Signed (Cross_XY_Word) * (1.0 / 800.0),
         Cross_ZX    => Low_Signed (Cross_Z_Word) * (1.0 / 800.0),
         Cross_ZY    => High_Signed (Cross_Z_Word) * (1.0 / 800.0));
   end Parse_OTP;

   procedure Mag_Reset (D : in out Bus_Device; OK : out Boolean)
     with Global => null;

   procedure Mag_Reset (D : in out Bus_Device; OK : out Boolean) is
      Status      : Byte_Array (0 .. 0);
      Unused_Done : Boolean;
   begin
      Read_Bytes (D, PMU_Status_Register, Status, OK);
      if not OK then
         return;
      end if;
      if (Status (0) and PMU_Normal_Mode) /= 0 then
         Write_Register (D, PMU_Cmd_Register, PMU_Suspend, OK);
         if not OK then
            return;
         end if;
         Wait_PMU_Cmd (D, PMU_Suspend, Suspend_Timeout_Ms, Unused_Done);
      end if;
      Write_Register (D, PMU_Cmd_Register, PMU_Bit_Reset, OK);
      if OK then
         Wait_PMU_Cmd (D, PMU_Bit_Reset, Bit_Reset_Timeout, OK);
      end if;
      if not OK then
         return;
      end if;
      Write_Register (D, PMU_Cmd_Register, PMU_Flux_Guide, OK);
      if OK then
         Wait_PMU_Cmd (D, PMU_Flux_Guide, Flux_Guide_Timeout, OK);
      end if;
      if not OK then
         return;
      end if;
      Set_Power_Mode (D, PMU_Normal, OK);
   end Mag_Reset;

   --  Three little-endian bytes as a signed 24-bit value.
   function Assemble (Low : Byte; Mid : Byte; High : Byte) return Raw_Value is
     (if High >= 128 then Integer (High) * 65_536 + Integer (Mid) * 256 + Integer (Low) - 2 ** 24
      else Integer (High) * 65_536 + Integer (Mid) * 256 + Integer (Low))
     with Global => null;

   --  The class of a compensated value: finite, an infinity by its sign or
   --  undefined, as the reference's single precision quotient over a zero
   --  divisor comes out and travels through the cross axis terms.
   type Value_Class is (Finite, Positive_Infinite, Negative_Infinite, Undefined);

   --  The class of a value times a finite coefficient: an infinity keeps or
   --  flips its sign with the coefficient's and a zero coefficient leaves it
   --  undefined.
   function Scaled_Class (C : Value_Class; Coefficient : Float) return Value_Class is
     (if C = Finite or else C = Undefined then C
      elsif Coefficient = 0.0 then Undefined
      elsif (Coefficient > 0.0) = (C = Positive_Infinite) then Positive_Infinite
      else Negative_Infinite)
     with Global => null;

   function Negated_Class (C : Value_Class) return Value_Class is
     (if C = Positive_Infinite then Negative_Infinite elsif C = Negative_Infinite then Positive_Infinite else C)
     with Global => null;

   --  The class of a sum: an infinity outweighs a finite value, opposite
   --  infinities and an undefined operand leave the sum undefined.
   function Sum_Class (A, B : Value_Class) return Value_Class is
     (if A = Undefined or else B = Undefined then Undefined
      elsif A = Finite then B
      elsif B = Finite then A
      elsif A = B then A
      else Undefined)
     with Global => null;

   function Difference_Class (A, B : Value_Class) return Value_Class is (Sum_Class (A, Negated_Class (B)))
     with Global => null;

   --  An axis in tenths of a microtesla within 16 bits: an infinity reads as
   --  the limit of its sign and an undefined value as zero, as the target's
   --  conversion of the reference's result does.
   function To_Axis (Value : Cross_Field; Class : Value_Class) return Interfaces.Integer_16
     with Global => null;

   function To_Axis (Value : Cross_Field; Class : Value_Class) return Interfaces.Integer_16 is
      Tenths : constant Float := Value * To_Tenths;
   begin
      case Class is
         when Positive_Infinite =>
            return Interfaces.Integer_16'Last;
         when Negative_Infinite =>
            return Interfaces.Integer_16'First;
         when Undefined =>
            return 0;
         when Finite =>
            if Tenths <= -32_768.0 then
               return Interfaces.Integer_16'First;
            elsif Tenths >= 32_767.0 then
               return Interfaces.Integer_16'Last;
            else
               return Interfaces.Integer_16
                 (Integer'Max (-32_768, Integer'Min (32_767, Adaflight.Maths.Round_Half_Even (Tenths))));
            end if;
      end case;
   end To_Axis;

   procedure Compensate_Axis
     (Scaled : Scaled_Field;
      Sensit : Sensitivity_Trim;
      Offset : Offset_Trim;
      TCO    : Offset_Coefficient;
      TCS    : Scale_Coefficient;
      Delta_T : Temperature_Delta;
      Field  : out Compensated_Field;
      Class  : out Value_Class)
     with Global => null;

   procedure Compensate_Axis
     (Scaled : Scaled_Field;
      Sensit : Sensitivity_Trim;
      Offset : Offset_Trim;
      TCO    : Offset_Coefficient;
      TCS    : Scale_Coefficient;
      Delta_T : Temperature_Delta;
      Field  : out Compensated_Field;
      Class  : out Value_Class)
   is
      Sum : constant Axis_Sum := (1.0 + Sensit) * Scaled + Offset + TCO * Delta_T;
      Den : constant Denominator := 1.0 + TCS * Delta_T;
   begin
      if abs Den >= Den_Min then
         Field := Sum / Den;
         Class := Finite;
      else
         Field := 0.0;
         Class := (if Sum > 0.0 then Positive_Infinite elsif Sum < 0.0 then Negative_Infinite else Undefined);
      end if;
   end Compensate_Axis;

   procedure Compensate (Trim : Compensation; Raw_X, Raw_Y, Raw_Z, Raw_T : Raw_Value; Data : out Axes)
     with Global => null;

   procedure Compensate (Trim : Compensation; Raw_X, Raw_Y, Raw_Z, Raw_T : Raw_Value; Data : out Axes) is
      Mag_X   : constant Scaled_Field := Float (Raw_X) * XY_Scale;
      Mag_Y   : constant Scaled_Field := Float (Raw_Y) * XY_Scale;
      Mag_Z   : constant Scaled_Field := Float (Raw_Z) * Z_Scale;
      Temp_0  : constant Temperature_Value := Float (Raw_T) * Temp_Scale - Temp_Base;
      Temp    : constant Temperature_Value := (1.0 + Trim.Sensit_Temp) * Temp_0 + Trim.Offset_Temp;
      Delta_T : constant Temperature_Delta := Temp - Trim.T0;
      X, Y, Z : Compensated_Field;
      X_Class, Y_Class, Z_Class : Value_Class;
      Den     : constant Cross_Denominator := 1.0 - Trim.Cross_YX * Trim.Cross_XY;
      Z_Of_X  : constant Cross_Coefficient := Trim.Cross_YX * Trim.Cross_ZY - Trim.Cross_ZX;
      Z_Of_Y  : constant Cross_Coefficient := Trim.Cross_ZY - Trim.Cross_XY * Trim.Cross_ZX;
      Cross_X, Cross_Y, Cross_Z : Cross_Field;
   begin
      Compensate_Axis (Mag_X, Trim.Sensit_X, Trim.Offset_X, Trim.TCO_X, Trim.TCS_X, Delta_T, X, X_Class);
      Compensate_Axis (Mag_Y, Trim.Sensit_Y, Trim.Offset_Y, Trim.TCO_Y, Trim.TCS_Y, Delta_T, Y, Y_Class);
      Compensate_Axis (Mag_Z, Trim.Sensit_Z, Trim.Offset_Z, Trim.TCO_Z, Trim.TCS_Z, Delta_T, Z, Z_Class);
      Cross_X := (X - Trim.Cross_XY * Y) / Den;
      Cross_Y := (Y - Trim.Cross_YX * X) / Den;
      Cross_Z := Z + (X * Z_Of_X - Y * Z_Of_Y) / Den;
      Data :=
        (To_Axis (Cross_X, Difference_Class (X_Class, Scaled_Class (Y_Class, Trim.Cross_XY))),
         To_Axis (Cross_Y, Difference_Class (Y_Class, Scaled_Class (X_Class, Trim.Cross_YX))),
         To_Axis (Cross_Z, Sum_Class (Z_Class, Difference_Class (Scaled_Class (X_Class, Z_Of_X),
                                                                  Scaled_Class (Y_Class, Z_Of_Y)))));
   end Compensate;

   procedure Probe (D : in out Bus_Device; Found : out Boolean)
     with Global => null;

   procedure Probe (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0);
      OK : Boolean;
   begin
      Read_Bytes (D, Chip_Id_Register, Id, OK);
      Found := OK and then Id (0) = Chip_Id;
   end Probe;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
   begin
      Delay_Ms (D, Detect_Delay_Ms);
      Found := False;
      if not Is_I2C (D) then
         return;
      end if;
      if I2C_Address (D) /= 0 then
         Probe (D, Found);
         return;
      end if;
      for Address of Byte_Array'(Address_ADSEL_GND, Address_ADSEL_VDDIO) loop
         Set_I2C_Address (D, Address);
         Probe (D, Found);
         if Found then
            return;
         end if;
      end loop;
      Set_I2C_Address (D, 0);
   end Detect;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
      Id          : Byte_Array (0 .. 0);
      Identified  : Boolean := False;
      Words       : Trim_Words;
      Unused_OK   : Boolean;
      Unused_Done : Boolean;
   begin
      Register_Device (D);
      for Attempt in 1 .. Boot_Retries loop
         Write_Register (D, Cmd_Register, Soft_Reset, OK);
         if OK then
            Delay_Ms (D, Reset_Delay_Ms);
            Read_Bytes (D, Chip_Id_Register, Id, OK);
            if OK and then Id (0) = Chip_Id then
               Identified := True;
               exit;
            end if;
         end if;
      end loop;
      if not Identified then
         OK := False;
         return;
      end if;
      S.Trim := (others => <>);
      Read_OTP (D, Words, OK);
      if OK then
         Parse_OTP (Words, S.Trim);
      end if;
      Write_Register (D, OTP_Cmd_Register, OTP_Power_Off, Unused_OK);
      Mag_Reset (D, Unused_OK);
      Write_Register (D, Int_Ctrl_Register, Int_Ctrl_Value, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, Aggr_Set_Register, Averaging_4_100Hz, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, PMU_Cmd_Register, PMU_Update_Offsets, OK);
      if not OK then
         return;
      end if;
      Wait_PMU_Cmd (D, PMU_Update_Offsets, Offsets_Timeout_Ms, Unused_Done);
      Write_Register (D, Axis_En_Register, Axes_XYZ, OK);
      if not OK then
         return;
      end if;
      Set_Power_Mode (D, PMU_Normal, OK);
      if OK then
         S.ODR_Hz := 100;
      end if;
   end Init;

   procedure Read (D : in out Bus_Device; S : State; Data : in out Axes; Got : out Boolean) is
      Buffer : Byte_Array (0 .. Data_Bytes - 1);
   begin
      Read_Bytes (D, Mag_Data_Register, Buffer, Got);
      if not Got then
         return;
      end if;
      Compensate
        (S.Trim, Assemble (Buffer (0), Buffer (1), Buffer (2)), Assemble (Buffer (3), Buffer (4), Buffer (5)),
         Assemble (Buffer (6), Buffer (7), Buffer (8)), Assemble (Buffer (9), Buffer (10), Buffer (11)), Data);
   end Read;

end Adaflight.BMM350;
