package body Adaflight.HMC5883 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address          : constant Byte := 16#1E#;
   Device_Id        : constant Byte := 16#48#;
   Max_SPI_Clock_Hz : constant Interfaces.Unsigned_32 := 10_000_000;
   Config_A         : constant Byte := 16#00#;
   Config_B         : constant Byte := 16#01#;
   Mode             : constant Byte := 16#02#;
   Data_Register    : constant Byte := 16#03#;
   Id_Register      : constant Byte := 16#0A#;
   Averaging_75_Hz  : constant Byte := 16#60# or 16#18# or 16#00#;
   Gain_1_3_Gauss   : constant Byte := 16#20#;
   Continuous       : constant Byte := 16#00#;

   function Word (High : Byte; Low : Byte) return Interfaces.Integer_16 is
     (if High >= 128 then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      if Is_SPI (D) then
         Register_Device (D);
         Prepare_SPI (D, Max_SPI_Clock_Hz);
      end if;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Address);
      end if;
      Read_Registers (D, Id_Register, Id, OK);
      Found := OK and then Id (0) = Device_Id;
   end Detect;

   procedure Init (D : in out Bus_Device; S : in out State; Interrupt_Pin : Boolean; OK : out Boolean) is
      Ignored : Boolean;
   begin
      Write_Register (D, Config_A, Averaging_75_Hz, Ignored);
      Write_Register (D, Config_B, Gain_1_3_Gauss, Ignored);
      Write_Register (D, Mode, Continuous, Ignored);
      Delay_Ms (D, 100);
      if Interrupt_Pin then
         Enable_Interrupt (D);
      end if;
      S.ODR_Hz := 75;
      OK := True;
   end Init;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      Started : Boolean;
      B       : Byte_Array (0 .. 5);
   begin
      if S.Start_Next then
         Start_Read (D, Data_Register, 6, Started);
         if Started then
            S.Start_Next := False;
         end if;
         Got := False;
         return;
      end if;
      Fetch (D, B);
      Data (0) := Word (B (0), B (1));
      Data (2) := Word (B (2), B (3));
      Data (1) := Word (B (4), B (5));
      S.Start_Next := True;
      Got := True;
   end Read;

end Adaflight.HMC5883;
