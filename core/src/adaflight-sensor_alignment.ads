--  Sensor mounting orientation: the standard clockwise alignments and
--  arbitrary angles in tenths of a degree, and the rotation they define.

with Interfaces;
with Adaflight.Vectors;

package Adaflight.Sensor_Alignment with SPARK_Mode, Pure is

   use type Interfaces.Integer_16;

   subtype Integer_16 is Interfaces.Integer_16;

   type Standard_Alignment is
     (Default, CW0, CW90, CW180, CW270, CW0_Flip, CW90_Flip, CW180_Flip, CW270_Flip, Custom);

   --  Tenths of a degree, limited to a full turn either way.
   subtype Decidegrees is Integer_16 range -3600 .. 3600;

   type Alignment_Angles is record
      Roll  : Decidegrees := 0;
      Pitch : Decidegrees := 0;
      Yaw   : Decidegrees := 0;
   end record;

   function Rotation_Matrix (Angles : Alignment_Angles) return Vectors.Matrix33
     with Post => Vectors.Bounded (Rotation_Matrix'Result, 2.0);

   --  Angles of a standard alignment: quarter turns about yaw, and a half
   --  turn about pitch for the flipped variants. Default and Custom leave
   --  the angles unchanged.
   procedure From_Standard (Angles : in out Alignment_Angles; Alignment : Standard_Alignment);

   --  A standard alignment applied to a sensor reading: quarter turns about
   --  yaw permute and negate the axes, the flipped variants negate the
   --  vertical axis. Default, CW0, and Custom leave the reading unchanged.
   function Align (V : Vectors.Vector3; Alignment : Standard_Alignment) return Vectors.Vector3
     with Post => abs Align'Result.X <= Float'Max (abs V.X, abs V.Y)
                  and then abs Align'Result.Y <= Float'Max (abs V.X, abs V.Y)
                  and then abs Align'Result.Z = abs V.Z;

end Adaflight.Sensor_Alignment;
