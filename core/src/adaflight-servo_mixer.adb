with Adaflight.Maths;
with Adaflight.Servo_Rules;

package body Adaflight.Servo_Mixer with SPARK_Mode is

   use type Mixer_Init.Mixer_Mode;

   Scaling   : constant Float := 0.7;
   Range_Min : constant Float := 1_000.0;
   Range_Max : constant Float := 2_000.0;

   Gimbal_Pitch   : constant Servo_Index := 0;
   Gimbal_Roll    : constant Servo_Index := 1;
   Flaps          : constant Servo_Index := 2;
   Flapperon_1    : constant Servo_Index := 3;
   Flapperon_2    : constant Servo_Index := 4;
   Rudder         : constant Servo_Index := 5;
   Throttle_Servo : constant Servo_Index := 7;

   No_Rule : constant Config_Groups.Servo_Mixer_Record :=
     (Target_Channel => 0, Input_Source => 0, Rate => 0, Speed => 0, Min => 0, Max => 0, Box => 0);

   subtype Source_Index is Natural range 0 .. Source_Count - 1;
   type Source_Values is array (Source_Index) of Integer_16;

   Wide_Bound : constant := 2 ** 48;
   subtype Wide is Integer_64 range -Wide_Bound .. Wide_Bound;

   --  A value narrowed to sixteen bits, as the reference's stores wrap it.
   function Wrap_16 (V : Wide) return Integer_16 is
     (Integer_16 ((V + 32_768) mod 65_536 - 32_768));

   --  The reference's constrain, which tests the low bound first.
   function Clamp (V, Low, High : Wide) return Wide is
     (if V < Low then Low elsif V > High then High else V);

   --  A float narrowed to sixteen bits toward zero.
   function Truncated (F : Float) return Integer_16 is
     (Integer_16 (Float'Truncation (F)))
     with Pre => F >= -32_768.0 and then F <= 32_767.0;

   --  A float narrowed to sixteen bits toward zero, held to the sixteen-bit
   --  range where the reference's conversion is undefined.
   function Held (F : Float) return Integer_16 is
     (if F >= 32_767.0 then Integer_16'Last
      elsif F <= -32_768.0 then Integer_16'First
      else Integer_16 (Float'Truncation (F)));

   --  A filter output rounded to the nearest integer with ties to even and
   --  narrowed to sixteen bits.
   function Rounded (F : Float) return Integer_16 is
     (if F >= Float (Maths.Rounding_Bound) - 1.0 then Wrap_16 (Maths.Rounding_Bound - 1)
      elsif F <= 1.0 - Float (Maths.Rounding_Bound) then Wrap_16 (1 - Maths.Rounding_Bound)
      else Wrap_16 (Integer_64 (Maths.Round_Half_Even (F))));

   --  The attitude angle in tenths of a degree scaled to a stick input.
   function Gimbal_Input (Angle : Integer_16) return Integer_16 is
     (Wrap_16 (1_000 * (Integer_64 (Angle) + 1_800) / 3_600 - 500));

   function Channel_Of (N : Servo_Index; C : Settings) return Natural is
     (Natural (Unsigned_8'Mod (Integer (C.Params (N).Forward_From_Channel))));

   --  The servo's middle, or its forwarded channel scaled to its range.
   function Middle_Or_Forward (C : Settings; I : Inputs; N : Servo_Index) return Integer_16 is
     (if Channel_Of (N, C) /= Disabled and then Channel_Of (N, C) < C.Channel_Count
      then Held (Maths.Scale_Range_F
                   (Maths.Constrain_F (I.RC_Data (Channel_Of (N, C)), Range_Min, Range_Max), Range_Min, Range_Max,
                    Float (C.Params (N).Min), Float (C.Params (N).Max)))
      else C.Params (N).Middle);

   ----------
   -- Init --
   ----------

   procedure Init (S : out State; C : Settings; Dt : Filters.Period) is
      Mode_Rules : Servo_Rules.Rule_List;
      Count      : Servo_Rules.Rule_Count;
      Forwarding : Boolean := False;
   begin
      for N in Servo_Index loop
         if Channel_Of (N, C) /= Disabled then
            Forwarding := True;
         end if;
      end loop;
      S := (Uses_Servos => Mixer_Init.Uses_Servos (C.Mode) or else C.Servo_Tilt or else C.Channel_Forwarding
                           or else Forwarding,
            Rule_Count  => 0,
            Rules       => (others => No_Rule),
            Outputs     => (others => 0),
            Servo       => (others => 1_500),
            Filter      => (others => (others => <>)),
            Written     => (others => False));
      if S.Uses_Servos then
         Servo_Rules.Mode_Rules (C.Options, C.Mode, Mode_Rules, Count);
         S.Rule_Count := Count;
         for R in 1 .. Count loop
            S.Rules (R - 1) :=
              (Target_Channel => Mode_Rules (R).Target, Input_Source => Mode_Rules (R).Input,
               Rate => Mode_Rules (R).Rate, Speed => Mode_Rules (R).Speed, Min => Mode_Rules (R).Min,
               Max => Mode_Rules (R).Max, Box => Mode_Rules (R).Box);
         end loop;
      end if;
      if C.Mode in Mixer_Init.Custom_Airplane | Mixer_Init.Custom_Tri then
         S.Rule_Count := 0;
         S.Rules := (others => No_Rule);
         for R in Rule_Index loop
            pragma Loop_Invariant (S.Rule_Count = R);
            exit when C.Custom_Rules (R).Rate = 0;
            S.Rules (R) := C.Custom_Rules (R);
            S.Rule_Count := S.Rule_Count + 1;
         end loop;
      end if;
      if C.Lowpass_Hz /= 0 then
         for N in Servo_Index loop
            Filters.SVF_Lowpass_Init (S.Filter (N), Float (C.Lowpass_Hz), Dt);
         end loop;
      end if;
   end Init;

   --  The servo mixer: the inputs, each rule active without a box or with
   --  its box on, then each servo's rate and its middle or forwarded
   --  channel. A rule naming a servo or an input past the tables, which the
   --  configuration never holds, is skipped.
   procedure Mix (S : in out State; C : Settings; I : Inputs) is
      Input : Source_Values := (others => 0);
   begin
      if I.Passthru then
         for A in Axis loop
            Input (A) := Truncated (I.RC_Command (A));
         end loop;
      else
         for A in Axis loop
            Input (A) := Truncated (I.PID_Sum (A) * Scaling);
         end loop;
         if C.Three_D and then I.RC_Data (3) < Float (C.Mid_RC) then
            Input (2) := Wrap_16 (-Integer_64 (Input (2)));
         end if;
      end if;
      Input (12) := Gimbal_Input (I.Pitch);
      Input (13) := Gimbal_Input (I.Roll);
      Input (3) := Truncated ((if I.Motor_Device then Float (I.External_Motor) else I.Motor) - 1_500.0);
      for K in 0 .. 7 loop
         Input (4 + K) := Truncated (I.RC_Data (K) - Float (C.Mid_RC));
      end loop;

      S.Servo := (others => 0);
      for R in 0 .. S.Rule_Count - 1 loop
         declare
            Rule : constant Config_Groups.Servo_Mixer_Record := S.Rules (R);
            Box  : constant Natural := Natural (Rule.Box);
         begin
            if Box = 0 or else (Box <= 3 and then I.Servo_Box (Box)) then
               if Natural (Rule.Target_Channel) < Max_Servos and then Natural (Rule.Input_Source) < Source_Count then
                  declare
                     Target : constant Servo_Index := Natural (Rule.Target_Channel);
                     From   : constant Source_Index := Natural (Rule.Input_Source);
                     Width  : constant Wide :=
                       (Integer_64 (C.Params (Target).Max) - Integer_64 (C.Params (Target).Min)) mod 65_536;
                     Low    : constant Wide := Integer_64 (Wrap_16 (Integer_64 (Rule.Min) * Width / 100 - Width / 2));
                     High   : constant Wide := Integer_64 (Wrap_16 (Integer_64 (Rule.Max) * Width / 100 - Width / 2));
                     Value  : constant Integer_16 := Input (From);
                     Sign   : constant Wide :=
                       (if (C.Params (Target).Reversed_Sources and Shift_Left (Unsigned_32'(1), From)) /= 0 then -1
                        else 1);
                  begin
                     if Rule.Speed = 0 then
                        S.Outputs (R) := Value;
                     elsif S.Outputs (R) < Value then
                        S.Outputs (R) := Integer_16 (Clamp (Integer_64 (S.Outputs (R)) + Integer_64 (Rule.Speed),
                                                            Integer_64 (S.Outputs (R)), Integer_64 (Value)));
                     elsif S.Outputs (R) > Value then
                        S.Outputs (R) := Integer_16 (Clamp (Integer_64 (S.Outputs (R)) - Integer_64 (Rule.Speed),
                                                            Integer_64 (Value), Integer_64 (S.Outputs (R))));
                     end if;
                     S.Servo (Target) :=
                       Wrap_16 (Integer_64 (S.Servo (Target))
                                + Sign * Clamp (Integer_64 (S.Outputs (R)) * Integer_64 (Rule.Rate) / 100, Low, High));
                  end;
               end if;
            else
               S.Outputs (R) := 0;
            end if;
         end;
      end loop;

      for N in Servo_Index loop
         S.Servo (N) := Wrap_16 (Integer_64 (C.Params (N).Rate) * Integer_64 (S.Servo (N)) / 100);
         S.Servo (N) := Wrap_16 (Integer_64 (S.Servo (N)) + Integer_64 (Middle_Or_Forward (C, I, N)));
      end loop;
   end Mix;

   ------------------
   -- Write_Servos --
   ------------------

   procedure Write_Servos (S : in out State; C : Settings; I : Inputs; W : out Servo_Writes; Count : out Write_Count)
   is
      procedure Put (Value : Float) is
      begin
         if Count < Max_Writes then
            Count := Count + 1;
            W (Count) := (Index => Count - 1, Value => Value);
         end if;
      end Put;

      procedure Track (N : Servo_Index) is
      begin
         Put (Float (S.Servo (N)));
         S.Written (N) := True;
      end Track;
   begin
      W := (others => (Index => 0, Value => 0.0));
      Count := 0;

      Mix (S, C, I);
      if C.Servo_Tilt then
         S.Servo (Gimbal_Pitch) := Middle_Or_Forward (C, I, Gimbal_Pitch);
         S.Servo (Gimbal_Roll) := Middle_Or_Forward (C, I, Gimbal_Roll);
         if I.Camera_Box then
            declare
               Rate_P : constant Wide := Integer_64 (C.Params (Gimbal_Pitch).Rate);
               Rate_R : constant Wide := Integer_64 (C.Params (Gimbal_Roll).Rate);
               Pitch  : constant Wide := Integer_64 (I.Pitch);
               Roll   : constant Wide := Integer_64 (I.Roll);
            begin
               if C.Mixed_Tilt then
                  S.Servo (Gimbal_Pitch) :=
                    Wrap_16 (Integer_64 (S.Servo (Gimbal_Pitch)) - ((-Rate_P) * Pitch / 50 - Rate_R * Roll / 50));
                  S.Servo (Gimbal_Roll) :=
                    Wrap_16 (Integer_64 (S.Servo (Gimbal_Roll)) + ((-Rate_P) * Pitch / 50 + Rate_R * Roll / 50));
               else
                  S.Servo (Gimbal_Pitch) := Wrap_16 (Integer_64 (S.Servo (Gimbal_Pitch)) + Rate_P * Pitch / 50);
                  S.Servo (Gimbal_Roll) := Wrap_16 (Integer_64 (S.Servo (Gimbal_Roll)) + Rate_R * Roll / 50);
               end if;
            end;
         end if;
      end if;
      for N in Servo_Index loop
         S.Servo (N) := Integer_16 (Clamp (Integer_64 (S.Servo (N)), Integer_64 (C.Params (N).Min),
                                           Integer_64 (C.Params (N).Max)));
      end loop;

      if C.Lowpass_Hz /= 0 then
         for N in Servo_Index loop
            declare
               Output : Float;
            begin
               Filters.SVF_Lowpass_Apply (S.Filter (N), Float (S.Servo (N)), Output);
               S.Servo (N) := Rounded (Output);
               S.Servo (N) := Integer_16 (Clamp (Integer_64 (S.Servo (N)), Integer_64 (C.Params (N).Min),
                                                 Integer_64 (C.Params (N).Max)));
            end;
         end loop;
      end if;

      case C.Mode is
         when Mixer_Init.Tri | Mixer_Init.Custom_Tri =>
            if not (C.Tri_Unarmed or else I.Armed) then
               S.Servo (Rudder) := 0;
            end if;
            Track (Rudder);
         when Mixer_Init.Flying_Wing =>
            Track (Flapperon_1);
            Track (Flapperon_2);
         when Mixer_Init.Custom_Airplane | Mixer_Init.Airplane =>
            for N in Flaps .. Throttle_Servo loop
               Track (N);
            end loop;
         when Mixer_Init.Bicopter | Mixer_Init.Dualcopter =>
            if C.Options.Uncommon then
               Track (4);
               Track (5);
            end if;
         when Mixer_Init.Heli_120_CCPM =>
            if C.Options.Uncommon then
               for N in Servo_Index range 0 .. 3 loop
                  Track (N);
               end loop;
            end if;
         when Mixer_Init.Singlecopter =>
            if C.Options.Uncommon then
               for N in Servo_Index range 3 .. 6 loop
                  Track (N);
               end loop;
            end if;
         when Mixer_Init.Quad_P | Mixer_Init.Quad_X | Mixer_Init.Gimbal | Mixer_Init.Y6 | Mixer_Init.Hex6
            | Mixer_Init.Y4 | Mixer_Init.Hex6X | Mixer_Init.Octo_X8 | Mixer_Init.Octo_Flat_P | Mixer_Init.Octo_Flat_X
            | Mixer_Init.Heli_90_Deg | Mixer_Init.Vtail4 | Mixer_Init.Hex6H | Mixer_Init.PPM_To_Servo
            | Mixer_Init.Atail4 | Mixer_Init.Custom | Mixer_Init.Quad_X_1234 | Mixer_Init.Octo_X8P =>
            null;
      end case;

      if C.Servo_Tilt or else C.Mode = Mixer_Init.Gimbal then
         Track (Gimbal_Pitch);
         Track (Gimbal_Roll);
      end if;

      for N in Servo_Index loop
         if Channel_Of (N, C) /= Disabled and then not S.Written (N) then
            Put (Float (S.Servo (N)));
         end if;
      end loop;

      if C.Channel_Forwarding then
         declare
            Channel : Natural := C.Forward_Start;
         begin
            for Offset in 0 .. Natural'Min (Max_Aux, C.Max_Aux_Channel) - 1 loop
               exit when Channel >= Max_Channels;
               Put (I.RC_Data (Channel));
               Channel := Channel + 1;
            end loop;
         end;
      end if;
   end Write_Servos;

end Adaflight.Servo_Mixer;
