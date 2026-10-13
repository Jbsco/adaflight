--  The OSD draw cycle: the active elements drawn one call at a time into
--  the element buffer and handed to the display. A display without a
--  background layer gets each element's background before its foreground;
--  the system elements go to the display as they are; an element whose
--  blink is in its hidden half is skipped unless the display blinks it
--  itself; and the background pass fills a background layer when the
--  elements are analyzed. The display operations go back to the target in
--  order; settings, sensors and readings stay with the target.
with Interfaces;
with Adaflight.OSD_Elements;
with Adaflight.OSD_Format;
with Adaflight.OSD_Render;
with Adaflight.OSD_Warnings;

package Adaflight.OSD_Draw with SPARK_Mode is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Integer_32;
   use type Adaflight.OSD_Elements.Item;
   use all type Adaflight.OSD_Elements.Item;

   subtype Unsigned_8 is Interfaces.Unsigned_8;
   subtype Item is Adaflight.OSD_Elements.Item;

   type Layer is (Foreground, Background);

   --  A display operation: a string at a position with its attribute, a
   --  system element at a position, a layer selection, a screen clear that
   --  waits, or a background redraw.
   type Op_Kind is (Write, Write_Sys, Select_Layer, Clear_Screen, Redraw_Background);
   type Op is record
      Kind   : Op_Kind := Write;
      X, Y   : Unsigned_8 := 0;
      Attr   : Unsigned_8 := 0;
      Line   : Adaflight.OSD_Format.Text;
      Sys    : Natural range 0 .. 10 := 0;
      Target : Layer := Foreground;
   end record;

   Max_Ops : constant := 64;
   type Op_Array is array (1 .. Max_Ops) of Op;
   type Ops is record
      List  : Op_Array;
      Count : Natural range 0 .. Max_Ops := 0;
   end record;

   Blink_Attribute : constant Unsigned_8 := 16#80#;

   --  The cycle: whether the display has a background layer, the element
   --  on turn, whether its background is drawn, the pending writes, the
   --  element last set up with its position, offsets and attribute, and the
   --  element buffer, which keeps its text until a write empties it.
   type Cycle is record
      Background_Layer    : Boolean := False;
      Active_Number       : Natural range 0 .. Adaflight.OSD_Elements.Max_Active := 0;
      Background_Rendered : Boolean := False;
      Pending_Foreground  : Boolean := False;
      Pending_Background  : Boolean := False;
      Element             : Item := Item'First;
      Pos_X, Pos_Y        : Unsigned_8 := 0;
      Offset_X, Offset_Y  : Unsigned_8 := 0;
      Attr                : Adaflight.OSD_Warnings.Severity := Adaflight.OSD_Warnings.Normal;
      Buffer              : Adaflight.OSD_Format.Text;
   end record;

   function Render_Pending (Cy : Cycle) return Boolean is (Cy.Pending_Foreground or else Cy.Pending_Background);

   --  What the renderers read: the settings, the readings, the warnings'
   --  settings and readings, and whether the craft name messages are on.
   type Context is record
      Settings            : Adaflight.OSD_Render.Settings;
      Inputs              : Adaflight.OSD_Render.Inputs;
      Warn_Settings       : Adaflight.OSD_Warnings.Settings;
      Warn_Inputs         : Adaflight.OSD_Warnings.Inputs;
      Craft_Name_Messages : Boolean := False;
   end record;

   function Context_Valid (X : Context) return Boolean is
     (X.Inputs.Min_Cell /= X.Inputs.Max_Cell and then X.Inputs.Date.Month in 1 .. 12
      and then Interfaces.Integer_32 (Float'Truncation (X.Inputs.Output_High))
               > Interfaces.Integer_32 (Float'Truncation (X.Inputs.Output_Low)));

   --  The elements with a foreground: the rendered ones, the warnings and
   --  the system elements.
   function Has_Foreground (I : Item) return Boolean is
     (Adaflight.OSD_Render.Supported (I) or else I = Warnings or else I in Sys_Goggle_Voltage .. Sys_Fan_Speed);

   procedure Init (Cy : out Cycle; Background_Layer : Boolean)
     with Post => Cy.Background_Layer = Background_Layer and then Cy.Active_Number = 0;

   --  One call of the cycle: the element on turn's background where the
   --  display has no background layer and it is not yet drawn, else its
   --  foreground, moving to the next element once it is complete; false
   --  after the last element, which starts the cycle again.
   procedure Draw_Next
     (Cy : in out Cycle; A : Adaflight.OSD_Elements.Active_List; Pos : Adaflight.OSD_Elements.Positions;
      B : in out Adaflight.OSD_Elements.Blink; Device_Blink : Boolean; S : in out Adaflight.OSD_Render.State;
      WS : in out Adaflight.OSD_Warnings.State; X : Context; Craft : in out Adaflight.OSD_Render.Craft_Name_Buffer;
      More : out Boolean; O : out Ops)
     with Pre => Context_Valid (X) and then S.ESC_Motor < Unsigned_8 (X.Inputs.Motors);

   --  The pending write: the background's, then the foreground's on the
   --  next call; true while the foreground still waits.
   procedure Display_Active
     (Cy : in out Cycle; A : Adaflight.OSD_Elements.Active_List; B : Adaflight.OSD_Elements.Blink; More : out Boolean;
      O : out Ops);

   --  The background pass after an analysis: with a background layer, the
   --  layer cleared and every active element's background drawn to
   --  completion into it; without, a background redraw.
   procedure Draw_Backgrounds
     (Cy : in out Cycle; A : Adaflight.OSD_Elements.Active_List; Pos : Adaflight.OSD_Elements.Positions;
      B : Adaflight.OSD_Elements.Blink; S : in out Adaflight.OSD_Render.State; X : Context;
      Craft : Adaflight.OSD_Render.Craft_Name_Buffer; O : out Ops);

end Adaflight.OSD_Draw;
