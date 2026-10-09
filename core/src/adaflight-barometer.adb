with Adaflight.Accurate_Power;

package body Adaflight.Barometer with SPARK_Mode is

   Sea_Level_Pa      : constant Float := 101_325.0;
   Altitude_Exponent : constant Float := 0.190295;
   Altitude_Scale    : constant Float := 4_433_000.0;

   --  The signed difference of two wrapping microsecond counters.
   function Elapsed (Later : Time_Us; Earlier : Time_Us) return Integer_32 is
      D : constant Interfaces.Integer_64 := Interfaces.Integer_64 (Later) - Interfaces.Integer_64 (Earlier);
   begin
      if D > Interfaces.Integer_64 (Integer_32'Last) then
         return Integer_32 (D - 2 ** 32);
      elsif D < Interfaces.Integer_64 (Integer_32'First) then
         return Integer_32 (D + 2 ** 32);
      else
         return Integer_32 (D);
      end if;
   end Elapsed;

   --  A positive pressure count as a float, in a context of its own.
   function Counts_Of (Pressure : Integer_32) return Float
     with Pre  => Pressure > 0,
          Post => Counts_Of'Result in 1.0 .. 2.0 ** 31
   is
   begin
      return Float (Pressure);
   end Counts_Of;

   --  The barometric altitude of a positive pressure. The power of a ratio
   --  within the 32-bit pressure range stays below seven; the bound of eight
   --  is where it saturates (DESIGN.md D21).
   function Pressure_To_Altitude (Pressure : Integer_32) return Altitude_Cm
     with Pre => Pressure > 0
   is
      Counts  : constant Float := Counts_Of (Pressure);
      Ratio   : constant Float range 4.0e-6 .. 2.2e4 := Counts / Sea_Level_Pa;
      Power   : constant Float := Accurate_Power.Pow (Ratio, Altitude_Exponent);
      Clamped : constant Float range 0.0 .. 8.0 := Float'Min (Power, 8.0);
   begin
      return (1.0 - Clamped) * Altitude_Scale;
   end Pressure_To_Altitude;

   ----------
   -- Init --
   ----------

   procedure Init (S : out State) is
   begin
      S := (others => <>);
   end Init;

   -----------------------
   -- Start_Calibration --
   -----------------------

   procedure Start_Calibration (S : in out State; C : Settings) is
   begin
      S.Temperature_At_Calibration := 0;
      if C.Virtual_Device then
         S.Calibrated := True;
         S.Ground_Altitude := 0.0;
         return;
      end if;
      S.Ground_Altitude := 0.0;
      S.Calibrated := False;
      S.Cycles := Calibration_Cycles;
      S.Count := 0;
   end Start_Calibration;

   ----------------------
   -- Set_Ground_Level --
   ----------------------

   procedure Set_Ground_Level (S : in out State) is
   begin
      S.Ground_Altitude := 0.0;
      S.Temperature_At_Calibration := 0;
      S.Calibrated := False;
      S.Cycles := Ground_Level_Cycles;
      S.Count := 0;
   end Set_Ground_Level;

   ------------
   -- Sample --
   ------------

   procedure Sample (
      S           : in out State;
      C           : Settings;
      Pressure    : Integer_32;
      Temperature : Temperature_Centi;
      Now_Us      : Time_Us
   ) is
      --  One calibration cycle: the altitude and temperature join the sums,
      --  and the last cycle turns them into means.
      procedure Calibration_Cycle (Altitude : Altitude_Cm)
        with Pre  => not S.Calibrated and then S.Count < Calibration_Cycles,
             Post => S.Pressure = S.Pressure'Old and then S.Temperature = S.Temperature'Old
                     and then S.Last_Data_Time_Us = S.Last_Data_Time_Us'Old
                     and then S.Data_Interval_Us = S.Data_Interval_Us'Old and then S.Altitude = S.Altitude'Old
      is
         Summed : constant Float := S.Ground_Altitude + Altitude;
         Warmed : constant Interfaces.Integer_64 :=
           Interfaces.Integer_64 (S.Temperature_At_Calibration) + Interfaces.Integer_64 (S.Temperature);
      begin
         S.Ground_Altitude := Float'Max (Altitude_Sum'First, Float'Min (Altitude_Sum'Last, Summed));
         S.Temperature_At_Calibration :=
           Integer_32 (Interfaces.Integer_64'Max
                         (Interfaces.Integer_64 (Temperature_Sum'First),
                          Interfaces.Integer_64'Min (Interfaces.Integer_64 (Temperature_Sum'Last), Warmed)));
         S.Count := S.Count + 1;
         if S.Count >= S.Cycles then
            S.Ground_Altitude := S.Ground_Altitude / Float (S.Count);
            S.Temperature_At_Calibration := S.Temperature_At_Calibration / Integer_32 (S.Count);
            S.Calibrated := True;
            S.Count := 0;
         end if;
      end Calibration_Cycle;
   begin
      S.Pressure := Pressure;
      S.Temperature := Temperature;
      if Pressure > 0 then
         declare
            Altitude : constant Altitude_Cm := Pressure_To_Altitude (Pressure);
         begin
            if S.Calibrated then
               declare
                  subtype Level_Cm is Float range -4.1e9 .. 4.1e9;
                  subtype Drift_Product is Interfaces.Integer_64 range -200_000_000_000 .. 200_000_000_000;
                  Level : constant Level_Cm := Altitude - S.Ground_Altitude;
               begin
                  if C.Virtual_Device then
                     S.Altitude := Level;
                  else
                     declare
                        Drift : constant Drift_Product :=
                          (Interfaces.Integer_64 (S.Temperature) - Interfaces.Integer_64 (S.Temperature_At_Calibration))
                          * Interfaces.Integer_64 (C.Temperature_Drift_Cm_Per_10C);
                     begin
                        S.Altitude := Level - Float (Drift) / 1_000.0;
                     end;
                  end if;
               end;
            elsif S.Count < Calibration_Cycles then
               Calibration_Cycle (Altitude);
               S.Altitude := 0.0;
            else
               S.Altitude := 0.0;
            end if;
         end;
         if S.Last_Data_Time_Us /= 0 then
            declare
               Interval : constant Integer_32 := Elapsed (Now_Us, S.Last_Data_Time_Us);
            begin
               if Interval > 0 then
                  S.Data_Interval_Us := Interval;
               end if;
            end;
         end if;
         S.Last_Data_Time_Us := Now_Us;
      elsif not S.Calibrated then
         S.Altitude := 0.0;
      end if;
   end Sample;

end Adaflight.Barometer;
