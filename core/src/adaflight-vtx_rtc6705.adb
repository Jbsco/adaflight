package body Adaflight.VTX_RTC6705 with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   Write_Bit          : constant := 16;
   PA_Control_Default : constant := 16#4FBD#;
   PA_Control_Low     : constant := 16#407D#;

   procedure Add (Ops : in out Operations; Op : Operation)
     with Global => null
   is
   begin
      if Ops.Count < Max_Operations then
         Ops.Count := Ops.Count + 1;
         Ops.List (Ops.Count) := Op;
      end if;
   end Add;

   procedure Write (D : in out Driver; Address : Unsigned_8; Value : Unsigned_32)
     with Global => null,
          Pre    => Address < Write_Bit
   is
   begin
      Add (D.Pending, (Kind => Write_Register, Address => Address + Write_Bit, Value => Value));
   end Write;

   procedure Start (Ops : out Operations) is
   begin
      Ops := No_Operations;
      Add (Ops, (Kind => Power_Off, Address => 0, Value => 0));
   end Start;

   --  The power amplifier register for a power value cut to its low byte and
   --  held from one to two.
   procedure Write_Power (D : in out Driver; Power : Unsigned_16)
     with Global => null
   is
      Level : constant Unsigned_8 := Unsigned_8'Max (1, Unsigned_8'Min (2, Unsigned_8'Mod (Power)));
   begin
      Write (D, 7, (if Level > 1 then PA_Control_Default else PA_Control_Low));
   end Write_Power;

   --  The reference divider of 400, then the divider of the frequency in
   --  steps of 40 kHz, its multiple of 64 above the remainder.
   procedure Write_Frequency (D : in out Driver; Freq : Unsigned_16)
     with Global => null
   is
      Steps : constant Unsigned_32 := Unsigned_32 (Freq) * 1000 / 40;
   begin
      Write (D, 0, 400);
      Write (D, 1, Interfaces.Shift_Left (Steps / 64, 7) or Steps mod 64);
   end Write_Frequency;

   procedure Set_Frequency (D : in out Driver; Freq : Unsigned_16) is
   begin
      if Freq in Freq_Min .. Freq_Max then
         D.Frequency := Freq;
         Write_Frequency (D, Freq);
      end if;
   end Set_Frequency;

   procedure Set_Power_Index (D : in out Driver; T : VTX_Table.Table; Index : Unsigned_8) is
   begin
      if VTX_Table.Has_Power_Value (T, Natural (Index)) then
         D.Power_Index := Index;
         Write_Power (D, VTX_Table.Power_Value_Of (T, Natural (Index)));
      end if;
   end Set_Power_Index;

   procedure Set_Pit_Mode (D : in out Driver; T : VTX_Table.Table; On : Boolean) is
   begin
      if On then
         if not D.Pit_Active then
            D.Pit_Active := True;
            Add (D.Pending, (Kind => Power_Off, Address => 0, Value => 0));
         end if;
      elsif D.Pit_Active then
         D.Pit_Active := False;
         Add (D.Pending, (Kind => Power_On, Address => 0, Value => 0));
         Add (D.Pending, (Kind => Wait, Address => 0, Value => Boot_Delay_Ms));
         Write_Power
           (D, (if VTX_Table.Has_Power_Value (T, Natural (D.Power_Index))
                then VTX_Table.Power_Value_Of (T, Natural (D.Power_Index)) else 0));
         if D.Frequency in Freq_Min .. Freq_Max then
            Write_Frequency (D, D.Frequency);
         end if;
      end if;
   end Set_Pit_Mode;

end Adaflight.VTX_RTC6705;
