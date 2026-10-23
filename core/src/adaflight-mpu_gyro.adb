package body Adaflight.MPU_Gyro with SPARK_Mode is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   use type Interfaces.Integer_64;

   subtype U32 is Interfaces.Unsigned_32;
   subtype I32 is Interfaces.Integer_32;
   subtype I16 is Interfaces.Integer_16;

   Startup_Ms        : constant := 100;
   Detect_Clock_Hz   : constant := 1_000_000;
   Accel_Register    : constant Byte := 16#3B#;
   Temp_Register     : constant Byte := 16#41#;
   Gyro_Register     : constant Byte := 16#43#;
   Read_Bit          : constant Byte := 16#80#;

   --  A cycle count difference as a signed 32-bit value.
   function Elapsed (Now : U32; Before : U32) return I32 is
     (if Now - Before >= 2 ** 31 then I32 (Interfaces.Integer_64 (Now - Before) - 2 ** 32) else I32 (Now - Before))
     with Global => null;

   --  The two's complement image of a signed 32-bit value.
   function Image (V : I32) return U32 is
     (if V >= 0 then U32 (V) else U32 (Interfaces.Integer_64 (V) + 2 ** 32))
     with Global => null;

   subtype Word_Float is Float range -32_768.0 .. 32_767.0;
   subtype Scaled_Float is Float range -8_192.0 .. 8_192.0;

   --  The big-endian 16-bit word at an index of 16-bit words.
   function Word_At (Data : Byte_Array; Index : Natural) return I16 is
     (if Natural (Data (Data'First + 2 * Index)) >= 128
      then I16 (Integer (Data (Data'First + 2 * Index)) * 256 + Integer (Data (Data'First + 2 * Index + 1)) - 65_536)
      else I16 (Integer (Data (Data'First + 2 * Index)) * 256 + Integer (Data (Data'First + 2 * Index + 1))))
     with Global => null,
          Pre    => Data'Length = 16 and then Index <= 7;

   procedure Preinit (D : in out SPI_Device; C : Device_Config) is
   begin
      Preinit_CS (D, C.CS_Tag);
   end Preinit;

   procedure Detect (D : in out SPI_Device; S : in out State; C : Device_Config; Found : out Boolean) is
      OK      : Boolean;
      Now     : U32;
      Divisor : Interfaces.Unsigned_16;
      Sensor  : Byte;
   begin
      Found := False;
      Delay_Ms (D, 35);
      if C.Bus_Type = Bus_None then
         return;
      end if;
      if C.CS_Tag = 0 then
         return;
      end if;
      Attach_Bus (D, C.SPI_Bus, OK);
      if not OK then
         return;
      end if;
      Prepare_CS (D, Byte'Mod (Integer (C.Index) + 1));
      loop
         Millis (D, Now);
         exit when Now >= Startup_Ms;
      end loop;
      Divider (D, Detect_Clock_Hz, Divisor);
      Set_Divisor (D, Divisor);
      for Index in 1 .. Chip_Count loop
         Probe_Chip (D, Index, Sensor);
         if Sensor /= No_Sensor then
            S.Sensor := Sensor;
            Register_Device (D);
            Found := True;
            return;
         end if;
      end loop;
      Release_CS (D);
   end Detect;

   procedure Init (D : in out SPI_Device; S : in out State) is
   begin
      S.DMA_Length := 0;
      S.Acc_Data_Reg := Accel_Register;
      S.Gyro_Data_Reg := Gyro_Register;
      S.Temp_Data_Reg := Temp_Register;
      S.DMA_Read_Start := Accel_Register;
      if S.Interrupt_Pin then
         Enable_Interrupt (D);
      end if;
   end Init;

   procedure Interrupt (D : in out SPI_Device; S : in out State) is
      Now : U32;
   begin
      Cycle_Count (D, Now);
      if S.Short_Period = 0 or else Elapsed (Now, S.Last_EXTI) < S.Short_Period then
         S.Sync_EXTI := S.Last_EXTI + Image (S.DMA_Max_Duration);
      end if;
      S.Last_EXTI := Now;
      if S.Mode = EXTI_Int_DMA then
         Start_Sequence (D, S.Tx (0 .. S.DMA_Length - 1), True);
      end if;
      S.Detected_EXTI := S.Detected_EXTI + 1;
   end Interrupt;

   procedure Transfer_Complete (D : in out SPI_Device; S : in out State) is
      Now      : U32;
      Duration : I32;
   begin
      Cycle_Count (D, Now);
      Duration := Elapsed (Now, S.Last_EXTI);
      if Duration > S.DMA_Max_Duration then
         S.DMA_Max_Duration := Duration;
      end if;
      S.Data_Ready := True;
   end Transfer_Complete;

   --  The index in 16-bit words of a register in the DMA read, which starts
   --  with the register address byte.
   function Word_Index (Register : Byte; Start : Byte) return Natural is
     (Natural (Register - Start) / 2 + 1)
     with Global => null;

   procedure Read_Gyro_SPI (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx    : Buffer_Bytes;
      Index : Natural;
      Temp  : Natural;
   begin
      case S.Mode is
         when EXTI_Init =>
            S.Tx := (others => 16#FF#);
            S.DMA_Max_Duration := 5;
            if S.Detected_EXTI > Detect_Count then
               if Uses_DMA (D) then
                  S.Tx (0) := S.DMA_Read_Start or Read_Bit;
                  S.DMA_Length := Natural'Min (Natural (S.Gyro_Data_Reg - S.DMA_Read_Start) + 1 + 6, 16);
                  S.Mode := EXTI_Int_DMA;
               else
                  S.Mode := EXTI_Int;
               end if;
            else
               S.Mode := EXTI_No_Int;
            end if;
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := S.Gyro_Data_Reg or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. 6), False);
            Wait (D);
            Fetch (D, Rx);
            S.Raw := (Word_At (Rx, 1), Word_At (Rx, 2), Word_At (Rx, 3));
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            Index := Word_Index (S.Gyro_Data_Reg, S.DMA_Read_Start);
            Temp := Word_Index (S.Temp_Data_Reg, S.DMA_Read_Start);
            if Index <= 5 then
               S.Raw := (Word_At (Rx, Index), Word_At (Rx, Index + 1), Word_At (Rx, Index + 2));
            end if;
            if Temp <= 7 then
               declare
                  Word   : constant Word_Float := Float (Word_At (Rx, Temp));
                  Scaled : constant Scaled_Float := Word * S.Temp_Scale;
               begin
                  S.Temperature := I16 (Float'Truncation (Scaled + S.Temp_Zero));
               end;
            end if;
      end case;
      OK := True;
   end Read_Gyro_SPI;

   procedure Read_Acc_SPI (D : in out SPI_Device; S : in out State; OK : out Boolean) is
      Rx    : Buffer_Bytes;
      Index : Natural;
   begin
      case S.Mode is
         when EXTI_Int | EXTI_No_Int =>
            S.Tx (0) := S.Acc_Data_Reg or Read_Bit;
            Start_Sequence (D, S.Tx (0 .. 6), False);
            Wait (D);
            Fetch (D, Rx);
            S.Acc_Raw := (Word_At (Rx, 1), Word_At (Rx, 2), Word_At (Rx, 3));
         when EXTI_Int_DMA =>
            Fetch (D, Rx);
            Index := Word_Index (S.Acc_Data_Reg, S.DMA_Read_Start);
            if Index <= 5 then
               S.Acc_Raw := (Word_At (Rx, Index), Word_At (Rx, Index + 1), Word_At (Rx, Index + 2));
            end if;
         when EXTI_Init =>
            null;
      end case;
      OK := True;
   end Read_Acc_SPI;

   --  Three big-endian words read from a register.
   procedure Read_Axes (D : in out SPI_Device; Register : Byte; Values : in out Axis_Values; OK : out Boolean) is
      Data : Byte_Array (0 .. 5) := (others => 0);
   begin
      Read_Registers (D, Register, Data, OK);
      if OK then
         for Axis in Values'Range loop
            Values (Axis) :=
              (if Data (2 * Axis) >= 128
               then I16 (Integer (Data (2 * Axis)) * 256 + Integer (Data (2 * Axis + 1)) - 65_536)
               else I16 (Integer (Data (2 * Axis)) * 256 + Integer (Data (2 * Axis + 1))));
         end loop;
      end if;
   end Read_Axes;

   procedure Read_Gyro (D : in out SPI_Device; S : in out State; OK : out Boolean) is
   begin
      Read_Axes (D, S.Gyro_Data_Reg, S.Raw, OK);
   end Read_Gyro;

   procedure Read_Acc (D : in out SPI_Device; S : in out State; OK : out Boolean) is
   begin
      Read_Axes (D, S.Acc_Data_Reg, S.Acc_Raw, OK);
   end Read_Acc;

   function Gyro_DLPF (S : State) return Byte is
      Setting : Byte := 0;
   begin
      if S.Rate_KHz <= Rate_8_kHz then
         case S.Hardware_LPF is
            when LPF_Experimental =>
               if S.Hardware not in Hardware_MPU6050 | Hardware_MPU6000 then
                  Setting := 7;
               end if;
            when others =>
               null;
         end case;
      end if;
      return Setting;
   end Gyro_DLPF;

end Adaflight.MPU_Gyro;
