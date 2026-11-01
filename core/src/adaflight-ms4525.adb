package body Adaflight.MS4525 with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   Out_Min       : constant Float := 1638.3;
   Out_Span      : constant Float := 13106.4;
   Psi_Range     : constant Float := 2.0;
   Psi_Min       : constant Float := -1.0;
   Pascal_Per_Psi : constant Float := 6894.757;

   procedure Decode (F : Frame; Valid : out Boolean; Pressure : out Pressure_Pa; Temperature : out Kelvin) is
      Status          : constant Interfaces.Unsigned_8 := Interfaces.Shift_Right (F (0), 6);
      Pressure_Raw    : constant Natural := Natural (F (0) and 16#3F#) * 256 + Natural (F (1));
      Temperature_Raw : constant Natural := Natural (F (2)) * 8 + Natural (Interfaces.Shift_Right (F (3), 5));
      Psi             : Float;
   begin
      Pressure := 0.0;
      Temperature := 273.15;
      Valid := Status /= 2 and then Status /= 3;
      if not Valid then
         return;
      end if;
      Psi := (Float (Pressure_Raw) - Out_Min) / Out_Span * Psi_Range + Psi_Min;
      Pressure := Psi * Pascal_Per_Psi;
      Temperature := Float (Temperature_Raw) * (200.0 / 2047.0) - 50.0 + 273.15;
   end Decode;

end Adaflight.MS4525;
