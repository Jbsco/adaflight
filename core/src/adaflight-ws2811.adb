package body Adaflight.WS2811 with SPARK_Mode is

   function Prescaler (Clock : Unsigned_32) return Unsigned_16 is
     (if Timer_Hz > Clock then 0
      else Unsigned_16'Mod ((Clock + Timer_Hz / 2) / Timer_Hz) - 1);

   function Packed (F : Format; Red, Green, Blue : Unsigned_8) return Unsigned_32 is
     (case F is
         when RGB  =>
            Shift_Left (Unsigned_32 (Red), 16) or Shift_Left (Unsigned_32 (Green), 8) or Unsigned_32 (Blue),
         when GRBW =>
            Shift_Left (Unsigned_32 (Green), 24) or Shift_Left (Unsigned_32 (Red), 16)
            or Shift_Left (Unsigned_32 (Blue), 8) or Unsigned_32 (Unsigned_8'Min (Unsigned_8'Min (Red, Green), Blue)),
         when GRB  =>
            Shift_Left (Unsigned_32 (Green), 16) or Shift_Left (Unsigned_32 (Red), 8) or Unsigned_32 (Blue));

end Adaflight.WS2811;
