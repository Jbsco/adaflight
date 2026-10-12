with Adaflight.Clock;
with Adaflight.Maths;

package body Adaflight.Nav_Trail with SPARK_Mode is

   use type Interfaces.Integer_64;
   use type Interfaces.Integer_32;

   --  Whole metres from centimetres, rounded to the nearest and held in
   --  sixteen bits; a value past forty kilometres lands on the bound either
   --  way.
   function Metres (Cm : Position_Cm) return Integer_16 is
      Scaled  : constant Float := Float'Max (-40_000.0, Float'Min (40_000.0, Cm / 100.0));
      Rounded : constant Integer := Adaflight.Maths.Round_Half_Even (Scaled);
   begin
      return Integer_16 (Integer'Max (-32_768, Integer'Min (32_767, Rounded)));
   end Metres;

   --  A point at the end; a full store keeps every second point and doubles
   --  the spacing first.
   procedure Push (T : in out Trail; P : Point) is
   begin
      while T.Length = Capacity loop
         pragma Loop_Variant (Decreases => T.Length);
         for I in 0 .. T.Length / 2 - 1 loop
            T.Points (I) := T.Points (2 * I + 1);
         end loop;
         T.Length := T.Length / 2;
         T.Spacing_Now := Spacing (Unsigned_32'Min (Unsigned_32 (T.Spacing_Now) * 2, Max_Spacing_M));
      end loop;
      T.Points (T.Length) := P;
      T.Length := T.Length + 1;
   end Push;

   -----------
   -- Reset --
   -----------

   procedure Reset (T : in out Trail) is
   begin
      T.Length := 0;
      T.Spacing_Now := Spacing_M;
   end Reset;

   ------------
   -- Ingest --
   ------------

   procedure Ingest (T : in out Trail; East_Cm, North_Cm : Position_Cm) is
      P : constant Point := (East_M => Metres (East_Cm), North_M => Metres (North_Cm));
   begin
      if T.Length = 0 then
         Push (T, P);
         return;
      end if;
      declare
         Last : constant Point := T.Points (T.Length - 1);
         Dx   : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (P.East_M) - Interfaces.Integer_64 (Last.East_M);
         Dy   : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (P.North_M) - Interfaces.Integer_64 (Last.North_M);
         S    : constant Interfaces.Integer_64 := Interfaces.Integer_64 (T.Spacing_Now);
      begin
         if Dx * Dx + Dy * Dy >= S * S then
            Push (T, P);
         end if;
      end;
   end Ingest;

   ------------
   -- Update --
   ------------

   procedure Update (T : in out Trail; Now_Us : Unsigned_32; Armed, Fix, Fix_Home : Boolean;
                     East_Cm, North_Cm : Position_Cm) is
   begin
      if Armed and then not T.Was_Armed then
         Reset (T);
      end if;
      T.Was_Armed := Armed;
      if T.Last_Update_Us /= 0 and then Adaflight.Clock.Elapsed (Now_Us, T.Last_Update_Us) < Update_Interval_Us then
         return;
      end if;
      T.Last_Update_Us := Now_Us;
      if not Armed or else not Fix or else not Fix_Home then
         return;
      end if;
      Ingest (T, East_Cm, North_Cm);
   end Update;

   --------------
   -- Point_At --
   --------------

   function Point_At (T : Trail; I : Natural) return Point is (T.Points (I));

end Adaflight.Nav_Trail;
