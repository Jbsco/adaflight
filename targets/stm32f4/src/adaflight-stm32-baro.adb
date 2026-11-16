--  The bus device of the drivers over the board's I2C and SPI buses, read
--  and written within a call: a started read or write runs at once and its
--  bytes wait for the fetch, so the bus never reports busy. The detection
--  scans the drivers the board names, the MS5611, the DPS310, the BMP388,
--  the BMP280, the QMP6988 and the LPS22DF so far, and the chip it finds
--  takes the task's calls and gives the samples. The MS5611 takes commands,
--  which go out as they are. The BMP388 runs without its end of conversion
--  pin.
with Adaflight.Sensor_Debug;
with Adaflight.STM32.Debug_Values;
with Interfaces;
with Adaflight.Barometer;
with Adaflight.Barometer_Task;
with Adaflight.Baro_Detect;
with Adaflight.Baro_Detect.Scan;
with Adaflight.STM32.MCU;
with Adaflight.BMP280;
with Adaflight.BMP388;
with Adaflight.Board;
with Adaflight.DPS310;
with Adaflight.LPS22DF;
with Adaflight.MS5611;
with Adaflight.QMP6988;
with Adaflight.Build_Features;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.I2C;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Baro is
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   subtype Integer_32 is Interfaces.Integer_32;
   use type Adaflight.Baro_Detect.Driver;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;
   package GPIO renames Adaflight.STM32.GPIO;
   package I2C renames Adaflight.STM32.I2C;
   package SPI renames Adaflight.STM32.SPI;

   Buffer_Size : constant := 32;
   type Device is limited record
      Use_I2C : Boolean := False;
      I2C_Bus : I2C.Bus := I2C.I2C1;
      Address : Byte := 0;
      SPI_Bus : SPI.Bus := SPI.SPI1;
      CS      : Pin := (Port_A, 0);
      Has_CS  : Boolean := False;
      Buffer  : Byte_Array (0 .. Buffer_Size - 1) := (others => 0);
      Failed  : Boolean := False;
   end record;

   function Is_I2C (D : Device) return Boolean is (D.Use_I2C);
   function Is_SPI (D : Device) return Boolean is (not D.Use_I2C and then D.Has_CS);
   function I2C_Address (D : Device) return Byte is (D.Address);
   procedure Set_I2C_Address (D : in out Device; Address : Byte) is
   begin
      D.Address := Address;
   end Set_I2C_Address;
   procedure Prepare_SPI (D : in out Device; Max_Clock_Hz : Unsigned_32) is
   begin
      SPI.Set_Divisor (D.SPI_Bus, SPI.Divider (Max_Clock_Hz));
      GPIO.Set_Low (D.CS);
   end Prepare_SPI;
   procedure Release_SPI (D : in out Device) is
   begin
      GPIO.Set_High (D.CS);
   end Release_SPI;
   procedure Read_Registers (D : in out Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
   begin
      if D.Use_I2C then
         I2C.Read (D.I2C_Bus, D.Address, Register, Data, OK);
      elsif D.Has_CS then
         declare
            Tx : Byte_Array (0 .. Data'Length) := (others => 0);
            Rx : Byte_Array (0 .. Data'Length) := (others => 0);
         begin
            Tx (0) := Register or 16#80#;
            GPIO.Set_Low (D.CS);
            SPI.Transfer (D.SPI_Bus, Tx, Rx);
            GPIO.Set_High (D.CS);
            Data := Rx (1 .. Data'Length);
            OK := True;
         end;
      else
         OK := False;
      end if;
   end Read_Registers;
   procedure Write_Register (D : in out Device; Register : Byte; Value : Byte; OK : out Boolean) is
   begin
      if D.Use_I2C then
         I2C.Write (D.I2C_Bus, D.Address, Register, Value, OK);
      elsif D.Has_CS then
         declare
            Rx : Byte_Array (0 .. 1) := (others => 0);
         begin
            GPIO.Set_Low (D.CS);
            SPI.Transfer (D.SPI_Bus, (Register and 16#7F#, Value), Rx);
            GPIO.Set_High (D.CS);
            OK := True;
         end;
      else
         OK := False;
      end if;
   end Write_Register;
   procedure Start_Read (D : in out Device; Register : Byte; Length : Positive; Started : out Boolean) is
      OK : Boolean;
   begin
      if Length > Buffer_Size then
         Started := False;
         return;
      end if;
      Read_Registers (D, Register, D.Buffer (0 .. Length - 1), OK);
      D.Failed := not OK;
      Started := True;
   end Start_Read;
   procedure Start_Write (D : in out Device; Register : Byte; Value : Byte; Started : out Boolean) is
      OK : Boolean;
   begin
      Write_Register (D, Register, Value, OK);
      D.Failed := not OK;
      Started := True;
   end Start_Write;
   procedure Check_Busy (D : in out Device; Busy : out Boolean; Error : out Boolean) is
   begin
      Busy := False;
      Error := D.Failed;
   end Check_Busy;
   procedure Fetch (D : in out Device; Data : out Byte_Array) is
   begin
      Data := (others => 0);
      if Data'Length <= Buffer_Size then
         Data := D.Buffer (0 .. Data'Length - 1);
      end if;
   end Fetch;
   --  A command sent as it is: an SPI read without the read bit and a write
   --  without the mask.
   procedure Raw_Read (D : in out Device; Command : Byte; Data : in out Byte_Array; OK : out Boolean) is
   begin
      if D.Use_I2C then
         I2C.Read (D.I2C_Bus, D.Address, Command, Data, OK);
      elsif D.Has_CS then
         declare
            Tx : Byte_Array (0 .. Data'Length) := (others => 0);
            Rx : Byte_Array (0 .. Data'Length) := (others => 0);
         begin
            Tx (0) := Command;
            GPIO.Set_Low (D.CS);
            SPI.Transfer (D.SPI_Bus, Tx, Rx);
            GPIO.Set_High (D.CS);
            Data := Rx (1 .. Data'Length);
            OK := True;
         end;
      else
         OK := False;
      end if;
   end Raw_Read;
   procedure Raw_Write (D : in out Device; Command : Byte; Value : Byte; OK : out Boolean) is
   begin
      if D.Use_I2C then
         I2C.Write (D.I2C_Bus, D.Address, Command, Value, OK);
      elsif D.Has_CS then
         declare
            Rx : Byte_Array (0 .. 1) := (others => 0);
         begin
            GPIO.Set_Low (D.CS);
            SPI.Transfer (D.SPI_Bus, (Command, Value), Rx);
            GPIO.Set_High (D.CS);
            OK := True;
         end;
      else
         OK := False;
      end if;
   end Raw_Write;
   procedure Raw_Start_Read (D : in out Device; Command : Byte; Length : Positive; Started : out Boolean) is
      OK : Boolean;
   begin
      if Length > Buffer_Size then
         Started := False;
         return;
      end if;
      Raw_Read (D, Command, D.Buffer (0 .. Length - 1), OK);
      D.Failed := not OK;
      Started := True;
   end Raw_Start_Read;
   procedure Raw_Start_Write (D : in out Device; Command : Byte; Value : Byte; Started : out Boolean) is
      OK : Boolean;
   begin
      Raw_Write (D, Command, Value, OK);
      D.Failed := not OK;
      Started := True;
   end Raw_Start_Write;
   procedure Register_Device (D : in out Device) is null;
   procedure Delay_Ms (D : in out Device; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Ms (Ms);
   end Delay_Ms;

   package BMP280 is new Adaflight.BMP280
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Release_SPI => Release_SPI,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read,
      Start_Write => Start_Write, Check_Busy => Check_Busy, Fetch => Fetch, Register_Device => Register_Device,
      Delay_Ms => Delay_Ms);

   package DPS310 is new Adaflight.DPS310
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Release_SPI => Release_SPI,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read,
      Check_Busy => Check_Busy, Fetch => Fetch, Register_Device => Register_Device, Delay_Ms => Delay_Ms);

   --  The identity of an SPL07-003, which the DPS310 driver also finds, and
   --  the variant the detection names an SPA06-003 from.
   SPL07_Id      : constant Byte := 16#11#;
   SPL07_Variant : constant Byte := 1;
   procedure Delay_Us (D : in out Device; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Us (Us);
   end Delay_Us;

   package MS5611 is new Adaflight.MS5611
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Release_SPI => Release_SPI,
      Raw_Read => Raw_Read, Raw_Write => Raw_Write, Raw_Start_Read => Raw_Start_Read,
      Raw_Start_Write => Raw_Start_Write, Check_Busy => Check_Busy, Fetch => Fetch,
      Register_Device => Register_Device, Delay_Ms => Delay_Ms, Delay_Us => Delay_Us);

   procedure No_EOC_Interrupt (D : in out Device) is null;

   package BMP388 is new Adaflight.BMP388
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Release_SPI => Release_SPI,
      Enable_EOC_Interrupt => No_EOC_Interrupt, Release_EOC_Interrupt => No_EOC_Interrupt,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read,
      Start_Write => Start_Write, Check_Busy => Check_Busy, Fetch => Fetch, Register_Device => Register_Device,
      Delay_Ms => Delay_Ms);

   procedure Millis (D : in out Device; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Adaflight.STM32.Time.Millis;
   end Millis;

   package LPS22DF is new Adaflight.LPS22DF
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Release_SPI => Release_SPI,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read,
      Check_Busy => Check_Busy, Fetch => Fetch, Register_Device => Register_Device, Delay_Ms => Delay_Ms,
      Millis => Millis);

   package QMP6988 is new Adaflight.QMP6988
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Prepare_SPI => Prepare_SPI, Return_CS => Release_SPI,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read,
      Check_Busy => Check_Busy, Fetch => Fetch, Register_Device => Register_Device, Delay_Ms => Delay_Ms);

   type Chip_Kind is
     (No_Chip, BMP280_Chip, DPS310_Chip, MS5611_Chip, BMP388_Chip, LPS22DF_Chip, QMP6988_Chip);
   Dev         : Device;
   Kind        : Chip_Kind := No_Chip;
   Chip        : BMP280.State;
   DPS         : DPS310.State;
   MS          : MS5611.State;
   B388        : BMP388.State;
   LPS         : LPS22DF.State;
   QMP         : QMP6988.State;
   Task_Device : Adaflight.Barometer_Task.Device;
   Task_State  : Adaflight.Barometer_Task.State;
   Baro_State  : Adaflight.Barometer.State;
   Settings    : Adaflight.Barometer.Settings;
   Found       : Boolean := False;
   Virtual     : Boolean := False;
   Hardware_Id : Byte := Adaflight.Baro_Detect.Hardware_None;

   --  The scan's bus selection over the board's buses, and the chip probe
   --  of each driver the board names.
   procedure Set_I2C_Instance (D : in out Device; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 4 and then I2C.Started (I2C.Bus'Val (Instance - 1));
      if OK then
         D.I2C_Bus := I2C.Bus'Val (Instance - 1);
         D.Use_I2C := True;
      end if;
   end Set_I2C_Instance;
   procedure Set_SPI_Instance (D : in out Device; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 6 and then SPI.Started (SPI.Bus'Val (Instance - 1));
      if OK then
         D.SPI_Bus := SPI.Bus'Val (Instance - 1);
         D.Use_I2C := False;
      end if;
   end Set_SPI_Instance;
   procedure Set_CS_Pin (D : in out Device; Tag : Byte) is
   begin
      D.Has_CS := Tag /= 0;
      if D.Has_CS then
         D.CS := Pin_Of (Natural (Tag));
         GPIO.Enable_Port (D.CS.Port);
         GPIO.Set_Output (D.CS);
         GPIO.Set_High (D.CS);
      end if;
   end Set_CS_Pin;
   procedure Detect_Chip
     (D : in out Device; Which : Adaflight.Baro_Detect.Driver; EOC_Tag, XCLR_Tag : Byte; Found : out Boolean;
      Variant : out Byte)
   is
      pragma Unreferenced (EOC_Tag, XCLR_Tag);
   begin
      Variant := 0;
      Found := False;
      if Which = Adaflight.Baro_Detect.BMP280 and then Adaflight.Board.Baro_BMP280 then
         BMP280.Detect (D, Chip, Found, Task_Device);
         if Found then
            Kind := BMP280_Chip;
         end if;
      elsif Which = Adaflight.Baro_Detect.DPS310 and then Adaflight.Board.Baro_DPS310 then
         DPS310.Detect (D, DPS, Found, Task_Device);
         if Found then
            Kind := DPS310_Chip;
            Variant := (if DPS.Chip_Id = SPL07_Id then SPL07_Variant else 0);
         end if;
      elsif Which = Adaflight.Baro_Detect.MS5611 and then Adaflight.Board.Baro_MS5611 then
         MS5611.Detect (D, MS, Found, Task_Device);
         if Found then
            Kind := MS5611_Chip;
         end if;
      elsif Which = Adaflight.Baro_Detect.BMP388 and then Adaflight.Board.Baro_BMP388 then
         BMP388.Detect (D, B388, False, Found, Task_Device);
         if Found then
            Kind := BMP388_Chip;
         end if;
      elsif Which = Adaflight.Baro_Detect.LPS22DF and then Adaflight.Board.Baro_LPS22DF then
         LPS22DF.Detect (D, LPS, Found, Task_Device);
         if Found then
            Kind := LPS22DF_Chip;
         end if;
      elsif Which = Adaflight.Baro_Detect.QMP6988 and then Adaflight.Board.Baro_QMP6988 then
         QMP6988.Detect (D, QMP, Found, Task_Device);
         if Found then
            Kind := QMP6988_Chip;
         end if;
      end if;
   end Detect_Chip;

   package Scan is new Adaflight.Baro_Detect.Scan
     (Bus_Device => Device, Set_I2C_Instance => Set_I2C_Instance, Set_I2C_Address => Set_I2C_Address,
      Set_SPI_Instance => Set_SPI_Instance, Set_CS_Pin => Set_CS_Pin, Detect_Chip => Detect_Chip);

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      B : constant Adaflight.Baro_Detect.Build :=
        (Drivers => (Adaflight.Baro_Detect.BMP280 => Adaflight.Board.Baro_BMP280,
                     Adaflight.Baro_Detect.DPS310 => Adaflight.Board.Baro_DPS310,
                     Adaflight.Baro_Detect.MS5611 => Adaflight.Board.Baro_MS5611,
                     Adaflight.Baro_Detect.BMP388 => Adaflight.Board.Baro_BMP388,
                     Adaflight.Baro_Detect.LPS22DF => Adaflight.Board.Baro_LPS22DF,
                     Adaflight.Baro_Detect.QMP6988 => Adaflight.Board.Baro_QMP6988,
                     others                       => False),
         SPA06 => Adaflight.Board.Baro_SPA06, I2C => True, SPI => True);
      Bus : constant Adaflight.Baro_Detect.Bus_Config :=
        (Bus_Type    => C.Barometer_Config.Baro_Bus_Type,
         I2C_Device  => C.Barometer_Config.Baro_I2c_Device,
         I2C_Address => C.Barometer_Config.Baro_I2c_Address,
         SPI_Device  => C.Barometer_Config.Baro_Spi_Device,
         SPI_CS      => C.Barometer_Config.Baro_Spi_Csn,
         EOC_Tag     => C.Barometer_Config.Baro_Eoc_Tag,
         XCLR_Tag    => C.Barometer_Config.Baro_Xclr_Tag);
      Drift : constant Integer := Integer (C.Barometer_Config.Baro_Temp_Drift_Cm_Per10_C);
   begin
      Found := False;
      Kind := No_Chip;
      Hardware_Id := Adaflight.Baro_Detect.Hardware_None;
      if not Adaflight.Build_Features.Barometer then
         return;
      end if;
      Adaflight.Barometer.Init (Baro_State);
      Settings := (Temperature_Drift_Cm_Per_10C => Integer'Max (-500, Integer'Min (500, Drift)),
                   Virtual_Device => False);
      if Adaflight.STM32.MCU.Simulated then
         Found := True;
         Virtual := True;
         Settings.Virtual_Device := True;
         Hardware_Id := Adaflight.Baro_Detect.Named (Adaflight.Baro_Detect.Virtual, 0, False);
         Task_Device := (Combined_Read => True, Temperature_Delay_Us => 10_000, Pressure_Delay_Us => 10_000);
         return;
      end if;
      if Adaflight.Board.Baro_I2C_Device = 0 and then Adaflight.Board.Baro_SPI_Device = 0 then
         return;
      end if;
      Scan.Detect (Dev, B, Bus, C.Barometer_Config.Baro_Hardware, Hardware_Id, Found);
      if not Found then
         Hardware_Id := Adaflight.Baro_Detect.Hardware_None;
      end if;
   end Init;

   function Live return Boolean is (Adaflight.Build_Features.Barometer and then Found);

   function Detected return Boolean is (Live);
   function Hardware return Unsigned_8 is (Hardware_Id);
   function Bus_Type return Unsigned_8 is
     (if not Live or else Virtual then 0 elsif Dev.Use_I2C then Adaflight.Baro_Detect.Bus_I2C else Adaflight.Baro_Detect.Bus_SPI);
   function Bus_Number return Natural is
     (if not Live or else Virtual then 0 elsif Dev.Use_I2C then I2C.Bus'Pos (Dev.I2C_Bus) + 1 else SPI.Bus'Pos (Dev.SPI_Bus) + 1);
   function Bus_Address return Unsigned_8 is (if Live and then Dev.Use_I2C then Dev.Address else 0);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
      Done        : Boolean := False;
      Pressure    : Integer_32 := 0;
      Temperature : Adaflight.Barometer.Temperature_Centi := Baro_State.Temperature;
      Report      : Adaflight.Barometer_Task.Report;
      Started     : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Next_State  : Integer_32;
   begin
      Next_Period_Us := 0;
      if not Live then
         return;
      end if;
      if Virtual then
         Done := True;
         if Adaflight.Barometer_Task.Takes_Sample (Task_State, Done) then
            Adaflight.STM32.MCU.Simulator_Pressure (Pressure);
            Temperature := 2_500;
         end if;
      else
         case Kind is
            when DPS310_Chip =>
               if Adaflight.Board.Baro_DPS310 then
                  DPS310.Device_Call (Dev, DPS, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
            when MS5611_Chip =>
               if Adaflight.Board.Baro_MS5611 then
                  MS5611.Device_Call (Dev, MS, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
            when BMP388_Chip =>
               if Adaflight.Board.Baro_BMP388 then
                  BMP388.Device_Call (Dev, B388, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
            when LPS22DF_Chip =>
               if Adaflight.Board.Baro_LPS22DF then
                  LPS22DF.Device_Call (Dev, LPS, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
            when QMP6988_Chip =>
               if Adaflight.Board.Baro_QMP6988 then
                  QMP6988.Device_Call (Dev, QMP, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
            when BMP280_Chip | No_Chip =>
               if Adaflight.Board.Baro_BMP280 then
                  BMP280.Device_Call (Dev, Chip, Adaflight.Barometer_Task.Call (Task_State), Done);
               end if;
         end case;
         if Adaflight.Barometer_Task.Takes_Sample (Task_State, Done) then
            if Kind = DPS310_Chip and then Adaflight.Board.Baro_DPS310 then
               DPS310.Calculate (DPS, Pressure, Temperature);
            elsif Kind = MS5611_Chip and then Adaflight.Board.Baro_MS5611 then
               MS5611.Calculate (MS, Pressure, Temperature);
            elsif Kind = BMP388_Chip and then Adaflight.Board.Baro_BMP388 then
               BMP388.Calculate (B388, Pressure, Temperature);
            elsif Kind = LPS22DF_Chip and then Adaflight.Board.Baro_LPS22DF then
               LPS22DF.Calculate (LPS, Pressure, Temperature);
            elsif Kind = QMP6988_Chip and then Adaflight.Board.Baro_QMP6988 then
               QMP6988.Calculate (QMP, Pressure, Temperature);
            elsif Adaflight.Board.Baro_BMP280 then
               BMP280.Calculate (Chip, Pressure, Temperature);
            end if;
            Temperature := Adaflight.Barometer.Temperature_Centi'Max
              (Adaflight.Barometer.Temperature_Centi'First,
               Adaflight.Barometer.Temperature_Centi'Min (Adaflight.Barometer.Temperature_Centi'Last, Temperature));
         end if;
      end if;
      Adaflight.Barometer_Task.Step
        (Task_State, Baro_State, Settings, Task_Device, Now_Us, Bus_Busy => False, Done => Done,
         Pressure => Pressure, Temperature => Temperature, R => Report);
      Adaflight.Sensor_Debug.Record_Baro (Adaflight.STM32.Debug_Values.State, Task_State, Baro_State);
      Adaflight.Barometer_Task.Finish (Task_State, Report.Ran, Adaflight.STM32.Time.Micros - Started, Next_State);
      Next_Period_Us := Adaflight.Scheduler.Time_Delta (Unsigned_32'Min (Report.Sleep_Us, 2 ** 30));
   end Update;

   procedure Start_Calibration is
   begin
      if Live then
         Adaflight.Barometer.Start_Calibration (Baro_State, Settings);
      end if;
   end Start_Calibration;
   procedure Set_Ground_Level is
   begin
      if Live then
         Adaflight.Barometer.Set_Ground_Level (Baro_State);
      end if;
   end Set_Ground_Level;
   function Calibrated return Boolean is (Live and then Baro_State.Calibrated);
   function Altitude_Cm return Float is
     (Float'Max (-4.0e7, Float'Min (4.0e7, Baro_State.Altitude)));
   function Temperature_Centi return Integer_32 is (Baro_State.Temperature);
   function Pressure return Integer_32 is (Baro_State.Pressure);
   function Sample_Time_Us return Unsigned_32 is (Unsigned_32 (Baro_State.Last_Data_Time_Us));
   function Interval_Us return Integer_32 is (Baro_State.Data_Interval_Us);
end Adaflight.STM32.Baro;
