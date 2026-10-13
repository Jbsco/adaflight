package body Adaflight.Four_Way with SPARK_Mode is

   Local_Escape     : constant := 16#2F#;
   Remote_Escape    : constant := 16#2E#;
   Interface_Name   : constant String := "m4wFCIntf";
   Protocol_Version : constant := 108;
   Version_High     : constant := 200;
   Version_Low      : constant := 6;
   RX_LED           : constant := 0;
   Reboot_Ms        : constant := 300;
   Release_Ops      : constant := 3 * Max_Motors + 1;
   Reply_Ops        : constant := 3 + Release_Ops;

   procedure Add (O : in out Output; Kind : Op_Kind; Index : Motor_Index := 0; Value : Natural := 0)
     with Pre  => O.Count < Max_Ops and then Value <= 300,
          Post => O.Count = O.Count'Old + 1 and then O.Length = O.Length'Old
   is
   begin
      O.Count := O.Count + 1;
      O.Ops (O.Count) := (Kind => Kind, Index => Index, Value => Value);
   end Add;

   procedure Disconnect (T : in out State) is
   begin
      T.Info (0) := 0;
      T.Info (1) := 0;
   end Disconnect;

   function Word (Info : Device_Info) return Unsigned_16 is
     (Unsigned_16 (Info (0)) + 256 * Unsigned_16 (Info (1)));

   function Atmel_Match (Info : Device_Info) return Boolean is
     (Word (Info) in 16#9307# | 16#930A# | 16#930F# | 16#940B#);

   function SiLabs_Match (Info : Device_Info) return Boolean is
     (Word (Info) > 16#E800# and then Word (Info) < 16#F900#);

   function ARM_Match (Info : Device_Info) return Boolean is
     (Info (1) > 0 and then Info (1) < 16#90# and then Info (0) = 16#06#);

   --  The pins go back to the motor outputs, low, in reverse ESC order, then
   --  each motor takes its pin back, and the motors restart when every one
   --  did.
   procedure Release (T : in out State; O : in out Output)
     with Pre  => O.Count <= Max_Ops - Release_Ops,
          Post => O.Length = O.Length'Old
   is
      Start : constant Op_Count := O.Count;
   begin
      for K in reverse 0 .. T.ESC_Total - 1 loop
         pragma Loop_Invariant (O.Count = Start + 2 * (T.ESC_Total - 1 - K) and then O.Length = O.Length'Loop_Entry);
         Add (O, Pin_Alternate, T.Pins (K));
         Add (O, Pin_Low, T.Pins (K));
      end loop;
      T.ESC_Total := 0;
      for I in Motor_Index loop
         pragma Loop_Invariant (O.Count <= Start + 2 * Max_Motors + I and then O.Length = O.Length'Loop_Entry);
         if T.Enabled (I) and then T.Has_Pin (I) then
            Add (O, Reinstate_Pin, I);
         end if;
      end loop;
      Add (O, Enable_Motors_If_Reinstated);
   end Release;

   --  The reply to the frame: the remote escape, the command, the address,
   --  the output length and parameters, the acknowledgement and the check.
   procedure Reply (T : in out State; O : in out Output)
     with Pre => O.Count <= Max_Ops - Reply_Ops
   is
      N   : constant Positive := Span (T.Out_Length);
      CRC : Unsigned_16 := 0;

      function Source_Byte (I : Param_Index) return Byte is
        (case T.Source is
            when Scratch    => (if I <= Scratch_Index'Last then T.Scratch (I) else 0),
            when Name       =>
              (if I < Interface_Name'Length then Character'Pos (Interface_Name (Interface_Name'First + I)) else 0),
            when Info       => (if I <= Info_Index'Last then T.Info (I) else 0),
            when Parameters => T.Params (I));

      procedure Put (K : Natural; B : Byte)
        with Pre  => K < Max_Reply,
             Post => O.Count = O.Count'Old and then O.Ops = O.Ops'Old
      is
      begin
         O.Reply (K) := B;
         CRC := Adaflight.Bytes.CRC16_CCITT (CRC, B);
      end Put;
   begin
      Add (O, LED_Off, RX_LED);
      Put (0, Remote_Escape);
      Put (1, T.Command);
      Put (2, T.Address_High);
      Put (3, T.Address_Low);
      Put (4, T.Out_Length);
      for I in 0 .. N - 1 loop
         pragma Loop_Invariant (O.Count = O.Count'Loop_Entry);
         Put (5 + I, Source_Byte (I));
      end loop;
      Put (5 + N, T.Ack);
      O.Reply (6 + N) := Byte (CRC / 256);
      O.Reply (7 + N) := Byte (CRC mod 256);
      O.Length := 8 + N;
      Add (O, Send_Reply);
      Add (O, LED_Off, T.TX_LED);
      if T.Exit_Scheduled then
         Release (T, O);
         T.Current := Finished;
      else
         T.Current := Await_Escape;
      end if;
   end Reply;

   procedure Ask (T : in out State; Kind : Request_Kind)
     with Post => T.Current = Awaiting
   is
   begin
      T.Pending := (Kind         => Kind,
                    ESC          => T.Selected,
                    Mode         => T.Mode,
                    Address_High => T.Address_High,
                    Address_Low  => T.Address_Low,
                    Count        => T.Count);
      T.Current := Awaiting;
   end Ask;

   --  Up to three tries, each with the STK500v2 bootloader first unless the
   --  interface is in the ARM mode, then the BLHeli bootloader.
   procedure Next_Connect (T : in out State; O : in out Output)
     with Pre => O.Count <= Max_Ops - Reply_Ops
   is
   begin
      if T.Try = Try_Count'Last then
         Disconnect (T);
         T.Ack := Ack_General_Error;
         Reply (T, O);
      elsif T.Mode /= ARM_Mode then
         Ask (T, STK_Connect);
      else
         Ask (T, BL_Connect);
      end if;
   end Next_Connect;

   procedure Connected (T : in out State; O : in out Output)
     with Pre => O.Count <= Max_Ops - Reply_Ops
   is
   begin
      T.Info (3) := T.Mode;
      Reply (T, O);
   end Connected;

   --  A frame whose check matched.
   procedure Execute (T : in out State; O : in out Output)
     with Pre => O.Count <= Max_Ops - Reply_Ops
   is
   begin
      case T.Command is
         when 16#30# =>
            if T.Info (0) > 0 then
               case T.Mode is
                  when SiLabs_Mode | Atmel_Mode | ARM_Mode =>
                     Ask (T, BL_Keep_Alive);
                  when STK_Mode =>
                     Ask (T, STK_Sign_On);
                  when C2_Mode =>
                     T.Ack := Ack_General_Error;
                     Disconnect (T);
                     Reply (T, O);
               end case;
            else
               Reply (T, O);
            end if;
         when 16#31# =>
            T.Scratch (0) := Protocol_Version;
            Reply (T, O);
         when 16#32# =>
            T.Out_Length := Interface_Name'Length;
            T.Source := Name;
            Reply (T, O);
         when 16#33# =>
            T.Out_Length := 2;
            T.Scratch := (Version_High, Version_Low);
            Reply (T, O);
         when 16#34# =>
            T.Exit_Scheduled := True;
            Reply (T, O);
         when 16#3F# =>
            if T.Params (0) in SiLabs_Mode .. ARM_Mode then
               T.Mode := T.Params (0);
            else
               T.Ack := Ack_Invalid_Param;
            end if;
            Reply (T, O);
         when 16#35# =>
            if Natural (T.Params (0)) < T.ESC_Total then
               T.Selected := T.Params (0);
               T.Reboot := T.Address_Low = 1;
               T.Reboot_Pin := T.Pins (Natural (T.Params (0)));
               case T.Mode is
                  when SiLabs_Mode | Atmel_Mode | ARM_Mode =>
                     Ask (T, BL_Restart);
                  when STK_Mode | C2_Mode =>
                     Disconnect (T);
                     Reply (T, O);
               end case;
            else
               T.Ack := Ack_Invalid_Channel;
               Reply (T, O);
            end if;
         when 16#37# =>
            Disconnect (T);
            if Natural (T.Params (0)) < T.ESC_Total then
               T.Selected := T.Params (0);
               T.Out_Length := Byte (Info_Index'Last + 1);
               T.Source := Info;
               T.Try := 0;
               Next_Connect (T, O);
            else
               T.Ack := Ack_Invalid_Channel;
               Reply (T, O);
            end if;
         when 16#38# =>
            if T.Mode = STK_Mode then
               Ask (T, STK_Chip_Erase);
            else
               T.Ack := Ack_Invalid_Command;
               Reply (T, O);
            end if;
         when 16#39# =>
            case T.Mode is
               when SiLabs_Mode | ARM_Mode =>
                  T.Scratch (0) := T.Params (0);
                  T.Address_High :=
                    Interfaces.Shift_Left (T.Params (0), (if T.Mode = ARM_Mode then 2 else 1));
                  T.Address_Low := 0;
                  Ask (T, BL_Page_Erase);
               when C2_Mode | Atmel_Mode | STK_Mode =>
                  T.Ack := Ack_Invalid_Command;
                  Reply (T, O);
            end case;
         when 16#3A# =>
            T.Count := T.Params (0);
            case T.Mode is
               when SiLabs_Mode | Atmel_Mode | ARM_Mode =>
                  Ask (T, BL_Read_Flash);
               when STK_Mode =>
                  Ask (T, STK_Read_Flash);
               when C2_Mode =>
                  T.Ack := Ack_Invalid_Command;
                  Reply (T, O);
            end case;
         when 16#3D# =>
            T.Count := T.Params (0);
            case T.Mode is
               when Atmel_Mode =>
                  Ask (T, BL_Read_EEPROM);
               when STK_Mode =>
                  Ask (T, STK_Read_EEPROM);
               when C2_Mode | SiLabs_Mode | ARM_Mode =>
                  T.Ack := Ack_Invalid_Command;
                  Reply (T, O);
            end case;
         when 16#3B# =>
            T.Count := T.Param_Length;
            case T.Mode is
               when SiLabs_Mode | Atmel_Mode | ARM_Mode =>
                  Ask (T, BL_Write_Flash);
               when STK_Mode =>
                  Ask (T, STK_Write_Flash);
               when C2_Mode =>
                  Reply (T, O);
            end case;
         when 16#3E# =>
            T.Count := T.Param_Length;
            T.Ack := Ack_General_Error;
            case T.Mode is
               when SiLabs_Mode =>
                  T.Ack := Ack_Invalid_Command;
                  Reply (T, O);
               when Atmel_Mode =>
                  Ask (T, BL_Write_EEPROM);
               when STK_Mode =>
                  Ask (T, STK_Write_EEPROM);
               when C2_Mode | ARM_Mode =>
                  Reply (T, O);
            end case;
         when 16#40# =>
            if T.Mode = ARM_Mode then
               T.Count := T.Param_Length;
               Ask (T, BL_Verify_Flash);
            else
               T.Ack := Ack_Invalid_Command;
               Reply (T, O);
            end if;
         when others =>
            T.Ack := Ack_Invalid_Command;
            Reply (T, O);
      end case;
   end Execute;

   ----------
   -- Init --
   ----------

   procedure Init (T : in out State; Enabled : Motor_Flags; Has_Pin : Motor_Flags; TX_LED : Natural; O : out Output) is
      K : Motor_Total := 0;
   begin
      O := (others => <>);
      T.Enabled := Enabled;
      T.Has_Pin := Has_Pin;
      T.TX_LED := TX_LED;
      T.Pins := (others => 0);
      Add (O, Disable_Motors);
      for I in Motor_Index loop
         pragma Loop_Invariant (K <= I and then O.Count = 1 + 3 * K);
         if Enabled (I) and then Has_Pin (I) then
            Add (O, Release_Pin, I);
            T.Pins (K) := I;
            Add (O, Pin_Input, I);
            Add (O, Pin_High, I);
            K := K + 1;
         end if;
      end loop;
      T.ESC_Total := K;
      T.Current := Await_Escape;
   end Init;

   -----------
   -- Start --
   -----------

   procedure Start (T : in out State; O : out Output) is
   begin
      O := (others => <>);
      Add (O, Silence_Beeper);
      T.Exit_Scheduled := False;
      T.Current := Await_Escape;
   end Start;

   -------------
   -- Receive --
   -------------

   procedure Receive (T : in out State; B : Byte; O : out Output) is
   begin
      O := (others => <>);
      case T.Current is
         when Await_Escape =>
            if B = Local_Escape then
               T.CRC := Adaflight.Bytes.CRC16_CCITT (0, B);
               Add (O, LED_On, RX_LED);
               T.Scratch := (others => 0);
               T.Source := Scratch;
               T.Out_Length := 1;
               T.Current := Command;
            end if;
         when Command =>
            T.Command := B;
            T.CRC := Adaflight.Bytes.CRC16_CCITT (T.CRC, B);
            T.Current := Address_High;
         when Address_High =>
            T.Address_High := B;
            T.CRC := Adaflight.Bytes.CRC16_CCITT (T.CRC, B);
            T.Current := Address_Low;
         when Address_Low =>
            T.Address_Low := B;
            T.CRC := Adaflight.Bytes.CRC16_CCITT (T.CRC, B);
            T.Current := Length;
         when Length =>
            T.Param_Length := B;
            T.CRC := Adaflight.Bytes.CRC16_CCITT (T.CRC, B);
            T.Received := 0;
            T.Current := Parameters;
         when Parameters =>
            if T.Received < Span (T.Param_Length) then
               T.Params (T.Received) := B;
               T.CRC := Adaflight.Bytes.CRC16_CCITT (T.CRC, B);
               T.Received := T.Received + 1;
            end if;
            if T.Received >= Span (T.Param_Length) then
               T.Current := Check_High;
            end if;
         when Check_High =>
            T.Check := Unsigned_16 (B) * 256;
            T.Current := Check_Low;
         when Check_Low =>
            T.Check := T.Check or Unsigned_16 (B);
            T.Ack := (if T.Check = T.CRC then Ack_OK else Ack_Invalid_CRC);
            Add (O, LED_On, T.TX_LED);
            if T.Ack = Ack_OK then
               Execute (T, O);
            else
               Reply (T, O);
            end if;
         when Awaiting | Finished =>
            null;
      end case;
   end Receive;

   --------------
   -- Complete --
   --------------

   procedure Complete (T : in out State; R : Result; O : out Output) is
   begin
      O := (others => <>);
      case T.Pending.Kind is
         when STK_Connect =>
            T.Info := R.Info;
            if R.Code /= 0 and then Atmel_Match (T.Info) then
               T.Mode := STK_Mode;
               Connected (T, O);
            else
               Ask (T, BL_Connect);
            end if;
         when BL_Connect =>
            T.Info := R.Info;
            if R.Code /= 0 and then SiLabs_Match (T.Info) then
               T.Mode := SiLabs_Mode;
               Connected (T, O);
            elsif R.Code /= 0 and then Atmel_Match (T.Info) then
               T.Mode := Atmel_Mode;
               Connected (T, O);
            elsif R.Code /= 0 and then ARM_Match (T.Info) then
               T.Mode := ARM_Mode;
               Connected (T, O);
            else
               if T.Try < Try_Count'Last then
                  T.Try := T.Try + 1;
               end if;
               Next_Connect (T, O);
            end if;
         when BL_Keep_Alive | STK_Sign_On =>
            if R.Code = 0 then
               T.Ack := Ack_General_Error;
               Disconnect (T);
            end if;
            Reply (T, O);
         when BL_Restart =>
            if T.Reboot then
               Add (O, Pin_Output, T.Reboot_Pin);
               Add (O, Pin_Low, T.Reboot_Pin);
               Add (O, Wait_Ms, Value => Reboot_Ms);
               Add (O, Pin_High, T.Reboot_Pin);
               Add (O, Pin_Input, T.Reboot_Pin);
            end if;
            Disconnect (T);
            Reply (T, O);
         when STK_Chip_Erase | BL_Page_Erase | BL_Write_Flash | STK_Write_Flash =>
            if R.Code = 0 then
               T.Ack := Ack_General_Error;
            end if;
            Reply (T, O);
         when BL_Read_Flash | STK_Read_Flash | BL_Read_EEPROM | STK_Read_EEPROM =>
            if R.Code = 0 then
               T.Ack := Ack_General_Error;
            else
               for I in 0 .. Span (T.Count) - 1 loop
                  T.Params (I) := R.Data (I);
               end loop;
               T.Out_Length := T.Count;
               T.Source := Parameters;
            end if;
            Reply (T, O);
         when BL_Write_EEPROM | STK_Write_EEPROM =>
            if R.Code /= 0 then
               T.Ack := Ack_OK;
            end if;
            Reply (T, O);
         when BL_Verify_Flash =>
            T.Ack := (case R.Code is
                         when 16#30# => Ack_OK,
                         when 16#C0# => Ack_Verify_Error,
                         when others => Ack_General_Error);
            Reply (T, O);
      end case;
   end Complete;

end Adaflight.Four_Way;
