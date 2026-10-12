package body Adaflight.Transponder with SPARK_Mode is

   Arcitimer_Bytes      : constant := 9;
   Arcitimer_Toggles    : constant := 4;
   Arcitimer_Buffer     : constant := 155 * Arcitimer_Toggles;
   ILAP_Bytes           : constant := 6;
   ILAP_Bits            : constant := 10;
   ILAP_Toggles         : constant := 11;
   ILAP_Buffer          : constant := (ILAP_Toggles + 1) * ILAP_Bits * ILAP_Bytes;
   ERLT_One_Cycles      : constant := 25;
   ERLT_Zero_Cycles     : constant := 10;

   type Jitter_Table is array (0 .. 14) of Unsigned_32;
   Jitter_Steps : constant Jitter_Table := (0, 9, 4, 8, 3, 9, 6, 7, 1, 6, 9, 7, 8, 2, 6);

   function Delay_Us (P : Provider) return Unsigned_32 is
     (case P is when ILAP => 4500, when Arcitimer => 4500, when ERLT => 22500, when None => 0);

   function Jitter_Us (P : Provider) return Unsigned_32 is
     (case P is when ILAP => 10000, when Arcitimer => 10000, when ERLT => 5000, when None => 0);

   --  Each bit low first as four toggles, the ones at the toggle value.
   procedure Encode_Arcitimer (Data : Code; Toggle : Unsigned_16; Result : in out Pattern) is
      Pos : Natural := 0;
   begin
      for B in 0 .. Arcitimer_Bytes - 1 loop
         for Bit in 0 .. 7 loop
            pragma Loop_Invariant (Pos = (B * 8 + Bit) * Arcitimer_Toggles);
            for T in 0 .. Arcitimer_Toggles - 1 loop
               Result.Buffer (Pos + T) :=
                 (if (Data (B) and Interfaces.Shift_Left (1, Bit)) /= 0 then Unsigned_32 (Toggle) else 0);
            end loop;
            Pos := Pos + Arcitimer_Toggles;
         end loop;
      end loop;
      Result.Length := Arcitimer_Buffer;
   end Encode_Arcitimer;

   --  Each byte as a start bit of toggles, its eight bits low first and a
   --  silent stop bit, eleven toggles and a gap per bit.
   procedure Encode_ILAP (Data : Code; Toggle : Unsigned_16; Result : in out Pattern) is
      Pos : Natural := 0;
   begin
      for B in 0 .. ILAP_Bytes - 1 loop
         for Bit in 0 .. ILAP_Bits - 1 loop
            pragma Loop_Invariant (Pos = (B * ILAP_Bits + Bit) * (ILAP_Toggles + 1));
            declare
               Pulsed : constant Boolean :=
                 (if Bit = 0 then True
                  elsif Bit = ILAP_Bits - 1 then False
                  else (Data (B) and Interfaces.Shift_Left (1, Bit - 1)) /= 0);
            begin
               for T in 0 .. ILAP_Toggles - 1 loop
                  Result.Buffer (Pos + T) := (if Pulsed then Unsigned_32 (Toggle) else 0);
               end loop;
               Result.Buffer (Pos + ILAP_Toggles) := 0;
               Pos := Pos + ILAP_Toggles + 1;
            end;
         end loop;
      end loop;
      Result.Length := ILAP_Buffer;
   end Encode_ILAP;

   --  The inverted code's six low bits high first between two start bits
   --  and a parity bit, a one as twenty-five cycles and a zero as ten,
   --  pulsed on the odd bits; the pulse value passes through a byte, as
   --  the reference narrows it (finding F84).
   procedure Encode_ERLT (Data : Code; Toggle : Unsigned_16; Result : in out Pattern) is
      Pulse  : constant Unsigned_32 := Unsigned_32 (Toggle and 16#FF#);
      Value  : constant Unsigned_8 := not Data (0);
      Pos    : Natural := 0;
      Parity : Natural := 0;

      procedure Add (Cycles : Natural; Width : Unsigned_32)
        with Pre => Cycles <= ERLT_One_Cycles and then Pos <= Max_Toggles - ERLT_One_Cycles - 1,
             Post => Pos = Pos'Old + Cycles
      is
      begin
         for I in 0 .. Cycles - 1 loop
            Result.Buffer (Pos + I) := Width;
         end loop;
         Pos := Pos + Cycles;
      end Add;
   begin
      Add (ERLT_Zero_Cycles, Pulse);
      Add (ERLT_Zero_Cycles, 0);
      for I in reverse 0 .. 5 loop
         pragma Loop_Invariant (Pos <= 20 + (5 - I) * ERLT_One_Cycles and then Parity <= 5 - I);
         declare
            Bit : constant Boolean := (Interfaces.Shift_Right (Value, I) and 1) /= 0;
         begin
            if Bit then
               Parity := Parity + 1;
            end if;
            Add ((if Bit then ERLT_One_Cycles else ERLT_Zero_Cycles), (if I mod 2 = 1 then Pulse else 0));
         end;
      end loop;
      Add ((if Parity mod 2 = 1 then ERLT_One_Cycles else ERLT_Zero_Cycles), Pulse);
      Result.Buffer (Pos) := 0;
      Result.Length := Pos + 1;
   end Encode_ERLT;

   ------------
   -- Encode --
   ------------

   procedure Encode (P : Provider; Data : Code; Toggle : Unsigned_16; Result : out Pattern) is
   begin
      Result := (others => <>);
      case P is
         when None => null;
         when ILAP => Encode_ILAP (Data, Toggle, Result);
         when Arcitimer => Encode_Arcitimer (Data, Toggle, Result);
         when ERLT => Encode_ERLT (Data, Toggle, Result);
      end case;
   end Encode;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Schedule; P : Provider; Now_Us : Unsigned_32; Ready : Boolean;
                     Transmit : out Boolean) is
      Elapsed : constant Unsigned_32 := Now_Us - S.Next_Update_Us;
   begin
      Transmit := False;
      if not Ready or else Elapsed >= 2 ** 31 or else P = None then
         return;
      end if;
      S.Next_Update_Us := Now_Us + Delay_Us (P) + (Jitter_Us (P) / 10) * Jitter_Steps (S.Jitter_Index);
      S.Jitter_Index := (if S.Jitter_Index = 14 then 0 else S.Jitter_Index + 1);
      Transmit := True;
   end Update;

end Adaflight.Transponder;
