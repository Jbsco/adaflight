with Adaflight.Maths;

package body Adaflight.LED_Strip with SPARK_Mode is

   subtype Hue_Word is Natural range 0 .. 65535;

   Fn_Color       : constant Unsigned_32 := 0;
   Fn_Flight_Mode : constant Unsigned_32 := 1;
   Fn_Arm_State   : constant Unsigned_32 := 2;
   Fn_Battery     : constant Unsigned_32 := 3;
   Fn_Rssi        : constant Unsigned_32 := 4;
   Fn_GPS         : constant Unsigned_32 := 5;
   Fn_Thrust_Ring : constant Unsigned_32 := 6;
   Fn_GPS_Bar     : constant Unsigned_32 := 7;
   Fn_Battery_Bar : constant Unsigned_32 := 8;
   Fn_Altitude    : constant Unsigned_32 := 9;

   Ov_Throttle  : constant := 0;
   Ov_Rainbow   : constant := 1;
   Ov_Larson    : constant := 2;
   Ov_Blink     : constant := 3;
   Ov_Vtx       : constant := 4;
   Ov_Indicator : constant := 5;
   Ov_Warning   : constant := 6;

   Function_Offset  : constant := 8;
   Overlay_Offset   : constant := 12;
   Color_Offset     : constant := 22;
   Direction_Offset : constant := 26;

   Max_Timer_Delay_Us : constant := 5_000_000;
   Sequence_Leds      : constant := 6;
   Sequence_Width     : constant := 2;
   Indicator_Deadband : constant := 25;
   Color_Interval_Us  : constant := 1_000_000.0;

   Black   : constant HSV := (0, 0, 0);
   White   : constant HSV := (0, 255, 255);
   Red     : constant HSV := (0, 0, 255);
   Orange  : constant HSV := (15, 0, 255);
   Yellow  : constant HSV := (50, 0, 255);
   Green   : constant HSV := (115, 0, 255);
   Blue    : constant HSV := (240, 0, 255);
   Magenta : constant HSV := (300, 0, 255);

   type Named_Table is array (Named_Color) of HSV;
   Named : constant Named_Table :=
     (Black, White, Red, Orange, Yellow, (100, 0, 255), Green, (125, 0, 255), (180, 0, 255), (210, 0, 255), Blue,
      (270, 0, 255), Magenta, (330, 0, 255));

   function X_Of (Cfg : Unsigned_32) return Natural is (Natural (Interfaces.Shift_Right (Cfg, 4) and 15));
   function Y_Of (Cfg : Unsigned_32) return Natural is (Natural (Cfg and 15));
   function Function_Of (Cfg : Unsigned_32) return Unsigned_32 is
     (Interfaces.Shift_Right (Cfg, Function_Offset) and 15);
   function Overlay_Of (Cfg : Unsigned_32) return Unsigned_32 is
     (Interfaces.Shift_Right (Cfg, Overlay_Offset) and 16#3FF#);
   function Color_Of (Cfg : Unsigned_32) return Color_Index is
     (Color_Index (Interfaces.Shift_Right (Cfg, Color_Offset) and 15));
   function Direction_Of (Cfg : Unsigned_32) return Unsigned_32 is
     (Interfaces.Shift_Right (Cfg, Direction_Offset) and 16#3F#);
   function Has_Overlay (Cfg : Unsigned_32; Id : Natural) return Boolean is
     ((Overlay_Of (Cfg) and Interfaces.Shift_Left (1, Id)) /= 0)
     with Pre => Id <= 9;

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function Hz_To_Us (Hz : Integer) return Integer_32 is
     (if Hz = 0 then 0 else Integer_32 (1_000_000 / Hz))
     with Pre => Hz in -1000 .. 1000;

   procedure Add_Us (T : in out Unsigned_32; Us : Integer_32)
     with Pre => Us > Integer_32'First
   is
   begin
      if Us >= 0 then
         T := T + Unsigned_32 (Us);
      else
         T := T - Unsigned_32 (abs Us);
      end if;
   end Add_Us;

   function Scale (Value, From, To, Dest_From, Dest_To : Integer_32) return Integer_32
     renames Adaflight.Maths.Scale_Range;

   --  A hue offset from a scaled value, floored at zero as the reference
   --  floors it.
   function Hue_Shift (V : Integer_32) return Natural is (Natural (Integer_32'Max (0, Integer_32'Min (V, 20_000_000))));

   --  A bounded value from a scaled one, where the bounds hold for every
   --  input in range.
   function Bounded (V, Low, High : Integer_32) return Integer_32 is (Integer_32'Max (Low, Integer_32'Min (High, V)))
     with Pre => Low <= High, Post => Bounded'Result in Low .. High;

   function Truncated (F : Float) return Integer_32 is (Integer_32 (Float'Truncation (F)))
     with Pre => F in -2.0e9 .. 2.0e9;

   --------------
   -- Evaluate --
   --------------

   function Evaluate (C : Settings) return Layout is
      L     : Layout;
      Max_X : Integer := 0;
      Min_X : Integer := 15;
      Max_Y : Integer := 0;
      Min_Y : Integer := 15;
      Seq   : Positive;
      Used  : array (0 .. Ov_Warning) of Boolean := (others => False);
   begin
      for I in Led_Index loop
         pragma Loop_Invariant (L.Count = I and then L.Ring <= I and then L.Larson <= I);
         exit when C.Leds (I) = 0;
         L.Count := I + 1;
         if Function_Of (C.Leds (I)) = Fn_Thrust_Ring then
            L.Ring := L.Ring + 1;
         end if;
         if Has_Overlay (C.Leds (I), Ov_Larson) then
            L.Larson := L.Larson + 1;
         end if;
      end loop;
      for I in 0 .. L.Count - 1 loop
         Max_X := Integer'Max (X_Of (C.Leds (I)), Max_X);
         Min_X := Integer'Min (X_Of (C.Leds (I)), Min_X);
         Max_Y := Integer'Max (Y_Of (C.Leds (I)), Max_Y);
         Min_Y := Integer'Min (Y_Of (C.Leds (I)), Min_Y);
         if Function_Of (C.Leds (I)) = Fn_GPS_Bar then
            L.GPS_Bars := L.GPS_Bars + 1;
         elsif Function_Of (C.Leds (I)) = Fn_Battery_Bar then
            L.Battery_Bars := L.Battery_Bars + 1;
         end if;
         for O in Used'Range loop
            if Has_Overlay (C.Leds (I), O) then
               Used (O) := True;
            end if;
         end loop;
         pragma Loop_Invariant (L.GPS_Bars + L.Battery_Bars <= I + 1);
         pragma Loop_Invariant (Max_X in 0 .. 15 and then Min_X in 0 .. 15);
         pragma Loop_Invariant (Max_Y in 0 .. 15 and then Min_Y in 0 .. 15);
      end loop;
      if Min_X < Max_X then
         L.Lowest_X_East := (Min_X + Max_X) / 2 + 1;
         L.Highest_X_West := (Min_X + Max_X - 1) / 2;
      else
         L.Lowest_X_East := 7;
         L.Highest_X_West := 6;
      end if;
      if Min_Y < Max_Y then
         L.Lowest_Y_South := (Min_Y + Max_Y) / 2 + 1;
         L.Highest_Y_North := (Min_Y + Max_Y - 1) / 2;
      else
         L.Lowest_Y_South := 7;
         L.Highest_Y_North := 6;
      end if;
      if L.Ring mod Sequence_Leds = 0 then
         Seq := Sequence_Leds;
      else
         Seq := L.Ring;
         while Seq > Sequence_Leds and then Seq mod 2 = 0 loop
            pragma Loop_Invariant (Seq in 2 .. Max_Leds);
            pragma Loop_Variant (Decreases => Seq);
            Seq := Seq / 2;
         end loop;
      end if;
      L.Ring_Seq_Len := Seq;
      L.Disabled := (Tim_Rainbow => not Used (Ov_Rainbow), Tim_Blink => not Used (Ov_Blink),
                     Tim_Larson => not Used (Ov_Larson), Tim_Warning => not Used (Ov_Warning),
                     Tim_Vtx => not Used (Ov_Vtx), Tim_Indicator => not Used (Ov_Indicator), others => False);
      return L;
   end Evaluate;

   ------------------
   -- Strip update --
   ------------------

   --  Every LED in use, or all of them after a change of count, scaled by
   --  the brightness and converted for the driver.
   procedure Strip_Update (S : in out Strip; L : Layout; Brightness : Brightness_Percent) is
      Last : constant Integer := (if S.Needs_Full then Max_Leds - 1 else L.Count - 1);
      C    : HSV;
   begin
      for I in 0 .. Last loop
         C := (if I < L.Count then S.Buffer (I) else Black);
         C.V := Unsigned_8 (Natural (C.V) * Natural (Brightness) / 100);
         S.Output (I) := Adaflight.Color.To_RGB (C);
      end loop;
      S.Needs_Full := False;
   end Strip_Update;

   procedure Set_All (S : in out Strip; L : Layout; C : HSV) is
   begin
      for I in 0 .. L.Count - 1 loop
         S.Buffer (I) := C;
      end loop;
   end Set_All;

   --  A color onto every LED whose configuration holds every bit of the
   --  mask; a function mask also matches the functions whose numbers hold
   --  its bits (finding F88).
   procedure Apply_Masked (S : in out Strip; C : Settings; L : Layout; Mask : Unsigned_32; Col : HSV) is
   begin
      for I in 0 .. L.Count - 1 loop
         if (C.Leds (I) and Mask) = Mask then
            S.Buffer (I) := Col;
         end if;
      end loop;
   end Apply_Masked;

   function Function_Mask (Fn : Unsigned_32) return Unsigned_32 is (Interfaces.Shift_Left (Fn, Function_Offset));
   function Overlay_Mask (Id : Natural) return Unsigned_32 is
     (Interfaces.Shift_Left (Interfaces.Shift_Left (1, Id), Overlay_Offset))
     with Pre => Id <= 9;

   ------------------
   -- Fixed layers --
   ------------------

   --  The first direction bit of a LED picks its mode color.
   function Directional (C : Settings; Cfg : Unsigned_32; M : Mode_Id; Fallback : HSV) return HSV is
      Dir : constant Unsigned_32 := Direction_Of (Cfg);
   begin
      for D in Direction_Id loop
         if (Dir and Interfaces.Shift_Left (1, Direction_Id'Pos (D))) /= 0 then
            return C.Colors (C.Modes (M) (D));
         end if;
      end loop;
      return Fallback;
   end Directional;

   function Flight_Led_Mode (Inp : Inputs) return Mode_Id is
     (if Inp.Headfree then Headfree_Mode elsif Inp.Mag then Mag_Mode elsif Inp.Horizon then Horizon_Mode
      elsif Inp.Angle then Angle_Mode else Orientation);

   --  Every LED from its function: the color, the mode color, the arm
   --  state, the battery, GPS, signal and altitude hues, the bars.
   procedure Apply_Fixed_Layers (S : in out Strip; C : Settings; L : Layout; Inp : Inputs) is
      GPS_Counter     : Natural := 0;
      Battery_Counter : Natural := 0;
      Aux             : constant Integer_32 range 0 .. 4000 := Truncated (Inp.Aux);
   begin
      for I in 0 .. L.Count - 1 loop
         pragma Loop_Invariant (GPS_Counter <= I and then Battery_Counter <= I);
         declare
            Cfg      : constant Unsigned_32 := C.Leds (I);
            Fn       : constant Unsigned_32 := Function_Of (Cfg);
            Col      : HSV := C.Colors (C.Specials (Background));
            H        : Hue_Word := Col.H;
            H_Offset : Natural range 0 .. 30_000_000 := 360;
            Total    : Natural;
            Apply    : Boolean := True;
         begin
            if Fn = Fn_Color then
               Col := C.Colors (Color_Of (Cfg));
               H := Col.H;
               if Has_Overlay (Cfg, Ov_Throttle) then
                  declare
                     Next : constant HSV := C.Colors ((Color_Of (Cfg) + 1) mod Color_Count);
                     Prev : constant HSV := C.Colors ((Color_Of (Cfg) + Color_Count - 1) mod Color_Count);
                  begin
                     if Aux < 1500 then
                        H := Natural (Scale (Aux, 1000, 1500, Integer_32 (Prev.H), Integer_32 (Col.H)) mod 65536);
                        Col.S := Unsigned_8 (Scale (Aux, 1000, 1500, Integer_32 (Prev.S), Integer_32 (Col.S)) mod 256);
                        Col.V := Unsigned_8 (Scale (Aux, 1000, 1500, Integer_32 (Prev.V), Integer_32 (Col.V)) mod 256);
                     else
                        H := Natural (Scale (Aux, 1500, 2000, Integer_32 (Col.H), Integer_32 (Next.H)) mod 65536);
                        Col.S := Unsigned_8 (Scale (Aux, 1500, 2000, Integer_32 (Col.S), Integer_32 (Next.S)) mod 256);
                        Col.V := Unsigned_8 (Scale (Aux, 1500, 2000, Integer_32 (Col.V), Integer_32 (Next.V)) mod 256);
                     end if;
                  end;
               end if;
            elsif Fn = Fn_Flight_Mode then
               Col := Directional (C, Cfg, Flight_Led_Mode (Inp), Col);
               H := Col.H;
            elsif Fn = Fn_Arm_State then
               Col := C.Colors (C.Specials (if Inp.Armed then Armed_Color else Disarmed));
               H := Col.H;
            elsif Fn = Fn_Battery or else Fn = Fn_Battery_Bar then
               Col := Red;
               H := Col.H;
               H_Offset := H_Offset + Hue_Shift (Scale (Integer_32 (Inp.Battery_Percent), 0, 100, -30, 120));
            elsif Fn = Fn_GPS_Bar then
               if Inp.Num_Sat = 0 or else not Inp.GPS_Present then
                  Col := Red;
               elsif Inp.Num_Sat >= Inp.Min_Sats then
                  Col := Green;
               else
                  Col := Red;
                  H_Offset := H_Offset
                    + Hue_Shift (Scale (Integer_32 (Inp.Num_Sat), 0, Integer_32 (Inp.Min_Sats), -30, 120));
               end if;
               H := Col.H;
            elsif Fn = Fn_Altitude then
               Col := C.Colors (Color_Of (Cfg));
               H := Col.H;
               H_Offset := H_Offset + Hue_Shift (Scale (Inp.Altitude_Cm, 0, 500, -30, 120));
            elsif Fn = Fn_Rssi then
               Col := Red;
               H := Col.H;
               H_Offset := H_Offset + Hue_Shift (Scale (Integer_32 (Inp.Rssi_Percent), 0, 100, -30, 120));
            end if;
            if Fn /= Fn_Color and then Has_Overlay (Cfg, Ov_Throttle) then
               Total := Integer'Max (0, H_Offset + Integer (Bounded (Scale (Aux, 1000, 2000, 0, 360), -360, 720)));
            else
               Total := H_Offset;
            end if;
            Col.H := (H + Total) mod 360;
            if Fn = Fn_GPS_Bar then
               if GPS_Counter < Natural (Inp.Num_Sat) or else GPS_Counter = 0 then
                  GPS_Counter := GPS_Counter + 1;
               else
                  Apply := False;
               end if;
            elsif Fn = Fn_Battery_Bar then
               if Battery_Counter < Natural (Inp.Battery_Percent) * L.Battery_Bars / 100
                 or else Battery_Counter = 0
               then
                  Battery_Counter := Battery_Counter + 1;
               else
                  Apply := False;
               end if;
            end if;
            S.Buffer (I) := (if Apply then Col else C.Colors (C.Specials (Background)));
         end;
      end loop;
   end Apply_Fixed_Layers;

   --------------------
   -- Overlay layers --
   --------------------

   procedure Warning_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Col   : HSV;
      Found : Boolean := False;
   begin
      if Now then
         S.Warning_Counter := (S.Warning_Counter + 1) and 15;
         if S.Warning_Counter = 0 then
            S.Warning_Flags := 0;
            if Inp.Voltage_Meter and then Inp.Battery /= OK then
               S.Warning_Flags := S.Warning_Flags or 2;
            end if;
            if Inp.Failsafe then
               S.Warning_Flags := S.Warning_Flags or 4;
            end if;
            if not Inp.Armed and then Inp.Arming_Disabled then
               S.Warning_Flags := S.Warning_Flags or 1;
            end if;
            if Inp.Crash_Flip then
               S.Warning_Flags := S.Warning_Flags or 8;
            end if;
         end if;
         Add_Us (S.Timer (Tim_Warning), Hz_To_Us (10));
      end if;
      Col := Black;
      if S.Warning_Flags /= 0 then
         declare
            On : constant Boolean := S.Warning_Counter mod 2 = 0;
            Id : constant Unsigned_8 := S.Warning_Counter / 4;
         begin
            if (S.Warning_Flags and Interfaces.Shift_Left (1, Natural (Id))) /= 0 then
               Found := True;
               case Id is
                  when 0 => Col := (if On then Green else Black);
                  when 1 => Col := (if On then Red else Black);
                  when 2 => Col := (if On then Yellow else Blue);
                  when others => Col := (if On then Magenta else Black);
               end case;
            end if;
         end;
      elsif Inp.Beeper_On then
         Found := True;
         Col := Named (C.Visual_Beeper_Color);
      end if;
      if Found then
         Apply_Masked (S, C, L, Overlay_Mask (Ov_Warning), Col);
      end if;
   end Warning_Layer;

   procedure Battery_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Delay_Us : Integer_32;
   begin
      if Now then
         case Inp.Battery is
            when OK =>
               S.Battery_Flash := True;
               Delay_Us := Hz_To_Us (1);
            when Warning =>
               S.Battery_Flash := not S.Battery_Flash;
               Delay_Us := Hz_To_Us (2);
            when others =>
               S.Battery_Flash := not S.Battery_Flash;
               Delay_Us := Hz_To_Us (8);
         end case;
         Add_Us (S.Timer (Tim_Battery), Delay_Us);
      end if;
      if not S.Battery_Flash then
         Apply_Masked (S, C, L, Function_Mask (Fn_Battery), C.Colors (C.Specials (Background)));
      end if;
   end Battery_Layer;

   procedure Rssi_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Delay_Us : Integer_32;
   begin
      if Now then
         if Inp.Rssi_Percent > 50 then
            S.Rssi_Flash := True;
            Delay_Us := Hz_To_Us (1);
         elsif Inp.Rssi_Percent > 20 then
            S.Rssi_Flash := not S.Rssi_Flash;
            Delay_Us := Hz_To_Us (2);
         else
            S.Rssi_Flash := not S.Rssi_Flash;
            Delay_Us := Hz_To_Us (8);
         end if;
         Add_Us (S.Timer (Tim_Rssi), Delay_Us);
      end if;
      if not S.Rssi_Flash then
         Apply_Masked (S, C, L, Function_Mask (Fn_Rssi), C.Colors (C.Specials (Background)));
      end if;
   end Rssi_Layer;

   --  The GPS LEDs flash the satellite count, then pause.
   procedure GPS_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Col : HSV;
   begin
      if Now then
         if S.GPS_Pause > 0 then
            S.GPS_Pause := S.GPS_Pause - 1;
         elsif S.GPS_Flash >= Inp.Num_Sat then
            S.GPS_Flash := 0;
            S.GPS_Pause := 4;
         else
            S.GPS_Flash := S.GPS_Flash + 1;
            S.GPS_Pause := 1;
         end if;
         Add_Us (S.Timer (Tim_Gps), 400_000);
      end if;
      if Inp.Num_Sat = 0 or else not Inp.GPS_Present then
         Col := C.Colors (C.Specials (GPS_No_Sats));
      elsif Inp.Fix then
         Col := C.Colors (C.Specials (if S.GPS_Pause = 0 then GPS_Locked else Background));
      else
         Col := C.Colors (C.Specials (if S.GPS_Pause = 0 then GPS_No_Lock else GPS_No_Sats));
      end if;
      Apply_Masked (S, C, L, Function_Mask (Fn_GPS), Col);
   end GPS_Layer;

   function Quadrant (L : Layout; Cfg : Unsigned_32) return Unsigned_32 is
      X : constant Integer := X_Of (Cfg);
      Y : constant Integer := Y_Of (Cfg);
      Q : Unsigned_32 := 0;
   begin
      if Y <= L.Highest_Y_North then
         Q := Q or 1;
      elsif Y >= L.Lowest_Y_South then
         Q := Q or 2;
      end if;
      if X >= L.Lowest_X_East then
         Q := Q or 4;
      elsif X <= L.Highest_X_West then
         Q := Q or 8;
      end if;
      return Q;
   end Quadrant;

   --  The indicator LEDs flash orange toward the sticks, faster with the
   --  deflection.
   procedure Indicator_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Quadrants : Unsigned_32 := 0;
   begin
      if Now then
         if Inp.Rx_Signal then
            declare
               Scale_V : constant Integer :=
                 Integer (Truncated (Float'Max (abs Inp.Roll_Command, abs Inp.Pitch_Command))) - Indicator_Deadband;
            begin
               Add_Us (S.Timer (Tim_Indicator), Hz_To_Us (5 + (45 * Scale_V) / (500 - Indicator_Deadband)));
            end;
            S.Indicator_Flash := not S.Indicator_Flash;
         else
            Add_Us (S.Timer (Tim_Indicator), Hz_To_Us (5));
         end if;
      end if;
      if not S.Indicator_Flash then
         return;
      end if;
      if Inp.Roll_Command > 25.0 then
         Quadrants := Quadrants or 4;
      elsif Inp.Roll_Command < -25.0 then
         Quadrants := Quadrants or 8;
      end if;
      if Inp.Pitch_Command > 25.0 then
         Quadrants := Quadrants or 1;
      elsif Inp.Pitch_Command < -25.0 then
         Quadrants := Quadrants or 2;
      end if;
      for I in 0 .. L.Count - 1 loop
         if Has_Overlay (C.Leds (I), Ov_Indicator) and then (Quadrant (L, C.Leds (I)) and Quadrants) /= 0 then
            S.Buffer (I) := Orange;
         end if;
      end loop;
   end Indicator_Layer;

   --  The ring LEDs run two lit of each sequence around, faster with the
   --  throttle while armed, and alternate at rest; the reference divides
   --  by a rate that reaches zero below a throttle of 880 (finding F89).
   procedure Thrust_Ring_Layer (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Now : Boolean) is
      Ring_Index : Natural := 0;
      Apply      : Boolean;
   begin
      if Now then
         S.Rotation_Phase := (if S.Rotation_Phase > 0 then S.Rotation_Phase - 1 else Unsigned_8 (L.Ring_Seq_Len) - 1);
         declare
            Scaled : constant Integer range -100 .. 300 :=
              (if Inp.Armed
               then Integer (Bounded (Scale (Truncated (Inp.Throttle), 1000, 2000, 0, 100), -100, 300))
               else 0);
         begin
            Add_Us (S.Timer (Tim_Ring), Hz_To_Us (5 + (45 * Scaled) / 100));
         end;
      end if;
      for I in 0 .. L.Count - 1 loop
         pragma Loop_Invariant (Ring_Index <= I);
         if Function_Of (C.Leds (I)) = Fn_Thrust_Ring then
            if Inp.Armed then
               Apply := (Ring_Index + Natural (S.Rotation_Phase)) mod L.Ring_Seq_Len < Sequence_Width;
            else
               Apply := Ring_Index mod 2 = 0;
            end if;
            if Apply then
               S.Buffer (I) := C.Colors (Color_Of (C.Leds (I)));
            end if;
            Ring_Index := Ring_Index + 1;
         end if;
      end loop;
   end Thrust_Ring_Layer;

   procedure Rainbow_Layer (S : in out Strip; C : Settings; L : Layout; Now : Boolean) is
      Index : Natural := 0;
   begin
      if Now then
         S.Rainbow_Offset := S.Rainbow_Offset + Unsigned_32 (C.Rainbow_Freq);
         Add_Us (S.Timer (Tim_Rainbow), Hz_To_Us (60));
      end if;
      for I in 0 .. L.Count - 1 loop
         pragma Loop_Invariant (Index <= I);
         if Has_Overlay (C.Leds (I), Ov_Rainbow) then
            S.Buffer (I) := ((Natural (S.Rainbow_Offset / 60) + Index * Natural (C.Rainbow_Delta)) mod 360, 0, 255);
            Index := Index + 1;
         end if;
      end loop;
   end Rainbow_Layer;

   --  The scanner's eye brightens then moves on, dimming its neighbours.
   procedure Larson_Layer (S : in out Strip; C : Settings; L : Layout; Now : Boolean) is
      Index : Natural := 0;
      Level : Integer;
   begin
      if Now then
         if S.Larson_Brightness > 255 - 15 then
            S.Larson_Brightness := 127;
            if S.Larson_Index >= L.Larson or else S.Larson_Index < 0 then
               S.Larson_Direction := -S.Larson_Direction;
            end if;
            S.Larson_Index := Integer'Max (Larson_Position'First,
                                           Integer'Min (Larson_Position'Last, S.Larson_Index + S.Larson_Direction));
         else
            S.Larson_Brightness := S.Larson_Brightness + 15;
         end if;
         Add_Us (S.Timer (Tim_Larson), Hz_To_Us (60));
      end if;
      for I in 0 .. L.Count - 1 loop
         pragma Loop_Invariant (Index <= I);
         if Has_Overlay (C.Leds (I), Ov_Larson) then
            declare
               Offset : constant Integer := Index - S.Larson_Index;
            begin
               if abs Offset > 1 then
                  Level := 8;
               elsif Offset = 0 then
                  Level := Integer (S.Larson_Brightness);
               elsif S.Larson_Direction = Offset then
                  Level := Integer (S.Larson_Brightness) - 127;
               else
                  Level := 255 - Integer (S.Larson_Brightness);
               end if;
            end;
            S.Buffer (I).V := Unsigned_8 (Level mod 256);
            Index := Index + 1;
         end if;
      end loop;
   end Larson_Layer;

   procedure Blink_Layer (S : in out Strip; C : Settings; L : Layout; Now : Boolean) is
   begin
      if Now then
         S.Blink_Mask := Interfaces.Shift_Right (S.Blink_Mask, 1);
         if S.Blink_Mask <= 1 then
            S.Blink_Mask := 16#8005#;
         end if;
         Add_Us (S.Timer (Tim_Blink), Hz_To_Us (10));
      end if;
      if (S.Blink_Mask and 1) = 0 then
         Apply_Masked (S, C, L, Overlay_Mask (Ov_Blink), C.Colors (C.Specials (Blink_Background)));
      end if;
   end Blink_Layer;

   --  The status profile: every layer whose time came, the fixed layers
   --  first; nothing when no timer fired. The video transmitter layer
   --  waits for the VTX branch and leaves its timer alone.
   procedure Apply_Status (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Advance : out Boolean) is
      Active : Timer_Set := (others => False);
      Any    : Boolean := False;
   begin
      for T in Timer_Id loop
         if not L.Disabled (T) then
            declare
               Elapsed : constant Integer_32 := To_Signed (Inp.Now_Us - S.Timer (T));
            begin
               if Elapsed > Max_Timer_Delay_Us then
                  S.Timer (T) := Inp.Now_Us;
               end if;
               if Elapsed >= 0 then
                  Active (T) := True;
                  Any := True;
               end if;
            end;
         end if;
      end loop;
      Advance := Any;
      if not Any then
         return;
      end if;
      Apply_Fixed_Layers (S, C, L, Inp);
      Rainbow_Layer (S, C, L, Active (Tim_Rainbow));
      Blink_Layer (S, C, L, Active (Tim_Blink));
      Larson_Layer (S, C, L, Active (Tim_Larson));
      Thrust_Ring_Layer (S, C, L, Inp, Active (Tim_Ring));
      Indicator_Layer (S, C, L, Inp, Active (Tim_Indicator));
      GPS_Layer (S, C, L, Inp, Active (Tim_Gps));
      Battery_Layer (S, C, L, Inp, Active (Tim_Battery));
      Rssi_Layer (S, C, L, Inp, Active (Tim_Rssi));
      Warning_Layer (S, C, L, Inp, Active (Tim_Warning));
   end Apply_Status;

   --  The race and beacon profiles: one color for the strip, the race
   --  color flashing white for the beeper switch or failsafe, the beacon
   --  flashing on its period; the strip repainted on a change or every
   --  second. A black race color would follow the video transmitter
   --  frequency and waits for the VTX branch.
   procedure Apply_Simple (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Advance : out Boolean) is
      Current : HSV := Black;
      Period  : Unsigned_32;
      On_For  : Unsigned_32;
   begin
      if C.Prof = Race then
         if C.Race_Color /= 0 then
            Current := C.Colors (C.Race_Color);
         end if;
         if Inp.Beeper_Box or else Inp.Failsafe then
            if Inp.Now_Ms mod 250 < 125 then
               Current := Named (C.Visual_Beeper_Color);
            end if;
         elsif C.Visual_Beeper and then Inp.Beeper_On then
            Current := Named (C.Visual_Beeper_Color);
         end if;
      elsif C.Prof = Beacon then
         Period := Unsigned_32 (C.Beacon_Period);
         On_For := Period * Unsigned_32 (C.Beacon_Percent) / 100;
         if Inp.Now_Ms mod Period < On_For then
            Current := Named (C.Beacon_Color);
         end if;
      end if;
      Advance := Current /= S.Previous_Simple or else To_Signed (Inp.Now_Us - S.Color_Update_Us) >= 0;
      if Advance then
         Set_All (S, L, Current);
         S.Previous_Simple := Current;
         S.Color_Update_Us :=
           Unsigned_32 (Float'Truncation (Float'Min (Float (Inp.Now_Us) + Color_Interval_Us, 4.29e9)));
      end if;
   end Apply_Simple;

   ----------
   -- Init --
   ----------

   procedure Init (S : out Strip; C : Settings; L : Layout) is
   begin
      S := (others => <>);
      S.Enabled := True;
      Set_All (S, L, Black);
      Strip_Update (S, L, 100);
      pragma Unreferenced (C);
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (S : in out Strip; C : Settings; L : Layout; Inp : Inputs; Updated : out Boolean) is
      Advance : Boolean;
   begin
      Updated := False;
      if S.Enabled and then Inp.Led_Low then
         S.Enabled := False;
         Set_All (S, L, Black);
         Strip_Update (S, L, C.Brightness);
         Updated := True;
      elsif not Inp.Led_Low then
         S.Enabled := True;
      end if;
      if S.Enabled then
         if C.Prof = Status then
            Apply_Status (S, C, L, Inp, Advance);
         else
            Apply_Simple (S, C, L, Inp, Advance);
         end if;
         if Advance then
            Strip_Update (S, L, C.Brightness);
            Updated := True;
         end if;
      end if;
   end Update;

   -------------
   -- Parsing --
   -------------

   --  The leading whitespace, sign and digits of a chunk, as the C
   --  library reads them, at most nine digits.
   type Digit_Limits is array (0 .. 9) of Integer_32;
   Limit_Of : constant Digit_Limits :=
     (1, 10, 100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000);

   function Atoi (S : String) return Integer_32
     with Pre => S'First >= 1 and then S'Last <= Max_Text
   is
      Pos      : Natural := S'First;
      Negative : Boolean := False;
      Value    : Integer_32 := 0;
      Digits_N : Natural := 0;
   begin
      while Pos <= S'Last and then S (Pos) in ' ' | ASCII.HT | ASCII.LF | ASCII.VT | ASCII.FF | ASCII.CR loop
         pragma Loop_Invariant (Pos >= S'First);
         pragma Loop_Variant (Increases => Pos);
         Pos := Pos + 1;
      end loop;
      if Pos <= S'Last and then S (Pos) in '+' | '-' then
         Negative := S (Pos) = '-';
         Pos := Pos + 1;
      end if;
      while Pos <= S'Last and then S (Pos) in '0' .. '9' and then Digits_N < 9 loop
         pragma Loop_Invariant (Pos >= S'First and then Value in 0 .. Limit_Of (Digits_N) - 1);
         pragma Loop_Variant (Increases => Pos);
         Value := Value * 10 + Integer_32 (Character'Pos (S (Pos)) - Character'Pos ('0'));
         Digits_N := Digits_N + 1;
         Pos := Pos + 1;
      end loop;
      return (if Negative then -Value else Value);
   end Atoi;

   Max_Chunk : constant := 10;

   --  The chunk up to the separator, at most ten characters long; the
   --  separator must follow where the chunk ends.
   procedure Chunk (Text : String; Pos : in out Natural; Separator : Character; Part : out String; Length : out Natural;
                    OK : out Boolean)
     with Pre => Part'First = 1 and then Part'Length = Max_Chunk and then Text'First = 1
                 and then Text'Last in 0 .. Max_Text and then Pos in Text'First .. Text'Last + 1,
          Post => Pos in Text'First .. Text'Last + 1 and then Length <= Max_Chunk
   is
   begin
      Part := (others => ' ');
      Length := 0;
      while Pos <= Text'Last and then Text (Pos) /= Separator and then Length < Max_Chunk loop
         pragma Loop_Invariant (Pos >= Text'First);
         pragma Loop_Variant (Increases => Pos);
         Length := Length + 1;
         Part (Length) := Text (Pos);
         Pos := Pos + 1;
      end loop;
      if Separator = ASCII.NUL then
         OK := Pos > Text'Last;
      else
         OK := Pos <= Text'Last and then Text (Pos) = Separator;
         if OK then
            Pos := Pos + 1;
         end if;
      end if;
   end Chunk;

   procedure Parse_Led (Text : String; Result : out Unsigned_32; OK : out Boolean) is
      Pos        : Natural := Text'First;
      Part       : String (1 .. Max_Chunk);
      Length     : Natural;
      X, Y, Col  : Integer_32;
      Fn         : Unsigned_32 := 0;
      Overlays   : Unsigned_32 := 0;
      Directions : Unsigned_32 := 0;
      Dir_Codes  : constant String := "NESWUD";
      Fn_Codes   : constant String := "CFALSGRPEU";
      Ov_Codes   : constant String := "TYOBVIW";
   begin
      Result := 0;
      Chunk (Text, Pos, ',', Part, Length, OK);
      if not OK then
         return;
      end if;
      X := Atoi (Part (1 .. Length));
      Chunk (Text, Pos, ':', Part, Length, OK);
      if not OK then
         return;
      end if;
      Y := Atoi (Part (1 .. Length));
      Chunk (Text, Pos, ':', Part, Length, OK);
      if not OK then
         return;
      end if;
      for I in 1 .. Length loop
         for D in Dir_Codes'Range loop
            if Part (I) = Dir_Codes (D) then
               Directions := Directions or Interfaces.Shift_Left (1, D - 1);
            end if;
         end loop;
      end loop;
      Chunk (Text, Pos, ':', Part, Length, OK);
      if not OK then
         return;
      end if;
      for I in 1 .. Length loop
         for F in Fn_Codes'Range loop
            if Part (I) = Fn_Codes (F) then
               Fn := Unsigned_32 (F - 1);
            end if;
         end loop;
         for O in Ov_Codes'Range loop
            if Part (I) = Ov_Codes (O) then
               Overlays := Overlays or Interfaces.Shift_Left (1, O - 1);
            end if;
         end loop;
      end loop;
      Chunk (Text, Pos, ASCII.NUL, Part, Length, OK);
      if not OK or else Pos <= Text'Last then
         OK := False;
         return;
      end if;
      Col := Atoi (Part (1 .. Length));
      if Col >= Color_Count then
         Col := 0;
      end if;
      Result := Interfaces.Shift_Left (Unsigned_32 (X mod 16), 4) or Unsigned_32 (Y mod 16)
        or Interfaces.Shift_Left (Unsigned_32 (Col mod 2 ** 10), Color_Offset)
        or Interfaces.Shift_Left (Directions, Direction_Offset)
        or Interfaces.Shift_Left (Fn, Function_Offset)
        or Interfaces.Shift_Left (Overlays, Overlay_Offset);
   end Parse_Led;

   --  Three values separated by commas, each within its limit; a failure
   --  leaves black.
   procedure Parse_Color (Text : String; Result : out HSV; OK : out Boolean) is
      Pos    : Natural := Text'First;
      Values : array (0 .. 2) of Integer_32 := (others => 0);
      Limits : constant array (0 .. 2) of Integer_32 := (359, 255, 255);
   begin
      Result := Black;
      OK := True;
      for I in Values'Range loop
         pragma Loop_Invariant (Pos in Text'First .. Text'Last + 1);
         pragma Loop_Invariant (for all J in 0 .. I - 1 => Values (J) in 0 .. Limits (J));
         Values (I) := Atoi (Text (Pos .. Text'Last));
         if Values (I) > Limits (I) or else Values (I) < 0 then
            OK := False;
            return;
         end if;
         while Pos <= Text'Last and then Text (Pos) /= ',' loop
            pragma Loop_Invariant (Pos >= Text'First);
            pragma Loop_Variant (Increases => Pos);
            Pos := Pos + 1;
         end loop;
         if Pos <= Text'Last then
            Pos := Pos + 1;
         elsif I < 2 then
            OK := False;
            return;
         end if;
      end loop;
      Result := (Natural (Values (0)), Unsigned_8 (Values (1)), Unsigned_8 (Values (2)));
   end Parse_Color;

end Adaflight.LED_Strip;
