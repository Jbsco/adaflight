with Adaflight.Maths;
with Adaflight.Vectors;

package body Adaflight.Compass_Debug with SPARK_Mode is
   use type Interfaces.Unsigned_32;

   Task_Rate_Hz : constant := 40;

   --  The low sixteen bits of an unsigned value, as the reference's store of
   --  an unsigned into the debug array keeps them.
   function Low (U : Interfaces.Unsigned_32) return Debug.Integer_16 is
     (Debug.Wrapped (Interfaces.Integer_32 (U mod 2 ** 16)));

   --  A value held within the conversion bound.
   Bound : constant := Debug.Conversion_Bound;
   subtype Held_Float is Float range -Bound .. Bound;
   function Held (X : Float) return Held_Float is (Float'Max (-Bound, Float'Min (Bound, X)));

   --  The data rate in hertz from the interval, as the reference truncates
   --  a million over the interval into sixteen unsigned bits; an interval
   --  outside that quotient's range gives zero.
   function Rate_Of (Interval_Us : Interfaces.Unsigned_32) return Debug.Integer_16 is
      Quotient : Float;
   begin
      if Interval_Us in 1 .. 2 ** 31 - 1 then
         Quotient := 1.0e6 / Float (Interval_Us);
         if Quotient < 65_536.0 then
            return Debug.Wrapped (Interfaces.Integer_32 (Float'Truncation (Quotient)));
         end if;
      end if;
      return 0;
   end Rate_Of;

   procedure Record_Cycle (D : in out Debug.State; S : in out Compass.State; Execute_Us : Interfaces.Unsigned_32)
   is
      Lambda_Map : constant Float := 1.0 / (1.0 - Compass.Lambda_Min + 1.0e-6) * 2.0e3;
   begin
      if Debug.Selected (D, Debug.Mag_Task_Rate) then
         if S.Taps.Cycle_Set then
            Debug.Set (D, Debug.Mag_Task_Rate, 6, Low (S.Taps.Task_Interval_Us));
            Debug.Set (D, Debug.Mag_Task_Rate, 4, (if S.Taps.Bus_Busy then 1 else 0));
            if S.Taps.Read_Checked then
               Debug.Set (D, Debug.Mag_Task_Rate, 5, (if S.Taps.No_Data then 1 else 0));
            end if;
         end if;
         if S.Taps.Data_Pending then
            S.Taps.Data_Interval_Us := S.Taps.Update_Us - S.Taps.Previous_Data_Us;
            S.Taps.Previous_Data_Us := S.Taps.Update_Us;
            S.Taps.Data_Pending := False;
         end if;
         if S.Taps.Updated then
            Debug.Set (D, Debug.Mag_Task_Rate, 0, Task_Rate_Hz);
            Debug.Set (D, Debug.Mag_Task_Rate, 1, Rate_Of (S.Taps.Data_Interval_Us));
            Debug.Set (D, Debug.Mag_Task_Rate, 2, Low (S.Taps.Data_Interval_Us));
            Debug.Set (D, Debug.Mag_Task_Rate, 3, Low (Execute_Us));
         end if;
      end if;
      if Debug.Selected (D, Debug.Mag_Calib) and then S.Taps.Updated then
         declare
            use Adaflight.Vectors;
            FX : constant Float := S.Field (X);
            FY : constant Float := S.Field (Y);
            FZ : constant Float := S.Field (Z);
            Norm : constant Float := Maths.Sqrt_Non_Negative (Held (FX * FX + FY * FY + FZ * FZ));
            Gain : constant Float :=
              (if S.Calibrating and then S.Movement_Started
               then (S.Estimator.Lambda - Compass.Lambda_Min) * Lambda_Map else 0.0);
         begin
            for A in Coordinate loop
               Debug.Set (D, Debug.Mag_Calib, Coordinate'Pos (A), Debug.Rounded (Held (S.Field (A))));
               Debug.Set (D, Debug.Mag_Calib, Coordinate'Pos (A) + 4, Debug.Rounded (Held (S.Estimator.B (A))));
            end loop;
            Debug.Set (D, Debug.Mag_Calib, 3, Debug.Rounded (Held (Norm)));
            Debug.Set (D, Debug.Mag_Calib, 7, Debug.Rounded (Held (Gain)));
         end;
      end if;
   end Record_Cycle;

end Adaflight.Compass_Debug;
