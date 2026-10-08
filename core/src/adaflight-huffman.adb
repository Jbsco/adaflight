with Adaflight.Huffman_Table; use Adaflight.Huffman_Table;

package body Adaflight.Huffman with SPARK_Mode is

   ------------
   -- Start --
   ------------

   procedure Start
     (E : out Encoder; Output : in out Byte_Array; Base : Buffer_Index; Out_Buf_Len : Buffer_Index)
   is
   begin
      Output (Base) := 0;
      E := (Base => Base, Position => Base, Bytes_Written => 0,
            Out_Buf_Len => Out_Buf_Len, Out_Bit => 16#80#);
   end Start;

   ------------
   -- Encode --
   ------------

   procedure Encode
     (E : in out Encoder; Output : in out Byte_Array; Input : Byte_Array; Overflow : out Boolean)
   is
      Saved_Position : constant Buffer_Index := E.Position;
      Saved_Byte     : constant Byte := Output (E.Position);
   begin
      Overflow := False;
      for P in Input'Range loop
         pragma Loop_Invariant (E.Base = E.Base'Loop_Entry
                                and then E.Out_Buf_Len = E.Out_Buf_Len'Loop_Entry
                                and then E.Bytes_Written < E.Out_Buf_Len);
         declare
            Entry_Code : constant Huffman_Code := Code_Of (Natural (Input (P)));
            Code       : constant Unsigned_16 := Interfaces.Shift_Left (Entry_Code.Code, 4);
            Test_Bit   : Unsigned_16 := 16#8000#;
         begin
            for J in 1 .. Entry_Code.Len loop
               pragma Loop_Invariant (E.Base = E.Base'Loop_Entry
                                      and then E.Out_Buf_Len = E.Out_Buf_Len'Loop_Entry
                                      and then E.Bytes_Written < E.Out_Buf_Len);
               if (Code and Test_Bit) /= 0 then
                  Output (E.Position) := Output (E.Position) or E.Out_Bit;
               end if;
               Test_Bit := Interfaces.Shift_Right (Test_Bit, 1);
               if E.Out_Bit = 1 then
                  E := (Base          => E.Base,
                        Position      => E.Position + 1,
                        Bytes_Written => E.Bytes_Written + 1,
                        Out_Buf_Len   => E.Out_Buf_Len,
                        Out_Bit       => 16#80#);
                  if E.Position <= Output'Last then
                     Output (E.Position) := 0;
                  end if;
               else
                  E.Out_Bit := Interfaces.Shift_Right (E.Out_Bit, 1);
               end if;
               if E.Bytes_Written >= E.Out_Buf_Len
                 and then (P < Input'Last or else J < Entry_Code.Len)
               then
                  Output (Saved_Position) := Saved_Byte;
                  Overflow := True;
                  return;
               end if;
            end loop;
         end;
      end loop;
   end Encode;

end Adaflight.Huffman;
