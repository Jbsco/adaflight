package body Adaflight.GPS_Lap_Timer with SPARK_Mode is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Integer_32;

   Rad : constant Float := Float'Machine (Float'Machine (3.14159265358979323846) / 180.0);

   --  Centimetres per unit of latitude at the equator, folded as the
   --  reference's compiler folds it.
   Angle_To_Cm : constant Float :=
     Float'Machine (Float'Machine (Float'Machine (Float'Machine (111.3195) * 1000.0) * 100.0) / 10_000_000.0);

   subtype Local_Cm is Float range -2.4e9 .. 2.4e9;
   subtype Square_Cm is Float range 0.0 .. 5.8e18;
   subtype Sum_Cm is Float range 0.0 .. 1.16e19;
   subtype Root_Cm is Float range 0.0 .. 4.2e9;
   subtype Degrees_100 is Float range -9_001.0 .. 27_001.0;

   function To_Signed (U : Unsigned_32) return Integer_32 is
     (if U >= 2 ** 31 then -Integer_32 (not U) - 1 else Integer_32 (U));

   function To_Unsigned (I : Integer_32) return Unsigned_32 is
     (if I < 0 then not Unsigned_32 (-(I + 1)) else Unsigned_32 (I));

   --  A difference of coordinates in thirty-two bits, wrapping as the
   --  reference's subtraction does.
   function Wrapped_Difference (A, B : Integer_32) return Integer_32 is
     (To_Signed (To_Unsigned (A) - To_Unsigned (B)));

   --  The offsets from the first position to the second over the local
   --  flat earth, north and east in centimetres.
   function North_Cm (From, To : Location) return Local_Cm is
     (Float (Wrapped_Difference (To.Lat, From.Lat)) * Angle_To_Cm);

   function East_Cm (From, To : Location; Cos_Lat : Cosine) return Local_Cm is
     ((Float (Wrapped_Difference (To.Lon, From.Lon)) * Cos_Lat) * Angle_To_Cm);

   function Distance_Cm (From, To : Location; Cos_Lat : Cosine) return Unsigned_32
     with Post => Distance_Cm'Result <= 4_200_000_000
   is
      D_Lat  : constant Local_Cm := North_Cm (From, To);
      D_Lon  : constant Local_Cm := East_Cm (From, To, Cos_Lat);
      Lat_Sq : constant Square_Cm := D_Lat * D_Lat;
      Lon_Sq : constant Square_Cm := D_Lon * D_Lon;
      Sum    : constant Sum_Cm := Lat_Sq + Lon_Sq;
      Root   : constant Root_Cm := Float'Min (Adaflight.Maths.Sqrt_Non_Negative (Sum), 4.2e9);
   begin
      return Unsigned_32 (Float'Truncation (Root));
   end Distance_Cm;

   --  The bearing from the first position to the second, clockwise from
   --  north in hundredths of a degree.
   function Bearing_To (From, To : Location; Cos_Lat : Cosine) return Bearing
     with Global => null
   is
      Angle : constant Adaflight.Maths.Half_Turn :=
        Adaflight.Maths.Atan2_Approx (North_Cm (From, To), East_Cm (From, To, Cos_Lat));
      Deg   : constant Degrees_100 := 9_000.0 - (Angle / Rad) * 100.0;
      B     : constant Integer_32 range -9_001 .. 27_001 := Integer_32 (Float'Truncation (Deg));
   begin
      return (if B < 0 then B + 36_000 else B);
   end Bearing_To;

   ----------
   -- Init --
   ----------

   procedure Init (T : in out Timer; C : Settings) is
   begin
      T.Gate := (Lat => C.Gate_Lat, Lon => C.Gate_Lon, Alt_Cm => 0);
      T.Set_Readings := 0;
      T.Best_Lap_Time := 0;
      T.Best_Three := 0;
      T.Previous := (others => 0);
      T.Timer_Running := False;
      T.Time_Of_Last_Lap := 0;
      T.Laps_Recorded := 0;
   end Init;

   --------------------
   -- Start_Set_Gate --
   --------------------

   procedure Start_Set_Gate (T : in out Timer) is
   begin
      T.Lat_Sum := 0;
      T.Lon_Sum := 0;
      T.Set_Readings := 0;
      T.Setting_Gate := True;
   end Start_Set_Gate;

   --  The fix joins the gate average up to the reading limit; the count
   --  moves before the sums so the bound holds at every step.
   procedure Process_Setting_Gate (T : in out Timer; Position : Location)
     with Pre => T.Setting_Gate, Post => T.Setting_Gate
   is
      Count : Integer_64;
   begin
      if T.Set_Readings < Max_Gate_Set_Readings then
         T.Set_Readings := T.Set_Readings + 1;
         T.Lat_Sum := T.Lat_Sum + Integer_64 (Position.Lat);
         T.Lon_Sum := T.Lon_Sum + Integer_64 (Position.Lon);
      end if;
      Count := Integer_64 (T.Set_Readings);
      T.Gate.Lat := Integer_32 (Integer_64'Max (Integer_64 (Integer_32'First),
                                Integer_64'Min (Integer_64 (Integer_32'Last), T.Lat_Sum / Count)));
      T.Gate.Lon := Integer_32 (Integer_64'Max (Integer_64 (Integer_32'First),
                                Integer_64'Min (Integer_64 (Integer_32'Last), T.Lon_Sum / Count)));
   end Process_Setting_Gate;

   ------------------
   -- End_Set_Gate --
   ------------------

   procedure End_Set_Gate (T : in out Timer; C : in out Settings) is
   begin
      T.Setting_Gate := False;
      C.Gate_Lat := T.Gate.Lat;
      C.Gate_Lon := T.Gate.Lon;
   end End_Set_Gate;

   ------------------
   -- New_GPS_Data --
   ------------------

   procedure New_GPS_Data (T : in out Timer; C : Settings; Position : Location; Time_Ms : Unsigned_32;
                           Cos_Lat : Cosine; Reset_Mode : Boolean) is
   begin
      T.Distance_To_Gate_Cm := Distance_Cm (Position, T.Gate, Cos_Lat);
      T.Direction_To_Gate := Bearing_To (Position, T.Gate, Cos_Lat);
      if T.Setting_Gate then
         Process_Setting_Gate (T, Position);
         return;
      end if;
      if Reset_Mode then
         Init (T, C);
         return;
      end if;
      if not T.Timer_Running
        or else Time_Ms - T.Time_Of_Last_Lap > Unsigned_32 (C.Minimum_Lap_Time_S) * 1000
      then
         if T.Distance_To_Gate_Cm < Unsigned_32 (C.Gate_Tolerance_M) * 100 then
            if not T.Was_In_Circle or else T.Distance_To_Gate_Cm < T.Min_Distance then
               T.Min_Distance := T.Distance_To_Gate_Cm;
               T.Min_Distance_Time := Time_Ms;
            end if;
            T.Was_In_Circle := True;
         else
            if T.Was_In_Circle then
               if T.Timer_Running then
                  declare
                     Lap_Time : constant Unsigned_32 := T.Min_Distance_Time - T.Time_Of_Last_Lap;
                     Sum      : Unsigned_32 := 0;
                  begin
                     T.Laps_Recorded := T.Laps_Recorded + 1;
                     if T.Laps_Recorded >= 1 and then (Lap_Time < T.Best_Lap_Time or else T.Best_Lap_Time = 0) then
                        T.Best_Lap_Time := Lap_Time;
                     end if;
                     for I in reverse 1 .. Lap_Index'Last loop
                        T.Previous (I) := T.Previous (I - 1);
                     end loop;
                     T.Previous (0) := Lap_Time;
                     if T.Laps_Recorded >= Previous_Laps_Kept then
                        for I in Lap_Index loop
                           Sum := Sum + T.Previous (I);
                        end loop;
                     end if;
                     if Sum > 0 and then (Sum < T.Best_Three or else T.Best_Three = 0) then
                        T.Best_Three := Sum;
                     end if;
                  end;
               end if;
               T.Time_Of_Last_Lap := T.Min_Distance_Time;
               T.Timer_Running := True;
            end if;
            T.Was_In_Circle := False;
         end if;
      end if;
   end New_GPS_Data;

end Adaflight.GPS_Lap_Timer;
