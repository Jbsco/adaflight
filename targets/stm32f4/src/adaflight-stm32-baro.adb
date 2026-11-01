--  The bus device of the drivers over the board's I2C and SPI buses, read
--  and written within a call: a started read or write runs at once and its
--  bytes wait for the fetch, so the bus never reports busy. The detection
--  scans the drivers the board names, the BMP280 alone so far.
with Adaflight.Sensor_Debug;
with Adaflight.STM32.Debug_Values;
with Interfaces;
with Adaflight.Barometer;
with Adaflight.Barometer_Task;
with Adaflight.Baro_Detect;
with Adaflight.Baro_Detect.Scan;
with Adaflight.STM32.MCU;
with Adaflight.BMP280;
with Adaflight.Board;
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

   Dev         : Device;
   Chip        : BMP280.State;
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
      end if;
   end Detect_Chip;

   package Scan is new Adaflight.Baro_Detect.Scan
     (Bus_Device => Device, Set_I2C_Instance => Set_I2C_Instance, Set_I2C_Address => Set_I2C_Address,
      Set_SPI_Instance => Set_SPI_Instance, Set_CS_Pin => Set_CS_Pin, Detect_Chip => Detect_Chip);

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      B : constant Adaflight.Baro_Detect.Build :=
        (Drivers => (Adaflight.Baro_Detect.BMP280 => Adaflight.Board.Baro_BMP280, others => False),
         SPA06 => False, I2C => True, SPI => True);
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
      Hardware_Id := Adaflight.Baro_Detect.Hardware_None;
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

   function Detected return Boolean is (Found);
   function Hardware return Unsigned_8 is (Hardware_Id);
   function Bus_Type return Unsigned_8 is
     (if not Found or else Virtual then 0 elsif Dev.Use_I2C then Adaflight.Baro_Detect.Bus_I2C else Adaflight.Baro_Detect.Bus_SPI);
   function Bus_Number return Natural is
     (if not Found or else Virtual then 0 elsif Dev.Use_I2C then I2C.Bus'Pos (Dev.I2C_Bus) + 1 else SPI.Bus'Pos (Dev.SPI_Bus) + 1);
   function Bus_Address return Unsigned_8 is (if Found and then Dev.Use_I2C then Dev.Address else 0);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
      Done        : Boolean := False;
      Pressure    : Integer_32 := 0;
      Temperature : Adaflight.Barometer.Temperature_Centi := Baro_State.Temperature;
      Report      : Adaflight.Barometer_Task.Report;
      Started     : constant Unsigned_32 := Adaflight.STM32.Time.Micros;
      Next_State  : Integer_32;
   begin
      Next_Period_Us := 0;
      if not Found then
         return;
      end if;
      if Virtual then
         Done := True;
         if Adaflight.Barometer_Task.Takes_Sample (Task_State, Done) then
            Adaflight.STM32.MCU.Simulator_Pressure (Pressure);
            Temperature := 2_500;
         end if;
      else
         BMP280.Device_Call (Dev, Chip, Adaflight.Barometer_Task.Call (Task_State), Done);
         if Adaflight.Barometer_Task.Takes_Sample (Task_State, Done) then
            BMP280.Calculate (Chip, Pressure, Temperature);
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
      if Found then
         Adaflight.Barometer.Start_Calibration (Baro_State, Settings);
      end if;
   end Start_Calibration;
   procedure Set_Ground_Level is
   begin
      if Found then
         Adaflight.Barometer.Set_Ground_Level (Baro_State);
      end if;
   end Set_Ground_Level;
   function Calibrated return Boolean is (Found and then Baro_State.Calibrated);
   function Altitude_Cm return Float is
     (Float'Max (-4.0e7, Float'Min (4.0e7, Baro_State.Altitude)));
   function Temperature_Centi return Integer_32 is (Baro_State.Temperature);
   function Sample_Time_Us return Unsigned_32 is (Unsigned_32 (Baro_State.Last_Data_Time_Us));
   function Interval_Us return Integer_32 is (Baro_State.Data_Interval_Us);
end Adaflight.STM32.Baro;
