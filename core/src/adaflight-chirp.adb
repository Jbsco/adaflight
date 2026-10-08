with Adaflight.Exponentials; use Adaflight.Exponentials;

package body Adaflight.Chirp with SPARK_Mode is

   Two_Pi : constant Float := 2.0 * Pi;

   ----------
   -- Fmod --
   ----------

   function Fmod (X : Float; Y : Float) return Float is
      R : constant Float := Float'Remainder (X, Y);
   begin
      if X >= 0.0 then
         return (if R < 0.0 then R + Y else R);
      else
         return (if R > 0.0 then R - Y else R);
      end if;
   end Fmod;

   --  Growth factor per second of the sweep, saturated at the base range.
   function Sweep_Base_Of (F0 : Chirp_Frequency; F1 : Chirp_Frequency; T1 : Chirp_Seconds)
     return Sweep_Base
   is
      Ratio : constant Float := F1 / F0;
   begin
      pragma Assert (Ratio in 1.0e-4 .. 1.0e4);
      return Constrain_F (Pow_Approx_Saturated (Ratio, 1.0 / T1), Sweep_Base'First, Sweep_Base'Last);
   end Sweep_Base_Of;

   --  Two pi over the logarithm of the base, with the logarithm held away
   --  from zero so the quotient is finite.
   function Sweep_Gain_Of (Beta : Sweep_Base) return Sweep_Gain is
      L     : constant Float := Log_Approx (Beta);
      Floor : constant Float := 2.0 ** (-20);
      Safe  : constant Float :=
        (if L >= 0.0 then Float'Max (Floor, L) else Float'Min (-Floor, L));
   begin
      return Constrain_F (Two_Pi / Safe, Sweep_Gain'First, Sweep_Gain'Last);
   end Sweep_Gain_Of;

   ----------
   -- Init --
   ----------

   procedure Init
     (G : out Generator; F0 : Chirp_Frequency; F1 : Chirp_Frequency;
      T1 : Chirp_Seconds; Loop_Time : Loop_Time_Us)
   is
      Ts   : constant Sample_Period := Float (Loop_Time) * 1.0e-6;
      Beta : constant Sweep_Base := Sweep_Base_Of (F0, F1, T1);
      K0   : constant Sweep_Gain := Sweep_Gain_Of (Beta);
   begin
      G := (F0          => F0,
            Ts          => Ts,
            N           => Unsigned_32 (Float'Truncation (T1 / Ts)),
            Beta        => Beta,
            K0          => K0,
            K1          => K0 * F0,
            Count       => 0,
            F_Chirp     => 0.0,
            Sin_Arg     => 0.0,
            Is_Finished => False);
   end Init;

   -----------
   -- Reset --
   -----------

   procedure Reset (G : in out Generator) is
   begin
      G.Count := 0;
      G.Is_Finished := False;
      G.F_Chirp := 0.0;
      G.Sin_Arg := 0.0;
   end Reset;

   -------------------
   -- Reset_Signals --
   -------------------

   procedure Reset_Signals (G : in out Generator) is
   begin
      G.F_Chirp := 0.0;
      G.Sin_Arg := 0.0;
   end Reset_Signals;

   ------------
   -- Update --
   ------------

   procedure Update (G : in out Generator; Running : out Boolean) is
   begin
      if G.Is_Finished then
         Running := False;
      elsif G.Count = G.N then
         G.Is_Finished := True;
         Reset_Signals (G);
         Running := False;
      else
         declare
            Elapsed : constant Float :=
              Constrain_F (Float (G.Count) * G.Ts, 0.0, 2.0 ** 20);
            Growth  : constant Float :=
              Constrain_F (Pow_Approx_Saturated (G.Beta, Elapsed), 0.0, Sweep_Frequency'Last);
         begin
            G.F_Chirp := Constrain_F (G.F0 * Growth, Sweep_Frequency'First, Sweep_Frequency'Last);
            G.Sin_Arg := Fmod (G.K0 * G.F_Chirp - G.K1, Two_Pi);
            G.Count := G.Count + 1;
            Running := True;
         end;
      end if;
   end Update;

end Adaflight.Chirp;
