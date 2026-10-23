package body Adaflight.LPS22DF with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   Default_Address   : constant Byte := 16#5D#;
   Who_Am_I          : constant Byte := 16#0F#;
   Chip_Identity     : constant Byte := 16#B4#;
   Control_1         : constant Byte := 16#10#;
   Control_2         : constant Byte := 16#11#;
   Software_Reset    : constant Byte := 16#04#;
   Low_Pass_Config   : constant Byte := 16#20#;
   Low_Pass          : constant Byte := 16#10#;
   Block_Data_Update : constant Byte := 16#08#;
   Rate_10_Hz        : constant Byte := 16#03#;
   Average_512       : constant Byte := 16#07#;
   Pressure_Out_XL   : constant Byte := 16#28#;
   Reset_Timeout_Ms  : constant := 10;
   Max_SPI_Clock_Hz  : constant := 10_000_000;

   procedure Release (D : in out Bus_Device; Default_Applied : Boolean) is
   begin
      if Is_SPI (D) then
         Release_SPI (D);
      end if;
      if Default_Applied then
         Set_I2C_Address (D, 0);
      end if;
   end Release;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Default_Applied : Boolean := False;
      Id              : Byte_Array (0 .. 0) := (0 => S.Chip_Id);
      Reset           : Byte_Array (0 .. 0) := (0 => 0);
      Start           : Interfaces.Unsigned_32;
      Now             : Interfaces.Unsigned_32;
      Ignored         : Boolean;
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
      Read_Registers (D, Who_Am_I, Id, Ignored);
      S.Chip_Id := Id (0);
      if S.Chip_Id /= Chip_Identity then
         Release (D, Default_Applied);
         return;
      end if;
      Register_Device (D);
      Write_Register (D, Control_2, Software_Reset, Ignored);
      Millis (D, Start);
      loop
         Read_Registers (D, Control_2, Reset, Ignored);
         Millis (D, Now);
         if Now - Start in Reset_Timeout_Ms + 1 .. 2 ** 31 - 1 then
            return;
         end if;
         exit when (Reset (0) and Software_Reset) = 0;
      end loop;
      Write_Register (D, Control_2, Low_Pass or Low_Pass_Config or Block_Data_Update, Ignored);
      Write_Register (D, Control_1, Rate_10_Hz * 8 or Average_512, Ignored);
      Device := (Combined_Read => True, Temperature_Delay_Us => 0, Pressure_Delay_Us => 10_000);
      Found := True;
   end Detect;

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
            Start_Read (D, Pressure_Out_XL, S.Sensor_Data'Length, Done);
         when Barometer_Task.Get_Pressure =>
            Check_Busy (D, Busy, Unused_Error);
            if Busy then
               Done := False;
               return;
            end if;
            Fetch (D, S.Sensor_Data);
            S.Raw_Pressure :=
              Interfaces.Integer_32 (S.Sensor_Data (0)) + Interfaces.Integer_32 (S.Sensor_Data (1)) * 2 ** 8
              + Interfaces.Integer_32 (S.Sensor_Data (2)) * 2 ** 16;
            S.Raw_Temperature :=
              Interfaces.Integer_32 (S.Sensor_Data (3)) + Interfaces.Integer_32 (S.Sensor_Data (4)) * 2 ** 8;
            Done := True;
      end case;
   end Device_Call;

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
      Scaled : constant Float := Float (S.Raw_Pressure) * 100.0 / 16.0;
   begin
      pragma Assert (Scaled in 0.0 .. 1.1E8);
      Pressure := Interfaces.Integer_32 (Interfaces.Unsigned_32 (Float'Truncation (Scaled)) / 256);
      Temperature := S.Raw_Temperature;
   end Calculate;

end Adaflight.LPS22DF;
