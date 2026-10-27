--  The OSD's canvas as its display starts: the stored canvas takes the
--  display's columns and rows, and an element placed past either is moved to
--  the last column or row with its profiles and variant kept. A display that
--  reports no columns or no rows changes nothing.
with Interfaces;
with Adaflight.Config_Groups; use Adaflight.Config_Groups;
with Adaflight.OSD_Elements;

package Adaflight.OSD_Canvas with SPARK_Mode is
   use type Interfaces.Unsigned_8;

   --  The profile and variant bits of a position.
   Kept_Mask : constant Interfaces.Unsigned_16 := 16#F800#;

   function On_Canvas (P : Interfaces.Unsigned_16; Rows, Cols : Interfaces.Unsigned_8) return Boolean is
     (Adaflight.OSD_Elements.Column (P) < Cols and then Adaflight.OSD_Elements.Row (P) < Rows);

   procedure Fit
     (O : in out Osd_Config_Record; E : in out Osd_Element_Config_Record; Rows, Cols : Interfaces.Unsigned_8)
     with Global => null,
          Post   =>
            (if Rows > 0 and then Cols > 0
             then O.Canvas_Rows = Rows and then O.Canvas_Cols = Cols
                  and then (for all I in E.Item_Pos'Range => On_Canvas (E.Item_Pos (I), Rows, Cols))
             else O = O'Old and then E = E'Old);

end Adaflight.OSD_Canvas;
