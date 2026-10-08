--  Sliding discrete Fourier transform over a window of Sample_Size
--  samples, updated one sample at a time in O(bins) per sample.
--
--  The twiddle factors carry the damping factor 0.9999 so the recursion is
--  stable. They are static constants computed once from the fast sine and
--  cosine, so the package has no elaboration.

with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.SDFT with SPARK_Mode, Pure is

   use type Interfaces.Integer_32;

   Sample_Size : constant := 72;
   Bin_Count   : constant := Sample_Size / 2;

   subtype Bin is Natural range 0 .. Bin_Count - 1;
   subtype Sample_Index is Natural range 0 .. Sample_Size - 1;

   --  Spectrum values are saturated at a bound the damped recursion cannot
   --  reach from Signal inputs; the saturation only absorbs rounding.
   Spectrum_Bound : constant := 2.0 ** 48;
   subtype Spectrum_Value is Float range -Spectrum_Bound .. Spectrum_Bound;

   type Complex is record
      Re : Spectrum_Value := 0.0;
      Im : Spectrum_Value := 0.0;
   end record;

   type Spectrum is array (Bin) of Complex;
   type Sample_Buffer is array (Sample_Index) of Signal;
   type Magnitudes is array (Bin) of Float;

   subtype Batch_Count is Positive range 1 .. Bin_Count;

   type Transform is record
      Idx         : Sample_Index := 0;
      Start_Bin   : Bin := 0;
      End_Bin     : Bin := Bin_Count - 1;
      Batch_Size  : Natural := Bin_Count;
      Num_Batches : Batch_Count := 1;
      Samples     : Sample_Buffer := (others => 0.0);
      Data        : Spectrum := (others => (Re => 0.0, Im => 0.0));
   end record
     with Dynamic_Predicate =>
       Transform.Start_Bin <= Transform.End_Bin
       and then Transform.Batch_Size
                = (Transform.End_Bin - Transform.Start_Bin + 1) / Transform.Num_Batches;

   --  Out of range bins are constrained as the reference does: the start
   --  bin into the bin range, the end bin to at least the start bin, and
   --  the batch count to at least one.
   procedure Init (T : out Transform; Start_Bin : Integer; End_Bin : Integer; Num_Batches : Integer)
     with Post => T.Idx = 0;

   procedure Push (T : in out Transform; Sample : Signal)
     with Post => T.Start_Bin = T.Start_Bin'Old and then T.End_Bin = T.End_Bin'Old
       and then T.Num_Batches = T.Num_Batches'Old;

   procedure Push_Batch (T : in out Transform; Sample : Signal; Batch_Idx : Natural)
     with Pre  => Batch_Idx < T.Num_Batches,
          Post => T.Start_Bin = T.Start_Bin'Old and then T.End_Bin = T.End_Bin'Old
       and then T.Num_Batches = T.Num_Batches'Old;

   --  Squared magnitude of the active bins; other entries are left as given.
   procedure Mag_Sq (T : Transform; Output : in out Magnitudes)
     with Post => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0);

   procedure Magnitude (T : Transform; Output : in out Magnitudes)
     with Post => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0);

   --  Squared magnitude with a Hann window applied in the frequency domain.
   --  The edges of the active range read one bin beyond it, so the range
   --  must leave one bin free on each side where it does not touch the end.
   procedure Win_Sq (T : Transform; Output : in out Magnitudes)
     with Pre  => T.End_Bin >= 1 and then T.Start_Bin <= Bin_Count - 2,
          Post => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0);

   procedure Window (T : Transform; Output : in out Magnitudes)
     with Pre  => T.End_Bin >= 1 and then T.Start_Bin <= Bin_Count - 2,
          Post => (for all B in T.Start_Bin .. T.End_Bin => Output (B) >= 0.0);

   Damping : constant Float := 0.9999;

   --  Damping ** Sample_Size.
   Damping_Power_N : constant Float := 16#1.FC5378# * 2.0 ** (-1);

   subtype Twiddle_Value is Float range -1.0 .. 1.0;

   type Twiddle_Factor is record
      Re : Twiddle_Value;
      Im : Twiddle_Value;
   end record;

   type Twiddle_Table is array (Bin) of Twiddle_Factor;

   Twiddle : constant Twiddle_Table :=
     (0 => (Re => 16#1.FFF2E4# * 2.0 ** (-1), Im => 0.0),
       1 => (Re => 16#1.FE002C# * 2.0 ** (-1), Im => 16#1.64F3CC# * 2.0 ** (-4)),
       2 => (Re => 16#1.F82BD# * 2.0 ** (-1), Im => 16#1.639832# * 2.0 ** (-3)),
       3 => (Re => 16#1.EE812C# * 2.0 ** (-1), Im => 16#1.0900F2# * 2.0 ** (-2)),
       4 => (Re => 16#1.E11312# * 2.0 ** (-1), Im => 16#1.5E319# * 2.0 ** (-2)),
       5 => (Re => 16#1.CFFBB# * 2.0 ** (-1), Im => 16#1.B0B7E8# * 2.0 ** (-2)),
       6 => (Re => 16#1.BB5C52# * 2.0 ** (-1), Im => 16#1.FFF31# * 2.0 ** (-2)),
       7 => (Re => 16#1.A35D26# * 2.0 ** (-1), Im => 16#1.25A452# * 2.0 ** (-1)),
       8 => (Re => 16#1.882CF# * 2.0 ** (-1), Im => 16#1.4912F4# * 2.0 ** (-1)),
       9 => (Re => 16#1.6A00A# * 2.0 ** (-1), Im => 16#1.6A00A# * 2.0 ** (-1)),
      10 => (Re => 16#1.4912F2# * 2.0 ** (-1), Im => 16#1.882CF2# * 2.0 ** (-1)),
      11 => (Re => 16#1.25A452# * 2.0 ** (-1), Im => 16#1.A35D26# * 2.0 ** (-1)),
      12 => (Re => 16#1.FFF30C# * 2.0 ** (-2), Im => 16#1.BB5C54# * 2.0 ** (-1)),
      13 => (Re => 16#1.B0B7E8# * 2.0 ** (-2), Im => 16#1.CFFBB# * 2.0 ** (-1)),
      14 => (Re => 16#1.5E318E# * 2.0 ** (-2), Im => 16#1.E11314# * 2.0 ** (-1)),
      15 => (Re => 16#1.0900EE# * 2.0 ** (-2), Im => 16#1.EE812C# * 2.0 ** (-1)),
      16 => (Re => 16#1.63983# * 2.0 ** (-3), Im => 16#1.F82BD# * 2.0 ** (-1)),
      17 => (Re => 16#1.64F3D8# * 2.0 ** (-4), Im => 16#1.FE002C# * 2.0 ** (-1)),
      18 => (Re => 0.0, Im => 16#1.FFF2E4# * 2.0 ** (-1)),
      19 => (Re => -16#1.64F3D8# * 2.0 ** (-4), Im => 16#1.FE002C# * 2.0 ** (-1)),
      20 => (Re => -16#1.63983E# * 2.0 ** (-3), Im => 16#1.F82BD# * 2.0 ** (-1)),
      21 => (Re => -16#1.0900F8# * 2.0 ** (-2), Im => 16#1.EE812A# * 2.0 ** (-1)),
      22 => (Re => -16#1.5E318E# * 2.0 ** (-2), Im => 16#1.E11314# * 2.0 ** (-1)),
      23 => (Re => -16#1.B0B7E8# * 2.0 ** (-2), Im => 16#1.CFFBB# * 2.0 ** (-1)),
      24 => (Re => -16#1.FFF314# * 2.0 ** (-2), Im => 16#1.BB5C52# * 2.0 ** (-1)),
      25 => (Re => -16#1.25A45# * 2.0 ** (-1), Im => 16#1.A35D28# * 2.0 ** (-1)),
      26 => (Re => -16#1.4912F2# * 2.0 ** (-1), Im => 16#1.882CF2# * 2.0 ** (-1)),
      27 => (Re => -16#1.6A00A6# * 2.0 ** (-1), Im => 16#1.6A009C# * 2.0 ** (-1)),
      28 => (Re => -16#1.882CF2# * 2.0 ** (-1), Im => 16#1.4912F2# * 2.0 ** (-1)),
      29 => (Re => -16#1.A35D28# * 2.0 ** (-1), Im => 16#1.25A45# * 2.0 ** (-1)),
      30 => (Re => -16#1.BB5C56# * 2.0 ** (-1), Im => 16#1.FFF308# * 2.0 ** (-2)),
      31 => (Re => -16#1.CFFBB# * 2.0 ** (-1), Im => 16#1.B0B7E8# * 2.0 ** (-2)),
      32 => (Re => -16#1.E11314# * 2.0 ** (-1), Im => 16#1.5E318E# * 2.0 ** (-2)),
      33 => (Re => -16#1.EE812C# * 2.0 ** (-1), Im => 16#1.0900EE# * 2.0 ** (-2)),
      34 => (Re => -16#1.F82BD# * 2.0 ** (-1), Im => 16#1.63983E# * 2.0 ** (-3)),
      35 => (Re => -16#1.FE002C# * 2.0 ** (-1), Im => 16#1.64F3D8# * 2.0 ** (-4)));

end Adaflight.SDFT;
