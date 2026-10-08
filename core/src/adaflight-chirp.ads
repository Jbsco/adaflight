--  Exponential chirp excitation for system identification: a sine whose
--  frequency sweeps from a start to an end frequency over a fixed time.
--
--  The sweep constants are saturated at bounds no admissible sweep reaches,
--  which keeps every field finite by type. A sweep whose end frequency
--  equals its start has no finite constant in the reference; here the
--  logarithm of the ratio is held away from zero instead.

with Interfaces;
with Adaflight.Maths; use Adaflight.Maths;

package Adaflight.Chirp with SPARK_Mode, Pure is

   use type Interfaces.Unsigned_32;

   subtype Unsigned_32 is Interfaces.Unsigned_32;

   subtype Chirp_Frequency is Float range 0.1 .. 1000.0;
   subtype Chirp_Seconds is Float range 1.0 .. 1000.0;
   subtype Loop_Time_Us is Unsigned_32 range 1 .. 1_000_000;

   subtype Sample_Period is Float range 1.0e-6 .. 1.0;
   subtype Sweep_Base is Float range 2.0 ** (-20) .. 2.0 ** 20;
   subtype Sweep_Gain is Float range -2.0 ** 24 .. 2.0 ** 24;
   subtype Sweep_Offset is Float range -2.0 ** 34 .. 2.0 ** 34;
   subtype Sweep_Frequency is Float range 0.0 .. 2.0 ** 24;
   subtype Phase is Float range -2.0 * Pi .. 2.0 * Pi;

   type Generator is record
      F0          : Chirp_Frequency := 1.0;
      Ts          : Sample_Period := 1.0e-3;
      Beta        : Sweep_Base := 1.0;
      K0          : Sweep_Gain := 0.0;
      K1          : Sweep_Offset := 0.0;
      Count       : Unsigned_32 := 0;
      N           : Unsigned_32 := 0;
      F_Chirp     : Sweep_Frequency := 0.0;
      Sin_Arg     : Phase := 0.0;
      Is_Finished : Boolean := False;
   end record;

   --  Start frequency F0, end frequency F1, duration T1, and the loop time.
   procedure Init
     (G : out Generator; F0 : Chirp_Frequency; F1 : Chirp_Frequency;
      T1 : Chirp_Seconds; Loop_Time : Loop_Time_Us)
     with Post => G.Count = 0 and then not G.Is_Finished;

   procedure Reset (G : in out Generator)
     with Post => G.Count = 0 and then not G.Is_Finished
       and then G.F_Chirp = 0.0 and then G.Sin_Arg = 0.0;

   procedure Reset_Signals (G : in out Generator)
     with Post => G.F_Chirp = 0.0 and then G.Sin_Arg = 0.0
       and then G.Count = G.Count'Old and then G.Is_Finished = G.Is_Finished'Old;

   --  Advances one sample; Running is False once the sweep is finished.
   procedure Update (G : in out Generator; Running : out Boolean);

   --  Remainder of the division, truncated toward zero as the C library
   --  function fmodf computes it.
   function Fmod (X : Float; Y : Float) return Float
     with Pre  => Y in 2.0 ** (-20) .. 2.0 ** 20 and then abs X <= 2.0 ** 60,
          Post => abs Fmod'Result < Y;

end Adaflight.Chirp;
