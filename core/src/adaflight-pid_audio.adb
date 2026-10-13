package body Adaflight.PID_Audio with SPARK_Mode is

   Sum_Limit : constant := 500;

   --  A sum's magnitude up to the limit, truncated to an integer.
   function Level (V : Float) return Natural is
     (Natural (Float'Truncation (Float'Min (V, Float (Sum_Limit)))))
     with Pre => V >= 0.0 and then V <= 2.0 ** 33,
          Post => Level'Result <= Sum_Limit;

   --  The integer range scale from 0 .. 500 onto 63 .. 0, truncating as C.
   function Tone_Of (L : Natural) return Tone is ((0 - (Tone_Count - 1)) * L / Sum_Limit + (Tone_Count - 1))
     with Pre => L <= Sum_Limit;

   --------------
   -- Set_Mode --
   --------------

   procedure Set_Mode (S : in out State; M : Audio_Mode) is
   begin
      S.Mode := M;
   end Set_Mode;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out State; Box_Active : Boolean; Roll_Sum, Pitch_Sum : PID_Sum; C : out Calls) is
   begin
      C := (others => <>);
      if S.Enabled /= Box_Active then
         if Box_Active then
            C.Start_Noise := True;
         else
            C.Silence := True;
         end if;
         S.Enabled := Box_Active;
      end if;
      if not S.Enabled then
         return;
      end if;
      C.Play := True;
      case S.Mode is
         when Adaflight.Adjustments.PID_Sum_X =>
            C.Played := Tone_Of (Level (abs Roll_Sum));
         when Adaflight.Adjustments.PID_Sum_Y =>
            C.Played := Tone_Of (Level (abs Pitch_Sum));
         when Adaflight.Adjustments.PID_Sum_XY =>
            C.Played := Tone_Of (Level ((abs Roll_Sum + abs Pitch_Sum) / 2.0));
         when Adaflight.Adjustments.Off =>
            C.Played := Tone_Mid;
      end case;
   end Update;

end Adaflight.PID_Audio;
