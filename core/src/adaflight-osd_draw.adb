package body Adaflight.OSD_Draw with SPARK_Mode is
   use Adaflight.OSD_Elements;

   procedure Add (O : in out Ops; P : Op)
     with Global => null,
          Post   => O.Count = Natural'Min (Max_Ops, O.Count'Old + 1)
   is
   begin
      if O.Count < Max_Ops then
         O.Count := O.Count + 1;
         O.List (O.Count) := P;
      end if;
   end Add;

   function To_Name (Craft : Adaflight.OSD_Render.Craft_Name_Buffer) return Adaflight.OSD_Render.Name is
      N : Adaflight.OSD_Render.Name;
   begin
      for K in 1 .. Adaflight.OSD_Render.Max_Name loop
         exit when Craft (K) = Character'Val (0);
         pragma Loop_Invariant (N.Length = K - 1);
         N.Data (K) := Craft (K);
         N.Length := K;
      end loop;
      return N;
   end To_Name;

   procedure Add_Writes (O : in out Ops; R : Adaflight.OSD_Render.Output)
     with Global => null
   is
   begin
      for K in 1 .. R.Written loop
         declare
            T : Adaflight.OSD_Format.Text;
         begin
            Adaflight.OSD_Format.Append (T, R.Writes (K).Char);
            if R.Writes (K).Char /= Character'Val (0) then
               Add (O, (Kind => Write, X => R.Writes (K).X, Y => R.Writes (K).Y, Attr => R.Writes (K).Attr, Line => T,
                        others => <>));
            end if;
         end;
      end loop;
   end Add_Writes;

   procedure Take (Cy : in out Cycle; R : Adaflight.OSD_Render.Output)
     with Global => null,
          Post   => Cy.Active_Number = Cy.Active_Number'Old
   is
   begin
      Cy.Offset_X := R.Offset_X;
      Cy.Offset_Y := R.Offset_Y;
      Cy.Attr := R.Attr;
      if R.Wrote then
         Cy.Buffer := R.Line;
      end if;
   end Take;

   procedure Set_Up (Cy : in out Cycle; I : Item; Pos : Positions)
     with Global => null,
          Post   => Cy.Active_Number = Cy.Active_Number'Old
   is
   begin
      Cy.Element := I;
      Cy.Pos_X := Column (Pos (I));
      Cy.Pos_Y := Row (Pos (I));
      Cy.Offset_X := 0;
      Cy.Offset_Y := 0;
      Cy.Attr := Adaflight.OSD_Warnings.Normal;
   end Set_Up;

   procedure Draw_Background
     (Cy : in out Cycle; I : Item; Pos : Positions; B : Blink; S : in out Adaflight.OSD_Render.State; X : Context;
      Craft : Adaflight.OSD_Render.Craft_Name_Buffer; O : in out Ops; Rendered : out Boolean)
     with Global => null,
          Post   => Cy.Active_Number = Cy.Active_Number'Old
   is
      Inp : Adaflight.OSD_Render.Inputs := X.Inputs;
      R   : Adaflight.OSD_Render.Output;
   begin
      if not Adaflight.OSD_Render.Background_Supported (I) then
         Rendered := True;
         return;
      end if;
      Set_Up (Cy, I, Pos);
      Inp.Item_Blinks := B.Bits (I);
      Inp.Craft_Name := To_Name (Craft);
      Adaflight.OSD_Render.Render_Background (I, S, X.Settings, Inp, Cy.Pos_X, Cy.Pos_Y, R);
      Add_Writes (O, R);
      Take (Cy, R);
      if R.Draw then
         Cy.Pending_Background := True;
      end if;
      Rendered := R.Rendered;
   end Draw_Background;

   procedure Draw_Element
     (Cy : in out Cycle; I : Item; Pos : Positions; B : in out Blink; Device_Blink : Boolean;
      S : in out Adaflight.OSD_Render.State; WS : in out Adaflight.OSD_Warnings.State; X : Context;
      Craft : in out Adaflight.OSD_Render.Craft_Name_Buffer; O : in out Ops; Rendered : out Boolean)
     with Global => null,
          Pre    => Context_Valid (X) and then S.ESC_Motor < Unsigned_8 (X.Inputs.Motors),
          Post   => Cy.Active_Number = Cy.Active_Number'Old
   is
      Inp      : Adaflight.OSD_Render.Inputs := X.Inputs;
      R        : Adaflight.OSD_Render.Output;
      Reported : Adaflight.OSD_Warnings.Reports;
   begin
      Rendered := True;
      if not Has_Foreground (I) or else (not Device_Blink and then Is_Blink (B, I)) then
         return;
      end if;
      Set_Up (Cy, I, Pos);
      if I in Sys_Goggle_Voltage .. Sys_Fan_Speed then
         Add (O, (Kind => Write_Sys, X => Cy.Pos_X, Y => Cy.Pos_Y, Sys => Item'Pos (I) - Item'Pos (Sys_Goggle_Voltage),
                  others => <>));
         return;
      end if;
      if I = Warnings then
         Adaflight.OSD_Render.Render_Warnings
           (WS, X.Warn_Settings, X.Warn_Inputs, X.Craft_Name_Messages, B.State, Inp, Craft, R, Reported);
         O.Reported := Reported;
      elsif I = Nav_Map then
         Adaflight.OSD_Render.Render_Nav_Map (S, X.Settings, Inp, Cy.Pos_X, Cy.Pos_Y, R);
      else
         Inp.Item_Blinks := B.Bits (I);
         Adaflight.OSD_Render.Render (I, Variant (Pos (I)), S, X.Settings, Inp, R);
      end if;
      case R.Blink is
         when Adaflight.OSD_Render.Set => B.Bits (I) := True;
         when Adaflight.OSD_Render.Clear => B.Bits (I) := False;
         when Adaflight.OSD_Render.Keep => null;
      end case;
      Add_Writes (O, R);
      Take (Cy, R);
      if R.Draw then
         Cy.Pending_Foreground := True;
      end if;
      Rendered := R.Rendered;
   end Draw_Element;

   procedure Init (Cy : out Cycle; Background_Layer : Boolean) is
   begin
      Cy := (Background_Layer => Background_Layer, others => <>);
   end Init;

   procedure Draw_Next
     (Cy : in out Cycle; A : Active_List; Pos : Positions; B : in out Blink; Device_Blink : Boolean;
      S : in out Adaflight.OSD_Render.State; WS : in out Adaflight.OSD_Warnings.State; X : Context;
      Craft : in out Adaflight.OSD_Render.Craft_Name_Buffer; More : out Boolean; O : out Ops)
   is
      I        : Item;
      Rendered : Boolean;
   begin
      O := (others => <>);
      if Cy.Active_Number >= A.Count then
         Cy.Active_Number := 0;
         More := False;
         return;
      end if;
      I := A.Items (Cy.Active_Number + 1);
      if not Cy.Background_Layer and then Adaflight.OSD_Render.Background_Supported (I)
        and then not Cy.Background_Rendered
      then
         Draw_Background (Cy, I, Pos, B, S, X, Craft, O, Rendered);
         Cy.Background_Rendered := Rendered;
         More := True;
         return;
      end if;
      Draw_Element (Cy, I, Pos, B, Device_Blink, S, WS, X, Craft, O, Rendered);
      More := True;
      if Rendered then
         Cy.Background_Rendered := False;
         Cy.Active_Number := Cy.Active_Number + 1;
         if Cy.Active_Number >= A.Count then
            Cy.Active_Number := 0;
            More := False;
         end if;
      end if;
   end Draw_Next;

   procedure Write_Buffer (Cy : in out Cycle; B : Blink; O : in out Ops)
     with Global => null
   is
      Attr : Unsigned_8 := Adaflight.OSD_Warnings.Severity'Pos (Cy.Attr);
   begin
      if B.Bits (Cy.Element) then
         Attr := Attr or Blink_Attribute;
      end if;
      if Cy.Buffer.Length > 0 then
         Add (O, (Kind => Write, X => Cy.Pos_X + Cy.Offset_X, Y => Cy.Pos_Y + Cy.Offset_Y, Attr => Attr,
                  Line => Cy.Buffer, others => <>));
      end if;
      Cy.Buffer.Length := 0;
   end Write_Buffer;

   procedure Display_Active (Cy : in out Cycle; A : Active_List; B : Blink; More : out Boolean; O : out Ops) is
   begin
      O := (others => <>);
      More := False;
      if Cy.Active_Number >= A.Count then
         return;
      end if;
      if Cy.Pending_Background then
         Write_Buffer (Cy, B, O);
         Cy.Pending_Background := False;
         More := Cy.Pending_Foreground;
         return;
      end if;
      if Cy.Pending_Foreground then
         Write_Buffer (Cy, B, O);
         Cy.Pending_Foreground := False;
      end if;
   end Display_Active;

   Background_Attempts : constant := 32;

   procedure Draw_Backgrounds
     (Cy : in out Cycle; A : Active_List; Pos : Positions; B : Blink; S : in out Adaflight.OSD_Render.State;
      X : Context; Craft : Adaflight.OSD_Render.Craft_Name_Buffer; O : out Ops)
   is
      Rendered : Boolean;
   begin
      O := (others => <>);
      if Cy.Background_Layer then
         Add (O, (Kind => Select_Layer, Target => Background, others => <>));
         Add (O, (Kind => Clear_Screen, Attr => 1, others => <>));
         for K in 1 .. A.Count loop
            pragma Loop_Invariant (Cy.Active_Number = Cy.Active_Number'Loop_Entry);
            for Attempt in 1 .. Background_Attempts loop
               pragma Loop_Invariant (Cy.Active_Number = Cy.Active_Number'Loop_Entry);
               Draw_Background (Cy, A.Items (K), Pos, B, S, X, Craft, O, Rendered);
               exit when Rendered;
            end loop;
         end loop;
         Add (O, (Kind => Select_Layer, Target => Foreground, others => <>));
      else
         Add (O, (Kind => Redraw_Background, others => <>));
      end if;
   end Draw_Backgrounds;

end Adaflight.OSD_Draw;
