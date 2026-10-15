with Adaflight.MSP_Write_Plans; use Adaflight.MSP_Write_Plans;

package body Adaflight.MSP_Font_In with SPARK_Mode is

   --  The request's byte at an offset, zero past its end.
   function Byte_At (Request : Byte_Array; Offset : Natural) return Byte is
     (if Offset < Request'Length then Request (Request'First + Offset) else 0)
     with Pre => Request'Length <= Max_Request;

   procedure Process (Request : Byte_Array; Port_Present : Boolean; R : out Result; E : out Effects) is
      Length : constant Natural := Request'Length;
      Offset : Natural range 1 .. 2;
   begin
      E := No_Effects;
      if Length >= Character_Bytes + 2 then
         E.Address := Interfaces.Unsigned_16 (U16 (Request, 0));
         E.Size := Character_Bytes;
         Offset := 2;
      elsif Length = Character_Bytes + 1 then
         E.Address := Interfaces.Unsigned_16 (U8 (Request, 0));
         E.Size := Character_Bytes;
         Offset := 1;
      elsif Length >= Visible_Bytes + 2 then
         E.Address := Interfaces.Unsigned_16 (U16 (Request, 0));
         E.Size := Visible_Bytes;
         Offset := 2;
      else
         E.Address := Interfaces.Unsigned_16 (U8 (Request, 0));
         E.Size := Visible_Bytes;
         Offset := 1;
      end if;
      for I in 0 .. E.Size - 1 loop
         E.Data (I) := Byte_At (Request, Offset + I);
      end loop;
      if not Port_Present then
         E := No_Effects;
         R := Error;
         return;
      end if;
      E.Write := True;
      R := Ack;
   end Process;

end Adaflight.MSP_Font_In;
