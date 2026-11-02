with Adaflight.Maths;

package body Adaflight.Optical_Flow with SPARK_Mode is

   ----------
   -- Init --
   ----------

   procedure Init (S : out Sensor; C : Settings; Rotation_Cos, Rotation_Sin : Cosine; Gyro_Delay_Us : Gyro_Delay;
                   Now_Us : Unsigned_32) is
   begin
      S := (Rotation_Cos   => Rotation_Cos,
            Rotation_Sin   => Rotation_Sin,
            Flip_X         => C.Flip_X,
            Gyro_Delay_Us  => Gyro_Delay_Us,
            Quality        => No_New_Data,
            Raw_Flow       => (X => 0.0, Y => 0.0),
            Processed_Flow => (X => 0.0, Y => 0.0),
            X_Valid        => True,
            Y_Valid        => True,
            Time_Stamp_Us  => Now_Us,
            Sample_Index   => 0,
            Roll_Rates     => (others => 0.0),
            Pitch_Rates    => (others => 0.0),
            Sample_Times   => (others => 0),
            Taps           => <>);
   end Init;

   -------------
   -- Process --
   -------------

   procedure Process (S : in out Sensor; D : Sample; Roll_Rate, Pitch_Rate : Gyro_Rate) is
      use type Interfaces.Integer_64;
      Target_Age : constant Integer_32 := Integer_32 (S.Gyro_Delay_Us);
      Delayed    : History_Index;
      Best_Error : Interfaces.Integer_64 := Interfaces.Integer_64 (Integer_32'Last);
      Rx, Ry     : Rotated_Rate;
   begin
      S.Quality := D.Quality;
      S.Taps.Processed := False;
      if Adaflight.Clock.Elapsed (D.Time_Stamp_Us, S.Time_Stamp_Us) = 0 then
         return;
      end if;
      Rx := D.Flow_X * S.Rotation_Cos - D.Flow_Y * S.Rotation_Sin;
      if S.Flip_X then
         Rx := -Rx;
      end if;
      Ry := D.Flow_X * S.Rotation_Sin + D.Flow_Y * S.Rotation_Cos;

      S.Sample_Index := (S.Sample_Index + 1) mod History_Depth;
      S.Roll_Rates (S.Sample_Index) := Roll_Rate;
      S.Pitch_Rates (S.Sample_Index) := -Pitch_Rate;
      S.Sample_Times (S.Sample_Index) := D.Time_Stamp_Us;

      --  The slot whose age is nearest the delay; an empty slot carries the
      --  time zero and is passed over, as is a sample stamped zero.
      Delayed := S.Sample_Index;
      for I in History_Index loop
         if S.Sample_Times (I) /= 0 then
            declare
               Age   : constant Integer_32 := Adaflight.Clock.Elapsed (D.Time_Stamp_Us, S.Sample_Times (I));
               Error : constant Interfaces.Integer_64 :=
                 abs (Interfaces.Integer_64 (Age) - Interfaces.Integer_64 (Target_Age));
            begin
               if Error < Best_Error then
                  Best_Error := Error;
                  Delayed := I;
               end if;
            end;
         end if;
      end loop;

      declare
         Gx      : constant Gyro_Rate := S.Roll_Rates (Delayed);
         Gy      : constant Gyro_Rate := S.Pitch_Rates (Delayed);
         X_Valid : constant Boolean := abs Gx <= Rotation_Gyro_Limit;
         Y_Valid : constant Boolean := abs Gy <= Rotation_Gyro_Limit;
         Px      : constant Frame_Rate := Rx - Gx * Adaflight.Maths.Rad_Per_Degree;
         Py      : constant Frame_Rate := Ry - Gy * Adaflight.Maths.Rad_Per_Degree;
      begin
         S.Raw_Flow := (X => D.Flow_X, Y => D.Flow_Y);
         S.Processed_Flow := (X => (if X_Valid then Px else S.Processed_Flow.X),
                              Y => (if Y_Valid then Py else S.Processed_Flow.Y));
         S.X_Valid := X_Valid;
         S.Y_Valid := Y_Valid;
         S.Time_Stamp_Us := D.Time_Stamp_Us;
         S.Taps := (Processed => True, Rotated_X => Rx, Rotated_Y => Ry, Gyro_X => Gx, Gyro_Y => Gy,
                    Compensated_X => Px, Compensated_Y => Py);
      end;
   end Process;

end Adaflight.Optical_Flow;
