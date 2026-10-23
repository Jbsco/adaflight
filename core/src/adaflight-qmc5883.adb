package body Adaflight.QMC5883 with SPARK_Mode is

   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;

   L_Address        : constant Byte := 16#0D#;
   L_Reset_Register : constant Byte := 16#0B#;
   L_Conf_1         : constant Byte := 16#09#;
   L_Conf_2         : constant Byte := 16#0A#;
   L_Id_Register    : constant Byte := 16#0D#;
   L_Id             : constant Byte := 16#FF#;
   L_Soft_Reset     : constant Byte := 16#80#;
   L_Mode_Mask      : constant Byte := 16#03#;
   L_Standby        : constant Byte := 16#00#;
   L_Config         : constant Byte := 16#01# or 16#0C# or 16#00# or 16#10#;
   P_Address        : constant Byte := 16#2C#;
   P_Id_Register    : constant Byte := 16#00#;
   P_Id             : constant Byte := 16#80#;
   P_Sign_Register  : constant Byte := 16#29#;
   P_Sign           : constant Byte := 16#06#;
   P_Conf_1         : constant Byte := 16#0A#;
   P_Conf_2         : constant Byte := 16#0B#;
   P_Config_1       : constant Byte := 16#03# or 16#08# or 16#10# or 16#00#;
   P_Config_2       : constant Byte := 16#08#;

   type Register_Table is array (Variant) of Byte;
   Status_Register : constant Register_Table := (L => 16#06#, P => 16#09#);
   Data_Register   : constant Register_Table := (L => 16#00#, P => 16#01#);
   Unlock_Register : constant Register_Table := (L => 16#05#, P => 16#00#);
   Ready_Mask      : constant Register_Table := (L => 16#01#, P => 16#01#);
   Overrun_Mask    : constant Register_Table := (L => 16#04#, P => 16#00#);

   function Word (Low : Byte; High : Byte) return Interfaces.Integer_16 is
     (if High >= 128 then Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low) - 65_536)
      else Interfaces.Integer_16 (Integer (High) * 256 + Integer (Low)))
     with Global => null;

   procedure Detect_L (D : in out Bus_Device; S : in out State; Found : out Boolean) is
      Id      : Byte_Array (0 .. 0) := (0 => 0);
      OK      : Boolean;
      Ignored : Boolean;
   begin
      Found := False;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, L_Address);
      end if;
      Write_Register (D, L_Conf_2, L_Soft_Reset, Ignored);
      Delay_Ms (D, 20);
      Read_Registers (D, L_Id_Register, Id, OK);
      if OK and then Id (0) = L_Id then
         Read_Registers (D, L_Conf_1, Id, OK);
         if OK and then (Id (0) and L_Mode_Mask) /= L_Standby then
            return;
         end if;
         S.Kind := L;
         Found := True;
      end if;
   end Detect_L;

   procedure Detect_P (D : in out Bus_Device; S : in out State; Found : out Boolean) is
      Id : Byte_Array (0 .. 0) := (0 => 0);
      OK : Boolean;
   begin
      Found := False;
      if Is_I2C (D) and then I2C_Address (D) = 0 then
         Set_I2C_Address (D, P_Address);
      end if;
      Read_Registers (D, P_Id_Register, Id, OK);
      if not OK or else Id (0) /= P_Id then
         return;
      end if;
      S.Kind := P;
      Found := True;
   end Detect_P;

   procedure Init (D : in out Bus_Device; S : in out State; OK : out Boolean) is
      Ack : Boolean;
   begin
      Register_Device (D);
      if S.Kind = L then
         Write_Register (D, L_Reset_Register, 16#01#, Ack);
         if Ack then
            Write_Register (D, L_Conf_1, L_Config, Ack);
         end if;
      else
         Write_Register (D, P_Sign_Register, P_Sign, Ack);
         if Ack then
            Write_Register (D, P_Conf_1, P_Config_1, Ack);
         end if;
         if Ack then
            Write_Register (D, P_Conf_2, P_Config_2, Ack);
         end if;
      end if;
      OK := Ack;
      if Ack then
         S.ODR_Hz := (if S.Kind = L then 200 else 100);
      end if;
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
         when Unlock_Read =>
            declare
               B : Byte_Array (0 .. 0);
            begin
               Fetch (D, B);
               S.Buffer (5) := B (0);
            end;
      end case;
      S.Pending := None;
   end Take_Pending;

   procedure Read (D : in out Bus_Device; S : in out State; Data : in out Axes; Got : out Boolean) is
      Started : Boolean;
   begin
      Got := False;
      Take_Pending (D, S);
      case S.Phase is
         when Wait_Ready =>
            if (S.Status and Ready_Mask (S.Kind)) /= 0 then
               Start_Read (D, Data_Register (S.Kind), 6, Started);
               if Started then
                  S.Phase := Data_Started;
                  S.Pending := Data_Read;
               end if;
            elsif (S.Status and Overrun_Mask (S.Kind)) /= 0 then
               Start_Read (D, Unlock_Register (S.Kind), 1, Started);
               if Started then
                  S.Status := 0;
                  S.Pending := Unlock_Read;
               end if;
            else
               Start_Read (D, Status_Register (S.Kind), 1, Started);
               if Started then
                  S.Pending := Status_Read;
               end if;
            end if;
         when Data_Started =>
            declare
               Reading : constant Axes :=
                 (Word (S.Buffer (0), S.Buffer (1)), Word (S.Buffer (2), S.Buffer (3)),
                  Word (S.Buffer (4), S.Buffer (5)));
            begin
               if S.Kind = P then
                  if Reading = (0, 0, 0) or else Reading = (-1, -1, -1) then
                     S.Phase := Wait_Ready;
                     return;
                  end if;
                  if Reading = S.Last then
                     if S.Stuck_Count = 10 then
                        S.Phase := Wait_Ready;
                        S.Stuck_Count := 0;
                        return;
                     end if;
                     S.Stuck_Count := S.Stuck_Count + 1;
                  else
                     S.Stuck_Count := 0;
                  end if;
                  S.Last := Reading;
               end if;
               Data := Reading;
               S.Phase := Wait_Ready;
               S.Status := 0;
               Got := True;
            end;
      end case;
   end Read;

end Adaflight.QMC5883;
