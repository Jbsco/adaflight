with Adaflight.Float_Bits;
with Adaflight.MAVLink;

package body Adaflight.MAVLink_Frames with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   procedure Put_U8 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_8) is
   begin
      P (At_Byte) := V;
   end Put_U8;

   procedure Put_U16 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_16) is
   begin
      P (At_Byte) := Unsigned_8 (V and 16#FF#);
      P (At_Byte + 1) := Unsigned_8 (Interfaces.Shift_Right (V, 8));
   end Put_U16;

   procedure Put_U32 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_32) is
   begin
      for K in 0 .. 3 loop
         P (At_Byte + K) := Unsigned_8 (Interfaces.Shift_Right (V, 8 * K) and 16#FF#);
      end loop;
   end Put_U32;

   procedure Put_U64 (P : in out Payload; At_Byte : Payload_Index; V : Unsigned_64) is
   begin
      for K in 0 .. 7 loop
         P (At_Byte + K) := Unsigned_8 (Interfaces.Shift_Right (V, 8 * K) and 16#FF#);
      end loop;
   end Put_U64;

   procedure Put_F32 (P : in out Payload; At_Byte : Payload_Index; V : Float) is
   begin
      Put_U32 (P, At_Byte, Adaflight.Float_Bits.Float_Bits (V));
   end Put_F32;

   procedure Frame
     (Seq       : in out Unsigned_8;
      Data      : in out Byte_Buffer;
      Length    : in out Natural;
      Id        : Message_Id;
      CRC_Extra : Unsigned_8;
      P         : Payload;
      Max_Len   : Positive)
   is
      Len    : Natural := Max_Len;
      Header : constant array (1 .. 9) of Unsigned_8 :=
        (0, 0, 0, Seq, System_Id, Component_Id, Unsigned_8 (Id mod 256), Unsigned_8 (Id / 256 mod 256),
         Unsigned_8 (Id / 65_536));
      CRC    : MAVLink.CRC_Word := MAVLink.CRC_Init;
   begin
      while Len > 1 and then P (Len - 1) = 0 loop
         pragma Loop_Invariant (Len in 2 .. Max_Len);
         Len := Len - 1;
      end loop;
      if Length > Data'Last - (12 + Len) then
         return;
      end if;
      CRC := MAVLink.Accumulate (CRC, Len);
      for K in 2 .. Header'Last loop
         CRC := MAVLink.Accumulate (CRC, Natural (Header (K)));
      end loop;
      for K in 0 .. Len - 1 loop
         CRC := MAVLink.Accumulate (CRC, Natural (P (K)));
      end loop;
      CRC := MAVLink.Accumulate (CRC, Natural (CRC_Extra));
      Data (Length + 1) := 16#FD#;
      Data (Length + 2) := Unsigned_8 (Len);
      for K in 2 .. Header'Last loop
         Data (Length + 1 + K) := Header (K);
      end loop;
      for K in 0 .. Len - 1 loop
         Data (Length + 11 + K) := P (K);
      end loop;
      Data (Length + 11 + Len) := Unsigned_8 (CRC and 16#FF#);
      Data (Length + 12 + Len) := Unsigned_8 (Interfaces.Shift_Right (CRC, 8));
      Length := Length + 12 + Len;
      Seq := Seq + 1;
   end Frame;

end Adaflight.MAVLink_Frames;
