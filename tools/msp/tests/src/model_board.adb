with Interfaces;

package body Model_Board is

   use type MSP.Byte;

   Queue_Size : constant := 2 ** 17;

   Current : Settings;
   Queue   : array (0 .. Queue_Size - 1) of MSP.Byte := (others => 0);
   Head    : Natural := 0;
   Tail    : Natural := 0;

   Good     : Natural := 0;
   Bad      : Natural := 0;
   Code_Was : Natural := 0;
   Size_Was : Natural := 0;
   V2_Was   : Boolean := False;
   Empties  : Natural := 0;

   function CRC8 (CRC : MSP.Byte; Data : MSP.Byte) return MSP.Byte is
      C : MSP.Byte := CRC xor Data;
   begin
      for I in 1 .. 8 loop
         C := (if (C and 16#80#) /= 0 then Interfaces.Shift_Left (C, 1) xor 16#D5# else Interfaces.Shift_Left (C, 1));
      end loop;
      return C;
   end CRC8;

   procedure Push (B : MSP.Byte) is
   begin
      Queue (Tail) := B;
      Tail := Tail + 1;
   end Push;

   procedure Push (Text : String) is
   begin
      for C of Text loop
         Push (MSP.Byte (Character'Pos (C)));
      end loop;
   end Push;

   procedure Configure (S : Settings) is
   begin
      Current := S;
      Head := 0;
      Tail := 0;
      Good := 0;
      Bad := 0;
      Code_Was := 0;
      Size_Was := 0;
      V2_Was := False;
      Empties := 0;
   end Configure;

   function Reply_Byte (Code : Natural; Request : MSP.Byte_Array; I : Positive) return MSP.Byte is
      From_Request : constant MSP.Byte :=
        (if Request'Length = 0 then 0 else Request (Request'First + (I - 1) mod Request'Length));
   begin
      return MSP.Byte ((Code + 7 * I) mod 256) xor From_Request;
   end Reply_Byte;

   --  A reply frame in the request's protocol version, or the first version's long form.
   procedure Push_Reply
     (Code : Natural; Request : MSP.Byte_Array; V2 : Boolean; Refused : Boolean; Length : Natural; Spoil : Boolean)
   is
      Check : MSP.Byte;
      procedure Add (B : MSP.Byte) is
      begin
         Push (B);
         Check := (if V2 then CRC8 (Check, B) else Check xor B);
      end Add;
   begin
      Push ((if V2 then "$X" else "$M") & (if Refused then "!" else ">"));
      Check := 0;
      if V2 then
         Add (0);
         Add (MSP.Byte (Code mod 256));
         Add (MSP.Byte (Code / 256));
         Add (MSP.Byte (Length mod 256));
         Add (MSP.Byte (Length / 256));
      elsif Current.Jumbo or else Length >= 255 then
         Add (255);
         Add (MSP.Byte (Code mod 256));
         Add (MSP.Byte (Length mod 256));
         Add (MSP.Byte (Length / 256));
      else
         Add (MSP.Byte (Length));
         Add (MSP.Byte (Code mod 256));
      end if;
      for I in 1 .. Length loop
         Add (Reply_Byte (Code, Request, I));
      end loop;
      Push ((if Spoil then Check xor 16#5A# else Check));
   end Push_Reply;

   procedure Answer (Code : Natural; Request : MSP.Byte_Array; V2 : Boolean) is
   begin
      Good := Good + 1;
      Code_Was := Code;
      Size_Was := Request'Length;
      V2_Was := V2;
      if Current.Silent then
         return;
      end if;
      if Current.Noise_First then
         Push ("noise $ $M $X< $M<");
         Push (0);
         Push (255);
      end if;
      if Current.Long_First then
         --  A frame that announces a payload of 9000 bytes, past what the client keeps.
         Push ("$X>");
         Push (0);
         Push (MSP.Byte (Code mod 256));
         Push (MSP.Byte (Code / 256));
         Push (MSP.Byte (9000 mod 256));
         Push (MSP.Byte (9000 / 256));
         for I in 1 .. 9001 loop
            Push (MSP.Byte (I mod 251));
         end loop;
      end if;
      if Current.Corrupt_First then
         Push_Reply (Code, Request, V2, False, Current.Reply_Length, Spoil => True);
      end if;
      if Current.Other_First then
         Push_Reply ((Code + 1) mod 255, Request, False, False, 3, Spoil => False);
      end if;
      Push_Reply
        (Code, Request, V2, Current.Refuse, (if Current.Refuse then 0 else Current.Reply_Length), Spoil => False);
   end Answer;

   function Is_Present return Boolean
   is (Current.Present);

   procedure Take (Data : MSP.Byte_Array; Ok : out Boolean) is
      F : constant Natural := Data'First;
      N : constant Natural := Data'Length;
      Check : MSP.Byte := 0;
   begin
      Ok := Current.Accept_Sends;
      if not Ok then
         return;
      end if;
      if N >= 6 and then Data (F) = Character'Pos ('$') and then Data (F + 1) = Character'Pos ('M')
        and then Data (F + 2) = Character'Pos ('<') and then N = 6 + Natural (Data (F + 3))
      then
         for I in F + 3 .. Data'Last - 1 loop
            Check := Check xor Data (I);
         end loop;
         if Check = Data (Data'Last) then
            Answer (Natural (Data (F + 4)), Data (F + 5 .. Data'Last - 1), V2 => False);
            return;
         end if;
      elsif N >= 9 and then Data (F) = Character'Pos ('$') and then Data (F + 1) = Character'Pos ('X')
        and then Data (F + 2) = Character'Pos ('<')
        and then N = 9 + Natural (Data (F + 6)) + 256 * Natural (Data (F + 7))
      then
         for I in F + 3 .. Data'Last - 1 loop
            Check := CRC8 (Check, Data (I));
         end loop;
         if Check = Data (Data'Last) then
            Answer (Natural (Data (F + 4)) + 256 * Natural (Data (F + 5)), Data (F + 8 .. Data'Last - 1), V2 => True);
            return;
         end if;
      end if;
      Bad := Bad + 1;
   end Take;

   procedure Give (Data : out MSP.Byte_Array; Got : out Natural) is
      Room : constant Natural := Natural'Min (Data'Length, Current.Chunk);
   begin
      Data := (others => 0);
      Got := Natural'Min (Room, Tail - Head);
      if Got = 0 then
         Empties := Empties + 1;
      end if;
      for I in 0 .. Got - 1 loop
         Data (Data'First + I) := Queue (Head + I);
      end loop;
      Head := Head + Got;
   end Give;

   function Good_Requests return Natural
   is (Good);
   function Bad_Requests return Natural
   is (Bad);
   function Last_Code return Natural
   is (Code_Was);
   function Last_Length return Natural
   is (Size_Was);
   function Last_Was_V2 return Boolean
   is (V2_Was);
   function Empty_Reads return Natural
   is (Empties);

end Model_Board;
