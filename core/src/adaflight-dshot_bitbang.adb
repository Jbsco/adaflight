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

   procedure Read_Replies
     (T : in out Adaflight.DShot.Telemetry; Counts : in out Adaflight.DShot.Read_Counts;
      Q : in out Adaflight.DShot.Qualities; D : in out Adaflight.DShot.Edge_Decoder; Ports : in out Port_Inputs;
      Used_Ports : Port_Total; Motors : Motor_Pins; Count : Adaflight.DShot.Motor_Total; Use_Telemetry : Boolean;
      Commands : Adaflight.DShot.Command_List; Now_Us : Adaflight.DShot.Time_Us; Now_Ms : Adaflight.DShot.Time_Ms)
   is
      package S renames Adaflight.DShot;
      Raw : Unsigned_32;
   begin
      if not Use_Telemetry then
         return;
      end if;
      for M in 0 .. Count - 1 loop
         if not Ports (Motors (M).Port).Aborted then
            S.Decode_Samples (D, Ports (Motors (M).Port).Buffer, Ports (Motors (M).Port).Count, Motors (M).Pin, Now_Us,
                              Raw);
            if Raw /= S.No_Edge then
               Counts.Reads := Counts.Reads + 1;
               if Raw /= S.Invalid_Value then
                  if Raw = S.Extended_Acknowledge and then Commands (M) = S.Extended_Telemetry_Enable then
                     T.Motors (M).Received := S.State_Events_Bit;
                  else
                     T.Motors (M).Raw := S.Raw_Value (Raw);
                  end if;
               else
                  Counts.Invalids := Counts.Invalids + 1;
               end if;
               S.Count_Packet (Q (M), Raw /= S.Invalid_Value, Now_Ms);
            end if;
         end if;
      end loop;
      T.State := S.Not_Processed;
      for P in 0 .. Used_Ports - 1 loop
         Ports (P).Aborted := False;
         pragma Loop_Invariant (for all K in 0 .. P => not Ports (K).Aborted);
      end loop;
   end Read_Replies;

end Adaflight.DShot_Bitbang;
