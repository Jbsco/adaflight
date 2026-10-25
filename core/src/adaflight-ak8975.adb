package body Adaflight.AK8975 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address          : constant Byte := 16#0C#;
   Device_Id        : constant Byte := 16#48#;
   Who_Am_I         : constant Byte := 16#00#;
   Status_1         : constant Byte := 16#02#;
   Data_Register    : constant Byte := 16#03#;
   Status_2         : constant Byte := 16#09#;
   Control          : constant Byte := 16#0A#;
   Sensitivity_X    : constant Byte := 16#10#;
   Ready_Mask       : constant Byte := 16#01#;
   Error_Mask       : constant Byte := 16#04#;
   Overflow_Mask    : constant Byte := 16#08#;
   Power_Down       : constant Byte := 16#00#;
   Fuse_ROM         : constant Byte := 16#0F#;
   Single_16_Bit    : constant Byte := 16#10# or 16#01#;

   function Word (Low : Byte; High : Byte) return Integer is
     (if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
      else Integer (High) * 256 + Integer (Low))
     with Global => null,
          Post   => Word'Result in -32_768 .. 32_767;

   --  The scaled axis clamped to 16 bits, then negated and kept to its low 16
   --  bits, as the reference's 16-bit store keeps a negated -32768.
   function Axis (Low : Byte; High : Byte; G : Gain) return Interfaces.Integer_16 is
     (Interfaces.Integer_16
        ((-Integer'Max (-32_768, Integer'Min (32_767, Word (Low, High) * G / 256)) + 32_768) mod 65_536 - 32_768))
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
      Ignored        : Boolean;
      Got            : Boolean;
      ASA            : Byte_Array (0 .. 2) := (others => 0);
      Ignored_Status : Byte_Array (0 .. 0) := (others => 0);
   begin
      Register_Device (D);
      Write_Register (D, Control, Power_Down, Ignored);
      Delay_Ms (D, 20);
      Write_Register (D, Control, Fuse_ROM, Ignored);
      Delay_Ms (D, 10);
      Read_Registers (D, Sensitivity_X, ASA, Got);
      if not Got then
         OK := False;
         return;
      end if;
      Delay_Ms (D, 10);
      for K in 0 .. 2 loop
         S.Sensitivity (K) := Integer (ASA (K)) + 128;
      end loop;
      Write_Register (D, Control, Power_Down, Ignored);
      Delay_Ms (D, 10);
      Read_Registers (D, Status_1, Ignored_Status, Ignored);
      Read_Registers (D, Status_2, Ignored_Status, Ignored);
      Write_Register (D, Control, Single_16_Bit, Ignored);
      S.ODR_Hz := 50;
      OK := True;
   end Init;

   procedure Take_Pending (D : in out Bus_Device; S : in out State) is
   begin
      case S.Pending is
         when None =>
            null;
         when Status_Read =>
            declare
               B : Byte_Array (0 .. 0);
            begin
               Fetch (D, B);
               S.Status := B (0);
            end;
         when Data_Read =>
            Fetch (D, S.Buffer);
      end case;
      S.Pending := None;
   end Take_Pending;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      Started : Boolean;
   begin
      Take_Pending (D, S);
      Got := False;
      case S.Phase is
         when Read_Status_1 =>
            Start_Read (D, Status_1, 1, Started);
            if Started then
               S.Pending := Status_Read;
               S.Phase := Wait_Status_1;
            end if;
         when Wait_Status_1 =>
            if (S.Status and Ready_Mask) = 0 then
               S.Phase := Read_Status_1;
               return;
            end if;
            Start_Read (D, Data_Register, 6, Started);
            if Started then
               S.Pending := Data_Read;
               S.Phase := Read_Status_2;
            end if;
         when Read_Status_2 =>
            Start_Read (D, Status_2, 1, Started);
            if Started then
               S.Pending := Status_Read;
               S.Phase := Wait_Status_2;
            end if;
         when Wait_Status_2 =>
            Start_Write (D, Control, Single_16_Bit, Started);
            if not Started then
               return;
            end if;
            if (S.Status and Error_Mask) /= 0 or else (S.Status and Overflow_Mask) /= 0 then
               S.Phase := Read_Status_1;
               return;
            end if;
            S.Phase := Wait_Start;
         when Wait_Start =>
            Data (0) := Axis (S.Buffer (0), S.Buffer (1), S.Sensitivity (0));
            Data (1) := Axis (S.Buffer (2), S.Buffer (3), S.Sensitivity (1));
            Data (2) := Axis (S.Buffer (4), S.Buffer (5), S.Sensitivity (2));
            S.Phase := Read_Status_1;
            Got := True;
      end case;
   end Read;

end Adaflight.AK8975;
