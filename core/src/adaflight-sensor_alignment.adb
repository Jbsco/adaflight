with Adaflight.Maths;

package body Adaflight.Sensor_Alignment with SPARK_Mode is

   function To_Radians (Angle : Decidegrees) return Maths.Angle is
     (Float (Angle) / 10.0 * 0.0174532925);

   ---------------------
   -- Rotation_Matrix --
   ---------------------

   function Rotation_Matrix (Angles : Alignment_Angles) return Vectors.Matrix33 is
     (Vectors.Rotation_Matrix
        ((Roll => To_Radians (Angles.Roll), Pitch => To_Radians (Angles.Pitch),
          Yaw => To_Radians (Angles.Yaw))));

   -------------------
   -- From_Standard --
   -------------------

   procedure From_Standard (Angles : in out Alignment_Angles; Alignment : Standard_Alignment) is
      Quarter_Turns : Integer_16;
      Flipped       : Boolean;
   begin
      case Alignment is
         when Default | Custom =>
            return;
         when CW0 | CW0_Flip =>
            Quarter_Turns := 0;
         when CW90 | CW90_Flip =>
            Quarter_Turns := 1;
         when CW180 | CW180_Flip =>
            Quarter_Turns := 2;
         when CW270 | CW270_Flip =>
            Quarter_Turns := 3;
      end case;
      Flipped := Alignment in CW0_Flip .. CW270_Flip;
      Angles := (Roll  => 0,
                 Pitch => (if Flipped then 1800 else 0),
                 Yaw   => 900 * Quarter_Turns);
   end From_Standard;

end Adaflight.Sensor_Alignment;
