package body Adaflight.MSP_Flash_Read with SPARK_Mode is

   function Parse (Payload : Byte_Array) return Request is
      function At_Index (K : Natural) return Unsigned_32 is
        (if K < Payload'Length then Unsigned_32 (Payload (Payload'First + K)) else 0);

      R : Request;
   begin
      R.Address := At_Index (0) + At_Index (1) * 2 ** 8 + At_Index (2) * 2 ** 16 + At_Index (3) * 2 ** 24;
      if Payload'Length >= 6 then
         R.Size := Unsigned_16 (At_Index (4) + At_Index (5) * 2 ** 8);
         R.Legacy := False;
         R.Compress := Payload'Length > 6 and then At_Index (6) /= 0;
      end if;
      return R;
   end Parse;

   function Read_Length (R : Request; Room : Room_Size; Flash_Size : Unsigned_32) return Read_Size is
      Wanted : constant Natural := Natural'Min (Natural (R.Size), Room - Info_Size);
   begin
      if R.Address >= Flash_Size then
         return 0;
      elsif Unsigned_32 (Wanted) > Flash_Size - R.Address then
         return Natural (Flash_Size - R.Address);
      else
         return Wanted;
      end if;
   end Read_Length;

   procedure Start
     (S : out State; R : Request; Room : Room_Size; Flash_Size : Unsigned_32; Reply : in out Byte_Array)
   is
      Length : constant Read_Size := Read_Length (R, Room, Flash_Size);
   begin
      S := (Req => R, Room => Room, Length => Length, Method => Plain, Offset => R.Address, Left => 0, Got => 0,
            Total => 0, Encoder => <>, Coding_On => False, Stopped => False);
      if Length > 0 then
         S.Left := Flash_Size - R.Address;
      end if;
      Reply (0) := Byte (R.Address and 16#FF#);
      Reply (1) := Byte (Interfaces.Shift_Right (R.Address, 8) and 16#FF#);
      Reply (2) := Byte (Interfaces.Shift_Right (R.Address, 16) and 16#FF#);
      Reply (3) := Byte (Interfaces.Shift_Right (R.Address, 24) and 16#FF#);
      if R.Compress and then not R.Legacy then
         S.Method := Huffman_Coded;
         Reply (Coded_At) := 0;
         if Length >= 1 then
            Adaflight.Huffman.Start (S.Encoder, Reply, Coded_At, Length);
            S.Coding_On := True;
         end if;
      end if;
   end Start;

   procedure Feed (S : in out State; Data : Byte_Array; Reply : in out Byte_Array) is
      Count : constant Natural := Data'Length;
   begin
      case S.Method is
         when Plain =>
            declare
               First : constant Natural := (if S.Req.Legacy then Count_At else Plain_At) + S.Got;
            begin
               for K in 0 .. Count - 1 loop
                  Reply (First + K) := Data (Data'First + K);
                  pragma Loop_Invariant (Reply'First = 0);
               end loop;
            end;
            S.Got := S.Got + Count;
            S.Offset := S.Offset + Unsigned_32 (Count);
            S.Stopped := True;
         when Huffman_Coded =>
            declare
               Overflow : Boolean;
            begin
               Adaflight.Huffman.Encode (S.Encoder, Reply, Data, Overflow);
               if Overflow then
                  S.Stopped := True;
               else
                  S.Total := S.Total + Unsigned_16 (Count);
                  S.Offset := S.Offset + Unsigned_32 (Count);
                  S.Left := S.Left - Unsigned_32 (Count);
               end if;
            end;
      end case;
   end Feed;

   procedure Stop (S : in out State) is
   begin
      S.Stopped := True;
   end Stop;

   procedure Finish (S : State; Reply : in out Byte_Array; Length : out Natural) is
      procedure Put_16 (At_Index : Read_Size; V : Unsigned_16)
        with Pre => Reply'First = 0 and then At_Index < Reply'Last, Post => Reply'First = 0
      is
      begin
         Reply (At_Index) := Byte (V and 16#FF#);
         Reply (At_Index + 1) := Byte (Interfaces.Shift_Right (V, 8));
      end Put_16;
   begin
      case S.Method is
         when Plain =>
            if S.Req.Legacy then
               for K in Count_At + S.Got .. Count_At + Legacy_Size - 1 loop
                  Reply (K) := 0;
                  pragma Loop_Invariant (Reply'First = 0);
               end loop;
               Length := Count_At + Legacy_Size;
            else
               Put_16 (Count_At, Unsigned_16 (S.Got));
               Reply (Method_At) := 0;
               Length := Plain_At + S.Got;
            end if;
         when Huffman_Coded =>
            declare
               Written : constant Natural := (if S.Coding_On then Adaflight.Huffman.Length (S.Encoder) else 0);
            begin
               Put_16 (Count_At, Unsigned_16 (2 + Written));
               Reply (Method_At) := 1;
               Put_16 (Plain_At, S.Total);
               Length := Coded_At + Written;
            end;
      end case;
   end Finish;

end Adaflight.MSP_Flash_Read;
