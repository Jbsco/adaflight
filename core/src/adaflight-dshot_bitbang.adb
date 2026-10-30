package body Adaflight.DShot_Bitbang with SPARK_Mode is

   procedure Init (B : in out Port_Buffer; Port_Mask : Unsigned_16; Inverted : Boolean) is
      Mask      : constant Unsigned_32 := Unsigned_32 (Port_Mask);
      Reset_Bit : constant Unsigned_32 := (if Inverted then Mask else Shift_Left (Mask, 16));
      Set_Bit   : constant Unsigned_32 := (if Inverted then Shift_Left (Mask, 16) else Mask);
      Hold      : constant := Frame_Bits * States_Per_Bit;
   begin
      for S in 0 .. Frame_Bits - 1 loop
         B (S * States_Per_Bit) := B (S * States_Per_Bit) or Set_Bit;
         B (S * States_Per_Bit + 1) := 0;
         B (S * States_Per_Bit + 2) := B (S * States_Per_Bit + 2) or Reset_Bit;
      end loop;
      B (Hold) := B (Hold) or Reset_Bit;
      B (Hold + 1) := 0;
      B (Hold + 2) := 0;
   end Init;

   procedure Set (B : in out Port_Buffer; Pin : Pin_Number; Value : Unsigned_16; Inverted : Boolean) is
      Middle : constant Unsigned_32 := Shift_Left (1, (if Inverted then Pin else Pin + 16));
      V      : Unsigned_16 := Value;
   begin
      for Pos in 0 .. Frame_Bits - 1 loop
         if (V and 16#8000#) = 0 then
            B (Pos * States_Per_Bit + 1) := B (Pos * States_Per_Bit + 1) or Middle;
         end if;
         V := Shift_Left (V, 1);
      end loop;
   end Set;

   procedure Clear (B : in out Port_Buffer) is
   begin
      for Pos in 0 .. Frame_Bits - 1 loop
         B (Pos * States_Per_Bit + 1) := 0;
      end loop;
   end Clear;

end Adaflight.DShot_Bitbang;
