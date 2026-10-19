package body Adaflight.MPU_Gyro.LSM6DSV16X with SPARK_Mode is

   use type Interfaces.Unsigned_32;

   Who_Am_I             : constant Byte := 16#0F#;
   Int1_Control         : constant Byte := 16#0D#;
   Control_1            : constant Byte := 16#10#;
   Control_2            : constant Byte := 16#11#;
   Control_3            : constant Byte := 16#12#;
   Control_4            : constant Byte := 16#13#;
   Control_6            : constant Byte := 16#15#;
   Control_7            : constant Byte := 16#16#;
   Control_8            : constant Byte := 16#17#;
   Control_9            : constant Byte := 16#18#;
   HAODR_Config         : constant Byte := 16#62#;
   Gyro_Data_Register   : constant Byte := 16#22#;
   Acc_Data_Register    : constant Byte := 16#28#;
   Read_Bit             : constant Byte := 16#80#;
   Identity_LSM6DSV16X  : constant Byte := 16#70#;
   Identity_LSM6DSK320X : constant Byte := 16#75#;
   Rate_Mask            : constant Byte := 16#0F#;
   Block_Update         : constant Byte := 16#40#;
   Address_Increment    : constant Byte := 16#04#;
   Software_Reset       : constant Byte := 16#01#;
   High_Accuracy_Mode   : constant Byte := 16#10#;
   HAODR_Mode_1         : constant Byte := 16#01#;
   Variant_Bit          : constant Byte := 16#04#;
   Acc_LPF2_Quarter     : constant Byte := 16#00#;
   Acc_Range_16G        : constant Byte := 16#03#;
   Acc_LPF2_On          : constant Byte := 16#08#;
   K320X_Control_6_Bit  : constant Byte := 16#08#;
   Gyro_Range_2000DPS   : constant Byte := 16#04#;
   Gyro_Range_4000DPS   : constant Byte := 16#0C#;
   Gyro_LPF1_On         : constant Byte := 16#01#;
   Pulsed_Data_Ready    : constant Byte := 16#02#;
   Int1_Gyro_Ready      : constant Byte := 16#02#;
   Gyro_Rate_8000Hz     : constant Byte := 12;
   Acc_Rate_1000Hz      : constant Byte := 9;
   Bandwidth_288Hz      : constant Byte := 0;
   Bandwidth_215Hz      : constant Byte := 1;
   Bandwidth_157Hz      : constant Byte := 2;
   Bandwidth_455Hz      : constant Byte := 3;
   Max_SPI_Clock_Hz     : constant := 10_000_000;
   Reset_Wait_Ms        : constant := 10;
   Reset_Timeout_Ms     : constant := 20;
   Init_Attempts        : constant := 3;
   Settle_Us            : constant := 500;
   Sample_Bytes         : constant := 6;
   Scale_2000DPS        : constant Float := 0.070;
   Scale_4000DPS        : constant Float := 0.140;

   --  The first low pass filter bandwidth of a filter setting; the reference
   --  indexes a four-entry table with the setting.
   function Bandwidth_Of (Filter : Byte) return Byte is
     (case Filter is
         when 0 => Bandwidth_288Hz,
         when 1 => Bandwidth_157Hz,
         when 2 => Bandwidth_215Hz,
         when LPF_Experimental => Bandwidth_455Hz,
         when others => Bandwidth_288Hz)
     with Global => null;

   procedure Write_Verified (D : in out SPI_Device; Register : Byte; Value : Byte; OK : out Boolean)
     with Global => null;

   procedure Write_Verified (D : in out SPI_Device; Register : Byte; Value : Byte; OK : out Boolean) is
      Read_Back : Byte;
   begin
      Write_Register (D, Register, Value);
      Read_Register (D, Register, Read_Back);
      OK := Read_Back = Value;
   end Write_Verified;

   procedure Reset (D : in out SPI_Device; Identity : Byte; OK : out Boolean)
     with Global => null;

   procedure Reset (D : in out SPI_Device; Identity : Byte; OK : out Boolean) is
      Control_1_Value : Byte;
      Control_2_Value : Byte;
      Value           : Byte;
   begin
      Read_Register (D, Control_1, Control_1_Value);
      Read_Register (D, Control_2, Control_2_Value);
      Write_Verified (D, Control_1, Control_1_Value and not Rate_Mask, OK);
      if not OK then
         return;
      end if;
      Write_Verified (D, Control_2, Control_2_Value and not Rate_Mask, OK);
      if not OK then
         return;
      end if;
      Write_Verified (D, Control_3, Address_Increment, OK);
      if not OK then
         return;
      end if;
      OK := False;
      Delay_Us (D, Settle_Us);
      Write_Register (D, Control_3, Software_Reset);
      Delay_Ms (D, Reset_Wait_Ms);
      for Elapsed in Reset_Wait_Ms .. Reset_Timeout_Ms loop
         Read_Register (D, Control_3, Value);
         if (Value and (Software_Reset or Block_Update)) = Block_Update then
            Read_Register (D, Who_Am_I, Value);
            OK := Value = Identity;
            return;
         end if;
         if Elapsed < Reset_Timeout_Ms then
            Delay_Ms (D, 1);
         end if;
      end loop;
   end Reset;

   procedure Detect_LSM6DSV16X (D : in out SPI_Device; Sensor : out Byte) is
      Value : Byte;
      OK    : Boolean;
   begin
      Sensor := No_Sensor;
      Read_Register (D, Who_Am_I, Value);
      if Value /= Identity_LSM6DSV16X then
         return;
      end if;
      Reset (D, Identity_LSM6DSV16X, OK);
      if not OK then
         return;
      end if;
      Read_Register (D, Control_8, Value);
      Sensor := (if (Value and Variant_Bit) /= 0 then Sensor_LSM6DSV32X else Sensor_LSM6DSV16X);
   end Detect_LSM6DSV16X;

   procedure Detect_LSM6DSK320X (D : in out SPI_Device; Sensor : out Byte) is
      Value : Byte;
   begin
      Sensor := No_Sensor;
      Read_Register (D, Who_Am_I, Value);
      if Value = Identity_LSM6DSK320X then
         Sensor := Sensor_LSM6DSK320X;
      end if;
   end Detect_LSM6DSK320X;

   procedure Gyro_Detect (S : State; Found : out Boolean) is
   begin
      Found := S.Sensor in Sensor_LSM6DSV16X | Sensor_LSM6DSK320X | Sensor_LSM6DSV32X;
   end Gyro_Detect;

   type Register_Write is record
      Register : Byte;
      Value    : Byte;
   end record;

   type Register_Writes is array (Positive range <>) of Register_Write;

   --  A reset, the control registers and the rates, each written and read
   --  back.
   procedure Configure (D : in out SPI_Device; Identity : Byte; Is_32X : Boolean; Filter : Byte; OK : out Boolean)
     with Global => null;

   procedure Configure (D : in out SPI_Device; Identity : Byte; Is_32X : Boolean; Filter : Byte; OK : out Boolean) is
      Writes : constant Register_Writes :=
        ((Control_3, Address_Increment or Block_Update),
         (HAODR_Config, HAODR_Mode_1),
         (Control_1, High_Accuracy_Mode),
         (Control_2, High_Accuracy_Mode),
         (Control_8, (if Is_32X then Variant_Bit else 0) or Acc_LPF2_Quarter or Acc_Range_16G),
         (Control_9, Acc_LPF2_On),
         (Control_6,
          (if Identity = Identity_LSM6DSK320X then K320X_Control_6_Bit else 0) or Bandwidth_Of (Filter) * 16
          or (if Is_32X then Gyro_Range_4000DPS else Gyro_Range_2000DPS)),
         (Control_7, Gyro_LPF1_On),
         (Control_4, Pulsed_Data_Ready),
         (Int1_Control, Int1_Gyro_Ready));
   begin
      Reset (D, Identity, OK);
      if not OK then
         return;
      end if;
      for W of Writes loop
         Write_Verified (D, W.Register, W.Value, OK);
         if not OK then
            return;
         end if;
      end loop;
      Delay_Us (D, Settle_Us);
      Write_Verified (D, Control_2, High_Accuracy_Mode or Gyro_Rate_8000Hz, OK);
      if OK then
         Write_Verified (D, Control_1, High_Accuracy_Mode or Acc_Rate_1000Hz, OK);
      end if;
   end Configure;

   procedure Gyro_Init (D : in out SPI_Device; S : in out State; Filter : Byte; Scale : in out Float) is
      Divisor    : Interfaces.Unsigned_16;
      Identity   : constant Byte :=
        (if S.Sensor = Sensor_LSM6DSK320X then Identity_LSM6DSK320X else Identity_LSM6DSV16X);
      Is_32X     : constant Boolean := S.Sensor = Sensor_LSM6DSV32X;
      Configured : Boolean;
   begin
      Divider (D, Max_SPI_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      Configure (D, Identity, Is_32X, Filter, Configured);
      for Attempt in 2 .. Init_Attempts loop
         exit when Configured;
         Configure (D, Identity, Is_32X, Filter, Configured);
      end loop;
      if not Configured then
         Failure (D);
         return;
      end if;
      Scale := (if Is_32X then Scale_4000DPS else Scale_2000DPS);
      Init (D, S);
   end Gyro_Init;

   --  A little-endian pair as the signed count.
   function Little_16 (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128
      then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   --  The three little-endian words at an offset of the receive buffer.
   function Sample_At (Rx : Buffer_Bytes; Offset : Natural) return Axis_Values is
     (Little_16 (Rx (Offset), Rx (Offset + 1)),
      Little_16 (Rx (Offset + 2), Rx (Offset + 3)),
      Little_16 (Rx (Offset + 4), Rx (Offset + 5)))
     with Global => null,
          Pre    => Offset <= Buffer_Bytes'Last - 5;

   procedure Transfer_Complete (D : in out SPI_Device; S : in out State; L : in out Sample_Latch) is
      Rx : Buffer_Bytes;
   begin
      Fetch (D, Rx);
      L.Sequence := L.Sequence + 1;
      for K in L.Samples'Range loop
         L.Samples (K) := Little_16 (Rx (2 + 2 * K), Rx (3 + 2 * K));
      end loop;
      L.Sequence := L.Sequence + 1;
      L.Ready := True;
      MPU_Gyro.Transfer_Complete (D, S);
   end Transfer_Complete;

   --  The latched sample from an offset, once one is ready and no completion
   --  is writing it.
   procedure Read_Latched (L : Sample_Latch; Offset : Natural; Values : in out Axis_Values; OK : out Boolean)
     with Global => null,
          Pre    => Offset <= 3;

   procedure Read_Latched (L : Sample_Latch; Offset : Natural; Values : in out Axis_Values; OK : out Boolean) is
   begin
      OK := False;
      if not L.Ready or else L.Sequence mod 2 = 1 then
         return;
      end if;
      Values := (L.Samples (Offset), L.Samples (Offset + 1), L.Samples (Offset + 2));
      OK := True;
   end Read_Latched;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; L : in out Sample_Latch; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      case S.Mode is
         when EXTI_Init =>
            S.Tx := (others => 16#FF#);
            L.Sequence := 0;
            L.Ready := False;
            S.DMA_Max_Duration := 5;
            if S.Detected_EXTI > Detect_Count then
               if Uses_DMA (D) then
                  S.Tx (0) := Gyro_Data_Register or Read_Bit;
                  S.DMA_Length := 1 + 2 * Sample_Bytes;
                  S.Mode := EXTI_Int_DMA;
               else
                  S.Mode := EXTI_Int;
               end if;
            else
               S.Mode := EXTI_No_Int;
            end if;
            OK := False;
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := Gyro_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sample_Bytes), False);
            Wait (D);
            Fetch (D, Rx);
            S.Raw := Sample_At (Rx, 2);
            OK := True;
         when EXTI_Int_DMA =>
            Read_Latched (L, 0, S.Raw, OK);
      end case;
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; L : Sample_Latch; OK : out Boolean) is
      Rx : Buffer_Bytes;
   begin
      case S.Mode is
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := Acc_Data_Register or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. Sample_Bytes), False);
            Wait (D);
            Fetch (D, Rx);
            S.Acc_Raw := Sample_At (Rx, 2);
            OK := True;
         when EXTI_Int_DMA =>
            Read_Latched (L, 3, S.Acc_Raw, OK);
         when EXTI_Init =>
            OK := False;
      end case;
   end Read_Acc;

end Adaflight.MPU_Gyro.LSM6DSV16X;
