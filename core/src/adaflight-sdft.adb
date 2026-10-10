package body Adaflight.SDFT with SPARK_Mode is

   subtype Shifted_Value is Float range -(Spectrum_Bound + Signal_Bound) .. Spectrum_Bound + Signal_Bound;

   --  One recursion step on a bin: multiply the shifted value by the
   --  twiddle factor and saturate at the spectrum bound.
   procedure Advance (D : in out Complex; W : Twiddle_Factor; Delta_Value : Shifted_Value)
     with Inline
   is
      Re : constant Float := D.Re + Delta_Value;
      Im : constant Float := D.Im;
   begin
      D.Re := Constrain_F (W.Re * Re - W.Im * Im, -Spectrum_Bound, Spectrum_Bound);
      D.Im := Constrain_F (W.Re * Im + W.Im * Re, -Spectrum_Bound, Spectrum_Bound);
   end Advance;

   procedure Update_Edges (T : in out Transform; Value : Shifted_Value; Batch_Idx : Natural)
     with Inline,
          Post => T.Start_Bin = T.Start_Bin'Old and then T.End_Bin = T.End_Bin'Old
            and then T.Num_Batches = T.Num_Batches'Old and then T.Batch_Size = T.Batch_Size'Old
            and then T.Idx = T.Idx'Old and then T.Samples = T.Samples'Old
   is
   begin
      if T.Start_Bin > 0 and then Batch_Idx = 0 then
         Advance (T.Data (T.Start_Bin - 1), Twiddle (T.Start_Bin - 1), Value);
      end if;
      if T.End_Bin < Bin_Count - 1 and then Batch_Idx = T.Num_Batches - 1 then
         Advance (T.Data (T.End_Bin + 1), Twiddle (T.End_Bin + 1), Value);
      end if;
   end Update_Edges;

   ----------
   -- Init --
   ----------

   procedure Init (T : out Transform; Start_Bin : Integer; End_Bin : Integer; Num_Batches : Integer) is
      S : constant Bin := Integer'Max (0, Integer'Min (Bin_Count - 1, Start_Bin));
      E : constant Bin := Integer'Max (S, Integer'Min (Bin_Count - 1, End_Bin));
      N : constant Batch_Count := Integer'Max (1, Integer'Min (Bin_Count, Num_Batches));
   begin
      T := (Idx         => 0,
            Start_Bin   => S,
            End_Bin     => E,
            Batch_Size  => (E - S + 1) / N,
            Num_Batches => N,
            Samples     => (others => 0.0),
            Data        => (others => (Re => 0.0, Im => 0.0)));
   end Init;

   ----------
   -- Push --
   ----------

   procedure Push (T : in out Transform; Sample : Signal) is
      Delta_Value : constant Shifted_Value := Sample - Damping_Power_N * T.Samples (T.Idx);
   begin
      T.Samples (T.Idx) := Sample;
      T.Idx := (T.Idx + 1) mod Sample_Size;
      for I in T.Start_Bin .. T.End_Bin loop
         pragma Loop_Invariant (T.Start_Bin = T.Start_Bin'Loop_Entry
                                and then T.End_Bin = T.End_Bin'Loop_Entry
                                and then T.Num_Batches = T.Num_Batches'Loop_Entry
                                and then T.Batch_Size = T.Batch_Size'Loop_Entry
                                and then T.Idx = T.Idx'Loop_Entry
                                and then T.Samples = T.Samples'Loop_Entry);
         Advance (T.Data (I), Twiddle (I), Delta_Value);
      end loop;
      Update_Edges (T, Delta_Value, 0);
   end Push;

   ----------------
   -- Push_Batch --
   ----------------

   procedure Push_Batch (T : in out Transform; Sample : Signal; Batch_Idx : Natural) is
      Batch_Start : constant Natural := T.Batch_Size * Batch_Idx + T.Start_Bin;
      Batch_End   : Natural := Batch_Start;
      Delta_Value : constant Shifted_Value := Sample - Damping_Power_N * T.Samples (T.Idx);
   begin
      pragma Assert (T.Batch_Size * Batch_Idx <= T.End_Bin - T.Start_Bin);
      if Batch_Idx = T.Num_Batches - 1 then
         T.Samples (T.Idx) := Sample;
         T.Idx := (T.Idx + 1) mod Sample_Size;
         Batch_End := Batch_End + (T.End_Bin - Batch_Start + 1);
      else
         Batch_End := Batch_End + T.Batch_Size;
      end if;
      pragma Assert (Batch_End <= T.End_Bin + 1);
      for I in Batch_Start .. Batch_End - 1 loop
         pragma Loop_Invariant (T.Start_Bin = T.Start_Bin'Loop_Entry
                                and then T.End_Bin = T.End_Bin'Loop_Entry
                                and then T.Num_Batches = T.Num_Batches'Loop_Entry
                                and then T.Batch_Size = T.Batch_Size'Loop_Entry
                                and then T.Idx = T.Idx'Loop_Entry
                                and then T.Samples = T.Samples'Loop_Entry);
         Advance (T.Data (I), Twiddle (I), Delta_Value);
      end loop;
      Update_Edges (T, Delta_Value, Batch_Idx);
   end Push_Batch;

   ------------
   -- Mag_Sq --
   ------------

   procedure Mag_Sq (T : Transform; Output : in out Magnitudes) is
   begin
      for I in T.Start_Bin .. T.End_Bin loop
         pragma Loop_Invariant (for all B in T.Start_Bin .. I - 1 => Output (B) >= 0.0);
         Output (I) := T.Data (I).Re * T.Data (I).Re + T.Data (I).Im * T.Data (I).Im;
      end loop;
   end Mag_Sq;

   procedure Apply_Sqrt (T : Transform; Output : in out Magnitudes)
     with Pre  => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0),
          Post => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0)
   is
   begin
      for I in T.Start_Bin .. T.End_Bin loop
         pragma Loop_Invariant (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0);
         Output (I) := Sqrt_Non_Negative (Output (I));
      end loop;
   end Apply_Sqrt;

   ---------------
   -- Magnitude --
   ---------------

   procedure Magnitude (T : Transform; Output : in out Magnitudes) is
   begin
      Mag_Sq (T, Output);
      Apply_Sqrt (T, Output);
   end Magnitude;

   ------------
   -- Win_Sq --
   ------------

   function Windowed_Power (Center : Complex; Lower : Complex; Upper : Complex) return Float
     with Inline, Post => Windowed_Power'Result >= 0.0
   is
      Re : constant Float := Center.Re - 0.5 * (Lower.Re + Upper.Re);
      Im : constant Float := Center.Im - 0.5 * (Lower.Im + Upper.Im);
   begin
      return Re * Re + Im * Im;
   end Windowed_Power;

   function Edge_Power (Center : Complex; Neighbor : Complex) return Float
     with Inline, Post => Edge_Power'Result >= 0.0
   is
      Re : constant Float := Center.Re - Neighbor.Re;
      Im : constant Float := Center.Im - Neighbor.Im;
   begin
      return Re * Re + Im * Im;
   end Edge_Power;

   procedure Win_Sq (T : Transform; Output : in out Magnitudes) is
   begin
      if T.Start_Bin = 0 then
         Output (T.Start_Bin) := Edge_Power (T.Data (T.Start_Bin), T.Data (T.Start_Bin + 1));
      else
         Output (T.Start_Bin) :=
           Windowed_Power (T.Data (T.Start_Bin), T.Data (T.Start_Bin - 1), T.Data (T.Start_Bin + 1));
      end if;
      for I in T.Start_Bin + 1 .. T.End_Bin - 1 loop
         pragma Loop_Invariant (for all B in T.Start_Bin .. I - 1 => Output (B) >= 0.0);
         Output (I) := Windowed_Power (T.Data (I), T.Data (I - 1), T.Data (I + 1));
      end loop;
      if T.End_Bin = Bin_Count - 1 then
         Output (T.End_Bin) := Edge_Power (T.Data (T.End_Bin), T.Data (T.End_Bin - 1));
      else
         Output (T.End_Bin) :=
           Windowed_Power (T.Data (T.End_Bin), T.Data (T.End_Bin - 1), T.Data (T.End_Bin + 1));
      end if;
   end Win_Sq;

   ------------
   -- Window --
   ------------

   procedure Window (T : Transform; Output : in out Magnitudes) is
   begin
      Win_Sq (T, Output);
      Apply_Sqrt (T, Output);
   end Window;

end Adaflight.SDFT;
