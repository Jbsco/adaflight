with Adaflight.Acc_Detect;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Gyro_Detect;
with Adaflight.Gyro_Start;
with Adaflight.MPU_Gyro;
with Adaflight.MPU_Gyro.BMI270;
with Adaflight.MPU_Gyro.ICM20689;
with Adaflight.MPU_Gyro.ICM426xx;
with Adaflight.MPU_Gyro.LSM6DSV16X;
with Adaflight.MPU_Gyro.MPU6000;
with Adaflight.MPU_Gyro.MPU6500;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.EXTI_Dispatch;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.Gyro_Clock;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Gyro_Chip is
   --  A gyro's bus from the board's configuration, SPI1 when it names none.
   function Bus_Of (Device_Number : Natural) return SPI.Bus is
     (if Device_Number in 1 .. 6 then SPI.Bus'Val (Device_Number - 1) else SPI.SPI1);
   --  The board's gyros by position.
   subtype Gyro_Position is Natural range 0 .. Adaflight.Board.Gyro_Count - 1;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   Read_Bit : constant Byte := 16#80#;

   --  A gyro's SPI device: its position, its bus, its select pin, its data
   --  ready line and whether the board has that line, the bytes the last
   --  transfer brought in, the place in the layer's buffer its first byte
   --  goes to, and whether an initialization read failed. The first gyro's
   --  values stand until a second gyro's detection sets its own.
   type Device is limited record
      Index    : Natural := 0;
      Bus      : SPI.Bus := Bus_Of (Adaflight.Board.Gyro_1_SPI_Device);
      Has_Line : Boolean := True;
      CS     : Pin := Adaflight.Board.Gyro_1_CS_Pin;
      Line   : Pin := Adaflight.Board.Gyro_1_EXTI_Pin;
      Rx     : Byte_Array (0 .. 15) := (others => 0);
      Offset : Natural range 0 .. 1 := 1;
      Failed : Boolean := False;
   end record;

   procedure Preinit_CS (D : in out Device; Tag : Byte);
   procedure Attach_Bus (D : in out Device; Instance : Byte; OK : out Boolean);
   procedure Prepare_CS (D : in out Device; Index : Byte);
   procedure Release_CS (D : in out Device);
   procedure Divider (D : in out Device; Hz : Unsigned_32; Divisor : out Unsigned_16);
   procedure Set_Divisor (D : in out Device; Divisor : Unsigned_16);
   procedure Probe_Chip (D : in out Device; Index : Positive; Sensor : out Byte);
   procedure Register_Device (D : in out Device);
   procedure Millis (D : in out Device; Now : out Unsigned_32);
   procedure Delay_Ms (D : in out Device; Ms : Natural);
   procedure Enable_Interrupt (D : in out Device);
   procedure Cycle_Count (D : in out Device; Now : out Unsigned_32);
   procedure Start_Sequence (D : in out Device; Data : Byte_Array; Completion : Boolean);
   procedure Wait (D : in out Device);
   procedure Fetch (D : in out Device; Data : out Byte_Array);
   function Uses_DMA (D : Device) return Boolean;
   procedure Read_Registers (D : in out Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean);
   procedure Write_Register (D : in out Device; Register : Byte; Value : Byte);
   procedure Read_Register (D : in out Device; Register : Byte; Value : out Byte);
   procedure Delay_Us (D : in out Device; Us : Natural);
   procedure Failure (D : in out Device);
   procedure Clock_In (D : in out Device; Started : out Boolean);
   procedure Write_Buffer (D : in out Device; Register : Byte; Data : Byte_Array);
   procedure Set_CS (D : in out Device; High : Boolean);

   package Layer is new Adaflight.MPU_Gyro
     (SPI_Device       => Device,
      Chip_Count       => 7,
      Preinit_CS       => Preinit_CS,
      Attach_Bus       => Attach_Bus,
      Prepare_CS       => Prepare_CS,
      Release_CS       => Release_CS,
      Divider          => Divider,
      Set_Divisor      => Set_Divisor,
      Probe_Chip       => Probe_Chip,
      Register_Device  => Register_Device,
      Millis           => Millis,
      Delay_Ms         => Delay_Ms,
      Enable_Interrupt => Enable_Interrupt,
      Cycle_Count      => Cycle_Count,
      Start_Sequence   => Start_Sequence,
      Wait             => Wait,
      Fetch            => Fetch,
      Uses_DMA         => Uses_DMA,
      Read_Registers   => Read_Registers);
   package LSM6DSV is new Layer.LSM6DSV16X
     (Write_Register => Write_Register,
      Read_Register  => Read_Register,
      Delay_Us       => Delay_Us,
      Failure        => Failure);
   package ICM20689 is new Layer.ICM20689
     (Write_Register => Write_Register,
      Read_Register  => Read_Register,
      Delay_Us       => Delay_Us);
   package MPU6000 is new Layer.MPU6000
     (Write_Register   => Write_Register,
      Read_Register    => Read_Register,
      Delay_Us         => Delay_Us,
      Micros_To_Cycles => Time.Micros_To_Cycles,
      Failure          => Failure);
   package MPU6500 is new Layer.MPU6500
     (Write_Register     => Write_Register,
      Read_Register      => Read_Register,
      Bus_Write_Register => Write_Register,
      Delay_Us           => Delay_Us);
   package BMI270 is new Layer.BMI270
     (Read_Masked    => Read_Registers,
      Write_Register => Write_Register,
      Write_Buffer   => Write_Buffer,
      Set_CS         => Set_CS);
   package ICM426xx is new Layer.ICM426xx
     (External_Clock => Adaflight.Board.Gyro_Clkin,
      Write_Register => Write_Register,
      Read_Register  => Read_Register,
      Start_Clock_In => Clock_In);

   --  Whether the board builds the LSM6DSV16X family's driver, and whether
   --  a sensor code is one of its chips.
   LSM_Built : constant Boolean :=
     Adaflight.Board.Gyro_LSM6DSV16X or else Adaflight.Board.Gyro_LSM6DSV32X
     or else Adaflight.Board.Gyro_LSM6DSK320X;
   function Is_LSM (Sensor : Byte) return Boolean is
     (Sensor in LSM6DSV.Sensor_LSM6DSV16X | LSM6DSV.Sensor_LSM6DSK320X | LSM6DSV.Sensor_LSM6DSV32X);

   type Device_List is array (Gyro_Position) of Device;
   type State_List is array (Gyro_Position) of Layer.State;
   type Latch_List is array (Gyro_Position) of LSM6DSV.Sample_Latch;
   type Flag_List is array (Gyro_Position) of Boolean;
   Devices     : Device_List;
   States      : State_List;
   Latches     : Latch_List;
   Found_Gyros : Flag_List := (others => False);
   --  The first enabled gyro, which gives the accelerometer's readings, the
   --  read mode, the interrupt counts and the temperature.
   Active      : Gyro_Position := 0;
   Polled_Temperature : Interfaces.Integer_16 := Interfaces.Integer_16'First;

   --  A data ready line's callback counts and times the sample in the
   --  layer: one for the first gyro and one for the last of the board's.
   procedure Data_Ready is
   begin
      Layer.Interrupt (Devices (0), States (0));
   end Data_Ready;

   procedure Data_Ready_Second is
   begin
      Layer.Interrupt (Devices (Gyro_Position'Last), States (Gyro_Position'Last));
   end Data_Ready_Second;

   procedure Select_Chip (D : Device) is
   begin
      GPIO.Set_Low (D.CS);
   end Select_Chip;

   procedure Deselect_Chip (D : Device) is
   begin
      GPIO.Set_High (D.CS);
   end Deselect_Chip;

   procedure Preinit_CS (D : in out Device; Tag : Byte) is
   begin
      if Tag /= 0 then
         GPIO.Enable_Port (D.CS.Port);
         GPIO.Set_Input (D.CS, GPIO.Up);
         GPIO.Set_High (D.CS);
      end if;
   end Preinit_CS;

   procedure Attach_Bus (D : in out Device; Instance : Byte; OK : out Boolean) is
      pragma Unreferenced (D);
   begin
      OK := Instance = 1;
   end Attach_Bus;

   procedure Prepare_CS (D : in out Device; Index : Byte) is
      pragma Unreferenced (Index);
   begin
      GPIO.Set_Output (D.CS);
      GPIO.Set_High (D.CS);
   end Prepare_CS;

   procedure Release_CS (D : in out Device) is
   begin
      GPIO.Set_Input (D.CS, GPIO.Up);
      GPIO.Set_High (D.CS);
   end Release_CS;

   procedure Divider (D : in out Device; Hz : Unsigned_32; Divisor : out Unsigned_16) is
      pragma Unreferenced (D);
   begin
      Divisor := SPI.Divider (Hz);
   end Divider;

   procedure Set_Divisor (D : in out Device; Divisor : Unsigned_16) is
   begin
      SPI.Set_Divisor (D.Bus, Divisor);
   end Set_Divisor;

   procedure Probe_Chip (D : in out Device; Index : Positive; Sensor : out Byte) is
   begin
      Sensor := Layer.No_Sensor;
      case Index is
         when 1 =>
            if Adaflight.Board.Gyro_LSM6DSV16X or else Adaflight.Board.Gyro_LSM6DSV32X then
               LSM6DSV.Detect_LSM6DSV16X (D, Sensor);
            end if;
         when 2 =>
            if Adaflight.Board.Gyro_LSM6DSK320X then
               LSM6DSV.Detect_LSM6DSK320X (D, Sensor);
            end if;
         when 3 =>
            if Adaflight.Board.Gyro_ICM20689 then
               ICM20689.Detect (D, Sensor);
            end if;
         when 4 =>
            if Adaflight.Board.Gyro_MPU6000 then
               MPU6000.Detect (D, Sensor);
            end if;
         when 5 =>
            if Adaflight.Board.Gyro_MPU6500 then
               MPU6500.Detect (D, Sensor);
               if Adaflight.Board.Gyro_Clkin and then Adaflight.Board.Gyro_ICM426xx
                 and then Sensor = ICM426xx.Sensor_ICM42688P and then D.Index = 0
               then
                  ICM426xx.Enable_External_Clock (D);
               end if;
            end if;
         when 6 =>
            if Adaflight.Board.Gyro_BMI270 then
               BMI270.Detect (D, Sensor);
            end if;
         when 7 =>
            if Adaflight.Board.Gyro_ICM426xx then
               ICM426xx.Detect (D, Sensor);
            end if;
         when others =>
            null;
      end case;
   end Probe_Chip;

   procedure Register_Device (D : in out Device) is
      pragma Unreferenced (D);
   begin
      null;
   end Register_Device;

   procedure Millis (D : in out Device; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Millis;
   end Millis;

   procedure Delay_Ms (D : in out Device; Ms : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Ms (Ms);
   end Delay_Ms;

   procedure Enable_Interrupt (D : in out Device) is
   begin
      if not D.Has_Line then
         return;
      end if;
      GPIO.Enable_Port (D.Line.Port);
      GPIO.Set_Input (D.Line);
      if D.Index = 0 then
         EXTI_Dispatch.Register (D.Line.Number, Data_Ready'Access);
      else
         EXTI_Dispatch.Register (D.Line.Number, Data_Ready_Second'Access);
      end if;
      EXTI.Enable_Rising (D.Line);
   end Enable_Interrupt;

   procedure Cycle_Count (D : in out Device; Now : out Unsigned_32) is
      pragma Unreferenced (D);
   begin
      Now := Time.Cycle_Count;
   end Cycle_Count;

   procedure Start_Sequence (D : in out Device; Data : Byte_Array; Completion : Boolean) is
      pragma Unreferenced (Completion);
   begin
      Select_Chip (D);
      SPI.Transfer (D.Bus, Data, D.Rx);
      Deselect_Chip (D);
   end Start_Sequence;

   procedure Wait (D : in out Device) is
      pragma Unreferenced (D);
   begin
      null;
   end Wait;

   --  The received bytes as the layer reads its buffer: the byte clocked
   --  with the command at 1 and the data from 2, or for a BMI270 that byte
   --  at 0, its dummy byte at 1 and the data from 2.
   procedure Fetch (D : in out Device; Data : out Byte_Array) is
   begin
      Data := (others => 0);
      for I in D.Rx'Range loop
         exit when Data'First + I + D.Offset > Data'Last;
         Data (Data'First + I + D.Offset) := D.Rx (I);
      end loop;
   end Fetch;

   function Uses_DMA (D : Device) return Boolean is
      pragma Unreferenced (D);
   begin
      return False;
   end Uses_DMA;

   procedure Read_Registers (D : in out Device; Register : Byte; Data : in out Byte_Array; OK : out Boolean) is
      Tx : constant Byte_Array (0 .. Data'Length) := (0 => Register or Read_Bit, others => 16#FF#);
      Rx : Byte_Array (0 .. Data'Length);
   begin
      Select_Chip (D);
      SPI.Transfer (D.Bus, Tx, Rx);
      Deselect_Chip (D);
      Data := Rx (1 .. Data'Length);
      OK := True;
   end Read_Registers;

   procedure Write_Register (D : in out Device; Register : Byte; Value : Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Select_Chip (D);
      SPI.Transfer (D.Bus, (Register, Value), Rx);
      Deselect_Chip (D);
   end Write_Register;

   procedure Read_Register (D : in out Device; Register : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Select_Chip (D);
      SPI.Transfer (D.Bus, (Register or Read_Bit, 16#FF#), Rx);
      Deselect_Chip (D);
      Value := Rx (1);
   end Read_Register;

   procedure Delay_Us (D : in out Device; Us : Natural) is
      pragma Unreferenced (D);
   begin
      Time.Delay_Us (Us);
   end Delay_Us;

   procedure Failure (D : in out Device) is
   begin
      D.Failed := True;
   end Failure;

   procedure Clock_In (D : in out Device; Started : out Boolean) is
      pragma Unreferenced (D);
   begin
      Adaflight.STM32.Gyro_Clock.Start (1, Started);
   end Clock_In;

   --  A register's address, then the data, in one selection.
   procedure Write_Buffer (D : in out Device; Register : Byte; Data : Byte_Array) is
      Tx : Byte_Array (0 .. Data'Length);
      Rx : Byte_Array (0 .. Data'Length);
   begin
      Tx (0) := Register;
      Tx (1 .. Data'Length) := Data;
      Select_Chip (D);
      SPI.Transfer (D.Bus, Tx, Rx);
      Deselect_Chip (D);
   end Write_Buffer;

   procedure Set_CS (D : in out Device; High : Boolean) is
   begin
      if High then
         Deselect_Chip (D);
      else
         Select_Chip (D);
      end if;
   end Set_CS;

   --  The drivers a board's configuration names.
   Build : constant Gyro_Detect.Driver_Set :=
     (Gyro_Detect.LSM6DSV16X  => Adaflight.Board.Gyro_LSM6DSV16X,
      Gyro_Detect.LSM6DSV32X  => Adaflight.Board.Gyro_LSM6DSV32X,
      Gyro_Detect.LSM6DSK320X => Adaflight.Board.Gyro_LSM6DSK320X,
      Gyro_Detect.ICM20689    => Adaflight.Board.Gyro_ICM20689,
      Gyro_Detect.MPU6000     => Adaflight.Board.Gyro_MPU6000,
      Gyro_Detect.MPU6500_SPI => Adaflight.Board.Gyro_MPU6500,
      Gyro_Detect.BMI270      => Adaflight.Board.Gyro_BMI270,
      Gyro_Detect.ICM426xx    => Adaflight.Board.Gyro_ICM426xx,
      others                  => False);
   Acc_Build : constant Acc_Detect.Driver_Set :=
     (Acc_Detect.LSM6DSV16X  => Adaflight.Board.Gyro_LSM6DSV16X,
      Acc_Detect.LSM6DSV32X  => Adaflight.Board.Gyro_LSM6DSV32X,
      Acc_Detect.LSM6DSK320X => Adaflight.Board.Gyro_LSM6DSK320X,
      Acc_Detect.ICM20689    => Adaflight.Board.Acc_ICM20689,
      Acc_Detect.MPU6000     => Adaflight.Board.Acc_MPU6000,
      Acc_Detect.MPU6500_SPI => Adaflight.Board.Acc_MPU6500,
      Acc_Detect.BMI270      => Adaflight.Board.Acc_BMI270,
      Acc_Detect.ICM426xx    => Adaflight.Board.Acc_ICM426xx,
      others                 => False);
   --  The gyro hardware code the detection gives a chip that the ICM20689
   --  driver starts.
   Hardware_ICM20689 : constant Byte := 11;
   --  A gyro on an SPI bus with a select pin.
   function Device_Config (Position : Gyro_Position) return Layer.Device_Config is
     (Index => Interfaces.Integer_8 (Position), Bus_Type => 2, SPI_Bus => 1, CS_Tag => 1);

   --  Whether the board gives the gyro at a position a bus: the first has
   --  one, a second needs its SPI instance and select pin.
   function Configured (Position : Natural) return Boolean is
     (Position = 0
      or else (Position in Gyro_Position and then Adaflight.Board.Gyro_2_SPI_Device in 1 .. 6
               and then Adaflight.Board.Gyro_2_CS_Tag /= 0));

   --  A second gyro's own bus, pins and line.
   procedure Set_Up (Position : Natural; D : in out Device) is
   begin
      D.Index := Position;
      if Position > 0 then
         D.Bus := Bus_Of (Adaflight.Board.Gyro_2_SPI_Device);
         D.CS := Adaflight.Board.Gyro_2_CS_Pin;
         D.Line := Adaflight.Board.Gyro_2_EXTI_Pin;
         D.Has_Line := Adaflight.Board.Gyro_2_EXTI_Tag /= 0;
      end if;
   end Set_Up;

   procedure Detect (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; R : out Report) is
      Chip_Found : Boolean;
      Found      : Boolean;
      Hardware   : Byte := Gyro_Detect.Hardware_None;
      Rates      : Gyro_Start.Rates;
   begin
      R := (others => <>);
      if Position not in Gyro_Position or else not Configured (Position) then
         return;
      end if;
      declare
         D : Device renames Devices (Position);
         S : Layer.State renames States (Position);
      begin
         Set_Up (Position, D);
         Layer.Preinit (D, Device_Config (Position));
         Layer.Detect (D, S, Device_Config (Position), Chip_Found);
         Gyro_Detect.Detect_Sensor (Build, Chip_Found, S.Sensor, Hardware, Found);
         if not Found then
            return;
         end if;
         Found := False;
         if Hardware = Layer.Hardware_MPU6000 then
            if Adaflight.Board.Gyro_MPU6000 then
               MPU6000.Gyro_Detect (S, Found, R.Scale);
            end if;
         elsif Hardware = Hardware_ICM20689 then
            if Adaflight.Board.Gyro_ICM20689 then
               ICM20689.Gyro_Detect (S, Found, R.Scale);
            end if;
         elsif LSM_Built and then Is_LSM (S.Sensor) then
            LSM6DSV.Gyro_Detect (S, Found);
         elsif Adaflight.Board.Gyro_BMI270 and then S.Sensor = BMI270.Sensor_BMI270 then
            BMI270.Gyro_Detect (S, Found, R.Scale);
            D.Offset := 0;
         elsif Adaflight.Board.Gyro_ICM426xx and then ICM426xx.Is_ICM426xx (S.Sensor) then
            ICM426xx.Gyro_Detect (S, Found, R.Scale);
         elsif Adaflight.Board.Gyro_MPU6500 then
            MPU6500.Gyro_Detect (S, High_Range, Found, R.Scale);
         end if;
         if not Found then
            return;
         end if;
         Found_Gyros (Position) := True;
         S.Interrupt_Pin := D.Has_Line;
         S.Hardware_LPF := Hardware_LPF;
         S.Hardware := Hardware;
         Rates := Gyro_Start.Sample_Rates (S.Sensor, Hardware_LPF);
         S.Rate_KHz := Rates.Rate_Code;
         R.Found := True;
         R.Hardware := Hardware;
         R.Sensor := S.Sensor;
         R.Sample_Rate_Hz := Rates.Gyro_Hz;
         R.Acc_Sample_Rate_Hz := Rates.Acc_Hz;
         R.Overflow_Protected := Gyro_Start.Overflow_Protected (Hardware);
      end;
   end Detect;

   procedure Init
     (Position : Natural; Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : in out Report) is
   begin
      if Position not in Gyro_Position or else not Found_Gyros (Position) then
         return;
      end if;
      declare
         D        : Device renames Devices (Position);
         S        : Layer.State renames States (Position);
         Hardware : constant Byte := S.Hardware;
      begin
         if Hardware = Layer.Hardware_MPU6000 then
            if Adaflight.Board.Gyro_MPU6000 then
               MPU6000.Gyro_Init (D, S, Gyro_Start.Divider_Drops);
            end if;
         elsif Hardware = Hardware_ICM20689 then
            if Adaflight.Board.Gyro_ICM20689 then
               ICM20689.Gyro_Init (D, S, Gyro_Start.Divider_Drops);
            end if;
         elsif LSM_Built and then Is_LSM (S.Sensor) then
            LSM6DSV.Gyro_Init (D, S, Hardware_LPF, R.Scale);
         elsif Adaflight.Board.Gyro_BMI270 and then S.Sensor = BMI270.Sensor_BMI270 then
            BMI270.Gyro_Init (D, S);
         elsif Adaflight.Board.Gyro_ICM426xx and then ICM426xx.Is_ICM426xx (S.Sensor) then
            ICM426xx.Gyro_Init (D, S, Hardware_LPF, Gyro_Start.Divider_Drops);
         elsif Adaflight.Board.Gyro_MPU6500 then
            MPU6500.Gyro_Init (D, S, High_Range, Gyro_Start.Divider_Drops);
         end if;
         R.Init_Failed := D.Failed;
         Acc_Detect.Detect (Acc_Build, Acc_Configured, S.Sensor, R.Acc_Hardware, R.Acc_Found);
         if R.Acc_Found and then Adaflight.Board.Acc_ICM426xx and then ICM426xx.Is_ICM426xx (S.Sensor) then
            R.One_G := Positive (ICM426xx.Acc_One_G (S));
         elsif R.Acc_Found and then LSM_Built and then Is_LSM (S.Sensor) then
            R.One_G := LSM6DSV.Acc_One_G (S);
         end if;
      end;
   end Init;

   procedure Set_Active (Position : Natural) is
   begin
      if Position in Gyro_Position then
         Active := Position;
      end if;
   end Set_Active;

   procedure Read_Gyro (Position : Natural; Raw : out Axis_Values; OK : out Boolean) is
   begin
      Raw := (others => 0);
      OK := False;
      if Position not in Gyro_Position then
         return;
      end if;
      declare
         D : Device renames Devices (Position);
         S : Layer.State renames States (Position);
      begin
         if Adaflight.Board.Gyro_BMI270 and then S.Sensor = BMI270.Sensor_BMI270 then
            BMI270.Read_Gyro (D, S, OK);
         elsif LSM_Built and then Is_LSM (S.Sensor) then
            LSM6DSV.Read_Gyro (D, S, Latches (Position), OK);
         else
            Layer.Read_Gyro_SPI (D, S, OK);
         end if;
         Raw := (S.Raw (0), S.Raw (1), S.Raw (2));
      end;
   end Read_Gyro;

   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean) is
      D : Device renames Devices (Active);
      S : Layer.State renames States (Active);
   begin
      if Adaflight.Board.Gyro_BMI270 and then S.Sensor = BMI270.Sensor_BMI270 then
         BMI270.Read_Acc (D, S, OK);
      elsif LSM_Built and then Is_LSM (S.Sensor) then
         LSM6DSV.Read_Acc (D, S, Latches (Active), OK);
      else
         Layer.Read_Acc_SPI (D, S, OK);
      end if;
      Raw := (S.Acc_Raw (0), S.Acc_Raw (1), S.Acc_Raw (2));
   end Read_Acc;

   function Mode return Read_Mode is
     (case States (Active).Mode is
         when Layer.EXTI_Init    => Interrupt_Init,
         when Layer.EXTI_Int_DMA => Interrupt_DMA,
         when Layer.EXTI_Int     => Interrupt,
         when Layer.EXTI_No_Int  => No_Interrupt);

   function Interrupt_Count return Unsigned_32 is (States (Active).Detected_EXTI);

   function Sync_Cycles return Unsigned_32 is (States (Active).Sync_EXTI);

   function Short_Period return Boolean is (States (Active).Short_Period /= 0);
   procedure Poll_Temperature (Now_Us : Adaflight.Scheduler.Time_Us) is
      pragma Unreferenced (Now_Us);
   begin
      Polled_Temperature :=
        (if Found_Gyros (Active) then States (Active).Temperature else Interfaces.Integer_16'First);
   end Poll_Temperature;

   function Temperature return Interfaces.Integer_16 is (Polled_Temperature);

   procedure Dump_Register (Position : Natural; Register : Byte; Value : out Byte) is
   begin
      Value := 0;
      if Position in Gyro_Position and then Found_Gyros (Position) then
         Read_Register (Devices (Position), Register, Value);
      end if;
   end Dump_Register;

end Adaflight.STM32.Gyro_Chip;
