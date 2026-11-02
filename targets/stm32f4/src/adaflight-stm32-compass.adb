with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.AK8975;
with Adaflight.AK9916;
with Adaflight.BMM350;
with Adaflight.Board;
with Adaflight.Compass_Detect;
with Adaflight.Compass_Detect.Scan;
with Adaflight.Config_Runtime;
with Adaflight.HMC5883;
with Adaflight.IST8310;
with Adaflight.LIS2MDL;
with Adaflight.LIS3MDL;
with Adaflight.MMC560X;
with Adaflight.QMC5883;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.I2C;
with Adaflight.STM32.MCU;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
with Adaflight.Compass_Debug;
with Adaflight.STM32.Debug_Values;
package body Adaflight.STM32.Compass is
   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Unsigned_32 is Interfaces.Unsigned_32;
   use type Adaflight.Compass_Detect.Driver;
   use type Adaflight.Compass.Beep;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;
   package GPIO renames Adaflight.STM32.GPIO;
   package I2C renames Adaflight.STM32.I2C;
   package SPI renames Adaflight.STM32.SPI;
   package CD renames Adaflight.Compass_Detect;

   Buffer_Size : constant := 32;
   type Device is limited record
      Bus           : Byte := Adaflight.Compass_Detect.Bus_I2C;
      I2C_Bus       : I2C.Bus := I2C.I2C1;
      Address       : Byte := 0;
      SPI_Bus       : SPI.Bus := SPI.SPI1;
      CS            : Pin := (Port_A, 0);
      Has_CS        : Boolean := False;
      Interrupt_Tag : Byte := 0;
      Buffer        : Byte_Array (0 .. Buffer_Size - 1) := (others => 0);
      Failed        : Boolean := False;
   end record;

   function Is_I2C (D : Device) return Boolean is (D.Bus = Adaflight.Compass_Detect.Bus_I2C);
   function Is_SPI (D : Device) return Boolean is (D.Bus = Adaflight.Compass_Detect.Bus_SPI and then D.Has_CS);
   function I2C_Address (D : Device) return Byte is (D.Address);
   procedure Set_I2C_Address (D : in out Device; Address : Byte) is
   begin
      D.Address := Address;
   end Set_I2C_Address;
   procedure Prepare_SPI (D : in out Device; Max_Clock_Hz : Unsigned_32) is
   begin
      SPI.Set_Divisor (D.SPI_Bus, SPI.Divider (Max_Clock_Hz));
   end Prepare_SPI;
   procedure Read_Registers (D : in out Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
   begin
      if Is_I2C (D) then
         I2C.Read (D.I2C_Bus, D.Address, Register, Data, OK);
      elsif Is_SPI (D) then
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
      if Is_I2C (D) then
         I2C.Write (D.I2C_Bus, D.Address, Register, Value, OK);
      elsif Is_SPI (D) then
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
   procedure Fetch (D : in out Device; Data : out Byte_Array) is
   begin
      Data := (others => 0);
      if Data'Length <= Buffer_Size then
         Data := D.Buffer (0 .. Data'Length - 1);
      end if;
   end Fetch;
   procedure Register_Device (D : in out Device) is null;
   procedure Enable_Interrupt (D : in out Device) is null;
   procedure Delay_Ms (D : in out Device; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Ms (Ms);
   end Delay_Ms;
   procedure Delay_Us (D : in out Device; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Time.Delay_Us (Us);
   end Delay_Us;

   package HMC is new Adaflight.HMC5883
     (Bus_Device => Device, Is_I2C => Is_I2C, Is_SPI => Is_SPI, I2C_Address => I2C_Address,
      Set_I2C_Address => Set_I2C_Address, Register_Device => Register_Device, Prepare_SPI => Prepare_SPI,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read, Fetch => Fetch,
      Delay_Ms => Delay_Ms, Enable_Interrupt => Enable_Interrupt);
   package QMC is new Adaflight.QMC5883
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Read_Registers => Read_Registers, Write_Register => Write_Register, Start_Read => Start_Read, Fetch => Fetch,
      Register_Device => Register_Device, Delay_Ms => Delay_Ms);
   package IST is new Adaflight.IST8310
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Start_Read => Start_Read, Start_Write => Start_Write, Fetch => Fetch, Delay_Ms => Delay_Ms);
   package LIS3 is new Adaflight.LIS3MDL
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Start_Read => Start_Read, Fetch => Fetch, Delay_Ms => Delay_Ms);
   package LIS2 is new Adaflight.LIS2MDL
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Start_Read => Start_Read, Fetch => Fetch);
   package AK75 is new Adaflight.AK8975
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Start_Read => Start_Read, Start_Write => Start_Write, Fetch => Fetch, Delay_Ms => Delay_Ms);
   package AK16 is new Adaflight.AK9916
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Delay_Ms => Delay_Ms);
   package MMC is new Adaflight.MMC560X
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Delay_Ms => Delay_Ms);
   package BMM is new Adaflight.BMM350
     (Bus_Device => Device, Is_I2C => Is_I2C, I2C_Address => I2C_Address, Set_I2C_Address => Set_I2C_Address,
      Register_Device => Register_Device, Read_Registers => Read_Registers, Write_Register => Write_Register,
      Delay_Ms => Delay_Ms, Delay_Us => Delay_Us);

   Dev          : Device;
   Kind         : Adaflight.Compass_Detect.Driver := Adaflight.Compass_Detect.Virtual;
   Found        : Boolean := False;
   Virtual_Dev  : Boolean := False;
   Hardware_Id  : Byte := Adaflight.Compass_Detect.Hardware_None;
   HMC_State    : HMC.State;
   QMC_State    : QMC.State;
   IST_State    : IST.State;
   LIS3_State   : LIS3.State;
   LIS2_State   : LIS2.State;
   AK75_State   : AK75.State;
   AK16_State   : AK16.State;
   MMC_State    : MMC.State;
   BMM_State    : BMM.State;
   Settings     : Adaflight.Compass.Settings;
   State        : Adaflight.Compass.State;
   Gyro_Rates   : Adaflight.Vectors.Vector3 := (0.0, 0.0, 0.0);
   Pending_Beep : Adaflight.Compass.Beep := Adaflight.Compass.Silence;
   Save_Pending : Boolean := False;
   Saved_Zero   : Adaflight.Compass.Zero_Offsets := (others => 0);

   function Bus_Type_Of (D : Device) return Byte is (D.Bus);
   procedure Set_Interrupt_Pin (D : in out Device; Tag : Byte) is
   begin
      D.Interrupt_Tag := Tag;
   end Set_Interrupt_Pin;
   procedure Set_I2C_Instance (D : in out Device; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 4 and then I2C.Started (I2C.Bus'Val (Instance - 1));
      if OK then
         D.I2C_Bus := I2C.Bus'Val (Instance - 1);
         D.Bus := Adaflight.Compass_Detect.Bus_I2C;
      end if;
   end Set_I2C_Instance;
   procedure Set_SPI_Instance (D : in out Device; Instance : Byte; OK : out Boolean) is
   begin
      OK := Instance in 1 .. 6 and then SPI.Started (SPI.Bus'Val (Instance - 1));
      if OK then
         D.SPI_Bus := SPI.Bus'Val (Instance - 1);
         D.Bus := Adaflight.Compass_Detect.Bus_SPI;
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
   procedure Set_MPU_Slave (D : in out Device; Address : Byte) is null;
   procedure Set_Bus_Type (D : in out Device; Bus : Byte) is
   begin
      D.Bus := Bus;
   end Set_Bus_Type;
   procedure Detect_DroneCAN (D : in out Device; Found : out Boolean) is
      pragma Unreferenced (D);
   begin
      Found := False;
   end Detect_DroneCAN;
   procedure Detect_Chip (D : in out Device; Chip : Adaflight.Compass_Detect.Driver; Found : out Boolean) is
   begin
      case Chip is
         when CD.HMC5883  => HMC.Detect (D, Found);
         when CD.LIS2MDL  => LIS2.Detect (D, Found);
         when CD.LIS3MDL  => LIS3.Detect (D, Found);
         when CD.AK9916   => AK16.Detect (D, Found);
         when CD.AK8975   => AK75.Detect (D, Found);
         when CD.QMC5883L => QMC.Detect_L (D, QMC_State, Found);
         when CD.QMC5883P => QMC.Detect_P (D, QMC_State, Found);
         when CD.IST8310  => IST.Detect (D, Found);
         when CD.MMC560X  => MMC.Detect (D, Found);
         when CD.BMM350   => BMM.Detect (D, Found);
         when CD.Virtual  => Found := Adaflight.STM32.MCU.Simulated;
         when CD.AK8963 | CD.MPU925X => Found := False;
      end case;
      if Found then
         Kind := Chip;
      end if;
   end Detect_Chip;

   package Scan is new Adaflight.Compass_Detect.Scan
     (Bus_Device => Device, Bus_Type => Bus_Type_Of, Set_Interrupt_Pin => Set_Interrupt_Pin,
      Set_I2C_Instance => Set_I2C_Instance, Set_I2C_Address => Set_I2C_Address, Set_SPI_Instance => Set_SPI_Instance,
      Set_CS_Pin => Set_CS_Pin, Set_MPU_Slave => Set_MPU_Slave, Set_Bus_Type => Set_Bus_Type,
      Detect_DroneCAN => Detect_DroneCAN, Detect_Chip => Detect_Chip);

   procedure Init (C : Adaflight.Config_Groups.Configuration) is
      B : constant CD.Build :=
        (I2C => True, SPI => True, MPU_Slave => False, DroneCAN => False,
         Simulator => Adaflight.STM32.MCU.Simulated, Mag_Align => Adaflight.Board.Mag_Align);
      Cfg : constant CD.Config :=
        (Hardware      => C.Compass_Config.Mag_Hardware,
         Bus_Type      => C.Compass_Config.Mag_Bus_Type,
         I2C_Device    => C.Compass_Config.Mag_I2c_Device,
         I2C_Address   => C.Compass_Config.Mag_I2c_Address,
         SPI_Device    => C.Compass_Config.Mag_Spi_Device,
         SPI_CS        => C.Compass_Config.Mag_Spi_Csn,
         Interrupt_Tag => C.Compass_Config.Interrupt_Tag);
      Alignment : Byte;
      Detected  : Byte := CD.Hardware_None;
      OK        : Boolean := True;
      Odr       : Natural := 0;
      Chosen    : Adaflight.Config_Groups.Compass_Config_Record := C.Compass_Config;
   begin
      Found := False;
      Virtual_Dev := False;
      Hardware_Id := CD.Hardware_None;
      Kind := CD.Virtual;
      Scan.Detect (Dev, B, Cfg, Gyro_Is_MPU9250 => False, Detected => Detected, Alignment => Alignment, Found => Found);
      if not Found then
         return;
      end if;
      Virtual_Dev := Kind = CD.Virtual;
      case Kind is
         when CD.HMC5883 =>
            HMC.Init (Dev, HMC_State, Interrupt_Pin => Dev.Interrupt_Tag /= 0, OK => OK);
            Odr := HMC_State.ODR_Hz;
         when CD.QMC5883L | CD.QMC5883P =>
            QMC.Init (Dev, QMC_State, OK);
            Odr := QMC_State.ODR_Hz;
         when CD.IST8310 =>
            IST.Init (Dev, IST_State, OK);
            Odr := IST_State.ODR_Hz;
         when CD.LIS3MDL =>
            LIS3.Init (Dev, LIS3_State, OK);
            Odr := LIS3_State.ODR_Hz;
         when CD.LIS2MDL =>
            LIS2.Init (Dev, LIS2_State, OK);
            Odr := LIS2_State.ODR_Hz;
         when CD.AK8975 =>
            AK75.Init (Dev, AK75_State, OK);
            Odr := AK75_State.ODR_Hz;
         when CD.AK9916 =>
            AK16.Init (Dev, AK16_State, OK);
            Odr := AK16_State.ODR_Hz;
         when CD.MMC560X =>
            MMC.Init (Dev, MMC_State, OK);
            Odr := MMC_State.ODR_Hz;
         when CD.BMM350 =>
            BMM.Init (Dev, BMM_State, OK);
            Odr := BMM_State.ODR_Hz;
         when CD.Virtual | CD.AK8963 | CD.MPU925X =>
            null;
      end case;
      if not OK then
         Found := False;
         Virtual_Dev := False;
         return;
      end if;
      Hardware_Id := Detected;
      if Chosen.Mag_Alignment = 0 then
         Chosen.Mag_Alignment := Alignment;
      end if;
      Settings := Adaflight.Config_Runtime.Compass_Settings_Of
        (Chosen, C.Board_Alignment, (if Odr in 16 .. 400 then Odr else 0));
      Adaflight.Compass.Init (State, Settings);
   end Init;

   function Detected return Boolean is (Found);
   function Hardware return Unsigned_8 is (Hardware_Id);
   function Bus_Type return Unsigned_8 is
     (if not Found or else Virtual_Dev then 0 elsif Is_I2C (Dev) then 1 elsif Is_SPI (Dev) then 2 else 0);
   function Bus_Number return Natural is
     (if not Found or else Virtual_Dev then 0
      elsif Is_I2C (Dev) then I2C.Bus'Pos (Dev.I2C_Bus) + 1
      elsif Is_SPI (Dev) then SPI.Bus'Pos (Dev.SPI_Bus) + 1
      else 0);
   function Bus_Address return Unsigned_8 is
     (if Found and then not Virtual_Dev and then Is_I2C (Dev) then Dev.Address else 0);

   procedure Update (Now_Us : Adaflight.Scheduler.Time_Us; Next_Period_Us : out Adaflight.Scheduler.Time_Delta) is
      Got    : Boolean := False;
      Sample : Adaflight.Compass.Raw_Vector := (others => 0);
      Next   : Natural;
      A      : array (0 .. 2) of Interfaces.Integer_16 := (others => 0);
   begin
      Next_Period_Us := 0;
      if not Found then
         return;
      end if;
      case Kind is
         when CD.Virtual =>
            declare
               F : Adaflight.STM32.MCU.Mag_Field;
            begin
               Adaflight.STM32.MCU.Simulator_Mag (F);
               A := (F (0), F (1), F (2));
               Got := True;
            end;
         when CD.HMC5883 =>
            declare
               D : HMC.Axes := (others => 0);
            begin
               HMC.Read (Dev, HMC_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.QMC5883L | CD.QMC5883P =>
            declare
               D : QMC.Axes := (others => 0);
            begin
               QMC.Read (Dev, QMC_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.IST8310 =>
            declare
               D : IST.Axes := (others => 0);
            begin
               IST.Read (Dev, IST_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.LIS3MDL =>
            declare
               D : LIS3.Axes := (others => 0);
            begin
               LIS3.Read (Dev, LIS3_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.LIS2MDL =>
            declare
               D : LIS2.Axes := (others => 0);
            begin
               LIS2.Read (Dev, LIS2_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.AK8975 =>
            declare
               D : AK75.Axes := (others => 0);
            begin
               AK75.Read (Dev, AK75_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.AK9916 =>
            declare
               D : AK16.Axes := (others => 0);
            begin
               AK16.Read (Dev, AK16_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.MMC560X =>
            declare
               D : MMC.Axes := (others => 0);
            begin
               MMC.Read (Dev, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.BMM350 =>
            declare
               D : BMM.Axes := (others => 0);
            begin
               BMM.Read (Dev, BMM_State, D, Got);
               A := (D (0), D (1), D (2));
            end;
         when CD.AK8963 | CD.MPU925X =>
            Got := False;
      end case;
      Sample := (Adaflight.Vectors.X => Integer (A (0)), Adaflight.Vectors.Y => Integer (A (1)),
                 Adaflight.Vectors.Z => Integer (A (2)));
      Adaflight.Compass.Read_Cycle
        (State, Settings, Bus_Busy => False, Data_Ready => Got, Sample => Sample, Gyro => Gyro_Rates, Now_Us => Now_Us,
         Next_Period_Us => Next);
      Next_Period_Us := Adaflight.Scheduler.Time_Delta (Next);
      Adaflight.Compass_Debug.Record_Cycle
        (Adaflight.STM32.Debug_Values.State, State, Adaflight.STM32.Time.Micros - Now_Us);
      if State.Beeper /= Adaflight.Compass.Silence then
         Pending_Beep := State.Beeper;
      end if;
      if State.Save_Requested then
         Save_Pending := True;
         Saved_Zero := State.Zero;
      end if;
   end Update;

   procedure Set_Gyro (Rates : Adaflight.Vectors.Vector3) is
      function Held (V : Float) return Float is (Float'Max (-1.0e6, Float'Min (1.0e6, V)));
   begin
      Gyro_Rates := (X => Held (Rates.X), Y => Held (Rates.Y), Z => Held (Rates.Z));
   end Set_Gyro;

   procedure Start_Calibration is
   begin
      if Found then
         Adaflight.Compass.Start_Calibration (State, Adaflight.STM32.Time.Micros);
      end if;
   end Start_Calibration;

   function Calibrated return Boolean is (Found and then State.Calibrated);
   function Enabled_And_Calibrated return Boolean is
     (Found and then Adaflight.Compass.Enabled_And_Calibrated (State));
   function Field return Adaflight.Vectors.Vector3 is
     (X => State.Field (Adaflight.Vectors.X), Y => State.Field (Adaflight.Vectors.Y),
      Z => State.Field (Adaflight.Vectors.Z));

   procedure Take_Beep (B : out Adaflight.Compass.Beep) is
   begin
      B := Pending_Beep;
      Pending_Beep := Adaflight.Compass.Silence;
   end Take_Beep;

   procedure Take_Save (Requested : out Boolean; Zero : out Adaflight.Compass.Zero_Offsets) is
   begin
      Requested := Save_Pending;
      Zero := Saved_Zero;
      Save_Pending := False;
   end Take_Save;
end Adaflight.STM32.Compass;
