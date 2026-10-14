package body Adaflight.Servo_Rules with SPARK_Mode is

   function R (Target, Input : Unsigned_8; Rate : Integer_8) return Rule is
     (Target => Target, Input => Input, Rate => Rate, Speed => 0, Min => 0, Max => 100, Box => 0);

   Tri_Rules : constant Rule_List := (1 => R (5, 2, 100), others => <>);

   Bicopter_Rules : constant Rule_List :=
     (R (4, 2, 100), R (4, 1, -100), R (5, 2, 100), R (5, 1, 100), others => <>);

   Gimbal_Rules : constant Rule_List := (R (0, 12, 125), R (1, 13, 125), others => <>);

   Flying_Wing_Rules : constant Rule_List :=
     (R (3, 0, 100), R (3, 1, 100), R (4, 0, -100), R (4, 1, 100), R (7, 3, 100), others => <>);

   Airplane_Rules : constant Rule_List :=
     (R (3, 0, 100), R (4, 0, 100), R (5, 2, 100), R (6, 1, 100), R (7, 3, 100), others => <>);

   Heli_Rules : constant Rule_List :=
     (R (0, 1, -50), R (0, 0, -87), R (0, 8, 100), R (1, 1, -50), R (1, 0, 87), R (1, 8, 100), R (2, 1, 100),
      R (2, 8, 100), R (3, 2, 100));

   Dualcopter_Rules : constant Rule_List := (R (4, 1, 100), R (5, 0, 100), others => <>);

   Singlecopter_Rules : constant Rule_List :=
     (R (3, 2, 100), R (3, 1, 100), R (4, 2, 100), R (4, 1, 100), R (5, 2, 100), R (5, 0, 100), R (6, 2, 100),
      R (6, 0, 100), others => <>);

   procedure Mode_Rules
     (O : Mixer_Init.Options; Mode : Mixer_Init.Mixer_Mode; Rules : out Rule_List; Count : out Rule_Count)
   is
      use Mixer_Init;
   begin
      Rules := (others => <>);
      Count := 0;
      case Mode is
         when Tri =>
            Rules := Tri_Rules;
            Count := 1;
         when Gimbal =>
            Rules := Gimbal_Rules;
            Count := 2;
         when Flying_Wing =>
            Rules := Flying_Wing_Rules;
            Count := 5;
         when Airplane =>
            Rules := Airplane_Rules;
            Count := 5;
         when Bicopter =>
            if O.Uncommon then
               Rules := Bicopter_Rules;
               Count := 4;
            end if;
         when Heli_120_CCPM =>
            if O.Uncommon then
               Rules := Heli_Rules;
               Count := 9;
            end if;
         when Dualcopter =>
            if O.Uncommon then
               Rules := Dualcopter_Rules;
               Count := 2;
            end if;
         when Singlecopter =>
            if O.Uncommon then
               Rules := Singlecopter_Rules;
               Count := 8;
            end if;
         when Quad_P | Quad_X | Y6 | Hex6 | Y4 | Hex6X | Octo_X8 | Octo_Flat_P | Octo_Flat_X | Heli_90_Deg | Vtail4
            | Hex6H | PPM_To_Servo | Atail4 | Custom | Custom_Airplane | Custom_Tri | Quad_X_1234 | Octo_X8P =>
            null;
      end case;
   end Mode_Rules;

end Adaflight.Servo_Rules;
