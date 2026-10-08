with Ada.Numerics.Elementary_Functions;

package body Adaflight.Vectors with SPARK_Mode is

   ---------
   -- Add --
   ---------

   function Add (A : Vector2; B : Vector2) return Vector2 is
     (X => A.X + B.X, Y => A.Y + B.Y);

   function Add (A : Vector3; B : Vector3) return Vector3 is
     (X => A.X + B.X, Y => A.Y + B.Y, Z => A.Z + B.Z);

   ---------
   -- Sub --
   ---------

   function Sub (A : Vector2; B : Vector2) return Vector2 is
     (X => A.X - B.X, Y => A.Y - B.Y);

   function Sub (A : Vector3; B : Vector3) return Vector3 is
     (X => A.X - B.X, Y => A.Y - B.Y, Z => A.Z - B.Z);

   -----------
   -- Scale --
   -----------

   function Scale (V : Vector2; K : Float) return Vector2 is
     (X => V.X * K, Y => V.Y * K);

   function Scale (V : Vector3; K : Float) return Vector3 is
     (X => V.X * K, Y => V.Y * K, Z => V.Z * K);

   ---------
   -- Dot --
   ---------

   function Dot (A : Vector2; B : Vector2) return Float is
     (A.X * B.X + A.Y * B.Y);

   function Dot (A : Vector3; B : Vector3) return Float is
     (A.X * B.X + A.Y * B.Y + A.Z * B.Z);

   -----------
   -- Cross --
   -----------

   function Cross (A : Vector2; B : Vector2) return Float is
     (A.X * B.Y - A.Y * B.X);

   function Cross (A : Vector3; B : Vector3) return Vector3 is
     (X => A.Y * B.Z - A.Z * B.Y,
      Y => A.Z * B.X - A.X * B.Z,
      Z => A.X * B.Y - A.Y * B.X);

   -------------
   -- Norm_Sq --
   -------------

   function Norm_Sq (V : Vector2) return Float is (Dot (V, V));

   function Norm_Sq (V : Vector3) return Float is (Dot (V, V));

   ----------
   -- Norm --
   ----------

   function Norm (V : Vector2) return Float is
     (Ada.Numerics.Elementary_Functions.Sqrt (Norm_Sq (V)));

   function Norm (V : Vector3) return Float is
     (Ada.Numerics.Elementary_Functions.Sqrt (Norm_Sq (V)));

   ---------------
   -- Normalize --
   ---------------

   function Unit (C : Float) return Float is (Constrain_F (C, -1.0, 1.0))
     with Inline, Post => abs Unit'Result <= 1.0;

   --  The root of a positive squared norm, held above the root of the
   --  smallest positive float so that its reciprocal is finite.
   Min_Root : constant := 2.0 ** (-75);

   function Positive_Root (Sq : Float) return Float is
     (Float'Max (Min_Root, Ada.Numerics.Elementary_Functions.Sqrt (Sq)))
     with Inline, Pre => Sq > 0.0, Post => Positive_Root'Result >= Min_Root;

   function Normalize (V : Vector2) return Vector2 is
      Sq : constant Float := Norm_Sq (V);
   begin
      if Sq > 0.0 then
         declare
            K : constant Float := 1.0 / Positive_Root (Sq);
         begin
            return (X => Unit (V.X * K), Y => Unit (V.Y * K));
         end;
      else
         return (X => 0.0, Y => 0.0);
      end if;
   end Normalize;

   function Normalize (V : Vector3) return Vector3 is
      Sq : constant Float := Norm_Sq (V);
   begin
      if Sq > 0.0 then
         declare
            K : constant Float := 1.0 / Positive_Root (Sq);
         begin
            return (X => Unit (V.X * K), Y => Unit (V.Y * K), Z => Unit (V.Z * K));
         end;
      else
         return (X => 0.0, Y => 0.0, Z => 0.0);
      end if;
   end Normalize;

   ------------
   -- Rotate --
   ------------

   function Rotate (V : Vector2; Angle_Rad : Angle) return Vector2 is
      S : Cosine;
      C : Cosine;
   begin
      Sin_Cos_Approx (Angle_Rad, S, C);
      return (X => V.X * C - V.Y * S, Y => V.X * S + V.Y * C);
   end Rotate;

   --------------
   -- Multiply --
   --------------

   function Multiply (M : Matrix33; V : Vector3) return Vector3 is
     (X => M (X, X) * V.X + M (X, Y) * V.Y + M (X, Z) * V.Z,
      Y => M (Y, X) * V.X + M (Y, Y) * V.Y + M (Y, Z) * V.Z,
      Z => M (Z, X) * V.X + M (Z, Y) * V.Y + M (Z, Z) * V.Z);

   -------------------------
   -- Multiply_Transposed --
   -------------------------

   function Multiply_Transposed (M : Matrix33; V : Vector3) return Vector3 is
     (X => M (X, X) * V.X + M (Y, X) * V.Y + M (Z, X) * V.Z,
      Y => M (X, Y) * V.X + M (Y, Y) * V.Y + M (Z, Y) * V.Z,
      Z => M (X, Z) * V.X + M (Y, Z) * V.Y + M (Z, Z) * V.Z);

   ---------------------
   -- Rotation_Matrix --
   ---------------------

   function Rotation_Matrix (RPY : Euler_Angles) return Matrix33 is
      Sin_X, Cos_X : Cosine;
      Sin_Y, Cos_Y : Cosine;
      Sin_Z, Cos_Z : Cosine;
   begin
      Sin_Cos_Approx (RPY.Roll, Sin_X, Cos_X);
      Sin_Cos_Approx (RPY.Pitch, Sin_Y, Cos_Y);
      Sin_Cos_Approx (RPY.Yaw, Sin_Z, Cos_Z);
      return
        (X => (X => Cos_Z * Cos_Y,
               Y => -Cos_Y * Sin_Z,
               Z => Sin_Y),
         Y => (X => Sin_Z * Cos_X + Sin_X * Cos_Z * Sin_Y,
               Y => Cos_Z * Cos_X - Sin_X * Sin_Z * Sin_Y,
               Z => -Sin_X * Cos_Y),
         Z => (X => Sin_X * Sin_Z - Cos_Z * Cos_X * Sin_Y,
               Y => Sin_X * Cos_Z + Sin_Z * Cos_X * Sin_Y,
               Z => Cos_Y * Cos_X));
   end Rotation_Matrix;

   --------------------
   -- Apply_Rotation --
   --------------------

   function Apply_Rotation (V : Vector3; M : Matrix33) return Vector3 is
     (Multiply_Transposed (M, V));

   --------------------
   -- Yaw_Rotation_Z --
   --------------------

   function Yaw_Rotation_Z (Yaw : Angle) return Matrix33 is
      Sin_Yaw, Cos_Yaw : Cosine;
   begin
      Sin_Cos_Approx (Yaw, Sin_Yaw, Cos_Yaw);
      return
        (X => (Cos_Yaw, -Sin_Yaw, 0.0),
         Y => (Sin_Yaw, Cos_Yaw, 0.0),
         Z => (0.0, 0.0, 1.0));
   end Yaw_Rotation_Z;

end Adaflight.Vectors;
