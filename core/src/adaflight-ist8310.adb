package body Adaflight.IST8310 with SPARK_Mode is

   use type Interfaces.Unsigned_8;

   Address           : constant Byte := 16#0E#;
   Who_Am_I          : constant Byte := 16#00#;
   Device_Id         : constant Byte := 16#10#;
   Data_Register     : constant Byte := 16#03#;
   Status_Register   : constant Byte := 16#02#;
   Ready_Mask        : constant Byte := 16#01#;
   Control_1         : constant Byte := 16#0A#;
   Average_Register  : constant Byte := 16#41#;
   Pulse_Register    : constant Byte := 16#42#;
   Single            : constant Byte := 16#01#;
   Average_16        : constant Byte := 16#24#;
   Pulse_Normal      : constant Byte := 16#C0#;
   Scale             : constant := 3;

   --  The low 16 bits of a scaled axis, as the reference's 16-bit store keeps them.
   function Wrapped (V : Integer) return Interfaces.Integer_16 is
     (Interfaces.Integer_16 ((V + 32_768) mod 65_536 - 32_768))
     with Global => null,
          Pre    => V in -1_000_000 .. 1_000_000;

   function Word (Low : Byte; High : Byte) return Integer is
     (if High >= 128 then Integer (High) * 256 + Integer (Low) - 65_536
      else Integer (High) * 256 + Integer (Low))
     with Global => null,
          Post   => Word'Result in -32_768 .. 32_767;

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
      Write_Register (D, Average_Register, Average_16, OK);
      Delay_Ms (D, 6);
      if OK then
         Write_Register (D, Pulse_Register, Pulse_Normal, OK);
      end if;
      Delay_Ms (D, 6);
      if OK then
         Write_Register (D, Control_1, Single, OK);
      end if;
      S.ODR_Hz := 100;
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
         when Check_Status =>
            if (S.Status and Ready_Mask) /= 0 then
               Start_Read (D, Data_Register, 6, Started);
               if Started then
                  S.Pending := Data_Read;
                  S.Phase := Read_Data;
                  S.Retries := 0;
               end if;
            elsif S.Retries >= Max_Retries then
               S.Phase := Trigger;
               S.Retries := 0;
            else
               Start_Read (D, Status_Register, 1, Started);
               if Started then
                  S.Pending := Status_Read;
                  S.Retries := S.Retries + 1;
               end if;
            end if;
         when Read_Data =>
            Data (0) := Wrapped (Word (S.Buffer (0), S.Buffer (1)) * Scale);
            Data (1) := Wrapped ((-Word (S.Buffer (2), S.Buffer (3))) * Scale);
            Data (2) := Wrapped (Word (S.Buffer (4), S.Buffer (5)) * Scale);
            Start_Write (D, Control_1, Single, Started);
            if Started then
               S.Phase := Check_Status;
               S.Status := 0;
               Got := True;
            else
               S.Phase := Trigger;
            end if;
         when Trigger =>
            Start_Write (D, Control_1, Single, Started);
            if Started then
               S.Phase := Check_Status;
               S.Status := 0;
               Got := True;
            end if;
      end case;
   end Read;

end Adaflight.IST8310;
