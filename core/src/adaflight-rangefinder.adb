with Adaflight.Maths;

package body Adaflight.Rangefinder with SPARK_Mode is

   Dynamic_Threshold_Snr : constant := 600;
   Dynamic_Factor        : constant := 75;

   --  The median of the last five readings in range, or the reading
   --  itself until five were seen.
   procedure Median (S : in out Sensor; New_Reading : Reading; Result : out Distance_Cm)
     with Pre => New_Reading >= 0
   is
   begin
      if New_Reading > Out_Of_Range then
         S.Median_Samples (S.Median_Index) := New_Reading;
         if S.Median_Index = 4 then
            S.Median_Index := 0;
            S.Median_Ready := True;
         else
            S.Median_Index := S.Median_Index + 1;
         end if;
      end if;
      if S.Median_Ready then
         Result := Integer_32'Max (0, Integer_32'Min (Sample_Cm'Last, Adaflight.Maths.Quick_Median_5
           (Adaflight.Maths.Int32_Window_5'(S.Median_Samples (0), S.Median_Samples (1), S.Median_Samples (2),
                                            S.Median_Samples (3), S.Median_Samples (4)))));
      else
         Result := New_Reading;
      end if;
   end Median;

   --  The sum of the last five squared changes over ten, each bounded.
   procedure Pseudo_Snr (S : in out Sensor; New_Reading : Reading; Result : out Integer_16) is
      Delta_Cm : constant Integer_32 := New_Reading - S.Previous_Reading;
      Sum      : Integer := 0;
   begin
      S.Snr_Samples (S.Snr_Index) := Snr_Sample (Integer_32'Max (0, Integer_32'Min (6400, Delta_Cm * Delta_Cm / 10)));
      if S.Snr_Index = 4 then
         S.Snr_Index := 0;
         S.Snr_Ready := True;
      else
         S.Snr_Index := S.Snr_Index + 1;
      end if;
      S.Previous_Reading := New_Reading;
      if S.Snr_Ready then
         for I in Snr_Window'Range loop
            pragma Loop_Invariant (Sum in 0 .. I * 6400);
            Sum := Sum + Integer (S.Snr_Samples (I));
         end loop;
         Result := Integer_16 (Integer'Min (Sum, 32000));
      else
         Result := Integer_16 (Out_Of_Range);
      end if;
   end Pseudo_Snr;

   ----------
   -- Init --
   ----------

   procedure Init (S : out Sensor; C : Settings; Now_Ms : Unsigned_32) is
      Half_Cone : constant Float := Float (C.Cone_Extended_Decidegrees) / 2.0;
      Radians   : constant Float := Half_Cone / 10.0 * 0.0174532925;
   begin
      S := (others => <>);
      S.Max_Tilt_Cos := Adaflight.Maths.Cos_Approx (Radians);
      S.Last_Valid_Ms := Now_Ms;
      S.Max_Alt_With_Tilt_Cm := Integer_16 (Float'Truncation (Float (C.Max_Range_Cm) * S.Max_Tilt_Cos));
      S.Cf_Altitude_Cm := C.Max_Range_Cm / 2;
   end Init;

   -------------
   -- Process --
   -------------

   procedure Process (S : in out Sensor; Now_Us, Now_Ms : Unsigned_32; Distance : Reading; Cos_Tilt : Cosine;
                      Processed : out Boolean) is
      Filtered : Distance_Cm;
   begin
      Processed := False;
      if Distance = No_New_Data then
         return;
      end if;
      if S.Last_Data_Us /= 0 then
         declare
            Interval : constant Unsigned_32 := Now_Us - S.Last_Data_Us;
         begin
            if Interval < 2 ** 31 and then Interval > 0 then
               S.Interval_Us := Integer_32 (Interval);
            end if;
         end;
      end if;
      S.Last_Data_Us := Now_Us;
      if Distance >= 0 then
         S.Last_Valid_Ms := Now_Ms;
         Median (S, Distance, Filtered);
         S.Raw_Altitude := Filtered;
      elsif Distance = Out_Of_Range then
         S.Last_Valid_Ms := Now_Ms;
         S.Raw_Altitude := Out_Of_Range;
      else
         S.Raw_Altitude := Hardware_Failure;
      end if;
      declare
         Snr : Integer_16;
      begin
         Pseudo_Snr (S, Distance, Snr);
         S.Snr := Snr;
      end;
      if not S.Threshold_Reached and then S.Raw_Altitude > 0 then
         if S.Snr < Dynamic_Threshold_Snr and then S.Dynamic_Threshold < S.Raw_Altitude then
            S.Dynamic_Threshold := S.Raw_Altitude * Dynamic_Factor / 100;
         end if;
         if S.Snr >= Dynamic_Threshold_Snr then
            S.Threshold_Reached := True;
         end if;
      end if;
      if Cos_Tilt < S.Max_Tilt_Cos or else S.Raw_Altitude < 0 then
         S.Calculated_Altitude := Out_Of_Range;
      else
         S.Calculated_Altitude := Integer_32 (Float'Truncation (Float (S.Raw_Altitude) * Cos_Tilt));
      end if;
      Processed := True;
   end Process;

   ----------------------------
   -- Surface_Altitude_Valid --
   ----------------------------

   function Surface_Altitude_Valid (S : Sensor) return Boolean is
   begin
      if S.Calculated_Altitude > 0 and then S.Raw_Altitude > 0 and then S.Snr < Dynamic_Threshold_Snr then
         if S.Threshold_Reached then
            return S.Raw_Altitude < S.Dynamic_Threshold;
         else
            return True;
         end if;
      end if;
      return False;
   end Surface_Altitude_Valid;

end Adaflight.Rangefinder;
