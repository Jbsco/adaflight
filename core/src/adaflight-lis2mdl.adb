package body Adaflight.LIS2MDL with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address       : constant Byte := 16#1E#;
   Device_Id     : constant Byte := 16#40#;
   Who_Am_I      : constant Byte := 16#4F#;
   Config_A      : constant Byte := 16#60#;
   Config_B      : constant Byte := 16#61#;
   Config_C      : constant Byte := 16#62#;
   Data_Register : constant Byte := 16#68#;
   Continuous    : constant Byte := 16#00# or 16#0C# or 16#80#;
   Offset_Cancel : constant Byte := 16#02#;
   Block_Update  : constant Byte := 16#10#;

   function Word (Low : Byte; High : Byte) return Integer is
     (if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
      else Integer (High) * 256 + Integer (Low))
     with Global => null,
          Post   => Word'Result in -32_768 .. 32_767;

   --  The low 16 bits, as the reference's 16-bit store keeps a negated -32768.
   function Wrapped (V : Integer) return Interfaces.Integer_16 is
     (Interfaces.Integer_16 ((V + 32_768) mod 65_536 - 32_768))
     with Global => null,
          Pre    => V in -32_768 .. 32_768;

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
   begin
      Register_Device (D);
      Write_Register (D, Config_A, Continuous, OK);
      if OK then
         Write_Register (D, Config_B, Offset_Cancel, OK);
      end if;
      if OK then
         Write_Register (D, Config_C, Block_Update, OK);
      end if;
      if OK then
         S.ODR_Hz := 100;
      end if;
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
      Data (0) := Wrapped (-Word (B (0), B (1)));
      Data (1) := Wrapped (Word (B (2), B (3)));
      Data (2) := Wrapped (Word (B (4), B (5)));
      S.Start_Next := True;
      Got := True;
   end Read;

end Adaflight.LIS2MDL;
