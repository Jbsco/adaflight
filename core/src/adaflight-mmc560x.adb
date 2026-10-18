package body Adaflight.MMC560X with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address          : constant Byte := 16#30#;
   Product_Id       : constant Byte := 16#10#;
   Product_Register : constant Byte := 16#39#;
   Output_Register  : constant Byte := 16#00#;
   Rate_Register    : constant Byte := 16#1A#;
   Control_0        : constant Byte := 16#1B#;
   Control_1        : constant Byte := 16#1C#;
   Control_2        : constant Byte := 16#1D#;
   Software_Reset   : constant Byte := 16#80#;
   Set_Operation    : constant Byte := 16#08#;
   Bandwidth_2_Ms   : constant Byte := 16#02#;
   Rate_100_Hz      : constant Byte := 16#64#;
   Continuous_Auto  : constant Byte := 16#80# or 16#40#;
   High_Power_Set   : constant Byte := 16#10# or 16#80# or 16#08#;
   Zero_Field       : constant := 131_072;

   --  The 18-bit count of the two high bytes and the top two bits of the low
   --  byte, centered on zero and shifted right by 2 with the sign kept.
   function Axis (High : Byte; Middle : Byte; Low : Byte) return Interfaces.Integer_16 is
     (Interfaces.Integer_16
        ((Integer (High) * 1_024 + Integer (Middle) * 4 + Integer (Low) / 64 - Zero_Field
          - (Integer (High) * 1_024 + Integer (Middle) * 4 + Integer (Low) / 64 - Zero_Field) mod 4) / 4))
     with Global => null;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, Address);
      end if;
      Delay_Ms (D, 10);
      Read_Registers (D, Product_Register, Id, OK);
      Found := OK and then Id (0) = Product_Id;
   end Detect;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
   begin
      Register_Device (D);
      Write_Register (D, Control_1, Software_Reset, OK);
      if not OK then
         return;
      end if;
      Delay_Ms (D, 20);
      Write_Register (D, Control_0, Set_Operation, OK);
      if not OK then
         return;
      end if;
      Delay_Ms (D, 1);
      Write_Register (D, Control_1, Bandwidth_2_Ms, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, Rate_Register, Rate_100_Hz, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, Control_0, Continuous_Auto, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, Control_2, High_Power_Set, OK);
      if not OK then
         return;
      end if;
      S.ODR_Hz := 100;
   end Init;

   procedure Read (D : in out Bus_Device; Data : in out Axes; Got : out Boolean) is
      B : Byte_Array (0 .. 8) := (others => 0);
   begin
      Read_Registers (D, Output_Register, B, Got);
      if not Got then
         return;
      end if;
      Data (0) := Axis (B (0), B (1), B (6));
      Data (1) := Axis (B (2), B (3), B (7));
      Data (2) := Axis (B (4), B (5), B (8));
   end Read;

end Adaflight.MMC560X;
