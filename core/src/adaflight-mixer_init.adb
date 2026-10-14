package body Adaflight.Mixer_Init with SPARK_Mode is

   subtype Motor_Index is Adaflight.Mixer.Motor_Index;

   Quad_X_Table : constant Mix_Table :=
     (0 => (1.0, -1.0, 1.0, -1.0), 1 => (1.0, -1.0, -1.0, 1.0), 2 => (1.0, 1.0, 1.0, 1.0),
      3 => (1.0, 1.0, -1.0, -1.0), others => <>);
   Tri_Table : constant Mix_Table :=
     (0 => (1.0, 0.0, 1.333333, 0.0), 1 => (1.0, -1.0, -0.666667, 0.0), 2 => (1.0, 1.0, -0.666667, 0.0),
      others => <>);
   Quad_P_Table : constant Mix_Table :=
     (0 => (1.0, 0.0, 1.0, -1.0), 1 => (1.0, -1.0, 0.0, 1.0), 2 => (1.0, 1.0, 0.0, 1.0), 3 => (1.0, 0.0, -1.0, -1.0),
      others => <>);
   Bicopter_Table : constant Mix_Table := (0 => (1.0, 1.0, 0.0, 0.0), 1 => (1.0, -1.0, 0.0, 0.0), others => <>);
   Y4_Table : constant Mix_Table :=
     (0 => (1.0, 0.0, 1.0, -1.0), 1 => (1.0, -1.0, -1.0, 0.0), 2 => (1.0, 0.0, 1.0, 1.0), 3 => (1.0, 1.0, -1.0, 0.0),
      others => <>);
   Hex6X_Table : constant Mix_Table :=
     (0 => (1.0, -0.5, 0.866025, 1.0), 1 => (1.0, -0.5, -0.866025, 1.0), 2 => (1.0, 0.5, 0.866025, -1.0),
      3 => (1.0, 0.5, -0.866025, -1.0), 4 => (1.0, -1.0, 0.0, -1.0), 5 => (1.0, 1.0, 0.0, 1.0), others => <>);
   Hex6H_Table : constant Mix_Table :=
     (0 => (1.0, -1.0, 1.0, -1.0), 1 => (1.0, -1.0, -1.0, 1.0), 2 => (1.0, 1.0, 1.0, 1.0),
      3 => (1.0, 1.0, -1.0, -1.0), 4 => (1.0, 0.0, 0.0, 0.0), 5 => (1.0, 0.0, 0.0, 0.0), others => <>);
   Hex6P_Table : constant Mix_Table :=
     (0 => (1.0, -0.866025, 0.5, 1.0), 1 => (1.0, -0.866025, -0.5, -1.0), 2 => (1.0, 0.866025, 0.5, 1.0),
      3 => (1.0, 0.866025, -0.5, -1.0), 4 => (1.0, 0.0, -1.0, 1.0), 5 => (1.0, 0.0, 1.0, -1.0), others => <>);
   Y6_Table : constant Mix_Table :=
     (0 => (1.0, 0.0, 1.333333, 1.0), 1 => (1.0, -1.0, -0.666667, -1.0), 2 => (1.0, 1.0, -0.666667, -1.0),
      3 => (1.0, 0.0, 1.333333, -1.0), 4 => (1.0, -1.0, -0.666667, 1.0), 5 => (1.0, 1.0, -0.666667, 1.0),
      others => <>);
   Octo_X8_Table : constant Mix_Table :=
     (0 => (1.0, -1.0, 1.0, -1.0), 1 => (1.0, -1.0, -1.0, 1.0), 2 => (1.0, 1.0, 1.0, 1.0),
      3 => (1.0, 1.0, -1.0, -1.0), 4 => (1.0, -1.0, 1.0, 1.0), 5 => (1.0, -1.0, -1.0, -1.0),
      6 => (1.0, 1.0, 1.0, -1.0), 7 => (1.0, 1.0, -1.0, 1.0));
   Octo_X8P_Table : constant Mix_Table :=
     (0 => (1.0, 0.0, 1.0, -1.0), 1 => (1.0, -1.0, 0.0, 1.0), 2 => (1.0, 1.0, 0.0, 1.0), 3 => (1.0, 0.0, -1.0, -1.0),
      4 => (1.0, 0.0, 1.0, 1.0), 5 => (1.0, -1.0, 0.0, -1.0), 6 => (1.0, 1.0, 0.0, -1.0), 7 => (1.0, 0.0, -1.0, 1.0));
   Octo_Flat_P_Table : constant Mix_Table :=
     (0 => (1.0, 0.707107, -0.707107, 1.0), 1 => (1.0, -0.707107, -0.707107, 1.0),
      2 => (1.0, -0.707107, 0.707107, 1.0), 3 => (1.0, 0.707107, 0.707107, 1.0), 4 => (1.0, 0.0, -1.0, -1.0),
      5 => (1.0, -1.0, 0.0, -1.0), 6 => (1.0, 0.0, 1.0, -1.0), 7 => (1.0, 1.0, 0.0, -1.0));
   Octo_Flat_X_Table : constant Mix_Table :=
     (0 => (1.0, 1.0, -0.414178, 1.0), 1 => (1.0, -0.414178, -1.0, 1.0), 2 => (1.0, -1.0, 0.414178, 1.0),
      3 => (1.0, 0.414178, 1.0, 1.0), 4 => (1.0, 0.414178, -1.0, -1.0), 5 => (1.0, -1.0, -0.414178, -1.0),
      6 => (1.0, -0.414178, 1.0, -1.0), 7 => (1.0, 1.0, 0.414178, -1.0));
   Vtail4_Table : constant Mix_Table :=
     (0 => (1.0, -0.58, 0.58, 1.0), 1 => (1.0, -0.46, -0.39, -0.5), 2 => (1.0, 0.58, 0.58, -1.0),
      3 => (1.0, 0.46, -0.39, 0.5), others => <>);
   Atail4_Table : constant Mix_Table :=
     (0 => (1.0, -0.58, 0.58, -1.0), 1 => (1.0, -0.46, -0.39, 0.5), 2 => (1.0, 0.58, 0.58, 1.0),
      3 => (1.0, 0.46, -0.39, -0.5), others => <>);
   Dualcopter_Table : constant Mix_Table := (0 => (1.0, 0.0, 0.0, -1.0), 1 => (1.0, 0.0, 0.0, 1.0), others => <>);
   Single_Prop_Table : constant Mix_Table := (0 => (1.0, 0.0, 0.0, 0.0), others => <>);
   Quad_X_1234_Table : constant Mix_Table :=
     (0 => (1.0, 1.0, -1.0, -1.0), 1 => (1.0, -1.0, -1.0, 1.0), 2 => (1.0, -1.0, 1.0, -1.0),
      3 => (1.0, 1.0, 1.0, 1.0), others => <>);
   No_Table : constant Mix_Table := (others => <>);

   function Table_Of (Mode : Mixer_Mode) return Mix_Table is
     (case Mode is
         when Tri => Tri_Table,
         when Quad_P => Quad_P_Table,
         when Quad_X => Quad_X_Table,
         when Bicopter => Bicopter_Table,
         when Y6 => Y6_Table,
         when Hex6 => Hex6P_Table,
         when Flying_Wing | Airplane | Heli_120_CCPM => Single_Prop_Table,
         when Y4 => Y4_Table,
         when Hex6X => Hex6X_Table,
         when Octo_X8 => Octo_X8_Table,
         when Octo_Flat_P => Octo_Flat_P_Table,
         when Octo_Flat_X => Octo_Flat_X_Table,
         when Vtail4 => Vtail4_Table,
         when Hex6H => Hex6H_Table,
         when Dualcopter => Dualcopter_Table,
         when Atail4 => Atail4_Table,
         when Quad_X_1234 => Quad_X_1234_Table,
         when Octo_X8P => Octo_X8P_Table,
         when Gimbal | Heli_90_Deg | PPM_To_Servo | Singlecopter | Custom | Custom_Airplane | Custom_Tri => No_Table);

   --------------------
   -- Motor_Count_Of --
   --------------------

   function Motor_Count_Of (Mode : Mixer_Mode) return Natural is
     (case Mode is
         when Gimbal | Heli_90_Deg | PPM_To_Servo | Custom => 0,
         when Flying_Wing | Airplane | Heli_120_CCPM | Singlecopter | Custom_Airplane => 1,
         when Bicopter | Dualcopter => 2,
         when Tri | Custom_Tri => 3,
         when Quad_P | Quad_X | Y4 | Vtail4 | Atail4 | Quad_X_1234 => 4,
         when Y6 | Hex6 | Hex6X | Hex6H => 6,
         when Octo_X8 | Octo_Flat_P | Octo_Flat_X | Octo_X8P => 8);

   ---------------
   -- Has_Table --
   ---------------

   function Has_Table (O : Options; Mode : Mixer_Mode) return Boolean is
     (case Mode is
         when Tri | Quad_P | Quad_X | Flying_Wing | Y4 | Airplane | Heli_120_CCPM | Vtail4 | Atail4
            | Quad_X_1234 => True,
         when Bicopter | Dualcopter => O.Uncommon,
         when Hex6X => O.Max_Motors >= 6,
         when Y6 | Hex6 | Hex6H => O.Uncommon and then O.Max_Motors >= 6,
         when Octo_X8 | Octo_Flat_P | Octo_Flat_X | Octo_X8P => O.Uncommon and then O.Max_Motors = 8,
         when Gimbal | Heli_90_Deg | PPM_To_Servo | Singlecopter | Custom | Custom_Airplane | Custom_Tri => False);

   ----------------------
   -- Configure_Output --
   ----------------------

   procedure Configure_Output
     (O : Options; Mode : Mixer_Mode; Custom_Mix : Mix_Table; Disarm_Output : Adaflight.Mixer.Motor_Value;
      Current : in out Mix_Table; Count : out Natural; Launch : in out Mix_Table; Disarmed : in out Motor_Outputs)
   is
   begin
      if O.Quad_Only then
         Count := 4;
         for I in Motor_Index range 0 .. 3 loop
            Current (I) := Quad_X_Table (I);
         end loop;
      elsif Mode in Custom | Custom_Tri | Custom_Airplane then
         Count := 0;
         for I in Motor_Index range 0 .. O.Max_Motors - 1 loop
            pragma Loop_Invariant (Count = I);
            exit when Custom_Mix (I).Throttle = 0.0;
            Current (I) := Custom_Mix (I);
            Count := Count + 1;
         end loop;
      else
         Count := Natural'Min (Motor_Count_Of (Mode), O.Max_Motors);
         if Has_Table (O, Mode) then
            for I in Motor_Index range 0 .. Count - 1 loop
               Current (I) := Table_Of (Mode) (I);
            end loop;
         end if;
      end if;
      if O.Launch_Control then
         for I in Motor_Index range 0 .. O.Max_Motors - 1 loop
            Launch (I) := Current (I);
            if Launch (I).Pitch < 0.0 then
               Launch (I).Pitch := 0.0;
               Launch (I).Throttle := 0.0;
            end if;
         end loop;
      end if;
      for I in Motor_Index range 0 .. O.Max_Motors - 1 loop
         Disarmed (I) := Disarm_Output;
      end loop;
   end Configure_Output;

   --------------
   -- Load_Mix --
   --------------

   procedure Load_Mix (O : Options; Mode : Mixer_Mode; Custom_Mix : in out Mix_Table) is
   begin
      for I in Motor_Index range 0 .. O.Max_Motors - 1 loop
         Custom_Mix (I).Throttle := 0.0;
      end loop;
      if Has_Table (O, Mode) then
         for I in Motor_Index range 0 .. Motor_Count_Of (Mode) - 1 loop
            Custom_Mix (I) := Table_Of (Mode) (I);
         end loop;
      end if;
   end Load_Mix;

   --------------------
   -- Motors_Running --
   --------------------

   function Motors_Running
     (Armed : Boolean; Disarmed : Motor_Outputs; Count : Natural; Disarm_Output : Float) return Boolean
   is
     (Armed or else (for some I in 0 .. Count - 1 => Disarmed (I) /= Disarm_Output));

   ----------------------
   -- Motors_Saturated --
   ----------------------

   function Motors_Saturated (Motors : Motor_Outputs; Count : Natural; Max_Throttle : Float) return Boolean is
     (for some I in 0 .. Count - 1 => Motors (I) >= Max_Throttle);

end Adaflight.Mixer_Init;
