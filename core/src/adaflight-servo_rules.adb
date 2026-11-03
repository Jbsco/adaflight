package body Adaflight.Servo_Rules with SPARK_Mode is

   Tri_Rules : constant Rule_List := (1 => (5, 2, 100, 0, 0, 100, 0), others => (0, 0, 0, 0, 0, 0, 0));

   Bicopter_Rules : constant Rule_List :=
     ((4, 2, 100, 0, 0, 100, 0), (4, 1, -100, 0, 0, 100, 0), (5, 2, 100, 0, 0, 100, 0), (5, 1, 100, 0, 0, 100, 0),
      others => (0, 0, 0, 0, 0, 0, 0));

   Gimbal_Rules : constant Rule_List :=
     ((0, 12, 125, 0, 0, 100, 0), (1, 13, 125, 0, 0, 100, 0), others => (0, 0, 0, 0, 0, 0, 0));

   Flying_Wing_Rules : constant Rule_List :=
     ((3, 0, 100, 0, 0, 100, 0), (3, 1, 100, 0, 0, 100, 0), (4, 0, -100, 0, 0, 100, 0), (4, 1, 100, 0, 0, 100, 0),
      (7, 3, 100, 0, 0, 100, 0), others => (0, 0, 0, 0, 0, 0, 0));

   Airplane_Rules : constant Rule_List :=
     ((3, 0, 100, 0, 0, 100, 0), (4, 0, 100, 0, 0, 100, 0), (5, 2, 100, 0, 0, 100, 0), (6, 1, 100, 0, 0, 100, 0),
      (7, 3, 100, 0, 0, 100, 0), others => (0, 0, 0, 0, 0, 0, 0));

   Heli_Rules : constant Rule_List :=
     ((0, 1, -50, 0, 0, 100, 0), (0, 0, -87, 0, 0, 100, 0), (0, 8, 100, 0, 0, 100, 0), (1, 1, -50, 0, 0, 100, 0),
      (1, 0, 87, 0, 0, 100, 0), (1, 8, 100, 0, 0, 100, 0), (2, 1, 100, 0, 0, 100, 0), (2, 8, 100, 0, 0, 100, 0),
      (3, 2, 100, 0, 0, 100, 0));

   Dualcopter_Rules : constant Rule_List :=
     ((4, 1, 100, 0, 0, 100, 0), (5, 0, 100, 0, 0, 100, 0), others => (0, 0, 0, 0, 0, 0, 0));

   Singlecopter_Rules : constant Rule_List :=
     ((3, 2, 100, 0, 0, 100, 0), (3, 1, 100, 0, 0, 100, 0), (4, 2, 100, 0, 0, 100, 0), (4, 1, 100, 0, 0, 100, 0),
      (5, 2, 100, 0, 0, 100, 0), (5, 0, 100, 0, 0, 100, 0), (6, 2, 100, 0, 0, 100, 0), (6, 0, 100, 0, 0, 100, 0),
      others => (0, 0, 0, 0, 0, 0, 0));

   procedure Mode_Rules
     (O : Mixer_Init.Options; Mode : Mixer_Init.Mixer_Mode; Rules : out Rule_List; Count : out Rule_Count)
   is
      use Mixer_Init;
   begin
      Rules := (others => (0, 0, 0, 0, 0, 0, 0));
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
