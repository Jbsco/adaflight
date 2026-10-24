package body Adaflight.LPS with SPARK_Mode is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   subtype I32 is Interfaces.Integer_32;

   Who_Am_I         : constant Byte := 16#0F#;
   Resolution       : constant Byte := 16#10#;
   Control_1        : constant Byte := 16#20#;
   Control_2        : constant Byte := 16#21#;
   Control_4        : constant Byte := 16#23#;
   Status           : constant Byte := 16#27#;
   Pressure_Out     : constant Byte := 16#28#;
   LPS22_Identity   : constant Byte := 16#B1#;
   LPS25_Identity   : constant Byte := 16#BD#;
   Read_Command     : constant Byte := 16#C0#;
   Power_Down       : constant Byte := 16#04#;
   Run_25_Hz        : constant Byte := 16#CE#;
   Averages         : constant Byte := 16#0F#;
   Data_Ready_Pin   : constant Byte := 16#01#;
   Max_SPI_Clock_Hz : constant := 10_000_000;
   Timeout_Ms       : constant := 500;

   procedure Write_Verify (D : in out Bus_Device; Register : Byte; Value : Byte; OK : out Boolean) is
      Back : Byte;
   begin
      Write_Plain (D, Register, Value);
      Read_Byte (D, Register, Back);
      OK := Back = Value;
   end Write_Verify;

   procedure Read_Sample (D : in out Bus_Device; S : in out State) is
      Status_Byte : Byte_Array (0 .. 0);
      Data        : Byte_Array (0 .. 4);
   begin
      Read_Registers (D, Status or Read_Command, Status_Byte);
      if (Status_Byte (0) and 16#03#) /= 0 then
         Read_Registers (D, Pressure_Out or Read_Command, Data);
         S.Raw_P := I32 (Data (0)) + I32 (Data (1)) * 256 + I32 (Data (2)) * 65_536
           - (if Data (2) >= 128 then 2 ** 24 else 0);
         S.Raw_T := Interfaces.Unsigned_16 (Data (4)) * 256 + Interfaces.Unsigned_16 (Data (3));
      else
         S.Raw_P := 0;
         S.Raw_T := 0;
      end if;
   end Read_Sample;

   procedure Detect
     (D      : in out Bus_Device;
      S      : in out State;
      Found  : out Boolean;
      Device : out Barometer_Task.Device)
   is
      Identity    : Byte_Array (0 .. 0);
      Unused_Back : Byte_Array (0 .. 0);
      OK          : Boolean;
      Started     : Interfaces.Unsigned_32;
      Now         : Interfaces.Unsigned_32;
   begin
      Device := (others => <>);
      Found := False;
      if not Is_SPI (D) then
         return;
      end if;
      Prepare_SPI (D, Max_SPI_Clock_Hz);
      Read_Registers (D, Who_Am_I or Read_Command, Identity);
      S.Chip_Id := Identity (0);
      if S.Chip_Id /= LPS22_Identity and then S.Chip_Id /= LPS25_Identity then
         return;
      end if;
      Write_Register (D, Control_1, Power_Down);
      Write_Verify (D, Control_2, 0, OK);
      if not OK then
         return;
      end if;
      Write_Verify (D, Resolution, Averages, OK);
      if not OK then
         return;
      end if;
      Write_Verify (D, Control_4, Data_Ready_Pin, OK);
      if not OK then
         return;
      end if;
      Write_Register (D, Control_1, Run_25_Hz);
      Read_Registers (D, Control_1 or Read_Command, Unused_Back);
      Device := (Combined_Read => True, Temperature_Delay_Us => 1, Pressure_Delay_Us => 41_666);
      Millis (D, Started);
      loop
         Read_Sample (D, S);
         Millis (D, Now);
         if Now - Started > Timeout_Ms then
            return;
         end if;
         exit when S.Raw_T /= 0 or else S.Raw_P /= 0;
      end loop;
      S.Raw_T := 0;
      S.Raw_P := 0;
      Found := True;
   end Detect;

   procedure Device_Call
     (D    : in out Bus_Device;
      S    : in out State;
      Call : Barometer_Task.Device_Call;
      Done : out Boolean) is
   begin
      case Call is
         when Barometer_Task.Start_Temperature | Barometer_Task.Read_Temperature
            | Barometer_Task.Get_Temperature | Barometer_Task.Start_Pressure
            | Barometer_Task.Read_Pressure =>
            null;
         when Barometer_Task.Get_Pressure =>
            Read_Sample (D, S);
      end case;
      Done := True;
   end Device_Call;

   procedure Calculate (S : State; Pressure : out Interfaces.Integer_32; Temperature : out Interfaces.Integer_32) is
   begin
      Pressure := S.Raw_P * 100 / 4096;
      Temperature := I32 (S.Raw_T) * 10 / 48 + 4250;
   end Calculate;

end Adaflight.LPS;
