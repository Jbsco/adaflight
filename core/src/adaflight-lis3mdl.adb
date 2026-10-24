package body Adaflight.LIS3MDL with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address        : constant Byte := 16#1E#;
   Device_Id      : constant Byte := 16#3D#;
   Who_Am_I       : constant Byte := 16#0F#;
   Control_1      : constant Byte := 16#20#;
   Control_2      : constant Byte := 16#21#;
   Control_3      : constant Byte := 16#22#;
   Control_4      : constant Byte := 16#23#;
   Control_5      : constant Byte := 16#24#;
   Data_Register  : constant Byte := 16#28#;
   --  The address bit that steps through the registers of a multi-byte read.
   I2C_Auto_Increment : constant Byte := 16#80#;
   SPI_Auto_Increment : constant Byte := 16#40#;
   Range_4_Gauss  : constant Byte := 16#00#;
   Ultra_High_80  : constant Byte := 16#80# or 16#60# or 16#1C#;
   Block_Update   : constant Byte := 16#40#;
   Z_Ultra_High   : constant Byte := 16#0C#;
   Continuous     : constant Byte := 16#00#;

   function Axis (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (Interfaces.Integer_16 ((if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
                              else Integer (High) * 256 + Integer (Low)) / 4))
     with Global => null;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Address);
      end if;
      Read_Registers (D, Who_Am_I, Id, OK);
      Found := OK and then Id (0) = Device_Id;
   end Detect;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
      Ignored : Boolean;
   begin
      Register_Device (D);
      Write_Register (D, Control_2, Range_4_Gauss, Ignored);
      Write_Register (D, Control_1, Ultra_High_80, Ignored);
      Write_Register (D, Control_5, Block_Update, Ignored);
      Write_Register (D, Control_4, Z_Ultra_High, Ignored);
      Write_Register (D, Control_3, Continuous, Ignored);
      Delay_Ms (D, 100);
      S.ODR_Hz := 80;
      OK := True;
   end Init;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      Started : Boolean;
      B       : Byte_Array (0 .. 5);
   begin
      if S.Start_Next then
         Start_Read (D, Data_Register or (if Is_I2C (D) then I2C_Auto_Increment else SPI_Auto_Increment), 6, Started);
         if Started then
            S.Start_Next := False;
         end if;
         Got := False;
         return;
      end if;
      Fetch (D, B);
      Data (0) := Axis (B (0), B (1));
      Data (1) := Axis (B (2), B (3));
      Data (2) := Axis (B (4), B (5));
      S.Start_Next := True;
      Got := True;
   end Read;

end Adaflight.LIS3MDL;
