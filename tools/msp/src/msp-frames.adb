package body MSP.Frames with SPARK_Mode is

   Dollar  : constant Byte := Character'Pos ('$');
   Letter_M : constant Byte := Character'Pos ('M');
   Letter_X : constant Byte := Character'Pos ('X');
   To_FC   : constant Byte := Character'Pos ('<');
   From_FC : constant Byte := Character'Pos ('>');
   Error   : constant Byte := Character'Pos ('!');

   function CRC8 (CRC : Byte; Data : Byte) return Byte is
      C : Byte := CRC xor Data;
   begin
      for I in 1 .. 8 loop
         if (C and 16#80#) /= 0 then
            C := Interfaces.Shift_Left (C, 1) xor 16#D5#;
         else
            C := Interfaces.Shift_Left (C, 1);
         end if;
      end loop;
      return C;
   end CRC8;

   procedure Encode (Code : Command; Payload : Byte_Array; Frame : out Byte_Array; Last : out Natural) is
      N     : constant Payload_Length := Payload'Length;
      Check : Byte;
   begin
      Frame := (others => 0);
      Frame (0) := Dollar;
      Frame (2) := To_FC;
      if Is_V1 (Code, N) then
         Frame (1) := Letter_M;
         Frame (3) := Byte (N);
         Frame (4) := Byte (Code);
         Check := Byte (N) xor Byte (Code);
         for I in 0 .. N - 1 loop
            Frame (5 + I) := Payload (Payload'First + I);
            Check := Check xor Payload (Payload'First + I);
         end loop;
         Frame (5 + N) := Check;
         Last := 5 + N;
      else
         Frame (1) := Letter_X;
         Frame (4) := Byte (Code mod 256);
         Frame (5) := Byte (Code / 256);
         Frame (6) := Byte (N mod 256);
         Frame (7) := Byte (N / 256);
         Check := 0;
         for I in 3 .. 7 loop
            Check := CRC8 (Check, Frame (I));
         end loop;
         for I in 0 .. N - 1 loop
            Frame (8 + I) := Payload (Payload'First + I);
            Check := CRC8 (Check, Payload (Payload'First + I));
         end loop;
         Frame (8 + N) := Check;
         Last := 8 + N;
      end if;
   end Encode;

   procedure Reset (D : out Decoder) is
   begin
      D := (others => <>);
   end Reset;

   --  The state after a byte that fits no frame at this point: a new frame's start, or idle.
   function Resync (B : Byte) return State
   is (if B = Dollar then Proto else Idle);

   procedure Feed (D : in out Decoder; B : Byte; Result : out Step) is
      Announced : Natural range 0 .. 65_535;
   begin
      Result := Pending;
      case D.Current is
         when Idle =>
            D.Current := Resync (B);

         when Proto =>
            if B = Letter_M then
               D.V2 := False;
               D.Current := Direction;
            elsif B = Letter_X then
               D.V2 := True;
               D.Current := Direction;
            else
               D.Current := Resync (B);
            end if;

         when Direction =>
            if B = From_FC or else B = Error then
               D.Is_Error := B = Error;
               D.Check := 0;
               D.Current := (if D.V2 then V2_Flag else V1_Size);
            else
               D.Current := Resync (B);
            end if;

         when V1_Size =>
            D.Check := B;
            D.Wide := B = 255;
            D.Size := (if B = 255 then 0 else Natural (B));
            D.Current := V1_Code;

         when V1_Code =>
            D.Command := Natural (B);
            D.Check := D.Check xor B;
            D.Count := 0;
            D.Current := (if D.Wide then V1_Size_Low elsif D.Size = 0 then V1_Check else V1_Payload);

         when V1_Size_Low | V2_Size_Low =>
            D.Low := B;
            D.Check := (if D.V2 then CRC8 (D.Check, B) else D.Check xor B);
            D.Current := (if D.V2 then V2_Size_High else V1_Size_High);

         when V1_Size_High | V2_Size_High =>
            D.Check := (if D.V2 then CRC8 (D.Check, B) else D.Check xor B);
            Announced := Natural (D.Low) + 256 * Natural (B);
            D.Count := 0;
            if Announced > Max_Payload then
               D.Left := Announced + 1;
               D.Current := Skipping;
            else
               D.Size := Announced;
               if Announced = 0 then
                  D.Current := (if D.V2 then V2_Check else V1_Check);
               else
                  D.Current := (if D.V2 then V2_Payload else V1_Payload);
               end if;
            end if;

         when V1_Payload | V2_Payload =>
            if D.Count < D.Size then
               D.Count := D.Count + 1;
               D.Data (D.Count) := B;
            end if;
            D.Check := (if D.V2 then CRC8 (D.Check, B) else D.Check xor B);
            if D.Count >= D.Size then
               D.Current := (if D.V2 then V2_Check else V1_Check);
            end if;

         when V1_Check | V2_Check =>
            D.Current := Idle;
            Result := (if B = D.Check then Complete else Bad_Checksum);

         when V2_Flag =>
            D.Check := CRC8 (0, B);
            D.Current := V2_Code_Low;

         when V2_Code_Low =>
            D.Low := B;
            D.Check := CRC8 (D.Check, B);
            D.Current := V2_Code_High;

         when V2_Code_High =>
            D.Command := Natural (D.Low) + 256 * Natural (B);
            D.Check := CRC8 (D.Check, B);
            D.Current := V2_Size_Low;

         when Skipping =>
            if D.Left > 1 then
               D.Left := D.Left - 1;
            else
               D.Left := 0;
               D.Current := Idle;
               Result := Too_Long;
            end if;
      end case;
   end Feed;

end MSP.Frames;
