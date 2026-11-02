package body Adaflight.Rangefinder_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   --  Sixteen unsigned bits as the reference's store into the debug array
   --  keeps them.
   function Low (U : Interfaces.Unsigned_16) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (U)));

   function Flag (B : Boolean) return Debug.Integer_16 is (if B then 1 else 0);

   procedure Record_Process (D : in out Debug.State; S : Rangefinder.Sensor) is
   begin
      if not S.Taps.Processed_Set then
         return;
      end if;
      if Debug.Selected (D, Debug.Rangefinder) then
         Debug.Set (D, Debug.Rangefinder, 1, Debug.Wrapped (S.Raw_Altitude));
         Debug.Set (D, Debug.Rangefinder, 2, Debug.Wrapped (S.Calculated_Altitude));
         Debug.Set (D, Debug.Rangefinder, 3, S.Snr);
         Debug.Set (D, Debug.Rangefinder, 4, Debug.Rounded (S.Taps.Cos_Tilt * 1000.0));
         Debug.Set (D, Debug.Rangefinder, 5, Debug.Rounded (S.Max_Tilt_Cos * 1000.0));
      end if;
      if Debug.Selected (D, Debug.Rangefinder_Quality) then
         Debug.Set (D, Debug.Rangefinder_Quality, 0, Debug.Wrapped (S.Raw_Altitude));
         Debug.Set (D, Debug.Rangefinder_Quality, 1, Flag (S.Threshold_Reached));
         Debug.Set (D, Debug.Rangefinder_Quality, 2, Debug.Wrapped (S.Dynamic_Threshold));
         Debug.Set (D, Debug.Rangefinder_Quality, 3, Flag (S.Taps.Quality_Valid));
      end if;
   end Record_Process;

   procedure Record_Lidar_TF
     (D : in out Debug.State; Distance, Strength : Interfaces.Unsigned_16; Byte_4, Byte_5 : Natural;
      Errors : Interfaces.Unsigned_32)
   is
   begin
      if Debug.Selected (D, Debug.Lidar_TF) then
         Debug.Set (D, Debug.Lidar_TF, 0, Low (Distance));
         Debug.Set (D, Debug.Lidar_TF, 1, Low (Strength));
         Debug.Set (D, Debug.Lidar_TF, 2, Debug.Integer_16 (Byte_4));
         Debug.Set (D, Debug.Lidar_TF, 3, Debug.Integer_16 (Byte_5));
         Debug.Set (D, Debug.Lidar_TF, 4, Debug.Wrapped (Interfaces.Integer_32 (Errors mod 2 ** 16)));
      end if;
   end Record_Lidar_TF;

   procedure Record_UPT1
     (D : in out Debug.State; Distance_Mm : Interfaces.Unsigned_16; Confidence : Natural;
      Flow_X, Flow_Y : Interfaces.Integer_16; Valid_Status : Natural; Integration_Us : Interfaces.Unsigned_16;
      Reported : Interfaces.Integer_32; Phase : Natural)
   is
   begin
      if Debug.Selected (D, Debug.UPT1) then
         Debug.Set (D, Debug.UPT1, 0, Low (Distance_Mm));
         Debug.Set (D, Debug.UPT1, 1, Debug.Integer_16 (Confidence));
         Debug.Set (D, Debug.UPT1, 2, Flow_X);
         Debug.Set (D, Debug.UPT1, 3, Flow_Y);
         Debug.Set (D, Debug.UPT1, 4, Debug.Integer_16 (Valid_Status));
         Debug.Set (D, Debug.UPT1, 5, Low (Integration_Us));
         Debug.Set (D, Debug.UPT1, 6, Debug.Integer_16 (Reported));
         Debug.Set (D, Debug.UPT1, 7, Debug.Integer_16 (Phase));
      end if;
   end Record_UPT1;

end Adaflight.Rangefinder_Debug;
