package body Adaflight.OSD_Spec with SPARK_Mode is
   use Adaflight.OSD_Format;

   type Names is array (Throttle_Limit_Kind) of String (1 .. 5);
   Limit_Names   : constant Names := ("OFF  ", "SCALE", "CLIP ");
   Limit_Lengths : constant array (Throttle_Limit_Kind) of Positive := (3, 5, 4);

   procedure Draw
     (S : in out State; C : Settings; Inp : Inputs; Rows, Cols : Unsigned_8; Version : String; X, Y : out Unsigned_8;
      Line : out Adaflight.OSD_Format.Text; Complete : out Boolean)
   is
      Mid_Row : constant Integer := Integer (Rows / 2);
      Mid_Col : constant Integer := Integer (Cols / 2);
      Row     : constant Integer range -3 .. 130 := (if S.Next = RPM then Mid_Row - 3 else S.Row);
      Next    : Row_Kind;
   begin
      Line := (others => <>);
      Complete := False;
      case S.Next is
         when RPM =>
            if C.RPM_Limit and then Inp.Bidir_DShot then
               Append_String (Line, "RPM LIMIT ON  ");
               Append_Natural (Line, Natural (C.RPM_Limit_Value), 1, False);
               Next := Poles;
            else
               Append_String (Line, "RPM LIMIT OFF");
               Next := Throttle;
            end if;
         when Poles =>
            Append_String (Line, "KV ");
            Append_Natural (Line, Natural (C.KV), 1, False);
            Append_String (Line, "   POLES ");
            Append_Natural (Line, Natural (C.Pole_Count), 1, False);
            Next := Mixer;
         when Mixer =>
            Append_Natural (Line, Natural (C.RPM_Limit_P), 1, False);
            Append_String (Line, "  ");
            Append_Natural (Line, Natural (C.RPM_Limit_I), 1, False);
            Append_String (Line, "  ");
            Append_Natural (Line, Natural (C.RPM_Limit_D), 1, False);
            Next := Throttle;
         when Throttle =>
            Append_String (Line, "THR LIMIT ");
            Append_String (Line, Limit_Names (C.Throttle_Limit) (1 .. Limit_Lengths (C.Throttle_Limit)));
            if C.Throttle_Limit /= 0 then
               Append (Line, ' ');
               Append_Natural (Line, Natural (C.Throttle_Limit_Percent), 1, False);
            end if;
            Next := Motor;
         when Motor =>
            Append_String (Line, "MOTOR LIMIT ");
            Append_Natural (Line, Natural (C.Motor_Output_Limit), 1, False);
            Next := Battery_Row;
         when Battery_Row =>
            Print_Float (Line, Battery_Symbol (Natural (Inp.Cell_Voltage), Inp.Battery, C.Min_Cell, C.Max_Cell),
                         Float (Inp.Pack_Voltage) / 100.0, Default_Format, 2, True, Symbol_Volt);
            Next := Version_Row;
         when Version_Row =>
            Append_String (Line, Version);
            Next := RPM;
            Complete := True;
      end case;
      X := Unsigned_8 ((Mid_Col - Line.Length / 2) mod 256);
      Y := Unsigned_8 (Row mod 256);
      S := (Next => Next, Row => Row + 1);
   end Draw;

end Adaflight.OSD_Spec;
