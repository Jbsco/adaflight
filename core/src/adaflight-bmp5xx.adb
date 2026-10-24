package body Adaflight.BMP5xx with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_64;

   subtype I32 is Interfaces.Integer_32;
   subtype U32 is Interfaces.Unsigned_32;

   Max_SPI_Clock_Hz    : constant := 10_000_000;
   Primary_Address     : constant Byte := 16#47#;
   Secondary_Address   : constant Byte := 16#46#;
   BMP580_Identity     : constant Byte := 16#50#;
   BMP581_Identity     : constant Byte := 16#51#;
   Chip_Id_Register    : constant Byte := 16#01#;
   Interrupt_Config    : constant Byte := 16#14#;
   Interrupt_Source    : constant Byte := 16#15#;
   Data_Register       : constant Byte := 16#1D#;
   DSP_Config          : constant Byte := 16#30#;
   DSP_IIR             : constant Byte := 16#31#;
   OSR_Config          : constant Byte := 16#36#;
   ODR_Config          : constant Byte := 16#37#;
   Command_Register    : constant Byte := 16#7E#;
   Soft_Reset          : constant Byte := 16#B6#;
   Pulsed_High_Enabled : constant Byte := 16#0A#;
   Data_Ready_Source   : constant Byte := 16#01#;
   Compensate_Shadow   : constant Byte := 16#0B#;
   IIR_15_Both         : constant Byte := 16#24#;
   Oversampling        : constant Byte := 16#57#;
   Normal_50_Hz        : constant Byte := 16#3D#;
   Pressure_Delay_Us   : constant := 15_000;

   function Known (Id : Byte) return Boolean is (Id = BMP580_Identity or else Id = BMP581_Identity);

   --  A read of registers, past the dummy byte of a chip on SPI; a failed
   --  read leaves the bytes.
   procedure Read (D : in out Bus_Device; Dummy : Boolean; Register : Byte; Data : in out Byte_Array; OK : out Boolean)
     with Pre => Data'Length in 1 .. Frame_Bytes'Length
   is
   begin
      if Dummy then
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
      Id              : Byte_Array (0 .. 0) := (others => 0);
      Busy            : Boolean;
      Unused_OK       : Boolean;
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
         Set_I2C_Address (D, Primary_Address);
         Default_Applied := True;
      end if;
      if Is_SPI (D) then
         S.Dummy_Byte := True;
      end if;
      Read (D, S.Dummy_Byte, Chip_Id_Register, Id, Unused_OK);
      S.Chip_Id := Id (0);
      if not Known (S.Chip_Id) then
         if Default_Applied then
            Set_I2C_Address (D, Secondary_Address);
            Read (D, S.Dummy_Byte, Chip_Id_Register, Id, Unused_OK);
            S.Chip_Id := Id (0);
            if not Known (S.Chip_Id) then
               if Is_SPI (D) then
                  Release_SPI (D);
               end if;
               Set_I2C_Address (D, 0);
               return;
            end if;
         else
            if Is_SPI (D) then
               Release_SPI (D);
            end if;
            return;
         end if;
      end if;
      Register_Device (D);
      Write_Register (D, Command_Register, Soft_Reset, Unused_OK);
      Delay_Ms (D, 5);
      if EOC_Pin then
         Write_Register (D, Interrupt_Config, Pulsed_High_Enabled, Unused_OK);
         Write_Register (D, Interrupt_Source, Data_Ready_Source, Unused_OK);
      end if;
      Write_Register (D, DSP_Config, Compensate_Shadow, Unused_OK);
      Write_Register (D, DSP_IIR, IIR_15_Both, Unused_OK);
      Write_Register (D, OSR_Config, Oversampling, Unused_OK);
      Write_Register (D, ODR_Config, Normal_50_Hz, Unused_OK);
      Device := (Combined_Read => True, Temperature_Delay_Us => 0, Pressure_Delay_Us => Pressure_Delay_Us);
      loop
         Check_Busy (D, Busy, Unused_Error);
         exit when not Busy;
      end loop;
      Found := True;
   end Detect;

   function Count (Data : Frame_Bytes; First : Natural) return Raw_Count is
     (Raw_Count (U32 (Data (First)) + 256 * U32 (Data (First + 1)) + 65_536 * U32 (Data (First + 2))))
     with Pre => First <= 3;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean) is
   begin
      case Call is
         when Barometer_Task.Start_Temperature | Barometer_Task.Read_Temperature
            | Barometer_Task.Get_Temperature | Barometer_Task.Start_Pressure =>
            Done := True;
         when Barometer_Task.Read_Pressure =>
            Read (D, S.Dummy_Byte, Data_Register, S.Frame, Done);
         when Barometer_Task.Get_Pressure =>
            S.Raw_Temperature := Count (S.Frame, 0);
            S.Raw_Pressure := Count (S.Frame, 3);
            Done := True;
      end case;
   end Device_Call;

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
      Signed : constant I32 :=
        (if S.Raw_Temperature >= 2 ** 23 then I32 (S.Raw_Temperature) - 2 ** 24 else I32 (S.Raw_Temperature));
   begin
      Temperature := I32 (Interfaces.Integer_64 (Signed) * 100 / 65_536);
      Pressure := I32 (S.Raw_Pressure / 64);
   end Calculate;

end Adaflight.BMP5xx;
