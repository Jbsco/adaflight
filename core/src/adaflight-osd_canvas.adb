package body Adaflight.OSD_Canvas with SPARK_Mode is
   use type Interfaces.Unsigned_16;

   procedure Fit
     (O : in out Osd_Config_Record; E : in out Osd_Element_Config_Record; Rows, Cols : Interfaces.Unsigned_8)
   is
   begin
      if Cols = 0 or else Rows = 0 then
         return;
      end if;
      O.Canvas_Cols := Cols;
      O.Canvas_Rows := Rows;
      for I in E.Item_Pos'Range loop
         declare
            Pos   : constant Interfaces.Unsigned_16 := E.Item_Pos (I);
            X     : Interfaces.Unsigned_8 := Adaflight.OSD_Elements.Column (Pos);
            Y     : Interfaces.Unsigned_8 := Adaflight.OSD_Elements.Row (Pos);
            Reset : Boolean := False;
         begin
            if X >= Cols then
               X := Cols - 1;
               Reset := True;
            end if;
            if Y >= Rows then
               Y := Rows - 1;
               Reset := True;
            end if;
            if Reset then
               E.Item_Pos (I) := (Pos and Kept_Mask) or Adaflight.OSD_Elements.Make_Position (X, Y);
            end if;
         end;
         pragma Loop_Invariant (for all J in E.Item_Pos'First .. I => On_Canvas (E.Item_Pos (J), Rows, Cols));
         pragma Loop_Invariant
           (for all J in I + 1 .. E.Item_Pos'Last => E.Item_Pos (J) = E.Item_Pos'Loop_Entry (J));
      end loop;
   end Fit;

end Adaflight.OSD_Canvas;
