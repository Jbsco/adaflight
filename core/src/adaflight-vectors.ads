--  Two and three dimensional vectors, rotation matrices, and the Euler
--  angle construction of a body to earth rotation.
--
--  Components are unbounded floats. Each operation states the input bound
--  under which it cannot overflow, so a caller proves finiteness from the
--  physical range of what it holds instead of a universal type bound.

with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.Vectors with SPARK_Mode, Pure is

   type Coordinate is (X, Y, Z);

   type Vector2 is record
      X : Float := 0.0;
      Y : Float := 0.0;
   end record;

   type Vector3 is record
      X : Float := 0.0;
      Y : Float := 0.0;
      Z : Float := 0.0;
   end record;

   type Matrix33 is array (Coordinate, Coordinate) of Float;

   Identity : constant Matrix33 :=
     (X => (1.0, 0.0, 0.0), Y => (0.0, 1.0, 0.0), Z => (0.0, 0.0, 1.0));

   --  Bounds under which sums and products of components stay finite.
   Linear_Bound  : constant := 2.0 ** 60;
   Rotation_Bound : constant := 2.0 ** 40;

   function Bounded (V : Vector2; Bound : Float) return Boolean is
     (abs V.X <= Bound and then abs V.Y <= Bound);

   function Bounded (V : Vector3; Bound : Float) return Boolean is
     (abs V.X <= Bound and then abs V.Y <= Bound and then abs V.Z <= Bound);

   function Bounded (M : Matrix33; Bound : Float) return Boolean is
     (abs M (X, X) <= Bound and then abs M (X, Y) <= Bound and then abs M (X, Z) <= Bound
      and then abs M (Y, X) <= Bound and then abs M (Y, Y) <= Bound and then abs M (Y, Z) <= Bound
      and then abs M (Z, X) <= Bound and then abs M (Z, Y) <= Bound and then abs M (Z, Z) <= Bound);

   ---------------------------------------------------------------------------
   --  Two dimensions
   ---------------------------------------------------------------------------

   function Equal (A : Vector2; B : Vector2) return Boolean is
     (A.X = B.X and then A.Y = B.Y);

   function Add (A : Vector2; B : Vector2) return Vector2
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Sub (A : Vector2; B : Vector2) return Vector2
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Scale (V : Vector2; K : Float) return Vector2
     with Pre => Bounded (V, Linear_Bound) and then abs K <= Linear_Bound;

   function Dot (A : Vector2; B : Vector2) return Float
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Cross (A : Vector2; B : Vector2) return Float
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Norm_Sq (V : Vector2) return Float
     with Pre  => Bounded (V, Linear_Bound),
          Post => Norm_Sq'Result >= 0.0;

   function Norm (V : Vector2) return Float
     with Pre  => Bounded (V, Linear_Bound),
          Post => Norm'Result >= 0.0;

   --  The unit vector along V, or zero when V is zero. Components are
   --  saturated at one, which only absorbs the rounding of the last product.
   function Normalize (V : Vector2) return Vector2
     with Pre  => Bounded (V, Signal_Bound),
          Post => Bounded (Normalize'Result, 1.0);

   --  Rotation by Angle radians, positive counterclockwise.
   function Rotate (V : Vector2; Angle_Rad : Angle) return Vector2
     with Pre  => Bounded (V, Linear_Bound),
          Post => Bounded (Rotate'Result, 2.0 * Linear_Bound);

   ---------------------------------------------------------------------------
   --  Three dimensions
   ---------------------------------------------------------------------------

   function Equal (A : Vector3; B : Vector3) return Boolean is
     (A.X = B.X and then A.Y = B.Y and then A.Z = B.Z);

   function Add (A : Vector3; B : Vector3) return Vector3
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Sub (A : Vector3; B : Vector3) return Vector3
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Scale (V : Vector3; K : Float) return Vector3
     with Pre => Bounded (V, Linear_Bound) and then abs K <= Linear_Bound;

   function Dot (A : Vector3; B : Vector3) return Float
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Cross (A : Vector3; B : Vector3) return Vector3
     with Pre => Bounded (A, Linear_Bound) and then Bounded (B, Linear_Bound);

   function Norm_Sq (V : Vector3) return Float
     with Pre  => Bounded (V, Linear_Bound),
          Post => Norm_Sq'Result >= 0.0;

   function Norm (V : Vector3) return Float
     with Pre  => Bounded (V, Linear_Bound),
          Post => Norm'Result >= 0.0;

   function Normalize (V : Vector3) return Vector3
     with Pre  => Bounded (V, Signal_Bound),
          Post => Bounded (Normalize'Result, 1.0);

   ---------------------------------------------------------------------------
   --  Matrices
   ---------------------------------------------------------------------------

   function Multiply (M : Matrix33; V : Vector3) return Vector3
     with Pre => Bounded (M, Rotation_Bound) and then Bounded (V, Linear_Bound);

   --  Multiplication by the transpose, which inverts a rotation.
   function Multiply_Transposed (M : Matrix33; V : Vector3) return Vector3
     with Pre => Bounded (M, Rotation_Bound) and then Bounded (V, Linear_Bound);

   type Euler_Angles is record
      Roll  : Angle := 0.0;
      Pitch : Angle := 0.0;
      Yaw   : Angle := 0.0;
   end record;

   --  Rotation matrix from roll, pitch, and yaw in radians. Every entry is a
   --  sum of at most two products of sines and cosines, hence within two.
   function Rotation_Matrix (RPY : Euler_Angles) return Matrix33
     with Post => Bounded (Rotation_Matrix'Result, 2.0);

   function Apply_Rotation (V : Vector3; M : Matrix33) return Vector3
     with Pre => Bounded (M, Rotation_Bound) and then Bounded (V, Linear_Bound);

   function Yaw_Rotation_Z (Yaw : Angle) return Matrix33
     with Post => Bounded (Yaw_Rotation_Z'Result, 1.0);

end Adaflight.Vectors;
