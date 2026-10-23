package body Adaflight.BLHeli_Bootloader with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Start_Bit_Timeout_Ms : constant := 2;
   Bit_Time             : constant := 52;
   Start_Bit_Time       : constant := Bit_Time / 2 + Bit_Time / 4;

   Reply_Success       : constant Byte := 16#30#;
   Reply_Command_Error : constant Byte := 16#C1#;
   Reply_CRC_Error     : constant Byte := 16#C2#;
   Reply_None          : constant Byte := 16#FF#;

   Command_Run          : constant Byte := 16#00#;
   Command_Prog_Flash   : constant Byte := 16#01#;
   Command_Erase_Flash  : constant Byte := 16#02#;
   Command_Read_SiLabs  : constant Byte := 16#03#;
   Command_Verify_Flash : constant Byte := 16#04#;
   Command_Read_EEPROM  : constant Byte := 16#04#;
   Command_Prog_EEPROM  : constant Byte := 16#05#;
   Command_Read_Atmel   : constant Byte := 16#07#;
   Command_Keep_Alive   : constant Byte := 16#FD#;
   Command_Set_Buffer   : constant Byte := 16#FE#;
   Command_Set_Address  : constant Byte := 16#FF#;

   Erase_Timeout        : constant := 3000 / Start_Bit_Timeout_Ms;
   Write_EEPROM_Timeout : constant := 3000 / Start_Bit_Timeout_Ms;
   Write_Flash_Timeout  : constant := 500 / Start_Bit_Timeout_Ms;
   Verify_Timeout       : constant := 40 / Start_Bit_Timeout_Ms;

   Boot_Init : constant Byte_Array (0 .. 20) :=
     (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16#0D#, Character'Pos ('B'), Character'Pos ('L'), Character'Pos ('H'),
      Character'Pos ('e'), Character'Pos ('l'), Character'Pos ('i'), 16#F4#, 16#7D#);
   Boot_Message : constant Byte_Array (0 .. 2) := (Character'Pos ('4'), Character'Pos ('7'), Character'Pos ('1'));

   procedure Add_CRC (CRC : in out Unsigned_16; B : Byte)
     with Global => null
   is
      X : Byte := B;
   begin
      for I in 1 .. 8 loop
         if ((X and 1) xor Byte (CRC and 1)) /= 0 then
            CRC := Interfaces.Shift_Right (CRC, 1) xor 16#A001#;
         else
            CRC := Interfaces.Shift_Right (CRC, 1);
         end if;
         X := Interfaces.Shift_Right (X, 1);
      end loop;
   end Add_CRC;

   procedure Wait_Until (L : in out Line; Time : Unsigned_32) is
      Now : Unsigned_32;
   begin
      loop
         Read_Micros (L, Now);
         exit when Now >= Time;
      end loop;
   end Wait_Until;

   procedure Receive_Byte (L : in out Line; ESC : Byte; B : in out Byte; Got : out Boolean) is
      Now     : Unsigned_32;
      Wait    : Unsigned_32;
      High    : Boolean;
      Time    : Unsigned_32;
      Bitmask : Unsigned_16 := 0;
      Bit     : Natural range 0 .. 10 := 0;
   begin
      Read_Millis (L, Now);
      Wait := Now + Start_Bit_Timeout_Ms;
      loop
         Read_Pin (L, ESC, High);
         exit when not High;
         Read_Millis (L, Now);
         if Now >= Wait then
            Got := False;
            return;
         end if;
      end loop;
      Read_Micros (L, Now);
      Time := Now + Start_Bit_Time;
      Wait_Until (L, Time);
      loop
         pragma Loop_Invariant (Bit < 10);
         Read_Pin (L, ESC, High);
         if High then
            Bitmask := Bitmask or Interfaces.Shift_Left (1, Bit);
         end if;
         Time := Time + Bit_Time;
         Bit := Bit + 1;
         exit when Bit = 10;
         Wait_Until (L, Time);
      end loop;
      if (Bitmask and 1) /= 0 or else (Bitmask and 16#200#) = 0 then
         Got := False;
         return;
      end if;
      B := Byte (Interfaces.Shift_Right (Bitmask, 1) and 16#FF#);
      Got := True;
   end Receive_Byte;

   procedure Send_Byte (L : in out Line; ESC : Byte; B : Byte) is
      Bitmask : Unsigned_16 := Interfaces.Shift_Left (Unsigned_16 (B), 2) or 1 or 16#400#;
      Time    : Unsigned_32;
   begin
      Read_Micros (L, Time);
      loop
         if (Bitmask and 1) /= 0 then
            Pin_High (L, ESC);
         else
            Pin_Low (L, ESC);
         end if;
         Time := Time + Bit_Time;
         Bitmask := Interfaces.Shift_Right (Bitmask, 1);
         exit when Bitmask = 0;
         Wait_Until (L, Time);
      end loop;
   end Send_Byte;

   procedure Read_Buffer
     (L         : in out Line;
      ESC       : Byte;
      Connected : Boolean;
      Data      : in out Byte_Array;
      Length    : Positive;
      OK        : out Boolean)
     with Pre => Data'First = 0 and then Length <= Data'Length
   is
      CRC       : Unsigned_16 := 0;
      CRC_Low   : Byte := 0;
      CRC_High  : Byte := 0;
      Last_Ack  : Byte := Reply_None;
      Got       : Boolean;
      B         : Byte;
   begin
      for I in 0 .. Length - 1 loop
         B := Data (I);
         Receive_Byte (L, ESC, B, Got);
         if not Got then
            OK := False;
            return;
         end if;
         Data (I) := B;
         Add_CRC (CRC, B);
      end loop;
      if Connected then
         Receive_Byte (L, ESC, CRC_Low, Got);
         if Got then
            Receive_Byte (L, ESC, CRC_High, Got);
         end if;
         if Got then
            Receive_Byte (L, ESC, Last_Ack, Got);
         end if;
         if not Got then
            OK := False;
            return;
         end if;
         if CRC /= (Unsigned_16 (CRC_Low) or Interfaces.Shift_Left (Unsigned_16 (CRC_High), 8)) then
            Last_Ack := Reply_CRC_Error;
         end if;
      else
         Receive_Byte (L, ESC, Last_Ack, Got);
         if not Got then
            OK := False;
            return;
         end if;
      end if;
      OK := Last_Ack = Reply_Success;
   end Read_Buffer;

   procedure Send_Buffer (L : in out Line; ESC : Byte; Connected : Boolean; Data : Byte_Array; Length : Positive)
     with Pre => Data'First = 0 and then Length <= Data'Length
   is
      CRC : Unsigned_16 := 0;
   begin
      Pin_Output (L, ESC);
      for I in 0 .. Length - 1 loop
         Send_Byte (L, ESC, Data (I));
         Add_CRC (CRC, Data (I));
      end loop;
      if Connected then
         Send_Byte (L, ESC, Byte (CRC and 16#FF#));
         Send_Byte (L, ESC, Byte (Interfaces.Shift_Right (CRC, 8)));
      end if;
      Pin_Input (L, ESC);
   end Send_Buffer;

   procedure Get_Ack (L : in out Line; ESC : Byte; Timeout : Natural; Ack : out Byte) is
      Left : Natural := Timeout;
      Got  : Boolean;
   begin
      Ack := Reply_None;
      loop
         Receive_Byte (L, ESC, Ack, Got);
         exit when Got or else Left = 0;
         Left := Left - 1;
      end loop;
   end Get_Ack;

   procedure Set_Address (L : in out Line; R : Four_Way.Request; Connected : Boolean; OK : out Boolean) is
      Ack : Byte;
   begin
      if R.Address_High = 16#FF# and then R.Address_Low = 16#FF# then
         OK := True;
         return;
      end if;
      Send_Buffer (L, R.ESC, Connected, (Command_Set_Address, 0, R.Address_High, R.Address_Low), 4);
      Get_Ack (L, R.ESC, 2, Ack);
      OK := Ack = Reply_Success;
   end Set_Address;

   procedure Set_Buffer
     (L         : in out Line;
      R         : Four_Way.Request;
      Connected : Boolean;
      Params    : Four_Way.Param_Buffer;
      OK        : out Boolean)
   is
      Ack : Byte;
   begin
      Send_Buffer (L, R.ESC, Connected, (Command_Set_Buffer, 0, (if R.Count = 0 then 1 else 0), R.Count), 4);
      Get_Ack (L, R.ESC, 2, Ack);
      if Ack /= Reply_None then
         OK := False;
         return;
      end if;
      Send_Buffer (L, R.ESC, Connected, Params, Four_Way.Span (R.Count));
      Get_Ack (L, R.ESC, 40, Ack);
      OK := Ack = Reply_Success;
   end Set_Buffer;

   procedure Read_At
     (L         : in out Line;
      R         : Four_Way.Request;
      Connected : Boolean;
      Command   : Byte;
      Data      : in out Four_Way.Param_Buffer;
      OK        : out Boolean)
   is
   begin
      Set_Address (L, R, Connected, OK);
      if OK then
         Send_Buffer (L, R.ESC, Connected, (Command, R.Count), 2);
         Read_Buffer (L, R.ESC, Connected, Data, Four_Way.Span (R.Count), OK);
      end if;
   end Read_At;

   procedure Write_At
     (L         : in out Line;
      R         : Four_Way.Request;
      Connected : Boolean;
      Command   : Byte;
      Timeout   : Natural;
      Params    : Four_Way.Param_Buffer;
      OK        : out Boolean)
   is
      Ack : Byte;
   begin
      Set_Address (L, R, Connected, OK);
      if OK then
         Set_Buffer (L, R, Connected, Params, OK);
         if OK then
            Send_Buffer (L, R.ESC, Connected, (Command, 1), 2);
            Get_Ack (L, R.ESC, Timeout, Ack);
            OK := Ack = Reply_Success;
         end if;
      end if;
   end Write_At;

   procedure Perform
     (L      : in out Line;
      R      : Four_Way.Request;
      Info   : Four_Way.Device_Info;
      Params : Four_Way.Param_Buffer;
      Result : out Four_Way.Result)
   is
      Connected : constant Boolean := Info (0) > 0;
      OK        : Boolean;
      Ack       : Byte;
      Boot_Info : Byte_Array (0 .. 8) := (others => 0);
   begin
      Result := (Code => 0, Info => Info, Data => Params);
      case R.Kind is
         when Four_Way.BL_Connect =>
            Send_Buffer (L, R.ESC, Connected, Boot_Init, Boot_Init'Length);
            Read_Buffer (L, R.ESC, Connected, Boot_Info, 8, OK);
            if OK and then Boot_Info (0 .. 2) = Boot_Message then
               Result.Info (2) := Boot_Info (3);
               Result.Info (1) := Boot_Info (4);
               Result.Info (0) := Boot_Info (5);
               Result.Code := 1;
            end if;
         when Four_Way.BL_Keep_Alive =>
            Send_Buffer (L, R.ESC, Connected, (Command_Keep_Alive, 0), 2);
            Get_Ack (L, R.ESC, 1, Ack);
            Result.Code := (if Ack = Reply_Command_Error then 1 else 0);
         when Four_Way.BL_Restart =>
            Result.Info (0) := 1;
            Send_Buffer (L, R.ESC, Result.Info (0) > 0, (Command_Run, 0), 2);
         when Four_Way.BL_Page_Erase =>
            Set_Address (L, R, Connected, OK);
            if OK then
               Send_Buffer (L, R.ESC, Connected, (Command_Erase_Flash, 1), 2);
               Get_Ack (L, R.ESC, Erase_Timeout, Ack);
               Result.Code := (if Ack = Reply_Success then 1 else 0);
            end if;
         when Four_Way.BL_Read_Flash =>
            Read_At (L, R, Connected, (if R.Mode = Four_Way.Atmel_Mode then Command_Read_Atmel
                                       else Command_Read_SiLabs), Result.Data, OK);
            Result.Code := (if OK then 1 else 0);
         when Four_Way.BL_Read_EEPROM =>
            Read_At (L, R, Connected, Command_Read_EEPROM, Result.Data, OK);
            Result.Code := (if OK then 1 else 0);
         when Four_Way.BL_Write_Flash =>
            Write_At (L, R, Connected, Command_Prog_Flash, Write_Flash_Timeout, Params, OK);
            Result.Code := (if OK then 1 else 0);
         when Four_Way.BL_Write_EEPROM =>
            Write_At (L, R, Connected, Command_Prog_EEPROM, Write_EEPROM_Timeout, Params, OK);
            Result.Code := (if OK then 1 else 0);
         when Four_Way.BL_Verify_Flash =>
            Set_Address (L, R, Connected, OK);
            if OK then
               Set_Buffer (L, R, Connected, Params, OK);
               if OK then
                  Send_Buffer (L, R.ESC, Connected, (Command_Verify_Flash, 1), 2);
                  Get_Ack (L, R.ESC, Verify_Timeout, Ack);
                  Result.Code := Ack;
               end if;
            end if;
         when others =>
            null;
      end case;
   end Perform;

end Adaflight.BLHeli_Bootloader;
