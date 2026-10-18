package body Adaflight.STK_Bootloader with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   Bit_Low_Us  : constant := 32;
   Bit_High_Us : constant := 2 * Bit_Low_Us;
   Bit_Timeout : constant := 250;

   Wait_Ticks        : constant := 1000 / Bit_Timeout;
   Wait_Cycles       : constant := Wait_Ticks * 35;
   Wait_Cycles_Start : constant := Wait_Ticks / 2;
   Wait_Cycles_Long  : constant := Wait_Ticks * 5000;

   Message_Start : constant Byte := 16#1B#;
   Token         : constant Byte := 16#0E#;

   Command_Sign_On        : constant Byte := 16#01#;
   Command_Load_Address   : constant Byte := 16#06#;
   Command_Chip_Erase     : constant Byte := 16#12#;
   Command_Program_Flash  : constant Byte := 16#13#;
   Command_Read_Flash     : constant Byte := 16#14#;
   Command_Program_EEPROM : constant Byte := 16#15#;
   Command_Read_EEPROM    : constant Byte := 16#16#;
   Command_SPI_Multi      : constant Byte := 16#1D#;
   Status_OK              : constant Byte := 16#00#;
   Memory_Read            : constant Byte := 16#A0#;
   Signature_Read         : constant Byte := 16#30#;

   --  The state of one reply: the check of the bytes received, the time of
   --  the last bit, the learned threshold and the command it answers.
   type Exchange is record
      Check_In      : Byte := 0;
      Last_Bit_Time : Unsigned_32 := 0;
      Threshold     : Unsigned_32 := Bit_High_Us + Bit_Low_Us;
      Command       : Byte := 0;
   end record;

   subtype Bit_Value is Integer range -1 .. 1;

   procedure Send_Byte (L : in out Line; ESC : Byte; Data : Byte)
     with Global => null
   is
      D : Byte := Data;
   begin
      for I in 1 .. 8 loop
         if (D and 1) /= 0 then
            Pin_High (L, ESC);
            Delay_Micros (L, Bit_High_Us);
            Pin_Low (L, ESC);
            Delay_Micros (L, Bit_High_Us);
         else
            Pin_High (L, ESC);
            Delay_Micros (L, Bit_Low_Us);
            Pin_Low (L, ESC);
            Delay_Micros (L, Bit_Low_Us);
            Pin_High (L, ESC);
            Delay_Micros (L, Bit_Low_Us);
            Pin_Low (L, ESC);
            Delay_Micros (L, Bit_Low_Us);
         end if;
         D := Interfaces.Shift_Right (D, 1);
      end loop;
   end Send_Byte;

   --  A byte that the message's XOR check covers.
   procedure Send_Checked (L : in out Line; ESC : Byte; Check : in out Byte; Data : Byte)
     with Global => null
   is
   begin
      Check := Check xor Data;
      Send_Byte (L, ESC, Data);
   end Send_Checked;

   procedure Send_Header (L : in out Line; ESC : Byte; K : in out Link; Check : out Byte)
     with Global => null
   is
   begin
      Pin_Output (L, ESC);
      Send_Byte (L, ESC, 16#FF#);
      Send_Byte (L, ESC, 16#FF#);
      Send_Byte (L, ESC, 16#7F#);
      Check := 0;
      Send_Checked (L, ESC, Check, Message_Start);
      K.Sequence := K.Sequence + 1;
      Send_Checked (L, ESC, Check, K.Sequence);
   end Send_Header;

   procedure Send_Body (L : in out Line; ESC : Byte; Check : in out Byte; Data : Byte_Array)
     with Global => null
   is
   begin
      for I in Data'Range loop
         Send_Checked (L, ESC, Check, Data (I));
      end loop;
   end Send_Body;

   procedure Send_Footer (L : in out Line; ESC : Byte; Check : Byte)
     with Global => null
   is
   begin
      Send_Byte (L, ESC, Check);
      Pin_High (L, ESC);
      Delay_Micros (L, Bit_Low_Us);
      Pin_Input (L, ESC);
   end Send_Footer;

   --  Waits while the pin reads as the level given, failing once the clock
   --  passes the deadline.
   procedure Wait_While (L : in out Line; ESC : Byte; High : Boolean; Deadline : Unsigned_32; OK : out Boolean)
     with Global => null
   is
      Level : Boolean;
      Now   : Unsigned_32;
   begin
      loop
         Read_Pin (L, ESC, Level);
         exit when Level /= High;
         Read_Micros (L, Now);
         if Now > Deadline then
            OK := False;
            return;
         end if;
      end loop;
      OK := True;
   end Wait_While;

   procedure Read_Bit (L : in out Line; ESC : Byte; X : in out Exchange; Bit : out Bit_Value)
     with Global => null
   is
      Start    : Unsigned_32;
      Now      : Unsigned_32;
      Deadline : Unsigned_32;
      OK       : Boolean;
   begin
      Bit := -1;
      Read_Micros (L, Start);
      Deadline := Start + Bit_Timeout;
      Wait_While (L, ESC, True, Deadline, OK);
      if not OK then
         return;
      end if;
      Wait_While (L, ESC, False, Deadline, OK);
      if not OK then
         return;
      end if;
      Read_Micros (L, Now);
      X.Last_Bit_Time := Now - Start;
      if X.Last_Bit_Time <= X.Threshold then
         Deadline := Deadline + Bit_Timeout;
         Wait_While (L, ESC, True, Deadline, OK);
         if not OK then
            return;
         end if;
         Wait_While (L, ESC, False, Deadline, OK);
         if not OK then
            return;
         end if;
         Bit := 0;
      else
         Bit := 1;
      end if;
   end Read_Bit;

   --  A byte from the lowest bit; a failed bit leaves the bits read so far.
   procedure Read_Byte (L : in out Line; ESC : Byte; X : in out Exchange; B : out Byte; OK : out Boolean)
     with Global => null
   is
      Bit : Bit_Value;
   begin
      B := 0;
      for I in 0 .. 7 loop
         Read_Bit (L, ESC, X, Bit);
         if Bit = -1 then
            OK := False;
            return;
         end if;
         if Bit = 1 then
            B := B or Interfaces.Shift_Left (1, I);
         end if;
      end loop;
      X.Check_In := X.Check_In xor B;
      OK := True;
   end Read_Byte;

   procedure Read_Leader (L : in out Line; ESC : Byte; X : in out Exchange; OK : out Boolean)
     with Global => null
   is
      Cycles : Natural;
      Bit    : Bit_Value;
   begin
      X.Threshold := Bit_High_Us + Bit_Low_Us;
      Cycles := (if X.Command = Command_Program_EEPROM or else X.Command = Command_Chip_Erase then Wait_Cycles_Long
                 elsif X.Command = Command_Sign_On then Wait_Cycles_Start
                 else Wait_Cycles);
      loop
         exit when Cycles = 0;
         Read_Bit (L, ESC, X, Bit);
         exit when Bit > -1;
         Cycles := Cycles - 1;
      end loop;
      if Cycles = 0 then
         OK := False;
         return;
      end if;
      for I in 1 .. 10 loop
         Read_Bit (L, ESC, X, Bit);
         if Bit = -1 then
            OK := False;
            return;
         end if;
      end loop;
      X.Threshold := Interfaces.Shift_Right (X.Last_Bit_Time, 1) + Interfaces.Shift_Right (X.Last_Bit_Time, 2);
      loop
         Read_Bit (L, ESC, X, Bit);
         if Bit = -1 then
            OK := False;
            return;
         end if;
         exit when Bit = 0;
      end loop;
      OK := True;
   end Read_Leader;

   --  A reply to Command into Data from its first element: the body after
   --  the command and its status, as many bytes as the length says. Bytes
   --  past the end of Data are read and checked but not kept.
   procedure Receive_Packet
     (L        : in out Line;
      ESC      : Byte;
      Sequence : Byte;
      Command  : Byte;
      Data     : in out Byte_Array;
      OK       : out Boolean)
     with Global => null,
          Pre    => Data'First = 0 and then Data'Length >= 1
   is
      X            : Exchange := (Command => Command, others => <>);
      B            : Byte;
      Got          : Boolean;
      Len_High     : Byte;
      Len_Low      : Byte;
      Count        : Integer;
      Unused_Got   : Boolean;
      Unused_Check : Byte;
   begin
      OK := False;
      Read_Leader (L, ESC, X, Got);
      if not Got then
         return;
      end if;
      X.Check_In := 0;
      Read_Byte (L, ESC, X, B, Got);
      if not Got or else B /= Message_Start then
         return;
      end if;
      Read_Byte (L, ESC, X, B, Got);
      if not Got or else B /= Sequence then
         return;
      end if;
      Read_Byte (L, ESC, X, Len_High, Unused_Got);
      if Len_High > 1 then
         return;
      end if;
      Read_Byte (L, ESC, X, Len_Low, Unused_Got);
      if Len_Low < 1 then
         return;
      end if;
      Read_Byte (L, ESC, X, B, Got);
      if not Got or else B /= Token then
         return;
      end if;
      Read_Byte (L, ESC, X, B, Got);
      if not Got or else B /= X.Command then
         return;
      end if;
      Read_Byte (L, ESC, X, B, Got);
      if not Got or else B /= Status_OK then
         return;
      end if;
      Count := Natural (Len_High) * 256 + Natural (Len_Low) - 2;
      for I in 0 .. Count - 1 loop
         Read_Byte (L, ESC, X, B, Got);
         if I <= Data'Last then
            Data (I) := B;
         end if;
         if not Got then
            return;
         end if;
      end loop;
      Read_Byte (L, ESC, X, Unused_Check, Unused_Got);
      OK := X.Check_In = 0;
   end Receive_Packet;

   procedure SPI_Multi
     (L      : in out Line;
      ESC    : Byte;
      K      : in out Link;
      Code   : Byte;
      High   : Byte;
      Low    : Byte;
      Result : in out Byte;
      OK     : out Boolean)
     with Global => null
   is
      Check : Byte;
   begin
      Send_Header (L, ESC, K, Check);
      Send_Body (L, ESC, Check, (0, 8, Token, Command_SPI_Multi, 4, 4, 0, Code, High, Low, 0));
      Send_Footer (L, ESC, Check);
      Receive_Packet (L, ESC, K.Sequence, Command_SPI_Multi, K.In_Buffer, OK);
      if OK and then K.In_Buffer (0) = 0 and then (K.In_Buffer (1) = Code or else K.In_Buffer (1) = 0)
        and then K.In_Buffer (2) = 0
      then
         Result := K.In_Buffer (3);
      end if;
   end SPI_Multi;

   procedure Sign_On (L : in out Line; ESC : Byte; K : in out Link; OK : out Boolean)
     with Global => null
   is
      Check : Byte;
   begin
      Send_Header (L, ESC, K, Check);
      Send_Body (L, ESC, Check, (0, 1, Token, Command_Sign_On));
      Send_Footer (L, ESC, Check);
      Receive_Packet (L, ESC, K.Sequence, Command_Sign_On, K.In_Buffer, OK);
   end Sign_On;

   procedure Load_Address (L : in out Line; K : in out Link; R : Four_Way.Request; OK : out Boolean)
     with Global => null
   is
      Check : Byte;
   begin
      if R.Address_High = 16#FF# and then R.Address_Low = 16#FF# then
         OK := True;
         return;
      end if;
      Send_Header (L, R.ESC, K, Check);
      Send_Body (L, R.ESC, Check, (0, 5, Token, Command_Load_Address, 0, 0, R.Address_High, R.Address_Low));
      Send_Footer (L, R.ESC, Check);
      Receive_Packet (L, R.ESC, K.Sequence, Command_Load_Address, K.In_Buffer, OK);
   end Load_Address;

   procedure Read_Memory
     (L       : in out Line;
      K       : in out Link;
      R       : Four_Way.Request;
      Command : Byte;
      Data    : in out Four_Way.Param_Buffer;
      OK      : out Boolean)
     with Global => null
   is
      Check : Byte;
   begin
      Send_Header (L, R.ESC, K, Check);
      Send_Body (L, R.ESC, Check, (0, 4, Token, Command, (if R.Count > 0 then 0 else 1), R.Count, Memory_Read));
      Send_Footer (L, R.ESC, Check);
      Receive_Packet (L, R.ESC, K.Sequence, Command, Data, OK);
   end Read_Memory;

   procedure Program_Memory
     (L       : in out Line;
      K       : in out Link;
      R       : Four_Way.Request;
      Command : Byte;
      Params  : Four_Way.Param_Buffer;
      OK      : out Boolean)
     with Global => null
   is
      Check  : Byte;
      Length : constant Natural := Four_Way.Span (R.Count) + 10;
   begin
      Send_Header (L, R.ESC, K, Check);
      Send_Body (L, R.ESC, Check, (Byte (Length / 256), Byte (Length mod 256), Token, Command,
                                   (if R.Count /= 0 then 0 else 1), R.Count, 0, 0, 0, 0, 0, 0, 0));
      Send_Body (L, R.ESC, Check, Params (0 .. Four_Way.Span (R.Count) - 1));
      Send_Footer (L, R.ESC, Check);
      Receive_Packet (L, R.ESC, K.Sequence, Command, K.In_Buffer, OK);
   end Program_Memory;

   procedure Perform
     (L      : in out Line;
      K      : in out Link;
      R      : Four_Way.Request;
      Info   : Four_Way.Device_Info;
      Params : Four_Way.Param_Buffer;
      Result : out Four_Way.Result)
   is
      OK : Boolean;
   begin
      Result := (Code => 0, Info => Info, Data => Params);
      case R.Kind is
         when Four_Way.STK_Connect =>
            Sign_On (L, R.ESC, K, OK);
            if OK then
               SPI_Multi (L, R.ESC, K, Signature_Read, 0, 1, Result.Info (1), OK);
               if OK then
                  SPI_Multi (L, R.ESC, K, Signature_Read, 0, 2, Result.Info (0), OK);
               end if;
            end if;
         when Four_Way.STK_Sign_On =>
            Sign_On (L, R.ESC, K, OK);
         when Four_Way.STK_Chip_Erase =>
            declare
               Check : Byte;
            begin
               Send_Header (L, R.ESC, K, Check);
               Send_Body (L, R.ESC, Check, (0, 7, Token, Command_Chip_Erase, 20, 0, 16#AC#, 16#88#, 16#13#, 16#76#));
               Send_Footer (L, R.ESC, Check);
               Receive_Packet (L, R.ESC, K.Sequence, Command_Chip_Erase, K.In_Buffer, OK);
            end;
         when Four_Way.STK_Read_Flash | Four_Way.STK_Read_EEPROM =>
            Load_Address (L, K, R, OK);
            if OK then
               Read_Memory (L, K, R, (if R.Kind = Four_Way.STK_Read_Flash then Command_Read_Flash
                                      else Command_Read_EEPROM), Result.Data, OK);
            end if;
         when Four_Way.STK_Write_Flash | Four_Way.STK_Write_EEPROM =>
            Load_Address (L, K, R, OK);
            if OK then
               Program_Memory (L, K, R, (if R.Kind = Four_Way.STK_Write_Flash then Command_Program_Flash
                                         else Command_Program_EEPROM), Params, OK);
            end if;
         when others =>
            OK := False;
      end case;
      Result.Code := (if OK then 1 else 0);
   end Perform;

end Adaflight.STK_Bootloader;
