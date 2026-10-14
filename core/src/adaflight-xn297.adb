with Adaflight.NRF24L01;

package body Adaflight.XN297 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;

   CRC_Length : constant := 2;

   type Scramble_Table is array (0 .. 29) of Byte;
   Data_Scramble : constant Scramble_Table :=
     (16#BC#, 16#E5#, 16#66#, 16#0D#, 16#AE#, 16#8C#, 16#88#, 16#12#,
      16#69#, 16#EE#, 16#1F#, 16#C7#, 16#62#, 16#97#, 16#D5#, 16#0B#,
      16#79#, 16#CA#, 16#CC#, 16#1B#, 16#5D#, 16#19#, 16#10#, 16#24#,
      16#D3#, 16#DC#, 16#3F#, 16#8E#, 16#C5#, 16#2F#);

   type Xorout_Table is array (0 .. Max_Length) of Interfaces.Unsigned_16;
   CRC_Xorout : constant Xorout_Table :=
     (16#9BA7#, 16#8BBB#, 16#85E1#, 16#3E8C#, 16#451E#, 16#18E6#, 16#6B24#, 16#E7AB#,
      16#3828#, 16#814B#, 16#D461#, 16#F494#, 16#2503#, 16#691D#, 16#FE8B#, 16#9BA7#,
      16#8B17#, 16#2920#, 16#8B5F#, 16#61B1#, 16#D391#, 16#7401#, 16#2138#, 16#129F#,
      16#B3A0#, 16#2988#);

   function Bit_Reverse (B : Byte) return Byte is
      In_Bits  : Byte := B;
      Out_Bits : Byte := 0;
   begin
      for I in 1 .. 8 loop
         Out_Bits := Interfaces.Shift_Left (Out_Bits, 1) or (In_Bits and 1);
         In_Bits := Interfaces.Shift_Right (In_Bits, 1);
      end loop;
      return Out_Bits;
   end Bit_Reverse;

   procedure Unscramble (Data : in out Byte_Array; Length : Natural; Rx_Address : Address;
                         CRC : out Interfaces.Unsigned_16)
   is
   begin
      CRC := 16#B5D2#;
      for I in reverse Address'Range loop
         CRC := Adaflight.Bytes.CRC16_CCITT (CRC, Rx_Address (I));
      end loop;
      for I in 0 .. Length - 1 loop
         CRC := Adaflight.Bytes.CRC16_CCITT (CRC, Data (I));
         Data (I) := Bit_Reverse (Data (I) xor Data_Scramble (I));
      end loop;
      CRC := CRC xor CRC_Xorout (Length);
   end Unscramble;

   procedure Write_Payload (O : in out Adaflight.SPI_Radio.Output; Data : Byte_Array; Length : Natural;
                            Rx_Address : Address)
   is
      Packet : Adaflight.SPI_Radio.Byte_Array (0 .. Address_Length + Length + CRC_Length - 1) := (others => 0);
      CRC    : Interfaces.Unsigned_16 := 16#B5D2#;
   begin
      for I in Address'Range loop
         Packet (I) := Rx_Address (Address_Length - 1 - I);
         CRC := Adaflight.Bytes.CRC16_CCITT (CRC, Packet (I));
      end loop;
      for I in 0 .. Length - 1 loop
         Packet (Address_Length + I) := Bit_Reverse (Data (I)) xor Data_Scramble (I);
         CRC := Adaflight.Bytes.CRC16_CCITT (CRC, Packet (Address_Length + I));
      end loop;
      CRC := CRC xor CRC_Xorout (Length);
      Packet (Address_Length + Length) := Byte (Interfaces.Shift_Right (CRC, 8));
      Packet (Address_Length + Length + 1) := Byte (CRC and 16#FF#);
      Adaflight.NRF24L01.Write_Payload (O, Packet);
   end Write_Payload;

end Adaflight.XN297;
