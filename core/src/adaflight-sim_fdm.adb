with Ada.Unchecked_Conversion;
with Adaflight.Maths;

package body Adaflight.Sim_FDM with SPARK_Mode is

   function C_Pow (X, Y : Long_Float) return Long_Float
     with Import, Convention => C, External_Name => "pow", Global => null;
   function C_Atan2 (Y, X : Long_Float) return Long_Float
     with Import, Convention => C, External_Name => "atan2", Global => null;
   function C_Sqrt (X : Long_Float) return Long_Float
     with Import, Convention => C, External_Name => "sqrt", Global => null;

   Gravity    : constant Long_Float := 9.80665;
   Acc_Scale  : constant Long_Float := 256.0 / Gravity;
   Gyro_Scale : constant Long_Float := 16.4;
   C_Pi       : constant Long_Float := 3.14159265358979323846;
   Rad_To_Deg : constant Long_Float := 180.0 / C_Pi;
   Timeout_Us : constant Long_Float := 500_000.0;

   Half_Root_Two : constant Float := 0.70710678;

   subtype Attitude_Value is Float range -2.0 .. 2.0;
   subtype Rotation_Value is Float range -40.0 .. 40.0;
   Field_North   : constant Float := 2046.8;
   Field_West    : constant Float := -71.5;
   Field_Up      : constant Float := -3547.2;

   function Finite (Bits : Unsigned_64) return Boolean is
     ((Shift_Right (Bits, 52) and 16#7FF#) /= 16#7FF#);

   function To_Double (Bits : Unsigned_64) return Long_Float
     with Pre => Finite (Bits);

   function To_Double (Bits : Unsigned_64) return Long_Float with SPARK_Mode => Off is
      function Convert is new Ada.Unchecked_Conversion (Unsigned_64, Long_Float);
   begin
      return Convert (Bits);
   end To_Double;

   procedure Decode (Bytes : Adaflight.Bytes.Byte_Array; P : out Packet; Valid : out Boolean) is
      Values : array (0 .. 17) of Field := (others => 0.0);
   begin
      Valid := True;
      for I in Values'Range loop
         declare
            Bits : Unsigned_64 := 0;
            V    : Long_Float;
         begin
            for K in reverse 0 .. 7 loop
               Bits := Shift_Left (Bits, 8) or Unsigned_64 (Bytes (Bytes'First + I * 8 + K));
            end loop;
            if Finite (Bits) then
               V := To_Double (Bits);
               if abs V <= Field_Bound then
                  Values (I) := V;
               else
                  Valid := False;
               end if;
            else
               Valid := False;
            end if;
         end;
      end loop;
      for I in 7 .. 10 loop
         if abs Values (I) > Orientation_Bound then
            Values (I) := 0.0;
            Valid := False;
         end if;
      end loop;
      P := (Timestamp    => Values (0),
            Rates        => (Values (1), Values (2), Values (3)),
            Acceleration => (Values (4), Values (5), Values (6)),
            Orientation  => (Values (7), Values (8), Values (9), Values (10)),
            Velocity     => (Values (11), Values (12), Values (13)),
            Position     => (Values (14), Values (15), Values (16)),
            Pressure     => Values (17));
   end Decode;

   --  A count as the C conversion to int truncates it and the constrain
   --  holds it within +-32767; beyond the int range the conversion is
   --  undefined and the count saturates.
   function Count (V : Long_Float) return Integer_16 is
     (if V >= 32_767.0 then 32_767
      elsif V <= -32_767.0 then -32_767
      else Integer_16 (Long_Float'Truncation (V)));

   function To_Int32 (V : Long_Float) return Integer_32 is
     (if V >= 2_147_483_647.0 then Integer_32'Last
      elsif V <= -2_147_483_648.0 then Integer_32'First
      else Integer_32 (Long_Float'Truncation (V)));

   function To_Int16 (V : Long_Float) return Integer_16 is
     (if V >= 32_767.0 then Integer_16'Last
      elsif V <= -32_768.0 then Integer_16'First
      else Integer_16 (Long_Float'Truncation (V)));

   function To_Unsigned_16 (V : Long_Float) return Unsigned_16 is
     (if V >= 65_535.0 then Unsigned_16'Last
      elsif V < 0.0 then 0
      else Unsigned_16 (Long_Float'Truncation (V)));

   --  lrintf, ties to even, then the conversion of its long to a 16-bit
   --  count, which the compiler wraps.
   function Wrap_16 (V : Integer_64) return Integer_16 is
     (if V mod 65_536 >= 32_768 then Integer_16 (V mod 65_536 - 65_536) else Integer_16 (V mod 65_536));

   function Rounded_16 (X : Float) return Integer_16 is
     (if abs X <= Float (Adaflight.Maths.Rounding_Bound) - 1.0
      then Wrap_16 (Integer_64 (Adaflight.Maths.Round_Half_Even (X)))
      elsif abs X <= 2.0 ** 62 then Wrap_16 (Integer_64 (X))
      else 0);

   function Rate_Of (Sim : Long_Float; Real : Long_Float) return Rate is
     (Long_Float'Max (0.0, Long_Float'Min (Sim / Real, Rate'Last)))
     with Pre => Sim in 0.0 .. 0.02 and then Real in 1.0E-9 .. 3.0E12;

   function Pressure_Of (P : Packet; B : Bridge) return Integer_32 is
   begin
      if B = Gazebo then
         declare
            Base : constant Long_Float := 1.0 - 2.25577E-5 * P.Position (3);
         begin
            if Base < 0.0 then
               return 0;
            end if;
            return To_Int32 (101_325.0 * Long_Float'Max (Long_Float'Min (C_Pow (Base, 5.25588), 1.0E10), 0.0));
         end;
      else
         return To_Int32 (P.Pressure);
      end if;
   end Pressure_Of;

   procedure Step (S : in out State; P : Packet; B : Bridge; Now_Us, End_Us : Unsigned_64; Now : Time_Spec;
                   F : out Feed)
   is
      Delta_Sim : Long_Float;
      Roll, Pitch, Yaw : Long_Float;
      W, X, Y, Z : Attitude_Value;
   begin
      F := (others => <>);
      if Long_Float (Now_Us) > Long_Float (S.Last_Realtime) + Timeout_Us then
         S.Last_Timestamp := P.Timestamp;
         S.Last_Realtime := Now_Us;
         F.Kind := Timeout;
         return;
      end if;

      Delta_Sim := P.Timestamp - S.Last_Timestamp;
      if Delta_Sim < 0.0 then
         return;
      end if;
      F.Kind := Update;

      for I in Axes'Range loop
         F.Acc (I) := Count (-P.Acceleration (I) * Acc_Scale);
      end loop;

      Roll := P.Rates (1);
      Pitch := -P.Rates (2);
      Yaw := (if B = Gazebo then P.Rates (3) else -P.Rates (3));
      F.Gyro := (Count (Roll * Gyro_Scale * Rad_To_Deg), Count (Pitch * Gyro_Scale * Rad_To_Deg),
                 Count (Yaw * Gyro_Scale * Rad_To_Deg));

      F.Pressure := Pressure_Of (P, B);

      if B = Gazebo then
         declare
            Qw : constant Float := Float (P.Orientation (1));
            Qx : constant Float := Float (P.Orientation (2));
            Qy : constant Float := Float (-P.Orientation (3));
            Qz : constant Float := Float (-P.Orientation (4));
         begin
            W := Half_Root_Two * (Qw - Qz);
            X := Half_Root_Two * (Qx - Qy);
            Y := Half_Root_Two * (Qy + Qx);
            Z := Half_Root_Two * (Qz + Qw);
         end;
      else
         W := Float (P.Orientation (1));
         X := Float (P.Orientation (2));
         Y := Float (P.Orientation (3));
         Z := Float (P.Orientation (4));
      end if;

      declare
         R00 : constant Rotation_Value := 1.0 - 2.0 * (Y * Y + Z * Z);
         R01 : constant Rotation_Value := 2.0 * (X * Y - W * Z);
         R02 : constant Rotation_Value := 2.0 * (X * Z + W * Y);
         R10 : constant Rotation_Value := 2.0 * (X * Y + W * Z);
         R11 : constant Rotation_Value := 1.0 - 2.0 * (X * X + Z * Z);
         R12 : constant Rotation_Value := 2.0 * (Y * Z - W * X);
         R20 : constant Rotation_Value := 2.0 * (X * Z - W * Y);
         R21 : constant Rotation_Value := 2.0 * (Y * Z + W * X);
         R22 : constant Rotation_Value := 1.0 - 2.0 * (X * X + Y * Y);
      begin
         F.Mag := (Rounded_16 (R00 * Field_North + R10 * Field_West + R20 * Field_Up),
                   Rounded_16 (R01 * Field_North + R11 * Field_West + R21 * Field_Up),
                   Rounded_16 (R02 * Field_North + R12 * Field_West + R22 * Field_Up));
      end;
      F.Attitude := (W, X, Y, Z);

      declare
         Lon : constant Field := P.Position (1);
         Lat : constant Field := P.Position (2);
         Alt : constant Field := P.Position (3);
         Corrected_Lat, Corrected_Lon : Long_Float range -3.0 * Field_Bound .. 3.0 * Field_Bound;
         Speed, Speed_3D, Course : Long_Float;
      begin
         if B = Gazebo then
            if not S.Origin_Set then
               S.Origin_Lat := Lat;
               S.Origin_Lon := Lon;
               S.Origin_Set := True;
            end if;
            Corrected_Lat := 2.0 * S.Origin_Lat - Lat;
            Corrected_Lon := 2.0 * S.Origin_Lon - Lon;
         else
            Corrected_Lat := Lat;
            Corrected_Lon := Lon;
         end if;
         Speed := C_Sqrt (P.Velocity (1) * P.Velocity (1) + P.Velocity (2) * P.Velocity (2));
         Speed_3D := C_Sqrt (P.Velocity (1) * P.Velocity (1) + P.Velocity (2) * P.Velocity (2)
                             + P.Velocity (3) * P.Velocity (3));
         Course := Long_Float'Min (Long_Float'Max (C_Atan2 (P.Velocity (1), P.Velocity (2)), -4.0), 4.0)
                   * Rad_To_Deg;
         if Course < 0.0 then
            Course := Course + 360.0;
         end if;
         if abs Lat <= 90.0 and then abs Lon <= 180.0 then
            F.GPS_Set := True;
            F.GPS := (Lat          => To_Int32 (Corrected_Lat * 10_000_000.0),
                      Lon          => To_Int32 (Corrected_Lon * 10_000_000.0),
                      Alt_Cm       => To_Int32 (Alt * 100.0),
                      Ground_Speed => To_Unsigned_16 (Long_Float'Max (Long_Float'Min (Speed, 1.0E7), 0.0) * 100.0),
                      Speed_3D     => To_Unsigned_16 (Long_Float'Max (Long_Float'Min (Speed_3D, 1.0E7), 0.0) * 100.0),
                      Course       => To_Unsigned_16 (Course * 10.0),
                      Vel_North    => To_Int16 (P.Velocity (2) * 100.0),
                      Vel_East     => To_Int16 (P.Velocity (1) * 100.0),
                      Vel_Down     => To_Int16 (-P.Velocity (3) * 100.0));
         end if;
      end;

      if Delta_Sim < 0.02 and then Delta_Sim > 0.0 then
         declare
            Carry : constant Integer_64 := (if Now.Nsec < S.Last_Time.Nsec then 1 else 0);
            Sec   : constant Integer_64 := Now.Sec - S.Last_Time.Sec - Carry;
            Nsec  : constant Integer_64 := Now.Nsec - S.Last_Time.Nsec + Carry * 1_000_000_000;
            Span  : constant Long_Float := Long_Float (Sec) + 1.0E-9 * Long_Float (Nsec);
         begin
            if Span >= 1.0E-9 and then Span <= 3.0E12 then
               S.Sim_Rate := Rate_Of (Delta_Sim, Span);
            end if;
         end;
      end if;

      S.Last_Timestamp := P.Timestamp;
      S.Last_Realtime := End_Us;
      S.Last_Time := Now;
   end Step;

end Adaflight.Sim_FDM;
