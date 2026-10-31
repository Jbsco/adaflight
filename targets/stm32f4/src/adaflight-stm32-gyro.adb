with Ada.Interrupts.Names;
with System;
with Adaflight.Board;
with Adaflight.Bytes; use Adaflight.Bytes;
with Adaflight.Gyro_Detect;
with Adaflight.Gyro_Start;
with Adaflight.MPU_Gyro;
with Adaflight.MPU_Gyro.MPU6000;
with Adaflight.MPU_Gyro.MPU6500;
with Adaflight.Pins; use Adaflight.Pins;
with Adaflight.STM32.EXTI;
with Adaflight.STM32.GPIO;
with Adaflight.STM32.SPI;
with Adaflight.STM32.Time;
package body Adaflight.STM32.Gyro is
   --  The gyro's bus from the board's configuration, SPI1 when it names none.
   Gyro_Bus : constant SPI.Bus :=
     (if Adaflight.Board.Gyro_1_SPI_Device in 1 .. 6 then SPI.Bus'Val (Adaflight.Board.Gyro_1_SPI_Device - 1)
      else SPI.SPI1);
   use type Interfaces.Unsigned_8;
   use type Interfaces.Integer_32;
   Read_Bit : constant Byte := 16#80#;

   --  The gyro's SPI device: its select pin, its data ready line, the bytes
   --  the last transfer brought in and whether an initialization read failed.
   type Device is limited record
      CS     : Pin := Adaflight.Board.Gyro_1_CS_Pin;
      Line   : Pin := Adaflight.Board.Gyro_1_EXTI_Pin;
      Rx     : Byte_Array (0 .. 15) := (others => 0);
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

   package Layer is new Adaflight.MPU_Gyro
     (SPI_Device       => Device,
      Chip_Count       => 2,
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

   Bus   : Device;
   State : Layer.State;

   --  The interrupt of a pin's external interrupt line.
   function Line_Interrupt (Line : Pin_Number) return Ada.Interrupts.Interrupt_ID is
     (case Line is
         when 0      => Ada.Interrupts.Names.EXTI0_Interrupt,
         when 1      => Ada.Interrupts.Names.EXTI1_Interrupt,
         when 2      => Ada.Interrupts.Names.EXTI2_Interrupt,
         when 3      => Ada.Interrupts.Names.EXTI3_Interrupt,
         when 4      => Ada.Interrupts.Names.EXTI4_Interrupt,
         when 5 .. 9 => Ada.Interrupts.Names.EXTI9_5_Interrupt,
         when others => Ada.Interrupts.Names.EXTI15_10_Interrupt);

   --  The data ready line's interrupt counts and times the sample in the
   --  layer.
   protected Data_Ready with Interrupt_Priority => System.Interrupt_Priority'First is
      function Count return Unsigned_32;
   private
      procedure Handler with Attach_Handler => Line_Interrupt (Adaflight.Board.Gyro_1_EXTI_Pin.Number);
   end Data_Ready;

   protected body Data_Ready is
      function Count return Unsigned_32 is (State.Detected_EXTI);

      procedure Handler is
      begin
         EXTI.Clear_Pending (Bus.Line.Number);
         Layer.Interrupt (Bus, State);
      end Handler;
   end Data_Ready;

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
      pragma Unreferenced (D);
   begin
      SPI.Set_Divisor (Gyro_Bus, Divisor);
   end Set_Divisor;

   procedure Probe_Chip (D : in out Device; Index : Positive; Sensor : out Byte) is
   begin
      case Index is
         when 1 =>
            MPU6000.Detect (D, Sensor);
         when 2 =>
            MPU6500.Detect (D, Sensor);
         when others =>
            Sensor := Layer.No_Sensor;
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
      GPIO.Enable_Port (D.Line.Port);
      GPIO.Set_Input (D.Line);
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
      SPI.Transfer (Gyro_Bus, Data, D.Rx);
      Deselect_Chip (D);
   end Start_Sequence;

   procedure Wait (D : in out Device) is
      pragma Unreferenced (D);
   begin
      null;
   end Wait;

   --  The received bytes as the layer reads its buffer: the byte clocked
   --  with the command at 1, the data from 2.
   procedure Fetch (D : in out Device; Data : out Byte_Array) is
   begin
      Data := (others => 0);
      for I in D.Rx'Range loop
         exit when Data'First + I + 1 > Data'Last;
         Data (Data'First + I + 1) := D.Rx (I);
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
      SPI.Transfer (Gyro_Bus, Tx, Rx);
      Deselect_Chip (D);
      Data := Rx (1 .. Data'Length);
      OK := True;
   end Read_Registers;

   procedure Write_Register (D : in out Device; Register : Byte; Value : Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Select_Chip (D);
      SPI.Transfer (Gyro_Bus, (Register, Value), Rx);
      Deselect_Chip (D);
   end Write_Register;

   procedure Read_Register (D : in out Device; Register : Byte; Value : out Byte) is
      Rx : Byte_Array (0 .. 1);
   begin
      Select_Chip (D);
      SPI.Transfer (Gyro_Bus, (Register or Read_Bit, 16#FF#), Rx);
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

   Build : constant Gyro_Detect.Driver_Set :=
     (Gyro_Detect.MPU6000 | Gyro_Detect.MPU6500_SPI => True, others => False);
   Acc_Build : constant Acc_Detect.Driver_Set :=
     (Acc_Detect.MPU6000 | Acc_Detect.MPU6500_SPI => True, others => False);
   --  The gyro on SPI bus 1 with a select pin.
   Config : constant Layer.Device_Config := (Index => 0, Bus_Type => 2, SPI_Bus => 1, CS_Tag => 1);

   procedure Start (Hardware_LPF : Byte; High_Range : Boolean; Acc_Configured : Byte; R : out Report) is
      Chip_Found : Boolean;
      Found      : Boolean;
      Hardware   : Byte := Gyro_Detect.Hardware_None;
      Rates      : Gyro_Start.Rates;
   begin
      R := (others => <>);
      Layer.Preinit (Bus, Config);
      Layer.Detect (Bus, State, Config, Chip_Found);
      Gyro_Detect.Detect_Sensor (Build, Chip_Found, State.Sensor, Hardware, Found);
      if not Found then
         return;
      end if;
      case Hardware is
         when Layer.Hardware_MPU6000 =>
            MPU6000.Gyro_Detect (State, Found, R.Scale);
         when others =>
            MPU6500.Gyro_Detect (State, High_Range, Found, R.Scale);
      end case;
      if not Found then
         return;
      end if;
      State.Interrupt_Pin := True;
      State.Hardware_LPF := Hardware_LPF;
      State.Hardware := Hardware;
      Rates := Gyro_Start.Sample_Rates (State.Sensor, Hardware_LPF);
      State.Rate_KHz := Rates.Rate_Code;
      case Hardware is
         when Layer.Hardware_MPU6000 =>
            MPU6000.Gyro_Init (Bus, State, Gyro_Start.Divider_Drops);
         when others =>
            MPU6500.Gyro_Init (Bus, State, High_Range, Gyro_Start.Divider_Drops);
      end case;
      R.Found := True;
      R.Init_Failed := Bus.Failed;
      R.Hardware := Hardware;
      R.Sensor := State.Sensor;
      R.Sample_Rate_Hz := Rates.Gyro_Hz;
      R.Acc_Sample_Rate_Hz := Rates.Acc_Hz;
      R.Overflow_Protected := Gyro_Start.Overflow_Protected (Hardware);
      Acc_Detect.Detect (Acc_Build, Acc_Configured, State.Sensor, R.Acc_Hardware, R.Acc_Found);
   end Start;

   procedure Read_Gyro (Raw : out Axis_Values; OK : out Boolean) is
   begin
      Layer.Read_Gyro_SPI (Bus, State, OK);
      Raw := (State.Raw (0), State.Raw (1), State.Raw (2));
   end Read_Gyro;

   procedure Read_Acc (Raw : out Axis_Values; OK : out Boolean) is
   begin
      Layer.Read_Acc_SPI (Bus, State, OK);
      Raw := (State.Acc_Raw (0), State.Acc_Raw (1), State.Acc_Raw (2));
   end Read_Acc;

   function Mode return Read_Mode is
     (case State.Mode is
         when Layer.EXTI_Init    => Interrupt_Init,
         when Layer.EXTI_Int_DMA => Interrupt_DMA,
         when Layer.EXTI_Int     => Interrupt,
         when Layer.EXTI_No_Int  => No_Interrupt);

   function Interrupt_Count return Unsigned_32 is (Data_Ready.Count);

   function Sync_Cycles return Unsigned_32 is (State.Sync_EXTI);

   function Short_Period return Boolean is (State.Short_Period /= 0);
end Adaflight.STM32.Gyro;
