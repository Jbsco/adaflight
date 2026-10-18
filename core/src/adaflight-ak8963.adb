package body Adaflight.AK8963 with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_64;

   Chip_Address       : constant Byte := 16#0C#;
   Device_Id          : constant Byte := 16#48#;
   Who_Am_I           : constant Byte := 16#00#;
   Status_1           : constant Byte := 16#02#;
   Data_Register      : constant Byte := 16#03#;
   Status_2           : constant Byte := 16#09#;
   Control_1          : constant Byte := 16#0A#;
   Control_2          : constant Byte := 16#0B#;
   Sensitivity_X      : constant Byte := 16#10#;
   Ready_Mask         : constant Byte := 16#01#;
   Overflow_Mask      : constant Byte := 16#08#;
   Power_Down         : constant Byte := 16#00#;
   Fuse_ROM           : constant Byte := 16#0F#;
   Single_16_Bit      : constant Byte := 16#10# or 16#01#;
   Soft_Reset         : constant Byte := 16#01#;
   Read_Flag          : constant Byte := 16#80#;
   Slave_Enable       : constant Byte := 16#80#;
   I2C_Master_Control : constant Byte := 16#24#;
   Slave_0_Address    : constant Byte := 16#25#;
   Slave_0_Register   : constant Byte := 16#26#;
   Slave_0_Control    : constant Byte := 16#27#;
   Int_Pin_Config     : constant Byte := 16#37#;
   Ext_Sens_Data_00   : constant Byte := 16#49#;
   Slave_0_Data_Out   : constant Byte := 16#63#;
   User_Control       : constant Byte := 16#6A#;
   Any_Read_Clear     : constant Byte := 16#10#;
   Bypass             : constant Byte := 16#02#;
   Master_400_kHz     : constant Byte := 16#0D#;
   Master_Mode        : constant Byte := 16#30#;
   Max_SPI_Clock_Hz   : constant := 10_000_000;
   Queued_Wait_Us     : constant := 8_000;

   subtype Read_Bytes is Byte_Array (0 .. 6);

   function Word (Low : Byte; High : Byte) return Integer is
     (if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
      else Integer (High) * 256 + Integer (Low))
     with Global => null,
          Post   => Word'Result in -32_768 .. 32_767;

   function Axis (Low : Byte; High : Byte; G : Gain) return Interfaces.Integer_16 is
     (Interfaces.Integer_16 (Integer'Max (-32_768, Integer'Min (32_767, Word (Low, High) * G / 256))))
     with Global => null;

   procedure Master_Write_Wait (D : in out Bus_Device; Register : Byte; Value : Byte) is
   begin
      Master_Write (D, Register, Value);
      Delay_Us (D, 10);
   end Master_Write_Wait;

   procedure Read_Any (D : in out Bus_Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Pre => Data'Length <= 7
   is
   begin
      if Is_MPU_Slave (D) then
         Master_Write_Wait (D, Slave_0_Address, I2C_Address (D) or Read_Flag);
         Master_Write_Wait (D, Slave_0_Register, Register);
         Master_Write_Wait (D, Slave_0_Control, (Byte (Data'Length) and 16#0F#) or Slave_Enable);
         Delay_Ms (D, 4);
         Mask_Interrupts (D);
         Master_Read (D, Ext_Sens_Data_00, Data, OK);
         Unmask_Interrupts (D);
      else
         Read_Registers (D, Register, Data, OK);
      end if;
   end Read_Any;

   procedure Write_Any (D : in out Bus_Device; Register : Byte; Value : Byte) is
      Ignored : Boolean;
   begin
      if Is_MPU_Slave (D) then
         Master_Write_Wait (D, Slave_0_Address, I2C_Address (D));
         Master_Write_Wait (D, Slave_0_Register, Register);
         Master_Write_Wait (D, Slave_0_Data_Out, Value);
         Master_Write_Wait (D, Slave_0_Control, 1 or Slave_Enable);
      else
         Write_Register (D, Register, Value, Ignored);
      end if;
   end Write_Any;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      if (Is_I2C (D) or else Is_MPU_Slave (D)) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Chip_Address);
      end if;
      if Is_SPI (D) then
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      elsif Is_MPU_Slave (D) then
         Master_DMA_Off (D);
         Master_Write_Wait (D, Int_Pin_Config, Any_Read_Clear or Bypass);
         Master_Write_Wait (D, I2C_Master_Control, Master_400_kHz);
         Master_Write_Wait (D, User_Control, Master_Mode);
      end if;
      Write_Any (D, Control_2, Soft_Reset);
      Delay_Ms (D, 4);
      Read_Any (D, Who_Am_I, Id, OK);
      if OK and then Id (0) = Device_Id then
         Found := True;
         return;
      end if;
      if Is_SPI (D) then
         Release_SPI (D);
      elsif Is_MPU_Slave (D) then
         Master_Write_Wait (D, Int_Pin_Config, Any_Read_Clear);
      end if;
      Found := False;
   end Detect;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
      ASA            : Byte_Array (0 .. 2) := (others => 0);
      Ignored_Status : Byte_Array (0 .. 0) := (others => 0);
      Ignored        : Boolean;
   begin
      Register_Device (D);
      Write_Any (D, Control_1, Power_Down);
      Write_Any (D, Control_1, Fuse_ROM);
      Read_Any (D, Sensitivity_X, ASA, Ignored);
      for K in 0 .. 2 loop
         S.Sensitivity (K) := Integer (ASA (K)) + 128;
      end loop;
      Write_Any (D, Control_1, Power_Down);
      Read_Any (D, Status_1, Ignored_Status, Ignored);
      Read_Any (D, Status_2, Ignored_Status, Ignored);
      Write_Any (D, Control_1, Single_16_Bit);
      S.ODR_Hz := 50;
      OK := True;
   end Init;

   procedure Start_Queued_Read (D : in out Bus_Device; S : in out State; Register : Byte; Length : Queued_Length) is
   begin
      if S.Waiting then
         return;
      end if;
      S.Length := Length;
      Master_Write_Wait (D, Slave_0_Address, I2C_Address (D) or Read_Flag);
      Master_Write_Wait (D, Slave_0_Register, Register);
      Master_Write_Wait (D, Slave_0_Control, (Byte (Length) and 16#0F#) or Slave_Enable);
      Micros (D, S.Started_At);
      S.Waiting := True;
   end Start_Queued_Read;

   --  The microseconds left of a queued read's 8 ms, from a signed 32-bit elapsed time.
   procedure Queued_Time_Remaining (D : in out Bus_Device; S : State; Remaining : out Interfaces.Unsigned_32) is
      Now : Interfaces.Unsigned_32;
   begin
      if not S.Waiting then
         Remaining := 0;
         return;
      end if;
      Micros (D, Now);
      declare
         Elapsed : constant Interfaces.Unsigned_32 := Now - S.Started_At;
         Since   : constant Interfaces.Integer_64 :=
           (if Elapsed >= 2 ** 31 then Interfaces.Integer_64 (Elapsed) - 2 ** 32
            else Interfaces.Integer_64 (Elapsed));
         Left    : constant Interfaces.Integer_64 := Queued_Wait_Us - Since;
      begin
         Remaining := (if Left < 0 then 0 else Interfaces.Unsigned_32 (Left));
      end;
   end Queued_Time_Remaining;

   procedure Complete_Queued_Read
     (D : in out Bus_Device; S : in out State; Buffer : in out Read_Bytes; OK : out Boolean)
   is
      Remaining : Interfaces.Unsigned_32;
   begin
      Queued_Time_Remaining (D, S, Remaining);
      if Remaining > 0 then
         Delay_Us (D, Remaining);
      end if;
      S.Waiting := False;
      Master_Read (D, Ext_Sens_Data_00, Buffer (0 .. S.Length - 1), OK);
   end Complete_Queued_Read;

   procedure Slave_Read_Data (D : in out Bus_Device; S : in out State; Buffer : in out Read_Bytes; Ack : out Boolean) is
      Remaining : Interfaces.Unsigned_32;
   begin
      Ack := False;
      case S.Phase is
         when Check_Status =>
            Start_Queued_Read (D, S, Status_1, 1);
            S.Phase := Waiting_For_Status;
         when Waiting_For_Status =>
            Queued_Time_Remaining (D, S, Remaining);
            if Remaining /= 0 then
               return;
            end if;
            Complete_Queued_Read (D, S, Buffer, Ack);
            if not Ack or else (Buffer (0) and Ready_Mask) = 0 then
               Ack := False;
               Start_Queued_Read (D, S, Status_1, 1);
               S.Phase := Waiting_For_Status;
               return;
            end if;
            Ack := False;
            Start_Queued_Read (D, S, Data_Register, 7);
            S.Phase := Waiting_For_Data;
         when Waiting_For_Data =>
            Queued_Time_Remaining (D, S, Remaining);
            if Remaining /= 0 then
               return;
            end if;
            Complete_Queued_Read (D, S, Buffer, Ack);
            S.Phase := Check_Status;
      end case;
   end Slave_Read_Data;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      Buffer : Read_Bytes := (others => 0);
      Status : Byte_Array (0 .. 0) := (0 => 0);
      Ack    : Boolean := False;
   begin
      Got := False;
      if Is_I2C (D) or else Is_SPI (D) then
         Read_Any (D, Status_1, Status, Ack);
         if Ack and then (Status (0) and Ready_Mask) /= 0 then
            Read_Any (D, Data_Register, Buffer, Ack);
         else
            Ack := False;
         end if;
      elsif Is_MPU_Slave (D) then
         Slave_Read_Data (D, S, Buffer, Ack);
      end if;
      if not Ack then
         return;
      end if;
      Write_Any (D, Control_1, Single_16_Bit);
      if (Buffer (6) and Overflow_Mask) /= 0 then
         return;
      end if;
      Data (0) := Axis (Buffer (0), Buffer (1), S.Sensitivity (0));
      Data (1) := Axis (Buffer (2), Buffer (3), S.Sensitivity (1));
      Data (2) := Axis (Buffer (4), Buffer (5), S.Sensitivity (2));
      Got := True;
   end Read;

end Adaflight.AK8963;
