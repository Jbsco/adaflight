package body Adaflight.AK9916 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address        : constant Byte := 16#0C#;
   Device_Id      : constant Byte := 16#09#;
   Identity_2     : constant Byte := 16#01#;
   Status_1       : constant Byte := 16#10#;
   Control_2      : constant Byte := 16#31#;
   Control_3      : constant Byte := 16#32#;
   Soft_Reset     : constant Byte := 16#01#;
   Continuous_100 : constant Byte := 16#08#;
   Mode_Mask      : constant Byte := 16#1F#;
   Ready_Mask     : constant Byte := 16#01#;
   Overflow_Mask  : constant Byte := 16#08#;

   function Axis (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (Interfaces.Integer_16
        (Integer'Max (-32_768, Integer'Min (32_767,
           (if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
            else Integer (High) * 256 + Integer (Low)) * 3 / 2))))
     with Global => null;

   procedure Detect (D : in out Bus_Device; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      Found := False;
      if not Is_I2C (D) then
         return;
      end if;
      if I2C_Address (D) = 0 then
         Set_I2C_Address (D, Address);
      end if;
      Read_Registers (D, Identity_2, Id, OK);
      Found := OK and then Id (0) = Device_Id;
   end Detect;

   procedure Setup_Mode (D : in out Bus_Device; OK : out Boolean) is
      Mode : Byte_Array (0 .. 0) := (0 => 0);
   begin
      Write_Register (D, Control_2, Continuous_100, OK);
      if not OK then
         return;
      end if;
      Read_Registers (D, Control_2, Mode, OK);
      if not OK then
         return;
      end if;
      OK := (Mode (0) and Mode_Mask) = Continuous_100;
   end Setup_Mode;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
   begin
      S.No_Data := 0;
      Register_Device (D);
      Write_Register (D, Control_3, Soft_Reset, OK);
      if not OK then
         return;
      end if;
      Delay_Ms (D, 1);
      Setup_Mode (D, OK);
      if not OK then
         return;
      end if;
      S.ODR_Hz := 100;
   end Init;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      B            : Byte_Array (0 .. 8) := (others => 0);
      OK           : Boolean;
      Ignored_Mode : Byte_Array (0 .. 0) := (0 => 0);
      Ignored      : Boolean;
   begin
      Got := False;
      Read_Registers (D, Status_1, B, OK);
      if not OK then
         return;
      end if;
      if (B (0) and Ready_Mask) = 0 then
         if S.No_Data + 1 >= No_Data_Retries then
            S.No_Data := 0;
            Write_Register (D, Control_2, Continuous_100, OK);
            if OK then
               Read_Registers (D, Control_2, Ignored_Mode, Ignored);
            end if;
         else
            S.No_Data := S.No_Data + 1;
         end if;
         return;
      end if;
      S.No_Data := 0;
      if (B (8) and Overflow_Mask) /= 0 then
         return;
      end if;
      for K in 0 .. 2 loop
         Data (K) := Axis (B (1 + 2 * K), B (2 + 2 * K));
      end loop;
      Got := True;
   end Read;

end Adaflight.AK9916;
